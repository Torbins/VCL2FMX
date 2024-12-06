unit VCL2FMXStyleGen;

interface

uses
  System.UITypes, System.Classes, FMX.Types, FMX.StdCtrls, FMX.Layouts, FMX.Edit, FMX.Memo;

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

  TButtonLayout = (blGlyphLeft, blGlyphRight, blGlyphTop, blGlyphBottom);
  TImageAlignment = (iaLeft, iaRight, iaTop, iaBottom);
  TButtonStyleHelper = class helper for TButton
  private
    function GetImageAlignment: TImageAlignment;
    function GetLayout: TButtonLayout;
    procedure SetImageAlignment(const Value: TImageAlignment);
    procedure SetLayout(const Value: TButtonLayout);
    function GetGlyphSize: Single;
    procedure SetGlyphSize(const Value: Single);
  public
    property GlyphSize: Single read GetGlyphSize write SetGlyphSize;
    property ImageAlignment: TImageAlignment read GetImageAlignment write SetImageAlignment;
    property Layout: TButtonLayout read GetLayout write SetLayout;
  end;

  TCheckBoxStyleHelper = class helper for TCheckBox
  private
    function GetColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
  public
    property Color: TAlphaColor read GetColor write SetColor;
  end;

  TEditStyleHelper = class helper for TEdit
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

  TMemoStyleHelper = class helper for TMemo
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

  TSpeedButtonStyleHelper = class helper for TSpeedButton
  private
    function GetLayout: TButtonLayout;
    procedure SetLayout(const Value: TButtonLayout);
    function GetGlyphSize: Single;
    procedure SetGlyphSize(const Value: Single);
  public
    property GlyphSize: Single read GetGlyphSize write SetGlyphSize;
    property Layout: TButtonLayout read GetLayout write SetLayout;
  end;

const
  CButtonStyle = 'VCL2FMXButtonStyle';
  CCheckBoxStyle = 'VCL2FMXCheckBoxStyle';
  CEditStyle = 'VCL2FMXEditStyle';
  CGroupBoxStyle = 'VCL2FMXGroupBoxStyle';
  CLabelStyle = 'VCL2FMXLabelStyle';
  CMemoStyle = 'VCL2FMXMemoStyle';
  CPanelStyle = 'VCL2FMXPanelStyle';
  CRadioButtonStyle = 'VCL2FMXRadioButtonStyle';
  CScrollBoxStyle = 'VCL2FMXScrollBoxStyle';
  CSpeedButtonStyle = 'VCL2FMXSpeedButtonStyle';
  CBackgroundColor = 'BackgroundColor';
  CGlyphPosition = 'GlyphPosition';
  CGlyphSize = 'GlyphSize';
  CShowFrame = 'ShowFrame';
  CColorBtnFace = 'xFFF0F0F0';

var
  StyleGenerator: TStyleGenerator;

implementation

