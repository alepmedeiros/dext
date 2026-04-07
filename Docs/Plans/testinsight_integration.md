# Plano de Implementação: Integração Dext.Testing com TestInsight

Este documento descreve as etapas necessárias para integrar o framework de testes unitários do Dext com o plugin de IDE **TestInsight**.

## Visão Geral

O TestInsight é um plugin para a IDE do Delphi que fornece uma interface gráfica para execução e visualização de testes unitários. A integração consiste em fazer o executável de testes do Dext comunicar-se com o servidor local do TestInsight via protocolo REST/JSON.

## Análise Técnica

### Componentes do TestInsight (Libs\TestInsight)
* `TestInsight.Client.pas`: Contém a interface `ITestInsightClient` e a implementação `TTestInsightRestClient` que gerencia a comunicação HTTP com a IDE.
* `TestInsight.DUnitX.pas`: Exemplo de integração com DUnitX, servindo de base para o projeto.

### Arquitetura do Dext.Testing
* `TTestRunner`: Executor central que suporta múltiplos ouvintes via interface `ITestListener`.
* `TTestConfigurator`: Interface fluente para configuração de testes.

## Lista de Tarefas (Task List)

### 1. Preparação da Infraestrutura
- [x] Criar a unidade `Dext.Testing.TestInsight.pas` na pasta `Sources\Testing`.
- [x] Garantir que o diretório `Libs\TestInsight` está no Search Path do framework (confirmado via Library Path).

### 2. Implementação do Listener
- [x] Criar a classe `TTestInsightListener` herdando de `TInterfacedObject` e implementando `ITestListener`.
- [x] Implementar o mapeamento de eventos:
    - `OnRunStart`: Chamar `fClient.StartedTesting(TotalTests)`.
    - `OnFixtureStart`: Notificar início do grupo.
    - `OnTestStart`: Enviar estado `TResultType.Running` para o TestInsight.
    - `OnTestComplete`: Converter `TTestInfo` para `TTestInsightResult` e enviar via `fClient.PostResult`.
    - `OnRunComplete`: Chamar `fClient.FinishedTesting`.
- [x] Tratar mapeamento de resultados:
    - `trPassed` -> `TResultType.Passed`
    - `trFailed` -> `TResultType.Failed`
    - `trError` -> `TResultType.Error`
    - `trSkipped` -> `TResultType.Skipped`

### 3. Integração com API Fluente
- [x] Modificar `TTestConfigurator` em `Dext.Testing.Fluent.pas`:
    - Adicionar campo `FUseTestInsight: Boolean`.
    - Adicionar método `function UseTestInsight: TTestConfigurator;`.
- [x] Modificar o método `TTestConfigurator.Run`:
    - Se `FUseTestInsight` for verdadeiro, instanciar e registrar `TTestInsightListener`.
    - Adicionar suporte a builders globais `ConfigureTests` e `RunTests`.

### 4. Suporte a Seleção de Testes (Fase 2 - Concluída)
- [x] Implementar leitura de testes selecionados na IDE via `fClient.GetTests` (metodo `SelectFromIDE`).
- [x] Integrar essa lista com o `TTestFilter` do Dext (`Runner.pas`) para rodar apenas o que foi selecionado.
- [x] Implementar auto-populate da árvore (fallback modo discovery) quando rodar todos os testes.

### 5. Ativação Global em `Dext.Testing.pas`
- [x] Adicionar o alias `TTestInsightListener`.
- [x] Adicionar funções globais de atalho `RunTests` e `ConfigureTests`.

### 6. Testes e Validação
- [x] Criar um projeto de teste de exemplo que utilize `.UseTestInsight`.
- [x] Validar a visualização de resultados na janela do TestInsight dentro da IDE (Delphi 11/12).
- [x] Validar a navegação para o código fonte ao clicar em uma falha no TestInsight (uso do `CodeAddress`).

## Considerações de Design
* O suporte ao TestInsight é agnóstico à IDE (funciona via CLI se o plugin estiver ouvindo).
* Codificação UTF-8 forçada no Host para compatibilidade com ícones e logs.
* Ativação automática via parâmetro `/X` ou `-testinsight` preservada para compatibilidade plena.

---
**Status:** Concluído em 07/04/2026.
