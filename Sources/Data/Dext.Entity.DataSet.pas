unit Dext.Entity.DataSet;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Rtti,
  System.TypInfo,
  System.Math,
  Data.DB,
  Dext.Utils,
  Dext.Collections,
  Dext.Collections.Vector,
  Dext.Collections.Dict,
  Dext.Core.Span,
  Dext.Entity.Mapping,
  Dext.Json.Utf8;

type
  /// <summary>
  ///   Data Structure of a Record Buffer for TEntityDataSet.
  ///   Stores fully updated bytes and modification trackers.
  /// </summary>
  PEntityRecordHeader = ^TEntityRecordHeader;
  TEntityRecordHeader = record
    BookmarkFlag: TBookmarkFlag;
    BookmarkIndex: Integer;
    RowState: TDataSetState;
    DirtyMask: UInt64; // Mask indicating which fields were modified in the Grid
  end;

  /// <summary>
  ///   Custom TDataSet for high-performance reading and writing to direct objects/lists.
  /// </summary>
  TEntityDataSet = class(TDataSet)
  private
    FEntityMap: TEntityMap;
    FEntityClass: TClass;
    
    // Virtual Buffers (Offsets Index)
    // Physical Objects Reference
    FItems: IList<TObject>;            // Real reference to the object list
    FOwnsItems: Boolean;               // Whether the dataset owns the list and should clear it
    FVirtualIndex: TVector<Integer>;   // Ordered/filtered view over FItems (contains indices to FItems)
    
    FRecordSize: Integer;
    FHeaderSize: Integer;
    
    // Internal Settings
    FReadOnly: Boolean;
    FIncludeShadowProperties: Boolean;
    FIndexFieldNames: string;
    FCurrentRec: Integer; // Dataset native cursor control
    FIsCursorOpen: Boolean;
    FInsertObj: TObject; // Temporary object for uncommitted dsInsert
    FIsAppending: Boolean;
    FPositionBeforeAction: Integer;
    
    procedure SetItems(const Value: IList<TObject>);
    procedure SetIndexFieldNames(const Value: string);
    procedure ApplyFilterAndSort; overload;
    procedure ApplyFilterAndSort(AFiltered: Boolean); overload;
    function CompareObjectsInternal(A, B: TObject; const APropNames: TArray<string>; RttiType: TRttiType): Integer;
    procedure BuildFieldDefs;
    
    /// <summary>
    ///   Core internal method that reads a field value from an entity object.
    ///   Used by both GetFieldData overloads.
    ///   Returns the value as Variant (Unassigned if not found).
    /// </summary>
    function ReadFieldValue(Field: TField; out Value: Variant): Boolean;
  protected
    // TDataSet overrides for filtering and sorting
    procedure InternalHandleException; override;
    function IsCursorOpen: Boolean; override;
    function GetRecord(Buffer: TRecordBuffer; GetMode: TGetMode; DoSearch: Boolean): TGetResult; override;
    procedure SetFiltered(Value: Boolean); override;
    procedure SetFilterText(const Value: string); override;
    
    // Mandatory TDataSet overrides
    procedure InternalOpen; override;
    procedure InternalClose; override;
    procedure InternalInitFieldDefs; override;

    // Buffer Alocations
    function AllocRecordBuffer: TRecordBuffer; override;
    procedure FreeRecordBuffer(var Buffer: TRecordBuffer); override;
    procedure InternalInitRecord(Buffer: TRecordBuffer); override;
    
    // Bookmark and Navigation
    procedure GetBookmarkData(Buffer: TRecordBuffer; Data: Pointer); override;
    procedure SetBookmarkData(Buffer: TRecordBuffer; Data: Pointer); override;
    function GetBookmarkFlag(Buffer: TRecordBuffer): TBookmarkFlag; override;
    procedure SetBookmarkFlag(Buffer: TRecordBuffer; Value: TBookmarkFlag); override;
    procedure InternalSetToRecord(Buffer: TRecordBuffer); override;
    procedure InternalGotoBookmark(Bookmark: TBookmark); override;
    
    function GetRecordSize: Word; override;
    function GetRecordCount: Integer; override;
    function GetRecNo: Integer; override;
    procedure SetRecNo(Value: Integer); override;

    // DML and Editing
    procedure SetFieldData(Field: TField; Buffer: TValueBuffer); override;
    procedure InternalAddRecord(Buffer: TRecordBuffer; Append: Boolean); override;
    procedure InternalDelete; override;
    procedure InternalPost; override;
    procedure InternalCancel; override;
    procedure InternalEdit; override;
    procedure InternalInsert; override;
    procedure InternalFirst; override;
    procedure InternalLast; override;
    procedure DoBeforeScroll; override;
    procedure DoAfterScroll; override;
    procedure DoBeforeInsert; override;
    procedure DoBeforeDelete; override;

  private
    function CreateNewEntity: TObject;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   GetFieldData override for modern Delphi (XE4+) with TValueBuffer (TArray of Byte).
    ///   This is the override that TField.GetData actually calls in modern Delphi.
    /// </summary>
    function GetFieldData(Field: TField; var Buffer: TValueBuffer): Boolean; override;
    function Locate(const KeyFields: string; const KeyValues: Variant; Options: TLocateOptions = []): Boolean; override;
    function BookmarkValid(Bookmark: TBookmark): Boolean; override;
    /// <summary>
    ///  Object data loading
    /// </summary>
    procedure Load(const AItems: IList<TObject>; AClass: TClass; AOwns: Boolean = False); overload;

    procedure Load(const AItems: TArray<TObject>; AClass: TClass); overload;
    
    /// <summary>
    ///  UTF-8 JSON data loading (Zero-Alloc Pipeline)
    /// </summary>
    procedure LoadFromUtf8Json(const ASpan: TByteSpan; AClass: TClass);

    property Items: IList<TObject> read FItems write SetItems;
    property ReadOnly: Boolean read FReadOnly write FReadOnly default False;
    property IncludeShadowProperties: Boolean read FIncludeShadowProperties write FIncludeShadowProperties default False;
    property IndexFieldNames: string read FIndexFieldNames write SetIndexFieldNames;
  end;

implementation

uses
  System.StrUtils,
  Dext.Collections.Comparers,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Parser,
  Dext.Specifications.Evaluator;
  
type
  TRttiHelper = class
  public
    class function GetFieldPtr(Instance: TObject; const FieldName: string): Pointer;
    class function CreateInstance(AClass: TClass): TObject;
  end;

{ TRttiHelper }

class function TRttiHelper.CreateInstance(AClass: TClass): TObject;
var
  RType: TRttiType;
  Method: TRttiMethod;
  Ctx: TRttiContext;
