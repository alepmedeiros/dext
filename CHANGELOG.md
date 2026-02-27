# 📢 Novidades do Dext Framework / Dext Framework News

> **[PT-BR]** Este documento contém as últimas novidades, breaking changes e novas features do Dext Framework. As atualizações mais recentes aparecem primeiro.
>
> **[EN]** This document contains the latest news, breaking changes and new features of the Dext Framework. Most recent updates appear first.

---

## 🚀 2026-03-01 - Dext.Collections Refactoring: Performance & Memory Safety

### ✨ Major Features / Features Principais

> **A new engine for collections, designed for the future of Dext!**
>
> **Um novo motor de coleções, desenhado para o futuro do Dext!**

#### Generic Collections Evolution

**[PT-BR]** Refatoramos completamente o núcleo de coleções do framework para garantir segurança de memória e performance superior.

- 🛡️ **Zero-Leak Architecture** - Substituição total de classes manuais por interfaces (`IList<T>`, `IDictionary<K,V>`). O gerenciamento de memória agora é automático, eliminando riscos de vazamento em closures e threads.
- 🧬 **Ownership Intelligence** - Controle de propriedade nativo. As listas gerenciam o ciclo de vida dos objetos de forma inteligente, destruindo-os apenas quando apropriado.
- ⚡ **LINQ Engine** - Suporte completo a operações funcionais lazies (`Where`, `Select`, `Any`, `OrderBy`, `GroupBy`) integradas nativamente às coleções.
- 🔍 **Native IExpression Integration** - Coleções agora suportam filtragem via especificações e árvores de expressão do Dext, mantendo paridade entre filtros em memória e filtros de banco (ORM).

**[EN]** Completely refactored the collections core to ensure memory safety and superior performance.

- 🛡️ **Zero-Leak Architecture** - Total replacement of manual classes with interfaces (`IList<T>`, `IDictionary<K,V>`). Memory management is now automatic, eliminating leakage risks in closures and threads.
- 🧬 **Ownership Intelligence** - Native ownership control. Lists manage object lifecycles intelligently, destroying them only when appropriate.
- ⚡ **LINQ Engine** - Full support for lazy functional operations (`Where`, `Select`, `Any`, `OrderBy`, `GroupBy`) natively integrated into collections.
- 🔍 **Native IExpression Integration** - Collections now support filtering via Dext specifications and expression trees, maintaining parity between in-memory and database (ORM) filters.

#### Documentation & Book

**[PT-BR]** Lançamento de documentação bilíngue completa e novos capítulos no Dext Book dedicados a coleções e gerenciamento de memória.
**[EN]** Launch of full bilingual documentation and new Dext Book chapters dedicated to collections and memory management.

---

## 🚀 2026-02-22 - Dext v1.0 Release Candidate: ORM Evolution & Performance

### ✨ Major Features / Features Principais

> **A evolução final do Dext ORM e Web API antes da v1.0!**
>
> **The final evolution of Dext ORM and Web API before v1.0!**

#### ORM Evolution & Fluency

**[PT-BR]** Simplificamos drasticamente a exposição de dados e a execução de consultas complexas.

- ⚡ **MapDataApi<T>** - Nova sintaxe fluente para criar endpoints REST completos a partir de uma entidade com uma única linha de código.
- 🛠️ **FromSql Support** - Agora você pode executar SQL puro diretamente via `DbContext.Users.FromSql(...)` mantendo o mapeamento automático para objetos.
- 🔗 **Multi-Mapping ([Nested])** - Suporte a hidratação recursiva estilo Dapper. Mapeie objetos complexos em uma única query usando o atributo `[Nested]`.
- 🔒 **Pessimistic Locking** - Controle total de concorrência com suporte nativo a `FOR UPDATE` (PostgreSQL/Oracle) e `UPDLOCK` (SQL Server).
- 🧬 **Stored Procedures Evolution** - Mapeamento declarativo via `[StoredProcedure]` e atributos `[DbParam]` para parâmetros de entrada e saída.

**[EN]** Drastically simplified data exposure and complex query execution.

