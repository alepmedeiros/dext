unit Dext.Entity.Metadata;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Consts,
  SimpleParser.Lexer.Types,
  Dext.Entity.Core;

type
  TEntityMetadataParser = class
    FTypeAttributes: TList<TSyntaxNode>;
    FMemberAttributes: TList<TSyntaxNode>;
    function GetNodeText(Node: TSyntaxNode): string;
    function HasAttribute(Nodes: TList<TSyntaxNode>; const AttrName: string; Node: TSyntaxNode = nil): Boolean;
    function GetAttributeValue(Nodes: TList<TSyntaxNode>; const AttrName: string; Node: TSyntaxNode = nil): string;
    procedure ExtractMembers(AMetadata: TEntityClassMetadata; AClassNode: TSyntaxNode);
  public
    constructor Create;
    destructor Destroy; override;
    function ParseUnit(const AFileName: string; const AContent: string = ''): IList<TEntityClassMetadata>;
    procedure Log(const Msg: string);
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.Types,
  System.TypInfo,
  System.StrUtils;

const
  LogPath = 'C:\dev\Dext\dext_metadata_debug.log';

procedure TEntityMetadataParser.Log(const Msg: string);
begin
  try
    TFile.AppendAllText(LogPath, Msg + sLineBreak);
    OutputDebugString(PChar('DextMetadata: ' + Msg));
  except
    // ignore logging errors
  end;
end;

function TEntityMetadataParser.GetNodeText(Node: TSyntaxNode): string;
  function FindText(ANode: TSyntaxNode): string;
  var
    Child: TSyntaxNode;
  begin
    Result := '';
    if ANode = nil then Exit;
    
    if ANode is TValuedSyntaxNode then
    begin
      Result := TValuedSyntaxNode(ANode).Value;
      if Result <> '' then Exit;
    end;
    
    Result := ANode.GetAttribute(anName);
    if Result <> '' then Exit;
    
    Result := ANode.GetAttribute(anType);
    if Result <> '' then Exit;
    
    for Child in ANode.ChildNodes do
    begin
      Result := FindText(Child);
      if Result <> '' then Exit;
    end;
  end;
begin
  Result := '';
  if Node = nil then Exit;
  Result := FindText(Node);
  if Result.StartsWith('&') then
    Result := Result.Substring(1);
end;

function TEntityMetadataParser.HasAttribute(Nodes: TList<TSyntaxNode>; const AttrName: string; Node: TSyntaxNode): Boolean;
  function Check(ANode: TSyntaxNode): Boolean;
  var
    Attr, AttrNameNode: TSyntaxNode;
    FoundName: string;
  begin
    Result := False;
    if (ANode = nil) or (ANode.Typ <> ntAttributes) then Exit;
    for Attr in ANode.ChildNodes do
    begin
      AttrNameNode := Attr.FindNode(ntName);
      if AttrNameNode <> nil then
      begin
        FoundName := GetNodeText(AttrNameNode);
        if SameText(FoundName, AttrName) or 
           SameText(FoundName, AttrName + 'Attribute') then
        begin
          Log('      ATTR_MATCH: Found [' + AttrName + '] on current search');
          Exit(True);
        end;
      end;
    end;
  end;
var
  Child: TSyntaxNode;
begin
  Result := False;
  if Node <> nil then
  begin
    if Node.Typ = ntAttributes then begin if Check(Node) then Exit(True); end;
    for Child in Node.ChildNodes do
      if Child.Typ = ntAttributes then
        if Check(Child) then Exit(True);
  end;
  if Nodes <> nil then
    for Child in Nodes do
      if Check(Child) then Exit(True);
end;

