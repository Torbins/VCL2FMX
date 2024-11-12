{$I InnovaLibDefs.inc}

unit PatchLib;

interface

uses
  System.Classes, System.UITypes, System.IOUtils, Winapi.Windows, System.SysUtils, System.Generics.Collections,
  Vcl.Imaging.PngImage;

const
  CRLF = #13#10;
  ZSISOffset = 0;
  LineTruncLength = 64;

type
  TImageList = class(TObjectList<TPngImage>);

function ColorToAlphaColor(const AColor: String): String;
function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1; const SkipChars: TArray<Char> = []):
  Integer;
procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArray<String>);
function BreakIntoLines(const AData, APad: String; ALineLen: Integer = LineTruncLength): String;
function StreamToHex(AMemStream:TMemoryStream): String;
procedure HexToStream(AData: string; AMemStream:TMemoryStream);

implementation

uses
  System.StrUtils, System.UIConsts, Vcl.Graphics;

function ColorToAlphaColor(const AColor: String): String;
var
  Color, AlphaColor: Integer;
begin
  Color := ColorToRGB(StringToColor(AColor));

  TAlphaColorRec(AlphaColor).A := 255;
  TAlphaColorRec(AlphaColor).B := TColorRec(Color).B;
  TAlphaColorRec(AlphaColor).G := TColorRec(Color).G;
  TAlphaColorRec(AlphaColor).R := TColorRec(Color).R;

  AlphaColorToIdent(AlphaColor, Result);
end;

function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1; const SkipChars: TArray<Char> = []):
  Integer;
var
  SubLength: Integer;
  FullLength: Integer;
  SubUp, SubLow: String;

  function CheckSubstr(APos: Integer): Boolean;
  var
    i, j, EndCount, SubIndex: Integer;
    FullChar: Char;
    Skip: Boolean;
  begin
    Result := True;
    i := 0;
    EndCount := SubLength;
    while i < EndCount do
    begin
      Inc(i);
      FullChar := AFullString[APos + i - 1];

      Skip := False;
      for j := 0 to Length(SkipChars) - 1 do
        if FullChar = SkipChars[j] then
        begin
          Skip := True;
          Inc(EndCount);
          Break;
        end;

      SubIndex := i - EndCount + SubLength;
      if (not Skip) and (SubUp[SubIndex] <> FullChar) and (SubLow[SubIndex] <> FullChar) then
        Exit(False);
    end;
  end;

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

  Result := Offset;
  while SubLength <= (FullLength - Result + 1) do
  begin
    if CheckSubstr(Result) then
      Exit
    else
      Inc(Result);
  end;

  Result := 0;
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
