# 🌐 Dext Web Framework - Roadmap

Este documento foca nas funcionalidades de alto nível do framework web (API, MVC, Views), construído sobre a infraestrutura do Dext.

> **Visão:** Um framework web completo, produtivo e moderno, comparável ao ASP.NET Core e Spring Boot.

---

## 🚀 Funcionalidades Core (Web)

### 0. HTTP Abstractions (Refactoring for Performance) 🔥

Blindagem das interfaces para suportar alta performance (Zero-Copy) no futuro.

- [x] **Lazy Headers**: `GetHeader(Name)` otimizado com acesso direto (sem alocação de dicionário).
- [ ] **Lazy Query**: Refatorar `GetQuery` para evitar parsing completo da QueryString quando apenas um parâmetro é solicitado.
- [x] **Items Bag**: Adicionar `Items: TDictionary<string, TValue>` em `IHttpContext` para comunicação entre Middlewares.
- [x] **Response Compression**: Suporte a GZip e Brotli (`Accept-Encoding`).
- [x] **Stream Writing**: Adicionado `Response.Write(TStream)` para suportar envio eficiente de arquivos.
- [ ] **Body Abstraction**: Abstrair o acesso ao Body para suportar `Span<Byte>` futuramente (Atual: `TStream`).

### 1. Web API Improvements (Prioridade Alta) 🔥

Melhorias na experiência de construção de APIs robustas e profissionais.

#### 0. **Object Serialization & Deserialization in Dext.Json** ✅ **CONCLUÍDO**

**Status da Serialização**: ✅ **COMPLETO**

- ✅ Adicionado método `SerializeObject(const AValue: TValue): IDextJsonObject`
- ✅ Atualizado `ValueToJson` para rotear `tkClass` corretamente (distinguir entre listas e objetos)
- ✅ Suporte a atributos `[JsonIgnore]` e `[JsonName]` para controle de serialização
- ✅ Lidar com objetos null (retornar `null` JSON)
- ✅ Serialização recursiva de objetos aninhados
- ✅ Suporte para `IList<TObject>` com objetos aninhados
- ✅ Zero memory leaks (validado com FastMM5)
- ✅ Testes criados (objetos simples, aninhados, listas, null)

**Próximos Passos** (por prioridade):

1. **🔥 Object Deserialization (URGENTE)** (6-8 horas) ✅ **CONCLUÍDO**
   - [x] Implementar `DeserializeObject(AJson: IDextJsonObject; AType: PTypeInfo): TValue`
   - [x] Suporte para objetos aninhados (recursivo)
   - [x] Suporte para `IList<TObject>` deserialization
   - [x] Criar instâncias via RTTI (`Create`)
   - [x] Setar propriedades via RTTI (`TRttiProperty.SetValue`)
   - [x] Lidar com propriedades null
   - [x] Testes abrangentes

2. **Circular Reference Detection** (2-3 horas)
   - [ ] Implementar `TDictionary<TObject, Boolean>` para rastrear objetos já serializados
   - [ ] Lançar exceção ou retornar `null` em caso de referência circular
   - [ ] Testes com grafos circulares

3. **Performance Optimization** (3-4 horas)
   - [ ] Cache de RTTI types (`TDictionary<PTypeInfo, TRttiType>`)
   - [ ] Cache de property metadata
   - [ ] Benchmark com objetos profundos (10+ níveis)
   - [ ] Otimizar clonagem de objetos JSON

**Exemplo de Uso Atual**:

```pascal
type
  TAddress = class
    Street: string;
    City: string;
  end;
  
  TPerson = class
    Name: string;
    Age: Integer;
    Address: TAddress;  // Objeto aninhado
  end;

// Serialização automática
var Json := TDextJson.Serialize(Person);
// {"Name":"John","Age":30,"Address":{"Street":"5th Ave","City":"NYC"}}
```

**Resultado**: Serialização completa de objetos, desbloqueando uso real do framework em APIs

---

