{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2026-01-20                                                      }
{                                                                           }
{***************************************************************************}

/// <summary>
/// Dext.UI.Navigator - Core Navigator implementation
///
/// This unit provides the main TNavigator class that implements INavigator.
/// Features:
/// - Navigation stack with history
/// - Middleware pipeline execution
/// - Route registration and guards
/// - View lifecycle management via adapters
/// </summary>
unit Dext.UI.Navigator;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Stack,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.UI.Navigator.Types,
  Dext.UI.Navigator.Interfaces;

type
  /// <summary>
  /// Route information stored in the registry
  /// </summary>
  TRouteInfo = record
    Path: string;
    ViewClass: TClass;
    RequiresAuth: Boolean;
    RequiredRoles: TArray<string>;
    Guards: IList<INavigationGuard>;
    Middlewares: IList<INavigationMiddleware>;
  end;

  /// <summary>
  /// Route builder implementation for fluent configuration
  /// </summary>
  TRouteBuilder = class(TInterfacedObject, IRouteBuilder)
  private
    FNavigator: INavigator;
    FPath: string;
    FRouteInfo: TRouteInfo;
  public
    constructor Create(const ANavigator: INavigator; const APath: string);
    
    function RequireAuth: IRouteBuilder;
    function RequireRole(const Role: string): IRouteBuilder;
    function UseGuard(const Guard: INavigationGuard): IRouteBuilder;
    function UseMiddleware(const Middleware: INavigationMiddleware): IRouteBuilder;
    function MapTo(ViewClass: TClass): IRouteBuilder;
    function Build: INavigator;
    
    property RouteInfo: TRouteInfo read FRouteInfo;
  end;

  /// <summary>
  /// Main Navigator implementation
  /// </summary>
  TNavigator = class(TInterfacedObject, INavigator)
  private
    FAdapter: INavigatorAdapter;
    FMiddlewares: IList<INavigationMiddleware>;
    FRoutes: IDictionary<string, TRouteInfo>;
    FHistory: IStack<THistoryEntry>;
    FServiceProvider: IServiceProvider;
    FOnNavigating: TProc<TNavigationContext>;
    FOnNavigated: TProc<TNavigationContext>;
    
    function GetRouteName(ViewClass: TClass): string;
    function CreateView(ViewClass: TClass): TObject;
    function FindRouteByClass(ViewClass: TClass): TRouteInfo;
    procedure ExecutePipeline(Context: TNavigationContext; 
      const Middlewares: IList<INavigationMiddleware>; Index: Integer; 
      FinalAction: TProc);
    procedure DoNavigation(Context: TNavigationContext);
    procedure NotifyNavigableView(View: TObject; const Params: TNavParams; Entering: Boolean);
    function CheckGuards(Context: TNavigationContext; const Guards: IList<INavigationGuard>): Boolean;
  public
    constructor Create; overload;
    constructor Create(const AServiceProvider: IServiceProvider); overload;
    destructor Destroy; override;
    
    // Route registration (internal, called by TRouteBuilder)
    procedure RegisterRoute(const Path: string; const RouteInfo: TRouteInfo);
    
    // INavigator - Navigation
    function Push(ViewClass: TClass): INavigator; overload;
    function Push(ViewClass: TClass; const Params: TNavParams): INavigator; overload;
    function PushNamed(const Route: string): INavigator; overload;
    function PushNamed(const Route: string; const Params: TNavParams): INavigator; overload;
    procedure Pop; overload;
    procedure Pop(const Result: TNavigationResult); overload;
    procedure PopUntil(ViewClass: TClass);
    function Replace(ViewClass: TClass): INavigator; overload;
    function Replace(ViewClass: TClass; const Params: TNavParams): INavigator; overload;
    function PopAndPush(ViewClass: TClass): INavigator; overload;
    function PopAndPush(ViewClass: TClass; const Params: TNavParams): INavigator; overload;
    
    // INavigator - Configuration  
    function UseAdapter(const Adapter: INavigatorAdapter): INavigator;
    function UseMiddleware(const Middleware: INavigationMiddleware): INavigator;
    function Route(const Path: string): IRouteBuilder;
    function SetInitialRoute(ViewClass: TClass): INavigator;
    
    // INavigator - State
    function CanGoBack: Boolean;
    function CurrentRoute: string;
    function CurrentView: TObject;
    function History: TArray<string>;
    function StackDepth: Integer;
    
    // INavigator - Events
    function OnNavigating(const Handler: TProc<TNavigationContext>): INavigator;
    function OnNavigated(const Handler: TProc<TNavigationContext>): INavigator;
  end;

