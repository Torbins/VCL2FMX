unit CvtrObjRoot;

interface

uses
  System.Classes, System.Types, System.SysUtils, Winapi.Windows, System.IniFiles, FMX.Objects,
  System.Generics.Collections, Vcl.Imaging.PngImage, PatchLib, CvtrObject, CvtrProp;

type
  TLinkControl = class
    DataSource: String;
    FieldName: String;
    Control: String;
  end;
  TLinkControlList = class(TObjectList<TLinkControl>);

  TLinkGrid = class
    DataSource: String;
    GridControl: String;
    Columns: TFmxProperty;
    destructor Destroy; override;
  end;
  TLinkGridList = class(TObjectList<TLinkGrid>);

  TDfmToFmxObjRoot = class(TDfmToFmxObject, IDfmToFmxRoot)
  protected
    FLinkControlList: TLinkControlList;
    FLinkGridList: TLinkGridList;
    FImageList: TImageList;
    FIniReplaceValues: TStringlist;
    FIniFile: TMemIniFile;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    procedure AddFieldLink(AObjName: String; AProp: TDfmProperty);
    procedure AddGridLink(AObjName: String; AProp: TDfmProperty);
    procedure AddGridColumns(AObjName: String; AProp: TFmxProperty);
    function AddImageItem(APng: TPngImage): Integer;
    procedure PushProgress;
    function GetIniFile: TMemIniFile;
    procedure InitObjects; override;
    procedure UpdateUsesStringList(AUsesList: TStrings); override;
    function ProcessUsesString(AOrigUsesArray: TArray<String>): String;
    function ProcessCodeBody(const ACodeBody: String): String;
    function GetFMXSingletons: String;
    function GetPASSingletons: String;
  public
    OnProgress: TNotifyEvent;
    constructor CreateRoot(const AIniConfigFile, ACreateText: String; AStm: TStreamReader);
    destructor Destroy; override;
    procedure IniFileLoad; override;
    class function DFMIsTextBased(ADfmFileName: String): Boolean;
    function GenPasFile(const APascalSourceFileName: String): String;
    function FMXFile(APad: String = ''): String; override;
    function WriteFMXToFile(const AFmxFileName: String): Boolean;
    function WritePasToFile(const APasOutFileName, APascalSourceFileName: String): Boolean;
  end;

implementation

uses
  ImageList;

function TDfmToFmxObjRoot.GetFMXSingletons: String;
var
  I: Integer;
begin
  Result := '';
  if FImageList.Count > 0 then
  begin
    Result := '  object SingletoneImageList: TImageList' + CRLF;
    Result := Result + EncodeImageList(FImageList, '  ') + CRLF;
    Result := Result + '    Left = 40' + CRLF + '    Top = 5' + CRLF + '  end' + CRLF;
  end;

  if (FLinkControlList.Count = 0) and (FLinkGridList.Count = 0) then
    Exit(Result.TrimRight([CR, LF]));

  Result := Result + '  object SingletoneBindingsList: TBindingsList' +
    CRLF + '    Methods = <>' +
    CRLF + '    OutputConverters = <>' +
    CRLF + '    Left = 20' +
    CRLF + '    Top = 5';

  for I := 0 to FLinkControlList.Count - 1 do
    if (FLinkControlList[I].DataSource <> '') and (FLinkControlList[I].FieldName <> '') and
      (FLinkControlList[I].Control <> '') then
    begin
      Result := Result +
        CRLF + '    object LinkControlToField' + I.ToString + ': TLinkControlToField' +
        CRLF + '      Category = ''Quick Bindings''' +
        CRLF + '      DataSource = ' + FLinkControlList[I].DataSource +
        CRLF + '      FieldName = ' + FLinkControlList[I].FieldName +
        CRLF + '      Control = ' + FLinkControlList[I].Control +
        CRLF + '      Track = False' +
        CRLF + '    end';
    end
    else
      raise Exception.Create('Binding incomplete for control ' + FLinkControlList[I].Control + ', datasource ' +
        FLinkControlList[I].DataSource + ' and field ' + FLinkControlList[I].FieldName);

  for I := 0 to FLinkGridList.Count - 1 do
    if (FLinkGridList[I].DataSource <> '') and (FLinkGridList[I].GridControl <> '') then
    begin
      Result := Result +
        CRLF + '    object LinkGridToDataSourceBindSourceDB' + I.ToString + ': TLinkGridToDataSource' +
        CRLF + '      Category = ''Quick Bindings''' +
        CRLF + '      DataSource = ' + FLinkGridList[I].DataSource +
        CRLF + '      GridControl = ' + FLinkGridList[I].GridControl + CRLF;

      if Assigned(FLinkGridList[I].Columns) then
        Result := Result + FLinkGridList[I].Columns.ToString('    ') + '    end'
      else
        Result := Result + '    end';
    end
    else
      raise Exception.Create('Binding incomplete for grid ' + FLinkGridList[I].GridControl + ' and datasource ' +
        FLinkGridList[I].DataSource);

  Result := Result + CRLF + '  end';
end;

function TDfmToFmxObjRoot.GetIniFile: TMemIniFile;
begin
  Result := FIniFile;
end;

function TDfmToFmxObjRoot.GetPASSingletons: String;
var
  I: Integer;
