program RunSetupTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Entity.Setup.Test in 'Dext.Entity.Setup.Test.pas';

var
  Test: TSetupTest;
begin
  Writeln('🚀 Starting Setup Test Runner...');
  try
    Writeln('   Creating TSetupTest...');
    Test := TSetupTest.Create;
    try
      Writeln('   Executing Test.Run...');
      Test.Run;
    finally
      Test.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  // No Readln here for automation
end.
