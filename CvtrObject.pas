unit CvtrObject;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.IniFiles, Vcl.Imaging.PngImage, CvtrProp;

type
  IDfmToFmxRoot = interface
    procedure AddGridColumns(AObjName: String; AProp: TFmxProperty);
    procedure AddGridLink(AObjName: String; AProp: TDfmProperty);
    procedure AddFieldLink(AObjName: String; AProp: TDfmProperty);
    function AddImageItem(APng: TPngImage): Integer;
    function GetIniFile: TMemIniFile;
    property IniFile: TMemIniFile read GetIniFile;
  end;

  TRule = record
    NewName: String;
    LineFound: Boolean;
    Action: String;
    Parameter: String;
  end;

  TCodeReplacement = record
    NewCode: String;
    IsEvent: Boolean;
  end;

  TCodeReplacements = class(TDictionary<String, TCodeReplacement>)
  public
    procedure AddProperty(const AOldCode, ANewCode: String);
    procedure AddEvent(const AEvent, AParams: String);
  end;

  TDfmToFmxObject = class;
  TOwnedObjects = class(TObjectList<TDfmToFmxObject>);

  TEnumList = class(TObjectDictionary<String, TStringList>)
  private
    FIniFile: TMemIniFile;
  public
    constructor Create(AIniFile: TMemIniFile);
    function GetEnum(const AName: String; var AItems: TStringList): Boolean;
  end;

  TDfmToFmxObject = class
  private
    FFMXFileText: String;
  protected
    FRoot: IDfmToFmxRoot;
    FParent: TDfmToFmxObject;
    FClassName: String;
    FOldClassName: String;
    FObjName: String;
    FDfmProps: TDfmProperties;
    FFmxProps: TFmxProperties;
    FOwnedObjs: TOwnedObjects;
    FGenerated: Boolean;
    FEnumList: TEnumList;
    FIniAddProperties: TStringlist;
    FIniDefaultValueProperties: TStringlist;
    FIniIncludeValues: TStringlist;
    FIniSectionValues: TStringlist;
    FCodeReplacements: TCodeReplacements;
    procedure InitObjects; virtual;
    function FMXProperties(APad: String): String;
    function FMXSubObjects(APad: String): String;
    function ReadContents(AStm: TStreamReader): String;
    function GetRule(const AName: string; AList: TStringList = nil): TRule;
    function TransformProperty(AProp: TDfmProperty): TFmxProperty;
    procedure LoadCommonProperties(AParamName: String);
    procedure GenerateObject(AProp: TDfmProperty; AObjectType: string);
    procedure GenerateStyle(const APropName, APropValue, AObjectType: String);
    procedure InternalProcessBody(var ABody: String);
    procedure UpdateUsesStringList(AUsesList: TStrings); virtual;
    function GetObjHeader: string; virtual;
  public
    property Root: IDfmToFmxRoot read FRoot;
    property Parent: TDfmToFmxObject read FParent;
    property ObjName: String read FObjName;
    property DfmProps: TDfmProperties read FDfmProps;
    constructor Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader);
    constructor CreateGenerated(AParent: TDfmToFmxObject; AObjName, AClassName: String);
    destructor Destroy; override;
    procedure IniFileLoad; virtual;
    function FMXFile(APad: String = ''): String; virtual;
  end;

  TDfmToFmxItem = class(TDfmToFmxObject)
  protected
    function GetObjHeader: String; override;
  public
    constructor CreateItem(AParent: TDfmToFmxObject; AClassName: String; AStm: TStreamReader; out ListEndFound: Boolean);
  end;

  TDfmToFmxItems = class(TObjectList<TDfmToFmxItem>);

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

implementation

uses
  System.Generics.Defaults, Image, PatchLib, ReflexiveMasks, VCL2FMXStyleGen;

{ TDfmToFmxObject }

constructor TDfmToFmxObject.Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader);
var
  InputArray: TArray<String>;
begin
  FParent := AParent;
  if Assigned(AParent) then
    FRoot := FParent.Root;
  InitObjects;
  if Pos('object', Trim(ACreateText)) = 1 then
  begin
    InputArray := ACreateText.Split([' ']);
    if Length(InputArray) > 2 then
    begin
      FObjName := InputArray[1].TrimRight([':']);
      FClassName := InputArray[2];
    end
    else
    begin
      FObjName := '';
      FClassName := InputArray[1];
    end;
    IniFileLoad;
    ReadContents(AStm);
  end
  else
    raise Exception.Create('Bad Start::' + ACreateText);
end;

constructor TDfmToFmxObject.CreateGenerated(AParent: TDfmToFmxObject; AObjName, AClassName: String);
begin
  FParent := AParent;
  FRoot := FParent.FRoot;
  FObjName := AObjName;
  FClassName := AClassName;
  FGenerated := True;
  InitObjects;
  IniFileLoad;
end;

destructor TDfmToFmxObject.Destroy;
begin
  FFmxProps.Free;
  FDfmProps.Free;
  FOwnedObjs.Free;
  FCodeReplacements.Free;
  FIniIncludeValues.Free;
  FIniSectionValues.Free;
  FEnumList.Free;
  FIniAddProperties.Free;
  FIniDefaultValueProperties.Free;
  inherited;
end;

function TDfmToFmxObject.FMXFile(APad: String): String;
var
  Properties: String;
