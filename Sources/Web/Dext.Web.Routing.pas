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
unit Dext.Web.Routing;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces;
  // Note: We don't import Versioning here to avoid circular dep if possible, 
  // or we define IApiVersionReader in Interfaces? 
  // For now, let's assume simple string matching or header reading inside logic if we pass Context.
  // Actually, we can just extract version in Middleware and pass it?
  // No, the interface change allows passing Context.
  
type
  // Forward delcaration if needed, but IApiVersionReader is in another unit.
  // Let's rely on manually checking context headers/query for now to minimize dependencies,
  // OR assume the Caller (Middleware) passes the Version string?
  // Ideally: FindMatchingRoute(Context).

  TRouteSegment = record
  public
    IsLiteral: Boolean;
    Text: string;
  end;

  TRoutePattern = class
  private
    FPattern: string;
    FSegments: TArray<TRouteSegment>;
    FParameterNames: TArray<string>;
    procedure ParseSegments(const APattern: string);
  public
    constructor Create(const APattern: string);
    function Match(const APath: string; out AParams: TRouteValueDictionary): Boolean;
    property Pattern: string read FPattern;
    property ParameterNames: TArray<string> read FParameterNames;
  end;

  TRouteDefinition = class
  private
    FMethod: string;
    FPath: string;
    FHandler: TRequestDelegate;
    FPattern: TRoutePattern;
    FMetadata: TEndpointMetadata;
  public
    constructor Create(const AMethod, APath: string; AHandler: TRequestDelegate);
    destructor Destroy; override;
    property Method: string read FMethod;
    property Path: string read FPath;
    property Handler: TRequestDelegate read FHandler;
    property Pattern: TRoutePattern read FPattern;
    property Metadata: TEndpointMetadata read FMetadata write FMetadata;
  end;

  IRouteMatcher = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function FindMatchingRoute(const AContext: IHttpContext;
      out AHandler: TRequestDelegate;
      out ARouteParams: TRouteValueDictionary;
      out AMetadata: TEndpointMetadata): Boolean;
  end;

  TRouteMatcher = class(TInterfacedObject, IRouteMatcher)
  private
    FRoutes: IList<TRouteDefinition>;
    function GetRequestedApiVersion(const AContext: IHttpContext): string;
    function IsVersionMatch(const RequestedVersion: string; const SupportedVersions: TArray<string>): Boolean;
  public
    constructor Create(const ARoutes: IList<TRouteDefinition>);
    destructor Destroy; override;
    function FindMatchingRoute(const AContext: IHttpContext;
      out AHandler: TRequestDelegate;
      out ARouteParams: TRouteValueDictionary;
      out AMetadata: TEndpointMetadata): Boolean;
  end;

  ERouteException = class(Exception);

implementation

{ TRoutePattern }

constructor TRoutePattern.Create(const APattern: string);
begin
  inherited Create;
  FPattern := APattern;

  if APattern = '' then
    raise ERouteException.Create('Route pattern cannot be empty');

  ParseSegments(APattern);
end;

procedure TRoutePattern.ParseSegments(const APattern: string);
var
  Idx, StartIdx: Integer;
  InParam: Boolean;
begin
  FSegments := nil;
  FParameterNames := nil;
  
  StartIdx := 1;
  InParam := False;
  Idx := 1;
  while Idx <= Length(APattern) do
  begin
    if (not InParam) and (APattern[Idx] = '{') then
    begin
      // Flush literal
      if Idx > StartIdx then
      begin
        SetLength(FSegments, Length(FSegments) + 1);
        FSegments[High(FSegments)].IsLiteral := True;
        FSegments[High(FSegments)].Text := Copy(APattern, StartIdx, Idx - StartIdx);
      end;
      StartIdx := Idx + 1;
      InParam := True;
    end
    else if InParam and (APattern[Idx] = '}') then
    begin
      // Flush param
      if Idx > StartIdx then
      begin
        SetLength(FSegments, Length(FSegments) + 1);
        FSegments[High(FSegments)].IsLiteral := False;
        FSegments[High(FSegments)].Text := Copy(APattern, StartIdx, Idx - StartIdx);
        
        SetLength(FParameterNames, Length(FParameterNames) + 1);
        FParameterNames[High(FParameterNames)] := FSegments[High(FSegments)].Text;
      end;
      StartIdx := Idx + 1;
      InParam := False;
    end;
    Inc(Idx);
  end;
  
  if StartIdx <= Length(APattern) then
  begin
    if InParam then
      raise ERouteException.Create('Unclosed parameter in pattern');
    SetLength(FSegments, Length(FSegments) + 1);
    FSegments[High(FSegments)].IsLiteral := True;
    FSegments[High(FSegments)].Text := Copy(APattern, StartIdx, Length(APattern) - StartIdx + 1);
  end;
