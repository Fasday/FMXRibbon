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
    /// <summary>AText shortened with an ellipsis so it fits AMaxWidth (unchanged when it fits).</summary>
    function FitText(const AText: string; const AMaxWidth: Single; const ASize: Single = 0;
      const ABold: Boolean = False): string;
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
    /// <summary>Width of the caption of a tab (tab font, bold when the theme makes the active tab bold).</summary>
    function TabCaptionWidth(const ACaption: string): Single;
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

    { additions for the ribbon control and its popups }
    /// <summary>Text with trimming (ellipsis) and optional word wrap, drawn with a text layout.</summary>
    procedure TextEx(const ACanvas: TCanvas; const R: TRectF; const AText: string; const AColor: TAlphaColor;
      const AHAlign, AVAlign: TTextAlign; const ASize: Single; const ABold, AWordWrap: Boolean;
      const ATrimming: TTextTrimming = TTextTrimming.Character; const AOpacity: Single = 1);
    /// <summary>Soft shadow around R (popups, screen tips): ASize dp of fading layers of the PopupShadow token.
    /// </summary>
    procedure DrawShadow(const ACanvas: TCanvas; const R: TRectF; const ARadius, ASize: Single);
    /// <summary>Background and border of a popup window (menus, group popups, palettes).</summary>
    procedure DrawPopupBackground(const ACanvas: TCanvas; const R: TRectF);
    /// <summary>Check box (or radio button) of a check item painted by the ribbon.</summary>
    procedure DrawCheckBox(const ACanvas: TCanvas; const R: TRectF; const AChecked, ARadio: Boolean;
      const AState: TFmrPartState);
    /// <summary>Magnifier glyph of the search box.</summary>
    procedure DrawSearchGlyph(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
    /// <summary>Glyph of the quick access toolbar customize button (a bar above a down arrow).</summary>
    procedure DrawCustomizeGlyph(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
    /// <summary>Double chevron (overflow of the quick access toolbar).</summary>
    procedure DrawChevron(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
    /// <summary>Color bar under the glyph of a color button (TAlphaColors.Null: an outlined empty bar).</summary>
    procedure DrawColorBar(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
    /// <summary>One cell of a color palette.</summary>
    procedure DrawColorCell(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor;
      const AHot, ASelected: Boolean);
    /// <summary>Thin horizontal separator of a screen tip.</summary>
    procedure DrawScreenTipSeparator(const ACanvas: TCanvas; const AX1, AX2, AY: Single);
    /// <summary>Background of the area around a floating body (Modern, Modern 2024, Soft) or of the body row.</summary>
    procedure DrawBodyBackground(const ACanvas: TCanvas; const R: TRectF; const AActive: Boolean);
    /// <summary>Gutter highlight of a checked menu item (Glass and Classic draw a box around the check mark).</summary>
    procedure DrawMenuCheckBackground(const ACanvas: TCanvas; const R: TRectF);

    { additions for galleries, the application menu, the mini toolbar and the radial menu }
    /// <summary>Resize grip band at the bottom of a drop-down gallery: dots in the bottom-right corner (ABoth) or a
    /// row of dots in the middle (vertical resizing only).</summary>
    procedure DrawResizeGrip(const ACanvas: TCanvas; const R: TRectF; const ABoth: Boolean);
    /// <summary>Thin vertical scroll bar of drop-down galleries and panes.</summary>
    procedure DrawThinScrollBar(const ACanvas: TCanvas; const ATrack, AThumb: TRectF; const AHot: Boolean);
    /// <summary>Filter band of a drop-down gallery: the current filter caption with a drop-down arrow.</summary>
    procedure DrawGalleryFilterBand(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
      const AHot: Boolean);
    /// <summary>Pin of a recent document: upright when pinned, lying when not.</summary>
    procedure DrawPinGlyph(const ACanvas: TCanvas; const R: TRectF; const APinned: Boolean; const AColor: TAlphaColor);
    /// <summary>Application menu (Glass themes): outer frame (R) around the panel area (AInner) with the bands above and
    /// below it.</summary>
    procedure DrawAppMenuFrame(const ACanvas: TCanvas; const R, AInner: TRectF);
    /// <summary>Background of the floating mini toolbar.</summary>
    procedure DrawMiniToolbar(const ACanvas: TCanvas; const R: TRectF);
    /// <summary>Radial menu disc: outer ring between ARing and AOuter (sub menu arrows), item area and the center
    /// button of radius AInner.</summary>
    procedure DrawRadialBackground(const ACanvas: TCanvas; const ACenter: TPointF; const AOuter, ARing,
      AInner: Single);
    /// <summary>Annular sector between the radii ARInner and AROuter; angles in degrees, 0 = right, clockwise.
    /// </summary>
    procedure DrawRadialSector(const ACanvas: TCanvas; const ACenter: TPointF; const ARInner, AROuter, AStart,
      ASweep: Single; const AColor: TAlphaColor; const AOpacity: Single = 1);

    { additions for display options, auto-hide, the simplified switch and the customization form }
    /// <summary>Glyph of the "Ribbon Display Options" caption button (a window with an arrow pointing up).
    /// </summary>
    procedure DrawDisplayOptionsGlyph(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
    /// <summary>Stroked chevron (switch between the classic and the simplified ribbon).</summary>
    procedure DrawSwitchChevron(const ACanvas: TCanvas; const R: TRectF; const AUp: Boolean; const AColor: TAlphaColor);
    /// <summary>Background of a caption-style button (display options, auto-hide "...") in a part state.</summary>
    procedure DrawCaptionStyleButton(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState);
    /// <summary>True when the canvas draws mirrored (right-to-left parts flip their canvas horizontally); the text
    /// methods then draw unmirrored text and swap leading and trailing alignment.</summary>
    class function IsMirrored(const ACanvas: TCanvas): Boolean; static;

    { additions for the caption row and tab row items (Modern 2024) }
    /// <summary>Toggle switch (a pill with a round thumb) in ATrack; AOpacity dims a disabled switch.</summary>
    procedure DrawToggleSwitch(const ACanvas: TCanvas; const ATrack: TRectF; const AChecked: Boolean;
      const AState: TFmrPartState);
    /// <summary>Background of an accent filled "primary" button (a "Share" button).</summary>
    procedure DrawPrimaryButton(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState;
      const ACorners: TCorners = []);
    /// <summary>Account picture: initials in a colored circle (AColor 0 = the accent).</summary>
    procedure DrawAvatar(const ACanvas: TCanvas; const R: TRectF; const AInitials: string; const AColor: TAlphaColor;
      const AState: TFmrPartState);

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

function MirrorAlign(const AAlign: TTextAlign): TTextAlign; inline;
begin
  case AAlign of
    TTextAlign.Leading: Result := TTextAlign.Trailing;
    TTextAlign.Trailing: Result := TTextAlign.Leading;
  else
    Result := AAlign;
  end;
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
  if FTheme.Style.ChevronArrows then
  begin
    // Modern 2024: a thin stroked chevron, S wide and S / 2 high.
    case ADirection of
      TFmrArrowDirection.Down:
        P := [PointF(ACenter.X - H, ACenter.Y - H / 2), PointF(ACenter.X, ACenter.Y + H / 2),
          PointF(ACenter.X + H, ACenter.Y - H / 2)];
      TFmrArrowDirection.Up:
        P := [PointF(ACenter.X - H, ACenter.Y + H / 2), PointF(ACenter.X, ACenter.Y - H / 2),
          PointF(ACenter.X + H, ACenter.Y + H / 2)];
      TFmrArrowDirection.Left:
        P := [PointF(ACenter.X + H / 2, ACenter.Y - H), PointF(ACenter.X - H / 2, ACenter.Y),
          PointF(ACenter.X + H / 2, ACenter.Y + H)];
      TFmrArrowDirection.Right:
        P := [PointF(ACenter.X - H / 2, ACenter.Y - H), PointF(ACenter.X + H / 2, ACenter.Y),
          PointF(ACenter.X - H / 2, ACenter.Y + H)];
    end;
    FStroke.Kind := TBrushKind.Solid;
    FStroke.Color := AColor;
    FStroke.Thickness := 1;
    FStroke.Cap := TStrokeCap.Round;
    FStroke.Join := TStrokeJoin.Round;
    FStroke.Dash := TStrokeDash.Solid;
    ACanvas.DrawLine(P[0], P[1], AOpacity, FStroke);
    ACanvas.DrawLine(P[1], P[2], AOpacity, FStroke);
    FStroke.Cap := TStrokeCap.Flat;
    FStroke.Join := TStrokeJoin.Miter;
    Exit;
  end;
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

function TFmrRibbonPainter.FitText(const AText: string; const AMaxWidth, ASize: Single; const ABold: Boolean): string;
var
  Lo, Hi, Mid: Integer;
begin
  if (AText = '') or (TextWidth(AText, ASize, ABold) <= AMaxWidth) then
    Exit(AText);
  // Longest prefix that fits together with the ellipsis
  Lo := 0;
  Hi := Length(AText);
  while Lo < Hi do
  begin
    Mid := (Lo + Hi + 1) div 2;
    if TextWidth(Copy(AText, 1, Mid) + #$2026, ASize, ABold) <= AMaxWidth then
      Lo := Mid
    else
      Hi := Mid - 1;
  end;
  Result := TrimRight(Copy(AText, 1, Lo)) + #$2026;
end;

procedure TFmrRibbonPainter.Text(const ACanvas: TCanvas; const R: TRectF; const AText: string;
  const AColor: TAlphaColor; const AHAlign, AVAlign: TTextAlign; const ASize: Single; const ABold, AWordWrap: Boolean;
  const AOpacity: Single);
var
  Saved: TMatrix;
begin
  if (AText = '') or (TAlphaColorRec(AColor).A = 0) or (R.Width <= 0) then
    Exit;
  PrepareFont(ACanvas.Font, ASize, ABold);
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AColor;
  if IsMirrored(ACanvas) then
  begin
    // Right-to-left part: the text is flipped back inside its rectangle; the reading start is on the right.
    Saved := ACanvas.Matrix;
    ACanvas.MultiplyMatrix(TMatrix.CreateScaling(-1, 1) * TMatrix.CreateTranslation(R.Left + R.Right, 0));
    try
      ACanvas.FillText(R, AText, AWordWrap, AOpacity, [], MirrorAlign(AHAlign), AVAlign);
    finally
      ACanvas.SetMatrix(Saved);
    end;
    Exit;
  end;
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
  W, IndH, IndR: Single;
  Bold: Boolean;
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
  Bold := Shown and FTheme.Style.BoldActiveTab;
  TextR := R;
  Text(ACanvas, TextR, Caption, TextColor, TTextAlign.Center, TTextAlign.Center, FTheme.Metrics.EffectiveTabFontSize,
    Bold);

  if Shown and (FTheme.Style.TabShape = TFmrTabShape.Underline) then
  begin
    IndH := FTheme.Metrics.TabIndicatorHeight;
    IndR := FTheme.Metrics.TabIndicatorRadius;
    if IndR <= 0 then
      IndR := IndH / 2;
    W := Min(TextWidth(Caption, FTheme.Metrics.EffectiveTabFontSize, Bold), R.Width - 8);
    Ind := RectF(R.CenterPoint.X - W / 2, R.Bottom - FTheme.Metrics.TabIndicatorOffset - IndH,
      R.CenterPoint.X + W / 2, R.Bottom - FTheme.Metrics.TabIndicatorOffset);
    if AContextColor <> 0 then
      Fill(ACanvas, Ind, TFmrFill.Solid(AContextColor), IndR)
    else
      Fill(ACanvas, Ind, TFmrToken.TabActiveIndicator, IndR);
  end;
end;

function TFmrRibbonPainter.TabCaptionWidth(const ACaption: string): Single;
var
  Caption: string;
begin
  // A tab is as wide as its caption when it is active (bold in Modern 2024), so tabs do not move when one is picked.
  Caption := ACaption;
  if FTheme.Style.UppercaseTabs then
    Caption := Caption.ToUpper;
  Result := TextWidth(Caption, FTheme.Metrics.EffectiveTabFontSize, FTheme.Style.BoldActiveTab);
end;

procedure TFmrRibbonPainter.DrawContextGroupHeader(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
  const AColor: TAlphaColor);
begin
  Fill(ACanvas, R, TFmrFill.Vertical([FmrWithAlpha(AColor, 0.55), FmrWithAlpha(AColor, 0.25)], []));
  Line(ACanvas, PointF(R.Left, R.Top + 1.5), PointF(R.Right, R.Top + 1.5), AColor, 3);
  Text(ACanvas, RectF(R.Left + 6, R.Top + 3, R.Right - 6, R.Bottom), FitText(ACaption, R.Width - 12),
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
      Text(ACanvas, R, ACaption, FTheme.Colors[TFmrToken.AppButtonText], TTextAlign.Center, TTextAlign.Center,
        FTheme.Metrics.EffectiveTabFontSize);
    end;
  end;
end;

{ body and groups }

procedure TFmrRibbonPainter.DrawBody(const ACanvas: TCanvas; const R: TRectF);
var
  Rad, A: Single;
  B, E: TRectF;
  Shadow: TAlphaColor;
  I: Integer;
begin
  Rad := FTheme.Metrics.BodyRadius;
  B := R;
  if FTheme.Style.FloatingBody and (FTheme.Style.Family = TFmrThemeFamily.Modern2024) then
  begin
    // Modern 2024: a 1 dp edge around the card and a short soft shadow below it.
    Shadow := FTheme.Colors[TFmrToken.BodyShadow];
    A := TAlphaColorRec(Shadow).A / 255;
    for I := 3 downto 0 do
      Fill(ACanvas, RectF(B.Left + Rad * 0.6, B.Bottom + I, B.Right - Rad * 0.6, B.Bottom + I + 1),
        TFmrFill.Solid(FmrWithAlpha(Shadow, A * Power(0.55, I))));
    E := B;
    E.Inflate(1, 1);
    Fill(ACanvas, E, TFmrToken.BodyBorder, Rad + 1);
    Fill(ACanvas, B, TFmrToken.BodyFill, Rad);
  end
  else if FTheme.Style.FloatingBody then
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
    Line(ACanvas, PointF(R.Right - 0.5, R.Top + FTheme.Metrics.GroupSeparatorInsetTop), PointF(R.Right - 0.5,
      R.Bottom - FTheme.Metrics.GroupSeparatorInsetBottom), FTheme.Colors[TFmrToken.GroupSeparator]);
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
  // When one part is hot the other is outlined lighter: paint the whole frame hot, then the
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
  Border: TAlphaColor;
  Inner: TRectF;
begin
  Rad := Max(FTheme.Metrics.ButtonRadius, 4);
  if FTheme.Style.Family = TFmrThemeFamily.Modern2024 then
  begin
    // Modern 2024: the edge is a little darker at the bottom (a shadow line).
    Border := FTheme.Colors[TFmrToken.SearchBoxBorder];
    Fill(ACanvas, RectF(R.Left, R.Top, R.Right, R.Bottom + 1), TFmrFill.Solid(FmrDarken(Border or $FF000000, 0.12)),
      Rad + 1, [], TAlphaColorRec(Border).A / 255);
    Fill(ACanvas, R, TFmrFill.Solid(Border), Rad);
    Inner := R;
    Inner.Inflate(-1, -1);
    if AHot then
      Fill(ACanvas, Inner, TFmrToken.SearchBoxHotFill, Rad - 1)
    else
      Fill(ACanvas, Inner, TFmrToken.SearchBoxFill, Rad - 1);
    Exit;
  end;
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

{ additions }

procedure TFmrRibbonPainter.TextEx(const ACanvas: TCanvas; const R: TRectF; const AText: string;
  const AColor: TAlphaColor; const AHAlign, AVAlign: TTextAlign; const ASize: Single; const ABold, AWordWrap: Boolean;
  const ATrimming: TTextTrimming; const AOpacity: Single);
var
  Mirrored: Boolean;
  Saved: TMatrix;
begin
  if (AText = '') or (TAlphaColorRec(AColor).A = 0) or (R.Width <= 0) or (R.Height <= 0) then
    Exit;
  Mirrored := IsMirrored(ACanvas);
  PrepareFont(FFont, ASize, ABold);
  FLayout.BeginUpdate;
  try
    FLayout.Font := FFont;
    FLayout.Text := AText;
    FLayout.WordWrap := AWordWrap;
    FLayout.Trimming := ATrimming;
    if Mirrored then
      FLayout.HorizontalAlign := MirrorAlign(AHAlign)
    else
      FLayout.HorizontalAlign := AHAlign;
    FLayout.VerticalAlign := AVAlign;
    FLayout.Color := AColor;
    FLayout.Opacity := AOpacity;
    FLayout.TopLeft := R.TopLeft;
    FLayout.MaxSize := TPointF.Create(R.Width, R.Height);
  finally
    FLayout.EndUpdate;
  end;
  if Mirrored then
  begin
    Saved := ACanvas.Matrix;
    ACanvas.MultiplyMatrix(TMatrix.CreateScaling(-1, 1) * TMatrix.CreateTranslation(R.Left + R.Right, 0));
    try
      FLayout.RenderLayout(ACanvas);
    finally
      ACanvas.SetMatrix(Saved);
    end;
  end
  else
    FLayout.RenderLayout(ACanvas);
  FLayout.Opacity := 1;
end;

procedure TFmrRibbonPainter.DrawShadow(const ACanvas: TCanvas; const R: TRectF; const ARadius, ASize: Single);
var
  I, Steps: Integer;
  Base: TAlphaColor;
  A: Single;
  S: TRectF;
begin
  Base := FTheme.Colors[TFmrToken.PopupShadow];
  if (TAlphaColorRec(Base).A = 0) or (ASize <= 0) then
    Exit;
  Steps := Max(1, Round(ASize));
  for I := Steps downto 1 do
  begin
    S := R;
    S.Inflate(I, I);
    S.Offset(0, I * 0.35);
    A := (TAlphaColorRec(Base).A / 255) * Sqr(1 - (I - 1) / Steps) / Steps * 1.6;
    Fill(ACanvas, S, TFmrFill.Solid(FmrWithAlpha(Base, A)), ARadius + I);
  end;
end;

procedure TFmrRibbonPainter.DrawPopupBackground(const ACanvas: TCanvas; const R: TRectF);
begin
  Fill(ACanvas, R, TFmrToken.MenuFill, FTheme.Metrics.MenuRadius);
  Frame(ACanvas, R, TFmrToken.MenuBorder, FTheme.Metrics.MenuRadius);
end;

procedure TFmrRibbonPainter.DrawCheckBox(const ACanvas: TCanvas; const R: TRectF; const AChecked, ARadio: Boolean;
  const AState: TFmrPartState);
var
  Box: TRectF;
  Border, Mark: TAlphaColor;
  D: Single;
begin
  D := Min(13, Min(R.Width, R.Height));
  Box := RectF(0, 0, D, D).CenterAt(R);
  Box := RectF(Round(Box.Left), Round(Box.Top), Round(Box.Left) + D, Round(Box.Top) + D);
  if AState = TFmrPartState.Disabled then
  begin
    Border := FTheme.Colors[TFmrToken.ButtonTextDisabled];
    Mark := Border;
  end
  else
  begin
    if AState in [TFmrPartState.Hot, TFmrPartState.Pressed, TFmrPartState.CheckedHot] then
      Border := FTheme.Colors[TFmrToken.EditBorderHot]
    else
      Border := FTheme.Colors[TFmrToken.EditBorder];
    Mark := FTheme.Colors[TFmrToken.ButtonText];
  end;
  if ARadio then
  begin
    FTheme.Fills[TFmrToken.EditFill].ApplyTo(FBrush);
    ACanvas.FillEllipse(Box, 1, FBrush);
    FStroke.Kind := TBrushKind.Solid;
    FStroke.Color := Border;
    FStroke.Thickness := 1;
    ACanvas.DrawEllipse(FmrStrokeRect(Box), 1, FStroke);
    if AChecked then
    begin
      ACanvas.Fill.Kind := TBrushKind.Solid;
      ACanvas.Fill.Color := Mark;
      ACanvas.FillEllipse(RectF(Box.CenterPoint.X - 3, Box.CenterPoint.Y - 3, Box.CenterPoint.X + 3,
        Box.CenterPoint.Y + 3), 1);
    end;
  end
  else
  begin
    Fill(ACanvas, Box, TFmrToken.EditFill, 2);
    Frame(ACanvas, Box, Border, 2);
    if AChecked then
      DrawCheckMark(ACanvas, Box, Mark);
  end;
end;

procedure TFmrRibbonPainter.DrawSearchGlyph(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
var
  C: TPointF;
  Rad: Single;
begin
  C := R.CenterPoint;
  Rad := Min(R.Width, R.Height) * 0.28;
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := AColor;
  FStroke.Thickness := 1.2;
  FStroke.Cap := TStrokeCap.Round;
  if FTheme.Style.Family = TFmrThemeFamily.Modern2024 then
  begin
    // Magnifier: the handle points down to the left.
    FStroke.Thickness := 1;
    ACanvas.DrawEllipse(RectF(C.X - Rad + 1, C.Y - Rad - 1, C.X + Rad + 1, C.Y + Rad - 1), 1, FStroke);
    ACanvas.DrawLine(PointF(C.X - Rad * 0.7 + 1, C.Y + Rad * 0.7 - 1), PointF(C.X - Rad * 1.6, C.Y + Rad * 1.6), 1,
      FStroke);
  end
  else
  begin
    ACanvas.DrawEllipse(RectF(C.X - Rad - 1, C.Y - Rad - 1, C.X + Rad - 1, C.Y + Rad - 1), 1, FStroke);
    ACanvas.DrawLine(PointF(C.X + Rad * 0.7 - 1, C.Y + Rad * 0.7 - 1), PointF(C.X + Rad * 1.6, C.Y + Rad * 1.6), 1,
      FStroke);
  end;
  FStroke.Cap := TStrokeCap.Flat;
end;

procedure TFmrRibbonPainter.DrawCustomizeGlyph(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
var
  C: TPointF;
begin
  C := R.CenterPoint;
  C.X := Round(C.X);
  C.Y := Round(C.Y);
  Line(ACanvas, PointF(C.X - 3.5, C.Y - 3.5), PointF(C.X + 3.5, C.Y - 3.5), AColor);
  Arrow(ACanvas, PointF(C.X, C.Y + 1), TFmrArrowDirection.Down, AColor, 7);
end;

procedure TFmrRibbonPainter.DrawChevron(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
var
  C: TPointF;
begin
  C := R.CenterPoint;
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := AColor;
  FStroke.Thickness := 1.2;
  ACanvas.DrawLine(PointF(C.X - 4, C.Y - 3), PointF(C.X - 1, C.Y), 1, FStroke);
  ACanvas.DrawLine(PointF(C.X - 1, C.Y), PointF(C.X - 4, C.Y + 3), 1, FStroke);
  ACanvas.DrawLine(PointF(C.X, C.Y - 3), PointF(C.X + 3, C.Y), 1, FStroke);
  ACanvas.DrawLine(PointF(C.X + 3, C.Y), PointF(C.X, C.Y + 3), 1, FStroke);
end;

procedure TFmrRibbonPainter.DrawColorBar(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
begin
  if TAlphaColorRec(AColor).A = 0 then
    Frame(ACanvas, R, TFmrToken.ButtonArrow)
  else
    Fill(ACanvas, R, TFmrFill.Solid(AColor));
end;

procedure TFmrRibbonPainter.DrawColorCell(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor;
  const AHot, ASelected: Boolean);
begin
  Fill(ACanvas, R, TFmrFill.Solid(AColor));
  Frame(ACanvas, R, FmrWithAlpha(FTheme.Colors[TFmrToken.MenuItemText], 0.18));
  if ASelected or AHot then
  begin
    Frame(ACanvas, RectF(R.Left - 1, R.Top - 1, R.Right + 1, R.Bottom + 1), TFmrToken.GalleryItemSelectedBorder,
      0, [], 1);
    Frame(ACanvas, R, TFmrToken.MenuFill, 0, [], 1);
  end;
end;

procedure TFmrRibbonPainter.DrawScreenTipSeparator(const ACanvas: TCanvas; const AX1, AX2, AY: Single);
begin
  Line(ACanvas, PointF(AX1, Round(AY) + 0.5), PointF(AX2, Round(AY) + 0.5), FTheme.Colors[TFmrToken.ScreenTipSeparator]);
end;

procedure TFmrRibbonPainter.DrawBodyBackground(const ACanvas: TCanvas; const R: TRectF; const AActive: Boolean);
begin
  DrawTabRow(ACanvas, R, AActive);
end;

procedure TFmrRibbonPainter.DrawMenuCheckBackground(const ACanvas: TCanvas; const R: TRectF);
begin
  if FTheme.Style.Family in [TFmrThemeFamily.Glass, TFmrThemeFamily.Classic] then
    DrawButton(ACanvas, R, TFmrPartState.Checked)
  else
  begin
    Fill(ACanvas, R, TFmrToken.ButtonCheckedFill, FTheme.Metrics.ButtonRadius);
    Frame(ACanvas, R, TFmrToken.ButtonCheckedBorder, FTheme.Metrics.ButtonRadius);
  end;
end;

{ display options, auto-hide, simplified switch, customization form }

class function TFmrRibbonPainter.IsMirrored(const ACanvas: TCanvas): Boolean;
begin
  Result := (ACanvas <> nil) and (ACanvas.Matrix.m11 < 0);
end;

procedure TFmrRibbonPainter.DrawDisplayOptionsGlyph(const ACanvas: TCanvas; const R: TRectF; const AColor: TAlphaColor);
var
  C: TPointF;
begin
  C := R.CenterPoint;
  C.X := Round(C.X);
  C.Y := Round(C.Y);
  Frame(ACanvas, RectF(C.X - 7, C.Y - 3, C.X + 7, C.Y + 7), AColor, 1);
  Line(ACanvas, PointF(C.X - 6, C.Y - 0.5), PointF(C.X + 6, C.Y - 0.5), AColor);
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := AColor;
  FStroke.Thickness := 1;
  FStroke.Cap := TStrokeCap.Flat;
  ACanvas.DrawLine(PointF(C.X - 3, C.Y - 5), PointF(C.X, C.Y - 8), 1, FStroke);
  ACanvas.DrawLine(PointF(C.X, C.Y - 8), PointF(C.X + 3, C.Y - 5), 1, FStroke);
end;

procedure TFmrRibbonPainter.DrawSwitchChevron(const ACanvas: TCanvas; const R: TRectF; const AUp: Boolean;
  const AColor: TAlphaColor);
var
  C: TPointF;
  D: Single;
begin
  C := R.CenterPoint;
  C.X := Round(C.X) + 0.5;
  C.Y := Round(C.Y) + 0.5;
  if AUp then
    D := -1
  else
    D := 1;
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := AColor;
  FStroke.Thickness := 1.3;
  FStroke.Cap := TStrokeCap.Round;
  FStroke.Join := TStrokeJoin.Round;
  ACanvas.DrawLine(PointF(C.X - 4.5, C.Y - 2.25 * D), PointF(C.X, C.Y + 2.25 * D), 1, FStroke);
  ACanvas.DrawLine(PointF(C.X, C.Y + 2.25 * D), PointF(C.X + 4.5, C.Y - 2.25 * D), 1, FStroke);
  FStroke.Cap := TStrokeCap.Flat;
end;

procedure TFmrRibbonPainter.DrawCaptionStyleButton(const ACanvas: TCanvas; const R: TRectF;
  const AState: TFmrPartState);
begin
  case AState of
    TFmrPartState.Hot, TFmrPartState.CheckedHot:
      Fill(ACanvas, R, TFmrToken.CaptionButtonHotFill);
    TFmrPartState.Pressed, TFmrPartState.Checked:
      Fill(ACanvas, R, TFmrToken.CaptionButtonPressedFill);
  end;
end;

{ caption row and tab row items }

procedure TFmrRibbonPainter.DrawToggleSwitch(const ACanvas: TCanvas; const ATrack: TRectF; const AChecked: Boolean;
  const AState: TFmrPartState);
var
  T, Thumb: TRectF;
  Rad, D, Op: Single;
  C: TPointF;
begin
  T := RectF(Round(ATrack.Left), Round(ATrack.Top), Round(ATrack.Right), Round(ATrack.Bottom));
  Rad := T.Height / 2;
  if AState = TFmrPartState.Disabled then
    Op := 0.45
  else
    Op := 1;
  // Windows 11: the thumb grows a little under the mouse.
  if AState in [TFmrPartState.Hot, TFmrPartState.CheckedHot, TFmrPartState.Pressed] then
    D := T.Height - 6
  else
    D := T.Height - 8;
  if AChecked then
  begin
    Fill(ACanvas, T, TFmrToken.ToggleSwitchFill, Rad, [], Op);
    C := PointF(T.Right - Rad, T.CenterPoint.Y);
  end
  else
  begin
    Frame(ACanvas, T, TFmrToken.ToggleSwitchBorder, Rad, [], 1, Op);
    C := PointF(T.Left + Rad, T.CenterPoint.Y);
  end;
  Thumb := RectF(C.X - D / 2, C.Y - D / 2, C.X + D / 2, C.Y + D / 2);
  if AChecked then
    FTheme.Fills[TFmrToken.ToggleSwitchThumbOn].ApplyTo(FBrush)
  else
    FTheme.Fills[TFmrToken.ToggleSwitchThumb].ApplyTo(FBrush);
  ACanvas.FillEllipse(Thumb, Op, FBrush);
end;

procedure TFmrRibbonPainter.DrawPrimaryButton(const ACanvas: TCanvas; const R: TRectF; const AState: TFmrPartState;
  const ACorners: TCorners);
var
  Token: TFmrToken;
  Op: Single;
begin
  Op := 1;
  case AState of
    TFmrPartState.Hot, TFmrPartState.CheckedHot:
      Token := TFmrToken.PrimaryButtonHotFill;
    TFmrPartState.Pressed, TFmrPartState.Checked:
      Token := TFmrToken.PrimaryButtonPressedFill;
    TFmrPartState.Disabled:
      begin
        Token := TFmrToken.PrimaryButtonFill;
        Op := 0.45;
      end;
  else
    Token := TFmrToken.PrimaryButtonFill;
  end;
  Fill(ACanvas, R, Token, Max(FTheme.Metrics.ButtonRadius, 2), ACorners, Op);
end;

procedure TFmrRibbonPainter.DrawAvatar(const ACanvas: TCanvas; const R: TRectF; const AInitials: string;
  const AColor: TAlphaColor; const AState: TFmrPartState);
var
  D: Single;
  Circle: TRectF;
  Col: TAlphaColor;
begin
  if AState in [TFmrPartState.Hot, TFmrPartState.Pressed, TFmrPartState.CheckedHot] then
    DrawCaptionStyleButton(ACanvas, R, AState);
  D := Min(Min(R.Width, R.Height) - 4, 24);
  Circle := RectF(0, 0, D, D).CenterAt(R);
  Col := AColor;
  if TAlphaColorRec(Col).A = 0 then
    Col := FTheme.Accent;
  FBrush.Kind := TBrushKind.Solid;
  FBrush.Color := Col;
  ACanvas.FillEllipse(Circle, 1, FBrush);
  Text(ACanvas, Circle, AInitials, FmrContrastText(Col), TTextAlign.Center, TTextAlign.Center, Max(9, D * 0.44));
end;

{ galleries, application menu, mini toolbar, radial menu }

procedure TFmrRibbonPainter.DrawResizeGrip(const ACanvas: TCanvas; const R: TRectF; const ABoth: Boolean);
var
  Col: TAlphaColor;
  I, J: Integer;
  X, Y: Single;
begin
  Fill(ACanvas, R, TFmrToken.MenuHeaderFill);
  Line(ACanvas, PointF(R.Left, Round(R.Top) + 0.5), PointF(R.Right, Round(R.Top) + 0.5),
    FTheme.Colors[TFmrToken.MenuSeparator]);
  Col := FTheme.Colors[TFmrToken.MenuShortcutText];
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := Col;
  if ABoth then
  begin
    // A triangle of dots in the corner.
    for I := 0 to 2 do
      for J := 0 to 2 - I do
      begin
        X := Round(R.Right) - 4 - J * 3;
        Y := Round(R.Bottom) - 3 - I * 3;
        ACanvas.FillRect(RectF(X - 1, Y - 1, X + 1, Y + 1), 0, 0, [], 0.9);
      end;
  end
  else
    for I := -2 to 2 do
    begin
      X := Round(R.CenterPoint.X) + I * 4;
      Y := Round(R.CenterPoint.Y) + 0.5;
      ACanvas.FillRect(RectF(X - 1, Y - 1, X + 1, Y + 1), 0, 0, [], 0.9);
    end;
end;

procedure TFmrRibbonPainter.DrawThinScrollBar(const ACanvas: TCanvas; const ATrack, AThumb: TRectF;
  const AHot: Boolean);
var
  Rad: Single;
  Col: TAlphaColor;
begin
  Rad := Min(ATrack.Width, 6) / 2;
  Fill(ACanvas, ATrack, TFmrToken.GalleryScrollFill, Rad);
  Col := FTheme.Colors[TFmrToken.GalleryScrollGlyph];
  if AHot then
    Fill(ACanvas, AThumb, TFmrFill.Solid(FmrWithAlpha(Col, 0.75 * TAlphaColorRec(Col).A / 255)), Rad)
  else
    Fill(ACanvas, AThumb, TFmrFill.Solid(FmrWithAlpha(Col, 0.45 * TAlphaColorRec(Col).A / 255)), Rad);
end;

procedure TFmrRibbonPainter.DrawGalleryFilterBand(const ACanvas: TCanvas; const R: TRectF; const ACaption: string;
  const AHot: Boolean);
var
  W: Single;
  Col: TAlphaColor;
begin
  Fill(ACanvas, R, TFmrToken.GalleryGroupHeaderFill);
  if AHot then
    DrawMenuItem(ACanvas, R, TFmrPartState.Hot);
  Col := FTheme.Colors[TFmrToken.GalleryGroupHeaderText];
  W := Min(TextWidth(ACaption, 0, True), R.Width - 32);
  TextEx(ACanvas, RectF(R.Left + 8, R.Top, R.Left + 8 + W + 2, R.Bottom), ACaption, Col, TTextAlign.Leading,
    TTextAlign.Center, 0, True, False);
  Arrow(ACanvas, PointF(R.Left + 8 + W + 10, R.CenterPoint.Y + 0.5), TFmrArrowDirection.Down, Col);
  Line(ACanvas, PointF(R.Left, Round(R.Bottom) - 0.5), PointF(R.Right, Round(R.Bottom) - 0.5),
    FTheme.Colors[TFmrToken.MenuSeparator]);
end;

procedure TFmrRibbonPainter.DrawPinGlyph(const ACanvas: TCanvas; const R: TRectF; const APinned: Boolean;
  const AColor: TAlphaColor);
var
  C: TPointF;
  M: TMatrix;
  State: TCanvasSaveState;
begin
  C := R.CenterPoint;
  C := PointF(Round(C.X) + 0.5, Round(C.Y) + 0.5);
  State := ACanvas.SaveState;
  try
    if not APinned then
    begin
      // The unpinned pin lies on its side (rotated by 90 degrees around the center).
      M := TMatrix.CreateTranslation(-C.X, -C.Y) * TMatrix.CreateRotation(DegToRad(-90)) *
        TMatrix.CreateTranslation(C.X, C.Y);
      ACanvas.MultiplyMatrix(M);
    end;
    FStroke.Kind := TBrushKind.Solid;
    FStroke.Color := AColor;
    FStroke.Thickness := 1;
    FStroke.Dash := TStrokeDash.Solid;
    // head, body, plate and needle
    ACanvas.DrawRect(RectF(C.X - 2.5, C.Y - 6, C.X + 2.5, C.Y - 5), 0, 0, [], 1, FStroke);
    ACanvas.DrawRect(RectF(C.X - 2, C.Y - 5, C.X + 2, C.Y + 1), 0, 0, [], 1, FStroke);
    ACanvas.DrawLine(PointF(C.X - 4.5, C.Y + 1), PointF(C.X + 4.5, C.Y + 1), 1, FStroke);
    ACanvas.DrawLine(PointF(C.X, C.Y + 1), PointF(C.X, C.Y + 6), 1, FStroke);
    if APinned then
    begin
      ACanvas.Fill.Kind := TBrushKind.Solid;
      ACanvas.Fill.Color := AColor;
      ACanvas.FillRect(RectF(C.X - 2, C.Y - 5, C.X + 2, C.Y + 1), 0, 0, [], 0.35);
    end;
  finally
    ACanvas.RestoreState(State);
  end;
end;

procedure TFmrRibbonPainter.DrawAppMenuFrame(const ACanvas: TCanvas; const R, AInner: TRectF);
var
  Rad: Single;
begin
  Rad := Max(FTheme.Metrics.MenuRadius, 3);
  if FTheme.Style.Family = TFmrThemeFamily.Glass then
    Fill(ACanvas, R, TFmrToken.CaptionFill, Rad)
  else
    Fill(ACanvas, R, TFmrToken.TabRowFill, Rad);
  Frame(ACanvas, R, TFmrToken.MenuBorder, Rad);
  Fill(ACanvas, AInner, TFmrToken.MenuFill);
  Frame(ACanvas, RectF(AInner.Left - 1, AInner.Top - 1, AInner.Right + 1, AInner.Bottom + 1), TFmrToken.MenuBorder);
end;

procedure TFmrRibbonPainter.DrawMiniToolbar(const ACanvas: TCanvas; const R: TRectF);
var
  Rad: Single;
begin
  Rad := Max(FTheme.Metrics.MenuRadius, 3);
  Fill(ACanvas, R, TFmrToken.MiniToolbarFill, Rad);
  Frame(ACanvas, R, TFmrToken.MiniToolbarBorder, Rad);
end;

procedure TFmrRibbonPainter.DrawRadialBackground(const ACanvas: TCanvas; const ACenter: TPointF; const AOuter, ARing,
  AInner: Single);
var
  Accent: TAlphaColor;
begin
  Accent := FTheme.Colors[TFmrToken.RadialBorder];
  // outer ring (accent tinted), item area, center button
  FTheme.Fills[TFmrToken.RadialFill].ApplyTo(FBrush);
  ACanvas.FillEllipse(RectF(ACenter.X - AOuter, ACenter.Y - AOuter, ACenter.X + AOuter, ACenter.Y + AOuter), 1, FBrush);
  DrawRadialSector(ACanvas, ACenter, ARing, AOuter, 0, 360, Accent, 0.16);
  FStroke.Kind := TBrushKind.Solid;
  FStroke.Color := Accent;
  FStroke.Thickness := 2;
  FStroke.Dash := TStrokeDash.Solid;
  ACanvas.DrawEllipse(RectF(ACenter.X - AOuter + 1, ACenter.Y - AOuter + 1, ACenter.X + AOuter - 1,
    ACenter.Y + AOuter - 1), 1, FStroke);
  FStroke.Thickness := 1;
  FStroke.Color := FmrWithAlpha(Accent, 0.45 * TAlphaColorRec(Accent).A / 255);
  ACanvas.DrawEllipse(RectF(ACenter.X - ARing, ACenter.Y - ARing, ACenter.X + ARing, ACenter.Y + ARing), 1, FStroke);
  FStroke.Color := Accent;
  FStroke.Thickness := 2;
  ACanvas.DrawEllipse(RectF(ACenter.X - AInner, ACenter.Y - AInner, ACenter.X + AInner, ACenter.Y + AInner), 1,
    FStroke);
  FStroke.Thickness := 1;
end;

procedure TFmrRibbonPainter.DrawRadialSector(const ACanvas: TCanvas; const ACenter: TPointF; const ARInner, AROuter,
  AStart, ASweep: Single; const AColor: TAlphaColor; const AOpacity: Single);
var
  Path: TPathData;
  I, N: Integer;
  A: Single;
begin
  if (TAlphaColorRec(AColor).A = 0) or (ASweep <= 0) then
    Exit;
  N := Max(4, Ceil(ASweep / 4));
  Path := TPathData.Create;
  try
    for I := 0 to N do
    begin
      A := DegToRad(AStart + ASweep * I / N);
      if I = 0 then
        Path.MoveTo(PointF(ACenter.X + AROuter * Cos(A), ACenter.Y + AROuter * Sin(A)))
      else
        Path.LineTo(PointF(ACenter.X + AROuter * Cos(A), ACenter.Y + AROuter * Sin(A)));
    end;
    for I := N downto 0 do
    begin
      A := DegToRad(AStart + ASweep * I / N);
      Path.LineTo(PointF(ACenter.X + ARInner * Cos(A), ACenter.Y + ARInner * Sin(A)));
    end;
    Path.ClosePath;
    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := AColor;
    ACanvas.FillPath(Path, AOpacity);
  finally
    Path.Free;
  end;
end;

end.
