# Dext MCP Server

Implementação nativa do **Model Context Protocol (MCP)** para o Dext Framework.  
Zero dependências externas — usa apenas RTL Delphi + infraestrutura já existente no Dext.

---

## O que é MCP?

O **Model Context Protocol** é um padrão aberto criado pela Anthropic que permite que LLMs (Claude, GPT, Gemini, etc.) chamem ferramentas externas de forma padronizada. Funciona como uma "ponte" entre o modelo de linguagem e o seu código.

```
[Claude / Agente IA]
        |
   MCP Protocol (JSON-RPC 2.0)
        |
[Seu TMCPServer em Delphi]
        |
[Banco de dados, APIs, regras de negócio...]
```

---

## Arquivos

| Arquivo | Descrição |
|---|---|
| `Dext.MCP.Protocol.pas` | Tipos JSON-RPC 2.0, constantes do protocolo, helper `TJsonRpc` |
| `Dext.MCP.Tools.pas` | Registry de tools + builder fluente `IMCPToolBuilder` |
| `Dext.MCP.Server.pas` | `TMCPServer` — transports SSE e Stdio, dispatch de mensagens |

---

## Quick Start

### 1. Crie o servidor

```pascal
uses
  Dext.MCP.Protocol,
  Dext.MCP.Tools,
  Dext.MCP.Server;

var
  Server: TMCPServer;
begin
  Server := TMCPServer.Create('meu-servidor', '1.0.0');

  Server.Tool('minha-tool')
    .Description('Descrição clara do que a tool faz e quando usá-la')
    .Param('entrada', 'Parâmetro de entrada', ptString)
    .OnCall(function(Args: TJSONObject): string
      begin
        Result := '{"resultado": "ok"}';
      end);

  Server.Run(mtSSE, 'http://localhost:3031');
end;
```

### 2. Adicione ao Claude Desktop

Edite `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "meu-servidor": {
      "url": "http://localhost:3031/sse"
    }
  }
}
```

### 3. Adicione ao Claude Code (este CLI)

```bash
/mcp add meu-servidor http://localhost:3031/sse
```

---

## Registrando Tools

### Tool simples (sem parâmetros)

```pascal
Server.Tool('status-sistema')
  .Description('Retorna o status atual do sistema')
  .OnCall(function(Args: TJSONObject): string
    begin
      Result := '{"status": "online", "versao": "2.1.0"}';
    end);
```

### Tool com parâmetros

```pascal
Server.Tool('buscar-cliente')
  .Description(
    'Busca dados cadastrais de um cliente. ' +
    'Use quando o usuário pedir informações sobre um cliente específico. ' +
    'Retorna nome, CPF, endereço e situação.')
  .Param('cpf', 'CPF do cliente (somente números)', ptString)
  .OnCall(function(Args: TJSONObject): string
    var
      CPF: string;
    begin
      CPF := Args.GetValue<string>('cpf', '');
      // Sua lógica aqui
      Result := Format('{"nome": "João Silva", "cpf": "%s"}', [CPF]);
    end);
```

### Tool com parâmetros opcionais

```pascal
Server.Tool('listar-pedidos')
  .Description('Lista pedidos com filtros opcionais')
  .Param('cliente_id', 'ID do cliente', ptString, {Required=}False)
  .Param('status',     'Status do pedido', ptString, False)
  .Param('limite',     'Máximo de registros', ptInteger, False)
  .OnCall(function(Args: TJSONObject): string
    var
      ClienteId: string;
      Limite: Integer;
    begin
      ClienteId := Args.GetValue<string>('cliente_id', '');
      Limite    := Args.GetValue<Integer>('limite', 50);
      // Sua consulta
      Result := '{"pedidos": []}';
    end);
```

---

## Tipos de Parâmetros

| Constante | Tipo JSON Schema | Delphi |
|---|---|---|
| `ptString` | `"string"` | `string` |
| `ptInteger` | `"integer"` | `Integer` |
| `ptNumber` | `"number"` | `Double` |
| `ptBoolean` | `"boolean"` | `Boolean` |
| `ptObject` | `"object"` | `TJSONObject` |
| `ptArray` | `"array"` | `TJSONArray` |

### Lendo argumentos no callback

```pascal
.OnCall(function(Args: TJSONObject): string
  var
    Nome:    string;
    Valor:   Double;
    Ativo:   Boolean;
    Qtd:     Integer;
  begin
    // Todos os GetValue<T> aceitam valor padrão como segundo argumento
    Nome  := Args.GetValue<string>('nome', '');
    Valor := Args.GetValue<Double>('valor', 0.0);
    Ativo := Args.GetValue<Boolean>('ativo', True);
    Qtd   := Args.GetValue<Integer>('quantidade', 1);

    // Para parâmetros do tipo object ou array:
    // var Obj := Args.GetValue('filtros') as TJSONObject;
    // if Obj <> nil then ...
  end);
```

---

## Transports

### SSE (Server-Sent Events) — padrão web

O transport mais usado. O cliente abre uma conexão persistente e recebe respostas em tempo real.

```
GET  /sse                           ← cliente conecta, recebe stream
POST /message?sessionId=<uuid>      ← cliente envia mensagens JSON-RPC
GET  /health                        ← verificação de saúde
```

**Fluxo:**
1. Cliente faz `GET /sse`
2. Servidor responde com SSE stream e envia: `event: endpoint\ndata: /message?sessionId=abc\n\n`
3. Cliente envia JSON-RPC para `POST /message?sessionId=abc`
4. Servidor responde via SSE: `event: message\ndata: {...}\n\n`

```pascal
Server.Run(mtSSE, 'http://localhost:3031');
// ou porta customizada:
Server.Run(mtSSE, 'http://localhost:8080');
```

