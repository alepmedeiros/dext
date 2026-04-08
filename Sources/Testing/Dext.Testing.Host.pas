{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2026-04-07                                                      }
{                                                                           }
{  Dext.Testing.Host - Application Host for Test Execution (GUI/Console)    }
{***************************************************************************}
{$I Dext.inc}

unit Dext.Testing.Host;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing.Fluent,
  Dext.Testing.Runner;

type
  /// <summary>Manages the lifecycle and execution environment during tests (Console, IDE, or CI).</summary>
  TTestHost = class
  public
    /// <summary>Executes the test suite with a specific configuration.</summary>
    class procedure Execute(const AConfig: TTestConfigurator); overload;
    /// <summary>Executes the tests using the detected default settings.</summary>
    class procedure Execute; overload;
  end;

procedure RunTests(const Config: TTestConfigurator); overload;
procedure RunTests; overload;

implementation

uses
  {$IFDEF MSWINDOWS}
  Vcl.Forms,
  Winapi.Windows,
  {$ENDIF}
  System.IOUtils,
  Dext.Utils,
  Dext.Core.Writers,
  Dext.Testing.TestInsight;

procedure RunTests(const Config: TTestConfigurator);
begin
  TTestHost.Execute(Config);
end;

procedure RunTests; overload;
begin
  TTestHost.Execute;
end;



{ TTestHost }

class procedure TTestHost.Execute;
begin
  Execute(TTest.Configure);
end;

class procedure TTestHost.Execute(const AConfig: TTestConfigurator);
var
  IsUI: Boolean;
  Config: TTestConfigurator;
  i: Integer;
  LogFile: string;
  LogStrings: TStringList;
  IsLogEnabled: Boolean;
begin
  SetConsoleCharSet;
  
  LogStrings := TStringList.Create;
  try
    IsLogEnabled := False;
    LogFile := '';
    
    // Detect parameters
    for i := 1 to ParamCount do
    begin
      var P := ParamStr(i);
      if (CompareText(P, '/log') = 0) or (CompareText(P, '-log') = 0) then
      begin
        IsLogEnabled := True;
        LogFile := ChangeFileExt(ParamStr(0), '.log');
      end;
    end;

    if IsLogEnabled then
    begin
      // Force Dext to write to our string list for persistence in background
      InitializeDextWriter(TStringsWriter.Create(LogStrings));
      SafeWriteLn('--- DEXT TEST HOST LOG STARTED: ' + DateTimeToStr(Now) + ' ---');
      SafeWriteLn('CmdLine: ' + GetCommandLine);
    end;

    Config := AConfig;
    IsUI := False;
    
    // Detect TestInsight from command line
    for i := 1 to ParamCount do
    begin
      var P := ParamStr(i);
      if (CompareText(P, '/X') = 0) or (CompareText(P, '-X') = 0) or 
         (CompareText(P, '/TestInsight') = 0) then
      begin
        TTestRunner.SetTestInsightActive(True);
        IsUI := True;
        Break;
      end;
    end;

    if not IsUI then
      IsUI := Config.IsTestInsightActive;

    {$IFDEF MSWINDOWS}
    if IsUI then
    begin
      if not Assigned(Application) then
        Application.Initialize;
        
      var Listener := TTestInsightListener.Create;
      TTestRunner.RegisterListener(Listener);
      
      var Selected := Listener.GetSelectedTests;
      if (Length(Selected) = 0) and TTestRunner.IsTestInsightActive then
      begin
        // If no selection from IDE, it is a "Run All" command.
        // We auto-select all tests to avoid IDE tree collapse.
        var FixtureClasses := Config.GetFixtureClasses;
        if Length(FixtureClasses) > 0 then
          TTestRunner.RegisterFixture(FixtureClasses)
        else
          TTestRunner.Discover;
          
        Selected := TTestRunner.GetAllTestPaths;
      end;

      if Length(Selected) > 0 then
      begin
        Config.FilterBySelection(Selected);
      end;

      Config.Run;
      
      var WaitCycles := 10;
      if TTestRunner.IsDiscoveryMode then
        WaitCycles := 60; // 3 seconds for discovery
        
      for i := 1 to WaitCycles do
      begin
        Application.ProcessMessages;
        Sleep(50);
      end;
    end
    else
    {$ENDIF}
    begin
      Config.Run;
    end;
    
    if TTestRunner.Summary.Failed > 0 then
      ExitCode := 1
    else
      ExitCode := 0;

    if IsLogEnabled and (LogFile <> '') then
    begin
      SafeWriteLn('--- DEXT TEST HOST LOG FINISHED (Summary: Fixtures=' + 
        TTestRunner.FixtureCount.ToString + ', Tests=' + TTestRunner.TestCount.ToString + ') ---');

      try
        LogStrings.SaveToFile(LogFile, TEncoding.UTF8);
      except
        // ignore
      end;
    end;
  finally
    LogStrings.Free;
    // Restore default writer to prevent AV on exit if LogStrings is gone
    InitializeDextWriter(Nil);
  end;
end;

end.