begin
  Ctx := TRttiContext.Create;
  RType := Ctx.GetType(AClass);
  for Method in RType.GetMethods do
    if Method.IsConstructor and (Length(Method.GetParameters) = 0) then
      Exit(Method.Invoke(AClass, []).AsObject);
  Result := nil;
end;

class function TRttiHelper.GetFieldPtr(Instance: TObject; const FieldName: string): Pointer;
var
  Ctx: TRttiContext;
  RField: TRttiField;
begin
  Ctx := TRttiContext.Create;
  RField := Ctx.GetType(Instance.ClassType).GetField(FieldName);
  if RField <> nil then
    Result := PByte(Instance) + RField.Offset
  else
    Result := nil;
end;

{ TEntityDataSet }

constructor TEntityDataSet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRecordSize := SizeOf(TEntityRecordHeader);
  FHeaderSize := SizeOf(TEntityRecordHeader);
  FReadOnly := False;
  BookmarkSize := SizeOf(Integer);
  FPositionBeforeAction := -2;
end;

destructor TEntityDataSet.Destroy;
begin
  if Assigned(FInsertObj) then
    FInsertObj.Free;
    
  if FOwnsItems then
    FItems := nil; // IList cuidará da liberação se for o caso
  FItems := nil;
  
  if Assigned(FEntityMap) then
    FEntityMap.Free;
    
  inherited Destroy;
end;

procedure TEntityDataSet.Load(const AItems: IList<TObject>; AClass: TClass; AOwns: Boolean = False);
begin
  if FOwnsItems and Assigned(FItems) and (FItems <> AItems) then
    FItems := nil;

  FItems := AItems;
  FEntityClass := AClass;
  FOwnsItems := AOwns;

  if FEntityMap = nil then
  begin
    FEntityMap := TEntityMap.Create(AClass.ClassInfo);
    FEntityMap.DiscoverAttributes;
  end;
  
  Active := True; // Chama Open -> InternalOpen e prepara buffers
end;

procedure TEntityDataSet.Load(const AItems: TArray<TObject>; AClass: TClass);
var
  LList: IList<TObject>;
begin
  LList := TCollections.CreateList<TObject>(False);
  LList.AddRange(AItems);
  Load(LList, AClass, True); // Owns the wrapper list but not the objects
end;

procedure TEntityDataSet.LoadFromUtf8Json(const ASpan: TByteSpan; AClass: TClass);
var
  Context: TRttiContext;
  CurrentObj: TObject;
  PropMap: TPropertyMap;
  PropName: string;
  PValue: Pointer;
  Reader: TUtf8JsonReader;
  RttiProp: TRttiProperty;
  RttiType: TRttiType;
begin
  FEntityClass := AClass;
  if FEntityMap = nil then
  begin
    FEntityMap := TEntityMap.Create(AClass.ClassInfo);
    FEntityMap.DiscoverAttributes;
  end;

  Reader := TUtf8JsonReader.Create(ASpan);

  // Limpar itens anteriores
  if not Assigned(FItems) then
    FItems := TCollections.CreateList<TObject>(True);

  if FOwnsItems then
    FItems.Clear;
  FOwnsItems := True;

  if not Reader.Read then Exit;

  // Preparar RTTI context uma vez para todas as propriedades
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(FEntityClass);

    if Reader.TokenType = TJsonTokenType.StartArray then
    begin
      while Reader.Read and (Reader.TokenType <> TJsonTokenType.EndArray) do
      begin
        if Reader.TokenType = TJsonTokenType.StartObject then
        begin
          CurrentObj := FEntityClass.Create;

          FItems.Add(CurrentObj);

          while Reader.Read and (Reader.TokenType <> TJsonTokenType.EndObject) do
          begin
            if Reader.TokenType = TJsonTokenType.PropertyName then
            begin
              PropName := Reader.GetString;
              Reader.Read; // Avance para o valor

              if FEntityMap.Properties.TryGetValue(PropName, PropMap) then
              begin
                // Se o FieldValueOffset é válido (> 0), escrita direta por offset (fast-path)
                // Caso contrário, fallback via RTTI SetValue
                if PropMap.FieldValueOffset > 0 then
                begin
                  PValue := Pointer(PByte(CurrentObj) + PropMap.FieldValueOffset);
                  case PropMap.DataType of
                    ftString, ftWideString:
                      PString(PValue)^ := Reader.GetString;
                    ftInteger, ftSmallint:
                      PInteger(PValue)^ := Reader.GetInt32;
                    ftLargeint:
                      PInt64(PValue)^ := Reader.GetInt64;
                    ftFloat, ftCurrency:
                      PDouble(PValue)^ := Reader.GetDouble;
                    ftBoolean:
                      PBoolean(PValue)^ := Reader.GetBoolean;
                  end;
                end
                else if RttiType <> nil then
                begin
                  // RTTI fallback para classes que usam campos privados padrão
                  RttiProp := RttiType.GetProperty(PropName);
                  if RttiProp <> nil then
                  begin
                    case Reader.TokenType of
                      TJsonTokenType.StringValue:
                        RttiProp.SetValue(CurrentObj, Reader.GetString);
                      TJsonTokenType.Number:
                      begin
                        if RttiProp.PropertyType.Handle = TypeInfo(Integer) then
                          RttiProp.SetValue(CurrentObj, Reader.GetInt32)
                        else if RttiProp.PropertyType.Handle = TypeInfo(Int64) then
                          RttiProp.SetValue(CurrentObj, Reader.GetInt64)
                        else
                          RttiProp.SetValue(CurrentObj, TValue.From<Double>(Reader.GetDouble));
                      end;
                      TJsonTokenType.TrueValue, TJsonTokenType.FalseValue:
                        RttiProp.SetValue(CurrentObj, Reader.GetBoolean);
                    end;
                  end;
                end;
              end
              else
                Reader.Skip; // propriedade não mapeada, pula valor/objeto
            end;
          end;
        end;
      end;
    end;
  finally
    Context.Free;
  end;

  if Active then Close;
  Open;
end;

procedure TEntityDataSet.SetIndexFieldNames(const Value: string);
begin
  if FIndexFieldNames <> Value then
  begin
    FIndexFieldNames := Value;
    if Active then
    begin
      ApplyFilterAndSort;
      Resync([]);
    end;
  end;
end;

procedure TEntityDataSet.SetFiltered(Value: Boolean);
begin
  if Filtered <> Value then
  begin
    if Active then
      ApplyFilterAndSort(Value); // Atualiza antes do inherited disparar o resync interno!
      
    inherited SetFiltered(Value);
  end;
