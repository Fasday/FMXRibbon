{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Image sources of items: image list, SVG, glyph, path }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Bars.Images;

/// TFmrImageSource describes the icon of an item. It is drawn on any FMX canvas (Direct2D, GDI+, Skia,
/// FastCanvas): image list entries through TCustomImageList, SVG through a renderer that produces a bitmap (Skia by
/// default, cached per pixel size and tint), icon font glyphs with FillText and path data with FillPath.
/// Define FMR_NO_SKIA to build without Skia (SVG then needs a TFmrImageSource.SvgRenderer of your own).

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, FMX.Types,
  FMX.Graphics, FMX.ImgList;

type
  /// <summary>Which source an image is drawn from.</summary>
  TFmrImageKind = (
    /// <summary>Decided by what is set: SVG, then glyph, then path, then image list index.</summary>
    Auto,
    None,
    ImageList,
    Svg,
    Glyph,
    Path);

  /// <summary>Renders SVG text into a new bitmap of AWidth x AHeight pixels (aspect kept, centered). With ATint
  /// other than TAlphaColors.Null every pixel gets the tint color (alpha kept). Returns nil when the SVG cannot be
  /// rendered. The caller owns the bitmap.</summary>
  TFmrSvgRenderer = reference to function(const ASvg: string; const AWidth, AHeight: Integer;
    const ATint: TAlphaColor): TBitmap;

  /// <summary>Icon of an item (Glyph, LargeGlyph of bar items, images of gallery entries and screen tips).</summary>
  TFmrImageSource = class(TPersistent)
  private type
    TCacheEntry = class
      Kind: TFmrImageKind;
      Width, Height, Index: Integer;
      Color: TAlphaColor;
      Images: Pointer;
      Bitmap: TBitmap;
      destructor Destroy; override;
    end;
  private const
    MaxCacheEntries = 6;
  private class var
    FDefaultGlyphFontFamily: string;
    FSvgRenderer: TFmrSvgRenderer;
  private
    [Weak] FOwner: TPersistent;
    FKind: TFmrImageKind;
    FImageIndex: TImageIndex;
    FSvgSource: string;
    FGlyphFontFamily: string;
    FGlyphCode: Cardinal;
    FPathData: string;
    FPathViewBox: Single;
    FColor: TAlphaColor;
    FRecolor: Boolean;
    FOnChange: TNotifyEvent;
    FPath: TPathData;
    FScaledPath: TPathData;
    FScaledPathRect: TRectF;
    FCache: TObjectList<TCacheEntry>;
    procedure SetKind(const Value: TFmrImageKind);
    procedure SetImageIndex(const Value: TImageIndex);
    procedure SetSvgSource(const Value: string);
    procedure SetGlyphFontFamily(const Value: string);
    procedure SetGlyphCode(const Value: Cardinal);
    procedure SetPathData(const Value: string);
    procedure SetPathViewBox(const Value: Single);
    procedure SetColor(const Value: TAlphaColor);
    procedure SetRecolor(const Value: Boolean);
    function GetPath: TPathData;
    function FindCache(const AKind: TFmrImageKind; const AWidth, AHeight, AIndex: Integer; const AColor: TAlphaColor;
      const AImages: Pointer): TBitmap;
    procedure AddCache(const AKind: TFmrImageKind; const AWidth, AHeight, AIndex: Integer; const AColor: TAlphaColor;
      const AImages: Pointer; const ABitmap: TBitmap);
    procedure DrawImageList(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
      const AColor: TAlphaColor; const AImages: TCustomImageList);
    procedure DrawSvg(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single; const AColor: TAlphaColor);
    procedure DrawGlyph(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
      const AColor: TAlphaColor);
    procedure DrawPath(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single; const AColor: TAlphaColor);
    function IsPathViewBoxStored: Boolean;
  protected
    function GetOwner: TPersistent; override;
    procedure Changed; virtual;
  public
    constructor Create(const AOwner: TPersistent);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    /// <summary>True when both describe the same image.</summary>
    function SameAs(const AOther: TFmrImageSource): Boolean;
    /// <summary>The kind actually drawn (Auto resolved).</summary>
    function EffectiveKind: TFmrImageKind;
    /// <summary>True when nothing would be drawn. AImages is checked for the image list kind when given.</summary>
    function IsEmpty(const AImages: TCustomImageList = nil): Boolean;
    /// <summary>Draws the image into ARect (aspect kept, centered). ATint colors glyphs and paths (and SVG/image
    /// list images when Recolor is set) unless Color is set; Null means black.</summary>
    procedure Draw(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single; const ATint: TAlphaColor;
      const AImages: TCustomImageList);
    /// <summary>Releases cached bitmaps (SVG renderings, recolored image list images).</summary>
    procedure ClearCache;
    /// <summary>The glyph code as a string (empty when GlyphCode is 0 or invalid).</summary>
    function GlyphText: string;
    /// <summary>Parsed PathData (nil when empty).</summary>
    property Path: TPathData read GetPath;
    /// <summary>Icon font used when GlyphFontFamily is empty: 'Segoe Fluent Icons' on Windows 11,
    /// 'Segoe MDL2 Assets' on Windows 10.</summary>
    class property DefaultGlyphFontFamily: string read FDefaultGlyphFontFamily write FDefaultGlyphFontFamily;
    /// <summary>Renderer of SVG images; Skia by default (nil with FMR_NO_SKIA).</summary>
    class property SvgRenderer: TFmrSvgRenderer read FSvgRenderer write FSvgRenderer;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property Kind: TFmrImageKind read FKind write SetKind default TFmrImageKind.Auto;
    /// <summary>Index in the image list of the bar manager (or the list given to Draw).</summary>
    property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
    /// <summary>SVG document text.</summary>
    property SvgSource: string read FSvgSource write SetSvgSource;
    property GlyphFontFamily: string read FGlyphFontFamily write SetGlyphFontFamily;
    /// <summary>Unicode code point of the glyph in the icon font (e.g. $E8C8 = Copy in Segoe Fluent Icons).</summary>
    property GlyphCode: Cardinal read FGlyphCode write SetGlyphCode default 0;
    /// <summary>SVG path syntax ('M0,0 L10,10 ...').</summary>
    property PathData: string read FPathData write SetPathData;
    /// <summary>When greater than 0 the path is drawn as designed in a square 0..PathViewBox (like an SVG viewBox
    /// '0 0 24 24'); otherwise the bounds of the path are fitted into the rectangle.</summary>
    property PathViewBox: Single read FPathViewBox write SetPathViewBox stored IsPathViewBoxStored;
    /// <summary>Fixed color of glyphs and paths (and of SVG/image list images with Recolor); Null = the tint passed
    /// by the painter.</summary>
    property Color: TAlphaColor read FColor write SetColor default TAlphaColors.Null;
    /// <summary>Draws SVG and image list images as a single-color mask (colored by Color or the painter's tint).
    /// </summary>
    property Recolor: Boolean read FRecolor write SetRecolor default False;
  end;