uses
  System.SysUtils, System.UIConsts, System.Types, REST.Utils, Winapi.UxTheme, FMX.Objects, FMX.Controls, FMX.Graphics,
  FMX.Effects, FMX.Styles.Objects, FMX.ImgList, Winapi.Windows, VCL2FMXWinThemes;

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

  function GenerateButtonStyle: TFmxObject;
  const
    ButtonTheme = 'button';
  var
    Style: TLayout;
    Glyph: TGlyph;
    StyleText: TButtonStyleTextObject;
    Button: TButtonStyleObject;
    States: TStates;
    Glow: TGlowEffect;
    Size: TSize;
    GlyphPosition: String;
  begin
    Style := TLayout.Create(Self);
    Style.StyleName := CButtonStyle;
    Style.Align := TAlignLayout.Contents;

    Glow := TGlowEffect.Create(Style);
    Glow.Parent := Style;
    Glow.Softness := 0.2;
    Glow.GlowColor := GetThemeColor(ButtonTheme, BP_PUSHBUTTON, PBS_NORMAL, TMT_GLOWCOLOR);
    Glow.Opacity := 1;
    Glow.Trigger := 'IsFocused=true';
    Glow.Enabled := False;

    Button := TButtonStyleObject.Create(Style);
    Button.Parent := Style;
    Button.StyleName := 'background';
    Button.Align := TAlignLayout.Contents;
    States := [PBS_NORMAL, PBS_HOT, PBS_PRESSED];
    Size := TSize.Create(13, 13);
    Button.Source := CreateImage(ButtonTheme, BP_PUSHBUTTON, States, Size, Button);
    CalcLink(Button.NormalLink, PBS_NORMAL, States, Size, {AAddCapInsets} True);
    CalcLink(Button.PressedLink, PBS_PRESSED, States, Size, {AAddCapInsets} True);
    CalcLink(Button.HotLink, PBS_HOT, States, Size, {AAddCapInsets} True);
    CalcLink(Button.FocusedLink, PBS_HOT, States, Size, {AAddCapInsets} True);

    Glyph := TGlyph.Create(Style);
    Glyph.Parent := Style;
    Glyph.StyleName := 'glyphstyle';
    GlyphPosition := Parameters.Values[CGlyphPosition];
    if GlyphPosition.ToLower = 'top' then
    begin
      Glyph.Margins.Left := 2;
      Glyph.Margins.Top := 3;
      Glyph.Margins.Right := 2;
      Glyph.Margins.Bottom := 1;
      Glyph.Align := TAlignLayout.Top;
    end
    else
    if GlyphPosition.ToLower = 'right' then
    begin
      Glyph.Margins.Left := 1;
      Glyph.Margins.Top := 2;
      Glyph.Margins.Right := 3;
      Glyph.Margins.Bottom := 2;
      Glyph.Align := TAlignLayout.Right;
    end
    else
    if GlyphPosition.ToLower = 'bottom' then
    begin
      Glyph.Margins.Left := 2;
      Glyph.Margins.Top := 1;
      Glyph.Margins.Right := 2;
      Glyph.Margins.Bottom := 3;
      Glyph.Align := TAlignLayout.Bottom;
    end
    else
    begin
      Glyph.Margins.Left := 3;
      Glyph.Margins.Top := 2;
      Glyph.Margins.Right := 1;
      Glyph.Margins.Bottom := 2;
      Glyph.Align := TAlignLayout.Left;
    end;
    if Parameters.IndexOfName(CGlyphSize) >= 0 then
    begin
      Glyph.Size.Width := Parameters.Values[CGlyphSize].ToSingle;
      Glyph.Size.Height := Glyph.Size.Width;
    end
    else
    begin
      Glyph.Size.Width := 16;
      Glyph.Size.Height := 16;
    end;
    Glyph.Size.PlatformDefault := False;

    StyleText := TButtonStyleTextObject.Create(Style);
    StyleText.Parent := Style;
    StyleText.StyleName := 'text';
    StyleText.Align := TAlignLayout.Client;
    StyleText.Margins.Left := 2;
    StyleText.Margins.Top := 2;
    StyleText.Margins.Right := 2;
    StyleText.Margins.Bottom := 2;
    StyleText.Size.PlatformDefault := False;
    StyleText.ShadowVisible := False;
    StyleText.HotColor := GetSystemColor(COLOR_BTNTEXT);
    StyleText.FocusedColor := StyleText.HotColor;
    StyleText.NormalColor := StyleText.HotColor;
    StyleText.PressedColor := StyleText.HotColor;

    Result := Style;
  end;

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
    Size: TSize;
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
    Size := TSize.Create(0, 0);
    Check.Source := CreateImage(ButtonTheme, BP_CHECKBOX, States, Size, Check);
    CalcLink(Check.SourceLink, CBS_UNCHECKEDNORMAL, States, Size);
    CalcLink(Check.ActiveLink, CBS_CHECKEDNORMAL, States, Size);
    CalcLink(Check.HotLink, CBS_UNCHECKEDHOT, States, Size);
    CalcLink(Check.ActiveHotLink, CBS_CHECKEDHOT, States, Size);
    CalcLink(Check.FocusedLink, CBS_UNCHECKEDHOT, States, Size);
    CalcLink(Check.ActiveFocusedLink, CBS_CHECKEDHOT, States, Size);
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
    StyleText.HotColor := GetSystemColor(COLOR_BTNTEXT);
    StyleText.FocusedColor := StyleText.HotColor;
    StyleText.NormalColor := StyleText.HotColor;
    StyleText.PressedColor := StyleText.HotColor;

    Result := Style;
  end;

  function GenerateEditStyle: TFmxObject;
  const
    EditTheme = 'edit';
  var
    Style, Content, Buttons: TLayout;
    Rectangle: TRectangle;
    Glow: TGlowEffect;
    Edit: TActiveStyleObject;
    States: TStates;
    Size: TSize;
    Foreground, Selection: TBrushObject;
    Font: TFontObject;
    Prompt: TLabel;
  begin
    Style := TLayout.Create(Self);
    Style.StyleName := CEditStyle;

    Glow := TGlowEffect.Create(Style);
    Glow.Parent := Style;
    Glow.Softness := 0.2;
    Glow.GlowColor := GetThemeColor(EditTheme, EP_EDITBORDER_NOSCROLL, EPSN_NORMAL, TMT_GLOWCOLOR);
    Glow.Opacity := 1;
    Glow.Trigger := 'IsFocused=true';
    Glow.Enabled := False;

    Edit := TActiveStyleObject.Create(Style);
    Edit.Parent := Style;
    Edit.StyleName := 'background';
    Edit.Align := TAlignLayout.Contents;
    Edit.ActiveTrigger := TStyleTrigger.Focused;
    States := [EPSN_NORMAL, EPSN_FOCUSED];
    Size := TSize.Create(13, 13);
    Edit.Source := CreateImage(EditTheme, EP_EDITBORDER_NOSCROLL, States, Size, Edit);
    CalcLink(Edit.SourceLink, EPSN_NORMAL, States, Size, {AAddCapInsets} True);
    CalcLink(Edit.ActiveLink, EPSN_FOCUSED, States, Size, {AAddCapInsets} True);

    Content := TLayout.Create(Style);
    Content.Parent := Style;
    Content.StyleName := 'content';
    Content.Align := TAlignLayout.Client;
    Content.Margins.Left := 2;
    Content.Margins.Top := 2;
    Content.Margins.Right := 2;
    Content.Margins.Bottom := 2;
    Content.Size.PlatformDefault := False;

    if Parameters.IndexOfName(CBackgroundColor) >= 0 then
    begin
      Rectangle := TRectangle.Create(Content);
      Rectangle.Parent := Content;
      Rectangle.Align := TAlignLayout.Client;
      Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor]);
      Rectangle.HitTest := False;
      Rectangle.Stroke.Kind := TBrushKind.None;
    end;

    Buttons := TLayout.Create(Style);
    Buttons.Parent := Style;
    Buttons.StyleName := 'buttons';
    Buttons.Align := TAlignLayout.Right;
    Buttons.Margins.Top := 2;
    Buttons.Margins.Right := 2;
    Buttons.Margins.Bottom := 2;
    Buttons.Size.PlatformDefault := False;

    Foreground := TBrushObject.Create(Style);
    Foreground.Parent := Style;
    Foreground.StyleName := 'foreground';
    Foreground.Brush.Color := GetSystemColor(COLOR_WINDOWTEXT);

    Selection := TBrushObject.Create(Style);
    Selection.Parent := Style;
    Selection.StyleName := 'selection';
    Selection.Brush.Color := GetSystemColor(COLOR_HIGHLIGHT, $7F);

    Font := TFontObject.Create(Style);
    Font.Parent := Style;
    Font.StyleName := 'font';

    Prompt := TLabel.Create(Style);
    Prompt.Parent := Style;
    Prompt.StyleName := 'prompt';
    Prompt.Opacity := 0.5;
    Prompt.Visible := False;

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

  function GenerateMemoStyle: TFmxObject;
  const
    EditTheme = 'edit';
  var
    Style, Content, SmallScrolls: TLayout;
    Rectangle: TRectangle;
    Edit: TActiveStyleObject;
    States: TStates;
    Size: TSize;
    Foreground, Selection: TBrushObject;
    Font: TFontObject;
    VScrollBar, HScrollBar: TScrollBar;
    VSmallScrollBar, HSmallScrollBar: TSmallScrollBar;
  begin
    Style := TLayout.Create(Self);
    Style.StyleName := CMemoStyle;

    Edit := TActiveStyleObject.Create(Style);
    Edit.Parent := Style;
    Edit.StyleName := 'background';
    Edit.Align := TAlignLayout.Contents;
    Edit.ActiveTrigger := TStyleTrigger.Focused;
    Edit.Padding.Left := 2;
    Edit.Padding.Top := 2;
    Edit.Padding.Right := 2;
    Edit.Padding.Bottom := 2;
    States := [EPSN_NORMAL, EPSN_FOCUSED];
    Size := TSize.Create(13, 13);
    Edit.Source := CreateImage(EditTheme, EP_EDITBORDER_NOSCROLL, States, Size, Edit);
    CalcLink(Edit.SourceLink, EPSN_NORMAL, States, Size, {AAddCapInsets} True);
    CalcLink(Edit.ActiveLink, EPSN_FOCUSED, States, Size, {AAddCapInsets} True);

    Content := TLayout.Create(Edit);
    Content.Parent := Edit;
    Content.StyleName := 'content';
    Content.Align := TAlignLayout.Client;
    Content.Margins.Left := 2;
    Content.Margins.Top := 2;
    Content.Margins.Right := 2;
    Content.Margins.Bottom := 2;
    Content.Size.PlatformDefault := False;

    if Parameters.IndexOfName(CBackgroundColor) >= 0 then
    begin
      Rectangle := TRectangle.Create(Content);
      Rectangle.Parent := Content;
      Rectangle.Align := TAlignLayout.Client;
      Rectangle.Fill.Color := StringToAlphaColor(Parameters.Values[CBackgroundColor]);
      Rectangle.HitTest := False;
      Rectangle.Stroke.Kind := TBrushKind.None;
    end;

    VScrollBar := TScrollBar.Create(Edit);
    VScrollBar.Parent := Edit;
    VScrollBar.StyleName := 'vscrollbar';
    VScrollBar.Align := TAlignLayout.Right;
    VScrollBar.Cursor := crArrow;
    VScrollBar.SmallChange := 0;
    VScrollBar.Orientation := TOrientation.Vertical;
    VScrollBar.Size.Width := 16;
    VScrollBar.Size.PlatformDefault := False;

    HScrollBar := TScrollBar.Create(Edit);
    HScrollBar.Parent := Edit;
    HScrollBar.StyleName := 'hscrollbar';
    HScrollBar.Align := TAlignLayout.Bottom;
    HScrollBar.Cursor := crArrow;
    HScrollBar.SmallChange := 0;
    HScrollBar.Orientation := TOrientation.Horizontal;
    HScrollBar.Size.Height := 16;
    HScrollBar.Size.PlatformDefault := False;

    SmallScrolls := TLayout.Create(Edit);
    SmallScrolls.Parent := Edit;
    SmallScrolls.Align := TAlignLayout.Client;

    VSmallScrollBar := TSmallScrollBar.Create(SmallScrolls);
    VSmallScrollBar.Parent := SmallScrolls;
    VSmallScrollBar.StyleName := 'vsmallscrollbar';
    VSmallScrollBar.Align := TAlignLayout.Right;
    VSmallScrollBar.Cursor := crArrow;
    VSmallScrollBar.SmallChange := 0;
    VSmallScrollBar.Orientation := TOrientation.Vertical;
    VSmallScrollBar.Size.Width := 8;
    VSmallScrollBar.Size.PlatformDefault := False;
    VSmallScrollBar.Visible := False;

    HSmallScrollBar := TSmallScrollBar.Create(SmallScrolls);
    HSmallScrollBar.Parent := SmallScrolls;
    HSmallScrollBar.StyleName := 'hsmallscrollbar';
    HSmallScrollBar.Align := TAlignLayout.Bottom;
    HSmallScrollBar.Cursor := crArrow;
    HSmallScrollBar.SmallChange := 0;
    HSmallScrollBar.Orientation := TOrientation.Horizontal;
    HSmallScrollBar.Size.Height := 8;
    HSmallScrollBar.Size.PlatformDefault := False;
    HSmallScrollBar.Visible := False;

    Foreground := TBrushObject.Create(Style);
    Foreground.Parent := Style;
    Foreground.StyleName := 'foreground';
    Foreground.Brush.Color := GetSystemColor(COLOR_WINDOWTEXT);

    Selection := TBrushObject.Create(Style);
    Selection.Parent := Style;
    Selection.StyleName := 'selection';
    Selection.Brush.Color := GetSystemColor(COLOR_HIGHLIGHT, $7F);

    Font := TFontObject.Create(Style);
    Font.Parent := Style;
    Font.StyleName := 'font';

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
    Size: TSize;
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
    Size := TSize.Create(0, 0);
    Check.Source := CreateImage(ButtonTheme, BP_RADIOBUTTON, States, Size, Check);
    CalcLink(Check.SourceLink, RBS_UNCHECKEDNORMAL, States, Size);
    CalcLink(Check.ActiveLink, RBS_CHECKEDNORMAL, States, Size);
    CalcLink(Check.HotLink, RBS_UNCHECKEDHOT, States, Size);
    CalcLink(Check.ActiveHotLink, RBS_CHECKEDHOT, States, Size);
    CalcLink(Check.FocusedLink, RBS_UNCHECKEDHOT, States, Size);
    CalcLink(Check.ActiveFocusedLink, RBS_CHECKEDHOT, States, Size);
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
    StyleText.HotColor := GetSystemColor(COLOR_BTNTEXT);
    StyleText.FocusedColor := StyleText.HotColor;
    StyleText.NormalColor := StyleText.HotColor;
    StyleText.PressedColor := StyleText.HotColor;

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

  function GenerateSpeedButtonStyle: TFmxObject;
  const
    ToolbarTheme = 'toolbar';
  var
    Style: TLayout;
    Glyph: TGlyph;
    StyleText: TButtonStyleTextObject;
    Button: TButtonStyleObject;
    States: TStates;
    Size: TSize;
    GlyphPosition: String;
  begin
    Style := TLayout.Create(Self);
    Style.StyleName := CSpeedButtonStyle;
    Style.Align := TAlignLayout.Contents;

    Button := TButtonStyleObject.Create(Style);
    Button.Parent := Style;
    Button.StyleName := 'background';
    Button.Align := TAlignLayout.Contents;
    States := [TS_NORMAL, TS_HOT, TS_PRESSED];
    Size := TSize.Create(13, 13);
    Button.Source := CreateImage(ToolbarTheme, TP_BUTTON, States, Size, Button);
    CalcLink(Button.NormalLink, TS_NORMAL, States, Size, {AAddCapInsets} True);
    CalcLink(Button.PressedLink, TS_PRESSED, States, Size, {AAddCapInsets} True);
    CalcLink(Button.HotLink, TS_HOT, States, Size, {AAddCapInsets} True);
    CalcLink(Button.FocusedLink, TS_HOT, States, Size, {AAddCapInsets} True);

    Glyph := TGlyph.Create(Style);
    Glyph.Parent := Style;
    Glyph.StyleName := 'glyphstyle';
    Glyph.Margins.Left := 2;
    Glyph.Margins.Top := 2;
    Glyph.Margins.Right := 2;
    Glyph.Margins.Bottom := 2;
    GlyphPosition := Parameters.Values[CGlyphPosition];
    if GlyphPosition.ToLower = 'top' then
      Glyph.Align := TAlignLayout.Top
    else
    if GlyphPosition.ToLower = 'right' then
      Glyph.Align := TAlignLayout.Right
    else
    if GlyphPosition.ToLower = 'bottom' then
      Glyph.Align := TAlignLayout.Bottom
    else
      Glyph.Align := TAlignLayout.Left;
    if Parameters.IndexOfName(CGlyphSize) >= 0 then
    begin
      Glyph.Size.Width := Parameters.Values[CGlyphSize].ToSingle;
      Glyph.Size.Height := Glyph.Size.Width;
    end
    else
    begin
      Glyph.Size.Width := 16;
      Glyph.Size.Height := 16;
    end;
    Glyph.Size.PlatformDefault := False;

    StyleText := TButtonStyleTextObject.Create(Style);
    StyleText.Parent := Style;
    StyleText.StyleName := 'text';
    StyleText.Align := TAlignLayout.Client;
    StyleText.Margins.Left := 2;
    StyleText.Margins.Top := 2;
    StyleText.Margins.Right := 2;
    StyleText.Margins.Bottom := 2;
    StyleText.Size.PlatformDefault := False;
    StyleText.ShadowVisible := False;
    StyleText.HotColor := GetSystemColor(COLOR_BTNTEXT);
    StyleText.FocusedColor := StyleText.HotColor;
    StyleText.NormalColor := StyleText.HotColor;
    StyleText.PressedColor := StyleText.HotColor;

    Result := Style;
  end;

