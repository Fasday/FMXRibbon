{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Office-style status bar                              }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.StatusBar;

/// TFmrStatusBar: an Office-like status bar (Align = Bottom, height from the theme metric StatusBarHeight). Its
/// panels are child controls (TFmrStatusBarPanel), so they are designed, selected and reordered like any FMX control
/// and get mouse events and hints of their own. A panel shows text with an optional glyph, hosts child controls
/// (Container), shows the links of a bar manager as small buttons (ItemLinks), a Word-like zoom slider (ZoomSlider)
/// or the three view buttons Read / Print / Web (ViewButtons). Left panels are placed from the left in their child
/// order, right panels end at the right edge; panels that do not fit shrink to MinWidth and are hidden from the end
/// of the left group (FMR.Ribbon.Extras.Layout).
/// The status bar paints with the theme of its ThemeProvider (normally the TFmrRibbon of the form) or, without
/// one, with its own Theme / AccentColor.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  System.Messaging, FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types,
  FMR.Bars.Images, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.ThemeLink,
  FMR.Ribbon.Extras.Layout;

type
  TFmrStatusBar = class;
  TFmrStatusBarPanel = class;

  /// <summary>Side of the status bar a panel is aligned to (same type as in FMR.Ribbon.Extras.Layout).</summary>
  TFmrStatusPanelSide = FMR.Ribbon.Extras.Layout.TFmrStatusPanelSide;

  /// <summary>What a status bar panel shows.</summary>
  TFmrStatusPanelKind = (
    /// <summary>Text with an optional glyph; hot tracked when OnClick is assigned.</summary>
    Text,
    /// <summary>Hosts its child controls (aligned inside the panel's Padding); give it a PanelWidth.</summary>
    Container,
    /// <summary>The links of ItemLinks as small buttons painted by the panel.</summary>
    ItemLinks,
    /// <summary>Word-like zoom slider: - button, track with the 100 % tick, + button, percentage.</summary>
    ZoomSlider,
    /// <summary>Three toggle buttons: Read Mode, Print Layout, Web Layout.</summary>
    ViewButtons);

  /// <summary>Line drawn around or next to a panel.</summary>
  TFmrStatusPanelBevel = (
    /// <summary>Separator line for the Office 2007/2010 themes, nothing for the flat themes.</summary>
    Auto,
    None,
    /// <summary>A vertical line between the panel and its neighbor.</summary>
    Separator,
    /// <summary>A thin frame around the panel.</summary>
    Frame);

  /// <summary>Views of the ViewButtons panel.</summary>
  TFmrStatusView = (Read, Print, Web);
  TFmrStatusViews = set of TFmrStatusView;

  /// <summary>Part of a panel under the mouse.</summary>
  TFmrStatusPart = (None, Body, ZoomOut, ZoomIn, ZoomTrack, ZoomThumb, ZoomPercent, View, Link);

  /// <summary>Click on a link of an ItemLinks panel; set AHandled to skip TFmrBarItem.Click.</summary>
  TFmrStatusLinkClickEvent = procedure(Sender: TObject; const APanel: TFmrStatusBarPanel; const ALink: TFmrItemLink;
    var AHandled: Boolean) of object;

  /// <summary>One panel of a TFmrStatusBar (a child control of the status bar). The status bar sets its bounds.
  /// </summary>
  TFmrStatusBarPanel = class(TControl, IFmrItemLinksOwner)
  private
    FThemeLink: TFmrThemeLink;
    FKind: TFmrStatusPanelKind;
    FSide: TFmrStatusPanelSide;
    FText: string;
    FPanelWidth: Single;
    FMinWidth: Single;
    FStretch: Boolean;
    FAlignment: TTextAlign;
    FBevel: TFmrStatusPanelBevel;
    FGlyph: TFmrImageSource;
    FItemLinks: TFmrItemLinks;
    FZoom: Integer;
    FZoomMin: Integer;
    FZoomMax: Integer;
    FZoomStep: Integer;
    FSliderWidth: Single;
    FShowZoomPercent: Boolean;
    FActiveView: TFmrStatusView;
    FViews: TFmrStatusViews;
    FOnZoomChange: TNotifyEvent;
    FOnZoomClick: TNotifyEvent;
    FOnViewChange: TNotifyEvent;
    // interaction
    FHotPart: TFmrStatusPart;
    FHotIndex: Integer;
    FPressedPart: TFmrStatusPart;
    FPressedIndex: Integer;
    FDragging: Boolean;
    FClickPart: TFmrStatusPart;
    // geometry (local dp)
    FLinkRects: TArray<TRectF>;
    FSeparators: TArray<Single>;
    FMinusRect, FPlusRect, FTrackRect, FPercentRect: TRectF;
    FViewRects: array [TFmrStatusView] of TRectF;
    FGeometryValid: Boolean;
    procedure SetKind(const Value: TFmrStatusPanelKind);
    procedure SetSide(const Value: TFmrStatusPanelSide);
    procedure SetText(const Value: string);
    procedure SetPanelWidth(const Value: Single);
    procedure SetMinWidth(const Value: Single);
    procedure SetStretch(const Value: Boolean);
    procedure SetAlignment(const Value: TTextAlign);
    procedure SetBevel(const Value: TFmrStatusPanelBevel);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetZoom(const Value: Integer);
    procedure SetZoomMin(const Value: Integer);
    procedure SetZoomMax(const Value: Integer);
    procedure SetZoomStep(const Value: Integer);
    procedure SetSliderWidth(const Value: Single);
    procedure SetShowZoomPercent(const Value: Boolean);
    procedure SetActiveView(const Value: TFmrStatusView);
    procedure SetViews(const Value: TFmrStatusViews);
    function IsPanelWidthStored: Boolean;
    function IsMinWidthStored: Boolean;
    function IsSliderWidthStored: Boolean;
    procedure GlyphChanged(Sender: TObject);
    procedure ThemeChanged(Sender: TObject);
    function GetStatusBar: TFmrStatusBar;
    function Images: TCustomImageList;
    function Painter: TFmrRibbonPainter;
    function Theme: TFmrTheme;
    function FontSize: Single;
    function TextColor: TAlphaColor;
    function EffectiveBevel: TFmrStatusPanelBevel;
    function IsClickable: Boolean;
    procedure UpdateGeometry;
    function LinkWidth(const ALink: TFmrItemLink): Single;
    function LinkShowsCaption(const ALink: TFmrItemLink): Boolean;
    function LinkIsChecked(const ALink: TFmrItemLink): Boolean;
    function PercentText: string;
    function PartAt(const P: TPointF; out AIndex: Integer): TFmrStatusPart;
    function ThumbRect: TRectF;
    function ZoomAtX(const X: Single): Integer;
    procedure SetHot(const APart: TFmrStatusPart; const AIndex: Integer);
    procedure PanelChanged(const ALayout: Boolean);
    procedure PaintPartFill(const R: TRectF; const AHot, APressed, AChecked: Boolean);
    procedure PaintText;
    procedure PaintLinks;
    procedure PaintZoom;
    procedure PaintViews;
    procedure PaintBevel;
    procedure DrawViewGlyph(const R: TRectF; const AView: TFmrStatusView; const AColor: TAlphaColor);
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure VisibleChanged; override;
    procedure EnabledChanged; override;
    procedure ParentChanged; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure Click; override;
    function HasHint: Boolean; override;
    function GetHintString: string; override;
    procedure DoZoomChange; virtual;
    procedure DoViewChange; virtual;
    procedure DoZoomClick; virtual;
    procedure DoLinkClick(const ALink: TFmrItemLink); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Width the panel wants (PanelWidth when set, otherwise its measured content), dp.</summary>
    function MeasureWidth: Single;
    /// <summary>Changes the zoom like a click on - (AUp = False) or + does.</summary>
    procedure StepZoom(const AUp: Boolean);
    /// <summary>The status bar the panel belongs to (nil when the parent is something else).</summary>
    property StatusBar: TFmrStatusBar read GetStatusBar;
    /// <summary>Part under the mouse (hot tracking).</summary>
    property HotPart: TFmrStatusPart read FHotPart;
  published
    property Kind: TFmrStatusPanelKind read FKind write SetKind default TFmrStatusPanelKind.Text;
    property Side: TFmrStatusPanelSide read FSide write SetSide default TFmrStatusPanelSide.Left;
    property Text: string read FText write SetText;
    /// <summary>Fixed width in dp; 0 = fit the content (Container panels without a width are 100 dp wide).
    /// </summary>
    property PanelWidth: Single read FPanelWidth write SetPanelWidth stored IsPanelWidthStored;
    property MinWidth: Single read FMinWidth write SetMinWidth stored IsMinWidthStored;
    /// <summary>The panel takes a share of the free width of the status bar.</summary>
    property Stretch: Boolean read FStretch write SetStretch default False;
    /// <summary>Alignment of the text when the panel is wider than its text.</summary>
    property Alignment: TTextAlign read FAlignment write SetAlignment default TTextAlign.Leading;
    property Bevel: TFmrStatusPanelBevel read FBevel write SetBevel default TFmrStatusPanelBevel.Auto;
    /// <summary>Glyph before the text (Text panels).</summary>
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    /// <summary>Links shown by an ItemLinks panel (items of a TFmrBarManager).</summary>
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    { zoom slider }
    property Zoom: Integer read FZoom write SetZoom default 100;
    property ZoomMin: Integer read FZoomMin write SetZoomMin default 10;
    property ZoomMax: Integer read FZoomMax write SetZoomMax default 500;
    /// <summary>Step of the - / + buttons (the zoom goes to the next multiple of the step).</summary>
    property ZoomStep: Integer read FZoomStep write SetZoomStep default 10;
    /// <summary>Width of the slider track, dp.</summary>
    property SliderWidth: Single read FSliderWidth write SetSliderWidth stored IsSliderWidthStored;
    property ShowZoomPercent: Boolean read FShowZoomPercent write SetShowZoomPercent default True;
    { view buttons }
    property ActiveView: TFmrStatusView read FActiveView write SetActiveView default TFmrStatusView.Print;
    /// <summary>Which view buttons are shown.</summary>
    property Views: TFmrStatusViews read FViews write SetViews
      default [TFmrStatusView.Read, TFmrStatusView.Print, TFmrStatusView.Web];
    { inherited }
    property Enabled;
    property Hint;
    property ShowHint default True;
    property Padding;
    property ClipChildren default True;
    property Visible;
    property TabOrder;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnResize;
    { events }
    /// <summary>Zoom changed (slider, buttons or code).</summary>
    property OnZoomChange: TNotifyEvent read FOnZoomChange write FOnZoomChange;
    /// <summary>Click on the percentage (Word opens its Zoom dialog).</summary>
    property OnZoomClick: TNotifyEvent read FOnZoomClick write FOnZoomClick;
    /// <summary>ActiveView changed by a click on a view button or by code.</summary>
    property OnViewChange: TNotifyEvent read FOnViewChange write FOnViewChange;
  end;

  /// <summary>Office-like status bar; see the unit description.</summary>
  TFmrStatusBar = class(TControl, IFmrThemeProvider, IFmrBarManagerListener)
  private
    FThemeLink: TFmrThemeLink;
    FBarManager: TFmrBarManager;
    FAutoHeight: Boolean;
    FPanelSpacing: Single;
    FShowSizeGrip: Boolean;
    FSizeGrip: TControl;
    FRealigning: Boolean;
    FOnLinkClick: TFmrStatusLinkClickEvent;
    function GetThemeName: string;
    procedure SetThemeName(const Value: string);
    function GetAccentColor: TAlphaColor;
    procedure SetAccentColor(const Value: TAlphaColor);
    function GetThemeProvider: TFmxObject;
    procedure SetThemeProvider(const Value: TFmxObject);
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetAutoHeight(const Value: Boolean);
    procedure SetPanelSpacing(const Value: Single);
    procedure SetShowSizeGrip(const Value: Boolean);
    function IsThemeNameStored: Boolean;
    function IsPanelSpacingStored: Boolean;
    function GetPanelCount: Integer;
    function GetPanel(const AIndex: Integer): TFmrStatusBarPanel;
    procedure ThemeChanged(Sender: TObject);
    procedure UpdateHeight;
    procedure UpdateSizeGrip;
    { IFmrThemeProvider }
    function GetFmrTheme: TFmrTheme;
    { IFmrBarManagerListener }
    procedure BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
      const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
  protected
    procedure Paint; override;
    procedure DoRealign; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoAddObject(const AObject: TFmxObject); override;
    procedure DoRemoveObject(const AObject: TFmxObject); override;
    function GetDefaultSize: TSizeF; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Creates a panel as a child of the status bar, owned by the owner of the status bar.</summary>
    function AddPanel(const AKind: TFmrStatusPanelKind = TFmrStatusPanelKind.Text; const AText: string = '';
      const ASide: TFmrStatusPanelSide = TFmrStatusPanelSide.Left): TFmrStatusBarPanel;
    /// <summary>The theme the status bar paints with.</summary>
    function CurrentTheme: TFmrTheme;
    /// <summary>The painter bound to CurrentTheme.</summary>
    function Painter: TFmrRibbonPainter;
    /// <summary>Re-measures and places the panels.</summary>
    procedure UpdatePanels;
    property PanelCount: Integer read GetPanelCount;
    property Panels[const AIndex: Integer]: TFmrStatusBarPanel read GetPanel;
    property ThemeLink: TFmrThemeLink read FThemeLink;
  published
    property Align default TAlignLayout.Bottom;
    property Anchors;
    /// <summary>Height follows the theme metric StatusBarHeight.</summary>
    property AutoHeight: Boolean read FAutoHeight write SetAutoHeight default True;
    /// <summary>Source of the images of ItemLinks panels (items also use the images of their own manager).
    /// </summary>
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    property Enabled;
    property Height;
    property Hint;
    property Margins;
    property Opacity;
    property Padding;
    /// <summary>Gap between neighboring panels, dp.</summary>
    property PanelSpacing: Single read FPanelSpacing write SetPanelSpacing stored IsPanelSpacingStored;
    property ParentShowHint;
    property Position;
    property ShowHint;
    /// <summary>Paints a size grip at the right end; dragging it resizes the form (not needed for windows
    /// with a sizing border).</summary>
    property ShowSizeGrip: Boolean read FShowSizeGrip write SetShowSizeGrip default False;
    property Size;
    /// <summary>Built-in theme used when no theme provider is set.</summary>
    property Theme: string read GetThemeName write SetThemeName stored IsThemeNameStored;
    /// <summary>Accent color of the own theme (0 = the theme's default).</summary>
    property AccentColor: TAlphaColor read GetAccentColor write SetAccentColor default TAlphaColors.Null;
    /// <summary>Object whose theme is used (an object implementing IFmrThemeProvider, normally the TFmrRibbon).
    /// </summary>
    property ThemeProvider: TFmxObject read GetThemeProvider write SetThemeProvider;
    property Visible;
    property Width;
    property OnLinkClick: TFmrStatusLinkClickEvent read FOnLinkClick write FOnLinkClick;
    property OnClick;
    property OnResize;
  end;

