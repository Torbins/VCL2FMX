unit CvtrObject;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.IniFiles;

type
  TDfmPropertyBase = class
  protected
    FName: String;
    FValue: string;
    function GetValue: String; virtual;
  public
    property Name: String read FName;
    property Value: String read GetValue write FValue;
    constructor Create(const AName, AValue: string); overload; virtual;
  end;

  TDfmProperties = class(TObjectList<TDfmPropertyBase>)
  public
    function FindByName(AName: String): TDfmPropertyBase;
  end;

  TFmxPropertyBase = class
  protected
    FName: String;
    FValue: string;
    function GetValue: String; virtual;
  public
    property Name: String read FName;
    property Value: String read GetValue write FValue;
    constructor Create(const AName, AValue: string); overload; virtual;
    constructor Create(const APropLine: string); overload; virtual;
    function ToString(APad: String): String; reintroduce; virtual;
  end;

  TFmxProperties = class(TObjectList<TFmxPropertyBase>)
  public
    procedure AddProp(AProp: TFmxPropertyBase);
    procedure AddMultipleProps(APropsText: String);
    function FindByName(AName: String): TFmxPropertyBase;
  end;

  IDfmToFmxRoot = interface
    procedure AddFieldLink(AObjName: String; AProp: TDfmPropertyBase);
    function GetIniFile: TMemIniFile;
    property IniFile: TMemIniFile read GetIniFile;
  end;

  TDfmToFmxObject = class;
  TOwnedObjects = TObjectList<TDfmToFmxObject>;
  TEnumList = TObjectDictionary<String,TStringList>;

  TDfmToFmxObject = class
  private
    FFMXFileText: String;
    FGenObjectType: String;
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
    procedure InitObjects; virtual;
    function FMXProperties(APad: String): String;
    function FMXSubObjects(APad: String): String;
    procedure ReadProperties(AData: String; AStm: TStreamReader);
    function TransformProperty(AProp: TDfmPropertyBase): TFmxPropertyBase;
    procedure LoadCommonProperties(AParamName: String);
    procedure LoadEnums;
    procedure GenerateObject(AProp: TDfmPropertyBase);
    procedure InternalProcessBody(var ABody: String);
    procedure UpdateUsesStringList(AUsesList: TStrings); virtual;
  public
    property Root: IDfmToFmxRoot read FRoot;
    property Parent: TDfmToFmxObject read FParent;
    property ObjName: String read FObjName;
    property DfmProps: TDfmProperties read FDfmProps;
    constructor Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader); virtual;
    constructor CreateGenerated(AParent: TDfmToFmxObject; AObjName, AClassName: String);
    destructor Destroy; override;
    procedure IniFileLoad; virtual;
    function FMXFile(APad: String = ''): String; virtual;
  end;

  TDfmToFmxItem = class(TDfmToFmxObject)

  end;

  TDfmToFmxItems = class(TObjectList<TDfmToFmxItem>)
  end;

implementation

uses
  System.Masks, Vcl.Graphics, CvtrProp, PatchLib;

{ TDfmPropertyBase }

constructor TDfmPropertyBase.Create(const AName, AValue: string);
begin
  FName := AName;
  FValue := AValue;
end;

function TDfmPropertyBase.GetValue: String;
begin
  Result := FValue;
end;

{ TDfmProperties }

function TDfmProperties.FindByName(AName: String): TDfmPropertyBase;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = AName then
      Exit(Items[i]);
end;

{ TFmxPropertyBase }

constructor TFmxPropertyBase.Create(const AName, AValue: string);
begin
  FName := AName;
  FValue := AValue;
end;

constructor TFmxPropertyBase.Create(const APropLine: string);
var
  PropEqSign: Integer;
begin
  PropEqSign := APropLine.IndexOf('=');
  FName := APropLine.Substring(0, PropEqSign).Trim;
  FValue := APropLine.Substring(PropEqSign + 1).Trim;
end;

function TFmxPropertyBase.GetValue: String;
begin
  Result := FValue;
end;

function TFmxPropertyBase.ToString(APad: String): String;
begin
  Result := APad + '  ' + FName + ' = ' + FValue + CRLF;
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