implementation

uses
  Dext.Collections.Extensions;

{ TRouteBuilder }

constructor TRouteBuilder.Create(const ANavigator: INavigator; const APath: string);
begin
  inherited Create;
  FNavigator := ANavigator;
  FPath := APath;
  FRouteInfo.Path := APath;
  FRouteInfo.Guards := TCollections.CreateList<INavigationGuard>(True);
  FRouteInfo.Middlewares := TCollections.CreateList<INavigationMiddleware>(True);
end;

function TRouteBuilder.RequireAuth: IRouteBuilder;
begin
  FRouteInfo.RequiresAuth := True;
  Result := Self;
end;

function TRouteBuilder.RequireRole(const Role: string): IRouteBuilder;
begin
  SetLength(FRouteInfo.RequiredRoles, Length(FRouteInfo.RequiredRoles) + 1);
  FRouteInfo.RequiredRoles[High(FRouteInfo.RequiredRoles)] := Role;
  Result := Self;
end;

function TRouteBuilder.UseGuard(const Guard: INavigationGuard): IRouteBuilder;
begin
  FRouteInfo.Guards.Add(Guard);
  Result := Self;
end;

function TRouteBuilder.UseMiddleware(const Middleware: INavigationMiddleware): IRouteBuilder;
begin
  FRouteInfo.Middlewares.Add(Middleware);
  Result := Self;
end;

function TRouteBuilder.MapTo(ViewClass: TClass): IRouteBuilder;
begin
  FRouteInfo.ViewClass := ViewClass;
  Result := Self;
end;

function TRouteBuilder.Build: INavigator;
begin
  // Register route with navigator
  (FNavigator as TNavigator).RegisterRoute(FPath, FRouteInfo);
  Result := FNavigator;
end;

{ TNavigator }

constructor TNavigator.Create;
begin
  inherited Create;
  FMiddlewares := TCollections.CreateList<INavigationMiddleware>(True);
  FRoutes := TCollections.CreateDictionary<string, TRouteInfo>;
  FHistory := TCollections.CreateStack<THistoryEntry>;
end;

constructor TNavigator.Create(const AServiceProvider: IServiceProvider);
begin
  Create;
  FServiceProvider := AServiceProvider;
end;

destructor TNavigator.Destroy;
var
  Entry: THistoryEntry;
begin
  // Clean up history stack - free params
  while FHistory.Count > 0 do
  begin
    Entry := FHistory.Pop;
    if Assigned(Entry.Params) then
      Entry.Params.Free;
  end;
  
  // FHistory is ARC managed
  // FRoutes is ARC
  inherited;
end;

function TNavigator.GetRouteName(ViewClass: TClass): string;
begin
  // First check if there's a registered route for this class
  for var Key in FRoutes.Keys do
    if FRoutes[Key].ViewClass = ViewClass then
      Exit(Key);
      
  // Default: use class name as route
  Result := '/' + ViewClass.ClassName;
end;

function TNavigator.CreateView(ViewClass: TClass): TObject;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RttiMethod: TRttiMethod;
begin
  // Try to resolve from DI container first
  if Assigned(FServiceProvider) then
  begin
    // TODO: Add DI resolution when available
  end;
  
  // Fallback: Create via RTTI
  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(ViewClass);
    if RttiType = nil then
      raise Exception.CreateFmt('Cannot create view: %s not found', [ViewClass.ClassName]);
      
    // Look for parameterless constructor
    for RttiMethod in RttiType.GetMethods do
    begin
      if RttiMethod.IsConstructor and (Length(RttiMethod.GetParameters) = 0) then
      begin
        Result := RttiMethod.Invoke(ViewClass, []).AsObject;
        Exit;
      end;
    end;
    
    // Look for constructor with TComponent parameter (common for Forms/Frames)
    for RttiMethod in RttiType.GetMethods do
    begin
      if RttiMethod.IsConstructor and (Length(RttiMethod.GetParameters) = 1) then
      begin
        if RttiMethod.GetParameters[0].ParamType.Handle = TypeInfo(TComponent) then
        begin
          Result := RttiMethod.Invoke(ViewClass, [nil]).AsObject;
          Exit;
        end;
      end;
    end;
    
    raise Exception.CreateFmt('No suitable constructor found for: %s', [ViewClass.ClassName]);
  finally
    RttiContext.Free;
  end;