begin
  Result := '';
  if FImageList.Count > 0 then
  begin
    Result := CRLF + '    SingletoneImageList: TImageList;';
  end;

  if (FLinkControlList.Count = 0) and (FLinkGridList.Count = 0) then
    Exit;

  Result := Result + CRLF + '    SingletoneBindingsList: TBindingsList;';

  for I := 0 to FLinkControlList.Count - 1 do
    if (FLinkControlList[I].DataSource <> '') and (FLinkControlList[I].FieldName <> '') and
      (FLinkControlList[I].Control <> '') then
      Result := Result + CRLF + '    LinkControlToField' + I.ToString + ': TLinkControlToField;';

  for I := 0 to FLinkGridList.Count - 1 do
    if (FLinkGridList[I].DataSource <> '') and (FLinkGridList[I].GridControl <> '') then
      Result := Result + CRLF + '    LinkGridToDataSourceBindSourceDB' + I.ToString + ': TLinkGridToDataSource;';
end;

procedure TDfmToFmxObjRoot.AddFieldLink(AObjName: String; AProp: TDfmProperty);
var
  i: Integer;
  CurrentLink: TLinkControl;
begin
  CurrentLink := nil;

  for i := 0 to FLinkControlList.Count - 1 do
    if FLinkControlList[i].Control = AObjName then
    begin
      CurrentLink := FLinkControlList[i];
      Break;
    end;

  if not Assigned(CurrentLink) then
  begin
    CurrentLink := TLinkControl.Create;
    CurrentLink.Control := AObjName;
    FLinkControlList.Add(CurrentLink);
  end;

  if AProp.Name = 'DataField' then
    CurrentLink.FieldName := AProp.Value;

  if AProp.Name = 'DataSource' then
    CurrentLink.DataSource := AProp.Value;
end;

procedure TDfmToFmxObjRoot.AddGridColumns(AObjName: String; AProp: TFmxProperty);
var
  i: Integer;
  CurrentLink: TLinkGrid;
begin
  CurrentLink := nil;

  for i := 0 to FLinkGridList.Count - 1 do
    if FLinkGridList[i].GridControl = AObjName then
    begin
      CurrentLink := FLinkGridList[i];
      Break;
    end;

  if not Assigned(CurrentLink) then
    raise Exception.Create('Grid ' + AObjName + ' not found in the list');

  CurrentLink.Columns := AProp;
end;

procedure TDfmToFmxObjRoot.AddGridLink(AObjName: String; AProp: TDfmProperty);
var
  Link: TLinkGrid;
begin
  Link := TLinkGrid.Create;
  Link.GridControl := AObjName;
  Link.DataSource := AProp.Value;

  FLinkGridList.Add(Link);
end;

function TDfmToFmxObjRoot.AddImageItem(APng: TPngImage): Integer;
begin
  Result := FImageList.Add(APng);
end;

constructor TDfmToFmxObjRoot.CreateRoot(const AIniConfigFile, ACreateText: String; AStm: TStreamReader);
begin
  FRoot := Self;
  FIniFile := TMemIniFile.Create(AIniConfigFile);
  Create(nil, ACreateText, AStm);
end;

destructor TDfmToFmxObjRoot.Destroy;
begin
  FLinkControlList.Free;
  FLinkGridList.Free;
  FImageList.Free;
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
  LB := GetFMXSingletons;
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

    BindInsertPos := PosNoCase(cBindSrc, PostUsesString) + cBindSrsLen;
    if BindInsertPos = cBindSrsLen then
    begin
      BindInsertPos := PosNoCase(FClassName, PostUsesString);
      BindInsertPos := Pos(')', PostUsesString, BindInsertPos) + 1;
    end;
    PostUsesString := Copy(PostUsesString, 1, BindInsertPos - 1) + GetPASSingletons +
      Copy(PostUsesString, BindInsertPos);

    SetLength(PreUsesString, Pred(StartPos) - cUsesLen);
    UsesString := ProcessUsesString(UsesArray);
  end;
  Result := PreUsesString + UsesString + PostUsesString;
end;

procedure TDfmToFmxObjRoot.IniFileLoad;
begin
  FIniFile.ReadSectionValues('TForm', FIniSectionValues);
  FIniFile.ReadSectionValues('TForm#Replace', FIniReplaceValues);
  FIniFile.ReadSection('TForm#Include', FIniIncludeValues);
  FIniFile.ReadSectionValues('TForm#AddIfPresent', FIniAddProperties);
  FIniFile.ReadSectionValues('TForm#DefaultValueProperty', FIniDefaultValueProperties);
end;

procedure TDfmToFmxObjRoot.InitObjects;
begin
  inherited;
  FImageList := TImageList.Create;
  FIniReplaceValues := TStringlist.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  FLinkControlList := TLinkControlList.Create;
  FLinkGridList := TLinkGridList.Create;
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
    Result := 'uses' + CRLF + '  ';
    LineLen := 2;
    for i := 0 to Pred(UsesList.Count) do
      if Trim(UsesList[i]) <> EmptyStr then
      begin
        LineLen := LineLen + Length(UsesList[i]) + 2;
        if LineLen > 80 then
        begin
          Result := Result + CRLF + '  ';
          LineLen := 2 + Length(UsesList[i]) + 2;
        end;
        Result := Result + UsesList[i] + ', ';
      end;
    SetLength(Result, Length(Result) - 2);
  finally
    UsesList.Free;
  end;
end;

procedure TDfmToFmxObjRoot.PushProgress;
begin
  if Assigned(OnProgress) then
    OnProgress(Self);
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

{ TLinkGrid }

destructor TLinkGrid.Destroy;
begin
  Columns.Free;
  inherited;
end;

end.
