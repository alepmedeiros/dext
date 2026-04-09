unit Dext.Entity.Drivers.FireDAC.Manager;

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  System.SyncObjs,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Comp.Client,
  FireDAC.DApt,
  FireDAC.Comp.UI,
  FireDAC.ConsoleUI.Wait,
  Dext.Entity.Drivers.FireDAC.Links; // Centralized driver linking

type
  TComponentHelper = class helper for TComponent
  public
    procedure SetUniqueName;
  end;

  TFireDACOptimization = (
    optDisableMacros,        // Sets MacroCreate/MacroExpand = False (Performance, SQL Injection safety)
    optDisableEscapes,       // Sets EscapeExpand = False (Performance, raw SQL fidelity)
    optDirectExecute         // Sets DirectExecute = True (Skip prepare step for simple queries)
  );
  
  TFireDACOptimizations = set of TFireDACOptimization;

type
  /// <summary>
  ///   Manages FireDAC Connection Definitions and Pooling globally
  ///   without requiring external INI files.
  /// </summary>
  TDextFireDACManager = class
  private
    class var FInstance: TDextFireDACManager;
    class var FCriticalSection: TCriticalSection;
    
    FManager: TFDManager;
    FDefinitions: IDictionary<string, string>; // Hash -> DefName
    constructor Create;
  public
    class constructor Create;
    class destructor Destroy;
    destructor Destroy; override;
    
    /// <summary>
    ///   Access the singleton instance.
    /// </summary>
    class function Instance: TDextFireDACManager;

    /// <summary>
    ///   Registers a connection definition with pooling enabled.
    ///   Returns the Definition Name to be used in TFDConnection.
    /// </summary>
    function RegisterConnectionDef(const ADriverName: string; 
      const AParams: TStrings; 
      APoolMax: Integer = 50): string;

    /// <summary>
    ///   Registers a connection definition from an INI-style string (key=value lines).
    /// </summary>
    function RegisterConnectionDefFromString(const ADefName, AConfig: string): string;
      
    /// <summary>
    ///   Ensures the FDManager is active.
    /// </summary>
    procedure EnsureActive;

    /// <summary>
    ///   Global finalization to drop all connections and close manager.
    /// </summary>
    class procedure Finalize;

    /// <summary>
    ///   Apply common resource options for specific databases (e.g. PostgreSQL)
    /// </summary>
    procedure ApplyResourceOptions(AConnection: TFDConnection; AOptimizations: TFireDACOptimizations);
  end;

implementation

uses
  Dext.Entity.Dialects;

{ TComponentHelper }

procedure TComponentHelper.SetUniqueName;
begin
  if Self.Name = '' then
    Self.Name := Self.ClassName + '_' + IntToHex(IntPtr(Self), 16);
end;

{ TDextFireDACManager }

class constructor TDextFireDACManager.Create;
begin
  FCriticalSection := TCriticalSection.Create;
end;

class destructor TDextFireDACManager.Destroy;
begin
  Finalize;
  FCriticalSection.Free;
end;

class procedure TDextFireDACManager.Finalize;
begin
  if FInstance <> nil then
  begin
    if FInstance.FManager <> nil then
    begin
      FInstance.FManager.Close;
    end;
    FreeAndNil(FInstance);
  end;
end;

constructor TDextFireDACManager.Create;
begin
  FManager := TFDManager(FireDAC.Comp.Client.FDManager);
  FManager.SilentMode := True;
  FManager.Active := True;
  FDefinitions := TCollections.CreateDictionary<string, string>;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TDextFireDACManager.Destroy;
begin
  FCriticalSection.Free;
  FDefinitions := nil;
  inherited;
end;

procedure TDextFireDACManager.EnsureActive;
begin
  FCriticalSection.Enter;
  try
    if not FManager.Active then
      FManager.Open;
  finally
    FCriticalSection.Leave;
  end;
end;

class function TDextFireDACManager.Instance: TDextFireDACManager;
begin
  if FInstance = nil then
  begin
    // Double-checked locking using a global critical section would be ideal, 
    // but here we use the existing pattern or instance-level lock if already created.
    FInstance := TDextFireDACManager.Create;
  end;
  Result := FInstance;
end;

function TDextFireDACManager.RegisterConnectionDef(const ADriverName: string;
  const AParams: TStrings; APoolMax: Integer): string;
var
  HashKey: string;
begin
    // Create a unique key based on params
    var SortedList := TStringList.Create;
    try
      SortedList.Sorted := True;
      SortedList.AddStrings(AParams);
      HashKey := ADriverName + ';' + SortedList.DelimitedText;
    finally
      SortedList.Free;
    end;
    
    FCriticalSection.Enter;
    try
      // Check cache first (thread-safe dictionary access)
      if FDefinitions.TryGetValue(HashKey, Result) then
        Exit;

      Result := 'DextPool_' + IntToHex(HashKey.GetHashCode, 8);
          
      if not FManager.IsConnectionDef(Result) then
      begin
        FManager.AddConnectionDef(Result, ADriverName, AParams);
        
        var Def := FManager.ConnectionDefs.FindConnectionDef(Result);
        if Def <> nil then
        begin
          Def.Params.Pooled := True;
          Def.Params.PoolMaximumItems := APoolMax;
          
          // Critical: Ensure wait cursor is none and pooling stability is high
          Def.Params.MonitorBy := mbNone;
        end;
      end;
      
      FDefinitions.Add(HashKey, Result);
      
      if not FManager.Active then
        FManager.Open;
    finally
      FCriticalSection.Leave;
    end;
end;

procedure TDextFireDACManager.ApplyResourceOptions(AConnection: TFDConnection; AOptimizations: TFireDACOptimizations);
begin
  var Dialect := TDialectFactory.DetectDialect(AConnection.DriverName);
  
  // Apply optimizations if dialect is PostgreSQL (or others if added later)
  if Dialect = ddPostgreSQL then
  begin
    if optDisableMacros in AOptimizations then
    begin
      AConnection.ResourceOptions.MacroCreate := False;
      AConnection.ResourceOptions.MacroExpand := False;
    end;
    
    if optDisableEscapes in AOptimizations then
      AConnection.ResourceOptions.EscapeExpand := False;
      
    if optDirectExecute in AOptimizations then
      AConnection.ResourceOptions.DirectExecute := True;
  end;
end;

function TDextFireDACManager.RegisterConnectionDefFromString(const ADefName,
  AConfig: string): string;
var
  SL: TStringList;
  DriverID: string;
begin
  FCriticalSection.Enter;
  try
    SL := TStringList.Create;
    try
      SL.Text := AConfig;
      DriverID := SL.Values['DriverID'];
      
      if not FManager.IsConnectionDef(ADefName) then
      begin
        FManager.AddConnectionDef(ADefName, DriverID, SL);
      end;
      
      EnsureActive;
      Result := ADefName;
    finally
      SL.Free;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

end.
