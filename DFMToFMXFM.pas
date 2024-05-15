﻿unit DFMToFMXFM;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Win.Registry,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.Layouts,
  FMX.Memo,
  CvtrObj,
  FMX.StdCtrls,
  FMX.ScrollBox,
  FMX.Controls.Presentation,
  FMX.Objects, FMX.Memo.Types;

type
  TDFMtoFMXConvert = class(TForm)
    BtnOpenFile: TButton;
    mmOutput: TMemo;
    BtnProcess: TButton;
    btnConfiguracoes: TButton;
    BtnSaveFMX: TButton;
    mmInput: TMemo;
    dlgAbrir: TOpenDialog;
    dlgSalvar: TSaveDialog;
    procedure BtnOpenFileClick(Sender: TObject);
    procedure BtnProcessClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BtnSaveFMXClick(Sender: TObject);
    procedure btnConfiguracoesClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    DFMObj: TDfmToFmxObject;
    FIniFileName: String;
    FInPasFileName: String;
    FInDfmFileName: String;
    FOutPasFileName: String;
    FOutFmxFileName: String;
    function GetRegFile: TRegistryIniFile;
    Procedure RegIniLoad;
    Procedure RegIniSave;
    Procedure UpdateForm;
    function MyMessageDialog(const AMessage: string; const ADialogType: TMsgDlgType; const AButtons: TMsgDlgButtons; const ADefaultButton: TMsgDlgBtn): Integer;
  end;

var
  DFMtoFMXConvert: TDFMtoFMXConvert;

implementation

{$R *.fmx}

uses
  PatchLib,
  CONFIGINI,
  FMX.DialogService;

procedure TDFMtoFMXConvert.btnConfiguracoesClick(Sender: TObject);
begin
  TINI.Create(Self).ShowModal;
  RegIniLoad;
end;

procedure TDFMtoFMXConvert.BtnOpenFileClick(Sender: TObject);
begin
  BtnProcess.Enabled := False;
  FreeAndNil(DFMObj);
  if FInDfmFileName <> EmptyStr then
    dlgAbrir.InitialDir := ExtractFileDir(FInDfmFileName);
  if dlgAbrir.Execute then
  begin
    FInPasFileName := ChangeFileExt(dlgAbrir.FileName, '.pas');
    FInDfmFileName := ChangeFileExt(FInPasFileName, '.dfm');
    if FileExists(FInDfmFileName) then
    begin
      if TDfmToFmxObject.DFMIsTextBased(FInDfmFileName) then
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
  Stm: TStringStream;
begin
  if mmInput.Text <> EmptyStr then
  begin
    FreeAndNil(DFMObj);
    Data := mmInput.Text;
    Stm := TStringStream.Create;
    Stm.LoadFromFile(FInDfmFileName);
    Stm.Seek(0,soFromBeginning);
    try
      Data := Trim(ReadLineFrmStream(Stm));
      if Pos('object', Data) = 1 then
        DFMObj := TDfmToFmxObject.Create(Data, Stm, 0);
    finally
      Stm.Free;
    end;
  end;

  DFMObj.LiveBindings;

  DFMObj.LoadInfileDefs(FIniFileName);
  mmOutput.Text := EmptyStr;
  mmOutput.Text := DFMObj.FMXFile;
  BtnProcess.Enabled := False;
  UpdateForm;
end;

function TDFMtoFMXConvert.MyMessageDialog(const AMessage: string; const ADialogType: TMsgDlgType; const AButtons: TMsgDlgButtons; const ADefaultButton: TMsgDlgBtn): Integer;
var
  mr: TModalResult;
begin
  mr := mrNone;

  TDialogService.MessageDialog(
    AMessage,
    ADialogType,
    AButtons,
    ADefaultButton,
    0,
    procedure (const AResult: TModalResult)
    begin
      mr := AResult
    end
  );

  while mr = mrNone do // wait for modal result
    Application.ProcessMessages;

  Result := mr;
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
      dlgSalvar.InitialDir := ExtractFileDir(FOutPasFileName);
      dlgSalvar.FileName   := ExtractFileName(ChangeFileExt(FOutPasFileName, '.fmx'));
    end;

    if dlgSalvar.Execute then
    begin
      FOutPasFileName := ChangeFileExt(dlgSalvar.FileName, '.pas');
      FOutFmxFileName := ChangeFileExt(FOutPasFileName, '.fmx');

      if FileExists(FOutFmxFileName) or FileExists(FOutPasFileName) then
      begin
        if myMessageDialog(
          'Replace Existing Files: '+ FOutFmxFileName +' and/or '+ FOutPasFileName,
          TMsgDlgType.mtWarning,
          [TMsgDlgBtn.mbOK, TMsgDlgBtn.mbCancel],
          TMsgDlgBtn.mbOK) = mrOk then
        begin
          DeleteFile(FOutFmxFileName);
          DeleteFile(FOutPasFileName);
        end;
      end;

      if FileExists(FOutFmxFileName) then
        raise Exception.Create(FOutFmxFileName + 'Already exists');

      DFMObj.WriteFMXToFile(FOutFmxFileName);

      if FileExists(FOutPasFileName) then
        raise Exception.Create(FOutPasFileName + 'Already exists');

      DFMObj.WritePasToFile(FOutPasFileName, FInPasFileName);
    end;
  end;
end;

procedure TDFMtoFMXConvert.FormClose(Sender: TObject; var Action: TCloseAction);
begin
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
      dlgAbrir.InitialDir := ExtractFileDir(FOutPasFileName);
    end;
    if FileExists(FInDfmFileName) and TDfmToFmxObject.DFMIsTextBased(FInDfmFileName) then
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
