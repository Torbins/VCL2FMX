unit CvtrProp;

interface

uses
  System.Classes, System.Generics.Collections, Vcl.Imaging.PngImage;

type
  TDfmProperty = class
  protected
    FName: String;
    FValue: string;
    function GetValue: String; virtual;
  public
    property Name: String read FName;
    property Value: String read GetValue write FValue;
    constructor Create(const AName: string); overload; virtual;
    constructor Create(const AName, AValue: string); overload; virtual;
    procedure ParseValue(AParser: TParser); virtual;
  end;

  TDfmDataProp = class(TDfmProperty)
  private
    FData: TMemoryStream;
  public
    property Data: TMemoryStream read FData;
    constructor Create(const AName: string); override;
    destructor Destroy; override;
    procedure ParseValue(AParser: TParser); override;
  end;

  TDfmStringsProp = class(TDfmProperty)
  protected
    FStrings: TStringList;
    function GetValue: String; override;
  public
    property Strings: TStringList read FStrings;
    constructor Create(const AName: string); override;
    destructor Destroy; override;
    procedure ParseValue(AParser: TParser); override;
  end;

  TDfmSetProp = class(TDfmProperty)
  protected
    FItems: TStringList;
  public
    property Items: TStringList read FItems;
    constructor Create(const AName: string); override;
    destructor Destroy; override;
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
    FValue: string;
    function GetValue: String; virtual;
  public
    property Name: String read FName;
    property Value: String read GetValue write FValue;
    constructor Create(const AName, AValue: string); overload; virtual;
    constructor CreateFromLine(const APropLine: string); virtual;
    function ToString(APad: String): String; reintroduce; virtual;
  end;

  TFmxDataProp = class(TFmxProperty)
  protected
    FData: TMemoryStream;
  public
    constructor Create(const AName: string; AStream: TStream); overload;
    destructor Destroy; override;
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
  protected
    FStrings: TStringList;
  public
    property Strings: TStringList read FStrings;
    constructor Create(const AName: string; AStrings: TStrings); overload; virtual;
    destructor Destroy; override;
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
  protected
    FItems: TStringList;
  public
    property Items: TStringList read FItems;
    constructor Create(const AName: string); overload;
    destructor Destroy; override;
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

constructor TDfmProperty.Create(const AName, AValue: string);
begin
  Create(AName);
  FValue := AValue;
end;

constructor TDfmProperty.Create(const AName: string);
begin
  FName := AName;
end;

function TDfmProperty.GetValue: String;
begin
  Result := FValue;
end;

procedure TDfmProperty.ParseValue(AParser: TParser);
begin
  FValue := FValue + AParser.TokenWideString;
  while AParser.NextToken = '+' do
  begin
    AParser.NextToken;
    if not (AParser.Token in [System.Classes.toString, toWString]) then
      AParser.CheckToken(System.Classes.toString);
    FValue := FValue + AParser.TokenWideString;
  end;
end;

{ TDfmStringsProp }

constructor TDfmStringsProp.Create(const AName: string);
begin
  inherited;
  FStrings := TStringList.Create;
end;

destructor TDfmStringsProp.Destroy;
begin
  FStrings.Free;
  inherited;
end;

function TDfmStringsProp.GetValue: String;
begin
  Result := FStrings.Text;
end;

procedure TDfmStringsProp.ParseValue(AParser: TParser);
begin
  AParser.NextToken;
  while AParser.Token <> ')' do inherited ParseValue(AParser);

  FStrings.Text := FValue;
  AParser.NextToken;
end;

{ TDfmDataProp }

constructor TDfmDataProp.Create(const AName: string);
begin
  inherited;
  FData := TMemoryStream.Create;
end;

destructor TDfmDataProp.Destroy;
begin
  FData.Free;
  inherited;
end;

procedure TDfmDataProp.ParseValue(AParser: TParser);
begin
  AParser.HexToBinary(FData);
  FData.Position := 0;
  AParser.NextToken;
end;

{ TFmxProperty }

constructor TFmxProperty.Create(const AName, AValue: string);
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
  FValue := APropLine.Substring(PropEqSign + 1).Trim;
end;

function TFmxProperty.GetValue: String;
begin
  Result := FValue;
end;

function TFmxProperty.ToString(APad: String): String;
var
  Line, Data: String;
  LineNum: Integer;
begin
  if (FValue.Length <= LineTruncLength) or (FValue[1] <> '''') then
    Result := APad + '  ' + FName + ' = ' + FValue + CRLF
  else
  begin
    Result := APad + '  ' + FName + ' = ';
    LineNum := 0;
    Data := FValue.DeQuotedString;

    repeat
      Line := Copy(Data, LineTruncLength * LineNum + 1, LineTruncLength);
      if Line <> '' then
        Result := Result + CRLF + APad + '    ' + Line.QuotedString + ' +';
      Inc(LineNum);
    until Length(Line) < LineTruncLength;

    Result := Result.TrimRight(['+', ' ']) + CRLF;
  end;
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
  if Assigned(FData) then
    BitmapData := ConvertPicture(FData, APad + '    ', Width, Height)
  else
    if Assigned(FPng) then
    begin
      BitmapData := EncodePicture(FPng, APad + '    ');
      Height := FPng.Height;
      Width := FPng.Width;
    end
    else
      raise Exception.Create('No data for image');

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
    ParseImageList(FData, ImageList);
    Result := EncodeImageList(ImageList, APad) + CRLF;
  finally
    ImageList.Free;
  end;
end;

{ TFmxStringsProp }

constructor TFmxStringsProp.Create(const AName: string; AStrings: TStrings);
begin
  FName := AName;
  FStrings := TStringList.Create;
  if not Assigned(AStrings) then
    raise Exception.Create('AStrings parameter should be assigned');
  FStrings.Assign(AStrings);
end;

destructor TFmxStringsProp.Destroy;
begin
  FStrings.Free;
  inherited;
end;

function TFmxStringsProp.ToString(APad: String): String;
var
  Str: String;
begin
  Result := APad + '  ' + FName + ' = (';
  for Str in FStrings do
    Result := Result + CRLF + APad + '    ' + Str;
  Result := Result + ')' + CRLF;
end;

{ TFmxDataProp }

constructor TFmxDataProp.Create(const AName: string; AStream: TStream);
begin
  FName := AName;
  FData := TMemoryStream.Create;
  FData.CopyFrom(AStream);
  FData.Position := 0;
end;

destructor TFmxDataProp.Destroy;
begin
  FData.Free;
  inherited;
end;

function TFmxDataProp.ToString(APad: String): String;
begin
  Result := APad + '  ' + FName + ' = {';
  Result := Result + BreakIntoLines(FValue, APad) + '}' + CRLF;
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

{ TDfmSetProp }

constructor TDfmSetProp.Create(const AName: string);
begin
  inherited;
  FItems := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
end;

destructor TDfmSetProp.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDfmSetProp.ParseValue(AParser: TParser);
var
  TokenStr: String;
begin
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
      FItems.Add(TokenStr);
      if AParser.NextToken = ']' then Break;
      AParser.CheckToken(',');
      AParser.NextToken;
    end;
  AParser.NextToken;
end;

{ TFmxSetProp }

constructor TFmxSetProp.Create(const AName: string);
begin
  FName := AName;
  FItems := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
end;

destructor TFmxSetProp.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TFmxSetProp.ToString(APad: String): String;
var
  Item, Line: String;
begin
  Result := APad + '  ' + FName + ' = [';

  for Item in FItems do
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
  BitmapData := ConvertPicture(FData, APad, Width, Height);

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