- ⚡ **MapDataApi<T>** - New fluent syntax to create full REST endpoints from an entity with a single line of code.
- 🛠️ **FromSql Support** - You can now execute raw SQL directly via `DbContext.Users.FromSql(...)` while maintaining automatic object mapping.
- 🔗 **Multi-Mapping ([Nested])** - Dapper-style recursive hydration support. Map complex objects in a single query using the `[Nested]` attribute.
- 🔒 **Pessimistic Locking** - Full concurrency control with native support for `FOR UPDATE` (PostgreSQL/Oracle) and `UPDLOCK` (SQL Server).
- 🧬 **Stored Procedures Evolution** - Declarative mapping via `[StoredProcedure]` and `[DbParam]` attributes for input and output parameters.

#### Web & Performance

**[PT-BR]** Foco em performance e flexibilidade na filtragem de dados.

- 🚀 **Zero-Allocation JSON** - Motor "Database as API" agora utiliza `TUtf8JsonWriter` para streaming direto do banco para o socket, minimizando alocações de memória.
- 🔍 **Dynamic Specification Mapping** - Filtragem avançada via QueryString integrada (`_gt`, `_lt`, `_sort`, etc) que mapeia automaticamente para o SQL.
- 🏗️ **Core Interception** - O motor de Proxy e ClassProxy foi movido para o Core, eliminando dependências circulares e otimizando o Lazy Loading.

**[EN]** Focus on performance and flexibility in data filtering.

- 🚀 **Zero-Allocation JSON** - "Database as API" engine now uses `TUtf8JsonWriter` for direct streaming from database to socket, minimizing memory allocations.
- 🔍 **Dynamic Specification Mapping** - Integrated advanced QueryString filtering (`_gt`, `_lt`, `_sort`, etc) that automatically maps to SQL.
- 🏗️ **Core Interception** - The Proxy and ClassProxy engine has been moved to Core, eliminating circular dependencies and optimizing Lazy Loading.

### 🧪 New Examples / Novos Exemplos

- **eShopOnWeb**: Implementação completa do clássico demo da Microsoft adaptado para Dext.
- **HelpDesk**: Sistema de chamados com arquitetura em camadas e testes de integração.
- **MultiTenancy**: Demonstração de isolamento de dados por Schema e por Banco.
- **SmartPropsDemo**: Uso avançado de `Prop<T>` e `Nullable<T>` com persistência.

### 🐛 Bug Fixes & Stability

- **SQL Generator**: Melhoria na geração de Foreign Keys, ignorando propriedades de navegação durante o `CREATE TABLE`.
- **Memory Management**: Resolvido conflitos de ownership no `THandlerInvoker` e memory leaks no seeding de dados.
- **Lazy Loading**: Correção de Access Violations causados por inicialização incorreta de proxies.
- **TActivator**: Priorização inteligente de construtores de classes derivadas.

## 🚀 2026-02-06 - Dext.Entity: DbType Propagation & Legacy Paging

### ✨ Major Feature / Feature Principal

> **Controle total sobre tipos de dados e suporte a bancos de dados legados!**
>
> **Full control over data types and support for legacy databases!**

#### DbType Propagation / Propagação de DbType

**[PT-BR]** O atributo `[DbType]` agora é propagado corretamente até o driver de baixo nível. Isso garante que o banco de dados receba o tipo exato de dado esperado, evitando erros de conversão implícita.

- 🎯 **Mapeamento Exato** - Use `[DbType(ftDate)]` para garantir que um `TDateTime` seja enviado apenas como data.
- 💰 **Suporte a High-Precision** - Use `[DbType(ftFMTBcd)]` para campos monetários de alta precisão.
- 🧪 **Compatibilidade FireDAC** - Integração total com os tipos de parâmetros do FireDAC.

**[EN]** The `[DbType]` attribute is now correctly propagated down to the low-level driver. This ensures the database receives the exact expected data type, avoiding implicit conversion errors.

- 🎯 **Exact Mapping** - Use `[DbType(ftDate)]` to ensure a `TDateTime` is sent as date only.
- 💰 **High-Precision Support** - Use `[DbType(ftFMTBcd)]` for high-precision currency fields.
- 🧪 **FireDAC Compatibility** - Full integration with FireDAC parameter types.

#### Legacy Paging Support / Suporte a Paginação Legada

**[PT-BR]** Melhoramos a estabilidade da paginação em versões antigas de bancos de dados que não suportam a sintaxe `OFFSET/FETCH`.

