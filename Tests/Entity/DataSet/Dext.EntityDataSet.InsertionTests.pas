unit Dext.EntityDataSet.InsertionTests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Dext.Collections,
  Dext.Entity.DataSet;

type
  TUserTest = class
  private
    FId: Integer;
    FName: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  [TestFixture]
  TEntityDataSetInsertionTests = class
  private
    FEntityDataSet: TEntityDataSet;
    FItems: IList<TObject>;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;

    [Test]
    procedure Test_Insert_In_Middle_Should_Preserve_Order;
    [Test]
    procedure Test_Append_Should_Add_To_End;
  end;

implementation

{ TEntityDataSetInsertionTests }

procedure TEntityDataSetInsertionTests.Setup;
var
  U1, U2: TUserTest;
begin
  FItems := TCollections.CreateList<TObject>(True);
  
  U1 := TUserTest.Create;
  U1.Id := 1;
  U1.Name := 'User 1';
  FItems.Add(U1);
  
  U2 := TUserTest.Create;
  U2.Id := 3;
  U2.Name := 'User 3';
  FItems.Add(U2);
  
  FEntityDataSet := TEntityDataSet.Create(nil);
  FEntityDataSet.Load(FItems, TUserTest, False); // We own the list wrapper, not objects (list manages objects)
end;

procedure TEntityDataSetInsertionTests.Teardown;
begin
  FEntityDataSet.Free;
  FItems := nil; // IList with True (OwnsObjects) will free U1, U2
end;

procedure TEntityDataSetInsertionTests.Test_Insert_In_Middle_Should_Preserve_Order;
begin
  FEntityDataSet.First; // Posicionado no Id 1
  FEntityDataSet.Next;  // Posicionado no Id 3
  
  Assert.AreEqual(3, FEntityDataSet.FieldByName('Id').AsInteger, 'Not at User 3');
  
  FEntityDataSet.Insert; // Should insert BEFORE User 3
  FEntityDataSet.FieldByName('Id').AsInteger := 2;
  FEntityDataSet.FieldByName('Name').AsString := 'User 2';
  FEntityDataSet.Post;
  
  // Order should be 1, 2, 3
  FEntityDataSet.First;
  Assert.AreEqual(1, FEntityDataSet.FieldByName('Id').AsInteger, 'R1 mismatch');
  FEntityDataSet.Next;
  Assert.AreEqual(2, FEntityDataSet.FieldByName('Id').AsInteger, 'R2 mismatch (INSERTION FAILED TO STAY IN MIDDLE)');
  FEntityDataSet.Next;
  Assert.AreEqual(3, FEntityDataSet.FieldByName('Id').AsInteger, 'R3 mismatch');
end;

procedure TEntityDataSetInsertionTests.Test_Append_Should_Add_To_End;
begin
  FEntityDataSet.Append;
  FEntityDataSet.FieldByName('Id').AsInteger := 4;
  FEntityDataSet.FieldByName('Name').AsString := 'User 4';
  FEntityDataSet.Post;
  
  FEntityDataSet.Last;
  Assert.AreEqual(4, FEntityDataSet.FieldByName('Id').AsInteger, 'Append failed to go to end');
end;

initialization
  TDUnitX.RegisterTestFixture(TEntityDataSetInsertionTests);

end.
