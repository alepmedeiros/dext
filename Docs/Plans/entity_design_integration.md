# Plano de Implementacao: Design-Time do TEntityDataSet

Ultima atualizacao: 2026-04-01

Este documento consolida o estado real da implementacao de design time do `TEntityDataSet`, registra decisoes de arquitetura e organiza o backlog para levar a experiencia ao nivel esperado no ecossistema Delphi.

## 1. Objetivo

Entregar uma experiencia de design time que permita:

- selecionar entidades do projeto sem configuracao manual tediosa;
- gerar e manter `TFields` persistentes com excelente fidelidade aos metadados do Dext;
- abrir o dataset em design time com dados reais ou de preview;
- facilitar o design de componentes dependentes de dataset, como `cxGrid`, `DBGrid`, editores e relatorios;
- reagir a alteracoes no codigo-fonte das entidades sem quebrar a IDE.

## 2. Estado Atual Consolidado

### 2.1. O que ja esta implementado

- Existe pacote design-only [`Dext.EF.Design.dpk`](C:\dev\Dext\DextRepository\Sources\Dext.EF.Design.dpk).
- Existe pacote de componentes [`Dext.EF.Components.dpk`](C:\dev\Dext\DextRepository\Sources\Dext.EF.Components.dpk), usado para os componentes que ficam disponiveis na IDE e tambem em runtime.
- O componente [`TEntityDataProvider`](C:\dev\Dext\DextRepository\Sources\Data\Dext.Entity.DataProvider.pas) ja existe e expoe:
  - `ModelUnits: TStrings`
  - `Connection: TFDConnection`
  - `FDConnection: TFDConnection`
  - `Dialect: TDatabaseDialect`
  - `DialectName: string`
  - `PreviewMaxRows: Integer`
  - `DebugMode: Boolean`
  - `EntityCount: Integer`
  - `LastRefreshSummary: string`
  - cache de `TEntityClassMetadata`
  - `RefreshMetadata`, `RefreshUnit`, `GetEntities`, `GetEntityMetadata`
  - `ResolveEntityClass`, `GetEntityUnitName`, `BuildPreviewSql`, `CreatePreviewItems`
  - autodiscovery de units do projeto ativo quando `ModelUnits` esta vazio
- O parser AST de metadata de design time existe em [`Dext.EF.Design.Metadata.pas`](C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Metadata.pas) e ja:
  - identifica classes com `[Table]` ou `[Entity]`;
  - extrai `ClassName`, `TableName`, `UnitName`;
  - extrai membros e varios atributos de UI/validacao.
- O `TEntityDataSet` ja possui as propriedades publicadas:
  - `DataProvider: TComponent`
  - `EntityClassName: string`
- O `TEntityDataSet` ja resolve automaticamente `FEntityClass` a partir de `DataProvider + EntityClassName` e tenta reconstruir `TEntityMap` quando necessario.
- O `TEntityDataSet` ja implementa [`GenerateFields`](C:\dev\Dext\DextRepository\Sources\Data\Dext.Entity.DataSet.pas), consumindo `IEntityDataProvider` para criar campos persistentes em design time.
- O `GenerateFields` ja foi evoluido para tambem sincronizar metadata de campos existentes em vez de apenas criar os faltantes.
- O `InternalOpen` do dataset ja tenta carregar preview real no proprio `TEntityDataSet` em design time via provider.
- Ja existe editor de propriedade para `EntityClassName` e component editor com os verbos:
  - `Generate Fields from Source`
  - `Open Preview Data`
  - `Preview SQL/Data...`
- Ja existe component editor para `TEntityDataProvider` com verbos de refresh/scan do projeto.
- Ja existe property editor para `DataProvider`, restringindo a selecao a instancias de `TEntityDataProvider` no owner atual.
- Ao selecionar `EntityClassName`, o design time ja tenta injetar a unit necessaria no `uses` e gerar os fields.
- Ja existe uma janela de preview baseada em `TFDQuery` em [`Dext.EF.Design.Preview.pas`](C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Preview.pas).
- Ja existe um notifier OTAPI em [`Dext.EF.Design.Expert.pas`](C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Expert.pas) capaz de disparar `RefreshMetadata` em `TEntityDataProvider` abertos.
- O registro do design time foi consolidado para garantir que os property editors e component editors sejam efetivamente carregados pela IDE.
- O `TEntityDataProvider` foi removido do package design-only e migrado para o package de componentes, evitando dependencia de `ToolsAPI` em aplicacoes.

