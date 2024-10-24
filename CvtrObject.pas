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
    constructor CreateFromLine(const APropLine: string); virtual;
    function ToString(APad: String): String; reintroduce; virtual;
  end;

  TFmxProperties = class(TObjectList<TFmxPropertyBase>)
  public
    procedure AddProp(AProp: TFmxPropertyBase);
    procedure AddMultipleProps(APropsText: String);
    function FindByName(AName: String): TFmxPropertyBase;
  end;

  IDfmToFmxRoot = interface
    procedure AddGridColumns(AObjName: String; AProp: TFmxPropertyBase);
    procedure AddGridLink(AObjName: String; AProp: TDfmPropertyBase);
    procedure AddFieldLink(AObjName: String; AProp: TDfmPropertyBase);
    function GetIniFile: TMemIniFile;
    property IniFile: TMemIniFile read GetIniFile;
  end;

  TRule = record
    NewPropName: String;
    Action: String;
    Parameter: String;
  end;

  TDfmToFmxObject = class;
  TOwnedObjects = class(TObjectList<TDfmToFmxObject>);
  TEnumList = class(TObjectDictionary<String, TStringList>);

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
    procedure InitObjects; virtual;
    function FMXProperties(APad: String): String;
    function FMXSubObjects(APad: String): String;
    function ReadContents(AStm: TStreamReader): String;
    function GetRule(AProp: TDfmPropertyBase): TRule;
    function TransformProperty(AProp: TDfmPropertyBase): TFmxPropertyBase;
    procedure LoadCommonProperties(AParamName: String);
    procedure LoadEnums;
    procedure GenerateObject(AProp: TDfmPropertyBase; AObjectType: string);
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

constructor TFmxPropertyBase.CreateFromLine(const APropLine: string);
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
    Add(TFmxProperty.CreateFromLine(Prop));
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
    FFmxProps.AddProp(TFmxProperty.CreateFromLine(sProp));
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
        FFmxProps.AddProp(TFmxProperty.CreateFromLine(sProp));
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

procedure TDfmToFmxObject.GenerateObject(AProp: TDfmPropertyBase; AObjectType: string);

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
  if AObjectType = 'ColoredRect' then
  begin
    Obj := GetObject(FObjName + '_Color', 'TShape', ColoredRectInitParams);

    if AProp.Name = 'Color' then
      GenerateProperty(Obj, 'Brush.Color', AProp.Value)
    else
      GenerateProperty(Obj, AProp.Name, AProp.Value);
  end;

  if AObjectType = 'FieldLink' then
    FRoot.AddFieldLink(FObjName, AProp);

  if AObjectType = 'GridLink' then
    FRoot.AddGridLink(FObjName, AProp);

  if AObjectType = 'MultipleTabs' then
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

  if AObjectType = 'SeparateCaption' then
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

function TDfmToFmxObject.GetObjHeader: string;
begin
  if FObjName <> '' then
    Result := 'object ' + FObjName + ': ' + FClassName + CRLF
  else
    Result := 'object ' + FClassName + CRLF;
end;

function TDfmToFmxObject.GetRule(AProp: TDfmPropertyBase): TRule;
var
  RuleLine: String;
  Mask: TMask;
  ActionNameStart, ActionNameEnd: Integer;
begin
  RuleLine := Trim(FIniSectionValues.Values[AProp.Name]);
  if RuleLine = '' then
    for var i := 0 to FIniSectionValues.Count - 1 do
    begin
      Mask := TMask.Create(FIniSectionValues.Names[i]);
      try
        if Mask.Matches(AProp.Name) then
        begin
          RuleLine := FIniSectionValues.ValueFromIndex[i];
          Break;
        end;
      finally
        Mask.Free;
      end;
    end;
  if RuleLine = '' then
    Result.NewPropName := AProp.Name
  else
  begin
    ActionNameStart := RuleLine.IndexOf('#');

    case ActionNameStart of
      -1: Result.NewPropName := RuleLine;
      0: Result.NewPropName := AProp.Name;
    else
      Result.NewPropName := RuleLine.Substring(0, ActionNameStart).Trim;
    end;

    ActionNameEnd := RuleLine.IndexOf('#', ActionNameStart + 1);
    if ActionNameEnd = -1 then
      Exit;

    Result.Action := RuleLine.Substring(ActionNameStart, ActionNameEnd - ActionNameStart + 1);
    Result.Parameter := RuleLine.Substring(ActionNameEnd + 1);
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
  LoadEnums;
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
    Rule := GetRule(Prop);
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

