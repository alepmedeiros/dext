# Diagnóstico Técnico e Plano de Resgate: TEntityDataSet

Este documento apresenta uma análise profunda das falhas atuais do `TEntityDataSet` no Delphi 13.1, focando na recuperação da estabilidade das SmartTypes, tipos numéricos e relações Mestre-Detalhe.

## 1. Diagnóstico de Falhas (Root Cause Analysis)

### 1.1. Lazy<T> e SmartProps (Test_Read_Lazy_Value)
*   **Problema:** O DataSet retorna valor Nulo ou lixo de memória (`ù`) ao tentar ler uma propriedade `Lazy<T>`.
*   **Causa Raiz:** O mapeamento (`TEntityMap`) estava capturando o offset do campo privado `FLoaded` (booleano) como se fosse o `FieldOffset` principal. O DataSet via `False` (não carregado) e retornava `Null` imediatamente, sem nunca disparar o *getter* da propriedade que realizaria o carregamento.
*   **Status da Solução:** O mapeamento foi ajustado para reconhecer `IsLazy` e desativar offsets automáticos, forçando o DataSet a usar RTTI (Path 4) para invocar o getter da propriedade.

### 1.2. Currency e Precision (Test_Currency_Value)
*   **Problema:** Valores Currency (ex: 29.9) são lidos como 0.
*   **Causa Raiz:** O `GetFieldData` e `ReadFieldValue` realizam conversões entre `Variant` e `Double` que podem perder a escala ou falhar no *cast* direto de ponteiros para tipos de ponto flutuante de 64-bit se o mapeamento de tipos do DataSet (`ftCurrency`) não estiver perfeitamente alinhado com o buffer.

### 1.3. DateTime e Formatação (Test_DateTime_Value)
*   **Problema:** Erro `'0.46037' is not a valid timestamp`.
*   **Causa Raiz:** O DataSet está tentando converter o valor numérico puro do `TDateTime` (que é um Double) via string ou usando uma lógica de conversão de Variant inadequada para o buffer do `TField`.

### 1.4. Master-Detail (Test_Detail_FieldValues)
*   **Problema:** Campos de detalhe retornam 0 em vez do valor esperado.
*   **Causa Raiz:** Provável falha na sincronização do `ActiveBuffer` ou na resolução do `CurrentObj` quando o DataSet está operando em contexto de filtragem por mestre.

## 2. Diretrizes Arquiteturais para a Correção

Para alinhar com o Delphi 13.1 e as práticas do Spring4D:

1.  **RTTI Priority para SmartTypes:** Propriedades que requerem execução de lógica (Lazy, Calculated, Proxy) **devem** ignorar o Fast Path de offsets e usar RTTI.
2.  **Unwrapping de TValue:** Utilizar consistentemente `TReflection.TryUnwrapProp` para extrair o valor real de `Prop<T>`, `Nullable<T>` e `Lazy<T>`.
3.  **Assinaturas XE4+:** Manter rigorosamente o uso de `TValueBuffer` (TArray<Byte>) e garantir que o manuseio de `Buffer` e `Bookmark` considere os novos tipos de buffer do `TDataSet`.
4.  **Ownership de Objetos:** Corrigir os testes para que a Fixture não tente dar `.Free` em objetos que o DataSet já marcou como `@OwnsItems`.

## 3. Plano de Implementação (Proposta)

### Fase A: Estabilização de Tipos (Core)
1.  [x] **Mapping:** Ajustar `Dext.Entity.Mapping.pas` para não mapear offsets em campos `Lazy`. (Já aplicado como pré-estudo)
2.  [x] **DataSet.Read:** Refinar `ReadFieldValue` para priorizar RTTI em tipos `IsLazy`. (Já aplicado como pré-estudo)
3.  [ ] **DataSet.Types:** Revisar o `case PropMap.DataType` no `ReadFieldValue` para garantir que `ftCurrency`, `ftDateTime` e `ftFloat` usem a precisão correta de 8 bytes e evitem conversões via String.

### Fase B: Shadow & Calculated Properties
1.  [ ] **Calculated Fields:** Revisar o fluxo de `CalcFields` para garantir que o buffer de cálculo (`CalcBuffer`) seja inicializado corretamente antes dos eventos `OnCalcFields`.
2.  [ ] **Shadow Properties:** Validar se o `FDbContext` está sendo passado corretamente para o DataSet para permitir a busca de valores não persistidos no objeto.

### Fase C: Master-Detail
1.  [ ] **Detail Resolution:** Depurar o método de `GetRecord` em contexto de detalhe para garantir que o ponteiro do objeto corresponda ao registro filtrado pelo mestre.

### Fase D: Validação TDD
1.  [ ] Rodar `Dext.Entity.UnitTests.dproj`.
2.  [ ] Rodar `Dext.EntityDataSet.Tests.dproj`.
3.  [ ] Corrigir Fixtures de teste para evitar "Double Free" (Ajustar `.Load(..., False)`).

## 4. Próximos Passos Sugeridos
*   Revisar este documento de diagnóstico.
*   Autorizar a aplicação formal das correções da Fase A (Types) e Fase B.
*   Executar a suíte de testes unitários para validação de regressão.

---
*Preparado por Antigravity - 25/03/2026*
