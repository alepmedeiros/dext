unit Dext.Core.Reflection;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict;

type
  TCustomAttributeClass = class of TCustomAttribute;

  /// <summary>
  ///   Indicates that a record type is a Dext Smart Property.
  /// </summary>
  SmartPropAttribute = class(TCustomAttribute);

  TRttiObjectHelper = class helper for TRttiObject
  public
    function GetAttribute<T: TCustomAttribute>: T; overload;
    function GetAttribute(AClass: TCustomAttributeClass): TCustomAttribute; overload;
    function HasAttribute<T: TCustomAttribute>: Boolean; overload;
    function HasAttribute(AClass: TCustomAttributeClass): Boolean; overload;
  end;

  /// <summary>
  ///   Cached structural information about a type.
  /// </summary>
  TTypeMetadata = class
  public
    RttiType: TRttiType;
    IsSmartProp: Boolean;
    IsNullable: Boolean;
    ValueField: TRttiField;
    HasValueField: TRttiField;
    InnerType: PTypeInfo;
    constructor Create(AType: PTypeInfo);
  end;

  TReflection = class
  private
    class var FCache: IDictionary<PTypeInfo, TTypeMetadata>;
    class var FContext: TRttiContext;
    class constructor Create;
    class destructor Destroy;
  public
    class function GetMetadata(AType: PTypeInfo): TTypeMetadata; static;
    class function GetValue(AInstance: TObject; const APropertyName: string): TValue; static;
    class procedure SetValue(AInstance: Pointer; AMember: TRttiMember; const AValue: TValue); static;
    class procedure SetValueByPath(AInstance: TObject; const APath: string; const AValue: TValue); static;
    class function IsSmartProp(AType: PTypeInfo): Boolean; static;
    class function TryUnwrapProp(const ASource: TValue; var ADest: TValue): Boolean; static;
  end;

implementation

uses
  Dext.Core.Activator,
  Dext.Core.ValueConverters,
  Dext.DI.Core;

{ TRttiObjectHelper }

function TRttiObjectHelper.GetAttribute<T>: T;
begin
  Result := nil;
  for var Attr in GetAttributes do if Attr is T then Exit(T(Attr));
end;

function TRttiObjectHelper.GetAttribute(AClass: TCustomAttributeClass): TCustomAttribute;
begin
  Result := nil;
  for var Attr in GetAttributes do if Attr.InheritsFrom(AClass) then Exit(Attr);
end;

function TRttiObjectHelper.HasAttribute<T>: Boolean;
begin
  Result := GetAttribute<T> <> nil;
end;

function TRttiObjectHelper.HasAttribute(AClass: TCustomAttributeClass): Boolean;
begin
  Result := GetAttribute(AClass) <> nil;
end;

{ TTypeMetadata }

constructor TTypeMetadata.Create(AType: PTypeInfo);
begin
  RttiType := TReflection.FContext.GetType(AType);
  IsSmartProp := False;
  IsNullable := False;
  ValueField := nil;
  HasValueField := nil;
  InnerType := nil;

  if (RttiType <> nil) and (RttiType.TypeKind = tkRecord) then
  begin
    var TypeName := RttiType.Name;
    IsNullable := TypeName.Contains('Nullable');
    IsSmartProp := RttiType.HasAttribute(SmartPropAttribute);

    for var Field in RttiType.GetFields do
    begin
      var LFieldName := Field.Name;
      if SameText(LFieldName, 'FValue') or SameText(LFieldName, 'Value') then
      begin
        ValueField := Field;
        InnerType := Field.FieldType.Handle;
        
        // Safety fallback: if it has FValue and looks like Prop/Type but missed the attribute
        if not IsSmartProp then
           IsSmartProp := TypeName.Contains('Prop') or TypeName.EndsWith('Type');
      end
      else if LFieldName.ToLower.Contains('hasvalue') then
        HasValueField := Field;
    end;
  end;
end;

{ TReflection }

class constructor TReflection.Create;
begin
  FContext := TRttiContext.Create;
  FCache := TCollections.CreateDictionary<PTypeInfo, TTypeMetadata>(True);
end;

class destructor TReflection.Destroy;
begin
  FCache := nil;
end;

class function TReflection.GetMetadata(AType: PTypeInfo): TTypeMetadata;
begin
  if not FCache.TryGetValue(AType, Result) then
  begin
    Result := TTypeMetadata.Create(AType);
    FCache.Add(AType, Result);
  end;
