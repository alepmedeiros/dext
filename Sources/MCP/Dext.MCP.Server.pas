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
{    Native MCP (Model Context Protocol) server for the Dext Framework.    }
{                                                                           }
{    Implements:                                                             }
{      - JSON-RPC 2.0 message dispatch                                      }
{      - MCP methods: initialize, ping, tools/list, tools/call             }
{      - SSE transport: GET /sse  +  POST /message                          }
{      - Stdio transport (for Claude Desktop / direct process integration)  }
{                                                                           }
{    SSE transport flow:                                                    }
{      1. Client connects: GET /sse                                         }
{         Server responds with SSE stream and sends the endpoint event:     }
{           event: endpoint                                                 }
{           data: /message?sessionId=<uuid>                                 }
{                                                                           }
{      2. Client sends JSON-RPC: POST /message?sessionId=<uuid>             }
{         Server returns HTTP 202 Accepted immediately.                     }
{         JSON-RPC response is delivered through the SSE stream:            }
{           event: message                                                  }
{           data: <json-rpc-response>                                       }
{                                                                           }
{    Stdio transport flow (Claude Desktop):                                 }
{      Reads newline-delimited JSON-RPC from stdin, writes to stdout.       }
{                                                                           }
{***************************************************************************}
unit Dext.MCP.Server;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.SyncObjs,
  System.Generics.Collections,
  Dext.MCP.Protocol,
  Dext.MCP.Tools,
  Dext.Web.Interfaces,
  Dext.WebHost;

type
  TMCPTransport = (mtSSE, mtStdio);

  // -------------------------------------------------------------------------
  // TMCPSession: one connected SSE client
  // -------------------------------------------------------------------------

  /// <summary>
  /// Represents a single SSE client session.
  /// Messages enqueued here are delivered through the open SSE stream.
  /// Thread-safe: POST /message and the SSE loop run on different threads.
  /// </summary>
  TMCPSession = class
  private
    FId: string;
    FMessages: TQueue<string>;
    FLock: TCriticalSection;
    FClosed: Int64; // 0 = open, 1 = closed (atomic via TInterlocked)
  public
    constructor Create(const AId: string);
    destructor Destroy; override;

    /// <summary>Enqueues a message to be sent via SSE. Thread-safe.</summary>
    procedure Enqueue(const AMessage: string);

    /// <summary>Dequeues one message. Returns '' if empty. Thread-safe.</summary>
    function Dequeue: string;

    /// <summary>True if there are pending messages. Thread-safe.</summary>
    function HasMessages: Boolean;

    /// <summary>Marks the session as closed so the SSE loop exits.</summary>
    procedure Close;

    function IsClosed: Boolean;
    property Id: string read FId;
  end;

  // -------------------------------------------------------------------------
  // TMCPSessionManager: registry of all active SSE sessions
  // -------------------------------------------------------------------------

  TMCPSessionManager = class
  private
    FSessions: TObjectDictionary<string, TMCPSession>;
    FLock: TCriticalSection;
    FShuttingDown: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Creates a new session with a random UUID. Returns the new session.</summary>
    function CreateSession: TMCPSession;

    /// <summary>Looks up an existing session. Returns nil if not found.</summary>
    function GetSession(const AId: string): TMCPSession;

    /// <summary>Removes a session from the registry (called after SSE loop exits).</summary>
    procedure RemoveSession(const AId: string);

    /// <summary>Closes all sessions so every SSE loop exits cleanly.</summary>
    procedure CloseAll;

    function IsShuttingDown: Boolean;
  end;

  // -------------------------------------------------------------------------
  // TMCPServer: main entry point
  // -------------------------------------------------------------------------

  /// <summary>
  /// Native MCP server.
  ///
  /// Typical setup:
  ///   var Server := TMCPServer.Create('my-server');
  ///   Server.Tool('my-tool')
  ///     .Description('Fetches data')
  ///     .Param('query', 'Search text', ptString)
  ///     .OnCall(function(Args: TJSONObject): string
  ///       begin Result := '{"ok":true}'; end);
  ///   Server.Run(mtSSE, 'http://localhost:3031');
  /// </summary>
  TMCPServer = class
  private
    FName: string;
    FVersion: string;
    FRegistry: TMCPToolRegistry;
    FSessions: TMCPSessionManager;
    FHost: IWebHost;

    // ---- JSON-RPC dispatch ----
    function Dispatch(const Body: string): string;
    function HandleInitialize(const Id: TJSONValue; const Params: TJSONObject): string;
    function HandlePing(const Id: TJSONValue): string;
    function HandleToolsList(const Id: TJSONValue): string;
    function HandleToolsCall(const Id: TJSONValue; const Params: TJSONObject): string;

    // ---- HTTP route handlers ----
    procedure RouteSSE(Ctx: IHttpContext);
    procedure RouteMessage(Ctx: IHttpContext);

    // ---- Stdio loop ----
    procedure RunStdioLoop;

    // ---- Helpers ----
    class function ReadBody(Ctx: IHttpContext): string; static;
    class function NewSessionId: string; static;
    class function WrapTextContent(const Text: string): TJSONObject; static;
  public
    constructor Create(const AName: string; const AVersion: string = '1.0.0');
    destructor Destroy; override;

    /// <summary>
    /// Returns a fluent builder for registering a new tool.
    /// Chain .Description / .Param / .OnCall to complete registration.
    /// </summary>
    function Tool(const AName: string): IMCPToolBuilder;

    /// <summary>
    /// Starts the MCP server.
    ///   mtSSE   — HTTP server with SSE transport (non-blocking Start).
    ///   mtStdio — reads stdin / writes stdout in a blocking loop.
    /// </summary>
    procedure Run(ATransport: TMCPTransport = mtSSE;
      const AUrl: string = 'http://localhost:3031');

    /// <summary>Stops the SSE HTTP server. No-op for stdio transport.</summary>
    procedure Stop;

    property Name: string read FName;
    property Version: string read FVersion;
    property Registry: TMCPToolRegistry read FRegistry;
  end;