begin
  Parameters := nil;
  try
    ExtractGetParams(AStyleLookup, Parameters);

    if AStyleLookup.StartsWith(CButtonStyle) then
      Result := GenerateButtonStyle
    else
    if AStyleLookup.StartsWith(CCheckBoxStyle) then
      Result := GenerateCheckBoxStyle
    else
    if AStyleLookup.StartsWith(CEditStyle) then
      Result := GenerateEditStyle
    else
    if AStyleLookup.StartsWith(CGroupBoxStyle) then
      Result := GenerateGroupBoxStyle
    else
    if AStyleLookup.StartsWith(CLabelStyle) then
      Result := GenerateLabelStyle
    else
    if AStyleLookup.StartsWith(CMemoStyle) then
      Result := GenerateMemoStyle
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
    if AStyleLookup.StartsWith(CSpeedButtonStyle) then
      Result := GenerateSpeedButtonStyle
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

{ TButtonStyleHelper }

function TButtonStyleHelper.GetGlyphSize: Single;
begin
  Result := StyleGenerator.ReadParamDef(StyleLookup, CButtonStyle, CGlyphSize, '16').ToSingle;
end;

function TButtonStyleHelper.GetImageAlignment: TImageAlignment;
var
  GlyphPosition: String;
begin
  GlyphPosition := StyleGenerator.ReadParamDef(StyleLookup, CButtonStyle, CGlyphPosition, 'Left');
  if GlyphPosition.ToLower = 'top' then
    Result := iaTop
  else
  if GlyphPosition.ToLower = 'right' then
    Result := iaRight
  else
  if GlyphPosition.ToLower = 'bottom' then
    Result := iaBottom
  else
    Result := iaLeft;
