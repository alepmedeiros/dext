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
{  Created: 2025-12-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Hosting.ApplicationLifetime;

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Threading.CancellationToken;

type
  /// <summary>
  ///   Allows consumers to be notified of application lifetime events.
  /// </summary>
  IHostApplicationLifetime = interface
    ['{DA4C3B2A-1E5F-4D8C-9B0A-2F3E4D5C6B7A}']
    /// <summary>
    ///   Triggered when the application host has fully started.
    /// </summary>
    function GetApplicationStarted: ICancellationToken;
    
    /// <summary>
    ///   Triggered when the application host is starting a graceful shutdown.
    ///   Requests may still be in flight.
    /// </summary>
    function GetApplicationStopping: ICancellationToken;
    
    /// <summary>
    ///   Triggered when the application host has completed a graceful shutdown.
    ///   The application will exit shortly after this.
    /// </summary>
    function GetApplicationStopped: ICancellationToken;

    /// <summary>
    ///   Requests termination of the current application.
    /// </summary>
    procedure StopApplication;

    property ApplicationStarted: ICancellationToken read GetApplicationStarted;
    property ApplicationStopping: ICancellationToken read GetApplicationStopping;
    property ApplicationStopped: ICancellationToken read GetApplicationStopped;
  end;

  /// <summary>
  ///   Default implementation of IHostApplicationLifetime.
  /// </summary>
  THostApplicationLifetime = class(TInterfacedObject, IHostApplicationLifetime)
  private
    FStartedSource: TCancellationTokenSource;
    FStoppingSource: TCancellationTokenSource;
    FStoppedSource: TCancellationTokenSource;
  public
    constructor Create;
    destructor Destroy; override;

    function GetApplicationStarted: ICancellationToken;
    function GetApplicationStopping: ICancellationToken;
    function GetApplicationStopped: ICancellationToken;
    procedure StopApplication;

    // Methods to be called by the Host itself
    procedure NotifyStarted;
    procedure NotifyStopping;
    procedure NotifyStopped;
  end;

implementation

{ THostApplicationLifetime }

constructor THostApplicationLifetime.Create;
begin
  inherited;
  FStartedSource := TCancellationTokenSource.Create;
  FStoppingSource := TCancellationTokenSource.Create;
  FStoppedSource := TCancellationTokenSource.Create;
end;

destructor THostApplicationLifetime.Destroy;
begin
  FStartedSource.Free;
  FStoppingSource.Free;
  FStoppedSource.Free;
  inherited;
end;

function THostApplicationLifetime.GetApplicationStarted: ICancellationToken;
begin
  Result := FStartedSource.Token;
end;

function THostApplicationLifetime.GetApplicationStopped: ICancellationToken;
begin
  Result := FStoppedSource.Token;
end;

function THostApplicationLifetime.GetApplicationStopping: ICancellationToken;
begin
  Result := FStoppingSource.Token;
end;

procedure THostApplicationLifetime.NotifyStarted;
begin
  FStartedSource.Cancel; // Signal that it has started
end;

procedure THostApplicationLifetime.NotifyStopped;
begin
  FStoppedSource.Cancel; // Signal that it has stopped
end;

procedure THostApplicationLifetime.NotifyStopping;
begin
  FStoppingSource.Cancel; // Signal that it is stopping
end;

procedure THostApplicationLifetime.StopApplication;
begin
  // Trigger the stopping sequence
  // In a real scenario, this might just signal a flag that the main loop checks
  NotifyStopping;
end;

end.
