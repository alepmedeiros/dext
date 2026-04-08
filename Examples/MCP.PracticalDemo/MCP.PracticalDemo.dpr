program MCP.PracticalDemo;

{$APPTYPE CONSOLE}
{$R *.res}

{***************************************************************************}
{                                                                           }
{  MCP Practical Demo                                                       }
{                                                                           }
{  Demonstra os dois padrões de implementação de tools MCP:               }
{                                                                           }
{  PADRÃO 1 — Sem API (lógica pura Delphi):                                }
{    - calcular-desconto   → tabela progressiva de descontos               }
{    - validar-cpf         → algoritmo da Receita Federal                  }
{    - calcular-imc        → classificação OMS                             }
{                                                                           }
{  PADRÃO 2 — Com API externa (THTTPClient RTL):                           }
{    - consultar-cep       → ViaCEP (endereço por CEP)                    }
{    - consultar-cambio    → Banco Central do Brasil (cotação PTAX)        }
{                                                                           }
{  Uso:                                                                     }
{    MCP.PracticalDemo.exe              -> SSE em http://localhost:3031     }
{    MCP.PracticalDemo.exe --stdio      -> Stdio (Claude Desktop)          }
{    MCP.PracticalDemo.exe --port 3040  -> SSE em porta customizada        }
{                                                                           }
{***************************************************************************}

uses
  System.SysUtils,
  Dext.MCP.Protocol         in '..\..\Sources\MCP\Dext.MCP.Protocol.pas',
  Dext.MCP.Tools            in '..\..\Sources\MCP\Dext.MCP.Tools.pas',
  Dext.MCP.Server           in '..\..\Sources\MCP\Dext.MCP.Server.pas',
  MCP.PracticalDemo.Tools   in 'MCP.PracticalDemo.Tools.pas';

function HasFlag(const AFlag: string): Boolean;
var I: Integer;
begin
  for I := 1 to ParamCount do
    if ParamStr(I).ToLower = AFlag.ToLower then Exit(True);
  Result := False;
end;

function GetParam(const AFlag, ADefault: string): string;
var I: Integer;
begin
  for I := 1 to ParamCount - 1 do
    if ParamStr(I).ToLower = AFlag.ToLower then Exit(ParamStr(I + 1));
  Result := ADefault;
end;

var
  Server: TMCPServer;
  Port, Url: string;

begin
  ReportMemoryLeaksOnShutdown := True;

  Port := GetParam('--port', '3031');
  Url  := 'http://localhost:' + Port;

  Server := TMCPServer.Create('practical-demo', '1.0.0');
  try
    RegisterDemoTools(Server);

    if HasFlag('--stdio') then
    begin
      Server.Run(mtStdio);
    end
    else
    begin
      Writeln('=== MCP Practical Demo ===');
      Writeln;
      Writeln('Tools registradas: ' + IntToStr(Server.Registry.Count));
      Writeln;
      Writeln('  [Puro Delphi]');
      Writeln('    calcular-desconto  -> tabela progressiva');
      Writeln('    validar-cpf        -> algoritmo Receita Federal');
      Writeln('    calcular-imc       -> classificacao OMS');
      Writeln;
      Writeln('  [Com API externa]');
      Writeln('    consultar-cep      -> ViaCEP');
      Writeln('    consultar-cambio   -> Banco Central (PTAX)');
      Writeln;
      Writeln('SSE endpoint : ' + Url + '/sse');
      Writeln('Health check : ' + Url + '/health');
      Writeln;
      Writeln('Configure no Claude Desktop (claude_desktop_config.json):');
      Writeln('  { "mcpServers": { "demo": { "url": "' + Url + '/sse" } } }');
      Writeln;
      Writeln('Pressione Enter para parar...');

      Server.Run(mtSSE, Url);
      Readln;

      Server.Stop;
    end;
  finally
    Server.Free;
  end;
end.
