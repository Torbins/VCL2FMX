unit CvtrObj;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.StrUtils, Winapi.Windows, System.IniFiles, FMX.Objects,
  System.Generics.Collections, PatchLib, CvtrProp, Image, ImageList;

type
  TLinkControl = record
    DataSource : String;
    FieldName : String;
    Control : String;
  end;

  TLinkGridColumn = record
    Caption : String;
    FieldName : String;
    Width : String;
  end;

  TLinkGrid = record
    DataSource : String;
    GridControl : String;
    Columns : TArray<TLinkGridColumn>;
  end;

  TEnumList = TObjectDictionary<String,TStringList>;
  TDfmToFmxObject = class;
  TOwnedObjects = TObjectList<TDfmToFmxObject>;

  TDfmToFmxObject = class
  private
    FParent: TDfmToFmxObject;
    FRoot: TDfmToFmxObject;
    FLinkControlList: TArray<TLinkControl>;
    FLinkGridList: TArray<TLinkGrid>;
    FClassName: String;
    FOldClassName: String;
    FObjName: String;
    FOwnedObjs: TOwnedObjects;
    FDepth: integer;
    FGenerated: Boolean;
    FGenObjectType: String;
    F2DPropertyArray: TDfmProperties;
    FFmxProps: TFmxProperties;
    FIniReplaceValues,
    FIniIncludeValues,
    FIniSectionValues,
    FIniAddProperties,
    FIniDefaultValueProperties,
    FUsesTranslation: TStringlist;
    FEnumList: TEnumList;
    FIni: TMemIniFile;
    FOriginalIni: TMemIniFile;
    FFMXFileText: String;
    procedure InitObjects;
    procedure UpdateUsesStringList(AUsesList: TStrings);
    procedure ReadProperties(AData: String; AStm: TStreamReader);
    function ProcessUsesString(AOrigUsesArray: TArray<String>): String;
    function ProcessCodeBody(const ACodeBody: String): String;
    procedure IniFileLoad(AIni: TMemIniFile);
    procedure InternalProcessBody(var ABody: String);
    procedure LoadCommonProperties(AParamName: String);
    function TransformProperty(AProp: TDfmProperty): TFmxProperty;
    function FMXProperties(APad: String): String;
    function FMXSubObjects(APad: String): String;
    function GetFMXLiveBindings: String;
    function GetPASLiveBindings: String;
    procedure GenerateObject(AProp: TDfmProperty);
    procedure CalcImageWrapMode;
  public
    constructor Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader; ADepth: integer);
    constructor CreateGenerated(AParent: TDfmToFmxObject; AObjName, AClassName: String; ADepth: integer);
    destructor Destroy; override;
    procedure LoadInfileDefs(AIniFileName: String);
    class function DFMIsTextBased(ADfmFileName: String): Boolean;
    function GenPasFile(const APascalSourceFileName: String): String;
    function FMXFile(APad: String = ''): String;
    function WriteFMXToFile(const AFmxFileName: String): Boolean;
    function WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
    procedure LiveBindings(DfmObject: TOwnedObjects = nil);
  end;

implementation

uses
  System.Masks, Vcl.Graphics;

const
  ContinueCode: String = '#$Continue$#';

{ DfmToFmxObject }

{ Eduardo }
procedure TDfmToFmxObject.LiveBindings(DfmObject: TOwnedObjects = nil);
var
  I,J: Integer;
  sFields: String;
  obj: TDfmToFmxObject;
  sItem: String;
  slItem: TStringDynArray;