end;

function TRoutePattern.Match(const APath: string;
  out AParams: TRouteValueDictionary): Boolean;
var
  I: Integer;
  PathIdx: Integer;
  Seg: TRouteSegment;
  ValueStart, ValueLen: Integer;
begin
  AParams.Clear;
  PathIdx := 1;

  for I := 0 to High(FSegments) do
  begin
    Seg := FSegments[I];
    
    if Seg.IsLiteral then
    begin
      if Length(APath) - PathIdx + 1 < Length(Seg.Text) then
        Exit(False);
        
      if StrLIComp(PChar(APath) + PathIdx - 1, PChar(Seg.Text), Length(Seg.Text)) <> 0 then
        Exit(False);
        
      Inc(PathIdx, Length(Seg.Text));
    end
    else
    begin
      ValueStart := PathIdx;
      
      if I < High(FSegments) then
      begin
        while (PathIdx <= Length(APath)) and (APath[PathIdx] <> '/') do
        begin
          if FSegments[I+1].IsLiteral and (Length(FSegments[I+1].Text) > 0) then
          begin
            if (Length(APath) - PathIdx + 1 >= Length(FSegments[I+1].Text)) and
               (StrLIComp(PChar(APath) + PathIdx - 1, PChar(FSegments[I+1].Text), Length(FSegments[I+1].Text)) = 0) then
              Break;
          end;
          Inc(PathIdx);
        end;
      end
      else
      begin
        while (PathIdx <= Length(APath)) and (APath[PathIdx] <> '/') do
          Inc(PathIdx);
      end;
      
      ValueLen := PathIdx - ValueStart;
      if ValueLen = 0 then
        Exit(False);
        
      AParams.Add(Seg.Text, Copy(APath, ValueStart, ValueLen));
    end;
  end;
  
  if PathIdx <= Length(APath) then
    Exit(False);
    
  Result := True;
end;

{ TRouteDefinition }

constructor TRouteDefinition.Create(const AMethod, APath: string; AHandler: TRequestDelegate);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;
  FHandler := AHandler;
  
  if APath.Contains('{') then
    FPattern := TRoutePattern.Create(APath)
  else
    FPattern := nil;

  FMetadata.Method := AMethod;
  FMetadata.Path := APath;
end;

destructor TRouteDefinition.Destroy;
begin
  if FPattern <> nil then
  begin
    FPattern.Free;
    FPattern := nil;
  end;
  inherited;
end;

{ TRouteMatcher }

constructor TRouteMatcher.Create(const ARoutes: IList<TRouteDefinition>);
var
  Route: TRouteDefinition;
  NewRoute: TRouteDefinition;
begin
  inherited Create;
  FRoutes := TCollections.CreateList<TRouteDefinition>(True); // Owns objects
  
  // Clone routes to ensure thread safety and independence
  for Route in ARoutes do
  begin
    NewRoute := TRouteDefinition.Create(Route.Method, Route.Path, Route.Handler);
    NewRoute.Metadata := Route.Metadata;
    FRoutes.Add(NewRoute);
  end;
end;

destructor TRouteMatcher.Destroy;
begin
  FRoutes := nil;
  inherited;
end;

function TRouteMatcher.GetRequestedApiVersion(const AContext: IHttpContext): string;
begin
  // First check Query string, then Header
  if AContext.Request.Query.TryGetValue('api-version', Result) then
    Exit;
    
  if AContext.Request.Headers.TryGetValue('X-Version', Result) then
    Exit;
    
  Result := '';
end;

function TRouteMatcher.IsVersionMatch(const RequestedVersion: string; const SupportedVersions: TArray<string>): Boolean;
var
  V: string;
