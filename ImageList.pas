{**********************************************}
{                                              }
{              Eduardo Rodrigues               }
{                 18/09/2019                   }
{                                              }
{**********************************************}
unit ImageList;

interface

function ProcessImageList(sData, APad: String): String;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Vcl.ImgList, Vcl.Graphics, Vcl.Imaging.PngImage,
  PatchLib;

type
  TImageListAccess = class(Vcl.ImgList.TCustomImageList)
  end;
  TPngList = TObjectList<TPngImage>;

function ProcessImageList(sData, APad: String): String;
var
  Stream: TMemoryStream;
  ImgList: TImageListAccess;
  PngList: TPngList;
  Png: TPngImage;
  Bmp: TBitmap;
  I: Integer;
  Data: String;
begin
  Stream := TMemoryStream.Create;
  ImgList := TImageListAccess.Create(nil);
  PngList := TPngList.Create({AOwnsObjects} True);
  try
    HexToStream(sData, Stream);
    TImageListAccess(ImgList).ReadData(Stream);

    for I := 0 to Pred(ImgList.Count) do
    begin
      Bmp := TBitmap.Create;
      try
        ImgList.GetBitmap(I, Bmp);
        Png := TPngImage.Create;
        Png.Assign(Bmp);
        PngList.Add(Png);
      finally
        FreeAndNil(Bmp);
      end;
    end;

    Result := '  Source = <';

    // Adiciona as imagens
    for I := 0 to Pred(PngList.Count) do
    begin
      Stream.Clear;
      PngList.Items[I].SaveToStream(Stream);
      Data := BreakIntoLines(StreamToHex(Stream), APad + '    ');

      Result := Result +
        CRLF + APad + '    item ' +
        CRLF + APad + '      MultiResBitmap = < ' +
        CRLF + APad + '        item ' +
        CRLF + APad + '          Width = ' + PngList.Items[I].Height.ToString +
        CRLF + APad + '          Height = ' + PngList.Items[I].Width.ToString +
        CRLF + APad + '          PNG = {' + Data + '}' +
        CRLF + APad + '        end>' +
        CRLF + APad + '      Name = ' + QuotedStr('Item ' + I.ToString) +
        CRLF + APad + '    end';
    end;

    Result := Result + '>' + CRLF + APad + '  Destination = < ';

    // Adiciona os itens
    for I := 0 to Pred(PngList.Count) do
      Result := Result +
        CRLF + APad + '    item ' +
        CRLF + APad + '      Layers = < ' +
        CRLF + APad + '        item ' +
        CRLF + APad + '          Name = ' + QuotedStr('Item ' + I.ToString) +
        CRLF + APad + '            SourceRect.Right = ' + PngList.Items[I].Width.ToString +
        CRLF + APad + '            SourceRect.Bottom = ' + PngList.Items[I].Height.ToString +
        CRLF + APad + '        end>' +
        CRLF + APad + '    end';

    Result := Result + '>';
  finally
    PngList.Free;
    ImgList.Free;
    Stream.Free;
  end;
end;

end.