### 2.2. O que esta parcial

- O parser funciona, mas hoje e uma implementacao propria do pacote de design e ainda nao esta claramente desacoplado/reaproveitado do pipeline do `dext.exe`.
- O `GenerateFields` cria `TFields`, mas:
  - nao sincroniza remocoes;
  - nao renomeia campos alterados;
  - nao preserva uma estrategia formal de merge entre campos persistentes do usuario e campos gerados;
  - ainda usa mapeamento simplificado em alguns tipos mais sofisticados.
- O preview funciona, mas a SQL ainda e simplificada:
  - ja usa colunas explicitas quando possivel;
  - ja usa o dialeto do Dext para quoting e paging;
  - ainda precisa evoluir para cenarios mais ricos como schemas, views e regras especificas por banco.
- O notifier da IDE ja existe, mas o fluxo ainda nao esta fechado:
  - `FileNotification` ainda esta praticamente vazio;
  - `TDextModuleNotifier` existe, mas nao ha registro completo por modulo aberto;
  - ainda nao ha escopo/refresco inteligente por arquivo afetado.
- O refresh de metadata ja produz efeito interno, mas ainda precisa de feedback mais claro e automacoes adicionais para o dev perceber imediatamente o resultado.

### 2.3. O que ainda nao fecha a experiencia ponta a ponta

- `DataProvider` ainda e do tipo `TComponent`, nao `TEntityDataProvider`.
  - Em runtime isso ajuda no baixo acoplamento via interface.
  - Em design time a UX melhorou com property editor filtrado, mas ainda pode evoluir para uma experiencia mais semantica.
- Falta estrategia de cache incremental e invalidacao precisa.
- Falta uma camada de adaptacao entre `TEntityClassMetadata` e o mapeamento completo do runtime (`TEntityMap` / RTTI real).
- O provider ainda depende de `ModelUnits` ou do scan do projeto ativo; no futuro podemos torná-lo ainda mais autonomo e contextual.
- O papel da `Connection: TFDConnection` esta correto para design time, mas ainda vamos evoluir a historia de credenciais/segredos.

## 3. Decisoes de Design

### 3.1. Manter o modelo Hub-and-Spoke

Decisao mantida:

- `TEntityDataProvider` continua sendo o hub de descoberta, cache, conexao e servicos de design time.
- `TEntityDataSet` continua sendo o spoke focado em bind visual, `TFields` e preview.

Motivo:

- reduz duplicacao de parsing;
- permite varios datasets compartilharem o mesmo cache;
- cria um ponto unico para OTAPI, logs de design time e estrategias futuras de refresh.

### 3.1.1. Separacao formal entre runtime e design time

Decisao implementada:

- `TEntityDataProvider` fica no package de componentes;
- parser de metadata e servicos de scan/populacao ficam no package design time;
- `Dext.EF.Design` fica responsavel apenas por:
  - `Register`
  - `ComponentEditor`
  - `PropertyEditor`
  - preview tooling
  - OTAPI/notifiers

Motivo:

- eliminar dependencias de `ToolsAPI` em exemplos e aplicacoes runtime;
- seguir o padrao correto de packages Delphi;
- permitir que o provider exista como componente reutilizavel fora do package da IDE.

### 3.2. Separar claramente "metadata de design" de "runtime mapping"

Decisao nova:

- o parser AST continua responsavel por descoberta leve e resiliente;
- o runtime mapping (`TEntityMap`, RTTI, atributos reais e conversoes profundas) continua sendo a fonte de verdade para comportamento do dataset em execucao;
- a ponte entre ambos deve ser formalizada em um resolver dedicado.

Motivo:

- o design time precisa sobreviver a codigo incompleto;
- o runtime precisa de fidelidade total e performance;
- misturar as duas responsabilidades diretamente no dataset tende a fragilizar a IDE.

### 3.3. Suporte a preview deve ter dois modos

Decisao nova:

- Modo 1: `External Preview`
  - abre SQL via `TFDQuery` numa janela auxiliar;
- Modo 2: `Dataset Preview`
  - carrega amostra de dados no proprio `TEntityDataSet` para permitir `Active := True` em design time.

