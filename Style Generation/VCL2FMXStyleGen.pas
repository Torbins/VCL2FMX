unit VCL2FMXStyleGen;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts, FMX.Styles.Objects;

type
  TStyleGenerator = class(TComponent)
  private
    function Lookup(const AStyleLookup: string; const Clone: Boolean = False): TFmxObject;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function ReadParam(const AStyleLookup, AType, AParam: String): String;
    function ReadParamDef(const AStyleLookup, AType, AParam, ADefault: String): String;
    function WriteParam(const AStyleLookup, AType, AParam, AValue: String): String;
  end;

  TLabelStyleHelper = class helper for TLabel
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
  public
    property Color: TAlphaColor read GetColor write SetColor;
  end;

  TGroupBoxStyleHelper = class helper for TGroupBox
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
    function GetShowFrame: Boolean;
    procedure SetShowFrame(const Value: Boolean);
  public
    property Color: TAlphaColor read GetColor write SetColor;
    property ShowFrame: Boolean read GetShowFrame write SetShowFrame;
  end;

const
  CLabelStyle = 'VCL2FMXLabelStyle';
  CGroupBoxStyle = 'VCL2FMXGroupBoxStyle';
  CPanelStyle = 'VCL2FMXPanelStyle';
  CScrollBoxStyle = 'VCL2FMXScrollBoxStyle';
  CBackgroundColor = 'BackgroundColor';
  CShowFrame = 'ShowFrame';

var
  StyleGenerator: TStyleGenerator;

implementation

uses
  System.UIConsts, REST.Utils;

type
  TShadowedText = class(TText)
  private
    FShadow: TControl;
    procedure SetShadow(const Value: TControl);
  protected
    procedure FreeNotification(AObject: TObject); override;
    procedure Resize; override;
  public
    property Shadow: TControl read FShadow write SetShadow;
  end;

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
  Style, Background, Content, SmallScrolls, GripContent, GripBottom: TLayout;
  Rectangle, Shadow: TRectangle;
  StyleText: TText;
  ShadowedText: TShadowedText;
  VScrollBar, HScrollBar: TScrollBar;
  VSmallScrollBar, HSmallScrollBar: TSmallScrollBar;
  Grip: TSizeGrip;
  Parameters: TStrings;