begin
  if FFMXFileText <> '' then
    Exit(FFMXFileText);

  Properties := FMXProperties(APad); // This can change FClassName, see FMXProperties.CalcShapeClass
  FFMXFileText := APad + GetObjHeader;
  FFMXFileText := FFMXFileText + Properties + FMXSubObjects(APad + ' ');
  FFMXFileText := FFMXFileText + APad +'end' + CRLF;
  Result := FFMXFileText;
end;

function TDfmToFmxObject.FMXProperties(APad: String): String;
var
  i, j: Integer;
  Rule: TRule;
  Mask: TReflexiveMask;
  DfmProp: TDfmProperty;
  ExistingProp: TFmxProperty;

  procedure HandleStyledSettings(AExcludeElement: String);
  var
    Prop: TFmxProperty;
    Item: Integer;
  begin
    Prop := FFmxProps.FindByName('StyledSettings');

    if not Assigned(Prop) then
    begin
      Prop := TFmxSetProp.Create('StyledSettings');
      TFmxSetProp(Prop).Items.AddStrings(['Family', 'Size', 'Style', 'FontColor', 'Other']);
      FFmxProps.AddProp(Prop);
    end;

    Item := (Prop as TFmxSetProp).Items.IndexOf(AExcludeElement);
    if Item >= 0 then
      (Prop as TFmxSetProp).Items.Delete(Item);
  end;

  procedure CalcImageWrapMode;
  var
    Center, Proportional, Stretch: Boolean;
    PropLine: TDfmProperty;
    FmxProp: TFmxProperty;
    Value: String;
  begin
    FmxProp := FFmxProps.FindByName('WrapMode');
    if Assigned(FmxProp) then
      Exit;

    Center := False;
    Proportional := False;
    Stretch := False;
    for PropLine in FDfmProps do
    begin
      if PropLine.Name = 'Center' then
        Center := True;
      if PropLine.Name = 'Proportional' then
        Proportional := True;
      if PropLine.Name = 'Stretch' then
        Stretch := True;
    end;

    if Proportional and Stretch then
      Value := 'Fit'
    else
    if Stretch then
      Value := 'Stretch'
    else
    if Center then
      Value := 'Center'
    else
      Value := 'Original';

    FFmxProps.AddProp(TFmxProperty.Create('WrapMode', Value));
  end;

  procedure CalcShapeClass;
  var
    Shape: String;
    Prop: TDfmProperty;
  begin
    Prop := FDfmProps.FindByName('Shape');
    if Assigned(Prop) then
      Shape := Prop.Value;

    FOldClassName := FClassName;
    if (Shape = '') or (Shape = 'stRectangle') or (Shape = 'stSquare') then
      FClassName := 'TRectangle';
    if Shape = 'stCircle' then
      FClassName := 'TCircle';
    if Shape = 'stEllipse' then
      FClassName := 'TEllipse';
    if (Shape = 'stRoundRect') or (Shape = 'stRoundSquare') then
      FClassName := 'TRoundRect';
  end;

  procedure CopyFromParent(ACopyProp: String);
  var
    Prop: TDfmProperty;
    Mask: TReflexiveMask;
    Found: Boolean;
    Parent: TDfmToFmxObject;
  begin
    Mask := TReflexiveMask.Create(ACopyProp);
    try
      Found := False;
      Parent := FParent;
      repeat
        for Prop in Parent.DfmProps do
          if Mask.Matches(Prop.Name) then
          begin
            FFmxProps.AddProp(TransformProperty(Prop));
            Found := True;
          end;
        Parent := Parent.Parent;
      until Found or not Assigned(Parent);
    finally
      Mask.Free;
    end;
  end;

  procedure ReconsiderAfterRemovingRule(ARemoveRule: String);
  var
    Line: TDfmProperty;
    Mask: TReflexiveMask;
    i: Integer;
  begin
    Mask := TReflexiveMask.Create(ARemoveRule);
    try
      for i := Pred(FIniSectionValues.Count) downto 0 do
        if Mask.Matches(FIniSectionValues.Names[i]) then
          FIniSectionValues.Delete(i);

      LoadCommonProperties(ARemoveRule);

      for Line in FDfmProps do
        if Mask.Matches(Line.Name) then
          FFmxProps.AddProp(TransformProperty(Line));
    finally
      Mask.Free;
    end;
  end;