procedure TFmxProperties.AddProp(AProp: TFmxPropertyBase);
begin
  if Assigned(AProp) then
    Add(AProp);
end;

function TFmxProperties.FindByName(AName: String): TFmxPropertyBase;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = AName then
      Exit(Items[i]);
end;

{ TDfmToFmxObject }

constructor TDfmToFmxObject.Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader);
var
  InputArray: TArray<String>;
  Data: String;
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
    Data := Trim(AStm.ReadLine);
    while Data <> 'end' do
    begin
      if Pos('object', Data) = 1 then
        FOwnedObjs.Add(TDfmToFmxObject.Create(Self, Data, AStm))
      else
        ReadProperties(Data,AStm);
      Data := Trim(AStm.ReadLine);
    end
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
  if FObjName <> '' then
    FFMXFileText := APad +'object '+ FObjName +': '+ FClassName + CRLF
  else
    FFMXFileText := APad +'object '+ FClassName + CRLF;
  FFMXFileText := FFMXFileText + Properties + FMXSubObjects(APad +' ');
  FFMXFileText := FFMXFileText + APad +'end' + CRLF;
  Result := FFMXFileText;
end;

function TDfmToFmxObject.FMXProperties(APad: String): String;
var
  i: Integer;
  sProp: String;
  ExistingProp: TFmxPropertyBase;

  procedure HandleStyledSettings(AExcludeElement: String);
  var
    Prop: TFmxPropertyBase;
  begin
    Prop := FFmxProps.FindByName('StyledSettings');

    if not Assigned(Prop) then
    begin
      Prop := TFmxProperty.Create('StyledSettings', '[Family, Size, Style, FontColor, Other]');
      FFmxProps.AddProp(Prop);
    end;

    Prop.Value := Prop.Value.Replace(AExcludeElement, '');
    Prop.Value := Prop.Value.Replace('[, ', '[');
    Prop.Value := Prop.Value.Replace(', , ', ', ');
    Prop.Value := Prop.Value.Replace(', ]', ']');
  end;

  procedure CalcImageWrapMode;
  var
    Center, Proportional, Stretch: Boolean;
    PropLine: TDfmPropertyBase;
    FmxProp: TFmxPropertyBase;
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
    Prop: TDfmPropertyBase;
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
    Prop: TDfmPropertyBase;
    Mask: TMask;
    Found: Boolean;
    Parent: TDfmToFmxObject;
  begin
    Mask := TMask.Create(ACopyProp);
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
    Line: TDfmPropertyBase;
    Mask: TMask;
    i: Integer;
  begin
    Mask := TMask.Create(ARemoveRule);
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
    sProp := FIniDefaultValueProperties.ValueFromIndex[i];
    if sProp.StartsWith('#CopyFromParent#') then
    begin
      CopyFromParent(Copy(sProp, Length('#CopyFromParent#') + 1));
      Continue;
    end;
    if sProp.StartsWith('#CalcImageWrapMode#') then
    begin
      CalcImageWrapMode;
      Continue;
    end;
    if sProp.StartsWith('#CalcShapeClass#') then
    begin
      CalcShapeClass;
      Continue;
    end;
    if sProp.StartsWith('#ReconsiderAfterRemovingRule#') then
    begin
      ReconsiderAfterRemovingRule(Copy(sProp, Length('#ReconsiderAfterRemovingRule#') + 1));
      Continue;
    end;
    FFmxProps.AddProp(TFmxProperty.Create(sProp));
  end;

  for i := 0 to Pred(FIniAddProperties.Count) do
  begin
    ExistingProp := FFmxProps.FindByName(FIniAddProperties.Names[i]);
    if Assigned(ExistingProp) then
    begin
      sProp := FIniAddProperties.ValueFromIndex[i];
      if sProp.StartsWith('#RemoveFromStyledSettings#') then
      begin
        HandleStyledSettings(Copy(sProp, Length('#RemoveFromStyledSettings#') + 1));
        Continue;
      end;
      ExistingProp := FFmxProps.FindByName(sProp.Split(['='], 1)[0].Trim);
      if not Assigned(ExistingProp) then
        FFmxProps.AddProp(TFmxProperty.Create(sProp));
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