end;

procedure TEntityDataSet.SetFilterText(const Value: string);
begin
  if Filter <> Value then
  begin
    inherited SetFilterText(Value);
    if Active and Filtered then
    begin
      ApplyFilterAndSort;
      Resync([]);
    end;
  end;
end;

procedure TEntityDataSet.ApplyFilterAndSort;
begin
  ApplyFilterAndSort(Filtered);
end;

procedure TEntityDataSet.ApplyFilterAndSort(AFiltered: Boolean);
var
  Expr: IExpression;
  i: Integer;
  Passing: Boolean;
  CurrentRealIdx: Integer;
begin
  // Salvar o índice real do item atual para restaurar FCurrentRec depois
  CurrentRealIdx := -1;
  if (FCurrentRec >= 0) and (FCurrentRec < FVirtualIndex.Count) then
    CurrentRealIdx := FVirtualIndex[FCurrentRec];

  FVirtualIndex.Clear;

  Expr := nil;
  if AFiltered and (Filter <> '') then
    Expr := TStringExpressionParser.Parse(Filter);

  if not Assigned(FItems) then Exit;

  for i := 0 to FItems.Count - 1 do
  begin
    Passing := True;

    if AFiltered then
    begin
      if Expr <> nil then
        Passing := TExpressionEvaluator.Evaluate(Expr, FItems[I])
      else if Assigned(OnFilterRecord) then
      begin
        OnFilterRecord(Self, Passing);
      end;
    end;

    if Passing then
      FVirtualIndex.Add(I);
  end;

  if (FIndexFieldNames <> '') and (FVirtualIndex.Count > 1) then
  begin
    var LNames := FIndexFieldNames.Split([';']);
    var LContext := TRttiContext.Create;
    try
      var LType := LContext.GetType(FEntityClass);
      FVirtualIndex.Sort(TComparer<Integer>.Construct(
        function(const A, B: Integer): Integer
        begin
          // A and B are indices in FItems
          Result := CompareObjectsInternal(FItems[A], FItems[B], LNames, LType);
        end));
    finally
      LContext.Free;
    end;
  end;

  // Restaurar a posição do cursor na visão virtual
  if CurrentRealIdx >= 0 then
    FCurrentRec := FVirtualIndex.IndexOf(CurrentRealIdx)
  else
    FCurrentRec := -1;
end;

function TEntityDataSet.Locate(const KeyFields: string; const KeyValues: Variant; Options: TLocateOptions): Boolean;
var
  Context: TRttiContext;
  CurVal: Variant;
  I: Integer;
  Match: Boolean;
  PropMap: TPropertyMap;
  RttiProp: TRttiProperty;
  RttiType: TRttiType;
  PValue: Pointer;
begin
  Result := False;
  if (KeyFields = '') or (FVirtualIndex.Count = 0) then Exit;

  // Simplificado para 1 Campo por iteração clássica de Locate
  if not FEntityMap.Properties.TryGetValue(KeyFields, PropMap) then Exit;

  // Preparar RTTI se necessário (quando FieldValueOffset não está disponível)
  RttiProp := nil;
  if PropMap.FieldValueOffset <= 0 then
  begin
    Context := TRttiContext.Create;
    RttiType := Context.GetType(FEntityClass);
    if RttiType <> nil then
      RttiProp := RttiType.GetProperty(KeyFields);
  end;

  for I := 0 to FVirtualIndex.Count - 1 do
  begin
    // Ler o valor do campo usando offset direto ou RTTI
    if PropMap.FieldValueOffset > 0 then
    begin
      PValue := Pointer(PByte(FItems[FVirtualIndex[I]]) + PropMap.FieldValueOffset);
      case PropMap.DataType of
        ftInteger, ftSmallint: CurVal := PInteger(PValue)^;
        ftLargeint: CurVal := PInt64(PValue)^;
        ftString, ftWideString: CurVal := PString(PValue)^;
        ftFloat: CurVal := PDouble(PValue)^;
        ftCurrency: CurVal := PCurrency(PValue)^;
        ftBoolean: CurVal := PBoolean(PValue)^;
      else
        Continue;
      end;
    end
    else if RttiProp <> nil then
      CurVal := RttiProp.GetValue(FItems[FVirtualIndex[I]]).AsVariant
    else
      Continue;

    if Options = [] then Match := CurVal = KeyValues
    else Match := SameText(VarToStr(CurVal), VarToStr(KeyValues));

    if Match then
    begin
      // Posicionar o cursor diretamente no registro encontrado
      FCurrentRec := I;
      Resync([]);
      Result := True;
      Break;
    end;
  end;
end;

function TEntityDataSet.CompareObjectsInternal(A, B: TObject; const APropNames: TArray<string>; RttiType: TRttiType): Integer;
var
  i: Integer;
  IsDesc: Boolean;
  PropName: string;
  PropMap: TPropertyMap;
  ValA, ValB: Variant;
  RttiProp: TRttiProperty;
