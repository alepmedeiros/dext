unit Dext.Core.SmartTypes.Combinatorial.Tests;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  Dext.Assertions,
  Dext.Testing.Attributes,
  Dext.Core.SmartTypes,
  Dext.Types.Nullable,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types;

type
  [TestFixture('SmartTypes Combinatorial Matrix')]
  TSmartTypesCombinatorialTests = class
  private
    procedure TestTypeStability<T>(const AValue: T; const AExpectStr: string);
    procedure TestArithmetic<T>(const A, B: Prop<T>; const ExpectedSum: T);
  public
    [Test]
    procedure Test_StringType_Stability;
    [Test]
    procedure Test_IntType_Stability;
    [Test]
    procedure Test_Int64Type_Stability;
    [Test]
    procedure Test_BoolType_Stability;
    [Test]
    procedure Test_FloatType_Stability;
    [Test]
    procedure Test_CurrencyType_Stability;
    [Test]
    procedure Test_DateTimeType_Stability;
    [Test]
    procedure Test_DateType_Stability;
    [Test]
    procedure Test_TimeType_Stability;

    [Test]
    procedure Test_QueryMode_Expression_Generation;
    [Test]
    procedure Test_Arithmetic_Operations;
    [Test]
    procedure Test_Nullable_Interop;
    [Test]
    procedure Test_Variant_Interop;
  end;

implementation

uses
  System.DateUtils,
  Dext.Core.ValueConverters;

{ TSmartTypesCombinatorialTests }

procedure TSmartTypesCombinatorialTests.TestTypeStability<T>(const AValue: T; const AExpectStr: string);
var
  P: Prop<T>;
  V: TValue;
begin
  P := AValue;
  
  // Implicit cast to T
  V := TValue.From<T>(T(P));
  Should(V.AsVariant).Be(TValue.From<T>(AValue).AsVariant);
  
  // Explicit cast to string
  Should(string(P)).Be(AExpectStr);
  
  // AsString method
  Should(P.AsString).Be(AExpectStr);
  
  // ToString method
  Should(P.ToString).Be(AExpectStr);

  // Runtime comparison
  Should(P = AValue).BeTrue;
  Should(P <> AValue).BeFalse;
end;

procedure TSmartTypesCombinatorialTests.TestArithmetic<T>(const A, B: Prop<T>; const ExpectedSum: T);
var
  Sum: Prop<T>;
begin
  Sum := A + B;
  Should(TValue.From<T>(Sum.Value).AsVariant).Be(TValue.From<T>(ExpectedSum).AsVariant);
  
  Sum := A + B.Value;
  Should(TValue.From<T>(Sum.Value).AsVariant).Be(TValue.From<T>(ExpectedSum).AsVariant);
end;

procedure TSmartTypesCombinatorialTests.Test_StringType_Stability;
begin
  TestTypeStability<string>('Dext Framework', 'Dext Framework');
end;

procedure TSmartTypesCombinatorialTests.Test_IntType_Stability;
begin
  TestTypeStability<Integer>(1234, '1234');
end;

procedure TSmartTypesCombinatorialTests.Test_Int64Type_Stability;
begin
  TestTypeStability<Int64>(9223372036854775807, '9223372036854775807');
end;

procedure TSmartTypesCombinatorialTests.Test_BoolType_Stability;
begin
  TestTypeStability<Boolean>(True, 'True');
  TestTypeStability<Boolean>(False, 'False');
end;

procedure TSmartTypesCombinatorialTests.Test_FloatType_Stability;
begin
  // Using Invariant to avoid decimal separator issues in tests
  var V: Double := 1234.56;
  TestTypeStability<Double>(V, TValueConverter.Convert<string>(V));
end;

procedure TSmartTypesCombinatorialTests.Test_CurrencyType_Stability;
begin
  var V: Currency := 99.99;
  TestTypeStability<Currency>(V, TValueConverter.Convert<string>(V));
end;

procedure TSmartTypesCombinatorialTests.Test_DateTimeType_Stability;
begin
  var D := EncodeDateTime(2025, 12, 19, 14, 30, 0, 0);
  TestTypeStability<TDateTime>(D, TValueConverter.Convert<string>(D));
end;

procedure TSmartTypesCombinatorialTests.Test_DateType_Stability;
begin
  var D := EncodeDate(2025, 12, 19);
  TestTypeStability<TDate>(D, TValueConverter.Convert<string>(D));
end;

procedure TSmartTypesCombinatorialTests.Test_TimeType_Stability;
begin
  var T := EncodeTime(14, 30, 0, 0);
  TestTypeStability<TTime>(T, TValueConverter.Convert<string>(T));
end;

procedure TSmartTypesCombinatorialTests.Test_QueryMode_Expression_Generation;
var
  P: Prop<Integer>;
begin
  // Create a pseudo-query mode prop
  P := Default(Prop<Integer>);
  TValue.From<IPropInfo>(TPropInfo.Create('Age')).ExtractRawData(@P.FInfo); // Injected via RTTI/Hack for testing
  
  Should(P.IsQueryMode).BeTrue;
  Should(P.Name).Be('Age');
  
  var Expr := P > 18;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression.Kind).Be(ekBinary);
  Should(TBinaryExpression(Expr.Expression).Operator).Be(boGreaterThan);
end;

procedure TSmartTypesCombinatorialTests.Test_Arithmetic_Operations;
begin
  TestArithmetic<Integer>(10, 20, 30);
  TestArithmetic<Double>(10.5, 4.5, 15.0);
  TestArithmetic<Int64>(1000, 2000, 3000);
end;

procedure TSmartTypesCombinatorialTests.Test_Nullable_Interop;
var
  P: Prop<Integer>;
  N: Nullable<Integer>;
begin
  P := 42;
  N := P;
  Should(N.HasValue).BeTrue;
  Should(N.Value).Be(42);
  
  N.Clear;
  P := N;
  Should(P.Value).Be(0);
end;

procedure TSmartTypesCombinatorialTests.Test_Variant_Interop;
var
  P: Prop<string>;
  V: Variant;
begin
  P := 'Vibe';
  V := P;
  Should(string(V)).Be('Vibe');
  
  V := 'NewVibe';
  P := V;
  Should(P.Value).Be('NewVibe');
end;

initialization
end.
