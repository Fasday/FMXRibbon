{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Painter: draws ribbon parts from theme tokens        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Painter;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Math.Vectors, FMX.Types, FMX.Graphics,
  FMX.TextLayout, FMR.Ribbon.Theme;

type
  TFmrPartState = (Normal, Hot, Pressed, Checked, CheckedHot, Disabled);

  TFmrArrowDirection = (Down, Up, Left, Right);

  TFmrCaptionGlyph = (Minimize, Maximize, Restore, Close, Help, Pin, Unpin, More);

  /// <summary>Paints every part of the ribbon with canvas primitives and the tokens of a theme. Stateless apart
  /// from the theme and a few cached objects; all coordinates are local dp of the canvas.</summary>
  TFmrRibbonPainter = class
  private
    FTheme: TFmrTheme;
    FBrush: TBrush;
    FStroke: TStrokeBrush;
    FLayout: TTextLayout;
    FFont: TFont;
    procedure SetTheme(const AValue: TFmrTheme);
  public
    constructor Create(const ATheme: TFmrTheme);
    destructor Destroy; override;

    { primitives }
    procedure Fill(const ACanvas: TCanvas; const R: TRectF; const AFill: TFmrFill; const ARadius: Single = 0;
      const ACorners: TCorners = []; const AOpacity: Single = 1); overload;
    procedure Fill(const ACanvas: TCanvas; const R: TRectF; const AToken: TFmrToken; const ARadius: Single = 0;
      const ACorners: TCorners = []; const AOpacity: Single = 1); overload;
    procedure Frame(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor; const ARadius: Single = 0;
      const ACorners: TCorners = []; const AThickness: Single = 1; const AOpacity: Single = 1); overload;
    procedure Frame(const ACanvas: TCanvas; const R: TRectF; const AToken: TFmrToken; const ARadius: Single = 0;
      const ACorners: TCorners = []; const AThickness: Single = 1; const AOpacity: Single = 1); overload;
    procedure Line(const ACanvas: TCanvas; const P1, P2: TPointF; const AColor: TAlphaColor;
      const AThickness: Single = 1; const AOpacity: Single = 1);
    procedure Arrow(const ACanvas: TCanvas; const ACenter: TPointF; const ADirection: TFmrArrowDirection;
      const AColor: TAlphaColor; const ASize: Single = 0; const AOpacity: Single = 1);

    { text }
    procedure PrepareFont(const AFont: TFont; const ASize: Single = 0; const ABold: Boolean = False);
    function TextSize(const AText: string; const ASize: Single = 0; const ABold: Boolean = False;
      const AMaxWidth: Single = 0; const AWordWrap: Boolean = False): TSizeF;
    function TextWidth(const AText: string; const ASize: Single = 0; const ABold: Boolean = False): Single;
    procedure Text(const ACanvas: TCanvas; const R: TRectF; const AText: string; const AColor: TAlphaColor;
      const AHAlign: TTextAlign = TTextAlign.Center; const AVAlign: TTextAlign = TTextAlign.Center;
      const ASize: Single = 0; const ABold: Boolean = False; const AWordWrap: Boolean = False;
      const AOpacity: Single = 1);

    { ribbon parts }
    procedure DrawCaption(const ACanvas: TCanvas; const R: TRectF; const AActive: Boolean);
    procedure DrawCaptionButton(const ACanvas: TCanvas; const R: TRectF; const AGlyph: TFmrCaptionGlyph;
      const AState: TFmrPartState; const AActive: Boolean);
    procedure DrawCaptionGlyph(const ACanvas: TCanvas; const R: TRectF; const AGlyph: TFmrCaptionGlyph;
      const AColor: TAlphaColor);
    procedure DrawTabRow(const ACanvas: TCanvas; const R: TRectF; const AActive: Boolean);
    /// <summary>AContextColor <> 0: tab of a contextual tab group.</summary>
    procedure DrawTab(const ACanvas: TCanvas; const R: TRectF; const ACaption: string; const AHot, ASelected,
      AEnabled, ARibbonMinimized: Boolean; const AContextColor: TAlphaColor = 0);
    function TabTextColor(const AHot, ASelected, AEnabled: Boolean): TAlphaColor;
    procedure DrawContextGroupHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
      const AColor: TAlphaColor);
    procedure DrawAppButton(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
      const AState: TFmrPartState);
    procedure DrawBody(const ACanvas: TCanvas; const R: TRectF);
    procedure DrawGroup(const ACanvas: TCanvas; const R: TRectF; const ACaption: string; const AHot: Boolean;
      const ACaptionHeight: Single; const ALast: Boolean);
    procedure DrawGroupLauncher(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
    procedure DrawCollapsedGroup(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
    procedure DrawButton(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState;
      const ACorners: TCorners = []);
    /// <summary>Split button: AMain and AArrow are the two parts of R; each has its own state.</summary>
    procedure DrawSplitButton(const ACanvas: TCanvas; const R, AMain, AArrow: TRectF;
      const AMainState, AArrowState: TFmrPartState; const AVertical: Boolean);
    procedure DrawButtonGroupFrame(const ACanvas: TCanvas; const R: TRectF);
    procedure DrawSeparator(const ACanvas: TCanvas; const R: TRectF; const AVertical: Boolean = True);
    procedure DrawScrollButton(const ACanvas: TCanvas; const R: TRectF; const ADirection: TFmrArrowDirection;
      const AState: TFmrPartState);
    procedure DrawGalleryFrame(const ACanvas: TCanvas; const R: TRectF; const AHot: Boolean);
    procedure DrawGalleryItem(const ACanvas: TCanvas; const R: TRectF; const AHot, ASelected: Boolean);
    procedure DrawGalleryScroll(const ACanvas: TCanvas; const R: TRectF; const ADirection: TFmrArrowDirection;
      const AState: TFmrPartState; const AIsDropDown: Boolean);
    procedure DrawGalleryGroupHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string);
    procedure DrawMenuBackground(const ACanvas: TCanvas; const R: TRectF; const AGutterWidth: Single);
    procedure DrawMenuItem(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
    procedure DrawMenuSeparator(const ACanvas: TCanvas; const R: TRectF; const AGutterWidth: Single);
    procedure DrawMenuHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string);
    procedure DrawCheckMark(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor;
      const ARadio: Boolean = False);
    procedure DrawKeyTip(const ACanvas: TCanvas; const R: TRectF; const AText: string; const AEnabled: Boolean);
    function KeyTipSize(const AText: string): TSizeF;
    procedure DrawScreenTipBackground(const ACanvas: TCanvas; const R: TRectF);
    procedure DrawQATBelow(const ACanvas: TCanvas; const R: TRectF);
    procedure DrawSearchBox(const ACanvas: TCanvas; const R: TRectF; const AHot: Boolean);
    procedure DrawStatusBar(const ACanvas: TCanvas; const R: TRectF);
    procedure DrawEditFrame(const ACanvas: TCanvas; const R: TRectF; const AHot, AEnabled: Boolean);

    { state helpers }
    function ButtonTextColor(const AState: TFmrPartState): TAlphaColor;
    function GlyphTint(const AState: TFmrPartState): TAlphaColor;
    function ButtonFillToken(const AState: TFmrPartState; out ABorder: TFmrToken): TFmrToken;
    function Metrics: TFmrThemeMetrics; inline;

    property Theme: TFmrTheme read FTheme write SetTheme;
  end;

/// <summary>Snaps a coordinate to the pixel grid of AScale (crisp 1 px lines).</summary>
function FmrSnap(const AValue, AScale: Single): Single; inline;
/// <summary>A rect inset by half a pixel so 1 px strokes are crisp.</summary>
function FmrStrokeRect(const R: TRectF; const AThickness: Single = 1): TRectF; inline;

implementation

function FmrSnap(const AValue, AScale: Single): Single;
begin
  if AScale <= 0 then
    Result := Round(AValue)
  else
    Result := Round(AValue * AScale) / AScale;
end;

function FmrStrokeRect(const R: TRectF; const AThickness: Single): TRectF;
begin
  Result := R;
  Result.Inflate(-AThickness / 2, -AThickness / 2);
end;

{ TFmrRibbonPainter }

constructor TFmrRibbonPainter.Create(const ATheme: TFmrTheme);
begin
  inherited Create;
  FTheme := ATheme;
  FBrush := TBrush.Create(TBrushKind.Solid, TAlphaColors.Null);
  FStroke := TStrokeBrush.Create(TBrushKind.Solid, TAlphaColors.Null);
  FFont := TFont.Create;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;
end;

destructor TFmrRibbonPainter.Destroy;
begin
  FLayout.Free;
  FFont.Free;
  FStroke.Free;
  FBrush.Free;
  inherited;
end;

procedure TFmrRibbonPainter.SetTheme(const AValue: TFmrTheme);
begin
  FTheme := AValue;
end;

function TFmrRibbonPainter.Metrics: TFmrThemeMetrics;
begin
  Result := FTheme.Metrics;
end;

procedure TFmrRibbonPainter.Fill(const ACanvas: TCanvas; const R: TRectF; const AFill: TFmrFill;
  const ARadius: Single; const ACorners: TCorners; const AOpacity: Single);
var
  Corners: TCorners;
begin
  if not AFill.IsVisible or R.IsEmpty then
    Exit;
  AFill.ApplyTo(FBrush);
  Corners := ACorners;
  if (ARadius > 0) and (Corners = []) then
    Corners := AllCorners;
  if ARadius > 0 then
    ACanvas.FillRect(R, ARadius, ARadius, Corners, AOpacity, FBrush)
  else
    ACanvas.FillRect(R, 0, 0, [], AOpacity, FBrush);
end;

procedure TFmrRibbonPainter.Fill(const ACanvas: TCanvas; const R: TRectF; const AToken: TFmrToken;
  const ARadius: Single; const ACorners: TCorners; const AOpacity: Single);
begin
  Fill(ACanvas, R, FTheme.Fills[AToken], ARadius, ACorners, AOpacity);
end;

procedure TFmrRibbonPainter.Frame(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor;
  const ARadius: Single; const ACorners: TCorners; const AThickness, AOpacity: Single);
var
  Corners: TCorners;
begin
  if (TAlphaColorRec(AColor).A = 0) or R.IsEmpty then
    Exit;
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := AColor;
  FStroke.Thickness := AThickness;
  Corners := ACorners;
  if (ARadius > 0) and (Corners = []) then
    Corners := AllCorners;
  ACanvas.DrawRect(FmrStrokeRect(R, AThickness), ARadius, ARadius, Corners, AOpacity, FStroke);
end;

procedure TFmrRibbonPainter.Frame(const ACanvas: TCanvas; const R: TRectF; const AToken: TFmrToken;
  const ARadius: Single; const ACorners: TCorners; const AThickness, AOpacity: Single);
begin
  Frame(ACanvas, R, FTheme.Colors[AToken], ARadius, ACorners, AThickness, AOpacity);
end;

procedure TFmrRibbonPainter.Line(const ACanvas: TCanvas; const P1, P2: TPointF; const AColor: TAlphaColor;
  const AThickness, AOpacity: Single);
begin
  if TAlphaColorRec(AColor).A = 0 then
    Exit;
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := AColor;
  FStroke.Thickness := AThickness;
  FStroke.Cap := TStrokeCap.Flat;
  FStroke.Dash := TStrokeDash.Solid;
  ACanvas.DrawLine(P1, P2, AOpacity, FStroke);
end;

procedure TFmrRibbonPainter.Arrow(const ACanvas: TCanvas; const ACenter: TPointF;
  const ADirection: TFmrArrowDirection; const AColor: TAlphaColor; const ASize, AOpacity: Single);
var
  S, H: Single;
  P: TPolygon;
begin
  S := ASize;
  if S <= 0 then
    S := FTheme.Metrics.ArrowSize;
  H := S / 2;
  case ADirection of
    TFmrArrowDirection.Down:
      P := [PointF(ACenter.X - H, ACenter.Y - H / 2), PointF(ACenter.X + H, ACenter.Y - H / 2),
        PointF(ACenter.X, ACenter.Y + H / 2)];
    TFmrArrowDirection.Up:
      P := [PointF(ACenter.X - H, ACenter.Y + H / 2), PointF(ACenter.X + H, ACenter.Y + H / 2),
        PointF(ACenter.X, ACenter.Y - H / 2)];
    TFmrArrowDirection.Left:
      P := [PointF(ACenter.X + H / 2, ACenter.Y - H), PointF(ACenter.X + H / 2, ACenter.Y + H),
        PointF(ACenter.X - H / 2, ACenter.Y)];
    TFmrArrowDirection.Right:
      P := [PointF(ACenter.X - H / 2, ACenter.Y - H), PointF(ACenter.X - H / 2, ACenter.Y + H),
        PointF(ACenter.X + H / 2, ACenter.Y)];
  end;
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AColor;
  ACanvas.FillPolygon(P, AOpacity);
end;

{ text }

procedure TFmrRibbonPainter.PrepareFont(const AFont: TFont; const ASize: Single; const ABold: Boolean);
begin
  AFont.Family := FTheme.Metrics.FontFamily;
  if ASize > 0 then
    AFont.Size := ASize
  else
    AFont.Size := FTheme.Metrics.FontSize;
  if ABold then
    AFont.Style := [TFontStyle.fsBold]
  else
    AFont.Style := [];
end;

function TFmrRibbonPainter.TextSize(const AText: string; const ASize: Single; const ABold: Boolean;
  const AMaxWidth: Single; const AWordWrap: Boolean): TSizeF;
var
  R: TRectF;
begin
  if AText = '' then
    Exit(TSizeF.Create(0, 0));
  PrepareFont(FFont, ASize, ABold);
  FLayout.BeginUpdate;
  try
    FLayout.Font := FFont;
    FLayout.Text := AText;
    FLayout.WordWrap := AWordWrap;
    FLayout.Trimming := TTextTrimming.None;
    FLayout.HorizontalAlign := TTextAlign.Leading;
    FLayout.VerticalAlign := TTextAlign.Leading;
    if AMaxWidth > 0 then
      FLayout.MaxSize := TPointF.Create(AMaxWidth, 10000)
    else
      FLayout.MaxSize := TPointF.Create(10000, 10000);
  finally
    FLayout.EndUpdate;
  end;
  R := FLayout.TextRect;
  Result := TSizeF.Create(Ceil(R.Width), Ceil(R.Height));
end;

function TFmrRibbonPainter.TextWidth(const AText: string; const ASize: Single; const ABold: Boolean): Single;
begin
  Result := TextSize(AText, ASize, ABold).Width;
end;

procedure TFmrRibbonPainter.Text(const ACanvas: TCanvas; const R: TRectF; const AText: string;
  const AColor: TAlphaColor; const AHAlign, AVAlign: TTextAlign; const ASize: Single; const ABold, AWordWrap: Boolean;
  const AOpacity: Single);
begin
  if (AText = '') or (TAlphaColorRec(AColor).A = 0) or (R.Width <= 0) then
    Exit;
  PrepareFont(ACanvas.Font, ASize, ABold);
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AColor;
  if AWordWrap then
    ACanvas.FillText(R, AText, True, AOpacity, [], AHAlign, AVAlign)
  else
    ACanvas.FillText(R, AText, False, AOpacity, [], AHAlign, AVAlign);
end;

{ state helpers }

function TFmrRibbonPainter.ButtonFillToken(const AState: TFmrPartState; out ABorder: TFmrToken): TFmrToken;
begin
  case AState of
    TFmrPartState.Hot:
      begin
        Result := TFmrToken.ButtonHotFill;
        ABorder := TFmrToken.ButtonHotBorder;
      end;
    TFmrPartState.Pressed:
      begin
        Result := TFmrToken.ButtonPressedFill;
        ABorder := TFmrToken.ButtonPressedBorder;
      end;
    TFmrPartState.Checked:
      begin
        Result := TFmrToken.ButtonCheckedFill;
        ABorder := TFmrToken.ButtonCheckedBorder;
      end;
    TFmrPartState.CheckedHot:
      begin
        Result := TFmrToken.ButtonCheckedHotFill;
        ABorder := TFmrToken.ButtonCheckedBorder;
      end;
  else
    Result := TFmrToken.BodyFill;
    ABorder := TFmrToken.BodyFill;
  end;
end;

function TFmrRibbonPainter.ButtonTextColor(const AState: TFmrPartState): TAlphaColor;
begin
  if AState = TFmrPartState.Disabled then
    Result := FTheme.Colors[TFmrToken.ButtonTextDisabled]
  else
    Result := FTheme.Colors[TFmrToken.ButtonText];
end;

function TFmrRibbonPainter.GlyphTint(const AState: TFmrPartState): TAlphaColor;
begin
  if AState = TFmrPartState.Disabled then
    Result := FTheme.Colors[TFmrToken.GlyphTintDisabled]
  else
    Result := FTheme.Colors[TFmrToken.GlyphTint];
end;

{ caption }

procedure TFmrRibbonPainter.DrawCaption(const ACanvas: TCanvas; const R: TRectF; const AActive: Boolean);
begin
  if AActive then
    Fill(ACanvas, R, TFmrToken.CaptionFill)
  else
    Fill(ACanvas, R, TFmrToken.CaptionFillInactive);
end;

procedure TFmrRibbonPainter.DrawCaptionGlyph(const ACanvas: TCanvas; const R: TRectF; const AGlyph: TFmrCaptionGlyph;
  const AColor: TAlphaColor);
var
  C: TPointF;
  S, H: Single;
  B: TRectF;
begin
  C := R.CenterPoint;
  C.X := Round(C.X) + 0.5;
  C.Y := Round(C.Y) + 0.5;
  S := 10;
  H := S / 2;
  case AGlyph of
    TFmrCaptionGlyph.Minimize:
      Line(ACanvas, PointF(C.X - H, C.Y), PointF(C.X + H, C.Y), AColor);
    TFmrCaptionGlyph.Maximize:
      Frame(ACanvas, RectF(C.X - H - 0.5, C.Y - H - 0.5, C.X + H + 0.5, C.Y + H + 0.5), AColor, 1);
    TFmrCaptionGlyph.Restore:
      begin
        B := RectF(C.X - H - 0.5, C.Y - H + 1.5, C.X + H - 1.5, C.Y + H + 0.5);
        Frame(ACanvas, B, AColor, 1);
        Line(ACanvas, PointF(B.Left + 2, B.Top - 2), PointF(B.Right + 1, B.Top - 2), AColor);
        Line(ACanvas, PointF(B.Right + 2, B.Top - 2), PointF(B.Right + 2, B.Bottom - 2), AColor);
      end;
    TFmrCaptionGlyph.Close:
      begin
        Line(ACanvas, PointF(C.X - H, C.Y - H), PointF(C.X + H, C.Y + H), AColor);
        Line(ACanvas, PointF(C.X + H, C.Y - H), PointF(C.X - H, C.Y + H), AColor);
      end;
    TFmrCaptionGlyph.Help:
      Text(ACanvas, R, '?', AColor, TTextAlign.Center, TTextAlign.Center, 13);
    TFmrCaptionGlyph.Pin, TFmrCaptionGlyph.Unpin:
      Arrow(ACanvas, C, TFmrArrowDirection.Up, AColor, 8);
    TFmrCaptionGlyph.More:
      begin
        ACanvas.Fill.Kind := TBrushKind.Solid;
        ACanvas.Fill.Color := AColor;
        ACanvas.FillEllipse(RectF(C.X - 6, C.Y - 1, C.X - 4, C.Y + 1), 1);
        ACanvas.FillEllipse(RectF(C.X - 1, C.Y - 1, C.X + 1, C.Y + 1), 1);
        ACanvas.FillEllipse(RectF(C.X + 4, C.Y - 1, C.X + 6, C.Y + 1), 1);
      end;
  end;
end;

procedure TFmrRibbonPainter.DrawCaptionButton(const ACanvas: TCanvas; const R: TRectF;
  const AGlyph: TFmrCaptionGlyph; const AState: TFmrPartState; const AActive: Boolean);
var
  GlyphColor: TAlphaColor;
  Opacity: Single;
begin
  GlyphColor := FTheme.Colors[TFmrToken.CaptionButtonGlyph];
  if AGlyph = TFmrCaptionGlyph.Close then
  begin
    case AState of
      TFmrPartState.Hot:
        begin
          Fill(ACanvas, R, TFmrToken.CloseButtonHotFill);
          GlyphColor := FTheme.Colors[TFmrToken.CloseButtonHotGlyph];
        end;
      TFmrPartState.Pressed:
        begin
          Fill(ACanvas, R, TFmrToken.CloseButtonPressedFill);
          GlyphColor := FTheme.Colors[TFmrToken.CloseButtonHotGlyph];
        end;
    end;
  end
  else
    case AState of
      TFmrPartState.Hot:
        Fill(ACanvas, R, TFmrToken.CaptionButtonHotFill);
      TFmrPartState.Pressed:
        Fill(ACanvas, R, TFmrToken.CaptionButtonPressedFill);
    end;
  if AActive or (AState in [TFmrPartState.Hot, TFmrPartState.Pressed]) then
    Opacity := 1
  else
    Opacity := 0.45;
  if AState = TFmrPartState.Disabled then
    Opacity := 0.35;
  DrawCaptionGlyph(ACanvas, R, AGlyph, FmrWithAlpha(GlyphColor, Opacity * TAlphaColorRec(GlyphColor).A / 255));
end;

{ tabs }

procedure TFmrRibbonPainter.DrawTabRow(const ACanvas: TCanvas; const R: TRectF; const AActive: Boolean);
begin
  if FTheme.Style.ColoredCaption and not AActive then
    Fill(ACanvas, R, TFmrToken.CaptionFillInactive)
  else
    Fill(ACanvas, R, TFmrToken.TabRowFill);
end;

function TFmrRibbonPainter.TabTextColor(const AHot, ASelected, AEnabled: Boolean): TAlphaColor;
begin
  if not AEnabled then
    Result := FTheme.Colors[TFmrToken.TabTextDisabled]
  else if ASelected then
    Result := FTheme.Colors[TFmrToken.TabTextActive]
  else if AHot then
    Result := FTheme.Colors[TFmrToken.TabTextHot]
  else
    Result := FTheme.Colors[TFmrToken.TabText];
end;

procedure TFmrRibbonPainter.DrawTab(const ACanvas: TCanvas; const R: TRectF; const ACaption: string; const AHot,
  ASelected, AEnabled, ARibbonMinimized: Boolean; const AContextColor: TAlphaColor);
var
  Rad: Single;
  Shown: Boolean;
  TextR, Ind: TRectF;
  Caption: string;
  TextColor: TAlphaColor;
  W: Single;
begin
  Rad := FTheme.Metrics.TabRadius;
  // A selected tab of a minimized ribbon looks like a hot tab until its popup opens
  Shown := ASelected and not ARibbonMinimized;
  if AContextColor <> 0 then
  begin
    Fill(ACanvas, RectF(R.Left, R.Top, R.Right, R.Bottom), TFmrFill.Vertical([FmrWithAlpha(AContextColor, 0.35),
      FmrWithAlpha(AContextColor, 0.08)], []));
    Line(ACanvas, PointF(R.Left, R.Top + 0.5), PointF(R.Right, R.Top + 0.5), AContextColor, 2);
  end;
  case FTheme.Style.TabShape of
    TFmrTabShape.Rounded, TFmrTabShape.Box:
      if Shown then
      begin
        Fill(ACanvas, RectF(R.Left, R.Top, R.Right, R.Bottom + 1), TFmrToken.TabActiveFill, Rad,
          [TCorner.TopLeft, TCorner.TopRight]);
        if TAlphaColorRec(FTheme.Colors[TFmrToken.TabActiveBorder]).A > 0 then
        begin
          Line(ACanvas, PointF(R.Left + 0.5, R.Bottom), PointF(R.Left + 0.5, R.Top + Rad),
            FTheme.Colors[TFmrToken.TabActiveBorder]);
          Line(ACanvas, PointF(R.Right - 0.5, R.Bottom), PointF(R.Right - 0.5, R.Top + Rad),
            FTheme.Colors[TFmrToken.TabActiveBorder]);
          Line(ACanvas, PointF(R.Left + Rad, R.Top + 0.5), PointF(R.Right - Rad, R.Top + 0.5),
            FTheme.Colors[TFmrToken.TabActiveBorder]);
        end;
      end
      else if AHot and AEnabled then
        Fill(ACanvas, R, TFmrToken.TabHotFill, Rad, [TCorner.TopLeft, TCorner.TopRight]);
    TFmrTabShape.Underline:
      if AHot and AEnabled and not Shown then
        Fill(ACanvas, RectF(R.Left + 1, R.Top + 3, R.Right - 1, R.Bottom - 3), TFmrToken.TabHotFill, Rad);
  end;

  Caption := ACaption;
  if FTheme.Style.UppercaseTabs then
    Caption := Caption.ToUpper;
  TextColor := TabTextColor(AHot, Shown, AEnabled);
  if (AContextColor <> 0) and Shown and (FTheme.Style.TabShape <> TFmrTabShape.Underline) then
    TextColor := FmrDarken(AContextColor, 0.25);
  TextR := R;
  Text(ACanvas, TextR, Caption, TextColor, TTextAlign.Center, TTextAlign.Center, 0, False);

  if Shown and (FTheme.Style.TabShape = TFmrTabShape.Underline) then
  begin
    W := Min(TextWidth(Caption), R.Width - 8);
    Ind := RectF(R.CenterPoint.X - W / 2, R.Bottom - 5, R.CenterPoint.X + W / 2, R.Bottom - 2);
    if AContextColor <> 0 then
      Fill(ACanvas, Ind, TFmrFill.Solid(AContextColor), 1.5)
    else
      Fill(ACanvas, Ind, TFmrToken.TabActiveIndicator, 1.5);
  end;
end;

procedure TFmrRibbonPainter.DrawContextGroupHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
  const AColor: TAlphaColor);
