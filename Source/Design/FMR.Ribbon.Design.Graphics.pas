{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: VCL graphics helpers, glyph names       }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.Graphics;

/// Helpers of the VCL editor windows: icon-font glyphs drawn with GDI into 32-bit alpha bitmaps and image lists,
/// FMX bitmaps (image source previews rendered by TFmrImageSource.Draw on an FMX canvas) converted to VCL bitmaps,
/// the glyphs of an icon font (GetFontUnicodeRanges) and a table of glyph names for the search of the image dialog.

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections,
  Vcl.Graphics, Vcl.ImgList, Vcl.Controls, FMX.ImgList, FMR.Bars.Images;

type
  TFmrGlyphName = record
    Code: Cardinal;
    Name: string;
  end;

/// <summary>'Segoe Fluent Icons' when installed (Windows 11), otherwise 'Segoe MDL2 Assets'.</summary>
function FmrIconFontFamily: string;
/// <summary>Icon fonts installed on this computer (Segoe Fluent Icons, Segoe MDL2 Assets, Segoe UI Symbol...).
/// </summary>
function FmrInstalledIconFonts: TArray<string>;
/// <summary>A 32-bit bitmap (alpha, not premultiplied: AlphaFormat = afDefined) with the glyph ACode of AFamily
/// centered, ASize pixels square, in AColor.</summary>
function FmrGlyphBitmap(const ACode: Cardinal; const ASize: Integer; const AColor: TColor;
  const AFamily: string = ''): Vcl.Graphics.TBitmap;
/// <summary>Adds a glyph to a 32-bit image list; returns the index.</summary>
function FmrAddGlyph(const AImages: Vcl.ImgList.TCustomImageList; const ACode: Cardinal; const AColor: TColor;
  const AFamily: string = ''): Integer;
/// <summary>Adds a 32-bit bitmap (any alpha format) to a 32-bit image list, scaled to its size.</summary>
function FmrAddBitmap(const AImages: Vcl.ImgList.TCustomImageList; const ABitmap: Vcl.Graphics.TBitmap): Integer;
/// <summary>Draws a glyph as text (any canvas, no alpha needed).</summary>
procedure FmrDrawGlyphText(const ACanvas: TCanvas; const ARect: TRect; const ACode: Cardinal; const AFamily: string;
  const AColor: TColor; const AHeight: Integer);
/// <summary>Renders AImage with TFmrImageSource.Draw on an FMX bitmap canvas (ASize pixels) and converts it to a
/// 32-bit VCL bitmap (afDefined). nil when nothing could be rendered.</summary>
function FmrRenderImageSource(const AImage: TFmrImageSource; const AImages: FMX.ImgList.TCustomImageList;
  const ASize: Integer; const ATint: TAlphaColor): Vcl.Graphics.TBitmap;
/// <summary>An entry of an FMX image list as a 32-bit VCL bitmap (nil when not available).</summary>
function FmrRenderImageListEntry(const AImages: FMX.ImgList.TCustomImageList; const AIndex, ASize: Integer)
  : Vcl.Graphics.TBitmap;
/// <summary>Code points of the glyphs of an icon font in the private use area (E000..F8FF); falls back to
/// E700..F8B3 when the font cannot be queried.</summary>
function FmrIconFontGlyphs(const AFamily: string): TArray<Cardinal>;
/// <summary>Known glyph names (Segoe Fluent Icons / Segoe MDL2 Assets).</summary>
function FmrGlyphNames: TArray<TFmrGlyphName>;
/// <summary>Name of a glyph ('' when unknown).</summary>
function FmrGlyphName(const ACode: Cardinal): string;
/// <summary>'#AARRGGBB' text of an alpha color.</summary>
function FmrAlphaColorText(const AColor: TAlphaColor): string;
function FmrAlphaColorToColor(const AColor: TAlphaColor): TColor;
function FmrColorToAlphaColor(const AColor: TColor): TAlphaColor;

implementation

uses
  System.Math, System.Character, Vcl.Forms, FMX.Types, FMX.Graphics;

