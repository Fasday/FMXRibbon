{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Themed content controls of the backstage view        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Backstage.Controls;

/// Controls for typical backstage content that paint with the theme of the backstage view they are placed in (the
/// view is their theme provider; outside a view they use the default theme):
///   - TFmrBackstageLabel: themed text (header, title, subtitle, normal, secondary), word wrap, auto height;
///   - TFmrBackstageHeader: the big page header ("Info", "Open"), aligned to the top;
///   - TFmrBackstageTile: a big clickable button with a glyph, a caption and a description (Info page commands,
///     Save As locations, the Print button);
///   - TFmrBackstageGalleryList: a list of entries with glyph, title and path (recent files), with group headers,
///     hot tracking, selection, keyboard and wheel scrolling.
/// Any other FMX control can be used in a backstage tab as well; these only save the theming work.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, FMX.Types, FMX.Graphics,
  FMX.Controls, FMX.Forms, FMX.ImgList, FMX.TextLayout, FMR.Bars.Images, FMR.Ribbon.Theme, FMR.Ribbon.Painter,
  FMR.Ribbon.ThemeLink, FMR.Ribbon.Extras.Layout, FMR.Ribbon.Backstage;

type
  /// <summary>Base of the themed backstage controls: theme from the nearest provider among the parents (the
  /// backstage view), images from the view's bar manager.</summary>
  TFmrBackstageCustomControl = class(TControl)
  private
    FThemeLink: TFmrThemeLink;
    procedure ThemeLinkChanged(Sender: TObject);
  protected
    /// <summary>Called after the theme in use changed; repaints by default.</summary>
    procedure ThemeChanged; virtual;
    function Theme: TFmrTheme;
    function Painter: TFmrRibbonPainter;
    /// <summary>Images of the bar manager of the backstage view the control is placed in (nil if none).</summary>
    function Images: TCustomImageList;
    /// <summary>The backstage view the control is placed in (nil if none).</summary>
    function OwnerView: TFmrRibbonBackstageView;
    function PaintOpacity: Single;
    /// <summary>The accent color, lightened when it would be too dark on the backstage background.</summary>
    function AccentForeground: TAlphaColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property ThemeLink: TFmrThemeLink read FThemeLink;
  end;

  /// <summary>Text roles of TFmrBackstageLabel.</summary>
  TFmrBackstageTextStyle = (
    /// <summary>Page header (large, light).</summary>
    Header,
    /// <summary>Section title.</summary>
    Title,
    /// <summary>Sub-section title.</summary>
    Subtitle,
    /// <summary>Body text.</summary>
    Normal,
    /// <summary>Secondary text (descriptions, paths) in the BackstageText color.</summary>
    Secondary);

  /// <summary>Themed text.</summary>
  TFmrBackstageLabel = class(TFmrBackstageCustomControl)
  private
    FText: string;
    FTextStyle: TFmrBackstageTextStyle;
    FWordWrap: Boolean;
    FHorzAlign: TTextAlign;
    FVertAlign: TTextAlign;
    FAutoSize: Boolean;
    FBold: Boolean;
    FLayout: TTextLayout;
    FSizing: Boolean;
    procedure SetText(const Value: string);
    procedure SetTextStyle(const Value: TFmrBackstageTextStyle);
    procedure SetWordWrap(const Value: Boolean);
    procedure SetHorzAlign(const Value: TTextAlign);
    procedure SetVertAlign(const Value: TTextAlign);
    procedure SetAutoSize(const Value: Boolean);
    procedure SetBold(const Value: Boolean);
    procedure PrepareLayout(const AMaxWidth, AMaxHeight: Single);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure Loaded; override;
    procedure ThemeChanged; override;
    procedure PaddingChanged; override;
    procedure AdjustHeight;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Font size of a text style for the theme in use.</summary>
    function StyleFontSize(const AStyle: TFmrBackstageTextStyle): Single;
  published
    property Text: string read FText write SetText;
    property TextStyle: TFmrBackstageTextStyle read FTextStyle write SetTextStyle
      default TFmrBackstageTextStyle.Normal;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default True;
    property HorzAlign: TTextAlign read FHorzAlign write SetHorzAlign default TTextAlign.Leading;
    property VertAlign: TTextAlign read FVertAlign write SetVertAlign default TTextAlign.Leading;
    /// <summary>The height follows the wrapped text at the current width.</summary>
    property AutoSize: Boolean read FAutoSize write SetAutoSize default True;
    property Bold: Boolean read FBold write SetBold default False;
    property Align;
    property Anchors;
    property Enabled;
    property Height;
    property HitTest default False;
    property Margins;
    property Opacity;
    property Padding;
    property Position;
    property Size;
    property Visible;
    property Width;
    property OnClick;
    property OnResize;
  end;

  /// <summary>The big page header of a backstage tab (TextStyle Header, aligned to the top).</summary>
  TFmrBackstageHeader = class(TFmrBackstageLabel)
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align default TAlignLayout.Top;
    property TextStyle default TFmrBackstageTextStyle.Header;
  end;

  /// <summary>Arrangement of a tile: glyph above the caption, or glyph left of caption and description.</summary>
  TFmrBackstageTileLayout = (Vertical, Horizontal);

  /// <summary>A big themed button with a glyph, a caption and an optional description.</summary>
  TFmrBackstageTile = class(TFmrBackstageCustomControl)
  private
    FCaption: string;
    FDescription: string;
    FGlyph: TFmrImageSource;
    FGlyphSize: Single;
    FLayout: TFmrBackstageTileLayout;
    FShowFrame: Boolean;
    FSelected: Boolean;
    FPressed: Boolean;
    procedure SetCaption(const Value: string);
    procedure SetDescription(const Value: string);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetGlyphSize(const Value: Single);
    procedure SetLayout(const Value: TFmrBackstageTileLayout);
    procedure SetShowFrame(const Value: Boolean);
    procedure SetSelected(const Value: Boolean);
    function IsGlyphSizeStored: Boolean;
    procedure GlyphChanged(Sender: TObject);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Caption: string read FCaption write SetCaption;
    property Description: string read FDescription write SetDescription;
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    property GlyphSize: Single read FGlyphSize write SetGlyphSize stored IsGlyphSizeStored;
    property Layout: TFmrBackstageTileLayout read FLayout write SetLayout default TFmrBackstageTileLayout.Vertical;
    property ShowFrame: Boolean read FShowFrame write SetShowFrame default True;
    /// <summary>Painted as selected (e.g. the chosen location of Save As).</summary>
    property Selected: Boolean read FSelected write SetSelected default False;
    property Align;
    property Anchors;
    property CanFocus default True;
    property Enabled;
    property Height;
    property Hint;
    property Margins;
    property Opacity;
    property Position;
    property ShowHint;
    property Size;
    property TabOrder;
    property TabStop;
    property Visible;
    property Width;
    property OnClick;
    property OnResize;
  end;

  TFmrBackstageGalleryList = class;

  /// <summary>An entry of TFmrBackstageGalleryList.</summary>
  TFmrBackstageGalleryItem = class(TCollectionItem)
  private
    FCaption: string;
    FDescription: string;
    FGlyph: TFmrImageSource;
    FHint: string;
    FHeader: Boolean;
    FTag: NativeInt;
    FData: TObject;
    procedure SetCaption(const Value: string);
    procedure SetDescription(const Value: string);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetHeader(const Value: Boolean);
    procedure GlyphChanged(Sender: TObject);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    /// <summary>Free for the application; not streamed, not owned.</summary>
    property Data: TObject read FData write FData;
  published
    /// <summary>Title (file name).</summary>
    property Caption: string read FCaption write SetCaption;
    /// <summary>Second line (path).</summary>
    property Description: string read FDescription write SetDescription;
    /// <summary>Glyph; empty = a document glyph in the accent color.</summary>
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    /// <summary>A group header ("Today", "Older"): small bold caption, not selectable.</summary>
    property Header: Boolean read FHeader write SetHeader default False;
    property Hint: string read FHint write FHint;
    property Tag: NativeInt read FTag write FTag default 0;
  end;

  TFmrBackstageGalleryItems = class(TOwnedCollection)
  private
    function GetItem(const AIndex: Integer): TFmrBackstageGalleryItem;
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(const AOwner: TFmrBackstageGalleryList);
    function Add: TFmrBackstageGalleryItem;
    /// <summary>Appends an entry.</summary>
    function AddItem(const ACaption, ADescription: string; const AGlyphCode: Cardinal = 0): TFmrBackstageGalleryItem;
    /// <summary>Appends a group header.</summary>
    function AddHeader(const ACaption: string): TFmrBackstageGalleryItem;
    property Items[const AIndex: Integer]: TFmrBackstageGalleryItem read GetItem; default;
  end;

  TFmrBackstageGalleryItemEvent = procedure(Sender: TObject; const AItem: TFmrBackstageGalleryItem) of object;

  /// <summary>A themed list of entries (recent files).</summary>
  TFmrBackstageGalleryList = class(TFmrBackstageCustomControl)
  private
    FItems: TFmrBackstageGalleryItems;
    FItemHeight: Single;
    FHeaderHeight: Single;
    FItemIndex: Integer;
    FHotIndex: Integer;
    FPressedIndex: Integer;
    FScroll: Single;
    FOnItemClick: TFmrBackstageGalleryItemEvent;
    FOnChange: TNotifyEvent;
    procedure SetItems(const Value: TFmrBackstageGalleryItems);
    procedure SetItemHeight(const Value: Single);
    procedure SetItemIndex(const Value: Integer);
    function IsItemHeightStored: Boolean;
    function RowTop(const AIndex: Integer): Single;
    function RowHeight(const AIndex: Integer): Single;
    function ContentHeight: Single;
    function IndexAt(const P: TPointF): Integer;
    function Selectable: TArray<Boolean>;
    procedure ScrollIntoView(const AIndex: Integer);
    procedure DrawDefaultGlyph(const R: TRectF; const AOpacity: Single);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DoMouseLeave; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    function GetHintString: string; override;
    function HasHint: Boolean; override;
    procedure DoItemClick(const AItem: TFmrBackstageGalleryItem); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ItemsChanged;
    property HotIndex: Integer read FHotIndex;
  published
    property Items: TFmrBackstageGalleryItems read FItems write SetItems;
    property ItemHeight: Single read FItemHeight write SetItemHeight stored IsItemHeightStored;
    /// <summary>Selected entry (-1 = none).</summary>
    property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;
    property Align;
    property Anchors;
    property CanFocus default True;
    property Enabled;
    property Height;
    property Margins;
    property Opacity;
    property Position;
    property ShowHint;
    property Size;
    property TabOrder;
    property TabStop;
    property Visible;
    property Width;
    /// <summary>An entry was clicked (or chosen with Enter).</summary>
    property OnItemClick: TFmrBackstageGalleryItemEvent read FOnItemClick write FOnItemClick;
    /// <summary>ItemIndex changed.</summary>
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnResize;
  end;

implementation

{ TFmrBackstageCustomControl }

constructor TFmrBackstageCustomControl.Create(AOwner: TComponent);
begin
  inherited;
  FThemeLink := TFmrThemeLink.Create(Self, ThemeLinkChanged);
end;

destructor TFmrBackstageCustomControl.Destroy;
begin
  FThemeLink.Free;
  FThemeLink := nil;
  inherited;
end;

procedure TFmrBackstageCustomControl.ThemeLinkChanged(Sender: TObject);
begin
  if not (csDestroying in ComponentState) then
    ThemeChanged;
end;

procedure TFmrBackstageCustomControl.ThemeChanged;
begin
  Repaint;
end;

function TFmrBackstageCustomControl.Theme: TFmrTheme;
begin
  Result := FThemeLink.Theme;
end;

function TFmrBackstageCustomControl.Painter: TFmrRibbonPainter;
begin
  Result := FThemeLink.Painter;
end;

function TFmrBackstageCustomControl.OwnerView: TFmrRibbonBackstageView;
var
  P: TFmxObject;
begin
  P := Parent;
  while P <> nil do
  begin
    if P is TFmrRibbonBackstageView then
      Exit(TFmrRibbonBackstageView(P));
    P := P.Parent;
  end;
  Result := nil;
end;

function TFmrBackstageCustomControl.Images: TCustomImageList;
var
  V: TFmrRibbonBackstageView;
begin
  V := OwnerView;
  if (V <> nil) and (V.BarManager <> nil) then
    Result := V.BarManager.Images
  else
    Result := nil;
end;

function TFmrBackstageCustomControl.PaintOpacity: Single;
begin
  Result := AbsoluteOpacity;
  if not AbsoluteEnabled then
    Result := Result * 0.45;
end;

function TFmrBackstageCustomControl.AccentForeground: TAlphaColor;
var
  T: TFmrTheme;
begin
  T := Theme;
  Result := T.Colors[TFmrToken.Accent];
  if (FmrLuminance(T.Colors[TFmrToken.BackstageFill]) < 0.3) and (FmrLuminance(Result) < 0.25) then
    Result := FmrLighten(Result, 0.45);
end;

{ TFmrBackstageLabel }

constructor TFmrBackstageLabel.Create(AOwner: TComponent);
begin
  inherited;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;
  FTextStyle := TFmrBackstageTextStyle.Normal;
  FWordWrap := True;
  FHorzAlign := TTextAlign.Leading;
  FVertAlign := TTextAlign.Leading;
  FAutoSize := True;
  HitTest := False;
  SetBounds(0, 0, 200, 20);
end;

destructor TFmrBackstageLabel.Destroy;
begin
  FLayout.Free;
  inherited;
end;

function TFmrBackstageLabel.StyleFontSize(const AStyle: TFmrBackstageTextStyle): Single;
var
  Base: Single;
begin
  Base := Theme.Metrics.FontSize;
  case AStyle of
    TFmrBackstageTextStyle.Header:
      Result := Base * 2.4;
    TFmrBackstageTextStyle.Title:
      Result := Base * 1.5;
    TFmrBackstageTextStyle.Subtitle:
      Result := Base + 3;
    TFmrBackstageTextStyle.Normal:
      Result := Base + 1;
  else
    Result := Base;
  end;
end;

procedure TFmrBackstageLabel.PrepareLayout(const AMaxWidth, AMaxHeight: Single);
var
  T: TFmrTheme;
  Family: string;
  Color: TAlphaColor;
begin
  T := Theme;
  Family := T.Metrics.FontFamily;
  if (FTextStyle in [TFmrBackstageTextStyle.Header, TFmrBackstageTextStyle.Title]) and SameText(Family, 'Segoe UI') then
    Family := 'Segoe UI Light';
  if FTextStyle = TFmrBackstageTextStyle.Secondary then
    Color := T.Colors[TFmrToken.BackstageText]
  else
    Color := T.Colors[TFmrToken.BackstageHeaderText];
  FLayout.BeginUpdate;
  try
    FLayout.Font.Family := Family;
    FLayout.Font.Size := StyleFontSize(FTextStyle);
    if FBold or (FTextStyle = TFmrBackstageTextStyle.Subtitle) then
      FLayout.Font.Style := [TFontStyle.fsBold]
    else
      FLayout.Font.Style := [];
    FLayout.Text := FText;
    FLayout.WordWrap := FWordWrap;
    FLayout.Trimming := TTextTrimming.Character;
    FLayout.HorizontalAlign := FHorzAlign;
    FLayout.VerticalAlign := FVertAlign;
    FLayout.Color := Color;
    FLayout.MaxSize := TPointF.Create(Max(1, AMaxWidth), Max(1, AMaxHeight));
  finally
    FLayout.EndUpdate;
  end;
end;

procedure TFmrBackstageLabel.AdjustHeight;
var
  H: Single;
begin
  if not FAutoSize or FSizing or ([csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  if Align in [TAlignLayout.Left, TAlignLayout.Right, TAlignLayout.Client, TAlignLayout.Contents,
    TAlignLayout.MostLeft, TAlignLayout.MostRight, TAlignLayout.Vertical] then
    Exit;
  FSizing := True;
  try
    PrepareLayout(Width - Padding.Left - Padding.Right, 100000);
    if FText = '' then
      H := StyleFontSize(FTextStyle) * 1.4
    else
      H := FLayout.TextHeight;
    H := Ceil(H + Padding.Top + Padding.Bottom);
    if not SameValue(H, Height, 0.5) then
      Height := H;
  finally
    FSizing := False;
  end;
end;

procedure TFmrBackstageLabel.Paint;
var
  R: TRectF;
begin
  R := LocalRect;
  R := RectF(R.Left + Padding.Left, R.Top + Padding.Top, R.Right - Padding.Right, R.Bottom - Padding.Bottom);
  if (csDesigning in ComponentState) and (FText = '') then
    DrawDesignBorder;
  if (FText = '') or (R.Width <= 0) or (R.Height <= 0) then
    Exit;
  PrepareLayout(R.Width, R.Height);
  FLayout.TopLeft := R.TopLeft;
  FLayout.Opacity := PaintOpacity;
  FLayout.RenderLayout(Canvas);
end;

procedure TFmrBackstageLabel.Resize;
begin
  inherited;
  AdjustHeight;
end;

procedure TFmrBackstageLabel.Loaded;
begin
  inherited;
  AdjustHeight;
end;

procedure TFmrBackstageLabel.ThemeChanged;
begin
  AdjustHeight;
  inherited;
end;

procedure TFmrBackstageLabel.PaddingChanged;
begin
  inherited;
  AdjustHeight;
end;

procedure TFmrBackstageLabel.SetText(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    AdjustHeight;
    Repaint;
  end;
end;

procedure TFmrBackstageLabel.SetTextStyle(const Value: TFmrBackstageTextStyle);
begin
  if FTextStyle <> Value then
  begin
    FTextStyle := Value;
    AdjustHeight;
    Repaint;
  end;
end;

procedure TFmrBackstageLabel.SetWordWrap(const Value: Boolean);
begin
  if FWordWrap <> Value then
  begin
    FWordWrap := Value;
    AdjustHeight;
    Repaint;
  end;
end;

procedure TFmrBackstageLabel.SetHorzAlign(const Value: TTextAlign);
begin
  if FHorzAlign <> Value then
  begin
    FHorzAlign := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageLabel.SetVertAlign(const Value: TTextAlign);
begin
  if FVertAlign <> Value then
  begin
    FVertAlign := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageLabel.SetAutoSize(const Value: Boolean);
begin
  if FAutoSize <> Value then
  begin
    FAutoSize := Value;
    AdjustHeight;
  end;
end;

procedure TFmrBackstageLabel.SetBold(const Value: Boolean);
begin
  if FBold <> Value then
  begin
    FBold := Value;
    AdjustHeight;
    Repaint;
  end;
end;

{ TFmrBackstageHeader }

constructor TFmrBackstageHeader.Create(AOwner: TComponent);
begin
  inherited;
  TextStyle := TFmrBackstageTextStyle.Header;
  Align := TAlignLayout.Top;
  Margins.Bottom := 8;
end;

{ TFmrBackstageTile }

constructor TFmrBackstageTile.Create(AOwner: TComponent);
begin
  inherited;
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
  FGlyphSize := 32;
  FShowFrame := True;
  CanFocus := True;
  HitTest := True;
  SetBounds(0, 0, 96, 96);
end;

destructor TFmrBackstageTile.Destroy;
begin
  FGlyph.Free;
  inherited;
end;

procedure TFmrBackstageTile.GlyphChanged(Sender: TObject);
begin
  Repaint;
end;

procedure TFmrBackstageTile.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.SetDescription(const Value: string);
begin
  if FDescription <> Value then
  begin
    FDescription := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrBackstageTile.SetGlyphSize(const Value: Single);
begin
  if not SameValue(FGlyphSize, Value) then
  begin
    FGlyphSize := Max(8, Value);
    Repaint;
  end;
end;

function TFmrBackstageTile.IsGlyphSizeStored: Boolean;
begin
  Result := not SameValue(FGlyphSize, 32);
end;

procedure TFmrBackstageTile.SetLayout(const Value: TFmrBackstageTileLayout);
begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.SetShowFrame(const Value: Boolean);
begin
  if FShowFrame <> Value then
  begin
    FShowFrame := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.SetSelected(const Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and AbsoluteEnabled then
  begin
    FPressed := True;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if FPressed then
  begin
    FPressed := False;
    Repaint;
  end;
end;

procedure TFmrBackstageTile.DoMouseEnter;
begin
  inherited;
  Repaint;
end;

procedure TFmrBackstageTile.DoMouseLeave;
begin
  inherited;
  FPressed := False;
  Repaint;
end;

procedure TFmrBackstageTile.DoEnter;
begin
  inherited;
  Repaint;
end;

procedure TFmrBackstageTile.DoExit;
begin
  inherited;
  Repaint;
end;

procedure TFmrBackstageTile.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  inherited;
  if ((Key = vkReturn) or (KeyChar = ' ')) and AbsoluteEnabled then
  begin
    Click;
    Key := 0;
    KeyChar := #0;
  end;
end;

procedure TFmrBackstageTile.Paint;
var
  P: TFmrRibbonPainter;
  T: TFmrTheme;
  R, G, TR: TRectF;
  DS: TSizeF;
  Rad, Op, FS, TextH: Single;
  TextCol, SecCol: TAlphaColor;
  Hot: Boolean;
begin
  P := Painter;
  T := Theme;
  R := LocalRect;
  Op := PaintOpacity;
  Rad := Max(2, T.Metrics.ButtonRadius);
  Hot := IsMouseOver and AbsoluteEnabled;
  if FSelected then
  begin
    P.Fill(Canvas, R, TFmrToken.GalleryItemSelectedFill, Rad, [], Op);
    if Hot then
      P.Fill(Canvas, R, TFmrToken.ButtonHotFill, Rad, [], Op * 0.5);
    P.Frame(Canvas, R, TFmrToken.GalleryItemSelectedBorder, Rad, [], 1, Op);
  end
  else
  begin
    if FPressed and Hot then
      P.Fill(Canvas, R, TFmrToken.ButtonPressedFill, Rad, [], Op)
    else if Hot then
      P.Fill(Canvas, R, TFmrToken.ButtonHotFill, Rad, [], Op);
    if FShowFrame then
      P.Frame(Canvas, R, TFmrToken.GalleryBorder, Rad, [], 1, Op);
  end;
  if IsFocused then
    P.Frame(Canvas, RectF(R.Left + 2, R.Top + 2, R.Right - 2, R.Bottom - 2), TFmrToken.FocusBorder, Rad, [], 1,
      Op * 0.6);
  TextCol := T.Colors[TFmrToken.BackstageHeaderText];
  SecCol := T.Colors[TFmrToken.BackstageText];
  FS := T.Metrics.FontSize;
  if FLayout = TFmrBackstageTileLayout.Vertical then
  begin
    if FGlyph.IsEmpty(Images) then
      G := RectF(R.CenterPoint.X, R.Top + 10, R.CenterPoint.X, R.Top + 10)
    else
      G := RectF(R.CenterPoint.X - FGlyphSize / 2, R.Top + 12, R.CenterPoint.X + FGlyphSize / 2,
        R.Top + 12 + FGlyphSize);
    if not FGlyph.IsEmpty(Images) then
      FGlyph.Draw(Canvas, G, Op, TextCol, Images);
    TR := RectF(R.Left + 6, G.Bottom + 6, R.Right - 6, R.Bottom - 4);
    P.TextEx(Canvas, TR, FCaption, TextCol, TTextAlign.Center, TTextAlign.Leading, FS, False, True,
      TTextTrimming.Character, Op);
  end
  else
  begin
    if FGlyph.IsEmpty(Images) then
      G := RectF(R.Left + 6, R.CenterPoint.Y, R.Left + 6, R.CenterPoint.Y)
    else
      G := RectF(R.Left + 14, R.CenterPoint.Y - FGlyphSize / 2, R.Left + 14 + FGlyphSize,
        R.CenterPoint.Y + FGlyphSize / 2);
    if not FGlyph.IsEmpty(Images) then
      FGlyph.Draw(Canvas, G, Op, TextCol, Images);
    TR := RectF(G.Right + 14, R.Top + 6, R.Right - 10, R.Bottom - 6);
    if FDescription = '' then
      P.TextEx(Canvas, TR, FCaption, TextCol, TTextAlign.Leading, TTextAlign.Center, FS + 2, False, True,
        TTextTrimming.Character, Op)
    else
    begin
      TextH := P.TextSize(FCaption, FS + 2, False, TR.Width, True).Height;
      DS := P.TextSize(FDescription, FS, False, TR.Width, True);
      // caption and description centered as a block
      TR.Top := Max(R.Top + 6, R.CenterPoint.Y - (TextH + 4 + DS.Height) / 2);
      P.TextEx(Canvas, RectF(TR.Left, TR.Top, TR.Right, TR.Top + TextH), FCaption, TextCol, TTextAlign.Leading,
        TTextAlign.Leading, FS + 2, False, True, TTextTrimming.Character, Op);
      P.TextEx(Canvas, RectF(TR.Left, TR.Top + TextH + 4, TR.Right, R.Bottom - 4), FDescription, SecCol,
        TTextAlign.Leading, TTextAlign.Leading, FS, False, True, TTextTrimming.Character, Op);
    end;
  end;
end;

{ TFmrBackstageGalleryItem }

constructor TFmrBackstageGalleryItem.Create(Collection: TCollection);
begin
  inherited;
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
end;

destructor TFmrBackstageGalleryItem.Destroy;
begin
  FGlyph.Free;
  inherited;
end;

procedure TFmrBackstageGalleryItem.Assign(Source: TPersistent);
var
  S: TFmrBackstageGalleryItem;
begin
  if Source is TFmrBackstageGalleryItem then
  begin
    S := TFmrBackstageGalleryItem(Source);
    FCaption := S.FCaption;
    FDescription := S.FDescription;
    FHint := S.FHint;
    FHeader := S.FHeader;
    FTag := S.FTag;
    FGlyph.Assign(S.FGlyph);
    Changed(False);
  end
  else
    inherited;
end;

function TFmrBackstageGalleryItem.GetDisplayName: string;
begin
  if FCaption <> '' then
    Result := FCaption
  else
    Result := inherited GetDisplayName;
end;

procedure TFmrBackstageGalleryItem.GlyphChanged(Sender: TObject);
begin
  Changed(False);
end;

procedure TFmrBackstageGalleryItem.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed(False);
  end;
end;

procedure TFmrBackstageGalleryItem.SetDescription(const Value: string);
begin
  if FDescription <> Value then
  begin
    FDescription := Value;
    Changed(False);
  end;
end;

procedure TFmrBackstageGalleryItem.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrBackstageGalleryItem.SetHeader(const Value: Boolean);
begin
  if FHeader <> Value then
  begin
    FHeader := Value;
    Changed(True);
  end;
end;

{ TFmrBackstageGalleryItems }

constructor TFmrBackstageGalleryItems.Create(const AOwner: TFmrBackstageGalleryList);
begin
  inherited Create(AOwner, TFmrBackstageGalleryItem);
end;

function TFmrBackstageGalleryItems.GetItem(const AIndex: Integer): TFmrBackstageGalleryItem;
begin
  Result := TFmrBackstageGalleryItem(inherited Items[AIndex]);
end;

function TFmrBackstageGalleryItems.Add: TFmrBackstageGalleryItem;
begin
  Result := TFmrBackstageGalleryItem(inherited Add);
end;

function TFmrBackstageGalleryItems.AddItem(const ACaption, ADescription: string;
  const AGlyphCode: Cardinal): TFmrBackstageGalleryItem;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.Caption := ACaption;
    Result.Description := ADescription;
    Result.Glyph.GlyphCode := AGlyphCode;
  finally
    EndUpdate;
  end;
end;

function TFmrBackstageGalleryItems.AddHeader(const ACaption: string): TFmrBackstageGalleryItem;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.Caption := ACaption;
    Result.Header := True;
  finally
    EndUpdate;
  end;
end;

procedure TFmrBackstageGalleryItems.Update(Item: TCollectionItem);
begin
  inherited;
  if Owner is TFmrBackstageGalleryList then
    TFmrBackstageGalleryList(Owner).ItemsChanged;
end;

{ TFmrBackstageGalleryList }

constructor TFmrBackstageGalleryList.Create(AOwner: TComponent);
begin
  inherited;
  FItems := TFmrBackstageGalleryItems.Create(Self);
  FItemHeight := 52;
  FHeaderHeight := 30;
  FItemIndex := -1;
  FHotIndex := -1;
  FPressedIndex := -1;
  CanFocus := True;
  HitTest := True;
  ClipChildren := True;
  SetBounds(0, 0, 320, 240);
end;

destructor TFmrBackstageGalleryList.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TFmrBackstageGalleryList.ItemsChanged;
begin
  if [csLoading, csDestroying] * ComponentState <> [] then
    Exit;
  if FItemIndex >= FItems.Count then
    FItemIndex := -1;
  if FHotIndex >= FItems.Count then
    FHotIndex := -1;
  FScroll := FmrClampScroll(FScroll, ContentHeight, Height);
  Repaint;
end;

procedure TFmrBackstageGalleryList.SetItems(const Value: TFmrBackstageGalleryItems);
begin
  FItems.Assign(Value);
end;

procedure TFmrBackstageGalleryList.SetItemHeight(const Value: Single);
begin
  if not SameValue(FItemHeight, Value) then
  begin
    FItemHeight := Max(20, Value);
    ItemsChanged;
  end;
end;

function TFmrBackstageGalleryList.IsItemHeightStored: Boolean;
begin
  Result := not SameValue(FItemHeight, 52);
end;

procedure TFmrBackstageGalleryList.SetItemIndex(const Value: Integer);
var
  V: Integer;
begin
  V := Value;
  if (V < -1) or (V >= FItems.Count) or ((V >= 0) and FItems[V].Header) then
    V := -1;
  if FItemIndex <> V then
  begin
    FItemIndex := V;
    if V >= 0 then
      ScrollIntoView(V);
    Repaint;
    if Assigned(FOnChange) and not (csLoading in ComponentState) then
      FOnChange(Self);
  end;
end;

function TFmrBackstageGalleryList.RowHeight(const AIndex: Integer): Single;
begin
  if FItems[AIndex].Header then
    Result := FHeaderHeight
  else
    Result := FItemHeight;
end;

function TFmrBackstageGalleryList.RowTop(const AIndex: Integer): Single;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to AIndex - 1 do
    Result := Result + RowHeight(I);
end;

function TFmrBackstageGalleryList.ContentHeight: Single;
begin
  Result := RowTop(FItems.Count);
end;

function TFmrBackstageGalleryList.IndexAt(const P: TPointF): Integer;
var
  I: Integer;
  Y: Single;
begin
  Result := -1;
  if not LocalRect.Contains(P) then
    Exit;
  Y := -FScroll;
  for I := 0 to FItems.Count - 1 do
  begin
    if (P.Y >= Y) and (P.Y < Y + RowHeight(I)) then
    begin
      if not FItems[I].Header then
        Result := I;
      Exit;
    end;
    Y := Y + RowHeight(I);
  end;
end;

function TFmrBackstageGalleryList.Selectable: TArray<Boolean>;
var
  I: Integer;
begin
  SetLength(Result, FItems.Count);
  for I := 0 to FItems.Count - 1 do
    Result[I] := not FItems[I].Header;
end;

procedure TFmrBackstageGalleryList.ScrollIntoView(const AIndex: Integer);
var
  Top: Single;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit;
  Top := RowTop(AIndex);
  FScroll := FmrClampScroll(FmrScrollIntoView(FScroll, Top, Top + RowHeight(AIndex), Height), ContentHeight, Height);
end;

procedure TFmrBackstageGalleryList.Resize;
begin
  inherited;
  FScroll := FmrClampScroll(FScroll, ContentHeight, Height);
end;

procedure TFmrBackstageGalleryList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and AbsoluteEnabled then
  begin
    FPressedIndex := IndexAt(PointF(X, Y));
    if CanFocus and not IsFocused then
      SetFocus;
    Repaint;
  end;
end;

procedure TFmrBackstageGalleryList.MouseMove(Shift: TShiftState; X, Y: Single);
var
  I: Integer;
begin
  inherited;
  I := IndexAt(PointF(X, Y));
  if I <> FHotIndex then
  begin
    FHotIndex := I;
    if (I >= 0) and not (csDesigning in ComponentState) and (Application <> nil) then
      Application.HideHint;
    Repaint;
  end;
end;

procedure TFmrBackstageGalleryList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I, Pressed: Integer;
begin
  inherited;
  Pressed := FPressedIndex;
  FPressedIndex := -1;
  if Button <> TMouseButton.mbLeft then
    Exit;
  I := IndexAt(PointF(X, Y));
  if (I >= 0) and (I = Pressed) then
  begin
    ItemIndex := I;
    DoItemClick(FItems[I]);
  end;
  Repaint;
end;

procedure TFmrBackstageGalleryList.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
var
  NewScroll: Single;
begin
  inherited;
  if Handled then
    Exit;
  NewScroll := FmrClampScroll(FScroll - WheelDelta / 120 * FItemHeight, ContentHeight, Height);
  if not SameValue(NewScroll, FScroll) then
  begin
    FScroll := NewScroll;
    Repaint;
    Handled := True;
  end;
end;

procedure TFmrBackstageGalleryList.DoMouseLeave;
begin
  inherited;
  FHotIndex := -1;
  FPressedIndex := -1;
  Repaint;
end;

procedure TFmrBackstageGalleryList.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  I: Integer;
begin
  inherited;
  case Key of
    vkUp:
      I := FmrNextSelectable(Selectable, FItemIndex, -1, False);
    vkDown:
      I := FmrNextSelectable(Selectable, FItemIndex, 1, False);
    vkHome:
      I := FmrEdgeSelectable(Selectable, False);
    vkEnd:
      I := FmrEdgeSelectable(Selectable, True);
    vkReturn:
      begin
        if FItemIndex >= 0 then
          DoItemClick(FItems[FItemIndex]);
        Key := 0;
        Exit;
      end;
  else
    Exit;
  end;
  if I >= 0 then
    ItemIndex := I;
  Key := 0;
end;

procedure TFmrBackstageGalleryList.DoItemClick(const AItem: TFmrBackstageGalleryItem);
begin
  if Assigned(FOnItemClick) then
    FOnItemClick(Self, AItem);
end;

function TFmrBackstageGalleryList.GetHintString: string;
begin
  if (FHotIndex >= 0) and (FHotIndex < FItems.Count) then
  begin
    Result := FItems[FHotIndex].Hint;
    if Result = '' then
      Result := FItems[FHotIndex].Description;
  end
  else
    Result := inherited GetHintString;
end;

function TFmrBackstageGalleryList.HasHint: Boolean;
begin
  Result := CanShowHint and (GetHintString <> '');
end;

procedure TFmrBackstageGalleryList.DrawDefaultGlyph(const R: TRectF; const AOpacity: Single);
var
  Accent: TAlphaColor;
  Page: TPathData;
  Stroke: TStrokeBrush;
  W, H, F, X, Y: Single;
  I: Integer;
begin
  // a page with a folded corner and text lines, in the accent color
  Accent := AccentForeground;
  W := R.Width * 0.72;
  H := R.Height * 0.9;
  X := R.CenterPoint.X - W / 2;
  Y := R.CenterPoint.Y - H / 2;
  F := W * 0.3;
  Page := TPathData.Create;
  Stroke := TStrokeBrush.Create(TBrushKind.Solid, Accent);
  try
    Page.MoveTo(PointF(X, Y));
    Page.LineTo(PointF(X + W - F, Y));
    Page.LineTo(PointF(X + W, Y + F));
    Page.LineTo(PointF(X + W, Y + H));
    Page.LineTo(PointF(X, Y + H));
    Page.ClosePath;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := Theme.Colors[TFmrToken.BackstageFill];
    Canvas.FillPath(Page, AOpacity);
    Stroke.Thickness := 1.2;
    Stroke.Join := TStrokeJoin.Round;
    Canvas.DrawPath(Page, AOpacity, Stroke);
    Canvas.DrawLine(PointF(X + W - F, Y), PointF(X + W - F, Y + F), AOpacity, Stroke);
    Canvas.DrawLine(PointF(X + W - F, Y + F), PointF(X + W, Y + F), AOpacity, Stroke);
    Stroke.Thickness := 1;
    for I := 0 to 2 do
      Canvas.DrawLine(PointF(X + W * 0.2, Y + H * (0.45 + I * 0.15)), PointF(X + W * 0.8, Y + H * (0.45 + I * 0.15)),
        AOpacity, Stroke);
  finally
    Stroke.Free;
    Page.Free;
  end;
end;

procedure TFmrBackstageGalleryList.Paint;
var
  P: TFmrRibbonPainter;
  T: TFmrTheme;
  I: Integer;
  Y, H, Op, FS, Rad, Content, ThumbH, ThumbY: Single;
  R, G, TR: TRectF;
  Item: TFmrBackstageGalleryItem;
  TextCol, SecCol: TAlphaColor;
begin
  P := Painter;
  T := Theme;
  Op := PaintOpacity;
  FS := T.Metrics.FontSize;
  Rad := Max(2, T.Metrics.ButtonRadius);
  TextCol := T.Colors[TFmrToken.BackstageHeaderText];
  SecCol := T.Colors[TFmrToken.BackstageText];
  if (csDesigning in ComponentState) and (FItems.Count = 0) then
    DrawDesignBorder;
  Y := -FScroll;
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    H := RowHeight(I);
    if (Y + H > 0) and (Y < Height) then
    begin
      R := RectF(0, Y, Width, Y + H);
      if Item.Header then
      begin
        P.TextEx(Canvas, RectF(R.Left + 12, R.Top + 6, R.Right - 8, R.Bottom), Item.Caption, TextCol,
          TTextAlign.Leading, TTextAlign.Center, FS, True, False, TTextTrimming.Character, Op);
      end
      else
      begin
        R.Inflate(0, -1);
        if I = FItemIndex then
          P.Fill(Canvas, R, TFmrToken.GalleryItemSelectedFill, Rad, [], Op);
        if (I = FHotIndex) and AbsoluteEnabled then
        begin
          if (I = FPressedIndex) then
            P.Fill(Canvas, R, TFmrToken.ButtonPressedFill, Rad, [], Op)
          else
            P.Fill(Canvas, R, TFmrToken.ButtonHotFill, Rad, [], Op);
        end;
        if (I = FItemIndex) and IsFocused then
          P.Frame(Canvas, R, TFmrToken.GalleryItemSelectedBorder, Rad, [], 1, Op);
        G := RectF(R.Left + 12, R.CenterPoint.Y - 16, R.Left + 44, R.CenterPoint.Y + 16);
        if Item.Glyph.IsEmpty(Images) then
          DrawDefaultGlyph(G, Op)
        else
          Item.Glyph.Draw(Canvas, G, Op, AccentForeground, Images);
        TR := RectF(G.Right + 14, R.Top, R.Right - 10, R.Bottom);
        if Item.Description = '' then
          P.TextEx(Canvas, TR, Item.Caption, TextCol, TTextAlign.Leading, TTextAlign.Center, FS + 1, False, False,
            TTextTrimming.Character, Op)
        else
        begin
          P.TextEx(Canvas, RectF(TR.Left, R.Top + 6, TR.Right, R.CenterPoint.Y + 1), Item.Caption, TextCol,
            TTextAlign.Leading, TTextAlign.Trailing, FS + 1, False, False, TTextTrimming.Character, Op);
          P.TextEx(Canvas, RectF(TR.Left, R.CenterPoint.Y + 2, TR.Right, R.Bottom - 4), Item.Description, SecCol,
            TTextAlign.Leading, TTextAlign.Leading, FS - 0.5, False, False, TTextTrimming.Character, Op);
        end;
      end;
    end;
    Y := Y + H;
  end;
  // thin scroll indicator
  Content := ContentHeight;
  if Content > Height + 0.5 then
  begin
    ThumbH := Max(24, Height * Height / Content);
    ThumbY := (Height - ThumbH) * FScroll / (Content - Height);
    P.Fill(Canvas, RectF(Width - 4, ThumbY + 2, Width - 1, ThumbY + ThumbH - 2),
      TFmrFill.Solid(FmrWithAlpha(SecCol, 0.45)), 1.5, [], Op);
  end;
end;

initialization
  RegisterFmxClasses([TFmrBackstageLabel, TFmrBackstageHeader, TFmrBackstageTile, TFmrBackstageGalleryList]);

end.
