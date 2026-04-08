unit Dext.Collections.Channels;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.TypInfo,
  Dext.Collections.Memory;

type
  IChannel<T> = interface
    function TryWrite(const Value: T): Boolean;
    function TryRead(out Value: T): Boolean;
    procedure Write(const Value: T); // Blocks if bounded and full
    function Read: T;                // Blocks until an item is available
    procedure Close;
    function IsClosed: Boolean;
  end;

  TChannelQueue<T> = class
  private
    FData: Pointer;
    FHead, FTail, FCount, FCapacity: Integer;
    procedure EnsureCapacity(NewCapacity: Integer);
  public
    constructor Create(InitialCapacity: Integer = 16);
    destructor Destroy; override;
    
    procedure Enqueue(const Value: T);
    function Dequeue(out Value: T): Boolean;
    property Count: Integer read FCount;
    property Capacity: Integer read FCapacity;
  end;

  TBoundedChannel<T> = class(TInterfacedObject, IChannel<T>)
  private
    FQueue: TChannelQueue<T>;
    FMaxCapacity: Integer;
    FClosed: Boolean;
    FLockObj: TObject;
  public
    constructor Create(MaxCapacity: Integer);
    destructor Destroy; override;
    
    function TryWrite(const Value: T): Boolean;
    function TryRead(out Value: T): Boolean;
    procedure Write(const Value: T);
    function Read: T;
    procedure Close;
    function IsClosed: Boolean;
  end;

  TUnboundedChannel<T> = class(TInterfacedObject, IChannel<T>)
  private
    FQueue: TChannelQueue<T>;
    FClosed: Boolean;
    FLockObj: TObject;
  public
    constructor Create;
    destructor Destroy; override;
    
    function TryWrite(const Value: T): Boolean;
    function TryRead(out Value: T): Boolean;
    procedure Write(const Value: T);
    function Read: T;
    procedure Close;
    function IsClosed: Boolean;
  end;

  TChannel<T> = class
  public
    class function CreateBounded(Capacity: Integer): IChannel<T>;
    class function CreateUnbounded: IChannel<T>;
  end;

implementation

{ TChannelQueue<T> }

constructor TChannelQueue<T>.Create(InitialCapacity: Integer);
begin
  inherited Create;
  if InitialCapacity < 4 then InitialCapacity := 4;
  FCapacity := InitialCapacity;
  FCount := 0;
  FHead := 0;
  FTail := 0;
  GetMem(FData, FCapacity * SizeOf(T));
  FillChar(FData^, FCapacity * SizeOf(T), 0);
end;

destructor TChannelQueue<T>.Destroy;
var
  I, Idx: Integer;
begin
  if FCount > 0 then
  begin
    for I := 0 to FCount - 1 do
    begin
      Idx := (FHead + I) mod FCapacity;
      RawFinalizeElement(PByte(FData) + (Idx * SizeOf(T)), SizeOf(T), System.TypeInfo(T));
    end;
  end;
  FreeMem(FData);
  inherited;
end;

procedure TChannelQueue<T>.EnsureCapacity(NewCapacity: Integer);
var
  NewData: Pointer;
  I: Integer;
begin
  if NewCapacity <= FCapacity then Exit;
  
  GetMem(NewData, NewCapacity * SizeOf(T));
  FillChar(NewData^, NewCapacity * SizeOf(T), 0);
  
  // Realign elements to the new buffer starting from index 0
  for I := 0 to FCount - 1 do
  begin
    RawMove(
      PByte(NewData) + (I * SizeOf(T)), 
      PByte(FData) + (((FHead + I) mod FCapacity) * SizeOf(T)), 
      1, SizeOf(T), System.TypeInfo(T)
    );
  end;
  
  FreeMem(FData);
  FData := NewData;
  FCapacity := NewCapacity;
  FHead := 0;
  FTail := FCount;
end;

procedure TChannelQueue<T>.Enqueue(const Value: T);
begin
  if FCount = FCapacity then
    EnsureCapacity(FCapacity * 2);
    
  RawCopyElement(PByte(FData) + (FTail * SizeOf(T)), @Value, SizeOf(T), System.TypeInfo(T));
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);
end;

function TChannelQueue<T>.Dequeue(out Value: T): Boolean;
var
  TargetPtr: Pointer;
begin
  if FCount = 0 then Exit(False);
  
  TargetPtr := PByte(FData) + (FHead * SizeOf(T));
  RawCopyElement(@Value, TargetPtr, SizeOf(T), System.TypeInfo(T));
  RawFinalizeElement(TargetPtr, SizeOf(T), System.TypeInfo(T));
  
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  Result := True;
end;


{ TBoundedChannel<T> }

