unit Dext.EF.Design.Editors;

interface

uses
  System.SysUtils,
  System.Classes,
  System.RegularExpressions,
  DesignIntf,
  DesignEditors,
  ToolsAPI,
  VCLEditors,
  Data.DB,
  Dext.Entity.DataSet,
  Dext.Entity.DataProvider,
  Dext.Entity.Core,
  Dext.EF.Design.Metadata,
  Dext.EF.Design.Preview;

type
  TEntityDataProviderComponentProperty = class(TComponentProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

  TEntityClassNameProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

  TEntityDataProviderEditor = class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

  TEntityDataSetSelectionEditor = class(TSelectionEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer; const List: IDesignerSelections); override;
  end;

procedure RegisterEditors;

implementation

function TryGetActiveProject(out AProject: IOTAProject): Boolean;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  ProjectGroup: IOTAProjectGroup;
  I: Integer;
begin
  AProject := nil;
  ModuleServices := BorlandIDEServices as IOTAModuleServices;
  if ModuleServices = nil then
    Exit(False);

  Module := ModuleServices.CurrentModule;
  if (Module <> nil) and Supports(Module, IOTAProject, AProject) then
    Exit(True);

  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    Module := ModuleServices.Modules[I];
    if (Module <> nil) and Supports(Module, IOTAProjectGroup, ProjectGroup) then
    begin
      AProject := ProjectGroup.ActiveProject;
      Exit(AProject <> nil);
    end;
  end;

  Result := False;
end;

function PopulateProviderModelUnitsFromActiveProject(AProvider: TEntityDataProvider): Integer;
var
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  I: Integer;
begin
  Result := 0;
  if AProvider = nil then
    Exit;

  if not TryGetActiveProject(Project) then
    Exit;

  AProvider.ModelUnits.BeginUpdate;
  try
    for I := 0 to Project.GetModuleCount - 1 do
    begin
      ModuleInfo := Project.GetModule(I);
      if ModuleInfo = nil then
        Continue;

      FileName := ModuleInfo.FileName;
      if not SameText(ExtractFileExt(FileName), '.pas') then
        Continue;

      if not FileExists(FileName) then
        Continue;

      if AProvider.ModelUnits.IndexOf(FileName) >= 0 then
        Continue;

      AProvider.ModelUnits.Add(FileName);
      Inc(Result);
    end;
  finally
    AProvider.ModelUnits.EndUpdate;
  end;
end;

procedure RefreshBoundDataSets(AProvider: TEntityDataProvider; ADesigner: IDesigner);
begin
  if (AProvider = nil) or (AProvider.Owner = nil) then
    Exit;

  for var I := 0 to AProvider.Owner.ComponentCount - 1 do
  begin
    var OwnedComponent := AProvider.Owner.Components[I];
    if (OwnedComponent is TEntityDataSet) and
       (TEntityDataSet(OwnedComponent).DataProvider = AProvider) and
       (TEntityDataSet(OwnedComponent).EntityClassName <> '') then
    begin
      TEntityDataSet(OwnedComponent).GenerateFields;
      if ADesigner <> nil then
        ADesigner.Modified;
    end;
  end;
end;

function ReadEditorContent(const AEditor: IOTASourceEditor): string;
const
  BufferSize = 1024;
var
  Reader: IOTAEditReader;
  Read: Integer;
  Position: Integer;
  Buffer: AnsiString;
begin
  Result := '';
  Reader := AEditor.CreateReader;
  Position := 0;

  repeat
    SetLength(Buffer, BufferSize);
    Read := Reader.GetText(Position, PAnsiChar(Buffer), BufferSize);
    SetLength(Buffer, Read);
    Result := Result + string(Buffer);
    Inc(Position, Read);
  until Read < BufferSize;
end;

function GetCurrentSourceEditor: IOTASourceEditor;
var
  Module: IOTAModule;
  ModuleServices: IOTAModuleServices;
  I: Integer;
begin
  Result := nil;
  ModuleServices := BorlandIDEServices as IOTAModuleServices;
  Module := ModuleServices.CurrentModule;
  if Module = nil then
    Exit;

  for I := 0 to Module.GetModuleFileCount - 1 do
    if Supports(Module.GetModuleFileEditor(I), IOTASourceEditor, Result) then
      Exit;
end;

procedure EnsureUnitInCurrentModuleUses(const AUnitName: string);
const
  RegexImplementation = '\bimplementation\b';
  RegexUsesSection = '\buses\b[\h\s\w[.,]*;';
var
  SourceEditor: IOTASourceEditor;
  Writer: IOTAEditWriter;
  Source: string;
  ImplementationMatch: TMatch;
  UsesMatches: TMatchCollection;
  UsesMatch: TMatch;
  HasUsesMatch: Boolean;
  InsertPosition: Integer;
  InsertText: string;
begin
  if AUnitName = '' then
    Exit;

  SourceEditor := GetCurrentSourceEditor;
  if SourceEditor = nil then
    Exit;

  Source := ReadEditorContent(SourceEditor);
  if TRegEx.IsMatch(Source, '\b' + AUnitName.Replace('.', '\.') + '\b', [roIgnoreCase, roMultiLine]) then
    Exit;

  ImplementationMatch := TRegEx.Match(Source, RegexImplementation, [roIgnoreCase, roMultiLine]);
  if not ImplementationMatch.Success then
    Exit;

  UsesMatches := TRegEx.Matches(Source, RegexUsesSection, [roIgnoreCase, roMultiLine]);
  HasUsesMatch := False;
  for var Match in UsesMatches do
  begin
    if Match.Index > ImplementationMatch.Index then
    begin
      UsesMatch := Match;
      HasUsesMatch := True;
      Break;
    end;
  end;

  if HasUsesMatch then
  begin
    InsertPosition := UsesMatch.Index + UsesMatch.Length - 1;
    InsertText := ', ' + AUnitName;
  end
  else
  begin
    InsertPosition := ImplementationMatch.Index + ImplementationMatch.Length;
    InsertText := sLineBreak + sLineBreak + 'uses' + sLineBreak + '  ' + AUnitName + ';';
  end;

  Writer := SourceEditor.CreateUndoableWriter;
  Writer.CopyTo(InsertPosition);
  Writer.Insert(PAnsiChar(AnsiString(InsertText)));
end;

{ TEntityDataProviderComponentProperty }

function TEntityDataProviderComponentProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList];
end;

