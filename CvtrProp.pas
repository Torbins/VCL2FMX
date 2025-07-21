unit CvtrProp;

interface

uses
  System.Classes, System.Generics.Collections, Vcl.Imaging.PngImage, CvtrPropValue;

type
  TDfmProperty = class
  protected
    FName: String;
    FValue: TPropValue;
    function ParseString(AParser: TParser): String;
    procedure ParseValue(AParser: TParser); virtual;
  public
    property Name: String read FName;
    property Value: TPropValue read FValue;
    constructor Create(const AName: string; AParser: TParser); overload; virtual;
    constructor Create(const AName: string; const AValue: TPropValue); overload; virtual;
  end;

  TDfmDataProp = class(TDfmProperty)
  protected
    procedure ParseValue(AParser: TParser); override;
  end;

  TDfmStringsProp = class(TDfmProperty)
  protected
    procedure ParseValue(AParser: TParser); override;
  end;

  TDfmSetProp = class(TDfmProperty)
  protected
    procedure ParseValue(AParser: TParser); override;
  end;

  TDfmProperties = class(TObjectList<TDfmProperty>)
  public
    function FindByName(const AName: String): TDfmProperty;
    function GetIntValueDef(const AName: String; ADef: Integer): Integer;
  end;

  TFmxProperty = class
  protected
    FName: String;
    FValue: TPropValue;
    function WriteString(const APad, AData: string): string;
  public
    property Name: String read FName;
    property Value: TPropValue read FValue;
    constructor Create(const AName: string; const AValue: TPropValue); overload; virtual;
    constructor CreateFromLine(const APropLine: string); virtual;
    function ToString(APad: String): String; reintroduce; virtual;
  end;

  TFmxDataProp = class(TFmxProperty)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxImageProp = class(TFmxDataProp)
  protected
    FPng: TPngImage;
  public
    constructor Create(const AName: string; AImage: TPngImage); overload;
    destructor Destroy; override;
    function ToString(APad: String): String; override;
  end;

  TFmxImageListProp = class(TFmxDataProp)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxStringsProp = class(TFmxProperty)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxItemsProp = class(TFmxProperty)
  protected
    FItems: TStringList;
  public
    property Items: TStringList read FItems;
    constructor Create(const AName: string); overload;
    destructor Destroy; override;
    function ToString(APad: String): String; override;
  end;

  TFmxSetProp = class(TFmxProperty)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxPictureProp = class(TFmxDataProp)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxProperties = class(TObjectList<TFmxProperty>)
  public
    procedure AddProp(AProp: TFmxProperty);
    procedure AddMultipleProps(APropsText: String);
    function FindByName(AName: String): TFmxProperty;
  end;

implementation

uses
  System.SysUtils, PatchLib, Image, ImageList;

{ TDfmProperty }

constructor TDfmProperty.Create(const AName: string; const AValue: TPropValue);
begin
  FName := AName;
  FValue := AValue;
end;

constructor TDfmProperty.Create(const AName: string; AParser: TParser);
begin
  FName := AName;
  ParseValue(AParser);
end;

function TDfmProperty.ParseString(AParser: TParser): String;
begin
  Result := AParser.TokenWideString;
  while AParser.NextToken = '+' do
  begin
    AParser.NextToken;
    if not (AParser.Token in [System.Classes.toString, toWString]) then
      AParser.CheckToken(System.Classes.toString);
    Result := Result + AParser.TokenWideString;
  end;
end;

procedure TDfmProperty.ParseValue(AParser: TParser);
begin
  case AParser.Token of
    toSymbol:
      begin
        FValue := TPropValue.CreateSymbolVal(AParser.TokenComponentIdent);
        AParser.NextToken;
      end;
    System.Classes.toString, toWString:
        FValue := TPropValue.CreateStringVal(ParseString(AParser));
    toInteger:
      begin
        FValue := TPropValue.CreateIntegerVal(AParser.TokenString);
        AParser.NextToken;
      end;
    toFloat:
      begin
        FValue := TPropValue.CreateFloatVal(AParser.TokenString);
        AParser.NextToken;
      end;
  end;
end;

{ TDfmStringsProp }

procedure TDfmStringsProp.ParseValue(AParser: TParser);
var
  Strings: TStringList;
