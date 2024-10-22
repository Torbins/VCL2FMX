unit CvtrProp;

interface

uses
  System.Classes, System.Generics.Collections, CvtrObject;

type
  TDfmProperty = class(TDfmPropertyBase)
  public
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

  TDfmItemsProp = class(TDfmProperty)
  protected
    FItems: TDfmToFmxItems;
  public
    property Items: TDfmToFmxItems read FItems;
    constructor Create(const AName, AValue: string); override;
    destructor Destroy; override;
    procedure ReadItems(AParent: TDfmToFmxObject; AClassName: String; AStm: TStreamReader);
    procedure Transform(AItemStrings: TStrings);
  end;

  TFmxProperty = class(TFmxPropertyBase)
  public
    function ToString(APad: String): String; reintroduce; override;
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

  TFmxItemsProp= class(TFmxProperty)
  protected
    FItems: TStringList;
  public
    property Items: TStringList read FItems;
    constructor Create(const AName: string); overload;
    destructor Destroy; override;
    function ToString(APad: String): String; override;
  end;

implementation

uses
  System.SysUtils, System.StrUtils, PatchLib, Image, ImageList;

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

constructor TDfmItemsProp.Create(const AName, AValue: string);
begin
  inherited;
  FItems := TDfmToFmxItems.Create({AOwnsObjects} True);
end;

destructor TDfmItemsProp.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDfmItemsProp.ReadItems(AParent: TDfmToFmxObject; AClassName: String; AStm: TStreamReader);
var
  Data: String;
  ClosingBracketFound: Boolean;
begin
  if FValue.EndsWith('>') then
    Exit;

  ClosingBracketFound := False;
  Data := Trim(AStm.ReadLine);
  while (not EndsText('>', Data)) and (not ClosingBracketFound) do
  begin
    if Data.StartsWith('item') then
      FItems.Add(TDfmToFmxItem.CreateItem(AParent, AClassName, AStm, ClosingBracketFound))
    else
      raise Exception.Create('Error reading items in ' + AParent.ObjName + '.' + FName);
    if not ClosingBracketFound then
      Data := Trim(AStm.ReadLine);
  end;
end;

procedure TDfmItemsProp.Transform(AItemStrings: TStrings);
var
  Item: TDfmToFmxItem;
  Transformed: String;
begin
  for Item in FItems do
  begin
    Transformed := Item.FMXFile;
    if Assigned(AItemStrings) then
      AItemStrings.Add(Transformed);
  end;
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

{ TFmxImageListProp }

function TFmxImageListProp.ToString(APad: String): String;
begin
  Result := ProcessImageList(FValue, APad) + CRLF;
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
  Result := Result.TrimRight([#13, #10, ' ']) + '>' + CRLF;
end;

end.
