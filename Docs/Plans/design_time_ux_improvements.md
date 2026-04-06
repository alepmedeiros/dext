# Design-Time UX: Problemas Identificados e Melhorias Propostas

Última atualização: 2026-04-06 (Sessão de Estabilização de Metadados e Fields)

## Sumário Executivo

Este documento cataloga todos os problemas de usabilidade identificados na experiência de design-time do `TEntityDataSet` + `TEntityDataProvider` e propõe soluções priorizadas. O objetivo é transformar a experiência atual — funcional porém com fricção — em uma experiência premium, digna de um framework profissional.

---

## 1. Problemas Identificados

### 1.1. Units escaneadas fora do escopo do projeto

**Sintoma:** O provider carrega 22 units com classes quando o projeto ativo tem apenas 2 units com 4 entidades. As units extras vêm de outros projetos no grupo.

**Causa raiz:** `PopulateProviderModelUnitsFromActiveProject` usa `IOTAProjectGroup.ActiveProject`, que pode não ser o projeto ao qual o form/datamodule pertence. Em um grupo com múltiplos projetos, o "projeto ativo" é controlado pela seleção no Project Manager, não pelo form que está aberto no designer.

**Impacto:**
- Lista de entidades poluída com classes irrelevantes
- Confusão do desenvolvedor ao selecionar `EntityClassName`
- Possíveis conflitos de nomes entre entidades de projetos diferentes
- Metadata desnecessário sendo parseado e cacheado

**Solução proposta:**
1. Detectar a qual projeto o form/unit atual pertence usando `IOTAModule.OwnerModuleCount` e `OwnerModules`
2. Fallback: percorrer todos os projetos do grupo e verificar se o `FileName` do módulo atual está em `GetModuleCount/GetModule`
3. Se não encontrar correspondência exata, usar o projeto ativo como fallback
4. Exibir no `LastRefreshSummary` de qual projeto as units foram escaneadas

### 1.2. Display Name nos editores de Collection

**Sintoma:** No editor de propriedades das coleções `EntitiesMetadata` e `Members`, cada item aparece como o nome da classe Delphi (ex: `TEntityClassMetadata`) em vez de um nome descritivo.

**Causa raiz:** As classes `TEntityClassMetadata` e `TEntityMemberMetadata` não implementam `GetDisplayName`.

**Impacto:**
- O editor de Collection fica ilegível com vários itens mostrando `"TEntityClassMetadata"` repetidamente
- Impossível identificar qual item é qual sem clicar em cada um

**Solução proposta:**
```pascal
// TEntityClassMetadata
function GetDisplayName: string; override;
begin
  if FEntityClassName <> '' then
    Result := FEntityClassName + ' (' + FTableName + ')'
  else
    Result := inherited GetDisplayName;
end;

// TEntityMemberMetadata
function GetDisplayName: string; override;
begin
  if FName <> '' then
    Result := FName + ': ' + FMemberType
  else
    Result := inherited GetDisplayName;
end;
```

### 1.3. Editor de Collections é limitado

**Sintoma:** O editor padrão de `TCollection` do Delphi é genérico e pobre para visualizar metadata complexo como entidades e seus membros.

**Impacto:**
- Difícil navegar com muitas entidades
- Não há busca/filtro
- Não mostra hierarquia (entidade → membros)
- Não permite ações contextuais (refresh individual, preview)

**Solução proposta (fases):**
1. **Curto prazo:** Implementar `GetDisplayName` (item 1.2) — ganho imediato
2. **Médio prazo:** Criar um `TComponentEditor` customizado para `EntitiesMetadata` que abre um formulário próprio com:
   - TreeView ou ListView com entidades no nível superior
   - Grid de membros quando uma entidade é selecionada
   - Botão "Refresh" por entidade
   - Botão "Preview SQL" por entidade
   - Indicador de status (unit encontrada / classe resolvida / erro)
3. **Longo prazo:** Editor visual com drag-and-drop para reordenar membros e configurar campos

### 1.4. Workflow de refresh é verboso demais

