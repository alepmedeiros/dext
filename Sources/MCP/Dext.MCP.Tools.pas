{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Description:                                                             }
{    MCP Tool registry and fluent builder.                                  }
{                                                                           }
{    Usage (resumo):                                                        }
{      Server.Tool('my-tool')                                               }
{        .Description('Does something useful')                              }
{        .Param('query', 'Search term', ptString)                           }
{        .Param('limit', 'Max results', ptInteger, False)                   }
{        .OnCall(function(Args: TJSONObject): string                        }
{          begin                                                            }
{            Result := 'ok';                                                }
{          end);                                                            }
{                                                                           }
{***************************************************************************}
unit Dext.MCP.Tools;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Dext.MCP.Protocol;

type
  TMCPToolRegistry = class;

  /// <summary>
  /// Fluent builder for configuring an MCP tool before registering it.
  /// Chain calls to Description / Param / OnCall.
  /// The tool is committed to the registry when OnCall is invoked.
  /// </summary>
  IMCPToolBuilder = interface
    ['{D1E2F3A4-B5C6-7890-ABCD-EF0123456789}']
    function Description(const AText: string): IMCPToolBuilder;
    function Param(const AName, ADesc: string;
      AType: TMCPParamType = ptString;
      ARequired: Boolean = True): IMCPToolBuilder;
    function OnCall(ACallback: TMCPToolCallback): IMCPToolBuilder;
  end;

  TMCPToolBuilder = class(TInterfacedObject, IMCPToolBuilder)
  private
    FDef: TMCPToolDef;
    FRegistry: TMCPToolRegistry; // weak ref — registry owns server lifetime
  public
    constructor Create(const AName: string; ARegistry: TMCPToolRegistry);

    function Description(const AText: string): IMCPToolBuilder;
    function Param(const AName, ADesc: string;
      AType: TMCPParamType = ptString;
      ARequired: Boolean = True): IMCPToolBuilder;
    function OnCall(ACallback: TMCPToolCallback): IMCPToolBuilder;
  end;

  /// <summary>
  /// Holds all registered MCP tools and generates their JSON Schema descriptors.
  /// </summary>
  TMCPToolRegistry = class
  private
    FTools: TDictionary<string, TMCPToolDef>;

    function BuildInputSchema(const Def: TMCPToolDef): TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Returns a fluent builder for a new tool with the given name.</summary>
    function Register(const AName: string): IMCPToolBuilder;

    /// <summary>Internal: called by TMCPToolBuilder.OnCall to commit the def.</summary>
    procedure Commit(const ADef: TMCPToolDef);

    /// <summary>Tries to find a tool by name. Returns False if not found.</summary>
    function TryGetTool(const AName: string; out ADef: TMCPToolDef): Boolean;

    /// <summary>
    /// Builds the JSON array for the tools/list response.
    /// Caller owns the returned TJSONArray.
    /// </summary>
    function BuildToolsArray: TJSONArray;

    function Count: Integer;
  end;

implementation

{ TMCPToolBuilder }

constructor TMCPToolBuilder.Create(const AName: string; ARegistry: TMCPToolRegistry);
begin
  inherited Create;
  FDef.Name     := AName;
  FRegistry     := ARegistry;
end;

function TMCPToolBuilder.Description(const AText: string): IMCPToolBuilder;
begin
  FDef.Description := AText;
  Result := Self;
end;

function TMCPToolBuilder.Param(const AName, ADesc: string;
  AType: TMCPParamType; ARequired: Boolean): IMCPToolBuilder;
var
  P: TMCPToolParam;
begin
  P := TMCPToolParam.Create(AName, ADesc, AType, ARequired);
  SetLength(FDef.Params, Length(FDef.Params) + 1);
  FDef.Params[High(FDef.Params)] := P;
  Result := Self;
end;

function TMCPToolBuilder.OnCall(ACallback: TMCPToolCallback): IMCPToolBuilder;
begin
  FDef.Callback := ACallback;
  FRegistry.Commit(FDef);
  Result := Self;
end;

{ TMCPToolRegistry }

constructor TMCPToolRegistry.Create;
begin
  inherited Create;
  FTools := TDictionary<string, TMCPToolDef>.Create;
end;

destructor TMCPToolRegistry.Destroy;
begin
  FTools.Free;
  inherited;
end;

function TMCPToolRegistry.Register(const AName: string): IMCPToolBuilder;
begin
  Result := TMCPToolBuilder.Create(AName, Self);
end;

procedure TMCPToolRegistry.Commit(const ADef: TMCPToolDef);
begin
  FTools.AddOrSetValue(ADef.Name, ADef);
end;

function TMCPToolRegistry.TryGetTool(const AName: string; out ADef: TMCPToolDef): Boolean;
begin
  Result := FTools.TryGetValue(AName, ADef);
end;

function TMCPToolRegistry.Count: Integer;
begin
  Result := FTools.Count;
end;

function TMCPToolRegistry.BuildInputSchema(const Def: TMCPToolDef): TJSONObject;
var
  Schema, Props, PropObj: TJSONObject;
  Required: TJSONArray;
  P: TMCPToolParam;
begin
  Schema := TJSONObject.Create;
  Schema.AddPair('type', 'object');

  Props := TJSONObject.Create;
  Required := TJSONArray.Create;

  for P in Def.Params do
  begin
    PropObj := TJSONObject.Create;
    PropObj.AddPair('type', P.TypeName);
    if P.Description <> '' then
      PropObj.AddPair('description', P.Description);
    Props.AddPair(P.Name, PropObj);

    if P.Required then
      Required.Add(P.Name);
  end;

  Schema.AddPair('properties', Props);

  if Required.Count > 0 then
    Schema.AddPair('required', Required)
  else
    Required.Free;

  Result := Schema;
end;

function TMCPToolRegistry.BuildToolsArray: TJSONArray;
var
  Arr: TJSONArray;
  Def: TMCPToolDef;
  ToolObj: TJSONObject;
begin
  Arr := TJSONArray.Create;

  for Def in FTools.Values do
  begin
    ToolObj := TJSONObject.Create;
    ToolObj.AddPair('name', Def.Name);
    ToolObj.AddPair('description', Def.Description);
    ToolObj.AddPair('inputSchema', BuildInputSchema(Def));
    Arr.Add(ToolObj);
  end;

  Result := Arr;
end;

end.