begin
  Result := 0;
  PropName := '';
  for i := 0 to High(APropNames) do
  begin
    var Token: string := APropNames[i].Trim;
    if Token = '' then Continue;
    IsDesc := Token.EndsWith(' DESC', True);
    PropName := Token;
    if IsDesc then
      PropName := Token.Substring(0, Token.Length - 5).Trim;

    ValA := Unassigned;
    ValB := Unassigned;
    var Matched: Boolean := False;

    // 1. Try Fast-Path via Mapper (Value Extraction)
    PropMap := nil;
    if FEntityMap.Properties.TryGetValue(PropName, PropMap) then
    begin
      if PropMap.FieldValueOffset > 0 then
      begin
        case PropMap.DataType of
          ftInteger, ftAutoInc, ftShortint, ftWord:
            begin
              ValA := PInteger(Pointer(PByte(A) + PropMap.FieldValueOffset))^;
              ValB := PInteger(Pointer(PByte(B) + PropMap.FieldValueOffset))^;
              Matched := True;
            end;
          ftBoolean:
            begin
              // Use PByte for Boolean as it's typically 1 byte in memory
              ValA := PByte(Pointer(PByte(A) + PropMap.FieldValueOffset))^;
              ValB := PByte(Pointer(PByte(B) + PropMap.FieldValueOffset))^;
              Matched := True;
            end;
          ftFloat, ftCurrency:
            begin
              ValA := PDouble(Pointer(PByte(A) + PropMap.FieldValueOffset))^;
              ValB := PDouble(Pointer(PByte(B) + PropMap.FieldValueOffset))^;
              Matched := True;
            end;
        end;
      end;
    end;

    // 2. Try RTTI Fallback
    if (not Matched) and (RttiType <> nil) then
    begin
      RttiProp := nil;
      for var LP in RttiType.GetProperties do
        if SameText(LP.Name, PropName) then
        begin
          RttiProp := LP;
          Break;
        end;

      if RttiProp <> nil then
      begin
        ValA := RttiProp.GetValue(A).AsVariant;
        ValB := RttiProp.GetValue(B).AsVariant;
      end
      else
      begin
        var RttiFld: TRttiField := nil;
        for var LF in RttiType.GetFields do
          if SameText(LF.Name, PropName) or SameText(LF.Name, 'F' + PropName) then
          begin
            RttiFld := LF;
            Break;
          end;
        
        if RttiFld <> nil then
        begin
          ValA := RttiFld.GetValue(A).AsVariant;
          ValB := RttiFld.GetValue(B).AsVariant;
        end;
      end;
    end;

    // Compare Variants obtained either via Fast-Path or RTTI
    if (not VarIsEmpty(ValA)) and (not VarIsEmpty(ValB)) then
    begin
      if ValA < ValB then Result := -1 else if ValA > ValB then Result := 1;
    end;

    if Result <> 0 then
    begin
      if IsDesc then Result := -Result;
      Break;
    end;
  end;

  // Stable sort tie-breaker (important for tests)
  if (Result = 0) and (not SameText(PropName, 'Id')) then
  begin
    PropMap := nil;
    if FEntityMap.Properties.TryGetValue('Id', PropMap) then
    begin
      var IdA := PInteger(Pointer(PByte(A) + PropMap.FieldValueOffset))^;
      var IdB := PInteger(Pointer(PByte(B) + PropMap.FieldValueOffset))^;
      if IdA < IdB then Result := -1 else if IdA > IdB then Result := 1;
    end
    else if RttiType <> nil then
    begin
      // Last-resort RTTI tie-breaker
      RttiProp := nil;
      for var LP in RttiType.GetProperties do
        if SameText(LP.Name, 'Id') then
        begin
          RttiProp := LP;
          Break;
        end;
      if RttiProp <> nil then
      begin
        ValA := RttiProp.GetValue(A).AsVariant;
        ValB := RttiProp.GetValue(B).AsVariant;
        if ValA < ValB then Result := -1 else if ValA > ValB then Result := 1;
      end;
    end;
  end;
end;

procedure TEntityDataSet.SetItems(const Value: IList<TObject>);
begin
  if FItems <> Value then
  begin
    if FOwnsItems then
      FItems := nil;
    
    FItems := Value;
    FOwnsItems := False; // Por padrão não somos donos de uma lista injetada via property

    if Active then
    begin
      ApplyFilterAndSort;
      Resync([]);
    end;
  end;
end;

{ TEntityDataSet }

procedure TEntityDataSet.InternalOpen;
begin
  FIsCursorOpen := True;
  
  if FEntityClass = nil then
    raise Exception.Create('EntityClass must be defined before opening TEntityDataSet.');

  if Active or (State = dsInactive) then
  begin
    if FieldDefs.Count = 0 then
      BuildFieldDefs;
      
    if FieldCount = 0 then
      CreateFields;
  end;

  ApplyFilterAndSort;
  BookmarkSize := SizeOf(Integer);
  FRecordSize := SizeOf(TEntityRecordHeader); // Importante para o VCL alocar buffers com espaço para o Header
  FCurrentRec := -1; // Reset de cursor nativo
  BindFields(True);
end;

procedure TEntityDataSet.InternalClose;
begin
  if Assigned(FInsertObj) then
  begin
    FInsertObj.Free;
    FInsertObj := nil;
  end;
  FIsCursorOpen := False;
  FVirtualIndex.Clear;
end;

procedure TEntityDataSet.InternalDelete;
var
  TargetIdx: Integer;
  ActualRow: Integer;
begin
  if not Assigned(FItems) then Exit;

  // 1. Usar exclusivamente a posição capturada no DoBeforeDelete (GetRecNo é 1-based)
  TargetIdx := FPositionBeforeAction - 1; 

  if (TargetIdx >= 0) and (TargetIdx < FVirtualIndex.Count) then
  begin
    // 2. Identificar o índice real na lista física
    ActualRow := FVirtualIndex[TargetIdx];
    
    // 3. Remover das listas
    FVirtualIndex.RemoveAt(TargetIdx);
    FItems.Delete(ActualRow);
    
    // 4. Reconstruir a visão virtual (necessário se houver filtros ou sorteio ativos)
    ApplyFilterAndSort;

    // 5. Estratégia de Reposicionamento para o Delphi TDataSet:
    // O TDataSet executa UpdateCursorPos e Resync nativamente após o InternalDelete.
    // Setando FCurrentRec em TargetIdx - 1, o framework fará o Next para TargetIdx.
    // Como os registros subiram para ocupar a vaga deletada, o sucessor agora é o novo TargetIdx.
    if FVirtualIndex.Count = 0 then
      FCurrentRec := -1
    else
    if TargetIdx <= FVirtualIndex.Count then
      FCurrentRec := TargetIdx
    else
      FCurrentRec := FVirtualIndex.Count;
    // NOTE: We do NOT call Resync([]); here. The base TDataSet manages this event
    // immediately after InternalDelete, ensuring the cursor lands on the correct record.
  end;
end;

procedure TEntityDataSet.InternalPost;
var
  NewIdx: Integer;
  TargetIdx: Integer;
  TargetPos: Integer;
begin
  if State = dsInsert then
  begin
    if Assigned(FInsertObj) then
    begin
      // 1. Decide between Add (Append) or Insert at position (Insert)
      if FIsAppending then
      begin
        FItems.Add(FInsertObj);
        NewIdx := FItems.Count -1;
      end
      else
      begin
        // Adjust 1-based RecNo to 0-based index
        TargetPos := FPositionBeforeAction - 1;

        if (TargetPos < 0) or (FVirtualIndex.Count = 0) then
          TargetIdx := 0
        else if (TargetPos >= FVirtualIndex.Count) then
          TargetIdx := FItems.Count
        else
          // In Insert mode, use the physical index pointed by the virtual view at the position stored in DoBeforeInsert
          TargetIdx := FVirtualIndex[TargetPos];

        if TargetIdx >= FItems.Count then
        begin
          FItems.Add(FInsertObj);
          NewIdx := FItems.Count - 1;
        end
        else
        begin
          FItems.Insert(TargetIdx, FInsertObj);
          NewIdx := TargetIdx;
        end;
      end;

      FInsertObj := nil; 
      FIsAppending := False; 
      FPositionBeforeAction := -2;

      // 2. Update Virtual View
      ApplyFilterAndSort;

      // 3. Position cursor on the new item
      FCurrentRec := FVirtualIndex.IndexOf(NewIdx);

      // 4. Notificar mudança
      DataEvent(deDataSetChange, 0);
    end;
  end
  else if State = dsEdit then
  begin
    ApplyFilterAndSort;
  end;