begin
  Parameters := nil;
  try
    ExtractGetParams(AStyleLookup, Parameters);

    if AStyleLookup.StartsWith(CGroupBoxStyle) then
    begin
      Style := TLayout.Create(Self);
      Style.StyleName := CGroupBoxStyle;
      Style.Padding.Left := 2;
      Style.Padding.Top := 8;
      Style.Padding.Right := 2;
      Style.Padding.Bottom := 2;

      Rectangle := TRectangle.Create(Style);
      Rectangle.Parent := Style;
      Rectangle.StyleName := 'background';
      Rectangle.Align := TAlignLayout.Client;
      if Parameters.IndexOfName(CBackgroundColor) >= 0 then
        Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor])
      else
        Rectangle.Fill.Color := claNull;
      Rectangle.Stroke.Color := claGainsboro;
      if not StrToBoolDef(Parameters.Values[CShowFrame], True) then
        Rectangle.Stroke.Kind := TBrushKind.None;

      Shadow := TRectangle.Create(Rectangle);
      Shadow.Parent := Rectangle;
      Shadow.ClipParent := True;
      Shadow.Fill.Color := Rectangle.Fill.Color;
      Shadow.HitTest := False;
      Shadow.Stroke.Kind := TBrushKind.None;

      ShadowedText := TShadowedText.Create(Rectangle);
      ShadowedText.Parent := Rectangle;
      ShadowedText.Shadow := Shadow;
      ShadowedText.StyleName := 'text';
      ShadowedText.AutoSize := True;
      ShadowedText.ClipParent := True;
      ShadowedText.HitTest := False;
      ShadowedText.Margins.Left := 1;
      ShadowedText.Margins.Top := 2;
      ShadowedText.Margins.Right := 1;
      ShadowedText.Position.X := 15;
      ShadowedText.Position.Y := -8;
      ShadowedText.TextSettings.WordWrap := False;

      Result := Style;
    end
    else
    if AStyleLookup.StartsWith(CLabelStyle) then
    begin
      Style := TLayout.Create(Self);
      Style.StyleName := CLabelStyle;

      if Parameters.IndexOfName(CBackgroundColor) >= 0 then
      begin
        Rectangle := TRectangle.Create(Style);
        Rectangle.Parent := Style;
        Rectangle.Align := TAlignLayout.Client;
        Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor]);
        Rectangle.HitTest := False;
        Rectangle.Stroke.Kind := TBrushKind.None;
      end;

      StyleText := TText.Create(Style);
      StyleText.Parent := Style;
      StyleText.StyleName := 'text';
      StyleText.Align := TAlignLayout.Client;
      StyleText.HitTest := False;

      Result := Style;
    end
    else
    if AStyleLookup.StartsWith(CPanelStyle) then
    begin
      Rectangle := TRectangle.Create(Self);
      Rectangle.StyleName := CPanelStyle;
      if Parameters.IndexOfName(CBackgroundColor) >= 0 then
        Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor])
      else
        Rectangle.Fill.Color := $FFF0F0F0;
      Rectangle.HitTest := False;
      Rectangle.Stroke.Color := $FFA3A3A3;
      Rectangle.XRadius := 2;
      Rectangle.YRadius := 2;

      Result := Rectangle;
    end
    else
    if AStyleLookup.StartsWith(CScrollBoxStyle) then
    begin
      Style := TLayout.Create(Self);
      Style.StyleName := CScrollBoxStyle;

      Background := TLayout.Create(Style);
      Background.Parent := Style;
      Background.StyleName := 'background';
      Background.Align := TAlignLayout.Contents;

      Content := TLayout.Create(Background);
      Content.Parent := Background;
      Content.StyleName := 'content';
      Content.Align := TAlignLayout.Client;

      if Parameters.IndexOfName(CBackgroundColor) >= 0 then
      begin
        Rectangle := TRectangle.Create(Content);
        Rectangle.Parent := Content;
        Rectangle.Align := TAlignLayout.Client;
        Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor]);
        Rectangle.HitTest := False;
        Rectangle.Stroke.Kind := TBrushKind.None;
      end;

      VScrollBar := TScrollBar.Create(Background);
      VScrollBar.Parent := Background;
      VScrollBar.StyleName := 'vscrollbar';
      VScrollBar.Align := TAlignLayout.Right;
      VScrollBar.SmallChange := 0;
      VScrollBar.Orientation := TOrientation.Vertical;
      VScrollBar.Size.Width := 16;
      VScrollBar.Size.PlatformDefault := False;

      HScrollBar := TScrollBar.Create(Background);
      HScrollBar.Parent := Background;
      HScrollBar.StyleName := 'hscrollbar';
      HScrollBar.Align := TAlignLayout.Bottom;
      HScrollBar.SmallChange := 0;
      HScrollBar.Orientation := TOrientation.Horizontal;
      HScrollBar.Size.Height := 16;
      HScrollBar.Size.PlatformDefault := False;

      SmallScrolls := TLayout.Create(Background);
      SmallScrolls.Parent := Background;
      SmallScrolls.Align := TAlignLayout.Client;

      VSmallScrollBar := TSmallScrollBar.Create(SmallScrolls);
      VSmallScrollBar.Parent := SmallScrolls;
      VSmallScrollBar.StyleName := 'vsmallscrollbar';
      VSmallScrollBar.Align := TAlignLayout.Right;
      VSmallScrollBar.SmallChange := 0;
      VSmallScrollBar.Orientation := TOrientation.Vertical;
      VSmallScrollBar.Size.Width := 8;
      VSmallScrollBar.Visible := False;

      HSmallScrollBar := TSmallScrollBar.Create(SmallScrolls);
      HSmallScrollBar.Parent := SmallScrolls;
      HSmallScrollBar.StyleName := 'hsmallscrollbar';
      HSmallScrollBar.Align := TAlignLayout.Bottom;
      HSmallScrollBar.SmallChange := 0;
      HSmallScrollBar.Orientation := TOrientation.Horizontal;
      HSmallScrollBar.Size.Height := 8;
      HSmallScrollBar.Visible := False;

      GripContent := TLayout.Create(Background);
      GripContent.Parent := Background;
      GripContent.Align := TAlignLayout.Contents;
      
      GripBottom := TLayout.Create(GripContent);
      GripBottom.Parent := GripContent;
      GripBottom.Align := TAlignLayout.Contents;

      Grip := TSizeGrip.Create(GripBottom);
      Grip.Parent := GripBottom;
      Grip.StyleName := 'sizegrip';
      Grip.Align := TAlignLayout.Right;
      Grip.Size.Width := 16;
      Grip.Size.Height := 16;
      Grip.Size.PlatformDefault := False;

      Result := Style;
    end
    else
      Result := nil;
  finally
    Parameters.Free;
  end;
