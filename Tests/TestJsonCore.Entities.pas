unit TestJsonCore.Entities;

interface

uses
  Dext.Collections,
  Dext.Core.Activator,
  Dext.DI.Attributes,
  Dext.Types.UUID;

type
  {$M+}
  TPost = class
  private
    FId: Integer;
    FContent: string;
  public
    property Id: Integer read FId write FId;
    property Content: string read FContent write FContent;
  end;

  {$M+}
  IPosts = interface(IList<TPost>)
    ['{1B72FB92-7381-4DC6-B297-BCF2C6241E33}']
  end;
  {$M-}
  TPosts = class(TList<TPost>, IPosts)
  end;

  TThreadContent = class
  private
    FId: Integer;
    FName: string;
    FInternalPosts: IPosts;
    procedure SetPosts(const Value: IPosts);
  public
    constructor Create;
    destructor Destroy; override;
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Posts: IPosts read FInternalPosts write SetPosts;
  end;

  TEntityWithGuid = class
  private
    FId: TGUID;
    FName: string;
  public
    property Id: TGUID read FId write FId;
    property Name: string read FName write FName;
  end;

  TEntityWithUuid = class
  private
    FId: TUUID;
    FName: string;
  public
    property Id: TUUID read FId write FId;
    property Name: string read FName write FName;
  end;

  {$M+} IEntityWithUUIDList = interface(IList<TEntityWithUUID>)
  ['{EFB6D27D-E6E2-4B9D-9414-B61B1CC18D20}']
  end;
  TEntityWithUUIDList = class(TList<TEntityWithUUID>, IEntityWithUUIDList)
  end;
  {$M-}

implementation

constructor TThreadContent.Create;
begin
  FInternalPosts := TPosts.Create;
end;

destructor TThreadContent.Destroy;
begin
  inherited;
end;

procedure TThreadContent.SetPosts(const Value: IPosts);
begin
  FInternalPosts := Value;
end;

initialization
  TActivator.RegisterDefault<IPosts, TPosts>;
  TActivator.RegisterDefault<IEntityWithUUIDList, TEntityWithUUIDList>;

end.