procedure TDfmToFmxObject.GenerateObject(AProp: TDfmPropertyBase);

  procedure GenerateProperty(AObj: TDfmToFmxObject; APropName, APropValue: String);
  var
    Prop: TDfmPropertyBase;
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

  function GetObject(AObjName, ADFMClass: String; AInitProps: array of TProp; APosition: Integer = 0): TDfmToFmxObject;
  var
    i: Integer;
  begin
    for i := 0 to Pred(FOwnedObjs.Count) do
    begin
      if not FOwnedObjs[i].FGenerated then
        Break;
      if (FOwnedObjs[i].FClassName = ADFMClass) and (FOwnedObjs[i].FObjName = AObjName) then
        Exit(FOwnedObjs[i]);
    end;

    Result := TDfmToFmxObject.CreateGenerated(Self, AObjName, ADFMClass);
    FOwnedObjs.Insert(APosition, Result);
    for i := 0 to High(AInitProps) do
      GenerateProperty(Result, AInitProps[i].Name, AInitProps[i].Value);
  end;

const
  ColoredRectInitParams: array [0..5] of TProp = ((Name: 'Align'; Value: 'alClient'), (Name: 'Margins.Left'; Value: '1'),
    (Name: 'Margins.Top'; Value: '1'), (Name: 'Margins.Right'; Value: '1'), (Name: 'Margins.Bottom'; Value: '1'),
    (Name: 'Pen.Style'; Value: 'psClear'));
  SeparateCaptionInitParams: array [0..3] of TProp = ((Name: 'Align'; Value: 'alClient'),
    (Name: 'TabStop'; Value: 'False'), (Name: 'Alignment'; Value: 'taCenter'), (Name: 'Layout'; Value: 'tlCenter'));
var
  Obj: TDfmToFmxObject;
  Num: Integer;
  Caption, Val: String;