end;

function TStyleGenerator.ReadParam(const AStyleLookup, AType, AParam: String): String;
var
  Parameters: TStrings;
begin
  Result := '';
  if AStyleLookup.StartsWith(AType, {IgnoreCase} True) then
  begin
    Parameters := nil;
    try
      ExtractGetParams(AStyleLookup, Parameters);
      Result := Parameters.Values[AParam];
    finally
      Parameters.Free;
    end;
  end;
end;

function TStyleGenerator.ReadParamDef(const AStyleLookup, AType, AParam, ADefault: String): String;
begin
  Result := StyleGenerator.ReadParam(AStyleLookup, AType, AParam);
  if Result = '' then
    Result := ADefault;
end;

function TStyleGenerator.WriteParam(const AStyleLookup, AType, AParam, AValue: String): String;
var
  Parameters: TStrings;
begin
  if AStyleLookup.StartsWith(AType, {IgnoreCase} True) then
  begin
    Parameters := nil;
    try
      ExtractGetParams(AStyleLookup, Parameters);
      Parameters.Values[AParam] := AValue;
      Result := AType + '?' + Parameters.DelimitedText;
    finally
      Parameters.Free;
    end;
  end
  else
    Result := AType + '?' + AParam + '=' + AValue;
end;

{ TLabelStyleHelper }

function TLabelStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CLabelStyle, CBackgroundColor, 'claNull'));
end;

procedure TLabelStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CLabelStyle, CBackgroundColor, AlphaColorToString(Value));
end;

{ TShadowedText }

procedure TShadowedText.FreeNotification(AObject: TObject);
begin
  inherited;
  if AObject = FShadow then
    FShadow := nil;
end;

procedure TShadowedText.Resize;
begin
  inherited;
  if Assigned(FShadow) then
    FShadow.SetBounds(Position.X, Position.Y, Size.Width, Size.Height);
end;

procedure TShadowedText.SetShadow(const Value: TControl);
begin
  if Assigned(FShadow) then
    FShadow.RemoveFreeNotify(Self);
  if Assigned(Value) then
    Value.AddFreeNotify(Self);
  FShadow := Value;
end;

{ TGroupBoxStyleHelper }

function TGroupBoxStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CGroupBoxStyle, CBackgroundColor, 'claNull'));
end;

function TGroupBoxStyleHelper.GetShowFrame: Boolean;
begin
  Result := StyleGenerator.ReadParamDef(StyleLookup, CGroupBoxStyle, CShowFrame, 'True').ToBoolean;
end;

procedure TGroupBoxStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CGroupBoxStyle, CBackgroundColor, AlphaColorToString(Value));
end;

procedure TGroupBoxStyleHelper.SetShowFrame(const Value: Boolean);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CGroupBoxStyle, CShowFrame,
    BoolToStr(Value, {UseBoolStrs} True));
end;

initialization
  StyleGenerator := TStyleGenerator.Create(nil);

finalization
  StyleGenerator.Free;

end.
