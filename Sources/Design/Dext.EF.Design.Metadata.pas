unit Dext.EF.Design.Metadata;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections,
  Dext.Collections.Base,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Consts,
  SimpleParser.Lexer.Types,
  Dext.Entity.Core,
  Dext.Entity.DataProvider;

type
  TEntityMetadataParser = class
  private
    function GetNodeText(Node: TSyntaxNode): string;
    function GetAttributeContainer(Node: TSyntaxNode): TSyntaxNode;
    function GetAttributeName(Node: TSyntaxNode): string;
    function HasAttribute(Node: TSyntaxNode; const AttrName: string): Boolean;
    function GetAttributeValue(Node: TSyntaxNode; const AttrName: string): string;
    procedure ExtractMembers(AMetadata: TEntityClassMetadata; AClassNode: TSyntaxNode);
  public
    function ParseUnit(const AFileName: string): IList<TEntityClassMetadata>;
  end;

procedure RefreshProviderMetadata(AProvider: TEntityDataProvider);

implementation

uses
  System.IOUtils,
  System.Types;

function TEntityMetadataParser.GetNodeText(Node: TSyntaxNode): string;
begin
  if Node = nil then Exit('');
  
  Result := Node.GetAttribute(anName);
    
  if (Result = '') and (Node is TValuedSyntaxNode) then
    Result := TValuedSyntaxNode(Node).Value;

  if Result = '' then
  begin
    // Search recursively in relevant container nodes
    if Node.Typ in [ntName, ntIdentifier, ntExpression, ntArguments, ntPositionalArgument, 
                   ntNamedArgument, ntConstant, ntLiteral, ntValue] then
    begin
      for var Child in Node.ChildNodes do
      begin
        Result := GetNodeText(Child);
        if Result <> '' then
          Break;
      end;
    end;
  end;

  if Result.StartsWith('&') then
    Result := Result.Substring(1);
end;

function TEntityMetadataParser.GetAttributeContainer(Node: TSyntaxNode): TSyntaxNode;
var
  Child: TSyntaxNode;
begin
  Result := nil;
  if Node = nil then
    Exit;

  if Node.Typ = ntAttributes then
    Exit(Node);

  for Child in Node.ChildNodes do
    if Child.Typ = ntAttributes then
      Exit(Child);
end;

function TEntityMetadataParser.GetAttributeName(Node: TSyntaxNode): string;
var
  Child: TSyntaxNode;
begin
  Result := '';
  if Node = nil then
    Exit;

  if Node.Typ = ntAttribute then
  begin
    Result := GetNodeText(Node);
    if Result <> '' then
      Exit;
  end;

  for Child in Node.ChildNodes do
  begin
    if Child.Typ = ntName then
    begin
      Result := GetNodeText(Child);
      Exit;
    end;
  end;

  Result := GetNodeText(Node);
end;

function TEntityMetadataParser.HasAttribute(Node: TSyntaxNode; const AttrName: string): Boolean;
var
  AttrsNode: TSyntaxNode;
  Attr: TSyntaxNode;
  AName: string;
begin
  Result := False;
  if Node = nil then
    Exit;

  AttrsNode := GetAttributeContainer(Node);
  if AttrsNode = nil then
    Exit;

  for Attr in AttrsNode.ChildNodes do
  begin
    if Attr.Typ = ntAttribute then
    begin
      AName := GetAttributeName(Attr);
      if SameText(AName, AttrName) or SameText(AName, AttrName + 'Attribute') then
        Exit(True);
    end;
  end;
end;

function TEntityMetadataParser.GetAttributeValue(Node: TSyntaxNode; const AttrName: string): string;
var
  AttrsNode: TSyntaxNode;
  Attr: TSyntaxNode;
  Arg: TSyntaxNode;
  AName: string;
