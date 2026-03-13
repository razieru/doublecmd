unit uDefaultFilePropertyFormatter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uFileProperty;

type

  TDefaultFilePropertyFormatter = class(TInterfacedObject, IFilePropertyFormatter)

  public
    function FormatFileName(FileProperty: TFileNameProperty): String;
    function FormatFileSize(FileProperty: TFileSizeProperty): String;
    function FormatDateTime(FileProperty: TFileDateTimeProperty): String;
    function FormatModificationDateTime(FileProperty: TFileModificationDateTimeProperty): String;
    function FormatNtfsAttributes(FileProperty: TNtfsFileAttributesProperty): String;
    function FormatUnixAttributes(FileProperty: TUnixFileAttributesProperty): String;

  end;

  TMaxDetailsFilePropertyFormatter = class(TInterfacedObject, IFilePropertyFormatter)

  public
    function FormatFileName(FileProperty: TFileNameProperty): String;
    function FormatFileSize(FileProperty: TFileSizeProperty): String;
    function FormatDateTime(FileProperty: TFileDateTimeProperty): String;
    function FormatModificationDateTime(FileProperty: TFileModificationDateTimeProperty): String;
    function FormatNtfsAttributes(FileProperty: TNtfsFileAttributesProperty): String;
    function FormatUnixAttributes(FileProperty: TUnixFileAttributesProperty): String;

  end;

var
  DefaultFilePropertyFormatter: IFilePropertyFormatter = nil;
  MaxDetailsFilePropertyFormatter: IFilePropertyFormatter = nil;

function FormatDateTimeWithRelativeDate(const AValue: TDateTime; const AFormat: String): String;

implementation

uses
  DateUtils, uGlobs, uDCUtils, DCBasicTypes, DCFileAttributes, DCDateTimeUtils, uLng;

function IsDateFormatToken(const AChar: Char): Boolean; inline;
begin
  Result := (AChar = 'c') or (AChar = 'd') or (AChar = 'm') or
            (AChar = 'y') or (AChar = 'e') or (AChar = 'g');
end;

function IsTimeFormatToken(const AChar: Char): Boolean; inline;
begin
  Result := (AChar = 'h') or (AChar = 'n') or (AChar = 's') or
            (AChar = 'z') or (AChar = 't');
end;

function StartsWithNoCase(const S, AValue: String; AIndex: SizeInt): Boolean; inline;
var
  ALen: SizeInt;
begin
  ALen := Length(AValue);
  Result := (AIndex + ALen - 1 <= Length(S)) and
            SameText(Copy(S, AIndex, ALen), AValue);
end;

function ContainsDateFormatToken(const AFormat: String): Boolean;
var
  I: SizeInt;
  AChar: Char;
begin
  I := 1;
  while I <= Length(AFormat) do
  begin
    AChar := AFormat[I];
    if AChar = '''' then
    begin
      Inc(I);
      while I <= Length(AFormat) do
      begin
        if AFormat[I] = '''' then
        begin
          Inc(I);
          Break;
        end;
        Inc(I);
      end;
      Continue;
    end;

    if IsDateFormatToken(AChar) then
      Exit(True);

    Inc(I);
  end;
  Result := False;
end;

function ExtractTimeFormat(const AFormat: String): String;
var
  I: SizeInt;
  AChar: Char;
  TokenLen: SizeInt;
