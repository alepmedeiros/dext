{***************************************************************************}
{                                                                           }
{  MCP Hotel Server — Tool Definitions                                      }
{                                                                           }
{  Equivalent to the Python FastMCP example:                                }
{    @mcp_server.tool("hotal-get-consultaestoque")                          }
{    @mcp_server.tool("hospitalidade-soma")                                 }
{                                                                           }
{***************************************************************************}
unit MCP.HotelServer.Tools;

interface

uses
  Dext.MCP.Server;

/// <summary>
/// Registers all hotel domain tools on the given MCP server instance.
/// Call this once during startup before calling Server.Run.
/// </summary>
procedure RegisterHotelTools(Server: TMCPServer);

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Net.HttpClient; // RTL HTTP client — no third-party dependency

procedure RegisterHotelTools(Server: TMCPServer);
begin
  // -------------------------------------------------------------------------
  // Tool 1: Consulta de estoque
  // Equivalent to @mcp_server.tool("hotal-get-consultaestoque")
  // -------------------------------------------------------------------------
  Server.Tool('hotal-get-consultaestoque')
    .Description(
      'Ferramenta especializada em consulta de estoque. ' +
      'Retorna uma lista de produtos em estoque.' +
      #10#10 +
      'Regras:' +
      #10 + '- Nunca inventar dados.' +
      #10 + '- Consistência de status: 0 = indisponivel, 1-5 = baixo_estoque, >5 = disponivel.' +
      #10 + '- Se sem resultados, retornar lista vazia.' +
      #10#10 +
      'Formato de saída: JSON com campos total e itens[].')
    .OnCall(
      function(Args: TJSONObject): string
      var
        Client: THTTPClient;
        Response: IHTTPResponse;
      begin
        Client := THTTPClient.Create;
        try
          try
            Response := Client.Get('http://localhost:3000/estoque');
            Result   := Response.ContentAsString(TEncoding.UTF8);
          except
            on E: Exception do
              Result := Format('{"error": "Falha ao consultar estoque: %s"}', [E.Message]);
          end;
        finally
          Client.Free;
        end;
      end);

  // -------------------------------------------------------------------------
  // Tool 2: Soma matemática
  // Equivalent to @mcp_server.tool("hospitalidade-soma")
  // -------------------------------------------------------------------------
  Server.Tool('hospitalidade-soma')
    .Description(
      'Ferramenta especializada em realizar somas matemáticas. ' +
      'Recebe dois números inteiros e retorna a soma.' +
      #10#10 +
      'Formato de saída: {"valor": <resultado>}')
    .Param('a', 'Primeiro número inteiro', ptInteger)
    .Param('b', 'Segundo número inteiro', ptInteger)
    .OnCall(
      function(Args: TJSONObject): string
      var
        A, B, Resultado: Integer;
      begin
        A := Args.GetValue<Integer>('a', 0);
        B := Args.GetValue<Integer>('b', 0);

        Resultado := A + B;

        Result := Format('{"valor": %d}', [Resultado]);
      end);
end;

end.