end;

procedure TEntityDataSet.InternalCancel;
begin
  if (State = dsInsert) and (FInsertObj <> nil) then
  begin
    FInsertObj.Free;
    FInsertObj := nil;
  end;
end;

procedure TEntityDataSet.InternalEdit;
begin
  // No-op.
end;

procedure TEntityDataSet.DoBeforeScroll;
begin
  inherited DoBeforeScroll;
end;

procedure TEntityDataSet.DoAfterScroll;
begin
  inherited DoAfterScroll;
end;

procedure TEntityDataSet.DoBeforeInsert;
begin
  FPositionBeforeAction := GetRecNo;
  inherited DoBeforeInsert;
end;

procedure TEntityDataSet.DoBeforeDelete;
begin
  FPositionBeforeAction := GetRecNo;
  inherited DoBeforeDelete;
end;

procedure TEntityDataSet.InternalInsert;
begin
  FIsAppending := (PEntityRecordHeader(ActiveBuffer).BookmarkFlag = bfEOF);
  if FInsertObj <> nil then
  begin
    FInsertObj.Free;
    FInsertObj := nil;
  end;
  FInsertObj := CreateNewEntity;
  
  if FInsertObj = nil then
    raise Exception.Create('Auto-append needs a parameterless constructor for ' + FEntityClass.ClassName);

  if (Pointer(ActiveBuffer) <> nil) then
  begin
    // Set virtual control flags for the new insertion buffer
    PEntityRecordHeader(Pointer(ActiveBuffer)).BookmarkIndex := -2; 
    PEntityRecordHeader(Pointer(ActiveBuffer)).BookmarkFlag := bfInserted;
  end;
end;

procedure TEntityDataSet.InternalAddRecord(Buffer: TRecordBuffer; Append: Boolean);
begin
  FIsAppending := Append;
  InternalPost;
end;

procedure TEntityDataSet.InternalFirst;
begin
  FCurrentRec := -1;
end;

procedure TEntityDataSet.InternalLast;
begin
  FCurrentRec := FVirtualIndex.Count;
end;

procedure TEntityDataSet.InternalInitFieldDefs;

  function MapTypeToFieldType(ATypeInfo: PTypeInfo): TFieldType;
  begin
    if ATypeInfo = nil then Exit(ftUnknown);
    case ATypeInfo.Kind of
      tkInteger, tkEnumeration:
      begin
        var LTypeName := string(ATypeInfo.Name);
        if (ATypeInfo = TypeInfo(Boolean)) or (LTypeName = 'Boolean') or (LTypeName = 'WordBool') or (LTypeName = 'ByteBool') or (LTypeName = 'LongBool') then
          Exit(ftBoolean)
        else
          Exit(ftInteger);
      end;
      tkFloat:
      begin
        if ATypeInfo = TypeInfo(TDateTime) then
          Exit(ftDateTime)
        else if ATypeInfo = TypeInfo(Currency) then
          Exit(ftCurrency)
        else
          Exit(ftFloat);
      end;
      tkString, tkLString, tkWString, tkUString, tkChar, tkWChar:
        Exit(ftWideString);
      tkInt64:
        Exit(ftLargeint);
      tkVariant:
        Exit(ftVariant);
    else
      Exit(ftUnknown);
    end;
  end;

  function IsTBytesType(ATypeInfo: PTypeInfo): Boolean;
  begin
    Result := (ATypeInfo <> nil) and (ATypeInfo.Kind = tkDynArray) and
              (ATypeInfo = TypeInfo(TBytes));
  end;

var
  Context: TRttiContext;
  FieldDef: TFieldDef;
  ResolvedType: TFieldType;
  NewField: TField;
  PropMap: TPropertyMap;
  Prop: TRttiProperty;
  RttiType: TRttiType;
begin
  if (FEntityMap = nil) or (FEntityClass = nil) then Exit;

  FieldDefs.Clear;

  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(FEntityClass);

    for PropMap in FEntityMap.Properties.Values do
    begin
      if PropMap.IsIgnored or PropMap.IsNavigation then Continue;

      // Calcular resolved type dinamicamente
      ResolvedType := PropMap.DataType;

      // Se tivermos Shadow mapping, ler do RTTI da Classe estática (Prop ou Field)
      if (ResolvedType = ftUnknown) and (RttiType <> nil) then
      begin
        Prop := RttiType.GetProperty(PropMap.PropertyName);
        if Prop <> nil then
        begin
          if IsTBytesType(Prop.PropertyType.Handle) then
            ResolvedType := ftBlob
          else
            ResolvedType := MapTypeToFieldType(Prop.PropertyType.Handle);
        end
        else
        begin
           var LFld := RttiType.GetField(PropMap.PropertyName);
           if LFld = nil then LFld := RttiType.GetField('F' + PropMap.PropertyName);
           
           if LFld <> nil then
           begin
              if IsTBytesType(LFld.FieldType.Handle) then
                ResolvedType := ftBlob
              else
                ResolvedType := MapTypeToFieldType(LFld.FieldType.Handle);
                
              // Update FieldOffset if not yet set
              if PropMap.FieldValueOffset <= 0 then
                PropMap.FieldValueOffset := LFld.Offset;
           end;
        end;
      end;

      // Se ainda for desconhecido e houver PTypeInfo no map
      if (ResolvedType = ftUnknown) and Assigned(PropMap.PropertyType) then
        ResolvedType := MapTypeToFieldType(PropMap.PropertyType);

      // CRITICAL: Persist resolved type back into PropMap
      if (PropMap.DataType = ftUnknown) and (ResolvedType <> ftUnknown) then
        PropMap.DataType := ResolvedType;

      // 1. Popular FieldDefs para metadados
      FieldDef := FieldDefs.AddFieldDef;
      FieldDef.Name := PropMap.PropertyName;
      FieldDef.DataType := ResolvedType;
      if PropMap.MaxLength > 0 then
        FieldDef.Size := PropMap.MaxLength
      else if ResolvedType in [ftString, ftWideString] then
        FieldDef.Size := 255;

      // 2. Instanciar os TFields dinamicamente
      if Fields.FindField(PropMap.PropertyName) = nil then
      begin
        NewField := nil;
        case ResolvedType of
          ftWideString: NewField := TWideStringField.Create(Self);
          ftString: NewField := TStringField.Create(Self);
          ftInteger, ftSmallint: NewField := TIntegerField.Create(Self);
          ftLargeint: NewField := TLargeintField.Create(Self);
          ftFloat: NewField := TFloatField.Create(Self);
          ftCurrency: NewField := TCurrencyField.Create(Self);
          ftBoolean: NewField := TBooleanField.Create(Self);
          ftDateTime: NewField := TDateTimeField.Create(Self);
          ftDate: NewField := TDateField.Create(Self);
          ftTime: NewField := TTimeField.Create(Self);
          ftBlob: NewField := TBlobField.Create(Self);
          ftMemo: NewField := TMemoField.Create(Self);
        end;

        if NewField <> nil then
        begin
          NewField.FieldName := PropMap.PropertyName;
          if NewField is TStringField then
          begin
            if PropMap.MaxLength > 0 then
              TStringField(NewField).Size := PropMap.MaxLength
            else
              TStringField(NewField).Size := 255;
          end
          else if NewField is TWideStringField then
          begin
            if PropMap.MaxLength > 0 then
              TWideStringField(NewField).Size := PropMap.MaxLength
            else
              TWideStringField(NewField).Size := 255;
          end;

          NewField.Required := PropMap.IsRequired and (not PropMap.IsAutoInc);
          NewField.ReadOnly := PropMap.IsAutoInc;
          NewField.DataSet := Self;
        end;
      end;
    end;
  finally
    Context.Free;
  end;