### Stdio — para Claude Desktop / processos locais

O Claude Desktop gerencia o processo diretamente. Comunicação via stdin/stdout.

```pascal
Server.Run(mtStdio);
// Bloqueia até EOF no stdin
```

**Config Claude Desktop para stdio:**
```json
{
  "mcpServers": {
    "meu-servidor": {
      "command": "C:\\MeuApp\\MeuMCP.exe",
      "args": ["--stdio"]
    }
  }
}
```

---

## Integração com Claude Desktop

Arquivo: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "erp-server": {
      "url": "http://localhost:3031/sse"
    },
    "fiscal-server": {
      "url": "http://localhost:3032/sse"
    }
  }
}
```

Reinicie o Claude Desktop após editar o arquivo.

---

## Múltiplos servidores MCP no mesmo projeto

Você pode rodar vários servidores MCP independentes, cada um em uma porta diferente:

```pascal
var
  ERPServer:    TMCPServer;
  FiscalServer: TMCPServer;
begin
  // Servidor ERP
  ERPServer := TMCPServer.Create('erp-server');
  ERPServer.Tool('buscar-cliente')...
  ERPServer.Tool('criar-pedido')...
  ERPServer.Run(mtSSE, 'http://localhost:3031'); // non-blocking

  // Servidor Fiscal
  FiscalServer := TMCPServer.Create('fiscal-server');
  FiscalServer.Tool('emitir-nfe')...
  FiscalServer.Tool('consultar-sefaz')...
  FiscalServer.Run(mtSSE, 'http://localhost:3032'); // non-blocking

  // Aguarda
  Readln;

  ERPServer.Stop;
  FiscalServer.Stop;
end;
```

---

## Combinando MCP Server com API REST Dext

O `TMCPServer` usa `TWebHostBuilder` internamente, então convive perfeitamente com uma API REST Dext rodando em paralelo:

```pascal
var
  MCPServer: TMCPServer;
  RestHost:  IWebHost;
begin
  // MCP Server na porta 3031
  MCPServer := TMCPServer.Create('meu-server');
  MCPServer.Tool('buscar-produto')...
  MCPServer.Run(mtSSE, 'http://localhost:3031');

  // API REST Dext na porta 5000
  RestHost := TWebHostBuilder.CreateDefault(nil)
    .UseUrls('http://localhost:5000')
    .Configure(procedure(App: IApplicationBuilder)
      begin
        App.MapGet('/produtos', procedure(Ctx: IHttpContext) begin ... end);
        App.MapPost('/pedidos', procedure(Ctx: IHttpContext) begin ... end);
      end)
    .Build;
  RestHost.Start;

  Readln;
  MCPServer.Stop;
  RestHost.Stop;
end;
```

---

## Boas práticas para Descriptions

O campo `Description` da tool é o que o LLM lê para decidir **quando** e **como** chamar sua ferramenta. Uma boa description aumenta muito a qualidade das respostas.

```pascal
// Ruim — vago demais
Server.Tool('clientes')
  .Description('Clientes')
  ...

// Bom — claro, com contexto de uso e formato de retorno
Server.Tool('buscar-cliente')
  .Description(
    'Busca dados completos de um cliente pelo CPF ou CNPJ. ' +
    'Use quando o usuário mencionar um cliente específico ou pedir ' +
    'informações cadastrais. ' +
    'Retorna: nome, documento, endereço, telefone, e-mail e limite de crédito. ' +
    'Se não encontrado, retorna {"encontrado": false}.')
  ...
```

---

## Tratamento de erros no callback

O servidor captura exceções automaticamente e retorna um erro MCP. Você também pode retornar erros manualmente via JSON:

```pascal
.OnCall(function(Args: TJSONObject): string
  var
    Id: string;
  begin
    Id := Args.GetValue<string>('id', '');

    if Id = '' then
    begin
      // Erro explícito via JSON
      Result := '{"erro": "ID obrigatório"}';
      Exit;
    end;

    try
      Result := BuscarDadosNoBanco(Id);
    except
      on E: Exception do
        // Exceção não tratada vira erro MCP -32001 automaticamente
        raise;
    end;
  end);
```

---

## Endpoints disponíveis (transport SSE)

| Método | Path | Descrição |
|---|---|---|
| `GET` | `/sse` | Abre o stream SSE. O cliente deve manter esta conexão aberta. |
| `POST` | `/message?sessionId=<id>` | Envia uma mensagem JSON-RPC. Retorna `202 Accepted`. |
| `GET` | `/health` | Status do servidor: `{"status":"ok","tools":N}` |

---

## Métodos MCP implementados

| Método JSON-RPC | Descrição |
|---|---|
| `initialize` | Handshake inicial — retorna capacidades do servidor |
| `notifications/initialized` | Confirmação do cliente (sem resposta) |
| `ping` | Keep-alive — retorna `{}` |
| `tools/list` | Lista todas as tools registradas com seus schemas |
| `tools/call` | Invoca uma tool específica com os argumentos fornecidos |

---

## Exemplo de sessão JSON-RPC completa

```jsonc
// 1. Cliente → Servidor: inicializar
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"claude","version":"1.0"}}}

// 2. Servidor → Cliente: capacidades
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"meu-servidor","version":"1.0.0"}}}

// 3. Cliente → Servidor: listar tools
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}

// 4. Servidor → Cliente: lista de tools
{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"buscar-cliente","description":"...","inputSchema":{...}}]}}

// 5. Cliente → Servidor: chamar tool
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"buscar-cliente","arguments":{"cpf":"12345678900"}}}

// 6. Servidor → Cliente: resultado
{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"{\"nome\":\"João Silva\"}"}]}}
```
