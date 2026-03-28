unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.DBCtrls, Vcl.Grids,
  Vcl.DBGrids, Data.DB, Dext.Entity.DataSet, Dext.Entity.Attributes, Vcl.Buttons,
  Dext.Collections;

type
//  Money = Currency;
  Money = Double;
  [Table('products')]
  TProduct = class
  private
    FId: Integer;
    FDescription: string;
    FPrice: Money;
  public
    constructor Create(Id: Integer; const Description: string; Price: Money);

    [PK]
    property Id: Integer read FId write FId;
    [MaxLength(100)]
    property Description: string read FDescription write FDescription;
    property Price: Money read FPrice write FPrice;
  end;

  TFormMain = class(TForm)
    PanelTop: TPanel;
    DBGridProducts: TDBGrid;
    DBNavigator: TDBNavigator;
    DataSource: TDataSource;
    EntityDataSet: TEntityDataSet;
    procedure FormCreate(Sender: TObject);
  private
    FDataSet: TEntityDataSet;
    FProducts: IList<TObject>;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FDataSet := TEntityDataSet.Create(Self);
  DataSource.DataSet := FDataSet;
  DBGridProducts.DataSource := DataSource;

  FProducts := TCollections.CreateList<TObject>(True);

  for var i := 0 to 99 do
  begin
    FProducts.Add(TProduct.Create(
      {Id}          100 + i,
      {Description} 'Product ' + IntToStr(i + 1),
      {Price}       100.0 * (i + 1)
    ));
  end;

  // Carregando dados no DataSet
  // TODO
  FDataSet.Load(FProducts, TProduct);
end;

{ TProduct }

constructor TProduct.Create(Id: Integer; const Description: string; Price:
  Money);
begin
  inherited Create;
  FId := Id;
  FDescription := Description;
  FPrice := Price;
end;

end.
