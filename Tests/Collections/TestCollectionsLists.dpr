program TestCollectionsLists;

{$APPTYPE CONSOLE}

uses
  System.Rtti,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Core.Activator,
  Dext.Json,
  Dext.Json.Types,
  Dext.Collections
  Dext.Utils;

type
  // 1. Entidade de Teste
  TPost = class
  private
    FId: Integer;
    FTitle: string;
  public
    property id: Integer read FId write FId;
    property title: string read FTitle write FTitle;
  end;

  // 2. Custom List para o caso 3 (Custom registrada pelo Activator)
  {$M+}
  IMyList<T> = interface(IInterface)
    ['{AD578CBE-F663-42AA-A8CB-3FFF0DE9611D}']
    procedure Add(const Item: T);
    function Count: Integer;
  end;

  TMyList<T> = class(TInterfacedObject, IMyList<T>)
  private
    FItems: TList<T>; // Usando System.Generics.Collections internamente
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Item: T);
    function Count: Integer;
  end;
  {$M-}
{ TMyList<T> }

constructor TMyList<T>.Create;
begin
  inherited Create;
  FItems := TList<T>.Create;
end;

destructor TMyList<T>.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TMyList<T>.Add(const Item: T);
begin
  FItems.Add(Item);
end;

function TMyList<T>.Count: Integer;
begin
  Result := FItems.Count;
end;

procedure RunTests;
var
  JsonStr: string;
  DextList: Dext.Collections.TList<TPost>;
  SystemList: System.Generics.Collections.TList<TPost>;
begin
  Writeln('--- Testes de Deserializacao de Listas ---');
  Writeln;

  JsonStr := '[{"id": 1, "title": "Post 1"}, {"id": 2, "title": "Post 2"}]';

  // ==========================================
  // Cenário 1: Dext.Collections.TList<TPost>
  // ==========================================
  Writeln('1. Testando Dext.Collections.TList<TPost>...');
  try
    DextList := TDextJson.Deserialize<Dext.Collections.TList<TPost>>(JsonStr);
    try
      Writeln('   Success! Count: ', DextList.Count);
    finally
      DextList.Free;
    end;
  except
    on E: Exception do
      Writeln('   Error: ', E.ClassName, ' - ', E.Message);
  end;
  Writeln;

  // ==========================================
  // Cenário 2: System.Generics.Collections.TList<TPost>
  // ==========================================
  Writeln('2. Testando System.Generics.Collections.TList<TPost>...');
  try
    // SystemList := TDextJson.Deserialize<System.Generics.Collections.TList<TPost>>(JsonStr); // Erro de namespace se não for explícito?
    // Em Delphi, o TDextJson.Deserialize dá suporte a classes se tiverem Add.
    var Val2 := TDextJson.Deserialize(TypeInfo(System.Generics.Collections.TList<TPost>), JsonStr);
    SystemList := Val2.AsType<System.Generics.Collections.TList<TPost>>;
    try
      Writeln('   Success! Count: ', SystemList.Count);
    finally
      SystemList.Free;
    end;
  except
    on E: Exception do
      Writeln('   Error: ', E.ClassName, ' - ', E.Message);
  end;
  Writeln;

  // ==========================================
  // Cenário 3: Custom List registrada (IMyList<TPost>)
  // ==========================================
  Writeln('3. Testando Custom List (IMyList<TPost>)...');
  try
    TActivator.RegisterDefault<IMyList<TPost>, TMyList<TPost>>;

    var CustomList := TDextJson.Deserialize<IMyList<TPost>>(JsonStr);
    if CustomList <> nil then
    begin
      Writeln('   Success! Count: ', CustomList.Count);
    end
    else
      Writeln('   Error: Failed to instantiate');
  except
    on E: Exception do
      Writeln('   Error: ', E.ClassName, ' - ', E.Message);
  end;
end;

begin
  try
    RunTests;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