/// <summary>New bitmap with every pixel of ASource in AColor, alpha kept (premultiplied).</summary>
function FmrRecolorBitmap(const ASource: TBitmap; const AColor: TAlphaColor): TBitmap;

implementation

uses
  System.Math, System.Character
  {$IFNDEF FMR_NO_SKIA}, System.Skia, FMX.Skia{$ENDIF};

function FmrRecolorBitmap(const ASource: TBitmap; const AColor: TAlphaColor): TBitmap;
var
  Src, Dst: TBitmapData;
  X, Y: Integer;
  A: Cardinal;
  C: TAlphaColorRec;
  Tint: TAlphaColorRec;
begin
  Result := TBitmap.Create(ASource.Width, ASource.Height);
  try
    Tint.Color := AColor;
    if ASource.Map(TMapAccess.Read, Src) then
    try
      if Result.Map(TMapAccess.Write, Dst) then
      try
        for Y := 0 to Src.Height - 1 do
          for X := 0 to Src.Width - 1 do
          begin
            A := TAlphaColorRec(Src.GetPixel(X, Y)).A * Tint.A div 255;
            C.A := A;
            C.R := Tint.R * A div 255;
            C.G := Tint.G * A div 255;
            C.B := Tint.B * A div 255;
            Dst.SetPixel(X, Y, C.Color);
          end;
      finally
        Result.Unmap(Dst);
      end;
    finally
      ASource.Unmap(Src);
    end;
  except
    Result.Free;
    raise;
  end;