begin
  // Se não informou um objeto, obtem o inicial
  if DfmObject = nil then
    DfmObject := FOwnedObjs;
  if DfmObject = nil then
    Exit;

  // Passa por todos objetos filhos
  for I := 0 to Pred(DfmObject.Count) do
  begin
    // Obtem o objeto
    obj := DfmObject[I];

    // Se for uma grid
    if obj.FClassName.Equals('TDBGrid') then
    begin
      // Inicializa
      sFields := EmptyStr;

      // Cria um novo item na lista de grids
      SetLength(FLinkGridList, Succ(Length(FLinkGridList)));

      // Insere o nome da grid
      FLinkGridList[Pred(Length(FLinkGridList))].GridControl := obj.FObjName;

      // Passa por todas propriedades da grid
      for J := 0 to obj.F2DPropertyArray.Count - 1 do
      begin
        // Obtem os dados do DataSource
        if obj.F2DPropertyArray[J].Name = 'DataSource' then
          FLinkGridList[Pred(Length(FLinkGridList))].DataSource := obj.F2DPropertyArray[J].Value;

        // Se for as colunas
        if obj.F2DPropertyArray[J].Name = 'Columns' then
        begin
          // Obtem os dados dos fields
          sFields := obj.F2DPropertyArray[J].Value;

          slItem := SplitString(sFields, #13);
          for sItem in slItem do
          begin
            if sItem = 'item' then
              SetLength(FLinkGridList[Pred(Length(FLinkGridList))].Columns, Succ(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns)))
            else
            if Trim(SplitString(sItem, '=')[0]) = 'Title.Caption' then
              FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].Caption := Trim(SplitString(sItem, '=')[1])
            else
            if Trim(SplitString(sItem, '=')[0]) = 'FieldName' then
              FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].FieldName := Trim(SplitString(sItem, '=')[1])
            else
            if Trim(SplitString(sItem, '=')[0]) = 'Width' then
              FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].Width := Trim(SplitString(sItem, '=')[1]);
          end;
        end;

        // Se ja encontrou tudo, sai do loop
        if not FLinkGridList[Pred(Length(FLinkGridList))].DataSource.IsEmpty and not sFields.IsEmpty then
          Break;
      end;
    end;

    // Se o componente atual possui componentes nele, faz recursão
    if Assigned(obj.FOwnedObjs) and (obj.FOwnedObjs.Count > 0) then
      LiveBindings(obj.FOwnedObjs);
  end;
end;

{ Eduardo }
function TDfmToFmxObject.GetFMXLiveBindings: String;
var
  I: Integer;
  J: Integer;
begin
  if (Length(FLinkControlList) = 0) and (Length(FLinkGridList) = 0) then
    Exit(EmptyStr);

  // Adiciona BindingsList
  Result :=
        '  object BindingsList: TBindingsList '+
  CRLF +'    Methods = <> '+
  CRLF +'    OutputConverters = <> '+
  CRLF +'    Left = 20 '+
  CRLF +'    Top = 5 ';

  // Passa pela lista de controles
  for I := 0 to High(FLinkControlList) do
  begin
    Result := Result +
    CRLF +'    object LinkControlToField'+ I.ToString +': TLinkControlToField '+
    CRLF +'      Category = ''Quick Bindings''' +
    CRLF +'      DataSource = '+ FLinkControlList[I].DataSource +
    CRLF +'      FieldName = '+ FLinkControlList[I].FieldName +
    CRLF +'      Control = '+ FLinkControlList[I].Control +
    CRLF +'      Track = False '+
    CRLF +'    end ';
  end;

  // Passa pela lista de grids
  for I := 0 to High(FLinkGridList) do
  begin
    Result := Result +
    CRLF +'    object LinkGridToDataSourceBindSourceDB'+ I.ToString +': TLinkGridToDataSource '+
    CRLF +'      Category = ''Quick Bindings''' +
    CRLF +'      DataSource = '+ FLinkGridList[I].DataSource +
    CRLF +'      GridControl = '+ FLinkGridList[I].GridControl +
    CRLF +'      Columns = < ';

    // Passa pela lista de colunas da grid
    for J := 0 to High(FLinkGridList[I].Columns) do
    begin
      Result := Result +
      CRLF +'        item '+
      CRLF +'          MemberName = '+ FLinkGridList[I].Columns[J].FieldName;
      
      // Se tem Caption
      if not FLinkGridList[I].Columns[J].Caption.IsEmpty then
      begin
        Result := Result +
        CRLF +'          Header = '+ FLinkGridList[I].Columns[J].Caption;      
      end;
      
      // Se tem Width
      if not FLinkGridList[I].Columns[J].Width.IsEmpty then
      begin
        Result := Result +
        CRLF +'          Width = '+ FLinkGridList[I].Columns[J].Width;      
      end;
      
      Result := Result +
      CRLF +'        end ';
    end;

    Result := Result +
    CRLF +'        > '+
    CRLF +'    end ';
  end;

  Result := Result +
  CRLF +'  end ';
end;

{ Eduardo }
function TDfmToFmxObject.GetPASLiveBindings: String;
var
  I: Integer;