begin
  Result := EmptyStr;

  for i := 0 to FDfmProps.Count - 1 do
    FFmxProps.AddProp(TransformProperty(FDfmProps[i]));

  for i := 0 to Pred(FIniDefaultValueProperties.Count) do
  begin
    DfmProp := FDfmProps.FindByName(FIniDefaultValueProperties.Names[i]);
    if (not Assigned(DfmProp)) and (TReflexiveMask.ContainsWildcards(FIniDefaultValueProperties.Names[i])) then
    begin
      Mask := TReflexiveMask.Create(FIniDefaultValueProperties.Names[i]);
      try
        for j := 0 to FDfmProps.Count - 1 do
          if Mask.Matches(FDfmProps[j].Name) then
          begin
            DfmProp := FDfmProps[j];
            Break;
          end;
      finally
        Mask.Free;
      end;
    end;
    if Assigned(DfmProp) then
      Continue;
        
    Rule := GetRule(FIniDefaultValueProperties.Names[i], FIniDefaultValueProperties);
    if Rule.Action = '#CopyFromParent#' then
    begin
      CopyFromParent(Rule.Parameter);
      Continue;
    end;
    if Rule.Action = '#CalcImageWrapMode#' then
    begin
      CalcImageWrapMode;
      Continue;
    end;
    if Rule.Action = '#CalcShapeClass#' then
    begin
      CalcShapeClass;
      Continue;
    end;
    if Rule.Action = '#GenerateStyle#' then
    begin
      GenerateStyle(Rule.NewName, '', Rule.Parameter);
      Continue;
    end;
    if Rule.Action = '#ReconsiderAfterRemovingRule#' then
    begin
      ReconsiderAfterRemovingRule(Rule.Parameter);
      Continue;
    end;
    FFmxProps.AddProp(TFmxProperty.CreateFromLine(Rule.Parameter));
  end;

  for i := 0 to Pred(FIniAddProperties.Count) do
  begin
    ExistingProp := FFmxProps.FindByName(FIniAddProperties.Names[i]);
    if Assigned(ExistingProp) then
    begin
      Rule := GetRule(FIniAddProperties.Names[i], FIniAddProperties);
      if Rule.Action = '#RemoveFromStyledSettings#' then
      begin
        HandleStyledSettings(Rule.Parameter);
        Continue;
      end;
      ExistingProp := FFmxProps.FindByName(Rule.Parameter.Split(['='], 1)[0].Trim);
      if not Assigned(ExistingProp) then
      begin
        if Rule.Action = '#PutToTheTop#' then
          FFmxProps.Insert(0, TFmxProperty.CreateFromLine(Rule.Parameter))
        else
          FFmxProps.AddProp(TFmxProperty.CreateFromLine(Rule.Parameter));
      end;
    end;
  end;

  for i := 0 to FFmxProps.Count - 1 do
    Result := Result + FFmxProps[i].ToString(APad);
end;

function TDfmToFmxObject.FMXSubObjects(APad: String): String;
var
  i: integer;
begin
  for i := 0 to Pred(FOwnedObjs.Count) do
    Result := Result + FOwnedObjs[i].FMXFile(APad +' ');
end;

procedure TDfmToFmxObject.GenerateObject(AProp: TDfmProperty; AObjectType: string);

  procedure AddFmxProperty(AObj: TDfmToFmxObject; const APropName, APropValue: String);
  var
    Prop: TFmxProperty;
  begin
    Prop := AObj.FFmxProps.FindByName(APropName);

    if Assigned(Prop) then
      Prop.Value := APropValue
    else
    begin
      Prop := TFmxProperty.Create(APropName, APropValue);
      AObj.FFmxProps.Add(Prop);
    end;
  end;

  procedure GenerateProperty(AObj: TDfmToFmxObject; const APropName, APropValue: String);
  var
    Prop: TDfmProperty;
  begin
    Prop := AObj.FDfmProps.FindByName(APropName);

    if Assigned(Prop) then
      Prop.Value := APropValue
    else
    begin
      Prop := TDfmProperty.Create(APropName, APropValue);
      AObj.FDfmProps.Add(Prop);
    end;
  end;

type
  TProp = record
    Name, Value: String;
  end;

  function GetObject(const AObjName, ADFMClass: String; const AInitProps, AReplacements: array of TProp;
    APosition: Integer = 0): TDfmToFmxObject;
  var
    Obj: TDfmToFmxObject;
    Prop: TProp;
  begin
    for Obj in FOwnedObjs do
    begin
      if not Obj.FGenerated then
        Break;
      if (Obj.FClassName = ADFMClass) and (Obj.FObjName = AObjName) then
        Exit(Obj);
    end;

    Result := TDfmToFmxObject.CreateGenerated(Self, AObjName, ADFMClass);
    FOwnedObjs.Insert(APosition, Result);
    for Prop in AInitProps do
      AddFmxProperty(Result, Prop.Name, Prop.Value);
    for Prop in AReplacements do
      FCodeReplacements.AddProperty(Prop.Name, Prop.Value);
  end;

  procedure ConvertGlyph;
  var
    NumGlyphs, Index: Integer;
  begin
    NumGlyphs := FDfmProps.GetIntValueDef('NumGlyphs', 1);
    Index := FRoot.AddImageItem(CreateGlyphPng(AProp.Value, NumGlyphs));

    AddFmxProperty(Self, 'Images', 'SingletoneImageList');
    AddFmxProperty(Self, 'ImageIndex', Index.ToString);
  end;

  procedure InitChildImage(AObj: TDfmToFmxObject);
  var
    Png: TPngImage;
    NumGlyphs, Width, Height: Integer;
  begin
    NumGlyphs := FDfmProps.GetIntValueDef('NumGlyphs', 1);
    Width := FDfmProps.GetIntValueDef('Width', 23);
    Height := FDfmProps.GetIntValueDef('Height', 22);

    Png := CreateGlyphPng(AProp.Value, NumGlyphs);

    Width := (Width - Png.Width) div 2;
    Height := (Height - Png.Height) div 2;
    AddFmxProperty(AObj, 'Margins.Left', Width.ToString);
    AddFmxProperty(AObj, 'Margins.Right', Width.ToString);
    AddFmxProperty(AObj, 'Margins.Top', Height.ToString);
    AddFmxProperty(AObj, 'Margins.Bottom', Height.ToString);

    AObj.FFmxProps.AddProp(TFmxImageProp.Create('Picture.Data', Png));
  end;