end;

{$IFNDEF FMR_NO_SKIA}
function SkiaRenderSvg(const ASvg: string; const AWidth, AHeight: Integer; const ATint: TAlphaColor): TBitmap;
var
  DOM: ISkSVGDOM;
  Size: TSizeF;
  ViewBox: TRectF;
begin
  Result := nil;
  if (ASvg = '') or (AWidth < 1) or (AHeight < 1) then
    Exit;
  DOM := TSkSVGDOM.Make(ASvg);
  if DOM = nil then
    Exit;
  Size := DOM.Root.GetIntrinsicSize(TSizeF.Create(0, 0));
  if (Size.cx <= 0) or (Size.cy <= 0) then
  begin
    if DOM.Root.TryGetViewBox(ViewBox) and (ViewBox.Width > 0) and (ViewBox.Height > 0) then
    begin
      Size := ViewBox.Size;
      DOM.Root.Width := TSkSVGLength.Create(Size.cx, TSkSVGLengthUnit.Pixel);
      DOM.Root.Height := TSkSVGLength.Create(Size.cy, TSkSVGLengthUnit.Pixel);
    end
    else
    begin
      Size := TSizeF.Create(AWidth, AHeight);
      DOM.SetContainerSize(Size);
    end;
  end;
  Result := TBitmap.Create(AWidth, AHeight);
  try
    Result.SkiaDraw(
      procedure(const ACanvas: ISkCanvas)
      var
        Paint: ISkPaint;
        S: Single;
      begin
        S := Min(AWidth / Size.cx, AHeight / Size.cy);
        if ATint <> TAlphaColors.Null then
        begin
          Paint := TSkPaint.Create;
          Paint.ColorFilter := TSkColorFilter.MakeBlend(ATint, TSkBlendMode.SrcIn);
          ACanvas.SaveLayer(Paint);
        end
        else
          ACanvas.Save;
        try
          ACanvas.Translate((AWidth - Size.cx * S) / 2, (AHeight - Size.cy * S) / 2);
          ACanvas.Scale(S, S);
          DOM.Render(ACanvas);
        finally
          ACanvas.Restore;
        end;
      end);
  except
    FreeAndNil(Result);
  end;
end;
{$ENDIF}

{ TFmrImageSource.TCacheEntry }

destructor TFmrImageSource.TCacheEntry.Destroy;
begin
  Bitmap.Free;
  inherited;
end;

{ TFmrImageSource }

constructor TFmrImageSource.Create(const AOwner: TPersistent);
begin
  inherited Create;
  FOwner := AOwner;
  FImageIndex := -1;
  FColor := TAlphaColors.Null;
end;

destructor TFmrImageSource.Destroy;
begin
  FCache.Free;
  FPath.Free;
  FScaledPath.Free;
  inherited;
end;

function TFmrImageSource.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

procedure TFmrImageSource.Assign(Source: TPersistent);
var
  S: TFmrImageSource;
begin
  if Source is TFmrImageSource then
  begin
    S := TFmrImageSource(Source);
    if SameAs(S) then
      Exit;
    FKind := S.FKind;
    FImageIndex := S.FImageIndex;
    FSvgSource := S.FSvgSource;
    FGlyphFontFamily := S.FGlyphFontFamily;
    FGlyphCode := S.FGlyphCode;
    FPathData := S.FPathData;
    FPathViewBox := S.FPathViewBox;
    FColor := S.FColor;
    FRecolor := S.FRecolor;
    FreeAndNil(FPath);
    Changed;
  end
  else
    inherited;
