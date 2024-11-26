unit VCL2FMXStyleGen;

interface

uses
  System.UITypes, System.Classes, FMX.Types, FMX.StdCtrls, FMX.Layouts;

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

  TCheckBoxStyleHelper = class helper for TCheckBox
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

  TLabelStyleHelper = class helper for TLabel
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
  public
    property Color: TAlphaColor read GetColor write SetColor;
  end;

  TPanelStyleHelper = class helper for TPanel
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
    function GetParentBackground: Boolean;
    procedure SetParentBackground(const Value: Boolean);
  public
    property Color: TAlphaColor read GetColor write SetColor;
    property ParentBackground: Boolean read GetParentBackground write SetParentBackground;
  end;

  TRadioButtonStyleHelper = class helper for TRadioButton
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
  public
    property Color: TAlphaColor read GetColor write SetColor;
  end;

  TScrollBoxStyleHelper = class helper for TScrollBox
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
    function GetParentBackground: Boolean;
    procedure SetParentBackground(const Value: Boolean);
  public
    property Color: TAlphaColor read GetColor write SetColor;
    property ParentBackground: Boolean read GetParentBackground write SetParentBackground;
  end;

const
  CCheckBoxStyle = 'VCL2FMXCheckBoxStyle';
  CGroupBoxStyle = 'VCL2FMXGroupBoxStyle';
  CLabelStyle = 'VCL2FMXLabelStyle';
  CPanelStyle = 'VCL2FMXPanelStyle';
  CRadioButtonStyle = 'VCL2FMXRadioButtonStyle';
  CScrollBoxStyle = 'VCL2FMXScrollBoxStyle';
  CBackgroundColor = 'BackgroundColor';
  CShowFrame = 'ShowFrame';
  CColorBtnFace = 'xFFF0F0F0';

var
  StyleGenerator: TStyleGenerator;

implementation