resourcestring
  SFmrStatusZoomIn = 'Zoom In';
  SFmrStatusZoomOut = 'Zoom Out';
  SFmrStatusZoom = 'Zoom';
  SFmrStatusZoomLevel = 'Zoom level';
  SFmrStatusReadMode = 'Read Mode';
  SFmrStatusPrintLayout = 'Print Layout';
  SFmrStatusWebLayout = 'Web Layout';

implementation

const
  PanelPaddingH = 7;
  GlyphSize = 16;
  GlyphGap = 4;
  LinkButtonPadding = 4;
  LinkSeparatorWidth = 7;
  ZoomButtonWidth = 20;
  ViewButtonWidth = 26;
  ViewButtonGap = 1;
  SizeGripWidth = 14;
  ThumbWidth = 5;
  ThumbHeight = 13;
  SnapDistance = 4;

type
  /// Size grip of the status bar (the form resizes when a control supporting ISizeGrip is dragged).
  TFmrStatusSizeGrip = class(TControl, ISizeGrip)
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

{ TFmrStatusSizeGrip }

constructor TFmrStatusSizeGrip.Create(AOwner: TComponent);
begin
  inherited;
  Stored := False;
  Locked := True;
  Cursor := crSizeNWSE;
end;

procedure TFmrStatusSizeGrip.Paint;
var
  Bar: TFmrStatusBar;
  C: TAlphaColor;
  I, J: Integer;
  X, Y: Single;