begin
  Strings := TStringList.Create;

  AParser.NextToken;
  while AParser.Token <> ')' do
    Strings.Add(ParseString(AParser));
  AParser.NextToken;

  FValue := TPropValue.CreateStringsVal(Strings);
end;

{ TDfmDataProp }

procedure TDfmDataProp.ParseValue(AParser: TParser);
var
  Data: TMemoryStream;
begin
  Data := TMemoryStream.Create;

  AParser.HexToBinary(Data);
  Data.Position := 0;
  AParser.NextToken;

  FValue := TPropValue.CreateDataVal(Data);
end;

{ TDfmSetProp }

procedure TDfmSetProp.ParseValue(AParser: TParser);
var
  TokenStr: String;
  Items: TStringList;
begin
  Items := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);

  AParser.NextToken;
  if AParser.Token <> ']' then
    while True do
    begin
      TokenStr := AParser.TokenString;
      case AParser.Token of
        toInteger: begin end;
        System.Classes.toString,toWString: TokenStr := '#' + IntToStr(Ord(TokenStr.Chars[0]));
      else
        AParser.CheckToken(toSymbol);
      end;
      Items.Add(TokenStr);
      if AParser.NextToken = ']' then Break;
      AParser.CheckToken(',');
      AParser.NextToken;
    end;
  AParser.NextToken;

  FValue := TPropValue.CreateSetVal(Items);
end;

{ TFmxProperty }

constructor TFmxProperty.Create(const AName: string; const AValue: TPropValue);
begin
  FName := AName;
  FValue := AValue;
end;

constructor TFmxProperty.CreateFromLine(const APropLine: string);
var
  PropEqSign: Integer;
begin
  PropEqSign := APropLine.IndexOf('=');
  FName := APropLine.Substring(0, PropEqSign).Trim;
  FValue := TPropValue.CreateSymbolVal(APropLine.Substring(PropEqSign + 1).Trim);
end;

function TFmxProperty.ToString(APad: String): String;
begin
  Result := APad + '  ' + FName + ' = ';

  if FValue.VType = vtString then
    Result := Result + WriteString(APad, FValue.Text)
  else
    Result := Result + FValue.Text;

  Result := Result + CRLF;
end;

function TFmxProperty.WriteString(const APad, AData: string): string;
var
  CurrPos, StartPos, Len: Integer;
  LineBreak: Boolean;
