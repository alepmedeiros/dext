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
{  Dext.Testing.TestInsight - IDE Integration Listener                      }
{***************************************************************************}
unit Dext.Testing.TestInsight;

{$IFDEF TESTINSIGHT}
  {$MESSAGE HINT 'Dext: TestInsight integration is enabled. Ensure TestInsight.Client.pas is in your Delphi Library Path.'}
{$ENDIF}

interface

uses
  System.SysUtils,
  Dext.Testing.Runner,
  TestInsight.Client;

type
  /// <summary>
  ///   TTestInsightListener reports test results back to the TestInsight IDE plugin.
  /// </summary>
  TTestInsightListener = class(TInterfacedObject, ITestListener)
  private
    FClient: ITestInsightClient;
    function TryPost(const AResult: TTestInsightResult): Boolean;

  public
    constructor Create(const ABaseUrl: string = '');
    
    // ITestListener Implementation
    procedure OnRunStart(TotalTests: Integer);
    procedure OnRunComplete(const Summary: TTestSummary);
    procedure OnFixtureStart(const FixtureName: string; TestCount: Integer);
    procedure OnFixtureComplete(const FixtureName: string);
    procedure OnTestStart(const UnitName, Fixture, Test: string);
    procedure OnTestComplete(const Info: TTestInfo);
    
    function GetSelectedTests: TArray<string>;
  end;

implementation

uses
  Dext.Utils;

{ TTestInsightListener }

constructor TTestInsightListener.Create(const ABaseUrl: string);
begin
  inherited Create;
  TTestRunner.SetTestInsightActive(True);
  
  if ABaseUrl = '' then
    FClient := TTestInsightRestClient.Create('http://localhost:8102/')
  else
    FClient := TTestInsightRestClient.Create(ABaseUrl);
end;

function TTestInsightListener.TryPost(const AResult: TTestInsightResult): Boolean;
begin
  Result := False;
  try
    FClient.PostResult(AResult, True);
    Result := True;
  except
    on E: Exception do;
  end;
end;


procedure TTestInsightListener.OnRunStart(TotalTests: Integer);
begin
  // No reporting needed here for current plugin versions
end;

procedure TTestInsightListener.OnRunComplete(const Summary: TTestSummary);
begin
  try
    FClient.FinishedTesting;
  except
    on E: Exception do;
  end;
end;

procedure TTestInsightListener.OnFixtureStart(const FixtureName: string; TestCount: Integer);
begin
  { Do nothing - reporting fixtures as tests causes duplicate nodes in IDE tree }
end;

procedure TTestInsightListener.OnFixtureComplete(const FixtureName: string);
begin
  { Do nothing }
end;

procedure TTestInsightListener.OnTestStart(const UnitName, Fixture, Test: string);
var
  TestResult: TTestInsightResult;
  LPath: string;
begin
  { Path MUST match UnitName.ClassName for the IDE to find the node }
  LPath := UnitName + '.' + Fixture;
  
  TestResult := TTestInsightResult.Create(TResultType.Running, Test, Fixture);
  TestResult.ClassName := Fixture;
  TestResult.UnitName := UnitName;
  TestResult.MethodName := Test;
  TestResult.Path := LPath;
  
  TryPost(TestResult);
end;

procedure TTestInsightListener.OnTestComplete(const Info: TTestInfo);
var
  ResultType: TResultType;
  TestResult: TTestInsightResult;
  LPath: string;
begin
  case Info.Result of
    trPassed:  ResultType := TResultType.Passed;
    trFailed:  ResultType := TResultType.Failed;
    trError:   ResultType := TResultType.Error;
    trSkipped: ResultType := TResultType.Skipped;
  else
    ResultType := TResultType.Error;
  end;

  LPath := Info.UnitName + '.' + Info.ClassName;

  TestResult := TTestInsightResult.Create(ResultType, Info.DisplayName, Info.ClassName);
  TestResult.Duration := Trunc(Info.Duration.TotalMilliseconds);
  TestResult.ClassName := Info.ClassName;
  TestResult.UnitName := Info.UnitName;
  TestResult.MethodName := Info.TestName;
  TestResult.Path := LPath;
  
  { Attempt to get line numbers if a provider (JCL/MadExcept) is available }
  GetExtendedDetails(Info.CodeAddress, TestResult);
  
  if Info.Result in [trFailed, trError] then
  begin
    TestResult.ExceptionMessage := Info.ErrorMessage;
    TestResult.Status := Info.StackTrace;
  end
  else if Info.Result = trSkipped then
  begin
    TestResult.ExceptionMessage := Info.ErrorMessage;
    TestResult.Status := Info.ErrorMessage;
  end;

  TryPost(TestResult);
end;

function TTestInsightListener.GetSelectedTests: TArray<string>;
begin
  try
    Result := FClient.GetTests;
  except
    on E: Exception do Result := [];
  end;
end;

end.