var
  GNameMap: TDictionary<Cardinal, string>;

function FmrIconFontFamily: string;
begin
  if Screen.Fonts.IndexOf('Segoe Fluent Icons') >= 0 then
    Result := 'Segoe Fluent Icons'
  else
    Result := 'Segoe MDL2 Assets';
end;

function FmrInstalledIconFonts: TArray<string>;
const
  Candidates: array[0..6] of string = ('Segoe Fluent Icons', 'Segoe MDL2 Assets', 'Segoe UI Symbol',
    'Segoe UI Emoji', 'Material Symbols Outlined', 'Material Icons', 'FontAwesome');
var
  S: string;
begin
  Result := nil;
  for S in Candidates do
    if Screen.Fonts.IndexOf(S) >= 0 then
      Result := Result + [S];
end;

function GlyphString(const ACode: Cardinal): string;
begin
  if (ACode = 0) or (ACode > $10FFFF) or ((ACode >= $D800) and (ACode <= $DFFF)) then
    Result := ''
  else
    Result := Char.ConvertFromUtf32(ACode);
end;

function FmrGlyphBitmap(const ACode: Cardinal; const ASize: Integer; const AColor: TColor;
  const AFamily: string): Vcl.Graphics.TBitmap;
var
  Mask: Vcl.Graphics.TBitmap;
  R: TRect;
  S: string;
  X, Y: Integer;
  Src: PRGBTriple;
  Dst: PRGBQuad;
  C: TColor;
  A: Byte;