implementation

uses
  System.IOUtils,
  Winapi.Windows;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function StreamToString(AStream: TStream): string;
var
  SS: TStringStream;
begin
  if (AStream = nil) or (AStream.Size = 0) then
    Exit('');
  AStream.Position := 0;
  SS := TStringStream.Create('', TEncoding.UTF8);
  try
    SS.CopyFrom(AStream, AStream.Size);
    Result := SS.DataString;
  finally
    SS.Free;
  end;
end;

procedure WriteSSEEvent(const Response: IHttpResponse;
  const EventType, Data: string);
begin
  Response.Write('event: ' + EventType + #10);
  Response.Write('data: ' + Data + #10#10);
end;

procedure WriteSSEComment(const Response: IHttpResponse; const Comment: string);
begin
  Response.Write(': ' + Comment + #10#10);
end;

procedure ConfigureSSEResponse(const Response: IHttpResponse);
begin
  Response.SetContentType('text/event-stream');
  Response.AddHeader('Cache-Control', 'no-cache');
  Response.AddHeader('Connection', 'keep-alive');
  Response.AddHeader('X-Accel-Buffering', 'no');
  Response.AddHeader('Access-Control-Allow-Origin', '*');
end;

// ---------------------------------------------------------------------------
// TMCPSession
// ---------------------------------------------------------------------------

constructor TMCPSession.Create(const AId: string);
begin
  inherited Create;
  FId       := AId;
  FMessages := TQueue<string>.Create;
  FLock     := TCriticalSection.Create;
  FClosed   := 0;
end;

destructor TMCPSession.Destroy;
begin
  FLock.Free;
  FMessages.Free;
  inherited;
end;

procedure TMCPSession.Enqueue(const AMessage: string);
begin
  if TInterlocked.Read(FClosed) = 1 then Exit;
  FLock.Enter;
  try
    FMessages.Enqueue(AMessage);
  finally
    FLock.Leave;
  end;
end;

function TMCPSession.Dequeue: string;
begin
  if TInterlocked.Read(FClosed) = 1 then Exit('');
  FLock.Enter;
  try
    if FMessages.Count > 0 then
      Result := FMessages.Dequeue
    else
      Result := '';
  finally
    FLock.Leave;
  end;
end;

function TMCPSession.HasMessages: Boolean;
begin
  if TInterlocked.Read(FClosed) = 1 then Exit(False);
  FLock.Enter;
  try
    Result := FMessages.Count > 0;
  finally
    FLock.Leave;
  end;
end;

procedure TMCPSession.Close;
begin
  TInterlocked.Exchange(FClosed, 1);
end;

function TMCPSession.IsClosed: Boolean;
begin
  Result := TInterlocked.Read(FClosed) = 1;
end;

// ---------------------------------------------------------------------------
// TMCPSessionManager
// ---------------------------------------------------------------------------

constructor TMCPSessionManager.Create;
begin
  inherited Create;
  FSessions     := TObjectDictionary<string, TMCPSession>.Create([doOwnsValues]);
  FLock         := TCriticalSection.Create;
  FShuttingDown := False;
end;

destructor TMCPSessionManager.Destroy;
begin
  CloseAll;
  FLock.Enter;
  try
    FSessions.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

function TMCPSessionManager.CreateSession: TMCPSession;
var
  Session: TMCPSession;
  Id: string;
begin
  Id      := TMCPServer.NewSessionId;
  Session := TMCPSession.Create(Id);
  FLock.Enter;
  try
    FSessions.Add(Id, Session);
  finally
    FLock.Leave;
  end;
  Result := Session;
end;

function TMCPSessionManager.GetSession(const AId: string): TMCPSession;
begin
  FLock.Enter;
  try
    if not FSessions.TryGetValue(AId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TMCPSessionManager.RemoveSession(const AId: string);
begin
  FLock.Enter;
  try
    FSessions.Remove(AId);
  finally
    FLock.Leave;
  end;
end;

procedure TMCPSessionManager.CloseAll;
var
  Session: TMCPSession;
begin
  FShuttingDown := True;
  FLock.Enter;
  try
    for Session in FSessions.Values do
      Session.Close;
  finally
    FLock.Leave;
  end;
end;

function TMCPSessionManager.IsShuttingDown: Boolean;
begin
  Result := FShuttingDown;
end;

// ---------------------------------------------------------------------------
// TMCPServer — helpers
// ---------------------------------------------------------------------------

class function TMCPServer.ReadBody(Ctx: IHttpContext): string;
begin
  Result := StreamToString(Ctx.Request.Body);
end;

class function TMCPServer.NewSessionId: string;
begin
  Result := TGUID.NewGuid.ToString
    .Replace('{', '', [rfReplaceAll])
    .Replace('}', '', [rfReplaceAll])
    .Replace('-', '', [rfReplaceAll])
    .ToLower;
end;

class function TMCPServer.WrapTextContent(const Text: string): TJSONObject;
var
  ContentArr: TJSONArray;
  ContentItem: TJSONObject;
begin
  // MCP tool result format:
  // { "content": [ { "type": "text", "text": "<result>" } ] }
  ContentItem := TJSONObject.Create;
  ContentItem.AddPair('type', 'text');
  ContentItem.AddPair('text', Text);

  ContentArr := TJSONArray.Create;
  ContentArr.Add(ContentItem);

  Result := TJSONObject.Create;
  Result.AddPair('content', ContentArr);
end;

// ---------------------------------------------------------------------------
// TMCPServer — JSON-RPC dispatch
// ---------------------------------------------------------------------------

function TMCPServer.Dispatch(const Body: string): string;
var
  Req: TJSONObject;
  Method: string;
  Id, Params: TJSONValue;
begin
  Result := '';

  if Body = '' then
    Exit(TJsonRpc.Error(nil, JSONRPC_INVALID_REQUEST, 'Empty request body'));

  Req := TJSONObject.ParseJSONValue(Body) as TJSONObject;
  if Req = nil then
    Exit(TJsonRpc.Error(nil, JSONRPC_PARSE_ERROR, 'Failed to parse JSON'));

  try
    Id     := TJsonRpc.GetId(Req);
    Method := Req.GetValue<string>('method', '');
    Params := Req.GetValue('params');

    // Notifications (no id) don't need a response
    if Method = 'notifications/initialized' then
      Exit('');

    if Method = 'initialize' then
      Exit(HandleInitialize(Id, Params as TJSONObject))
    else if Method = 'ping' then
      Exit(HandlePing(Id))
    else if Method = 'tools/list' then
      Exit(HandleToolsList(Id))
    else if Method = 'tools/call' then
      Exit(HandleToolsCall(Id, Params as TJSONObject))
    else
    begin
      // Unknown method — only respond if it has an id (not a notification)
      if Id <> nil then
        Result := TJsonRpc.Error(Id, JSONRPC_METHOD_NOT_FOUND,
          'Method not found: ' + Method);
    end;
  finally
    Req.Free;
  end;
end;

function TMCPServer.HandleInitialize(const Id: TJSONValue;
  const Params: TJSONObject): string;
var
  ResultObj, ServerInfo, Caps, ToolsCap: TJSONObject;
begin
  // Reply with our server capabilities
  ServerInfo := TJSONObject.Create;
  ServerInfo.AddPair('name', FName);
  ServerInfo.AddPair('version', FVersion);

  ToolsCap := TJSONObject.Create;
  ToolsCap.AddPair('listChanged', TJSONFalse.Create);

  Caps := TJSONObject.Create;
  Caps.AddPair('tools', ToolsCap);

  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('protocolVersion', MCP_PROTOCOL_VERSION);
  ResultObj.AddPair('capabilities', Caps);
  ResultObj.AddPair('serverInfo', ServerInfo);

  try
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandlePing(const Id: TJSONValue): string;
var
  Empty: TJSONObject;
begin
  Empty := TJSONObject.Create;
  try
    Result := TJsonRpc.Success(Id, Empty);
  finally
    Empty.Free;
  end;
end;

function TMCPServer.HandleToolsList(const Id: TJSONValue): string;
var
  ResultObj: TJSONObject;
  ToolsArr: TJSONArray;
begin
  ToolsArr  := FRegistry.BuildToolsArray;
  ResultObj := TJSONObject.Create;
  try
    ResultObj.AddPair('tools', ToolsArr);
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandleToolsCall(const Id: TJSONValue;
  const Params: TJSONObject): string;
var
  ToolName: string;
  Def: TMCPToolDef;
  ArgsVal: TJSONValue;
  ArgsObj: TJSONObject;
  CallResult: string;
  Content: TJSONObject;
begin
  if Params = nil then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing params'));

  ToolName := Params.GetValue<string>('name', '');
  if ToolName = '' then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing tool name'));

  if not FRegistry.TryGetTool(ToolName, Def) then
    Exit(TJsonRpc.Error(Id, MCP_ERROR_TOOL_NOT_FOUND,
      'Tool not found: ' + ToolName));

  // arguments field may be absent (tool with no params)
  ArgsVal := Params.GetValue('arguments');
  if (ArgsVal <> nil) and (ArgsVal is TJSONObject) then
    ArgsObj := ArgsVal as TJSONObject
  else
    ArgsObj := TJSONObject.Create; // empty args — freed below if we own it

  try
    try
      CallResult := Def.Callback(ArgsObj);
    except
      on E: Exception do
        Exit(TJsonRpc.Error(Id, MCP_ERROR_TOOL_EXEC_FAILED,
          'Tool execution failed: ' + E.Message));
    end;

    Content := WrapTextContent(CallResult);
    try
      Result := TJsonRpc.Success(Id, Content);
    finally
      Content.Free;
    end;
  finally
    // Only free ArgsObj if we created it (i.e. ArgsVal was nil or not an object)
    if (ArgsVal = nil) or not (ArgsVal is TJSONObject) then
      ArgsObj.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TMCPServer — SSE route handlers
// ---------------------------------------------------------------------------

procedure TMCPServer.RouteSSE(Ctx: IHttpContext);
var
  Session: TMCPSession;
  Msg: string;
  KeepAlive: Integer;
begin
  Session := FSessions.CreateSession;

  ConfigureSSEResponse(Ctx.Response);

  // First event: tell the client where to POST messages
  WriteSSEEvent(Ctx.Response, 'endpoint',
    '/message?sessionId=' + Session.Id);

  KeepAlive := 0;

  // SSE loop — stays open until client disconnects or server shuts down
  while (not Session.IsClosed) and (not FSessions.IsShuttingDown) do
  begin
    // Drain the message queue
    while Session.HasMessages and not FSessions.IsShuttingDown do
    begin
      Msg := Session.Dequeue;
      if Msg <> '' then
        WriteSSEEvent(Ctx.Response, 'message', Msg);
    end;

    // Keep-alive comment every ~15 s (150 × 100 ms)
    Inc(KeepAlive);
    if KeepAlive >= 150 then
    begin
      WriteSSEComment(Ctx.Response, 'ping');
      KeepAlive := 0;
    end;

    Sleep(100);
  end;

  FSessions.RemoveSession(Session.Id);
end;

procedure TMCPServer.RouteMessage(Ctx: IHttpContext);
var
  SessionId, Body, Response: string;
  Session: TMCPSession;
begin
  // Handle CORS preflight
  if Ctx.Request.Method = 'OPTIONS' then
  begin
    Ctx.Response.AddHeader('Access-Control-Allow-Origin', '*');
    Ctx.Response.AddHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    Ctx.Response.AddHeader('Access-Control-Allow-Headers', 'Content-Type');
    Ctx.Response.StatusCode := 204;
    Exit;
  end;

  Ctx.Response.AddHeader('Access-Control-Allow-Origin', '*');

  // Locate the session
  if not Ctx.Request.Query.TryGetValue('sessionId', SessionId) then
    SessionId := Ctx.Request.GetQueryParam('sessionId');

  Session := FSessions.GetSession(SessionId);
  if Session = nil then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Unknown sessionId"}');
    Exit;
  end;

  // Read and dispatch the JSON-RPC body
  Body     := ReadBody(Ctx);
  Response := Dispatch(Body);

  // Enqueue the response for delivery via SSE
  if Response <> '' then
    Session.Enqueue(Response);

  // MCP SSE spec: POST always returns 202 Accepted (no body)
  Ctx.Response.StatusCode := 202;
end;

// ---------------------------------------------------------------------------
// TMCPServer — stdio transport
// ---------------------------------------------------------------------------

procedure TMCPServer.RunStdioLoop;
var
  Line, Response: string;
begin
  // Stdio: read one JSON-RPC message per line, write response to stdout
  while not EOF(Input) do
  begin
    Readln(Line);
    Line := Line.Trim;
    if Line = '' then Continue;

    Response := Dispatch(Line);
    if Response <> '' then
      Writeln(Response);
  end;
end;

// ---------------------------------------------------------------------------
// TMCPServer — public API
// ---------------------------------------------------------------------------

constructor TMCPServer.Create(const AName: string; const AVersion: string);
begin
  inherited Create;
  FName     := AName;
  FVersion  := AVersion;
  FRegistry := TMCPToolRegistry.Create;
  FSessions := TMCPSessionManager.Create;
end;

destructor TMCPServer.Destroy;
begin
  Stop;
  FSessions.Free;
  FRegistry.Free;
  inherited;
end;

function TMCPServer.Tool(const AName: string): IMCPToolBuilder;
begin
  Result := FRegistry.Register(AName);
end;

procedure TMCPServer.Run(ATransport: TMCPTransport; const AUrl: string);
begin
  if ATransport = mtStdio then
  begin
    RunStdioLoop;
    Exit;
  end;

  // SSE transport — build and start the HTTP server
  FHost := TWebHostBuilder.CreateDefault(nil)
    .UseUrls(AUrl)
    .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        // No extra DI registrations needed for a basic MCP server.
        // Add your own (e.g. database, HTTP client) here.
      end)
    .Configure(procedure(App: IApplicationBuilder)
      begin
        // CORS preflight for /sse
        App.MapGet('/sse',
          procedure(Ctx: IHttpContext)
          begin
            RouteSSE(Ctx);
          end);

        // Client sends JSON-RPC messages here
        App.MapPost('/message',
          procedure(Ctx: IHttpContext)
          begin
            RouteMessage(Ctx);
          end);

        // OPTIONS for /message (CORS)
        App.MapEndpoint('OPTIONS', '/message',
          procedure(Ctx: IHttpContext)
          begin
            RouteMessage(Ctx);
          end);

        // Health check
        App.MapGet('/health',
          procedure(Ctx: IHttpContext)
          begin
            Ctx.Response.SetContentType('application/json');
            Ctx.Response.Write(Format(
              '{"status":"ok","server":"%s","version":"%s","tools":%d}',
              [FName, FVersion, FRegistry.Count]));
          end);
      end)
    .Build;

  FHost.Start;
  OutputDebugString(PChar(Format('[MCP] %s v%s listening at %s (SSE)',
    [FName, FVersion, AUrl])));
end;

procedure TMCPServer.Stop;
begin
  FSessions.CloseAll;

  if FHost <> nil then
  begin
    try
      FHost.Stop;
    except
      // Swallow shutdown errors
    end;
    FHost := nil;
  end;
end;

end.
