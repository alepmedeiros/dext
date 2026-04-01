unit Dext.EF.Design.Expert;

interface

uses
  System.SysUtils,
  System.Classes,
  ToolsAPI,
  Dext.Entity.DataProvider,
  Dext.EF.Design.Metadata;

type
  TDextModuleNotifier = class(TNotifierObject, IOTAModuleNotifier)
  public
    // IOTAModuleNotifier
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
  end;

  TDextIDENotifier = class(TNotifierObject, IOTAIDENotifier)
  public
    // IOTAIDENotifier
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var CanModify: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var CanCompile: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure BeforeCompile(const Project: IOTAProject; IsCodeInsigth: Boolean; var CanCompile: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean); overload;
  end;

procedure RegisterExpert;

implementation

var
  FNotifierIndex: Integer = -1;

procedure RegisterExpert;
begin
  if FNotifierIndex = -1 then
    FNotifierIndex := (BorlandIDEServices as IOTAServices).AddNotifier(TDextIDENotifier.Create);
end;

{ TDextModuleNotifier }

procedure TDextModuleNotifier.AfterSave;
var
  Module: IOTAModule;
  Editor: IOTAEditor;
  i, j: Integer;
  FormEditor: IOTAFormEditor;
  Component: IOTAComponent;
  Comp: TComponent;
begin
  // Get active module
  Module := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if Module = nil then Exit;

  // Refresh all TEntityDataProvider in all open forms
  // Refresh all TEntityDataProvider in all open forms
  for i := 0 to (BorlandIDEServices as IOTAModuleServices).ModuleCount - 1 do
  begin
    Module := (BorlandIDEServices as IOTAModuleServices).Modules[i];
    if Module = nil then Continue;
    
    for j := 0 to Module.GetModuleFileCount - 1 do
    begin
      Editor := Module.GetModuleFileEditor(j);
      if Supports(Editor, IOTAFormEditor, FormEditor) then
      begin
        // Iterate components in the form using RootComponent
        if Assigned(FormEditor.GetRootComponent) then
        begin
          for var k := 0 to FormEditor.GetRootComponent.GetComponentCount - 1 do
          begin
            Component := FormEditor.GetRootComponent.GetComponent(k);
            if Assigned(Component) then
            begin
              Comp := (Component as INTAComponent).GetComponent;
              if Comp is TEntityDataProvider then
              begin
                 RefreshProviderMetadata(TEntityDataProvider(Comp));
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TDextModuleNotifier.BeforeSave;
begin
end;

function TDextModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TDextModuleNotifier.Destroyed;
begin
end;

procedure TDextModuleNotifier.Modified;
begin
end;

procedure TDextModuleNotifier.ModuleRenamed(const NewName: string);
begin
end;

{ TDextIDENotifier }

procedure TDextIDENotifier.AfterCompile(Succeeded: Boolean);
begin
end;

procedure TDextIDENotifier.AfterCompile(Succeeded, IsCodeInsight: Boolean);
begin
end;

procedure TDextIDENotifier.BeforeCompile(const Project: IOTAProject; var CanCompile: Boolean);
begin
end;

procedure TDextIDENotifier.BeforeCompile(const Project: IOTAProject; IsCodeInsigth: Boolean; var CanCompile: Boolean);
begin
end;

procedure TDextIDENotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var CanModify: Boolean);
begin
  if (NotifyCode = ofnFileOpened) and SameText(ExtractFileExt(FileName), '.pas') then
  begin
    // Add module notifier if needed
  end;
end;

initialization

finalization
  if FNotifierIndex <> -1 then
    (BorlandIDEServices as IOTAServices).RemoveNotifier(FNotifierIndex);

end.
