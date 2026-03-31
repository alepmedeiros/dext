object FormMasterDetailReal: TFormMasterDetailReal
  Left = 0
  Top = 0
  Caption = 'Real Master-Detail  (MasterSource/MasterFields)'
  ClientHeight = 500
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object Splitter: TSplitter
    Left = 0
    Top = 241
    Width = 800
    Height = 3
    Cursor = crVSplit
    Align = alTop
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Caption = 'Independent DataSets'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 0
  end
  object PanelMaster: TPanel
    Left = 0
    Top = 41
    Width = 800
    Height = 200
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object DBNavigatorMaster: TDBNavigator
      Left = 0
      Top = 0
      Width = 800
      Height = 25
      DataSource = MasterDataSource
      Align = alTop
      TabOrder = 0
    end
    object DBGridMaster: TDBGrid
      Left = 0
      Top = 25
      Width = 800
      Height = 175
      Align = alClient
      DataSource = MasterDataSource
      TabOrder = 1
      TitleFont.Charset = DEFAULT_CHARSET
      TitleFont.Color = clWindowText
      TitleFont.Height = -12
      TitleFont.Name = 'Segoe UI'
      TitleFont.Style = []
    end
  end
  object PanelDetail: TPanel
    Left = 0
    Top = 244
    Width = 800
    Height = 256
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object DBNavigatorDetail: TDBNavigator
      Left = 0
      Top = 0
      Width = 800
      Height = 25
      DataSource = DetailDataSource
      Align = alTop
      TabOrder = 0
    end
    object DBGridDetail: TDBGrid
      Left = 0
      Top = 25
      Width = 800
      Height = 231
      Align = alClient
      DataSource = DetailDataSource
      TabOrder = 1
      TitleFont.Charset = DEFAULT_CHARSET
      TitleFont.Color = clWindowText
      TitleFont.Height = -12
      TitleFont.Name = 'Segoe UI'
      TitleFont.Style = []
    end
  end
  object MasterDataSource: TDataSource
    Left = 600
    Top = 100
  end
  object DetailDataSource: TDataSource
    Left = 600
    Top = 300
  end
  object MasterDataSet: TEntityDataSet
    Left = 680
    Top = 100
  end
  object DetailDataSet: TEntityDataSet
    Left = 680
    Top = 300
  end
end