procedure TEntityDataProviderComponentProperty.GetValues(Proc: TGetStrProc);
begin
  if (GetComponent(0) <> nil) and (GetComponent(0) is TComponent) and
     (TComponent(GetComponent(0)).Owner <> nil) then
  begin
    for var I := 0 to TComponent(GetComponent(0)).Owner.ComponentCount - 1 do
    begin
      var OwnedComponent := TComponent(GetComponent(0)).Owner.Components[I];
      if OwnedComponent is TEntityDataProvider then
        Proc(OwnedComponent.Name);
    end;
    Exit;
  end;

  for var I := 0 to Designer.Root.ComponentCount - 1 do
  begin
    var Component := Designer.Root.Components[I];
    if Component is TEntityDataProvider then
      Proc((Component as TComponent).Name);
  end;
end;

procedure TEntityDataProviderComponentProperty.SetValue(const Value: string);
begin
  inherited SetValue(Value);
end;

{ TEntityClassNameProperty }

function TEntityClassNameProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList];
end;

procedure TEntityClassNameProperty.GetValues(Proc: TGetStrProc);
var
  DataSet: TEntityDataSet;
  DP: IEntityDataProvider;
  Entities: TArray<string>;
  E: string;
begin
  DataSet := GetComponent(0) as TEntityDataSet;
  if Assigned(DataSet.DataProvider) then
  begin
    if DataSet.DataProvider.GetInterface(IEntityDataProvider, DP) then
    begin
      Entities := DP.GetEntities;
      for E in Entities do
        Proc(E);
    end;
  end;
end;

procedure TEntityClassNameProperty.SetValue(const Value: string);
var
  DataSet: TEntityDataSet;
  DP: IEntityDataProvider;
  EntityMD: TEntityClassMetadata;
begin
  inherited SetValue(Value);
  
  DataSet := GetComponent(0) as TEntityDataSet;
  if Assigned(DataSet.DataProvider) and DataSet.DataProvider.GetInterface(IEntityDataProvider, DP) then
  begin
    EntityMD := DP.GetEntityMetadata(Value);
    if EntityMD <> nil then
    begin
      EnsureUnitInCurrentModuleUses(DP.GetEntityUnitName(Value));
      DataSet.GenerateFields;
    end;
  end;
end;

{ TEntityDataProviderEditor }

procedure TEntityDataProviderEditor.ExecuteVerb(Index: Integer);
var
  Provider: TEntityDataProvider;
begin
  Provider := TEntityDataProvider(Component);

  case Index of
    0:
      begin
        PopulateProviderModelUnitsFromActiveProject(Provider);
        RefreshProviderMetadata(Provider);
        RefreshBoundDataSets(Provider, Designer);
        if Designer <> nil then
          Designer.Modified;
      end;
    1:
      begin
        RefreshProviderMetadata(Provider);
        RefreshBoundDataSets(Provider, Designer);
        if Designer <> nil then
          Designer.Modified;
      end;
  end;
end;

function TEntityDataProviderEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Scan Active Project + Refresh Metadata';
    1: Result := 'Refresh Entity Metadata';
  end;
end;

function TEntityDataProviderEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

{ TEntityDataSetSelectionEditor }

procedure TEntityDataSetSelectionEditor.ExecuteVerb(Index: Integer; const List: IDesignerSelections);
begin
  if (List.Count > 0) and (List[0] is TEntityDataSet) then
  begin
    case Index of
      0: TEntityDataSet(List[0]).BuildFieldDefs;
      1: ShowEntityPreview(TEntityDataSet(List[0]));
      2: TEntityDataSet(List[0]).Active := not TEntityDataSet(List[0]).Active;
    end;
  end;
end;

function TEntityDataSetSelectionEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Dext: Generate Fields (Auto)';
    1: Result := 'Dext: Preview Data...';
    2: Result := 'Dext: Toggle Design-Time Preview';
  end;
end;

function TEntityDataSetSelectionEditor.GetVerbCount: Integer;
begin
  Result := 3;
end;

procedure RegisterEditors;
begin
  RegisterComponents('Dext Entity', [TEntityDataProvider, TEntityDataSet]);
  RegisterPropertyEditor(TypeInfo(string), TEntityDataSet, 'EntityClassName', TEntityClassNameProperty);
  RegisterComponentEditor(TEntityDataProvider, TEntityDataProviderEditor);
  RegisterSelectionEditor(TEntityDataSet, TEntityDataSetSelectionEditor);
end;

end.