- [x] **Content Negotiation Avançado**: Suporte a múltiplos formatos de saída baseados no header `Accept`.
  - [x] Interfaces: `IOutputFormatter` (JSON, XML, CSV).
  - [x] Implementação padrão JSON (já existente, mas desacoplar).
  - [ ] Suporte a XML (`text/xml`, `application/xml`) -> *Próximo passo.*
- [x] **API Versioning**: Estratégias para versionamento de endpoints.
  - [x] Via URL: `/v1/users` (Route Constraints).
  - [x] Via Query String: `?api-version=1.0`.
  - [x] Via Header: `X-Version: 1.0` ou `Accept` header.
- [x] **Multipart/Form-Data**: Suporte a upload de arquivos e formulários complexos (`IFormFile`).
- [x] **Cookies Support**: Suporte leitura e escrita (`TCookieOptions`).
- [ ] **OData Support**: Suporte parcial a queryable APIs (integrado com Dext Entity).
- [ ] **GraphQL Support**: Endpoint `/graphql` nativo com suporte a Queries, Mutations e Subscriptions.
- [ ] **gRPC Support**: Implementação de serviços gRPC de alta performance (Protobuf).

### 1.1. Database as API ✅ **CONCLUÍDO**

Zero-code REST endpoints a partir de entity classes.

- [x] **TDataApiHandler<T>**: Classe genérica para expor entities como REST API
- [x] **CRUD Endpoints**: GET (list), GET/{id}, POST, PUT/{id}, DELETE/{id}
- [x] **Query String Filtering**: Filtros automáticos baseados nas propriedades da entity
- [x] **Pagination**: Suporte a `limit` e `offset` via query string
- [x] **Security Policies**: `RequireAuth`, `RequireRole`, `RequireReadRole`, `RequireWriteRole`
- [x] **JSON Body Parsing**: Deserialização automática do body para POST/PUT
- [x] **Endpoint Configuration**: `ReadOnly`, `WriteOnly`, `AllowedMethods`
- [x] **RegisterForDisposal**: Lifecycle management via `IApplicationBuilder.RegisterForDisposal`
- [ ] **DataApi Query Builder**: Criar um builder tipado genérico para a criação de URLs e queries da DataAPI (resolvendo `_limit`, `_offset`, filtros compostos e `_orderby`) com segurança de tipos para uso em Testes e Clients.

**Exemplo de Uso**:

```pascal
// Uma linha = API REST completa
TDataApiHandler<TCustomer>.Map(App, '/api/customers', DbContext);

// Com security policies
TDataApiHandler<TCustomer>.Map(App, '/api/customers', DbContext,
  TDataApiOptions<TCustomer>.Create
    .RequireAuth
    .RequireReadRole('viewer')
    .RequireWriteRole('admin')
);
```

### 2. MVC & Views Engine

Expansão do suporte para aplicações Web completas (Server-Side Rendering).

- [x] **Views Engine**: Sistema de templates para renderização de HTML no servidor.
  - ✅ Sintaxe inspirada em Razor (`@Model.Name`) com **Web Stencils**.
  - ✅ Suporte a Layouts e Partials.
- [ ] **MVC Controllers**: Suporte completo ao padrão MVC.
  - ✅ `ViewResult`: Retornar views de Minimal APIs e controllers.
  - ✅ `ViewBag`/`ViewData`: Passagem de dados dinâmica.
  - [ ] `TagHelpers`: Componentes reutilizáveis em views (ex: `<dext-form>`).

### 3. Observability & Monitoring

Suporte nativo a padrões abertos de monitoramento para produção.

- [ ] **OpenTelemetry Support**: Integração completa com OTel.
  - Rastreamento automático de Requests (Middleware).
  - Propagação de Contexto (W3C Trace Context).
  - Exportadores para Jaeger/Zipkin/OTLP.
- [ ] **Metrics Dashboard**: Endpoint `/metrics` (Prometheus format) nativo.

### 4. Real-Time & Eventing (SignalR-like)

Suporte a comunicação bidirecional em tempo real.

