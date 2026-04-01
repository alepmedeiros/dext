unit Dext.Entity.DataProvider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Data.DB,
  Dext.Collections,
  Dext.Collections.Dict,
  FireDAC.Comp.Client,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Mapping,
  Dext.Core.Reflection,
  Dext.Utils;

type
  TEntityDataProvider = class(TComponent, IEntityDataProvider)
  private
    FModelUnits: TStrings;
    FMetadataCache: IDictionary<string, TEntityClassMetadata>;
    FDatabaseConnection: TFDCustomConnection;
    FPreviewMaxRows: Integer;
    FDialect: TDatabaseDialect;
    FDebugMode: Boolean;
    FLastRefreshSummary: string;
    function BuildEntityMap(AClass: TClass): TEntityMap;
    function BuildColumnList(AClass: TClass; const AClassName: string): string;
    function GetEntityCount: Integer;
    function GetResolvedDialect: TDatabaseDialect;
    function GetDialectName: string;
    procedure SetDialect(const Value: TDatabaseDialect);
    procedure SetModelUnits(const Value: TStrings);
    procedure OnModelUnitsChange(Sender: TObject);
    procedure SetDatabaseConnection(const Value: TFDCustomConnection);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearMetadata;
    procedure AddOrSetMetadata(const AMetadata: TEntityClassMetadata);
    procedure UpdateRefreshSummary;
    procedure LogDebug(const AMsg: string);
    procedure RefreshMetadata;
    procedure RefreshUnit(const AFileName: string);
    function GetEntities: TArray<string>;
    function GetEntityMetadata(const AClassName: string): TEntityClassMetadata;
    function GetEntityUnitName(const AClassName: string): string;
    function ResolveEntityClass(const AClassName: string): TClass;
    function BuildPreviewSql(const AClassName: string; AMaxRows: Integer = 50): string;
    function CreatePreviewItems(const AClassName: string; AMaxRows: Integer = 50): IObjectList;
  published
    property DatabaseConnection: TFDCustomConnection read FDatabaseConnection write SetDatabaseConnection;
    property ModelUnits: TStrings read FModelUnits write SetModelUnits;
    property Dialect: TDatabaseDialect read FDialect write SetDialect default ddUnknown;
    property DialectName: string read GetDialectName;
    property PreviewMaxRows: Integer read FPreviewMaxRows write FPreviewMaxRows default 50;
    property DebugMode: Boolean read FDebugMode write FDebugMode default False;
    property EntityCount: Integer read GetEntityCount stored False;
    property LastRefreshSummary: string read FLastRefreshSummary stored False;
  end;

implementation

constructor TEntityDataProvider.Create(AOwner: TComponent);
begin
  inherited;
  FModelUnits := TStringList.Create;
  TStringList(FModelUnits).OnChange := OnModelUnitsChange;
  FMetadataCache := TCollections.CreateDictionary<string, TEntityClassMetadata>(True);
  FPreviewMaxRows := 50;
  FDialect := ddUnknown;
end;

destructor TEntityDataProvider.Destroy;
begin
  FMetadataCache := nil;
  FModelUnits.Free;
  inherited;
end;

function TEntityDataProvider.BuildEntityMap(AClass: TClass): TEntityMap;
begin
  Result := TEntityMap.Create(AClass.ClassInfo);
  Result.DiscoverAttributes;
end;

function TEntityDataProvider.BuildColumnList(AClass: TClass; const AClassName: string): string;
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
      for var Member in Metadata.Members do
        Columns.Add(Member.Name);
  end;

  if Columns.Count = 0 then
    Exit('*');

  Result := string.Join(', ', Columns.ToArray);
end;

function TEntityDataProvider.GetEntityCount: Integer;
begin
  Result := FMetadataCache.Count;
end;

function TEntityDataProvider.GetResolvedDialect: TDatabaseDialect;
begin
  if FDialect <> ddUnknown then
    Exit(FDialect);

  if FDatabaseConnection <> nil then
    Exit(TDialectFactory.DetectDialect(FDatabaseConnection.DriverName));

  Result := ddUnknown;
end;

function TEntityDataProvider.GetDialectName: string;
begin
  Result := GetEnumName(TypeInfo(TDatabaseDialect), Ord(GetResolvedDialect));
end;

procedure TEntityDataProvider.LogDebug(const AMsg: string);
begin
  if not FDebugMode then
    Exit;

  DebugLog('[Dext.EntityDataProvider] ' + AMsg);
end;

procedure TEntityDataProvider.SetDialect(const Value: TDatabaseDialect);
begin
  FDialect := Value;
end;

function TEntityDataProvider.GetEntities: TArray<string>;
var
  List: IList<string>;
  MD: TEntityClassMetadata;
begin
  List := TCollections.CreateList<string>;
  for MD in FMetadataCache.Values do
    List.Add(MD.ClassName);
  Result := List.ToArray;
end;

function TEntityDataProvider.GetEntityMetadata(const AClassName: string): TEntityClassMetadata;
begin
  if not FMetadataCache.TryGetValue(AClassName, Result) then
    Result := nil;
end;

function TEntityDataProvider.GetEntityUnitName(const AClassName: string): string;
var
  Metadata: TEntityClassMetadata;
begin
  Metadata := GetEntityMetadata(AClassName);
  if Metadata <> nil then
    Result := Metadata.UnitName
  else
    Result := '';
end;

function TEntityDataProvider.ResolveEntityClass(const AClassName: string): TClass;
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

function TEntityDataProvider.BuildPreviewSql(const AClassName: string; AMaxRows: Integer): string;
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

function TEntityDataProvider.CreatePreviewItems(const AClassName: string; AMaxRows: Integer): IObjectList;
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

  if FDatabaseConnection = nil then
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
      Query.Connection := FDatabaseConnection;
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

procedure TEntityDataProvider.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDatabaseConnection) then
    FDatabaseConnection := nil;
end;

procedure TEntityDataProvider.OnModelUnitsChange(Sender: TObject);
begin
end;

procedure TEntityDataProvider.ClearMetadata;
begin
  FMetadataCache.Clear;
end;

procedure TEntityDataProvider.AddOrSetMetadata(const AMetadata: TEntityClassMetadata);
begin
  if AMetadata = nil then
    Exit;

  FMetadataCache.AddOrSetValue(AMetadata.ClassName, AMetadata);
end;

procedure TEntityDataProvider.UpdateRefreshSummary;
begin
  FLastRefreshSummary := Format('%d entidade(s) encontradas em %d unit(s).',
    [FMetadataCache.Count, FModelUnits.Count]);
  LogDebug(FLastRefreshSummary);
end;

procedure TEntityDataProvider.RefreshMetadata;
begin
  ClearMetadata;
  UpdateRefreshSummary;
end;

procedure TEntityDataProvider.RefreshUnit(const AFileName: string);
begin
  LogDebug('RefreshUnit requested for ' + AFileName + ', aguardando servico de design time.');
end;

procedure TEntityDataProvider.SetDatabaseConnection(const Value: TFDCustomConnection);
begin
  if FDatabaseConnection <> Value then
  begin
    if FDatabaseConnection <> nil then
      FDatabaseConnection.RemoveFreeNotification(Self);

    FDatabaseConnection := Value;

    if FDatabaseConnection <> nil then
      FDatabaseConnection.FreeNotification(Self);
  end;
end;

procedure TEntityDataProvider.SetModelUnits(const Value: TStrings);
begin
  FModelUnits.Assign(Value);
end;

end.
