# 📑 Dext Framework - Features Implemented Index

Este documento serve como um índice mestre de todas as funcionalidades implementadas no Dext Framework. Ele deve ser usado como referência para auditorias de qualidade, documentação e cobertura de testes.

> [!IMPORTANT]
> Este índice foi gerado via "Raio-X" técnico nos fontes direto. Todas as funcionalidades listadas abaixo possuem implementação validada nas pastas `Sources/`.

---

## 🧩 1. Dext Core Foundation (Sources\Core)

Fundação de baixo nível e utilitários de alto desempenho para o ecossistema Dext.

- **Dext.Core.Reflection**: Inclui o motor de **Smart Properties** para resolução recursiva de caminhos (ex: `User.Address.Street`) e o **Metadata Engine** com cache global de tipos e scanning de atributos de alta performance.
- **Dext.DI (Dependency Injection)**: Modelo híbrido com suporte a ARC (Interfaces) e Não-ARC (Classes), ciclos de vida Singleton, Transient e Scoped, e suporte a **Auto-Collections** (instanciação automática de listas).
- **Dext.Json (High Performance Engine)**: Driver-based (`DextJsonDataObjects` / `System.JSON`) com suporte a buffers `IDataReader`, **Automatic Casing** (Pascal, camel, snake_case) e **Utf8 Serializer** de baixa alocação.
- **Dext.Configuration**: Sistema hierárquico estilo .NET com suporte a múltiplos provedores (JSON, YAML, EnvVars, CLI) e o **Options Pattern** para configuração tipada via `IOptions<T>`.
- **Dext.Types & Semantics**: Suporte nativo a **UUID v7 (RFC 9562)** com armazenamento Big-Endian, **Nullable\<T\>**, Smart Enums e conversores de tipo baseados em RTTI.
- **Dext.Core.Activator**: Motor de ativação com **Greedy Strategy** para resolução de construtores complexos.
- **Dext.Threading & Async**: Implementação fluente de **Async/Await** via `TAsyncTask` e suporte a **CancellationToken** para cancelamento cooperativo.
- **Dext.Core.Memory**: Gerenciamento de memória avançado com **Dext.Core.Span** (Zero-allocation) e `Dext.MM` para buffers temporários.

---

## 📚 2. Dext Collections Library (Sources\Core)

Biblioteca de coleções moderna otimizada para performance extrema e concorrência.

- **Standard & Concurrent**: Implementações otimizadas de List, Dictionary, HashSet e versões thread-safe como `ConcurrentQueue` e `ConcurrentStack`.
- **Frozen Collections**: Estruturas de dados imutáveis de alto desempenho otimizadas para cenários de leitura intensa (estilo .NET 8).
- **Channels**: Primitivas de comunicação assíncrona estilo Go (Producer/Consumer) para construção de pipelines de dados.
- **Aceleração de Hardware**: Suporte a **SIMD & Vectors** (AVX/SSE) para processamento matemático em lote e **Raw Collections** para redução de overhead do Garbage Collector.

---

## 🌐 3. Dext Web Framework (Sources\Web)

Framework web modular baseado em pipeline de middlewares e arquitetura Controller/Minimal API.

- **Minimal API & Bootstrapping**: Classe `TWebApplication` para inicialização fluente. Inclui carregamento automático de configurações (`appsettings.json`, `appsettings.yaml`, Environment Variables), registro de serviços e build do pipeline em uma única fachada.
- **Pipeline de Middlewares**: Arquitetura baseada em "Chain of Responsibility" suportando middlewares funcionais (delegates) e baseados em classe com injeção de dependência via construtor.
- **Roteamento Avançado**: Motor de rotas com suporte a parâmetros dinâmicos (ex: `{id}`), restrições de rota e versionamento nativo de API via cabeçalho (`THeaderApiVersionReader`), query string (`TQueryStringApiVersionReader`), path (`TPathApiVersionReader`) e composição de múltiplas estratégias (`TCompositeApiVersionReader`).
- **Model Binding Inteligente**: Suporte a **Hybrid Binding** e atributos `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`, `[FromServices]`. Otimização **Zero-Allocation** com deserialização UTF-8 direta para recordes e classes.
- **Hosting Foundation**: Abstrações de `IWebHost` e `IWebHostBuilder`. Servidor padrão baseado em **Indy** com suporte a **OpenSSL** e **Taurus SSL**. Inclui suporte a **IHostedService** para tarefas de background.
- **Auto-Migrations**: Sincronização automática de schema durante o startup do servidor web.
- **Segurança & Identidade**: Abstração de `IClaimsPrincipal` para suporte a autenticação JWT, Basic Auth e Cookies.
- **Middleware Pipeline Nativo**: Logger, Compression (GZip/Brotli), Exception Handling (**ProblemDetails**), **DeveloperExceptionPage**, CORS e StartupLock.
- **Rate Limiting**: Políticas de Fixed/Sliding Window, Token Bucket e Concurrency Limiter.
- **Caching & Observability**: Suporte a In-Memory/Redis, **Health Checks** detalhados e geração automática de **OpenAPI / Swagger**.
- **Real-time & Hubs**: Suporte nativo a **SSE (Server-Sent Events)** e infraestrutura de Hubs inspirada no SignalR com `IHubContext` e protocolos JSON.
- **Object Lifecycle Management**: Tracking robusto de objetos criados por Model Binding, com integração ao **ChangeTracker** do ORM para transferência automática de ownership (evita memory leaks em entidades persistidas).