end;

function TButtonStyleHelper.GetLayout: TButtonLayout;
var
  GlyphPosition: String;
begin
  GlyphPosition := StyleGenerator.ReadParamDef(StyleLookup, CButtonStyle, CGlyphPosition, 'Left');
  if GlyphPosition.ToLower = 'top' then
    Result := blGlyphTop
  else
  if GlyphPosition.ToLower = 'right' then
    Result := blGlyphRight
  else
  if GlyphPosition.ToLower = 'bottom' then
    Result := blGlyphBottom
  else
    Result := blGlyphLeft;
end;

procedure TButtonStyleHelper.SetGlyphSize(const Value: Single);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphSize, Value.ToString);
end;

procedure TButtonStyleHelper.SetImageAlignment(const Value: TImageAlignment);
begin
  case Value of
    iaLeft: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, '');
    iaRight: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, 'Right');
    iaTop: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, 'Top');
    iaBottom: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, 'Bottom');
  end;
end;

procedure TButtonStyleHelper.SetLayout(const Value: TButtonLayout);
begin
  case Value of
    blGlyphLeft: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, '');
    blGlyphRight: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, 'Rigth');
    blGlyphTop: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, 'Top');
    blGlyphBottom: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CButtonStyle, CGlyphPosition, 'Bottom');
  end;
