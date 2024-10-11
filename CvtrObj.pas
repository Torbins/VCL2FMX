unit CvtrObj;

interface

uses
  PatchLib,
  System.Classes,
  System.Types,
  System.SysUtils,
  System.StrUtils,
  Contnrs,
  Winapi.Windows,
  System.IniFiles,
  FMX.Objects,
  System.Generics.Collections,
  Image,
  ImageList;

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
  TDfmToFmxListItem = class;
  TOwnedItems = TObjectList<TDfmToFmxListItem>;

  TDfmToFmxObject = class(TObject)
  private
    FParent: TDfmToFmxObject;
    FLinkControlList: TArray<TLinkControl>;
    FLinkGridList: TArray<TLinkGrid>;
    FDFMClass: String;
    FOldDfmClass: String;
    FObjName: String;
    FOwnedObjs: TOwnedObjects;
    FOwnedItems: TOwnedItems;
    FDepth: integer;
    FGenerated: Boolean;
    F2DPropertyArray: TTwoDArrayOfString;
    FPropertyArraySz, FPropertyMax: integer;
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
    function OwnedObjs: TOwnedObjects;
    function IniSectionValues: TStringlist;
    function UsesTranslation: TStringlist;
    function IniReplaceValues: TStringlist;
    function IniIncludeValues: TStringlist;
    function IniAddProperties: TStringlist;
    function IniDefaultValueProperties: TStringlist;
    function PropertyArray(ARow: integer): TArrayOfStrings;
    procedure UpdateUsesStringList(AUsesList: TStrings);
    procedure ReadProperties(AData: String; AStm: TStreamReader; var AIdx: Integer);
    function ProcessUsesString(AOrigUsesArray: TArrayOfStrings): String;
    function ProcessCodeBody(const ACodeBody: String): String;
    procedure IniFileLoad(AIni: TMemIniFile);
    procedure InternalProcessBody(var ABody: String);
    procedure LoadCommonProperties(AParamName: String);
    procedure ReadItems(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStreamReader);
    function FMXClass: String;
    function TransformProperty(ACurrentName, ACurrentValue: String; APad: String = ''): String;
    function AddArrayOfItemProperties(APropertyIdx: Integer; APad: String): String;
    function FMXProperties(APad: String): String;
    function FMXSubObjects(APad: String): String;
    procedure ReadData(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStreamReader);
    function GetFMXLiveBindings: String;
    function GetPASLiveBindings: String;
    procedure ReadText(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStreamReader);
    procedure GenerateObject(AObjType, ACurrentName, ACurrentValue: string);
    procedure CalcImageWrapMode(APad: string; var APropsText: String);
  public
    constructor Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader; ADepth: integer);
    constructor CreateGenerated(AParent: TDfmToFmxObject; AObjName, ADFMClass: String; ADepth: integer);
    destructor Destroy; override;
    procedure LoadInfileDefs(AIniFileName: String);
    class function DFMIsTextBased(ADfmFileName: String): Boolean;
    function GenPasFile(const APascalSourceFileName: String): String;
    function FMXFile(APad: String = ''): String;
    function WriteFMXToFile(const AFmxFileName: String): Boolean;
    function WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
    procedure LiveBindings(DfmObject: TOwnedObjects = nil);
  end;

  TDfmToFmxListItem = class(TDfmToFmxObject)
    FHasMore: Boolean;
    FPropertyIndex: Integer;
    FOwner: TDfmToFmxObject;
    public
      constructor Create(AOwner: TDfmToFmxObject; APropertyIdx: integer; AStm: TStreamReader; ADepth: integer);
      property HasMore: Boolean read FHasMore;
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
    if obj.FDFMClass.Equals('TDBGrid') then
    begin
      // Inicializa
      sFields := EmptyStr;

      // Cria um novo item na lista de grids
      SetLength(FLinkGridList, Succ(Length(FLinkGridList)));

      // Insere o nome da grid
      FLinkGridList[Pred(Length(FLinkGridList))].GridControl := obj.FObjName;

      // Passa por todas propriedades da grid
      for J := Low(obj.F2DPropertyArray) to High(obj.F2DPropertyArray) do
      begin
        // Obtem os dados do DataSource
        if obj.F2DPropertyArray[J, 0].Equals('DataSource') then
          FLinkGridList[Pred(Length(FLinkGridList))].DataSource := obj.F2DPropertyArray[J, 1];

        // Se for as colunas
        if obj.F2DPropertyArray[J, 0].Equals('Columns') then
        begin
          // Obtem os dados dos fields
          sFields := obj.F2DPropertyArray[J, 1];

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

    // Se for um dbedit
    if obj.FDFMClass.Equals('TDBEdit') then
    begin
      // Cria um novo item na lista de dbedits
      SetLength(FLinkControlList, Succ(Length(FLinkControlList)));

      // Insere o nome do dbedit
      FLinkControlList[Pred(Length(FLinkControlList))].Control := obj.FObjName;

      // Passa por todas propriedades do dbedit
      for J := Low(obj.F2DPropertyArray) to High(obj.F2DPropertyArray) do
      begin
        // Obtem os dados do DataSource
        if obj.F2DPropertyArray[J, 0].Equals('DataSource') then
          FLinkControlList[Pred(Length(FLinkControlList))].DataSource := obj.F2DPropertyArray[J, 1];

        // Obtem os dados do field
        if obj.F2DPropertyArray[J, 0].Equals('DataField') then
          FLinkControlList[Pred(Length(FLinkControlList))].FieldName := GetArrayFromString(obj.F2DPropertyArray[J, 1], '=', True, True)[0];

        // Se ja encontrou tudo, sai do loop
        if not FLinkControlList[Pred(Length(FLinkControlList))].DataSource.IsEmpty and not FLinkControlList[Pred(Length(FLinkControlList))].FieldName.IsEmpty then
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
    CRLF +'      Category = '+ QuotedStr('Quick Bindings') +
    CRLF +'      DataSource = '+ FLinkControlList[I].DataSource +
    CRLF +'      FieldName = '+ QuotedStr(FLinkControlList[I].FieldName) +
    CRLF +'      Control = '+ FLinkControlList[I].Control +
    CRLF +'      Track = False '+
    CRLF +'    end ';
  end;

  // Passa pela lista de grids
  for I := 0 to High(FLinkGridList) do
  begin
    Result := Result +
    CRLF +'    object LinkGridToDataSourceBindSourceDB'+ I.ToString +': TLinkGridToDataSource '+
    CRLF +'      Category = '+ QuotedStr('Quick Bindings') +
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