end;

procedure TEntityDataSet.BuildFieldDefs;
begin
  InternalInitFieldDefs;
end;

function TEntityDataSet.AllocRecordBuffer: TRecordBuffer;
begin
  GetMem(Pointer(Result), FRecordSize);
  InternalInitRecord(Result);
end;

procedure TEntityDataSet.FreeRecordBuffer(var Buffer: TRecordBuffer);
begin
  FreeMem(Pointer(Buffer));
end;

function TEntityDataSet.CreateNewEntity: TObject;
var
  Context: TRttiContext;
  RttiMethod: TRttiMethod;
  RttiType: TRttiType;
begin
  Result := nil;
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(FEntityClass);
    if RttiType <> nil then
    begin
      for RttiMethod in RttiType.GetMethods do
      begin
        // Busca constructor sem parâmetros
        if RttiMethod.IsConstructor and (Length(RttiMethod.GetParameters) = 0) then
        begin
          Result := RttiMethod.Invoke(FEntityClass, []).AsObject;
          Break;
        end;
      end;
    end;
  finally
    Context.Free;
  end;
end;

procedure TEntityDataSet.InternalInitRecord(Buffer: TRecordBuffer);
begin
  FillChar(Buffer^, FRecordSize, 0);
  PEntityRecordHeader(Buffer).BookmarkIndex := -2;
end;

procedure TEntityDataSet.GetBookmarkData(Buffer: TRecordBuffer; Data: Pointer);
begin
  PInteger(Data)^ := PEntityRecordHeader(Buffer).BookmarkIndex;
end;

procedure TEntityDataSet.SetBookmarkData(Buffer: TRecordBuffer; Data: Pointer);
begin
  PEntityRecordHeader(Buffer).BookmarkIndex := PInteger(Data)^;
end;

procedure TEntityDataSet.InternalGotoBookmark(Bookmark: TBookmark);
begin
  FCurrentRec := PInteger(Pointer(Bookmark))^;
end;

function TEntityDataSet.GetBookmarkFlag(Buffer: TRecordBuffer): TBookmarkFlag;
begin
  Result := PEntityRecordHeader(Buffer).BookmarkFlag;
end;

procedure TEntityDataSet.SetBookmarkFlag(Buffer: TRecordBuffer; Value: TBookmarkFlag);
begin
  PEntityRecordHeader(Buffer).BookmarkFlag := Value;
end;

procedure TEntityDataSet.InternalSetToRecord(Buffer: TRecordBuffer);
var
  Idx: Integer;
begin
  Idx := PEntityRecordHeader(Buffer).BookmarkIndex;
  if (Idx >= 0) and (Idx < FVirtualIndex.Count) then
    FCurrentRec := Idx;
end;

function TEntityDataSet.GetRecordSize: Word;
begin
  Result := FRecordSize;
end;

function TEntityDataSet.GetRecordCount: Integer;
begin
  Result := FVirtualIndex.Count;
end;

function TEntityDataSet.GetRecNo: Integer;
begin
  CheckActive;
  if Pointer(ActiveBuffer) <> nil then
    Result := PEntityRecordHeader(Pointer(ActiveBuffer)).BookmarkIndex + 1
  else
    Result := FCurrentRec + 1;
end;

procedure TEntityDataSet.SetRecNo(Value: Integer);
begin
  CheckBrowseMode;
  Value := System.Math.Min(System.Math.Max(Value, 1), RecordCount);
  if RecNo <> Value then
  begin
    DoBeforeScroll;
    FCurrentRec := Value - 1;
    Resync([rmCenter]);
    DoAfterScroll;
  end;
end;

function TEntityDataSet.BookmarkValid(Bookmark: TBookmark): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  if (Pointer(Bookmark) = nil) or (FVirtualIndex.Count = 0) then
    Exit;

  // In virtual datasets, the bookmark stores the logical index.
  Idx := PInteger(Pointer(Bookmark))^;
  Result := (Idx >= 0) and (Idx < FVirtualIndex.Count);
end;

function TEntityDataSet.GetRecord(Buffer: TRecordBuffer; GetMode: TGetMode; DoSearch: Boolean): TGetResult;
var
  Header: PEntityRecordHeader;
begin
  Header := PEntityRecordHeader(Buffer);

  case GetMode of
    gmNext:
      begin
        if FCurrentRec < FVirtualIndex.Count - 1 then
        begin
          Inc(FCurrentRec);
          Result := grOK;
        end
        else
          Result := grEOF;
      end;
      
    gmPrior:
      begin
        if FCurrentRec >= 0 then
          Dec(FCurrentRec);
        if FCurrentRec < 0 then
          Result := grBOF
        else
          Result := grOK;
      end;
      
    gmCurrent:
      begin
        if (FCurrentRec < 0) or (FCurrentRec >= FVirtualIndex.Count) then
          Result := grError
        else
          Result := grOK;
      end;
  else
    Result := grError;
  end;

  if Result = grOK then
  begin
     Header.BookmarkIndex := FCurrentRec;
     Header.BookmarkFlag := bfCurrent;
  end
  else if Result = grEOF then
  begin
     Header.BookmarkFlag := bfEOF;
  end
  else if Result = grBOF then
  begin
     Header.BookmarkFlag := bfBOF;
  end;
