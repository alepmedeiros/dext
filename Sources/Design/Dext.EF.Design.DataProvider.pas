unit Dext.EF.Design.DataProvider;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Data.DB,
  ToolsAPI,
  Dext.Collections,
  Dext.Collections.Dict,
  FireDAC.Comp.Client,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Mapping,
  Dext.Core.Reflection,
  Dext.EF.Design.Metadata;

type
  TDesignEntityDataProvider = class(TComponent, IEntityDataProvider)
  private
    FModelUnits: TStrings;
    FMetadataCache: IDictionary<string, TEntityClassMetadata>;
    FConnection: TFDConnection;
    FPreviewMaxRows: Integer;
    FDialect: TDatabaseDialect;
    FDebugMode: Boolean;
    FLastRefreshSummary: string;
    function BuildEntityMap(AClass: TClass): TEntityMap;
    function BuildColumnList(AClass: TClass; const AClassName: string): string;
    function GetEntityCount: Integer;
    function GetResolvedDialect: TDatabaseDialect;
    function GetDialectName: string;
    procedure LogDebug(const AMsg: string);
    procedure SetDialect(const Value: TDatabaseDialect);
    procedure SetModelUnits(const Value: TStrings);
    procedure OnModelUnitsChange(Sender: TObject);
    procedure SetConnection(const Value: TFDConnection);
    function TryGetActiveProject(out AProject: IOTAProject): Boolean;
    function DiscoverModelUnitsFromProject: Integer;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AutoDiscoverModelUnits: Integer;
    procedure RefreshMetadata;
    procedure RefreshUnit(const AFileName: string);
    function GetEntities: TArray<string>;
    function GetEntityMetadata(const AClassName: string): TEntityClassMetadata;
    function GetEntityUnitName(const AClassName: string): string;
    function ResolveEntityClass(const AClassName: string): TClass;
    function BuildPreviewSql(const AClassName: string; AMaxRows: Integer = 50): string;
    function CreatePreviewItems(const AClassName: string; AMaxRows: Integer = 50): IObjectList;
  published
    property ModelUnits: TStrings read FModelUnits write SetModelUnits;
    property Connection: TFDConnection read FConnection write SetConnection;
    property FDConnection: TFDConnection read FConnection write SetConnection;
    property Dialect: TDatabaseDialect read FDialect write SetDialect default ddUnknown;
    property DialectName: string read GetDialectName;
    property PreviewMaxRows: Integer read FPreviewMaxRows write FPreviewMaxRows default 50;
    property DebugMode: Boolean read FDebugMode write FDebugMode default False;
    property EntityCount: Integer read GetEntityCount stored False;
    property LastRefreshSummary: string read FLastRefreshSummary stored False;
  end;

implementation

{ TDesignEntityDataProvider }

constructor TDesignEntityDataProvider.Create(AOwner: TComponent);
begin
  inherited;
  FModelUnits := TStringList.Create;
  TStringList(FModelUnits).OnChange := OnModelUnitsChange;
  FMetadataCache := TCollections.CreateDictionary<string, TEntityClassMetadata>(True);
  FPreviewMaxRows := 50;
  FDialect := ddUnknown;
end;

destructor TDesignEntityDataProvider.Destroy;
begin
  FMetadataCache := nil; { Interface ARC }
  FModelUnits.Free;
  inherited;
end;

function TDesignEntityDataProvider.BuildEntityMap(AClass: TClass): TEntityMap;
begin
  Result := TEntityMap.Create(AClass.ClassInfo);
  Result.DiscoverAttributes;
end;

function TDesignEntityDataProvider.GetResolvedDialect: TDatabaseDialect;
begin
  if FDialect <> ddUnknown then
    Exit(FDialect);

  if FConnection <> nil then
    Exit(TDialectFactory.DetectDialect(FConnection.DriverName));

  Result := ddUnknown;
end;

function TDesignEntityDataProvider.GetDialectName: string;
begin
  Result := GetEnumName(TypeInfo(TDatabaseDialect), Ord(GetResolvedDialect));
end;

procedure TDesignEntityDataProvider.SetDialect(const Value: TDatabaseDialect);
begin
  FDialect := Value;
end;

function TDesignEntityDataProvider.BuildColumnList(AClass: TClass; const AClassName: string): string;
var
  EntityMap: TEntityMap;
  Metadata: TEntityClassMetadata;
  Columns: IList<string>;
begin
  Columns := TCollections.CreateList<string>;

  if AClass <> nil then
  begin
    EntityMap := BuildEntityMap(AClass);
    try
      for var PropMap in EntityMap.Properties.Values do
      begin
        if PropMap.IsIgnored or PropMap.IsNavigation or PropMap.IsShadow then
          Continue;

        if PropMap.ColumnName <> '' then
          Columns.Add(PropMap.ColumnName)
        else
          Columns.Add(PropMap.PropertyName);
      end;
    finally
      EntityMap.Free;
    end;
  end
  else
  begin
    Metadata := GetEntityMetadata(AClassName);
    if Metadata <> nil then
    begin
      for var Member in Metadata.Members do
        Columns.Add(Member.Name);
    end;
  end;

  if Columns.Count = 0 then
    Exit('*');

  Result := string.Join(', ', Columns.ToArray);