function TDfmToFmxObject.AddArrayOfItemProperties(APropertyIdx: Integer; APad: String): String;
begin
  Result:=APad+'  item'+ CRLF +
  APad+ '  Prop1 = 6'+ CRLF +
  APad+ '  end>'+ CRLF;
  //Tempary patch
end;

procedure TDfmToFmxObject.CalcImageWrapMode(APad: string; var APropsText: String);
var
  Center, Proportional, Stretch: Boolean;
  PropLine: TArrayOfStrings;
  Value: String;
begin
  if Pos('WrapMode', APropsText) > 0 then
    Exit;

  Center := False;
  Proportional := False;
  Stretch := False;
  for PropLine in F2DPropertyArray do
  begin
    if PropLine[0] = 'Center' then
      Center := True;
    if PropLine[0] = 'Proportional' then
      Proportional := True;
    if PropLine[0] = 'Stretch' then
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

  APropsText := APropsText + APad + '  WrapMode = ' + Value + CRLF;
end;

constructor TDfmToFmxObject.Create(AParent: TDfmToFmxObject; ACreateText: String; AStm: TStreamReader; ADepth: integer);
var
  InputArray: TArrayOfStrings;
  Data: String;
  NxtChr: PChar;
  i: integer;
begin
  FParent := AParent;
  i := 0;
  FDepth := ADepth;
  if Pos('object', Trim(ACreateText)) = 1 then
  begin
    InputArray := GetArrayFromString(ACreateText, ' ');
    if Length(InputArray) > 2 then
    begin
      NxtChr := @InputArray[1][1];
      FObjName := FieldSep(NxtChr, ':');
      FDFMClass := InputArray[2];
    end
    else
    begin
      FObjName := '';
      FDFMClass := InputArray[1];
    end;
    Data := Trim(AStm.ReadLine);
    while Data <> 'end' do
    begin
      if Pos('object', Data) = 1 then
        OwnedObjs.Add(TDfmToFmxObject.Create(Self, Data, AStm, FDepth + 1))
      else
        ReadProperties(Data,AStm,i);
      Data := Trim(AStm.ReadLine);
    end
  end
  else
    raise Exception.Create('Bad Start::' + ACreateText);
  SetLength(F2DPropertyArray, FPropertyMax + 1);
