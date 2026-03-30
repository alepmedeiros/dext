object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Dext Framework - Entity DataSet Demo'
  ClientHeight = 442
  ClientWidth = 886
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object DBGridProducts: TDBGrid
    Left = 0
    Top = 41
    Width = 886
    Height = 401
    Align = alClient
    DataSource = DataSource
    TabOrder = 0
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -12
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = []
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 886
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object DBNavigator: TDBNavigator
      Left = 8
      Top = 8
      Width = 240
      Height = 25
      DataSource = DataSource
      TabOrder = 0
    end
  end
  object DataSource: TDataSource
    Left = 320
    Top = 184
  end
end
