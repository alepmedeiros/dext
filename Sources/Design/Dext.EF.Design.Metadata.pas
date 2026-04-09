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
<<<<<<< HEAD
  LogPath: string;
  LogStrings: TStringList;
=======
  ParsedCollection: ICollection;
  ParsedList: IList<TEntityClassMetadata>;
  Parser: TEntityMetadataParser;
>>>>>>> upstream/main
begin
  if AProvider = nil then
    Exit;

  LogPath := 'C:\dev\Dext\dext_metadata_debug.log';
  LogStrings := TStringList.Create;
  try
    LogStrings.Add('--- Dext Metadata Refresh Log ---');
    LogStrings.Add('Time: ' + DateTimeToStr(Now));
    LogStrings.Add('ModelUnits Count: ' + IntToStr(AProvider.ModelUnits.Count));

    AProvider.ClearMetadata;
    Parser := TEntityMetadataParser.Create;
    try
      for FileName in AProvider.ModelUnits do
      begin
        LogStrings.Add('Parsing: ' + FileName);
        
        Content := '';
        if Assigned(GOnGetSourceContent) then
          Content := GOnGetSourceContent(FileName);

<<<<<<< HEAD
        ParsedList := Parser.ParseUnit(FileName, Content);
        try
          LogStrings.Add(Format('  Result: Found %d classes', [ParsedList.Count]));
          for MD in ParsedList do
          begin
            AProvider.AddOrSetMetadata(MD);
            LogStrings.Add(Format('  Entity: %s (Table=%s, Members=%d)',
              [MD.EntityClassName, MD.TableName, MD.Members.Count]));
            
            for var I := 0 to MD.Members.Count - 1 do
            begin
              var Member := MD.Members[I];
              LogStrings.Add(Format('    Member [%d]: %s (DisplayLabel="%s", DisplayWidth=%d, Currency=%s)',
                [I, Member.Name, Member.DisplayLabel, Member.DisplayWidth, BoolToStr(Member.IsCurrency, True)]));
            end;
          end;

          if Supports(ParsedList, ICollection, ParsedCollection) then
            ParsedCollection.OwnsObjects := False;
        finally
          // ParsedList cleaned by interface
        end;
      end;
    finally
      Parser.Free;
    end;

    AProvider.UpdateRefreshSummary;
    LogStrings.Add('Refresh completed.');
    try
      TFile.AppendAllText(LogPath, LogStrings.Text);
    except
=======
      ParsedList := Parser.ParseUnit(FileName, Content);
      for MD in ParsedList do
      begin
        AProvider.AddOrSetMetadata(MD);
      end;

      if Supports(ParsedList, ICollection, ParsedCollection) then
        ParsedCollection.OwnsObjects := False;
>>>>>>> upstream/main
    end;
  finally
    LogStrings.Free;
  end;
end;

end.