function TEntityMetadataParser.GetAttributeValue(Nodes: TList<TSyntaxNode>; const AttrName: string; Node: TSyntaxNode): string;
  function GetValFromAttr(AnAttr: TSyntaxNode): string;
  var
    Args, Arg, ValNode: TSyntaxNode;
    RawVal: string;
  begin
    Result := '';
    Args := AnAttr.FindNode(ntArguments);
    if Args <> nil then
    begin
      for Arg in Args.ChildNodes do
      begin
        ValNode := Arg.FindNode(ntValue);
        if ValNode <> nil then
        begin
          RawVal := GetNodeText(ValNode);
          Log('        ARG_DEBUG: Raw value for [' + AttrName + ']: ' + RawVal);
          Result := RawVal.DeQuotedString('''');
          if Result <> '' then Exit;
        end;
      end;
    end;
  end;

  function GetVal(ANode: TSyntaxNode): string;
  var
    Attr, NameNode: TSyntaxNode;
    FoundName: string;
  begin
    Result := '';
    if (ANode = nil) or (ANode.Typ <> ntAttributes) then Exit;
    for Attr in ANode.ChildNodes do
    begin
      NameNode := Attr.FindNode(ntName);
      if NameNode <> nil then
      begin
        FoundName := GetNodeText(NameNode);
        if SameText(FoundName, AttrName) or 
           SameText(FoundName, AttrName + 'Attribute') then
        begin
          Result := GetValFromAttr(Attr);
          Log('        ARG_VAL: [' + AttrName + '] = ' + Result);
          if Result <> '' then Exit;
        end;
      end;
    end;
  end;
var
  Child: TSyntaxNode;
begin
  Result := '';
  if Node <> nil then
  begin
    Result := GetVal(Node);
    if Result <> '' then Exit;
    for Child in Node.ChildNodes do
    begin
      Result := GetVal(Child);
      if Result <> '' then Exit;
    end;
  end;
  if Nodes <> nil then
    for Child in Nodes do
    begin
      Result := GetVal(Child);
      if Result <> '' then Exit;
    end;
end;

procedure TEntityMetadataParser.ExtractMembers(AMetadata: TEntityClassMetadata; AClassNode: TSyntaxNode);
  procedure Scan(ContextNode: TSyntaxNode);
  var
    CChild, Sub: TSyntaxNode;
    MName, MType, AlignAttr: string;
    Member: TEntityMemberMetadata;
    LTemp: string;
  begin
    for CChild in ContextNode.ChildNodes do
    begin
      Log(Format('      SCAN_NODE: Type=%d, Name=%s', [Integer(CChild.Typ), GetNodeText(CChild)]));
      
      if CChild.Typ = ntAttributes then
      begin
        Log('      ATTR_COLLECT: Adding attribute block');
        FMemberAttributes.Add(CChild);
        Continue;
      end;

      if CChild.Typ in [ntProperty, ntField] then
      begin
        MName := GetNodeText(CChild);
        if MName = '' then Continue;

        // SKIP private fields starting with 'F' unless they have attributes
        if (CChild.Typ = ntField) and (FMemberAttributes.Count = 0) and (MName.StartsWith('F')) then
          Continue;

        Log('    MEMBER_SCAN: ' + MName);
        MType := CChild.GetAttribute(anType);
        if MType = '' then
        begin
          for Sub in CChild.ChildNodes do
            if Sub.Typ = ntType then
              MType := GetNodeText(Sub);
        end;

        Member := AMetadata.Members.Add;
        Member.Name := MName;
        Member.MemberType := MType;
        Member.Visible := True;
        
        Member.IsPrimaryKey := HasAttribute(FMemberAttributes, 'PrimaryKey', CChild) or 
                               HasAttribute(FMemberAttributes, 'PK', CChild);
        
        Member.IsRequired := HasAttribute(FMemberAttributes, 'Required', CChild);
        Member.IsAutoInc := HasAttribute(FMemberAttributes, 'AutoInc', CChild);
        Member.IsReadOnly := HasAttribute(FMemberAttributes, 'NotMapped', CChild);
        Member.IsCurrency := HasAttribute(FMemberAttributes, 'Currency', CChild);
        
        Member.DefaultValue := GetAttributeValue(FMemberAttributes, 'DefaultValue', CChild);

        // DisplayLabel / Caption / DisplayName
        LTemp := GetAttributeValue(FMemberAttributes, 'Caption', CChild);
        if LTemp = '' then LTemp := GetAttributeValue(FMemberAttributes, 'DisplayLabel', CChild);
        if LTemp = '' then LTemp := GetAttributeValue(FMemberAttributes, 'DisplayName', CChild);
        if LTemp <> '' then Member.DisplayLabel := LTemp;

        // DisplayFormat
        LTemp := GetAttributeValue(FMemberAttributes, 'DisplayFormat', CChild);
        if LTemp <> '' then Member.DisplayFormat := LTemp;

        // EditMask
        LTemp := GetAttributeValue(FMemberAttributes, 'EditMask', CChild);
        if LTemp <> '' then Member.EditMask := LTemp;

        // Visible
        LTemp := GetAttributeValue(FMemberAttributes, 'Visible', CChild);
        if LTemp <> '' then Member.Visible := SameText(LTemp, 'True');

        // Integer Attributes (Only set if > 0)
        LTemp := GetAttributeValue(FMemberAttributes, 'MaxLength', CChild);
        if (LTemp <> '') and (StrToIntDef(LTemp, 0) > 0) then Member.MaxLength := StrToInt(LTemp);

        LTemp := GetAttributeValue(FMemberAttributes, 'DisplayWidth', CChild);
        if (LTemp <> '') and (StrToIntDef(LTemp, 0) > 0) then Member.DisplayWidth := StrToInt(LTemp);

        LTemp := GetAttributeValue(FMemberAttributes, 'Precision', CChild);
        if (LTemp <> '') and (StrToIntDef(LTemp, 0) > 0) then Member.Precision := StrToInt(LTemp);

        // Alignment
        AlignAttr := GetAttributeValue(FMemberAttributes, 'Alignment', CChild);
        if AlignAttr <> '' then Member.Alignment := TAlignment(GetEnumValue(TypeInfo(TAlignment), AlignAttr));

        FMemberAttributes.Clear;
      end
      else if CChild.Typ in [ntPrivate, ntPublic, ntPublished, ntProtected, ntStrictPrivate, ntStrictProtected] then
      begin
        Log('      SCAN_SCOPE: Entering ' + GetNodeText(CChild));
        Scan(CChild);
      end
      else if not (CChild.Typ in [ntAnsiComment, ntBorComment, ntSlashesComment]) then
      begin
        if FMemberAttributes.Count > 0 then
          Log(Format('      ATTR_CLEAR: Noise node (%d) cleared %d attrs', [Integer(CChild.Typ), FMemberAttributes.Count]));
        FMemberAttributes.Clear;
      end;
    end;
  end;
begin
  FMemberAttributes.Clear;
  Scan(AClassNode);
end;

constructor TEntityMetadataParser.Create;
begin
  FTypeAttributes := TList<TSyntaxNode>.Create;
  FMemberAttributes := TList<TSyntaxNode>.Create;
end;

destructor TEntityMetadataParser.Destroy;
begin
  FTypeAttributes.Free;
  FMemberAttributes.Free;
  inherited;
end;

function TEntityMetadataParser.ParseUnit(const AFileName: string; const AContent: string): IList<TEntityClassMetadata>;
var
  Builder: TPasSyntaxTreeBuilder;
  SyntaxTree, InterfaceNode, TypeSection, TypeNode, ClassNode: TSyntaxNode;
  ClassName, TableName, DisplayName, LContent, LUnitName: string;
  Stream: TStringStream;
  Metadata: TEntityClassMetadata;
begin
  Result := TCollections.CreateObjectList<TEntityClassMetadata>(True);
  LContent := AContent;
  LUnitName := ChangeFileExt(ExtractFileName(AFileName), '');

  if LContent = '' then
  begin
    if not FileExists(AFileName) then
    begin
       Log('  ERROR: File ' + AFileName + ' not found');
       Exit;
    end;
    try
      LContent := TFile.ReadAllText(AFileName);
    except
      on E: Exception do 
      begin
        Log('  ERROR reading file: ' + E.Message);
        Exit;
      end;
    end;
  end;

  Log('--- Dext Metadata Parsing Start ---');
  Log('Time: ' + DateTimeToStr(Now));
  Log('Unit: ' + LUnitName);
  
  Builder := TPasSyntaxTreeBuilder.Create;
  try
    Builder.InitDefinesDefinedByCompiler;
    Builder.AddDefine('MSWINDOWS');
    Builder.UseDefines := True;

    Stream := TStringStream.Create(LContent);
    try
      try
        SyntaxTree := Builder.Run(Stream);
        try
          InterfaceNode := SyntaxTree.FindNode(ntInterface);
          if InterfaceNode = nil then InterfaceNode := SyntaxTree;

          for TypeSection in InterfaceNode.ChildNodes do
          begin
            if TypeSection.Typ <> ntTypeSection then Continue;

            FTypeAttributes.Clear;
            for TypeNode in TypeSection.ChildNodes do
            begin
              if TypeNode.Typ = ntAttributes then
              begin
                FTypeAttributes.Add(TypeNode);
                Continue;
              end;

              if TypeNode.Typ = ntTypeDecl then
              begin
                ClassName := TypeNode.GetAttribute(anName);
                ClassNode := TypeNode.FindNode(ntType);

                if (ClassNode <> nil) and SameText(ClassNode.GetAttribute(anType), 'class') then
                begin
                   if HasAttribute(FTypeAttributes, 'Table', TypeNode) or HasAttribute(FTypeAttributes, 'Entity', TypeNode) then
                   begin
                    Log('    Found Entity Class: ' + ClassName);
                    
                    TableName := GetAttributeValue(FTypeAttributes, 'Table', TypeNode);
                    if TableName = '' then TableName := GetAttributeValue(FTypeAttributes, 'Entity', TypeNode);
                    if TableName = '' then TableName := ClassName;
                    
                    DisplayName := GetAttributeValue(FTypeAttributes, 'DisplayLabel', TypeNode);
                    if DisplayName = '' then DisplayName := GetAttributeValue(FTypeAttributes, 'DisplayName', TypeNode);
                    if DisplayName = '' then DisplayName := GetAttributeValue(FTypeAttributes, 'Caption', TypeNode);

                    Metadata := TEntityClassMetadata.Create;
                    Metadata.EntityClassName := ClassName;
                    Metadata.DisplayName := DisplayName;
                    Metadata.EntityUnitName := LUnitName;
                    Metadata.TableName := TableName;
                    ExtractMembers(Metadata, ClassNode);
                    Result.Add(Metadata);
                  end
                  else
                    Log('    Skipping Class (no Entity/Table attribute): ' + ClassName);
                end;
                // ALWAYS clear after any type declaration node to prepare for the next potential class
                FTypeAttributes.Clear;
              end;
            end;
          end;
        finally
          SyntaxTree.Free;
        end;
      except
        on E: Exception do Log('  FATAL: Parser Exception: ' + E.Message);
      end;
    finally
      Stream.Free;
    end;
  finally
    Builder.Free;
  end;
end;

end.