end;

function TNavigator.FindRouteByClass(ViewClass: TClass): TRouteInfo;
begin
  for var Key in FRoutes.Keys do
    if FRoutes[Key].ViewClass = ViewClass then
      Exit(FRoutes[Key]);
      
  // Return empty route info
  Result := Default(TRouteInfo);
  Result.ViewClass := ViewClass;
  Result.Path := GetRouteName(ViewClass);
  Result.Guards := TCollections.CreateList<INavigationGuard>(True);
  Result.Middlewares := TCollections.CreateList<INavigationMiddleware>(True);
end;

procedure TNavigator.ExecutePipeline(Context: TNavigationContext;
  const Middlewares: IList<INavigationMiddleware>; Index: Integer;
  FinalAction: TProc);
begin
  if Context.Canceled then
    Exit;
    
  if Index >= Middlewares.Count then
  begin
    // All middlewares executed, run final action
    FinalAction();
  end
  else
  begin
    // Execute current middleware
    Middlewares[Index].Execute(Context,
      procedure
      begin
        // Continue to next middleware
        ExecutePipeline(Context, Middlewares, Index + 1, FinalAction);
      end
    );
  end;
end;

function TNavigator.CheckGuards(Context: TNavigationContext;
  const Guards: IList<INavigationGuard>): Boolean;
var
  Guard: INavigationGuard;
begin
  Result := True;
  for Guard in Guards do
  begin
    if not Guard.CanActivate(Context) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

procedure TNavigator.NotifyNavigableView(View: TObject; const Params: TNavParams; Entering: Boolean);
var
  Navigable: INavigableView;
begin
  if Supports(View, INavigableView, Navigable) then
  begin
    if Entering then
      Navigable.OnNavigatedTo(Params)
    else
      Navigable.OnNavigatedFrom;
  end;
end;

procedure TNavigator.DoNavigation(Context: TNavigationContext);
var
  RouteInfo: TRouteInfo;
  AllMiddlewares: IList<INavigationMiddleware>;
  View: TObject;
  CurrentEntry: THistoryEntry;
  Middleware: INavigationMiddleware;
  Navigable: INavigableView;
begin
  // Fire OnNavigating event
  if Assigned(FOnNavigating) then
    FOnNavigating(Context);
    
  // Get route info
  RouteInfo := FindRouteByClass(Context.TargetViewClass);
  
  // Check guards first
  if not CheckGuards(Context, RouteInfo.Guards) then
  begin
    Context.Cancel;
    Exit;
  end;
  
  // Combine global + route-specific middlewares
  AllMiddlewares := TCollections.CreateList<INavigationMiddleware>(True);
  for Middleware in FMiddlewares do
    AllMiddlewares.Add(Middleware);
  for Middleware in RouteInfo.Middlewares do
    AllMiddlewares.Add(Middleware);
  
  // Execute middleware pipeline
  ExecutePipeline(Context, AllMiddlewares, 0,
    procedure
    begin
      if Context.Canceled then
        Exit;
        
      // Check if current view allows navigation
      if FHistory.Count > 0 then
      begin
        CurrentEntry := FHistory.Peek;
        if Supports(CurrentEntry.View, INavigableView, Navigable) then
        begin
          if not Navigable.CanNavigateAway then
          begin
            Context.Cancel;
            Exit;
          end;
        end;
        
        // Notify current view we're leaving
        NotifyNavigableView(CurrentEntry.View, nil, False);
        
        // Hide current view
        if Assigned(FAdapter) then
        begin
          FAdapter.OnBeforeHide(CurrentEntry.View);
          FAdapter.HideView(CurrentEntry.View);
          FAdapter.OnAfterHide(CurrentEntry.View);
        end;
      end;
      
      // Create new view
      View := CreateView(Context.TargetViewClass);
      Context.TargetView := View;
      
      // Handle different actions
      case Context.Action of
        naPush:
          begin
            // Add to history
            FHistory.Push(THistoryEntry.Create(
              Context.TargetRoute, 
              Context.TargetViewClass, 
              View, 
              Context.Params
            ));
          end;
          
        naReplace:
          begin
            // Remove current from history first
            if FHistory.Count > 0 then
            begin
              CurrentEntry := FHistory.Pop;
              if Assigned(FAdapter) then
                FAdapter.RemoveView(CurrentEntry.View);
              if Assigned(CurrentEntry.Params) then
                CurrentEntry.Params.Free;
            end;
            // Add new
            FHistory.Push(THistoryEntry.Create(
              Context.TargetRoute,
              Context.TargetViewClass,
              View,
              Context.Params
            ));
          end;
      end;
      
      // Show new view via adapter
      if Assigned(FAdapter) then
      begin
        FAdapter.OnBeforeShow(View);
        FAdapter.ShowView(View, Context.TargetRoute);
        FAdapter.OnAfterShow(View);
      end;
      
      // Notify new view
      NotifyNavigableView(View, Context.Params, True);
      
      // Fire OnNavigated event
      if Assigned(FOnNavigated) then
        FOnNavigated(Context);
    end
  );