end;

function TDesignEntityDataProvider.GetEntityCount: Integer;
begin
  Result := FMetadataCache.Count;
end;

function TDesignEntityDataProvider.GetEntities: TArray<string>;
var
  List: IList<string>;
  MD: TEntityClassMetadata;
begin
  List := TCollections.CreateList<string>;
  for MD in FMetadataCache.Values do
    List.Add(MD.ClassName);
  Result := List.ToArray;
end;

procedure TDesignEntityDataProvider.LogDebug(const AMsg: string);
begin
  if not FDebugMode then
    Exit;

  OutputDebugString(PChar('[Dext.EntityDataProvider] ' + AMsg));
end;

function TDesignEntityDataProvider.GetEntityMetadata(const AClassName: string): TEntityClassMetadata;
begin
  if not FMetadataCache.TryGetValue(AClassName, Result) then
    Result := nil;
end;

function TDesignEntityDataProvider.GetEntityUnitName(const AClassName: string): string;
var
  Metadata: TEntityClassMetadata;
begin
  Metadata := GetEntityMetadata(AClassName);
  if Metadata <> nil then
    Result := Metadata.UnitName
  else
    Result := '';
end;

function TDesignEntityDataProvider.ResolveEntityClass(const AClassName: string): TClass;
var
  Metadata: TEntityClassMetadata;
  RttiType: TRttiType;
begin
  Result := nil;
  if AClassName = '' then
    Exit;

  Metadata := GetEntityMetadata(AClassName);
  if Metadata <> nil then
  begin
    if Metadata.UnitName <> '' then
    begin
      RttiType := TReflection.Context.FindType(Metadata.UnitName + '.' + Metadata.ClassName);
      if RttiType is TRttiInstanceType then
        Exit(TRttiInstanceType(RttiType).MetaclassType);
    end;

    RttiType := TReflection.Context.FindType(Metadata.ClassName);
    if RttiType is TRttiInstanceType then
      Exit(TRttiInstanceType(RttiType).MetaclassType);
  end;

  Result := GetClass(AClassName);
end;

function TDesignEntityDataProvider.BuildPreviewSql(const AClassName: string; AMaxRows: Integer): string;
var
  Metadata: TEntityClassMetadata;
  EntityClass: TClass;
  Columns: string;
  BaseSql: string;
  DialectSvc: ISQLDialect;
begin
  Metadata := GetEntityMetadata(AClassName);
  if Metadata = nil then
    Exit('');

  if AMaxRows <= 0 then
    AMaxRows := FPreviewMaxRows;

  EntityClass := ResolveEntityClass(AClassName);
  Columns := BuildColumnList(EntityClass, AClassName);
  DialectSvc := TDialectFactory.CreateDialect(GetResolvedDialect);

  if DialectSvc <> nil then
    BaseSql := Format('SELECT %s FROM %s',
      [Columns, DialectSvc.QuoteIdentifier(Metadata.TableName)])
  else
    BaseSql := Format('SELECT %s FROM %s', [Columns, Metadata.TableName]);

  if DialectSvc <> nil then
    Result := DialectSvc.GeneratePaging(BaseSql, 0, AMaxRows)
  else
    Result := BaseSql;
end;

function TDesignEntityDataProvider.CreatePreviewItems(const AClassName: string; AMaxRows: Integer): IObjectList;
var
  EntityClass: TClass;
  EntityMap: TEntityMap;
  Query: TFDQuery;
  SqlText: string;
  ColumnMap: IDictionary<string, TPropertyMap>;
  Obj: TObject;
  PropMap: TPropertyMap;
  FieldValue: TValue;
