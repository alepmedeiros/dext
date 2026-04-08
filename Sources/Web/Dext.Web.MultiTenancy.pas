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
{***************************************************************************}
unit Dext.Web.MultiTenancy;

interface

uses
  System.SysUtils, System.Classes, System.Rtti,
  Dext.Web.Interfaces, Dext.DI.Interfaces, Dext.Web.Middleware,
  Dext.Web.Core, Dext.MultiTenancy;

type
  ITenantResolutionStrategy = interface
    ['{C8E9D0A1-B2F3-4C5D-6E7F-8A9B0C1D2E3F}']
    function Resolve(const AContext: IHttpContext): string;
  end;

  ITenantStore = interface
    ['{631320AF-1279-4684-9075-C66946D58AEB}']
    function GetTenant(const AId: string): ITenant;
  end;

  TMultiTenancyMiddleware = class(TMiddleware)
  private
    FStrategy: ITenantResolutionStrategy;
    FStore: ITenantStore;
  public
    constructor Create(const AStrategy: ITenantResolutionStrategy; const AStore: ITenantStore);
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

implementation

{ TMultiTenancyMiddleware }

constructor TMultiTenancyMiddleware.Create(const AStrategy: ITenantResolutionStrategy; const AStore: ITenantStore);
begin
  inherited Create;
  FStrategy := AStrategy;
  FStore := AStore;
end;

procedure TMultiTenancyMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  LTenantId: string;
  LTenant: ITenant;
  LProvider: ITenantProvider;
begin
  if FStrategy <> nil then
  begin
    LTenantId := FStrategy.Resolve(AContext);
    if LTenantId <> '' then
    begin
      if FStore <> nil then
      begin
        LTenant := FStore.GetTenant(LTenantId);
        if LTenant <> nil then
        begin
          // Store in Context Items for easy access in views/controllers
          AContext.Items.AddOrSetValue('Tenant', TValue.From<ITenant>(LTenant));
          
          // Populate ITenantProvider if registered (Scoped service)
          if Supports(AContext.Services.GetService(TypeInfo(ITenantProvider)), ITenantProvider, LProvider) then
          begin
            LProvider.Tenant := LTenant;
          end;
        end;
      end;
    end;
  end;

  ANext(AContext);
end;

end.