end;

function TFmrImageSource.SameAs(const AOther: TFmrImageSource): Boolean;
begin
  Result := (AOther <> nil) and (FKind = AOther.FKind) and (FImageIndex = AOther.FImageIndex) and
    (FSvgSource = AOther.FSvgSource) and (FGlyphFontFamily = AOther.FGlyphFontFamily) and
    (FGlyphCode = AOther.FGlyphCode) and (FPathData = AOther.FPathData) and
    SameValue(FPathViewBox, AOther.FPathViewBox) and (FColor = AOther.FColor) and (FRecolor = AOther.FRecolor);
end;

procedure TFmrImageSource.Changed;
begin
  ClearCache;
  FreeAndNil(FScaledPath);
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TFmrImageSource.ClearCache;
begin
  if FCache <> nil then
    FCache.Clear;
end;

function TFmrImageSource.EffectiveKind: TFmrImageKind;
begin
  if FKind <> TFmrImageKind.Auto then
    Exit(FKind);
  if FSvgSource <> '' then
    Result := TFmrImageKind.Svg
  else if FGlyphCode <> 0 then
    Result := TFmrImageKind.Glyph
  else if FPathData <> '' then
    Result := TFmrImageKind.Path
  else if FImageIndex >= 0 then
    Result := TFmrImageKind.ImageList
  else
    Result := TFmrImageKind.None;
end;

function TFmrImageSource.IsEmpty(const AImages: TCustomImageList): Boolean;
begin
  case EffectiveKind of
    TFmrImageKind.ImageList:
      Result := (FImageIndex < 0) or ((AImages <> nil) and (FImageIndex >= AImages.Count));
    TFmrImageKind.Svg:
      Result := FSvgSource = '';
    TFmrImageKind.Glyph:
      Result := GlyphText = '';
    TFmrImageKind.Path:
      Result := FPathData.Trim = '';
  else
    Result := True;
  end;
end;

function TFmrImageSource.GlyphText: string;
begin
  if (FGlyphCode = 0) or (FGlyphCode > $10FFFF) or ((FGlyphCode >= $D800) and (FGlyphCode <= $DFFF)) then
    Result := ''
  else
    Result := Char.ConvertFromUtf32(UCS4Char(FGlyphCode));
end;

function TFmrImageSource.GetPath: TPathData;
begin
  if (FPath = nil) and (FPathData.Trim <> '') then
  begin
    FPath := TPathData.Create;
    try
      FPath.Data := FPathData;
    except
      FPath.Clear;
    end;
  end;
  Result := FPath;
end;

function TFmrImageSource.IsPathViewBoxStored: Boolean;
begin
  Result := FPathViewBox <> 0;
end;

