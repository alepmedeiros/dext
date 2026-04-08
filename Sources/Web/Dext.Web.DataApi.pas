{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Web.DataApi;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.Character,
  System.TypInfo,
  Dext.DI.Interfaces,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Json,
  Dext.Json.Types,
  Dext.Web.Interfaces,
  Dext.Web.Routing,
  Dext.Web.Pipeline,
  Dext.Entity.Mapping,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.TypeConverters,
  Dext.Entity.Dialects,
  Dext.Core.ValueConverters,
  Dext.OpenAPI.Extensions,
  Dext.Web.DataApi.Resolver,
  Dext.Web.ModelBinding;

type
  TApiMethod = (amGet, amGetList, amPost, amPut, amDelete);
  TApiMethods = set of TApiMethod;

  const AllApiMethods = [amGet, amGetList, amPost, amPut, amDelete];

type
  /// <summary>Base options for Data API, allowing non-generic configuration.</summary>
  TDataApiOptions = class
  protected
    FAllowedMethods: TApiMethods;
    FTenantIdRequired: Boolean;
    FRequireAuthentication: Boolean;
    FRolesForRead: string;
    FRolesForWrite: string;
    FNamingStrategy: TCaseStyle;
    FEnumStyle: TEnumStyle;
    FContextClass: TClass;
    FEnableSwagger: Boolean;
    FSwaggerTag: string;
    FSwaggerDescription: string;
    FSql: string;
  public
    constructor Create;
    property Sql: string read FSql write FSql;
    property AllowedMethods: TApiMethods read FAllowedMethods write FAllowedMethods;
    property TenantIdRequired: Boolean read FTenantIdRequired write FTenantIdRequired;
    property RequireAuthentication: Boolean read FRequireAuthentication write FRequireAuthentication;
    property RolesForRead: string read FRolesForRead write FRolesForRead;
    property RolesForWrite: string read FRolesForWrite write FRolesForWrite;
    property ContextClass: TClass read FContextClass write FContextClass;
    property EnableSwagger: Boolean read FEnableSwagger write FEnableSwagger;
    property SwaggerTag: string read FSwaggerTag write FSwaggerTag;
    property SwaggerDescription: string read FSwaggerDescription write FSwaggerDescription;
    property NamingStrategy: TCaseStyle read FNamingStrategy write FNamingStrategy;
    property EnumStyle: TEnumStyle read FEnumStyle write FEnumStyle;
  end;

  TDataApiOptions<T> = class(TDataApiOptions)
  public
    // Fluent configuration
    function Allow(AMethods: TApiMethods): TDataApiOptions<T>;
    function RequireTenant: TDataApiOptions<T>;
    function RequireAuth: TDataApiOptions<T>;
    function RequireRole(const ARoles: string): TDataApiOptions<T>;
    function RequireReadRole(const ARoles: string): TDataApiOptions<T>;
    function RequireWriteRole(const ARoles: string): TDataApiOptions<T>;
    function UseSnakeCase: TDataApiOptions<T>;
    function UseCamelCase: TDataApiOptions<T>;
    function UseSwagger: TDataApiOptions<T>;
    function Tag(const ATag: string): TDataApiOptions<T>;
    function Description(const ADescription: string): TDataApiOptions<T>;
    function DbContext<TCtx: class>: TDataApiOptions<T>;
    function UseSql(const ASql: string): TDataApiOptions<T>;
    function EnumsAsStrings: TDataApiOptions<T>;
    function EnumsAsNumbers: TDataApiOptions<T>;
  end;

  TDataApiHandler<T: class> = class
  private
    FOptions: TDataApiOptions<T>;
    FPath: string;
    FDbContext: TDbContext;  // Reference to DbContext (not owned)
    FUseExplicitContext: Boolean;
      
    function GetDbContext(const Context: IHttpContext): TDbContext;
    function EntityToJson(const Entity: T): string;
    function CheckAuthorization(const Context: IHttpContext; IsWriteOperation: Boolean): IResult;
  public
    constructor Create(const APath: string; AOptions: TDataApiOptions<T>; ADbContext: TDbContext = nil);
    destructor Destroy; override;
      
    procedure RegisterRoutes(const ABuilder: IApplicationBuilder);
      
    // Option A: Explicit DbContext parameter
    class procedure Map(const ABuilder: IApplicationBuilder; const APath: string; ADbContext: TDbContext); overload;
    class procedure Map(const ABuilder: IApplicationBuilder; const APath: string; ADbContext: TDbContext; AOptions: TDataApiOptions<T>); overload;
    // Option B: Resolve DbContext from DI (Context.Services)
    class procedure Map(const ABuilder: IApplicationBuilder; const APath: string); overload;
    class procedure Map(const ABuilder: IApplicationBuilder; const APath: string; AOptions: TDataApiOptions<T>); overload;
      
    // Request Handlers
    function HandleGetList(const Context: IHttpContext): IResult;
    function HandleGet(const Context: IHttpContext): IResult;
    function HandlePost(const Context: IHttpContext): IResult;
    function HandlePut(const Context: IHttpContext): IResult;
    function HandleDelete(const Context: IHttpContext): IResult;
  end;

  /// <summary>Non-generic entry point for Data API mapping.</summary>
  TDataApi = class
  public
    class procedure Map(const ABuilder: IApplicationBuilder; const AClass: TClass; const APath: string; AOptions: TDataApiOptions = nil);
  end;

/// <summary>Factory function for Data API options to simplify syntax.</summary>
function DataApiOptions: TDataApiOptions<TObject>;

implementation

uses
  System.DateUtils,
  Dext,
  Dext.Core.Activator,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Core.DateUtils,
  Dext.Specifications.Types,
  Dext.Specifications.Interfaces,
  Dext.Specifications.OrderBy,
  Dext.Specifications.SQL.Generator,
  Dext.Entity.Query,
  Dext.Json.Utf8,
  Dext.Auth.Identity,
  Dext.Web.Results,
  Dext.Utils,
  Dext.Core.Reflection,
  Dext.DI.Extensions,
  Dext.Types.UUID;


{ TDataApiOptions }

constructor TDataApiOptions.Create;
begin
  FAllowedMethods := AllApiMethods;
  FTenantIdRequired := False;
  FNamingStrategy := TCaseStyle.CaseInherit;
  FEnumStyle := TEnumStyle.EnumInherit;
end;

function DataApiOptions: TDataApiOptions<TObject>;
begin
  Result := TDataApiOptions<TObject>.Create;
end;

{ TDataApiOptions<T> }

function TDataApiOptions<T>.Allow(AMethods: TApiMethods): TDataApiOptions<T>;
begin
  FAllowedMethods := AMethods;
  Result := Self;
end;

function TDataApiOptions<T>.RequireTenant: TDataApiOptions<T>;
begin
  FTenantIdRequired := True;
  Result := Self;
end;

function TDataApiOptions<T>.RequireAuth: TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  Result := Self;
end;

function TDataApiOptions<T>.RequireRole(const ARoles: string): TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  FRolesForRead := ARoles;
  FRolesForWrite := ARoles;
  Result := Self;
end;

function TDataApiOptions<T>.RequireReadRole(const ARoles: string): TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  FRolesForRead := ARoles;
  Result := Self;
end;

function TDataApiOptions<T>.RequireWriteRole(const ARoles: string): TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  FRolesForWrite := ARoles;
  Result := Self;
end;

function TDataApiOptions<T>.UseSnakeCase: TDataApiOptions<T>;
begin
  FNamingStrategy := TCaseStyle.SnakeCase;
  Result := Self;
end;

function TDataApiOptions<T>.UseCamelCase: TDataApiOptions<T>;
begin
  FNamingStrategy := TCaseStyle.CamelCase;
  Result := Self;
end;

function TDataApiOptions<T>.UseSwagger: TDataApiOptions<T>;
begin
  FEnableSwagger := True;
  Result := Self;
end;

function TDataApiOptions<T>.Tag(const ATag: string): TDataApiOptions<T>;
begin
  FSwaggerTag := ATag;
  Result := Self;
end;

function TDataApiOptions<T>.Description(const ADescription: string): TDataApiOptions<T>;
begin
  FSwaggerDescription := ADescription;
  Result := Self;
end;

function TDataApiOptions<T>.DbContext<TCtx>: TDataApiOptions<T>;
begin
  FContextClass := TCtx;
  Result := Self;
end;

function TDataApiOptions<T>.UseSql(const ASql: string): TDataApiOptions<T>;
begin
  FSql := ASql;
  Result := Self;
end;

function TDataApiOptions<T>.EnumsAsStrings: TDataApiOptions<T>;
begin
  FEnumStyle := TEnumStyle.AsString;
  Result := Self;
end;

function TDataApiOptions<T>.EnumsAsNumbers: TDataApiOptions<T>;
begin
  FEnumStyle := TEnumStyle.AsNumber;
  Result := Self;
end;

{ TDataApiHandler<T> }

constructor TDataApiHandler<T>.Create(const APath: string; AOptions: TDataApiOptions<T>; ADbContext: TDbContext);
begin
  inherited Create;
  FPath := APath;
  FOptions := AOptions;
  FDbContext := ADbContext;
  FUseExplicitContext := (ADbContext <> nil);
  if FOptions = nil then
    FOptions := TDataApiOptions<T>.Create;
end;

destructor TDataApiHandler<T>.Destroy;
begin
  FOptions.Free;
  // Note: FDbContext is NOT owned by handler - do not free
  inherited;
end;

function TDataApiHandler<T>.GetDbContext(const Context: IHttpContext): TDbContext;
var
  Obj: TObject;
  TargetClass: TClass;
begin
  if FUseExplicitContext then
    Result := FDbContext
  else
  begin
    // Determine which context class to resolve
    if (FOptions <> nil) and (FOptions.ContextClass <> nil) then
      TargetClass := FOptions.ContextClass
    else
      TargetClass := TDbContext;

    // Resolve from DI using TServiceType
    Obj := Context.Services.GetService(TServiceType.FromClass(TargetClass));
    if Obj = nil then
      raise Exception.CreateFmt('%s not registered in DI container. Use Map(App, Path, DbContext) or register it in ConfigureServices.', [TargetClass.ClassName]);
    
    if not (Obj is TDbContext) then
      raise Exception.CreateFmt('Service resolved for %s is not a TDbContext descendant.', [TargetClass.ClassName]);
      
    Result := TDbContext(Obj);
  end;
end;

function TDataApiHandler<T>.CheckAuthorization(const Context: IHttpContext; IsWriteOperation: Boolean): IResult;
var
  User: IClaimsPrincipal;
  RequiredRoles: string;
  RoleArray: TArray<string>;
  Role: string;
  HasRole: Boolean;
begin
  Result := nil;  // nil = authorized
  
  if not FOptions.RequireAuthentication then
    Exit;  // No auth required
  
  // Check if user is authenticated
  User := Context.User;
  if (User = nil) or not User.Identity.IsAuthenticated then
    Exit(Results.StatusCode(401, '{"error":"Authentication required"}'));
  
  // Determine which roles to check
  if IsWriteOperation then
    RequiredRoles := FOptions.RolesForWrite
  else
    RequiredRoles := FOptions.RolesForRead;
  
  if RequiredRoles = '' then
    Exit;  // Auth required but no specific roles
  
  // Check roles (comma-separated, user must have at least one)
  RoleArray := RequiredRoles.Split([',']);
  HasRole := False;
  for Role in RoleArray do
  begin
    if User.IsInRole(Role.Trim) then
    begin
      HasRole := True;
      Break;
    end;
  end;
  
  if not HasRole then
    Result := Results.StatusCode(403, Format('{"error":"Forbidden - requires one of roles: %s"}', [RequiredRoles]));
end;

function TDataApiHandler<T>.EntityToJson(const Entity: T): string;
var
  FinalSettings: TJsonSettings;
begin
  if Entity = nil then
    Exit('null');

  FinalSettings := TDextJson.GetDefaultSettings;
  if FOptions.NamingStrategy <> TCaseStyle.CaseInherit then
    FinalSettings.CaseStyle := FOptions.NamingStrategy;
  if FOptions.EnumStyle <> TEnumStyle.EnumInherit then
    FinalSettings.EnumStyle := FOptions.EnumStyle;

  var Serializer := TDextSerializer.Create(FinalSettings);
  try
    Result := Serializer.Serialize(TValue.From<T>(Entity));
  finally
    Serializer.Free;
  end;
end;

procedure TDataApiHandler<T>.RegisterRoutes(const ABuilder: IApplicationBuilder);
var
  CleanPath, EntityName, EntityTag: string;
  RttiCtx: TRttiContext;
  RttiType: TRttiType;
begin
  CleanPath := FPath.TrimRight(['/']);
  
  // Get entity name for Swagger tag (e.g., "TCustomer" -> "Customers")
  RttiCtx := TRttiContext.Create;
  try
    RttiType := RttiCtx.GetType(TypeInfo(T));
    if RttiType <> nil then
      EntityName := RttiType.Name
    else
      EntityName := 'Entity';
  finally
    RttiCtx.Free;
  end;
  
  // Remove 'T' prefix if present and pluralize
  if EntityName.StartsWith('T') then
    EntityTag := EntityName.Substring(1)
  else
    EntityTag := EntityName;
  if not EntityTag.EndsWith('s') then
    EntityTag := EntityTag + 's';
  
  // Use custom tag if provided
  if FOptions.SwaggerTag <> '' then
    EntityTag := FOptions.SwaggerTag;

  // GET List
  if amGetList in FOptions.AllowedMethods then
  begin
    ABuilder.MapGet(CleanPath, 
      procedure(Ctx: IHttpContext)
      begin
        var Res := HandleGetList(Ctx);
        Res.Execute(Ctx);
      end);
    
    // Add Swagger metadata
    if FOptions.EnableSwagger then
    begin
      TEndpointMetadataExtensions.WithSummary(ABuilder, 'List all ' + EntityTag);
      TEndpointMetadataExtensions.WithDescription(ABuilder, 
        'Returns a list of ' + EntityTag + '. Supports filtering by property values, ' +
        'pagination with _limit and _offset query parameters.');
      TEndpointMetadataExtensions.WithTag(ABuilder, EntityTag);
      TEndpointMetadataExtensions.WithResponse(ABuilder, 200, 'List of ' + EntityTag, TypeInfo(T));
      if FOptions.RequireAuthentication then
        TEndpointMetadataExtensions.RequireAuthorization(ABuilder, 'bearerAuth');
    end;
  end;

  // GET by ID
  if amGet in FOptions.AllowedMethods then
  begin
    ABuilder.MapGet(CleanPath + '/{id}', 
      procedure(Ctx: IHttpContext)
      begin
        var Res := HandleGet(Ctx);
        Res.Execute(Ctx);
      end);
    
    if FOptions.EnableSwagger then
    begin
      TEndpointMetadataExtensions.WithSummary(ABuilder, 'Get ' + EntityTag.TrimRight(['s']) + ' by ID');
      TEndpointMetadataExtensions.WithDescription(ABuilder, 
        'Returns a single ' + EntityTag.TrimRight(['s']) + ' by its unique identifier.');
      TEndpointMetadataExtensions.WithTag(ABuilder, EntityTag);
      TEndpointMetadataExtensions.WithResponse(ABuilder, 200, EntityTag.TrimRight(['s']) + ' found', TypeInfo(T));
      TEndpointMetadataExtensions.WithResponse(ABuilder, 404, 'Entity not found');
      if FOptions.RequireAuthentication then
        TEndpointMetadataExtensions.RequireAuthorization(ABuilder, 'bearerAuth');
    end;
  end;

  // POST
  if amPost in FOptions.AllowedMethods then
  begin
    ABuilder.MapPost(CleanPath, 
      procedure(Ctx: IHttpContext)
      begin
        var Res := HandlePost(Ctx);
        Res.Execute(Ctx);
      end);
    
    if FOptions.EnableSwagger then
    begin
      TEndpointMetadataExtensions.WithSummary(ABuilder, 'Create ' + EntityTag.TrimRight(['s']));
      TEndpointMetadataExtensions.WithDescription(ABuilder, 
        'Creates a new ' + EntityTag.TrimRight(['s']) + '. Returns the created entity with its generated ID.');
      TEndpointMetadataExtensions.WithTag(ABuilder, EntityTag);
      TEndpointMetadataExtensions.WithRequestType(ABuilder, TypeInfo(T));
      TEndpointMetadataExtensions.WithResponse(ABuilder, 201, 'Entity created', TypeInfo(T));
      TEndpointMetadataExtensions.WithResponse(ABuilder, 400, 'Invalid request body');
      if FOptions.RequireAuthentication then
        TEndpointMetadataExtensions.RequireAuthorization(ABuilder, 'bearerAuth');
    end;
  end;

  // PUT
  if amPut in FOptions.AllowedMethods then
  begin
    ABuilder.MapPut(CleanPath + '/{id}', 
      procedure(Ctx: IHttpContext)
      begin
        var Res := HandlePut(Ctx);
        Res.Execute(Ctx);
      end);
    
    if FOptions.EnableSwagger then
    begin
      TEndpointMetadataExtensions.WithSummary(ABuilder, 'Update ' + EntityTag.TrimRight(['s']));
      TEndpointMetadataExtensions.WithDescription(ABuilder, 
        'Updates an existing ' + EntityTag.TrimRight(['s']) + ' by ID.');
      TEndpointMetadataExtensions.WithTag(ABuilder, EntityTag);
      TEndpointMetadataExtensions.WithRequestType(ABuilder, TypeInfo(T));
      TEndpointMetadataExtensions.WithResponse(ABuilder, 200, 'Entity updated', TypeInfo(T));
      TEndpointMetadataExtensions.WithResponse(ABuilder, 404, 'Entity not found');
      if FOptions.RequireAuthentication then
        TEndpointMetadataExtensions.RequireAuthorization(ABuilder, 'bearerAuth');
    end;
  end;

  // DELETE
  if amDelete in FOptions.AllowedMethods then
  begin
    ABuilder.MapDelete(CleanPath + '/{id}', 
      procedure(Ctx: IHttpContext) 
      begin
        var Res := HandleDelete(Ctx);
        Res.Execute(Ctx);
      end);
    
    if FOptions.EnableSwagger then
    begin
      TEndpointMetadataExtensions.WithSummary(ABuilder, 'Delete ' + EntityTag.TrimRight(['s']));
      TEndpointMetadataExtensions.WithDescription(ABuilder, 
        'Deletes an existing ' + EntityTag.TrimRight(['s']) + ' by ID.');
      TEndpointMetadataExtensions.WithTag(ABuilder, EntityTag);
      TEndpointMetadataExtensions.WithResponse(ABuilder, 204, 'Entity deleted');
      TEndpointMetadataExtensions.WithResponse(ABuilder, 404, 'Entity not found');
      if FOptions.RequireAuthentication then
        TEndpointMetadataExtensions.RequireAuthorization(ABuilder, 'bearerAuth');
    end;
  end;
end;


function TDataApiHandler<T>.HandleGetList(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  Query: IStringDictionary;
  i: Integer;
  ParamName, ParamValue: string;
  FilterExpr: IExpression;
  NewExpr: IExpression;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  PropType: TRttiType;
  IntVal: Integer;
  BoolVal: Boolean;
  Limit, Offset: Integer;
  OrderList: IList<IOrderBy>;
  AuthResult: IResult;
  Map: TEntityMap;
  PropMap: TPropertyMap;
  Qry: TFluentQuery<T>;
begin
  // Authorization check
  AuthResult := CheckAuthorization(Context, False);  // Read operation
  if AuthResult <> nil then
    Exit(AuthResult);
    
  try
    DbCtx := GetDbContext(Context);
    
    // Parse query parameters for filtering and ordering
    Query := Context.Request.Query;
    FilterExpr := nil;
    Limit := 0;
    Offset := 0;
    
    OrderList := TCollections.CreateList<IOrderBy>;
    try
      var Properties: TArray<TRttiProperty>;
      Ctx := TRttiContext.Create;
      try
        Typ := Ctx.GetType(TypeInfo(T));
        if Typ = nil then Exit(Results.BadRequest('Entity type not found in RTTI'));
        Properties := Typ.GetProperties;
        Map := TModelBuilder.Instance.GetMap(TypeInfo(T));
        
        var QueryArray := Query.ToArray;
        for i := 0 to High(QueryArray) do
        begin
          ParamName := QueryArray[i].Key;
          ParamValue := QueryArray[i].Value;
          
          if ParamName = '' then Continue;

          // Pagination
          if SameText(ParamName, '_limit') then
          begin
            TryStrToInt(ParamValue, Limit);
            Continue;
          end;
          if SameText(ParamName, '_offset') then
          begin
            TryStrToInt(ParamValue, Offset);
            Continue;
          end;

          // Ordering (_orderby=Name desc,Age asc)
          if SameText(ParamName, '_orderby') then
          begin
             var OrderParts := ParamValue.Split([',']);
             for var Part in OrderParts do
             begin
               var P := Part.Trim.Split([' ']);
               if System.Length(P) > 0 then
               begin
                 var Ascending := True;
                 if (System.Length(P) > 1) and SameText(P[1], 'desc') then
                   Ascending := False;
                 OrderList.Add(TOrderBy.Create(P[0], Ascending));
               end;
             end;
             Continue;
          end;
          
          // Filter extraction (PropName_Operator)
          var ActualPropName := ParamName;
          var UnderscorePos := ParamName.LastIndexOf('_');
          var BinaryOp := boEqual;
          
          if UnderscorePos > 0 then
          begin
            var Suffix := ParamName.Substring(UnderscorePos + 1).ToLower;
            var Handled := True;
            if Suffix = 'eq' then BinaryOp := boEqual
            else if Suffix = 'neq' then BinaryOp := boNotEqual
            else if Suffix = 'gt' then BinaryOp := boGreaterThan
            else if Suffix = 'gte' then BinaryOp := boGreaterThanOrEqual
            else if Suffix = 'lt' then BinaryOp := boLessThan
            else if Suffix = 'lte' then BinaryOp := boLessThanOrEqual
            else if (Suffix = 'cont') or (Suffix = 'contains') then BinaryOp := boLike
            else if Suffix = 'sw' then BinaryOp := boLike
            else if Suffix = 'ew' then BinaryOp := boLike
            else if Suffix = 'in' then BinaryOp := boIn
            else Handled := False;

            if Handled then
               ActualPropName := ParamName.Substring(0, UnderscorePos);
          end;

          // Find matching property (case insensitive)
          Prop := nil;
          for var P in Properties do
            if SameText(P.Name, ActualPropName) then
            begin
              Prop := P;
              Break;
            end;
          
          if Prop = nil then
            Continue;
            
          if Map.Properties.TryGetValue(Prop.Name, PropMap) and PropMap.IsIgnored then
            Continue;
          
          PropType := Prop.PropertyType;
          
          // Adjust value based on operator
          var AdjustedValue := ParamValue;
          if BinaryOp = boLike then
          begin
            var Suffix := ParamName.Substring(UnderscorePos + 1).ToLower;
            if Suffix = 'sw' then AdjustedValue := ParamValue + '%'
            else if Suffix = 'ew' then AdjustedValue := '%' + ParamValue
            else AdjustedValue := '%' + ParamValue + '%';
          end;

          // Create expression
          if BinaryOp = boIn then
          begin
            var InValues := ParamValue.Split([',']);
            NewExpr := TBinaryExpression.Create(Prop.Name, boIn, TValue.From<TArray<string>>(InValues));
          end
          else
          begin
              case PropType.TypeKind of
                tkInteger, tkInt64:
                  if TryStrToInt(ParamValue, IntVal) then
                  begin
                     NewExpr := TBinaryExpression.Create(Prop.Name, BinaryOp, IntVal)
                  end
                  else Continue;
                tkEnumeration:
                  if PropType.Handle = TypeInfo(Boolean) then
                  begin
                    BoolVal := SameText(ParamValue, 'true') or (ParamValue = '1');
                     NewExpr := TBinaryExpression.Create(Prop.Name, BinaryOp, BoolVal);
                  end else Continue;
                tkString, tkUString, tkWString, tkLString:
                   NewExpr := TBinaryExpression.Create(Prop.Name, BinaryOp, AdjustedValue);
              else Continue;
              end;
          end;
          
          if FilterExpr = nil then
            FilterExpr := NewExpr
          else
            FilterExpr := TLogicalExpression.Create(FilterExpr, NewExpr, loAnd);
        end;
      finally
        Ctx.Free;
      end;
      
      if FOptions.Sql <> '' then
        Qry := DbCtx.Entities<T>.FromSql(FOptions.Sql)
      else
        Qry := DbCtx.Entities<T>.QueryAll;

      if FilterExpr <> nil then
        Qry := Qry.Where(FilterExpr);

      // Use AsNoTracking for DataApi to avoid memory leaks and context overhead.
      Qry := Qry.AsNoTracking;

      for var OrderItem in OrderList do
        Qry := Qry.OrderBy(OrderItem);

      if Offset > 0 then Qry := Qry.Skip(Offset);
      if Limit > 0 then Qry := Qry.Take(Limit);

      var FinalItems := Qry.ToList;
      try
        // Build JSON response with high-performance UTF8 writer
        var Stream := TMemoryStream.Create;
        try
          var FinalSettings := TDextJson.GetDefaultSettings;
          if FOptions.NamingStrategy <> TCaseStyle.CaseInherit then
            FinalSettings.CaseStyle := FOptions.NamingStrategy;
          if FOptions.EnumStyle <> TEnumStyle.EnumInherit then
            FinalSettings.EnumStyle := FOptions.EnumStyle;

          var Writer := TUtf8JsonWriter.Create(Stream, False);
          Writer.Settings := FinalSettings;
          Writer.WriteStartArray;
          for var Item in FinalItems do
          begin
            Writer.WriteValue(TValue.From<T>(Item));
          end;
          Writer.WriteEndArray;

          Stream.Position := 0;
          Result := Results.Stream(Stream, 'application/json');
        except
          Stream.Free;
          raise;
        end;
      finally
        FinalItems := nil;
      end;
    finally
      OrderList := nil;
      FilterExpr := nil;
      NewExpr := nil;
      AuthResult := nil;
      Query := nil;
      Qry := Default(TFluentQuery<T>);
    end;
  except
    on E: Exception do
      Result := Results.StatusCode(500, Format('{"error":"[%s] %s"}', [E.ClassName, EscapeJsonString(E.Message)]));
  end;
end;

function TDataApiHandler<T>.HandleGet(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  IdStr: string;
  PKValue: Variant;
  Binder: IModelBinder;
  Entity: T;
  AuthResult: IResult;
begin
  // Authorization check
  AuthResult := CheckAuthorization(Context, False);  // Read operation
  if AuthResult <> nil then
    Exit(AuthResult);
    
  try
    // Get ID from route parameter
    if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
      Exit(Results.BadRequest('{"error":"Missing id parameter"}'));

    DbCtx := GetDbContext(Context);
    
    // Resolve Strong-Typed ID using metadata and Model Binder (optional service)
    Binder := TServiceProviderExtensions.GetService<IModelBinder>(Context.Services);
    PKValue := TEntityIdResolver.Resolve(TEntityMap(DbCtx.GetMapping(TypeInfo(T))), IdStr, Binder);

    Entity := DbCtx.Entities<T>.Find(PKValue);
    if Entity = nil then
      Result := Results.NotFound(Format('{"error":"Entity with id %s not found"}', [IdStr]))
    else
      Result := Results.Json(EntityToJson(Entity));
  except
    on E: Exception do
      Result := Results.StatusCode(500, Format('{"error":"%s"}', [EscapeJsonString(E.Message)]));
  end;
end;

function TDataApiHandler<T>.HandlePost(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  Entity: T;
  Stream: TStream;
  JsonString: string;
  Bytes: TBytes;
  JsonNode: IDextJsonNode;
  AuthResult: IResult;
begin
  // Authorization check
  AuthResult := CheckAuthorization(Context, True);  // Write operation
  if AuthResult <> nil then
    Exit(AuthResult);
    
  try
    DbCtx := GetDbContext(Context);
    
    // Read JSON body
    Stream := Context.Request.Body;
    if (Stream = nil) or (Stream.Size = 0) then
      Exit(Results.BadRequest('{"error":"Request body is empty"}'));
    
    Stream.Position := 0;
    SetLength(Bytes, Stream.Size);
    Stream.ReadBuffer(Bytes[0], Stream.Size);
    JsonString := TEncoding.UTF8.GetString(Bytes);
    
    // Parse JSON
    JsonNode := TDextJson.Provider.Parse(JsonString);
    if (JsonNode = nil) or (JsonNode.GetNodeType <> jntObject) then
      Exit(Results.BadRequest('{"error":"Invalid JSON in request body"}'));
    
    var FinalSettings := TDextJson.GetDefaultSettings;
    if FOptions.NamingStrategy <> TCaseStyle.CaseInherit then
      FinalSettings.CaseStyle := FOptions.NamingStrategy;
    if FOptions.EnumStyle <> TEnumStyle.EnumInherit then
      FinalSettings.EnumStyle := FOptions.EnumStyle;

    var Serializer := TDextSerializer.Create(FinalSettings);
    try
       Entity := Serializer.Deserialize<T>(JsonString);
    finally
       Serializer.Free;
    end;
      
    var TargetSet := DbCtx.Entities<T>;
    var Map := TEntityMap(DbCtx.GetMapping(TypeInfo(T)));

    // Validation for Manual IDs
    for var KeyName in Map.Keys do
    begin
      var PropMap := Map.Properties[KeyName];
      if not PropMap.IsAutoInc then
      begin
        var Val := PropMap.Prop.GetValue(TObject(Entity));
        if Val.IsEmpty or ((Val.Kind = tkInteger) and (Val.AsInteger = 0)) or ((Val.Kind in [tkString, tkUString, tkWString, tkLString]) and (Val.AsString = '')) then
           Exit(Results.BadRequest(Format('{"error":"Primary key %s is required for this entity"}', [KeyName])));
      end;
    end;
      
    TargetSet.Add(Entity);
    DbCtx.SaveChanges;
    
    // Get ID for response. If manual PK, it should be obtainable from the entity.
    var IdStr := TargetSet.GetEntityId(Entity);
    
    // Canonical format for URL (lowercase, no braces)
    if IdStr.StartsWith('{') and (IdStr.Length = 38) then
      IdStr := IdStr.Substring(1, 36);
    IdStr := IdStr.ToLower;

    Result := Results.Created(FPath + '/' + IdStr, EntityToJson(Entity));
  except
    on E: Exception do
      Result := Results.StatusCode(500, Format('{"error":"%s"}', [EscapeJsonString(E.Message)]));
  end;
end;

function TDataApiHandler<T>.HandlePut(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  IdStr: string;
  PKValue: Variant;
  Entity: T;
  Stream: TStream;
  JsonString: string;
  Bytes: TBytes;
  JsonNode: IDextJsonNode;
  AuthResult: IResult;
begin
  // Authorization check
  AuthResult := CheckAuthorization(Context, True);  // Write operation
  if AuthResult <> nil then
    Exit(AuthResult);
    
  try
    if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
      Exit(Results.BadRequest('{"error":"Missing id parameter"}'));

    DbCtx := GetDbContext(Context);

    // Resolve Strong-Typed ID using metadata and Model Binder (optional service)
    var Binder := TServiceProviderExtensions.GetService<IModelBinder>(Context.Services);
    PKValue := TEntityIdResolver.Resolve(TEntityMap(DbCtx.GetMapping(TypeInfo(T))), IdStr, Binder);
    Entity := DbCtx.Entities<T>.Find(PKValue);
    
    if Entity = nil then
      Exit(Results.NotFound(Format('{"error":"Entity with id %s not found"}', [IdStr])));
    
    // Read JSON body
    Stream := Context.Request.Body;
    if (Stream = nil) or (Stream.Size = 0) then
      Exit(Results.BadRequest('{"error":"Request body is empty"}'));
    
    Stream.Position := 0;
    SetLength(Bytes, Stream.Size);
    Stream.ReadBuffer(Bytes[0], Stream.Size);
    JsonString := TEncoding.UTF8.GetString(Bytes);
    
    // Parse JSON
    JsonNode := TDextJson.Provider.Parse(JsonString);
    if (JsonNode = nil) or (JsonNode.GetNodeType <> jntObject) then
      Exit(Results.BadRequest('{"error":"Invalid JSON in request body"}'));
    
    var FinalSettings := TDextJson.GetDefaultSettings;
    if FOptions.NamingStrategy <> TCaseStyle.CaseInherit then
      FinalSettings.CaseStyle := FOptions.NamingStrategy;
    if FOptions.EnumStyle <> TEnumStyle.EnumInherit then
      FinalSettings.EnumStyle := FOptions.EnumStyle;

    var Serializer := TDextSerializer.Create(FinalSettings);
    try
       Serializer.Populate(TObject(Entity), JsonString);
    finally
       Serializer.Free;
    end;
    
    DbCtx.Entities<T>.Update(Entity);
    DbCtx.SaveChanges;
    
    Result := Results.Json(EntityToJson(Entity));
  except
    on E: Exception do
      Result := Results.StatusCode(500, Format('{"error":"%s"}', [EscapeJsonString(E.Message)]));
  end;
end;

function TDataApiHandler<T>.HandleDelete(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  IdStr: string;
  PKValue: Variant;
  Entity: T;
  AuthResult: IResult;
begin
  // Authorization check
  AuthResult := CheckAuthorization(Context, True);  // Write operation
  if AuthResult <> nil then
    Exit(AuthResult);
    
  try
    if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
      Exit(Results.BadRequest('{"error":"Missing id parameter"}'));

    DbCtx := GetDbContext(Context);

    // Resolve Strong-Typed ID using metadata and Model Binder (optional service)
    var Binder := TServiceProviderExtensions.GetService<IModelBinder>(Context.Services);
    PKValue := TEntityIdResolver.Resolve(TEntityMap(DbCtx.GetMapping(TypeInfo(T))), IdStr, Binder);
    Entity := DbCtx.Entities<T>.Find(PKValue);
    
    if Entity = nil then
      Exit(Results.NotFound(Format('{"error":"Entity with id %s not found"}', [IdStr])));
    
    DbCtx.Entities<T>.Remove(Entity);
    DbCtx.SaveChanges;
    
    Result := Results.Ok(Format('{"deleted":true,"id":"%s"}', [IdStr]));
  except
    on E: Exception do
      Result := Results.StatusCode(500, Format('{"error":"%s"}', [EscapeJsonString(E.Message)]));
  end;
end;

// Option A: Explicit DbContext parameter
class procedure TDataApiHandler<T>.Map(
  const ABuilder: IApplicationBuilder; 
  const APath: string;
  ADbContext: TDbContext);
var
  Options: TDataApiOptions<T>;
  Handler: TDataApiHandler<T>;
begin
  Options := TDataApiOptions<T>.Create;
  Handler := TDataApiHandler<T>.Create(APath, Options, ADbContext);
  Handler.RegisterRoutes(ABuilder);
  
  // Register handler for disposal when host shuts down
  ABuilder.RegisterForDisposal(Handler);
end;

class procedure TDataApiHandler<T>.Map(
  const ABuilder: IApplicationBuilder; 
  const APath: string; 
  ADbContext: TDbContext;
  AOptions: TDataApiOptions<T>);
var
  Handler: TDataApiHandler<T>;
begin
  if AOptions = nil then
    AOptions := TDataApiOptions<T>.Create;

  Handler := TDataApiHandler<T>.Create(APath, AOptions, ADbContext);
  Handler.RegisterRoutes(ABuilder);
  
  // Register handler for disposal when host shuts down
  ABuilder.RegisterForDisposal(Handler);
end;

// Option B: Resolve DbContext from DI
class procedure TDataApiHandler<T>.Map(
  const ABuilder: IApplicationBuilder; 
  const APath: string);
var
  Options: TDataApiOptions<T>;
  Handler: TDataApiHandler<T>;
begin
  Options := TDataApiOptions<T>.Create;
  Handler := TDataApiHandler<T>.Create(APath, Options, nil);
  Handler.RegisterRoutes(ABuilder);
  
  // Register handler for disposal when host shuts down
  ABuilder.RegisterForDisposal(Handler);
end;

class procedure TDataApiHandler<T>.Map(const ABuilder: IApplicationBuilder; const APath: string; AOptions: TDataApiOptions<T>);
begin
  Map(ABuilder, APath, nil, AOptions);
end;

{ TDataApi }

class procedure TDataApi.Map(const ABuilder: IApplicationBuilder; const AClass: TClass;
  const APath: string; AOptions: TDataApiOptions);
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  GenericTyp: TRttiType;
  Method: TRttiMethod;
begin
  Ctx := TRttiContext.Create;
  try
    // Find TDataApiHandler<T>
    GenericTyp := Ctx.FindType('Dext.Web.DataApi.TDataApiHandler<T>');
    if GenericTyp = nil then
      GenericTyp := Ctx.FindType('TDataApiHandler<T>');
      
    if GenericTyp = nil then
       raise Exception.Create('Could not find TDataApiHandler<T> type');

    // Make generic with AClass
    // TODO: Delphi RTTI does not support generic instantiation at runtime.
    // This requires a registration-based approach instead.
    Typ := Ctx.GetType(AClass);
    
    // Find Map(ABuilder, APath, AOptions)
    // Since TDataApiOptions is a base class, we might need to find the right overload
    for Method in Typ.GetMethods('Map') do
    begin
       var Params := Method.GetParameters;
       if (Length(Params) = 3) and 
          (Params[0].ParamType.Handle = TypeInfo(IApplicationBuilder)) and
           (Params[1].ParamType.TypeKind in [tkString, tkUString, tkWString, tkLString]) then
       begin
          Method.Invoke(nil, [TValue.From<IApplicationBuilder>(ABuilder), APath, AOptions]);
          Exit;
       end;
    end;
  finally
    Ctx.Free;
  end;
end;

end.
