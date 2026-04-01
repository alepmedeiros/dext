{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Web.Binding.Tests;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Auth.Identity,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Entity.Attributes,
  Dext.Testing,
  Dext.Web.Interfaces,
  Dext.Web.ModelBinding;

type
  { Mocks }

  TMockHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FQuery: IStringDictionary;
    FHeaders: IStringDictionary;
    FRouteParams: TRouteValueDictionary;
  public
    constructor Create;
    function GetMethod: string;
    function GetPath: string;
    function GetQuery: IStringDictionary;
    function GetBody: TStream;
    function GetRouteParams: TRouteValueDictionary;
    function GetHeaders: IStringDictionary;
    function GetRemoteIpAddress: string;
    function GetHeader(const AName: string): string;
    function GetQueryParam(const AName: string): string;
    function GetCookies: IStringDictionary;
    function GetFiles: IFormFileCollection;
  end;

  TMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
  public
    constructor Create(ARequest: IHttpRequest);
    function GetRequest: IHttpRequest;
    function GetResponse: IHttpResponse;
    procedure SetResponse(const AValue: IHttpResponse);
    function GetServices: IServiceProvider;
    procedure SetServices(const AValue: IServiceProvider);
    function GetUser: IClaimsPrincipal;
    procedure SetUser(const AValue: IClaimsPrincipal);
    function GetItems: IDictionary<string, TValue>;
  end;

  { Test Models }

  TTestRecord = record
    [DefaultValue('John Doe')]
    Name: string;
    [DefaultValue(25)]
    Age: Integer;
    [DefaultValue('2024-01-01')]
    JoinDate: TDateTime;
  end;

  TTestClass = class
  private
    FName: string;
    FAge: Integer;
  public
    [DefaultValue('Jane Doe')]
    property Name: string read FName write FName;
    [DefaultValue(30)]
    property Age: Integer read FAge write FAge;
  end;

  TDummyController = class
    procedure Action([DefaultValue('Dext')] Name: string; [DefaultValue(100)] Score: Integer);
  end;

  [TestClass]
  TWebBindingTests = class
  private
    FBinder: IModelBinder;
    function CreateMockContext(AQueryParams: TArray<string> = []): IHttpContext;
  public
    [Setup]
    procedure Setup;
    
    [Test]
    procedure Test_BindParameter_With_DefaultValue;
    
    [Test]
    procedure Test_BindRecord_Hybrid_With_DefaultValue;

    [Test]
    procedure Test_BindQuery_Class_With_DefaultValue;
  end;

implementation

{ TMockHttpRequest }

constructor TMockHttpRequest.Create;
begin
  inherited;
  FQuery := TDextStringDictionary.Create;
  FHeaders := TDextStringDictionary.Create;
  FRouteParams.Clear;
end;

function TMockHttpRequest.GetBody: TStream; begin Result := nil; end;
function TMockHttpRequest.GetCookies: IStringDictionary; begin Result := nil; end;
function TMockHttpRequest.GetFiles: IFormFileCollection; begin Result := nil; end;
function TMockHttpRequest.GetHeader(const AName: string): string; begin if not FHeaders.TryGetValue(AName, Result) then Result := ''; end;
function TMockHttpRequest.GetHeaders: IStringDictionary; begin Result := FHeaders; end;
function TMockHttpRequest.GetMethod: string; begin Result := 'GET'; end;
function TMockHttpRequest.GetPath: string; begin Result := '/'; end;
function TMockHttpRequest.GetQuery: IStringDictionary; begin Result := FQuery; end;
function TMockHttpRequest.GetQueryParam(const AName: string): string; begin if not FQuery.TryGetValue(AName, Result) then Result := ''; end;
function TMockHttpRequest.GetRemoteIpAddress: string; begin Result := '127.0.0.1'; end;
function TMockHttpRequest.GetRouteParams: TRouteValueDictionary; begin Result := FRouteParams; end;

{ TMockHttpContext }

constructor TMockHttpContext.Create(ARequest: IHttpRequest);
begin
  inherited Create;
  FRequest := ARequest;
end;

function TMockHttpContext.GetItems: IDictionary<string, TValue>; begin Result := nil; end;
function TMockHttpContext.GetRequest: IHttpRequest; begin Result := FRequest; end;
function TMockHttpContext.GetResponse: IHttpResponse; begin Result := nil; end;
function TMockHttpContext.GetServices: IServiceProvider; begin Result := nil; end;
function TMockHttpContext.GetUser: IClaimsPrincipal; begin Result := nil; end;
procedure TMockHttpContext.SetResponse(const AValue: IHttpResponse); begin end;
procedure TMockHttpContext.SetUser(const AValue: IClaimsPrincipal); begin end;
procedure TMockHttpContext.SetServices(const AValue: IServiceProvider); begin end;

{ TDummyController }

procedure TDummyController.Action(Name: string; Score: Integer); begin end;

{ TWebBindingTests }

procedure TWebBindingTests.Setup;
begin
  FBinder := TModelBinder.Create;
end;

function TWebBindingTests.CreateMockContext(AQueryParams: TArray<string>): IHttpContext;
var
  Req: TMockHttpRequest;
  I: Integer;
begin
  Req := TMockHttpRequest.Create;
  I := 0;
  while I < Length(AQueryParams) do
  begin
    Req.FQuery.Add(AQueryParams[I], AQueryParams[I+1]);
    Inc(I, 2);
  end;
  Result := TMockHttpContext.Create(Req);
end;

procedure TWebBindingTests.Test_BindParameter_With_DefaultValue;
var
  Context: IHttpContext;
  Val: TValue;
  Ctx: TRttiContext;
  Meth: TRttiMethod;
  Param: TRttiParameter;
begin
  Context := CreateMockContext([]); // Empty query
  Meth := Ctx.GetType(TDummyController).GetMethod('Action');
  
  // Param 1: Name
  Param := Meth.GetParameters[0];
  Val := FBinder.BindParameter(Param, Context);
  Should(Val.AsString).Be('Dext');
  
  // Param 2: Score
  Param := Meth.GetParameters[1];
  Val := FBinder.BindParameter(Param, Context);
  Should(Val.AsInteger).Be(100);
  
  // Now with values in query
  Context := CreateMockContext(['Name', 'NewName', 'Score', '200']);
  
  Param := Meth.GetParameters[0];
  Val := FBinder.BindParameter(Param, Context);
  Should(Val.AsString).Be('NewName');
  
  // Actually, for query parameters it uses lowercase typically or exact match?
  // Our model binding currently seems to match case as found in earlier conversation fixes.
  
  Param := Meth.GetParameters[1];
  Val := FBinder.BindParameter(Param, Context);
  Should(Val.AsInteger).Be(200);
end;

procedure TWebBindingTests.Test_BindRecord_Hybrid_With_DefaultValue;
var
  Context: IHttpContext;
  Rec: TTestRecord;
begin
  Context := CreateMockContext([]); // Empty
  
  Rec := FBinder.BindRecordHybrid(TypeInfo(TTestRecord), Context).AsType<TTestRecord>;
  
  Should(Rec.Name).Be('John Doe');
  Should(Rec.Age).Be(25);
  Should(FormatDateTime('yyyy-mm-dd', Rec.JoinDate)).Be('2024-01-01');
end;

procedure TWebBindingTests.Test_BindQuery_Class_With_DefaultValue;
var
  Context: IHttpContext;
  Obj: TTestClass;
begin
  Context := CreateMockContext([]); // Empty
  
  Obj := TModelBinderHelper.BindQuery<TTestClass>(FBinder, Context);
  try
    Should(Obj.Name).Be('Jane Doe');
    Should(Obj.Age).Be(30);
  finally
    Obj.Free;
  end;
end;

end.