const
  ChildImageInitParams: array [0..2] of TProp = ((Name: 'Align'; Value: 'Client'), (Name: 'HitTest'; Value: 'False'),
    (Name: 'WrapMode'; Value: 'Fit'));
  ChildImageReplacements: array [0..0] of TProp = ((Name: 'Picture'; Value: '_Glyph.Bitmap'));
  ColoredRectInitParams: array [0..5] of TProp = ((Name: 'Align'; Value: 'Client'), (Name: 'Margins.Left'; Value: '1'),
    (Name: 'Margins.Top'; Value: '1'), (Name: 'Margins.Right'; Value: '1'), (Name: 'Margins.Bottom'; Value: '1'),
    (Name: 'Stroke.Kind'; Value: 'None'));
  ColoredRectReplacements: array [0..0] of TProp = ((Name: 'Color'; Value: '_Color.Fill.Color'));
  RadioButtonInitParams: array [0..2] of TProp = ((Name: 'Size.Height'; Value: '19'), (Name: 'Position.X'; Value: '8'),
    (Name: 'Size.Width'; Value: '50'));
  SeparateCaptionInitParams: array [0..1] of TProp = ((Name: 'Align'; Value: 'Client'),
    (Name: 'TabStop'; Value: 'False'));
  SeparateCaptionReplacements: array [0..7] of TProp = ((Name: 'ShowCaption'; Value: '_Caption.Visible'),
    (Name: 'VerticalAlignment'; Value: '_Caption.TextSettings.VertAlign'),
    (Name: 'Alignment'; Value: '_Caption.TextSettings.HorzAlign'), (Name: 'Caption'; Value: '_Caption.Text'),
    (Name: 'Font.Color'; Value: '_Caption.TextSettings.FontColor'),
    (Name: 'Font.Height'; Value: '_Caption.TextSettings.Font.Size'),
    (Name: 'Font.Name'; Value: '_Caption.TextSettings.Font.Family'),
    (Name: 'Font.Style'; Value: '_Caption.TextSettings.Font.Style'));
var
  Obj: TDfmToFmxObject;
  Num, i: Integer;
  Caption: String;
begin
  if AObjectType = 'ChildImage' then
  begin
    Obj := GetObject(FObjName + '_Glyph', 'TImage', ChildImageInitParams, ChildImageReplacements);
    InitChildImage(Obj);
  end;

  if AObjectType = 'ColoredRect' then
  begin
    Obj := GetObject(FObjName + '_Color', 'TShape', ColoredRectInitParams, ColoredRectReplacements);

    if AProp.Name = 'Color' then
      GenerateProperty(Obj, 'Brush.Color', AProp.Value)
    else
      GenerateProperty(Obj, AProp.Name, AProp.Value);
  end;

  if AObjectType = 'FieldLink' then
    FRoot.AddFieldLink(FObjName, AProp);

  if AObjectType = 'ImageItem' then
    ConvertGlyph;

  if AObjectType = 'GridLink' then
    FRoot.AddGridLink(FObjName, AProp);

  if AObjectType = 'MultipleRadioButtons' then
  begin
    Num := 0;

    for Caption in (AProp as TDfmStringsProp).Strings do
    begin
      Obj := GetObject(FObjName + '_RadioButton' + (Num + 1).ToString, 'TRadioButton', RadioButtonInitParams, [], Num);
      AddFmxProperty(Obj, 'Text', Caption);
      AddFmxProperty(Obj, 'TabOrder', Num.ToString);
      AddFmxProperty(Obj, 'Position.Y', (16 + Num * 20).ToString);
      Inc(Num);
    end;
  end;

  if AObjectType = 'MultipleTabs' then
  begin
    Num := 1;

    for Caption in (AProp as TDfmStringsProp).Strings do
    begin
      Obj := GetObject(FObjName + 'Tab' + Num.ToString, 'TTabSheet', [], [], Num - 1);
      AddFmxProperty(Obj, 'Text', Caption);
      Inc(Num);
    end;
  end;

  if AObjectType = 'SelectRadioButton' then
  begin
    Num := AProp.Value.ToInteger;
    Obj := nil;
    for i := 0 to Num do
      Obj := GetObject(FObjName + '_RadioButton' + (i + 1).ToString, 'TRadioButton', RadioButtonInitParams, [], i);
    AddFmxProperty(Obj, 'IsChecked', 'True');
  end;

  if AObjectType = 'SeparateCaption' then
  begin
    Obj := GetObject(FObjName + '_Caption', 'TLabel', SeparateCaptionInitParams, SeparateCaptionReplacements);
    if Obj.FDfmProps.Count = 0 then
    begin
      GenerateProperty(Obj, 'Alignment', 'taCenter');
      GenerateProperty(Obj, 'Layout', 'tlCenter');
    end;

    if AProp.Name = 'ShowCaption' then
      AddFmxProperty(Obj, 'Visible', AProp.Value)
    else
    if AProp.Name = 'VerticalAlignment' then
    begin
      if AProp.Value = 'taAlignBottom' then
        GenerateProperty(Obj, 'Layout', 'tlBottom'); //Center is default for panel and top - for label
    end
    else
      GenerateProperty(Obj, AProp.Name, AProp.Value);
  end;
end;

procedure TDfmToFmxObject.GenerateStyle(const APropName, APropValue, AObjectType: String);

  procedure SetStyle(const AType, AParam, AValue: String);
  var
    Prop: TFmxProperty;
  begin
    Prop := FFmxProps.FindByName('StyleLookup');

    if not Assigned(Prop) then
    begin
      Prop := TFmxProperty.Create('StyleLookup', '');
      FFmxProps.AddProp(Prop);
    end;

    Prop.Value := StyleGenerator.WriteParam(Prop.Value.DeQuotedString, AType, AParam, AValue).QuotedString;
  end;

  function IsParamSet(const AType, AParam: String): Boolean;
  var
    Prop: TFmxProperty;
  begin
    Result := False;
    Prop := FFmxProps.FindByName('StyleLookup');
    if Assigned(Prop) and (StyleGenerator.ReadParam(Prop.Value.DeQuotedString, AType, AParam) <> '') then
      Result := True;
  end;