end;

constructor TDfmToFmxObject.CreateGenerated(AParent: TDfmToFmxObject; AObjName, ADFMClass: String; ADepth: integer);
begin
  FParent := AParent;
  FDepth := ADepth;
  FObjName := AObjName;
  FDFMClass := ADFMClass;
  FGenerated := True;
  IniFileLoad(FParent.FIni);
end;

destructor TDfmToFmxObject.Destroy;
begin
  SetLength(F2DPropertyArray, 0);
  FOwnedObjs.Free;
  FOwnedItems.Free;
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

function TDfmToFmxObject.FMXClass: String;
begin
  Result := FDFMClass;
end;

function TDfmToFmxObject.FMXFile(APad: String = ''): String;
var
  Properties, lb: String;
begin
  if FFMXFileText <> '' then
    Exit(FFMXFileText);

  Properties := FMXProperties(APad);
  if FObjName <> '' then
    FFMXFileText := APad +'object '+ FObjName +': '+ FMXClass + CRLF
  else
    FFMXFileText := APad +'object '+ FMXClass + CRLF;
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

  procedure HandleStyledSettings(AExcludeElement: String; var ACurrentVal: String);
  var
    PropPos, SetStart, SetEnd: Integer;
    SetVal: String;
  begin
    SetStart := 0;
    SetEnd := 0;
    PropPos := Pos('StyledSettings', ACurrentVal);

    if PropPos = 0 then
      SetVal := '[Family, Size, Style, FontColor, Other]'
    else
    begin
      SetStart := Pos('[', ACurrentVal, PropPos);
      SetEnd := Pos(']', ACurrentVal, SetStart);
      SetVal := Copy(ACurrentVal, SetStart, SetEnd - SetStart + 1);
    end;

    SetVal := ReplaceStr(SetVal, AExcludeElement, '');
    SetVal := ReplaceStr(SetVal, '[, ', '[');
    SetVal := ReplaceStr(SetVal, ', , ', ', ');
    SetVal := ReplaceStr(SetVal, ', ]', ']');

    if PropPos = 0 then
      ACurrentVal := ACurrentVal + APad + '  StyledSettings = ' + SetVal + CRLF
    else
      ACurrentVal := Copy(ACurrentVal, 1, SetStart - 1) + SetVal + Copy(ACurrentVal, SetEnd + 1);
  end;

  procedure CalcShapeClass;
  var
    i: Integer;
    Shape: String;
  begin
    for i := 0 to High(F2DPropertyArray) do
      if (Length(F2DPropertyArray[i]) > 1) and (F2DPropertyArray[i, 0] = 'Shape') then
      begin
        Shape := F2DPropertyArray[i, 1];
        Break;
      end;

    FOldDfmClass := FDFMClass;
    if (Shape = '') or (Shape = 'stRectangle') or (Shape = 'stSquare') then
      FDFMClass := 'TRectangle';
    if Shape = 'stCircle' then
      FDFMClass := 'TCircle';
    if Shape = 'stEllipse' then
      FDFMClass := 'TEllipse';
    if (Shape = 'stRoundRect') or (Shape = 'stRoundSquare') then
      FDFMClass := 'TRoundRect';
  end;

  procedure CopyFromParent(ACopyProp: String; var ACurrentProps: String);
  var
    Line: TArrayOfStrings;
    Prop: String;
    Mask: TMask;
  begin
    Mask := TMask.Create(ACopyProp);
    try
      for Line in FParent.F2DPropertyArray do
        if Mask.Matches(Line[0]) then
        begin
          Prop := TransformProperty(Line[0], Line[1], APad);
          if not Prop.IsEmpty then
            ACurrentProps := ACurrentProps + APad +'  '+ Prop + CRLF;
        end;
    finally
      Mask.Free;
    end;
  end;

  procedure ReconsiderAfterRemovingRule(ARemoveRule: String; var ACurrentProps: String);
  var
    Line: TArrayOfStrings;
    Prop: String;
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
        if Mask.Matches(Line[0]) then
        begin
          Prop := TransformProperty(Line[0], Line[1], APad);
          if not Prop.IsEmpty then
            ACurrentProps := ACurrentProps + APad +'  '+ Prop + CRLF;
        end;
    finally
      Mask.Free;
    end;
  end;

