# 🔧 Object Tracking Fix — Diagnóstico, Correção e Plano de Testes

> Data: 08 de Abril de 2026  
> Contexto: Correção do `EInvalidPointer` no Web.SmartPropsDemo após refactoring do Object Tracking

---

## 1. Diagnóstico do Bug

### Sintoma
```
GET /products → HTTP 500
EInvalidPointer: Invalid pointer operation
```

### Causa Raiz
A implementação inicial do Object Tracking Opção B (ChangeTracker integration) tinha **dois problemas**:

#### Problema A: Resolução de `IDbContext` falha
O `CleanupBoundObjects` tentava resolver `IDbContext` via `TypeInfo(IDbContext)`, mas o `AddDbContext<TAppDbContext>` registra o DbContext como **classe concreta**, não como interface. O `GetService` retornava vazio → `Tracker = nil` → **todos os objetos eram liberados**, incluindo entidades.

#### Problema B: Sem fallback
Quando o `Tracker` era `nil` (por falha na resolução ou por ausência de DbContext), o código liberava todos os objetos incondicionalmente. Isso causava double-free ou use-after-free de entidades gerenciadas pelo DbSet.

### Fluxo do Bug
```
1. POST /products → TProduct bindado do body → adicionado a FBoundObjects
2. Controller: Db.Products.Add(Product) → SaveChanges → OK
3. CleanupBoundObjects: GetService(IDbContext) → FALHA (registrado como TAppDbContext)
4. Tracker = nil → Product.Free → Product destruído
5. Mas o DbSet interno ainda referencia o Product (está no IdentityMap)
6. GET /products → DbSet.ToList → acessa Product já destruído → EInvalidPointer
```

---

## 2. Correção Aplicada

**Arquivo:** `Sources\Web\Mvc\Dext.Web.HandlerInvoker.pas`

### Abordagem Híbrida (já implementada)

```
CleanupBoundObjects agora usa:
├── COM DbContext/ChangeTracker disponível:
│   └── Verifica Tracker.GetTrackedEntities.ContainsKey(obj) ← Robusto
└── SEM DbContext/ChangeTracker:
    └── Fallback: verifica [Table] attribute via `Attr is TableAttribute` ← Seguro
```

**Vantagens sobre o código original:**
- `Attr is TableAttribute` ao invés de `Attr.ClassName = 'TableAttribute'` (type-safe)
- Quando DbContext está disponível, usa ChangeTracker (zero false positives)
- Quando não está, o fallback é seguro e compatível

### Status: ✅ Correção aplicada — aguardando compilação e teste

---

## 3. Plano de Testes Unitários Necessários

> [!IMPORTANT]
> Os testes existentes não cobriram este cenário porque o tracking de objetos é testado apenas indiretamente via os exemplos de integração.

### 3.1 Testes para `TPathApiVersionReader` (Tarefa 3)
**Unit de teste:** `Tests\Web\Test.Dext.Web.Versioning.pas` (novo ou existente)

| # | Teste | Esperado |
|---|-------|----------|
| 1 | Path `/v1/users` com prefix padrão 'v' | Retorna `'1'` |
| 2 | Path `/v2.1/api/orders` | Retorna `'2.1'` |
| 3 | Path `/api/users` (sem prefix) | Retorna `''` |
| 4 | Path `/` (raiz) | Retorna `''` |
| 5 | Path vazio `''` | Retorna `''` |
| 6 | Path `/V1/users` (case insensitive) | Retorna `'1'` |
| 7 | Path `/version2/users` com prefix 'version' | Retorna `'2'` |
| 8 | Path `/v/users` (prefix sem número) | Retorna `''` |

### 3.2 Testes para `GetHeader` / `GetHeaders` (Tarefa 1)
**Unit de teste:** `Tests\Net\Test.Dext.Net.RestClient.pas` (novo ou existente)

