{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                            }
{    TToolsNode — nó padrão que executa as tool calls pendentes (ToolNode). }
{    Delega registro/despacho de tools para Dext.AI.MCP.Tools.             }
{    TMCPToolRegistry (já usado pelo MCP Server) em vez de reimplementar   }
{    o scan RTTI aqui — evita duas cópias divergentes da mesma lógica.     }
{                                                                           }
{***************************************************************************}
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
{           software distributed under the LICENSE is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Node.Tools;

interface

uses
  Dext.AI.Graph.Contracts,
  Dext.AI.Graph.State,
  Dext.AI.Agent.Contracts,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Protocol,
  System.JSON,
  System.SysUtils;

type
  TToolsNode = class
  private
    // TMCPToolRegistry já faz o scan RTTI de [MCPTool]/[MCPParam] e é dono
    // dos providers registrados (RegisterProvider assume ownership) — não
    // há double-free aqui porque TToolsNode nunca guarda os providers
    // diretamente, só repassa para o registry.
    FRegistry: TMCPToolRegistry;

    function ExecuteSingleTool(
      const AToolName, AArgsJson: string
    ): string;

    function ToolResultToText(const AResult: TMCPToolResult): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterProvider(AProvider: TMCPToolProvider);
    function GetToolSchemas: TArray<TToolSchema>;
    function GetAsHandler: TNodeHandler;
    function Execute(
      const AState: TAgentState;
      const ACtx:   TNodeContext
    ): TAgentState;

    property AsHandler: TNodeHandler read GetAsHandler;
  end;

implementation

{ TToolsNode }

constructor TToolsNode.Create;
begin
  inherited Create;
  FRegistry := TMCPToolRegistry.Create;
end;

destructor TToolsNode.Destroy;
begin
  FRegistry.Free;
  inherited;
end;

procedure TToolsNode.RegisterProvider(AProvider: TMCPToolProvider);
begin
  if AProvider <> nil then
    FRegistry.RegisterProvider(AProvider);
end;

function TToolsNode.GetAsHandler: TNodeHandler;
begin
  Result :=
    function(const AState: TAgentState; const ACtx: TNodeContext): TAgentState
    begin
      Result := Self.Execute(AState, ACtx);
    end;
end;

function TToolsNode.GetToolSchemas: TArray<TToolSchema>;
var
  Arr: TJSONArray;
  Item: TJSONObject;
  InputSchema: TJSONValue;
  Schema: TToolSchema;
  List: TArray<TToolSchema>;
  I: Integer;
begin
  Arr := FRegistry.BuildToolsArray;
  try
    SetLength(List, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Schema := Default(TToolSchema);
      Schema.Name        := Item.GetValue<string>('name', '');
      Schema.Description := Item.GetValue<string>('description', '');
      InputSchema := Item.GetValue('inputSchema');
      if InputSchema <> nil then
        Schema.InputSchema := InputSchema.ToJSON
      else
        Schema.InputSchema := '{}';
      List[I] := Schema;
    end;
    Result := List;
  finally
    Arr.Free;
  end;
end;

function TToolsNode.ToolResultToText(const AResult: TMCPToolResult): string;
var
  Item: TMCPContent;
  Parts: TStringBuilder;
begin
  Parts := TStringBuilder.Create;
  try
    for Item in AResult.Content do
      if Item.ContentType = mctText then
      begin
        if Parts.Length > 0 then
          Parts.Append(sLineBreak);
        Parts.Append(Item.TextValue);
      end;

    Result := Parts.ToString;
    if AResult.IsError then
      Result := '[Error] ' + Result;
  finally
    Parts.Free;
  end;
end;

function TToolsNode.ExecuteSingleTool(
  const AToolName, AArgsJson: string
): string;
var
  Def: TMCPToolDef;
  JArgs: TJSONObject;
begin
  if not FRegistry.TryGetTool(AToolName, Def) then
    Exit('[Error: Tool not found: ' + AToolName + ']');

  JArgs := TJSONObject.ParseJSONValue(AArgsJson) as TJSONObject;
  if JArgs = nil then
    JArgs := TJSONObject.Create;
  try
    try
      // ResultCallback (rico) tem precedência sobre o Callback legado
      // (string) — mesma ordem usada em TMCPServer.HandleToolsCall.
      if Assigned(Def.ResultCallback) then
        Exit(ToolResultToText(Def.ResultCallback(JArgs)))
      else if Assigned(Def.Callback) then
        Exit(Def.Callback(JArgs))
      else
        Exit('[Error: Tool "' + AToolName + '" has no callback]');
    except
      on E: Exception do
        Exit('[Error] ' + E.Message);
    end;
  finally
    JArgs.Free;
  end;
end;

function TToolsNode.Execute(
  const AState: TAgentState;
  const ACtx: TNodeContext
): TAgentState;
var
  NewState: TAgentState;
  TC: TLLMToolCall;
  ToolResultText: string;
  Old: TAgentState;
begin
  NewState := AState;
  for TC in AState.PendingCalls do
  begin
    if Assigned(ACtx.Observer) then
      ACtx.Observer.OnToolCall(TC.Name, TC.ArgsJson);

    ToolResultText := ExecuteSingleTool(TC.Name, TC.ArgsJson);

    if Assigned(ACtx.Observer) then
      ACtx.Observer.OnToolResult(TC.Name, ToolResultText);

    Old := NewState;
    NewState := NewState.WithMessage(TLLMMessage.ToolResult(TC.Id, ToolResultText));
    if (Old <> AState) and (Old <> NewState) then
      Old.Free;
  end;

  Old := NewState;
  NewState := NewState.ClearPendingCalls;
  if (Old <> AState) and (Old <> NewState) then
    Old.Free;

  Result := NewState;
end;

end.
