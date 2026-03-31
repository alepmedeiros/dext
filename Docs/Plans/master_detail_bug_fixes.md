# Bug Report & Fix Plan: Master-Detail Stability

Este documento organiza as falhas críticas identificadas no uso real do Master-Detail e Nested Datasets no `TEntityDataSet`.

## 1. Problemas Identificados

### 1.1 Access Violation em `InternalPost` (Linha 1375)
- **Sintoma:** AV ao tentar postar um novo registro no Detail logo após inserir um Master.
- **Causa Provável:** `FItems` está `nil`. No modo Nested Dataset (IList), se o dataset é criado vazio ou o link com o campo mestre não instanciou a lista, a referência se perde.
- **Local:** `TEntityDataSet.InternalPost` (Linha 1375).

### 1.2 Registros Detail não persistem
- **Sintoma:** Adiciona-se um detalhe, mas ao mudar de mestre e voltar, o registro sumiu.
- **Causa Provável:** O `InternalPost` está inserindo no buffer local (`FVirtualIndex`), mas não está dando o `Add` na lista concreta (`IList<T>`) da entidade mestre, ou não está notificando o mestre da alteração.

### 1.3 Falha na Inserção de Master (DateTime Conversion)
- **Sintoma:** Erro de timestamp/conversão ao tentar inserir um mestre com campos de data.
- **Causa Provável:** O erro de `'0.46112' is not a valid timestamp` está ocorrendo agora na **escrita** (`SetFieldData`). A Grid passa um valor que o `TField` tenta validar antes de mandar para o dataset.

### 1.4 Access Violations em Cascata
- **Sintoma:** Após um erro de conversão, ocorrem vários AVs.
- **Causa Provável:** Estado inconsistente do `RecordBuffer` ou erro no `InternalCancel` / `InternalPost` que deixa ponteiros órfãos.

---

## 2. Checklist de Correção (Ação Imediata)

### Fase 1: Estabilização de Memória & Estrutura
- [x] **Fix AV 1375:** Garantir que `FItems` seja inicializado ou verificado antes de qualquer operação em `InternalPost`.
- [X] **Nested Persist/Auto-Init:** Implementada auto-inicialização de `IList` em novas entidades e `SyncDetailData` garantindo lista válida.

### Fase 2: Input de Dados (SetFieldData) & Linkage
- [x] **DateTime Input:** Implementada conversão reversa de milissegundos para `TDateTime` no `SetFieldData`.
- [x] **Master Linkage:** Registros detalhe agora herdam automaticamente os valores de `MasterFields` no momento da inserção (InternalInsert).

### Fase 3: Validação via Exemplo Desktop
- [x] Validar Inserção de Pedido (Master).
- [x] Validar Inserção de Item (Detail) com persistência real.
- [x] Validar Edição de Datas sem erros de timestamp.

---
*Documento gerado em: 31/03/2026.*