uses
  System.SysUtils, System.UIConsts, REST.Utils, Winapi.UxTheme, FMX.Objects, FMX.Controls, FMX.Graphics, FMX.Effects,
  FMX.Styles.Objects, VCL2FMXWinThemes;

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
  Parameters: TStrings;

  function GenerateCheckBoxStyle: TFmxObject;
  const
    ButtonTheme = 'button';
  var
    Style, CheckLeft: TLayout;
    Rectangle: TRectangle;
    StyleText: TButtonStyleTextObject;
    Check: TCheckStyleObject;
    States: TStates;
    Glow: TGlowEffect;
  begin
    Style := TLayout.Create(Self);
    Style.StyleName := CCheckBoxStyle;

    if Parameters.IndexOfName(CBackgroundColor) >= 0 then
    begin
      Rectangle := TRectangle.Create(Style);
      Rectangle.Parent := Style;
      Rectangle.Align := TAlignLayout.Client;
      Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor]);
      Rectangle.HitTest := False;
      Rectangle.Stroke.Kind := TBrushKind.None;
    end;

    CheckLeft := TLayout.Create(Style);
    CheckLeft.Parent := Style;
    CheckLeft.Align := TAlignLayout.Left;
    CheckLeft.Size.Width := 18;
    CheckLeft.Size.PlatformDefault := False;

    Check := TCheckStyleObject.Create(CheckLeft);
    Check.Parent := CheckLeft;
    Check.StyleName := 'background';
    Check.Align := TAlignLayout.Center;
    Check.CapMode := TCapWrapMode.Tile;
    States := [CBS_UNCHECKEDNORMAL, CBS_CHECKEDNORMAL, CBS_UNCHECKEDHOT, CBS_CHECKEDHOT];
    Check.Source := CreateImage(ButtonTheme, BP_CHECKBOX, States);
    CalcLink(Check.SourceLink, CBS_UNCHECKEDNORMAL, ButtonTheme, BP_CHECKBOX, States);
    CalcLink(Check.ActiveLink, CBS_CHECKEDNORMAL, ButtonTheme, BP_CHECKBOX, States);
    CalcLink(Check.HotLink, CBS_UNCHECKEDHOT, ButtonTheme, BP_CHECKBOX, States);
    CalcLink(Check.ActiveHotLink, CBS_CHECKEDHOT, ButtonTheme, BP_CHECKBOX, States);
    CalcLink(Check.FocusedLink, CBS_UNCHECKEDHOT, ButtonTheme, BP_CHECKBOX, States);
    CalcLink(Check.ActiveFocusedLink, CBS_CHECKEDHOT, ButtonTheme, BP_CHECKBOX, States);
    Check.Size.Width := 15;
    Check.Size.Height := 15;
    Check.Size.PlatformDefault := False;
    Check.WrapMode := TImageWrapMode.Center;
    Check.ActiveTrigger := TStyleTrigger.Checked;

    Glow := TGlowEffect.Create(Check);
    Glow.Parent := Check;
    Glow.Softness := 0.2;
    Glow.GlowColor := GetThemeColor(ButtonTheme, BP_CHECKBOX, CBS_UNCHECKEDHOT, TMT_GLOWCOLOR);
    Glow.Opacity := 1;
    Glow.Trigger := 'IsFocused=true';
    Glow.Enabled := False;

    StyleText := TButtonStyleTextObject.Create(Style);
    StyleText.Parent := Style;
    StyleText.StyleName := 'text';
    StyleText.Align := TAlignLayout.Client;
    StyleText.Margins.Left := 3;
    StyleText.Size.PlatformDefault := False;
    StyleText.ShadowVisible := False;
    StyleText.HotColor := claBlack;
    StyleText.FocusedColor := claBlack;
    StyleText.NormalColor := claBlack;
    StyleText.PressedColor := claBlack;

    Result := Style;
  end;

  function GenerateGroupBoxStyle: TFmxObject;
  var
    Style: TLayout;
    Rectangle, Shadow: TRectangle;
    ShadowedText: TShadowedText;
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
  end;

  function GenerateLabelStyle: TFmxObject;
  var
    Style: TLayout;
    Rectangle: TRectangle;
    StyleText: TText;
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
  end;

  function GeneratePanelStyle: TFmxObject;
  var
    Rectangle: TRectangle;
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
  end;

  function GenerateRadioButtonStyle: TFmxObject;
  const
    ButtonTheme = 'button';
  var
    Style, CheckLeft: TLayout;
    Rectangle: TRectangle;
    StyleText: TButtonStyleTextObject;
    Check: TCheckStyleObject;
    States: TStates;
    Glow: TGlowEffect;
  begin
    Style := TLayout.Create(Self);
    Style.StyleName := CRadioButtonStyle;

    if Parameters.IndexOfName(CBackgroundColor) >= 0 then
    begin
      Rectangle := TRectangle.Create(Style);
      Rectangle.Parent := Style;
      Rectangle.Align := TAlignLayout.Client;
      Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor]);
      Rectangle.HitTest := False;
      Rectangle.Stroke.Kind := TBrushKind.None;
    end;

    CheckLeft := TLayout.Create(Style);
    CheckLeft.Parent := Style;
    CheckLeft.Align := TAlignLayout.Left;
    CheckLeft.Size.Width := 18;
    CheckLeft.Size.PlatformDefault := False;

    Check := TCheckStyleObject.Create(CheckLeft);
    Check.Parent := CheckLeft;
    Check.StyleName := 'background';
    Check.Align := TAlignLayout.Center;
    States := [RBS_UNCHECKEDNORMAL, RBS_CHECKEDNORMAL, RBS_UNCHECKEDHOT, RBS_CHECKEDHOT];
    Check.Source := CreateImage(ButtonTheme, BP_RADIOBUTTON, States);
    CalcLink(Check.SourceLink, RBS_UNCHECKEDNORMAL, ButtonTheme, BP_RADIOBUTTON, States);
    CalcLink(Check.ActiveLink, RBS_CHECKEDNORMAL, ButtonTheme, BP_RADIOBUTTON, States);
    CalcLink(Check.HotLink, RBS_UNCHECKEDHOT, ButtonTheme, BP_RADIOBUTTON, States);
    CalcLink(Check.ActiveHotLink, RBS_CHECKEDHOT, ButtonTheme, BP_RADIOBUTTON, States);
    CalcLink(Check.FocusedLink, RBS_UNCHECKEDHOT, ButtonTheme, BP_RADIOBUTTON, States);
    CalcLink(Check.ActiveFocusedLink, RBS_CHECKEDHOT, ButtonTheme, BP_RADIOBUTTON, States);
    Check.Size.Width := 15;
    Check.Size.Height := 15;
    Check.Size.PlatformDefault := False;
    Check.WrapMode := TImageWrapMode.Center;
    Check.ActiveTrigger := TStyleTrigger.Checked;

    Glow := TGlowEffect.Create(Check);
    Glow.Parent := Check;
    Glow.Softness := 0.2;
    Glow.GlowColor := GetThemeColor(ButtonTheme, BP_RADIOBUTTON, RBS_UNCHECKEDHOT, TMT_GLOWCOLOR);
    Glow.Opacity := 1;
    Glow.Trigger := 'IsFocused=true';
    Glow.Enabled := False;

    StyleText := TButtonStyleTextObject.Create(Style);
    StyleText.Parent := Style;
    StyleText.StyleName := 'text';
    StyleText.Align := TAlignLayout.Client;
    StyleText.Margins.Left := 3;
    StyleText.Size.PlatformDefault := False;
    StyleText.ShadowVisible := False;
    StyleText.HotColor := claBlack;
    StyleText.FocusedColor := claBlack;
    StyleText.NormalColor := claBlack;
    StyleText.PressedColor := claBlack;

    Result := Style;
  end;

  function GenerateScrollBoxStyle: TFmxObject;
  var
    Style, Background, Content, SmallScrolls, GripContent, GripBottom: TLayout;
    Rectangle: TRectangle;
    VScrollBar, HScrollBar: TScrollBar;
    VSmallScrollBar, HSmallScrollBar: TSmallScrollBar;
    Grip: TSizeGrip;
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
  end;

