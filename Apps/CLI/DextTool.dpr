program DextTool;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  Dext.Configuration.Core,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Json,
  Dext.Entity.Context,
  Dext.Entity.Core,
  Dext.Entity.Setup,
  Dext.Hosting.CLI,
  Dext.Hosting.CLI.Registry,
  Dext.Hosting.CLI.Commands.Configuration in 'Commands\Dext.Hosting.CLI.Commands.Configuration.pas',
  Dext.Hosting.CLI.Commands.Doc in 'Commands\Dext.Hosting.CLI.Commands.Doc.pas',
  Dext.Hosting.CLI.Commands.Facade in 'Commands\Dext.Hosting.CLI.Commands.Facade.pas',
  Dext.Hosting.CLI.Commands.MigrateDown in 'Commands\Dext.Hosting.CLI.Commands.MigrateDown.pas',
  Dext.Hosting.CLI.Commands.MigrateGenerate in 'Commands\Dext.Hosting.CLI.Commands.MigrateGenerate.pas',
  Dext.Hosting.CLI.Commands.MigrateList in 'Commands\Dext.Hosting.CLI.Commands.MigrateList.pas',
  Dext.Hosting.CLI.Commands.MigrateUp in 'Commands\Dext.Hosting.CLI.Commands.MigrateUp.pas',
  Dext.Hosting.CLI.Commands.Scaffold in 'Commands\Dext.Hosting.CLI.Commands.Scaffold.pas',
  Dext.Hosting.CLI.Commands.Test in 'Commands\Dext.Hosting.CLI.Commands.Test.pas',
  Dext.Dashboard.Routes in '..\..\Sources\Dashboard\Dext.Dashboard.Routes.pas',
  Dext.Hosting.CLI.Commands.UI in 'Commands\Dext.Hosting.CLI.Commands.UI.pas',
  Dext.Hosting.CLI.Tools.DocGen in 'Tools\Dext.Hosting.CLI.Tools.DocGen.pas',
  Dext.Hosting.CLI.Hubs.Dashboard in 'Hubs\Dext.Hosting.CLI.Hubs.Dashboard.pas',
  Dext.Dashboard.TestScanner in '..\..\Sources\Dashboard\Dext.Dashboard.TestScanner.pas',
  Dext.Dashboard.TestRunner in '..\..\Sources\Dashboard\Dext.Dashboard.TestRunner.pas';

function CreateDbContext: IDbContext;
var
  Builder: IConfigurationBuilder;
  Config: IConfigurationRoot;
  Options: TDbContextOptions;
  ConnString: string;
  Driver: string;
begin
  // Build Configuration
  Builder := TConfigurationBuilder.Create;
  Builder.Add(TJsonConfigurationSource.Create('appsettings.json', True));
  Config := Builder.Build;

  // Configure Options
  Options := TDbContextOptions.Create;
  try
    // Check Command Line for overrides
    for var i := 1 to ParamCount do
    begin
      if SameText(ParamStr(i), '--connection') or SameText(ParamStr(i), '-c') then
        if i < ParamCount then ConnString := ParamStr(i+1);
        
      if SameText(ParamStr(i), '--driver') or SameText(ParamStr(i), '-d') then
        if i < ParamCount then Driver := ParamStr(i+1);
    end;

    if ConnString = '' then
      ConnString := Config['ConnectionStrings:DefaultConnection'];

    if Driver = '' then 
      Driver := Config['Database:Driver'];

    if ConnString = '' then
      ConnString := 'Data Source=dext_cli.db;Mode=ReadWriteCreate'; // Default fallback

    // Set up options
    if (ConnString <> '') and (not ConnString.Contains('Data Source=')) or (Driver <> '') and (Driver.ToLower <> 'sqlite') then
    begin
      Options.ConnectionString := ConnString;
      if Driver <> '' then
        Options.DriverName := Driver;
    end
    else
    begin
       // SQLite logic
       var DbFile := 'dext_cli.db';
       if ConnString.Contains('Data Source=') then
       begin
         var Parts := ConnString.Split([';']);
         for var P in Parts do
           if P.Trim.StartsWith('Data Source=') then
             DbFile := P.Trim.Substring(12);
       end;
       Options.UseSQLite(DbFile);
    end;

    // Create Context
    Result := TDbContext.Create(Options);
  except
    Options.Free;
    raise;
  end;
end;

var
  CLI: TDextCLI;
begin
  try
    CLI := TDextCLI.Create(CreateDbContext);
    try
      // Migration Commands
      CLI.AddCommand(TMigrateUpCommand.Create(CreateDbContext));
      CLI.AddCommand(TMigrateDownCommand.Create(CreateDbContext));
      CLI.AddCommand(TMigrateListCommand.Create(CreateDbContext));
      CLI.AddCommand(TMigrateGenerateCommand.Create);
      
      // Tool Commands
      CLI.AddCommand(TTestCommand.Create);
      CLI.AddCommand(TConfigInitCommand.Create);
      CLI.AddCommand(TEnvScanCommand.Create);
      CLI.AddCommand(TUICommand.Create);
      CLI.AddCommand(TScaffoldCommand.Create);
      CLI.AddCommand(TDocCommand.Create);
      CLI.AddCommand(TFacadeCommand.Create);

      CLI.Run;
    finally
      CLI.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