**Sintoma:** Para atualizar os campos após editar uma entidade, o desenvolvedor precisa:
1. Salvar o arquivo `.pas` da entidade
2. Ir até o `TEntityDataProvider` no form/datamodule
3. Clicar "Scan Active Project + Refresh Metadata"
4. Voltar ao `TEntityDataSet`
5. Fechar o dataset (Active = False)
6. Limpar os TFields existentes (Fields Editor → Delete All)
7. Clicar "Generate Fields (Auto)"
8. Reativar o dataset (Active = True)

**Impacto:** São 8 passos para uma operação que deveria ser 1 clique.

**Solução proposta:**

#### 1.4.1. Verbo "Refresh Entity" no TEntityDataSet

Novo verbo de contexto no selection editor: **"Dext: Refresh Entity (Scan + Rebuild Fields)"**

Comportamento:
1. Localiza o `DataProvider` vinculado
2. Identifica a unit da entidade atual via metadata
3. Faz refresh **apenas da unit** relevante (não do projeto inteiro)
4. Regenera os TFields
5. Se havia campos customizados pelo dev, exibe diálogo perguntando:
   - "Foram encontrados X campos personalizados. Deseja excluí-los e recriar todos? [Sim] [Não - manter e adicionar novos] [Cancelar]"
6. Reativa o preview se estava ativo antes

#### 1.4.2. Hotkey / Ação de IDE

Registrar uma ação de IDE (via `IOTAKeyboardBinding` ou `IOTAActionServices`) para ctrl+shift+R → Refresh Entity Dataset no dataset selecionado.

### 1.5. Notificação automática incompleta (OTAPI)

**Sintoma:** O `TDextIDENotifier.FileNotification` está praticamente vazio. O `TDextModuleNotifier.AfterSave` faz refresh de todos os providers em todos os forms, sem escopo.

**Impacto:**
- Refresh não dispara automaticamente ao salvar units de entidade
- Quando dispara, faz broadcast para todos os providers (potencialmente lento)
- Não há feedback visual ao desenvolvedor de que algo foi atualizado

**Solução proposta:**
1. No `FileNotification(ofnFileSaved)`, verificar se o arquivo salvo está no `ModelUnits` de algum provider aberto
2. Se sim, fazer `RefreshUnit` apenas daquele arquivo naquele provider
3. Opcionalmente, propagar para os datasets vinculados que usam entidades daquela unit
4. Exibir notificação não-invasiva na Status Bar da IDE: `"Dext: Refreshed TCustomer from Customer.pas"`

### 1.6. Cache de metadados — Clear manual necessário

**Sintoma:** O cache de metadata pode ficar stale quando units são editadas fora do projeto ativo ou quando o grupo de projetos muda. Não há forma fácil de limpar o cache.

**Solução proposta:**

#### 1.6.1. Verbo "Clear Cached Metadata" no TEntityDataProvider

Novo verbo no component editor: **"Dext: Clear All Cached Metadata"**

Comportamento:
1. Limpa `FMetadataCache`
2. Limpa `FEntitiesMetadata` collection
3. Notifica datasets vinculados para fecharem se estiverem em preview
4. Atualiza `LastRefreshSummary` para `"Cache cleared. Use 'Scan Project' to reload."`

#### 1.6.2. Verbo "Clear + Rescan" combinado

**"Dext: Clear Cache + Rescan Active Project"** — limpa tudo e refaz o scan do zero.

---

## 2. Análise de Workflows do Desenvolvedor

Abaixo estão todos os cenários de uso previstos e a fricção identificada em cada um.

### 2.1. Primeiro uso — Setup inicial