- 🏛️ **Oracle Legacy** - Implementada paginação robusta via `ROWNUM` compatível com Oracle 11g e anteriores.
- 🔄 **SQL Wrapper Architecture** - Nova arquitetura de dialeto que permite "envelopar" queries para suportar qualquer estratégia de paginação.
- 🔗 **Fluent Mapping** - Adicionado suporte a `HasDbType(ADataType)` na API fluente para configuração explícita de tipos.
- 🐍 **Improved Snake Case** - Nova lógica no `TSnakeCaseNamingStrategy` que agora lida corretamente com acrônimos (ex: `THTTPLogEntry` vira `http_log_entry` em vez de `h_t_t_p_log_entry`).

**[EN]** We've improved paging stability for older database versions that do not support the `OFFSET/FETCH` syntax.

- 🏛️ **Oracle Legacy** - Robust paging implementation via `ROWNUM` compatible with Oracle 11g and earlier.
- 🔄 **SQL Wrapper Architecture** - New dialect architecture that allows "wrapping" queries to support any paging strategy.
- 🔗 **Fluent Mapping** - Added support for `HasDbType(ADataType)` in the fluent API for explicit type configuration.
- 🐍 **Improved Snake Case** - New logic in `TSnakeCaseNamingStrategy` that now correctly handles acronyms (e.g., `THTTPLogEntry` becomes `http_log_entry` instead of `h_t_t_p_log_entry`).

---

## 🚀 2026-02-06 - Dext.Entity: JSON Queries

### ✨ Major Feature / Feature Principal

> **Consulte dados dentro de colunas JSON/JSONB como se fossem propriedades nativas!**
>
> **Query data inside JSON/JSONB columns as if they were native properties!**

#### JSON Column Queries

**[PT-BR]** Agora você pode consultar dados semi-estruturados armazenados em colunas JSON diretamente na API fluente do ORM. Esta feature permite:

- 🔍 **Filtrar por propriedades JSON** - Busque registros baseado em valores dentro do JSON
- 🌳 **Acessar propriedades aninhadas** - Navegue em estruturas JSON complexas com notação de ponto
- ✅ **Verificar existência de chaves** - Use `.IsNull` para encontrar registros sem determinada propriedade
- 🔄 **Conversão automática de tipos** - O framework gera casts SQL apropriados automaticamente

**Exemplo Completo:**

```pascal
type
  [Table('UserSettings')]
  TUserSetting = class
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [JsonColumn]  // Marca a coluna como JSON
    property Preferences: string read FPreferences write FPreferences;
  end;

// Consultas JSON fluentes
var Users := Context.UserSettings
  .Where(Prop('Preferences').Json('theme') = 'dark')
  .Where(Prop('Preferences').Json('notifications.email') = True)
  .ToList;

// Verificar chaves inexistentes
var NoProfile := Context.UserSettings
  .Where(Prop('Preferences').Json('profile').IsNull)
  .ToList;
```

**[EN]** You can now query semi-structured data stored in JSON columns directly from the ORM's fluent API. This feature enables:

- 🔍 **Filter by JSON properties** - Find records based on values inside JSON
- 🌳 **Access nested properties** - Navigate complex JSON structures with dot notation
- ✅ **Check key existence** - Use `.IsNull` to find records missing a property
- 🔄 **Automatic type conversion** - Framework generates appropriate SQL casts automatically

#### Multi-Database Support / Suporte Multi-Banco

| Database | JSON Function | Column Type | Status |
|----------|--------------|-------------|--------|
| PostgreSQL | `#>>` operator | `JSONB` / `JSON` | ✅ Full Support |
| SQLite 3.9+ | `json_extract()` | `TEXT` | ✅ Full Support |
| MySQL 5.7+ | `JSON_EXTRACT()` | `JSON` | ✅ Full Support |
| SQL Server 2016+ | `JSON_VALUE()` | `NVARCHAR(MAX)` | ✅ Full Support |

#### Smart Type Casting / Conversão Inteligente de Tipos

**[PT-BR]** O Dext gera automaticamente os casts SQL corretos:

- **INSERT PostgreSQL**: `::jsonb` aplicado automaticamente em colunas `[JsonColumn]`
- **Comparações numéricas**: `::text` aplicado para comparar JSON text com números
- **NULL checking**: Gera `IS NULL` corretamente para expressões JSON

