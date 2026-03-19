program Dext.EntityDataSet.Tests;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext.Testing,
  Dext.Entity.DataSet.Tests in 'Dext.Entity.DataSet.Tests.pas';

begin
  SetConsoleCharSet;
  try
    SafeWriteln;
    SafeWriteln('=== Dext - EntityDataSet Unit Tests ===');
    SafeWriteln;

    TTest.SetExitCode(
      TTest.Configure
        .Verbose
        .RegisterFixtures([
          TEntityDataSetTests,
          TProductDataSetTests,
          TMasterDetailDataSetTests,
          TEntityDataSetCRUDTests,
          TEntityDataSetStressTests
        ]).Run
    );
  except
    on E: Exception do
    begin
      SafeWriteln('FATAL ERROR: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  ConsolePause;
end.
