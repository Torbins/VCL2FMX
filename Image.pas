{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit Image;

interface

uses
  Vcl.Imaging.PngImage;

function CreateGlyphPng(const AData: String; ANumGlyphs: Integer): TPngImage;
function EncodePicture(APng: TPngImage): String;
function ConvertPicture(const AData, APad: String; out AWidth, AHeight: Integer): String;

implementation

uses
  System.Classes, System.SysUtils, Vcl.Graphics, Vcl.Imaging.Jpeg, Vcl.Imaging.GIFImg, PatchLib;

type
  TGraphicAccess = class(Vcl.Graphics.TGraphic)
  end;

function CreateGlyphPng(const AData: String; ANumGlyphs: Integer): TPngImage;
const
  StreamLenghtFieldLen = 4;
var
  GlyphBmp: TBitmap;
  Stream: TMemoryStream;
begin
  GlyphBmp := nil;
  Stream := nil;
  try
    GlyphBmp := TBitmap.Create;
    Stream := TMemoryStream.Create;

    HexToStream(AData, Stream);
    Stream.Position := StreamLenghtFieldLen;
    GlyphBmp.LoadFromStream(Stream);

    Result := TPngImage.CreateBlank(COLOR_RGB, 8, GlyphBmp.Width div ANumGlyphs, GlyphBmp.Height);
    Result.Canvas.Draw(0, 0, GlyphBmp);
  finally
    GlyphBmp.Free;
    Stream.Free;
  end;
end;

function EncodePicture(APng: TPngImage): String;
const
  PicClass = 'TPngImage';
var
  Stream: TMemoryStream;
  Len: Integer;
  Bytes: TBytes;
begin
  Stream := TMemoryStream.Create;
  try
    Bytes := TEncoding.UTF8.GetBytes(PicClass);
    Len := Length(Bytes);
    Stream.Write(Len, 1);
    Stream.Write(Bytes, Len);
    APng.SaveToStream(Stream);

    Result := StreamToHex(Stream);
  finally
    Stream.Free;
  end;
end;

function ConvertPicture(const AData, APad: String; out AWidth, AHeight: Integer): String;
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
    HexToStream(AData, Stream);
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
    Result := '{' + BreakIntoLines(StreamToHex(Stream), APad) + '}';
    AHeight := Graphic.Height;
    AWidth := Graphic.Width;
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
