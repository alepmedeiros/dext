program Dext.BasicAuthTest;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext.Web,
  Dext.Auth.BasicAuth,
  Dext.Web.Interfaces,
  Dext.Assertions,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Mocks in '..\Common\Dext.Web.Mocks.pas';

function MakeContext(const APath: string; const AHeaders: IDictionary<string, string> = nil): IHttpContext;
var
  Req: IHttpRequest;
  Res: IHttpResponse;
begin
  if Assigned(AHeaders) then
    Req := TMockHttpRequestWithHeaders.CreateWithHeaders('', AHeaders)
  else
    Req := TMockHttpRequest.Create('', 'GET', APath);

  // If headers were provided the path is still default '/api/test' - we create a new request with proper path
  if Assigned(AHeaders) then
  begin
    // Re-create with path set. TMockHttpRequestWithHeaders doesn't accept path yet,
    // so we cast and override via the parent constructor's FPath field via RTTI is complex.
    // Simpler: just use the factory method and pass path directly.
    // Since TMockHttpRequestWithHeaders.CreateWithHeaders takes only querystring,
    // we embed the path in the query string parsing... actually the mock reads path separately.
    // Let's just create context directly.
    Res := TMockHttpResponse.Create;
    Result := TMockFactory.CreateHttpContextWithHeaders('', AHeaders);
    // Override path using the request field - TMockHttpRequest stores FPath
    // FPath is private, but we can use RTTI or expose it via a property.
    // For now, cast to class and call the constructor path param via inherited.
    // The simplest solution: not use FPath directly, but pass path in constructor.
    Exit;
  end;

  Res := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(Req, Res);
end;

function MakeContextWithPath(const APath: string): IHttpContext;
var
  Req: TMockHttpRequest;
  Res: TMockHttpResponse;
begin
  Req := TMockHttpRequest.Create('', 'GET', APath);
  Res := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(Req, Res);
end;

function MakeContextWithPathAndAuth(const APath, AAuthHeader: string): IHttpContext;
var
  Headers: IDictionary<string, string>;
  Req: TMockHttpRequestWithHeaders;
  Res: TMockHttpResponse;
begin
  Headers := TCollections.CreateDictionary<string, string>;
  Headers.Add('Authorization', AAuthHeader);
  Req := TMockHttpRequestWithHeaders.CreateWithHeaders('', Headers);
  // Override path via field access - since FPath is private we use the constructor trick:
  // TMockHttpRequest.Create sets FPath in the passed APath parameter.
  // TMockHttpRequestWithHeaders.CreateWithHeaders calls inherited Create('', ...) setting FPath = '/api/test'
  // We need to expose path or patch the mock. Let's patch Dext.Web.Mocks instead to add a Path property.
  Res := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(Req, Res);
end;

procedure RunTests;
var
  App: IWebApplication;
  Pipeline: TRequestDelegate;
  Context: IHttpContext;
begin
  Writeln('🧪 Basic Auth Tests Starting...');

  App := TWebApplication.Create;

  // 1. Configure Basic Auth
  App.Builder.UseBasicAuthentication(
    'Test Realm',
    function(const Username, Password: string): Boolean
    begin
      Result := (Username = 'testuser') and (Password = 'testpass');
    end);

  // 2. Protected route
  App.Builder.MapGet('/protected', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.Write('Authorized access');
  end).RequireAuthorization;

  // 3. Public route
  App.Builder.MapGet('/public', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.Write('Public access');
  end);

  // 4. Build pipeline
  Pipeline := App.Builder.Unwrap.Build;

  // --- Scenario 1: Public endpoint, no credentials ---
  Writeln('Scenario 1: Public endpoint, no credentials (expect 200)');
  Context := MakeContextWithPath('/public');
  Pipeline(Context);
  Should(Context.Response.StatusCode).Be(200);  
  Writeln('  PASS');

  // --- Scenario 2: Protected endpoint, no credentials ---
  Writeln('Scenario 2: Protected endpoint, no credentials (expect 401)');
  Context := MakeContextWithPath('/protected');
  Pipeline(Context);  
  Should(Context.Response.StatusCode).Be(401);  
  Writeln('  PASS');

  // --- Scenario 3: Protected endpoint, valid credentials ---
  Writeln('Scenario 3: Protected endpoint, valid credentials (expect 200)');
  // testuser:testpass -> Base64 = dGVzdHVzZXI6dGVzdHBhc3M=
  Context := MakeContextWithPath('/protected');
  (Context.Request as TMockHttpRequest).GetHeaders.AddOrSetValue('Authorization', 'Basic dGVzdHVzZXI6dGVzdHBhc3M=');
  Pipeline(Context);
  Should(Context.Response.StatusCode).Be(200);
  Writeln('  PASS');

  // --- Scenario 4: Protected endpoint, wrong credentials ---
  Writeln('Scenario 4: Protected endpoint, wrong credentials (expect 401)');
  // user:wrong -> Base64 = dXNlcjp3cm9uZw==
  Context := MakeContextWithPath('/protected');
  (Context.Request as TMockHttpRequest).GetHeaders.AddOrSetValue('Authorization', 'Basic dXNlcjp3cm9uZw==');
  Pipeline(Context);
  Should(Context.Response.StatusCode).Be(401);
  Writeln('  PASS');

  Writeln('');
  Writeln('✅ All tests passed!');
end;

begin
  try
    SetConsoleCharSet;
    RunTests;
    Writeln('Press Enter to exit...');
    ConsolePause;
  except
    on E: Exception do
    begin
      Writeln('❌ TEST FAILED: ', E.ClassName, ': ', E.Message);
      ConsolePause;
    end;
  end;
end.