var
  i: Integer;
  sProp: String;
begin
  Result := EmptyStr;

  for i := Low(F2DPropertyArray) to High(F2DPropertyArray) do
  begin
    if Length(F2DPropertyArray[i]) = 0 then
      Continue;
    if F2DPropertyArray[i, 1] = '<' then
      Result := Result + APad +'  '+ TransformProperty(F2DPropertyArray[i, 0], F2DPropertyArray[i, 1]) + CRLF + AddArrayOfItemProperties(i, APad +'  ') + CRLF
    else
    if (Length(F2DPropertyArray[i, 1]) > 0) and (F2DPropertyArray[i, 1][1] = '{') then
    begin
      sProp := TransformProperty(F2DPropertyArray[i, 0], F2DPropertyArray[i, 1], APad);
      if not sProp.IsEmpty then
        Result := Result + APad +'  '+ sProp + CRLF;
    end
    else
    if F2DPropertyArray[i, 0] <> EmptyStr then
    begin
      sProp := TransformProperty(F2DPropertyArray[i, 0], F2DPropertyArray[i, 1]);
      if not sProp.IsEmpty then
        Result := Result + APad +'  '+ sProp + CRLF;
    end;
  end;

  for i := 0 to Pred(IniDefaultValueProperties.Count) do
  begin
    sProp := FIniDefaultValueProperties.ValueFromIndex[i];
    if sProp.StartsWith('#CopyFromParent#') then
    begin
      CopyFromParent(Copy(sProp, Length('#CopyFromParent#') + 1), Result);
      Continue;
    end;
    if sProp.StartsWith('#CalcImageWrapMode#') then
    begin
      CalcImageWrapMode(APad, Result);
      Continue;
    end;
    if sProp.StartsWith('#CalcShapeClass#') then
    begin
      CalcShapeClass;
      Continue;
    end;
    if sProp.StartsWith('#ReconsiderAfterRemovingRule#') then
    begin
      ReconsiderAfterRemovingRule(Copy(sProp, Length('#ReconsiderAfterRemovingRule#') + 1), Result);
      Continue;
    end;
    Result := Result + APad + '  ' + StringReplace(sProp, '=', ' = ', []) + CRLF;
  end;

  for i := 0 to Pred(IniAddProperties.Count) do
    if (Pos(FIniAddProperties.Names[i], Result) > 0) then
    begin
      sProp := FIniAddProperties.ValueFromIndex[i];
      if sProp.StartsWith('#RemoveFromStyledSettings#') then
      begin
        HandleStyledSettings(Copy(sProp, Length('#RemoveFromStyledSettings#') + 1), Result);
        Continue;
      end;
      if (Pos(GetArrayFromString(sProp, '=')[0], Result) = 0) then
        Result := Result + APad + '  ' + StringReplace(sProp, '=', ' = ', []) + CRLF;
    end;
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

procedure TDfmToFmxObject.GenerateObject(AObjType, ACurrentName, ACurrentValue: string);

  procedure GenerateProperty(AObj: TDfmToFmxObject; APropName, APropValue: String);
  var
    PropLine, i: Integer;
  begin
    PropLine := -1;
    for i := 0 to High(AObj.F2DPropertyArray) do
      if (AObj.F2DPropertyArray[i] = nil) or (AObj.F2DPropertyArray[i, 0] = APropName) then
      begin
        PropLine := i;
        Break;
      end;

    if PropLine = -1 then
    begin
      PropLine := Length(AObj.F2DPropertyArray);
      AObj.PropertyArray(PropLine);
    end;

    if AObj.F2DPropertyArray[PropLine] = nil then
    begin
      SetLength(AObj.F2DPropertyArray[PropLine], 2);
      AObj.F2DPropertyArray[PropLine, 0] := APropName;
    end;

    AObj.F2DPropertyArray[PropLine, 1] := APropValue;
  end;

