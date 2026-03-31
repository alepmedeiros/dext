# Plano Técnico: Suporte Nativo Mestre-Detalhe (MasterSource/MasterFields)

O objetivo é evoluir o `TEntityDataSet` para suportar o modelo clássico de mestre-detalhe do Delphi (estilo FireDAC/ClientDataSet), onde o dataset detalhe se vincula a um `MasterSource` e aplica filtros automáticos ou dispara cargas sob demanda.

## 1. Alterações no `TEntityDataSet` (Dext.Entity.DataSet.pas)

### 1.1 Estrutura e Propriedades
- Adicionar classe interna `TEntityMasterDataLink = class(TDataLink)` para monitorar o dataset mestre.
- Adicionar propriedades `MasterSource: TDataSource` e `MasterFields: string` (publicadas).
- Adicionar propriedade `IndexFieldNames: string` (já existente, mas agora vinculada ao link mestre).

### 1.2 Lógica de Sincronização (`SyncMasterDetail`)
- Quando o mestre mudar de posição (`RecordChanged` ou `ActiveChanged` com `Field = nil`):
  - Identificar os campos mestre (`MasterFields`) e campos detalhe (`IndexFieldNames`).
  - Obter os valores correntes do Master.
  - Aplicar um filtro interno no DataSet detalhe (ex: `DetailField = :Value`).
  - Se estiver operando em modo "Lazy Load", notificar o usuário via evento (ex: `OnMasterChange`).

### 1.3 Suporte ao `TDataEvent`
- Garantir que o `deDataSetChange` e `deDataSetScroll` no mestre disparem a carga/filtro no detalhe.

---

## 2. Testes Unitários (Dext.Entity.DataSet.Tests.pas)

### 2.1 Novo Caso de Teste: `Test_Real_MasterDetail_Link`
- Criar Master e Detail independentes.
- Vincular via `MasterSource`.
- Validar se ao dar `.Next` no Master, o `RecordCount` do Detail muda automaticamente via filtragem.

---

## 3. Exemplo de Desktop (Examples/Desktop.EntityDataSet.Demo)

### 3.1 Novo Form: `fRealMasterDetail.pas`
- Layout inspirado no exemplo do DocWiki do FireDAC.
- Grade Mestre (Pedidos) e Grade Detalhe (Itens).
- Demonstração de configuração via código (Runtime) e via Object Inspector (Design-time simulado).

---

## 4. Checklist de Execução

- [x] Criar classe de Link Privada em `Dext.Entity.DataSet.pas`.
- [x] Implementar propriedades `MasterSource` e `MasterFields`.
- [x] Implementar método `SyncMasterDetail` com filtragem automática.
- [x] Validar suporte a caches e filtros (Faze 4.3 do plano original).
- [x] Adicionar testes unitários de regressão para este cenário.
- [x] Implementar o novo form no exemplo Desktop.