Motivo:

- o modo externo e simples e continua util para diagnostico;
- o modo no proprio dataset e o que realmente destrava experiencia premium em grids, fields editor, colunas e relatorios.

### 3.4. Campos gerados precisam de politica explicita de sincronizacao

Decisao nova:

- adotar tres operacoes formais para campos persistentes:
  - `Generate Missing Fields`
  - `Sync Generated Fields`
  - `Regenerate All Generated Fields`

Motivo:

- evita destruir personalizacoes do desenvolvedor;
- permite automacao sem comportamento surpreendente;
- aproxima a UX do que componentes Delphi maduros costumam fazer.

### 3.5. A propriedade de conexao do provider deve ser orientada a runtime, mas visivel no design

Decisao atualizada:

- a propriedade `Connection: TFDConnection` continua no provider;
- a alias `FDConnection: TFDConnection` tambem fica exposta para ficar mais clara no Object Inspector;
- seu papel deve ser documentado como "fonte de preview/design assistido", nao como dependencia central do runtime do dataset.

Motivo:

- preserva a arquitetura do Dext;
- habilita design assistido sem transformar o dataset em clone de `TFDQuery`.

### 3.6. Evolucao futura de credenciais

Decisao registrada para o roadmap:

- a configuracao atual por `Connection: TFDConnection` em design time permanece;
- futuramente o provider deve evoluir para integrar com vault/secrets/variaveis de ambiente;
- essa evolucao deve preservar a ergonomia atual, nao substitui-la abruptamente.

Motivo:

- a necessidade imediata e produtividade no design time;
- a necessidade futura e seguranca e portabilidade entre ambientes.

## 4. Gaps Tecnicos Identificados

### Gap A. Resolucao de classe real a partir de `EntityClassName`

Status:

- parcialmente resolvido.

Ainda falta:

- fortalecer os casos de RTTI/linker mais complexos;
- reduzir dependencia de contexto do modulo atual para injecao de `uses`.

### Gap B. Preview no proprio dataset

Status:

- parcialmente resolvido.

Ja existe:

- geracao de SQL de preview;
- execucao via provider;
- materializacao de objetos;
- tentativa de carga do proprio `TEntityDataSet` em design time.

Ainda falta:

- tornar o ciclo mais previsivel para todos os componentes visuais;
- melhorar feedback de falhas e diagnostico.

### Gap C. Mapeamento de tipos de design time ainda simplificado

Impacto:

- risco de `TField` inadequado para enums, `Nullable`, smart types, blobs e tipos Dext.

Necessidade:

- centralizar conversao `MemberType/metadata -> TFieldType/TFieldClass`;
- alinhar com o mapeamento ja consolidado do runtime.

### Gap D. Integracao OTAPI incompleta

Impacto:

- refresh excessivo ou insuficiente;
- pouca automacao no fluxo real de trabalho.

Necessidade:

- registrar notifiers por modulo;
- reagir a `AfterSave` com escopo por arquivo;
- opcionalmente atualizar datasets dependentes de forma silenciosa.

### Gap E. Falta de operacoes de design time de alto nivel

Impacto:

- a base existe, mas a sensacao ainda e de ferramenta interna, nao de produto polido.

Necessidade:

- menus e comandos orientados a intencao:
  - scan project entities
  - refresh provider cache
  - sync generated fields
  - open sample data
  - inject required uses

Status:

- parcialmente resolvido.

Ja existe:

- scan do projeto ativo + refresh;
- refresh do provider;
- open preview data;
- injecao de `uses` ao selecionar entidade.

## 5. Backlog Priorizado

### Fase 1. Fechar o fluxo minimo premium

- [x] Criar resolver `EntityClassName -> TClass` para o design time.
- [x] Fazer o `TEntityDataSet` preencher `FEntityClass` automaticamente a partir do `DataProvider`.
- [x] Permitir `Active := True` em design time quando houver `DataProvider + EntityClassName`.
- [ ] Adicionar validacoes amigaveis quando faltar provider, connection, metadata ou unit no `uses`.

### Fase 2. Tornar o provider o centro real da experiencia

- [x] Evoluir `TEntityDataProvider` para expor servicos de:
  - lookup por classe;
  - lookup por unit;
  - invalidacao por arquivo;
  - geracao de SQL de preview;
  - carregamento de amostra.
