unit VCL2FMXWinThemes;

interface

uses
  FMX.MultiResBitmap, FMX.Objects, FMX.Styles.Objects, System.UITypes;

type
  TStates = TArray<Integer>;

function CreateImage(const ATheme: string; APart: Integer; const AStates: TStates): TImage;
procedure CalcLink(ALinks: TBitmapLinks; AState: Integer; const ATheme: string; APart: Integer; const AStates: TStates);
function GetThemeColor(const ATheme: string; APart, AState, AProp: Integer): TAlphaColor;

implementation

uses
  System.SysUtils, System.Classes, System.Win.ComObj, Winapi.UxTheme, Winapi.Windows, FMX.Types, FMX.Graphics,
  VCL2FMXStyleGen;

type
  TScale = (One, OneHalf, Two);

const
  CDPI: array[TScale] of Integer = (96, 144, 192);
  CScales: array[TScale] of Single = (1, 1.5, 2);

procedure DrawStates(AThemeHandle: THandle; APart: Integer; const AStates: TStates; ABitmap: TBitmap);
var
  DC: HDC;
  Bmp: HBITMAP;
  Size: TSize;
  BmpInfo: TBitmapInfo;
  Bits: Pointer;
  SrcData, DstData: TBitmapData;
  Count, i: Integer;
begin
  DC := 0;
  Bmp := 0;
  try
    Count := Length(AStates);
    DC := CreateCompatibleDC(0);
    Win32Check(DC <> 0);
    OleCheck(GetThemePartSize(AThemeHandle, DC, APart, AStates[0], nil, TS_TRUE, Size));

    FillMemory(@BmpInfo, SizeOf(BmpInfo), 0);
    BmpInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    BmpInfo.bmiHeader.biWidth := Size.cx;
    BmpInfo.bmiHeader.biHeight := -Size.cy * Count;  // top-down
    BmpInfo.bmiHeader.biPlanes := 1;
    BmpInfo.bmiHeader.biBitCount := 32;
    BmpInfo.bmiHeader.biCompression := BI_RGB;
    Bits := nil;
    Bmp := CreateDIBSection(DC, BmpInfo, DIB_RGB_COLORS, Bits, 0, 0);
    Win32Check(Bmp <> 0);

    SelectObject(DC, Bmp);
    for i := 0 to Count - 1 do
      OleCheck(DrawThemeBackground(AThemeHandle, DC, APart, AStates[i],
        Rect(0, i * Size.cy, Size.cx, (i + 1) * Size.cy), nil));

    ABitmap.SetSize(Size.cx, Size.cy * Count);
    if ABitmap.Map(TMapAccess.Write, DstData) then
    begin
      SrcData := TBitmapData.Create(Size.cx, Size.cy, TPixelFormat.BGRA);
      SrcData.Data := Bits;
      SrcData.Pitch := SrcData.BytesPerLine;
      DstData.Copy(SrcData);
      ABitmap.Unmap(DstData);
    end;
  finally
    DeleteObject(Bmp);
    DeleteDC(DC);
  end;
end;

procedure DrawScale(AScale: TScale; const ATheme: string; APart: Integer; const AStates: TStates;
  AMultiResBitmap: TFixedMultiResBitmap);
var
  ThemeHandle: THandle;
  Item: TFixedBitmapItem;
begin
  ThemeHandle := 0;
  try
    ThemeHandle := OpenThemeDataForDPI(0, PChar(ATheme), CDPI[AScale]);
    Win32Check(ThemeHandle <> 0);

    Item := TFixedBitmapItem(AMultiResBitmap.ItemByScale(CScales[AScale], {ExactMatch} True, {IncludeEmpty} True));
    if not Assigned(Item) then
    begin
      Item := AMultiResBitmap.Add;
      Item.Scale := CScales[AScale];
    end;

    DrawStates(ThemeHandle, APart, AStates, Item.Bitmap);
  finally
    CloseThemeData(ThemeHandle);
  end;
end;

function CreateImage(const ATheme: string; APart: Integer; const AStates: TStates): TImage;
var
  Scale: TScale;
begin
  Result := TImage.Create(StyleGenerator);

  for Scale := One to Two do
    DrawScale(Scale, ATheme, APart, AStates, Result.MultiResBitmap);
end;

procedure CalcLink(ALinks: TBitmapLinks; AState: Integer; const ATheme: string; APart: Integer; const AStates: TStates);
var
  ThemeHandle: THandle;
  DC: HDC;
  Size: TSize;
  i: Integer;
  Scale: TScale;
  Link: TBitmapLink;
begin
  DC := 0;
  try
    DC := CreateCompatibleDC(0);
    Win32Check(DC <> 0);

    for i := 0 to Length(AStates) - 1 do
      if AStates[i] = AState then
      begin
        for Scale := One to Two do
        begin
          ThemeHandle := 0;
          try
            ThemeHandle := OpenThemeDataForDPI(0, PChar(ATheme), CDPI[Scale]);
            Win32Check(ThemeHandle <> 0);
            OleCheck(GetThemePartSize(ThemeHandle, DC, APart, AStates[0], nil, TS_TRUE, Size));

            Link := ALinks.LinkByScale(CScales[Scale], {ExactMatch} True);
            if not Assigned(Link) then
            begin
              Link := ALinks.Add as TBitmapLink;
              Link.Scale := CScales[Scale];
            end;

            Link.SourceRect.Top := Size.cx * i;
            Link.SourceRect.Left := 0;
            Link.SourceRect.Bottom := Size.cx * (i + 1);
            Link.SourceRect.Right := Size.cy;
          finally
            CloseThemeData(ThemeHandle);
          end;
        end;
        Break;
      end;
  finally
    DeleteDC(DC);
  end;
end;

function GetThemeColor(const ATheme: string; APart, AState, AProp: Integer): TAlphaColor;
var
  ThemeHandle: THandle;
  Color: Cardinal;
begin
  ThemeHandle := 0;
  try
    ThemeHandle := OpenThemeDataForDPI(0, PChar(ATheme), CDPI[One]);
    Win32Check(ThemeHandle <> 0);

    Color := 0;
    Winapi.UxTheme.GetThemeColor(ThemeHandle, APart, AState, AProp, Color);
    if Color <> 0 then
      TAlphaColorRec(Color).A := 255;
    Result := Color;
  finally
    CloseThemeData(ThemeHandle);
  end;
end;

end.