function TDfmToFmxObject.TransformProperty(AProp: TDfmPropertyBase): TFmxPropertyBase;
type
  TEnumResult = (erNotEnum, erIgnore, erOk);
var
  Mask: TMask;
  DefaultValuePropPos: Integer;
  Rule: TRule;
  EnumValue, Item: String;

  function ReplaceEnum(const APropValue: String; var AEnumValue: String): TEnumResult;
  var
    Item: Integer;
    EnumItems: TStringList;
  begin
    Result := erNotEnum;

    if (Rule.Action = '') or (Rule.Action = '#ItemClass#') then
      Exit;

    if not FEnumList.TryGetValue(Rule.Action, EnumItems) then
      raise Exception.Create('Required enum ' + Rule.Action + ' not found');

    Item := EnumItems.IndexOfName(APropValue);
    if Item >= 0 then
      AEnumValue := EnumItems.ValueFromIndex[Item]
    else
    begin
      Item := EnumItems.IndexOfName('#UnknownValuesAllowed#');
      if Item < 0 then
        raise Exception.Create('Unknown item ' + APropValue + ' in enum ' + Rule.Action)
      else
      begin
        if EnumItems.ValueFromIndex[Item] = '#GenerateColorValue#' then
          AEnumValue := ConvertColor(StrToUInt(APropValue))
        else
          AEnumValue := APropValue;
      end;
    end;

    if AEnumValue = '#GenerateColorValue#' then
      AEnumValue := ConvertColor(ColorToRGB(StringToColor(APropValue)));

    if AEnumValue = '#IgnoreValue#' then
    begin
      AEnumValue := '';
      Exit(erIgnore);
    end;

    if AEnumValue.StartsWith('#SetProperty#', {IgnoreCase} True) then
    begin
      FFmxProps.AddMultipleProps(Copy(AEnumValue, Length('#SetProperty#') + 1));
      AEnumValue := '';
      Exit(erIgnore);
    end;

    Result := erOk;
  end;

begin
  Rule := GetRule(AProp);

  if Rule.Action = '#ConvertFontSize#' then
    Result := TFmxProperty.Create(Rule.NewPropName, Abs(AProp.Value.ToInteger).ToString)
  else
  if Rule.Action = '#Delete#' then
  begin
    Result := nil;
    if AProp is TDfmItemsProp then
      TDfmItemsProp(AProp).Transform(nil);
  end
  else
  if Rule.Action = '#GenerateLinkColumns#' then
  begin
    if not (AProp is TDfmItemsProp) then
      raise Exception.Create('#GenerateColumns# can be used only with object list properties');

    Result := TFmxItemsProp.Create(Rule.NewPropName);
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
  if Rule.Action = '#ImageData#' then
    Result := TFmxImageProp.Create(Rule.NewPropName, AProp.Value)
  else
  if Rule.Action = '#ImageListData#' then
    Result := TFmxImageListProp.Create(Rule.NewPropName, AProp.Value)
  else
  if Rule.Action = '#SetValue#' then
  begin
    FFmxProps.AddMultipleProps(Rule.NewPropName + '=' + Rule.Parameter);
    Result := nil;
  end
  else
  if AProp is TDfmSetProp then
  begin
    Result := TFmxSetProp.Create(Rule.NewPropName);
    for Item in TDfmSetProp(AProp).Items do
      case ReplaceEnum(Item, EnumValue) of
        erOk: TFmxSetProp(Result).Items.Add(EnumValue);
        erNotEnum: TFmxSetProp(Result).Items.Add(Item);
      end;
  end
  else
  case ReplaceEnum(AProp.Value, EnumValue) of
    erOk: Result := TFmxProperty.Create(Rule.NewPropName, EnumValue);
    erNotEnum:
      begin
        if AProp is TDfmStringsProp then
          Result := TFmxStringsProp.Create(Rule.NewPropName, TDfmStringsProp(AProp).Strings)
        else
        if AProp is TDfmDataProp then
          Result := TFmxDataProp.Create(Rule.NewPropName, AProp.Value)
        else
        if AProp is TDfmItemsProp then
        begin
          Result := TFmxItemsProp.Create(Rule.NewPropName);
          TDfmItemsProp(AProp).Transform(TFmxItemsProp(Result).Items);
        end
        else
          Result := TFmxProperty.Create(Rule.NewPropName, AProp.Value);
      end;
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

end.
