unit PatchLib;

interface

uses
  System.Classes, System.UITypes, System.IOUtils, Winapi.Windows, System.SysUtils, System.Generics.Collections,
  Vcl.Imaging.PngImage, CvtrPropValue;

const
  CRLF = #13#10;
  CR = #13;
  LF = #10;
  ZSISOffset = 0;
  LineTruncLength = 64;

type
  TImageList = class(TObjectList<TPngImage>);

function ColorToAlphaColor(const AColor: String): TPropValue;
function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1;
  const ASkipChars: TArray<Char> = []): Integer;
function StringReplaceSkipChars(const Source, OldPattern, NewPattern: string): string; overload;
function StringReplaceSkipChars(const Source, OldPattern, NewPattern: string; const ASkipChars: TArray<Char>): string; overload;
procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArray<String>);
function BreakIntoLines(const AData, APad: String; ALineLen: Integer = LineTruncLength): String;
function StreamToHex(AMemStream:TMemoryStream): String;
procedure HexToStream(AData: string; AMemStream:TMemoryStream);

implementation

uses
  System.UIConsts, Vcl.Graphics;

function ColorToAlphaColor(const AColor: String): TPropValue;
var
  Color, AlphaColor: Integer;
  ColorStr: String;
begin
  Color := ColorToRGB(StringToColor(AColor));

  TAlphaColorRec(AlphaColor).A := 255;
  TAlphaColorRec(AlphaColor).B := TColorRec(Color).B;
  TAlphaColorRec(AlphaColor).G := TColorRec(Color).G;
  TAlphaColorRec(AlphaColor).R := TColorRec(Color).R;

  AlphaColorToIdent(AlphaColor, ColorStr);
  Result := TPropValue.CreateSymbolVal(ColorStr);
end;

function CheckSubstr(const AFullString, ASubUp, ASubLow: String; APos: Integer; const ASkipChars: TArray<Char>;
  var ASkipCount: Integer): Boolean; inline;
var
  i: Integer;
  FullChar, SkipChar: Char;
  Skip: Boolean;
begin
  Result := True;
  i := 0;
  ASkipCount := 0;
  while i < ASubUp.Length + ASkipCount do
  begin
    Inc(i);
    FullChar := AFullString[APos + i];

    Skip := False;
    for SkipChar in ASkipChars do
      if SkipChar = FullChar then
      begin
        Skip := True;
        Inc(ASkipCount);
        Break;
      end;

    if Skip and (i = 1) then
      Exit(False);

    if (not Skip) and (ASubUp[i - ASkipCount] <> FullChar) and (ASubLow[i - ASkipCount] <> FullChar) then
      Exit(False);
  end;
end;

function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1;
  const ASkipChars: TArray<Char> = []): Integer;
var
  FullLength, SubLength, Temp: Integer;
  SubUp, SubLow: String;
begin
  Result := 0;
  if (AFullString = '') or (ASubstr = '') or (Offset <= 0) then
    Exit;

  SubLength := ASubstr.Length;
  FullLength := AFullString.Length;

  if SubLength + Offset - 1 > FullLength then
    Exit;

  SubUp := ASubstr.ToUpper;
  SubLow := ASubstr.ToLower;

  Result := Offset - 1;
  while SubLength <= (FullLength - Result) do
  begin
    if CheckSubstr(AFullString, SubUp, SubLow, Result, ASkipChars, Temp) then
      Exit(Result + 1)
    else
      Inc(Result);
  end;

  Result := 0;
end;

function StringReplaceSkipChars(const Source, OldPattern, NewPattern: string): string;
begin
  Result := StringReplaceSkipChars(Source, OldPattern, NewPattern, [CR, LF, ' ']);
end;

function StringReplaceSkipChars(const Source, OldPattern, NewPattern: string; const ASkipChars: TArray<Char>): string;
var
  SourceLength, OldLength, SkipCount, Pos, Len, i, PrevEnd: Integer;
  PatternStarts, PatternEnds: array of Integer;
  OldUp, OldLow: String;
begin
  Result := Source;
  if (Source = '') or (OldPattern = '') then
    Exit;

  OldLength := OldPattern.Length;
  SourceLength := Source.Length;

  if OldLength > SourceLength then
    Exit;

  OldUp := OldPattern.ToUpper;
  OldLow := OldPattern.ToLower;

  Pos := 0;
  while OldLength <= (SourceLength - Pos) do
  begin
    if CheckSubstr(Source, OldUp, OldLow, Pos, ASkipChars, SkipCount) then
    begin
      Len := Length(PatternStarts);
      SetLength(PatternStarts, Len + 1);
      PatternStarts[Len] := Pos;
      Len := Length(PatternEnds);
      SetLength(PatternEnds, Len + 1);
      PatternEnds[Len] := Pos + OldLength + SkipCount;
      Inc(Pos, OldLength + SkipCount)
    end
    else
      Inc(Pos);
  end;

  Result := '';
  PrevEnd := 0;
  for i := 0 to High(PatternStarts) do
  begin
    Result := Result + Source.Substring(PrevEnd, PatternStarts[i] - PrevEnd) + NewPattern;
    PrevEnd := PatternEnds[i];
  end;
  Result := Result + Source.Substring(PrevEnd);
end;

procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArray<String>);
var
  i: Integer;
begin
  if AStrings = nil then
    raise Exception.Create('PopulateStringsFromArray');
  AStrings.Clear;
  for i := 0 to high(AArray) do
    AStrings.Add(AArray[i].Trim);
end;

function StreamToHex(AMemStream:TMemoryStream): String;
begin
  SetLength(Result, AMemStream.Size * 2);
  BinToHex(AMemStream.Memory^, PChar(Result), AMemStream.Size);
end;

function BreakIntoLines(const AData, APad: String; ALineLen: Integer = LineTruncLength): String;
var
  Line: String;
  LineNum: Integer;
begin
  Result := '';
  LineNum := 0;
  repeat
    Line := Copy(AData, ALineLen * LineNum + 1, ALineLen);
    if Line <> '' then
      Result := Result + CRLF + APad + '    ' + Line;
    Inc(LineNum);
  until Length(Line) < ALineLen;
end;

procedure HexToStream(AData: string; AMemStream:TMemoryStream);
begin
  AMemStream.Size := Length(AData) div 2;
  HexToBin(PChar(AData), AMemStream.Memory^, AMemStream.Size);
end;

end.