begin
  Result := EmptyStr;
  I := 1;
  while I <= Length(AFormat) do
  begin
    AChar := AFormat[I];
    if AChar = '''' then
    begin
      Result += AChar;
      Inc(I);
      while I <= Length(AFormat) do
      begin
        Result += AFormat[I];
        if AFormat[I] = '''' then
        begin
          Inc(I);
          Break;
        end;
        Inc(I);
      end;
      Continue;
    end;

    if StartsWithNoCase(AFormat, 'AM/PM', I) then
      TokenLen := 5
    else if StartsWithNoCase(AFormat, 'A/P', I) then
      TokenLen := 3
    else if StartsWithNoCase(AFormat, 'AMPM', I) then
      TokenLen := 4
    else
      TokenLen := 0;

    if TokenLen > 0 then
    begin
      Result += Copy(AFormat, I, TokenLen);
      Inc(I, TokenLen);
      Continue;
    end;

    if IsDateFormatToken(AChar) then
    begin
      repeat
        Inc(I);
      until (I > Length(AFormat)) or (AFormat[I] <> AChar);
      Continue;
    end;

    if IsTimeFormatToken(AChar) then
    begin
      repeat
        Result += AFormat[I];
        Inc(I);
      until (I > Length(AFormat)) or (AFormat[I] <> AChar);
      Continue;
    end;

    Result += AChar;
    Inc(I);
  end;

  Result := Trim(Result);
  while (Length(Result) > 0) and CharInSet(Result[1], [' ', ',', '.', '-', '/', '\']) do
    Delete(Result, 1, 1);
  while (Length(Result) > 0) and CharInSet(Result[Length(Result)], [' ', ',', '.', '-', '/', '\']) do
    SetLength(Result, Length(Result) - 1);
end;

function GetRelativeDateWord(const AValue: TDateTime): String;
var
  DaysDiff: Int64;
begin
  DaysDiff := Trunc(DateOf(Now) - DateOf(AValue));
  case DaysDiff of
    0: Result := rsSimpleWordToday;
    1: Result := rsSimpleWordYesterday;
    else Result := EmptyStr;
  end;
end;

function FormatDateTimeWithRelativeDate(const AValue: TDateTime; const AFormat: String): String;
var
  RelativeWord: String;
  TimeFormat: String;
  TimeText: String;
begin
  if not gRelativeDateDisplay then
    Exit(SysUtils.FormatDateTime(AFormat, AValue));
  if not ContainsDateFormatToken(AFormat) then
    Exit(SysUtils.FormatDateTime(AFormat, AValue));

  RelativeWord := GetRelativeDateWord(AValue);
  if RelativeWord = EmptyStr then
    Exit(SysUtils.FormatDateTime(AFormat, AValue));

  TimeFormat := ExtractTimeFormat(AFormat);
  if TimeFormat = EmptyStr then
    Exit(RelativeWord);

  TimeText := Trim(SysUtils.FormatDateTime(TimeFormat, AValue));
  if TimeText = EmptyStr then
    Exit(RelativeWord);

  Result := RelativeWord + ' ' + TimeText;
end;

function TDefaultFilePropertyFormatter.FormatFileName(
           FileProperty: TFileNameProperty): String;
begin
  Result := FileProperty.Value;
end;

function TDefaultFilePropertyFormatter.FormatFileSize(
           FileProperty: TFileSizeProperty): String;
begin
  Result := cnvFormatFileSize(FileProperty.Value);
end;

function TDefaultFilePropertyFormatter.FormatDateTime(
            FileProperty: TFileDateTimeProperty): String;
begin
  Result := FormatDateTimeWithRelativeDate(FileProperty.Value, gDateTimeFormat);
end;

function TDefaultFilePropertyFormatter.FormatModificationDateTime(
           FileProperty: TFileModificationDateTimeProperty): String;
begin
  Result := FormatDateTime(FileProperty);
end;

function TDefaultFilePropertyFormatter.FormatNtfsAttributes(FileProperty: TNtfsFileAttributesProperty): String;
{
  Format as decimal:
begin
  Result := IntToStr(FileProperty.Value);
end;
}
begin
  Result:= DCFileAttributes.FormatNtfsAttributes(FileProperty.Value);
end;

function TDefaultFilePropertyFormatter.FormatUnixAttributes(FileProperty: TUnixFileAttributesProperty): String;
begin
  Result:= DCFileAttributes.FormatUnixAttributes(FileProperty.Value);
end;

// ----------------------------------------------------------------------------

function TMaxDetailsFilePropertyFormatter.FormatFileName(
           FileProperty: TFileNameProperty): String;
begin
  Result := FileProperty.Value;
end;

function TMaxDetailsFilePropertyFormatter.FormatFileSize(
           FileProperty: TFileSizeProperty): String;
var
  d: Double;
begin
  d := FileProperty.Value;
  Result := Format('%.0n', [d]);
end;

function TMaxDetailsFilePropertyFormatter.FormatDateTime(
            FileProperty: TFileDateTimeProperty): String;
var
  Bias: LongInt = 0;
  Sign: String;
begin
  Bias := -GetTimeZoneBias;

  if Bias >= 0 then
    Sign := '+'
  else
    Sign := '-';

  Result := SysUtils.FormatDateTime('ddd, dd mmmm yyyy hh:nn:ss', FileProperty.Value)
          + ' UT' + Sign
          + Format('%.2D%.2D', [Bias div 60, Bias mod 60]);
end;

function TMaxDetailsFilePropertyFormatter.FormatModificationDateTime(
           FileProperty: TFileModificationDateTimeProperty): String;
begin
  Result := FormatDateTime(FileProperty);
end;

function TMaxDetailsFilePropertyFormatter.FormatNtfsAttributes(FileProperty: TNtfsFileAttributesProperty): String;
begin
  Result := DefaultFilePropertyFormatter.FormatNtfsAttributes(FileProperty);
end;

function TMaxDetailsFilePropertyFormatter.FormatUnixAttributes(FileProperty: TUnixFileAttributesProperty): String;
begin
  Result := DefaultFilePropertyFormatter.FormatUnixAttributes(FileProperty);
end;

initialization

  DefaultFilePropertyFormatter := TDefaultFilePropertyFormatter.Create as IFilePropertyFormatter;
  MaxDetailsFilePropertyFormatter := TMaxDetailsFilePropertyFormatter.Create as IFilePropertyFormatter;

finalization

  DefaultFilePropertyFormatter := nil; // frees the interface
  MaxDetailsFilePropertyFormatter := nil;

end.