begin
  Result := Vcl.Graphics.TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.SetSize(ASize, ASize);
  Result.AlphaFormat := afIgnored;
  for Y := 0 to ASize - 1 do
    FillChar(Result.ScanLine[Y]^, ASize * 4, 0);
  S := GlyphString(ACode);
  if S <> '' then
  begin
    Mask := Vcl.Graphics.TBitmap.Create;
    try
      Mask.PixelFormat := pf24bit;
      Mask.SetSize(ASize, ASize);
      Mask.Canvas.Brush.Color := clBlack;
      Mask.Canvas.FillRect(Rect(0, 0, ASize, ASize));
      if AFamily <> '' then
        Mask.Canvas.Font.Name := AFamily
      else
        Mask.Canvas.Font.Name := FmrIconFontFamily;
      Mask.Canvas.Font.Height := -Round(ASize * 0.8);
      Mask.Canvas.Font.Color := clWhite;
      Mask.Canvas.Font.Quality := fqAntialiased;
      Mask.Canvas.Brush.Style := bsClear;
      R := Rect(0, 0, ASize, ASize);
      DrawText(Mask.Canvas.Handle, PChar(S), Length(S), R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
      C := ColorToRGB(AColor);
      for Y := 0 to ASize - 1 do
      begin
        Src := Mask.ScanLine[Y];
        Dst := Result.ScanLine[Y];
        for X := 0 to ASize - 1 do
        begin
          A := Max(Src.rgbtRed, Max(Src.rgbtGreen, Src.rgbtBlue));
          Dst.rgbRed := GetRValue(C);
          Dst.rgbGreen := GetGValue(C);
          Dst.rgbBlue := GetBValue(C);
          Dst.rgbReserved := A;
          Inc(Src);
          Inc(Dst);
        end;
      end;
    finally
      Mask.Free;
    end;
  end;
  Result.AlphaFormat := afDefined;
end;

function FmrAddBitmap(const AImages: Vcl.ImgList.TCustomImageList; const ABitmap: Vcl.Graphics.TBitmap): Integer;
var
  B: Vcl.Graphics.TBitmap;
  X, Y: Integer;
  P: PRGBQuad;
  A: Integer;
begin
  B := Vcl.Graphics.TBitmap.Create;
  try
    B.PixelFormat := pf32bit;
    B.SetSize(AImages.Width, AImages.Height);
    B.AlphaFormat := afIgnored;
    for Y := 0 to B.Height - 1 do
      FillChar(B.ScanLine[Y]^, B.Width * 4, 0);
    // Premultiplied drawing into a transparent bitmap, then back to straight alpha for the image list.
    B.AlphaFormat := afPremultiplied;
    if (ABitmap.Width = B.Width) and (ABitmap.Height = B.Height) then
      B.Canvas.Draw(0, 0, ABitmap)
    else
      B.Canvas.StretchDraw(Rect(0, 0, B.Width, B.Height), ABitmap);
    B.AlphaFormat := afIgnored;
    for Y := 0 to B.Height - 1 do
    begin
      P := B.ScanLine[Y];
      for X := 0 to B.Width - 1 do
      begin
        A := P.rgbReserved;
        if (A > 0) and (A < 255) then
        begin
          P.rgbRed := Min(255, P.rgbRed * 255 div A);
          P.rgbGreen := Min(255, P.rgbGreen * 255 div A);
          P.rgbBlue := Min(255, P.rgbBlue * 255 div A);
        end;
        Inc(P);
      end;
    end;
    B.AlphaFormat := afDefined;
    Result := AImages.Add(B, nil);
  finally
    B.Free;
  end;
end;

function FmrAddGlyph(const AImages: Vcl.ImgList.TCustomImageList; const ACode: Cardinal; const AColor: TColor;
  const AFamily: string): Integer;
var
  B: Vcl.Graphics.TBitmap;
begin
  B := FmrGlyphBitmap(ACode, AImages.Width, AColor, AFamily);
  try
    Result := AImages.Add(B, nil);
  finally
    B.Free;
  end;
end;

procedure FmrDrawGlyphText(const ACanvas: Vcl.Graphics.TCanvas; const ARect: TRect; const ACode: Cardinal;
  const AFamily: string; const AColor: TColor; const AHeight: Integer);
var
  S: string;
  R: TRect;
begin
  S := GlyphString(ACode);
  if S = '' then
    Exit;
  ACanvas.Font.Name := AFamily;
  ACanvas.Font.Height := -AHeight;
  ACanvas.Font.Color := AColor;
  ACanvas.Font.Quality := fqClearType;
  ACanvas.Brush.Style := bsClear;
  R := ARect;
  DrawText(ACanvas.Handle, PChar(S), Length(S), R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

function FmxToVcl(const ASource: FMX.Graphics.TBitmap): Vcl.Graphics.TBitmap;
var
  Data: TBitmapData;
  Y, X: Integer;
  Dst: PRGBQuad;
  C: Cardinal;
  A: Integer;
begin
  Result := nil;
  if (ASource = nil) or ASource.IsEmpty then
    Exit;
  if not ASource.Map(TMapAccess.Read, Data) then
    Exit;
  try
    Result := Vcl.Graphics.TBitmap.Create;
    Result.PixelFormat := pf32bit;
    Result.SetSize(ASource.Width, ASource.Height);
    Result.AlphaFormat := afIgnored;
    for Y := 0 to ASource.Height - 1 do
    begin
      Dst := Result.ScanLine[Y];
      for X := 0 to ASource.Width - 1 do
      begin
        // Premultiplied FMX pixel → straight alpha.
        C := Data.GetPixel(X, Y);
        A := TAlphaColorRec(C).A;
        Dst.rgbReserved := A;
        if A = 0 then
        begin
          Dst.rgbRed := 0;
          Dst.rgbGreen := 0;
          Dst.rgbBlue := 0;
        end
        else
        begin
          Dst.rgbRed := Min(255, TAlphaColorRec(C).R * 255 div A);
          Dst.rgbGreen := Min(255, TAlphaColorRec(C).G * 255 div A);
          Dst.rgbBlue := Min(255, TAlphaColorRec(C).B * 255 div A);
        end;
        Inc(Dst);
      end;
    end;
    Result.AlphaFormat := afDefined;
  finally
    ASource.Unmap(Data);
  end;
end;

function FmrRenderImageSource(const AImage: TFmrImageSource; const AImages: FMX.ImgList.TCustomImageList;
  const ASize: Integer; const ATint: TAlphaColor): Vcl.Graphics.TBitmap;
var
  B: FMX.Graphics.TBitmap;
begin
  Result := nil;
  if (AImage = nil) or AImage.IsEmpty(AImages) then
    Exit;
  try
    B := FMX.Graphics.TBitmap.Create(ASize, ASize);
    try
      if B.Canvas.BeginScene then
      try
        B.Canvas.Clear(TAlphaColors.Null);
        AImage.Draw(B.Canvas, RectF(0, 0, ASize, ASize), 1, ATint, AImages);
      finally
        B.Canvas.EndScene;
      end;
      Result := FmxToVcl(B);
    finally
      B.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function FmrRenderImageListEntry(const AImages: FMX.ImgList.TCustomImageList; const AIndex, ASize: Integer)
  : Vcl.Graphics.TBitmap;
var
  B: FMX.Graphics.TBitmap;
begin
  Result := nil;
  if (AImages = nil) or (AIndex < 0) or (AIndex >= AImages.Count) then
    Exit;
  try
    B := AImages.Bitmap(TSizeF.Create(ASize, ASize), AIndex);
    if B <> nil then
      Result := FmxToVcl(B);
  except
    FreeAndNil(Result);
  end;
end;

function FmrIconFontGlyphs(const AFamily: string): TArray<Cardinal>;
type
  TRangeArray = array[0..65535] of TWCRange;
  PRangeArray = ^TRangeArray;
var
  Ranges: PRangeArray;
  DC: HDC;
  Font, OldFont: HFONT;
  Size: DWORD;
  GS: PGlyphSet;
  I: Integer;
  First, Last, C: Cardinal;
  L: TList<Cardinal>;
  LF: TLogFont;
begin
  Result := nil;
  L := TList<Cardinal>.Create;
  try
    DC := CreateCompatibleDC(0);
    try
      FillChar(LF, SizeOf(LF), 0);
      LF.lfHeight := -16;
      LF.lfCharSet := DEFAULT_CHARSET;
      StrPLCopy(LF.lfFaceName, AFamily, Length(LF.lfFaceName) - 1);
      Font := CreateFontIndirect(LF);
      OldFont := SelectObject(DC, Font);
      try
        Size := GetFontUnicodeRanges(DC, nil);
        if Size > 0 then
        begin
          GetMem(GS, Size);
          try
            GetFontUnicodeRanges(DC, GS);
            Ranges := PRangeArray(@GS.ranges[0]);
            for I := 0 to Integer(GS.cRanges) - 1 do
            begin
              First := Ord(Ranges[I].wcLow);
              Last := First + Cardinal(Ranges[I].cGlyphs);
              if Last > First then
                Dec(Last);
              for C := Max(First, Cardinal($E000)) to Min(Last, Cardinal($F8FF)) do
                L.Add(C);
            end;
          finally
            FreeMem(GS);
          end;
        end;
      finally
        SelectObject(DC, OldFont);
        DeleteObject(Font);
      end;
    finally
      DeleteDC(DC);
    end;
  except
    L.Clear;
  end;
  try
    if L.Count = 0 then
      for C := $E700 to $F8B3 do
        L.Add(C);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

const
  GlyphNameTable: array[0..257] of TFmrGlyphName = (
    (Code: $E700; Name: 'GlobalNavigation Menu Hamburger'),
    (Code: $E70D; Name: 'ChevronDown'),
    (Code: $E70E; Name: 'ChevronUp'),
    (Code: $E70F; Name: 'Edit Pencil'),
    (Code: $E710; Name: 'Add Plus New'),
    (Code: $E711; Name: 'Cancel Close X'),
    (Code: $E712; Name: 'More Ellipsis'),
    (Code: $E713; Name: 'Settings Gear Options'),
    (Code: $E714; Name: 'Video'),
    (Code: $E715; Name: 'Mail Email'),
    (Code: $E716; Name: 'People Users'),
    (Code: $E717; Name: 'Phone'),
    (Code: $E718; Name: 'Pin'),
    (Code: $E719; Name: 'Shop'),
    (Code: $E71A; Name: 'Stop'),
    (Code: $E71B; Name: 'Link Hyperlink'),
    (Code: $E71C; Name: 'Filter'),
    (Code: $E71D; Name: 'AllApps'),
    (Code: $E71E; Name: 'Zoom Magnifier'),
    (Code: $E71F; Name: 'ZoomOut'),
    (Code: $E720; Name: 'Microphone'),
    (Code: $E721; Name: 'Search Find'),
    (Code: $E722; Name: 'Camera'),
    (Code: $E723; Name: 'Attach Paperclip'),
    (Code: $E724; Name: 'Send'),
    (Code: $E72A; Name: 'Forward'),
    (Code: $E72B; Name: 'Back'),
    (Code: $E72C; Name: 'Refresh'),
    (Code: $E72D; Name: 'Share'),
    (Code: $E72E; Name: 'Lock'),
    (Code: $E734; Name: 'Favorite Star'),
    (Code: $E735; Name: 'FavoriteFill StarFill'),
    (Code: $E736; Name: 'ReadingMode Book'),
    (Code: $E737; Name: 'Window Favicon'),
    (Code: $E738; Name: 'Remove Minus Dash'),
    (Code: $E739; Name: 'Checkbox Square Border'),
    (Code: $E73E; Name: 'CheckMark Accept'),
    (Code: $E740; Name: 'FullScreen'),
    (Code: $E749; Name: 'Print Printer'),
    (Code: $E74A; Name: 'Up Arrow'),
    (Code: $E74B; Name: 'Down Arrow'),
    (Code: $E74D; Name: 'Delete Trash Bin'),
    (Code: $E74E; Name: 'Save Disk'),
    (Code: $E74F; Name: 'Mute'),
    (Code: $E751; Name: 'ReturnKey Enter Break'),
    (Code: $E753; Name: 'Cloud'),
    (Code: $E756; Name: 'CommandPrompt Console'),
    (Code: $E75A; Name: 'TextBox Rectangle'),
    (Code: $E75B; Name: 'Footer Bar'),
    (Code: $E75C; Name: 'EraseTool Eraser'),
    (Code: $E762; Name: 'MultiSelect Checklist'),
    (Code: $E767; Name: 'Volume'),
    (Code: $E768; Name: 'Play'),
    (Code: $E769; Name: 'Pause'),
    (Code: $E76B; Name: 'ChevronLeft'),
    (Code: $E76C; Name: 'ChevronRight'),
    (Code: $E76E; Name: 'Emoji Smiley Icons'),
    (Code: $E770; Name: 'System Laptop'),
    (Code: $E771; Name: 'Personalize Brush FormatPainter'),
    (Code: $E772; Name: 'Devices'),
    (Code: $E774; Name: 'Globe Web'),
    (Code: $E775; Name: 'TimeLanguage'),
    (Code: $E777; Name: 'UpdateRestore'),
    (Code: $E779; Name: 'ContactInfo'),
    (Code: $E77B; Name: 'Contact Person'),
    (Code: $E77F; Name: 'Paste Clipboard'),
    (Code: $E781; Name: 'LEDLight'),
    (Code: $E783; Name: 'Error'),
    (Code: $E785; Name: 'Unlock'),
    (Code: $E786; Name: 'Slideshow'),
    (Code: $E787; Name: 'Calendar'),
    (Code: $E789; Name: 'Megaphone'),
    (Code: $E78B; Name: 'NewWindow'),
    (Code: $E790; Name: 'Color Palette'),
    (Code: $E792; Name: 'SaveAs'),
    (Code: $E793; Name: 'Light Brightness'),
    (Code: $E799; Name: 'AspectRatio Margins'),
    (Code: $E7A6; Name: 'Redo'),
    (Code: $E7A7; Name: 'Undo'),
    (Code: $E7A8; Name: 'Crop'),
    (Code: $E7AD; Name: 'Rotate'),
    (Code: $E7B8; Name: 'Package Box'),
    (Code: $E7BA; Name: 'Warning'),
    (Code: $E7BE; Name: 'Education'),
    (Code: $E7BF; Name: 'ShoppingCart'),
    (Code: $E7C1; Name: 'Flag Bookmark'),
    (Code: $E7C3; Name: 'Page'),
    (Code: $E7C4; Name: 'TaskView Windows'),
    (Code: $E7C8; Name: 'Record'),
    (Code: $E7E6; Name: 'Highlight Marker'),
    (Code: $E7E8; Name: 'PowerButton'),
    (Code: $E7EF; Name: 'Admin'),
    (Code: $E7F4; Name: 'TVMonitor'),
    (Code: $E7F6; Name: 'Headphone'),
    (Code: $E7FC; Name: 'Game'),
    (Code: $E80A; Name: 'Table Grid'),
    (Code: $E80F; Name: 'Home House'),
    (Code: $E81C; Name: 'History'),
    (Code: $E81D; Name: 'Location'),
    (Code: $E81E; Name: 'MapLayers Layers'),
    (Code: $E821; Name: 'Work Briefcase'),
    (Code: $E823; Name: 'Recent Clock'),
    (Code: $E825; Name: 'Bank'),
    (Code: $E82D; Name: 'Dictionary Book'),
    (Code: $E82F; Name: 'ToolTip Lightbulb'),
    (Code: $E838; Name: 'FolderOpen'),
    (Code: $E83D; Name: 'DefenderApp Shield'),
    (Code: $E84A; Name: 'LowerCase abc'),
    (Code: $E84B; Name: 'UpperCase ChangeCase ABC'),
    (Code: $E890; Name: 'View Eye'),
    (Code: $E894; Name: 'Clear X'),
    (Code: $E895; Name: 'Sync'),
    (Code: $E896; Name: 'Download'),
    (Code: $E897; Name: 'Help Question'),
    (Code: $E898; Name: 'Upload'),
    (Code: $E899; Name: 'Emoji'),
    (Code: $E89A; Name: 'TwoPage Pages'),
    (Code: $E89F; Name: 'ClosePane'),
    (Code: $E8A0; Name: 'OpenPane NavigationPane'),
    (Code: $E8A1; Name: 'PreviewLink Layout WrapText'),
    (Code: $E8A3; Name: 'ZoomIn'),
    (Code: $E8A4; Name: 'Bookmarks List'),
    (Code: $E8A5; Name: 'Document New'),
    (Code: $E8A6; Name: 'ProtectedDocument'),
    (Code: $E8A7; Name: 'OpenInNewWindow External'),
    (Code: $E8A9; Name: 'ViewAll Grid Tiles'),
    (Code: $E8AB; Name: 'Switch Replace Swap'),
    (Code: $E8AC; Name: 'Rename'),
    (Code: $E8AD; Name: 'Go Arrow'),
    (Code: $E8B1; Name: 'Shuffle'),
    (Code: $E8B3; Name: 'SelectAll'),
    (Code: $E8B4; Name: 'Orientation'),
    (Code: $E8B5; Name: 'Import IncreaseIndent'),
    (Code: $E8B7; Name: 'Folder'),
    (Code: $E8B9; Name: 'Picture Image'),
    (Code: $E8BA; Name: 'Caption'),
    (Code: $E8BB; Name: 'ChromeClose X'),
    (Code: $E8BC; Name: 'ShowResults List'),
    (Code: $E8BD; Name: 'Message'),
    (Code: $E8C1; Name: 'Characters Symbol'),
    (Code: $E8C3; Name: 'Read Mail'),
    (Code: $E8C6; Name: 'Cut Scissors'),
    (Code: $E8C7; Name: 'PaymentCard Currency'),
    (Code: $E8C8; Name: 'Copy'),
    (Code: $E8C9; Name: 'Important'),
    (Code: $E8CA; Name: 'MailReply'),
    (Code: $E8CB; Name: 'Sort'),
    (Code: $E8D1; Name: 'GotoToday'),
    (Code: $E8D2; Name: 'Font Text'),
    (Code: $E8D3; Name: 'FontColor'),
    (Code: $E8D4; Name: 'Contact2'),
    (Code: $E8D5; Name: 'FolderFill'),
    (Code: $E8D6; Name: 'Audio Music'),
    (Code: $E8D7; Name: 'Permissions Key'),
    (Code: $E8DB; Name: 'Italic'),
    (Code: $E8DC; Name: 'Underline'),
    (Code: $E8DD; Name: 'Bold'),
    (Code: $E8DE; Name: 'MoveToFolder'),
    (Code: $E8E0; Name: 'Dislike'),
    (Code: $E8E1; Name: 'Like'),
    (Code: $E8E2; Name: 'AlignRight'),
    (Code: $E8E3; Name: 'AlignCenter'),
    (Code: $E8E4; Name: 'AlignLeft'),
    (Code: $E8E5; Name: 'OpenFile'),
    (Code: $E8E6; Name: 'ClearSelection'),
    (Code: $E8E7; Name: 'FontDecrease Shrink'),
    (Code: $E8E8; Name: 'FontIncrease Grow'),
    (Code: $E8E9; Name: 'FontSize'),
    (Code: $E8EC; Name: 'Tag'),
    (Code: $E8ED; Name: 'RepeatOne'),
    (Code: $E8EE; Name: 'RepeatAll'),
    (Code: $E8EF; Name: 'Calculator Sum'),
    (Code: $E8F1; Name: 'Library'),
    (Code: $E8F2; Name: 'ChatBubbles'),
    (Code: $E8F4; Name: 'NewFolder'),
    (Code: $E8FA; Name: 'AddFriend'),
    (Code: $E8FB; Name: 'Accept Check'),
    (Code: $E8FD; Name: 'BulletedList Bullets'),
    (Code: $E8FE; Name: 'Scan'),
    (Code: $E8FF; Name: 'Preview'),
    (Code: $E902; Name: 'Group'),
    (Code: $E90A; Name: 'Comment'),
    (Code: $E90F; Name: 'Repair Wrench'),
    (Code: $E910; Name: 'Accounts'),
    (Code: $E916; Name: 'Stopwatch'),
    (Code: $E917; Name: 'Clock'),
    (Code: $E91B; Name: 'Webcam Photo'),
    (Code: $E924; Name: 'Screenshot Clip'),
    (Code: $E92C; Name: 'BackToWindow'),
    (Code: $E92D; Name: 'FullScreen2'),
    (Code: $E943; Name: 'Code Braces Function'),
    (Code: $E946; Name: 'Info'),
    (Code: $E947; Name: 'Multiply'),
    (Code: $E948; Name: 'Plus IncreaseDecimal'),
    (Code: $E949; Name: 'Minus DecreaseDecimal'),
    (Code: $E94A; Name: 'Divide'),
    (Code: $E94B; Name: 'SquareRoot Equation'),
    (Code: $E94C; Name: 'Percent'),
    (Code: $E94E; Name: 'Equal'),
    (Code: $E97E; Name: 'Letter A DropCap'),
    (Code: $E9A6; Name: 'FitPage Size'),
    (Code: $E9AA; Name: 'ParagraphMark ShowHide'),
    (Code: $E9CA; Name: 'Thermometer'),
    (Code: $E9CE; Name: 'Unknown Question'),
    (Code: $E9D2; Name: 'AreaChart Chart'),
    (Code: $E9D5; Name: 'CheckList ConditionalFormatting'),
    (Code: $E9D9; Name: 'Diagnostic'),
    (Code: $E9E9; Name: 'Equalizer Sliders'),
    (Code: $E9F5; Name: 'Processing Gears'),
    (Code: $E9F9; Name: 'ReportDocument'),
    (Code: $EA37; Name: 'List'),
    (Code: $EA3C; Name: 'Merge'),
    (Code: $EA40; Name: 'MultilevelList'),
    (Code: $EA52; Name: 'DecreaseIndent'),
    (Code: $EA86; Name: 'Puzzle AddIns'),
    (Code: $EA90; Name: 'PDF'),
    (Code: $EA99; Name: 'Broom Clear'),
    (Code: $EABB; Name: 'Flowchart SmartArt'),
    (Code: $EAFC; Name: 'Trending LineChart'),
    (Code: $EB05; Name: 'PieChart'),
    (Code: $EB3C; Name: 'Design Ruler Pencil'),
    (Code: $EB42; Name: 'Droplet Shading Fill'),
    (Code: $EB51; Name: 'Heart'),
    (Code: $EB91; Name: 'Shapes Overlap'),
    (Code: $EB95; Name: 'Certificate'),
    (Code: $EB9F; Name: 'Pictures Photo'),
    (Code: $EC92; Name: 'DateTime'),
    (Code: $ECA5; Name: 'Tiles'),
    (Code: $ECE7; Name: 'LineSpacing UpDown'),
    (Code: $ED0E; Name: 'BlankPage NewNote'),
    (Code: $ED25; Name: 'OpenFolder'),
    (Code: $ED5E; Name: 'Ruler'),
    (Code: $ED60; Name: 'Eraser ClearFormatting'),
    (Code: $ED63; Name: 'Pencil Marker'),
    (Code: $ED6E; Name: 'Header Top'),
    (Code: $ED6F; Name: 'Position FreezePanes'),
    (Code: $EDE0; Name: 'Strikethrough'),
    (Code: $EDE1; Name: 'Export'),
    (Code: $EDFB; Name: 'FountainPen'),
    (Code: $EE40; Name: 'BringForward'),
    (Code: $EE47; Name: 'Expand'),
    (Code: $EE4D; Name: 'Columns TwoColumns'),
    (Code: $EE4E; Name: 'Split'),
    (Code: $EE4F; Name: 'Gridlines FourGrid'),
    (Code: $EE50; Name: 'SendBackward'),
    (Code: $EE56; Name: 'Signature'),
    (Code: $EE94; Name: 'Database GetData'),
    (Code: $EF60; Name: 'WordArt TextPen'),
    (Code: $EFDA; Name: 'InsertTable InsertCells'),
    (Code: $F003; Name: 'Relationship Share'),
    (Code: $F0E2; Name: 'GridView'),
    (Code: $F0E3; Name: 'ClipboardList'),
    (Code: $F111; Name: 'Comma Punctuation'),
    (Code: $F146; Name: 'Number1 PageNumber'),
    (Code: $F156; Name: 'Layers'),
    (Code: $F158; Name: 'Cube 3D'),
    (Code: $F168; Name: 'NumberedList Numbering'),
    (Code: $F404; Name: 'ColumnChart BarChart'));

function FmrGlyphNames: TArray<TFmrGlyphName>;
var
  I: Integer;
begin
  SetLength(Result, Length(GlyphNameTable));
  for I := 0 to High(GlyphNameTable) do
    Result[I] := GlyphNameTable[I];
end;

function FmrGlyphName(const ACode: Cardinal): string;
var
  N: TFmrGlyphName;
begin
  if GNameMap = nil then
  begin
    GNameMap := TDictionary<Cardinal, string>.Create;
    for N in FmrGlyphNames do
      GNameMap.AddOrSetValue(N.Code, N.Name);
  end;
  if not GNameMap.TryGetValue(ACode, Result) then
    Result := '';
end;

function FmrAlphaColorText(const AColor: TAlphaColor): string;
begin
  Result := '#' + IntToHex(AColor, 8);
end;

function FmrAlphaColorToColor(const AColor: TAlphaColor): TColor;
begin
  Result := RGB(TAlphaColorRec(AColor).R, TAlphaColorRec(AColor).G, TAlphaColorRec(AColor).B);
end;

function FmrColorToAlphaColor(const AColor: TColor): TAlphaColor;
var
  C: TColor;
begin
  C := ColorToRGB(AColor);
  Result := TAlphaColor($FF000000 or (Cardinal(GetRValue(C)) shl 16) or (Cardinal(GetGValue(C)) shl 8) or
    Cardinal(GetBValue(C)));
end;

initialization

finalization
  FreeAndNil(GNameMap);

end.
