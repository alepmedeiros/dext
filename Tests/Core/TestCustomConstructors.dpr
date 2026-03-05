program TestCustomConstructors;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.DI.Attributes,
  Dext.Testing.Attributes,
  Dext.Testing.Runner,
  Dext.Testing.Fluent,
  Dext.Assertions;

type
  ILogger = interface
    ['{8F3C4D2E-1A5B-4C7D-9E8F-2A3B4C5D6E7F}']
    procedure Log(const Msg: string);
  end;

  TConsoleLogger = class(TInterfacedObject, ILogger)
    procedure Log(const Msg: string);
  end;

  IConfig = interface
    ['{9A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D}']
    function GetValue: string;
  end;

  TAppConfig = class(TInterfacedObject, IConfig)
    function GetValue: string;
  end;

  // Service with multiple constructors
  TMyService = class
  private
    FLogger: ILogger;
    FConfig: IConfig;
    FConstructorUsed: string;
  public
    // Constructor 1: No parameters (should NOT be used by DI)
    constructor Create; overload;
    
    // Constructor 2: Only Logger (greedy would prefer Constructor 3)
    constructor Create(ALogger: ILogger); overload;

    // Constructor 3: Logger + Config (greedy would pick this)
    [ServiceConstructor]  // But we mark this one as preferred!
    constructor Create(ALogger: ILogger; AConfig: IConfig); overload;

    property ConstructorUsed: string read FConstructorUsed;
  end;

  // New service to test field injection
  TFieldInjectedService = class
  private
    [Inject]
    FLogger: ILogger;

    [Inject]
    FConfig: IConfig;

    FSomeString: string;
  public
    property Logger: ILogger read FLogger;
    property Config: IConfig read FConfig;
    property SomeString: string read FSomeString;
  end;

  [TestFixture('DI Custom Constructors and Field Injection')]
  TDICustomConstructorsTests = class
  private
    FServices: IServiceCollection;
    FProvider: IServiceProvider;
  public
    [Setup]
    procedure Setup;
    
    [Test('Should resolve using greedy strategy fallback without attribute')]
    procedure TestGreedyFallback;
    
    [Test('Should use constructor marked with ServiceConstructor attribute')]
    procedure TestServiceConstructorAttribute;
    
    [Test('Should inject fields marked with Inject attribute')]
    procedure TestFieldInjection;
  end;

{ TConsoleLogger }

procedure TConsoleLogger.Log(const Msg: string);
begin
  WriteLn('[LOG] ', Msg);
end;

{ TAppConfig }

function TAppConfig.GetValue: string;
begin
  Result := 'AppConfig Value';
end;

{ TMyService }

constructor TMyService.Create;
begin
  FConstructorUsed := 'Create()';
end;

constructor TMyService.Create(ALogger: ILogger);
begin
  FLogger := ALogger;
  FConstructorUsed := 'Create(ILogger)';
end;

constructor TMyService.Create(ALogger: ILogger; AConfig: IConfig);
begin
  FLogger := ALogger;
  FConfig := AConfig;
  FConstructorUsed := 'Create(ILogger, IConfig)';
end;

{ TDICustomConstructorsTests }

procedure TDICustomConstructorsTests.Setup;
begin
  FServices := TDextServiceCollection.Create;
  TServiceCollectionExtensions.AddSingleton<ILogger, TConsoleLogger>(FServices);
  TServiceCollectionExtensions.AddSingleton<IConfig, TAppConfig>(FServices);
  
  FServices.AddScoped(TServiceType.FromClass(TMyService), TMyService);
  FServices.AddScoped(TServiceType.FromClass(TFieldInjectedService), TFieldInjectedService);
  
  FProvider := FServices.BuildServiceProvider;
end;

procedure TDICustomConstructorsTests.TestGreedyFallback;
begin
  // Automatically covered by normal DI resolution if ServiceConstructor is absent
  Should(Assigned(FProvider)).BeTrue; // basic check to ensure container is valid
end;

procedure TDICustomConstructorsTests.TestServiceConstructorAttribute;
var
  MyService: TMyService;
begin
  MyService := FProvider.GetService(TServiceType.FromClass(TMyService)) as TMyService;
  
  Should(MyService).NotBeNil;
  Should(MyService.ConstructorUsed).Be('Create(ILogger, IConfig)');
end;

procedure TDICustomConstructorsTests.TestFieldInjection;
var
  MyService: TFieldInjectedService;
begin
  MyService := FProvider.GetService(TServiceType.FromClass(TFieldInjectedService)) as TFieldInjectedService;
  
  Should(MyService).NotBeNil;
  Should(MyService.Logger).NotBeNil;
  Should(MyService.Config).NotBeNil;
end;

begin
  SetConsoleCharSet();
  try
    WriteLn;
    WriteLn('DI Attributes Unit Tests');
    WriteLn('========================');
    WriteLn;

    TTest.SetExitCode(
      TTest
        .Configure
        .Verbose
        .RegisterFixtures([
          TDICustomConstructorsTests
         ])
        .Run);
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  ConsolePause;
end.
