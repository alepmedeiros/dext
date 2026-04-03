object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Dext Framework - Entity DataSet Demo'
  ClientHeight = 442
  ClientWidth = 910
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
    Width = 904
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
    Width = 910
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
    Width = 910
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
    Width = 910
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
    Left = 48
    Top = 56
  end
  object DataSourceDetail: TDataSource
    Left = 48
    Top = 284
  end
  object EntityDataSet: TEntityDataSet
    TableName = 'order'
    DataProvider = EntityDataProvider
    EntityClassName = 'TOrder'
    Left = 464
    Top = 88
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
        '.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Sm' +
        'artTypes.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Fl' +
        'uentQuery.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Da' +
        'taSet.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.As' +
        'ync.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Sq' +
        'lGenerator.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Fl' +
        'uentMapping.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Da' +
        'taSet.NewFeatures.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Id' +
        'Return.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Nu' +
        'llableHydration.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Da' +
        'taSet.Export.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.De' +
        'faultValue.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.De' +
        'sign.Metadata.Tests.pas'
      
        'C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.Re' +
        'portedIssues.Tests.pas')
    Dialect = ddSQLite
    DebugMode = True
    EntitiesMetadata = <
      item
        EntityClassName = 'TStockItem'
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TProduct'
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
            Alignment = taLeftJustify
            DisplayWidth = 75
            Visible = True
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
          end>
      end
      item
        EntityClassName = 'TOrder'
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
          end>
      end
      item
        EntityClassName = 'TOrderItem'
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TUserTest'
        TableName = 'users'
        EntityUnitName = 'Dext.Entity.DataSet.Tests'
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
          end
          item
            Name = 'Name'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Score'
            MemberType = 'Double'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Active'
            MemberType = 'Boolean'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TProductTest'
        TableName = 'products'
        EntityUnitName = 'Dext.Entity.DataSet.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Name'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 100
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Description'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 500
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Price'
            MemberType = 'Currency'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Weight'
            MemberType = 'Double'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'StockQty'
            MemberType = 'Int64'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Active'
            MemberType = 'Boolean'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'CreatedAt'
            MemberType = 'TDateTime'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Photo'
            MemberType = 'TBytes'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TOrderItemTest'
        TableName = 'order_items'
        EntityUnitName = 'Dext.Entity.DataSet.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'OrderId'
            MemberType = 'Integer'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'ProductName'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 100
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Quantity'
            MemberType = 'Integer'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'UnitPrice'
            MemberType = 'Currency'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TOrderTest'
        TableName = 'orders_native'
        EntityUnitName = 'Dext.Entity.DataSet.Tests'
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
          end
          item
            Name = 'Items'
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
            Visible = True
          end>
      end
      item
        EntityClassName = 'TFloatingPointTest'
        TableName = 'floating_point'
        EntityUnitName = 'Dext.Entity.DataSet.Tests'
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
          end
          item
            Name = 'DoubleVal'
            MemberType = 'Double'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'CurrencyVal'
            MemberType = 'Currency'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TTestUser'
        TableName = 'Users'
        EntityUnitName = 'Dext.Entity.SqlGenerator.Tests'
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
          end
          item
            Name = 'Name'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'IsDeleted'
            MemberType = 'Boolean'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TProductFeaturesTest'
        TableName = 'products_feat'
        EntityUnitName = 'Dext.Entity.DataSet.NewFeatures.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Name'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = True
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 100
            Precision = 0
            Scale = 0
            DisplayLabel = 'Product Name'
            Alignment = taLeftJustify
            DisplayWidth = 50
            Visible = True
          end
          item
            Name = 'Price'
            MemberType = 'Double'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            DisplayLabel = 'Unit Price'
            Alignment = taLeftJustify
            DisplayWidth = 15
            Visible = True
          end>
      end
      item
        EntityClassName = 'TIntEntity'
        TableName = 'int_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Integer'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TInt64Entity'
        TableName = 'int64_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Int64'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TIntTypeEntity'
        TableName = 'inttype_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'IntType'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TGuidEntity'
        TableName = 'guid_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'TGUID'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TPropGuidEntity'
        TableName = 'propguid_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Prop'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TUUIDEntity'
        TableName = 'uuid_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'TUUID'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TPropUUIDEntity'
        TableName = 'propuuid_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'Prop'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TStringEntity'
        TableName = 'string_table'
        EntityUnitName = 'Dext.Entity.IdReturn.Tests'
        Members = <
          item
            Name = 'Id'
            MemberType = 'string'
            IsPrimaryKey = True
            IsRequired = False
            IsAutoInc = True
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TNullableHydrationEntity'
        TableName = 'nullable_entities'
        EntityUnitName = 'Dext.Entity.NullableHydration.Tests'
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
          end
          item
            Name = 'Name'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Age'
            MemberType = 'Nullable'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'UpdatedAt'
            MemberType = 'Nullable'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TExportProduct'
        TableName = 'export_products'
        EntityUnitName = 'Dext.Entity.DataSet.Export.Tests'
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
          end
          item
            Name = 'Name'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Category'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Price'
            MemberType = 'Double'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end>
      end
      item
        EntityClassName = 'TDefaultValueEntity'
        TableName = 'default_value_entities'
        EntityUnitName = 'Dext.Entity.DefaultValue.Tests'
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
          end
          item
            Name = 'Status'
            MemberType = 'string'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Age'
            MemberType = 'Integer'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
          end
          item
            Name = 'Score'
            MemberType = 'Nullable'
            IsPrimaryKey = False
            IsRequired = False
            IsAutoInc = False
            IsReadOnly = False
            MaxLength = 0
            Precision = 0
            Scale = 0
            Alignment = taLeftJustify
            DisplayWidth = 0
            Visible = True
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