begin
  if not (Parent is TFmrStatusBar) then
    Exit;
  Bar := TFmrStatusBar(Parent);
  C := FmrWithAlpha(Bar.CurrentTheme.Colors[TFmrToken.StatusBarText], 0.55);
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := C;
  // three rows of dots forming a triangle in the bottom right corner
  for I := 0 to 2 do
    for J := 0 to I do
    begin
      X := Width - 3 - J * 4;
      Y := Height - 3 - (2 - I + J) * 4;
      if Y > 0 then
        Canvas.FillRect(RectF(X - 1, Y - 1, X + 1, Y + 1), 0, 0, [], AbsoluteOpacity);
    end;
end;

{ TFmrStatusBarPanel }

constructor TFmrStatusBarPanel.Create(AOwner: TComponent);
begin
  inherited;
  FThemeLink := TFmrThemeLink.Create(Self, ThemeChanged);
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
  FItemLinks := TFmrItemLinks.Create(Self);
  FAlignment := TTextAlign.Leading;
  FZoom := 100;
  FZoomMin := 10;
  FZoomMax := 500;
  FZoomStep := 10;
  FSliderWidth := 100;
  FShowZoomPercent := True;
  FActiveView := TFmrStatusView.Print;
  FViews := [TFmrStatusView.Read, TFmrStatusView.Print, TFmrStatusView.Web];
  FHotIndex := -1;
  FPressedIndex := -1;
  ShowHint := True;
  ClipChildren := True;
  HitTest := True;
  SetBounds(0, 0, 80, 23);
end;

destructor TFmrStatusBarPanel.Destroy;
begin
  FreeAndNil(FItemLinks);
  FGlyph.Free;
  FThemeLink.Free;
  inherited;
end;

function TFmrStatusBarPanel.GetStatusBar: TFmrStatusBar;
begin
  if Parent is TFmrStatusBar then
    Result := TFmrStatusBar(Parent)
  else
    Result := nil;
end;

function TFmrStatusBarPanel.Images: TCustomImageList;
begin
  if (StatusBar <> nil) and (StatusBar.BarManager <> nil) then
    Result := StatusBar.BarManager.Images
  else
    Result := nil;
end;

function TFmrStatusBarPanel.Painter: TFmrRibbonPainter;
begin
  Result := FThemeLink.Painter;
end;

function TFmrStatusBarPanel.Theme: TFmrTheme;
begin
  Result := FThemeLink.Theme;
end;

function TFmrStatusBarPanel.FontSize: Single;
begin
  Result := Theme.Metrics.FontSize;
end;

function TFmrStatusBarPanel.TextColor: TAlphaColor;
begin
  Result := Theme.Colors[TFmrToken.StatusBarText];
end;

function TFmrStatusBarPanel.EffectiveBevel: TFmrStatusPanelBevel;
begin
  Result := FBevel;
  if Result = TFmrStatusPanelBevel.Auto then
    if Theme.Style.Family in [TFmrThemeFamily.Office2007, TFmrThemeFamily.Office2010] then
      Result := TFmrStatusPanelBevel.Separator
    else
      Result := TFmrStatusPanelBevel.None;
end;

function TFmrStatusBarPanel.IsClickable: Boolean;
begin
  Result := (FKind = TFmrStatusPanelKind.Text) and Assigned(OnClick) and AbsoluteEnabled;
end;

procedure TFmrStatusBarPanel.ThemeChanged(Sender: TObject);
begin
  FGeometryValid := False;
  Repaint;
end;

procedure TFmrStatusBarPanel.GlyphChanged(Sender: TObject);
begin
  PanelChanged(True);
end;

procedure TFmrStatusBarPanel.PanelChanged(const ALayout: Boolean);
begin
  FGeometryValid := False;
  if [csLoading, csDestroying] * ComponentState <> [] then
    Exit;
  if ALayout and (StatusBar <> nil) then
    StatusBar.UpdatePanels;
  Repaint;
end;

procedure TFmrStatusBarPanel.ParentChanged;
begin
  inherited;
  FGeometryValid := False;
end;

procedure TFmrStatusBarPanel.Resize;
begin
  inherited;
  FGeometryValid := False;
end;

procedure TFmrStatusBarPanel.VisibleChanged;
begin
  inherited;
  if not (csLoading in ComponentState) and (StatusBar <> nil) then
    StatusBar.UpdatePanels;
end;

procedure TFmrStatusBarPanel.EnabledChanged;
begin
  inherited;
  Repaint;
end;

{ properties }