type
  TProp = record
    Name, Value: String;
  end;

  function GetObject(AObjName, ADFMClass: String; AInitProps: array of TProp): TDfmToFmxObject;
  var
    i: Integer;
  begin
    for i := 0 to Pred(OwnedObjs.Count) do
    begin
      if not FOwnedObjs[i].FGenerated then
        Break;
      if FOwnedObjs[i].FDFMClass = ADFMClass then
        Exit(FOwnedObjs[i]);
    end;

    Result := TDfmToFmxObject.CreateGenerated(Self, AObjName, ADFMClass, FDepth + 1);
    FOwnedObjs.Insert(0, Result);
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
begin
  if AObjType = 'ColoredRect' then
  begin
    Obj := GetObject(FObjName + '_Color', 'TShape', ColoredRectInitParams);

    if ACurrentName = 'Color' then
      GenerateProperty(Obj, 'Brush.Color', ACurrentValue)
    else
      GenerateProperty(Obj, ACurrentName, ACurrentValue);
  end;

  if AObjType = 'SeparateCaption' then
  begin
    Obj := GetObject(FObjName + '_Caption', 'TLabel', SeparateCaptionInitParams);

    if ACurrentName = 'ShowCaption' then
      GenerateProperty(Obj, 'Visible', ACurrentValue)
    else
    if ACurrentName = 'VerticalAlignment' then
    begin
      if ACurrentValue = 'taAlignBottom' then
        GenerateProperty(Obj, 'Layout', 'tlBottom'); //Center is default for panel and top - for label
    end
    else
      GenerateProperty(Obj, ACurrentName, ACurrentValue);
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
  UsesArray: TArrayOfStrings;
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
    UsesArray := GetArrayFromString(StringReplace(Copy(PreUsesString, StartPos, EndPos - StartPos), CRLF, '', [rfReplaceAll]), ',');
    PostUsesString := Copy(PreUsesString, EndPos);
    PostUsesString := ProcessCodeBody(PostUsesString);

    BindInsertPos := Pos(cBindSrc, PostUsesString) + cBindSrsLen;
    if BindInsertPos = cBindSrsLen then
    begin
      BindInsertPos := PosNoCase(FDFMClass, PostUsesString);
      BindInsertPos := Pos(')', PostUsesString, BindInsertPos);
    end;
    PostUsesString := Copy(PostUsesString, 1, BindInsertPos) + GetPASLiveBindings + Copy(PostUsesString, BindInsertPos + 1);

    SetLength(PreUsesString, Pred(StartPos) - cUsesLen);
    UsesString := ProcessUsesString(UsesArray);
  end;
  Result := PreUsesString + UsesString + PostUsesString;
end;

function TDfmToFmxObject.IniAddProperties: TStringlist;
begin
  if FIniAddProperties = nil then
    FIniAddProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  Result := FIniAddProperties;
end;

function TDfmToFmxObject.IniDefaultValueProperties: TStringlist;
begin
  if FIniDefaultValueProperties = nil then
    FIniDefaultValueProperties := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  Result := FIniDefaultValueProperties;
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
    AIni.ReadSectionValues('TForm', IniSectionValues);
    AIni.ReadSectionValues('TForm#Replace', IniReplaceValues);
    AIni.ReadSection('TForm#Include', IniIncludeValues);
  end
  else
  begin
    NewClassName := AIni.ReadString('ObjectChanges', FDFMClass, EmptyStr);
    if NewClassName <> EmptyStr then
    begin
      FOldDfmClass := FDFMClass;
      FDFMClass := NewClassName;
    end;
    AIni.ReadSectionValues(FDFMClass, IniSectionValues);
    AIni.ReadSectionValues(FDFMClass + '#Replace', IniReplaceValues);
    AIni.ReadSection(FDFMClass + '#Include', IniIncludeValues);
    AIni.ReadSectionValues(FDFMClass + '#AddIfPresent', IniAddProperties);
    AIni.ReadSectionValues(FDFMClass + '#DefaultValueProperty', IniDefaultValueProperties);

    LoadCommonProperties('*');
  end;

  Sections := TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  try
    FEnumList := TEnumList.Create([doOwnsValues]);

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

  for i := 0 to Pred(OwnedObjs.Count) do
    FOwnedObjs[i].IniFileLoad(AIni);

  if FOwnedItems <> nil then
    for i := 0 to Pred(fOwnedItems.Count) do
      fOwnedItems[i].IniFileLoad(AIni);
