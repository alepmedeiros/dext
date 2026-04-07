unit Dext.Dashboard.Routes;

interface

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  Dext.Json,
  Dext.Json.Types,
  System.Types,
  Dext.DI.Interfaces,
  Dext.Dashboard.TestScanner,
  Dext.Dashboard.TestRunner,
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  Dext.DI.Core,
  Dext.Web.Interfaces,
  Dext.Web.Routing,
  Dext.Web.Results,
  Dext.Web.StaticFiles,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Extensions,
  // Note: These dependencies suggest the dashboard logic is tightly coupled with CLI infrastructure for now.
  // Ideally these should be moved to a shared Dext.Dashboard namespace in the future.
  Dext.Hosting.CLI.Hubs.Dashboard,
  Dext.Hosting.CLI.Registry,
  Dext.Hosting.CLI.Config,
  Dext.Hosting.CLI.Tools.CodeCoverage,
  Dext.Http.Parser,
  Dext.Http.Executor,
  Dext.Http.Request;

type
  TDashboardRoutes = class
  public
    class procedure Configure(App: IApplicationBuilder);
  end;

  THttpHistoryItem = class
  public
    Id: string;
    Method: string;
    Url: string;
    StatusCode: Integer;
    DurationMs: Int64;
    Timestamp: TDateTime;
    Content: string; // The .http content used
  end;

var
  FHttpHistory: IList<THttpHistoryItem>;

implementation

uses
  Dext.Web.Indy, // Access to TDextIndyHttpContext
  IdContext,     // Access to TIdContext
  IdGlobal;      // Access to ToBytes/IndyTextEncoding_UTF8

var
  FSSEClients: IList<IHttpContext>;
  FLock: TObject;

procedure BroadcastSSE(const EventName, Data: string); forward;

{$R 'Dext.Dashboard.res'}

{ TDashboardRoutes }