begin
  Fill(ACanvas, R, TFmrFill.Vertical([FmrWithAlpha(AColor, 0.55), FmrWithAlpha(AColor, 0.25)], []));
  Line(ACanvas, PointF(R.Left, R.Top + 1.5), PointF(R.Right, R.Top + 1.5), AColor, 3);
  Text(ACanvas, RectF(R.Left + 6, R.Top + 3, R.Right - 6, R.Bottom), ACaption,
    FTheme.Colors[TFmrToken.CaptionText], TTextAlign.Center, TTextAlign.Center);
end;

procedure TFmrRibbonPainter.DrawAppButton(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
  const AState: TFmrPartState);
var
  Token: TFmrToken;
  Orb: TRectF;
  D: Single;
begin
  case AState of
    TFmrPartState.Hot:
      Token := TFmrToken.AppButtonHotFill;
    TFmrPartState.Pressed, TFmrPartState.Checked, TFmrPartState.CheckedHot:
      Token := TFmrToken.AppButtonPressedFill;
  else
    Token := TFmrToken.AppButtonFill;
  end;
  case FTheme.Style.AppButton of
    TFmrAppButtonShape.Orb:
      begin
        D := Min(R.Width, R.Height);
        Orb := RectF(R.CenterPoint.X - D / 2, R.CenterPoint.Y - D / 2, R.CenterPoint.X + D / 2, R.CenterPoint.Y + D / 2);
        FTheme.Fills[Token].ApplyTo(FBrush);
        ACanvas.FillEllipse(Orb, 1, FBrush);
        FStroke.Kind := TBrushKind.Solid;
        FStroke.Color := FTheme.Colors[TFmrToken.AppButtonBorder];
        FStroke.Thickness := 1;
        ACanvas.DrawEllipse(FmrStrokeRect(Orb), 1, FStroke);
        // inner highlight
        Orb.Inflate(-D * 0.12, -D * 0.12);
        Orb.Bottom := Orb.Top + Orb.Height * 0.5;
        FBrush.Kind := TBrushKind.Gradient;
        FBrush.Gradient.Style := TGradientStyle.Linear;
        FBrush.Gradient.StartPosition.Point := PointF(0, 0);
        FBrush.Gradient.StopPosition.Point := PointF(0, 1);
        FBrush.Gradient.Points.Clear;
        with TGradientPoint(FBrush.Gradient.Points.Add) do
        begin
          Color := $A0FFFFFF;
          Offset := 0;
        end;
        with TGradientPoint(FBrush.Gradient.Points.Add) do
        begin
          Color := $10FFFFFF;
          Offset := 1;
        end;
        ACanvas.FillEllipse(Orb, 1, FBrush);
        Text(ACanvas, R, ACaption, FTheme.Colors[TFmrToken.AppButtonText], TTextAlign.Center, TTextAlign.Center,
          0, True);
      end;
    TFmrAppButtonShape.ColoredTab:
      begin
        Fill(ACanvas, R, Token, FTheme.Metrics.TabRadius, [TCorner.TopLeft, TCorner.TopRight]);
        Text(ACanvas, R, ACaption, FTheme.Colors[TFmrToken.AppButtonText]);
      end;
  else
    begin
      if AState in [TFmrPartState.Hot, TFmrPartState.Pressed, TFmrPartState.Checked, TFmrPartState.CheckedHot] then
        Fill(ACanvas, RectF(R.Left + 1, R.Top + 2, R.Right - 1, R.Bottom - 2), Token, FTheme.Metrics.TabRadius)
      else
        Fill(ACanvas, R, Token);
      Text(ACanvas, R, ACaption, FTheme.Colors[TFmrToken.AppButtonText]);
    end;
  end;
