unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.DBCtrls, Vcl.Grids,
  Vcl.DBGrids, Data.DB, Dext.Entity.DataSet, Dext.Entity.Attributes, Vcl.Buttons,
  Dext.Collections, Dext.Core.Activator;

type
//  Money = Currency;
  Money = Double;
  TStockItem = class
  private
    FId: Integer;
    FWarehouse: string;
    FQuantity: Double;
  public
    constructor Create(Id: Integer; const Warehouse: string; Qty: Double);
    [PK]
    property Id: Integer read FId write FId;
    property Warehouse: string read FWarehouse write FWarehouse;
    property Quantity: Double read FQuantity write FQuantity;
  end;

  [Table('products')]
  TProduct = class
  private
    FId: Integer;
    FDescription: string;
    FPrice: Money;
    FStock: IList<TStockItem>;
  public
    constructor Create(Id: Integer; const Description: string; Price: Money);
    destructor Destroy; override;

    [PK]
    property Id: Integer read FId write FId;
    [MaxLength(200), DisplayWidth(75)]
    property Description: string read FDescription write FDescription;
    property Price: Money read FPrice write FPrice;
    [Visible(False)]
    property Stock: IList<TStockItem> read FStock write FStock;
  end;

  TFormMain = class(TForm)
    PanelTop: TPanel;
    DBGridProducts: TDBGrid;
    DBNavigator: TDBNavigator;
    DataSource: TDataSource;
    DBGridDetail: TDBGrid;
    Splitter: TSplitter;
    DataSourceDetail: TDataSource;
    EntityDataSet1: TEntityDataSet;
    RealMasterDetailButton: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure RealMasterDetailButtonClick(Sender: TObject);
  private
    FDataSet: TEntityDataSet;
    FProducts: IList<TProduct>;
  end;

var
  FormMain: TFormMain;

implementation

uses
  MasterDetailForm;

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FDataSet := TEntityDataSet.Create(Self);
  DataSource.DataSet := FDataSet;
  DBGridProducts.DataSource := DataSource;

  FProducts := TCollections.CreateList<TProduct>(True);

  for var i := 0 to 99 do
  begin
    var LProduct := TProduct.Create(
      100 + i,
      'Product ' + IntToStr(i + 1),
      100.0 * (i + 1)
    );
    
    // Adicionando alguns itens de estoque para o mestre
    LProduct.Stock.Add(TStockItem.Create(i * 10 + 1, 'Warehouse A', (i + 1) * 10));
    LProduct.Stock.Add(TStockItem.Create(i * 10 + 2, 'Warehouse B', (i + 1) * 5));
    if i mod 2 = 0 then
    begin
      LProduct.Stock.Add(TStockItem.Create(i * 10 + 3, 'Warehouse C', (i + 1) * 15));
      LProduct.Stock.Add(TStockItem.Create(i * 10 + 4, 'Warehouse D', (i + 1) * 20));
    end;

    FProducts.Add(LProduct);
  end;

  // Carregando dados no DataSet
  FDataSet.Load(FProducts as IObjectList, TProduct);
  FDataSet.Open;

  // Vinculando o Detalhe nativamente via NestedDataSet
  DataSourceDetail.DataSet := (FDataSet.FieldByName('Stock') as TDataSetField).NestedDataSet;
end;

{ TStockItem }

constructor TStockItem.Create(Id: Integer; const Warehouse: string; Qty: Double);
begin
  inherited Create;
  FId := Id;
  FWarehouse := Warehouse;
  FQuantity := Qty;
end;

{ TProduct }

constructor TProduct.Create(Id: Integer; const Description: string; Price: Money);
begin
  inherited Create;
  FId := Id;
  FDescription := Description;
  FPrice := Price;
  FStock := TCollections.CreateList<TStockItem>(True);
end;

destructor TProduct.Destroy;
begin
  FStock := nil;
  inherited;
end;

procedure TFormMain.RealMasterDetailButtonClick(Sender: TObject);
begin
  with TFormMasterDetailReal.Create(Self) do
  try
    ShowModal;
  finally
    Free;
  end;
end;

initialization
  TActivator.RegisterDefault<IList<TStockItem>, TList<TStockItem>>;

end.
