unit CvtrProp;

interface

uses
  System.Classes, System.Generics.Collections;

type
  TDfmProperty = class
  private
    FName: String;
    FValue: string;
    function GetValue: String; virtual;
    procedure SetValue(const Value: String);
  public
    property Name: String read FName write FName;
    property Value: String read GetValue write SetValue;
    constructor Create(const AName, AValue: string); virtual;
    procedure ReadMultiline(AStm: TStreamReader);
  end;

  TDfmProperties = class(TObjectList<TDfmProperty>)
  public
    function FindByName(AName: String): TDfmProperty;
  end;

  TDfmDataProp = class(TDfmProperty)
  public
    procedure ReadData(AStm: TStreamReader);
  end;

  TDfmStringsProp = class(TDfmProperty)
  private
    FStrings: TStringList;
    function GetValue: String; override;
  public
    property Strings: TStringList read FStrings;
    constructor Create(const AName, AValue: string); override;
    destructor Destroy; override;
    procedure ReadLines(AStm: TStreamReader);
  end;

  TDfmItemsProp = class(TDfmProperty)
  public
    procedure ReadItems(AStm: TStreamReader);
  end;

  TFmxProperty = class
  private
    FName: String;
    FValue: string;
    function GetValue: String; virtual;
    procedure SetValue(const Value: String);
  public
    property Name: String read FName write FName;
    property Value: String read GetValue write SetValue;
    constructor Create(const AName, AValue: string); overload; virtual;
    constructor Create(const APropLine: string); overload; virtual;
    function ToString(APad: String): String; reintroduce; virtual;
  end;

  TFmxProperties = class(TObjectList<TFmxProperty>)
  public
    procedure AddProp(AProp: TFmxProperty);
    procedure AddMultipleProps(APropsText: String);
    function FindByName(AName: String): TFmxProperty;
  end;

  TFmxImageProp = class(TFmxProperty)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxImageListProp = class(TFmxProperty)
  public
    function ToString(APad: String): String; override;
  end;

  TFmxStringsProp = class(TFmxProperty)
  private
    FStrings: TStrings;
  public
    constructor Create(const AName: string; AStrings: TStrings); overload; virtual;
    function ToString(APad: String): String; override;
  end;

  TFmxDataProp = class(TFmxProperty)
  public
    function ToString(APad: String): String; override;
  end;

implementation

uses
  System.SysUtils, System.StrUtils, PatchLib, Image, ImageList;

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
  while EndsText('+', Data) do
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

procedure TDfmProperty.SetValue(const Value: String);
begin
  FValue := Value;
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

  while not EndsText(')', Data) do
  begin
    FStrings.Add(Data);
    Data := Trim(AStm.ReadLine);
  end;

  FStrings.Add(Data.TrimRight([')']));
end;

{ TDfmItemsProp }

procedure TDfmItemsProp.ReadItems(AStm: TStreamReader);
var
  Data: String;
begin
  if FValue.EndsWith('>') then
    Exit;

  Data := Trim(AStm.ReadLine);

  while not EndsText('>', Data) do
  begin
    FValue := FValue + #13 + Data;
    Data := Trim(AStm.ReadLine);
  end;

  FValue := FValue + #13 + Data;
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

  while not EndsText('}', Data) do
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

constructor TFmxProperty.Create(const APropLine: string);
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

procedure TFmxProperty.SetValue(const Value: String);
begin
  FValue := Value;
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

function TFmxImageProp.ToString(APad: String): String;
begin
  if FName = 'Picture.Data' then
    Result := APad + '  MultiResBitmap'
  else
    Result := APad + '  ' + FName;
  Result := Result + ProcessImage(FValue, APad) + CRLF;
end;

{ TFmxProperties }

procedure TFmxProperties.AddMultipleProps(APropsText: String);
var
  PropsArray: TArray<String>;
  Prop: String;
begin
  PropsArray := APropsText.Split(['#NextProp#']);
  for Prop in PropsArray do
    Add(TFmxProperty.Create(Prop));
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

{ TFmxImageListProp }

function TFmxImageListProp.ToString(APad: String): String;
begin
  Result := ProcessImageList(FValue, APad) + CRLF;
end;

{ TDfmProperties }

function TDfmProperties.FindByName(AName: String): TDfmProperty;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = AName then
      Exit(Items[i]);
end;

{ TFmxStringsProp }

constructor TFmxStringsProp.Create(const AName: string; AStrings: TStrings);
begin
  FName := AName;
  FStrings := AStrings;
  if not Assigned(AStrings) then
    raise Exception.Create('AStrings parameter should be assigned');
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

end.
