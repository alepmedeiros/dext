unit Dext.Entity.SmartTypes.Tests;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Rtti,
  Dext.Assertions,
  Dext.Testing.Attributes,
  Dext.Core.SmartTypes,
  Dext.Types.Nullable;

type
  [TestFixture('SmartTypes (Prop<T>) Tests')]
  TSmartTypesTests = class
  public
    [Test]
    [Description('Verify explicit casts from Prop<T> to common types')]
    procedure TestExplicitCasts;

    [Test]
    [Description('Verify fluent .AsXXXX methods for conversion')]
    procedure TestAsMethods;

    [Test]
    [Description('Verify generic .As<T> conversion')]
    procedure TestGenericAs;

    [Test]
    [Description('Verify assertions working directly with Prop<T>')]
    procedure TestSmartAssertions;

    [Test]
    [Description('Verify assertions working with Nullable<T>')]
    procedure TestNullableAssertions;
  end;

  [TestFixture('SmartTypes Combinatorial Matrix')]
  TSmartTypesMatrixTests = class
  private
    procedure CheckType<T>(const Value: T; const ExpectedStr: string;
      TestConversionBack: Boolean = True);
  public
    [Test]
    procedure Test_All_Fundament_Types_Consistency;
  end;

implementation

{ TSmartTypesMatrixTests }

procedure TSmartTypesMatrixTests.CheckType<T>(const Value: T; const
  ExpectedStr: string; TestConversionBack: Boolean = True);
var
  P: Prop<T>;
begin
  P := Value;
  Should(P.AsString).Be(ExpectedStr);
  Should(Nullable<T>(P).HasValue).BeTrue;

  if not TestConversionBack then Exit;

  var expect := TValue.From<T>(T(P)).AsVariant;
  var actual := TValue.From<T>(Value).AsVariant;
  // Test conversion back to T using Variant as bridge for generics
  Should(expect).Be(actual);
end;

procedure TSmartTypesMatrixTests.Test_All_Fundament_Types_Consistency;
var
  G: TGuid;
begin
  // String
  CheckType<string>('Dext', 'Dext');
  
  // Integer
  CheckType<Integer>(123, '123');
  
  // Int64
  CheckType<Int64>(9223372036854775807, '9223372036854775807');
  
  // Double
  CheckType<Double>(123.45, '123.45');
  
  // Boolean
  CheckType<Boolean>(True, 'True');
  CheckType<Boolean>(False, 'False');
  
  // DateTime
  var D := EncodeDateTime(2025, 12, 19, 14, 30, 0, 0);
  CheckType<TDateTime>(D, DateTimeToStr(D));
  
  // Currency
  CheckType<Currency>(1234.56, '1234.56');
  
  // Guid
  G := TGuid.Create('{D6A5D5A1-949B-4B7C-9F8A-E7C1D1B1B1B1}');
  CheckType<TGuid>(G, GUIDToString(G), False);
end;

{ TSmartTypesTests }

procedure TSmartTypesTests.TestExplicitCasts;
var
  IntProp: Prop<Integer>;
  StrProp: Prop<string>;
  NumStrProp: Prop<string>;
  BoolProp: Prop<Boolean>;
begin
  IntProp := 10;
  Should(Integer(IntProp)).Be(10);
  Should(string(IntProp)).Be('10');

  StrProp := 'Dext';
  Should(string(StrProp)).Be('Dext');
  
  NumStrProp := '123';
  Should(Integer(NumStrProp)).Be(123);
  
  BoolProp := True;
  Should(Boolean(BoolProp)).BeTrue;
  Should(string(BoolProp)).BeEquivalentTo('True');
end;

procedure TSmartTypesTests.TestAsMethods;
var
  Age: Prop<Integer>;
  Price: Prop<Double>;
begin
  Age := 25;
  Should(Age.AsInteger).Be(25);
  Should(Age.AsString).Be('25');
  
  Price := 1500.50;
  Should(Price.AsDouble).Be(1500.50);
  Should(Price.AsString).StartWith('1500');
end;

procedure TSmartTypesTests.TestGenericAs;
var
  Value: Prop<Integer>;
begin
  Value := 100;
  Should(Value.AsType<Int64>()).Be(100);
end;

procedure TSmartTypesTests.TestSmartAssertions;
var
  S: StringType;
  I: IntType;
begin
  S := 'Framework';
  Should(S).StartWith('Frame');
  Should(S).NotBeEmpty;
  
  I := 100;
  Should(I).BeGreaterThan(50);
  Should(I).Be(100);
end;

procedure TSmartTypesTests.TestNullableAssertions;
var
  N: Nullable<Integer>;
  D: Nullable<TDateTime>;
begin
  N := 42;
  Should(N).Be(42);
  
  D := Now;
  ShouldDate(D).BeToday;
  
  // Test failure case (Manual check if needed, but here we just verify success)
  N.Clear;
  // Should(N).Be(0); // This would call Assert.Fail as expected
end;

initialization
  // Fixtures are registered in the main runner
end.