end;

// ---------------------------------------------------------------------------
//  ReadFieldValue - Core universal method: reads a property from the entity
// ---------------------------------------------------------------------------
function TEntityDataSet.ReadFieldValue(Field: TField; out Value: Variant): Boolean;
var
  BlobData: TArray<Byte>;
  Context: TRttiContext;
  CurrentObj: TObject;
  Header: PEntityRecordHeader;
  PropMap: TPropertyMap;
  PValue: Pointer;
  RttiField: TRttiField;
  RttiProp: TRttiProperty;
  RttiType: TRttiType;
begin
  Result := False;
  Value := Unassigned;

  if not Active then Exit;
  Header := PEntityRecordHeader(ActiveBuffer);

  // 1. Identify target object - ABSOLUTE PRIORITY to active buffer painting (Grid)
  CurrentObj := nil;
  
  if (Header <> nil) then
  begin
    if (Header.BookmarkIndex = -2) then
      CurrentObj := FInsertObj
    else if (Header.BookmarkIndex >= 0) and (Header.BookmarkIndex < FVirtualIndex.Count) then
      CurrentObj := FItems[FVirtualIndex[Header.BookmarkIndex]];
  end;

  // 2. Fallback to global cursor (programmatic Field.Value access or navigation outside the painting loop)
  if (CurrentObj = nil) and (FCurrentRec >= 0) and (FCurrentRec < FVirtualIndex.Count) then
  begin
     CurrentObj := FItems[FVirtualIndex[FCurrentRec]];
  end;

  if (CurrentObj = nil) or (FEntityMap = nil) then Exit;

  if not FEntityMap.Properties.TryGetValue(Field.FieldName, PropMap) then
    Exit;

  PValue := Pointer(PByte(CurrentObj) + PropMap.FieldValueOffset);

  // 3. RTTI Fallback if field offset is not defined
  if (PropMap.FieldValueOffset <= 0) then
  begin
   Context := TRttiContext.Create;
    try
      RttiType := Context.GetType(FEntityClass);
      if RttiType <> nil then
      begin
       RttiProp := RttiType.GetProperty(Field.FieldName);
        if RttiProp <> nil then
        begin
          case Field.DataType of
            ftString, ftWideString:
              Value := RttiProp.GetValue(CurrentObj).AsString;
            ftInteger, ftSmallint:
              Value := RttiProp.GetValue(CurrentObj).AsInteger;
            ftLargeint:
              Value := RttiProp.GetValue(CurrentObj).AsInt64;
            ftFloat:
              Value := RttiProp.GetValue(CurrentObj).AsExtended;
            ftCurrency:
              Value := RttiProp.GetValue(CurrentObj).AsCurrency;
            ftBoolean:
              Value := RttiProp.GetValue(CurrentObj).AsBoolean;
            ftDateTime, ftDate, ftTime:
              Value := RttiProp.GetValue(CurrentObj).AsExtended;
          else
            Exit;
          end;
          Result := True;
          Exit;
        end;

        RttiField := RttiType.GetField(Field.FieldName);
        if RttiField <> nil then
        begin
          case Field.DataType of
            ftString, ftWideString:
              Value := RttiField.GetValue(CurrentObj).AsString;
            ftInteger, ftSmallint:
              Value := RttiField.GetValue(CurrentObj).AsInteger;
            ftLargeint:
              Value := RttiField.GetValue(CurrentObj).AsInt64;
            ftFloat:
              Value := RttiField.GetValue(CurrentObj).AsExtended;
            ftCurrency:
              Value := RttiField.GetValue(CurrentObj).AsCurrency;
            ftBoolean:
              Value := RttiField.GetValue(CurrentObj).AsBoolean;
            ftDateTime, ftDate, ftTime:
              Value := RttiField.GetValue(CurrentObj).AsExtended;
          else
            Exit;
          end;
          Result := True;
          Exit;
        end;
      end;
    finally
      Context.Free;
    end;
    Exit;
  end;

  // Leitura direta por offset (fast-path)
  case Field.DataType of
    ftString, ftWideString:
      Value := PString(PValue)^;
    ftInteger, ftSmallint:
      Value := PInteger(PValue)^;
    ftLargeint:
      Value := PInt64(PValue)^;
    ftFloat:
      Value := PDouble(PValue)^;
    ftCurrency:
      Value := PCurrency(PValue)^;
    ftBoolean:
      Value := PBoolean(PValue)^;
    ftDateTime, ftDate, ftTime:
      Value := PDateTime(PValue)^;
    ftBlob:
    begin
      // Para Blob, retornar True se houver dados (IsNull check)
      // O conteúdo real é servido por CreateBlobStream
      BlobData := TBytes(PValue^);
      if Length(BlobData) = 0 then
        Exit; // Result fica False = IsNull
      Value := True; // Sinaliza não-nulo
    end;
  else
    Exit; // Tipo não mapeado diretamente
  end;
  
  Result := True;
end;

// ---------------------------------------------------------------------------
//  GetFieldData — Override with TValueBuffer (TArray<Byte>) for modern Delphi
//  This is the method TField.GetData actually calls (XE3+).
// ---------------------------------------------------------------------------
function TEntityDataSet.GetFieldData(Field: TField; var Buffer: TValueBuffer): Boolean;
var
  DblVal: Double;
  I64Val: Int64;
  IntVal: Integer;
  S: string;
  TempBuf: TValueBuffer;
  TempBytes: TBytes;
  V: Variant;
  WB: WordBool;