end;

function TDfmToFmxObject.IniIncludeValues: TStringlist;
begin
  if FIniIncludeValues = nil then
    FIniIncludeValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  Result := FIniIncludeValues;
end;

function TDfmToFmxObject.IniReplaceValues: TStringlist;
begin
  if FIniReplaceValues = nil then
    FIniReplaceValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  Result := FIniReplaceValues;
end;

function TDfmToFmxObject.IniSectionValues: TStringlist;
begin
  if FIniSectionValues = nil then
    FIniSectionValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  Result := FIniSectionValues;
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

    Insert(CRLF + '    ' + FObjName + ': ' + FDFMClass + ';', ABody, LineEnd);
  end
  else
    if FOldDfmClass <> '' then
    begin
      NameStart := PosNoCase(FObjName, ABody);
      ClassStart := PosNoCase(FOldDfmClass, ABody, NameStart);
      ABody := Copy(ABody, 1, NameStart + Length(FObjName) - 1) + ': ' + FDFMClass + Copy(ABody, ClassStart + Length(FOldDfmClass));
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
        (IniSectionValues.IndexOfName(CommonProps.Names[i]) = -1) then
      begin
        Found := False;
        CommonPropMask := TMask.Create(CommonProps.Names[i]);
        try
          for j := 0 to Pred(IniSectionValues.Count) do
            if CommonPropMask.Matches(IniSectionValues.Names[j]) then
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

    for i := 0 to Pred(IniSectionValues.Count) do
    begin
      ExistingPropMask := TMask.Create(IniSectionValues.Names[i]);
      try
        for j := Pred(Candidates.Count) downto 0 do
          if ExistingPropMask.Matches(Candidates.Names[j]) then
            Candidates.Delete(j);
      finally
        ExistingPropMask.Free;
      end;
    end;

    for i := 0 to Pred(Candidates.Count) do
      IniSectionValues.Add(Candidates[i]);

    CommonProps.Clear;
    FIni.ReadSectionValues('CommonProperties#AddIfPresent', CommonProps);
    for i := 0 to Pred(CommonProps.Count) do
      if IniAddProperties.IndexOfName(CommonProps.Names[i]) = -1 then
        IniAddProperties.Add(CommonProps[i]);
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

function TDfmToFmxObject.OwnedObjs: TOwnedObjects;
begin
  if FOwnedObjs = nil then
    FOwnedObjs := TOwnedObjects.Create({AOwnsObjects} True);
  Result := FOwnedObjs;
end;

function TDfmToFmxObject.ProcessCodeBody(const ACodeBody: String): String;
var
  BdyStr: String;
begin
  BdyStr := StringReplace(ACodeBody, '{$R *.DFM}', '{$R *.FMX}', [rfIgnoreCase]);

  InternalProcessBody(BdyStr);

  Result := BdyStr;
end;

function TDfmToFmxObject.ProcessUsesString(AOrigUsesArray: TArrayOfStrings): String;
var
  i, LineLen: integer;
begin
  PopulateStringsFromArray(UsesTranslation, AOrigUsesArray);
  UpdateUsesStringList(UsesTranslation);
  Result := 'uses'#13#10'  ';
  LineLen := 2;
  for i := 0 to Pred(UsesTranslation.Count) do
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

function TDfmToFmxObject.PropertyArray(ARow: integer): TArrayOfStrings;
begin
  while ARow >= FPropertyArraySz do
  begin
    inc(FPropertyArraySz, 5);
    SetLength(F2DPropertyArray, FPropertyArraySz);
  end;
  if ARow > FPropertyMax then
    FPropertyMax := ARow;
  Result := F2DPropertyArray[ARow];