end;

{ TSpeedButtonStyleHelper }

function TSpeedButtonStyleHelper.GetGlyphSize: Single;
begin
  Result := StyleGenerator.ReadParamDef(StyleLookup, CSpeedButtonStyle, CGlyphSize, '16').ToSingle;
end;

function TSpeedButtonStyleHelper.GetLayout: TButtonLayout;
var
  GlyphPosition: String;
begin
  GlyphPosition := StyleGenerator.ReadParamDef(StyleLookup, CSpeedButtonStyle, CGlyphPosition, 'Left');
  if GlyphPosition.ToLower = 'top' then
    Result := blGlyphTop
  else
  if GlyphPosition.ToLower = 'right' then
    Result := blGlyphRight
  else
  if GlyphPosition.ToLower = 'bottom' then
    Result := blGlyphBottom
  else
    Result := blGlyphLeft;
end;

procedure TSpeedButtonStyleHelper.SetGlyphSize(const Value: Single);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CSpeedButtonStyle, CGlyphSize, Value.ToString);
end;

procedure TSpeedButtonStyleHelper.SetLayout(const Value: TButtonLayout);
begin
  case Value of
    blGlyphLeft: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CSpeedButtonStyle, CGlyphPosition, '');
    blGlyphRight: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CSpeedButtonStyle, CGlyphPosition, 'Rigth');
    blGlyphTop: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CSpeedButtonStyle, CGlyphPosition, 'Top');
    blGlyphBottom: StyleLookup := StyleGenerator.WriteParam(StyleLookup, CSpeedButtonStyle, CGlyphPosition, 'Bottom');
  end;
end;

{ TEditStyleHelper }

function TEditStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CEditStyle, CBackgroundColor, 'claNull'));
end;

procedure TEditStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CEditStyle, CBackgroundColor, AlphaColorToString(Value));
end;

{ TMemoStyleHelper }

function TMemoStyleHelper.GetColor: TAlphaColor;
begin
  Result := StringToAlphaColor(StyleGenerator.ReadParamDef(StyleLookup, CMemoStyle, CBackgroundColor, 'claNull'));
end;

procedure TMemoStyleHelper.SetColor(const Value: TAlphaColor);
begin
  StyleLookup := StyleGenerator.WriteParam(StyleLookup, CMemoStyle, CBackgroundColor, AlphaColorToString(Value));
end;

initialization
  StyleGenerator := TStyleGenerator.Create(nil);

finalization
  StyleGenerator.Free;

end.