begin
  FIniIncludeValues.Add('VCL2FMXStyleGen');

  if (AObjectType = 'CheckBox') and (APropName = 'Color') then
    SetStyle(CCheckBoxStyle, CBackgroundColor, ColorToAlphaColor(APropValue))
  else
  if (AObjectType = 'Label') and (APropName = 'Color') then
    SetStyle(CLabelStyle, CBackgroundColor, ColorToAlphaColor(APropValue))
  else
  if AObjectType = 'GroupBox' then
  begin
    if APropName = 'Color' then
      SetStyle(CGroupBoxStyle, CBackgroundColor, ColorToAlphaColor(APropValue));
    if APropName = 'ShowFrame' then
      SetStyle(CGroupBoxStyle, CShowFrame, APropValue);
    if APropName = 'ParentBackground' then
    begin
      if StrToBoolDef(APropValue, True) then
        SetStyle(CGroupBoxStyle, CBackgroundColor, 'claNull')
      else
        if not IsParamSet(CGroupBoxStyle, CBackgroundColor) then
          SetStyle(CGroupBoxStyle, CBackgroundColor, CColorBtnFace);
    end;
  end
  else
  if AObjectType = 'Panel' then
  begin
    if APropName = 'Color' then
      SetStyle(CPanelStyle, CBackgroundColor, ColorToAlphaColor(APropValue));
    if APropName = 'ParentBackground' then
    begin
      if StrToBoolDef(APropValue, True) then
        SetStyle(CPanelStyle, CBackgroundColor, 'claNull')
      else
        if not IsParamSet(CPanelStyle, CBackgroundColor) then
          SetStyle(CPanelStyle, CBackgroundColor, CColorBtnFace);
    end;
  end
  else
  if (AObjectType = 'RadioButton') and (APropName = 'Color') then
    SetStyle(CRadioButtonStyle, CBackgroundColor, ColorToAlphaColor(APropValue))
  else
  if AObjectType = 'ScrollBox' then
  begin
    if APropName = 'Color' then
      SetStyle(CScrollBoxStyle, CBackgroundColor, ColorToAlphaColor(APropValue));
    if APropName = 'ParentBackground' then
    begin
      if StrToBoolDef(APropValue, False) then
        SetStyle(CScrollBoxStyle, CBackgroundColor, 'claNull')
      else
        if not IsParamSet(CScrollBoxStyle, CBackgroundColor) then
          SetStyle(CScrollBoxStyle, CBackgroundColor, CColorBtnFace);
    end;
  end;
end;

function TDfmToFmxObject.GetObjHeader: string;
begin
  if FObjName <> '' then
    Result := 'object ' + FObjName + ': ' + FClassName + CRLF
  else
    Result := 'object ' + FClassName + CRLF;
end;

function TDfmToFmxObject.GetRule(const AName: string; AList: TStringList = nil): TRule;
var
  RuleLine: String;
  Mask: TReflexiveMask;
  ActionNameStart, ActionNameEnd: Integer;
begin
  Mask := nil;
  try
    if not Assigned(AList) then
    begin
      RuleLine := FIniSectionValues.Values[AName].Trim;
      if RuleLine = '' then
        for var i := 0 to FIniSectionValues.Count - 1 do
        begin
          if not TReflexiveMask.ContainsWildcards(FIniSectionValues.Names[i]) then
            Continue;
            
          Mask.Free;
          Mask := TReflexiveMask.Create(FIniSectionValues.Names[i]);
          if Mask.Matches(AName) then
          begin
            RuleLine := FIniSectionValues.ValueFromIndex[i];
            Break;
          end;
        end;
    end
    else
      RuleLine := AList.Values[AName].Trim;

    if RuleLine = '' then
    begin
      Result.NewName := AName;
      Result.LineFound := False;
    end
    else
    begin
      Result.LineFound := True;
      ActionNameStart := RuleLine.IndexOf('#');

      case ActionNameStart of
        -1: Result.NewName := RuleLine;
        0: Result.NewName := AName;
      else
        Result.NewName := RuleLine.Substring(0, ActionNameStart).Trim;
      end;

      if Assigned(Mask) and Mask.ContainsWildcards(Result.NewName) then
        Result.NewName := Mask.RestoreText(Result.NewName);

      if ActionNameStart > -1 then
      begin
        ActionNameEnd := RuleLine.IndexOf('#', ActionNameStart + 1);
        if ActionNameEnd > -1 then
        begin
          Result.Action := RuleLine.Substring(ActionNameStart, ActionNameEnd - ActionNameStart + 1);
          Result.Parameter := RuleLine.Substring(ActionNameEnd + 1);
        end
        else
          Result.Parameter := RuleLine.Substring(ActionNameStart + 1);
      end
      else
        Result.Parameter := RuleLine;
    end;
  finally
    Mask.Free;
  end;
end;

procedure TDfmToFmxObject.IniFileLoad;
var
  NewClassName: String;