- [x] **Dext.Web.Hubs** ✅ **IMPLEMENTADO**: Abstração de alto nível para comunicação em tempo real (SignalR-compatible).
  - *Status*: Pronto para v1.0
  - ✅ RPC Cliente-Servidor (`Clients.All.SendAsync`).
  - ✅ Gerenciamento de Grupos (`Groups.AddToGroupAsync`, `Groups.RemoveFromGroupAsync`).
  - ✅ Targeting de clientes (All, Caller, Others, Group, User).
  - ✅ Transporte via Polling (com suporte a SSE planejado).
  - ✅ JavaScript client (`dext-hubs.js`).
  - ✅ Exemplo completo (`Examples/Hubs/HubsExample`).
- [x] **Server-Sent Events (SSE)**: Infraestrutura pronta (usado internamente por Hubs).

### 5. UI & Frontend Strategy

Estratégia para construção de interfaces modernas, focando em produtividade e simplicidade (Server-Driven UI).

#### A. Modern Server-Side UI (HTMX)

- [x] **HTMX Integration**: Suporte nativo a respostas parciais (HTML Fragments) e auto-detecção de `HX-Request`.
  - Permite criar SPAs (Single Page Apps) sem escrever JavaScript complexo.
- [ ] **UI Components Library**: Biblioteca de componentes web (Bootstrap/Tailwind) encapsulados em classes Delphi.
  - Licença amigável (MIT/Apache), sem dependências de terceiros duvidosas.

#### B. Legacy Bridge (Migration Path)

- [ ] **VCL/FMX Bridge API**: Camada de compatibilidade para expor lógicas de negócio legadas como APIs REST/HTMX.
- [ ] **Form Renderer**: (Experimental) Renderizar Forms VCL simples como HTML para facilitar migração gradual.

#### C. Future: Dext Blazor / WASM

- [ ] **Server-Side Rendering**: Modelo de componentes stateful no servidor (via WebSocket/SignalR), similar ao Blazor Server.
- [ ] **WebAssembly Compiler**: (Long Term) Investigação sobre compilação de Delphi para WASM para rodar lógica no cliente.

---

### 6. Security & Identity

Modernização da stack de autenticação para padrões de mercado (OAuth2/OIDC).

#### A. Authentication Handlers

- [ ] **OAuth2 & OpenID Connect (OIDC)**: Client genérico para autenticação com qualquer provedor compatível (Auth0, Keycloak, Azure AD).
- [ ] **Social Providers**: Configurações pré-definidas para Google, Facebook, GitHub, Microsoft.
- [ ] **Enterprise SSO**: Suporte a Single Sign-On via SAML 2.0 ou OIDC para integração corporativa.

#### B. Authorization & Policy

- [ ] **Policy-Based Authorization**: Sistema flexível de políticas (`[Authorize('MustBeAdmin')]`) além de simples Roles.
- [ ] **Resource-Based Auth**: Autorização baseada no recurso sendo acessado (ex: "Usuário pode editar ESTE documento?").

---

## 📅 Roadmap de Integração

### Fase 1: Fundação (Infraestrutura)

*Depende de:* [INFRA_ROADMAP.md](INFRA_ROADMAP.md)

- [x] **WebBroker Adapter** ✅ **IMPLEMENTADO**: Suporte a deployment nativo como ISAPI/CGI via WebBroker (IIS/Apache) lado a lado com o Indy.
- [x] **DCS Adapter (epoll/IOCP/kqueue)** ✅ **IMPLEMENTADO**: Integração via `TServerFactory` suportando I/O Assíncrono de altíssima performance.
  - ⚠️ *Aviso de Licença: A biblioteca DCS usa LGPL-3.0. Requer linkagem dinâmica (BPL) ou a distribuição em código aberto se não for uso interno.*
- [ ] Explorar/Migrar motores de HTTP de alta performance (como `http.sys` ou wrappers `epoll` nativos) com licenças permissivas (Apache 2.0 / MIT) nativamente no Dext.
- [ ] Adotar `RawUTF8` no pipeline de processamento de requisições.

### Fase 2: Ecosystem

- [ ] **Dext.Identity**: Sistema de identidade completo (Users, Roles, Claims, OAuth2/OIDC).
- [ ] **Dext.Blazor**: (Futuro) Componentes UI server-side ou integração com WebAssembly.