begin
  if (Length(FLinkControlList) = 0) and (Length(FLinkGridList) = 0) then
    Exit(EmptyStr);

  // Adiciona BindingsList
  Result := CRLF + '    BindingsList: TBindingsList; ';

  // Passa pela lista de controles
  for I := 0 to High(FLinkControlList) do
  begin
    Result := Result +
    CRLF +'    LinkControlToField'+ I.ToString +': TLinkControlToField; ';
  end;

  // Passa pela lista de grids
  for I := 0 to High(FLinkGridList) do
  begin
    Result := Result +
    CRLF +'    LinkGridToDataSourceBindSourceDB'+ I.ToString +': TLinkGridToDataSource; ';
  end;
end;

procedure TDfmToFmxObject.CalcImageWrapMode;
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
  for PropLine in F2DPropertyArray do
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

constructor TDfmToFmxObject.Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader; ADepth: integer);
var
  InputArray: TArray<String>;
  Data: String;
begin
  FParent := AParent;
  if Assigned(FParent) then
    FRoot := FParent.FRoot
  else
    FRoot := Self;
  InitObjects;
  FDepth := ADepth;
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
        FOwnedObjs.Add(TDfmToFmxObject.Create(Self, Data, AStm, FDepth + 1))
      else
        ReadProperties(Data,AStm);
      Data := Trim(AStm.ReadLine);
    end
  end
  else
    raise Exception.Create('Bad Start::' + ACreateText);
end;

constructor TDfmToFmxObject.CreateGenerated(AParent: TDfmToFmxObject; AObjName, AClassName: String; ADepth: integer);
begin
  FParent := AParent;
  FRoot := FParent.FRoot;
  FDepth := ADepth;
  FObjName := AObjName;
  FClassName := AClassName;
  FGenerated := True;
  InitObjects;
  IniFileLoad(FParent.FIni);
end;

destructor TDfmToFmxObject.Destroy;
begin
  FFmxProps.Free;
  F2DPropertyArray.Free;
  FOwnedObjs.Free;
  FIniReplaceValues.Free;
  FIniIncludeValues.Free;
  FIniSectionValues.Free;
  FUsesTranslation.Free;
  FEnumList.Free;
  FIniAddProperties.Free;
  FIniDefaultValueProperties.Free;
  FOriginalIni.Free;
end;

class function TDfmToFmxObject.DFMIsTextBased(ADfmFileName: String): Boolean;
var
  DFMFile: TStreamReader;
begin
  Result := false;
  if not FileExists(ADfmFileName) then
    Exit;

  DFMFile := TStreamReader.Create(ADfmFileName);
  try
    if Pos('object', DFMFile.ReadLine) > 0 then
      Result := true;
  finally
    DFMFile.Free;
  end;
end;

function TDfmToFmxObject.FMXFile(APad: String = ''): String;
var
  Properties, lb: String;
begin
  if FFMXFileText <> '' then
    Exit(FFMXFileText);

  Properties := FMXProperties(APad);
  if FObjName <> '' then
    FFMXFileText := APad +'object '+ FObjName +': '+ FClassName + CRLF
  else
    FFMXFileText := APad +'object '+ FClassName + CRLF;
  FFMXFileText := FFMXFileText + Properties + FMXSubObjects(APad +' ');
  if APad = EmptyStr then
  begin
    lb := GetFMXLiveBindings;
    if lb <> '' then
      FFMXFileText := FFMXFileText + lb + CRLF;
  end;
  FFMXFileText := FFMXFileText + APad +'end' + CRLF;
  Result := FFMXFileText;
end;