begin
  if FClassName <> '' then
  begin
    NewClassName := FRoot.IniFile.ReadString('ObjectChanges', FClassName, EmptyStr);
    if NewClassName <> EmptyStr then
    begin
      FOldClassName := FClassName;
      FClassName := NewClassName;
    end;
    FRoot.IniFile.ReadSectionValues(FClassName, FIniSectionValues);
    FRoot.IniFile.ReadSection(FClassName + '#Include', FIniIncludeValues);
    FRoot.IniFile.ReadSectionValues(FClassName + '#AddIfPresent', FIniAddProperties);
    FRoot.IniFile.ReadSectionValues(FClassName + '#DefaultValueProperty', FIniDefaultValueProperties);
  end;

  LoadCommonProperties('*');
end;

procedure TDfmToFmxObject.InitObjects;
begin
  FDfmProps := TDfmProperties.Create({AOwnsObjects} True);
  FFmxProps := TFmxProperties.Create({AOwnsObjects} True);
  FEnumList := TEnumList.Create(FRoot.IniFile);
  FIniAddProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniDefaultValueProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniIncludeValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniSectionValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FCodeReplacements := TCodeReplacements.Create;
  FOwnedObjs := TOwnedObjects.Create({AOwnsObjects} True);
end;

procedure TDfmToFmxObject.InternalProcessBody(var ABody: String);
type
  TReplacementPair = TPair<String, TCodeReplacement>;
var
  i, NameStart, ClassStart, LineEnd: Integer;
  Replacement: TReplacementPair;
  RuleName: String;
  Rule: TRule;

  procedure ReplaceEventParams(AReplacement: TReplacementPair);
  var
    Name, Opening, Closing: Integer;
  begin
    Name := PosNoCase(AReplacement.Key, ABody);
    while Name > 0 do
    begin
      Opening := Pos('(', ABody, Name + AReplacement.Key.Length);
      Closing := Pos(')', ABody, Opening + 1);
      ABody := ABody.Substring(0, Opening) + AReplacement.Value.NewCode + ABody.Substring(Closing - 1);

      Name := PosNoCase(AReplacement.Key, ABody, Closing + 1);
    end;
  end;

begin
  if FGenerated then
  begin
    NameStart := PosNoCase(FParent.ObjName, ABody);
    if NameStart = 0 then
      raise Exception.Create('Can''t find parent control ' + FParent.ObjName + ' in form class');

    LineEnd := Pos(CRLF, ABody, NameStart);
    if LineEnd = 0 then
      LineEnd := Pos(CR, ABody, NameStart);
    if LineEnd = 0 then
      LineEnd := Pos(LF, ABody, NameStart);
    if LineEnd = 0 then
      LineEnd := NameStart;

    ABody.Insert(LineEnd - 1, CRLF + '    ' + FObjName + ': ' + FClassName + ';');
  end
  else
    if (FOldClassName <> '') and (FObjName <> '') then
    begin
      NameStart := PosNoCase(FObjName, ABody);
      ClassStart := PosNoCase(FOldClassName, ABody, NameStart);
      ABody := ABody.Substring(0, NameStart + FObjName.Length - 1) + ': ' + FClassName +
        ABody.Substring(ClassStart + FOldClassName.Length - 1);
    end;

  if (FObjName <> '') and not FGenerated then
  begin
    for i := 0 to FIniSectionValues.Count - 1 do
    begin
      RuleName := FIniSectionValues.Names[i];
      if not TReflexiveMask.ContainsWildcards(RuleName) then
      begin
        Rule := GetRule(RuleName, FIniSectionValues);
        if (RuleName <> Rule.NewName) and not FCodeReplacements.ContainsKey('.' + RuleName) then
          FCodeReplacements.AddProperty(RuleName, '.' + Rule.NewName)
      end;
    end;

    for Replacement in FCodeReplacements do
      if not Replacement.Value.IsEvent then
        ABody := StringReplaceSkipChars(ABody, FObjName + Replacement.Key, FObjName + Replacement.Value.NewCode,
          [CR, LF, ' '])
      else
        ReplaceEventParams(Replacement);
  end;

  for i := 0 to Pred(FOwnedObjs.Count) do
    FOwnedObjs[i].InternalProcessBody(ABody);
end;

procedure TDfmToFmxObject.LoadCommonProperties(AParamName: String);
var
  i, j: integer;
  Found: Boolean;
  CommonProps, Candidates: TStringList;
  ParamMask, CommonPropMask, ExistingPropMask: TReflexiveMask;
begin
  CommonProps := nil;
  Candidates := nil;
  ParamMask := nil;
  try
    CommonProps := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
    Candidates := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
    ParamMask := TReflexiveMask.Create(AParamName);

    FRoot.IniFile.ReadSectionValues('CommonProperties', CommonProps);
    for i := 0 to Pred(CommonProps.Count) do
      if ParamMask.Matches(CommonProps.Names[i]) and
        (FIniSectionValues.IndexOfName(CommonProps.Names[i]) = -1) then
      begin
        Found := False;
        if TReflexiveMask.ContainsWildcards(CommonProps.Names[i]) then
        begin
          CommonPropMask := TReflexiveMask.Create(CommonProps.Names[i]);
          try
            for j := 0 to Pred(FIniSectionValues.Count) do
              if CommonPropMask.Matches(FIniSectionValues.Names[j]) then
              begin
                Found := True;
                Break;
              end;
          finally
            CommonPropMask.Free;
          end;
        end;
        if not Found then
          Candidates.Add(CommonProps[i]);
      end;

    for i := 0 to Pred(FIniSectionValues.Count) do
      if TReflexiveMask.ContainsWildcards(FIniSectionValues.Names[i]) then
      begin
        ExistingPropMask := TReflexiveMask.Create(FIniSectionValues.Names[i]);
        try
          for j := Pred(Candidates.Count) downto 0 do
            if ExistingPropMask.Matches(Candidates.Names[j]) then
              Candidates.Delete(j);
        finally
          ExistingPropMask.Free;
        end;
      end;

    for i := 0 to Pred(Candidates.Count) do
      FIniSectionValues.Add(Candidates[i]);

    CommonProps.Clear;
    FRoot.IniFile.ReadSectionValues('CommonProperties#AddIfPresent', CommonProps);
    for i := 0 to Pred(CommonProps.Count) do
      if FIniAddProperties.IndexOfName(CommonProps.Names[i]) = -1 then
        FIniAddProperties.Add(CommonProps[i]);
  finally
    ParamMask.Free;
    CommonProps.Free;
    Candidates.Free;
  end;
