{***************************************************************************}
{                                                                           }
{  MCP Practical Demo — Tool Definitions                                    }
{                                                                           }
{  Demonstra dois padrões de implementação de tools MCP:                   }
{                                                                           }
{  PADRÃO 1 — Tool sem chamada a API (lógica pura Delphi)                  }
{    Ideal para: validações, cálculos, formatações, regras de negócio.     }
{    Vantagem: sem latência de rede, sem dependência externa.               }
{                                                                           }
{  PADRÃO 2 — Tool com chamada a API externa                               }
{    Ideal para: consulta de dados externos, integrações.                  }
{    Usa THTTPClient do RTL — sem componentes de terceiros.                 }
{                                                                           }
{***************************************************************************}
unit MCP.PracticalDemo.Tools;

interface

uses
  Dext.MCP.Server;

procedure RegisterDemoTools(Server: TMCPServer);

implementation

uses
  System.SysUtils,
  System.Math,
  System.JSON,
  System.Net.HttpClient; // RTL — disponível desde Delphi XE8

// ===========================================================================
// PADRÃO 1: Tools sem chamada a API
// Toda a lógica roda dentro do callback — sem rede, sem I/O externo.
// ===========================================================================

procedure RegisterPureDelphi(Server: TMCPServer);
begin

  // -------------------------------------------------------------------------
  // Tool: calcular-desconto
  // Regra de negócio pura — calcula desconto progressivo por valor de compra.
  // -------------------------------------------------------------------------
  Server.Tool('calcular-desconto')
    .Description(
      'Calcula o valor do desconto e o preço final de uma compra ' +
      'aplicando a tabela progressiva de descontos da empresa. ' +
      'Regras: até R$100 = 0%, R$101-500 = 5%, R$501-1000 = 10%, acima = 15%. ' +
      'Retorna percentual aplicado, valor do desconto e preço final.')
    .Param('valor_original', 'Valor total da compra em reais', ptNumber)
    .OnCall(
      function(Args: TJSONObject): string
      var
        Valor, Percentual, Desconto, Final: Double;
        Faixa: string;
      begin
        Valor := Args.GetValue<Double>('valor_original', 0);

        if Valor <= 0 then
        begin
          Result := '{"erro": "Valor deve ser maior que zero"}';
          Exit;
        end;

        // Tabela de descontos progressiva
        if Valor <= 100 then
        begin
          Percentual := 0;
          Faixa      := 'sem desconto';
        end
        else if Valor <= 500 then
        begin
          Percentual := 5;
          Faixa      := 'compra intermediaria';
        end
        else if Valor <= 1000 then
        begin
          Percentual := 10;
          Faixa      := 'compra expressiva';
        end
        else
        begin
          Percentual := 15;
          Faixa      := 'compra premium';
        end;

        Desconto := RoundTo(Valor * (Percentual / 100), -2);
        Final    := RoundTo(Valor - Desconto, -2);

        Result := Format(
          '{"valor_original": %.2f, "percentual": %.0f, ' +
          '"desconto": %.2f, "valor_final": %.2f, "faixa": "%s"}',
          [Valor, Percentual, Desconto, Final, Faixa],
          TFormatSettings.Create('en-US'));
      end);

  // -------------------------------------------------------------------------
  // Tool: validar-cpf
  // Algoritmo puro de validação de CPF — sem API, sem banco.
  // -------------------------------------------------------------------------
  Server.Tool('validar-cpf')
    .Description(
      'Valida se um número de CPF é matematicamente correto ' +
      'usando o algoritmo oficial da Receita Federal. ' +
      'Aceita CPF com ou sem formatação (pontos e traço). ' +
      'Retorna valido (boolean) e o CPF formatado.')
    .Param('cpf', 'Número do CPF com ou sem formatação', ptString)
    .OnCall(
      function(Args: TJSONObject): string
      var
        CPF, Numeros: string;
        I, Soma, Resto, D1, D2: Integer;
        Valido: Boolean;
        Formatado: string;
      begin
        CPF := Args.GetValue<string>('cpf', '').Trim;

        // Remove formatação
        Numeros := '';
        for I := 1 to Length(CPF) do
          if CharInSet(CPF[I], ['0'..'9']) then
            Numeros := Numeros + CPF[I];

        Valido := False;

        repeat // usando repeat..until False como bloco de validação com break
          if Length(Numeros) <> 11 then Break;

          // Rejeita sequências iguais (111.111.111-11, etc.)
          if Numeros = StringOfChar(Numeros[1], 11) then Break;

          // Calcula primeiro dígito verificador
          Soma := 0;
          for I := 1 to 9 do
            Soma := Soma + StrToInt(Numeros[I]) * (11 - I);
          Resto := Soma mod 11;
          D1 := IfThen(Resto < 2, 0, 11 - Resto);

          if D1 <> StrToInt(Numeros[10]) then Break;

          // Calcula segundo dígito verificador
          Soma := 0;
          for I := 1 to 10 do
            Soma := Soma + StrToInt(Numeros[I]) * (12 - I);
          Resto := Soma mod 11;
          D2 := IfThen(Resto < 2, 0, 11 - Resto);

          if D2 <> StrToInt(Numeros[11]) then Break;

          Valido := True;
        until True;

        if Valido then
          Formatado := Format('%s.%s.%s-%s', [
            Copy(Numeros, 1, 3), Copy(Numeros, 4, 3),
            Copy(Numeros, 7, 3), Copy(Numeros, 10, 2)])
        else
          Formatado := CPF;

        Result := Format('{"valido": %s, "cpf_formatado": "%s", "numeros": "%s"}',
          [BoolToStr(Valido, True).ToLower, Formatado, Numeros]);
      end);

  // -------------------------------------------------------------------------
  // Tool: calcular-imc
  // Cálculo e classificação de IMC — lógica totalmente local.
  // -------------------------------------------------------------------------
  Server.Tool('calcular-imc')
    .Description(
      'Calcula o Índice de Massa Corporal (IMC) e retorna a classificação ' +
      'segundo a tabela da OMS. ' +
      'Retorna o valor do IMC, classificação e faixa de peso ideal.')
    .Param('peso_kg',   'Peso em quilogramas', ptNumber)
    .Param('altura_cm', 'Altura em centímetros', ptNumber)
    .OnCall(
      function(Args: TJSONObject): string
      var
        Peso, Altura, IMC: Double;
        Classificacao: string;
      begin
        Peso   := Args.GetValue<Double>('peso_kg', 0);
        Altura := Args.GetValue<Double>('altura_cm', 0) / 100; // cm → m

        if (Peso <= 0) or (Altura <= 0) then
        begin
          Result := '{"erro": "Peso e altura devem ser maiores que zero"}';
          Exit;
        end;

        IMC := RoundTo(Peso / (Altura * Altura), -1);

        if IMC < 18.5 then
          Classificacao := 'Abaixo do peso'
        else if IMC < 25.0 then
          Classificacao := 'Peso normal'
        else if IMC < 30.0 then
          Classificacao := 'Sobrepeso'
        else if IMC < 35.0 then
          Classificacao := 'Obesidade grau I'
        else if IMC < 40.0 then
          Classificacao := 'Obesidade grau II'
        else
          Classificacao := 'Obesidade grau III';

        Result := Format(
          '{"imc": %.1f, "classificacao": "%s", ' +
          '"peso_ideal_min_kg": %.1f, "peso_ideal_max_kg": %.1f}',
          [IMC, Classificacao,
           RoundTo(18.5 * Altura * Altura, -1),
           RoundTo(24.9 * Altura * Altura, -1)],
          TFormatSettings.Create('en-US'));
      end);