end;

procedure TNavigator.RegisterRoute(const Path: string; const RouteInfo: TRouteInfo);
begin
  FRoutes.AddOrSetValue(Path, RouteInfo);
end;

// === Navigation Methods ===

function TNavigator.Push(ViewClass: TClass): INavigator;
begin
  Result := Push(ViewClass, nil);
end;

function TNavigator.Push(ViewClass: TClass; const Params: TNavParams): INavigator;
var
  Context: TNavigationContext;
begin
  Result := Self;
  
  Context := TNavigationContext.Create;
  try
    Context.Action := naPush;
    Context.TargetViewClass := ViewClass;
    Context.TargetRoute := GetRouteName(ViewClass);
    Context.Params := Params;
    
    if FHistory.Count > 0 then
    begin
      Context.SourceRoute := FHistory.Peek.Route;
      Context.SourceView := FHistory.Peek.View;
    end;
    
    DoNavigation(Context);
  finally
    Context.Free;
  end;
end;

function TNavigator.PushNamed(const Route: string): INavigator;
begin
  Result := PushNamed(Route, nil);
end;

function TNavigator.PushNamed(const Route: string; const Params: TNavParams): INavigator;
var
  RouteInfo: TRouteInfo;
begin
  if not FRoutes.TryGetValue(Route, RouteInfo) then
    raise Exception.CreateFmt('Route not found: %s', [Route]);
    
  Result := Push(RouteInfo.ViewClass, Params);
end;

procedure TNavigator.Pop;
begin
  Pop(TNavigationResult.Cancel);
end;

procedure TNavigator.Pop(const Result: TNavigationResult);
var
  CurrentEntry: THistoryEntry;
  PreviousEntry: THistoryEntry;
begin
  if FHistory.Count <= 1 then
    Exit; // Can't pop the root
    
  // Pop current
  CurrentEntry := FHistory.Pop;
  
  // Notify current view we're leaving
  NotifyNavigableView(CurrentEntry.View, nil, False);
  
  // Hide and remove current view
  if Assigned(FAdapter) then
  begin
    FAdapter.OnBeforeHide(CurrentEntry.View);
    FAdapter.HideView(CurrentEntry.View);
    FAdapter.OnAfterHide(CurrentEntry.View);
    FAdapter.RemoveView(CurrentEntry.View);
  end;
  
  // Free params if any
  if Assigned(CurrentEntry.Params) then
    CurrentEntry.Params.Free;
  
  // Show previous view
  if FHistory.Count > 0 then
  begin
    PreviousEntry := FHistory.Peek;
    
    if Assigned(FAdapter) then
    begin
      FAdapter.OnBeforeShow(PreviousEntry.View);
      FAdapter.ShowView(PreviousEntry.View, PreviousEntry.Route);
      FAdapter.OnAfterShow(PreviousEntry.View);
    end;
    
    // Notify previous view we're returning (with result)
    NotifyNavigableView(PreviousEntry.View, PreviousEntry.Params, True);
  end;
end;

procedure TNavigator.PopUntil(ViewClass: TClass);
var
  Entry: THistoryEntry;
