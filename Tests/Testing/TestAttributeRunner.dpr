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
{  Created: 2026-01-04                                                      }
{                                                                           }
{  TestAttributeRunner - Demo for Attribute-Based Test Framework            }
{                                                                           }
{  Demonstrates the new [TestFixture] / [Test] attribute system             }
{                                                                           }
{***************************************************************************}
program TestAttributeRunner;

{$IFNDEF TESTINSIGHT}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  Dext.MM,
  System.SysUtils,
  System.Rtti,
  Dext.Assertions,
  Dext.Testing.Host,
  Dext.Testing.Attributes,
  Dext.Testing.Runner,
  Dext.Testing.Fluent,
  Dext.Testing.TestInsight,
  Dext.Utils,
  Dext.Core.SmartTypes,
  Dext.Entity.Prototype,
  Dext.Testing.Listeners.Telemetry,
  Dext.Logging,
  Dext.Logging.Global;

type
  TSmartUser = class
  public
    FName: StringType; // Smart Property
    FAge: IntType;     // Smart Property
  end;

  TAddress = class
  private
    FCity: string;
    FZip: Integer;
  public
    constructor Create(const ACity: string; AZip: Integer);
    property City: string read FCity;
    property Zip: Integer read FZip;
  end;

  TPerson = class
  private
    FName: string;
    FAddress: TAddress;
  public
    constructor Create(const AName: string; AAddress: TAddress);
    destructor Destroy; override;
    property Name: string read FName;
    property Address: TAddress read FAddress;
  end;
  
  [TestFixture]
  TGlobalSetup = class
  public
    [AssemblyInitialize]
    class procedure GlobalSetup;
    
    [AssemblyCleanup]
    class procedure GlobalCleanup;
  end;

  [TestFixture('Calculator Tests')]
  TCalculatorTests = class
  private
    FInitialized: Boolean;
  public
    [BeforeAll]
    procedure BeforeAll;
    
    [AfterAll]
    procedure AfterAll;
    
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure TestAddition;
    
    [Test('Subtraction should handle negative results')]
    procedure TestSubtraction;
    
    [Test]
    [Category('Math')]
    procedure TestMultiplication;

    [Test]
    [Category('Math')]
    [Category('Division')]
    procedure TestDivision;
    
    [Test]
    [Ignore('Not implemented yet')]
    procedure TestModulo;
    
    [Test]
    [TestCase(2, 3, 5)]
    [TestCase(0, 0, 0)]
    [TestCase(-1, 1, 0)]
    [TestCase(100, 200, 300)]
    procedure TestAddWithCases(A, B, Expected: Integer);
    
    [Test]
    [TestCase(10, 2, 5)]
    [TestCase(9, 3, 3)]
    [TestCase(100, 10, 10)]
    procedure TestDivideWithCases(A, B, Expected: Integer);
  end;

  [TestFixture]
  TStringTests = class
  public
    [Test]
    procedure TestUpperCase;
    
    [Test]
    procedure TestLowerCase;
    
    [Test]
    procedure TestTrim;
    
    [Test]
    [TestCase('Hello', 'HELLO')]
    [TestCase('World', 'WORLD')]
    [TestCase('Dext', 'DEXT')]
    procedure TestUpperCaseParameterized(const Input, Expected: string);

    [Test]
    [Priority(1)]
    procedure TestConcatenation;
    
    [Test]
    [Explicit('Integration test - run manually')]
    procedure TestFileRead;
  end;

  [TestFixture('Assertion Integration')]
  TAssertionTests = class
  public
    [Test]
    procedure TestShouldString;
    
    [Test]
    procedure TestShouldInteger;
    
    [Test]
    procedure TestShouldBoolean;
    
    [Test]
    procedure TestShouldList;
    
    [Test]
    [Description('Verifies that fluent chaining works correctly')]
    procedure TestFluentChaining;

    [Test]
    procedure TestDeepAssertions;

    [Test]
    [Description('Verifies strongly typed assertions using Prototype.Entity<T>')]
    procedure TestSmartAssertions;
    
    [Test]
    [Description('Demonstrates automatic ITestContext injection')]
    procedure TestContextInjection(Context: ITestContext);

    [Test]
    procedure TestMultipleAssertions;
  end;

  TExternalData = class
  public
    class function GetValues: TArray<TArray<TValue>>; static;
  end;

  [TestFixture('External Data Tests')]
  TExternalDataTests = class
  public
    [Test]
    [TestCaseSource(TExternalData, 'GetValues')]
    procedure TestWithExternalData(A, B, Expected: Integer);
  end;

{ TGlobalSetup }

class procedure TGlobalSetup.GlobalSetup;
begin
  SafeWriteLn('  🌐 [AssemblyInitialize] Global test environment setup...');
end;

class procedure TGlobalSetup.GlobalCleanup;
begin
  SafeWriteLn('  🌐 [AssemblyCleanup] Global test environment cleanup...');
end;

{ TAddress }

constructor TAddress.Create(const ACity: string; AZip: Integer);
begin
  FCity := ACity;
  FZip := AZip;
end;

{ TPerson }

constructor TPerson.Create(const AName: string; AAddress: TAddress);
begin
  FName := AName;
  FAddress := AAddress;
end;

destructor TPerson.Destroy;
begin
  FAddress.Free;
  inherited;
end;

{ TCalculatorTests }