function TDfmToFmxObject.FMXProperties(APad: String): String;
var
  i: Integer;
  sProp: String;
  ExistingProp: TFmxProperty;

  procedure HandleStyledSettings(AExcludeElement: String);
  var
    Prop: TFmxProperty;
  begin
    Prop := FFmxProps.FindByName('StyledSettings');

    if not Assigned(Prop) then
    begin
      Prop := TFmxProperty.Create('StyledSettings', '[Family, Size, Style, FontColor, Other]');
      FFmxProps.AddProp(Prop);
    end;

    Prop.Value := ReplaceStr(Prop.Value, AExcludeElement, '');
    Prop.Value := ReplaceStr(Prop.Value, '[, ', '[');
    Prop.Value := ReplaceStr(Prop.Value, ', , ', ', ');
    Prop.Value := ReplaceStr(Prop.Value, ', ]', ']');
  end;

  procedure CalcShapeClass;
  var
    Shape: String;
    Prop: TDfmProperty;
  begin
    Prop := F2DPropertyArray.FindByName('Shape');
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
    Line: TDfmProperty;
    Mask: TMask;
    Found: Boolean;
    Parent: TDfmToFmxObject;
  begin
    Mask := TMask.Create(ACopyProp);
    try
      Found := False;
      Parent := FParent;
      repeat
        for Line in Parent.F2DPropertyArray do
          if Mask.Matches(Line.Name) then
          begin
            FFmxProps.AddProp(TransformProperty(Line));
            Found := True;
          end;
        Parent := Parent.FParent;
      until Found or not Assigned(Parent);
    finally
      Mask.Free;
    end;
  end;

  procedure ReconsiderAfterRemovingRule(ARemoveRule: String);
  var
    Line: TDfmProperty;
    Mask: TMask;
    i: Integer;
  begin
    Mask := TMask.Create(ARemoveRule);
    try
      for i := Pred(FIniSectionValues.Count) downto 0 do
        if Mask.Matches(FIniSectionValues.Names[i]) then
          FIniSectionValues.Delete(i);

      LoadCommonProperties(ARemoveRule);

      for Line in F2DPropertyArray do
        if Mask.Matches(Line.Name) then
          FFmxProps.AddProp(TransformProperty(Line));
    finally
      Mask.Free;
    end;
  end;

begin
  Result := EmptyStr;

  for i := 0 to F2DPropertyArray.Count - 1 do
    FFmxProps.AddProp(TransformProperty(F2DPropertyArray[i]));

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
  I: integer;
begin
  Result := EmptyStr;
  if FOwnedObjs = nil then
    Exit;

  for I := 0 to Pred(FOwnedObjs.Count) do
    Result := Result + FOwnedObjs[I].FMXFile(APad +' ');
end;

procedure TDfmToFmxObject.GenerateObject(AProp: TDfmProperty);

  procedure GenerateFieldLink;
  var
    i, Len: Integer;
    CurrentLink: ^TLinkControl;
  begin
    CurrentLink := nil;

    for i := 0 to High(FRoot.FLinkControlList) do
      if FRoot.FLinkControlList[i].Control = FObjName then
      begin
        CurrentLink := @(FRoot.FLinkControlList[i]);
        Break;
      end;

    if not Assigned(CurrentLink) then
    begin
      Len := Length(FRoot.FLinkControlList);
      SetLength(FRoot.FLinkControlList, Len + 1);
      CurrentLink := @(FRoot.FLinkControlList[Len]);
      CurrentLink.Control := FObjName;
    end;

    if AProp.Name = 'DataField' then
      CurrentLink.FieldName := AProp.Value;

    if AProp.Name = 'DataSource' then
      CurrentLink.DataSource := AProp.Value;
  end;

  procedure GenerateProperty(AObj: TDfmToFmxObject; APropName, APropValue: String);
  var
    Prop: TDfmProperty;
  begin
    Prop := AObj.F2DPropertyArray.FindByName(APropName);

    if Assigned(Prop) then
      Prop.Value := APropValue
    else
    begin
      Prop := TDfmProperty.Create(APropName, APropValue);
      AObj.F2DPropertyArray.Add(Prop);
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

    Result := TDfmToFmxObject.CreateGenerated(Self, AObjName, ADFMClass, FDepth + 1);
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
    GenerateFieldLink;

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

function TDfmToFmxObject.GenPasFile(const APascalSourceFileName: String): String;
const
  cUses = 'uses';
  cUsesLen = Length(cUses);
  cBindSrc = 'TBindSourceDB;';
  cBindSrsLen = Length(cBindSrc);
var
  PasFile: TStreamReader;
  PreUsesString, PostUsesString, UsesString: String;
  UsesArray: TArray<String>;
  StartPos, EndPos, BindInsertPos: Integer;
