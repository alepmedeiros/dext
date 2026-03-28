# Plano de Implementação: Correção e Aprimoramento do TEntityDataSet

Este plano visa corrigir as falhas introduzidas na tentativa de adicionar suporte a campos calculados e "Shadow Properties" no `TEntityDataSet`, além de estabilizar o processo de `Post` e `Insert`.

## Objetivos

1. **Correção do Locate**: Permitir busca em campos `fkCalculated` e `fkLookup`.
2. **Suporte a Shadow Properties**: Integrar a leitura de campos que existem apenas no mapeamento do `TDbContext`.
3. **Estabilidade de Post/Insert**: Garantir que o `FVirtualIndex` e o `FCurrentRec` sejam atualizados corretamente após inserções, especialmente com filtros e ordenação ativos.

## Mudanças Propostas

### 1. TPropertyMap & TEntityMap (Dext.Entity.Mapping.pas)
- Adicionar flag `IsShadowProperty` para identificar campos que não possuem correspondência física na classe Delphi.

### 2. TEntityDataSet.Locate (Dext.Entity.DataSet.pas)
- **Fast-Path**: Manter para campos físicos mapeados com offset.
- **Fallback**: Se o campo não for encontrado no `FEntityMap` (ou for calculado), usar `GetFieldData` para obter o valor formatado do buffer e comparar. Isso torna o `Locate` compatível com qualquer tipo de campo do `TDataSet`.

### 3. TEntityDataSet.ReadFieldValue (Dext.Entity.DataSet.pas)
- Se a propriedade for uma "Shadow Property", delegar a leitura para o `FDbContext` associado (ou retornar null se não houver contexto).

### 4. Gestão de fkInternalCalc
- Refinar o `FInternalCalcStorage` para que seja um array de buffers indexado pelo índice físico do objeto em `FItems`.
- Sincronizar apenas em `InternalPost` e `InternalAddRecord`.

### 5. Reposicionamento de Cursor
- Após `ApplyFilterAndSort` no `InternalPost`, recalcular `FCurrentRec` usando `FVirtualIndex.IndexOf(ActualPhysicalIdx)`.
- Se o registro novo for filtrado, decidir se o cursor fica no "buraco" (comportamento padrão) ou se move para o registro mais próximo.

## Plano de Verificação

### Testes de Unidade (Novos Casos)
- [ ] `Test_Locate_CalculatedField`: Testa `Locate` em um campo `OnCalcFields`.
- [ ] `Test_ShadowProperty_Read`: Testa leitura de campo via ORM Mapping sem propriedade na classe.
- [ ] `Test_Post_With_Filter_Active`: Garante que o cursor não se perde ao postar um registro que satisfaz o filtro.

### Testes de Regressão
- Rodar a suite completa em `Tests\Entity\DataSet\Dext.Entity.DataSet.Tests.pas`.
