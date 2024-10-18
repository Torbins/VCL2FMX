program VCL2FMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  CvtrObj in 'CvtrObj.pas',
  DFMToFMXFM in 'DFMToFMXFM.pas' {DFMtoFMXConvert},
  PatchLib in 'PatchLib.pas',
  CONFIGINI in 'CONFIGINI.pas' {INI},
  Image in 'Image.pas',
  ImageList in 'ImageList.pas',
  CvtrProp in 'CvtrProp.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := False;
  Application.CreateForm(TDFMtoFMXConvert, DFMtoFMXConvert);
  Application.Run;
end.
