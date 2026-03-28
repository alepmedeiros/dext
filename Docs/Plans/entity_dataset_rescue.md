Estamos trabalhando na implementação de um DataSet para o Dext, TEntityDataset, o projeto e o status está neste arquivo:

C:\dev\Dext\DextRepository\Docs\Plans\entity_dataset_integration.md

O problema atual, é que a partir da implementação do Shadow Properties, Calculated Fields e mais algumas features listadas a seguir, quebrou muitas funcionalidades do dataset, e mesmo após trabalhar 3 dias tentando corrigir os problemas, não foi possível, alterava o código sem um fundamento, quebrava compilação, passava horas para corrigir o que quebrou, nada era corrigido, os mesmos testes quebrados nunca eram corrigidos.

diff com versão anterior que foi mergeada com a master

### 🛠️ Fase 4: Tipos de Dados Avançados & Validação TDD

*Objetivo: Garantir a completude da engine de dados e cobertura de tipos complexos.*

- [x] **Shadow Properties:** Validar leitura/escrita de propriedades persistentes que não possuem campo físico na classe (`TEntityMap`).
- [x] **Eventos de Modificação:** Garantir disparo de eventos (BeforePost, AfterPost, etc).
- [x] **Tratamento de Exceções:** Lidar com comportamentos anômalos no ciclo de vida do DataSet e reportar adequadamente para a UI (DBGrid).
- [x] **Calculated Fields:** Suporte nativo a campos calculados via evento `OnCalcFields` do `TDataSet`.

### 🔄 Fase 5: Integração & Conversão de Dados

*Objetivo: Facilitar a interoperabilidade entre listas, JSON e o engine do DataSet.*

- [x] **IList<T> Integration:** Melhorar integração nativa com `IList<T>` e coleções fluentes.
- [x] **Fluent Load:** Refinar método `.Load` para suportar diferentes origens de dados de forma transparente.
- [x] **Entity to Json:** Bridge para exportar dados do DataSet/Entidade para JSON.
- [x] **Json to Entity:** Bridge para importar dados de JSON diretamente para entidades via DataSet.

Branch Atual: feature/entity-dataset

Versão paralelas
Fiz uma cópia do conteúdo das branches, para analisarmos as mudanças e aplicar as alterações corretamente em:
C:\dev\Dext\Fixes

- brach-main: cópia dos arquivos da branch main, que teve merge da feature/entity-dataset, até o status anterior ao diff das tarefas listadas acima
    Erro que deve ser corrigido somente na branch feature/entity-dataset
    Fixture: TDataSetSmartTypesTests  TEntityDataSet SmartTypes Support
    ❌  Test_Read_SmartTypes

- branch-feature-entitydataset: branch atual que estamos trabalhando
- pending: foram alterações das implementações complementares não comitadas dos itens listados acima, que quebraram quase todos os testes e achei melhor isolar como referencia, mas considero que as mudanças no dataset quebraram muito.

Importante, a implementação deve ser focada na versão atual do Delphi, temos de seguir a assinatura correta dos métodos, principalmente em relação a Buffer e Bookmark

Exemplos:

Delphi XE 4 - atualmente (temos de usar desta forma)
procedure GetBookmarkData(Buffer: TRecBuf; Data: TBookmark); override;
procedure SetBookmarkData(Buffer: TRecBuf; Data: TBookmark); override;
Delphi XE3
procedure GetBookmarkData(Buffer: TRecordBuffer; Data: TBookmark); override;
procedure SetBookmarkData(Buffer: TRecordBuffer; Data: TBookmark); override;

Acho importante, realmente importante usarmos como referencia estas declarações da mesma forma que o Spring4d implementou
C:\dev\Dext\Libs\spring4d\Source\Data\ObjectDataSet\Spring.Data.VirtualDataSet.pas
C:\dev\Dext\Libs\spring4d\Source\Data\ObjectDataSet\Spring.Data.ObjectDataSet.pas

Units essenciais muito usadas no DataSet:
C:\dev\Dext\DextRepository\Sources\Core\Dext.Core.Reflection.pas
C:\dev\Dext\DextRepository\Sources\Data\Dext.Entity.Mapping.pas

Unit do TDataset atual para referencia
C:\dev\Dext\Libs\RTL\Data.DB.pas

Projetos de testes:

- C:\dev\Dext\DextRepository\Tests\Entity\DataSet\Dext.EntityDataSet.Tests.dproj
- C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.UnitTests.dproj

Projeto Exemplo

- C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\Desktop.EntityDataSet.Demo.dproj

- Estamos trabalhando com o Delphi 13.1.

1. Precisamos analisar tudo que foi passado até aqui, o conteúdo da branch atual, os mesmos arquivos da branch main, na pasta C:\dev\Dext\Fixes\branch-main, e os arquivos da pasta C:\dev\Dext\Fixes\pending.
2. Analisar na interface das units do sprint e mapear definitivamente a assinatura dos métodos, para a versão atual que estamos trabalhando
3. temos de implementar corretamente todas as features do documento
4. todas as features devem ter testes unitários e os testes devem passar

Faça uma analise muito detalhada de tudo que passei e crie um documento descrevendo tudo que descobriu, defina um plano para implementar o que falta, e corrigir todos os problemas de acordo com as regras definidas, sempre focado na versão atual do Delphi (13.1).

O trabalho agora é de Análise e Planejamento, devemos definir detalhadamente todas as tarefas que temos de implementar e como devemos implementar para concluir esta sprint, por enquanto não vamos escrever código.

Testes que estão falhando:

vamos continuar as analises e complementar o documento de acordo com os testes unitários:

C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.UnitTests.dproj
Fixture: TDataSetSmartTypesTests  TEntityDataSet SmartTypes Support
  ❌  Test_Read_Lazy_Value
      >> Expected "Lazy" but was "ù"

C:\dev\Dext\DextRepository\Tests\Entity\DataSet\Dext.EntityDataSet.Tests.dproj
Fixture: TProductDataSetTests
  ❌  Test_Currency_Value
      >> Expected 29,9 but was 0
  ❌  Test_DateTime_Value
      >> '0.46037' is not a valid timestamp

Fixture: TMasterDetailDataSetTests
  ❌  Test_Detail_FieldValues
      >> Expected 10 but was 0

NÃO ALTERE CÓDIGO, não escreva código, analise o código dos testes, o fluxo do código sendo testado, documente os problemas, e as possíveis soluções, não faça nada além disso.

Crie um novo documento na pasta C:\dev\Dext\DextRepository\Docs\Plans e detalhe tudo que descobri, novamente repito, não escreva código, apenas analise, faça um diagnóstico completo  e documente.
