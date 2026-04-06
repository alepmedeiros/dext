unit Dext.EF.Design.Editors;

interface

uses
  System.SysUtils,
  System.Classes,
  System.RegularExpressions,
  System.IOUtils,
  DesignIntf,
  DesignEditors,
  ToolsAPI,
  VCLEditors,
  Data.DB,
  Dext.Collections,
  Dext.Collections.Base,
  Dext.Entity.DataSet,
  Dext.Entity.DataProvider,
  Dext.Entity.Core,
  Dext.Entity.Metadata,
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

function FindOwnerProject(ADesigner: IDesigner): IOTAProject;
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

function FindOwnerProject(ADesigner: IDesigner): IOTAProject;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  ProjectGroup: IOTAProjectGroup;
  Project: IOTAProject;
  CurrentFile: string;
  I, J, K: Integer;
begin
  Result := nil;
  if ADesigner = nil then
    Exit;

  ModuleServices := BorlandIDEServices as IOTAModuleServices;
  if ModuleServices = nil then
    Exit;

  Module := ModuleServices.CurrentModule;
  if Module = nil then
    Exit;

  CurrentFile := Module.FileName;

  // Find which project contains this file
  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    Module := ModuleServices.Modules[I];
    if (Module <> nil) and Supports(Module, IOTAProjectGroup, ProjectGroup) then
    begin
      for J := 0 to ProjectGroup.ProjectCount - 1 do
      begin
        Project := ProjectGroup.Projects[J];
        if Project = nil then
          Continue;

        for K := 0 to Project.GetModuleCount - 1 do
        begin
          if SameText(ChangeFileExt(Project.GetModule(K).FileName, ''), 
                      ChangeFileExt(CurrentFile, '')) then
          begin
            Result := Project;
            Exit;
          end;
        end;
      end;
    end;
  end;
end;

function PopulateProviderModelUnitsFromProject(AProvider: TEntityDataProvider; AProject: IOTAProject): Integer;
var
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  I: Integer;
begin
  Result := 0;
  if (AProvider = nil) or (AProject = nil) then
    Exit;

  AProvider.ModelUnits.BeginUpdate;
  try
    for I := 0 to AProject.GetModuleCount - 1 do
    begin
      ModuleInfo := AProject.GetModule(I);
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

function PopulateProviderModelUnitsFromActiveProject(AProvider: TEntityDataProvider; ADesigner: IDesigner = nil): Integer;
var
  Project: IOTAProject;
begin
  Result := 0;
  if AProvider = nil then
    Exit;

  // Try to find the project that owns the current form first
  if ADesigner <> nil then
    Project := FindOwnerProject(ADesigner);

  // Fallback to active project
  if Project = nil then
    TryGetActiveProject(Project);

  if Project = nil then
    Exit;

  Result := PopulateProviderModelUnitsFromProject(AProvider, Project);
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
  BufferSize = 1024 * 32;
var
  Reader: IOTAEditReader;
  Buffer: AnsiString;
  Read: Integer;
  Position: Integer;
begin
  Result := '';
  if (AEditor = nil) then Exit;
  Reader := AEditor.CreateReader;
  Position := 0;
  repeat
    SetLength(Buffer, BufferSize);
    Read := Reader.GetText(Position, PAnsiChar(Buffer), BufferSize);
    if Read > 0 then
    begin
      SetLength(Buffer, Read);
      Result := Result + UTF8ToString(Buffer);
    end;
    Inc(Position, Read);
  until Read < BufferSize;
end;

function GetModuleContent(const AFileName: string): string;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTAEditor;
  SourceEditor: IOTASourceEditor;
  I: Integer;
begin
  Result := '';
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then Exit;
  
  Module := ModuleServices.FindModule(AFileName);
  if Module = nil then Exit;
  
  for I := 0 to Module.GetModuleFileCount - 1 do
  begin
    Editor := Module.GetModuleFileEditor(I);
    if Supports(Editor, IOTASourceEditor, SourceEditor) then
    begin
      Result := ReadEditorContent(SourceEditor);
      if Result <> '' then Break;
    end;
  end;
end;

procedure DesignTimeRefreshUnit(AProvider: TEntityDataProvider; const AFileName: string);
var
  Parser: TEntityMetadataParser;
  ParsedList: IList<TEntityClassMetadata>;
  ParsedCollection: ICollection;
  MD: TEntityClassMetadata;
  Content: string;