begin
  Parameters := nil;
  try
    ExtractGetParams(AStyleLookup, Parameters);

    if AStyleLookup.StartsWith(CCheckBoxStyle) then
      Result := GenerateCheckBoxStyle
    else
    if AStyleLookup.StartsWith(CGroupBoxStyle) then
      Result := GenerateGroupBoxStyle
    else
    if AStyleLookup.StartsWith(CLabelStyle) then
      Result := GenerateLabelStyle
    else
    if AStyleLookup.StartsWith(CPanelStyle) then
      Result := GeneratePanelStyle
    else
    if AStyleLookup.StartsWith(CRadioButtonStyle) then
      Result := GenerateRadioButtonStyle
    else
    if AStyleLookup.StartsWith(CScrollBoxStyle) then
      Result := GenerateScrollBoxStyle
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

{ TCheckBoxStyleHelper }

function TCheckBoxStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CCheckBoxStyle, CBackgroundColor, 'claNull'));
end;

procedure TCheckBoxStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CCheckBoxStyle, CBackgroundColor, AlphaColorToString(Value));
end;

{ TRadioButtonStyleHelper }

function TRadioButtonStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CRadioButtonStyle, CBackgroundColor, 'claNull'));
end;

procedure TRadioButtonStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CRadioButtonStyle, CBackgroundColor, AlphaColorToString(Value));
end;

{ TPanelStyleHelper }

function TPanelStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CPanelStyle, CBackgroundColor, 'claNull'));
end;

function TPanelStyleHelper.GetParentBackground: Boolean;
begin
  Result := StyleGenerator.ReadParamDef(StyleLookup, CPanelStyle, CBackgroundColor, 'claNull') = 'claNull';
end;

procedure TPanelStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CPanelStyle, CBackgroundColor, AlphaColorToString(Value));
end;

procedure TPanelStyleHelper.SetParentBackground(const Value: Boolean);
begin
  if Value then
    StyleLookup := StyleGenerator.WriteParam(StyleLookup, CPanelStyle, CBackgroundColor, 'claNull')
  else
    if StyleGenerator.ReadParamDef(StyleLookup, CPanelStyle, CBackgroundColor, 'claNull') = 'claNull' then
      StyleLookup := StyleGenerator.WriteParam(StyleLookup, CPanelStyle, CBackgroundColor, CColorBtnFace);
end;

{ TScrollBoxStyleHelper }

function TScrollBoxStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CPanelStyle, CBackgroundColor, CColorBtnFace));
end;

function TScrollBoxStyleHelper.GetParentBackground: Boolean;
begin
  Result := StyleGenerator.ReadParam(StyleLookup, CPanelStyle, CBackgroundColor) = 'claNull';
end;

procedure TScrollBoxStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CPanelStyle, CBackgroundColor, AlphaColorToString(Value));
end;

procedure TScrollBoxStyleHelper.SetParentBackground(const Value: Boolean);
begin
  if Value then
    StyleLookup := StyleGenerator.WriteParam(StyleLookup, CPanelStyle, CBackgroundColor, 'claNull')
  else
    if StyleGenerator.ReadParamDef(StyleLookup, CPanelStyle, CBackgroundColor, 'claNull') = 'claNull' then
      StyleLookup := StyleGenerator.WriteParam(StyleLookup, CPanelStyle, CBackgroundColor, CColorBtnFace);
end;

initialization
  StyleGenerator := TStyleGenerator.Create(nil);

finalization
  StyleGenerator.Free;

end.