end;

// ===========================================================================
// PADRÃO 2: Tools com chamada a API externa
// Usa THTTPClient do RTL — nativo, sem dependências externas.
// ===========================================================================

procedure RegisterAPITools(Server: TMCPServer);
begin

  // -------------------------------------------------------------------------
  // Tool: consultar-cep
  // Chama a API pública ViaCEP (https://viacep.com.br)
  // API gratuita, sem autenticação, amplamente usada no Brasil.
  // -------------------------------------------------------------------------
  Server.Tool('consultar-cep')
    .Description(
      'Consulta o endereço completo de um CEP brasileiro ' +
      'usando a API pública ViaCEP. ' +
      'Retorna logradouro, bairro, cidade, UF e DDD. ' +
      'Aceita CEP com ou sem hífen.')
    .Param('cep', 'CEP a consultar (ex: 01310-100 ou 01310100)', ptString)
    .OnCall(
      function(Args: TJSONObject): string
      var
        CEP: string;
        Client: THTTPClient;
        Response: IHTTPResponse;
        URL: string;
        I: Integer;
        Numeros: string;
      begin
        CEP := Args.GetValue<string>('cep', '').Trim;

        // Remove formatação
        Numeros := '';
        for I := 1 to Length(CEP) do
          if CharInSet(CEP[I], ['0'..'9']) then
            Numeros := Numeros + CEP[I];

        if Length(Numeros) <> 8 then
        begin
          Result := '{"erro": "CEP inválido — informe 8 dígitos"}';
          Exit;
        end;

        URL    := 'https://viacep.com.br/ws/' + Numeros + '/json/';
        Client := THTTPClient.Create;
        try
          try
            Response := Client.Get(URL);

            if Response.StatusCode = 200 then
            begin
              // ViaCEP retorna {"erro": true} para CEPs inexistentes
              Result := Response.ContentAsString(TEncoding.UTF8);
            end
            else
              Result := Format('{"erro": "Serviço indisponível (HTTP %d)"}',
                [Response.StatusCode]);
          except
            on E: Exception do
              Result := Format('{"erro": "Falha na consulta: %s"}', [E.Message]);
          end;
        finally
          Client.Free;
        end;
      end);

  // -------------------------------------------------------------------------
  // Tool: consultar-cambio
  // Chama a API pública do Banco Central do Brasil (PTAX)
  // Consulta a cotação oficial do dólar (ou outra moeda) na data informada.
  // API pública do BCB: https://olinda.bcb.gov.br
  // -------------------------------------------------------------------------
  Server.Tool('consultar-cambio')
    .Description(
      'Consulta a cotação de câmbio oficial (PTAX) do Banco Central do Brasil. ' +
      'Use quando o usuário perguntar sobre dólar, euro ou outra moeda. ' +
      'Se a data não for informada, usa a cotação mais recente disponível. ' +
      'Retorna cotação de compra e venda.')
    .Param('moeda', 'Código da moeda: USD, EUR, GBP, ARS, etc.', ptString)
    .Param('data',  'Data no formato MM-DD-AAAA (opcional)', ptString, {Required=}False)
    .OnCall(
      function(Args: TJSONObject): string
      var
        Moeda, Data, URL: string;
        Client: THTTPClient;
        Response: IHTTPResponse;
        JsonVal: TJSONValue;
        JsonObj: TJSONObject;
        Valor: TJSONArray;
        Item: TJSONObject;
        Compra, Venda: string;
      begin
        Moeda := Args.GetValue<string>('moeda', 'USD').ToUpper.Trim;
        Data  := Args.GetValue<string>('data', '').Trim;

        if Data = '' then
          // Último dia útil
          URL := Format(
            'https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/' +
            'CotacaoMoedaDia(moeda=''%s'',dataCotacao=''%s'')' +
            '?$top=1&$format=json',
            [Moeda, FormatDateTime('MM-dd-yyyy', Now)])
        else
          URL := Format(
            'https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/' +
            'CotacaoMoedaDia(moeda=''%s'',dataCotacao=''%s'')' +
            '?$top=1&$format=json',
            [Moeda, Data]);

        Client := THTTPClient.Create;
        try
          try
            Response := Client.Get(URL);
            if Response.StatusCode <> 200 then
            begin
              Result := Format('{"erro": "BCB retornou HTTP %d"}',
                [Response.StatusCode]);
              Exit;
            end;

            JsonVal := TJSONObject.ParseJSONValue(
              Response.ContentAsString(TEncoding.UTF8));
            try
              if JsonVal is TJSONObject then
              begin
                JsonObj := JsonVal as TJSONObject;
                Valor   := JsonObj.GetValue('value') as TJSONArray;

                if (Valor = nil) or (Valor.Count = 0) then
                begin
                  Result := Format(
                    '{"erro": "Sem cotação disponível para %s na data informada"}',
                    [Moeda]);
                  Exit;
                end;

                Item   := Valor.Items[0] as TJSONObject;
                Compra := Item.GetValue<string>('cotacaoCompra', '0');
                Venda  := Item.GetValue<string>('cotacaoVenda', '0');

                Result := Format(
                  '{"moeda": "%s", "compra": %s, "venda": %s, "fonte": "BCB-PTAX"}',
                  [Moeda, Compra, Venda]);
              end
              else
                Result := '{"erro": "Resposta inesperada do BCB"}';
            finally
              JsonVal.Free;
            end;

          except
            on E: Exception do
              Result := Format('{"erro": "Falha na consulta: %s"}', [E.Message]);
          end;
        finally
          Client.Free;
        end;
      end);
end;

// ===========================================================================
// Registro geral
// ===========================================================================

procedure RegisterDemoTools(Server: TMCPServer);
begin
  RegisterPureDelphi(Server);
  RegisterAPITools(Server);
end;

end.