end;

{ Eduardo }
procedure TDfmToFmxObject.ReadItems(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStreamReader);
var
  Data: String;
  saTemp: Array of String;
  sTemp: String;
begin
  Data := Trim(AStm.ReadLine);
  while not EndsText('>', Data) do
  begin
    SetLength(saTemp, Succ(Length(saTemp)));
    saTemp[Pred(Length(saTemp))] := Data;
    Data := Trim(AStm.ReadLine);
  end;
  SetLength(saTemp, Succ(Length(saTemp)));
  saTemp[Pred(Length(saTemp))] := Data;
  
  for sTemp in saTemp do
    Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + #13 + sTemp;
end;

{ Eduardo }
procedure TDfmToFmxObject.ReadData(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStreamReader);
var
  Data: String;
begin
  Data := Trim(AStm.ReadLine);
  while not EndsText('}', Data) do
  begin
    Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
    Data := Trim(AStm.ReadLine);
  end;
  Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
end;

{ Eduardo }
procedure TDfmToFmxObject.ReadText(Prop: TTwoDArrayOfString; APropertyIdx: integer; AStm: TStreamReader);
var
  Data: String;
begin
  Data := Trim(AStm.ReadLine);
  while EndsText('+', Data) do
  begin
    Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
    Data := Trim(AStm.ReadLine);
  end;
  Prop[APropertyIdx, 1] := Prop[APropertyIdx, 1] + Data;
end;

procedure TDfmToFmxObject.ReadProperties(AData: String; AStm: TStreamReader; var AIdx: Integer);
begin
  PropertyArray(AIdx);
  F2DPropertyArray[AIdx] := GetArrayFromString(AData, '=');
  if High(F2DPropertyArray[AIdx]) < 1 then
  begin
    SetLength(F2DPropertyArray[AIdx], 2);
    F2DPropertyArray[AIdx, 0] := ContinueCode;
    F2DPropertyArray[AIdx, 1] := AData;
  end
  else
  if (F2DPropertyArray[AIdx,1] = '<') then
    ReadItems(F2DPropertyArray, AIdx, AStm)
  else
  if (F2DPropertyArray[AIdx,1] = '{') then
    ReadData(F2DPropertyArray, AIdx, AStm)
  else
  if (F2DPropertyArray[AIdx,1] = '') then
    ReadText(F2DPropertyArray, AIdx, AStm);
  Inc(AIdx);
end;

function TDfmToFmxObject.TransformProperty(ACurrentName, ACurrentValue: String; APad: String = ''): String;
var
  s, GenObjectType: String;
  Mask: TMask;
  DefaultValuePropPos: Integer;

  function ReplaceEnum(var ReplacementLine: String): Boolean;
  var
    EnumNameStart, EnumNameEnd, Item, FontSize: Integer;
    EnumName, PropName, Value: String;
    EnumItems: TStringList;
  begin
    Result := False;
    EnumNameStart := Pos('#', s);
    if EnumNameStart = 0 then
      Exit;

    if EnumNameStart > 1 then
      PropName := Trim(Copy(s, 1, EnumNameStart - 1))
    else
      PropName := ACurrentName;

    EnumNameEnd := Pos('#', s, EnumNameStart + 1);
    if EnumNameEnd = 0 then
      Exit;

    EnumName := Copy(s, EnumNameStart, EnumNameEnd - EnumNameStart + 1);

    if EnumName = '#SetValue#' then
    begin
      Value := Copy(s, EnumNameEnd + 1);
      ReplacementLine := PropName + ' = ' + Value;
      Exit(True);
    end;

    if EnumName = '#ConvertFontSize#' then
    begin
      FontSize := Abs(StrToInt(ACurrentValue));
      ReplacementLine := PropName + ' = ' + IntToStr(FontSize);
      Exit(True);
    end;

    if (EnumName = '') then
      Exit;
    if not FEnumList.TryGetValue(EnumName, EnumItems) then
      raise Exception.Create('Required enum ' + EnumName + ' not found');

    Item := EnumItems.IndexOfName(ACurrentValue);
    if Item >= 0 then
      Value := EnumItems.ValueFromIndex[Item]
    else
    begin
      Item := EnumItems.IndexOfName('#UnknownValuesAllowed#');
      if Item < 0 then
        raise Exception.Create('Unknown item ' + ACurrentValue + ' in enum ' + EnumName)
      else
      begin
        if EnumItems.ValueFromIndex[Item] = '#GenerateColorValue#' then
          Value := ConvertColor(StrToUInt(ACurrentValue))
        else
          Value := ACurrentValue;
      end;
    end;

    if Value = '#GenerateColorValue#' then
      Value := ConvertColor(ColorToRGB(StringToColor(ACurrentValue)));

    if Value.StartsWith('#SetProperty#', {IgnoreCase} True) then
    begin
      ReplacementLine := Copy(Value, Length('#SetProperty#') + 1).Replace('=', ' = ', []);
      Exit(True);
    end;

    ReplacementLine := PropName + ' = ' + Value;
    Result := True;
  end;