begin
  Result := '';
  AttrsNode := GetAttributeContainer(Node);
  if AttrsNode = nil then
    Exit;

  for Attr in AttrsNode.ChildNodes do
  begin
    AName := GetAttributeName(Attr);
    if SameText(AName, AttrName) or SameText(AName, AttrName + 'Attribute') then
    begin
      for Arg in Attr.ChildNodes do
      begin
        if Arg.Typ in [ntName, ntAttributes] then
          Continue;

        Result := GetNodeText(Arg);
        if Result <> '' then
          Exit(Result.DeQuotedString(''''));
      end;
      Exit('');
    end;
  end;
end;

procedure TEntityMetadataParser.ExtractMembers(AMetadata: TEntityClassMetadata; AClassNode: TSyntaxNode);
  procedure Scan(ContextNode: TSyntaxNode);
  var
    CChild: TSyntaxNode;
    MName: string;
    MType: string;
    Member: TEntityMemberMetadata;
    VisAttr: string;
    LenAttr: string;
    WidthAttr: string;
    PrecisionAttr: string;
    DefAttr: string;
    AlignAttr: string;
    LastMemberAttributes: TSyntaxNode;
    ActualNode: TSyntaxNode;
    
    function MemberHasAttr(const AName: string): Boolean;
    begin
      Result := HasAttribute(LastMemberAttributes, AName) or HasAttribute(CChild, AName);
    end;
    
    function MemberGetAttr(const AName: string): string;
    begin
      Result := GetAttributeValue(LastMemberAttributes, AName);
      if Result = '' then
        Result := GetAttributeValue(CChild, AName);
    end;
  begin
    LastMemberAttributes := nil;
    for CChild in ContextNode.ChildNodes do
    begin
      if CChild.Typ = ntAttributes then
      begin
        LastMemberAttributes := CChild;
        Continue;
      end;

      if CChild.Typ in [ntProperty, ntField] then
      begin
        MName := GetNodeText(CChild);
        if MName = '' then
          Continue;

        ActualNode := CChild.FindNode(ntType);
        if ActualNode <> nil then
          MType := GetNodeText(ActualNode)
        else
          MType := CChild.GetAttribute(anType);

        Member := TEntityMemberMetadata.Create;
        Member.Name := MName;
        Member.MemberType := MType;
        Member.Visible := True;
        Member.IsPrimaryKey := MemberHasAttr('PrimaryKey') or MemberHasAttr('PK');
        Member.IsRequired := MemberHasAttr('Required');
        Member.IsAutoInc := MemberHasAttr('AutoInc');
        Member.IsReadOnly := MemberHasAttr('NotMapped');
        Member.DisplayLabel := MemberGetAttr('Caption');
        if Member.DisplayLabel = '' then
          Member.DisplayLabel := MemberGetAttr('DisplayLabel');
        Member.DisplayFormat := MemberGetAttr('DisplayFormat');
        Member.EditMask := MemberGetAttr('EditMask');

        VisAttr := MemberGetAttr('Visible');
        if VisAttr <> '' then
          Member.Visible := SameText(VisAttr, 'True')
        else
          Member.Visible := True;

        LenAttr := MemberGetAttr('MaxLength');
        if LenAttr <> '' then
          Member.MaxLength := StrToIntDef(LenAttr, 0);

        WidthAttr := MemberGetAttr('DisplayWidth');
        if WidthAttr <> '' then
          Member.DisplayWidth := StrToIntDef(WidthAttr, 0);

        PrecisionAttr := MemberGetAttr('Precision');
        if PrecisionAttr <> '' then
          Member.Precision := StrToIntDef(PrecisionAttr, 0);

        DefAttr := MemberGetAttr('DefaultValue');
        if DefAttr <> '' then
          Member.DefaultValue := DefAttr;

        AlignAttr := MemberGetAttr('Alignment');
        if AlignAttr <> '' then
        begin
          if SameText(AlignAttr, 'taLeftJustify') then
            Member.Alignment := taLeftJustify
          else if SameText(AlignAttr, 'taRightJustify') then
            Member.Alignment := taRightJustify
          else if SameText(AlignAttr, 'taCenter') then
            Member.Alignment := taCenter;
        end;

        AMetadata.Members.Add(Member);
        LastMemberAttributes := nil;
      end
      else if CChild.Typ in [ntPublic, ntPublished, ntProtected] then
        Scan(CChild);
    end;
  end;
begin
  Scan(AClassNode);
end;

function TEntityMetadataParser.ParseUnit(const AFileName: string): IList<TEntityClassMetadata>;
var
  Builder: TPasSyntaxTreeBuilder;
  SyntaxTree: TSyntaxNode;
  InterfaceNode: TSyntaxNode;
  SearchRoot: TSyntaxNode;
  TypeSection: TSyntaxNode;
  TypeNode: TSyntaxNode;
  ClassNode: TSyntaxNode;
  Content: string;
  Stream: TStringStream;
  Metadata: TEntityClassMetadata;
  ClassName: string;
  TableName: string;
  LastTypeAttributes: TSyntaxNode;
begin
  Result := TCollections.CreateObjectList<TEntityClassMetadata>(True);
  if not FileExists(AFileName) then
    Exit;

  Builder := TPasSyntaxTreeBuilder.Create;
  try
    Builder.InitDefinesDefinedByCompiler;
    Builder.AddDefine('MSWINDOWS');
    Builder.UseDefines := True;

    Content := TFile.ReadAllText(AFileName);
    Stream := TStringStream.Create(Content, TEncoding.UTF8);
    try
      try
        SyntaxTree := Builder.Run(Stream);
        try
          InterfaceNode := SyntaxTree.FindNode(ntInterface);
          if InterfaceNode <> nil then
            SearchRoot := InterfaceNode
          else
            SearchRoot := SyntaxTree;

          for TypeSection in SearchRoot.ChildNodes do
          begin
            if TypeSection.Typ <> ntTypeSection then
              Continue;

            LastTypeAttributes := nil;
            for TypeNode in TypeSection.ChildNodes do
            begin
              if TypeNode.Typ = ntAttributes then
              begin
                LastTypeAttributes := TypeNode;
                Continue;
              end;

              if TypeNode.Typ = ntTypeDecl then
              begin
                ClassName := TypeNode.GetAttribute(anName);
                ClassNode := TypeNode.FindNode(ntType);

                if (ClassNode <> nil) and SameText(ClassNode.GetAttribute(anType), 'class') then
                begin
                  if HasAttribute(LastTypeAttributes, 'Table') or HasAttribute(LastTypeAttributes, 'Entity') or
                     HasAttribute(TypeNode, 'Table') or HasAttribute(TypeNode, 'Entity') then
                  begin
                    TableName := GetAttributeValue(LastTypeAttributes, 'Table');
                    if TableName = '' then
                      TableName := GetAttributeValue(TypeNode, 'Table');
                    if TableName = '' then
                      TableName := GetAttributeValue(LastTypeAttributes, 'Entity');
                    if TableName = '' then
                      TableName := GetAttributeValue(TypeNode, 'Entity');
                    if TableName = '' then
                      TableName := ClassName;

                    Metadata := TEntityClassMetadata.Create;
                    Metadata.ClassName := ClassName;
                    Metadata.TableName := TableName;
                    Metadata.UnitName := ChangeFileExt(ExtractFileName(AFileName), '');
                    ExtractMembers(Metadata, ClassNode);
                    Result.Add(Metadata);
                  end;
                  LastTypeAttributes := nil;
                end;
              end
              else if not (TypeNode.Typ in [ntAnsiComment, ntBorComment, ntSlashesComment]) then
                LastTypeAttributes := nil;
            end;
          end;
        finally
          SyntaxTree.Free;
        end;
      except
        // Ignore parse errors in design-time metadata extraction
      end;
    finally
      Stream.Free;
    end;
  finally
    Builder.Free;
  end;
end;

procedure RefreshProviderMetadata(AProvider: TEntityDataProvider);
var
  Parser: TEntityMetadataParser;
  ParsedList: IList<TEntityClassMetadata>;
  ParsedCollection: ICollection;
  FileName: string;
  MD: TEntityClassMetadata;
begin
  if AProvider = nil then
    Exit;

  AProvider.ClearMetadata;
  AProvider.LogDebug(Format('RefreshProviderMetadata start. ModelUnits=%d', [AProvider.ModelUnits.Count]));
  Parser := TEntityMetadataParser.Create;
  try
    for FileName in AProvider.ModelUnits do
    begin
      AProvider.LogDebug('Parsing unit: ' + FileName);
      ParsedList := Parser.ParseUnit(FileName);
      try
        AProvider.LogDebug(Format('Metadata candidates found in %s: %d', [ExtractFileName(FileName), ParsedList.Count]));
        for MD in ParsedList do
        begin
          AProvider.AddOrSetMetadata(MD);
          AProvider.LogDebug(Format('Entity cached: %s (%s) Table=%s Members=%d',
            [MD.ClassName, MD.UnitName, MD.TableName, MD.Members.Count]));
          for var Member in MD.Members do
            AProvider.LogDebug(Format('  Member: %s Type=%s PK=%s Visible=%s',
              [Member.Name, Member.MemberType, BoolToStr(Member.IsPrimaryKey, True), BoolToStr(Member.Visible, True)]));
        end;
        if Supports(ParsedList, ICollection, ParsedCollection) then
          ParsedCollection.OwnsObjects := False;
      finally
        ParsedList := nil;
      end;
    end;
  finally
    Parser.Free;
  end;

  AProvider.UpdateRefreshSummary;
end;

end.
