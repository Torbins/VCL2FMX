unit CvtrProp;

interface

uses
  System.Classes;

type
  TDfmToFmxProperty = class
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

  TDfmToFmxDataProp = class(TDfmToFmxProperty)
  public
    procedure ReadData(AStm: TStreamReader);
  end;

  TDfmToFmxStringsProp = class(TDfmToFmxProperty)
  private
    FStrings: TStringList;
    function GetValue: String; override;
  public
    property Strings: TStringList read FStrings;
    constructor Create(const AName, AValue: string); override;
    destructor Destroy; override;
    procedure ReadLines(AStm: TStreamReader);
  end;

  TDfmToFmxItemsProp = class(TDfmToFmxProperty)
  public
    procedure ReadItems(AStm: TStreamReader);
  end;

implementation

uses
  System.SysUtils, System.StrUtils, PatchLib;

{ TDfmToFmxProperty }

constructor TDfmToFmxProperty.Create(const AName, AValue: string);
begin
  FName := AName;
  FValue := AValue;
end;

function TDfmToFmxProperty.GetValue: String;
begin
  Result := FValue;
end;

procedure TDfmToFmxProperty.ReadMultiline(AStm: TStreamReader);
var
  Data: String;
begin
  Data := Trim(AStm.ReadLine);
  while EndsText('+', Data) do
  begin
    FValue := FValue + Data + CRLF;
    Data := Trim(AStm.ReadLine);
  end;
  FValue := FValue + Data;
end;

procedure TDfmToFmxProperty.SetValue(const Value: String);
begin
  FValue := Value;
end;

{ TDfmToFmxStringsProp }

constructor TDfmToFmxStringsProp.Create(const AName, AValue: string);
begin
  inherited;
  FStrings := TStringList.Create;
end;

destructor TDfmToFmxStringsProp.Destroy;
begin
  FStrings.Free;
  inherited;
end;

function TDfmToFmxStringsProp.GetValue: String;
begin
  Result := '('#13#10 + FStrings.Text + ')';
end;

procedure TDfmToFmxStringsProp.ReadLines(AStm: TStreamReader);
var
  Data: String;
begin
  Data := Trim(AStm.ReadLine);
  while not EndsText(')', Data) do
  begin
    FStrings.Add(Data);
    Data := Trim(AStm.ReadLine);
  end;
  FStrings.Add(Data.Trim([')']));
end;

{ TDfmToFmxItemsProp }

procedure TDfmToFmxItemsProp.ReadItems(AStm: TStreamReader);
var
  Data: String;
begin
  Data := Trim(AStm.ReadLine);

  while not EndsText('>', Data) do
  begin
    FValue := FValue + #13 + Data;
    Data := Trim(AStm.ReadLine);
  end;

  FValue := FValue + #13 + Data;
end;

{ TDfmToFmxDataProp }

procedure TDfmToFmxDataProp.ReadData(AStm: TStreamReader);
var
  Data: String;
begin
  Data := Trim(AStm.ReadLine);
  while not EndsText('}', Data) do
  begin
    FValue := FValue + Data;
    Data := Trim(AStm.ReadLine);
  end;
  FValue := FValue + Data;
end;

end.