begin
  Result := ''; // compiler quirk
  if AData = '' then
    Result := Result + ''''''
  else
  begin
    Len := High(AData);
    CurrPos := Low(AData);
    StartPos := CurrPos;
    if Len > LineTruncLength then
      Result := Result + CRLF + APad + '    ';

    repeat
      LineBreak := False;
      if (AData[CurrPos] >= ' ') and (AData[CurrPos] <> '''') and (Ord(AData[CurrPos]) <= 127) then
      begin
        repeat
          Inc(CurrPos)
        until (CurrPos > Len) or (AData[CurrPos] < ' ') or (AData[CurrPos] = '''') or
          ((CurrPos - StartPos) >= LineTruncLength) or (Ord(AData[CurrPos]) > 127);

        if ((CurrPos - StartPos) >= LineTruncLength) then
          LineBreak := True;

        Result := Result + '''' + AData.Substring(StartPos - 1, CurrPos - StartPos) + '''';
      end
      else
      begin
        Result := Result +'#' + IntToStr(Ord(AData[CurrPos]));
        Inc(CurrPos);

        if ((CurrPos - StartPos) >= LineTruncLength) then
          LineBreak := True;
      end;

      if LineBreak and (CurrPos <= Len) then
      begin
        Result := Result + ' +' + CRLF + APad + '    ';
        StartPos := CurrPos;
      end;
    until CurrPos > Len;
  end;
end;

function TFmxDataProp.ToString(APad: String): String;
var
  Data: String;
begin
  Data := StreamToHex(FValue.Data);
  Result := APad + '  ' + FName + ' = {';
  Result := Result + BreakIntoLines(Data, APad) + '}' + CRLF;
end;

constructor TFmxImageProp.Create(const AName: string; AImage: TPngImage);
begin
  FName := AName;
  FPng := AImage;
end;

destructor TFmxImageProp.Destroy;
begin
  FPng.Free;
  inherited;
end;

function TFmxImageProp.ToString(APad: String): String;
var
  Width, Height: Integer;
  BitmapData: String;
begin
  if Assigned(FPng) then
  begin
    BitmapData := EncodePicture(FPng, APad + '    ');
    Height := FPng.Height;
    Width := FPng.Width;
  end
  else
    BitmapData := ConvertPicture(FValue.Data, APad + '    ', Width, Height);

  if FName = 'Picture.Data' then
    Result := APad + '  MultiResBitmap'
  else
    Result := APad + '  ' + FName;

  Result := Result + ' = <' +
    CRLF + APad + '    item ' +
    CRLF + APad + '      Width = ' + Width.ToString +
    CRLF + APad + '      Height = ' + Height.ToString +
    CRLF + APad + '      PNG = ' + BitmapData +
    CRLF + APad + '    end>' + CRLF;
end;

{ TFmxImageListProp }

function TFmxImageListProp.ToString(APad: String): String;
var
  ImageList: TImageList;
begin
  ImageList := TImageList.Create;
  try
    ParseImageList(FValue.Data, ImageList);
    Result := EncodeImageList(ImageList, APad) + CRLF;
  finally
    ImageList.Free;
  end;
end;

{ TFmxStringsProp }

function TFmxStringsProp.ToString(APad: String): String;
var
  Str: String;
begin
  Result := APad + '  ' + FName + ' = (';
  for Str in FValue.Strings do
    Result := Result + CRLF + APad + '    ' + WriteString(APad, Str);
  Result := Result + ')' + CRLF;
end;

{ TFmxItemsProp }

constructor TFmxItemsProp.Create(const AName: string);
begin
  FName := AName;
  FItems := TStringList.Create;
end;

destructor TFmxItemsProp.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TFmxItemsProp.ToString(APad: String): String;
var
  i: Integer;
begin
  Result := APad + '  ' + FName + ' = <' + CRLF + APad + '    ';
  for i := 0 to FItems.Count - 1 do
    Result := Result + FItems[i].Replace(CRLF, CRLF + APad + '    ');
  Result := Result.TrimRight([CR, LF, ' ']) + '>' + CRLF;
end;

{ TFmxSetProp }

function TFmxSetProp.ToString(APad: String): String;
var
  Item, Line: String;
begin
  Result := APad + '  ' + FName + ' = [';

  for Item in FValue.SetItems do
  begin
    Line := Line + Item + ', ';
    if Line.Length >= LineTruncLength then
    begin
      Result := Result + Line + CRLF + APad + '    ';
      Line := '';
    end;
  end;

  Result := Result + Line.TrimRight([',', ' ']) + ']' + CRLF;
end;

{ TFmxPictureProp }

function TFmxPictureProp.ToString(APad: String): String;
var
  Width, Height: Integer;
  BitmapData: String;
begin
  BitmapData := ConvertPicture(FValue.Data, APad, Width, Height);

  if FName.EndsWith('.Data') then
    FName := FName.Substring(0, FName.Length - 5);

  Result := APad + '  ' + FName + '.PNG = ' + BitmapData  + CRLF;
end;

{ TDfmProperties }

function TDfmProperties.FindByName(const AName: String): TDfmProperty;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = AName then
      Exit(Items[i]);
end;

function TDfmProperties.GetIntValueDef(const AName: String; ADef: Integer): Integer;
var
  Prop: TDfmProperty;
begin
  Prop := FindByName(AName);
  if Assigned(Prop) then
    Result := StrToIntDef(Prop.Value, ADef)
  else
    Result := ADef;
end;

{ TFmxProperties }

procedure TFmxProperties.AddMultipleProps(APropsText: String);
var
  PropsArray: TArray<String>;
  Prop: String;
begin
  PropsArray := APropsText.Split(['#NextProp#']);
  for Prop in PropsArray do
    Add(TFmxProperty.CreateFromLine(Prop));
end;

procedure TFmxProperties.AddProp(AProp: TFmxProperty);
begin
  if Assigned(AProp) then
    Add(AProp);
end;

function TFmxProperties.FindByName(AName: String): TFmxProperty;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = AName then
      Exit(Items[i]);
end;

end.
