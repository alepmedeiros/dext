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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-01-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Authentication;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetEncoding,
  System.SyncObjs;

type
  IAuthenticationProvider = interface
    ['{E1D2C3B4-A5B6-4C7D-8E9F-0A1B2C3D4E5F}']
    function GetHeaderValue: string;
  end;

  TBearerAuthProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FToken: string;
  public
    constructor Create(const AToken: string);
    function GetHeaderValue: string;
  end;

  TBasicAuthProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FUsername: string;
    FPassword: string;
  public
    constructor Create(const AUsername, APassword: string);
    function GetHeaderValue: string;
  end;

  TApiKeyAuthProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FKey: string;
    FValue: string;
  public
    constructor Create(const AKey, AValue: string);
    function GetHeaderValue: string;
    property Key: string read FKey;
  end;

  /// <summary>
  ///   OAuth 2.0 Client Credentials authentication provider (RFC 6749 Section 4.4).
  ///   Designed for machine-to-machine (M2M) communication where no user context is needed.
  ///   Automatically fetches and caches the access token, refreshing it when expired.
  /// </summary>
  /// <remarks>
  ///   Thread-safe: uses a critical section to protect concurrent token refresh.
  ///   The token is refreshed 30 seconds before actual expiration to avoid edge cases.
  /// </remarks>
  TOAuth2ClientCredentialsProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FTokenUrl: string;
    FClientId: string;
    FClientSecret: string;
    FScope: string;
    FCachedToken: string;
    FExpiresAt: TDateTime;
    FLock: TCriticalSection;
    /// <summary>Fetches a new access token from the authorization server.</summary>
    procedure RefreshToken;
  public
    /// <summary>Creates an OAuth2 Client Credentials provider.</summary>
    /// <param name="ATokenUrl">The token endpoint URL (e.g. https://auth.example.com/oauth/token).</param>
    /// <param name="AClientId">The client identifier issued by the authorization server.</param>
    /// <param name="AClientSecret">The client secret issued by the authorization server.</param>
    /// <param name="AScope">Optional space-separated list of requested scopes.</param>
    constructor Create(const ATokenUrl, AClientId, AClientSecret: string;
      const AScope: string = '');
    destructor Destroy; override;
    function GetHeaderValue: string;
  end;

implementation

{ TBearerAuthProvider }

constructor TBearerAuthProvider.Create(const AToken: string);
begin
  inherited Create;
  FToken := AToken;
end;

function TBearerAuthProvider.GetHeaderValue: string;
begin
  Result := 'Bearer ' + FToken;
end;

{ TBasicAuthProvider }

constructor TBasicAuthProvider.Create(const AUsername, APassword: string);
begin
  inherited Create;
  FUsername := AUsername;
  FPassword := APassword;
end;

function TBasicAuthProvider.GetHeaderValue: string;
var
  Auth: string;
begin
  Auth := FUsername + ':' + FPassword;
  Result := 'Basic ' + TNetEncoding.Base64.Encode(Auth).Replace(#13#10, '');
end;

{ TApiKeyAuthProvider }

constructor TApiKeyAuthProvider.Create(const AKey, AValue: string);
begin
  inherited Create;
  FKey := AKey;
  FValue := AValue;
end;

function TApiKeyAuthProvider.GetHeaderValue: string;
begin
  Result := FValue;
end;

{ TOAuth2ClientCredentialsProvider }

constructor TOAuth2ClientCredentialsProvider.Create(const ATokenUrl, AClientId, AClientSecret: string;
  const AScope: string);
begin
  inherited Create;
  FTokenUrl := ATokenUrl;
  FClientId := AClientId;
  FClientSecret := AClientSecret;
  FScope := AScope;
  FCachedToken := '';
  FExpiresAt := 0;
  FLock := TCriticalSection.Create;
end;

destructor TOAuth2ClientCredentialsProvider.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TOAuth2ClientCredentialsProvider.RefreshToken;
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  Body: TStringStream;
  JsonStr: string;
  TokenStart, TokenEnd: Integer;
  ExpiresStart, ExpiresEnd: Integer;
  ExpiresIn: Integer;
  BodyContent: string;
begin
  HttpClient := THTTPClient.Create;
  try
    HttpClient.ContentType := 'application/x-www-form-urlencoded';

    BodyContent := 'grant_type=client_credentials' +
      '&client_id=' + TNetEncoding.URL.Encode(FClientId) +
      '&client_secret=' + TNetEncoding.URL.Encode(FClientSecret);
    if FScope <> '' then
      BodyContent := BodyContent + '&scope=' + TNetEncoding.URL.Encode(FScope);

    Body := TStringStream.Create(BodyContent, TEncoding.UTF8);
    try
      Response := HttpClient.Post(FTokenUrl, Body, nil,
        [TNetHeader.Create('Content-Type', 'application/x-www-form-urlencoded')]) as IHTTPResponse;

      if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
        raise Exception.CreateFmt(
          'OAuth2 token request failed (HTTP %d): %s',
          [Response.StatusCode, Response.ContentAsString]);

      // Lightweight JSON parsing (avoids dependency on Dext.Json for this low-level unit)
      JsonStr := Response.ContentAsString;

      // Extract access_token
      TokenStart := Pos('"access_token"', JsonStr);
      if TokenStart = 0 then
        raise Exception.Create('OAuth2 response missing access_token');
      TokenStart := Pos('"', JsonStr, TokenStart + Length('"access_token"'));
      TokenStart := Pos('"', JsonStr, TokenStart + 1) + 1;
      TokenEnd := Pos('"', JsonStr, TokenStart);
      FCachedToken := Copy(JsonStr, TokenStart, TokenEnd - TokenStart);

      // Extract expires_in (default 3600 if not present)
      ExpiresIn := 3600;
      ExpiresStart := Pos('"expires_in"', JsonStr);
      if ExpiresStart > 0 then
      begin
        ExpiresStart := Pos(':', JsonStr, ExpiresStart) + 1;
        // Skip whitespace
        while (ExpiresStart <= Length(JsonStr)) and (JsonStr[ExpiresStart] = ' ') do
          Inc(ExpiresStart);
        ExpiresEnd := ExpiresStart;
        while (ExpiresEnd <= Length(JsonStr)) and CharInSet(JsonStr[ExpiresEnd], ['0'..'9']) do
          Inc(ExpiresEnd);
        ExpiresIn := StrToIntDef(Copy(JsonStr, ExpiresStart, ExpiresEnd - ExpiresStart), 3600);
      end;

      // Set expiration with 30-second safety margin
      FExpiresAt := IncSecond(Now, ExpiresIn - 30);
    finally
      Body.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

function TOAuth2ClientCredentialsProvider.GetHeaderValue: string;
begin
  FLock.Enter;
  try
    if (FCachedToken = '') or (Now >= FExpiresAt) then
      RefreshToken;
    Result := 'Bearer ' + FCachedToken;
  finally
    FLock.Leave;
  end;
end;

end.
