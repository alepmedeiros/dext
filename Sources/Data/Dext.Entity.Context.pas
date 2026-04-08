{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Context;

interface

uses
  System.SysUtils,
  Data.DB,
  System.TypInfo,
  System.Rtti,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Entity.Naming,
  Dext.Entity.Mapping,
  Dext.Entity.Core,
  Dext.Entity.DbSet,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Setup,
  Dext.Entity.Tenancy,
  Dext.MultiTenancy,
  Dext.Entity.Attributes,
  Dext.Entity.LazyLoading,
  Dext.Specifications.Interfaces,
  Dext,
  Dext.Entity.TypeSystem,
  Dext.Specifications.Fluent,
  Dext.Specifications.Types,
  Dext.Core.Reflection,
  Dext.Threading.Async;

type
  TFluentExpression = Dext.Specifications.Types.TFluentExpression;
  // TypeSystem
  TPropertyInfo = Dext.Entity.TypeSystem.TPropertyInfo;
  TDbContext = class;

  /// <summary>
  ///   Concrete implementation of DbContext.
  TEntityShadowState = class
  private
    FShadowValues: IDictionary<string, TValue>;
    FModifiedProperties: IDictionary<string, Boolean>;
  public
    constructor Create;
    destructor Destroy; override;
    property ShadowValues: IDictionary<string, TValue> read FShadowValues;
    property ModifiedProperties: IDictionary<string, Boolean> read FModifiedProperties;
  end;

  TChangeTracker = class(TInterfacedObject, IChangeTracker)
  private
    FTrackedEntities: IDictionary<TObject, TEntityState>;
    FShadowStates: IDictionary<TObject, TEntityShadowState>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Track(const AEntity: TObject; AState: TEntityState);
    procedure Remove(const AEntity: TObject);
    function GetState(const AEntity: TObject): TEntityState;
    function HasChanges: Boolean;
    procedure AcceptAllChanges;
    procedure Clear;
    function GetTrackedEntities: IDictionary<TObject, TEntityState>;
    
    // Shadow Property Methods
    function GetShadowState(const AEntity: TObject): TEntityShadowState;
  end;

  TPropertyEntry = class(TInterfacedObject, IPropertyEntry)
  private
    FContext: TDbContext;
    FEntity: TObject;
    FPropName: string;
    FIsShadow: Boolean;
  public
    constructor Create(const AContext: TDbContext; const AEntity: TObject; const APropName: string);
    function GetCurrentValue: TValue;
    procedure SetCurrentValue(const AValue: TValue);
    function GetIsModified: Boolean;
    procedure SetIsModified(const AValue: Boolean);
  end;

  TCollectionEntry = class(TInterfacedObject, ICollectionEntry)
  private
    FContext: TDbContext;
    FParent: TObject;
    FPropName: string;
  public
    constructor Create(const AContext: TDbContext; const AParent: TObject; const APropName: string);
    procedure Load;
  end;

  TReferenceEntry = class(TInterfacedObject, IReferenceEntry)
  private
    FContext: TDbContext;
    FParent: TObject;
    FPropName: string;
  public
    constructor Create(const AContext: TDbContext; const AParent: TObject; const APropName: string);
    procedure Load;
  end;

  TEntityEntry = class(TInterfacedObject, IEntityEntry)
  private
    FContext: TDbContext;
    FEntity: TObject;
  public
    constructor Create(const AContext: TDbContext; const AEntity: TObject);
    function Collection(const APropName: string): ICollectionEntry;
    function Reference(const APropName: string): IReferenceEntry;
    function Member(const APropName: string): IPropertyEntry;
  end;



  /// <summary>
  ///   Concrete implementation of DbContext.
  ///   Manages database connection, transactions, and entity sets.
  ///   
  ///   Note: This class implements IDbContext but disables reference counting.
  ///   You must manage its lifecycle manually (Free).
  /// </summary>
  /// <summary>
  ///   Concrete implementation of DbContext.
  ///   Manages database connection, transactions, and entity sets.
  ///   
  ///   Note: This class implements IDbContext but disables reference counting.
  ///   You must manage its lifecycle manually (Free).
  /// </summary>
  TDbContext = class(TObject, IDbContext)
  private
    FConnection: IDbConnection;
    FDialect: ISQLDialect;
    FNamingStrategy: INamingStrategy;
    FModelBuilder: TModelBuilder; // Model Builder
    FOwnsModelBuilder: Boolean;
    FTransaction: IDbTransaction;
    FCache: IDictionary<PTypeInfo, IInterface>; // Cache for DbSets
    FChangeTracker: IChangeTracker;
    FTenantProvider: ITenantProvider;
    FTenantConfigApplied: Boolean;
    FLastAppliedTenantId: string;
    FOnLog: TProc<string>;
    FProxies: IList<TObject>;
    procedure SetOnLog(const AValue: TProc<string>);
    function GetOnLog: TProc<string>;
    procedure ApplyTenantConfig(ACreateSchema: Boolean = False);
    function GetModelBuilder: TModelBuilder;
  protected
    // IDbContext Implementation
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    
    /// <summary>
    ///   Override this method to configure the model (Fluent Mapping).
    /// </summary>
    procedure OnModelCreating(Builder: TModelBuilder); virtual;
    
    /// <summary>
    ///   Override this method to configure the database context (e.g. Connection String, Naming Strategy).
    ///   This is called during constructor execution.
    /// </summary>
    procedure OnConfiguring(Options: TDbContextOptions); virtual;
    function CreateDynamicDbSet(AEntityType: PTypeInfo): IDbSet; virtual;
    
  public
    class var FModelCache: IDictionary<TClass, TModelBuilder>;
    class var FCriticalSection: TObject; // For thread safety
    
    constructor Create(const AConnection: IDbConnection; const ADialect: ISQLDialect = nil; const ANamingStrategy: INamingStrategy = nil; const ATenantProvider: ITenantProvider = nil); overload;
    constructor Create(const AOptions: TDbContextOptions; const ATenantProvider: ITenantProvider = nil); overload;
    destructor Destroy; override;
    
    class constructor Create;
    class destructor Destroy;
    
    function Connection: IDbConnection;
    function Dialect: ISQLDialect;
    function NamingStrategy: INamingStrategy;
    function ModelBuilder: TModelBuilder; // Expose ModelBuilder
    function GetTenantProvider: ITenantProvider;
    
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
    
    /// <summary>
    ///   Access the DbSet for a specific entity type.
    /// </summary>
    function DataSet(AEntityType: PTypeInfo): IDbSet;

    /// <summary>
    /// Preload the DBSets cache to avoid having to manually call Entities<T> for
    ///  each type which are already exposed as properties on the current TDBContext
    ///  implementation.
    /// </summary>
    procedure PreloadDbSets;
    function EnsureCreated: Boolean;
    procedure ExecuteSchemaSetup;
    
    function SaveChanges: Integer;
    function SaveChangesAsync: TAsyncBuilder<Integer>;
    procedure Clear;
    procedure DetachAll;
    procedure Detach(const AEntity: TObject);
    procedure ExecuteProcedure(const ADto: TObject);
    function ChangeTracker: IChangeTracker;
    
    function GetMapping(AType: PTypeInfo): TObject;
    
    /// <summary>
    ///   Access the DbSet for a specific entity type.
    /// </summary>
    function Entities<T: class>: IDbSet<T>;
    
    function Entry(const AEntity: TObject): IEntityEntry;
    procedure TrackProxy(const AProxy: TObject);
    
    property OnLog: TProc<string> read GetOnLog write SetOnLog;
  end;

implementation

uses
  Dext.Utils,
  Dext.Validation,
  Dext.Entity.Validator;

{ Helper Functions }

/// <summary>
///   Unwraps Nullable<T> values and validates if FK is valid (non-zero for integers, non-empty for strings)
/// </summary>
function TryUnwrapAndValidateFK(var AValue: TValue; AContext: TRttiContext): Boolean;
var
  RType: TRttiType;
  TypeName: string;
  Fields: TArray<TRttiField>;
  HasValueField, ValueField: TRttiField;
  HasValue: Boolean;
  Instance: Pointer;
begin
  Result := False;
  
  // Handle Nullable<T> unwrapping
  if AValue.Kind = tkRecord then
  begin
    RType := AContext.GetType(AValue.TypeInfo);
    if RType <> nil then
    begin
      TypeName := RType.Name;
      
      // Check if it's a Nullable<T> by name (Delphi doesn't generate RTTI for generic record properties)
      if TypeName.StartsWith('Nullable<') or TypeName.StartsWith('TNullable') then
      begin
        // Access fields directly since GetProperty won't work for generic records
        Fields := RType.GetFields;
        HasValueField := nil;
        ValueField := nil;
        
        // Find fHasValue and fValue fields
        for var Field in Fields do
        begin
          if Field.Name.ToLower.Contains('hasvalue') then
            HasValueField := Field
          else if Field.Name.ToLower = 'fvalue' then
            ValueField := Field;
        end;
        
        if (HasValueField <> nil) and (ValueField <> nil) then
        begin
          Instance := AValue.GetReferenceToRawData;
          
          // Check HasValue - it can be a string (Spring4D) or Boolean
          var HasValueVal := HasValueField.GetValue(Instance);
          if HasValueVal.Kind = tkUString then
            HasValue := HasValueVal.AsString <> ''
          else if HasValueVal.Kind = tkEnumeration then
            HasValue := HasValueVal.AsBoolean
          else
            HasValue := False;
            
          if not HasValue then Exit; // Null, nothing to load
          
          // Get the actual value
          AValue := ValueField.GetValue(Instance);
        end
        else
          Exit; // Couldn't find fields, treat as invalid
      end;
    end;
  end;

  if AValue.IsEmpty then Exit;

  // Validate based on type
  if AValue.Kind in [tkInteger, tkInt64] then
    Result := AValue.AsInt64 <> 0
  else if AValue.Kind in [tkString, tkUString, tkWString, tkLString] then
    Result := AValue.AsString <> ''
  else
    Result := True; // For other types like GUID, assume valid if not empty
end;


{ TDbContext }

type
  TEntityNode = class
  public
    TypeInfo: PTypeInfo;
    DbSet: IDbSet;
    Dependencies: IList<PTypeInfo>;
    constructor Create;
    destructor Destroy; override;
  end;

const
  // Key for caching based on class type
  CACHE_KEY = 'Model';

class constructor TDbContext.Create;
begin
  FModelCache := TCollections.CreateDictionary<TClass, TModelBuilder>(True);
  FCriticalSection := TObject.Create;
end;
 
 class destructor TDbContext.Destroy;
 begin
   FModelCache := nil;
   FreeAndNil(FCriticalSection);
 end;

constructor TDbContext.Create(const AConnection: IDbConnection; const ADialect: ISQLDialect; const ANamingStrategy: INamingStrategy; const ATenantProvider: ITenantProvider);
begin
  inherited Create;
  FConnection := AConnection;
  
  if ADialect <> nil then
    FDialect := ADialect
  else if (FConnection <> nil) and (FConnection.Dialect <> ddUnknown) then
    FDialect := TDialectFactory.CreateDialect(FConnection.Dialect)
  else
    FDialect := nil; // Will likely cause issues if query generation is attempted without dialect

  if FDialect = nil then
  begin
     // Optional: Raise warning or default to generic?
     // We leave it nil, it might be set later or cause runtime error if used.
  end;
  
  if ANamingStrategy <> nil then
    FNamingStrategy := ANamingStrategy
  else
    FNamingStrategy := TDefaultNamingStrategy.Create; // Default
    
  FCache := TCollections.CreateDictionary<PTypeInfo, IInterface>;
  FChangeTracker := TChangeTracker.Create;
  FTenantProvider := ATenantProvider;
  FTenantConfigApplied := False;
  FProxies := TCollections.CreateList<TObject>(True);
  
  // Model Caching Logic
  System.TMonitor.Enter(FCriticalSection);
  try
    if not FModelCache.TryGetValue(Self.ClassType, FModelBuilder) then
    begin
      FModelBuilder := TModelBuilder.Create;
      // Initialize Model
      OnModelCreating(FModelBuilder);
      
      FModelCache.Add(Self.ClassType, FModelBuilder);
    end;
    // We reuse the cached builder. Do NOT own it.
    FOwnsModelBuilder := False;
  finally
    System.TMonitor.Exit(FCriticalSection);
  end;

  PreloadDbSets;
end;

constructor TDbContext.Create(const AOptions: TDbContextOptions;
  const ATenantProvider: ITenantProvider);
begin
  // Allow derived classes to configure options (e.g. Naming Strategy)
  OnConfiguring(AOptions);
  
  Self.Create(AOptions.BuildConnection, AOptions.BuildDialect, AOptions.BuildNamingStrategy, ATenantProvider);
end;

procedure TDbContext.OnConfiguring(Options: TDbContextOptions);
begin
  // Virtual method implies do nothing by default
end;

destructor TDbContext.Destroy;
begin
  // Clear ChangeTracker before freeing DbSets (which free entities).
  // This prevents ChangeTracker from holding dangling pointers during its destruction.
  if FChangeTracker <> nil then
    FChangeTracker.Clear;
    
  if FConnection <> nil then
    FConnection.Disconnect;
    
  // 1. Clear Proxies first. This restores original VMTs while entity instances
  // are still held by IdentityMaps in DbSets.
  FProxies := nil; 
  
  // 2. Clear DbSets second. This will call Free on entity instances.
  // Since proxies were unproxified in step 1, they will destroy as normal objects.
  FCache := nil;   
  
  if FOwnsModelBuilder then
    FModelBuilder.Free;
  inherited;
end;

procedure TDbContext.SetOnLog(const AValue: TProc<string>);
begin
  FOnLog := AValue;
  if FConnection <> nil then
    FConnection.OnLog := AValue;
end;

function TDbContext.GetOnLog: TProc<string>;
begin
  Result := FOnLog;
end;

function TDbContext.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TDbContext._AddRef: Integer;
begin
  Result := -1; // Disable ref counting
end;

function TDbContext._Release: Integer;
begin
  Result := -1; // Disable ref counting
end;

function TDbContext.Connection: IDbConnection;
begin
  Result := FConnection;
end;

function TDbContext.Dialect: ISQLDialect;
begin
  Result := FDialect;
end;

function TDbContext.NamingStrategy: INamingStrategy;
begin
  Result := FNamingStrategy;
end;

function TDbContext.GetModelBuilder: TModelBuilder;
begin
  Result := FModelBuilder;
end;

function TDbContext.ModelBuilder: TModelBuilder;
begin
  Result := FModelBuilder;
end;

function TDbContext.GetTenantProvider: ITenantProvider;
begin
  Result := FTenantProvider;
end;

procedure TDbContext.OnModelCreating(Builder: TModelBuilder);
begin
  // Default implementation does nothing.
  // Override this in your derived context to configure mappings.
end;

procedure TDbContext.TrackProxy(const AProxy: TObject);
begin
  if AProxy <> nil then
    FProxies.Add(AProxy);
end;

procedure TDbContext.PreloadDbSets;
var
  ctx : TRttiContext;
  typ : TRttiType;
  props :  TArray<TRttiProperty>;
  Prop : TRttiProperty;
begin
   Ctx := TRttiContext.Create;
   try
     Typ := Ctx.GetType(self.classtype);
     Props := Typ.GetProperties;
     for Prop in Props do
     begin
       // ignore any properties that are [NotMapped].
       if Prop.HasAttribute<NotMappedAttribute> then
         continue;

       // assume that properties that hold an interface are likely models (IDbSet<T>)
       if Prop.IsReadable and (Prop.PropertyType.TypeKind = tkInterface) then
       begin
         // Capture the property name for naming discovery (e.g. "Customers" -> "customers")
         // We need to find the generic type T from IDbSet<T>
         var IntfType := Prop.PropertyType;
         if IntfType.Name.StartsWith('IDbSet<') then
         begin
            // This is a simple heuristic. Better: check GUID or use RTTI to find the entity type.
            // But usually, the property name is exactly what we want as a table name placeholder.
            
            // Try to extract T from IDbSet<T> RTTI if possible, 
            // but even simpler: when the getter is called by Prop.GetValue(Self), 
            // Entities<T> is called, which registers the type. 
            // We just need to associate this specific property name with the type T.
            
             var Val := Prop.GetValue(Self);
             try
               var DbSet: IDbSet;
               if (not Val.IsEmpty) and Supports(Val.AsInterface, IDbSet, DbSet) then
               begin
                 // Register this property name as the "Discovery Name" for this entity type
                 TModelBuilder.Instance.RegisterDiscoveryName(DbSet.EntityType, Prop.Name);
               end;
             finally
               Val := TValue.Empty;
             end;
          end;
        end;
      end;
   finally
      Ctx.free;
   end;
end;

function TDbContext.GetMapping(AType: PTypeInfo): TObject;
begin
  Result := FModelBuilder.GetMap(AType);
end;

procedure TDbContext.ApplyTenantConfig(ACreateSchema: Boolean);
var
  Sql: string;
  CurrentTenantId: string;
begin
  CurrentTenantId := '';
  if (FTenantProvider <> nil) and (FTenantProvider.Tenant <> nil) then
    CurrentTenantId := FTenantProvider.Tenant.Id;

  if (FLastAppliedTenantId = CurrentTenantId) and FTenantConfigApplied and (not ACreateSchema) then Exit;
  
  if (FTenantProvider <> nil) and (FTenantProvider.Tenant <> nil) then
  begin
    // 1. Handle Schema-based tenancy
    if FTenantProvider.Tenant.Schema <> '' then
    begin
      if ACreateSchema then
      begin
        // Sql := FDialect.GetCreateSchemaSQL(FTenantProvider.Tenant.Schema);
        Sql := '';
        if Sql <> '' then
        begin
          var Cmd := FConnection.CreateCommand(Sql);
          Cmd.ExecuteNonQuery;
        end;
      end;

      // Sql := FDialect.GetSetSchemaSQL(FTenantProvider.Tenant.Schema);
      Sql := '';
      if Sql <> '' then
      begin
        var Cmd := FConnection.CreateCommand(Sql);
        Cmd.ExecuteNonQuery;
      end;
    end;

    // 2. Handle Connection-based tenancy (Tenant per Database)
    if FTenantProvider.Tenant.ConnectionString <> '' then
    begin
      if FConnection.ConnectionString <> FTenantProvider.Tenant.ConnectionString then
      begin
        FConnection.ConnectionString := FTenantProvider.Tenant.ConnectionString;
        // If we are already connected, we need to reconnect with the new string
        if FConnection.IsConnected then
        begin
          FConnection.Disconnect;
          FConnection.Connect;
        end;
      end;
    end;
  end;
  
  FLastAppliedTenantId := CurrentTenantId;
  FTenantConfigApplied := True;
end;

procedure TDbContext.ExecuteSchemaSetup;
begin
  ApplyTenantConfig(False);
end;

procedure TDbContext.BeginTransaction;
begin
  ApplyTenantConfig(False);
  FTransaction := FConnection.BeginTransaction;
end;

procedure TDbContext.Commit;
begin
  if FTransaction <> nil then
  begin
    FTransaction.Commit;
    FTransaction := nil;
  end;
end;

procedure TDbContext.Rollback;
begin
  if FTransaction <> nil then
  begin
    FTransaction.Rollback;
    FTransaction := nil;
  end;
end;

function TDbContext.InTransaction: Boolean;
begin
  Result := FTransaction <> nil;
end;

function TDbContext.DataSet(AEntityType: PTypeInfo): IDbSet;
begin
  ApplyTenantConfig;
  if FCache.ContainsKey(AEntityType) then
    Exit(FCache[AEntityType] as IDbSet);

  // Create the DbSet instance dynamically for this type.
  // This is required when we discover types from ModelBuilder (fluent) 
  // that haven't been accessed via generic Entities<T> properties yet.
  Result := CreateDynamicDbSet(AEntityType);
  if Result <> nil then
    FCache.Add(AEntityType, Result);
end;

function TDbContext.CreateDynamicDbSet(AEntityType: PTypeInfo): IDbSet;
var
  Factory: IDynamicDbSetFactory;
begin
  Factory := ModelBuilder.GetFactory(AEntityType);
  if Factory <> nil then
    Exit(Factory.CreateDbSet(IDbContext(Self)) as IDbSet);

  raise Exception.CreateFmt('Could not create DbSet for type %s. Please ensure TDbSet<%s> is instantiated somewhere or call Entities<%s> to register it.', [AEntityType.Name, AEntityType.Name, AEntityType.Name]);
end;

function TDbContext.Entities<T>: IDbSet<T>;
var
  TypeInfo: PTypeInfo;
  NewSet: IDbSet<T>;
begin
  TypeInfo := System.TypeInfo(T);
  
  if not FCache.ContainsKey(TypeInfo) then
  begin
    // Create the DbSet instance.
    NewSet := TDbSet<T>.Create(IDbContext(Self));
    FCache.Add(TypeInfo, NewSet);
  end;
  
  Result := IDbSet<T>(FCache[TypeInfo]);
end;

function TDbContext.EnsureCreated: Boolean;
var
  Nodes: IList<TEntityNode>;
  Created: IList<PTypeInfo>;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Node: TEntityNode;
  Pair: TPair<PTypeInfo, IInterface>;
  DbSet: IDbSet;
  SQL: string;
  Cmd: IDbCommand;
  CmdIntf: IInterface;
  HasProgress, CanCreate: Boolean;
  i: Integer;
begin
  Result := False;
  ApplyTenantConfig(True);
  Nodes := TCollections.CreateList<TEntityNode>(True);
  Created := TCollections.CreateList<PTypeInfo>;
  if FCache.Count = 0 then
    PreloadDBSets;
    
  // Ensure all entities registered in the ModelBuilder (via Fluent API or attributes) 
  // are also present in the cache for schema creation.
  for var Map in ModelBuilder.GetMaps do
    DataSet(Map.EntityType);
  Ctx := TRttiContext.Create;
  try
    // 1. Build Dependency Graph
    for Pair in FCache do
    begin
      if not Supports(Pair.Value, IDbSet, DbSet) then Continue;
      
      Node := TEntityNode.Create;
      Node.TypeInfo := Pair.Key;
      Node.DbSet := DbSet;
      Nodes.Add(Node);
      
      // Analyze Dependencies
      Typ := Ctx.GetType(Pair.Key);
      if Typ = nil then Continue;
      
      for Prop in Typ.GetProperties do
      begin
        for Attr in Prop.GetAttributes do
        begin
          if Attr is ForeignKeyAttribute then
          begin
            // Found a FK. Check if the property type is a class we manage.
            if Prop.PropertyType.TypeKind = tkClass then
            begin
               var DepType := Prop.PropertyType.Handle;
               // Only add dependency if it's in our Cache (managed entity)
               if FCache.ContainsKey(DepType) and (DepType <> Pair.Key) then // Avoid self-dependency
               begin
                 if not Node.Dependencies.Contains(DepType) then
                   Node.Dependencies.Add(DepType);
               end;
            end;
          end;
        end;
      end;
    end;
    
    // 2. Topological Sort / Execution
    while Nodes.Count > 0 do
    begin
      HasProgress := False;
      
      for i := Nodes.Count - 1 downto 0 do
      begin
        Node := Nodes[i];
        CanCreate := True;
        
        // Check if all dependencies are created
        for var Dep in Node.Dependencies do
        begin
          if not Created.Contains(Dep) then
          begin
            CanCreate := False;
            Break;
          end;
        end;
        
        if CanCreate then
        begin
          // Execute Creation
          SQL := Node.DbSet.GenerateCreateTableScript;
          if SQL <> '' then
          begin
            // Check if table exists first (to support databases without IF NOT EXISTS like Firebird)
            // Note: GenerateCreateTableScript returns "CREATE TABLE Name ...". We need to extract the name.
            // But we already have the name in the Node/DbSet metadata.
            // Actually, we can just use FConnection.TableExists(TableName)
            
            var TableName := '';
            var Mapping := GetMapping(Node.TypeInfo);
            var MapTableName := '';
            
            if Mapping <> nil then
              MapTableName := Dext.Entity.Mapping.TEntityMap(Mapping).TableName;
              
            if MapTableName <> '' then
            begin
              TableName := MapTableName;
            end
            else
            begin
              // Fallback to Attribute or Naming Strategy if Mapping doesn't specify TableName
              var RContext := TRttiContext.Create;
              try
                var RType := RContext.GetType(Node.TypeInfo);
                if RType <> nil then
                begin
                  var TableAttr := RType.GetAttribute<TableAttribute>;
                  if TableAttr <> nil then
                    TableName := TableAttr.Name;
                end;
              finally
                RContext.Free;
              end;
              
              if TableName = '' then
                TableName := FNamingStrategy.GetTableName(Node.TypeInfo.TypeData.ClassType);
            end;
            
            // Quote identifier if needed (Dialect specific)
            // But TableExists expects the name as is (or handles quotes internally)
            // Let's pass the raw name first.
            
            if not FConnection.TableExists(TableName) then
            begin
              if Assigned(FOnLog) then
                FOnLog(SQL);

              try
                CmdIntf := FConnection.CreateCommand(SQL);
                Cmd := IDbCommand(CmdIntf);
                Cmd.ExecuteNonQuery;
                Result := True;
              except
                 on E: Exception do
                 begin
                   if Assigned(FOnLog) then
                     FOnLog('FAILED SQL: ' + SQL);
                   raise; // Propagate the error so the developer knows why it failed
                 end;
              end;
            end;
          end;
          
          Created.Add(Node.TypeInfo);
          Nodes.Delete(i); // Remove from pending
          HasProgress := True;
        end;
      end;
      
      if not HasProgress then
      begin
        // Cycle detected or missing dependency.
        // For now, force create the remaining ones (might fail on FKs, but better than hanging)

        for i := Nodes.Count - 1 downto 0 do
        begin
           Node := Nodes[i];
           SQL := Node.DbSet.GenerateCreateTableScript;
            if SQL <> '' then
            begin
              try
                CmdIntf := FConnection.CreateCommand(SQL);
                Cmd := IDbCommand(CmdIntf);
                Cmd.ExecuteNonQuery;
              except
                 on E: Exception do; // Ignore errors in forced creation
              end;
            end;
           Nodes.Delete(i);
        end;
        Break;
      end;
    end;
    
  finally
    Created := nil;
    Nodes := nil;
    Ctx.Free;
  end;
end;

{ TEntityNode }

{ TEntityNode }

constructor TEntityNode.Create;
begin
  Dependencies := TCollections.CreateList<PTypeInfo>;
end;

destructor TEntityNode.Destroy;
begin
  Dependencies := nil;
  inherited;
end;

function TDbContext.SaveChanges: Integer;
var
  Pair: TPair<TObject, TEntityState>;
  Entity: TObject;
  DbSet: IDbSet;
begin
  ApplyTenantConfig(False);
  Result := 0;
  if not FChangeTracker.HasChanges then Exit;
 
   if not InTransaction then BeginTransaction;
   try
     // 1. Process Inserts (Bulk Optimized)
     var AddedGroups := TCollections.CreateDictionary<PTypeInfo, IList<TObject>>;
     try
       for Pair in FChangeTracker.GetTrackedEntities do
       begin
         if Pair.Value = esAdded then
         begin
           Entity := Pair.Key;
           if not AddedGroups.ContainsKey(Entity.ClassInfo) then
             AddedGroups.Add(Entity.ClassInfo, TCollections.CreateList<TObject>);
           
            // Auto-populate TenantId if applicable (Security & Convenience)
            if (FTenantProvider <> nil) and (FTenantProvider.Tenant <> nil) then
            begin
              var TenantAware: ITenantAware;
              if Supports(Entity, ITenantAware, TenantAware) then
              begin
                 // Always enforce current tenant ID on insert
                 TenantAware.TenantId := FTenantProvider.Tenant.Id;
              end;
            end;
              
 
            // Validate Entity
            var Map: TEntityMap := nil;
            if FModelBuilder <> nil then
              Map := FModelBuilder.GetMap(Entity.ClassInfo);
              
            TEntityValidator.Validate(Entity, Map);
 
            AddedGroups[Entity.ClassInfo].Add(Entity);
         end;
       end;
 
       for var APair in AddedGroups do
       begin
         var List := APair.Value;
         DbSet := DataSet(APair.Key);
         
         // Force loop to ensure IDs are retrieved for all entities.
         // Bulk Insert (PersistAddRange) does not currently support ID retrieval.
         for var Item in List do
           DbSet.PersistAdd(Item);
           
         Inc(Result, List.Count);
       end;
      finally
        AddedGroups := nil;
      end;
     
     // 2. Process Updates
     for Pair in FChangeTracker.GetTrackedEntities do
     begin
       if Pair.Value = esModified then
       begin
         Entity := Pair.Key;
         
         // Validate Entity
         var Map: TEntityMap := nil;
         if FModelBuilder <> nil then
           Map := FModelBuilder.GetMap(Entity.ClassInfo);
           
         TEntityValidator.Validate(Entity, Map);
 
         DbSet := DataSet(Entity.ClassInfo);
         DbSet.PersistUpdate(Entity);
         Inc(Result);
       end;
     end;
     
     // 3. Process Deletes
     // Note: We need a snapshot for deletes because PersistRemove calls Remove from tracker
     var Deletes := TCollections.CreateList<TObject>;
     try
       for Pair in FChangeTracker.GetTrackedEntities do
         if Pair.Value = esDeleted then
           Deletes.Add(Pair.Key);
           
       for Entity in Deletes do
       begin
         DbSet := DataSet(Entity.ClassInfo);
         
         // Remove from tracker BEFORE freeing the entity (via PersistRemove -> IdentityMap)
         // This prevents dangling pointers in the tracker.
         FChangeTracker.Remove(Entity);
         
         DbSet.PersistRemove(Entity);
         Inc(Result);
       end;
     finally
       Deletes := nil;
     end;
     
     Commit;
     FChangeTracker.AcceptAllChanges;
   except
     Rollback;
     raise;
   end;
end;

function TDbContext.SaveChangesAsync: TAsyncBuilder<Integer>;
begin
  if (FConnection <> nil) and not FConnection.Pooled then
    raise Exception.Create('SaveChangesAsync requires a pooled connection to ensure thread safety.');

  Result := TAsyncTask.Run<Integer>(
    TFunc<Integer>(
      function: Integer
      begin
        Result := SaveChanges;
      end
    )
  );
end;

procedure TDbContext.Clear;
var
  SetIntf: IInterface;
  DbSet: IDbSet;
begin
  // Clear Change Tracker
  FChangeTracker.Clear;
  
  // Clear Identity Map of all cached DbSets
  for SetIntf in FCache.Values do
  begin
    if Supports(SetIntf, IDbSet, DbSet) then
    begin
      DbSet.Clear;
    end;
  end;
end;

procedure TDbContext.DetachAll;
var
  SetIntf: IInterface;
  DbSet: IDbSet;
begin
  // Clear Change Tracker (Stop tracking everything)
  FChangeTracker.Clear;
  
  // Detach all entities in all DbSets
  for SetIntf in FCache.Values do
  begin
    if Supports(SetIntf, IDbSet, DbSet) then
    begin
      DbSet.DetachAll;
    end;
  end;
end;

procedure TDbContext.Detach(const AEntity: TObject);
begin
  DataSet(AEntity.ClassInfo).Detach(AEntity);
end;

procedure TDbContext.ExecuteProcedure(const ADto: TObject);
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  ProcAttr: StoredProcedureAttribute;
  ProcName: string;
  Prop: TRttiProperty;
  ParamAttr: DbParamAttribute;
  Cmd: IDbCommand;
  ParamNames: IList<string>;
  PropList: IList<TRttiProperty>;
  i: Integer;
begin
  Ctx := TRttiContext.Create;
  ParamNames := TCollections.CreateList<string>;
  PropList := TCollections.CreateList<TRttiProperty>;
  try
    Typ := Ctx.GetType(ADto.ClassType);
    ProcAttr := Typ.GetAttribute<StoredProcedureAttribute>;
    if ProcAttr <> nil then
      ProcName := ProcAttr.Name
    else
      ProcName := ADto.ClassName;

    for Prop in Typ.GetProperties do
    begin
      ParamAttr := Prop.GetAttribute<DbParamAttribute>;
      if ParamAttr <> nil then
      begin
        if ParamAttr.Name <> '' then
          ParamNames.Add(ParamAttr.Name)
        else
          ParamNames.Add(Prop.Name);
          
        PropList.Add(Prop);
      end;
    end;

    Cmd := FConnection.CreateCommand(FDialect.GenerateProcedureCallSQL(ProcName, ParamNames.ToArray));
    for i := 0 to PropList.Count - 1 do
    begin
      Prop := PropList[i];
      ParamAttr := Prop.GetAttribute<DbParamAttribute>;
      var ParamName := ParamNames[i];
      
      Cmd.AddParam(ParamName, Prop.GetValue(Pointer(ADto)));
      if ParamAttr.ParamType <> ptInput then
        Cmd.SetParamType(ParamName, ParamAttr.ParamType);
    end;

    Cmd.Execute;

    // Map back output parameters
    for i := 0 to PropList.Count - 1 do
    begin
      Prop := PropList[i];
      ParamAttr := Prop.GetAttribute<DbParamAttribute>;
      if ParamAttr.ParamType in [ptOutput, ptInputOutput, ptResult] then
      begin
        Prop.SetValue(Pointer(ADto), Cmd.GetParamValue(ParamNames[i]));
      end;
    end;
  finally
    ParamNames := nil;
    PropList := nil;
    Ctx.Free;
  end;
end;

function TDbContext.ChangeTracker: IChangeTracker;
begin
  Result := FChangeTracker;
end;

function TDbContext.Entry(const AEntity: TObject): IEntityEntry;
begin
  Result := TEntityEntry.Create(Self, AEntity);
end;

{ TEntityShadowState }

constructor TEntityShadowState.Create;
begin
  FShadowValues := TCollections.CreateDictionary<string, TValue>;
  FModifiedProperties := TCollections.CreateDictionary<string, Boolean>;
end;
 
 destructor TEntityShadowState.Destroy;
 begin
   FShadowValues := nil;
   FModifiedProperties := nil;
   inherited;
 end;

{ TChangeTracker }

constructor TChangeTracker.Create;
begin
  inherited Create;
  FTrackedEntities := TCollections.CreateDictionary<TObject, TEntityState>;
  FShadowStates := TCollections.CreateDictionary<TObject, TEntityShadowState>(True);
end;

destructor TChangeTracker.Destroy;
begin
  FTrackedEntities := nil;
  FShadowStates := nil;
  inherited;
end;

procedure TChangeTracker.Track(const AEntity: TObject; AState: TEntityState);
begin
  if AEntity = nil then Exit;
  FTrackedEntities.AddOrSetValue(AEntity, AState);
end;

procedure TChangeTracker.Remove(const AEntity: TObject);
begin
  FTrackedEntities.Remove(AEntity);
  FShadowStates.Remove(AEntity);
end;

function TChangeTracker.GetState(const AEntity: TObject): TEntityState;
begin
  if not FTrackedEntities.TryGetValue(AEntity, Result) then
    Result := esDetached;
end;

function TChangeTracker.HasChanges: Boolean;
var
  LPair: TPair<TObject, TEntityState>;
begin
  Result := False;
  for LPair in FTrackedEntities do
  begin
    if LPair.Value in [esAdded, esModified, esDeleted] then
      Exit(True);
  end;
end;

procedure TChangeTracker.AcceptAllChanges;
var
  LKey: TObject;
  LPair: TPair<TObject, TEntityShadowState>;
begin
  for LKey in FTrackedEntities.Keys do
  begin
    if FTrackedEntities[LKey] = esDeleted then
      FTrackedEntities.Remove(LKey)
    else
      FTrackedEntities[LKey] := esUnchanged;
  end;
    
  for LPair in FShadowStates do
    LPair.Value.ModifiedProperties.Clear;
end;

procedure TChangeTracker.Clear;
begin
  FTrackedEntities.Clear;
  FShadowStates.Clear;
end;

function TChangeTracker.GetTrackedEntities: IDictionary<TObject, TEntityState>;
begin
  Result := FTrackedEntities;
end;

function TChangeTracker.GetShadowState(const AEntity: TObject): TEntityShadowState;
begin
  if not FShadowStates.TryGetValue(AEntity, Result) then
  begin
    Result := TEntityShadowState.Create;
    FShadowStates.Add(AEntity, Result);
  end;
end;

{ TPropertyEntry }

constructor TPropertyEntry.Create(const AContext: TDbContext; const AEntity: TObject;
  const APropName: string);
begin
  inherited Create;
  FContext := AContext;
  FEntity := AEntity;
  FPropName := APropName;
  
  var Map := FContext.ModelBuilder.GetMap(FEntity.ClassInfo);
  var PropMap: TPropertyMap;
  if (Map <> nil) and Map.Properties.TryGetValue(FPropName, PropMap) then
    FIsShadow := PropMap.IsShadow
  else
    FIsShadow := False;
end;

function TPropertyEntry.GetCurrentValue: TValue;
begin
  if FIsShadow then
  begin
    var Tracker := TChangeTracker(FContext.ChangeTracker);
    var State := Tracker.GetShadowState(FEntity);
    if not State.ShadowValues.TryGetValue(FPropName, Result) then
      Result := TValue.Empty;
  end
  else
  begin
    var Ctx := TRttiContext.Create;
    try
      var Typ := Ctx.GetType(FEntity.ClassType);
      var Prop := Typ.GetProperty(FPropName);
      if Prop <> nil then
        Result := Prop.GetValue(Pointer(FEntity))
      else
        Result := TValue.Empty;
    finally
      Ctx.Free;
    end;
  end;
end;

procedure TPropertyEntry.SetCurrentValue(const AValue: TValue);
begin
  if FIsShadow then
  begin
    var Tracker := TChangeTracker(FContext.ChangeTracker);
    var State := Tracker.GetShadowState(FEntity);
    State.ShadowValues.AddOrSetValue(FPropName, AValue);
    SetIsModified(True);
  end
  else
  begin
    var Ctx := TRttiContext.Create;
    try
      var Typ := Ctx.GetType(FEntity.ClassType);
      var Prop := Typ.GetProperty(FPropName);
      if Prop <> nil then
      begin
        Prop.SetValue(Pointer(FEntity), AValue);
        SetIsModified(True);
      end;
    finally
      Ctx.Free;
    end;
  end;
end;

function TPropertyEntry.GetIsModified: Boolean;
begin
  var Tracker := TChangeTracker(FContext.ChangeTracker);
  var State := Tracker.GetShadowState(FEntity);
  Result := State.ModifiedProperties.ContainsKey(FPropName);
end;

procedure TPropertyEntry.SetIsModified(const AValue: Boolean);
begin
  var Tracker := TChangeTracker(FContext.ChangeTracker);
  var State := Tracker.GetShadowState(FEntity);
  if AValue then
  begin
    State.ModifiedProperties.AddOrSetValue(FPropName, True);
    if Tracker.GetState(FEntity) = esUnchanged then
      Tracker.Track(FEntity, esModified);
  end
  else
    State.ModifiedProperties.Remove(FPropName);
end;

{ TCollectionEntry }

constructor TCollectionEntry.Create(const AContext: TDbContext; const AParent: TObject; const APropName: string);
begin
  inherited Create;
  FContext := AContext;
  FParent := AParent;
  FPropName := APropName;
end;

procedure TCollectionEntry.Load;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Val: TValue;
  ListObj: TObject;
  ListIntf: IInterface;
  IsInterface: Boolean;
  ListType: TRttiType;
begin
  Ctx := TRttiContext.Create;
  try
    Typ := Ctx.GetType(FParent.ClassType);
  Prop := Typ.GetProperty(FPropName);
  if Prop = nil then
    raise Exception.CreateFmt('Property %s not found on %s', [FPropName, Typ.Name]);

  Val := Prop.GetValue(Pointer(FParent));
  if Val.IsEmpty then
    raise Exception.Create('Collection must be initialized before loading.');
  
  // Detect if property is Interface or Class
  IsInterface := Prop.PropertyType.TypeKind = tkInterface;

  if IsInterface then
  begin
    // Handle IList<T> (interface)
    if not Val.TryAsType<IInterface>(ListIntf) or (ListIntf = nil) then
      raise Exception.Create('Collection interface is nil and must be initialized before loading.');
    
    // Get the interface type to find Add method
    ListType := Prop.PropertyType;
  end
  else
  begin
    // Handle TList<T> or TObjectList<T> (class)
    if not Val.TryAsType<TObject>(ListObj) or (ListObj = nil) then
      raise Exception.Create('Collection must be initialized before loading.');
    
    ListType := Ctx.GetType(ListObj.ClassType);
  end;
  
  // Find Add method
  var AddMethod := ListType.GetMethod('Add');
  if AddMethod = nil then
    raise Exception.Create('Collection does not have Add method');
    
  var ChildType := AddMethod.GetParameters[0].ParamType;
  var ChildClass := ChildType.AsInstance.MetaclassType;
  
  // Find DbSet for ChildClass
  var DbSet := FContext.DataSet(ChildClass.ClassInfo);
  
  // Find Parent PK
  var ParentPKProp := Typ.GetProperty('Id'); // Simplified
  if ParentPKProp = nil then raise Exception.Create('PK Id not found on parent');
  var ParentPKVal := ParentPKProp.GetValue(Pointer(FParent));
  
  // Find FK on Child pointing to Parent
  var FKName := '';
  var ChildTyp := Ctx.GetType(ChildClass);
  var CProp: TRttiProperty;
  var Attr: TCustomAttribute;
  
  for CProp in ChildTyp.GetProperties do
  begin
    if CProp.PropertyType.Handle = Typ.Handle then // Found property of Parent type
    begin
       // Check for ForeignKey attribute
       for Attr in CProp.GetAttributes do
         if Attr is ForeignKeyAttribute then
         begin
           FKName := ForeignKeyAttribute(Attr).ColumnName;
           Break;
         end;
       if FKName <> '' then Break;
    end;
  end;
  
  // If not found via attribute, try convention 'ParentClassNameId'
  if FKName = '' then
  begin
    // Try 'UserId' if parent is TUser
    var Candidate := Typ.Name.Substring(1) + 'Id'; // TUser -> User + Id
    if ChildTyp.GetProperty(Candidate) <> nil then
      FKName := Candidate;
  end;
  
  if FKName = '' then
    raise Exception.CreateFmt('Could not determine Foreign Key for collection %s', [FPropName]);
  
  // IMPORTANT: FKName is the property name, we need to convert to column name!
  var FKProp := ChildTyp.GetProperty(FKName);
  if FKProp <> nil then
  begin
    // Check if property has [Column] attribute
    for Attr in FKProp.GetAttributes do
    begin
      if Attr is ColumnAttribute then
      begin
        FKName := ColumnAttribute(Attr).Name;
        Break;
      end;
    end;
  end;
  
  // Clear the collection before loading to ensure it reflects current DB state
  var ClearMethod := ListType.GetMethod('Clear');
  if ClearMethod <> nil then
  begin
    if IsInterface then
      ClearMethod.Invoke(Val, [])
    else
      ClearMethod.Invoke(ListObj, []);
  end;
    
  // Build Query: Child.FK = Parent.Id
  var Expr := TBinaryExpression.Create(
    FKName,
    boEqual,
    ParentPKVal
  );
  
  var Results := DbSet.ListObjects(Expr);
    // Add results to collection
    for var ChildObj in Results do
    begin
      if IsInterface then
        AddMethod.Invoke(Val, [ChildObj])
      else
        AddMethod.Invoke(ListObj, [ChildObj]);
    end;
  finally
    Ctx.Free;
  end;
end;

{ TReferenceEntry }

constructor TReferenceEntry.Create(const AContext: TDbContext; const AParent: TObject; const APropName: string);
begin
  inherited Create;
  FContext := AContext;
  FParent := AParent;
  FPropName := APropName;
end;

procedure TReferenceEntry.Load;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  ChildType: TRttiType;
  ChildClass: TClass;
  DbSet: IDbSet;
  FKProp: TRttiProperty;
  FKVal: TValue;
  FKName: string;
  ChildObj: TObject;
  Attr: TCustomAttribute;
begin
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(FParent.ClassType);
  Prop := Typ.GetProperty(FPropName);
  if Prop = nil then
    raise Exception.CreateFmt('Property %s not found on %s', [FPropName, Typ.Name]);

  ChildType := Prop.PropertyType;
  if ChildType.TypeKind <> tkClass then
    raise Exception.Create('Reference property must be a class');
    
  ChildClass := ChildType.AsInstance.MetaclassType;
  DbSet := FContext.DataSet(ChildClass.ClassInfo);
  
  // Find FK Property on Parent
  // Look for [ForeignKey] on Prop
  FKName := '';
  for Attr in Prop.GetAttributes do
    if Attr is ForeignKeyAttribute then
    begin
      FKName := ForeignKeyAttribute(Attr).ColumnName;
      Break;
    end;
    
  if FKName = '' then
  begin
    // Convention: PropName + 'Id'
    FKName := FPropName + 'Id';
  end;
  
  FKProp := Typ.GetProperty(FKName);
  if FKProp = nil then
    raise Exception.CreateFmt('Foreign Key property %s not found for reference %s', [FKName, FPropName]);
    
  FKVal := FKProp.GetValue(Pointer(FParent));
  
  // Unwrap Nullable<T> and validate FK value
  if not TryUnwrapAndValidateFK(FKVal, Ctx) then Exit;

  
  // Find Child
  ChildObj := DbSet.FindObject(FKVal.AsVariant);
  if ChildObj <> nil then
  begin
    // The TClassToClassConverter will handle the conversion from TObject to TAddress
    Prop.SetValue(Pointer(FParent), ChildObj);
  end;
end;

{ TEntityEntry }

constructor TEntityEntry.Create(const AContext: TDbContext; const AEntity: TObject);
begin
  inherited Create;
  FContext := AContext;
  FEntity := AEntity;
end;

function TEntityEntry.Collection(const APropName: string): ICollectionEntry;
begin
  Result := TCollectionEntry.Create(FContext, FEntity, APropName);
end;

function TEntityEntry.Reference(const APropName: string): IReferenceEntry;
begin
  Result := TReferenceEntry.Create(FContext, FEntity, APropName);
end;

function TEntityEntry.Member(const APropName: string): IPropertyEntry;
begin
  Result := TPropertyEntry.Create(FContext, FEntity, APropName);
end;

end.