procedure TFmrStatusBarPanel.SetKind(const Value: TFmrStatusPanelKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    SetHot(TFmrStatusPart.None, -1);
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetSide(const Value: TFmrStatusPanelSide);
begin
  if FSide <> Value then
  begin
    FSide := Value;
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetText(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    PanelChanged(FPanelWidth <= 0);
  end;
end;

procedure TFmrStatusBarPanel.SetPanelWidth(const Value: Single);
begin
  if not SameValue(FPanelWidth, Value) then
  begin
    FPanelWidth := Max(0, Value);
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetMinWidth(const Value: Single);
begin
  if not SameValue(FMinWidth, Value) then
  begin
    FMinWidth := Max(0, Value);
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetStretch(const Value: Boolean);
begin
  if FStretch <> Value then
  begin
    FStretch := Value;
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetAlignment(const Value: TTextAlign);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    PanelChanged(False);
  end;
end;

procedure TFmrStatusBarPanel.SetBevel(const Value: TFmrStatusPanelBevel);
begin
  if FBevel <> Value then
  begin
    FBevel := Value;
    PanelChanged(False);
  end;
end;

procedure TFmrStatusBarPanel.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrStatusBarPanel.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrStatusBarPanel.SetZoom(const Value: Integer);
var
  Z: Integer;
begin
  if csLoading in ComponentState then
  begin
    FZoom := Value;
    Exit;
  end;
  Z := EnsureRange(Value, FZoomMin, Max(FZoomMin, FZoomMax));
  if FZoom <> Z then
  begin
    FZoom := Z;
    PanelChanged(False);
    DoZoomChange;
  end;
end;

procedure TFmrStatusBarPanel.SetZoomMin(const Value: Integer);
begin
  if FZoomMin <> Value then
  begin
    FZoomMin := Max(1, Value);
    if not (csLoading in ComponentState) then
      SetZoom(FZoom);
    PanelChanged(False);
  end;
end;

procedure TFmrStatusBarPanel.SetZoomMax(const Value: Integer);
begin
  if FZoomMax <> Value then
  begin
    FZoomMax := Max(1, Value);
    if not (csLoading in ComponentState) then
      SetZoom(FZoom);
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetZoomStep(const Value: Integer);
begin
  FZoomStep := Max(1, Value);
end;

procedure TFmrStatusBarPanel.SetSliderWidth(const Value: Single);
begin
  if not SameValue(FSliderWidth, Value) then
  begin
    FSliderWidth := Max(20, Value);
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetShowZoomPercent(const Value: Boolean);
begin
  if FShowZoomPercent <> Value then
  begin
    FShowZoomPercent := Value;
    PanelChanged(True);
  end;
end;

procedure TFmrStatusBarPanel.SetActiveView(const Value: TFmrStatusView);
begin
  if FActiveView <> Value then
  begin
    FActiveView := Value;
    PanelChanged(False);
    if not (csLoading in ComponentState) then
      DoViewChange;
  end;
end;

procedure TFmrStatusBarPanel.SetViews(const Value: TFmrStatusViews);
begin
  if FViews <> Value then
  begin
    FViews := Value;
    PanelChanged(True);
  end;
end;

function TFmrStatusBarPanel.IsPanelWidthStored: Boolean;
begin
  Result := FPanelWidth <> 0;
end;

function TFmrStatusBarPanel.IsMinWidthStored: Boolean;
begin
  Result := FMinWidth <> 0;
end;

function TFmrStatusBarPanel.IsSliderWidthStored: Boolean;
begin
  Result := not SameValue(FSliderWidth, 100);
end;

{ IFmrItemLinksOwner }

procedure TFmrStatusBarPanel.LinksChanged(const ALinks: TFmrItemLinks);
begin
  PanelChanged(True);
end;

procedure TFmrStatusBarPanel.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  PanelChanged(AChange = TFmrItemChange.Layout);
end;

procedure TFmrStatusBarPanel.LinkRemoving(const ALink: TFmrItemLink);
begin
  FHotPart := TFmrStatusPart.None;
  FHotIndex := -1;
  FPressedPart := TFmrStatusPart.None;
  FPressedIndex := -1;
  FGeometryValid := False;
end;

{ links }

function TFmrStatusBarPanel.LinkShowsCaption(const ALink: TFmrItemLink): Boolean;
begin
  Result := (ALink.Item <> nil) and ((ALink.ViewLevels = [TFmrViewLevel.SmallWithText]) or
    (ALink.Item is TFmrStaticItem) or ALink.Item.Glyph.IsEmpty(Images));
end;

function TFmrStatusBarPanel.LinkIsChecked(const ALink: TFmrItemLink): Boolean;
begin
  Result := (ALink.Item <> nil) and ALink.Item.IsChecked;
end;

function TFmrStatusBarPanel.LinkWidth(const ALink: TFmrItemLink): Single;
var
  HasGlyph: Boolean;
begin
  if (ALink.Item = nil) or (ALink.Item is TFmrSeparatorItem) then
    Exit(LinkSeparatorWidth);
  HasGlyph := not ALink.Item.Glyph.IsEmpty(Images);
  Result := LinkButtonPadding * 2;
  if HasGlyph then
    Result := Result + GlyphSize;
  if LinkShowsCaption(ALink) and (ALink.Caption <> '') then
  begin
    if HasGlyph then
      Result := Result + GlyphGap;
    Result := Result + Painter.TextWidth(ALink.Caption.Replace('&', ''), FontSize);
  end;
  if (ALink.Item is TFmrStaticItem) and (TFmrStaticItem(ALink.Item).Width > 0) then
    Result := TFmrStaticItem(ALink.Item).Width;
  Result := Max(Result, 22);
end;

{ geometry }

function TFmrStatusBarPanel.PercentText: string;
begin
  Result := IntToStr(FZoom) + '%';
end;

function TFmrStatusBarPanel.MeasureWidth: Single;
var
  I: Integer;
  L: TFmrItemLink;
  V: TFmrStatusView;
  N: Integer;
begin
  if FPanelWidth > 0 then
    Exit(FPanelWidth);
  case FKind of
    TFmrStatusPanelKind.Text:
      begin
        Result := PanelPaddingH * 2;
        if not FGlyph.IsEmpty(Images) then
        begin
          Result := Result + GlyphSize;
          if FText <> '' then
            Result := Result + GlyphGap;
        end;
        if FText <> '' then
          Result := Result + Painter.TextWidth(FText, FontSize);
      end;
    TFmrStatusPanelKind.Container:
      Result := 100;
    TFmrStatusPanelKind.ItemLinks:
      begin
        Result := 4;
        for I := 0 to FItemLinks.Count - 1 do
        begin
          L := FItemLinks[I];
          if not L.IsVisible then
            Continue;
          if L.BeginGroup and (Result > 4) then
            Result := Result + LinkSeparatorWidth;
          Result := Result + LinkWidth(L);
        end;
        Result := Result + 4;
      end;
    TFmrStatusPanelKind.ZoomSlider:
      begin
        Result := 4 + ZoomButtonWidth + 2 + FSliderWidth + 2 + ZoomButtonWidth + 4;
        if FShowZoomPercent then
          Result := Result + Max(Painter.TextWidth(IntToStr(FZoomMax) + '%', FontSize), 30) + 10;
      end;
    TFmrStatusPanelKind.ViewButtons:
      begin
        N := 0;
        for V := Low(TFmrStatusView) to High(TFmrStatusView) do
          if V in FViews then
            Inc(N);
        Result := 4 + N * ViewButtonWidth + Max(0, N - 1) * ViewButtonGap + 4;
      end;
  else
    Result := 60;
  end;
  Result := Max(Result, FMinWidth);
end;

procedure TFmrStatusBarPanel.UpdateGeometry;
var
  R: TRectF;
  X, CY, W: Single;
  I: Integer;
  L: TFmrItemLink;
  V: TFmrStatusView;
begin
  if FGeometryValid then
    Exit;
  FGeometryValid := True;
  R := LocalRect;
  CY := R.Height / 2;
  case FKind of
    TFmrStatusPanelKind.ItemLinks:
      begin
        SetLength(FLinkRects, FItemLinks.Count);
        FSeparators := nil;
        X := 4;
        for I := 0 to FItemLinks.Count - 1 do
        begin
          L := FItemLinks[I];
          FLinkRects[I] := TRectF.Empty;
          if not L.IsVisible then
            Continue;
          if L.BeginGroup and (X > 4) then
          begin
            FSeparators := FSeparators + [X + LinkSeparatorWidth / 2];
            X := X + LinkSeparatorWidth;
          end;
          W := LinkWidth(L);
          if L.Item is TFmrSeparatorItem then
            FSeparators := FSeparators + [X + W / 2]
          else
            FLinkRects[I] := RectF(X, 1, X + W, R.Height - 1);
          X := X + W;
        end;
      end;
    TFmrStatusPanelKind.ZoomSlider:
      begin
        X := 4;
        FMinusRect := RectF(X, 1, X + ZoomButtonWidth, R.Height - 1);
        X := FMinusRect.Right + 2;
        W := FSliderWidth;
        if FPanelWidth > 0 then
        begin
          // a fixed width panel gives the track what is left
          W := R.Width - 4 - ZoomButtonWidth * 2 - 4 - 4;
          if FShowZoomPercent then
            W := W - Max(Painter.TextWidth(IntToStr(FZoomMax) + '%', FontSize), 30) - 10;
          W := Max(20, W);
        end;
        FTrackRect := RectF(X + ThumbWidth / 2, CY - ThumbHeight / 2, X + W - ThumbWidth / 2, CY + ThumbHeight / 2);
        X := X + W + 2;
        FPlusRect := RectF(X, 1, X + ZoomButtonWidth, R.Height - 1);
        X := FPlusRect.Right + 2;
        if FShowZoomPercent then
          FPercentRect := RectF(X, 1, R.Width - 2, R.Height - 1)
        else
          FPercentRect := TRectF.Empty;
      end;
    TFmrStatusPanelKind.ViewButtons:
      begin
        X := 4;
        for V := Low(TFmrStatusView) to High(TFmrStatusView) do
          if V in FViews then
          begin
            FViewRects[V] := RectF(X, 1, X + ViewButtonWidth, R.Height - 1);
            X := X + ViewButtonWidth + ViewButtonGap;
          end
          else
            FViewRects[V] := TRectF.Empty;
      end;
  end;
end;

function TFmrStatusBarPanel.ThumbRect: TRectF;
var
  X: Single;
begin
  UpdateGeometry;
  X := FTrackRect.Left + FTrackRect.Width * FmrZoomToFraction(FZoom, FZoomMin, FZoomMax);
  Result := RectF(X - ThumbWidth / 2, FTrackRect.Top, X + ThumbWidth / 2, FTrackRect.Bottom);
end;

function TFmrStatusBarPanel.ZoomAtX(const X: Single): Integer;
var
  CenterX: Single;
begin
  UpdateGeometry;
  if FTrackRect.Width <= 0 then
    Exit(FZoom);
  CenterX := FTrackRect.Left + FTrackRect.Width * FmrZoomToFraction(100, FZoomMin, FZoomMax);
  if (FZoomMin < 100) and (FZoomMax > 100) and (Abs(X - CenterX) <= SnapDistance) then
    Exit(100);
  Result := FmrFractionToZoom((X - FTrackRect.Left) / FTrackRect.Width, FZoomMin, FZoomMax);
end;

function TFmrStatusBarPanel.PartAt(const P: TPointF; out AIndex: Integer): TFmrStatusPart;
var
  I: Integer;
  V: TFmrStatusView;
  Track: TRectF;
begin
  AIndex := -1;
  Result := TFmrStatusPart.None;
  if not LocalRect.Contains(P) then
    Exit;
  UpdateGeometry;
  case FKind of
    TFmrStatusPanelKind.ItemLinks:
      for I := 0 to High(FLinkRects) do
        if not FLinkRects[I].IsEmpty and FLinkRects[I].Contains(P) then
        begin
          AIndex := I;
          Exit(TFmrStatusPart.Link);
        end;
    TFmrStatusPanelKind.ZoomSlider:
      begin
        if FMinusRect.Contains(P) then
          Exit(TFmrStatusPart.ZoomOut);
        if FPlusRect.Contains(P) then
          Exit(TFmrStatusPart.ZoomIn);
        if ThumbRect.Contains(P) then
          Exit(TFmrStatusPart.ZoomThumb);
        Track := RectF(FTrackRect.Left - ThumbWidth / 2, 0, FTrackRect.Right + ThumbWidth / 2, Height);
        if Track.Contains(P) then
          Exit(TFmrStatusPart.ZoomTrack);
        if not FPercentRect.IsEmpty and FPercentRect.Contains(P) then
          Exit(TFmrStatusPart.ZoomPercent);
      end;
    TFmrStatusPanelKind.ViewButtons:
      for V := Low(TFmrStatusView) to High(TFmrStatusView) do
        if not FViewRects[V].IsEmpty and FViewRects[V].Contains(P) then
        begin
          AIndex := Ord(V);
          Exit(TFmrStatusPart.View);
        end;
  else
    Result := TFmrStatusPart.Body;
  end;
end;

{ mouse }

procedure TFmrStatusBarPanel.SetHot(const APart: TFmrStatusPart; const AIndex: Integer);
begin
  if (FHotPart <> APart) or (FHotIndex <> AIndex) then
  begin
    // A different part has a different hint: FMX asks a control for its hint only when the mouse enters it, so the
    // hint is released and asked for again (the form calls TriggerControlHint right after MouseMove)
    if (APart <> TFmrStatusPart.None) and not (csDesigning in ComponentState) and (Application <> nil) then
      Application.HideHint;
    FHotPart := APart;
    FHotIndex := AIndex;
    Repaint;
  end;
end;

procedure TFmrStatusBarPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Part: TFmrStatusPart;
  Index: Integer;
begin
  inherited;
  FClickPart := TFmrStatusPart.None;
  if (Button <> TMouseButton.mbLeft) or not AbsoluteEnabled then
    Exit;
  Part := PartAt(PointF(X, Y), Index);
  FClickPart := Part;
  FPressedPart := Part;
  FPressedIndex := Index;
  case Part of
    TFmrStatusPart.ZoomThumb, TFmrStatusPart.ZoomTrack:
      begin
        FDragging := True;
        Capture;
        if Part = TFmrStatusPart.ZoomTrack then
          Zoom := ZoomAtX(X);
      end;
    TFmrStatusPart.ZoomOut:
      StepZoom(False);
    TFmrStatusPart.ZoomIn:
      StepZoom(True);
  end;
  Repaint;
end;

procedure TFmrStatusBarPanel.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Part: TFmrStatusPart;
  Index: Integer;
begin
  inherited;
  if FDragging then
  begin
    Zoom := ZoomAtX(X);
    Exit;
  end;
  Part := PartAt(PointF(X, Y), Index);
  SetHot(Part, Index);
end;

procedure TFmrStatusBarPanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Part: TFmrStatusPart;
  Index: Integer;
  WasPressed: TFmrStatusPart;
  PressedIndex: Integer;
begin
  WasPressed := FPressedPart;
  PressedIndex := FPressedIndex;
  FPressedPart := TFmrStatusPart.None;
  FPressedIndex := -1;
  if FDragging then
  begin
    FDragging := False;
    ReleaseCapture;
  end;
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    Part := PartAt(PointF(X, Y), Index);
    if (Part = WasPressed) and (Index = PressedIndex) and AbsoluteEnabled then
      case Part of
        TFmrStatusPart.View:
          ActiveView := TFmrStatusView(Index);
        TFmrStatusPart.Link:
          if (Index >= 0) and (Index < FItemLinks.Count) then
            DoLinkClick(FItemLinks[Index]);
        TFmrStatusPart.ZoomPercent:
          DoZoomClick;
      end;
    SetHot(Part, Index);
  end;
  Repaint;
end;

procedure TFmrStatusBarPanel.DoMouseLeave;
begin
  inherited;
  if not FDragging then
  begin
    FHotPart := TFmrStatusPart.None;
    FHotIndex := -1;
    Repaint;
  end;
end;

procedure TFmrStatusBarPanel.Click;
begin
  // OnClick belongs to the body of the panel, not to its buttons
  if FClickPart in [TFmrStatusPart.None, TFmrStatusPart.Body] then
    inherited;
end;

procedure TFmrStatusBarPanel.StepZoom(const AUp: Boolean);
begin
  Zoom := FmrZoomStep(FZoom, FZoomStep, FZoomMin, FZoomMax, AUp);
end;

procedure TFmrStatusBarPanel.DoZoomChange;
begin
  if Assigned(FOnZoomChange) then
    FOnZoomChange(Self);
end;

procedure TFmrStatusBarPanel.DoViewChange;
begin
  if Assigned(FOnViewChange) then
    FOnViewChange(Self);
end;

procedure TFmrStatusBarPanel.DoZoomClick;
begin
  if Assigned(FOnZoomClick) then
    FOnZoomClick(Self);
end;

procedure TFmrStatusBarPanel.DoLinkClick(const ALink: TFmrItemLink);
var
  Handled: Boolean;
begin
  Handled := False;
  if (StatusBar <> nil) and Assigned(StatusBar.OnLinkClick) then
    StatusBar.OnLinkClick(StatusBar, Self, ALink, Handled);
  if not Handled and (ALink.Item <> nil) then
    ALink.Item.Click;
end;

{ hints }

function TFmrStatusBarPanel.GetHintString: string;
begin
  case FHotPart of
    TFmrStatusPart.ZoomOut:
      Result := SFmrStatusZoomOut;
    TFmrStatusPart.ZoomIn:
      Result := SFmrStatusZoomIn;
    TFmrStatusPart.ZoomTrack, TFmrStatusPart.ZoomThumb:
      Result := SFmrStatusZoom;
    TFmrStatusPart.ZoomPercent:
      Result := SFmrStatusZoomLevel;
    TFmrStatusPart.View:
      case TFmrStatusView(EnsureRange(FHotIndex, 0, 2)) of
        TFmrStatusView.Read: Result := SFmrStatusReadMode;
        TFmrStatusView.Print: Result := SFmrStatusPrintLayout;
      else
        Result := SFmrStatusWebLayout;
      end;
    TFmrStatusPart.Link:
      if (FHotIndex >= 0) and (FHotIndex < FItemLinks.Count) and (FItemLinks[FHotIndex].Item <> nil) then
      begin
        Result := FItemLinks[FHotIndex].Item.Hint;
        if Result = '' then
          Result := FItemLinks[FHotIndex].Caption.Replace('&', '');
      end
      else
        Result := '';
  else
    Result := inherited GetHintString;
  end;
  if (Result = '') and (FHotPart <> TFmrStatusPart.Body) then
    Result := inherited GetHintString;
end;

function TFmrStatusBarPanel.HasHint: Boolean;
begin
  Result := CanShowHint and (GetHintString <> '');
end;

{ painting }

procedure TFmrStatusBarPanel.PaintPartFill(const R: TRectF; const AHot, APressed, AChecked: Boolean);
var
  Hot: TFmrFill;
  C: TAlphaColor;
  Rad: Single;
begin
  Hot := Theme.Fills[TFmrToken.StatusBarItemHotFill];
  Rad := Min(Theme.Metrics.ButtonRadius, 3);
  C := Hot.MainColor;
  if APressed then
    Painter.Fill(Canvas, R, TFmrFill.Solid(FmrBlend(C, TextColor, 0.18)), Rad, [], AbsoluteOpacity)
  else if AChecked and AHot then
    Painter.Fill(Canvas, R, TFmrFill.Solid(FmrBlend(C, TextColor, 0.14)), Rad, [], AbsoluteOpacity)
  else if AChecked then
    Painter.Fill(Canvas, R, TFmrFill.Solid(FmrBlend(C, TextColor, 0.08)), Rad, [], AbsoluteOpacity)
  else if AHot then
    Painter.Fill(Canvas, R, Hot, Rad, [], AbsoluteOpacity);
  if AChecked then
    Painter.Frame(Canvas, R, FmrWithAlpha(TextColor, 0.35), Rad, [], 1, AbsoluteOpacity);
end;

procedure TFmrStatusBarPanel.PaintBevel;
var
  R: TRectF;
  X: Single;
  C: TAlphaColor;
begin
  R := LocalRect;
  C := Theme.Colors[TFmrToken.StatusBarSeparator];
  case EffectiveBevel of
    TFmrStatusPanelBevel.Separator:
      begin
        if FSide = TFmrStatusPanelSide.Left then
          X := Round(R.Right) - 0.5
        else
          X := Round(R.Left) + 0.5;
        Painter.Line(Canvas, PointF(X, R.Top + 4), PointF(X, R.Bottom - 4), C, 1, AbsoluteOpacity);
      end;
    TFmrStatusPanelBevel.Frame:
      Painter.Frame(Canvas, RectF(R.Left + 1, R.Top + 2, R.Right - 1, R.Bottom - 2), C, 0, [], 1, AbsoluteOpacity);
  end;
end;

procedure TFmrStatusBarPanel.PaintText;
var
  R, G: TRectF;
  Op: Single;
  Hot: Boolean;
begin
  R := LocalRect;
  Op := AbsoluteOpacity;
  if not AbsoluteEnabled then
    Op := Op * 0.45;
  Hot := IsClickable and (FHotPart = TFmrStatusPart.Body);
  if Hot then
    PaintPartFill(RectF(R.Left, R.Top + 1, R.Right, R.Bottom - 1), True, FPressedPart = TFmrStatusPart.Body, False);
  R.Inflate(-PanelPaddingH, 0);
  if not FGlyph.IsEmpty(Images) then
  begin
    G := RectF(R.Left, R.CenterPoint.Y - GlyphSize / 2, R.Left + GlyphSize, R.CenterPoint.Y + GlyphSize / 2);
    FGlyph.Draw(Canvas, G, Op, TextColor, Images);
    R.Left := G.Right + GlyphGap;
  end;
  Painter.TextEx(Canvas, R, FText, TextColor, FAlignment, TTextAlign.Center, FontSize, False, False,
    TTextTrimming.Character, Op);
end;

procedure TFmrStatusBarPanel.PaintLinks;
var
  I: Integer;
  L: TFmrItemLink;
  R, G, T: TRectF;
  X, Op: Single;
  Enabled, HasGlyph: Boolean;
begin
  UpdateGeometry;
  for X in FSeparators do
    Painter.Line(Canvas, PointF(Round(X) + 0.5, 5), PointF(Round(X) + 0.5, Height - 5),
      Theme.Colors[TFmrToken.StatusBarSeparator], 1, AbsoluteOpacity);
  for I := 0 to FItemLinks.Count - 1 do
  begin
    if (I > High(FLinkRects)) or FLinkRects[I].IsEmpty then
      Continue;
    L := FItemLinks[I];
    if L.Item = nil then
      Continue;
    R := FLinkRects[I];
    Enabled := L.Item.Enabled and AbsoluteEnabled;
    Op := AbsoluteOpacity;
    if not Enabled then
      Op := Op * 0.4;
    if not (L.Item is TFmrStaticItem) then
      PaintPartFill(R, Enabled and (FHotPart = TFmrStatusPart.Link) and (FHotIndex = I),
        Enabled and (FPressedPart = TFmrStatusPart.Link) and (FPressedIndex = I) and (FHotIndex = I),
        LinkIsChecked(L));
    T := R;
    T.Inflate(-LinkButtonPadding, 0);
    HasGlyph := not L.Item.Glyph.IsEmpty(Images);
    if HasGlyph then
    begin
      if LinkShowsCaption(L) and (L.Caption <> '') then
        G := RectF(T.Left, R.CenterPoint.Y - GlyphSize / 2, T.Left + GlyphSize, R.CenterPoint.Y + GlyphSize / 2)
      else
        G := RectF(R.CenterPoint.X - GlyphSize / 2, R.CenterPoint.Y - GlyphSize / 2, R.CenterPoint.X + GlyphSize / 2,
          R.CenterPoint.Y + GlyphSize / 2);
      L.Item.Glyph.Draw(Canvas, G, Op, TextColor, Images);
      T.Left := G.Right + GlyphGap;
    end;
    if LinkShowsCaption(L) then
      Painter.TextEx(Canvas, T, L.Caption.Replace('&', ''), TextColor, TTextAlign.Leading, TTextAlign.Center,
        FontSize, False, False, TTextTrimming.Character, Op);
  end;
end;

procedure TFmrStatusBarPanel.PaintZoom;
var
  C, Track: TAlphaColor;
  CY, X, Op: Single;
  Th: TRectF;
  Enabled: Boolean;
begin
  UpdateGeometry;
  Enabled := AbsoluteEnabled;
  Op := AbsoluteOpacity;
  if not Enabled then
    Op := Op * 0.45;
  C := TextColor;
  Track := FmrWithAlpha(C, 0.55 * TAlphaColorRec(C).A / 255);
  CY := Round(Height / 2) + 0.5;
  // - and + buttons
  PaintPartFill(FMinusRect, Enabled and (FHotPart = TFmrStatusPart.ZoomOut),
    Enabled and (FPressedPart = TFmrStatusPart.ZoomOut) and (FHotPart = TFmrStatusPart.ZoomOut), False);
  PaintPartFill(FPlusRect, Enabled and (FHotPart = TFmrStatusPart.ZoomIn),
    Enabled and (FPressedPart = TFmrStatusPart.ZoomIn) and (FHotPart = TFmrStatusPart.ZoomIn), False);
  X := FMinusRect.CenterPoint.X;
  Painter.Line(Canvas, PointF(X - 4.5, CY), PointF(X + 4.5, CY), C, 1, Op);
  X := FPlusRect.CenterPoint.X;
  Painter.Line(Canvas, PointF(X - 4.5, CY), PointF(X + 4.5, CY), C, 1, Op);
  X := Round(X) + 0.5;
  Painter.Line(Canvas, PointF(X, CY - 4.5), PointF(X, CY + 4.5), C, 1, Op);
  // track and the 100 % tick
  Painter.Line(Canvas, PointF(FTrackRect.Left, CY), PointF(FTrackRect.Right, CY), Track, 1, Op);
  if (FZoomMin < 100) and (FZoomMax > 100) then
  begin
    X := Round(FTrackRect.Left + FTrackRect.Width * FmrZoomToFraction(100, FZoomMin, FZoomMax)) + 0.5;
    Painter.Line(Canvas, PointF(X, CY - 4), PointF(X, CY + 4), Track, 1, Op);
  end;
  // thumb
  Th := ThumbRect;
  Th := RectF(Round(Th.Left), Th.Top, Round(Th.Left) + ThumbWidth, Th.Bottom);
  if Enabled and (FDragging or (FHotPart = TFmrStatusPart.ZoomThumb)) then
    Painter.Fill(Canvas, Th, TFmrFill.Solid(FmrBlend(C, Theme.Fills[TFmrToken.StatusBarFill].MainColor, 0.25)), 1,
      [], Op)
  else
    Painter.Fill(Canvas, Th, TFmrFill.Solid(C), 1, [], Op);
  // percentage
  if FShowZoomPercent and not FPercentRect.IsEmpty then
  begin
    PaintPartFill(FPercentRect, Enabled and Assigned(FOnZoomClick) and (FHotPart = TFmrStatusPart.ZoomPercent),
      Enabled and (FPressedPart = TFmrStatusPart.ZoomPercent) and (FHotPart = TFmrStatusPart.ZoomPercent), False);
    Painter.TextEx(Canvas, FPercentRect, PercentText, C, TTextAlign.Center, TTextAlign.Center, FontSize, False,
      False, TTextTrimming.None, Op);
  end;
end;

procedure TFmrStatusBarPanel.DrawViewGlyph(const R: TRectF; const AView: TFmrStatusView; const AColor: TAlphaColor);
var
  C: TPointF;
  B: TRectF;
  Stroke: TStrokeBrush;
  I: Integer;
  Op: Single;
begin
  C := PointF(Round(R.CenterPoint.X), Round(R.CenterPoint.Y));
  Op := AbsoluteOpacity;
  if not AbsoluteEnabled then
    Op := Op * 0.45;
  Stroke := TStrokeBrush.Create(TBrushKind.Solid, AColor);
  try
    Stroke.Thickness := 1;
    case AView of
      TFmrStatusView.Read:
        begin
          // an open book: two pages joined in the middle
          B := RectF(C.X - 7.5, C.Y - 5.5, C.X - 0.5, C.Y + 5.5);
          Canvas.DrawRect(B, 1, 1, AllCorners, Op, Stroke);
          B := RectF(C.X + 0.5, C.Y - 5.5, C.X + 7.5, C.Y + 5.5);
          Canvas.DrawRect(B, 1, 1, AllCorners, Op, Stroke);
          for I := 0 to 2 do
          begin
            Canvas.DrawLine(PointF(C.X - 5.5, C.Y - 2.5 + I * 2.5), PointF(C.X - 2.5, C.Y - 2.5 + I * 2.5), Op, Stroke);
            Canvas.DrawLine(PointF(C.X + 2.5, C.Y - 2.5 + I * 2.5), PointF(C.X + 5.5, C.Y - 2.5 + I * 2.5), Op, Stroke);
          end;
        end;
      TFmrStatusView.Print:
        begin
          // a page with lines of text
          B := RectF(C.X - 5.5, C.Y - 6.5, C.X + 5.5, C.Y + 6.5);
          Canvas.DrawRect(B, 0, 0, [], Op, Stroke);
          for I := 0 to 3 do
            Canvas.DrawLine(PointF(C.X - 3, C.Y - 3.5 + I * 2.5), PointF(C.X + 3, C.Y - 3.5 + I * 2.5), Op, Stroke);
        end;
      TFmrStatusView.Web:
        begin
          // a globe: circle, equator, meridian
          B := RectF(C.X - 6.5, C.Y - 6.5, C.X + 6.5, C.Y + 6.5);
          Canvas.DrawEllipse(B, Op, Stroke);
          Canvas.DrawEllipse(RectF(C.X - 3, C.Y - 6.5, C.X + 3, C.Y + 6.5), Op, Stroke);
          Canvas.DrawLine(PointF(C.X - 6.5, C.Y + 0.5), PointF(C.X + 6.5, C.Y + 0.5), Op, Stroke);
        end;
    end;
  finally
    Stroke.Free;
  end;
end;

procedure TFmrStatusBarPanel.PaintViews;
var
  V: TFmrStatusView;
  Enabled: Boolean;
begin
  UpdateGeometry;
  Enabled := AbsoluteEnabled;
  for V := Low(TFmrStatusView) to High(TFmrStatusView) do
  begin
    if FViewRects[V].IsEmpty then
      Continue;
    PaintPartFill(FViewRects[V], Enabled and (FHotPart = TFmrStatusPart.View) and (FHotIndex = Ord(V)),
      Enabled and (FPressedPart = TFmrStatusPart.View) and (FPressedIndex = Ord(V)) and (FHotIndex = Ord(V)),
      V = FActiveView);
    DrawViewGlyph(FViewRects[V], V, TextColor);
  end;
end;

procedure TFmrStatusBarPanel.Paint;
begin
  if (csDesigning in ComponentState) and (FKind = TFmrStatusPanelKind.Container) then
    DrawDesignBorder;
  case FKind of
    TFmrStatusPanelKind.Text:
      PaintText;
    TFmrStatusPanelKind.ItemLinks:
      PaintLinks;
    TFmrStatusPanelKind.ZoomSlider:
      PaintZoom;
    TFmrStatusPanelKind.ViewButtons:
      PaintViews;
  end;
  PaintBevel;
end;

{ TFmrStatusBar }

constructor TFmrStatusBar.Create(AOwner: TComponent);
begin
  inherited;
  FThemeLink := TFmrThemeLink.Create(Self, ThemeChanged);
  FAutoHeight := True;
  Align := TAlignLayout.Bottom;
  HitTest := True;
  SetBounds(0, 0, 400, 23);
end;

destructor TFmrStatusBar.Destroy;
begin
  if FBarManager <> nil then
    FBarManager.RemoveListener(Self);
  if FThemeLink.Provider <> nil then
    FThemeLink.Provider.RemoveFreeNotification(Self);
  FThemeLink.Free;
  FThemeLink := nil;
  inherited;
end;

function TFmrStatusBar.GetDefaultSize: TSizeF;
begin
  Result := TSizeF.Create(400, 23);
end;

function TFmrStatusBar.CurrentTheme: TFmrTheme;
begin
  Result := FThemeLink.Theme;
end;

function TFmrStatusBar.Painter: TFmrRibbonPainter;
begin
  Result := FThemeLink.Painter;
end;

function TFmrStatusBar.GetFmrTheme: TFmrTheme;
begin
  Result := FThemeLink.Theme;
end;

function TFmrStatusBar.GetThemeName: string;
begin
  Result := FThemeLink.ThemeName;
end;

procedure TFmrStatusBar.SetThemeName(const Value: string);
begin
  FThemeLink.ThemeName := Value;
end;

function TFmrStatusBar.IsThemeNameStored: Boolean;
begin
  Result := FThemeLink.ThemeName <> FmrDefaultThemeName;
end;

function TFmrStatusBar.GetAccentColor: TAlphaColor;
begin
  Result := FThemeLink.AccentColor;
end;

procedure TFmrStatusBar.SetAccentColor(const Value: TAlphaColor);
begin
  FThemeLink.AccentColor := Value;
end;

function TFmrStatusBar.GetThemeProvider: TFmxObject;
begin
  Result := FThemeLink.Provider;
end;

procedure TFmrStatusBar.SetThemeProvider(const Value: TFmxObject);
begin
  if FThemeLink.Provider <> Value then
  begin
    if FThemeLink.Provider <> nil then
      FThemeLink.Provider.RemoveFreeNotification(Self);
    FThemeLink.Provider := Value;
    if Value <> nil then
      Value.FreeNotification(Self);
  end;
end;

procedure TFmrStatusBar.SetBarManager(const Value: TFmrBarManager);
begin
  if FBarManager <> Value then
  begin
    if FBarManager <> nil then
    begin
      FBarManager.RemoveListener(Self);
      FBarManager.RemoveFreeNotification(Self);
    end;
    FBarManager := Value;
    if FBarManager <> nil then
    begin
      FBarManager.AddListener(Self);
      FBarManager.FreeNotification(Self);
    end;
    UpdatePanels;
  end;
end;

procedure TFmrStatusBar.SetAutoHeight(const Value: Boolean);
begin
  if FAutoHeight <> Value then
  begin
    FAutoHeight := Value;
    UpdateHeight;
  end;
end;

procedure TFmrStatusBar.SetPanelSpacing(const Value: Single);
begin
  if not SameValue(FPanelSpacing, Value) then
  begin
    FPanelSpacing := Max(0, Value);
    UpdatePanels;
  end;
end;

function TFmrStatusBar.IsPanelSpacingStored: Boolean;
begin
  Result := FPanelSpacing <> 0;
end;

procedure TFmrStatusBar.SetShowSizeGrip(const Value: Boolean);
begin
  if FShowSizeGrip <> Value then
  begin
    FShowSizeGrip := Value;
    UpdateSizeGrip;
    UpdatePanels;
    Repaint;
  end;
end;

procedure TFmrStatusBar.UpdateSizeGrip;
begin
  if FShowSizeGrip and not (csDesigning in ComponentState) then
  begin
    if FSizeGrip = nil then
    begin
      FSizeGrip := TFmrStatusSizeGrip.Create(nil);
      FSizeGrip.Parent := Self;
    end;
    FSizeGrip.SetBounds(Width - SizeGripWidth, 0, SizeGripWidth, Height);
  end
  else
    FreeAndNil(FSizeGrip);
end;

function TFmrStatusBar.GetPanelCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrStatusBarPanel then
      Inc(Result);
end;

function TFmrStatusBar.GetPanel(const AIndex: Integer): TFmrStatusBarPanel;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrStatusBarPanel then
    begin
      if N = AIndex then
        Exit(TFmrStatusBarPanel(Children[I]));
      Inc(N);
    end;
  raise EArgumentOutOfRangeException.CreateFmt('Panel index %d out of range', [AIndex]);
end;

function TFmrStatusBar.AddPanel(const AKind: TFmrStatusPanelKind; const AText: string;
  const ASide: TFmrStatusPanelSide): TFmrStatusBarPanel;
begin
  Result := TFmrStatusBarPanel.Create(Owner);
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Side := ASide;
  Result.Parent := Self;
end;

procedure TFmrStatusBar.ThemeChanged(Sender: TObject);
var
  I: Integer;
begin
  if csDestroying in ComponentState then
    Exit;
  UpdateHeight;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrStatusBarPanel then
      TFmrStatusBarPanel(Children[I]).FGeometryValid := False;
  UpdatePanels;
  Repaint;
  TMessageManager.DefaultManager.SendMessage(Self, TFmrThemeChangedMessage.Create(Self));
end;

procedure TFmrStatusBar.UpdateHeight;
begin
  if FAutoHeight and not (csLoading in ComponentState) then
    Height := Max(16, CurrentTheme.Metrics.StatusBarHeight);
end;

procedure TFmrStatusBar.UpdatePanels;
begin
  if [csLoading, csDestroying] * ComponentState <> [] then
    Exit;
  Realign;
end;

procedure TFmrStatusBar.DoRealign;
var
  Panels: TList<TFmrStatusBarPanel>;
  Measures: TArray<TFmrStatusPanelMeasure>;
  Slots: TArray<TFmrStatusPanelSlot>;
  I: Integer;
  P: TFmrStatusBarPanel;
  EndX: Single;
begin
  inherited;
  if FRealigning or ([csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  FRealigning := True;
  Panels := TList<TFmrStatusBarPanel>.Create;
  try
    for I := 0 to ChildrenCount - 1 do
      if Children[I] is TFmrStatusBarPanel then
        Panels.Add(TFmrStatusBarPanel(Children[I]));
    SetLength(Measures, Panels.Count);
    for I := 0 to Panels.Count - 1 do
    begin
      P := Panels[I];
      Measures[I] := TFmrStatusPanelMeasure.Create(P.Side, P.MeasureWidth, P.MinWidth, P.Stretch, P.Visible);
    end;
    EndX := Width - Padding.Right - 2;
    if FShowSizeGrip then
      EndX := EndX - SizeGripWidth;
    Slots := FmrLayoutStatusPanels(Measures, Padding.Left + 2, EndX, FPanelSpacing);
    for I := 0 to Panels.Count - 1 do
    begin
      P := Panels[I];
      if Slots[I].Shown then
        P.SetBounds(Slots[I].Left, Padding.Top, Slots[I].Width, Height - Padding.Top - Padding.Bottom)
      else
        P.SetBounds(Slots[I].Left, Padding.Top, 0, Height - Padding.Top - Padding.Bottom);
      P.FGeometryValid := False;
    end;
    if FSizeGrip <> nil then
      FSizeGrip.SetBounds(Width - SizeGripWidth, 0, SizeGripWidth, Height);
  finally
    Panels.Free;
    FRealigning := False;
  end;
end;

procedure TFmrStatusBar.Paint;
begin
  Painter.DrawStatusBar(Canvas, LocalRect);
end;

procedure TFmrStatusBar.Loaded;
begin
  inherited;
  UpdateHeight;
  UpdateSizeGrip;
  UpdatePanels;
end;

procedure TFmrStatusBar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if (FThemeLink <> nil) and (AComponent = FThemeLink.Provider) then
      FThemeLink.Provider := nil;
    if AComponent = FBarManager then
    begin
      FBarManager := nil;
      UpdatePanels;
    end;
  end;
end;

procedure TFmrStatusBar.DoAddObject(const AObject: TFmxObject);
begin
  inherited;
  if AObject is TFmrStatusBarPanel then
    UpdatePanels;
end;

procedure TFmrStatusBar.DoRemoveObject(const AObject: TFmxObject);
begin
  inherited;
  if AObject is TFmrStatusBarPanel then
    UpdatePanels;
end;

procedure TFmrStatusBar.BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
  const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
begin
  case AChange of
    TFmrManagerChange.Destroying:
      begin
        FBarManager := nil;
        UpdatePanels;
      end;
    TFmrManagerChange.ImagesChanged, TFmrManagerChange.Updated:
      begin
        UpdatePanels;
        Repaint;
      end;
  end;
end;

initialization
  RegisterFmxClasses([TFmrStatusBar, TFmrStatusBarPanel]);

end.
