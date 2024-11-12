unit VCL2FMXStyleGen;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts;

type
  TStyleGenerator = class(TComponent)
  private
    function Lookup(const AStyleLookup: string; const Clone: Boolean = False): TFmxObject;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TLabelStyleHelper = class helper for TLabel
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
  public
    property Color: TAlphaColor read GetColor write SetColor;
  end;

const
  LabelStyle = 'VCL2FMXLabelStyle';
  BackgroundColor = 'BackgroundColor';

var
  StyleGenerator: TStyleGenerator;

implementation

uses
  System.UIConsts, REST.Utils;

{ TStyleGenerator }

constructor TStyleGenerator.Create(AOwner: TComponent);
begin
  inherited;
  AddCustomFindStyleResource(Lookup);
end;

destructor TStyleGenerator.Destroy;
begin
  RemoveCustomFindStyleResource(Lookup);
  inherited;
end;

function TStyleGenerator.Lookup(const AStyleLookup: string; const Clone: Boolean): TFmxObject;
var
  Style: TLayout;
  Rectangle: TRectangle;
  StyleText: TText;
  Parameters: TStrings;
begin
  Parameters := nil;
  try
    if AStyleLookup.StartsWith(LabelStyle) then
    begin
      ExtractGetParams(AStyleLookup, Parameters);

      Style := TLayout.Create(Self);
      Style.StyleName := LabelStyle;

      if Parameters.IndexOfName(BackgroundColor) >= 0 then
      begin
        Rectangle := TRectangle.Create(Style);
        Rectangle.Parent := Style;
        Rectangle.Align := TAlignLayout.Client;
        Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[BackgroundColor]);
        Rectangle.Locked := True;
        Rectangle.HitTest := False;
        Rectangle.Stroke.Kind := TBrushKind.None;
      end;

      StyleText := TText.Create(Style);
      StyleText.Parent := Style;
      StyleText.StyleName := 'text';
      StyleText.Align := TAlignLayout.Client;
      StyleText.Locked := True;
      StyleText.HitTest := False;

      Result := Style;
    end
    else
      Result := nil;
  finally
    Parameters.Free;
  end;
end;

{ TLabelStyleHelper }

function TLabelStyleHelper.GetColor: TAlphaColor;
var
  Parameters: TStrings;
begin
  Result := TAlphaColors.Null;
  if StyleLookup.StartsWith(LabelStyle) then
  try
    Parameters := nil;
    ExtractGetParams(StyleLookup, Parameters);
    if Parameters.IndexOfName(BackgroundColor) >= 0 then
      Result := StringToAlphaColor(Parameters.Values[BackgroundColor]);
  finally
    Parameters.Free;
  end;
end;

procedure TLabelStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := LabelStyle + '?' + BackgroundColor + '=' + AlphaColorToString(Value);
end;

initialization
  StyleGenerator := TStyleGenerator.Create(nil);

finalization
  StyleGenerator.Free;

end.
