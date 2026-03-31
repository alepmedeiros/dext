# Plano de Implementação: Integração Design-Time (TEntityDataProvider)

Este documento descreve a arquitetura e o roteiro de implementação para a experiência de Design-Time do `TEntityDataSet` no Dext Framework, focando em produtividade (especialmente para componentes como cxGrid) e estabilidade da IDE.

## 1. Visão Geral da Arquitetura

A integração será baseada em um modelo **Hub-and-Spoke**, onde o componente `TEntityDataProvider` centraliza os metadados extraídos via parsing estático da `interface` das Units.

### Componentes Chave

*   **TEntityDataProvider (O Hub):** 
    *   Centraliza o cache de metadados das classes decoradas com `[Entity]`.
    *   Mantém a lista de caminhos de arquivos fonte (Model Units).
    *   Propriedade `TFDConnection` (opcional) para ponte de dados reais.
*   **TEntityDataSet (O Spoke):** 
    *   Propriedade `DataProvider: TEntityDataProvider`.
    *   Em design-time, consome o Hub para criar `TFields` e visualizar dados via FireDAC.

## 2. Estratégia de Parsing (Reuso Dext CLI)

Não criaremos um novo parser. Utilizaremos o motor de **DelphiAST** já presente no `dext.exe`, desacoplando sua lógica de extração de metadados de entidades.

*   **Oque reaproveitar:** A lógica de identificação de classes, propriedades e leitura de atributos customizados usada nas Facades e Documentação HTML do CLI.
*   **Mapeamento em Cache:** O Hub mantém um `TDictionary` atualizado no salvamento do arquivo, garantindo que o re-parsing seja rápido e transparente.

## 3. Integração com a IDE e Produtividade (OTAPI)

A experiência deve evitar "bloat" na memória do Delphi e ser resiliente a erros de digitação.

*   **Hook AfterSave (IOTAModuleNotifier):** O re-parsing ocorre silenciosamente ao salvar (Ctrl+S). Se a sintaxe estiver inválida, o estado visual mantém o último cache estável (resiliência).
*   **Injeção Automática de Uses:** Ao selecionar uma classe no editor do DataSet, o expert verifica se a Unit correspondente já está no `uses` do Form/Datamodule. Caso não esteja, ela é injetada automaticamente para garantir a compilação imediata.
*   **Shortcut "Execute Direct":** Botão direito no DataSet para "Preview Data" via FireDAC, simulando o modo "Database as API" do Dext.

## 4. Roteiro de Implementação (Fases)

### Fase 1: Fundação e Reuso (dext.ef.design)
- [ ] Desacoplar MetadataParser do `dext.exe` para unit compartilhada no Framework.
- [ ] Implementar `TEntityDataProvider` básico com cache e gerenciamento de Units.
- [ ] Garantir que o componente lide com `csDesigning` para não estourar erros de conexão nula.

### Fase 2: Editores e OTAPI
- [ ] Property Editor para seleção de classes (com busca via cache do Provider).
- [ ] Component Editor (Right-Click) "Generate Fields from Source".
- [ ] Registrar Notificadores IOTA (AfterSave) no Hub Central.
- [ ] Lógica de injeção automática de `uses`.

### Fase 3: SQL & Preview Data
- [ ] Implementar gerador de SQL de preview baseado no mapeamento AST.
- [ ] Integrar `TFDConnection` ao Hub para povoar os DataSets em modo design.

---
**Nota sobre o Futuro (Backlog):**
Gráficos e diagramas de entidades navegáveis serão implementados em uma fase posterior, aproveitando a lógica de gráficos já existente na documentação do Dext CLI.
