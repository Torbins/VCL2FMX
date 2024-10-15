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
var
  Stream: TMemoryStream;
  GraphClassName: ShortString;
  Graphic: TGraphic;
  Png: TPngImage;
begin
  Graphic := nil;
  Png := nil;
  Stream := TMemoryStream.Create;
  try
    HexToStream(sData, Stream);
    GraphClassName := PShortString(Stream.Memory)^;

    Graphic := TGraphicClass(FindClass(UTF8ToString(GraphClassName))).Create;
    Stream.Position := 1 + Length(GraphClassName);
    TGraphicAccess(Graphic).ReadData(Stream);

    if (Graphic is TPngImage) or (Graphic is TBitmap) or (Graphic is TWICImage) then
    begin
      Png := TPngImage.Create;
      Png.Assign(Graphic);
    end
    else
    begin
      Png := TPngImage.CreateBlank(COLOR_RGB, 8, Graphic.Width, Graphic.Height);
      Png.Canvas.Draw(0, 0, Graphic, 255);
    end;

    Stream.Clear;
    Png.SaveToStream(Stream);
    Result := BreakIntoLines(StreamToHex(Stream), APad + '    ');

    Result := 'MultiResBitmap = <' +
      CRLF + APad + '    item ' +
      CRLF + APad + '      Width = ' + Graphic.Width.ToString +
      CRLF + APad + '      Height = ' + Graphic.Height.ToString +
      CRLF + APad + '      PNG = {' + Result + '}' +
      CRLF + APad + '    end>';
  finally
    Stream.Free;
    Png.Free;
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
