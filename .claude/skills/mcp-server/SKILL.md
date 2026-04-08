---
name: mcp-server
description: Cria um novo MCP Server Dext completo — gera o projeto, as units de tools e o .dpr. Use quando o usuário pedir para criar um servidor MCP, uma nova tool MCP, ou integrar algo com Claude/agentes de IA via MCP.
---

Você deve criar um novo MCP Server para o Dext Framework seguindo rigorosamente os padrões estabelecidos nos arquivos existentes.

## Contexto do projeto

O framework Dext possui uma implementação nativa de MCP Server em:
- `Sources/MCP/Dext.MCP.Protocol.pas` — tipos JSON-RPC 2.0
- `Sources/MCP/Dext.MCP.Tools.pas` — registry e builder fluente
- `Sources/MCP/Dext.MCP.Server.pas` — TMCPServer (SSE + Stdio)

Exemplos de referência:
- `Examples/MCP.HotelServer/` — exemplo com chamada a API
- `Examples/MCP.PracticalDemo/` — exemplo com tools puras e com API

## O que você deve fazer

1. **Pergunte** (se não foi informado):
   - Nome do servidor (ex: `erp-server`, `fiscal-server`)
   - Quais tools são necessárias e o que cada uma faz
   - Para cada tool: tem chamada a API externa ou é lógica pura?
   - Porta desejada (padrão: 3031)

2. **Crie os arquivos** na pasta `Examples/MCP.<NomeServidor>/`:

   - `MCP.<NomeServidor>.Tools.pas` — definição das tools
   - `MCP.<NomeServidor>.dpr` — entry point com suporte a `--stdio` e `--port`

3. **Siga os padrões obrigatórios**:

### Pattern: Tool sem API (lógica pura)

```pascal
Server.Tool('nome-da-tool')
  .Description(
    'Descrição clara e detalhada do que a tool faz. ' +
    'Inclua: quando usar, o que retorna, formato de saída. ' +
    'O LLM usa isso para decidir quando chamar a tool.')
  .Param('parametro', 'Descrição do parâmetro', ptString)  // ptString/ptInteger/ptNumber/ptBoolean
  .OnCall(
    function(Args: TJSONObject): string
    var
      Valor: string;
    begin
      Valor := Args.GetValue<string>('parametro', '');
      // lógica Delphi aqui
      Result := '{"resultado": "..."}'; // sempre retorna JSON válido
    end);
```

### Pattern: Tool com API externa

```pascal
Server.Tool('nome-da-tool')
  .Description('...')
  .Param('entrada', 'Parâmetro', ptString)
  .OnCall(
    function(Args: TJSONObject): string
    var
      Client: THTTPClient;
      Response: IHTTPResponse;
    begin
      Client := THTTPClient.Create;
      try
        try
          Response := Client.Get('https://api.exemplo.com/endpoint');
          Result := Response.ContentAsString(TEncoding.UTF8);
        except
          on E: Exception do
            Result := Format('{"erro": "%s"}', [E.Message]);
        end;
      finally
        Client.Free;
      end;
    end);
```

### Pattern: .dpr padrão

```pascal
program MCP.<NomeServidor>;
{$APPTYPE CONSOLE}
{$R *.res}
uses
  System.SysUtils,
  Dext.MCP.Protocol in '..\..\Sources\MCP\Dext.MCP.Protocol.pas',
  Dext.MCP.Tools    in '..\..\Sources\MCP\Dext.MCP.Tools.pas',
  Dext.MCP.Server   in '..\..\Sources\MCP\Dext.MCP.Server.pas',
  MCP.<NomeServidor>.Tools in 'MCP.<NomeServidor>.Tools.pas';

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
var Server: TMCPServer; Port, Url: string;
begin
  Port   := GetParam('--port', '3031');
  Url    := 'http://localhost:' + Port;
  Server := TMCPServer.Create('<nome-servidor>', '1.0.0');
  try
    Register<NomeServidor>Tools(Server);
    if HasFlag('--stdio') then
      Server.Run(mtStdio)
    else
    begin
      Writeln('MCP <NomeServidor> -> ' + Url + '/sse');
      Server.Run(mtSSE, Url);
      Readln;
      Server.Stop;
    end;
  finally
    Server.Free;
  end;
end.
```

4. **Após criar os arquivos**, mostre ao usuário:
   - Quais arquivos foram criados
   - Como registrar no Claude Desktop (snippet do `claude_desktop_config.json`)
   - Como testar com `GET /health`
   - Exemplo de pergunta que o LLM pode fazer para acionar cada tool

## Regras de qualidade obrigatórias

- **Description é o mais importante**: seja específico sobre quando usar, o que retorna e o formato
- **Sempre use THTTPClient** (RTL) para chamadas HTTP — nunca Indy, nunca terceiros
- **Trate erros** nos callbacks — retorne `{"erro": "mensagem"}` em vez de deixar explodir
- **Use `Args.GetValue<T>('campo', default)`** com sempre um valor padrão
- **Retorne sempre JSON válido** — mesmo em caso de erro
- **Nunca use `Sleep`** nos callbacks — tools devem ser rápidas
- **Organize em procedimentos** `RegisterXxxTools(Server)` quando há muitas tools