- [x] Adicionar comando explicito para scan do projeto inteiro.
- [ ] Adicionar cache incremental por arquivo e timestamp.

### Fase 3. TFields com comportamento profissional

- [ ] Implementar `Sync Generated Fields`.
- [ ] Marcar campos gerados pelo Dext de forma identificavel e segura.
- [ ] Preservar customizacoes do desenvolvedor quando possivel.
- [ ] Suportar remocao/renomeacao de membros sem deixar lixo no DFM.

### Fase 4. Preview de dados no proprio dataset

- [x] Criar gerador de SQL por dialeto para preview.
- [ ] Limitar volume de dados de preview.
- [x] Abrir o proprio `TEntityDataSet` com amostra real.
- [ ] Garantir fechamento/limpeza sem side effects no form designer.

### Fase 5. OTAPI e automacoes de produtividade

- [ ] Registrar `IOTAModuleNotifier` corretamente nos modulos relevantes.
- [ ] Implementar refresh por arquivo salvo.
- [x] Implementar injecao automatica de `uses`.
- [ ] Opcional: mostrar mensagens nao invasivas de status no IDE.

### Fase 6. Acabamento de produto

- [x] Melhorar nomes e tipos das propriedades expostas no Object Inspector.
- [ ] Adicionar categories e hints mais ricos.
- [ ] Criar wizard/menu de onboarding do provider.
- [ ] Criar testes manuais guiados para `cxGrid`, `DBGrid`, Fields Editor e FastReport.

### Fase 7. Credenciais e ambientes

- [ ] Evoluir o provider para suportar vault de secrets e variaveis de ambiente.
- [ ] Permitir estrategias seguras para preview em design time sem hardcode de credenciais.
- [ ] Preservar compatibilidade com o fluxo atual baseado em `Connection: TFDConnection`.

## 6. Tarefas Imediatas Recomendadas

As proximas tarefas de maior retorno sao:

1. Fazer o refresh de metadata reagir automaticamente a save/alteracao de units do projeto com escopo mais preciso.
2. Evoluir `GenerateFields` para um sincronizador formal de campos persistentes.
3. Melhorar feedback visual/logico do provider durante scan, refresh e falhas de preview.
4. Refinar o ciclo de preview no proprio dataset para cenarios mais complexos.
5. Registrar e implementar a fase futura de vault/secrets sem perder a ergonomia atual.

## 7. Observacoes Importantes

- O preview atual em [`Dext.EF.Design.Preview.pas`](C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Preview.pas) e util, mas ainda nao representa o objetivo final. Ele deve ser tratado como etapa intermediaria.
- O uso da `ToolsAPI-helper` em `C:\dev\Dext\Libs\ToolsAPI-helper\` pode ser valioso como referencia para:
  - navegacao de modulos;
  - manipulacao de `uses`;
  - registro correto de notifiers;
  - interacao segura com o designer.
- O parser AST atual ja entrega bastante valor. O ganho principal agora nao esta em "parsear mais", e sim em fechar a jornada completa do desenvolvedor dentro da IDE.
- O projeto de referencia atual para validacao manual e:
  - [`Desktop.EntityDataSet.Demo.dproj`](C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\Desktop.EntityDataSet.Demo.dproj)
  - [`MainForm.pas`](C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\MainForm.pas)
- Esse exemplo e especialmente importante porque as entidades estao nas mesmas units dos forms, o que valida a necessidade de scan do projeto e descoberta automatica de units.

## 8. Definicao de Sucesso

Consideraremos esta frente bem sucedida quando o fluxo abaixo funcionar de forma natural:

1. O desenvolvedor solta um `TEntityDataProvider` no datamodule.
2. Informa a `Connection` e faz scan das entities do projeto.
3. Solta um `TEntityDataSet`.
4. Liga o dataset ao provider e escolhe a entidade por nome.
5. O Dext injeta `uses` quando necessario.
6. O desenvolvedor clica em `Sync Fields` ou simplesmente ativa o dataset.
7. Os `TFields` aparecem corretos.
8. O dataset abre com dados de preview.
9. `cxGrid`, relatorios e outros componentes conseguem ser desenhados imediatamente sobre o dataset.

Quando isso estiver fluindo sem friccao, teremos uma experiencia de design time realmente apaixonante.