begin
  if ACurrentName = ContinueCode then
    Result := '  ' + ACurrentValue
  else
  begin
    s := Trim(FIniSectionValues.Values[ACurrentName]);
    if s = EmptyStr then
      for var i := 0 to Pred(FIniSectionValues.Count) do
      begin
        Mask := TMask.Create(FIniSectionValues.Names[i]);
        try
          if Mask.Matches(ACurrentName) then
          begin
            s := FIniSectionValues.ValueFromIndex[i];
            Break;
          end;
        finally
          Mask.Free;
        end;
      end;
    if s = EmptyStr then
      s := ACurrentName;
    if s = '#Delete#' then
      Result := EmptyStr
    else
    if s = '#Class#' then
    begin
      if FDFMClass = 'TImage' then
        Result := StringReplace(s, '#Class#', ProcessImage(ACurrentValue, APad), [])
      else
      if FDFMClass = 'TImageList' then
        Result := StringReplace(s, '#Class#', ProcessImageList(ACurrentValue, APad), [])
    end
    else
    if s.StartsWith('#GenerateControl#') then
    begin
      GenObjectType := Copy(s, Length('#GenerateControl#') + 1);
      GenerateObject(GenObjectType, ACurrentName, ACurrentValue);
      Result := EmptyStr;
    end
    else
    if not ReplaceEnum(Result) then
      Result := s +' = '+ ACurrentValue;

    if IniDefaultValueProperties.Count > 0 then
    begin
      DefaultValuePropPos := FIniDefaultValueProperties.IndexOfName(ACurrentName);
      if DefaultValuePropPos >= 0 then
        FIniDefaultValueProperties.Delete(DefaultValuePropPos)
      else
        for var i := 0 to Pred(FIniDefaultValueProperties.Count) do
        begin
          Mask := TMask.Create(FIniDefaultValueProperties.Names[i]);
          try
            if Mask.Matches(ACurrentName) then
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

function TDfmToFmxObject.UsesTranslation: TStringlist;
begin
  if FUsesTranslation = nil then
    FUsesTranslation := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  Result := FUsesTranslation;
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

{ TDfmToFmxListItem }

constructor TDfmToFmxListItem.Create(AOwner: TDfmToFmxObject; APropertyIdx: integer; AStm: TStreamReader; ADepth: integer);
var
  Data: String;
  i,LoopCount: integer;
begin
  FPropertyIndex := APropertyIdx;
  FOwner := AOwner;
  i := 0;
  FDepth := ADepth;
  Data   := EmptyStr;
  LoopCount := 55;
  while (LoopCount > 0) and (Pos('end',Data) <> 1)  do
  Begin
    Dec(LoopCount);
    if Pos('object', Data) = 1 then
      OwnedObjs.Add(TDfmToFmxObject.Create(Self, Data, AStm, FDepth + 1))
    else
      ReadProperties(Data,AStm,i);
    Data := Trim(AStm.ReadLine);
    if (Data <> EmptyStr) then
      LoopCount := 55;
  end;
  SetLength(F2DPropertyArray, FPropertyMax + 1);
  FHasMore := (Pos('end',Data)=1) and not (Pos('end>',Data) = 1);
end;

end.