| # | Teste | Esperado |
|---|-------|----------|
| 1 | `GetHeader('Content-Type')` com header presente | Retorna valor correto |
| 2 | `GetHeader('content-type')` case insensitive | Retorna mesmo valor |
| 3 | `GetHeader('X-Missing')` header ausente | Retorna `''` |
| 4 | `GetHeaders` retorna array completo | Array com todos headers |
| 5 | Response sem headers (nil) | `GetHeader` retorna `''` sem crash |
| 6 | `TRestResponse<T>` propaga headers | Headers acessíveis na response genérica |

### 3.3 Testes para `TOAuth2ClientCredentialsProvider` (Tarefa 2)
**Unit de teste:** `Tests\Net\Test.Dext.Net.Authentication.pas` (novo ou existente)

| # | Teste | Esperado |
|---|-------|----------|
| 1 | Criação com parâmetros válidos | Provider criado sem erro |
| 2 | `GetHeaderValue` retorna `'Bearer ...'` | Token com prefix Bearer |
| 3 | Thread-safety (múltiplas chamadas concorrentes) | Sem race conditions |
| 4 | Token URL inválida gera exceção descritiva | Exception com HTTP status |
| 5 | Response sem `access_token` gera exceção | Exception 'missing access_token' |

> [!NOTE]
> Testes 2-5 requerem mock HTTP server ou mock do `THTTPClient`. Avaliar se já existe infraestrutura de mock no Dext Testing.

### 3.4 Testes para `CleanupBoundObjects` (Tarefa 4 — CRÍTICOS)
**Unit de teste:** `Tests\Web\Test.Dext.Web.HandlerInvoker.pas` (novo)

| # | Teste | Esperado |
|---|-------|----------|
| 1 | DTO sem [Table] é liberado | Objeto destruído corretamente |
| 2 | Entidade com [Table] e sem DbContext **NÃO** é liberada | Fallback via attribute funciona |
| 3 | Entidade com [Table] e com DbContext (no ChangeTracker) **NÃO** é liberada | ChangeTracker check funciona |
| 4 | Entidade com [Table] e com DbContext (NÃO no ChangeTracker) **NÃO** é liberada | Fallback ativado quando tracker não contém |
| 5 | Mix de DTOs e Entidades | Apenas DTOs são liberados |
| 6 | FBoundObjects vazio | Cleanup não crasheia |

> [!IMPORTANT]
> O teste **#2** é exatamente o cenário que causou o bug no SmartPropsDemo. Ele é o mais crítico para regressão.

---

## 4. Documentação Pendente

- [x] `Features_Implemented_Index.md` — Atualizado
- [x] `Improvement_Opportunities.md` — 4 itens marcados como ✅
- [ ] XML Doc nos arquivos fonte — Completo para novas classes, revisar consistência

---

## 5. Arquivos Modificados (Referência Completa)

| Arquivo | Tarefa | Mudança |
|---------|--------|---------|
| `Sources/Web/Dext.Web.Versioning.pas` | 3 | `TPathApiVersionReader` nova classe |
| `Sources/Web/Dext.Web.pas` | 3 | Alias `TPathApiVersionReader` |
| `Sources/Web/Mvc/Dext.Web.HandlerInvoker.pas` | 4 | CleanupBoundObjects híbrido + tracking incondicional |
| `Sources/Net/Dext.Net.RestClient.pas` | 1+2 | GetHeaders, FHeaders, OAuth2 fluent |
| `Sources/Net/Dext.Net.Authentication.pas` | 2 | `TOAuth2ClientCredentialsProvider` |
| `Docs/Features_Implemented_Index.md` | — | Nova seção Net, versioning, lifecycle |
| `Docs/Plans/Improvement_Opportunities.md` | — | 4 itens ✅ |

---

## 6. Comandos de Verificação

### Compilar Framework
```powershell
& cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && "C:\dev\Dext\DextRepository\Scripts\build_framework.bat"'
```

### Executar SmartPropsDemo Test
```powershell
cd C:\dev\Dext\DextRepository\Examples\Web.SmartPropsDemo
.\Test.Web.SmartPropsDemo.ps1
```

### Executar Todos os Testes (na IDE)
Abrir o projeto de testes no Delphi e executar via TestInsight.

---

*Documento de referência para continuação do trabalho de estabilização RC 1.0.*
