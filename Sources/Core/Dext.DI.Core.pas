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
{  Updated: 2025-12-10 - Refactored ownership model for explicit memory     }
{                        management. Interface-based services are managed   }
{                        by ARC, class-based services by explicit Free.     }
{                                                                           }
{***************************************************************************}
unit Dext.DI.Core;

interface

uses
  System.SysUtils, System.SyncObjs,
  Dext.Collections, Dext.Collections.Dict, Dext.DI.Interfaces;

type
  TDextServiceScope = class;

  /// <summary>
  ///   The service provider (DI container) that resolves service instances.
  ///   Manages two separate storage mechanisms:
  ///   - FSingletons/FScopedInstances: For class-based services (explicit Free)
  ///   - FSingletonInterfaces/FScopedInterfaces: For interface-based services (ARC)
  /// </summary>
  TDextServiceProvider = class(TInterfacedObject, IServiceProvider)
  private
    FDescriptors: IList<TServiceDescriptor>;
    
    // Class-based service storage (DI owns and frees these)
    FSingletons: IDictionary<string, TObject>;
    FScopedInstances: IDictionary<string, TObject>;
    
    // Interface-based service storage (ARC manages these)
    FSingletonInterfaces: IDictionary<string, IInterface>;
    FScopedInterfaces: IDictionary<string, IInterface>;
    
    FIsRootProvider: Boolean;
    FParentProvider: IServiceProvider;
    FLock: TCriticalSection;
    FOwnsDescriptors: Boolean;

    function CreateInstance(ADescriptor: TServiceDescriptor): TObject;
    function FindDescriptor(const AServiceType: TServiceType): TServiceDescriptor;
  public
    constructor Create(const ADescriptors: IList<TServiceDescriptor>); overload;
    constructor CreateScoped(AParent: IServiceProvider; const ADescriptors: IList<TServiceDescriptor>); overload;
    destructor Destroy; override;

    function GetService(const AServiceType: TServiceType): TObject;
    function GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
    function GetRequiredService(const AServiceType: TServiceType): TObject;
    function CreateScope: IServiceScope;
  end;

  TDextServiceScope = class(TInterfacedObject, IServiceScope)
  private
    FServiceProvider: IServiceProvider;
  public
    constructor Create(AServiceProvider: IServiceProvider);
    function GetServiceProvider: IServiceProvider;
  end;

  TDextServiceCollection = class(TInterfacedObject, IServiceCollection)
  private
    FDescriptors: IList<TServiceDescriptor>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    function GetDescriptors: IList<TServiceDescriptor>;
    function AddSingleton(const AServiceType: TServiceType;
                         const AImplementationClass: TClass;
                         const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload;
    
    function AddSingleton(const AServiceType: TServiceType;
                         AInstance: TObject): IServiceCollection; overload;

    function AddTransient(const AServiceType: TServiceType;
                          const AImplementationClass: TClass;
                          const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection;

    function AddScoped(const AServiceType: TServiceType;
                       const AImplementationClass: TClass;
                       const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection;

    procedure AddRange(const AOther: IServiceCollection);
    function BuildServiceProvider: IServiceProvider;
  end;

implementation

uses
  System.Rtti,
  System.TypInfo,
  Dext.Core.Activator;

{ TDextServiceCollection }

constructor TDextServiceCollection.Create;
begin
  inherited Create;
  FDescriptors := TCollections.CreateList<TServiceDescriptor>(True);
  FLock := TCriticalSection.Create;
end;

destructor TDextServiceCollection.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TDextServiceCollection.GetDescriptors: IList<TServiceDescriptor>;
begin
  Result := FDescriptors;
end;

function TDextServiceCollection.AddSingleton(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Descriptor: TServiceDescriptor;
begin
  FLock.Enter;
  try
    Descriptor := TServiceDescriptor.Create(
      AServiceType, AImplementationClass, TServiceLifetime.Singleton, AFactory);
    FDescriptors.Add(Descriptor);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

// Instance registration overload - register pre-created singleton
function TDextServiceCollection.AddSingleton(const AServiceType: TServiceType;
  AInstance: TObject): IServiceCollection;
var
  Descriptor: TServiceDescriptor;
begin
  FLock.Enter;
  try
    Descriptor := TServiceDescriptor.Create(
      AServiceType, nil, TServiceLifetime.Singleton, nil);
    Descriptor.Instance := AInstance;  // Set the pre-created instance
    FDescriptors.Add(Descriptor);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TDextServiceCollection.AddTransient(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Descriptor: TServiceDescriptor;
begin
  FLock.Enter;
  try
    Descriptor := TServiceDescriptor.Create(
      AServiceType, AImplementationClass, TServiceLifetime.Transient, AFactory);
    FDescriptors.Add(Descriptor);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TDextServiceCollection.AddScoped(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Descriptor: TServiceDescriptor;
begin
  FLock.Enter;
  try
    Descriptor := TServiceDescriptor.Create(
      AServiceType, AImplementationClass, TServiceLifetime.Scoped, AFactory);
    FDescriptors.Add(Descriptor);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

procedure TDextServiceCollection.AddRange(const AOther: IServiceCollection);
var
  OtherColl: TDextServiceCollection;
  Desc: TServiceDescriptor;
begin
  if Assigned(AOther) and (TObject(AOther) is TDextServiceCollection) then
  begin
    OtherColl := TDextServiceCollection(TObject(AOther));
    FLock.Enter;
    try
      for Desc in OtherColl.FDescriptors do
        FDescriptors.Add(Desc.Clone);
    finally
      FLock.Leave;
    end;
  end;
end;

function TDextServiceCollection.BuildServiceProvider: IServiceProvider;
begin
  Result := TDextServiceProvider.Create(FDescriptors);
end;

{ TDextServiceProvider }

constructor TDextServiceProvider.Create(const ADescriptors: IList<TServiceDescriptor>);
var
  Desc: TServiceDescriptor;
begin
  inherited Create;
  // Clone descriptors so the provider owns its own copies.
  // This is critical: factory closures in descriptors capture interface references
  // (like IConfiguration) that MUST be released when the provider is destroyed.
  FDescriptors := TCollections.CreateList<TServiceDescriptor>(True);
  for Desc in ADescriptors do
    FDescriptors.Add(Desc.Clone);
  FOwnsDescriptors := True;

  // Class-based storage (DI owns these objects)
  FSingletons := TCollections.CreateDictionary<string, TObject>;
  FScopedInstances := TCollections.CreateDictionary<string, TObject>;
  
  // Interface-based storage (ARC owns these objects)
  FSingletonInterfaces := TCollections.CreateDictionary<string, IInterface>;
  FScopedInterfaces := TCollections.CreateDictionary<string, IInterface>;
  
  FLock := TCriticalSection.Create;
  FIsRootProvider := True;
  FParentProvider := nil;
end;

constructor TDextServiceProvider.CreateScoped(AParent: IServiceProvider; 
  const ADescriptors: IList<TServiceDescriptor>);
var
  Desc: TServiceDescriptor;
begin
  inherited Create;
  FDescriptors := TCollections.CreateList<TServiceDescriptor>(False);
  for Desc in ADescriptors do
    FDescriptors.Add(Desc);
  FOwnsDescriptors := True;

  // Scoped providers don't manage singletons - they delegate to parent
  FSingletons := nil;
  FSingletonInterfaces := nil;
  
  // But they do manage scoped instances
  FScopedInstances := TCollections.CreateDictionary<string, TObject>;
  FScopedInterfaces := TCollections.CreateDictionary<string, IInterface>;
  
  FLock := TCriticalSection.Create;
  FIsRootProvider := False;
  FParentProvider := AParent;
end;

destructor TDextServiceProvider.Destroy;
begin
  // === SINGLETON CLEANUP (only for root provider) ===
  if FIsRootProvider then
  begin
    // 1. Free class-based singletons (non-TInterfacedObject)
    if Assigned(FSingletons) then
    begin
      for var Pair in FSingletons do
      begin
        Pair.Value.Free;
      end;
      FSingletons := nil;
    end;
    
    // 2. Clear interface-based singletons (ARC manages)
    FSingletonInterfaces := nil;
  end;

  // === SCOPED CLEANUP ===
  // Scoped providers or root provider clearing temporary scoped items used for resolution?
  // Actually usually only TServiceScope calls this when it's destroyed.
  if Assigned(FScopedInstances) then
  begin
    for var Pair in FScopedInstances do
    begin
       Pair.Value.Free;
    end;
    FScopedInstances := nil;
  end;
  
  // 2. Clear interface-based scoped instances (ARC)
  FScopedInterfaces := nil;

  FLock.Free;
  
  if FOwnsDescriptors then
    FDescriptors := nil;

  inherited Destroy;
end;

function TDextServiceProvider.CreateScope: IServiceScope;
var
  ScopedProvider: IServiceProvider;
begin
  ScopedProvider := TDextServiceProvider.CreateScoped(Self, FDescriptors);
  Result := TDextServiceScope.Create(ScopedProvider);
end;

function TDextServiceProvider.FindDescriptor(const AServiceType: TServiceType): TServiceDescriptor;
var
  Descriptor: TServiceDescriptor;
begin
  for Descriptor in FDescriptors do
  begin
    if Descriptor.ServiceType = AServiceType then
      Exit(Descriptor);
  end;
  Result := nil;
end;

function TDextServiceProvider.CreateInstance(ADescriptor: TServiceDescriptor): TObject;
begin
  // Check if descriptor has pre-created instance (instance registration)
  if Assigned(ADescriptor.Instance) then
    Result := ADescriptor.Instance
  else if Assigned(ADescriptor.Factory) then
    Result := ADescriptor.Factory(Self)
  else
    Result := TActivator.CreateInstance(Self, ADescriptor.ImplementationClass);
end;

function TDextServiceProvider.GetService(const AServiceType: TServiceType): TObject;
var
  Descriptor: TServiceDescriptor;
  Key: string;
  Instance: TObject;
  Intf: IInterface;
begin
  // Special handling for IServiceProvider to return Self without dictionary cycle
  if AServiceType.IsInterface and IsEqualGUID(AServiceType.AsInterface, IServiceProvider) then
    Exit(TObject(Self));

  Descriptor := FindDescriptor(AServiceType);
  if not Assigned(Descriptor) then
    Exit(nil);

  Key := AServiceType.ToString;

  FLock.Enter;
  try
    case Descriptor.Lifetime of
      TServiceLifetime.Singleton:
      begin
        if FIsRootProvider then
        begin
          // Check both dictionaries for existing instance
          if FSingletonInterfaces.TryGetValue(Key, Intf) then
            Result := TObject(Intf)
          else if FSingletons.TryGetValue(Key, Instance) then
            Result := Instance
          else
          begin
            // Create new instance
            Instance := CreateInstance(Descriptor);
            
            // Store in appropriate dictionary based on type
            if Instance is TInterfacedObject then
              FSingletonInterfaces.Add(Key, Instance as TInterfacedObject)
            else
              FSingletons.Add(Key, Instance);
            
            Result := Instance;
          end;
        end
        else
          Result := FParentProvider.GetService(AServiceType);
      end;

      TServiceLifetime.Scoped:
      begin
        if not FScopedInstances.TryGetValue(Key, Instance) then
        begin
          Instance := CreateInstance(Descriptor);
          FScopedInstances.Add(Key, Instance);
        end;
        Result := Instance;
      end;

      TServiceLifetime.Transient:
        Result := CreateInstance(Descriptor);
    else
      Result := nil;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDextServiceProvider.GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
var
  Descriptor: TServiceDescriptor;
  Key: string;
  Intf: IInterface;
  Obj: TObject;
begin
  // Special handling for IServiceProvider to return Self without dictionary cycle
  if AServiceType.IsInterface and IsEqualGUID(AServiceType.AsInterface, IServiceProvider) then
    Exit(Self);

  Descriptor := FindDescriptor(AServiceType);
  if not Assigned(Descriptor) then
    Exit(nil);

  Key := AServiceType.ToString;

  FLock.Enter;
  try
    case Descriptor.Lifetime of
      TServiceLifetime.Singleton:
      begin
        if FIsRootProvider then
        begin
          if not FSingletonInterfaces.TryGetValue(Key, Intf) then
          begin
            Obj := CreateInstance(Descriptor);
            if not Supports(Obj, AServiceType.AsInterface, Intf) then
            begin
              Obj.Free;
              raise EDextDIException.CreateFmt('Service %s does not implement interface %s',
                [Obj.ClassName, GUIDToString(AServiceType.AsInterface)]);
            end;
            FSingletonInterfaces.Add(Key, Intf);
            // Note: The object is now owned by ARC via the interface reference
          end;
          Result := Intf;
        end
        else
          Result := FParentProvider.GetServiceAsInterface(AServiceType);
      end;

      TServiceLifetime.Scoped:
      begin
        if not FScopedInterfaces.TryGetValue(Key, Intf) then
        begin
          Obj := CreateInstance(Descriptor);
          if not Supports(Obj, AServiceType.AsInterface, Intf) then
          begin
            Obj.Free;
            raise EDextDIException.CreateFmt('Service %s does not implement interface %s',
              [Obj.ClassName, GUIDToString(AServiceType.AsInterface)]);
          end;
          FScopedInterfaces.Add(Key, Intf);
        end;
        Result := Intf;
      end;

      TServiceLifetime.Transient:
      begin
        Obj := CreateInstance(Descriptor);
        if not Supports(Obj, AServiceType.AsInterface, Intf) then
        begin
          Obj.Free;
          raise EDextDIException.CreateFmt('Service %s does not implement interface %s',
            [Obj.ClassName, GUIDToString(AServiceType.AsInterface)]);
        end;
        Result := Intf;
      end;
    else
      Result := nil;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDextServiceProvider.GetRequiredService(const AServiceType: TServiceType): TObject;
begin
  Result := GetService(AServiceType);
  if not Assigned(Result) then
    raise EDextDIException.CreateFmt('Required service not found: %s', [AServiceType.ToString]);
end;

{ TDextServiceScope }

constructor TDextServiceScope.Create(AServiceProvider: IServiceProvider);
begin
  inherited Create;
  FServiceProvider := AServiceProvider;
end;

function TDextServiceScope.GetServiceProvider: IServiceProvider;
begin
  Result := FServiceProvider;
end;

initialization
  TDextDIFactory.CreateServiceCollectionFunc := 
    function: IServiceCollection
    begin
      Result := TDextServiceCollection.Create;
    end;

end.