class procedure TDashboardRoutes.Configure(App: IApplicationBuilder);
begin
  // Map SignalR/WebSocket Hub
  THubExtensions.MapHub(App, '/hubs/dashboard', TDashboardHub);

  // Serve embedded dashboard HTML/CSS/JS
  App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
    var
      Path, ResName, CT: string;
      RS: TResourceStream;
    begin
      Path := Ctx.Request.Path;
      ResName := '';
      CT := '';

      if (Path = '/') or (Path = '/index.html') then
      begin
        ResName := 'MAIN_HTML';
        CT := 'text/html; charset=utf-8';
      end
      else if Path = '/main.css' then
      begin
        ResName := 'MAIN_CSS';
        CT := 'text/css; charset=utf-8';
      end
      else if Path = '/main.js' then
      begin
        ResName := 'MAIN_JS';
        CT := 'text/javascript; charset=utf-8';
      end
      else if Path = '/i18n.js' then
      begin
        ResName := 'I18N_JS';
        CT := 'text/javascript; charset=utf-8';
      end;

      if ResName <> '' then
      begin
        Ctx.Response.SetContentType(CT);
        RS := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
        try
          Ctx.Response.SetContentLength(RS.Size);
          Ctx.Response.Write(RS);
        finally
          RS.Free;
        end;
        Exit;
      end;
      
      Next(Ctx);
    end);

  // Serve Test Reports
  App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
    var
      Path, ReportPath, FilePath, CT: string;
      CP: TContentTypeProvider;
      FS: TFileStream;
    begin
      Path := Ctx.Request.Path;
      if Path.StartsWith('/reports/', True) or (Path = '/reports') then
      begin
         if Path = '/reports' then 
         begin
           Ctx.Response.StatusCode := 302;
           Ctx.Response.AddHeader('Location', '/reports/CodeCoverage_Summary.html');
           Exit;
         end;
         
         ReportPath := TPath.GetFullPath('TestOutput\report');
         if TDirectory.Exists(ReportPath) then
         begin
             FilePath := TPath.Combine(ReportPath, Path.Substring(9)); 
             
             if FileExists(FilePath) then
             begin
                 CP := TContentTypeProvider.Create;
                 try
                    if not CP.TryGetContentType(FilePath, CT) then CT := 'application/octet-stream';
                 finally
                    CP.Free;
                 end;
                 
                 Ctx.Response.SetContentType(CT);
                 FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
                 try
                    Ctx.Response.SetContentLength(FS.Size);
                    Ctx.Response.Write(FS);
                 finally
                    FS.Free;
                 end;
                 Exit;
             end;
         end;
      end;
      
      Next(Ctx);
    end);

  // API: Test Summary
  App.MapGet('/api/test/summary',
    procedure(Ctx: IHttpContext)
    var
      ReportDir, SummaryFile: string;
      Res: IResult;
      Content: string;
      P1, P2: Integer;
      Coverage: string;
    begin
       ReportDir := TPath.GetFullPath('TestOutput\report');
       SummaryFile := TPath.Combine(ReportDir, 'CodeCoverage_Summary.xml');
       
       if FileExists(SummaryFile) then
       begin
          Content := TFile.ReadAllText(SummaryFile);
          P1 := Content.IndexOf('percent="');
          if P1 > 0 then
          begin
             Inc(P1, 9);
             P2 := Content.IndexOf('"', P1);
             if P2 > P1 then
             begin
                Coverage := Content.Substring(P1, P2 - P1);
                Res := Results.Ok('{"available": true, "coverage": ' + Coverage.Replace(',', '.') + '}');
                Res.Execute(Ctx);
                Exit;
             end;
          end;
       end;
       
       Res := Results.Ok('{"available": false}');
       Res.Execute(Ctx);
    end);
    
  // API: HTTP Client - History
  App.MapGet('/api/http/history',
    procedure(Ctx: IHttpContext)
    var
      Res: IResult;
      Arr: IDextJsonArray;
      Item: THttpHistoryItem;
      Obj: IDextJsonObject;
    begin
      if FHttpHistory = nil then
      begin
        Res := Results.Ok('[]');
        Res.Execute(Ctx);
        Exit;
      end;

      Arr := TDextJson.Provider.CreateArray;
      TMonitor.Enter(TObject(FHttpHistory));
      try
        for Item in FHttpHistory do
        begin
          Obj := TDextJson.Provider.CreateObject;
          Obj.SetString('id', Item.Id);
          Obj.SetString('method', Item.Method);
          Obj.SetString('url', Item.Url);
          Obj.SetInteger('statusCode', Item.StatusCode);
          Obj.SetInt64('durationMs', Item.DurationMs);
          Obj.SetString('timestamp', DateToISO8601(Item.Timestamp));
          // Don't send full content to list to save bandwidth, maybe logic to fetch detail later?
          // For now send it, text is small.
          Obj.SetString('content', Item.Content);
          Arr.Add(Obj);
        end;
      finally
        TMonitor.Exit(TObject(FHttpHistory));
      end;
      
      Res := Results.Json(Arr.ToJson);
      Res.Execute(Ctx);
    end);
    
  // API: Projects
  App.MapGet('/api/projects', 
    procedure(Ctx: IHttpContext)
    var
      Registry: TProjectRegistry;
      Projects: TArray<TProjectInfo>;
      SB: TStringBuilder;
      I: Integer;
      EscapedPath, EscapedName: string;
      Res: IResult;
    begin
       Registry := Ctx.Services.GetRequiredService(TProjectRegistry) as TProjectRegistry;
       Projects := Registry.GetAllProjects;
       
       SB := TStringBuilder.Create;
       try
         SB.Append('[');
         for I := 0 to High(Projects) do
         begin
           if I > 0 then SB.Append(',');
           EscapedPath := Projects[I].Path.Replace('\', '\\').Replace('"', '\"');
           EscapedName := Projects[I].Name.Replace('\', '\\').Replace('"', '\"');
           
           SB.Append('{');
           SB.Append('"path":"').Append(EscapedPath).Append('",');
           SB.Append('"name":"').Append(EscapedName).Append('",');
           SB.Append('"lastAccess":"').Append(DateToISO8601(Projects[I].LastAccess)).Append('"');
           SB.Append('}');
         end;

         SB.Append(']');
         Res := Results.Text(SB.ToString, 200);
         Res.Execute(Ctx);
       finally
         SB.Free;
       end;
    end);

  // API: File System List
  App.MapGet('/api/fs/list',
    procedure(Ctx: IHttpContext)
    var
      ScanPath: string;
      Entries: TArray<string>;
      Entry: string;
      Arr: IDextJsonArray;
      Obj: IDextJsonObject;
      Res: IResult;
    begin
      if not Ctx.Request.Query.TryGetValue('path', ScanPath) then 
        ScanPath := '';
      if ScanPath = '' then ScanPath := 'C:\'; 
      
      if (Length(ScanPath) > 3) and ScanPath.EndsWith('\') then 
        ScanPath := ScanPath.Substring(0, Length(ScanPath)-1);
      
      try
        Arr := TDextJson.Provider.CreateArray;
        if TDirectory.Exists(ScanPath) then
        begin
          Entries := TDirectory.GetDirectories(ScanPath);
          for Entry in Entries do
          begin
            Obj := TDextJson.Provider.CreateObject;
            Obj.SetString('name', TPath.GetFileName(Entry));
            Obj.SetString('type', 'dir');
            Arr.Add(Obj);
          end;
          
          Entries := TDirectory.GetFiles(ScanPath);
          for Entry in Entries do
          begin
            Obj := TDextJson.Provider.CreateObject;
            Obj.SetString('name', TPath.GetFileName(Entry));
            Obj.SetString('type', 'file');
            Arr.Add(Obj);
          end;
        end;
        
        Res := Results.Json(Arr.ToJson);
        Res.Execute(Ctx);
      except
        on E: Exception do Results.BadRequest(E.Message).Execute(Ctx);
      end;
    end);

  // API: File System Read
  App.MapGet('/api/fs/read',
    procedure(Ctx: IHttpContext)
    var
      FilePath: string;
      Content: string;
    begin
      if not Ctx.Request.Query.TryGetValue('path', FilePath) then
        FilePath := '';
      if (FilePath = '') or not FileExists(FilePath) then
      begin
        Results.BadRequest('Valid file path required').Execute(Ctx);
        Exit;
      end;

      try
        Content := TFile.ReadAllText(FilePath, TEncoding.UTF8);
        Results.Text(Content, 200).Execute(Ctx);
      except
        on E: Exception do Results.InternalServerError(E.Message).Execute(Ctx);
      end;
    end);

  // API: Workspace Scan
  App.MapGet('/api/workspace/scan',
    procedure(Ctx: IHttpContext)
    var
       ScanPath: string;
       Projects, Tests, HttpFiles, Docs: IDextJsonArray;
       Files: TArray<string>;
       F: string;
       FinalObj: IDextJsonObject;
       Res: IResult;
    begin
       if not Ctx.Request.Query.TryGetValue('path', ScanPath) then
         ScanPath := '';
       if ScanPath = '' then 
       begin
          Results.BadRequest('Path required').Execute(Ctx);
          Exit;
       end;
       
       Projects := TDextJson.Provider.CreateArray;
       Tests := TDextJson.Provider.CreateArray;
       HttpFiles := TDextJson.Provider.CreateArray;
       Docs := TDextJson.Provider.CreateArray;
       
       try
          if TDirectory.Exists(ScanPath) then
          begin
              Files := TDirectory.GetFiles(ScanPath, '*.dproj', TSearchOption.soAllDirectories);
              for F in Files do Projects.Add(TPath.GetFileNameWithoutExtension(F));

              // Also scan for .dpr (console apps/tests that are not in dproj)
              Files := TDirectory.GetFiles(ScanPath, '*.dpr', TSearchOption.soAllDirectories);
              for F in Files do 
              begin
                 var Name := TPath.GetFileNameWithoutExtension(F);
                 // Avoid duplicates if dproj already found
                 var Found := False;
                 for var I := 0 to Projects.GetCount - 1 do
                   if Projects.GetString(I).Equals(Name) then
                   begin
                     Found := True;
                     Break;
                   end;
                 
                 if not Found then Projects.Add(Name);
              end;
              
              Files := TDirectory.GetFiles(ScanPath, '*.http', TSearchOption.soAllDirectories);
              for F in Files do HttpFiles.Add(TPath.GetFileName(F));
              
              // Scan for Test Projects (.dpr) instead of units (.pas)
              // Convention: Starts with "Test" or ends with "Tests"
              var TestFiles := TDirectory.GetFiles(ScanPath, 'Test*.dpr', TSearchOption.soAllDirectories);
              TestFiles := TestFiles + TDirectory.GetFiles(ScanPath, '*Tests.dpr', TSearchOption.soAllDirectories);
              
              for F in TestFiles do 
              begin
                 var Name := TPath.GetFileNameWithoutExtension(F);
                 // Avoid duplicates
                 var Found := False;
                 for var I := 0 to Tests.GetCount - 1 do
                   if (Tests.GetNode(I).GetNodeType = jntObject) and Tests.GetObject(I).GetString('name').Equals(Name) then
                   begin
                     Found := True;
                     Break;
                   end;
                 
                 if not Found then 
                 begin
                   var TestObj := TDextJson.Provider.CreateObject;
                   TestObj.SetString('name', Name);
                   TestObj.SetString('path', F);
                   Tests.Add(TestObj);
                 end;
              end;
          end;
          
          FinalObj := TDextJson.Provider.CreateObject;
          FinalObj.SetArray('projects', Projects);
          FinalObj.SetArray('tests', Tests);
          FinalObj.SetArray('httpFiles', HttpFiles);
          FinalObj.SetArray('docs', Docs);
          
          Res := Results.Json(FinalObj.ToJson);
          Res.Execute(Ctx);
       finally
       end;
    end);


  // API: Discover Tests in Project
  App.MapGet('/api/tests/discover',
    procedure(Ctx: IHttpContext)
    var
       ProjectPath: string;
       ProjectInfo: TTestProjectInfo;
       Fixture: TTestFixtureInfo;
       Method: TTestMethodInfo;
       
       ResJson, FixtureObj, MethodObj: IDextJsonObject;
       FixturesArr, MethodsArr: IDextJsonArray;
       Res: IResult;
    begin
       if not Ctx.Request.Query.TryGetValue('project', ProjectPath) then
         ProjectPath := '';
       
       if (ProjectPath = '') or not FileExists(ProjectPath) then
       begin
          Results.BadRequest('Valid project path required').Execute(Ctx);
          Exit;
       end;
       
       try
         ProjectInfo := TTestScanner.ScanProject(ProjectPath);
         try
            ResJson := TDextJson.Provider.CreateObject;
            ResJson.SetString('project', TPath.GetFileNameWithoutExtension(ProjectPath));
            ResJson.SetString('path', ProjectPath);
            
            FixturesArr := TDextJson.Provider.CreateArray;
            for Fixture in ProjectInfo.Fixtures do
            begin
                FixtureObj := TDextJson.Provider.CreateObject;
                FixtureObj.SetString('name', Fixture.Name);
                FixtureObj.SetString('unit', Fixture.UnitName);
                FixtureObj.SetInteger('line', Fixture.LineNumber);
                
                MethodsArr := TDextJson.Provider.CreateArray;
                for Method in Fixture.Methods do
                begin
                    MethodObj := TDextJson.Provider.CreateObject;
                    MethodObj.SetString('name', Method.Name);
                    MethodObj.SetInteger('line', Method.LineNumber);
                    MethodsArr.Add(MethodObj);
                end;
                FixtureObj.SetArray('tests', MethodsArr);
                
                FixturesArr.Add(FixtureObj);
            end;
            ResJson.SetArray('fixtures', FixturesArr);
            
            Res := Results.Json(ResJson.ToJson);
            Res.Execute(Ctx);
         finally
            ProjectInfo.Free;
         end;
       except
         on E: Exception do Results.StatusCode(500, E.Message).Execute(Ctx);
       end;
    end);
    
  // API: Get Config
  App.MapGet('/api/config',
    procedure(Ctx: IHttpContext)
    var
      Config: TDextGlobalConfig;
      Json, EnvObj: IDextJsonObject;
      Arr, PlatArr: IDextJsonArray;
      Res: IResult;
      Env: TDextEnvironment;
      P: string;
      CovPath: string;
    begin
      Config := TDextGlobalConfig.Create;
      try
        Config.Load;
        Json := TDextJson.Provider.CreateObject;
        
        Json.SetString('dextPath', Config.DextPath);
        if Config.DextPath.IsEmpty then Json.SetString('dextPath', ParamStr(0));
        
        CovPath := Config.CoveragePath;
        if (CovPath = '') then
           CovPath := TCodeCoverageTool.FindPath(Config, 'Win32');

        Json.SetString('coveragePath', CovPath);
        Json.SetString('configPath', TPath.Combine(TPath.Combine(TPath.GetHomePath, '.dext'), 'config.yaml'));
        
        Arr := TDextJson.Provider.CreateArray;
        for Env in Config.Environments do
        begin
          EnvObj := TDextJson.Provider.CreateObject;
          EnvObj.SetString('version', Env.Version);
          EnvObj.SetString('name', Env.Name);
          EnvObj.SetString('path', Env.Path);
          EnvObj.SetBoolean('isDefault', Env.IsDefault);
          
          PlatArr := TDextJson.Provider.CreateArray;
          for P in Env.Platforms do
            PlatArr.Add(P);
          EnvObj.SetArray('platforms', PlatArr);
          
          Arr.Add(EnvObj);
        end;
        Json.SetArray('environments', Arr);
        
        Res := Results.Json(Json.ToJson);
        Res.Execute(Ctx);
      finally
        Config.Free;
      end;
    end);

  // API: Save Config 
  App.MapPost('/api/config',
    procedure(Ctx: IHttpContext)
    var
      Body: string;
      Res: IResult;
      SR: TStreamReader;
      Node: IDextJsonNode;
      Json: IDextJsonObject;
      Config: TDextGlobalConfig;
    begin
      SR := TStreamReader.Create(Ctx.Request.Body);
      try
         Body := SR.ReadToEnd;
         try
           Node := TDextJson.Provider.Parse(Body);
           if (Node <> nil) and (Node.GetNodeType = jntObject) then
           begin
              Json := Node as IDextJsonObject;
              Config := TDextGlobalConfig.Create;
              try
                Config.Load;
                if Json.Contains('dextPath') then Config.DextPath := Json.GetString('dextPath');
                if Json.Contains('coveragePath') then Config.CoveragePath := Json.GetString('coveragePath');
                Config.Save;
                
                Res := Results.Ok('{"status":"saved"}');
              finally
                Config.Free;
              end;
           end
           else
             Res := Results.BadRequest('Invalid JSON or not an object');
         except
           on E: Exception do Res := Results.BadRequest('Invalid JSON: ' + E.Message);
         end;
            
         Res.Execute(Ctx);
      finally
         SR.Free;
      end;
    end);
    
  // API: Scan Environments
  App.MapPost('/api/env/scan',
    procedure(Ctx: IHttpContext)
    var
      Scanner: TDextGlobalConfig;
      Res: IResult;
    begin
       Scanner := TDextGlobalConfig.Create;
       try
         Scanner.ScanEnvironments;
         Res := Results.Ok('{"status":"ok"}');
         Res.Execute(Ctx);
       finally
         Scanner.Free;
       end;
    end);

  // API: Install Code Coverage
  App.MapPost('/api/tools/codecoverage/install',
    procedure(Ctx: IHttpContext)
    var
      Path: string;
      Res: IResult;
    begin
       try
         TCodeCoverageTool.InstallLatest(Path);
         Res := Results.Ok('{"status":"ok", "path": "' + Path.Replace('\', '\\') + '"}');
         Res.Execute(Ctx);
       except
         on E: Exception do
         begin
           Res := Results.StatusCode(500, Format('{"error": "%s"}', [E.Message.Replace('"', '\"')]));
           Res.Execute(Ctx);
         end;
       end;
    end);

  // API: Set Default Environment
  App.MapPost('/api/env/default',
    procedure(Ctx: IHttpContext)
    var
      Body, Ver: string;
      Res: IResult;
      SR: TStreamReader;
      Node: IDextJsonNode;
      Json: IDextJsonObject;
      Config: TDextGlobalConfig;
      I: Integer;
      Updated: Boolean;
      E: TDextEnvironment;
      NewState: Boolean;
    begin
      SR := TStreamReader.Create(Ctx.Request.Body);
      try
         Body := SR.ReadToEnd;
         try
           Node := TDextJson.Provider.Parse(Body);
           if (Node <> nil) and (Node.GetNodeType = jntObject) then
           begin
              Json := Node as IDextJsonObject;
              if Json.Contains('version') then
              begin
                Ver := Json.GetString('version');
                Config := TDextGlobalConfig.Create;
                try
                  Config.Load;
                  Updated := False;
                  for I := 0 to Config.Environments.Count - 1 do
                  begin
                     E := Config.Environments[I];
                     NewState := (E.Version = Ver);
                     if E.IsDefault <> NewState then
                     begin
                        E.IsDefault := NewState;
                        Config.Environments[I] := E; 
                        Updated := True;
                     end;
                  end;
                  
                  if Updated then Config.Save;
                  Res := Results.Ok('{"status":"updated"}');
                finally
                  Config.Free;
                end;
              end
              else
                Res := Results.BadRequest('Missing version field');
           end
           else
             Res := Results.BadRequest('Invalid JSON');
         except
           on E: Exception do Res := Results.BadRequest('Invalid JSON: ' + E.Message);
         end;
         Res.Execute(Ctx);
      finally
         SR.Free;
      end;
    end);

  // API: HTTP Client - Parse
  App.MapPost('/api/http/parse',
    procedure(Ctx: IHttpContext)
    var
      Body: string;
      Res: IResult;
      SR: TStreamReader;
      Node: IDextJsonNode;
      Json, ResJson, ReqObj, VarObj: IDextJsonObject;
      Collection: THttpRequestCollection;
      ReqArr, VarArr: IDextJsonArray;
      I: Integer;
    begin
      SR := TStreamReader.Create(Ctx.Request.Body);
      try
        Body := SR.ReadToEnd;
        try
          Node := TDextJson.Provider.Parse(Body);
          if (Node <> nil) and (Node.GetNodeType = jntObject) then
          begin
            Json := Node as IDextJsonObject;
            if Json.Contains('content') then
            begin
              Body := Json.GetString('content');
              Collection := THttpRequestParser.Parse(Body);
              try
                ResJson := TDextJson.Provider.CreateObject;
                ReqArr := TDextJson.Provider.CreateArray;
                for I := 0 to Collection.Requests.Count - 1 do
                begin
                  ReqObj := TDextJson.Provider.CreateObject;
                  ReqObj.SetString('name', Collection.Requests[I].Name);
                  ReqObj.SetString('method', Collection.Requests[I].Method);
                  ReqObj.SetString('url', Collection.Requests[I].Url);
                  ReqObj.SetInteger('lineNumber', Collection.Requests[I].LineNumber);
                  ReqObj.SetString('body', Collection.Requests[I].Body);
                  ReqArr.Add(ReqObj);
                end;
                ResJson.SetArray('requests', ReqArr);
                
                VarArr := TDextJson.Provider.CreateArray;
                for I := 0 to Collection.Variables.Count - 1 do
                begin
                  VarObj := TDextJson.Provider.CreateObject;
                  VarObj.SetString('name', Collection.Variables[I].Name);
                  VarObj.SetString('value', Collection.Variables[I].Value);
                  VarObj.SetBoolean('isEnvVar', Collection.Variables[I].IsEnvVar);
                  VarObj.SetString('envVarName', Collection.Variables[I].EnvVarName);
                  VarArr.Add(VarObj);
                end;
                ResJson.SetArray('variables', VarArr);
                
                Res := Results.Json(ResJson.ToJson);
              finally
                Collection.Free;
              end;
            end
            else
              Res := Results.BadRequest('Missing content field');
          end
          else
            Res := Results.BadRequest('Invalid JSON');
        except
          on E: Exception do Res := Results.BadRequest('Invalid JSON: ' + E.Message);
        end;
        Res.Execute(Ctx);
      finally
        SR.Free;
      end;
    end);

  // API: HTTP Client - Execute
  App.MapPost('/api/http/execute',
    procedure(Ctx: IHttpContext)
    var
      Body: string;
      Collection: THttpRequestCollection;
      ExResult: THttpExecutionResult;
      Node: IDextJsonNode;
      Json, ResJson, HeadersObj: IDextJsonObject;
      RequestIndex: Integer;
      Res: IResult;
      SR: TStreamReader;
    begin
      SR := TStreamReader.Create(Ctx.Request.Body);
      try
        Body := SR.ReadToEnd;
        try
          Node := TDextJson.Provider.Parse(Body);
          if (Node <> nil) and (Node.GetNodeType = jntObject) then
          begin
            Json := Node as IDextJsonObject;
            RequestIndex := 0;
            if Json.Contains('requestIndex') then RequestIndex := Json.GetInteger('requestIndex');
            
            if Json.Contains('content') then
            begin
              Body := Json.GetString('content');
              Collection := THttpRequestParser.Parse(Body);
              try
                if (RequestIndex >= 0) and (RequestIndex < Collection.Requests.Count) then
                begin
                  ExResult := THttpExecutor.ExecuteSync(Collection.Requests[RequestIndex], Collection.Variables);
                  
                  ResJson := TDextJson.Provider.CreateObject;
                  ResJson.SetString('requestName', ExResult.RequestName);
                  ResJson.SetString('requestMethod', ExResult.RequestMethod);
                  ResJson.SetString('requestUrl', ExResult.RequestUrl);
                  ResJson.SetInteger('statusCode', ExResult.StatusCode);
                  ResJson.SetString('statusText', ExResult.StatusText);
                  ResJson.SetString('responseBody', ExResult.ResponseBody);
                  ResJson.SetInt64('durationMs', ExResult.DurationMs);
                  ResJson.SetBoolean('success', ExResult.Success);
                  ResJson.SetString('errorMessage', ExResult.ErrorMessage);
                  
                  HeadersObj := TDextJson.Provider.CreateObject;
                  if ExResult.ResponseHeaders <> nil then
                    for var HdrKey in ExResult.ResponseHeaders.Keys do
                      HeadersObj.SetString(HdrKey, ExResult.ResponseHeaders[HdrKey]);
                  ResJson.SetObject('responseHeaders', HeadersObj);
                  
                  Res := Results.Json(ResJson.ToJson);
                  Res.Execute(Ctx);
                  
                  // Save to History
                  if FHttpHistory = nil then
                     FHttpHistory := TCollections.CreateList<THttpHistoryItem>(True);
                  
                  TMonitor.Enter(TObject(FHttpHistory));
                  try
                    var HistoryItem := THttpHistoryItem.Create;
                    HistoryItem.Id := TGUID.NewGuid.ToString;
                    HistoryItem.Method := Collection.Requests[RequestIndex].Method;
                    HistoryItem.Url := Collection.Requests[RequestIndex].Url;
                    HistoryItem.StatusCode := ExResult.StatusCode;
                    HistoryItem.DurationMs := ExResult.DurationMs;
                    HistoryItem.Timestamp := Now;
                    HistoryItem.Content := Body; 
                    
                    FHttpHistory.Insert(0, HistoryItem);
                    
                    // Limit to 50
                    while FHttpHistory.Count > 50 do
                      FHttpHistory.Delete(FHttpHistory.Count - 1);
                  finally
                    TMonitor.Exit(TObject(FHttpHistory));
                  end;
                end
                else
                  Results.BadRequest('Invalid request index').Execute(Ctx);
              finally
                Collection.Free;
              end;
            end
            else
              Results.BadRequest('Missing content field').Execute(Ctx);
          end
          else
            Results.BadRequest('Invalid JSON').Execute(Ctx);
        except
          on E: Exception do Results.BadRequest('Invalid JSON: ' + E.Message).Execute(Ctx);
        end;
      finally
        SR.Free;
      end;
    end);

  // API: Telemetry Logs Ingestion
  App.MapPost('/api/telemetry/logs',
    procedure(Ctx: IHttpContext)
    var
      Body: string;
      EventType: string;
      JO: IDextJsonObject;
      Node: IDextJsonNode;
      SR: TStreamReader;
      SseEvent: string;
    begin
      // Read logs
      SR := TStreamReader.Create(Ctx.Request.Body);
      try
        Body := SR.ReadToEnd;
        if Body.IsEmpty then
        begin
          Ctx.Response.StatusCode := 204; // No Content
          Exit;
        end;

        // ADAPTER: Telemetry to Dashboard
        try
          Node := TDextJson.Provider.Parse(Body);
          if (Node <> nil) and (Node.GetNodeType = jntObject) then
          begin
            JO := Node as IDextJsonObject;
            EventType := '';
            if JO.Contains('event') then EventType := JO.GetString('event');
                 
            SseEvent := '';
            if EventType = 'RunStart' then SseEvent := 'run_start'
            else if EventType = 'TestStart' then SseEvent := 'test_start'
            else if EventType = 'TestComplete' then SseEvent := 'test_complete'
            else if EventType = 'RunComplete' then SseEvent := 'run_complete';
            
            if SseEvent <> '' then
                 BroadcastSSE(SseEvent, JO.ToJson);
          end;
        except
          // Log parsing error but don't fail the request (telemetry ingestion often just accepts)
        end;
        
        Ctx.Response.StatusCode := 202; // Accepted
      finally
        SR.Free;
      end;
    end);

  // API: Run Tests
  App.MapPost('/api/tests/run',
    procedure(Ctx: IHttpContext)
    var
       Body: string;
       Node: IDextJsonNode;
       Json: IDextJsonObject;
       TestRunResult: IDextJsonObject;
       Project: string;
       SR: TStreamReader;
    begin
       SR := TStreamReader.Create(Ctx.Request.Body);
       try
         Body := SR.ReadToEnd;
       finally
         SR.Free;
       end;
 
       try
         Node := TDextJson.Provider.Parse(Body);
         if (Node = nil) or (Node.GetNodeType <> jntObject) then
         begin
            Results.BadRequest('Invalid JSON').Execute(Ctx);
            Exit;
         end;
         
         Json := Node as IDextJsonObject;
         if not Json.Contains('project') then
         begin
            Results.BadRequest('Missing "project" field').Execute(Ctx);
            Exit;
         end;
         
         Project := Json.GetString('project');
         TestRunResult := TTestRunner.RunProject(Project);
         if TestRunResult <> nil then
         begin
            Results.Json(TestRunResult.ToJson).Execute(Ctx);
         end
         else
         begin
            Results.InternalServerError('Failed to run tests (Result is nil)').Execute(Ctx);
         end;
       except
          on E: Exception do
            Results.InternalServerError(E.Message).Execute(Ctx);
       end;
    end);

  // API: SSE Events Endpoint (Fallback)
  App.MapGet('/events',
    procedure(Ctx: IHttpContext)
    var
      IndyCtx: TIdContext;
    begin
         IndyCtx := nil;
         if Ctx is TDextIndyHttpContext then
            IndyCtx := TDextIndyHttpContext(Ctx).Context;



         if IndyCtx <> nil then
         begin
             // Manually write headers to flush immediately
             IndyCtx.Connection.IOHandler.WriteLn('HTTP/1.1 200 OK');
             IndyCtx.Connection.IOHandler.WriteLn('Content-Type: text/event-stream; charset=utf-8');
             IndyCtx.Connection.IOHandler.WriteLn('Cache-Control: no-cache');
             IndyCtx.Connection.IOHandler.WriteLn('Connection: keep-alive');
             IndyCtx.Connection.IOHandler.WriteLn(''); // End of headers
             
             // Initial Handshake
             IndyCtx.Connection.IOHandler.Write('event: connected'#10'data: {"msg":"welcome"}'#10#10);
         end
         else
         begin
             // Fallback
             Ctx.Response.SetContentType('text/event-stream; charset=utf-8');
             Ctx.Response.AddHeader('Cache-Control', 'no-cache');
             Ctx.Response.AddHeader('Connection', 'keep-alive');
             Ctx.Response.Write('event: connected'#10'data: {"msg":"welcome"}'#10#10);
         end;
         
         // Add to active clients list
         TMonitor.Enter(FLock);
         try
            FSSEClients.Add(Ctx);

         finally
            TMonitor.Exit(FLock);
         end;
         
         // Keep connection open
         try
            while True do
            begin
               if (IndyCtx <> nil) and (not IndyCtx.Connection.Connected) then Break;
               Sleep(500); 
            end;
         finally
            TMonitor.Enter(FLock);
            try
               FSSEClients.Remove(Ctx);
            finally
               TMonitor.Exit(FLock);
            end;
         end;
    end);
    
end;

procedure BroadcastSSE(const EventName, Data: string);
var
  Ctx: IHttpContext;
  Msg: string;
  IndyCtx: TIdContext;
begin
  if (FSSEClients = nil) then Exit;

  TMonitor.Enter(FLock);
  try


    if FSSEClients.Count = 0 then Exit;

    Msg := Format('event: %s'#10'data: %s'#10#10, [EventName, Data]);
    
    // Iterate backwards so we can remove dead clients if needed (though we just ignore errors here)
    for Ctx in FSSEClients do
    begin
      try
        if Ctx is TDextIndyHttpContext then
        begin
           IndyCtx := TDextIndyHttpContext(Ctx).Context;
           if (IndyCtx <> nil) and (IndyCtx.Connection <> nil) and IndyCtx.Connection.Connected then
           begin
               IndyCtx.Connection.IOHandler.Write(ToBytes(Msg, IndyTextEncoding_UTF8));
           end;
        end;
      except
        // Handle disconnection?

      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

initialization
  FHttpHistory := TCollections.CreateList<THttpHistoryItem>(True);
  FSSEClients := TCollections.CreateList<IHttpContext>;
  FLock := TObject.Create;

finalization
  FLock.Free;
  FHttpHistory := nil;

end.

