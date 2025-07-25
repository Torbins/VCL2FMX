program VCL2FMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  CvtrObjRoot in 'CvtrObjRoot.pas',
  DFMToFMXFM in 'DFMToFMXFM.pas' {DFMtoFMXConvert},
  PatchLib in 'PatchLib.pas',
  CONFIGINI in 'CONFIGINI.pas' {INI},
  Image in 'Image.pas',
  ImageList in 'ImageList.pas',
  CvtrProp in 'CvtrProp.pas',
  CvtrObject in 'CvtrObject.pas',
  ReflexiveMasks in 'ReflexiveMasks.pas',
  VCL2FMXStyleGen in 'Style Generation\VCL2FMXStyleGen.pas',
  VCL2FMXWinThemes in 'Style Generation\VCL2FMXWinThemes.pas',
  CvtrPropValue in 'CvtrPropValue.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := False;
  Application.CreateForm(TDFMtoFMXConvert, DFMtoFMXConvert);
  Application.Run;
end.
