object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Dext Framework - Entity DataSet Demo'
  ClientHeight = 442
  ClientWidth = 960
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
    Width = 954
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
    Width = 960
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
    Width = 960
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
    Width = 960
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
    Left = 40
    Top = 160
  end
  object DataSourceDetail: TDataSource
    Left = 48
    Top = 284
  end
  object EntityDataSet: TEntityDataSet
    TableName = 'products'
    DataProvider = EntityDataProvider
    EntityClassName = 'TProduct'
    Active = True
    Left = 464
    Top = 88
    object EntityDataSetId: TIntegerField
      DisplayLabel = 'C'#243'digo'
      FieldName = 'Id'
      DisplayFormat = '#,##0.00'
    end
    object EntityDataSetDescription: TWideStringField
      DisplayLabel = 'Descri'#231#227'o'
      DisplayWidth = 75
      FieldName = 'Description'
      Size = 200
    end
    object EntityDataSetPrice: TCurrencyField
      DisplayLabel = 'Valor'
      FieldName = 'Price'
    end
  end
  object EntityDataProvider: TEntityDataProvider
    DatabaseConnection = FDConnection
    ModelUnits.Strings = (
      
        'C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\M' +
        'ainForm.pas'
      
        'C:\dev\Dext\DextRepository\Examples\Desktop.EntityDataSet.Demo\M' +
        'asterDetailForm.pas')
    Dialect = ddSQLite
    DebugMode = True
    EntitiesMetadata = <
      item
        EntityClassName = 'TStockItem'
        DisplayName = ''
        TableName = 'stock'
        EntityUnitName = 'MainForm'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'C'#243'digo #'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Warehouse'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Armazem'
            Alignment = taLeftJustify
            DisplayWidth = 100
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Quantity'
            MemberType = 'Double'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Quantidade'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end>
      end
      item
        EntityClassName = 'TProduct'
        DisplayName = ''
        TableName = 'products'
        EntityUnitName = 'MainForm'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'C'#243'digo'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Description'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 200
            Precision = 0
            Scale = 0
            DisplayLabel = 'Descri'#231#227'o'
            Alignment = taLeftJustify
            DisplayWidth = 75
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Price'
            MemberType = 'Money'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Valor'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = True
          end
          item
            Name = 'Stock'
            MemberType = 'IList'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = False
            IsCurrency = False
          end>
      end
      item
        EntityClassName = 'TOrder'
        DisplayName = ''
        TableName = 'order'
        EntityUnitName = 'MasterDetailForm'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'C'#243'digo'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Date'
            MemberType = 'TDateTime'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Data'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Customer'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Cliente'
            Alignment = taLeftJustify
            DisplayWidth = 100
            Visible = True
            IsCurrency = False
          end>
      end
      item
        EntityClassName = 'TOrderItem'
        DisplayName = ''
        TableName = 'order_item'
        EntityUnitName = 'MasterDetailForm'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'OrderId'
            MemberType = 'Integer'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Pedido'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Product'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Nome do Produto'
            Alignment = taLeftJustify
            DisplayWidth = 100
            Visible = True
            IsCurrency = False
          end
          item
            Name = 'Qty'
            MemberType = 'Integer'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Quantidade'
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
            IsCurrency = False
          end>
      end>
    Left = 464
    Top = 152
  end
  object FDConnection: TFDConnection
    Params.Strings = (
      'DriverID=SQLite'
      
        'Database=C:\dev\Dext\DextRepository\Tests\Entity\TestData\dext_t' +
        'est.db')
    Connected = True
    LoginPrompt = False
    Left = 352
    Top = 88
  end
end
