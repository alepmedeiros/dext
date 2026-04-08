unit Dext.Collections.Concurrent;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Dext.Collections.Comparers,
  Dext.Collections.Dict;

type
  IDextConcurrentDictionary<K, V> = interface
    function GetOrAdd(const Key: K; const ValueFactory: TFunc<K, V>): V;
    function TryAdd(const Key: K; const Value: V): Boolean;
    function TryGetValue(const Key: K; out Value: V): Boolean;
    function TryRemove(const Key: K; out Value: V): Boolean;
    function TryUpdate(const Key: K; const NewValue, ComparisonValue: V): Boolean;
    procedure Clear;
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;

  TConcurrentDictionary<K, V> = class(TInterfacedObject, IDextConcurrentDictionary<K, V>)
  private
    const DEFAULT_CONCURRENCY_LEVEL = 32;
  type
    TStripe = record
      Lock: TSpinLock;
      Items: IDictionary<K, V>;
    end;
  private
    FStripes: TArray<TStripe>;
    FConcurrencyLevel: Integer;
    FComparer: IEqualityComparer<K>;
    function GetStripeIndex(const Key: K): Integer; inline;
  public
    constructor Create(ConcurrencyLevel: Integer = DEFAULT_CONCURRENCY_LEVEL);
    
    function GetOrAdd(const Key: K; const ValueFactory: TFunc<K, V>): V;
    function TryAdd(const Key: K; const Value: V): Boolean;
    function TryGetValue(const Key: K; out Value: V): Boolean;
    function TryRemove(const Key: K; out Value: V): Boolean;
    function TryUpdate(const Key: K; const NewValue, ComparisonValue: V): Boolean;
    procedure Clear;
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;

implementation

{ TConcurrentDictionary<K, V> }

constructor TConcurrentDictionary<K, V>.Create(ConcurrencyLevel: Integer);
var
  I: Integer;
begin
  inherited Create;
  if ConcurrencyLevel < 1 then
    ConcurrencyLevel := DEFAULT_CONCURRENCY_LEVEL;
  FConcurrencyLevel := ConcurrencyLevel;
  FComparer := TEqualityComparer<K>.Default;
  
  SetLength(FStripes, FConcurrencyLevel);
  for I := 0 to FConcurrencyLevel - 1 do
  begin
    FStripes[I].Lock := TSpinLock.Create(False);
    FStripes[I].Items := TDictionary<K, V>.Create;
  end;
end;

function TConcurrentDictionary<K, V>.GetStripeIndex(const Key: K): Integer;
var
  HashCode: Integer;
begin
  HashCode := FComparer.GetHashCode(Key);
  Result := Abs(HashCode) mod FConcurrencyLevel;
end;

function TConcurrentDictionary<K, V>.GetCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FConcurrencyLevel - 1 do
  begin
    FStripes[I].Lock.Enter;
    try
      Inc(Result, FStripes[I].Items.Count);
    finally
      FStripes[I].Lock.Exit;
    end;
  end;
end;

procedure TConcurrentDictionary<K, V>.Clear;
var
  I: Integer;
begin
  for I := 0 to FConcurrencyLevel - 1 do
  begin
    FStripes[I].Lock.Enter;
    try
      // The current TDictionary does not have a Clear method in its interface yet.
      // We can just re-create it or drop items by iterating (re-creating is safer/faster for now)
      FStripes[I].Items := TDictionary<K, V>.Create;
    finally
      FStripes[I].Lock.Exit;
    end;
  end;
end;

function TConcurrentDictionary<K, V>.GetOrAdd(const Key: K; const ValueFactory: TFunc<K, V>): V;
var
  StripeIdx: Integer;
begin
  StripeIdx := GetStripeIndex(Key);
  
  // Fast read
  FStripes[StripeIdx].Lock.Enter;
  try
    if FStripes[StripeIdx].Items.TryGetValue(Key, Result) then
      Exit;
  finally
    FStripes[StripeIdx].Lock.Exit;
  end;
  
  // Create value outside to minimize lock time
  Result := ValueFactory(Key);
  
  FStripes[StripeIdx].Lock.Enter;
  try
    // Check again inside lock
    if not FStripes[StripeIdx].Items.TryGetValue(Key, Result) then
    begin
      // Result here initially holds the factory value. If TryGetValue fails, it retains the factory value.
      Result := ValueFactory(Key);
      FStripes[StripeIdx].Items.AddOrSetValue(Key, Result);
    end;
  finally
    FStripes[StripeIdx].Lock.Exit;
  end;
end;

function TConcurrentDictionary<K, V>.TryAdd(const Key: K; const Value: V): Boolean;
var
  StripeIdx: Integer;
  Existing: V;
begin
  StripeIdx := GetStripeIndex(Key);
  FStripes[StripeIdx].Lock.Enter;
  try
    if FStripes[StripeIdx].Items.TryGetValue(Key, Existing) then
      Result := False
    else
    begin
      FStripes[StripeIdx].Items.AddOrSetValue(Key, Value);
      Result := True;
    end;
  finally
    FStripes[StripeIdx].Lock.Exit;
  end;
end;

function TConcurrentDictionary<K, V>.TryGetValue(const Key: K; out Value: V): Boolean;
var
  StripeIdx: Integer;
begin
  StripeIdx := GetStripeIndex(Key);
  FStripes[StripeIdx].Lock.Enter;
  try
    Result := FStripes[StripeIdx].Items.TryGetValue(Key, Value);
  finally
    FStripes[StripeIdx].Lock.Exit;
  end;
end;

function TConcurrentDictionary<K, V>.TryRemove(const Key: K; out Value: V): Boolean;
var
  StripeIdx: Integer;
begin
  StripeIdx := GetStripeIndex(Key);
  FStripes[StripeIdx].Lock.Enter;
  try
    if FStripes[StripeIdx].Items.TryGetValue(Key, Value) then
    begin
      Result := FStripes[StripeIdx].Items.Remove(Key);
    end
    else
      Result := False;
  finally
    FStripes[StripeIdx].Lock.Exit;
  end;
end;

function TConcurrentDictionary<K, V>.TryUpdate(const Key: K; const NewValue, ComparisonValue: V): Boolean;
var
  StripeIdx: Integer;
  CurrentValue: V;
  ValComparer: IEqualityComparer<V>;
begin
  StripeIdx := GetStripeIndex(Key);
  ValComparer := TEqualityComparer<V>.Default;
  
  FStripes[StripeIdx].Lock.Enter;
  try
    if FStripes[StripeIdx].Items.TryGetValue(Key, CurrentValue) then
    begin
      if ValComparer.Equals(CurrentValue, ComparisonValue) then
      begin
        FStripes[StripeIdx].Items.AddOrSetValue(Key, NewValue);
        Result := True;
      end
      else
        Result := False;
    end
    else
      Result := False;
  finally
    FStripes[StripeIdx].Lock.Exit;
  end;
end;

end.
