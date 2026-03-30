# Diagnósticos e Debugging

O Dext Framework oferece captura nativa de stack trace com alocação zero de memória e parseamento assíncrono de arquivos MAP para entregar logs de erro legíveis e prontos para produção.

## A Unit `Dext.Core.Debug.pas`

Ao simplesmente incluir a unit `Dext.Core.Debug` em seu projeto, o Dext Framework intercepta automaticamente exceções não tratadas globalmente e gera um stack trace legível, incluindo **nomes de units**, **números de linha** e **definições de métodos**.

```pascal
program MyDextApp;

uses
  System.StartUpCopy,
  FMX.Forms,
  Dext.Core.Debug, // Ativa o gancho automático de exceções
  MainForm in 'MainForm.pas' {Form1};
```

### Principais Capacidades

1. **Buffer Circular de Alocação Zero:** Os stack traces e registros de exceção são capturados em um buffer circular fixo pré-alocado. Isso garante que, se sua aplicação travar devido a um erro de falta de memória (OOM) ou corrupção de heap, o Dext ainda poderá capturar o stack trace com segurança sem solicitar memória adicional.

2. **Parseamento Assíncrono de Arquivo MAP:** Para resolver endereços de memória (ponteiros) de volta para linhas de código-fonte, o Dext precisa ler o arquivo `.map` do seu executável. Como os arquivos MAP podem ter vários megabytes, o framework delega a operação de parseamento para uma `TAsyncTask` em segundo plano. Isso evita que sua aplicação ou suíte de testes congele na inicialização.

3. **Espera Inteligente (Smart Wait):** Se uma exceção for levantada exatamente enquanto a thread de segundo plano ainda está carregando o arquivo `.map`, o mecanismo `TStackTrace` aguarda de forma inteligente (até 3 segundos) para que o processamento termine, permitindo que ele entregue um log de stack útil e totalmente resolvido, em vez de retornar apenas endereços hexadecimais.

4. **Alinhamento Correto de RVA:** No compilador Delphi para formatos Windows PE32/PE64, o segmento de código `0001: CODE` requer uma correção de RVA (-$1000). O parser otimizado do Dext alinha automaticamente esses ponteiros sem a necessidade de bibliotecas de terceiros.

### Exemplo Rápido

Para capturar manualmente o stack de execução atual (por exemplo, dentro de um bloco de log customizado ou métricas), basta chamar `TStackTrace.Capture`:

```pascal
uses
  Dext.Core.Debug;

procedure LogCriticalState;
begin
  Log.Error('Sistema entrou em estado crítico! Stack: '#13#10 + TStackTrace.Capture(1));
end;
```

> **Nota:** Para que os números de linha e nomes de units apareçam corretamente, você deve compilar seu `.exe` / `.dll` com a configuração de "Detailed Map File" ativada (`Project Options -> Building -> Delphi Compiler -> Linking -> Map file: Detailed`).
