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

function ConvertColor(AColorVal: Cardinal): String;
function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1): Integer;
procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArray<String>);
function BreakIntoLines(const AData, APad: String; ALineLen: Integer = LineTruncLength): String;
function StreamToHex(AMemStream:TMemoryStream): String;
procedure HexToStream(AData: string; AMemStream:TMemoryStream);

implementation

uses
  System.StrUtils;

function ConvertColor(AColorVal: Cardinal): String;
begin
  AColorVal := ((AColorVal and $FF0000) shr 16) or (AColorVal and $FF00) or ((AColorVal and $FF) shl 16);
  Result := 'x' + IntToHex(AColorVal or $FF000000);
end;

function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1): Integer;
var
  Substr: String;
  S: String;
begin
  if (ASubstr = '') or (AFullString = '') then
  begin
    Result := -1;
    exit;
  end;
  Substr := AnsiLowerCase(ASubstr);
  S := AnsiLowerCase(AFullString);
  Result := Pos(Substr, S, Offset);
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
