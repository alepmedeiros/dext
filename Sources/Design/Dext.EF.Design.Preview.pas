unit Dext.EF.Design.Preview;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Grids,
  Vcl.DBGrids,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  Dext.Entity.DataSet,
  Dext.Entity.DataProvider,
  Dext.Entity.Core;

type
  TPreviewForm = class(TForm)
  private
    FGrid: TDBGrid;
    FDataSource: TDataSource;
    FQuery: TFDQuery;
    FPanel: TPanel;
    FCloseBtn: TButton;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Preview(ADataSet: TEntityDataSet);
  end;

procedure ShowEntityPreview(ADataSet: TEntityDataSet);

implementation

procedure ShowEntityPreview(ADataSet: TEntityDataSet);
var
  Form: TPreviewForm;
begin
  Form := TPreviewForm.Create(nil);
  try
    Form.Preview(ADataSet);
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

{ TPreviewForm }

constructor TPreviewForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Dext Entity Preview';
  Width := 800;
  Height := 600;
  Position := poScreenCenter;
  
  FPanel := TPanel.Create(Self);
  FPanel.Parent := Self;
  FPanel.Align := alBottom;
  FPanel.Height := 50;
  
  FCloseBtn := TButton.Create(Self);
  FCloseBtn.Parent := FPanel;
  FCloseBtn.Caption := 'Close';
  FCloseBtn.ModalResult := mrOk;
  FCloseBtn.Left := Width - 100;
  FCloseBtn.Top := 15;
  
  FGrid := TDBGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ReadOnly := True;
  
  FDataSource := TDataSource.Create(Self);
  FGrid.DataSource := FDataSource;
  
  FQuery := TFDQuery.Create(Self);
  FDataSource.DataSet := FQuery;
end;

procedure TPreviewForm.Preview(ADataSet: TEntityDataSet);
var
  DP: IEntityDataProvider;
  MD: TEntityClassMetadata;
  SQL: string;
begin
  if not Assigned(ADataSet.DataProvider) then
    raise Exception.Create('Provider is missing.');
    
  if not ADataSet.DataProvider.GetInterface(IEntityDataProvider, DP) then
    raise Exception.Create('Invalid Provider.');

  if ADataSet.EntityClassName = '' then
     raise Exception.Create('EntityClassName is missing.');

  MD := DP.GetEntityMetadata(ADataSet.EntityClassName);
  if MD = nil then
    raise Exception.Create('Entity metadata not found.');

  FQuery.Connection := ADataSet.DataProvider.DatabaseConnection;
  if FQuery.Connection = nil then
     raise Exception.Create('Connection is not assigned to Provider.');

  SQL := DP.BuildPreviewSql(ADataSet.EntityClassName, 50);
  if SQL = '' then
    SQL := 'SELECT * FROM ' + MD.TableName;

  FQuery.SQL.Text := SQL;
  FQuery.Open;
  
  Caption := 'Previewing: ' + MD.ClassName + ' (Table: ' + MD.TableName + ')';
end;

end.