procedure TFmrImageSource.SetKind(const Value: TFmrImageKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    Changed;
  end;
end;

procedure TFmrImageSource.SetImageIndex(const Value: TImageIndex);
begin
  if FImageIndex <> Value then
  begin
    FImageIndex := Value;
    Changed;
  end;
end;

procedure TFmrImageSource.SetSvgSource(const Value: string);
begin
  if FSvgSource <> Value then
  begin
    FSvgSource := Value;
    Changed;
  end;
end;

procedure TFmrImageSource.SetGlyphFontFamily(const Value: string);
begin
  if FGlyphFontFamily <> Value then
  begin
    FGlyphFontFamily := Value;
    Changed;
  end;
end;

procedure TFmrImageSource.SetGlyphCode(const Value: Cardinal);
begin
  if FGlyphCode <> Value then
  begin
    FGlyphCode := Value;
    Changed;
  end;
end;

procedure TFmrImageSource.SetPathData(const Value: string);
begin
  if FPathData <> Value then
  begin
    FPathData := Value;
    FreeAndNil(FPath);
    Changed;
  end;
end;

procedure TFmrImageSource.SetPathViewBox(const Value: Single);
begin
  if not SameValue(FPathViewBox, Value) then
  begin
    FPathViewBox := Max(0, Value);
    Changed;
  end;
end;

procedure TFmrImageSource.SetColor(const Value: TAlphaColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    Changed;
  end;
end;

procedure TFmrImageSource.SetRecolor(const Value: Boolean);
begin
  if FRecolor <> Value then
  begin
    FRecolor := Value;
    Changed;
  end;
end;

function TFmrImageSource.FindCache(const AKind: TFmrImageKind; const AWidth, AHeight, AIndex: Integer;
  const AColor: TAlphaColor; const AImages: Pointer): TBitmap;
var
  E: TCacheEntry;
begin
  if FCache <> nil then
    for E in FCache do
      if (E.Kind = AKind) and (E.Width = AWidth) and (E.Height = AHeight) and (E.Index = AIndex) and
        (E.Color = AColor) and (E.Images = AImages) then
        Exit(E.Bitmap);
  Result := nil;
end;

procedure TFmrImageSource.AddCache(const AKind: TFmrImageKind; const AWidth, AHeight, AIndex: Integer;
  const AColor: TAlphaColor; const AImages: Pointer; const ABitmap: TBitmap);
var
  E: TCacheEntry;
begin
  if FCache = nil then
    FCache := TObjectList<TCacheEntry>.Create(True);
  while FCache.Count >= MaxCacheEntries do
    FCache.Delete(0);
  E := TCacheEntry.Create;
  E.Kind := AKind;
  E.Width := AWidth;
  E.Height := AHeight;
  E.Index := AIndex;
  E.Color := AColor;
  E.Images := AImages;
  E.Bitmap := ABitmap;
  FCache.Add(E);
end;

procedure TFmrImageSource.Draw(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
  const ATint: TAlphaColor; const AImages: TCustomImageList);
var
  LColor: TAlphaColor;
begin
  if (ACanvas = nil) or (ARect.Width <= 0) or (ARect.Height <= 0) or (AOpacity <= 0) then
    Exit;
  if FColor <> TAlphaColors.Null then
    LColor := FColor
  else if ATint <> TAlphaColors.Null then
    LColor := ATint
  else
    LColor := TAlphaColors.Black;
  case EffectiveKind of
    TFmrImageKind.ImageList: DrawImageList(ACanvas, ARect, AOpacity, LColor, AImages);
    TFmrImageKind.Svg: DrawSvg(ACanvas, ARect, AOpacity, LColor);
    TFmrImageKind.Glyph: DrawGlyph(ACanvas, ARect, AOpacity, LColor);
    TFmrImageKind.Path: DrawPath(ACanvas, ARect, AOpacity, LColor);
  end;
end;

procedure TFmrImageSource.DrawImageList(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
  const AColor: TAlphaColor; const AImages: TCustomImageList);
var
  W, H: Integer;
  Source, Bmp: TBitmap;
  Dest: TRectF;
begin
  if (AImages = nil) or (FImageIndex < 0) or (FImageIndex >= AImages.Count) then
    Exit;
  if not FRecolor then
  begin
    AImages.Draw(ACanvas, ARect, FImageIndex, AOpacity);
    Exit;
  end;
  W := Max(1, Round(ARect.Width * ACanvas.Scale));
  H := Max(1, Round(ARect.Height * ACanvas.Scale));
  Bmp := FindCache(TFmrImageKind.ImageList, W, H, FImageIndex, AColor, AImages);
  if Bmp = nil then
  begin
    Source := AImages.Bitmap(TSizeF.Create(W, H), FImageIndex);
    if Source = nil then
      Exit;
    Bmp := FmrRecolorBitmap(Source, AColor);
    AddCache(TFmrImageKind.ImageList, W, H, FImageIndex, AColor, AImages, Bmp);
  end;
  Dest := TRectF.Create(0, 0, Bmp.Width / ACanvas.Scale, Bmp.Height / ACanvas.Scale);
  Dest := Dest.CenterAt(ARect);
  ACanvas.DrawBitmap(Bmp, TRectF.Create(0, 0, Bmp.Width, Bmp.Height), Dest, AOpacity, False);
end;

procedure TFmrImageSource.DrawSvg(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
  const AColor: TAlphaColor);
var
  W, H: Integer;
  Tint: TAlphaColor;
  Bmp: TBitmap;
begin
  if (FSvgSource = '') or not Assigned(FSvgRenderer) then
    Exit;
  W := Max(1, Round(ARect.Width * ACanvas.Scale));
  H := Max(1, Round(ARect.Height * ACanvas.Scale));
  if FRecolor then
    Tint := AColor
  else
    Tint := TAlphaColors.Null;
  Bmp := FindCache(TFmrImageKind.Svg, W, H, 0, Tint, nil);
  if Bmp = nil then
  begin
    Bmp := FSvgRenderer(FSvgSource, W, H, Tint);
    if Bmp = nil then
      Exit;
    AddCache(TFmrImageKind.Svg, W, H, 0, Tint, nil, Bmp);
  end;
  ACanvas.DrawBitmap(Bmp, TRectF.Create(0, 0, Bmp.Width, Bmp.Height), ARect, AOpacity, False);
end;

procedure TFmrImageSource.DrawGlyph(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
  const AColor: TAlphaColor);
var
  Text, Family: string;
  State: TCanvasSaveState;
begin
  Text := GlyphText;
  if Text = '' then
    Exit;
  Family := FGlyphFontFamily;
  if Family = '' then
    Family := FDefaultGlyphFontFamily;
  State := ACanvas.SaveState;
  try
    if Family <> '' then
      ACanvas.Font.Family := Family;
    ACanvas.Font.Size := Min(ARect.Width, ARect.Height);
    ACanvas.Font.Style := [];
    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := AColor;
    ACanvas.FillText(ARect, Text, False, AOpacity, [], TTextAlign.Center, TTextAlign.Center);
  finally
    ACanvas.RestoreState(State);
  end;
end;

procedure TFmrImageSource.DrawPath(const ACanvas: TCanvas; const ARect: TRectF; const AOpacity: Single;
  const AColor: TAlphaColor);
var
  P: TPathData;
  Box: TRectF;
  S: Single;
  State: TCanvasSaveState;
begin
  P := GetPath;
  if (P = nil) or P.IsEmpty then
    Exit;
  if (FScaledPath = nil) or (FScaledPathRect <> ARect) then
  begin
    if FPathViewBox > 0 then
      Box := TRectF.Create(0, 0, FPathViewBox, FPathViewBox)
    else
      Box := P.GetBounds;
    if (Box.Width <= 0) and (Box.Height <= 0) then
      Exit;
    if Box.Width <= 0 then
      S := ARect.Height / Box.Height
    else if Box.Height <= 0 then
      S := ARect.Width / Box.Width
    else
      S := Min(ARect.Width / Box.Width, ARect.Height / Box.Height);
    if FScaledPath = nil then
      FScaledPath := TPathData.Create;
    FScaledPath.Assign(P);
    FScaledPath.Translate(-Box.Left, -Box.Top);
    FScaledPath.Scale(S, S);
    FScaledPath.Translate(ARect.Left + (ARect.Width - Box.Width * S) / 2,
      ARect.Top + (ARect.Height - Box.Height * S) / 2);
    FScaledPathRect := ARect;
  end;
  State := ACanvas.SaveState;
  try
    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := AColor;
    ACanvas.FillPath(FScaledPath, AOpacity);
  finally
    ACanvas.RestoreState(State);
  end;
end;

initialization
  {$IFDEF MSWINDOWS}
  if (TOSVersion.Major > 10) or ((TOSVersion.Major = 10) and (TOSVersion.Build >= 22000)) then
    TFmrImageSource.DefaultGlyphFontFamily := 'Segoe Fluent Icons'
  else
    TFmrImageSource.DefaultGlyphFontFamily := 'Segoe MDL2 Assets';
  {$ENDIF}
  {$IFNDEF FMR_NO_SKIA}
  TFmrImageSource.SvgRenderer := SkiaRenderSvg;
  {$ENDIF}

end.