```
Cenário: Dev solta TEntityDataProvider e TEntityDataSet pela primeira vez.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Soltar TEntityDataProvider | ✅ Sem fricção |
| 2 | Configurar DatabaseConnection | ✅ Sem fricção (dropdown funciona) |
| 3 | Clicar "Scan Active Project" | ⚠️ Pode escanear projeto errado (item 1.1) |
| 4 | Soltar TEntityDataSet | ✅ Sem fricção |
| 5 | Configurar DataProvider | ✅ Sem fricção (dropdown filtrado) |
| 6 | Selecionar EntityClassName | ⚠️ Lista pode ter classes de outros projetos |
| 7 | Gerar campos | ✅ Automático via SetValue do property editor |
| 8 | Ativar preview | ✅ Automático se conexão disponível |

**Melhoria:** No passo 3, detectar o projeto correto. No passo 6, agrupar entidades por projeto/unit.

### 2.2. Edição de entidade — Adicionar propriedade/atributo

```
Cenário: Dev que já tem o dataset funcionando edita a classe da entidade.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Editar .pas da entidade (adicionar propriedade) | ✅ |
| 2 | Salvar o .pas | ✅ |
| 3 | Voltar ao form designer | ✅ |
| 4 | Ir até o DataProvider | ❌ **Boilerplate** |
| 5 | Clicar Refresh Metadata | ❌ **Boilerplate** |
| 6 | Voltar ao DataSet | ❌ **Boilerplate** |
| 7 | Fechar dataset | ❌ **Boilerplate** |
| 8 | Limpar fields | ❌ **Boilerplate** |
| 9 | Gerar fields | ❌ **Boilerplate** |
| 10 | Ativar preview | ❌ **Boilerplate** |

**Melhoria:** Tudo deveria ser 1 clique no dataset: "Dext: Refresh Entity" (item 1.4.1). Ou automático via OTAPI.

### 2.3. Trocar de entidade no mesmo dataset

```
Cenário: Dev muda o EntityClassName no Object Inspector.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Clicar no dropdown de EntityClassName | ✅ |
| 2 | Selecionar nova entidade | ✅ |
| 3 | Fields antigos são limpos | ✅ (implementado) |
| 4 | Novos fields são gerados | ✅ (implementado) |
| 5 | Preview ativa automaticamente | ✅ (implementado) |

**Status:** ✅ **CONCLUÍDO** — O `GenerateFields` agora limpa todos os campos persistentes antes de recriar, garantindo 100% de integridade ao trocar de classe.

### 2.4. Personalizar campos após geração

```
Cenário: Dev gera campos automaticamente e depois personaliza (DisplayLabel, DisplayWidth manual).
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Gerar campos | ✅ |
| 2 | Personalizar DisplayLabel de um campo | ✅ |
| 3 | Mais tarde, entidade é alterada | ✅ |
| 4 | Rodar "Refresh Entity" | ⚠️ **Campos personalizados serão perdidos?** |

**Melhoria necessária:**
- Detectar se há campos com valores diferentes do default do metadata
- Perguntar ao dev antes de substituir
- Opção de merge inteligente: só recriar campos que não foram personalizados

### 2.5. Abrir form de outro projeto no grupo

```
Cenário: Dev tem um grupo com ProjectA e ProjectB. Está com ProjectB ativo, mas abre um form do ProjectA.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Duplo-clique no .pas do ProjectA | ✅ |
| 2 | Form abre no designer | ✅ |
| 3 | DataProvider do form já tem metadata do ProjectA salvo no DFM | ✅ |
| 4 | Dev clica "Refresh Metadata" no provider | ❌ **Escanea ProjectB!** |
| 5 | Entidades do ProjectA desaparecem, aparecem as do ProjectB | ❌ **Bug** |

**Melhoria:**
- Detectar o projeto dono do form (item 1.1)
- Se não for o ativo, notificar: `"⚠️ Este form pertence ao projeto X, mas o projeto ativo é Y. Deseja escanear X?"`
- Opção: percorrer todos os projetos do grupo para buscar a unit

### 2.6. Renomear propriedade na entidade

```
Cenário: Dev renomeia "CustomerName" para "FullName" na entidade.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Editar .pas, renomear propriedade | ✅ |
| 2 | Salvar | ✅ |
| 3 | Refresh metadata | ✅ |
| 4 | Regenerar fields | ⚠️ Campo antigo "CustomerName" fica órfão no DFM |
| 5 | Campo novo "FullName" é criado | ✅ |

