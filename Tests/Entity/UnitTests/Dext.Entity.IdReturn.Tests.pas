unit Dext.Entity.IdReturn.Tests;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Mocks,
  Dext.Mocks.Matching,
  Dext.Core.SmartTypes,
  Dext.Types.UUID,
  Dext.Interception,
  Dext.Entity.Attributes,
  Dext.Entity.Context,
  Dext.Entity.DbSet,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Setup,
  Dext.Entity.Core;

type
  { --- Test Entities --- }

  [Table('int_table')]
  TIntEntity = class
  private
    FId: Integer;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
  end;

  [Table('int64_table')]
  TInt64Entity = class
  private
    FId: Int64;
  public
    [PK, AutoInc]
    property Id: Int64 read FId write FId;
  end;

  [Table('inttype_table')]
  TIntTypeEntity = class
  private
    FId: IntType;
  public
    [PK, AutoInc]
    property Id: IntType read FId write FId;
  end;

  [Table('guid_table')]
  TGuidEntity = class
  private
    FId: TGUID;
  public
    [PK, AutoInc]
    property Id: TGUID read FId write FId;
  end;

  [Table('propguid_table')]
  TPropGuidEntity = class
  private
    FId: Prop<TGUID>;
  public
    [PK, AutoInc]
    property Id: Prop<TGUID> read FId write FId;
  end;

  [Table('uuid_table')]
  TUUIDEntity = class
  private
    FId: TUUID;
  public
    [PK, AutoInc]
    property Id: TUUID read FId write FId;
  end;

  [Table('propuuid_table')]
  TPropUUIDEntity = class
  private
    FId: Prop<TUUID>;
  public
    [PK, AutoInc]
    property Id: Prop<TUUID> read FId write FId;
  end;

  [Table('string_table')]
  TStringEntity = class
  private
    FId: string;
  public
    [PK, AutoInc]
    property Id: string read FId write FId;
  end;

  { --- Test Fixture --- }

  [TestFixture('Entity ID Return/Assignment Tests')]
  TEntityIdReturnTests = class
  private
    procedure TestIdAssignment<T: class, constructor>(const AReturnValue: TValue; ACheck: TProc<T>);
  public
    [Test]
    procedure Test_Integer_Id_Return;
    
    [Test]
    procedure Test_Int64_Id_Return;
    
    [Test]
    procedure Test_IntType_Id_Return;
    
    [Test]
    procedure Test_TGUID_Id_Return;
    
    [Test]
    procedure Test_PropTGUID_Id_Return;
    
    [Test]
    procedure Test_TUUID_Id_Return;
    
    [Test]
    procedure Test_PropTUUID_Id_Return;

    [Test]
    procedure Test_String_Id_Return;
  end;

implementation

{ TEntityIdReturnTests }

procedure TEntityIdReturnTests.TestIdAssignment<T>(const AReturnValue: TValue; ACheck: TProc<T>);
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Dialect: Mock<ISQLDialect>;
  Ctx: TDbContext;
  Entity: T;
  DbSet: IDbSet<T>;
begin
  // Setup Mock Command
  Cmd := Mock<IDbCommand>.Create;
  Cmd.Setup.Returns(AReturnValue).When.ExecuteScalar;
  
  // Setup Mock Dialect (Force RETURNING support to trigger ExecuteScalar in PersistAdd)
  Dialect := Mock<ISQLDialect>.Create;
  Dialect.Setup.Returns(True).When.SupportsInsertReturning;
  Dialect.Setup.Returns('RETURNING id').When.GetReturningSQL(Arg.Any<string>);
  Dialect.Setup.Returns(ddPostgreSQL).When.GetDialect;
  Dialect.Setup.Returns(':').When.GetParamPrefix;
  Dialect.Setup.Executes(procedure(Invocation: IInvocation) begin Invocation.Result := '"' + Invocation.Arguments[0].AsString + '"'; end).When.QuoteIdentifier(Arg.Any<string>);

  // Setup Mock Connection
  Conn := Mock<IDbConnection>.Create;
  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  
  Ctx := TDbContext.Create(Conn.Instance, Dialect.Instance);
  try
    DbSet := Ctx.Entities<T>;
    Entity := T.Create;
    
    DbSet.Add(Entity);
    Ctx.SaveChanges;
    
    if Assigned(ACheck) then
      ACheck(Entity);

    DbSet := nil; // CRITICAL: Release interface reference before Freeing Ctx
  finally
    Ctx.Free;
  end;
