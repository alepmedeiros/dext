unit MasterDetailForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.DBCtrls, Vcl.Grids,
  Vcl.DBGrids, Data.DB, Dext.Entity.DataSet, Dext.Entity.Attributes, Dext.Collections,
  Vcl.Buttons;

type
  [Table('order')]
  TOrder = class
  private
    FId: Integer;
    FDate: TDateTime;
    FCustomer: string;
  public
    [PK, DisplayLabel('Código')]
    property Id: Integer read FId write FId;
    [DisplayLabel('Data')]
    property Date: TDateTime read FDate write FDate;
    [DisplayLabel('Cliente'), DisplayWidth(100)]
    property Customer: string read FCustomer write FCustomer;
    constructor Create(AId: Integer; ACustomer: string);
  end;

  [Table('order_item')]
  TOrderItem = class
  private
    FId: Integer;
    FOrderId: Integer;
    FProduct: string;
    FQty: Integer;
  public
    [PK]
    property Id: Integer read FId write FId;
    [DisplayLabel('Pedido')]
    property OrderId: Integer read FOrderId write FOrderId;
    [DisplayLabel('Nome do Produto'), DisplayWidth(100)]
    property Product: string read FProduct write FProduct;
    [DisplayLabel('Quantidade')]
    property Qty: Integer read FQty write FQty;
    constructor Create(AId, AOrderId: Integer; AProduct: string; AQty: Integer);
  end;

  TFormMasterDetailReal = class(TForm)
    PanelTop: TPanel;
    PanelMaster: TPanel;
    PanelDetail: TPanel;
    DBGridMaster: TDBGrid;
    DBGridDetail: TDBGrid;
    Splitter: TSplitter;
    MasterDataSource: TDataSource;
    DetailDataSource: TDataSource;
    MasterDataSet: TEntityDataSet;
    DetailDataSet: TEntityDataSet;
    DBNavigatorMaster: TDBNavigator;
    DBNavigatorDetail: TDBNavigator;
    procedure FormCreate(Sender: TObject);
  private
    FOrders: IList<TOrder>;
    FItems: IList<TOrderItem>;
  public
  end;

implementation

{$R *.dfm}

procedure TFormMasterDetailReal.FormCreate(Sender: TObject);
begin
  // Dados de Exemplo
  FOrders := TCollections.CreateList<TOrder>(True);
  FItems := TCollections.CreateList<TOrderItem>(True);

  for var i := 1 to 5 do
  begin
    FOrders.Add(TOrder.Create(i * 100, 'Customer ' + i.ToString));
    for var j := 1 to 3 do
      FItems.Add(TOrderItem.Create(i * 1000 + j, i * 100, 'Product ' + (i * 10 + j).ToString, j * 2));
  end;

  // Configuração EDS Master
  MasterDataSet.Load<TOrder>(FOrders);
  MasterDataSet.Open;
  MasterDataSource.DataSet := MasterDataSet;

  // Configuração EDS Detalhe (Vínculo Real via MasterSource/MasterFields)
  DetailDataSet.Load<TOrderItem>(FItems);
  DetailDataSet.MasterSource := MasterDataSource;
  DetailDataSet.MasterFields := 'Id';
  DetailDataSet.IndexFieldNames := 'OrderId';
  DetailDataSet.Open;
  DetailDataSource.DataSet := DetailDataSet;
end;

{ TOrder }
constructor TOrder.Create(AId: Integer; ACustomer: string);
begin
  FId := AId;
  FDate := Now;
  FCustomer := ACustomer;
end;

{ TOrderItem }
constructor TOrderItem.Create(AId, AOrderId: Integer; AProduct: string; AQty: Integer);
begin
  FId := AId;
  FOrderId := AOrderId;
  FProduct := AProduct;
  FQty := AQty;
end;

end.
