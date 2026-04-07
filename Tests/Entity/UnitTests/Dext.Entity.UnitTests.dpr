program Dext.Entity.UnitTests;

{$IFNDEF TESTINSIGHT}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  Dext.MM,
  Dext.Core.Debug,
  System.SysUtils,
  Dext.Testing.Runner,
  Dext.Testing.Attributes,
  Dext.Testing.Fluent,
  Dext.Testing,
  Dext.Utils,
  Dext.Entity.SmartTypes.Tests in 'Dext.Entity.SmartTypes.Tests.pas',
  Dext.Entity.FluentQuery.Tests in 'Dext.Entity.FluentQuery.Tests.pas',
  Dext.Entity.DataSet.Tests in 'Dext.Entity.DataSet.Tests.pas',
  Dext.Entity.Async.Tests in 'Dext.Entity.Async.Tests.pas',
  Dext.Entity.SqlGenerator.Tests in 'Dext.Entity.SqlGenerator.Tests.pas',
  Dext.Entity.FluentMapping.Tests in 'Dext.Entity.FluentMapping.Tests.pas',
  Dext.Entity.DataSet.NewFeatures.Tests in 'Dext.Entity.DataSet.NewFeatures.Tests.pas',
  Dext.Entity.IdReturn.Tests in 'Dext.Entity.IdReturn.Tests.pas',
  Dext.Entity.NullableHydration.Tests in 'Dext.Entity.NullableHydration.Tests.pas',
  Dext.Entity.DataSet.Export.Tests in 'Dext.Entity.DataSet.Export.Tests.pas',
  Dext.Entity.DefaultValue.Tests in 'Dext.Entity.DefaultValue.Tests.pas',
  Dext.Entity.Design.Metadata.Tests in 'Dext.Entity.Design.Metadata.Tests.pas',
  Dext.Entity.ReportedIssues.Tests in 'Dext.Entity.ReportedIssues.Tests.pas';

begin
  SetConsoleCharSet();
  try
    SafeWriteLn;
    SafeWriteLn('🧪 Dext Entity Unit Tests');
    SafeWriteLn('=========================');
    SafeWriteLn;

    RunTests(ConfigureTests
      .VeryVerbose
      //.UseTestInsight
      .RegisterFixtures([
        TCalculatedFieldsTests,
        TDataSetSmartTypesTests,
        TEntityDataSetAutomationTests,
        TEntityDataSetCRUDTests,
        TEntityDataSetExportTests,
        TEntityDataSetFeaturesTests,
        TEntityDataSetStressTests,
        TEntityDataSetTests,
        TEntityDesignMetadataTests,
        TEntityIdReturnTests,
        TEntityNullableHydrationTests,
        TEntityDefaultValueTests,
        TFloatingPointDataSetTests,
        TMasterDetailDataSetTests,
        TNativeMasterDetailTests,
        TProductDataSetTests,
        TShadowDataSetTests,
        TSmartPropertyDataSetTests,
        TSmartTypesMatrixTests,
        TSmartTypesTests,
        TEntityReportedIssuesTests
      ]));
  except
    on E: Exception do
    begin
      SafeWriteLn('FATAL ERROR: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;

  ConsolePause;
end.
