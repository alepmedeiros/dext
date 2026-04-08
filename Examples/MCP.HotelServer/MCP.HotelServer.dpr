program MCP.HotelServer;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Dext.MCP.Protocol     in '..\..\Sources\MCP\Dext.MCP.Protocol.pas',
  Dext.MCP.Tools        in '..\..\Sources\MCP\Dext.MCP.Tools.pas',
  Dext.MCP.Server       in '..\..\Sources\MCP\Dext.MCP.Server.pas',
  MCP.HotelServer.Tools in 'MCP.HotelServer.Tools.pas';

// ---------------------------------------------------------------------------
// Usage:
//   MCP.HotelServer.exe           -> SSE transport on http://localhost:3031
//   MCP.HotelServer.exe --stdio   -> stdio transport (for Claude Desktop)
//   MCP.HotelServer.exe --port 8080 -> SSE on custom port
// ---------------------------------------------------------------------------

function HasFlag(const AFlag: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if ParamStr(I).ToLower = AFlag.ToLower then
      Exit(True);
  Result := False;
end;

function GetParam(const AFlag: string; const ADefault: string = ''): string;
var
  I: Integer;
begin
  for I := 1 to ParamCount - 1 do
    if ParamStr(I).ToLower = AFlag.ToLower then
      Exit(ParamStr(I + 1));
  Result := ADefault;
end;

var
  Server: TMCPServer;
  UseStdio: Boolean;
  Port, Url: string;

begin
  ReportMemoryLeaksOnShutdown := True;

  UseStdio := HasFlag('--stdio');
  Port     := GetParam('--port', '3031');
  Url      := 'http://localhost:' + Port;

  Server := TMCPServer.Create('hotel-server', '1.0.0');
  try
    // Register domain tools — same pattern as @mcp_server.tool() in Python
    RegisterHotelTools(Server);

    if UseStdio then
    begin
      // Stdio transport: Claude Desktop manages this process directly.
      // Blocks until stdin closes (EOF).
      Server.Run(mtStdio);
    end
    else
    begin
      Writeln('[MCP] Hotel Server iniciando...');
      Writeln('[MCP] Ferramentas: ' + IntToStr(Server.Registry.Count));
      Writeln('[MCP] SSE endpoint: ' + Url + '/sse');
      Writeln('[MCP] Mensagens:    ' + Url + '/message?sessionId=<uuid>');
      Writeln('[MCP] Health:       ' + Url + '/health');
      Writeln('[MCP] Pressione Enter para parar.');
      Writeln;

      Server.Run(mtSSE, Url);
      Readln;

      Writeln('[MCP] Encerrando...');
      Server.Stop;
    end;
  finally
    Server.Free;
  end;
end.
