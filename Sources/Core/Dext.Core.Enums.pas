unit Dext.Core.Enums;

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  System.Types;

type
  /// <summary>
  ///   Utilitário para manipulação de tipos enumerados no estilo Dext.
  /// </summary>
  EnumValue = class
  public
    class function AsInteger<T>(const AValue: T): Integer; static; inline;
    class function AsString<T>(const AValue: T): string; static;
    class function IsValid<T>(const AValue: Integer): Boolean; static;
    class function TryParse<T>(const AValue: string; out AEnum: T): Boolean; overload; static;
    class function TryParse<T>(const AValue: Integer; out AEnum: T): Boolean; overload; static;
    class function GetNames<T>: TArray<string>; static;
    class function GetValues<T>: TArray<T>; static;
  end;

implementation

{ TEnum }

class function EnumValue.AsInteger<T>(const AValue: T): Integer;
begin
  Result := TValue.From<T>(AValue).AsOrdinal;
end;

class function EnumValue.AsString<T>(const AValue: T): string;
begin
  Result := GetEnumName(TypeInfo(T), AsInteger<T>(AValue));
end;

class function EnumValue.GetNames<T>: TArray<string>;
var
  Data: PTypeData;
  I: Integer;
begin
  Data := GetTypeData(TypeInfo(T));
  SetLength(Result, Data.MaxValue - Data.MinValue + 1);
  for I := Data.MinValue to Data.MaxValue do
    Result[I - Data.MinValue] := GetEnumName(TypeInfo(T), I);
end;

class function EnumValue.GetValues<T>: TArray<T>;
var
  Data: PTypeData;
  I: Integer;
begin
  Data := GetTypeData(TypeInfo(T));
  SetLength(Result, Data.MaxValue - Data.MinValue + 1);
  for I := Data.MinValue to Data.MaxValue do
  begin
    if not TryParse<T>(I, Result[I - Data.MinValue]) then
       FillChar(Result[I - Data.MinValue], SizeOf(T), 0);
  end;
end;

class function EnumValue.IsValid<T>(const AValue: Integer): Boolean;
var
  Data: PTypeData;
begin
  Data := GetTypeData(TypeInfo(T));
  Result := (AValue >= Data.MinValue) and (AValue <= Data.MaxValue);
end;

class function EnumValue.TryParse<T>(const AValue: string; out AEnum: T): Boolean;
var
  IntValue: Integer;
begin
  IntValue := GetEnumValue(TypeInfo(T), AValue);
  Result := TryParse<T>(IntValue, AEnum);
end;

class function EnumValue.TryParse<T>(const AValue: Integer; out AEnum: T): Boolean;
begin
  Result := IsValid<T>(AValue);
  if Result then
  begin
    // Enums can be 1, 2 or 4 bytes. Integer is always 4.
    // Move is the most reliable way to perform this ordinal conversion without EInvalidCast.
    FillChar(AEnum, SizeOf(T), 0);
    Move(AValue, AEnum, SizeOf(T));
  end;
end;

end.