begin
  while (FHistory.Count > 1) and (FHistory.Peek.ViewClass <> ViewClass) do
  begin
    Entry := FHistory.Pop;
    
    NotifyNavigableView(Entry.View, nil, False);
    
    if Assigned(FAdapter) then
      FAdapter.RemoveView(Entry.View);
      
    if Assigned(Entry.Params) then
      Entry.Params.Free;
  end;
  
  // Show the target view
  if (FHistory.Count > 0) and (FHistory.Peek.ViewClass = ViewClass) then
  begin
    Entry := FHistory.Peek;
    
    if Assigned(FAdapter) then
    begin
      FAdapter.OnBeforeShow(Entry.View);
      FAdapter.ShowView(Entry.View, Entry.Route);
      FAdapter.OnAfterShow(Entry.View);
    end;
    
    NotifyNavigableView(Entry.View, Entry.Params, True);
  end;
end;

function TNavigator.Replace(ViewClass: TClass): INavigator;
begin
  Result := Replace(ViewClass, nil);
end;

function TNavigator.Replace(ViewClass: TClass; const Params: TNavParams): INavigator;
var
  Context: TNavigationContext;
begin
  Result := Self;
  
  Context := TNavigationContext.Create;
  try
    Context.Action := naReplace;
    Context.TargetViewClass := ViewClass;
    Context.TargetRoute := GetRouteName(ViewClass);
    Context.Params := Params;
    
    if FHistory.Count > 0 then
    begin
      Context.SourceRoute := FHistory.Peek.Route;
      Context.SourceView := FHistory.Peek.View;
    end;
    
    DoNavigation(Context);
  finally
    Context.Free;
  end;
end;

function TNavigator.PopAndPush(ViewClass: TClass): INavigator;
begin
  Result := PopAndPush(ViewClass, nil);
end;

function TNavigator.PopAndPush(ViewClass: TClass; const Params: TNavParams): INavigator;
var
  Entry: THistoryEntry;
begin
  // Clear all history
  while FHistory.Count > 0 do
  begin
    Entry := FHistory.Pop;
    
    NotifyNavigableView(Entry.View, nil, False);
    
    if Assigned(FAdapter) then
      FAdapter.RemoveView(Entry.View);
      
    if Assigned(Entry.Params) then
      Entry.Params.Free;
  end;
  
  // Push new root
  Result := Push(ViewClass, Params);
end;

// === Configuration ===

function TNavigator.UseAdapter(const Adapter: INavigatorAdapter): INavigator;
begin
  FAdapter := Adapter;
  Result := Self;
end;

function TNavigator.UseMiddleware(const Middleware: INavigationMiddleware): INavigator;
begin
  FMiddlewares.Add(Middleware);
  Result := Self;
end;

function TNavigator.Route(const Path: string): IRouteBuilder;
begin
  Result := TRouteBuilder.Create(Self, Path);
end;

function TNavigator.SetInitialRoute(ViewClass: TClass): INavigator;
begin
  // Push as the root without history check
  Result := Push(ViewClass);
end;

// === State ===

function TNavigator.CanGoBack: Boolean;
begin
  Result := FHistory.Count > 1;
end;

function TNavigator.CurrentRoute: string;
begin
  if FHistory.Count > 0 then
    Result := FHistory.Peek.Route
  else
    Result := '';
end;

function TNavigator.CurrentView: TObject;
begin
  if FHistory.Count > 0 then
    Result := FHistory.Peek.View
  else
    Result := nil;
end;

function TNavigator.History: TArray<string>;
var
  Arr: TArray<THistoryEntry>;
  I: Integer;
begin
  Arr := FHistory.ToArray;
  SetLength(Result, Length(Arr));
  for I := 0 to High(Arr) do
    Result[I] := Arr[I].Route;
end;

function TNavigator.StackDepth: Integer;
begin
  Result := FHistory.Count;
end;

// === Events ===

function TNavigator.OnNavigating(const Handler: TProc<TNavigationContext>): INavigator;
begin
  FOnNavigating := Handler;
  Result := Self;
end;

function TNavigator.OnNavigated(const Handler: TProc<TNavigationContext>): INavigator;
begin
  FOnNavigated := Handler;
  Result := Self;
end;

end.