constructor TBoundedChannel<T>.Create(MaxCapacity: Integer);
begin
  inherited Create;
  FQueue := TChannelQueue<T>.Create(MaxCapacity);
  FMaxCapacity := MaxCapacity;
  FLockObj := TObject.Create;
end;

destructor TBoundedChannel<T>.Destroy;
begin
  Close;
  FQueue.Free;
  FLockObj.Free;
  inherited;
end;

procedure TBoundedChannel<T>.Close;
begin
  System.TMonitor.Enter(FLockObj);
  try
    FClosed := True;
    System.TMonitor.PulseAll(FLockObj);
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TBoundedChannel<T>.IsClosed: Boolean;
begin
  System.TMonitor.Enter(FLockObj);
  try
    Result := FClosed;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TBoundedChannel<T>.TryRead(out Value: T): Boolean;
begin
  System.TMonitor.Enter(FLockObj);
  try
    if FQueue.Count > 0 then
    begin
      FQueue.Dequeue(Value);
      System.TMonitor.PulseAll(FLockObj);
      Exit(True);
    end;
    Result := False;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TBoundedChannel<T>.TryWrite(const Value: T): Boolean;
begin
  System.TMonitor.Enter(FLockObj);
  try
    if FClosed then Exit(False);
    if FQueue.Count < FMaxCapacity then
    begin
      FQueue.Enqueue(Value);
      System.TMonitor.PulseAll(FLockObj);
      Exit(True);
    end;
    Result := False;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TBoundedChannel<T>.Read: T;
begin
  System.TMonitor.Enter(FLockObj);
  try
    while (FQueue.Count = 0) and not FClosed do
      System.TMonitor.Wait(FLockObj, INFINITE);

    if FQueue.Count > 0 then
    begin
      FQueue.Dequeue(Result);
      System.TMonitor.PulseAll(FLockObj);
      Exit;
    end;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
  raise Exception.Create('Channel is closed or empty.');
end;

procedure TBoundedChannel<T>.Write(const Value: T);
begin
  System.TMonitor.Enter(FLockObj);
  try
    if FClosed then raise Exception.Create('Channel is closed.');
    while (FQueue.Count >= FMaxCapacity) and not FClosed do
      System.TMonitor.Wait(FLockObj, INFINITE);

    if FClosed then raise Exception.Create('Channel is closed.');
    FQueue.Enqueue(Value);
    System.TMonitor.PulseAll(FLockObj);
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;


{ TUnboundedChannel<T> }

constructor TUnboundedChannel<T>.Create;
begin
  inherited Create;
  FQueue := TChannelQueue<T>.Create;
  FLockObj := TObject.Create;
end;

destructor TUnboundedChannel<T>.Destroy;
begin
  Close;
  FQueue.Free;
  FLockObj.Free;
  inherited;
end;

procedure TUnboundedChannel<T>.Close;
begin
  System.TMonitor.Enter(FLockObj);
  try
    FClosed := True;
    System.TMonitor.PulseAll(FLockObj);
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TUnboundedChannel<T>.IsClosed: Boolean;
begin
  System.TMonitor.Enter(FLockObj);
  try
    Result := FClosed;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TUnboundedChannel<T>.TryRead(out Value: T): Boolean;
begin
  System.TMonitor.Enter(FLockObj);
  try
    if FQueue.Count > 0 then
    begin
      FQueue.Dequeue(Value);
      Exit(True);
    end;
    Result := False;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TUnboundedChannel<T>.TryWrite(const Value: T): Boolean;
begin
  System.TMonitor.Enter(FLockObj);
  try
    if FClosed then Exit(False);
    FQueue.Enqueue(Value);
    System.TMonitor.PulseAll(FLockObj);
    Result := True;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;

function TUnboundedChannel<T>.Read: T;
begin
  System.TMonitor.Enter(FLockObj);
  try
    while (FQueue.Count = 0) and not FClosed do
      System.TMonitor.Wait(FLockObj, INFINITE);

    if FQueue.Count > 0 then
    begin
      FQueue.Dequeue(Result);
      Exit;
    end;
  finally
    System.TMonitor.Exit(FLockObj);
  end;
  raise Exception.Create('Channel is closed or empty.');
end;

procedure TUnboundedChannel<T>.Write(const Value: T);
begin
  System.TMonitor.Enter(FLockObj);
  try
    if FClosed then raise Exception.Create('Channel is closed.');
    FQueue.Enqueue(Value);
    System.TMonitor.PulseAll(FLockObj);
  finally
    System.TMonitor.Exit(FLockObj);
  end;
end;


{ TChannel<T> }

class function TChannel<T>.CreateBounded(Capacity: Integer): IChannel<T>;
begin
  Result := TBoundedChannel<T>.Create(Capacity);
end;

class function TChannel<T>.CreateUnbounded: IChannel<T>;
begin
  Result := TUnboundedChannel<T>.Create;
end;

end.
