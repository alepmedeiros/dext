# Dext Basic Authentication Demo

Este exemplo demonstra como utilizar a Autenticação Basic com o Dext Framework em Minimal APIs, utilizando o método `.RequireAuthorization()` para bloqueio automático de rotas protegidas.

## Funcionalidades demonstradas
- Configuração do Middleware de Basic Auth.
- Definição de uma função de validação customizada.
- Proteção automática de rotas via `RequireAuthorization`.
- Diferenciação entre endpoints públicos e privados.

## Como Executar

1. Abra o projeto `Web.BasicAuthDemo.dproj` no Delphi.
2. Compile e execute o projeto (F9).
3. Utilize os comandos `curl` demonstrados no console para testar os endpoints.

## Exemplo de Código

```pascal
App.Builder.UseBasicAuthentication(
  'Dext Protected API',
  function(const Username, Password: string): Boolean
  begin
    Result := (Username = 'admin') and (Password = 'secret');
  end);

App.Builder.MapGet('/api/privado', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.Write('Área Privada!');
  end)
  .RequireAuthorization;
```

## Testando com PowerShell

Você também pode utilizar o script `Test.Web.BasicAuthDemo.ps1` incluído nesta pasta para automatizar os testes de requisição.