begin
  Result := ReadFieldValue(Field, V);
  if not Result then Exit;
  
  // Se Buffer vazio, apenas check de null (TField chama com buffer vazio para testar IsNull)
  if Length(Buffer) = 0 then
    Exit;

  case Field.DataType of
    ftWideString, ftFixedWideChar:
    begin
      S := VarToStr(V);
      TempBytes := TEncoding.Unicode.GetBytes(S);
      // Adicionar null terminator Unicode (2 bytes)
      SetLength(TempBytes, Length(TempBytes) + SizeOf(Char));
      TempBytes[Length(TempBytes) - 2] := 0;
      TempBytes[Length(TempBytes) - 1] := 0;
      Move(TempBytes[0], Buffer[0], Min(Length(TempBytes), Length(Buffer)));
    end;
    
    ftString, ftFixedChar:
    begin
      S := VarToStr(V);
      TempBytes := TEncoding.Default.GetBytes(S);
      Move(TempBytes[0], Buffer[0], Min(Length(TempBytes), Length(Buffer)));
      // Null terminator ANSI
      if Length(TempBytes) < Length(Buffer) then
        Buffer[Length(TempBytes)] := 0;
    end;

    ftInteger, ftSmallint, ftAutoInc:
    begin
      IntVal := V;
      Move(IntVal, Buffer[0], SizeOf(Integer));
    end;

    ftLargeint:
    begin
      I64Val := V;
      Move(I64Val, Buffer[0], SizeOf(Int64));
    end;

    ftFloat:
    begin
      DblVal := V;
      Move(DblVal, Buffer[0], SizeOf(Double));
    end;

    ftCurrency:
    begin
      DblVal := V;
      Move(DblVal, Buffer[0], SizeOf(Double));
    end;

    ftBoolean:
    begin
      WB := WordBool(Boolean(V));
      Move(WB, Buffer[0], SizeOf(WordBool));
    end;

    ftDate, ftTime, ftDateTime:
    begin
      DblVal := V;
      // DateTime precisa de DataConvert para NativeFormat
      SetLength(TempBuf, SizeOf(Double));
      Move(DblVal, TempBuf[0], SizeOf(Double));
      DataConvert(Field, TempBuf, Buffer, True);
    end;
  else
    Result := False;
  end;
end;

procedure TEntityDataSet.SetFieldData(Field: TField; Buffer: TValueBuffer);
var
  Context: TRttiContext;
  CurrentObj: TObject;
  Header: PEntityRecordHeader;
  P: Pointer;
  PropMap: TPropertyMap;
  PValue: Pointer;
  Prop: TRttiProperty;
  Fld: TRttiField;
  RttiType: TRttiType;
begin
  CurrentObj := nil;
  Header := nil;
  if Pointer(ActiveBuffer) <> nil then
    Header := PEntityRecordHeader(ActiveBuffer);

  // Extract raw pointer from TValueBuffer
  if Length(Buffer) > 0 then
    P := @Buffer[0]
  else
    P := nil;

  // Identifica o objeto de destino (Insert ou registro existente)
  if (Header <> nil) and (Header.BookmarkIndex = -2) then
    CurrentObj := FInsertObj
  else if (Header <> nil) and (Header.BookmarkIndex >= 0) and (Header.BookmarkIndex < FVirtualIndex.Count) then
    CurrentObj := FItems[FVirtualIndex[Header.BookmarkIndex]]
  else if (State = dsInsert) then
    CurrentObj := FInsertObj
  else if (FCurrentRec >= 0) and (FCurrentRec < FVirtualIndex.Count) then
    CurrentObj := FItems[FVirtualIndex[FCurrentRec]];

  if (CurrentObj = nil) or (FEntityMap = nil) then Exit;

  if not FEntityMap.Properties.TryGetValue(Field.FieldName, PropMap) then
    Exit;

  PValue := Pointer(PByte(CurrentObj) + PropMap.FieldValueOffset);

  // RTTI fallback path (for properties without direct offset)
  if (PropMap.FieldValueOffset <= 0) then
  begin
    Context := TRttiContext.Create;
    try
     RttiType := Context.GetType(FEntityClass);
      if RttiType <> nil then
      begin
        Prop := RttiType.GetProperty(Field.FieldName);
        if (Prop <> nil) and (P <> nil) then
        begin
          case Field.DataType of
            ftString, ftWideString:
              Prop.SetValue(CurrentObj, string(PWideChar(P)));
            ftInteger, ftSmallint:
              Prop.SetValue(CurrentObj, PInteger(P)^);
            ftLargeint:
              Prop.SetValue(CurrentObj, PInt64(P)^);
            ftFloat, ftCurrency:
              Prop.SetValue(CurrentObj, PDouble(P)^);
            ftBoolean:
              Prop.SetValue(CurrentObj, PWordBool(P)^ <> False);
            ftDateTime, ftDate, ftTime:
              Prop.SetValue(CurrentObj, TValue.From<Double>(PDouble(P)^));
          end;
          SetModified(True);
          Exit;
        end;

        Fld := RttiType.GetField(Field.FieldName);
        if (Fld <> nil) and (P <> nil) then
        begin
          case Field.DataType of
            ftString, ftWideString:
              Fld.SetValue(CurrentObj, string(PWideChar(P)));
            ftInteger, ftSmallint:
              Fld.SetValue(CurrentObj, PInteger(P)^);
            ftLargeint:
              Fld.SetValue(CurrentObj, PInt64(P)^);
            ftFloat, ftCurrency:
              Fld.SetValue(CurrentObj, PDouble(P)^);
            ftBoolean:
              Fld.SetValue(CurrentObj, PWordBool(P)^ <> False);
            ftDateTime, ftDate, ftTime:
              Fld.SetValue(CurrentObj, TValue.From<Double>(PDouble(P)^));
          end;
          SetModified(True);
          Exit;
        end;
      end;
    finally
      Context.Free;
    end;
  end;

  // Direct offset write path (fast-path)
  if P <> nil then
  begin
    case Field.DataType of
      ftString, ftWideString:
        PString(PValue)^ := string(PWideChar(P));
      ftInteger, ftSmallint:
        PInteger(PValue)^ := PInteger(P)^;
      ftLargeint:
        PInt64(PValue)^ := PInt64(P)^;
      ftFloat, ftCurrency:
        PDouble(PValue)^ := PDouble(P)^;
      ftBoolean:
        PBoolean(PValue)^ := PWordBool(P)^ <> False;
      ftDateTime, ftDate, ftTime:
        PDouble(PValue)^ := PDouble(P)^;
    else
      Exit;
    end;
  end
  else
  begin
    // Buffer vazio = limpar campo
    case Field.DataType of
      ftString, ftWideString:
        PString(PValue)^ := '';
      ftInteger, ftSmallint:
        PInteger(PValue)^ := 0;
      ftLargeint:
        PInt64(PValue)^ := 0;
      ftFloat, ftCurrency:
        PDouble(PValue)^ := 0;
      ftBoolean:
        PBoolean(PValue)^ := False;
      ftDateTime, ftDate, ftTime:
        PDouble(PValue)^ := 0;
    end;
  end;
  
  SetModified(True);
end;

procedure TEntityDataSet.InternalHandleException;
begin
  // No-op. Exceções em memória não exigem buffer rollback ou handle físico de database.
end;

function TEntityDataSet.IsCursorOpen: Boolean;
begin
  Result := FIsCursorOpen;
end;

end.
