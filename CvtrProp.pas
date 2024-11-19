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
    constructor Create(const AName, AValue: string); overload; virtual;
    procedure ReadMultiline(AStm: TStreamReader);
  end;

  TDfmDataProp = class(TDfmProperty)
  public
    procedure ReadData(AStm: TStreamReader);
  end;

  TDfmStringsProp = class(TDfmProperty)
  protected
    FStrings: TStringList;
    function GetValue: String; override;
  public
    property Strings: TStringList read FStrings;
    constructor Create(const AName, AValue: string); override;
    destructor Destroy; override;
    procedure ReadLines(AStm: TStreamReader);
  end;

  TDfmSetProp = class(TDfmProperty)
  protected
    FItems: TStringList;
  public
    property Items: TStringList read FItems;
    constructor Create(const AName, AValue: string); override;
    destructor Destroy; override;
    procedure ReadSetItems(AStm: TStreamReader);
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

  TFmxImageProp = class(TFmxProperty)
  protected
    FPng: TPngImage;
  public
    constructor Create(const AName: string; AImage: TPngImage); overload;
    destructor Destroy; override;
    function ToString(APad: String): String; override;
  end;

  TFmxImageListProp = class(TFmxProperty)
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

  TFmxDataProp = class(TFmxProperty)
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
  protected
    FItems: TStringList;
  public
    property Items: TStringList read FItems;
    constructor Create(const AName: string); overload;
    destructor Destroy; override;
    function ToString(APad: String): String; override;
  end;

  TFmxPictureProp = class(TFmxProperty)
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
  FName := AName;
  FValue := AValue;
end;

function TDfmProperty.GetValue: String;
begin
  Result := FValue;
end;

procedure TDfmProperty.ReadMultiline(AStm: TStreamReader);
var
  Data: String;
  Quoted: Boolean;
begin
  Data := AStm.ReadLine.Trim;
  Quoted := Data[1] = '''';
  while Data.EndsWith('+') do
  begin
    if Quoted then
      FValue := FValue + Data.Trim(['+']).Trim.DeQuotedString
    else
      FValue := FValue + Data.Trim(['+']).Trim;
    Data := Trim(AStm.ReadLine);
  end;
  if Quoted then
    FValue := FValue + Data.Trim(['+']).Trim.DeQuotedString
  else
    FValue := FValue + Data.Trim(['+']).Trim;
  FValue := FValue.QuotedString;
end;

{ TDfmStringsProp }

constructor TDfmStringsProp.Create(const AName, AValue: string);
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

procedure TDfmStringsProp.ReadLines(AStm: TStreamReader);
var
  Data: String;
begin
  if FValue.EndsWith(')') then
    Exit;

  Data := Trim(AStm.ReadLine);

  while not Data.EndsWith(')') do
  begin
    FStrings.Add(Data);
    Data := Trim(AStm.ReadLine);
  end;

  FStrings.Add(Data.TrimRight([')']));
end;

{ TDfmDataProp }

procedure TDfmDataProp.ReadData(AStm: TStreamReader);
var
  Data: String;
begin
  if FValue.EndsWith('}') then
  begin
    FValue := FValue.Trim(['{', '}']);
    Exit;
  end;

  FValue := FValue.TrimLeft(['{']);
  Data := Trim(AStm.ReadLine);

  while not Data.EndsWith('}') do
  begin
    FValue := FValue + Data;
    Data := Trim(AStm.ReadLine);
  end;

  FValue := FValue + Data.TrimRight(['}']);
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
    Result := APad + '  ' + FName + ' =';
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
  if not Assigned(FPng) then
    BitmapData := ConvertPicture(FValue, APad + '    ', Width, Height)
  else
  begin
    BitmapData := EncodePicture(FPng, APad + '    ');
    Height := FPng.Height;
    Width := FPng.Width;
  end;

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
    ParseImageList(FValue, ImageList);
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

constructor TDfmSetProp.Create(const AName, AValue: string);
begin
  inherited;
  FItems := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
end;

destructor TDfmSetProp.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDfmSetProp.ReadSetItems(AStm: TStreamReader);
var
  Data: String;

  procedure AddItems(const AItemsLine: String);
  var
    ItemsArray: TArray<String>;
    Item: String;
  begin
    ItemsArray := AItemsLine.TrimRight([',']).Split([', ']);
    for Item in ItemsArray do
      FItems.Add(Item);
  end;

begin
  AddItems(FValue.Trim(['[', ']']));
  if FValue.EndsWith(']') then
    Exit;

  Data := Trim(AStm.ReadLine);
  while not Data.EndsWith(']') do
  begin
    AddItems(Data);
    Data := Trim(AStm.ReadLine);
  end;

  AddItems(Data.TrimRight([']']));
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
  BitmapData := ConvertPicture(FValue, APad, Width, Height);

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
