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
  object Splitter: TSplitter
    AlignWithMargins = True
    Left = 3
    Top = 244
    Width = 880
    Height = 3
    Cursor = crVSplit
    Align = alTop
    ExplicitLeft = 0
    ExplicitTop = 241
    ExplicitWidth = 442
  end
  object DBGridProducts: TDBGrid
    Left = 0
    Top = 41
    Width = 886
    Height = 200
    Align = alTop
    DataSource = DataSource
    TabOrder = 0
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -12
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = []
  end
  object DBGridDetail: TDBGrid
    Left = 0
    Top = 250
    Width = 886
    Height = 192
    Align = alClient
    DataSource = DataSourceDetail
    TabOrder = 2
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
    object RealMasterDetailButton: TSpeedButton
      Left = 256
      Top = 8
      Width = 150
      Height = 25
      Caption = 'Real Master-Detail'
      OnClick = RealMasterDetailButtonClick
    end
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
  object DataSourceDetail: TDataSource
    Left = 400
    Top = 300
  end
  object EntityDataSet1: TEntityDataSet
    Left = 504
    Top = 120
  end
end
