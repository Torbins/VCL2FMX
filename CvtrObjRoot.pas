unit CvtrObjRoot;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.StrUtils, Winapi.Windows, System.IniFiles, FMX.Objects,
  System.Generics.Collections, PatchLib, CvtrObject;

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

  TDfmToFmxObjRoot = class(TDfmToFmxObject, IDfmToFmxRoot)
  protected
    FLinkControlList: TArray<TLinkControl>;
    FLinkGridList: TArray<TLinkGrid>;
    FIniReplaceValues: TStringlist;
    FIniFile: TMemIniFile;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    procedure AddFieldLink(AObjName: String; AProp: TDfmPropertyBase);
    function GetIniFile: TMemIniFile;
    procedure InitObjects; override;
    procedure UpdateUsesStringList(AUsesList: TStrings); override;
    function ProcessUsesString(AOrigUsesArray: TArray<String>): String;
    function ProcessCodeBody(const ACodeBody: String): String;
    function GetFMXLiveBindings: String;
    function GetPASLiveBindings: String;
  public
    constructor CreateRoot(const AIniConfigFile, ACreateText: String; AStm: TStreamReader);
    destructor Destroy; override;
    procedure IniFileLoad; override;
    class function DFMIsTextBased(ADfmFileName: String): Boolean;
    function GenPasFile(const APascalSourceFileName: String): String;
    function FMXFile(APad: String = ''): String; override;
    function WriteFMXToFile(const AFmxFileName: String): Boolean;
    function WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
    procedure LiveBindings(DfmObject: TOwnedObjects = nil);
  end;

implementation

{ DfmToFmxObject }

{ Eduardo }
procedure TDfmToFmxObjRoot.LiveBindings(DfmObject: TOwnedObjects = nil);
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
//    if obj.FClassName.Equals('TDBGrid') then
    begin
      // Inicializa
      sFields := EmptyStr;

      // Cria um novo item na lista de grids
//      SetLength(FLinkGridList, Succ(Length(FLinkGridList)));

      // Insere o nome da grid
//      FLinkGridList[Pred(Length(FLinkGridList))].GridControl := obj.FObjName;

      // Passa por todas propriedades da grid
//      for J := 0 to obj.FDfmProps.Count - 1 do
//      begin
//        // Obtem os dados do DataSource
//        if obj.FDfmProps[J].Name = 'DataSource' then
//          FLinkGridList[Pred(Length(FLinkGridList))].DataSource := obj.FDfmProps[J].Value;
//
//        // Se for as colunas
//        if obj.FDfmProps[J].Name = 'Columns' then
//        begin
//          // Obtem os dados dos fields
//          sFields := obj.FDfmProps[J].Value;
//
//          slItem := SplitString(sFields, #13);
//          for sItem in slItem do
//          begin
//            if sItem = 'item' then
//              SetLength(FLinkGridList[Pred(Length(FLinkGridList))].Columns, Succ(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns)))
//            else
//            if Trim(SplitString(sItem, '=')[0]) = 'Title.Caption' then
//              FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].Caption := Trim(SplitString(sItem, '=')[1])
//            else
//            if Trim(SplitString(sItem, '=')[0]) = 'FieldName' then
//              FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].FieldName := Trim(SplitString(sItem, '=')[1])
//            else
//            if Trim(SplitString(sItem, '=')[0]) = 'Width' then
//              FLinkGridList[Pred(Length(FLinkGridList))].Columns[Pred(Length(FLinkGridList[Pred(Length(FLinkGridList))].Columns))].Width := Trim(SplitString(sItem, '=')[1]);
//          end;
//        end;
//
//        // Se ja encontrou tudo, sai do loop
//        if not FLinkGridList[Pred(Length(FLinkGridList))].DataSource.IsEmpty and not sFields.IsEmpty then
//          Break;
//      end;
    end;

    // Se o componente atual possui componentes nele, faz recursão
//    if Assigned(obj.FOwnedObjs) and (obj.FOwnedObjs.Count > 0) then
//      LiveBindings(obj.FOwnedObjs);
  end;
end;

{ Eduardo }
function TDfmToFmxObjRoot.GetFMXLiveBindings: String;
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

function TDfmToFmxObjRoot.GetIniFile: TMemIniFile;
begin
  Result := FIniFile;
end;