**[EN]** Dext automatically generates correct SQL casts:

- **INSERT PostgreSQL**: `::jsonb` applied automatically on `[JsonColumn]` columns  
- **Numeric comparisons**: `::text` applied to compare JSON text with numbers
- **NULL checking**: Correctly generates `IS NULL` for JSON expressions

#### SQLite JSON Support / Suporte JSON no SQLite

**[PT-BR]** Nova diretiva de compilação para habilitar funções JSON no SQLite:

```pascal
// Em Dext.inc
{$DEFINE DEXT_ENABLE_SQLITE_JSON}  // Requer sqlite3.dll 3.9+ com JSON1
```

**[EN]** New compilation directive to enable JSON functions in SQLite:

```pascal
// In Dext.inc
{$DEFINE DEXT_ENABLE_SQLITE_JSON}  // Requires sqlite3.dll 3.9+ with JSON1
```

> 💡 **Dica/Tip**: SQLite 3.51.2+ já inclui suporte JSON por padrão. Baixe em [sqlite.org](https://sqlite.org/download.html).

#### 📚 Documentation / Documentação

- **English**: [JSON Queries Guide](docs/Book/05-orm/json-queries.md)
- **Português**: [Guia de Consultas JSON](docs/Book.pt-br/05-orm/consultas-json.md)

---

## 2026-02-05 - Dext.Entity: Many-to-Many & Full Attribute Suite

### ✨ Nova Feature / New Feature

#### Many-to-Many Relationships & WebSalesSystem Support

**[PT-BR]** Implementação motivada por limitações de relacionamento identificadas no novo projeto `WebSalesSystem`. Suporte completo a relacionamentos Muitos-para-Muitos via atributo `[ManyToMany]`. Gerenciamento automático de tabelas de ligação, suporte a Lazy Loading e Eager Loading (`Include`). Novos métodos `LinkManyToMany`, `UnlinkManyToMany` e `SyncManyToMany` adicionados ao `IDbSet<T>`.

**[EN]** Implementation driven by relationship limitations identified in the new `WebSalesSystem` project. Full support for Many-to-Many relationships via `[ManyToMany]` attribute. Automatic join table management, support for Lazy and Eager loading (`Include`). New methods `LinkManyToMany`, `UnlinkManyToMany`, and `SyncManyToMany` added to `IDbSet<T>`.

#### Full Attribute Suite

**[PT-BR]** Expansão do mapeamento para suportar os requisitos de modelagem do `WebSalesSystem`:

- `[SoftDelete]`: Filtro automático e deleção lógica.
- `[Version]`: Controle de concorrência otimista.
- `[CreatedAt]` / `[UpdatedAt]`: Auditoria automática de timestamps.
- `[JsonColumn]`: Armazenamento de objetos e listas como JSON.
- `[DbType]`, `[Precision]`, `[MaxLength]`: Controle refinado de tipos e constraints.

**[EN]** Mapping expansion to support `WebSalesSystem` modeling requirements:

- `[SoftDelete]`: Automatic filtering and logical deletion.
- `[Version]`: Optimistic concurrency control.
- `[CreatedAt]` / `[UpdatedAt]`: Automatic timestamp auditing.
- `[JsonColumn]`: Storage of objects and lists as JSON.
- `[DbType]`, `[Precision]`, `[MaxLength]`: Refined control over types and constraints.

### 🐛 Bug Fixes

- **WebSalesSystem List Deserialization**: Resolvido `EBindingException` na desserialização de `IList<T>` em DTOs complexos. Implementado fallback para `TSmartList<T>` no `TActivator` quando fábricas de coleções não são encontradas.
- **Lazy Loading Memory Leak**: Correção de `Invalid pointer operation` causado por dupla liberação de entidades. Agora o `LazyLoader` respeita o ciclo de vida do `DbContext` (`OwnsObjects := False`).
- **FireDAC Params**: Resolvido erro de "Parameter not found" causado por limpeza incorreta de definições de parâmetros em reuso de comandos.
- **M2M Index**: Corrigido erro de índice (off-by-one) na recuperação de IDs da tabela de ligação.

---

## 2026-02-01 - Zero-Leak Architecture & Attribute Revamp

### ⚠️ Breaking Changes & Modernization

#### TDextServices Refactoring

**[PT-BR]** `TDextServices` e os Builders (`AddHealthChecks`, `AddBackgroundServices`) agora são **Records**. Não é mais necessário (nem possível) chamar `.Free`. Isso elimina os memory leaks causados por capturas de ciclos em closures.

**[EN]** `TDextServices` and Builders (`AddHealthChecks`, `AddBackgroundServices`) are now **Records**. It is no longer necessary (nor possible) to call `.Free`. This eliminates memory leaks caused by cycle captures in closures.

#### New Attribute Names (Parity with .NET)

| Antes / Before | Depois / After |
|----------------|----------------|
| `[Controller]` | `[ApiController]` |
| `[Get]` | `[HttpGet]` |
| `[Post]` | `[HttpPost]` |
| `[Put]` | `[HttpPut]` |
| `[Delete]` | `[HttpDelete]` |
| `[Patch]` | `[HttpPatch]` |

**[PT-BR]** Os atributos antigos continuam funcionando mas estão **deprecated**. Use preferred names para melhor compatibilidade com o ecossistema .NET. O novo atributo `[Route]` agora é suportado na classe para prefixos de rota.

**[EN]** Old attributes still work but are **deprecated**. Use preferred names for better compatibility with the .NET ecosystem. The new `[Route]` attribute is now supported at the class level for route prefixes.

**Novo Exemplo / New Example:**

```pascal
[ApiController]
[Route('/api/orders')]
TOrdersController = class
  [HttpGet]
  procedure GetAll(Ctx: IHttpContext);
  
  [HttpPost('{id}/cancel')]
  procedure Cancel(Ctx: IHttpContext; [FromRoute] Id: string);
end;
```

#### Deprecated Extensions (Memory Leak Fixes)

**[PT-BR]** As seguintes classes foram marcadas como **deprecated** por causarem memory leaks ou serem redundantes com a nova API `TDextServices`:

**[EN]** The following classes have been marked as **deprecated** because they caused memory leaks or are redundant with the new `TDextServices` API:

| Classe Deprecated | Substituição / Replacement |
|-------------------|----------------------------|
| `TServiceCollectionExtensions` | `TDextServices` |
| `TServiceProviderExtensions` | `IServiceProvider.GetService<T>` |
| `TApplicationBuilderModelBindingExtensions` | `TApplicationBuilderExtensions` |
| `TApplicationBuilderWithModelBinding` | `TApplicationBuilderExtensions.MapPost<T>` |

**Antes / Before (memory leak):**

```pascal
TApplicationBuilderModelBindingExtensions
  .WithModelBinding(App)
  .MapPost<TUserRequest>('/api/users',
    procedure(Req: TUserRequest)
    var UserService: IUserIntegrationService;
    begin
      UserService := TServiceProviderExtensions.GetService<IUserIntegrationService>(App.GetServiceProvider);
      UserService.ProcessUser(Req);
    end
  );
```

**Depois / After (sem leak, DI automático):**

```pascal
TApplicationBuilderExtensions.MapPost<TUserRequest, IUserIntegrationService>(App, '/api/users',
  procedure(Req: TUserRequest; UserService: IUserIntegrationService)
  begin
    // Service injetado automaticamente!
    UserService.ProcessUser(Req);
  end
);
```

---

## 2026-01-31 - API Cleanup: JSON, CORS & Swagger

### ⚠️ Breaking Changes (com compatibilidade / with backward compatibility)

Os tipos e métodos antigos foram marcados como `deprecated` e continuarão funcionando. Recomendamos migrar para a nova API.

**The old types and methods have been marked as `deprecated` and will continue to work. We recommend migrating to the new API.**

#### JSON Settings

| Antes / Before | Depois / After |
|----------------|----------------|
| `TDextSettings` | `TJsonSettings` |
| `TDextCaseStyle` | `TCaseStyle` |
| `TDextEnumStyle` | `TEnumStyle` |
| `TDextFormatting` | `TJsonFormatting` |
| `TDextDateFormat` | `TDateFormat` |
| `.WithCamelCase` | `.CamelCase` |
| `.WithCaseInsensitive` | `.CaseInsensitive` |
| `.WithEnumAsString` | `.EnumAsString` |

**Sintaxe antiga / Old syntax:**

```pascal
TDextJson.SetDefaultSettings(TDextSettings.Default.WithCamelCase.WithCaseInsensitive);
```

**Sintaxe nova / New syntax:**

```pascal
DefaultJsonSettings(JsonSettings.CamelCase.CaseInsensitive);
```

#### CORS Configuration

| Antes / Before | Depois / After |
|----------------|----------------|
| `.WithOrigins(...)` | `.Origins(...)` |
| `.WithMethods(...)` | `.Methods(...)` |
| `.WithHeaders(...)` | `.Headers(...)` |
| `TCorsBuilder.Create...` | `Cors...` |

**Sintaxe antiga / Old syntax:**

```pascal
App.Builder.UseCors(
  procedure(Builder: TCorsBuilder)
  begin
    Builder.WithAllowAnyOrigin.WithAllowAnyMethod;
  end);
```

**Sintaxe nova / New syntax:**

```pascal
Builder.UseCors(Cors.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader);
```

#### Swagger Configuration

| Antes / Before | Depois / After |
|----------------|----------------|
| `.WithTitle(...)` | `.Title(...)` |
| `.WithVersion(...)` | `.Version(...)` |
| `.WithDescription(...)` | `.Description(...)` |
| `TOpenAPIBuilder.Create...` | `Swagger...` |

**Sintaxe antiga / Old syntax:**

```pascal
var SwaggerOpts := TOpenAPIBuilder.Create;
SwaggerOpts.WithTitle('My API');
SwaggerOpts.WithVersion('v1');
App.Builder.UseSwagger(SwaggerOpts);
```

**Sintaxe nova / New syntax:**

```pascal
Builder.UseSwagger(Swagger.Title('My API').Version('v1'));
```

#### Controller Attributes

| Antes / Before | Depois / After |
|----------------|----------------|
| `[DextController('/api')]` | `[Route('/api')]` ou `[Controller('/api')]` |
| `[DextGet('')]` | `[Get('')]` |
| `[DextPost('')]` | `[Post('')]` |
| `[DextPut('/{id}')]` | `[Put('/{id}')]` |
| `[DextDelete('/{id}')]` | `[Delete('/{id}')]` |
| `[DextPatch('/{id}')]` | `[Patch('/{id}')]` |
| `EDextHttpException` | `HttpException` |

#### Web Application & Hosting

| Antes / Before | Depois / After |
|----------------|----------------|
| `TDextApplication` | `TWebApplication` |
| `TDextAppBuilder` | `AppBuilder` |
| `TDextWebHost` | `WebHost` |
| `TWebApplication.Create` | `WebApplication` (Global Function) |

**Sintaxe antiga / Old syntax:**

```pascal
[DextController('/api/orders')]
TOrdersController = class
  [DextGet('')]
  procedure GetAll(Ctx: IHttpContext);
  
  [DextPost('')]
  procedure Create(Ctx: IHttpContext; Request: TCreateOrderRequest);
end;
```

**Sintaxe nova / New syntax:**

```pascal
[Route('/api/orders')]
TOrdersController = class
  [Get('')]
  procedure GetAll(Ctx: IHttpContext);
  
  [Post('')]
  procedure Create(Ctx: IHttpContext; Request: TCreateOrderRequest);
end;
```

### ✨ Novas Features / New Features

1. **Função global `JsonSettings`**: Retorna um `TJsonSettings` padrão para configuração fluente.

   **Global function `JsonSettings`**: Returns a default `TJsonSettings` for fluent configuration.

2. **Procedure `DefaultJsonSettings`**: Atalho para `TDextJson.SetDefaultSettings`.

   **Procedure `DefaultJsonSettings`**: Shorthand for `TDextJson.SetDefaultSettings`.

3. **Função global `Cors`**: Cria um `TCorsBuilder` para configuração fluente.

   **Global function `Cors`**: Creates a `TCorsBuilder` for fluent configuration.

4. **Função global `Swagger`**: Cria um `TOpenAPIBuilder` para configuração fluente.

   **Global function `Swagger`**: Creates a `TOpenAPIBuilder` for fluent configuration.

5. **Função global `WebApplication`**: Atalho para `TWebApplication.Create`.

   **Global function `WebApplication`**: Shorthand for `TWebApplication.Create`.

6. **Modulariedade (DEXT_ENABLE_ENTITY)**: Agora é possível desativar a dependência do ORM/Banco de dados globalmente no `Dext.inc` ao comentar a diretiva `{$DEFINE DEXT_ENABLE_ENTITY}`. Isso reduz o tamanho do binário para projetos que não utilizam o ORM.

   **Modularity (DEXT_ENABLE_ENTITY)**: It is now possible to disable ORM/Database dependency globally in `Dext.inc` by commenting the `{$DEFINE DEXT_ENABLE_ENTITY}` directive. This reduces binary size for projects not using the ORM.

7. **Regra de Ordem de Importação ("Last Helper Wins")**: Para garantir que todos os métodos fluentes (Core + Entity + Web) estejam disponíveis no `TDextServices`, as units devem ser importadas na ordem específica: `Dext, Dext.Entity, Dext.Web`.

   **Unit Order Rule ("Last Helper Wins")**: To ensure all fluent methods (Core + Entity + Web) are available in `TDextServices`, units must be imported in a specific order: `Dext, Dext.Entity, Dext.Web`.

8. **Padrão `var Builder`**: Novo padrão recomendado no `TStartup.Configure`:

```pascal
procedure TStartup.Configure(const App: IWebApplication);
begin
  var Builder := App.Builder;
  
  DefaultJsonSettings(JsonSettings.CamelCase.CaseInsensitive);
  
  Builder
    .UseExceptionHandler
    .UseHttpLogging;
    
  Builder.UseCors(Cors.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader);
  
  Builder.MapControllers;
  
  Builder.UseSwagger(Swagger.Title('My API').Version('v1'));
end;
```

### 📄 Documentação / Documentation

- RFC-001 criado em `Docs/RFC/RFC-001-JSON-API-CLEANUP.md`
- RFC-002 criado em `Docs/RFC/RFC-002-DEXT-WEB-API-CLEANUP.md`
- SKILL.md atualizado com novas convenções
- Exemplo `DextFood.Startup.pas` atualizado

---

## 2026-01-30 - Dext.Entity: FireDAC Transaction Fix

### 🐛 Bug Fix

**Correção crítica no driver FireDAC**: Transações explícitas agora funcionam corretamente.

**Critical fix in FireDAC driver**: Explicit transactions now work correctly.

O construtor `TFireDACTransaction.Create` agora vincula corretamente a transação ao `Connection.Transaction` e `Connection.UpdateTransaction`, garantindo que os comandos SQL respeitem a transação ativa.

---

## 2026-01-28 - Dext.Net.RestClient

### ✨ Nova Feature

**Dext Rest Client**: Novo cliente HTTP moderno para Delphi com:

- API fluente e intuitiva
- Suporte a async/await com Promises
- Serialização JSON integrada
- Interceptadores de request/response
- Retry policies

```pascal
var Response := RestClient
  .BaseUrl('https://api.example.com')
  .Get('/users')
  .Execute;
```

---

## 2026-01-21 - Dext.UI Navigator Framework

### ✨ Nova Feature

**Navigator Framework**: Sistema de navegação para aplicações MVVM Desktop.

- `INavigator` interface para navegação entre views
- `TSimpleNavigator` implementação leve
- Integração com DI Container
- Gerenciamento automático de lifecycle de ViewModels

```pascal
Navigator.NavigateTo<TCustomerEditViewModel>(
  procedure(VM: TCustomerEditViewModel)
  begin
    VM.LoadCustomer(CustomerId);
  end);
```

---

## 2026-01-15 - Dext.Entity Smart Properties

### ✨ Nova Feature

**Smart Properties (Prototype Pattern)**: Consultas LINQ-like com propriedades tipadas.

```pascal
var Customer := Prototype.Entity<TCustomer>;
var List := Db.Customers
  .Where(Customer.Active = True)
  .Where(Customer.City = 'São Paulo')
  .OrderBy(Customer.Name)
  .ToList;
```

---

## Como Contribuir / How to Contribute

Se você encontrar bugs ou tiver sugestões, por favor abra uma issue no GitHub.

**If you find bugs or have suggestions, please open an issue on GitHub.**