**Melhoria:** O sync deveria detectar que "CustomerName" não existe mais no metadata e oferecer remoção.

### 2.7. Remover propriedade da entidade

```
Cenário: Dev remove uma propriedade da entidade.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Remover propriedade do .pas | ✅ |
| 2 | Refresh + Regenerate | ⚠️ Campo persiste como TField órfão |
| 3 | Dev precisa deletar manualmente no Fields Editor | ❌ |

**Melhoria:** Detectar campos que não têm correspondência no metadata e oferecer remoção.

### 2.8. Adicionar atributos visuais a uma propriedade existente

```
Cenário: Dev adiciona [Caption('Nome do Cliente')] ou [DisplayWidth(30)] a uma propriedade que já tem TField gerado.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Adicionar atributo no .pas | ✅ |
| 2 | Salvar | ✅ |
| 3 | Refresh metadata | ✅ Metadata atualiza |
| 4 | Regenerar fields | ⚠️ O campo já existe, precisa ser atualizado, não recriado |
| 5 | Reativar preview | ⚠️ Os atributos são aplicados pelo ApplyMapMetadataToFields? |

**Status:** Parcialmente resolvido — `ApplyMapMetadataToFields` aplica na abertura. Mas se o campo persistente já tem valores hardcoded, não será sobrescrito.

**Melhoria:** O `GenerateFields` deveria reaplicar atributos do metadata nos campos existentes (já faz parcialmente, mas precisa cobrir todos os cenários de merge).

### 2.9. Múltiplos datasets ligados ao mesmo provider

