unit Dext.EF.Design.Metadata;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections,
  Dext.Collections.Base,
  Dext.Entity.Core,
  Dext.Entity.DataProvider,
  Dext.Entity.Metadata;

/// <summary>
///   Design-time helper to refresh metadata from source code using the canonical parser.
/// </summary>
procedure RefreshProviderMetadata(AProvider: TEntityDataProvider);

implementation

uses
  System.IOUtils,
  System.Types,
  Winapi.Windows;

procedure RefreshProviderMetadata(AProvider: TEntityDataProvider);
var
  FileName, Content: string;
  MD: TEntityClassMetadata;
  ParsedCollection: ICollection;
  ParsedList: IList<TEntityClassMetadata>;
  Parser: TEntityMetadataParser;
begin
  if AProvider = nil then
    Exit;

  AProvider.ClearMetadata;
  Parser := TEntityMetadataParser.Create;
  try
    for FileName in AProvider.ModelUnits do
    begin
      Content := '';
      if Assigned(GOnGetSourceContent) then
        Content := GOnGetSourceContent(FileName);

      ParsedList := Parser.ParseUnit(FileName, Content);
      for MD in ParsedList do
        AProvider.AddOrSetMetadata(MD);

      if Supports(ParsedList, ICollection, ParsedCollection) then
        ParsedCollection.OwnsObjects := False;
    end;
  finally
    Parser.Free;
  end;
end;

end.
