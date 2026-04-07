unit Dext.Web.Indy.Types;

interface

uses
  System.Classes,
  Dext.Web.Interfaces;

type
  TDextIndyFormFile = class(TInterfacedObject, IFormFile)
  private
    FFileName: string;
    FName: string;
    FContentType: string;
    FStream: TStream;
  public
    constructor Create(const AName, AFileName, AContentType: string; AStream: TStream);
    destructor Destroy; override;
    function GetFileName: string;
    function GetName: string;
    function GetContentType: string;
    function GetLength: Int64;
    function GetStream: TStream;
  end;

implementation

{ TDextIndyFormFile }

constructor TDextIndyFormFile.Create(const AName, AFileName, AContentType: string; AStream: TStream);
begin
  inherited Create;
  FName := AName;
  FFileName := AFileName;
  FContentType := AContentType;
  FStream := AStream;
end;

destructor TDextIndyFormFile.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TDextIndyFormFile.GetFileName: string; begin Result := FFileName; end;
function TDextIndyFormFile.GetName: string; begin Result := FName; end;
function TDextIndyFormFile.GetContentType: string; begin Result := FContentType; end;
function TDextIndyFormFile.GetLength: Int64; begin Result := FStream.Size; end;
function TDextIndyFormFile.GetStream: TStream; begin Result := FStream; end;

end.