```
Cenário: Um DataModule tem 1 provider e 5 datasets para diferentes entidades.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Alterar uma entidade usada por 1 dataset | ✅ |
| 2 | Refresh no provider | ✅ |
| 3 | Provider atualiza metadata global | ✅ |
| 4 | Quais datasets são afetados? | ⚠️ Todos são regenerados (desnecessário) |

**Melhoria:** O `RefreshBoundDataSets` deveria verificar se o metadata da entidade do dataset realmente mudou antes de regenerar.

### 2.10. Designer de relatório / Grid customizado

```
Cenário: Dev está usando cxGrid com colunas customizadas sobre o dataset.
```

| Passo | Ação | Fricção |
|-------|------|---------|
| 1 | Dataset com campos gerados | ✅ |
| 2 | cxGrid com colunas customizadas (cores, formatos) | ✅ |
| 3 | Refresh entity regenera campos | ⚠️ **cxGrid columns podem perder binding** |

**Melhoria:** Ao regenerar campos, manter o `FieldName` estável. Nunca mudar o `Name` do `TField` se o `FieldName` não mudou. Isso preserva bindings de grids e relatórios.

---

## 3. Novos Verbos e Menus Propostos

### 3.1. TEntityDataSet — Selection Editor

| # | Verbo | Comportamento |
|---|-------|---------------|
| 0 | `Dext: Generate Fields (Auto)` | ✅ Já existe |
| 1 | `Dext: Preview Data...` | ✅ Já existe |
| 2 | `Dext: Toggle Design-Time Preview` | ✅ Já existe |
| 3 | **`Dext: Refresh Entity (Scan + Rebuild Fields)`** | 🆕 Refresh inteligente de 1 clique |
| 4 | **`Dext: Sync Fields (Keep Customizations)`** | 🆕 Merge: adiciona novos, atualiza metadata, remove órfãos |

### 3.2. TEntityDataProvider — Component Editor

| # | Verbo | Comportamento |
|---|-------|---------------|
| 0 | `Scan Active Project + Refresh Metadata` | ✅ Já existe |
| 1 | `Refresh Entity Metadata` | ✅ Já existe |
| 2 | **`Dext: Clear All Cached Metadata`** | 🆕 Limpa cache e collections |
| 3 | **`Dext: Clear + Rescan Active Project`** | 🆕 Hard reset + scan |
| 4 | **`Dext: Browse Entities...`** | 🆕 Abre editor visual customizado |

---

## 4. Melhorias no Core (não-visuais)

### 4.1. GetDisplayName para TEntityClassMetadata [CONCLUÍDO]

**Arquivo:** `Dext.Entity.Core.pas`
**Esforço:** Baixo
**Impacto:** Alto (legibilidade imediata no editor de collections)

### 4.2. GetDisplayName para TEntityMemberMetadata [CONCLUÍDO]

**Arquivo:** `Dext.Entity.Core.pas`
**Esforço:** Baixo
**Impacto:** Alto

### 4.3. Detecção do projeto dono do form

**Arquivo:** `Dext.EF.Design.Editors.pas`
**Esforço:** Médio
**Impacto:** Crítico para grupos com múltiplos projetos

```pascal
function FindOwnerProject(AModule: IOTAModule): IOTAProject;
// Percorre todos os projetos no grupo
// Verifica se o FileName do módulo está nas units do projeto
// Retorna o projeto dono ou nil
```

### 4.4. Refresh de unit individual

**Arquivo:** `Dext.Entity.DataProvider.pas` e `Dext.EF.Design.Metadata.pas`
**Esforço:** Médio
**Impacto:** Alto (performance + precisão)

O `RefreshUnit` hoje é um stub. Precisa:
1. Parsear apenas a unit indicada
2. Atualizar/adicionar metadata das classes encontradas
3. Remover metadata de classes que não existem mais naquela unit
4. Retornar lista de classes afetadas

### 4.5. GenerateFields Smart Sync (Modo Regenerate) [CONCLUÍDO]

**Arquivo:** `Dext.Entity.DataSet.pas`
**Esforço:** Alto
**Impacto:** Alto

Três modos de operação:
- **Generate:** Cria campos faltantes (atual)
- **Sync:** Adiciona novos + atualiza metadata existentes + marca órfãos
- **Regenerate:** Limpa tudo e recria

---

## 5. Priorização

### 🔴 Urgente (Próxima sessão)

1. **GetDisplayName** para `TEntityClassMetadata` e `TEntityMemberMetadata` — ✅ **CONCLUÍDO**
2. **Hard Reset de TFields** no `GenerateFields` — ✅ **CONCLUÍDO** (Elimina stale metadata)
3. **Mapeamento ftCurrency e Precisão 0.00** — ✅ **CONCLUÍDO**
4. **Verbo "Refresh Entity"** no dataset — ⏳ Pendente de menu contextual
5. **Verbo "Clear Cached Metadata"** no provider — ⏳ Pendente

### 🟡 Importante (Próximas 2-3 sessões)

4. **Detecção do projeto dono** — resolve bug crítico em grupos multi-projeto
5. **RefreshUnit funcional** — refresh incremental em vez de full scan
6. **Diálogo de confirmação** no refresh quando há campos customizados
7. **Detecção de campos órfãos** após regeneração

### 🟢 Desejável (Backlog)

8. Editor visual customizado para `EntitiesMetadata`
9. Notificação automática completa via OTAPI (AfterSave com escopo)
10. Status bar messages não-invasivas
11. Hotkey para refresh
12. Agrupamento de entidades por unit/projeto no dropdown de `EntityClassName`
13. Smart sync formal (Generate / Sync / Regenerate como três ações distintas)

---

## 6. Definição de Sucesso

O fluxo ideal após todas as melhorias:

1. Dev edita a classe da entidade e salva
2. A IDE detecta automaticamente a mudança e atualiza o metadata (OTAPI)
3. Se o dataset estiver aberto no designer, os campos são atualizados silenciosamente
4. Se houver conflito (campos customizados), um toast discreto pergunta ao dev
5. O preview recarrega automaticamente
6. Em nenhum momento o dev precisa navegar para outro componente para fazer refresh

**Até lá, o fluxo intermediário aceitável é:**

1. Dev edita e salva a entidade
2. Volta ao form, clica uma vez no dataset
3. Clica "Dext: Refresh Entity" no menu contextual
4. Tudo é atualizado em 1 clique