begin
  Result := nil;

  if FConnection = nil then
    Exit;

  EntityClass := ResolveEntityClass(AClassName);
  if EntityClass = nil then
    Exit;

  SqlText := BuildPreviewSql(AClassName, AMaxRows);
  if SqlText = '' then
    Exit;

  EntityMap := BuildEntityMap(EntityClass);
  try
    ColumnMap := TCollections.CreateDictionaryIgnoreCase<string, TPropertyMap>;
    for var CurrentPropMap in EntityMap.Properties.Values do
    begin
      if CurrentPropMap.IsIgnored or CurrentPropMap.IsNavigation or CurrentPropMap.IsShadow then
        Continue;

      if CurrentPropMap.ColumnName <> '' then
        ColumnMap.AddOrSetValue(CurrentPropMap.ColumnName, CurrentPropMap);

      ColumnMap.AddOrSetValue(CurrentPropMap.PropertyName, CurrentPropMap);

      if CurrentPropMap.FieldName <> '' then
        ColumnMap.AddOrSetValue(CurrentPropMap.FieldName, CurrentPropMap);
    end;

    Result := TCollections.CreateObjectList<TObject>(True) as IObjectList;

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := SqlText;
      Query.Open;

      while not Query.Eof do
      begin
        Obj := TReflection.CreateInstance(EntityClass);
        if Obj <> nil then
        begin
          for var I := 0 to Query.Fields.Count - 1 do
          begin
            if not ColumnMap.TryGetValue(Query.Fields[I].FieldName, PropMap) then
              Continue;

            if PropMap.Prop = nil then
              PropMap.Prop := TReflection.Context.GetType(EntityClass.ClassInfo).GetProperty(PropMap.PropertyName);

            if PropMap.Prop = nil then
              Continue;

            if Query.Fields[I].IsNull then
              Continue;

            case Query.Fields[I].DataType of
              ftBlob, ftOraBlob:
                FieldValue := TValue.From<TBytes>(Query.Fields[I].AsBytes);
              ftMemo, ftWideMemo, ftOraClob:
                FieldValue := TValue.From<string>(Query.Fields[I].AsString);
            else
              FieldValue := TValue.FromVariant(Query.Fields[I].Value);
            end;
            TReflection.SetValue(Pointer(Obj), PropMap.Prop, FieldValue);
          end;

          Result.Add(Obj);
        end;

        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    EntityMap.Free;
  end;
end;

procedure TDesignEntityDataProvider.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FConnection) then
    FConnection := nil;
end;

procedure TDesignEntityDataProvider.OnModelUnitsChange(Sender: TObject);
begin
  if csDesigning in ComponentState then
    RefreshMetadata;
end;

function TDesignEntityDataProvider.TryGetActiveProject(out AProject: IOTAProject): Boolean;
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

function TDesignEntityDataProvider.DiscoverModelUnitsFromProject: Integer;
var
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  FileName: string;
  I: Integer;
begin
  Result := 0;

  if not TryGetActiveProject(Project) then
  begin
    LogDebug('No active project found for auto-discovery.');
    Exit;
  end;

  LogDebug('Discovering model units from active project: ' + Project.FileName);

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

    if FModelUnits.IndexOf(FileName) >= 0 then
      Continue;

    FModelUnits.Add(FileName);
    Inc(Result);
    LogDebug('Added unit to ModelUnits: ' + FileName);
  end;
end;

function TDesignEntityDataProvider.AutoDiscoverModelUnits: Integer;
begin
  Result := DiscoverModelUnitsFromProject;
  if Result > 0 then
    LogDebug(Format('Auto-discovery added %d unit(s).', [Result]))
  else
    LogDebug('Auto-discovery added no new units.');
end;

procedure TDesignEntityDataProvider.RefreshMetadata;
var
  FileName: string;
  AddedUnits: Integer;
begin
  if FModelUnits.Count = 0 then
  begin
    AddedUnits := AutoDiscoverModelUnits;
    LogDebug(Format('Refresh requested with empty ModelUnits. Auto-discovery result: %d unit(s).', [AddedUnits]));
  end;

  FMetadataCache.Clear;
  LogDebug(Format('Refreshing metadata from %d configured unit(s).', [FModelUnits.Count]));

  for FileName in FModelUnits do
    RefreshUnit(FileName);

  FLastRefreshSummary := Format('%d entidade(s) encontradas em %d unit(s).',
    [FMetadataCache.Count, FModelUnits.Count]);
  LogDebug(FLastRefreshSummary);
end;

procedure TDesignEntityDataProvider.RefreshUnit(const AFileName: string);
var
  Parser: TEntityMetadataParser;
  List: TList<TEntityClassMetadata>;
  MD: TEntityClassMetadata;
begin
  LogDebug('Parsing unit: ' + AFileName);
  Parser := TEntityMetadataParser.Create;
  try
    List := TList<TEntityClassMetadata>(Parser.ParseUnit(AFileName));
    try
      for MD in List do
      begin
        // Add or Overwrite in cache
        FMetadataCache.AddOrSetValue(MD.ClassName, MD);
        LogDebug(Format('Entity cached: %s (%s)', [MD.ClassName, MD.UnitName]));
      end;
      // Clear list to stop it from owning the items we just put in cache
      List.OwnsObjects := False; 
    finally
      List.Free;
    end;
  finally
    Parser.Free;
  end;
end;

procedure TDesignEntityDataProvider.SetConnection(const Value: TFDConnection);
begin
  if FConnection <> Value then
  begin
    FConnection := Value;
    if FConnection <> nil then
      FConnection.FreeNotification(Self);
  end;
end;

procedure TDesignEntityDataProvider.SetModelUnits(const Value: TStrings);
begin
  FModelUnits.Assign(Value);
end;

end.