---

## 📊 4. Dext ORM & Entity Framework (Sources\Data)

Persistência poliglota com foco em produtividade Code-First e performance.

- **Core Persistence**: Implementação de `TDbContext` (Unit of Work) e `DbSet<T>` (Repository) com **Change Tracking** automático e **Identity Map** para unicidade de instâncias.
- **Query Engine (LINQ-like)**: Query fluída com suporte a Projeção (**Select**), Paging, Aggregates e **SQL Cache** para reaproveitamento de comandos SQL gerados.
- **Specification Pattern**: Integração com `Dext.Specifications` para regras de negócio desacopladas e reutilizáveis.
- **Relacionamentos & Loading**: Suporte a One-to-One, One-to-Many e Many-to-Many com estratégias de **Lazy Loading** (via Proxy) e **Eager Loading** (`Include`/`ThenInclude`).
- **Migrations System**: Evolução Code-First automatizada com snapshots cronológicos do modelo de dados.
- **Poliglota (Dialetos)**: Suporte nativo a PostgreSQL, SQL Server, MySQL, SQLite, Oracle e Firebird.
- **EntityDataSet**: Componente especializado para VCL/FMX com suporte a **Design-Time Data Preview**, Sorting e Filtering inline.
- **Performance & Normalization**: **Streaming Iterators** (Flyweight pattern) para grandes volumes e conversores automáticos para GUID, Enums, JSONB e UUID v7.

---

## 🔌 5. Dext Net (HTTP Client & Authentication) (Sources\Net)

Cliente HTTP de alto desempenho com suporte a autenticação plugável.

- **REST Client (TRestClient)**: API fluente com Connection Pooling, retry automático com backoff exponencial e suporte a Async/Await.
- **Response Headers**: Acesso completo aos headers da resposta HTTP via `GetHeader` (case-insensitive) e `GetHeaders` (TNetHeaders array).
- **Authentication Providers**: Bearer Token (JWT), Basic Auth (RFC 7617), API Key e **OAuth 2.0 Client Credentials** (RFC 6749 §4.4) com token caching automático, refresh thread-safe e margem de segurança de 30s.
- **HTTP Request Builder**: Suporte a `THttpRequestInfo` para integração com parsers `.http`.

---

## 🧪 6. Dext Testing Framework (Sources\Testing)

Infraestrutura de testes integrada para garantia de qualidade.

- **Test Runner & Dashboard**: Executor CLI de alta velocidade e host visual interno para monitoramento de execução.
- **Assertions & Mocking**: API fluente de asserções rica e framework de **Mocking dinâmico** via Proxies com interceptores de chamada.
- **Integração IDE**: Suporte nativo ao **TestInsight** e geração de relatórios em HTML, JSON e XML (JUnit).

---

## 🖥️ 7. Outras Tecnologias & Design-Time (Sources\UI, Sources\Design)

- **Dext UI Framework**: Arquitetura **MVU** reativa para VCL/FMX, com Navigator (baseado em rotas), State Management desacoplado e Binding potente.
- **Interception Engine**: Motor de proxy para intercepção de métodos, base para Mocks e recursos de AOP.
- **Design-Time Experts**: Visualização de dados real-time no IDE Grid (Data Preview) e editores de propriedades especializados para metadados.
- **Dext.Web.DataApi**: Motor de geração dinâmica de endpoints CRUD baseados no DbContext.

---

---

*Dext Framework - Exhaustive Technical Map & Features Index. (Revision: April 08, 2026).*
