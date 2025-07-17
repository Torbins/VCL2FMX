{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit Image;

interface

uses
  Vcl.Imaging.PngImage, System.Classes;

function CreateGlyphPng(const AData: TMemoryStream; ANumGlyphs: Integer): TPngImage;
function EncodePicture(APng: TPngImage; const APad: String): String;
function ConvertPicture(AData: TMemoryStream; const APad: String; out AWidth, AHeight: Integer): String;

implementation

uses
  System.SysUtils, Vcl.Graphics, Vcl.Imaging.Jpeg, Vcl.Imaging.GIFImg, PatchLib;

type
  TGraphicAccess = class(Vcl.Graphics.TGraphic)
  end;

function CreateGlyphPng(const AData: TMemoryStream; ANumGlyphs: Integer): TPngImage;
const
  StreamLenghtFieldLen = 4;
var
  GlyphBmp: TBitmap;
begin
  GlyphBmp := TBitmap.Create;
  try
    AData.Position := StreamLenghtFieldLen;
    GlyphBmp.LoadFromStream(AData);

    Result := TPngImage.CreateBlank(COLOR_RGB, 8, GlyphBmp.Width div ANumGlyphs, GlyphBmp.Height);
    Result.Canvas.Draw(0, 0, GlyphBmp);
  finally
    GlyphBmp.Free;
  end;
end;

function EncodePicture(APng: TPngImage; const APad: String): String;
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    APng.SaveToStream(Stream);
    Result := '{' + BreakIntoLines(StreamToHex(Stream), APad) + '}';
  finally
    Stream.Free;
  end;
end;

function ConvertPicture(AData: TMemoryStream; const APad: String; out AWidth, AHeight: Integer): String;
var
  GraphClassName: ShortString;
  Graphic: TGraphic;
  Png: TPngImage;
begin
  Graphic := nil;
  Png := nil;
  try
    GraphClassName := PShortString(AData.Memory)^;

    Graphic := TGraphicClass(FindClass(UTF8ToString(GraphClassName))).Create;
    AData.Position := 1 + Length(GraphClassName);
    TGraphicAccess(Graphic).ReadData(AData);

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

    Result := EncodePicture(Png, APad);
    AHeight := Graphic.Height;
    AWidth := Graphic.Width;
  finally
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