begin
  Result := '';
  PostUsesString := '';
  UsesString := '';
  if not FileExists(APascalSourceFileName) then
    Exit;

  PasFile := TStreamReader.Create(APascalSourceFileName);
  try
    PreUsesString := PasFile.ReadToEnd;
  finally
    PasFile.Free;
  end;

  if Length(PreUsesString) > 20 then
  begin
    StartPos := PosNoCase(cUses, PreUsesString) + cUsesLen;
    EndPos := Pos(';', PreUsesString, StartPos);
    UsesArray := StringReplace(Copy(PreUsesString, StartPos, EndPos - StartPos), CRLF, '', [rfReplaceAll]).Split([',']);
    PostUsesString := Copy(PreUsesString, EndPos);
    PostUsesString := ProcessCodeBody(PostUsesString);

    BindInsertPos := Pos(cBindSrc, PostUsesString) + cBindSrsLen;
    if BindInsertPos = cBindSrsLen then
    begin
      BindInsertPos := PosNoCase(FClassName, PostUsesString);
      BindInsertPos := Pos(')', PostUsesString, BindInsertPos);
    end;
    PostUsesString := Copy(PostUsesString, 1, BindInsertPos) + GetPASLiveBindings + Copy(PostUsesString, BindInsertPos + 1);

    SetLength(PreUsesString, Pred(StartPos) - cUsesLen);
    UsesString := ProcessUsesString(UsesArray);
  end;
  Result := PreUsesString + UsesString + PostUsesString;
end;

procedure TDfmToFmxObject.IniFileLoad(AIni: TMemIniFile);
var
  i: integer;
  NewClassName: String;
  Sections: TStringList;
begin
  if AIni = nil then
    Exit;
  FIni := AIni;
  if FDepth < 1 then
  begin
    AIni.ReadSectionValues('TForm', FIniSectionValues);
    AIni.ReadSectionValues('TForm#Replace', FIniReplaceValues);
    AIni.ReadSection('TForm#Include', FIniIncludeValues);
  end
  else
  begin
    NewClassName := AIni.ReadString('ObjectChanges', FClassName, EmptyStr);
    if NewClassName <> EmptyStr then
    begin
      FOldClassName := FClassName;
      FClassName := NewClassName;
    end;
    AIni.ReadSectionValues(FClassName, FIniSectionValues);
    AIni.ReadSectionValues(FClassName + '#Replace', FIniReplaceValues);
    AIni.ReadSection(FClassName + '#Include', FIniIncludeValues);
    AIni.ReadSectionValues(FClassName + '#AddIfPresent', FIniAddProperties);
    AIni.ReadSectionValues(FClassName + '#DefaultValueProperty', FIniDefaultValueProperties);

    LoadCommonProperties('*');
  end;

  Sections := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  try
    AIni.ReadSections(Sections);
    for var Section in Sections do
      if Section.StartsWith('#') and Section.EndsWith('#') then
      begin
        var EnumElements := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
        AIni.ReadSectionValues(Section, EnumElements);
        FEnumList.Add(Section, EnumElements);
      end;
  finally
    Sections.Free;
  end;

  for i := 0 to Pred(FOwnedObjs.Count) do
    FOwnedObjs[i].IniFileLoad(AIni);
end;

procedure TDfmToFmxObject.InitObjects;
begin
  F2DPropertyArray := TDfmProperties.Create({AOwnsObjects} True);
  FFmxProps := TFmxProperties.Create({AOwnsObjects} True);
  FEnumList := TEnumList.Create([doOwnsValues]);
  FIniAddProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniDefaultValueProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniIncludeValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniReplaceValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FIniSectionValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FOwnedObjs := TOwnedObjects.Create({AOwnsObjects} True);
  FUsesTranslation := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
end;

procedure TDfmToFmxObject.InternalProcessBody(var ABody: String);
var
  i, NameStart, ClassStart, LineEnd: Integer;
begin
  if FGenerated then
  begin
    NameStart := PosNoCase(FParent.FObjName, ABody);
    if NameStart = 0 then
      raise Exception.Create('Can''t find parent control ' + FParent.FObjName + ' in form class');

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

    FIni.ReadSectionValues('CommonProperties', CommonProps);
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
    FIni.ReadSectionValues('CommonProperties#AddIfPresent', CommonProps);
    for i := 0 to Pred(CommonProps.Count) do
      if FIniAddProperties.IndexOfName(CommonProps.Names[i]) = -1 then
        FIniAddProperties.Add(CommonProps[i]);
  finally
    ParamMask.Free;
    CommonProps.Free;
    Candidates.Free;
  end;
end;

procedure TDfmToFmxObject.LoadInfileDefs(AIniFileName: String);
begin
  FOriginalIni := TMemIniFile.Create(AIniFileName);
  IniFileLoad(FOriginalIni);
end;

