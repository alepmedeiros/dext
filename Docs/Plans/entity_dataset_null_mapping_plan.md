# Plano de Refatoração: TEntityDataSet e Tipos Inteligentes

Este documento descreve as diretrizes arquiteturais para a refatoração do `TEntityDataSet` do Dext, visando corrigir as anomalias no mapeamento de nulos em `Prop<T>` e garantir suporte completo aos Tipos Inteligentes nativos de forma limpa.

## 1. Tratamento de Nulidade com Smart Types
O ecossistema do Dext adota uma separação rigorosa de responsabilidades para os genéricos:
* `Prop<T>`: Essencialmente primitivo para o banco e **não suporta estado Nulo**. Fisicamente não possui o espaço estrutural (`FHasValue`) para discernir entre o default da linguagem (como `0`) e a ausência de valor (`Null`).
* Para suportar Nulidade, o mapeamento **deve** usar obrigatoriamente `Nullable<Prop<T>>` ou composições como `Lazy<Nullable<Prop<T>>>`.

### Arquitetura de Offsets no `TEntityMap`
Durante a varredura (`GetFields`/`GetProperties`) estrutural, o `TReflection` encontra de modo encadeado o `FHasValue` no nível do `Nullable` e o `FValue` aninhado no `Prop<T>`.

**Ação:**
O `TEntityDataSet` não deve tentar criar coerção mágica quando uma UI / código cliente assinalar `.Clear` ou `Null` em um `TField`.
Quando ocorrer um `SetFieldData` com `Buffer = nil` em um campo que o ORM detectou não possuir flag `FHasValue` (isto é, `FieldOffset <= 0`), esse campo deve ser reportado ao `TDataSet` como **Required = True**. Assim, o DataSet e a interface barrarão essa atribuição de forma consistente, impedindo que o null passe silenciosamente.

## 2. Ajuste na Inicialização dos Defaults
Vamos modificar `Dext.Entity.DataSet.pas` no método `InternalInitFieldDefs` para que o dataset herde a obrigatoriedade inerente do tipo refletido:

```delphi
      if PropMap.IsAutoInc or PropMap.IsCreatedAt or PropMap.IsUpdatedAt or PropMap.IsVersion then
        FieldDef.Required := False
      else if PropMap.FieldOffset <= 0 then
        FieldDef.Required := True // Obriga a ser Required por não possuir mecanismo interno de Null
      else
        FieldDef.Required := PropMap.IsRequired;
```

## 3. Falha de Memória Adversa (Testes Unitários)
Durante a validação, encontramos um problema de "double free" / "invalid pointer" reportado pelo FastMM5 nos arquivos de teste do `TEntityDataSet`.

### Análise do Problema
1. O `TEntityDataSet` por padrão, implementa `FOwnsItems` = `True`.
2. O método `.Load(TArray<T>)` possui o argumento padrão `AOwnsObjects: Boolean = True` que é repassado para manter o Ownership.
3. Várias Fixtures de Teste, nos métodos de SetUp/Testes chamavam `.Load(FProducts, TProductTest)` etc. sem especificar o ownership explicitamente.
4. Nos métodos de TearDown, as classes de teste iteravam os elementos da array original (ex. `FProducts`) chamando o método `.Free`.
5. Com a propriedade padrão ativada, os objetos passavam por liberação de memória em dobro (uma no Free do TEntityDataSet e outra no TearDown explícito da fixture), gerando a falha de memória reportada.

### Ação:
Atualizar as chamadas de `.Load(...)` para `.Load(..., False)` nos testes pertinentes do diretório `Tests\Entity\` para garantir que a matriz repasse a lista baseada em *borrowed references* em cenários em que as Fixtures gerenciam o tempo de vida (*lifecycle*) via `TearDown`.

## Verificação Subsequente
* A tipagem `Prop<T>` será considerada `Required` estritamente pelo `TEntityDataSet` e não permitirá anulação silenciosa.
* O encadeamento `Lazy<Nullable<Prop<T>>>` gerará corretamente um `FieldOffset > 0`, propagando seu status `IsRequired = False` e aceitando a manipulação de `Null` perfeitamente em `SetFieldData` e `GetFieldData`.
* O Log do FastMM5 não deverá acusar vazamentos de memória (Memory Leaks) ou Double Frees nas suítes de teste de datasets.