end;

function TDfmToFmxObject.ReadContents(AStm: TStreamReader): String;
var
  PropEqSign: Integer;
  Name, Value: String;
  Prop: TDfmProperty;
  Data: String;

  function GetItemsClass: String;
  var
    Rule: TRule;
  begin
    Result := '';
    Rule := GetRule(Name);
    if (Rule.Action = '#ItemClass#') or (Rule.Action = '#Delete#') or (Rule.Action = '#GenerateLinkColumns#') then
      Result := Rule.Parameter;
  end;

begin
  Data := Trim(AStm.ReadLine);
  while not Data.StartsWith('end') do
  begin
    if Pos('object', Data) = 1 then
      FOwnedObjs.Add(TDfmToFmxObject.Create(Self, Data, AStm))
    else
    begin
      PropEqSign := Data.IndexOf('=');
      Name := Data.Substring(0, PropEqSign).Trim;
      Value := Data.Substring(PropEqSign + 1).Trim;

      if Value = '' then
      begin
        Prop := TDfmProperty.Create(Name, '');
        Prop.ReadMultiline(AStm);
      end
      else
      if Value[1] = '(' then
      begin
        Prop := TDfmStringsProp.Create(Name, Value);
        TDfmStringsProp(Prop).ReadLines(AStm);
      end
      else
      if Value[1] = '<' then
      begin
        Prop := TDfmItemsProp.Create(Name, Value);
        TDfmItemsProp(Prop).ReadItems(Self, GetItemsClass, AStm);
      end
      else
      if Value[1] = '{' then
      begin
        Prop := TDfmDataProp.Create(Name, Value);
        TDfmDataProp(Prop).ReadData(AStm);
      end
      else
      if Value[1] = '[' then
      begin
        Prop := TDfmSetProp.Create(Name, Value);
        TDfmSetProp(Prop).ReadSetItems(AStm);
      end
      else
        Prop := TDfmProperty.Create(Name, Value);
      FDfmProps.Add(Prop);
    end;
    Data := Trim(AStm.ReadLine);
  end;
  Result := Data.Substring(3);
end;

function TDfmToFmxObject.TransformProperty(AProp: TDfmProperty): TFmxProperty;
var
  Rule: TRule;
  EnumValue, Item: String;

  function ReplaceEnum(const APropValue: String): String;
  var
    EnumRule: TRule;
    EnumItems: TStringList;
  begin
    if not FEnumList.GetEnum(Rule.Parameter, EnumItems) then
      raise Exception.Create('Required enum ' + Rule.Parameter + ' not found');

    EnumRule := GetRule(APropValue, EnumItems);
    if (not EnumRule.LineFound) and (EnumItems.IndexOfName('#UnknownValuesAllowed#') < 0) then
      raise Exception.Create('Unknown item ' + APropValue + ' in enum ' + Rule.Parameter);

    if EnumRule.Action = '#IgnoreValue#' then
      Exit('');

    if EnumRule.Action = '#SetProperty#' then
    begin
      FFmxProps.AddMultipleProps(EnumRule.Parameter);
      Exit('');
    end;

    if EnumRule.Action <> '' then
      raise Exception.Create('Unknown action ' + EnumRule.Action + ' in item ' + APropValue + ' in enum ' + 
        Rule.Parameter);
      
    Result := EnumRule.NewName;
  end;