procedure TCalculatorTests.BeforeAll;
begin
  SafeWriteLn('    [BeforeAll] Calculator tests starting...');
  FInitialized := True;
end;

procedure TCalculatorTests.AfterAll;
begin
  SafeWriteLn('    [AfterAll] Calculator tests completed.');
end;

procedure TCalculatorTests.Setup;
begin
end;

procedure TCalculatorTests.TearDown;
begin
end;

procedure TCalculatorTests.TestAddition;
begin
  Should(2 + 2).Be(4);
end;

procedure TCalculatorTests.TestSubtraction;
begin
  Should(5 - 10).Be(-5);
end;

procedure TCalculatorTests.TestMultiplication;
begin
  Should(3 * 4).Be(12);
end;

procedure TCalculatorTests.TestDivision;
begin
  Should(10 div 2).Be(5);
end;

procedure TCalculatorTests.TestModulo;
begin
  Should(10 mod 3).Be(1);
end;

procedure TCalculatorTests.TestAddWithCases(A, B, Expected: Integer);
begin
  Should(A + B).Be(Expected);
end;

procedure TCalculatorTests.TestDivideWithCases(A, B, Expected: Integer);
begin
  Should(A div B).Be(Expected);
end;

{ TStringTests }

procedure TStringTests.TestUpperCase;
begin
  Should('hello').BeEquivalentTo('HELLO');
end;

procedure TStringTests.TestLowerCase;
begin
  Should('WORLD'.ToLower).Be('world');
end;

procedure TStringTests.TestTrim;
begin
  Should('  trimmed  '.Trim).Be('trimmed');
end;

procedure TStringTests.TestUpperCaseParameterized(const Input, Expected: string);
begin
  Should(Input.ToUpper).Be(Expected);
end;

procedure TStringTests.TestConcatenation;
begin
  Should('Hello' + ' ' + 'World').Be('Hello World');
end;

procedure TStringTests.TestFileRead;
begin
  Should(True).BeTrue;
end;

{ TAssertionTests }

procedure TAssertionTests.TestShouldString;
begin
  Should('Dext Framework')
    .StartWith('Dext')
    .AndAlso.EndWith('Framework')
    .AndAlso.Contain('Frame');
end;

procedure TAssertionTests.TestShouldInteger;
begin
  Should(42)
    .BeGreaterThan(40)
    .AndAlso.BeLessThan(50)
    .AndAlso.BeInRange(40, 45);
end;

procedure TAssertionTests.TestShouldBoolean;
begin
  Should(True).BeTrue;
  Should(False).BeFalse;
  Should(1 = 1).BeTrue;
end;

procedure TAssertionTests.TestShouldList;
var
  Numbers: TArray<Integer>;
begin
  Numbers := [1, 2, 3, 4, 5];
  Should(Length(Numbers)).Be(5);
  Should(Numbers[2]).Be(3);
end;

procedure TAssertionTests.TestFluentChaining;
begin
  Should('Hello World')
    .NotBeEmpty
    .AndAlso.HaveLength(11)
    .AndAlso.StartWith('Hello')
    .AndAlso.EndWith('World');
end;

procedure TAssertionTests.TestDeepAssertions;
var
  Addr: TAddress;
  Person: TPerson;
begin
  Addr := TAddress.Create('New York', 10001);
  Person := TPerson.Create('John Doe', Addr);
  try
    Should(Person).HavePropertyValue('Name', 'John Doe');
    Should(Person)
      .HaveProperty('Address')
        .WhichObject
          .HavePropertyValue('City', 'New York')
          .AndAlso
          .HavePropertyValue('Zip', 10001);
  finally
    Person.Free;
  end;
end;

procedure TAssertionTests.TestSmartAssertions;
var
  User: TSmartUser;
  u: TSmartUser;
begin
  User := TSmartUser.Create;
  try
    User.FName := 'Alice';
    User.FAge := 30;
    u := Prototype.Entity<TSmartUser>;
    Should(User)
      .HaveValue(u.FName, 'Alice')
      .AndAlso
      .HaveValue(u.FAge, 30);
  finally
    User.Free;
  end;
end;

procedure TAssertionTests.TestContextInjection(Context: ITestContext);
begin
  Context.WriteLine('This test demonstrates ITestContext injection');
  Should(Context).NotBeNil;
end;

procedure TAssertionTests.TestMultipleAssertions;
begin
  Assert.Multiple(procedure
  begin
    Should(10).BeGreaterThan(5);
    Should('Dext').StartWith('D');
  end);
end;

{ TExternalData }

class function TExternalData.GetValues: TArray<TArray<TValue>>;
begin
  Result := [
    [TValue.From(1), TValue.From(2), TValue.From(3)],
    [TValue.From(10), TValue.From(20), TValue.From(30)]
  ];
end;

{ TExternalDataTests }

procedure TExternalDataTests.TestWithExternalData(A, B, Expected: Integer);
begin
  Should(A + B).Be(Expected);
end;

begin
  SetConsoleCharSet();
  try
    SafeWriteLn;
    SafeWriteLn('🧪 Dext Attribute-Based Testing Demo');
    SafeWriteLn('=====================================');
    SafeWriteLn;

    RunTests(ConfigureTests
      .Verbose
      //.UseTestInsight
      .RegisterFixtures([
        TGlobalSetup,
        TCalculatorTests,
        TStringTests,
        TAssertionTests,
        TExternalDataTests
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
