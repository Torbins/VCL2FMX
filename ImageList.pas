{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit ImageList;

interface

uses
  PatchLib;

function EncodeImageList(AImageList: TImageList; APad: String): String;
procedure ParseImageList(sData: String; AImageList: TImageList);

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Vcl.ImgList, Vcl.Graphics, Vcl.Imaging.PngImage;

type
  TImageListAccess = class(Vcl.ImgList.TCustomImageList)
  end;

procedure ParseImageList(sData: String; AImageList: TImageList);
var
  Stream: TMemoryStream;
  ImgList: TImageListAccess;
  Png: TPngImage;
  Bmp: TBitmap;
  I: Integer;
begin
  Stream := nil;
  ImgList := nil;
  try
    Stream := TMemoryStream.Create;
    ImgList := TImageListAccess.Create(nil);

    HexToStream(sData, Stream);
    TImageListAccess(ImgList).ReadData(Stream);

    for I := 0 to Pred(ImgList.Count) do
    begin
      Bmp := TBitmap.Create;
      try
        ImgList.GetBitmap(I, Bmp);
        Png := TPngImage.Create;
        Png.Assign(Bmp);
        AImageList.Add(Png);
      finally
        FreeAndNil(Bmp);
      end;
    end;
  finally
    ImgList.Free;
    Stream.Free;
  end;
end;

function EncodeImageList(AImageList: TImageList; APad: String): String;
var
  Stream: TMemoryStream;
  Data: String;
  i: Integer;
begin
  Stream := TMemoryStream.Create;
  try
    Result := APad + '  Source = <';

    // Adiciona as imagens
    for i := 0 to AImageList.Count - 1 do
    begin
      Stream.Clear;
      AImageList[i].SaveToStream(Stream);
      Data := BreakIntoLines(StreamToHex(Stream), APad + '        ');

      Result := Result +
        CRLF + APad + '    item ' +
        CRLF + APad + '      MultiResBitmap = < ' +
        CRLF + APad + '        item ' +
        CRLF + APad + '          Width = ' + AImageList[i].Height.ToString +
        CRLF + APad + '          Height = ' + AImageList[i].Width.ToString +
        CRLF + APad + '          PNG = {' + Data + '}' +
        CRLF + APad + '        end>' +
        CRLF + APad + '      Name = ''Item' + i.toString + '''' +
        CRLF + APad + '    end';
    end;

    Result := Result + '>' + CRLF + APad + '  Destination = < ';

    // Adiciona os itens
    for i := 0 to AImageList.Count - 1 do
      Result := Result +
        CRLF + APad + '    item ' +
        CRLF + APad + '      Layers = < ' +
        CRLF + APad + '        item ' +
        CRLF + APad + '          Name = ''Item' + i.toString + '''' +
        CRLF + APad + '          SourceRect.Right = ' + AImageList[i].Width.ToString +
        CRLF + APad + '          SourceRect.Bottom = ' + AImageList[i].Height.ToString +
        CRLF + APad + '        end>' +
        CRLF + APad + '    end';

    Result := Result + '>';
  finally
    Stream.Free;
  end;
end;

end.