end;

class procedure TReflection.SetValue(AInstance: Pointer; AMember: TRttiMember; const AValue: TValue);
var
  TargetType: PTypeInfo;
begin
  if (AInstance = nil) or (AMember = nil) then Exit;
  if AMember is TRttiProperty then TargetType := TRttiProperty(AMember).PropertyType.Handle
  else if AMember is TRttiField then TargetType := TRttiField(AMember).FieldType.Handle
  else Exit;
  var Converted := TValueConverter.Convert(AValue, TargetType);
  if AMember is TRttiProperty then TRttiProperty(AMember).SetValue(AInstance, Converted)
  else if AMember is TRttiField then TRttiField(AMember).SetValue(AInstance, Converted);
end;

class function TReflection.GetValue(AInstance: TObject; const APropertyName: string): TValue;
var
  Prop: TRttiProperty;
  Raw, Unwrapped: TValue;
begin
  Result := TValue.Empty;
  if AInstance = nil then Exit;
  Prop := FContext.GetType(AInstance.ClassType).GetProperty(APropertyName);
  if Prop = nil then Exit;
  Raw := Prop.GetValue(Pointer(AInstance));
  if TryUnwrapProp(Raw, Unwrapped) then
    Result := Unwrapped
  else
    Result := Raw;
end;

class procedure TReflection.SetValueByPath(AInstance: TObject; const APath: string; const AValue: TValue);
var
  Parts: TArray<string>;
  Prop: TRttiProperty;
  CurObj: TObject;
  SubPath: string;
begin
  if (AInstance = nil) or (APath = '') then Exit;
  
  // Support both . and _ as separators
  if APath.Contains('_') then Parts := APath.Split(['_'])
  else Parts := APath.Split(['.']);

  if Length(Parts) = 1 then
  begin
    Prop := FContext.GetType(AInstance.ClassInfo).GetProperty(Parts[0]);
    if Prop <> nil then SetValue(Pointer(AInstance), Prop, AValue);
    Exit;
  end;

  // Level 1: Find the first part
  Prop := FContext.GetType(AInstance.ClassInfo).GetProperty(Parts[0]);
  if (Prop <> nil) and (Prop.PropertyType.TypeKind = tkClass) then
  begin
    CurObj := Prop.GetValue(Pointer(AInstance)).AsObject;
    if CurObj = nil then
    begin
       // Auto-instantiate nested classes
       CurObj := TActivator.CreateInstance(GetTypeData(Prop.PropertyType.Handle)^.ClassType, []);
       Prop.SetValue(Pointer(AInstance), CurObj);
    end;
    
    // Recursive call for the rest of the path
    SubPath := string.Join('.', Parts, 1, Length(Parts) - 1);
    SetValueByPath(CurObj, SubPath, AValue);
  end;
end;

class function TReflection.IsSmartProp(AType: PTypeInfo): Boolean;
begin
  Result := GetMetadata(AType).IsSmartProp;
end;

class function TReflection.TryUnwrapProp(const ASource: TValue; var ADest: TValue): Boolean;
var
  PData: Pointer;
begin
  ADest := ASource;
  Result := False;

  if ASource.TypeInfo = nil then Exit;

  // Use the same approach as TSQLGenerator.TryUnwrapSmartValue which is proven to work.
  // Check both Kind sources for maximum compatibility with Delphi RTTI inconsistencies.
  if (ASource.Kind <> tkRecord) and (ASource.TypeInfo.Kind <> tkRecord) then Exit;

  // Check for Smart Types (marked with [SmartProp] attribute)
  var Meta := GetMetadata(ASource.TypeInfo);
  if Meta.IsSmartProp and (Meta.ValueField <> nil) then
  begin
    // For Nullable<T>, check HasValue first
    if Meta.IsNullable then
    begin
      if Meta.HasValueField <> nil then
      begin
        PData := ASource.GetReferenceToRawData;
        if (PData = nil) or not Meta.HasValueField.GetValue(PData).AsBoolean then
        begin
          ADest := TValue.Empty;
          Result := True;
          Exit;
        end;
      end;
    end;

    PData := ASource.GetReferenceToRawData;
    if PData <> nil then
    begin
      ADest := Meta.ValueField.GetValue(PData);
      Result := True;
    end;
  end;
end;

end.