begin
  Result := nil;
  Rule := GetRule(AProp.Name);

  if Rule.Action = '#Color#' then
    Result := TFmxProperty.Create(Rule.NewName, ColorToAlphaColor(AProp.Value))
  else
  if Rule.Action = '#ConvertData#' then
  begin
    if Rule.Parameter = 'Image' then
      Result := TFmxImageProp.Create(Rule.NewName, AProp.Value)
    else
    if Rule.Parameter = 'ImageList' then
      Result := TFmxImageListProp.Create(Rule.NewName, AProp.Value)
    else
    if Rule.Parameter = 'Picture' then
      Result := TFmxPictureProp.Create(Rule.NewName, AProp.Value)
    else
      raise Exception.Create('Unknown data type ' + Rule.Parameter + ' for property ' + AProp.Name);
  end
  else
  if Rule.Action = '#Delete#' then
  begin
    Result := nil;
    if AProp is TDfmItemsProp then
      TDfmItemsProp(AProp).Transform(nil);
  end
  else
  if Rule.Action = '#EventParameters#' then
  begin
    Result := TFmxProperty.Create(Rule.NewName, AProp.Value);
    FCodeReplacements.AddEvent(AProp.Value, Rule.Parameter);
  end
  else
  if Rule.Action = '#FontSize#' then
    Result := TFmxProperty.Create(Rule.NewName, Abs(AProp.Value.ToInteger).ToString)
  else
  if Rule.Action = '#GenerateLinkColumns#' then
  begin
    if not (AProp is TDfmItemsProp) then
      raise Exception.Create('#GenerateLinkColumns# can be used only with object list properties');

    Result := TFmxItemsProp.Create(Rule.NewName);
    TDfmItemsProp(AProp).Transform(TFmxItemsProp(Result).Items);
    FRoot.AddGridColumns(FObjName, Result);
    Result := nil;
  end
  else
  if Rule.Action = '#GenerateControl#' then
  begin
    GenerateObject(AProp, Rule.Parameter);
    Result := nil;
  end
  else
  if Rule.Action = '#GenerateStyle#' then
  begin
    GenerateStyle(AProp.Name, AProp.Value, Rule.Parameter);
    Result := nil;
  end
  else
  if Rule.Action = '#ItemEnum#' then
  begin
    if AProp is TDfmSetProp then
    begin
      Result := TFmxSetProp.Create(Rule.NewName);
      for Item in TDfmSetProp(AProp).Items do
      begin
        EnumValue := ReplaceEnum(Item);
        if EnumValue <> '' then
          TFmxSetProp(Result).Items.Add(EnumValue);
      end
    end
    else
    begin
      EnumValue := ReplaceEnum(AProp.Value);
      if EnumValue <> '' then     
        Result := TFmxProperty.Create(Rule.NewName, EnumValue);
    end;
  end
  else
  if Rule.Action = '#SetValue#' then
  begin
    FFmxProps.AddMultipleProps(Rule.NewName + '=' + Rule.Parameter);
    Result := nil;
  end
  else
  if Rule.Action = '#ToString#' then
    Result := TFmxProperty.Create(Rule.NewName, AProp.Value.QuotedString)
  else
  if (Rule.Action = '') or (Rule.Action = '#ItemClass#') then
  begin
    if AProp is TDfmStringsProp then
      Result := TFmxStringsProp.Create(Rule.NewName, TDfmStringsProp(AProp).Strings)
    else
    if AProp is TDfmDataProp then
      Result := TFmxDataProp.Create(Rule.NewName, AProp.Value)
    else
    if AProp is TDfmItemsProp then
    begin
      Result := TFmxItemsProp.Create(Rule.NewName);
      TDfmItemsProp(AProp).Transform(TFmxItemsProp(Result).Items);
    end
    else
    if AProp is TDfmSetProp then
    begin
      Result := TFmxSetProp.Create(Rule.NewName);
      for Item in TDfmSetProp(AProp).Items do
        TFmxSetProp(Result).Items.Add(Item);
    end
    else
      Result := TFmxProperty.Create(Rule.NewName, AProp.Value);
  end
  else
    raise Exception.Create('Unknown action ' + Rule.Action + ' for property ' + AProp.Name);

  if Assigned(Result) and (Result.Name <> AProp.Name) then
    FCodeReplacements.AddProperty(AProp.Name, '.' + Result.Name);
end;

procedure TDfmToFmxObject.UpdateUsesStringList(AUsesList: TStrings);
var
  i: integer;
  Idx: integer;
begin
  if FIniIncludeValues <> nil then
  begin
    for i := 0 to Pred(FIniIncludeValues.Count) do
    begin
      Idx := AUsesList.IndexOf(FIniIncludeValues[i]);
      if Idx < 0 then
        AUsesList.add(FIniIncludeValues[i]);
    end;
  end;

  for i := 0 to Pred(FOwnedObjs.Count) do
    FOwnedObjs[i].UpdateUsesStringList(AUsesList);
end;

{ TDfmToFmxItem }

constructor TDfmToFmxItem.CreateItem(AParent: TDfmToFmxObject; AClassName: String; AStm: TStreamReader; out
    ListEndFound: Boolean);
begin
  FParent := AParent;
  FRoot := FParent.FRoot;
  FClassName := AClassName;
  InitObjects;
  IniFileLoad;
  ListEndFound := ReadContents(AStm) = '>';
end;

function TDfmToFmxItem.GetObjHeader: String;
begin
  Result := 'item' + CRLF;
end;

{ TCodeReplacements }

procedure TCodeReplacements.AddEvent(const AEvent, AParams: String);
var
  Rep: TCodeReplacement;
begin
  Rep.IsEvent := True;
  Rep.NewCode := AParams;
  AddOrSetValue(AEvent, Rep);
end;

procedure TCodeReplacements.AddProperty(const AOldCode, ANewCode: String);
var
  Rep: TCodeReplacement;
begin
  Rep.IsEvent := False;
  Rep.NewCode := ANewCode;
  AddOrSetValue('.' + AOldCode, Rep);
end;

{ TEnumList }

constructor TEnumList.Create(AIniFile: TMemIniFile);
begin
  inherited Create([doOwnsValues]);
  FIniFile := AIniFile;
end;

function TEnumList.GetEnum(const AName: String; var AItems: TStringList): Boolean;
var
  Sections: TStringList;
begin
  if TryGetValue(AName, AItems) then
    Result := True
  else
  begin
    Sections := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
    try
      FIniFile.ReadSections(Sections);
      if Sections.IndexOf(AName) >= 0 then
      begin
        AItems := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
        FIniFile.ReadSectionValues(AName, AItems);
        Add(AName, AItems);
        Result := True;
      end
      else
        Result := False;
    finally
      Sections.Free;
    end;
  end;
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
  while (not Data.EndsWith('>')) and (not ClosingBracketFound) do
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

end.
