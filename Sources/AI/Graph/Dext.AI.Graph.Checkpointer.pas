{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    Checkpointers em memória (MemorySaver) e em arquivo JSON.              }
{                                                                           }
{***************************************************************************}
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the LICENSE is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Checkpointer;

interface

uses
  Dext.AI.Graph.Contracts,
  Dext.Collections,
  Dext.Collections.Dict,
  System.SysUtils,
  System.Hash;

type
  TMemoryCheckpointer = class(TInterfacedObject, ICheckpointer)
  private
    FStore: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Save(const AThreadId: string; const AStateJson: string);
    function  Load(const AThreadId: string): string;
    function  Exists(const AThreadId: string): Boolean;
    procedure Delete(const AThreadId: string);
  end;

  TFileCheckpointer = class(TInterfacedObject, ICheckpointer)
  private
    FBasePath: string;
    function FilePath(const AThreadId: string): string;
    function SanitizeId(const AThreadId: string): string;
  public
    constructor Create(const ABasePath: string = '');
    procedure Save(const AThreadId: string; const AStateJson: string);
    function  Load(const AThreadId: string): string;
    function  Exists(const AThreadId: string): Boolean;
    procedure Delete(const AThreadId: string);
  end;

implementation

uses
  System.IOUtils;

{ TMemoryCheckpointer }

constructor TMemoryCheckpointer.Create;
begin
  inherited Create;
  FStore := TDictionary<string, string>.Create;
end;

destructor TMemoryCheckpointer.Destroy;
begin
  FStore.Free;
  inherited;
end;

procedure TMemoryCheckpointer.Save(const AThreadId: string; const AStateJson: string);
begin
  FStore.AddOrSetValue(AThreadId, AStateJson);
end;

function TMemoryCheckpointer.Load(const AThreadId: string): string;
begin
  if not FStore.TryGetValue(AThreadId, Result) then
    raise EGraphError.CreateFmt('Checkpoint não encontrado: %s', [AThreadId]);
end;

function TMemoryCheckpointer.Exists(const AThreadId: string): Boolean;
begin
  Result := FStore.ContainsKey(AThreadId);
end;

procedure TMemoryCheckpointer.Delete(const AThreadId: string);
begin
  FStore.Remove(AThreadId);
end;

{ TFileCheckpointer }

constructor TFileCheckpointer.Create(const ABasePath: string);
begin
  inherited Create;
  if ABasePath = '' then
    FBasePath := TPath.Combine(TPath.GetTempPath, 'dext-ai-graph')
  else
    FBasePath := ABasePath;
end;

function TFileCheckpointer.SanitizeId(const AThreadId: string): string;
var
  I: Integer;
  C: Char;
  Clean: string;
begin
  Clean := '';
  for I := 1 to Length(AThreadId) do
  begin
    C := AThreadId[I];
    if CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) then
      Clean := Clean + C
    else
      Clean := Clean + '_';
  end;
  if Clean = '' then
    Clean := 'thread';
  // Substituir caracteres inválidos por "_" pode colidir (ex.: "a/b" e "a:b"
  // viram ambos "a_b"), fazendo threads distintas compartilharem o mesmo
  // arquivo de checkpoint. Um sufixo hash do id original torna o nome do
  // arquivo praticamente único mesmo quando a parte legível colide.
  Result := Clean + '-' + IntToHex(THashBobJenkins.GetHashValue(AThreadId), 8);
end;

function TFileCheckpointer.FilePath(const AThreadId: string): string;
begin
  Result := TPath.Combine(FBasePath, SanitizeId(AThreadId) + '.json');
end;

procedure TFileCheckpointer.Save(const AThreadId: string; const AStateJson: string);
begin
  TDirectory.CreateDirectory(FBasePath);
  TFile.WriteAllText(FilePath(AThreadId), AStateJson, TEncoding.UTF8);
end;

function TFileCheckpointer.Load(const AThreadId: string): string;
var
  Path: string;
begin
  Path := FilePath(AThreadId);
  if not TFile.Exists(Path) then
    raise EGraphError.CreateFmt('Checkpoint não encontrado: %s', [AThreadId]);
  Result := TFile.ReadAllText(Path, TEncoding.UTF8);
end;

function TFileCheckpointer.Exists(const AThreadId: string): Boolean;
begin
  Result := TFile.Exists(FilePath(AThreadId));
end;

procedure TFileCheckpointer.Delete(const AThreadId: string);
var
  Path: string;
begin
  Path := FilePath(AThreadId);
  if TFile.Exists(Path) then
    TFile.Delete(Path);
end;

end.