begin
  if FGenObjectType = 'ColoredRect' then
  begin
    Obj := GetObject(FObjName + '_Color', 'TShape', ColoredRectInitParams);

    if AProp.Name = 'Color' then
      GenerateProperty(Obj, 'Brush.Color', AProp.Value)
    else
      GenerateProperty(Obj, AProp.Name, AProp.Value);
  end;

  if FGenObjectType = 'FieldLink' then
    FRoot.AddFieldLink(FObjName, AProp);

  if FGenObjectType = 'MultipleTabs' then
  begin
    Val := AProp.Value.Trim(['(', ')', #13, #10]);
    Num := 1;

    for Caption in Val.Split([#13#10]) do
    begin
      Obj := GetObject(FObjName + 'Tab' + Num.ToString, 'TTabSheet', [], Num - 1);
      GenerateProperty(Obj, 'Caption', Caption);
      Inc(Num);
    end;
  end;

  if FGenObjectType = 'SeparateCaption' then
  begin
    Obj := GetObject(FObjName + '_Caption', 'TLabel', SeparateCaptionInitParams);

    if AProp.Name = 'ShowCaption' then
      GenerateProperty(Obj, 'Visible', AProp.Value)
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

procedure TDfmToFmxObject.IniFileLoad;
var
  i: integer;
  NewClassName: String;
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

  LoadCommonProperties('*');
  LoadEnums;

  for i := 0 to Pred(FOwnedObjs.Count) do
    FOwnedObjs[i].IniFileLoad;
end;

procedure TDfmToFmxObject.InitObjects;
begin
  FDfmProps := TDfmProperties.Create({AOwnsObjects} True);
  FFmxProps := TFmxProperties.Create({AOwnsObjects} True);
  FEnumList := TEnumList.Create([doOwnsValues]);
  FIniAddProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniDefaultValueProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniIncludeValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniSectionValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FOwnedObjs := TOwnedObjects.Create({AOwnsObjects} True);
end;

procedure TDfmToFmxObject.InternalProcessBody(var ABody: String);
var
  i, NameStart, ClassStart, LineEnd: Integer;
begin
  if FGenerated then
  begin
    NameStart := PosNoCase(FParent.ObjName, ABody);
    if NameStart = 0 then
      raise Exception.Create('Can''t find parent control ' + FParent.ObjName + ' in form class');

    LineEnd := Pos(CRLF, ABody, NameStart);
    if LineEnd = 0 then
      LineEnd := Pos(#13, ABody, NameStart);
    if LineEnd = 0 then
      LineEnd := Pos(#10, ABody, NameStart);
    if LineEnd = 0 then
      LineEnd := NameStart;

    Insert(CRLF + '    ' + FObjName + ': ' + FClassName + ';', ABody, LineEnd);
  end
  else
    if FOldClassName <> '' then
    begin
      NameStart := PosNoCase(FObjName, ABody);
      ClassStart := PosNoCase(FOldClassName, ABody, NameStart);
      ABody := Copy(ABody, 1, NameStart + Length(FObjName) - 1) + ': ' + FClassName + Copy(ABody, ClassStart + Length(FOldClassName));
    end;

  for i := 0 to Pred(FOwnedObjs.Count) do
    FOwnedObjs[i].InternalProcessBody(ABody);
end;

procedure TDfmToFmxObject.LoadCommonProperties(AParamName: String);
var
  i, j: integer;
  Found: Boolean;
  CommonProps, Candidates: TStringList;
  ParamMask, CommonPropMask, ExistingPropMask: TMask;
begin
  CommonProps := nil;
  Candidates := nil;
  ParamMask := nil;
  try
    CommonProps := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
    Candidates := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
    ParamMask := TMask.Create(AParamName);

    FRoot.IniFile.ReadSectionValues('CommonProperties', CommonProps);
    for i := 0 to Pred(CommonProps.Count) do
      if ParamMask.Matches(CommonProps.Names[i]) and
        (FIniSectionValues.IndexOfName(CommonProps.Names[i]) = -1) then
      begin
        Found := False;
        CommonPropMask := TMask.Create(CommonProps.Names[i]);
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
        if not Found then
          Candidates.Add(CommonProps[i]);
      end;

    for i := 0 to Pred(FIniSectionValues.Count) do
    begin
      ExistingPropMask := TMask.Create(FIniSectionValues.Names[i]);
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

procedure TDfmToFmxObject.LoadEnums;
var
  Section: String;
  Sections: TStringList;
begin
  Sections := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  try
    FRoot.IniFile.ReadSections(Sections);
    for Section in Sections do
      if Section.StartsWith('#') and Section.EndsWith('#') then
      begin
        var EnumElements := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
        FRoot.IniFile.ReadSectionValues(Section, EnumElements);
        FEnumList.Add(Section, EnumElements);
      end;
  finally
    Sections.Free;
  end;
end;

procedure TDfmToFmxObject.ReadProperties(AData: String; AStm: TStreamReader);
var
  PropEqSign: Integer;
  Name, Value: String;
  Prop: TDfmProperty;
begin
  PropEqSign := AData.IndexOf('=');
  Name := AData.Substring(0, PropEqSign).Trim;
  Value := AData.Substring(PropEqSign + 1).Trim;

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
    TDfmItemsProp(Prop).ReadItems(AStm);
  end
  else
  if Value[1] = '{' then
  begin
    Prop := TDfmDataProp.Create(Name, Value);
    TDfmDataProp(Prop).ReadData(AStm);
  end
  else
    Prop := TDfmProperty.Create(Name, Value);
  FDfmProps.Add(Prop);
end;

function TDfmToFmxObject.TransformProperty(AProp: TDfmPropertyBase): TFmxPropertyBase;
var
  NewName: String;
  Mask: TMask;
  DefaultValuePropPos: Integer;

  function ReplaceEnum(var ReplacementProp: TFmxPropertyBase): Boolean;
  var
    EnumNameStart, EnumNameEnd, Item, FontSize: Integer;
    EnumName, PropName, Value: String;
    EnumItems: TStringList;
  begin
    Result := False;
    EnumNameStart := Pos('#', NewName);
    if EnumNameStart = 0 then
      Exit;

    if EnumNameStart > 1 then
      PropName := Trim(Copy(NewName, 1, EnumNameStart - 1))
    else
      PropName := AProp.Name;

    EnumNameEnd := Pos('#', NewName, EnumNameStart + 1);
    if EnumNameEnd = 0 then
      Exit;

    EnumName := Copy(NewName, EnumNameStart, EnumNameEnd - EnumNameStart + 1);

    if EnumName = '#SetValue#' then
    begin
      FFmxProps.AddMultipleProps(NewName.Replace('#SetValue#', '=', [rfIgnoreCase]));
      ReplacementProp := nil;
      Exit(True);
    end;

    if EnumName = '#ConvertFontSize#' then
    begin
      FontSize := Abs(StrToInt(AProp.Value));
      ReplacementProp := TFmxProperty.Create(PropName, IntToStr(FontSize));
      Exit(True);
    end;

    if EnumName = '#ImageData#' then
    begin
      ReplacementProp := TFmxImageProp.Create(PropName, AProp.Value);
      Exit(True);
    end;

    if EnumName = '#ImageListData#' then
    begin
      ReplacementProp := TFmxImageListProp.Create(PropName, AProp.Value);
      Exit(True);
    end;

    if (EnumName = '') then
      Exit;
    if not FEnumList.TryGetValue(EnumName, EnumItems) then
      raise Exception.Create('Required enum ' + EnumName + ' not found');

    Item := EnumItems.IndexOfName(AProp.Value);
    if Item >= 0 then
      Value := EnumItems.ValueFromIndex[Item]
    else
    begin
      Item := EnumItems.IndexOfName('#UnknownValuesAllowed#');
      if Item < 0 then
        raise Exception.Create('Unknown item ' + AProp.Value + ' in enum ' + EnumName)
      else
      begin
        if EnumItems.ValueFromIndex[Item] = '#GenerateColorValue#' then
          Value := ConvertColor(StrToUInt(AProp.Value))
        else
          Value := AProp.Value;
      end;
    end;

    if Value = '#GenerateColorValue#' then
      Value := ConvertColor(ColorToRGB(StringToColor(AProp.Value)));

    if Value = '#IgnoreValue#' then
    begin
      ReplacementProp := nil;
      Exit(True);
    end;

    if Value.StartsWith('#SetProperty#', {IgnoreCase} True) then
    begin
      FFmxProps.AddMultipleProps(Copy(Value, Length('#SetProperty#') + 1));
      ReplacementProp := nil;
      Exit(True);
    end;

    ReplacementProp := TFmxProperty.Create(PropName, Value);
    Result := True;
  end;

begin
  NewName := Trim(FIniSectionValues.Values[AProp.Name]);
  if NewName = EmptyStr then
    for var i := 0 to Pred(FIniSectionValues.Count) do
    begin
      Mask := TMask.Create(FIniSectionValues.Names[i]);
      try
        if Mask.Matches(AProp.Name) then
        begin
          NewName := FIniSectionValues.ValueFromIndex[i];
          Break;
        end;
      finally
        Mask.Free;
      end;
    end;
  if NewName = EmptyStr then
    NewName := AProp.Name;
  if NewName = '#Delete#' then
    Result := nil
  else
  if NewName.StartsWith('#GenerateControl#') then
  begin
    FGenObjectType := Copy(NewName, Length('#GenerateControl#') + 1);
    GenerateObject(AProp);
    Result := nil;
  end
  else
  if not ReplaceEnum(Result) then
  begin
    if AProp is TDfmStringsProp then
      Result := TFmxStringsProp.Create(NewName, TDfmStringsProp(AProp).Strings)
    else
    if AProp is TDfmDataProp then
      Result := TFmxDataProp.Create(NewName, AProp.Value)
    else
      Result := TFmxProperty.Create(NewName, AProp.Value);
  end;

  if FIniDefaultValueProperties.Count > 0 then
  begin
    DefaultValuePropPos := FIniDefaultValueProperties.IndexOfName(AProp.Name);
    if DefaultValuePropPos >= 0 then
      FIniDefaultValueProperties.Delete(DefaultValuePropPos)
    else
      for var i := 0 to Pred(FIniDefaultValueProperties.Count) do
      begin
        Mask := TMask.Create(FIniDefaultValueProperties.Names[i]);
        try
          if Mask.Matches(AProp.Name) then
          begin
            FIniDefaultValueProperties.Delete(i);
            Break;
          end;
        finally
          Mask.Free;
        end;
      end;
  end;
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

end.