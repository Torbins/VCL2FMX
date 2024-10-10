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
  System.SysUtils, System.Classes, Vcl.ImgList, Vcl.Graphics, FMX.ImgList, PatchLib;

type
  TCustomImageListAccess = class(Vcl.ImgList.TCustomImageList)
  end;

function ProcessImageList(sData, APad: String): String;
var
  Loutput: TMemoryStream;
  Lgraphic: TCustomImageListAccess;
  img1: FMX.ImgList.TImageList;
  stream: TMemoryStream;
  stream2: TMemoryStream;
  bmp: TBitmap;
  I: Integer;
  sTemp: String;
begin
  Loutput := TMemoryStream.Create;
  try
    // Carrega dados para memoria
    HexToStream(sData, Loutput);

    Lgraphic := TCustomImageListAccess.Create(nil);
    try
      // Carrega dados para imagem VCL
      TCustomImageListAccess(Lgraphic).ReadData(Loutput);

      // Cria imagem FMX
      img1 := FMX.ImgList.TImageList.Create(nil);
      try
        // Passa por todas imagens VCL
        for I := 0 to Pred(Lgraphic.Count) do
        begin
          // Converte de VCL para FMX
          stream := TMemoryStream.Create;
          try
            bmp := TBitmap.Create;
            try
              // Obtem imagem
              Lgraphic.GetBitmap(I, bmp);
              // Salva no Stream
              bmp.SaveToStream(stream);
//              bmp.SaveToFile('D:\teste.bmp');
              // Adiciona imagem no FMX
              stream.Position := 0;
              img1.Source.Add.MultiResBitmap.Add.Bitmap.LoadFromStream(stream);
            finally
              FreeAndNil(bmp);
            end;
          finally
            stream.Free;
          end;
        end;

        Result := '  Source = <';

        // Adiciona as imagens
        for I := 0 to Pred(img1.Source.Count) do
        begin
          stream2 := TMemoryStream.Create;
          try
            img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.SaveToStream(stream2);

            sTemp := StreamToHex(stream2, APad, 64);

            Result := Result +
            sLineBreak + APad +'    item '+
            sLineBreak + APad +'      MultiResBitmap.Height = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Height.ToString +
            sLineBreak + APad +'      MultiResBitmap.Width = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Width.ToString +
            sLineBreak + APad +'      MultiResBitmap = < '+
            sLineBreak + APad +'        item '+
            sLineBreak + APad +'          Width = 256 '+
            sLineBreak + APad +'          Height = 256 '+
            sLineBreak + APad +'          PNG = {'+ sTemp +'}'+
            sLineBreak + APad +'          FileName = '+ QuotedStr('') +
            sLineBreak + APad +'        end>'+
            sLineBreak + APad +'      Name = '+ QuotedStr('Item '+ I.ToString) +
            sLineBreak + APad +'    end';

            if Pred(img1.Source.Count) = I then
              Result := Result +'>';
          finally
            FreeAndNil(stream2);
          end;
        end;

        Result := Result +
        sLineBreak + APad +'  Destination = < ';

        // Adiciona os itens
        for I := 0 to Pred(img1.Source.Count) do
        begin
          Result := Result +
          sLineBreak + APad +'    item '+
          sLineBreak + APad +'      Layers = < '+
          sLineBreak + APad +'        item '+
          sLineBreak + APad +'          Name = '+ QuotedStr('Item '+ I.ToString) +
          sLineBreak + APad +'            SourceRect.Right = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Width.ToString +
          sLineBreak + APad +'            SourceRect.Bottom = '+ img1.Source.Items[I].MultiResBitmap.Items[0].Bitmap.Height.ToString +
          sLineBreak + APad +'        end>'+
          sLineBreak + APad +'    end';

          if Pred(img1.Source.Count) = I then
            Result := Result +'>';
        end;

      finally
        img1.Free;
      end;
    finally
      Lgraphic.Free;
    end;
  finally
    Loutput.Free;
  end;
end;

end.
