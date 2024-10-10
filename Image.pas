{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit Image;

interface

function ProcessImage(sData, APad: String): String;

implementation

uses
  System.Classes, System.SysUtils, Vcl.Graphics, Vcl.Imaging.Jpeg, Vcl.Imaging.GIFImg, Vcl.Imaging.PngImage, PatchLib;

type
  TGraphicAccess = class(Vcl.Graphics.TGraphic)
  end;

function ProcessImage(sData, APad: String): String;
const
  LineLen = 64;
var
  InStr, OutStr, LineStr: String;
  InStream, OutStream: TMemoryStream;
  GraphClassName: ShortString;
  Graphic: TGraphic;
  Pic: TPngImage;
  LineNum, DataStart, DataLen: Integer;
begin
  if sData.StartsWith('{') then
    DataStart := 2
  else
    DataStart := 1;
  DataLen := Length(sData) - DataStart + 1;
  if sData.EndsWith('}') then
    Dec(DataLen);

  InStr := Copy(sData, DataStart, DataLen);
  Graphic := nil;
  Pic := nil;
  InStream := TMemoryStream.Create;
  OutStream := TMemoryStream.Create;
  try
    InStream.Size := Length(InStr) div 2;
    HexToBin(PChar(InStr), InStream.Memory^, InStream.Size);
    GraphClassName := PShortString(InStream.Memory)^;

    Graphic := TGraphicClass(FindClass(UTF8ToString(GraphClassName))).Create;
    InStream.Position := 1 + Length(GraphClassName);
    TGraphicAccess(Graphic).ReadData(InStream);

    if (Graphic is TPngImage) or (Graphic is TBitmap) or (Graphic is TWICImage) then
    begin
      Pic := TPngImage.Create;
      Pic.Assign(Graphic);
    end
    else
    begin
      Pic := TPngImage.CreateBlank(COLOR_RGB, 8, Graphic.Width, Graphic.Height);
      Pic.Canvas.Draw(0, 0, Graphic, 255);
    end;

    Pic.SaveToStream(OutStream);
    OutStream.Position := 0;
    SetLength(OutStr, OutStream.Size * 2);
    BinToHex(OutStream.Memory^, PChar(OutStr), OutStream.Size);

    LineNum := 0;
    repeat
      LineStr := Copy(OutStr, LineLen * LineNum + 1, LineLen);
      if LineStr <> '' then
        Result := Result + CRLF + APad + '        ' + LineStr;
      Inc(LineNum);
    until Length(LineStr) < LineLen;

    Result := 'MultiResBitmap = <' +
      CRLF + APad + '    item ' +
      CRLF + APad + '      Width = ' + Graphic.Width.ToString +
      CRLF + APad + '      Height = ' + Graphic.Height.ToString +
      CRLF + APad + '      PNG = {' + Result + '}' +
      CRLF + APad + '    end>';
  finally
    OutStream.Free;
    InStream.Free;
    Pic.Free;
    Graphic.Free;
  end;
end;

initialization
  System.Classes.RegisterClass(TMetafile);
  System.Classes.RegisterClass(TIcon);
  System.Classes.RegisterClass(TBitmap);
  System.Classes.RegisterClass(TWICImage);
  System.Classes.RegisterClass(TJpegImage);
  System.Classes.RegisterClass(TGifImage);
  System.Classes.RegisterClass(TPngImage);

end.
