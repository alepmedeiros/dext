unit Dext.Entity.DataSet.NewFeatures.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Dext.Testing,
  Dext.Entity.DataSet,
  Dext.Entity.Attributes,
  Dext.Collections;

type
  [Table('products_feat')]
  TProductFeaturesTest = class
  private
    FId: Integer;
    FName: string;
    FPrice: Double;
  public
    [PrimaryKey, AutoInc]
    property Id: Integer read FId write FId;

    [Required, MaxLength(100), DisplayWidth(50), DisplayLabel('Product Name')]
    property Name: string read FName write FName;

    [DisplayWidth(15), DisplayLabel('Unit Price')]
    property Price: Double read FPrice write FPrice;
  end;

  // Hacker para o TDataLink (permitir acesso a membros publicos/protegidos)
  TMyDataLink = class(TDataLink)
  public
    property ActiveRecord;
    property BufferCount;
  end;

  [TestFixture('TEntityDataSet New Features')]
  TEntityDataSetFeaturesTests = class
  private
    FDataSet: TEntityDataSet;
    procedure DoPrepareField(Sender: TObject; AField: TField);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_DisplayAttributes_Mapping;
    [Test]
    procedure Test_OnPrepareField_Event;
    [Test]
    procedure Test_Grid_Painting_Simulation_MultiBuffer;
  end;

implementation

{ TEntityDataSetFeaturesTests }

procedure TEntityDataSetFeaturesTests.Setup;
begin
  FDataSet := TEntityDataSet.Create(nil);
end;

procedure TEntityDataSetFeaturesTests.TearDown;
begin
  FDataSet.Free;
end;

procedure TEntityDataSetFeaturesTests.DoPrepareField(Sender: TObject; AField: TField);
begin
  if AField.FieldName = 'Name' then
    AField.ReadOnly := True;
end;

procedure TEntityDataSetFeaturesTests.Test_DisplayAttributes_Mapping;
var
  LList: IList<TProductFeaturesTest>;
  FldName, FldPrice: TField;
begin
  LList := TCollections.CreateList<TProductFeaturesTest>;
  FDataSet.Load<TProductFeaturesTest>(LList);
  
  FldName := FDataSet.FindField('Name');
  FldPrice := FDataSet.FindField('Price');
  
  Should(FldName).NotBeNil;
  Should(FldName.DisplayWidth).Be(50);
  Should(FldName.DisplayLabel).Be('Product Name');
  
  Should(FldPrice).NotBeNil;
  Should(FldPrice.DisplayWidth).Be(15);
  Should(FldPrice.DisplayLabel).Be('Unit Price');
end;

procedure TEntityDataSetFeaturesTests.Test_OnPrepareField_Event;
var
  LList: IList<TProductFeaturesTest>;
begin
  LList := TCollections.CreateList<TProductFeaturesTest>;
  FDataSet.OnPrepareField := DoPrepareField;
  
  FDataSet.Load<TProductFeaturesTest>(LList);
  
  Should(FDataSet.FieldByName('Name').ReadOnly).BeTrue;
  Should(FDataSet.FieldByName('Price').ReadOnly).BeFalse;
end;

procedure TEntityDataSetFeaturesTests.Test_Grid_Painting_Simulation_MultiBuffer;
var
  L: IList<TProductFeaturesTest>;
  LDataSource: TDataSource;
  LDataLink: TMyDataLink;
  P1, P2: TProductFeaturesTest;
begin
  L := TCollections.CreateList<TProductFeaturesTest>(True);
  P1 := TProductFeaturesTest.Create;
  P1.Id := 1; P1.Name := 'Product 1';
  P2 := TProductFeaturesTest.Create;
  P2.Id := 2; P2.Name := 'Product 2';
  L.Add(P1);
  L.Add(P2);

  FDataSet.Load<TProductFeaturesTest>(L);
  FDataSet.Open;

  LDataSource := TDataSource.Create(nil);
  LDataLink := TMyDataLink.Create;
  try
    LDataSource.DataSet := FDataSet;
    LDataLink.DataSource := LDataSource;
    
    // Simula a Grid tendo espaco para buffers (BufferCount > 1)
    LDataLink.BufferCount := 5;

    // 1. Dataset posicionado no primeiro registro (FCurrentRec = 0)
    FDataSet.First;
    Should(FDataSet.FieldByName('Id').AsInteger).Be(1);
    Should(LDataLink.ActiveRecord).Be(0);

    // 2. SIMULACAO DA GRID PINTANDO A SEGUNDA LINHA:
    // A Grid seta o ActiveRecord do DataLink como 1.
    // Isso dispara o mecanismo interno do TDataSet (via unit Data.DB) 
    // que aponta o ActiveBuffer para o segundo buffer da lista.
    LDataLink.ActiveRecord := 1;

    // 3. VALIDACAO DA CORRECAO:
    // O TEntityDataSet deve ler o BookmarkIndex contido no ActiveBuffer (que agora eh 1),
    // e retornar o valor do segundo objeto ('Product 2'), 
    // mesmo que globalmente o cursor ainda esteja em First (0).
    Should(FDataSet.FieldByName('Id').AsInteger).Be(2).Because('O Dataset deve respeitar o buffer alternativo setado pela Grid/DataLink');
    Should(FDataSet.FieldByName('Name').AsString).Be('Product 2');

    // 4. Volta para o indice 0 para confirmar restauracao do contexto
    LDataLink.ActiveRecord := 0;
    Should(FDataSet.FieldByName('Id').AsInteger).Be(1);

  finally
    LDataLink.Free;
    LDataSource.Free;
  end;
end;

end.