begin
  if (AProvider = nil) or (AFileName = '') then
    Exit;

  Content := GetModuleContent(AFileName);

  Parser := TEntityMetadataParser.Create;
  try
    ParsedList := Parser.ParseUnit(AFileName, Content);
    try
      for MD in ParsedList do
      begin
        AProvider.AddOrSetMetadata(MD);
        AProvider.LogDebug(Format('RefreshUnitFromIDE: %s (%s) Table=%s Members=%d',
          [MD.EntityClassName, MD.EntityUnitName, MD.TableName, MD.Members.Count]));
      end;

      if Supports(ParsedList, ICollection, ParsedCollection) then
        ParsedCollection.OwnsObjects := False;
    finally
      ParsedList := nil;
    end;
  finally
    Parser.Free;
  end;

  AProvider.UpdateRefreshSummary;
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
    0: // Scan Active Project + Refresh Metadata
      begin
        PopulateProviderModelUnitsFromActiveProject(Provider, Designer);
        RefreshProviderMetadata(Provider);
        RefreshBoundDataSets(Provider, Designer);
        if Designer <> nil then
          Designer.Modified;
      end;
    1: // Refresh Entity Metadata
      begin
        RefreshProviderMetadata(Provider);
        RefreshBoundDataSets(Provider, Designer);
        if Designer <> nil then
          Designer.Modified;
      end;
    2: // Clear All Cached Metadata
      begin
        Provider.ClearMetadata;
        Provider.LastRefreshSummary := 'Cache cleared. Use "Scan Project" to reload.';
        if Designer <> nil then
          Designer.Modified;
      end;
    3: // Clear + Rescan Active Project
      begin
        Provider.ClearMetadata;
        Provider.ModelUnits.Clear;
        PopulateProviderModelUnitsFromActiveProject(Provider, Designer);
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
    0: Result := 'Dext: Scan Project + Refresh Metadata';
    1: Result := 'Dext: Refresh Entity Metadata';
    2: Result := 'Dext: Clear All Cached Metadata';
    3: Result := 'Dext: Clear + Rescan Active Project';
  end;
end;

function TEntityDataProviderEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

{ TEntityDataSetSelectionEditor }

procedure TEntityDataSetSelectionEditor.ExecuteVerb(Index: Integer; const List: IDesignerSelections);
var
  DataSet: TEntityDataSet;
  Provider: TEntityDataProvider;
begin
  if (List.Count = 0) or not (List[0] is TEntityDataSet) then
    Exit;

  DataSet := TEntityDataSet(List[0]);

  case Index of
    0: // Generate Fields (Auto)
      DataSet.GenerateFields;
    1: // Preview Data
      ShowEntityPreview(DataSet);
    2: // Toggle Design-Time Preview
      DataSet.Active := not DataSet.Active;
    3: // Refresh Entity (Scan + Rebuild Fields)
      begin
        Provider := DataSet.DataProvider;
        if Provider = nil then
          Exit;

        // Re-scan only the unit of this entity if possible
        var UnitName := Provider.GetEntityUnitName(DataSet.EntityClassName);
        if UnitName <> '' then
        begin
          // Find the full filename from ModelUnits
          for var I := 0 to Provider.ModelUnits.Count - 1 do
          begin
            if SameText(ChangeFileExt(ExtractFileName(Provider.ModelUnits[I]), ''), UnitName) then
            begin
              DesignTimeRefreshUnit(Provider, Provider.ModelUnits[I]);
              Break;
            end;
          end;
        end
        else
        begin
          // Full refresh as fallback
          PopulateProviderModelUnitsFromActiveProject(Provider, Designer);
          RefreshProviderMetadata(Provider);
        end;

        // Rebuild fields on this dataset
        DataSet.DisableControls;
        try
          if DataSet.Active then
            DataSet.Close;

          DataSet.GenerateFields(True, True); // RemoveOrphans=True, UpdateExisting=True
        finally
          DataSet.EnableControls;
        end;

        if Designer <> nil then
          Designer.Modified;
      end;
      4: // Dext: Sync Fields (Keep Customizations)
      begin
        Provider := DataSet.DataProvider;
        if Provider = nil then
          Exit;

        var UnitName := Provider.GetEntityUnitName(DataSet.EntityClassName);
        if UnitName <> '' then
        begin
          for var I := 0 to Provider.ModelUnits.Count - 1 do
          begin
            if SameText(ChangeFileExt(ExtractFileName(Provider.ModelUnits[I]), ''), UnitName) then
            begin
              DesignTimeRefreshUnit(Provider, Provider.ModelUnits[I]);
              Break;
            end;
          end;
        end
        else
        begin
          PopulateProviderModelUnitsFromActiveProject(Provider, Designer);
          RefreshProviderMetadata(Provider);
        end;

        DataSet.DisableControls;
        try
          if DataSet.Active then
            DataSet.Close;

          // Merge fields safely without overwriting user customizations
          DataSet.GenerateFields(True, False); // RemoveOrphans=True, UpdateExisting=False
        finally
          DataSet.EnableControls;
        end;

        if Designer <> nil then
          Designer.Modified;
      end;
  end;
end;

function TEntityDataSetSelectionEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Dext: Generate Fields (Auto)';
    1: Result := 'Dext: Preview Data...';
    2: Result := 'Dext: Toggle Design-Time Preview';
    3: Result := 'Dext: Refresh Entity (Scan + Rebuild Fields)';
    4: Result := 'Dext: Sync Fields (Keep Customizations)';
  end;
end;

function TEntityDataSetSelectionEditor.GetVerbCount: Integer;
begin
  Result := 5;
end;

procedure RegisterEditors;
begin
  RegisterComponents('Dext Entity', [TEntityDataProvider, TEntityDataSet]);
  RegisterPropertyEditor(TypeInfo(string), TEntityDataSet, 'EntityClassName', TEntityClassNameProperty);
  RegisterComponentEditor(TEntityDataProvider, TEntityDataProviderEditor);
  RegisterSelectionEditor(TEntityDataSet, TEntityDataSetSelectionEditor);
end;

initialization
  GOnGetSourceContent := GetModuleContent;
finalization
  GOnGetSourceContent := nil;
end.
