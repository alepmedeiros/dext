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
unit Dext.Core.Activator;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.DI.Attributes;

type
  TActivator = class
  public
    // 1. Manual Instantiation (No DI)
    // Uses only provided arguments. Must match exactly.
    class function CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject; overload;

    // 2. Pure DI Instantiation (No Manual Args)
    // Uses DI container to resolve all dependencies.
    // Uses "Greedy" strategy: prefers constructor with MOST resolvable parameters.
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass): TObject; overload;

    // 3. Hybrid Instantiation (Manual Args + DI)
    // Uses provided arguments for the first N parameters, then DI for the rest.
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject; overload;

    // 4. Full Metadata Instantiation (Supports Class and Interface)
    // If it's a class, works like Pure DI.
    // If it's an interface, tries to resolve from DI, with fallback for IList/IEnumerable.
    class function CreateInstance(AProvider: IServiceProvider; AType: PTypeInfo): TValue; overload;

    class function CreateInstance<T: class>(const AArgs: array of TValue): T; overload;
    class function CreateInstance<T: class>: T; overload;

    class procedure RegisterDefault(ABase: TClass; AImpl: TClass); overload;
    class procedure RegisterDefault(AInterface: PTypeInfo; AImpl: TClass); overload;
    class procedure RegisterDefault<TService: IInterface; TImplementation: class>; overload;
    class function ResolveImplementation(AClass: TClass): TClass;
    class function GetDictionaryValueType(AType: PTypeInfo): PTypeInfo;
    class function IsListType(AType: PTypeInfo): Boolean;
    class function GetListElementType(AType: PTypeInfo): PTypeInfo;
    class function IsDictionaryType(AType: PTypeInfo): Boolean;
    class function GetDictionaryKeyType(AType: PTypeInfo): PTypeInfo;
  private
    class var FDefaultImplementations: IDictionary<TClass, TClass>;
    class var FInterfaceDefaultImpl: IDictionary<PTypeInfo, TClass>;
    class constructor Create;
    class destructor Destroy;
    class function TryResolveService(AProvider: IServiceProvider; AParamType: TRttiType; out AResolvedService: TValue): Boolean;
    class procedure InjectFields(AProvider: IServiceProvider; AInstance: TObject; ATypeObj: TRttiType);
  end;

implementation

uses
  System.Classes;

{ TActivator }

class constructor TActivator.Create;
begin
  FDefaultImplementations := TCollections.CreateDictionary<TClass, TClass>;
  FInterfaceDefaultImpl := TCollections.CreateDictionary<PTypeInfo, TClass>;
  // Default framework mappings
  RegisterDefault(TStrings, TStringList);
end;

class destructor TActivator.Destroy;
begin
  FDefaultImplementations := nil;
  FInterfaceDefaultImpl := nil;
end;

class procedure TActivator.RegisterDefault(ABase: TClass; AImpl: TClass);
begin
  if ABase <> nil then
    FDefaultImplementations.AddOrSetValue(ABase, AImpl);
end;

class procedure TActivator.RegisterDefault(AInterface: PTypeInfo; AImpl: TClass);
begin
  if AInterface <> nil then
    FInterfaceDefaultImpl.AddOrSetValue(AInterface, AImpl);
end;

class procedure TActivator.RegisterDefault<TService, TImplementation>;
begin
  RegisterDefault(TypeInfo(TService), TImplementation);
end;

class function TActivator.ResolveImplementation(AClass: TClass): TClass;
begin
  if (AClass = nil) or not FDefaultImplementations.TryGetValue(AClass, Result) then
    Result := AClass;
end;

class function TActivator.TryResolveService(AProvider: IServiceProvider; AParamType: TRttiType; out AResolvedService: TValue): Boolean;
var
  ServiceType: TServiceType;
