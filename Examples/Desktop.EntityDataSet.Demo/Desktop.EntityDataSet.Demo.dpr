program Desktop.EntityDataSet.Demo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {FormMain},
  MasterDetailForm in 'MasterDetailForm.pas' {FormMasterDetailReal};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