{ Eduardo }
function TDfmToFmxObjRoot.GetPASLiveBindings: String;
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

procedure TDfmToFmxObjRoot.AddFieldLink(AObjName: String; AProp: TDfmPropertyBase);
var
  i, Len: Integer;
  CurrentLink: ^TLinkControl;
begin
  CurrentLink := nil;

  for i := 0 to High(FLinkControlList) do
    if FLinkControlList[i].Control = AObjName then
    begin
      CurrentLink := @(FLinkControlList[i]);
      Break;
    end;

  if not Assigned(CurrentLink) then
  begin
    Len := Length(FLinkControlList);
    SetLength(FLinkControlList, Len + 1);
    CurrentLink := @(FLinkControlList[Len]);
    CurrentLink.Control := AObjName;
  end;

  if AProp.Name = 'DataField' then
    CurrentLink.FieldName := AProp.Value;

  if AProp.Name = 'DataSource' then
    CurrentLink.DataSource := AProp.Value;
end;

constructor TDfmToFmxObjRoot.CreateRoot(const AIniConfigFile, ACreateText: String; AStm: TStreamReader);
begin
  FRoot := Self;
  FIniFile := TMemIniFile.Create(AIniConfigFile);
  Create(nil, ACreateText, AStm);
end;

destructor TDfmToFmxObjRoot.Destroy;
begin
  FIniReplaceValues.Free;
  FIniFile.Free;
  inherited;
end;

class function TDfmToFmxObjRoot.DFMIsTextBased(ADfmFileName: String): Boolean;
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

function TDfmToFmxObjRoot.FMXFile(APad: String = ''): String;
var
  LB: String;
begin
  Result := inherited;
  Result := Result.Substring(0, Result.Length - 5);
  LB := GetFMXLiveBindings;
  if LB <> '' then
    Result := Result + LB + CRLF;
  Result := Result + APad +'end' + CRLF;
end;

function TDfmToFmxObjRoot.GenPasFile(const APascalSourceFileName: String): String;
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

procedure TDfmToFmxObjRoot.IniFileLoad;
begin
  FRoot.IniFile.ReadSectionValues('TForm', FIniSectionValues);
  FRoot.IniFile.ReadSectionValues('TForm#Replace', FIniReplaceValues);
  FRoot.IniFile.ReadSection('TForm#Include', FIniIncludeValues);

  LoadEnums;
end;

procedure TDfmToFmxObjRoot.InitObjects;
begin
  inherited;
  FIniReplaceValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
end;

function TDfmToFmxObjRoot.ProcessCodeBody(const ACodeBody: String): String;
var
  BdyStr: String;
begin
  BdyStr := StringReplace(ACodeBody, '{$R *.DFM}', '{$R *.FMX}', [rfIgnoreCase]);

  InternalProcessBody(BdyStr);

  Result := BdyStr;
end;

function TDfmToFmxObjRoot.ProcessUsesString(AOrigUsesArray: TArray<String>): String;
var
  i, LineLen: integer;
  UsesList: TStringlist;
begin
  UsesList := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  try
    PopulateStringsFromArray(UsesList, AOrigUsesArray);
    UpdateUsesStringList(UsesList);
    Result := 'uses'#13#10'  ';
    LineLen := 2;
    for i := 0 to Pred(UsesList.Count) do
      if Trim(UsesList[i]) <> EmptyStr then
      begin
        LineLen := LineLen + Length(UsesList[i]) + 2;
        if LineLen > 80 then
        begin
          Result := Result + #13#10'  ';
          LineLen := 2 + Length(UsesList[i]) + 2;
        end;
        Result := Result + UsesList[i] + ', ';
      end;
    SetLength(Result, Length(Result) - 2);
  finally
    UsesList.Free;
  end;
end;

function TDfmToFmxObjRoot.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

procedure TDfmToFmxObjRoot.UpdateUsesStringList(AUsesList: TStrings);
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

  inherited;
end;

function TDfmToFmxObjRoot.WriteFMXToFile(const AFmxFileName: String): Boolean;
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

function TDfmToFmxObjRoot.WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
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

function TDfmToFmxObjRoot._AddRef: Integer;
begin
  Result := -1;
end;

function TDfmToFmxObjRoot._Release: Integer;
begin
  Result := -1;
end;

end.