begin
  AResolvedService := TValue.Empty;
  Result := False;

  if AProvider = nil then
    Exit;

  if AParamType.TypeKind = tkInterface then
  begin
    var Guid := TRttiInterfaceType(AParamType).GUID;
    if not Guid.IsEmpty then
    begin
      ServiceType := TServiceType.FromInterface(Guid);
      var Intf := AProvider.GetServiceAsInterface(ServiceType);
      if Intf <> nil then
      begin
        TValue.Make(@Intf, AParamType.Handle, AResolvedService);
        Result := True;
      end;
    end;
  end
  else if AParamType.TypeKind = tkClass then
  begin
    var Cls := TRttiInstanceType(AParamType).MetaclassType;
    ServiceType := TServiceType.FromClass(Cls);
    var Obj := AProvider.GetService(ServiceType);
    if Obj <> nil then
    begin
      AResolvedService := TValue.From(Obj);
      Result := True;
    end;
  end;
end;

class procedure TActivator.InjectFields(AProvider: IServiceProvider; AInstance: TObject; ATypeObj: TRttiType);
var
  Field: TRttiField;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  InjectAttr: InjectAttribute;
  TargetType: PTypeInfo;
  ResolvedValue: TValue;
begin
  if (AProvider = nil) or (AInstance = nil) or (ATypeObj = nil) then Exit;

  // Process Fields
  for Field in ATypeObj.GetFields do
  begin
    InjectAttr := nil;
    for Attr in Field.GetAttributes do
      if Attr is InjectAttribute then
      begin
        InjectAttr := InjectAttribute(Attr);
        Break;
      end;
      
    if InjectAttr <> nil then
    begin
      TargetType := Field.FieldType.Handle;
      if InjectAttr.TargetTypeInfo <> nil then
        TargetType := PTypeInfo(InjectAttr.TargetTypeInfo);
        
      if TargetType <> nil then
      begin
        ResolvedValue := CreateInstance(AProvider, TargetType);
        if not ResolvedValue.IsEmpty then
          Field.SetValue(AInstance, ResolvedValue);
      end;
    end;
  end;

  // Process Properties
  for Prop in ATypeObj.GetProperties do
  begin
    if not Prop.IsWritable then Continue;
    
    InjectAttr := nil;
    for Attr in Prop.GetAttributes do
      if Attr is InjectAttribute then
      begin
        InjectAttr := InjectAttribute(Attr);
        Break;
      end;
      
    if InjectAttr <> nil then
    begin
      TargetType := Prop.PropertyType.Handle;
      if InjectAttr.TargetTypeInfo <> nil then
        TargetType := PTypeInfo(InjectAttr.TargetTypeInfo);
        
      if TargetType <> nil then
      begin
        ResolvedValue := CreateInstance(AProvider, TargetType);
        if not ResolvedValue.IsEmpty then
          Prop.SetValue(AInstance, ResolvedValue);
      end;
    end;
  end;
end;

// 1. Manual Instantiation with Hybrid DI Support
class function TActivator.CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  BestMethod: TRttiMethod;
  BestArgs: TArray<TValue>;
  TargetClass: TClass;
