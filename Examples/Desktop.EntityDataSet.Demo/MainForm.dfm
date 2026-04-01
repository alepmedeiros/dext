object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Dext Framework - Entity DataSet Demo'
  ClientHeight = 442
  ClientWidth = 1129
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
    Width = 1123
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
    Width = 1129
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
    Width = 1129
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
    Width = 1129
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
    DataSet = EntityDataSet
    Left = 320
    Top = 184
  end
  object DataSourceDetail: TDataSource
    Left = 400
    Top = 300
  end
  object EntityDataSet: TEntityDataSet
    TableName = 'order'
    DataProvider = EntityDataProvider
    EntityClassName = 'TOrder'
    Left = 1040
    Top = 88
    object EntityDataSetId: TIntegerField
      Alignment = taLeftJustify
      FieldName = 'Id'
    end
    object EntityDataSetDate: TDateTimeField
      FieldName = 'Date'
    end
    object EntityDataSetCustomer: TWideStringField
      FieldName = 'Customer'
      Size = 255
    end
    object EntityDataSetDescription: TWideStringField
      DisplayWidth = 75
      FieldName = 'Description'
      Size = 200
    end
    object EntityDataSetPrice: TFloatField
      Alignment = taLeftJustify
      FieldName = 'Price'
    end
    object EntityDataSetStock: TStringField
      FieldName = 'Stock'
      Visible = False
      Size = 255
    end
  end
  object EntityDataProvider: TEntityDataProvider
    DatabaseConnection = FDConnection
    ModelUnits.Strings = (
      
        'C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Metadat' +
        'a.pas'
      
        'C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Editors' +
        '.pas'
      
        'C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Expert.' +
        'pas'
      
        'C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Preview' +
        '.pas'
      
        'C:\dev\Dext\DextRepository\Sources\Design\Dext.EF.Design.Registr' +
        'ation.pas'
      
        'C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\M' +
        'ainForm.pas'
      
        'C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\M' +
        'asterDetailForm.pas'
      'C:\dev\Dext\DextRepository\Sources\Data\Dext.Entity.DataSet.pas'
      
        'C:\dev\Dext\DextRepository\Sources\Data\Dext.Entity.DataProvider' +
        '.pas')
    Dialect = ddSQLite
    DebugMode = True
    Left = 1040
    Top = 160
  end
  object FDConnection: TFDConnection
    Params.Strings = (
      'DriverID=SQLite'
      
        'Database=C:\dev\Dext\DextRepository\Tests\Entity\TestData\dext_t' +
        'est.db')
    Connected = True
    LoginPrompt = False
    Left = 888
    Top = 160
  end
end
