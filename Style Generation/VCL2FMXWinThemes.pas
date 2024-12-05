unit VCL2FMXWinThemes;

interface

uses
  System.Types, System.UITypes, FMX.Types, FMX.MultiResBitmap, FMX.Objects, FMX.Styles.Objects;

type
  TStates = TArray<Integer>;

function CreateImage(const ATheme: string; APart: Integer; const AStates: TStates; var ASize: TSize;
  AOwner: TFmxObject): TImage;
procedure CalcLink(ALinks: TBitmapLinks; AState: Integer; const AStates: TStates; ASize: TSize;
  AAddCapInsets: Boolean = False);
function GetThemeColor(const ATheme: string; APart, AState, AProp: Integer): TAlphaColor;
function GetSystemColor(AType: Integer; AAlpha: Byte = 255): TAlphaColor;

implementation

uses
  System.SysUtils, System.Classes, System.Win.ComObj, Winapi.UxTheme, Winapi.Windows, FMX.Graphics, VCL2FMXStyleGen;

type
  TScale = (One, OneHalf, Two);

const
  CDPI: array[TScale] of Integer = (96, 144, 192);
  CScales: array[TScale] of Single = (1, 1.5, 2);

procedure DrawStates(AThemeHandle: THandle; APart: Integer; const AStates: TStates; ABitmap: TBitmap; var ASize: TSize);
var
  DC: HDC;
  Bmp: HBITMAP;
  DefSize: TSize;
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

    if (ASize.Height = 0) or (ASize.Width = 0) then
      OleCheck(GetThemePartSize(AThemeHandle, DC, APart, AStates[0], nil, TS_TRUE, DefSize));
    if ASize.Height = 0 then
      ASize.Height := DefSize.Height;
    if ASize.Width = 0 then
      ASize.Width := DefSize.Width;

    FillMemory(@BmpInfo, SizeOf(BmpInfo), 0);
    BmpInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    BmpInfo.bmiHeader.biWidth := ASize.Width;
    BmpInfo.bmiHeader.biHeight := -1 * ASize.Height * Count;  // negative means top-down
    BmpInfo.bmiHeader.biPlanes := 1;
    BmpInfo.bmiHeader.biBitCount := 32;
    BmpInfo.bmiHeader.biCompression := BI_RGB;
    Bits := nil;
    Bmp := CreateDIBSection(DC, BmpInfo, DIB_RGB_COLORS, Bits, 0, 0);
    Win32Check(Bmp <> 0);

    SelectObject(DC, Bmp);
    for i := 0 to Count - 1 do
      OleCheck(DrawThemeBackground(AThemeHandle, DC, APart, AStates[i],
        Rect(0, i * ASize.Height, ASize.Width, (i + 1) * ASize.Height), nil));

    ABitmap.SetSize(ASize.Width, ASize.Height * Count);
    if ABitmap.Map(TMapAccess.Write, DstData) then
    begin
      SrcData := TBitmapData.Create(ASize.Width, ASize.Height, TPixelFormat.BGRA);
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

function CreateImage(const ATheme: string; APart: Integer; const AStates: TStates; var ASize: TSize;
  AOwner: TFmxObject): TImage;
var
  Scale: TScale;
  ThemeHandle: THandle;
  Item: TFixedBitmapItem;
  Size: TSize;
begin
  Result := TImage.Create(AOwner);

  for Scale := One to Two do
  begin
    ThemeHandle := 0;
    try
      ThemeHandle := OpenThemeDataForDPI(0, PChar(ATheme), CDPI[Scale]);
      Win32Check(ThemeHandle <> 0);

      Item := TFixedBitmapItem(Result.MultiResBitmap.ItemByScale(CScales[Scale], {ExactMatch} True,
        {IncludeEmpty} True));
      if not Assigned(Item) then
      begin
        Item := Result.MultiResBitmap.Add;
        Item.Scale := CScales[Scale];
      end;

      if Scale = One then
        DrawStates(ThemeHandle, APart, AStates, Item.Bitmap, ASize)
      else
      begin
        Size := TSize.Create(MulDiv(ASize.Width, CDPI[Scale], USER_DEFAULT_SCREEN_DPI),
          MulDiv(ASize.Height, CDPI[Scale], USER_DEFAULT_SCREEN_DPI));
        DrawStates(ThemeHandle, APart, AStates, Item.Bitmap, Size);
      end;
    finally
      CloseThemeData(ThemeHandle);
    end;
  end;
end;

procedure CalcLink(ALinks: TBitmapLinks; AState: Integer; const AStates: TStates; ASize: TSize;
  AAddCapInsets: Boolean = False);
var
  i, InsetHeight, InsetWidth: Integer;
  Scale: TScale;
  Link: TBitmapLink;
  Size: TSize;
begin
  for i := 0 to Length(AStates) - 1 do
    if AStates[i] = AState then
    begin
      for Scale := One to Two do
      begin
        Link := ALinks.LinkByScale(CScales[Scale], {ExactMatch} True);
        if not Assigned(Link) then
        begin
          Link := ALinks.Add as TBitmapLink;
          Link.Scale := CScales[Scale];
        end;

        if Scale = One then
          Size := ASize
        else
          Size := TSize.Create(MulDiv(ASize.Width, CDPI[Scale], USER_DEFAULT_SCREEN_DPI),
            MulDiv(ASize.Height, CDPI[Scale], USER_DEFAULT_SCREEN_DPI));

        Link.SourceRect.Top := Size.Height * i;
        Link.SourceRect.Left := 0;
        Link.SourceRect.Bottom := Size.Height * (i + 1);
        Link.SourceRect.Right := Size.Width;

        if AAddCapInsets then
        begin
          InsetHeight := Size.Height mod 2;
          if InsetHeight = 0 then
            InsetHeight := 2;
          InsetWidth := Size.Width mod 2;
          if InsetWidth = 0 then
            InsetWidth := 2;

          Link.CapInsets.Top := (Size.Height - InsetHeight) / 2;
          Link.CapInsets.Left := (Size.Width - InsetWidth) / 2;
          Link.CapInsets.Bottom := Link.CapInsets.Top; // This is not coordinates, but a distance from the edge
          Link.CapInsets.Right := Link.CapInsets.Left;
        end;
      end;
      Break;
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
    OleCheck(Winapi.UxTheme.GetThemeColor(ThemeHandle, APart, AState, AProp, Color));
    TAlphaColorRec(Color).A := 255;
    Result := Color;
  finally
    CloseThemeData(ThemeHandle);
  end;
end;

function GetSystemColor(AType: Integer; AAlpha: Byte = 255): TAlphaColor;
var
  Color: Cardinal;
begin
  Color := GetSysColor(AType);

  TAlphaColorRec(Result).A := AAlpha;
  TAlphaColorRec(Result).B := TColorRec(Color).B;
  TAlphaColorRec(Result).G := TColorRec(Color).G;
  TAlphaColorRec(Result).R := TColorRec(Color).R;
end;

end.