begin
  TargetClass := ResolveImplementation(AClass);
  BestMethod := nil;
  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(TargetClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI information not found for class %s', [TargetClass.ClassName]);

    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        
        if Length(Params) < Length(AArgs) then
          Continue; 
        
        Matched := True;
        SetLength(Args, Length(Params));
        
        for I := 0 to High(AArgs) do
        begin
          if AArgs[I].IsEmpty then Continue;

          if AArgs[I].Kind <> Params[I].ParamType.TypeKind then
          begin
            if (AArgs[I].Kind = tkInterface) and (Params[I].ParamType.TypeKind = tkInterface) then
            begin
              Args[I] := AArgs[I];
              Continue;
            end;
            
            if (AArgs[I].Kind = tkClass) and (Params[I].ParamType.TypeKind = tkClass) then
            begin
              Args[I] := AArgs[I];
              Continue;
            end;

            Matched := False;
            Break;
          end;
          
          if (AArgs[I].Kind = tkRecord) and (AArgs[I].TypeInfo <> Params[I].ParamType.Handle) then
          begin
             Matched := False;
             Break;
          end;
          
          Args[I] := AArgs[I];
        end;

        if not Matched then
          Continue;
        
        if Length(Params) = Length(AArgs) then
        begin
          // If we find a constructor, we prefer the one from the most derived class
          if BestMethod = nil then
          begin
            BestMethod := Method;
            BestArgs := Args;
          end
          else if Method.Parent.Handle = TypeObj.Handle then
          begin
            // Current class constructor ALWAYS wins over inherited ones
            BestMethod := Method;
            BestArgs := Args;
          end;
        end;
      end;
    end;

    if BestMethod <> nil then
    begin
       Result := BestMethod.Invoke(AClass, BestArgs).AsObject;
       Exit;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for class %s', [AClass.ClassName]);
  finally
    Context.Free;
  end;
end;

// 2. Pure DI Instantiation (Greedy)
class function TActivator.CreateInstance(AProvider: IServiceProvider; AClass: TClass): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  ResolvedService: TValue;
  
  // Best match tracking
  BestMethod: TRttiMethod;
  BestArgs: TArray<TValue>;
  MaxParams: Integer;
  HasServiceConstructorAttr: Boolean;
  TargetClass: TClass;
begin
  TargetClass := ResolveImplementation(AClass);
  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(TargetClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI not found for %s', [TargetClass.ClassName]);

    BestMethod := nil;
    MaxParams := -1;

    // First pass: Look for [ServiceConstructor] attribute
    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        HasServiceConstructorAttr := False;
        for var Attr in Method.GetAttributes do
        begin
          if Attr is ServiceConstructorAttribute then
          begin
            HasServiceConstructorAttr := True;
            Break;
          end;
        end;
        
        if HasServiceConstructorAttr then
        begin
          // Try to resolve this constructor
          Params := Method.GetParameters;
          SetLength(Args, Length(Params));
          Matched := True;

          for I := 0 to High(Params) do
          begin
            if not TryResolveService(AProvider, Params[I].ParamType, ResolvedService) then
            begin
              Matched := False;
              Break;
            end;
            Args[I] := ResolvedService;
          end;

          if Matched then
          begin
            // Use this constructor (marked with [ServiceConstructor])
            Result := Method.Invoke(AClass, Args).AsObject;
            InjectFields(AProvider, Result, TypeObj);
            Exit;
          end;
        end;
      end;
    end;

    // Second pass: Greedy strategy (no [ServiceConstructor] found or it failed)
    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        SetLength(Args, Length(Params));
        Matched := True;
        for I := 0 to High(Params) do
        begin
          if not TryResolveService(AProvider, Params[I].ParamType, ResolvedService) then
          begin
            Matched := False;
            Break;
          end;
          Args[I] := ResolvedService;
        end;

        if Matched then
        begin
          // Greedy selection: prefer constructor with MORE parameters.
          // If parameters are equal, prefer the one from the most derived class (Target class).
          if (Length(Params) > MaxParams) or 
             ((Length(Params) = MaxParams) and (Method.Parent.Handle = TypeObj.Handle)) then
          begin
            MaxParams := Length(Params);
            BestMethod := Method;
            BestArgs := Args;
          end;
        end;
      end;
    end;

    if BestMethod <> nil then
    begin
      Result := BestMethod.Invoke(AClass, BestArgs).AsObject;
      InjectFields(AProvider, Result, TypeObj);
    end
    else
    begin
      // ERROR: No suitable constructor found (or dependencies missing)
      // Do NOT fallback to TObject.Create arbitrarily.
      raise EArgumentException.CreateFmt('TActivator: No satisfiable constructor found for %s. Check if all dependencies are registered.', [AClass.ClassName]);
    end;
  finally
    Context.Free;
  end;
end;

// 3. Hybrid Instantiation (Manual Args + DI)
class function TActivator.CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  ResolvedService: TValue;
  TargetClass: TClass;
begin
  TargetClass := ResolveImplementation(AClass);
  // If no args provided, delegate to Pure DI overload
  if Length(AArgs) = 0 then
    Exit(CreateInstance(AProvider, TargetClass));

  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(TargetClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI not found for %s', [TargetClass.ClassName]);

    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        
        // Must have at least enough params for explicit args
        if Length(Params) < Length(AArgs) then
          Continue;
          
        SetLength(Args, Length(Params));
        Matched := True;

        for I := 0 to High(Params) do
        begin
          // 1. Check explicit args (positional)
          if I < Length(AArgs) then
          begin
             Args[I] := AArgs[I];
             Continue;
          end;

          // 2. Resolve remaining from DI
          if not TryResolveService(AProvider, Params[I].ParamType, ResolvedService) then
          begin
            Matched := False;
            Break;
          end;
          Args[I] := ResolvedService;
        end;

        if Matched then
        begin
          Result := Method.Invoke(AClass, Args).AsObject;
          InjectFields(AProvider, Result, TypeObj);
          Exit;
        end;
      end;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for %s using Hybrid Injection', [AClass.ClassName]);
  finally
    Context.Free;
  end;
end;

class function TActivator.CreateInstance(AProvider: IServiceProvider; AType: PTypeInfo): TValue;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  ServiceType: TServiceType;
  ElementType: PTypeInfo;
  KeyType, ValueType: PTypeInfo;
begin
  if AType = nil then
    Exit(TValue.Empty);

  if AType.Kind = tkClass then
    Exit(TValue.From(CreateInstance(AProvider, AType.TypeData.ClassType)));

  if AType.Kind = tkInterface then
  begin
    Context := TRttiContext.Create;
    try
      RttiType := Context.GetType(AType);
      
      // 1. Try explicit mapping
      var RegisteredImpl: TClass;
      if FInterfaceDefaultImpl.TryGetValue(AType, RegisteredImpl) then
      begin
        var Instance := CreateInstance(AProvider, RegisteredImpl);
        var Intf: IInterface;
        if Instance.GetInterface(TRttiInterfaceType(RttiType).GUID, Intf) then
          TValue.Make(@Intf, AType, Result)
        else
          Result := TValue.From(Instance);
        Exit;
      end;

      // 2. Try to resolve via DI
      if AProvider <> nil then
      begin
        var Guid := TRttiInterfaceType(RttiType).GUID;
        if Guid <> TGUID.Empty then
        begin
          ServiceType := TServiceType.FromInterface(Guid);
          var Intf := AProvider.GetServiceAsInterface(ServiceType);
          if Intf <> nil then
          begin
            TValue.Make(@Intf, AType, Result);
            Exit;
          end;
        end;
      end;

      // 2. Fallback for Collections (IList/IEnumerable)
      if IsListType(AType) then
      begin
        ElementType := GetListElementType(AType);
        if ElementType = nil then
          raise EArgumentException.CreateFmt('TActivator: Could not determine element type for %s', [string(AType^.Name)]);

        var ImplRtti: TRttiType;
        var TypeName := string(AType^.Name);
        var ElementTypeName := string(ElementType^.Name);
        
        // Create implementation name from interface name (e.g., IList<T> -> TList<T>)
        var ImplName := TypeName.Replace('IList<', 'TList<').Replace('IEnumerable<', 'TList<');
        
        ImplRtti := Context.FindType(ImplName);
        if ImplRtti = nil then
          ImplRtti := Context.FindType('Dext.Collections.' + ImplName);

        // Strategy B: Scan all types for ANY TList<ElementType> or TSmartList<ElementType>
        if ImplRtti = nil then
        begin
          for var TmpType in Context.GetTypes do
          begin
            if TmpType.IsInstance and (TmpType.Name.StartsWith('TList<') or TmpType.Name.StartsWith('TSmartList<')) then
            begin
               var AddM := TmpType.GetMethod('Add');
               if Assigned(AddM) and (Length(AddM.GetParameters) = 1) then
                 if AddM.GetParameters[0].ParamType.Handle = ElementType then
                 begin
                   ImplRtti := TmpType;
                   Break;
                 end;
            end;
          end;
        end;

        if (ImplRtti = nil) and (AType.Kind = tkClass) then
          ImplRtti := RttiType;

        if (ImplRtti <> nil) and (ImplRtti is TRttiInstanceType) then
        begin
            var TargetClass := TRttiInstanceType(ImplRtti).MetaclassType;
            var BestConstructor: TRttiMethod := nil;
            // Prefer parameterless constructor for collections
            for var Method in ImplRtti.GetMethods do
              if Method.IsConstructor then
              begin
                if (Length(Method.GetParameters) = 0) then 
                begin 
                  BestConstructor := Method; 
                  Break; 
                end;
                if (BestConstructor = nil) and (Length(Method.GetParameters) = 1) and 
                   (Method.GetParameters[0].ParamType.TypeKind = tkEnumeration) then
                  BestConstructor := Method;
              end;

            if BestConstructor <> nil then
            begin
              var Instance: TValue;
              if Length(BestConstructor.GetParameters) = 0 then 
                Instance := BestConstructor.Invoke(TargetClass, [])
              else 
                Instance := BestConstructor.Invoke(TargetClass, [TValue.FromOrdinal(TypeInfo(Boolean), 0)]); // OwnsObjects = False
                 
              if AType.Kind = tkInterface then
              begin
                var Intf: IInterface;
                if Instance.AsObject.GetInterface(TRttiInterfaceType(RttiType).GUID, Intf) then
                  TValue.Make(@Intf, AType, Result)
                else 
                  Result := Instance;
              end
              else 
                Result := Instance;
              Exit;
            end;
        end;
      end;

      // 3. Fallback for IDictionary
      if IsDictionaryType(AType) then
      begin
        KeyType := GetDictionaryKeyType(AType);
        ValueType := GetDictionaryValueType(AType);
        if (KeyType <> nil) and (ValueType <> nil) then
        begin
          var ImplRtti: TRttiType := nil;
          var KeyName := string(KeyType^.Name);
          var ValName := string(ValueType^.Name);
          
          for var TmpType in Context.GetTypes do
            if TmpType.IsInstance and TmpType.Name.StartsWith('TDictionary<') then
            begin
               var AddM := TmpType.GetMethod('Add');
               if Assigned(AddM) and (Length(AddM.GetParameters) = 2) then
                 if (AddM.GetParameters[0].ParamType.Handle = KeyType) and 
                    (AddM.GetParameters[1].ParamType.Handle = ValueType) then
                  begin
                    ImplRtti := TmpType;
                    Break;
                  end;
            end;

          if (ImplRtti <> nil) and (ImplRtti is TRttiInstanceType) then
          begin
            var TargetClass := TRttiInstanceType(ImplRtti).MetaclassType;
            var BestConstructor: TRttiMethod := nil;
            for var Method in ImplRtti.GetMethods do
              if Method.IsConstructor then
              begin
                if Length(Method.GetParameters) = 0 then begin BestConstructor := Method; Break; end;
                if (BestConstructor = nil) and (Length(Method.GetParameters) <= 3) then 
                  BestConstructor := Method;
              end;

            if BestConstructor <> nil then
            begin
              var CtorArgs: TArray<TValue>;
              SetLength(CtorArgs, Length(BestConstructor.GetParameters));
              for var J := 0 to High(CtorArgs) do CtorArgs[J] := TValue.Empty; 
              
              var Instance := BestConstructor.Invoke(TargetClass, CtorArgs);
              if AType.Kind = tkInterface then
              begin
                var Intf: IInterface;
                if Instance.AsObject.GetInterface(TRttiInterfaceType(RttiType).GUID, Intf) then
                  Result := TValue.From<IInterface>(Intf)
                else 
                  Result := Instance;
              end
              else 
                Result := Instance;
              Exit;
            end;
          end;
        end;
      end;
      
      raise EArgumentException.CreateFmt('TActivator: Cannot find a suitable implementation for interface %s. ' +
        'Ensure the implementation is registered in DI or use TArray<T> for automatic RTTI support in DTOs.', [AType.NameFld.ToString]);
    finally
      Context.Free;
    end;
  end;

  raise EArgumentException.CreateFmt('TActivator: Unsupported type for instantiation: %s', [AType.NameFld.ToString]);
end;

class function TActivator.IsListType(AType: PTypeInfo): Boolean;
var
  TypeName: string;
  Ctx: TRttiContext;
  RttiType: TRttiType;
  IntfType: TRttiInterfaceType;
  ImplIntf: TRttiInterfaceType;
begin
  if AType = nil then Exit(False);
  TypeName := string(AType^.Name);
  
  Result := ((AType.Kind = tkClass) or (AType.Kind = tkInterface)) and
            (TypeName.Contains('IList<') or TypeName.Contains('IEnumerable<') or
             TypeName.Contains('TList<') or TypeName.Contains('TSmartList<') or
            (TypeName.EndsWith('List')));
            
  if Result then Exit;

  if (AType.Kind = tkClass) or (AType.Kind = tkInterface) then
  begin
    Ctx := TRttiContext.Create;
    try
      RttiType := Ctx.GetType(AType);
      
      if RttiType is TRttiInterfaceType then
      begin
        IntfType := TRttiInterfaceType(RttiType);
        while IntfType <> nil do
        begin
          if IntfType.Name.Contains('IList<') or IntfType.Name.Contains('IEnumerable<') then
            Exit(True);
          if IntfType.BaseType is TRttiInterfaceType then
            IntfType := TRttiInterfaceType(IntfType.BaseType)
          else
            IntfType := nil;
        end;
      end
      else if RttiType is TRttiInstanceType then
      begin
        for ImplIntf in TRttiInstanceType(RttiType).GetImplementedInterfaces do
        begin
          if ImplIntf.Name.Contains('IList<') or ImplIntf.Name.Contains('IEnumerable<') then
            Exit(True);
        end;
      end;

      if RttiType <> nil then
      begin
        for var Method in RttiType.GetMethods do
          if (Method.Name = 'Add') and (Length(Method.GetParameters) = 1) then
            Exit(True);
      end;
    finally
      Ctx.Free;
    end;
  end;
end;

class function TActivator.IsDictionaryType(AType: PTypeInfo): Boolean;
var
  TypeName: string;
begin
  if AType = nil then Exit(False);
  TypeName := string(AType^.Name);
  Result := (AType.Kind = tkInterface) and (TypeName.Contains('IDictionary<'));
end;

class function TActivator.GetDictionaryKeyType(AType: PTypeInfo): PTypeInfo;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  IntfType, ImplIntf: TRttiInterfaceType;
  
  function TryGetKeyType(ATgt: TRttiType): PTypeInfo;
  var M: TRttiMethod;
  begin
    Result := nil;
    if ATgt = nil then Exit;
    M := ATgt.GetMethod('ContainsKey');
    if Assigned(M) and (Length(M.GetParameters) = 1) then
      Result := M.GetParameters[0].ParamType.Handle;
  end;

begin
  Result := nil;
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AType);
    if RttiType = nil then Exit;
    
    Result := TryGetKeyType(RttiType);
    if Result <> nil then Exit;
    
    if RttiType is TRttiInterfaceType then
    begin
      IntfType := TRttiInterfaceType(RttiType);
      while IntfType <> nil do
      begin
        Result := TryGetKeyType(IntfType);
        if Result <> nil then Exit;
        if IntfType.BaseType is TRttiInterfaceType then IntfType := TRttiInterfaceType(IntfType.BaseType) else IntfType := nil;
      end;
    end
    else if RttiType is TRttiInstanceType then
    begin
      for ImplIntf in TRttiInstanceType(RttiType).GetImplementedInterfaces do
      begin
        Result := TryGetKeyType(ImplIntf);
        if Result <> nil then Exit;
      end;
    end;
  finally
    Context.Free;
  end;
end;

class function TActivator.GetDictionaryValueType(AType: PTypeInfo): PTypeInfo;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  IntfType, ImplIntf: TRttiInterfaceType;
  
  function TryGetValueType(ATgt: TRttiType): PTypeInfo;
  var M: TRttiMethod;
  begin
    Result := nil;
    if ATgt = nil then Exit;
    M := ATgt.GetMethod('TryGetValue');
    if Assigned(M) and (Length(M.GetParameters) = 2) then
      Result := M.GetParameters[1].ParamType.Handle;
  end;

begin
  Result := nil;
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AType);
    if RttiType = nil then Exit;
    
    Result := TryGetValueType(RttiType);
    if Result <> nil then Exit;
    
    if RttiType is TRttiInterfaceType then
    begin
      IntfType := TRttiInterfaceType(RttiType);
      while IntfType <> nil do
      begin
        Result := TryGetValueType(IntfType);
        if Result <> nil then Exit;
        if IntfType.BaseType is TRttiInterfaceType then IntfType := TRttiInterfaceType(IntfType.BaseType) else IntfType := nil;
      end;
    end
    else if RttiType is TRttiInstanceType then
    begin
      for ImplIntf in TRttiInstanceType(RttiType).GetImplementedInterfaces do
      begin
        Result := TryGetValueType(ImplIntf);
        if Result <> nil then Exit;
      end;
    end;
  finally
    Context.Free;
  end;
end;

class function TActivator.GetListElementType(AType: PTypeInfo): PTypeInfo;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  IntfType, ImplIntf: TRttiInterfaceType;
  
  function TryGetElementType(ATgt: TRttiType): PTypeInfo;
  var 
    M: TRttiMethod;
    P: TRttiProperty;
  begin
    Result := nil;
    if ATgt = nil then Exit;
    
    M := ATgt.GetMethod('GetItem');
    if Assigned(M) and (M.MethodKind = mkFunction) and (Length(M.GetParameters) = 1) then
      Exit(M.ReturnType.Handle);

    for M in ATgt.GetMethods do
    begin
      if (M.Name = 'Add') and (Length(M.GetParameters) = 1) then
        Exit(M.GetParameters[0].ParamType.Handle);
    end;
    
    P := ATgt.GetProperty('Items');
    if Assigned(P) then
      Exit(P.PropertyType.Handle);
  end;

begin
  Result := nil;
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AType);
    if RttiType = nil then Exit;
    
    Result := TryGetElementType(RttiType);
    if Result <> nil then Exit;
    
    if RttiType is TRttiInterfaceType then
    begin
      IntfType := TRttiInterfaceType(RttiType);
      while IntfType <> nil do
      begin
        Result := TryGetElementType(IntfType);
        if Result <> nil then Exit;
        if IntfType.BaseType is TRttiInterfaceType then IntfType := TRttiInterfaceType(IntfType.BaseType) else IntfType := nil;
      end;
    end
    else if RttiType is TRttiInstanceType then
    begin
      for ImplIntf in TRttiInstanceType(RttiType).GetImplementedInterfaces do
      begin
        Result := TryGetElementType(ImplIntf);
        if Result <> nil then Exit;
      end;
    end;
  finally
    Context.Free;
  end;
end;

class function TActivator.CreateInstance<T>: T;
begin
  Result := T(CreateInstance<T>([]));
end;

class function TActivator.CreateInstance<T>(const AArgs: array of TValue): T;
var
  Ctx: TRttiContext;
  TypeObj: TRttiType;
begin
  Ctx := TRttiContext.Create;
  try
    var TI := TypeInfo(T);
    if TI = nil then
      raise EArgumentException.Create('Type information not found for T');

    TypeObj := Ctx.GetType(TI);
    if (TypeObj <> nil) and (TypeObj.IsInstance) then
      Result := T(CreateInstance(TypeObj.AsInstance.MetaclassType, AArgs))
    else
      raise EArgumentException.Create('Type parameter T must be a class type');
  finally
    Ctx.Free;
  end;
end;

end.