function TDfmToFmxObject.ProcessCodeBody(const ACodeBody: String): String;
var
  BdyStr: String;
begin
  BdyStr := StringReplace(ACodeBody, '{$R *.DFM}', '{$R *.FMX}', [rfIgnoreCase]);

  InternalProcessBody(BdyStr);

  Result := BdyStr;
end;

function TDfmToFmxObject.ProcessUsesString(AOrigUsesArray: TArray<String>): String;
var
  i, LineLen: integer;
begin
  PopulateStringsFromArray(FUsesTranslation, AOrigUsesArray);
  UpdateUsesStringList(FUsesTranslation);
  Result := 'uses'#13#10'  ';
  LineLen := 2;
  for i := 0 to Pred(FUsesTranslation.Count) do
    if Trim(FUsesTranslation[i]) <> EmptyStr then
    begin
      LineLen := LineLen + Length(FUsesTranslation[i]) + 2;
      if LineLen > 80 then
      begin
        Result := Result + #13#10'  ';
        LineLen := 2 + Length(FUsesTranslation[i]) + 2;
      end;
      Result := Result + FUsesTranslation[i] + ', ';
    end;
  SetLength(Result, Length(Result) - 2);
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
  F2DPropertyArray.Add(Prop);
end;

function TDfmToFmxObject.TransformProperty(AProp: TDfmProperty): TFmxProperty;
var
  NewName: String;
  Mask: TMask;
  DefaultValuePropPos: Integer;

  function ReplaceEnum(var ReplacementProp: TFmxProperty): Boolean;
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
  NewUnits: TStringList;
begin
  if FIniReplaceValues <> nil then
  begin
    NewUnits := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
    try
      for i := Pred(AUsesList.Count) downto 0 do
      begin
        Idx := FIniReplaceValues.IndexOfName(AUsesList[i]);
        if Idx >= 0 then
        begin
          AUsesList.Delete(i);
          NewUnits.Add(FIniReplaceValues.ValueFromIndex[Idx]);
        end;
      end;
      AUsesList.AddStrings(NewUnits);
    finally
      NewUnits.Free;
    end;
  end;

  for i := Pred(AUsesList.Count) downto 0 do
    if Trim(AUsesList[i]) = EmptyStr then
      AUsesList.Delete(i);

  if FIniIncludeValues <> nil then
  begin
    for i := 0 to Pred(FIniIncludeValues.Count) do
    begin
      Idx := AUsesList.IndexOf(FIniIncludeValues[i]);
      if Idx < 0 then
        AUsesList.add(FIniIncludeValues[i]);
    end;
  end;

  if FOwnedObjs = nil then
    Exit;

  for i := 0 to Pred(FOwnedObjs.Count) do
    FOwnedObjs[i].UpdateUsesStringList(AUsesList);
end;

function TDfmToFmxObject.WriteFMXToFile(const AFmxFileName: String): Boolean;
var
  OutFile: TStreamWriter;
  s: String;
begin
  s := FMXFile;
  if s.IsEmpty then
    raise Exception.Create('There is no data for the file FMX!');

  if FileExists(AFmxFileName) then
    RenameFile(AFmxFileName, ChangeFileExt(AFmxFileName, '.fbk'));

  OutFile := TStreamWriter.Create(AFmxFileName, {Append} False, TEncoding.UTF8);
  try
    OutFile.Write(s);
    Result := True;
  finally
    OutFile.Free;
  end;
end;

function TDfmToFmxObject.WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
var
  OutFile: TStreamWriter;
  s: String;
begin
  if not FileExists(APascalSourceFileName) then
    raise Exception.Create('Pascal Source:' + APascalSourceFileName + ' Does not Exist');

  s := GenPasFile(APascalSourceFileName);
  if s = '' then
    raise Exception.Create('No Data for Pas File');
  s := StringReplace(s, ChangeFileExt(ExtractFileName(APascalSourceFileName), ''), ChangeFileExt(ExtractFileName(APasOutFileName), ''), [rfIgnoreCase]);
  if FileExists(APasOutFileName) then
    RenameFile(APasOutFileName, ChangeFileExt(APasOutFileName, '.bak'));
  OutFile := TStreamWriter.Create(APasOutFileName, {Append} False, TEncoding.UTF8);
  try
    OutFile.Write(s);
    Result := true;
  finally
    OutFile.Free;
  end;
end;

end.
