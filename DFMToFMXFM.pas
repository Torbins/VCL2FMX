unit DFMToFMXFM;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, System.Win.Registry, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Layouts, FMX.Memo, CvtrObjRoot, FMX.StdCtrls, FMX.ScrollBox,
  FMX.Controls.Presentation, FMX.Objects, FMX.Memo.Types;

type
  TDFMtoFMXConvert = class(TForm)
    BtnOpenFile: TButton;
    mmOutput: TMemo;
    BtnProcess: TButton;
    btnConfiguration: TButton;
    BtnSaveFMX: TButton;
    mmInput: TMemo;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    procedure BtnOpenFileClick(Sender: TObject);
    procedure BtnProcessClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BtnSaveFMXClick(Sender: TObject);
    procedure btnConfigurationClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    DFMObj: TDfmToFmxObjRoot;
    FIniFileName: String;
    FInPasFileName: String;
    FInDfmFileName: String;
    FOutPasFileName: String;
    FOutFmxFileName: String;
    function GetRegFile: TRegistryIniFile;
    Procedure RegIniLoad;
    Procedure RegIniSave;
    Procedure UpdateForm;
    procedure SaveFiles;
  end;

var
  DFMtoFMXConvert: TDFMtoFMXConvert;

implementation

{$R *.fmx}

uses
  FMX.DialogService, PatchLib, CONFIGINI;

procedure TDFMtoFMXConvert.btnConfigurationClick(Sender: TObject);
begin
  TINI.Create(Self).ShowModal;
  RegIniLoad;
end;

procedure TDFMtoFMXConvert.BtnOpenFileClick(Sender: TObject);
begin
  BtnProcess.Enabled := False;
  FreeAndNil(DFMObj);
  if FInDfmFileName <> EmptyStr then
    dlgOpen.InitialDir := ExtractFileDir(FInDfmFileName);
  if dlgOpen.Execute then
  begin
    FInPasFileName := ChangeFileExt(dlgOpen.FileName, '.pas');
    FInDfmFileName := ChangeFileExt(FInPasFileName, '.dfm');
    if FileExists(FInDfmFileName) then
    begin
      if TDfmToFmxObjRoot.DFMIsTextBased(FInDfmFileName) then
      begin
        mmInput.Lines.Clear;
        mmInput.Lines.LoadFromFile(FInDfmFileName);
        BtnProcess.Enabled := True;
      end
      else
        raise Exception.Create('Incompatible dfm file:' + FInDfmFileName);
    end;
  end;
  UpdateForm;
end;

procedure TDFMtoFMXConvert.BtnProcessClick(Sender: TObject);
var
  Data: String;
  Stm: TStreamReader;
begin
  if mmInput.Text <> EmptyStr then
  begin
    FreeAndNil(DFMObj);
    Data := mmInput.Text;
    Stm := TStreamReader.Create(FInDfmFileName);
    try
      Data := Trim(Stm.ReadLine);
      if Pos('object', Data) = 1 then
        DFMObj := TDfmToFmxObjRoot.CreateRoot(FIniFileName, Data, Stm);
    finally
      Stm.Free;
    end;
  end;

  mmOutput.Text := DFMObj.FMXFile;
  BtnProcess.Enabled := False;
  UpdateForm;
end;

procedure TDFMtoFMXConvert.BtnSaveFMXClick(Sender: TObject);
begin
  if DFMObj = nil then
    UpdateForm
  else
  begin
    FOutPasFileName := ExtractFilePath(FOutPasFileName) + ChangeFileExt(ExtractFileName(FInDfmFileName), 'FMX.pas');

    if not FOutPasFileName.IsEmpty then
    begin
      dlgSave.InitialDir := ExtractFileDir(FOutPasFileName);
      dlgSave.FileName   := ExtractFileName(ChangeFileExt(FOutPasFileName, '.fmx'));
    end;

    if dlgSave.Execute then
    begin
      FOutPasFileName := ChangeFileExt(dlgSave.FileName, '.pas');
      FOutFmxFileName := ChangeFileExt(FOutPasFileName, '.fmx');

      if FileExists(FOutFmxFileName) or FileExists(FOutPasFileName) then
        TDialogService.MessageDialog(
          'Replace Existing Files: '+ FOutFmxFileName +' and/or '+ FOutPasFileName,
          TMsgDlgType.mtWarning,
          [TMsgDlgBtn.mbOK, TMsgDlgBtn.mbCancel],
          TMsgDlgBtn.mbOK, 0, procedure (const AResult: TModalResult)
        begin
          if AResult = mrOk then
          begin
            DeleteFile(FOutFmxFileName);
            DeleteFile(FOutPasFileName);
          end;

          SaveFiles;
        end)
        else
          SaveFiles;
    end;
  end;
end;

procedure TDFMtoFMXConvert.SaveFiles;
begin
  if FileExists(FOutFmxFileName) then
    raise Exception.Create(FOutFmxFileName + 'Already exists');

  DFMObj.WriteFMXToFile(FOutFmxFileName);

  if FileExists(FOutPasFileName) then
    raise Exception.Create(FOutPasFileName + 'Already exists');

  DFMObj.WritePasToFile(FOutPasFileName, FInPasFileName);
end;

procedure TDFMtoFMXConvert.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FreeAndNil(DFMObj);
  RegIniSave;
end;

procedure TDFMtoFMXConvert.FormCreate(Sender: TObject);
begin
  RegIniLoad;
  if not FileExists(FIniFileName) then
    FIniFileName := ChangeFileExt(ParamStr(0), '.ini');
  UpdateForm;
end;

function TDFMtoFMXConvert.GetRegFile: TRegistryIniFile;
begin
  Result := TRegistryIniFile.Create('DFMtoFMXConvertor');
end;

procedure TDFMtoFMXConvert.RegIniLoad;
var
  RegFile: TRegistryIniFile;
begin
  RegFile := GetRegFile;
  try
    FIniFileName    := RegFile.ReadString('Files', 'Inifile',   EmptyStr);
    FInDfmFileName  := RegFile.ReadString('Files', 'Inputdfm',  EmptyStr);
    FOutPasFileName := RegFile.ReadString('Files', 'Outputpas', EmptyStr);
    if FInDfmFileName <> EmptyStr then
      FInPasFileName := ChangeFileExt(FInDfmFileName, '.pas');
    if FOutPasFileName <> EmptyStr then
    begin
      FOutFmxFileName := ChangeFileExt(FOutPasFileName, '.fmx');
      dlgOpen.InitialDir := ExtractFileDir(FOutPasFileName);
    end;
    if FileExists(FInDfmFileName) and TDfmToFmxObjRoot.DFMIsTextBased(FInDfmFileName) then
    begin
      mmInput.Lines.Clear;
      mmInput.Lines.LoadFromFile(FInDfmFileName);
    end;
  finally
    RegFile.Free;
  end;
end;

procedure TDFMtoFMXConvert.RegIniSave;
var
  RegFile: TRegistryIniFile;
begin
  RegFile := GetRegFile;
  try
    RegFile.WriteString('Files', 'InputDFm', FInDfmFileName);
    RegFile.WriteString('Files', 'OutputPas', FOutPasFileName);
  finally
    RegFile.Free;
  end;
end;

procedure TDFMtoFMXConvert.UpdateForm;
begin
  BtnSaveFMX.Visible := DFMObj <> nil;
end;

end.