end;

{ body and groups }

procedure TFmrRibbonPainter.DrawBody(const ACanvas: TCanvas; const R: TRectF);
var
  Rad: Single;
  B: TRectF;
begin
  Rad := FTheme.Metrics.BodyRadius;
  B := R;
  if FTheme.Style.FloatingBody then
  begin
    // soft shadow under the card
    Fill(ACanvas, RectF(B.Left, B.Top + 1, B.Right, B.Bottom + 1.5), TFmrToken.BodyShadow, Rad + 1);
    Fill(ACanvas, B, TFmrToken.BodyFill, Rad);
    Frame(ACanvas, B, TFmrToken.BodyBorder, Rad);
  end
  else
  begin
    Fill(ACanvas, B, TFmrToken.BodyFill, Rad, [TCorner.BottomLeft, TCorner.BottomRight]);
    Line(ACanvas, PointF(B.Left, B.Top + 0.5), PointF(B.Right, B.Top + 0.5), FTheme.Colors[TFmrToken.BodyBorder]);
    Line(ACanvas, PointF(B.Left, B.Bottom - 0.5), PointF(B.Right, B.Bottom - 0.5),
      FTheme.Colors[TFmrToken.BodyBorder]);
  end;
end;

procedure TFmrRibbonPainter.DrawGroup(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
  const AHot: Boolean; const ACaptionHeight: Single; const ALast: Boolean);
