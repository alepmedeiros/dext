unit Dext.Hosting.CLI.Commands.MigrateList;

interface

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Runner,
  Dext.Hosting.CLI,
  Dext.Hosting.CLI.Args,
  Dext.Entity.Drivers.Interfaces,
  Dext.Utils;

type
  TMigrateListCommand = class(TInterfacedObject, IConsoleCommand)
  private
    FContextFactory: TFunc<IDbContext>;
  public
    constructor Create(AContextFactory: TFunc<IDbContext>);
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TCommandLineArgs);
  end;

implementation

{ TMigrateListCommand }

constructor TMigrateListCommand.Create(AContextFactory: TFunc<IDbContext>);
begin
  FContextFactory := AContextFactory;
end;

function TMigrateListCommand.GetName: string;
begin
  Result := 'migrate:list';
end;

function TMigrateListCommand.GetDescription: string;
begin
  Result := 'Lists applied and pending migrations.';
end;

procedure TMigrateListCommand.Execute(const Args: TCommandLineArgs);
var
  Context: IDbContext;
  Migrator: TMigrator;
  Applied: IList<string>;
  Available: TArray<IMigration>;
  Status: string;
  SourcePath: string;
begin
  SourcePath := Args.GetOption('source');
  if SourcePath = '' then
    SourcePath := Args.GetOption('s'); // Alias

  if SourcePath <> '' then
  begin
    SafeWriteLn('   📂 Loading migrations from: ' + SourcePath);
    TJsonMigrationLoader.LoadFromDirectory(SourcePath);
  end;

  Context := FContextFactory();
  try
    Migrator := TMigrator.Create(Context);
    try
      SafeWriteLn('Migration Status:');
      SafeWriteLn('-----------------');
      
      Available := TMigrationRegistry.Instance.GetMigrations;
      
      Applied := Migrator.GetAppliedMigrations;

      for var Mig in Available do
      begin
        if Applied.Contains(Mig.GetId) then
          Status := '[Applied]'
        else
          Status := '[Pending]';

        SafeWriteLn(Status.PadRight(12) + Mig.GetId);
      end;
    finally
      Migrator.Free;
    end;
  finally
    if Context is TDbContext then
    begin
      var CtxObj := Context as TDbContext;
      Context := nil; 
      CtxObj.Free;
    end;
  end;
end;

end.
