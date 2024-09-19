{$I InnovaLibDefs.inc}

unit PatchLib;

interface

uses
  System.Classes, System.UITypes,
  System.IOUtils,
  Winapi.Windows,
  System.SysUtils;

type
  TArrayOfStrings = array of String;
  TTwoDArrayOfString = array of TArrayOfStrings;

function ConvertColor(AColorVal: Cardinal): String;
function GetArrayFromString(const S: String; SepVal: Char; ARemoveQuote: Boolean = false; ATrim: Boolean = True; ADropNulls: Boolean = false): TArrayOfStrings; overload;
function FieldSep(var ss: PChar; SepVal: Char): String; overload;
function PosNoCase(const ASubstr: String; AFullString: String; Offset: Integer = 1): Integer; overload;
procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArrayOfStrings);

const
  CRLF = #13#10;
  ZSISOffset = 0;

implementation

uses
  System.StrUtils;

function ConvertColor(AColorVal: Cardinal): String;
begin
  AColorVal := ((AColorVal and $FF0000) shr 16) or (AColorVal and $FF00) or ((AColorVal and $FF) shl 16);
  Result := 'x' + IntToHex(AColorVal or $FF000000);
end;

function GetArrayFromString(const S: String; SepVal: Char; ARemoveQuote: Boolean = false; ATrim: Boolean = True; ADropNulls: Boolean = false): TArrayOfStrings;
var
  i: Integer;
  NextChar, SecondQuoteChar: PChar;
  CSepVal, FirstQuoteChar: Char;
  QuoteVal: String;
  ThisS, fs: String;
begin
  SetLength(Result, 0);
  if S = '' then
    exit;
  ThisS := S;
  NextChar := @ThisS[1];
  CSepVal := SepVal;
  i := 0;
  while Pointer(NextChar) <> nil do
  begin
    if NextChar[0] = CSepVal then
    begin
      inc(NextChar);
      fs := '';
    end
    else
    if CharInSet(NextChar[0], ['''', '"', '[', '{', '(', '<']) then
    begin
      FirstQuoteChar := NextChar[0];
      case FirstQuoteChar of
        '''', '"':
          QuoteVal := NextChar[0];
        '[':
          QuoteVal := ']';
        '{':
          QuoteVal := '}';
        '(':
          QuoteVal := ')';
        '<':
          QuoteVal := '>';
      else
        QuoteVal := NextChar[0];
      end;

      SecondQuoteChar := StrPos(PChar(NextChar + 1), PChar(QuoteVal));
      if (Pointer(SecondQuoteChar) <> nil) and ((SecondQuoteChar[1] = CSepVal) or (SecondQuoteChar[1] = #0)) then
      begin
        if ARemoveQuote then
        begin
          inc(NextChar);
          if NextChar = SecondQuoteChar then
          begin
            fs := '';
            inc(NextChar);
          end
          else
            fs := FieldSep(NextChar, QuoteVal[1 + ZSISOffset]);
          if SecondQuoteChar[1] = #0 then
            NextChar := nil
          else
            inc(NextChar);
        end
        else
        begin
          fs := Copy(NextChar, 0, SecondQuoteChar - NextChar + 1);
          if SecondQuoteChar[1] = #0 then
            NextChar := nil
          else
            NextChar := SecondQuoteChar + 1;
        end;
      end
      else
        fs := FieldSep(NextChar, CSepVal);
    end
    else
      fs := FieldSep(NextChar, CSepVal);
    if i > high(Result) then
      SetLength(Result, i + 6);
    if ATrim then
      Result[i] := Trim(fs)
    else
      Result[i] := fs;
    if not (ADropNulls and (Result[i] = '')) then
      Inc(i);
  end;
  SetLength(Result, i);
end;

function FieldSep(var ss: PChar; SepVal: Char): String;
var
  CharPointer: PChar;
  j: Integer;
begin
  if ss <> nil then
  begin
    if (SepVal <> AnsiChar(0)) then
      while ss[0] = SepVal do
        ss := ss + 1;
    CharPointer := StrScan(ss, SepVal);
    if CharPointer = nil then
      Result := StrPas(ss) { Last Field }
    else
    begin
      j := CharPointer - ss;
      Result := Copy(ss, 0, j);
    end;
    if CharPointer = nil then
      ss := nil
    else
      if SepVal = ' ' then
        ss := CharPointer + 1
      else
        repeat
          CharPointer := CharPointer + 1;
          ss := CharPointer;
        until ss[0] <> ' ';
  end
  else
    Result := '';
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

procedure PopulateStringsFromArray(AStrings: TStrings; AArray: TArrayOfStrings);
var
  i: Integer;
begin
  if AStrings = nil then
    raise Exception.Create('PopulateStringsFromArray');
  AStrings.Clear;
  for i := 0 to high(AArray) do
    AStrings.Add(AArray[i])
end;

end.