var
  Rad: Single;
  CapR: TRectF;
begin
  Rad := FTheme.Metrics.GroupRadius;
  CapR := RectF(R.Left, R.Bottom - ACaptionHeight, R.Right, R.Bottom);
  if FTheme.Style.GroupFrame = TFmrGroupFrame.Boxed then
  begin
    if AHot then
      Fill(ACanvas, R, TFmrToken.GroupHotFill, Rad)
    else
      Fill(ACanvas, R, TFmrToken.GroupFill, Rad);
    Fill(ACanvas, CapR, TFmrToken.GroupCaptionFill, Rad, [TCorner.BottomLeft, TCorner.BottomRight]);
    Frame(ACanvas, R, TFmrToken.GroupBorder, Rad);
  end
  else if not ALast or True then
    Line(ACanvas, PointF(R.Right - 0.5, R.Top + 4), PointF(R.Right - 0.5, R.Bottom - 4),
      FTheme.Colors[TFmrToken.GroupSeparator]);
  Text(ACanvas, RectF(CapR.Left + 4, CapR.Top, CapR.Right - 4, CapR.Bottom - 1), ACaption,
    FTheme.Colors[TFmrToken.GroupCaptionText], TTextAlign.Center, TTextAlign.Center,
    FTheme.Metrics.GroupCaptionFontSize);