begin
  // If no version requested, match anything that DOESN'T require a specific version?
  // Or match typically V1?
  // Policy: If route has NO versions defined, it matches any request (implicit neutral).
  // If route HAS versions, request MUST match one of them.
  
  if Length(SupportedVersions) = 0 then
    Exit(True); // Route is version neutral
    
  if RequestedVersion = '' then
  begin
    // If no version requested, do we match versioned routes?
    // Maybe default to '1.0' or reject?
    // For now: assume neutral match only if requested matches. 
    // If requested is empty, we only match neutral routes (Length=0 check matches).
    // What if we want default version?
    // Let's assume empty request only matches neutral routes.
    Exit(False); 
  end;
    
  for V in SupportedVersions do
    if SameText(V, RequestedVersion) then
      Exit(True);
      
  Result := False;
end;

function TRouteMatcher.FindMatchingRoute(const AContext: IHttpContext;
  out AHandler: TRequestDelegate;
  out ARouteParams: TRouteValueDictionary;
  out AMetadata: TEndpointMetadata): Boolean;
var
  Route: TRouteDefinition;
  Method, Path, RequestVersion: string;
  LiteralCandidates, PatternCandidates: IList<TRouteDefinition>;
  BestMatch: TRouteDefinition;
begin
  ARouteParams.Clear;
  Result := False;
  Method := AContext.Request.Method;
  Path := AContext.Request.Path;
  RequestVersion := GetRequestedApiVersion(AContext);
  
  // Normalize path: remove trailing slash (except for root "/")
  if (Length(Path) > 1) and (Path[Length(Path)] = '/') then
    Path := Copy(Path, 1, Length(Path) - 1);
  
  // Separate into literal and pattern candidates
  // RULE: Literal routes (exact match) take priority over pattern routes (with {params})
  LiteralCandidates := TCollections.CreateList<TRouteDefinition>;
  PatternCandidates := TCollections.CreateList<TRouteDefinition>;
  try
    for Route in FRoutes do
    begin
        if (Route.Method = Method) then
        begin
             if (Route.Pattern = nil) and (Route.Path = Path) then
               LiteralCandidates.Add(Route)
              else if (Route.Pattern <> nil) and Route.Pattern.Match(Path, ARouteParams) then
             begin
               // Route matches with pattern. Clean up the params if we decide to keep searching. 
               // Actually we keep looking. But PatternCandidates keeps the route.
               ARouteParams.Clear;
               PatternCandidates.Add(Route);
             end;
        end;
    end;
    
    // Select Best Candidate based on Version
    // Priority: Literal routes first, then pattern routes
    BestMatch := nil;
    
    // 1. Try literal candidates first
    for Route in LiteralCandidates do
    begin
      if IsVersionMatch(RequestVersion, Route.Metadata.ApiVersions) then
      begin
        BestMatch := Route;
        Break;
      end;
    end;
    
    // 2. If no literal match, try pattern candidates
    if BestMatch = nil then
    begin
      for Route in PatternCandidates do
      begin
        if IsVersionMatch(RequestVersion, Route.Metadata.ApiVersions) then
        begin
          BestMatch := Route;
          Break;
        end;
      end;
    end;
    
    // 3. If still no match and RequestVersion is empty, try neutral routes (literal first)
    if (BestMatch = nil) and (RequestVersion = '') then
    begin
      for Route in LiteralCandidates do
        if Length(Route.Metadata.ApiVersions) = 0 then
        begin
          BestMatch := Route;
          Break;
        end;
      
      if BestMatch = nil then
        for Route in PatternCandidates do
          if Length(Route.Metadata.ApiVersions) = 0 then
          begin
            BestMatch := Route;
            Break;
          end;
    end;
    
    if BestMatch <> nil then
    begin
        AHandler := BestMatch.Handler;
        AMetadata := BestMatch.Metadata;
        
        // Re-generate params for the winner
        if BestMatch.Pattern <> nil then
           BestMatch.Pattern.Match(Path, ARouteParams);
           
        Result := True;
    end;
    
  finally
    LiteralCandidates := nil;
    PatternCandidates := nil;
  end;
end;

end.