end;

procedure TEntityIdReturnTests.Test_Integer_Id_Return;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Dialect: Mock<ISQLDialect>;
  Ctx: TDbContext;
  Entity: TIntEntity;
begin
  // Setup Mock Command
  Cmd := Mock<IDbCommand>.Create;
  Cmd.Setup.Returns(TValue.From<Integer>(123)).When.ExecuteScalar;
  
  // Setup Mock Dialect
  Dialect := Mock<ISQLDialect>.Create;
  Dialect.Setup.Returns(True).When.SupportsInsertReturning;
  Dialect.Setup.Returns('RETURNING id').When.GetReturningSQL(Arg.Any<string>);
  Dialect.Setup.Returns(ddPostgreSQL).When.GetDialect;
  Dialect.Setup.Returns(':').When.GetParamPrefix;
  Dialect.Setup.Executes(procedure(Invocation: IInvocation) begin Invocation.Result := '"' + Invocation.Arguments[0].AsString + '"'; end).When.QuoteIdentifier(Arg.Any<string>);

  // Setup Mock Connection
  Conn := Mock<IDbConnection>.Create;
  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  
  Ctx := TDbContext.Create(Conn.Instance, Dialect.Instance);
  try
    Entity := TIntEntity.Create;
    Ctx.Entities<TIntEntity>.Add(Entity);
    Ctx.SaveChanges;
    Should(Entity.Id).Be(123);
  finally
    Ctx.Free;
  end;
end;

procedure TEntityIdReturnTests.Test_Int64_Id_Return;
begin
  TestIdAssignment<TInt64Entity>(Int64(9223372036854775807), 
    procedure(E: TInt64Entity)
    begin
      Should(E.Id).Be(9223372036854775807);
    end);
end;

procedure TEntityIdReturnTests.Test_IntType_Id_Return;
begin
  TestIdAssignment<TIntTypeEntity>(456, 
    procedure(E: TIntTypeEntity)
    begin
      Should(Integer(E.Id)).Be(456);
    end);
end;

procedure TEntityIdReturnTests.Test_TGUID_Id_Return;
var
  G: TGUID;
begin
  G := TGuid.Create('{D6A5D5A1-949B-4B7C-9F8A-E7C1D1B1B1B1}');
  TestIdAssignment<TGuidEntity>(TValue.From<TGUID>(G), 
    procedure(E: TGuidEntity)
    begin
      Should(IsEqualGUID(E.Id, G)).BeTrue;
    end);
end;

procedure TEntityIdReturnTests.Test_PropTGUID_Id_Return;
var
  G: TGUID;
begin
  G := TGuid.Create('{A1A1A1A1-B2B2-C3C3-D4D4-E5E5E5E5E5E5}');
  TestIdAssignment<TPropGuidEntity>(TValue.From<TGUID>(G), 
    procedure(E: TPropGuidEntity)
    begin
      Should(IsEqualGUID(E.Id.Value, G)).BeTrue;
    end);
end;

procedure TEntityIdReturnTests.Test_TUUID_Id_Return;
var
  G: TGUID;
  U: TUUID;
begin
  G := TGuid.Create('{B2B2B2B2-C3C3-D4D4-E5E5-F6F6F6F6F6F6}');
  U := G;
  
  // Test passing TGUID (common from DB driver) to TUUID property
  TestIdAssignment<TUUIDEntity>(TValue.From<string>(G.ToString), 
    procedure(E: TUUIDEntity)
    begin
      Should(E.Id.ToString).BeEquivalentTo(U.ToString);
    end);
end;

procedure TEntityIdReturnTests.Test_PropTUUID_Id_Return;
var
  G: TGUID;
  U: TUUID;
begin
  G := TGuid.Create('{C3C3C3C3-D4D4-E5E5-F6F6-A1A1A1A1A1A1}');
  U := G;
  
  TestIdAssignment<TPropUUIDEntity>(TValue.From<string>(G.ToString), 
    procedure(E: TPropUUIDEntity)
    begin
      Should(E.Id.Value.ToString).BeEquivalentTo(U.ToString);
    end);
end;

procedure TEntityIdReturnTests.Test_String_Id_Return;
begin
  TestIdAssignment<TStringEntity>('some-uuid-string', 
    procedure(E: TStringEntity)
    begin
      Should(E.Id).Be('some-uuid-string');
    end);
end;

end.