end;

procedure TFmrRibbonPainter.DrawGroupLauncher(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
var
  C: TPointF;
  Col: TAlphaColor;
begin
  DrawButton(ACanvas, R, AState);
  C := R.CenterPoint;
  Col := FTheme.Colors[TFmrToken.GroupLauncherGlyph];
  Line(ACanvas, PointF(C.X - 3.5, C.Y - 3.5), PointF(C.X + 1, C.Y - 3.5), Col);
  Line(ACanvas, PointF(C.X - 3.5, C.Y - 3.5), PointF(C.X - 3.5, C.Y + 1), Col);
  Line(ACanvas, PointF(C.X - 2, C.Y - 2), PointF(C.X + 3, C.Y + 3), Col);
  Line(ACanvas, PointF(C.X + 3.5, C.Y), PointF(C.X + 3.5, C.Y + 3.5), Col);
  Line(ACanvas, PointF(C.X, C.Y + 3.5), PointF(C.X + 3.5, C.Y + 3.5), Col);
end;

procedure TFmrRibbonPainter.DrawCollapsedGroup(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
var
  Rad: Single;
begin
  Rad := Max(FTheme.Metrics.GroupRadius, FTheme.Metrics.ButtonRadius);
  case AState of
    TFmrPartState.Hot:
      Fill(ACanvas, R, TFmrToken.GroupCollapsedHotFill, Rad);
    TFmrPartState.Pressed, TFmrPartState.Checked, TFmrPartState.CheckedHot:
      Fill(ACanvas, R, TFmrToken.ButtonPressedFill, Rad);
  else
    Fill(ACanvas, R, TFmrToken.GroupCollapsedFill, Rad);
  end;
  if FTheme.Style.GroupFrame = TFmrGroupFrame.Boxed then
    Frame(ACanvas, R, TFmrToken.GroupBorder, Rad);
end;

{ buttons }

procedure TFmrRibbonPainter.DrawButton(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState;
  const ACorners: TCorners);
var
  F, B: TFmrToken;
  Rad: Single;
  Corners: TCorners;
begin
  if AState in [TFmrPartState.Normal, TFmrPartState.Disabled] then
    Exit;
  F := ButtonFillToken(AState, B);
  Rad := FTheme.Metrics.ButtonRadius;
  Corners := ACorners;
  if Corners = [] then
    Corners := AllCorners;
  Fill(ACanvas, R, F, Rad, Corners);
  Frame(ACanvas, R, B, Rad, Corners);
end;

procedure TFmrRibbonPainter.DrawSplitButton(const ACanvas: TCanvas; const R, AMain, AArrow: TRectF;
  const AMainState, AArrowState: TFmrPartState; const AVertical: Boolean);
var
  Outer: TFmrPartState;
begin
  // When one part is hot the other is outlined lighter (Office behavior): paint the whole frame hot, then the
  // pressed/hot part on top.
  if (AMainState in [TFmrPartState.Normal, TFmrPartState.Disabled]) and
    (AArrowState in [TFmrPartState.Normal, TFmrPartState.Disabled]) then
    Exit;
  if (AMainState in [TFmrPartState.Checked, TFmrPartState.CheckedHot]) then
    Outer := AMainState
  else
    Outer := TFmrPartState.Hot;
  DrawButton(ACanvas, R, Outer);
  if AMainState in [TFmrPartState.Pressed] then
    if AVertical then
      DrawButton(ACanvas, AMain, AMainState, [TCorner.TopLeft, TCorner.TopRight])
    else
      DrawButton(ACanvas, AMain, AMainState, [TCorner.TopLeft, TCorner.BottomLeft]);
  if AArrowState in [TFmrPartState.Pressed, TFmrPartState.Hot] then
    if AVertical then
      DrawButton(ACanvas, AArrow, AArrowState, [TCorner.BottomLeft, TCorner.BottomRight])
    else
      DrawButton(ACanvas, AArrow, AArrowState, [TCorner.TopRight, TCorner.BottomRight]);
  if AVertical then
    Line(ACanvas, PointF(R.Left + 2, AArrow.Top + 0.5), PointF(R.Right - 2, AArrow.Top + 0.5),
      FTheme.Colors[TFmrToken.ButtonSplitLine])
  else
    Line(ACanvas, PointF(AArrow.Left + 0.5, R.Top + 2), PointF(AArrow.Left + 0.5, R.Bottom - 2),
      FTheme.Colors[TFmrToken.ButtonSplitLine]);
end;

procedure TFmrRibbonPainter.DrawButtonGroupFrame(const ACanvas: TCanvas; const R: TRectF);
begin
  Fill(ACanvas, R, TFmrToken.ButtonGroupFill, FTheme.Metrics.ButtonRadius);
  Frame(ACanvas, R, TFmrToken.ButtonGroupBorder, FTheme.Metrics.ButtonRadius);
end;

procedure TFmrRibbonPainter.DrawSeparator(const ACanvas: TCanvas; const R: TRectF; const AVertical: Boolean);
var
  X, Y: Single;
begin
  if AVertical then
  begin
    X := Round(R.CenterPoint.X) + 0.5;
    Line(ACanvas, PointF(X, R.Top), PointF(X, R.Bottom), FTheme.Colors[TFmrToken.GroupSeparator]);
  end
  else
  begin
    Y := Round(R.CenterPoint.Y) + 0.5;
    Line(ACanvas, PointF(R.Left, Y), PointF(R.Right, Y), FTheme.Colors[TFmrToken.GroupSeparator]);
  end;
end;

procedure TFmrRibbonPainter.DrawScrollButton(const ACanvas: TCanvas; const R: TRectF;
  const ADirection: TFmrArrowDirection; const AState: TFmrPartState);
begin
  if AState in [TFmrPartState.Hot, TFmrPartState.Pressed] then
    Fill(ACanvas, R, TFmrToken.ScrollButtonHotFill, FTheme.Metrics.ButtonRadius)
  else
    Fill(ACanvas, R, TFmrToken.ScrollButtonFill, FTheme.Metrics.ButtonRadius);
  Frame(ACanvas, R, TFmrToken.BodyBorder, FTheme.Metrics.ButtonRadius);
  Arrow(ACanvas, R.CenterPoint, ADirection, FTheme.Colors[TFmrToken.ScrollButtonGlyph]);
end;

{ galleries }

procedure TFmrRibbonPainter.DrawGalleryFrame(const ACanvas: TCanvas; const R: TRectF; const AHot: Boolean);
begin
  Fill(ACanvas, R, TFmrToken.GalleryFill, FTheme.Metrics.ButtonRadius);
  if AHot then
    Frame(ACanvas, R, TFmrToken.EditBorderHot, FTheme.Metrics.ButtonRadius)
  else
    Frame(ACanvas, R, TFmrToken.GalleryBorder, FTheme.Metrics.ButtonRadius);
end;

procedure TFmrRibbonPainter.DrawGalleryItem(const ACanvas: TCanvas; const R: TRectF; const AHot, ASelected: Boolean);
var
  Rad: Single;
begin
  Rad := FTheme.Metrics.ButtonRadius;
  if ASelected then
  begin
    Fill(ACanvas, R, TFmrToken.GalleryItemSelectedFill, Rad);
    Frame(ACanvas, R, TFmrToken.GalleryItemSelectedBorder, Rad, [], 1.5);
  end;
  if AHot then
  begin
    if not ASelected then
      Fill(ACanvas, R, TFmrToken.GalleryItemHotFill, Rad);
    Frame(ACanvas, R, TFmrToken.GalleryItemHotBorder, Rad);
  end;
end;

procedure TFmrRibbonPainter.DrawGalleryScroll(const ACanvas: TCanvas; const R: TRectF;
  const ADirection: TFmrArrowDirection; const AState: TFmrPartState; const AIsDropDown: Boolean);
var
  C: TPointF;
  Col: TAlphaColor;
begin
  if AState in [TFmrPartState.Hot, TFmrPartState.Pressed] then
    Fill(ACanvas, R, TFmrToken.GalleryScrollHotFill)
  else
    Fill(ACanvas, R, TFmrToken.GalleryScrollFill);
  Col := FTheme.Colors[TFmrToken.GalleryScrollGlyph];
  if AState = TFmrPartState.Disabled then
    Col := FTheme.Colors[TFmrToken.ButtonTextDisabled];
  C := R.CenterPoint;
  if AIsDropDown then
  begin
    Line(ACanvas, PointF(C.X - 3, C.Y - 3.5), PointF(C.X + 3, C.Y - 3.5), Col);
    Arrow(ACanvas, PointF(C.X, C.Y + 1), TFmrArrowDirection.Down, Col);
  end
  else
    Arrow(ACanvas, C, ADirection, Col);
end;

procedure TFmrRibbonPainter.DrawGalleryGroupHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string);
begin
  Fill(ACanvas, R, TFmrToken.GalleryGroupHeaderFill);
  Text(ACanvas, RectF(R.Left + 8, R.Top, R.Right - 8, R.Bottom), ACaption,
    FTheme.Colors[TFmrToken.GalleryGroupHeaderText], TTextAlign.Leading, TTextAlign.Center, 0, True);
end;

{ menus }

procedure TFmrRibbonPainter.DrawMenuBackground(const ACanvas: TCanvas; const R: TRectF; const AGutterWidth: Single);
var
  Rad: Single;
begin
  Rad := FTheme.Metrics.MenuRadius;
  Fill(ACanvas, R, TFmrToken.MenuFill, Rad);
  if AGutterWidth > 0 then
    Fill(ACanvas, RectF(R.Left + 1, R.Top + 1, R.Left + AGutterWidth, R.Bottom - 1), TFmrToken.MenuGutterFill);
  Frame(ACanvas, R, TFmrToken.MenuBorder, Rad);
end;

procedure TFmrRibbonPainter.DrawMenuItem(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
var
  Rad: Single;
  Inner: TRectF;
begin
  if not (AState in [TFmrPartState.Hot, TFmrPartState.Pressed]) then
    Exit;
  Rad := Max(FTheme.Metrics.MenuRadius - 2, FTheme.Metrics.ButtonRadius);
  Inner := R;
  if FTheme.Metrics.MenuRadius > 0 then
    Inner.Inflate(-4, -1);
  Fill(ACanvas, Inner, TFmrToken.MenuItemHotFill, Rad);
  Frame(ACanvas, Inner, TFmrToken.MenuItemHotBorder, Rad);
end;

procedure TFmrRibbonPainter.DrawMenuSeparator(const ACanvas: TCanvas; const R: TRectF; const AGutterWidth: Single);
var
  Y: Single;
begin
  Y := Round(R.CenterPoint.Y) + 0.5;
  Line(ACanvas, PointF(R.Left + AGutterWidth + 4, Y), PointF(R.Right - 4, Y), FTheme.Colors[TFmrToken.MenuSeparator]);
end;

procedure TFmrRibbonPainter.DrawMenuHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string);
begin
  Fill(ACanvas, R, TFmrToken.MenuHeaderFill);
  Text(ACanvas, RectF(R.Left + 8, R.Top, R.Right - 8, R.Bottom), ACaption, FTheme.Colors[TFmrToken.MenuHeaderText],
    TTextAlign.Leading, TTextAlign.Center, 0, True);
end;

procedure TFmrRibbonPainter.DrawCheckMark(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor;
  const ARadio: Boolean);
var
  C: TPointF;
begin
  C := R.CenterPoint;
  if ARadio then
  begin
    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := AColor;
    ACanvas.FillEllipse(RectF(C.X - 3, C.Y - 3, C.X + 3, C.Y + 3), 1);
  end
  else
  begin
    FStroke.Kind := TBrushKind.Solid;
    FStroke.Color := AColor;
    FStroke.Thickness := 1.5;
    FStroke.Cap := TStrokeCap.Round;
    FStroke.Join := TStrokeJoin.Round;
    ACanvas.DrawLine(PointF(C.X - 4, C.Y), PointF(C.X - 1.5, C.Y + 3), 1, FStroke);
    ACanvas.DrawLine(PointF(C.X - 1.5, C.Y + 3), PointF(C.X + 4, C.Y - 3.5), 1, FStroke);
    FStroke.Cap := TStrokeCap.Flat;
  end;
end;

{ tips }

function TFmrRibbonPainter.KeyTipSize(const AText: string): TSizeF;
var
  S: TSizeF;
begin
  S := TextSize(AText, FTheme.Metrics.FontSize - 1);
  Result := TSizeF.Create(Max(S.Width + 8, 16), S.Height + 4);
end;

procedure TFmrRibbonPainter.DrawKeyTip(const ACanvas: TCanvas; const R: TRectF; const AText: string;
  const AEnabled: Boolean);
var
  Op: Single;
begin
  if AEnabled then
    Op := 1
  else
    Op := 0.55;
  Fill(ACanvas, R, TFmrToken.KeyTipFill, FTheme.Metrics.KeyTipRadius, [], Op);
  Frame(ACanvas, R, TFmrToken.KeyTipBorder, FTheme.Metrics.KeyTipRadius, [], 1, Op);
  Text(ACanvas, R, AText, FTheme.Colors[TFmrToken.KeyTipText], TTextAlign.Center, TTextAlign.Center,
    FTheme.Metrics.FontSize - 1, False, False, Op);
end;

procedure TFmrRibbonPainter.DrawScreenTipBackground(const ACanvas: TCanvas; const R: TRectF);
begin
  Fill(ACanvas, R, TFmrToken.ScreenTipFill, FTheme.Metrics.MenuRadius);
  Frame(ACanvas, R, TFmrToken.ScreenTipBorder, FTheme.Metrics.MenuRadius);
end;

{ misc }

procedure TFmrRibbonPainter.DrawQATBelow(const ACanvas: TCanvas; const R: TRectF);
begin
  Fill(ACanvas, R, TFmrToken.QATBelowFill);
  Line(ACanvas, PointF(R.Left, R.Bottom - 0.5), PointF(R.Right, R.Bottom - 0.5), FTheme.Colors[TFmrToken.QATBorder]);
end;

procedure TFmrRibbonPainter.DrawSearchBox(const ACanvas: TCanvas; const R: TRectF; const AHot: Boolean);
var
  Rad: Single;
begin
  Rad := Max(FTheme.Metrics.ButtonRadius, 4);
  if AHot then
    Fill(ACanvas, R, TFmrToken.SearchBoxHotFill, Rad)
  else
    Fill(ACanvas, R, TFmrToken.SearchBoxFill, Rad);
  Frame(ACanvas, R, TFmrToken.SearchBoxBorder, Rad);
end;

procedure TFmrRibbonPainter.DrawStatusBar(const ACanvas: TCanvas; const R: TRectF);
begin
  Fill(ACanvas, R, TFmrToken.StatusBarFill);
  Line(ACanvas, PointF(R.Left, R.Top + 0.5), PointF(R.Right, R.Top + 0.5), FTheme.Colors[TFmrToken.StatusBarSeparator]);
end;

procedure TFmrRibbonPainter.DrawEditFrame(const ACanvas: TCanvas; const R: TRectF; const AHot, AEnabled: Boolean);
var
  Rad: Single;
begin
  Rad := FTheme.Metrics.ButtonRadius;
  if AEnabled then
    Fill(ACanvas, R, TFmrToken.EditFill, Rad)
  else
    Fill(ACanvas, R, TFmrToken.BodyFill, Rad);
  if AHot and AEnabled then
    Frame(ACanvas, R, TFmrToken.EditBorderHot, Rad)
  else
    Frame(ACanvas, R, TFmrToken.EditBorder, Rad);
end;

end.
