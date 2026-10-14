{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Galleries: in-ribbon, drop-down and menu galleries   }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Gallery;

/// Galleries of the ribbon, plugged in through the extension points of FMR.Ribbon.Views and FMR.Ribbon.Popup:
///   - TFmrGalleryView (FmrRegisterItemView for TFmrGalleryItem): the in-ribbon gallery. Entries in a grid whose
///     column count is reduced by the layout calculator (MinColumns..MaxColumns), whole rows scrolled with the up/down
///     buttons of the strip at the right, the drop-down button below them, hot tracking with live preview
///     (TFmrGalleryItem.HotTrack while the mouse is over an entry, nil when it leaves), selection, one key tip for the
///     gallery. When the layout reduces the gallery to a large drop-down button it is painted by TFmrButtonView.
///   - TFmrGalleryPopupContent (FmrRegisterDropDown): the drop-down gallery. Sections from top to bottom: an
///     optional filter band (AllowFilter: All / group names), gallery sections (group headers, scrolling with the
///     wheel and a thin scroll bar, keyboard navigation), menu sections (TFmrMenuControl with the commands below the
///     gallery) and a resize grip (both directions or vertical only). Over an in-ribbon gallery the popup opens at its
///     top-left corner, at least as wide as the gallery.
///   - Menus that contain gallery links (TFmrButtonItem.DropDownLinks, TFmrSubItem.ItemLinks) are shown by the same
///     content: every gallery link becomes an inline gallery section, the other links menu sections.
/// TFmrRibbonGalleryItem adds owner drawing (OnDrawItem) and the resize mode of the drop-down to TFmrGalleryItem.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Layout, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup,
  FMR.Ribbon.ScreenTips, FMR.Ribbon.Strings;

type
  /// <summary>How the user may resize a drop-down gallery with the grip at its bottom.</summary>
  TFmrGalleryResizeMode = (None, Vertical, Both);

  /// <summary>State of a gallery entry while it is painted.</summary>
  TFmrGalleryDrawState = (Hot, Selected, Pressed, Disabled, InRibbon);
  TFmrGalleryDrawStates = set of TFmrGalleryDrawState;

  /// <summary>Owner drawing of a gallery entry. The hot/selected background is painted already; set AHandled to
  /// skip the default glyph and caption. ARect: the cell inset by one pixel.</summary>
  TFmrGalleryDrawItemEvent = procedure(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
    const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
    var AHandled: Boolean) of object;

  /// <summary>Gallery item with owner drawing and drop-down options (a plain TFmrGalleryItem works too: it draws
  /// glyphs and captions and its drop-down resizes in both directions).</summary>
  TFmrRibbonGalleryItem = class(TFmrGalleryItem)
  private
    FDropDownResize: TFmrGalleryResizeMode;
    FDropDownMinWidth: Single;
    FOnDrawItem: TFmrGalleryDrawItemEvent;
  public
    constructor Create(AOwner: TComponent); override;
  published
    /// <summary>Resize grip of the drop-down gallery.</summary>
    property DropDownResize: TFmrGalleryResizeMode read FDropDownResize write FDropDownResize
      default TFmrGalleryResizeMode.Both;
    /// <summary>Minimum width of the drop-down in dp (0 = the columns decide).</summary>
    property DropDownMinWidth: Single read FDropDownMinWidth write FDropDownMinWidth;
    property OnDrawItem: TFmrGalleryDrawItemEvent read FOnDrawItem write FOnDrawItem;
  end;

  /// <summary>One cell of a gallery grid (grid coordinates: 0,0 = top-left of the first row).</summary>
  TFmrGalleryCell = record
    Entry: TFmrGalleryEntry;
    Rect: TRectF;
    Row: Integer;
    Col: Integer;
  end;

  /// <summary>Group header of a gallery grid.</summary>
  TFmrGalleryHeader = record
    Caption: string;
    Rect: TRectF;
  end;

  /// <summary>Places the visible entries of a gallery in a grid of fixed-size cells (optionally with group headers,
  /// every group starting on a new row) and finds cells by point or by keyboard direction.</summary>
  TFmrGalleryGrid = class
  private
    FGallery: TFmrGalleryItem;
    FCells: TArray<TFmrGalleryCell>;
    FHeaders: TArray<TFmrGalleryHeader>;
    FItemSize: TSizeF;
    FColumns: Integer;
    FRowCount: Integer;
    FHeight: Single;
    function GetCount: Integer;
    function GetCell(const AIndex: Integer): TFmrGalleryCell;
  public
    constructor Create(const AGallery: TFmrGalleryItem);
    /// <summary>Lays out the entries. AGroup: only that group (-1 = all); AHeaders: group headers of
    /// AHeaderHeight.</summary>
    procedure Build(const AItemSize: TSizeF; const AColumns: Integer; const AHeaders: Boolean;
      const AHeaderHeight: Single; const AGroup: Integer = -1);
    function CellAt(const P: TPointF): Integer;
    function IndexOfEntry(const AEntry: TFmrGalleryEntry): Integer;
    /// <summary>Cell reached from AFrom with an arrow key, Home/End or PgUp/PgDn (APageRows rows); -1 when Up/Down
    /// leave the grid.</summary>
    function Navigate(const AFrom: Integer; const AKey: Word; const APageRows: Integer): Integer;
    property Gallery: TFmrGalleryItem read FGallery;
    property Count: Integer read GetCount;
    property Cells[const AIndex: Integer]: TFmrGalleryCell read GetCell; default;
    property Headers: TArray<TFmrGalleryHeader> read FHeaders;
    property ItemSize: TSizeF read FItemSize;
    property Columns: Integer read FColumns;
    property RowCount: Integer read FRowCount;
    property Height: Single read FHeight;
  end;

  /// <summary>Inner part of an in-ribbon gallery under the mouse.</summary>
  TFmrGalleryPart = (None, Cell, ScrollUp, ScrollDown, DropDown, Frame);

  /// <summary>View of a TFmrGalleryItem: an in-ribbon gallery in classic groups, a drop-down button elsewhere (or
  /// when the layout reduced the gallery to a button).</summary>
  TFmrGalleryView = class(TFmrButtonView)
  private
    FGrid: TFmrGalleryGrid;
    FInRibbon: Boolean;
    FColumns: Integer;
    FRows: Integer;
    FTopRow: Integer;
    FHotCell: Integer;
    FSub: TFmrGalleryPart;
    FPreview: Boolean;
    FItemSize: TSizeF;
    FColW: Single;
    FExtra: Single;
    FButtonW: Single;
    FGridDirty: Boolean;
    function Gallery: TFmrGalleryItem; inline;
    procedure UpdateMetrics;
    procedure RebuildGrid;
    function StripWidth: Single;
    function GridRect: TRectF;
    function PartRect(const APart: TFmrGalleryPart): TRectF;
    function CellRect(const AIndex: Integer): TRectF;
    function MaxTopRow: Integer;
    function SubPartAt(const P: TPointF; out ACell: Integer): TFmrGalleryPart;
    procedure EndPreview;
    procedure EnsureSelectedVisible;
    function StripState(const APart: TFmrGalleryPart): TFmrPartState;
  protected
    procedure SetHotPart(const Value: TFmrElementPart); override;
  public
    constructor Create(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
      const APlace: TFmrViewPlace); override;
    destructor Destroy; override;
    function LayoutLink: TFmrLayoutLink; override;
    procedure Place(const ABounds: TRectF; const ALevel: TFmrViewLevel; const ASegment: TFmrLayoutSegment); override;
    procedure Hide; override;
    procedure ItemChanged(const AChange: TFmrItemChange); override;
    function PartAt(const P: TPointF): TFmrElementPart; override;
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Execute(const APart: TFmrElementPart); override;
    procedure MouseMoveAt(const P: TPointF); override;
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipAnchor: TPointF; override;
    /// <summary>Scrolls the in-ribbon gallery by ADelta rows.</summary>
    procedure ScrollRows(const ADelta: Integer);
    /// <summary>True while the gallery is shown in the ribbon (not as a drop-down button).</summary>
    property InRibbon: Boolean read FInRibbon;
    property TopRow: Integer read FTopRow;
    property Columns: Integer read FColumns;
    property VisibleRows: Integer read FRows;
  end;

  TFmrGallerySectionKind = (Gallery, Menu);

  /// <summary>One section of a gallery popup: an (inline) gallery or a menu.</summary>
  TFmrGallerySection = class
  private
    FKind: TFmrGallerySectionKind;
    FGallery: TFmrGalleryItem;
    FGrid: TFmrGalleryGrid;
    FMenu: TFmrMenuControl;
    FTemp: TFmrTempMenu;
    FLinks: TFmrItemLinks;
    FTop: Single;
    FHeight: Single;
    FScroll: Single;
    FPrimary: Boolean;
    FColumns: Integer;
    FScrollBar: Boolean;
    FNaturalWidth: Single;
  public
    destructor Destroy; override;
    property Kind: TFmrGallerySectionKind read FKind;
    property Gallery: TFmrGalleryItem read FGallery;
    property Grid: TFmrGalleryGrid read FGrid;
    property Menu: TFmrMenuControl read FMenu;
    property Top: Single read FTop;
    property Height: Single read FHeight;
    property Scroll: Single read FScroll;
  end;

  /// <summary>Content of a drop-down gallery (and of menus with gallery links).</summary>
  TFmrGalleryPopupContent = class(TControl, IFmrPopupContent)
  private type
    TCellRef = record
      Section: Integer;
      Cell: Integer;
      class function None: TCellRef; static;
      function IsNone: Boolean;
      function Same(const B: TCellRef): Boolean;
    end;
    THit = (None, Filter, Cell, ScrollBar, Thumb, Grip);
  private
    FContext: IFmrPopupContext;
    FOwnerItem: TFmrBarItem;
    FGallery: TFmrGalleryItem;
    FLinks: TFmrItemLinks;
    FUserWidth: Boolean;
    FLastMouse: TPointF;
    FSections: TObjectList<TFmrGallerySection>;
    FWidth: Single;
    FHeight: Single;
    FMinWidth: Single;
    FFilterGroup: Integer;
    FFilterRect: TRectF;
    FFilterHot: Boolean;
    FGripRect: TRectF;
    FResize: TFmrGalleryResizeMode;
    FHot: TCellRef;
    FFocus: TCellRef;
    FPressed: TCellRef;
    FMenuFocus: TFmrMenuControl;
    FPreviewGallery: TFmrGalleryItem;
    FResizing: Boolean;
    FResizeOrigin: TPointF;
    FResizeSize: TSizeF;
    FDragSection: Integer;
    FDragOffset: Single;
    FHotScrollSection: Integer;
    FArranging: Boolean;
    FRelocated: Boolean;
    FFilterPopup: TFmrPopupForm;
    function Painter: TFmrRibbonPainter; inline;
    function Images: TCustomImageList; inline;
    function MyPopup: TFmrPopupForm;
    procedure AddMenuSection(const ALinks: TFmrItemLinks; const ATemp: TFmrTempMenu);
    procedure BuildSections;
    procedure CreateMenus(const AWidth: Single);
    function ItemSizeOf(const AGallery: TFmrGalleryItem): TSizeF;
    function NaturalColumns(const S: TFmrGallerySection): Integer;
    function GalleryWidth(const S: TFmrGallerySection): Single;
    procedure Layout(const AWidth, AHeight: Single);
    procedure Arrange;
    function FilterBandHeight: Single;
    function GripHeight: Single;
    function ViewRect(const S: TFmrGallerySection): TRectF;
    function ScrollTrack(const S: TFmrGallerySection): TRectF;
    function ScrollThumb(const S: TFmrGallerySection): TRectF;
    function MaxScroll(const S: TFmrGallerySection): Single;
    procedure SetScroll(const S: TFmrGallerySection; const AValue: Single);
    function CellScreenRect(const ARef: TCellRef): TRectF;
    function CellRect(const ARef: TCellRef): TRectF;
    function HitAt(const P: TPointF; out ARef: TCellRef; out ASection: Integer): THit;
    procedure SetHot(const ARef: TCellRef);
    procedure SetFocusCell(const ARef: TCellRef);
    procedure EnsureVisible(const ARef: TCellRef);
    procedure Preview(const ARef: TCellRef);
    procedure EndPreview;
    procedure ClickCell(const ARef: TCellRef);
    procedure ShowFilterMenu;
    procedure ApplyFilter(const AGroup: Integer);
    function FilterCaption: string;
    procedure ApplySize(const AWidth, AHeight: Single);
    procedure FocusMenu(const AMenu: TFmrMenuControl; const AFirst: Boolean);
    procedure FocusSection(const AIndex: Integer; const AFirst: Boolean);
    function FirstSelectableLink(const AMenu: TFmrMenuControl; const ALast: Boolean): TFmrItemLink;
    procedure UpdateTip;
  protected
    { IFmrPopupContent }
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
    { TControl }
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DoMouseLeave; override;
  public
    /// <summary>Drop-down of a gallery item: the gallery, its filter, its commands (DropDownLinks) and the resize
    /// grip.</summary>
    constructor CreateGallery(const AContext: IFmrPopupContext; const AGallery: TFmrGalleryItem);
    /// <summary>Menu with inline galleries: ALinks are the links of a button or sub item.</summary>
    constructor CreateMenu(const AContext: IFmrPopupContext; const AOwnerItem: TFmrBarItem;
      const ALinks: TFmrItemLinks);
    destructor Destroy; override;
    /// <summary>Makes the content at least AWidth wide (more columns for the gallery).</summary>
    procedure SetMinWidth(const AWidth: Single);
    property Context: IFmrPopupContext read FContext;
    property Gallery: TFmrGalleryItem read FGallery;
    property Sections: TObjectList<TFmrGallerySection> read FSections;
    property FilterGroup: Integer read FFilterGroup;
  end;

/// <summary>Size of the cells of a gallery: ItemWidth/ItemHeight, or from the caption position, the captions and
/// the theme.</summary>
function FmrGalleryItemSize(const AGallery: TFmrGalleryItem; const APainter: TFmrRibbonPainter): TSizeF;
/// <summary>Paints one entry (background, owner drawing, glyph and caption).</summary>
procedure FmrDrawGalleryEntry(const ACanvas: TCanvas; const APainter: TFmrRibbonPainter;
  const AImages: TCustomImageList; const AGallery: TFmrGalleryItem; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AStates: TFmrGalleryDrawStates);
/// <summary>True when ALinks contains a visible gallery link (such menus are shown with inline galleries).</summary>
function FmrLinksHaveGallery(const ALinks: TFmrItemLinks): Boolean;

implementation

const
  GalleryFramePad = 2;
  PopupGridPad = 3;
  ScrollBarWidth = 9;
  SectionGap = 7;

{ helpers }

function FmrLinksHaveGallery(const ALinks: TFmrItemLinks): Boolean;
var
  I: Integer;
begin
  if ALinks <> nil then
    for I := 0 to ALinks.Count - 1 do
      if ALinks[I].IsVisible and (ALinks[I].Item is TFmrGalleryItem) then
        Exit(True);
  Result := False;
end;

function FmrGalleryItemSize(const AGallery: TFmrGalleryItem; const APainter: TFmrRibbonPainter): TSizeF;
var
  M: TFmrThemeMetrics;
  I: Integer;
  E: TFmrGalleryEntry;
  CapW, DescW, TextH: Single;
  HasDesc: Boolean;
begin
  M := APainter.Metrics;
  CapW := 0;
  DescW := 0;
  HasDesc := False;
  if AGallery.CaptionPosition <> TFmrGalleryCaptionPosition.None then
    for I := 0 to AGallery.EntryCount - 1 do
    begin
      E := AGallery.Entries[I];
      if not E.Visible then
        Continue;
      CapW := Max(CapW, APainter.TextWidth(E.Caption, 0, AGallery.CaptionPosition = TFmrGalleryCaptionPosition.Right));
      if E.Description <> '' then
      begin
        HasDesc := True;
        DescW := Max(DescW, Min(220, APainter.TextWidth(E.Description)));
      end;
    end;
  TextH := APainter.TextSize('Wg').Height;
  case AGallery.CaptionPosition of
    TFmrGalleryCaptionPosition.Bottom:
      Result := TSizeF.Create(Max(M.LargeGlyphSize + 20, Min(130, CapW + 12)), M.LargeGlyphSize + 12 + TextH);
    TFmrGalleryCaptionPosition.Right:
      if HasDesc then
        Result := TSizeF.Create(M.LargeGlyphSize + 24 + Min(260, Max(CapW, DescW)), Max(M.LargeGlyphSize + 12,
          2 * TextH + 14))
      else
        Result := TSizeF.Create(M.SmallGlyphSize + 22 + Min(220, CapW), Max(M.SmallButtonHeight + 2, TextH + 8));
  else
    Result := TSizeF.Create(M.LargeGlyphSize + 12, M.LargeGlyphSize + 12);
  end;
  if AGallery.ItemWidth > 0 then
    Result.Width := AGallery.ItemWidth;
  if AGallery.ItemHeight > 0 then
    Result.Height := AGallery.ItemHeight;
  Result := TSizeF.Create(Ceil(Result.Width), Ceil(Result.Height));
end;

procedure FmrDrawGalleryEntry(const ACanvas: TCanvas; const APainter: TFmrRibbonPainter;
  const AImages: TCustomImageList; const AGallery: TFmrGalleryItem; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AStates: TFmrGalleryDrawStates);
var
  M: TFmrThemeMetrics;
  R, GR, TR: TRectF;
  Handled, Disabled: Boolean;
  G: TFmrImageSource;
  GS, TextH, Op: Single;
  TextColor, DimColor, Tint: TAlphaColor;
  Bold: Boolean;
begin
  M := APainter.Metrics;
  R := ARect;
  R.Inflate(-1, -1);
  APainter.DrawGalleryItem(ACanvas, R, [TFmrGalleryDrawState.Hot, TFmrGalleryDrawState.Pressed] * AStates <> [],
    TFmrGalleryDrawState.Selected in AStates);
  Handled := False;
  if (AGallery is TFmrRibbonGalleryItem) and Assigned(TFmrRibbonGalleryItem(AGallery).OnDrawItem) then
    TFmrRibbonGalleryItem(AGallery).OnDrawItem(AGallery, ACanvas, AEntry, R, AStates, APainter, Handled);
  if Handled then
    Exit;
  Disabled := TFmrGalleryDrawState.Disabled in AStates;
  if TFmrGalleryDrawState.InRibbon in AStates then
  begin
    TextColor := APainter.ButtonTextColor(TFmrPartState.Normal);
    if Disabled then
      TextColor := APainter.ButtonTextColor(TFmrPartState.Disabled);
  end
  else if Disabled then
    TextColor := APainter.Theme.Colors[TFmrToken.MenuItemTextDisabled]
  else
    TextColor := APainter.Theme.Colors[TFmrToken.MenuItemText];
  DimColor := APainter.Theme.Colors[TFmrToken.MenuShortcutText];
  if Disabled then
  begin
    Op := 0.45;
    Tint := APainter.GlyphTint(TFmrPartState.Disabled);
  end
  else
  begin
    Op := 1;
    Tint := APainter.GlyphTint(TFmrPartState.Normal);
  end;
  G := AEntry.Glyph;
  if (G <> nil) and G.IsEmpty(AImages) then
    G := nil;
  TextH := APainter.TextSize('Wg').Height;
  case AGallery.CaptionPosition of
    TFmrGalleryCaptionPosition.Bottom:
      begin
        GS := Min(M.LargeGlyphSize, R.Height - TextH - 10);
        if G <> nil then
        begin
          GR := RectF(0, 0, GS, GS);
          GR.Offset(Round(R.CenterPoint.X - GS / 2), Round(R.Top + 4));
          G.Draw(ACanvas, GR, Op, Tint, AImages);
        end;
        TR := RectF(R.Left + 3, R.Bottom - TextH - 4, R.Right - 3, R.Bottom - 2);
        APainter.TextEx(ACanvas, TR, AEntry.Caption, TextColor, TTextAlign.Center, TTextAlign.Center, 0, False, False);
      end;
    TFmrGalleryCaptionPosition.Right:
      begin
        if R.Height >= M.LargeGlyphSize + 6 then
          GS := M.LargeGlyphSize
        else
          GS := M.SmallGlyphSize;
        TR := RectF(R.Left + 6, R.Top, R.Right - 4, R.Bottom);
        if G <> nil then
        begin
          GR := RectF(0, 0, GS, GS);
          GR.Offset(Round(R.Left + 6), Round(R.CenterPoint.Y - GS / 2));
          G.Draw(ACanvas, GR, Op, Tint, AImages);
          TR.Left := GR.Right + 8;
        end;
        Bold := AEntry.Description <> '';
        if Bold then
        begin
          APainter.TextEx(ACanvas, RectF(TR.Left, R.Top + 5, TR.Right, R.Top + 5 + TextH), AEntry.Caption, TextColor,
            TTextAlign.Leading, TTextAlign.Center, 0, True, False);
          APainter.TextEx(ACanvas, RectF(TR.Left, R.Top + 6 + TextH, TR.Right, R.Bottom - 3), AEntry.Description,
            DimColor, TTextAlign.Leading, TTextAlign.Leading, 0, False, True);
        end
        else
          APainter.TextEx(ACanvas, TR, AEntry.Caption, TextColor, TTextAlign.Leading, TTextAlign.Center, 0, False,
            False);
      end;
  else
    if G <> nil then
    begin
      GS := Min(M.LargeGlyphSize, Min(R.Width, R.Height) - 6);
      if GS < M.LargeGlyphSize - 4 then
        GS := Min(GS, M.SmallGlyphSize + 4);
      GR := RectF(0, 0, GS, GS);
      GR.Offset(Round(R.CenterPoint.X - GS / 2), Round(R.CenterPoint.Y - GS / 2));
      G.Draw(ACanvas, GR, Op, Tint, AImages);
    end
    else
      APainter.TextEx(ACanvas, RectF(R.Left + 2, R.Top, R.Right - 2, R.Bottom), AEntry.Caption, TextColor,
        TTextAlign.Center, TTextAlign.Center, 0, False, True);
  end;
end;

{ entry screen tips }

type
  /// Element handed to the screen tip controller for one gallery entry (the strings are copied, so the tip never
  /// touches an entry that was deleted meanwhile).
  TFmrGalleryTipElement = class(TFmrElement)
  private
    FHeader: string;
    FDescription: string;
    FEntry: TFmrGalleryEntry;
  public
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
  end;

var
  GGalleryTips: TFmrScreenTipController;
  GGalleryTip: TFmrGalleryTipElement;

procedure TFmrGalleryTipElement.Paint(const ACanvas: TCanvas);
begin
end;

function TFmrGalleryTipElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := Default(TFmrScreenTipInfo);
  AInfo.Header := FHeader;
  AInfo.Description := FDescription;
  Result := FHeader <> '';
end;

/// Hover over a gallery entry (nil: over none). Entries show a tip when they have a hint, or when their caption is
/// not painted in the cell.
procedure GalleryTipHover(const AGallery: TFmrGalleryItem; const AEntry: TFmrGalleryEntry; const AScreenRect: TRectF;
  const APainter: TFmrRibbonPainter; const AForm: TCommonCustomForm);
var
  Old: TFmrGalleryTipElement;
  Desc: string;
begin
  if (AEntry <> nil) and (AEntry.Hint = '') and ((AGallery.CaptionPosition <> TFmrGalleryCaptionPosition.None) or
    (AEntry.Caption = '')) then
  begin
    GalleryTipHover(AGallery, nil, AScreenRect, APainter, AForm);
    Exit;
  end;
  if AEntry = nil then
  begin
    if GGalleryTips <> nil then
      GGalleryTips.Cancel;
    FreeAndNil(GGalleryTip);
    Exit;
  end;
  if (GGalleryTip <> nil) and (GGalleryTip.FEntry = AEntry) then
    Exit;
  if GGalleryTips = nil then
    GGalleryTips := TFmrScreenTipController.Create;
  Old := GGalleryTip;
  GGalleryTip := TFmrGalleryTipElement.Create(nil);
  GGalleryTip.FEntry := AEntry;
  GGalleryTip.FHeader := AEntry.Caption;
  Desc := AEntry.Hint;
  if (Desc = '') and (AGallery.CaptionPosition <> TFmrGalleryCaptionPosition.Right) then
    Desc := AEntry.Description;
  GGalleryTip.FDescription := Desc;
  GGalleryTips.Hover(GGalleryTip, AScreenRect, APainter, AForm);
  Old.Free;
end;

{ TFmrRibbonGalleryItem }

constructor TFmrRibbonGalleryItem.Create(AOwner: TComponent);
begin
  inherited;
  FDropDownResize := TFmrGalleryResizeMode.Both;
end;

{ TFmrGalleryGrid }

constructor TFmrGalleryGrid.Create(const AGallery: TFmrGalleryItem);
begin
  inherited Create;
  FGallery := AGallery;
  FColumns := 1;
end;

function TFmrGalleryGrid.GetCount: Integer;
begin
  Result := Length(FCells);
end;

function TFmrGalleryGrid.GetCell(const AIndex: Integer): TFmrGalleryCell;
begin
  Result := FCells[AIndex];
end;

procedure TFmrGalleryGrid.Build(const AItemSize: TSizeF; const AColumns: Integer; const AHeaders: Boolean;
  const AHeaderHeight: Single; const AGroup: Integer);
var
  Cells: TList<TFmrGalleryCell>;
  Headers: TList<TFmrGalleryHeader>;
  G, I, Col, Row, N: Integer;
  Y: Single;
  Grp: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
  Cell: TFmrGalleryCell;
  H: TFmrGalleryHeader;
begin
  FItemSize := AItemSize;
  FColumns := Max(1, AColumns);
  Cells := TList<TFmrGalleryCell>.Create;
  Headers := TList<TFmrGalleryHeader>.Create;
  try
    Y := 0;
    Row := 0;
    Col := 0;
    for G := 0 to FGallery.Groups.Count - 1 do
    begin
      Grp := FGallery.Groups[G];
      if not Grp.Visible or ((AGroup >= 0) and (G <> AGroup)) then
        Continue;
      N := 0;
      for I := 0 to Grp.Items.Count - 1 do
        if Grp.Items[I].Visible then
          Inc(N);
      if N = 0 then
        Continue;
      if AHeaders then
      begin
        // Every group starts on a new row below its header.
        if Col > 0 then
        begin
          Y := Y + FItemSize.Height;
          Inc(Row);
          Col := 0;
        end;
        if (Grp.Caption <> '') and FGallery.ShowGroupHeaders then
        begin
          H.Caption := Grp.Caption;
          H.Rect := RectF(0, Y, FColumns * FItemSize.Width, Y + AHeaderHeight);
          Headers.Add(H);
          Y := Y + AHeaderHeight;
        end;
      end;
      for I := 0 to Grp.Items.Count - 1 do
      begin
        E := Grp.Items[I];
        if not E.Visible then
          Continue;
        if Col = FColumns then
        begin
          Col := 0;
          Y := Y + FItemSize.Height;
          Inc(Row);
        end;
        Cell.Entry := E;
        Cell.Rect := RectF(Col * FItemSize.Width, Y, (Col + 1) * FItemSize.Width, Y + FItemSize.Height);
        Cell.Row := Row;
        Cell.Col := Col;
        Cells.Add(Cell);
        Inc(Col);
      end;
    end;
    if Col > 0 then
    begin
      Y := Y + FItemSize.Height;
      Inc(Row);
    end;
    FCells := Cells.ToArray;
    FHeaders := Headers.ToArray;
    FRowCount := Row;
    FHeight := Y;
  finally
    Cells.Free;
    Headers.Free;
  end;
end;

function TFmrGalleryGrid.CellAt(const P: TPointF): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FCells) do
    if FCells[I].Rect.Contains(P) then
      Exit(I);
  Result := -1;
end;

function TFmrGalleryGrid.IndexOfEntry(const AEntry: TFmrGalleryEntry): Integer;
var
  I: Integer;
begin
  if AEntry <> nil then
    for I := 0 to High(FCells) do
      if FCells[I].Entry = AEntry then
        Exit(I);
  Result := -1;
end;

function TFmrGalleryGrid.Navigate(const AFrom: Integer; const AKey: Word; const APageRows: Integer): Integer;

  function Vertical(const AIndex, ADir: Integer): Integer;
  var
    I, Best, TargetRow: Integer;
    D, BestD, X: Single;
  begin
    Result := -1;
    if (AIndex < 0) or (AIndex > High(FCells)) then
      Exit;
    TargetRow := FCells[AIndex].Row + ADir;
    X := FCells[AIndex].Rect.CenterPoint.X;
    Best := -1;
    BestD := MaxSingle;
    for I := 0 to High(FCells) do
      if FCells[I].Row = TargetRow then
      begin
        D := Abs(FCells[I].Rect.CenterPoint.X - X);
        if D < BestD then
        begin
          BestD := D;
          Best := I;
        end;
      end;
    Result := Best;
  end;

var
  I, N: Integer;
begin
  if Length(FCells) = 0 then
    Exit(-1);
  if (AFrom < 0) or (AFrom > High(FCells)) then
  begin
    if AKey in [vkUp, vkEnd, vkPrior] then
      Exit(High(FCells))
    else
      Exit(0);
  end;
  case AKey of
    vkLeft: Result := Max(0, AFrom - 1);
    vkRight: Result := Min(High(FCells), AFrom + 1);
    vkUp: Result := Vertical(AFrom, -1);
    vkDown: Result := Vertical(AFrom, 1);
    vkHome: Result := 0;
    vkEnd: Result := High(FCells);
    vkPrior, vkNext:
      begin
        Result := AFrom;
        N := Max(1, APageRows);
        for I := 1 to N do
        begin
          if AKey = vkPrior then
            Result := Vertical(AFrom, -I)
          else
            Result := Vertical(AFrom, I);
          if Result < 0 then
          begin
            if AKey = vkPrior then
              Result := Vertical(AFrom, -(I - 1))
            else
              Result := Vertical(AFrom, I - 1);
            Break;
          end;
        end;
        if Result < 0 then
          Result := AFrom;
      end;
  else
    Result := AFrom;
  end;
end;

{ TFmrGalleryView }

constructor TFmrGalleryView.Create(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
  const APlace: TFmrViewPlace);
begin
  inherited;
  FGrid := TFmrGalleryGrid.Create(TFmrGalleryItem(ALink.Item));
  FHotCell := -1;
  FColumns := 1;
  FRows := 1;
  FGridDirty := True;
end;

destructor TFmrGalleryView.Destroy;
begin
  if FPreview and (Item <> nil) and not (csDestroying in Item.ComponentState) then
    Gallery.HotTrack(nil);
  if (GGalleryTip <> nil) and (FGrid.IndexOfEntry(GGalleryTip.FEntry) >= 0) then
    GalleryTipHover(Gallery, nil, TRectF.Empty, nil, nil);
  FreeAndNil(FGrid);
  inherited;
end;

function TFmrGalleryView.Gallery: TFmrGalleryItem;
begin
  Result := TFmrGalleryItem(Item);
end;

function TFmrGalleryView.StripWidth: Single;
begin
  Result := Max(14, Metrics.ScrollButtonWidth + 1);
end;

procedure TFmrGalleryView.UpdateMetrics;
begin
  FItemSize := FmrGalleryItemSize(Gallery, Painter);
  // The in-ribbon cells are never taller than the content height of the group.
  FItemSize.Height := Min(FItemSize.Height, Metrics.ContentHeight - 2 * GalleryFramePad);
  FColW := FItemSize.Width;
  FExtra := 2 * GalleryFramePad + StripWidth + 1;
  FButtonW := inherited MeasureWidth(TFmrViewLevel.Large);
end;

function TFmrGalleryView.LayoutLink: TFmrLayoutLink;
begin
  if (ViewPlace <> TFmrViewPlace.Group) or not Gallery.ShowInRibbon then
    Exit(inherited LayoutLink);
  UpdateMetrics;
  Result := TFmrLayoutLink.Gallery(FColW, Gallery.MinColumns, Gallery.MaxColumns, FExtra, FButtonW);
  Result.Hidden := not Link.IsVisible;
  Result.BeginGroup := Link.BeginGroup;
  Result.SimplifiedVisibility := Link.SimplifiedVisibility;
  Result.SimplifiedWidth := inherited MeasureWidth(TFmrViewLevel.SmallWithText);
end;

function TFmrGalleryView.GridRect: TRectF;
begin
  Result := RectF(Bounds.Left + GalleryFramePad, Bounds.Top + GalleryFramePad,
    Bounds.Right - StripWidth - 1 - GalleryFramePad + 1, Bounds.Bottom - GalleryFramePad);
end;

function TFmrGalleryView.PartRect(const APart: TFmrGalleryPart): TRectF;
var
  S: TRectF;
  H: Single;
begin
  S := RectF(Bounds.Right - StripWidth, Bounds.Top, Bounds.Right, Bounds.Bottom);
  H := S.Height / 3;
  case APart of
    TFmrGalleryPart.ScrollUp: Result := RectF(S.Left, S.Top, S.Right, Round(S.Top + H));
    TFmrGalleryPart.ScrollDown: Result := RectF(S.Left, Round(S.Top + H), S.Right, Round(S.Top + 2 * H));
    TFmrGalleryPart.DropDown: Result := RectF(S.Left, Round(S.Top + 2 * H), S.Right, S.Bottom);
  else
    Result := S;
  end;
end;

procedure TFmrGalleryView.RebuildGrid;
var
  GR: TRectF;
begin
  FGridDirty := False;
  if not FInRibbon then
    Exit;
  GR := GridRect;
  FRows := Max(1, Floor(GR.Height / Max(1, FItemSize.Height) + 0.001));
  FGrid.Build(FItemSize, FColumns, False, 0);
  FTopRow := EnsureRange(FTopRow, 0, MaxTopRow);
end;

function TFmrGalleryView.MaxTopRow: Integer;
begin
  Result := Max(0, FGrid.RowCount - FRows);
end;

function TFmrGalleryView.CellRect(const AIndex: Integer): TRectF;
var
  C: TFmrGalleryCell;
  GR: TRectF;
  OffY: Single;
begin
  if (AIndex < 0) or (AIndex >= FGrid.Count) then
    Exit(TRectF.Empty);
  C := FGrid[AIndex];
  if (C.Row < FTopRow) or (C.Row >= FTopRow + FRows) then
    Exit(TRectF.Empty);
  GR := GridRect;
  OffY := Round((GR.Height - FRows * FItemSize.Height) / 2);
  Result := RectF(GR.Left + C.Rect.Left, GR.Top + OffY + (C.Row - FTopRow) * FItemSize.Height,
    GR.Left + C.Rect.Right, GR.Top + OffY + (C.Row - FTopRow + 1) * FItemSize.Height);
end;

procedure TFmrGalleryView.Place(const ABounds: TRectF; const ALevel: TFmrViewLevel;
  const ASegment: TFmrLayoutSegment);
var
  Cols: Integer;
  WasInRibbon: Boolean;
begin
  inherited;
  WasInRibbon := FInRibbon;
  FInRibbon := False;
  if (ViewPlace = TFmrViewPlace.Group) and (ALevel = TFmrViewLevel.Large) and Gallery.ShowInRibbon then
  begin
    UpdateMetrics;
    Cols := Round((ABounds.Width - FExtra) / FColW);
    if (Cols >= 1) and (Abs(Cols * FColW + FExtra - ABounds.Width) < 1.5) then
    begin
      FInRibbon := True;
      FColumns := Cols;
      RebuildGrid;
      if not WasInRibbon then
        EnsureSelectedVisible;
    end;
  end;
  if not FInRibbon then
  begin
    FSub := TFmrGalleryPart.None;
    FHotCell := -1;
  end;
end;

procedure TFmrGalleryView.Hide;
begin
  EndPreview;
  FSub := TFmrGalleryPart.None;
  FHotCell := -1;
  inherited;
end;

procedure TFmrGalleryView.ItemChanged(const AChange: TFmrItemChange);
begin
  inherited;
  FGridDirty := True;
  if FInRibbon then
  begin
    RebuildGrid;
    if AChange = TFmrItemChange.Value then
      EnsureSelectedVisible;
  end;
  Invalidate;
end;

procedure TFmrGalleryView.EnsureSelectedVisible;
var
  I, Row: Integer;
begin
  I := FGrid.IndexOfEntry(Gallery.SelectedEntry);
  if I < 0 then
    Exit;
  Row := FGrid[I].Row;
  if Row < FTopRow then
    FTopRow := Row
  else if Row >= FTopRow + FRows then
    FTopRow := Row - FRows + 1;
  FTopRow := EnsureRange(FTopRow, 0, MaxTopRow);
end;

procedure TFmrGalleryView.ScrollRows(const ADelta: Integer);
var
  T: Integer;
begin
  T := EnsureRange(FTopRow + ADelta, 0, MaxTopRow);
  if T <> FTopRow then
  begin
    FTopRow := T;
    FHotCell := -1;
    EndPreview;
    Invalidate;
  end;
end;

function TFmrGalleryView.SubPartAt(const P: TPointF; out ACell: Integer): TFmrGalleryPart;
var
  I: Integer;
  R: TRectF;
begin
  ACell := -1;
  if not FInRibbon or not Bounds.Contains(P) then
    Exit(TFmrGalleryPart.None);
  if PartRect(TFmrGalleryPart.DropDown).Contains(P) then
    Exit(TFmrGalleryPart.DropDown);
  if PartRect(TFmrGalleryPart.ScrollUp).Contains(P) then
    Exit(TFmrGalleryPart.ScrollUp);
  if PartRect(TFmrGalleryPart.ScrollDown).Contains(P) then
    Exit(TFmrGalleryPart.ScrollDown);
  for I := 0 to FGrid.Count - 1 do
  begin
    R := CellRect(I);
    if not R.IsEmpty and R.Contains(P) then
    begin
      ACell := I;
      Exit(TFmrGalleryPart.Cell);
    end;
  end;
  Result := TFmrGalleryPart.Frame;
end;

function TFmrGalleryView.PartAt(const P: TPointF): TFmrElementPart;
begin
  if not FInRibbon then
    Exit(inherited PartAt(P));
  if not Visible or not Bounds.Contains(P) then
    Result := TFmrElementPart.None
  else if PartRect(TFmrGalleryPart.DropDown).Contains(P) then
    Result := TFmrElementPart.DropDown
  else
    Result := TFmrElementPart.Main;
end;

function TFmrGalleryView.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  if FInRibbon then
    Result := APart = TFmrElementPart.DropDown
  else
    Result := inherited OpensOnPress(APart);
end;

procedure TFmrGalleryView.EndPreview;
begin
  if FPreview then
  begin
    FPreview := False;
    if (Item <> nil) and not (csDestroying in Item.ComponentState) then
      Gallery.HotTrack(nil);
  end;
end;

procedure TFmrGalleryView.MouseMoveAt(const P: TPointF);
var
  Cell: Integer;
  Part: TFmrGalleryPart;
  HostCtl: TControl;
  R: TRectF;
  TL, BR: TPointF;
  E: TFmrGalleryEntry;
begin
  if not FInRibbon then
    Exit;
  Part := SubPartAt(P, Cell);
  if (Part = FSub) and (Cell = FHotCell) then
    Exit;
  FSub := Part;
  if Cell <> FHotCell then
  begin
    FHotCell := Cell;
    E := nil;
    if Cell >= 0 then
      E := FGrid[Cell].Entry;
    // Live preview while the mouse is over an entry; reverted when it leaves the entries.
    if (E <> nil) and E.Enabled and IsEnabled then
    begin
      FPreview := True;
      Gallery.HotTrack(E);
    end
    else
      EndPreview;
    HostCtl := nil;
    if Host <> nil then
      HostCtl := Host.GetHostControl;
    if (E <> nil) and (HostCtl <> nil) then
    begin
      R := CellRect(Cell);
      TL := HostCtl.LocalToScreen(PointF(R.Left, Bounds.Top));
      BR := HostCtl.LocalToScreen(PointF(R.Right, Bounds.Bottom + 4));
      GalleryTipHover(Gallery, E, RectF(TL.X, TL.Y, BR.X, BR.Y), Painter, FmrFormOf(HostCtl));
    end
    else
      GalleryTipHover(Gallery, nil, TRectF.Empty, nil, nil);
  end;
  Invalidate;
end;

procedure TFmrGalleryView.SetHotPart(const Value: TFmrElementPart);
begin
  inherited;
  if (Value = TFmrElementPart.None) and FInRibbon then
  begin
    if (FSub <> TFmrGalleryPart.None) or (FHotCell >= 0) then
    begin
      FSub := TFmrGalleryPart.None;
      FHotCell := -1;
      GalleryTipHover(Gallery, nil, TRectF.Empty, nil, nil);
      Invalidate;
    end;
    EndPreview;
  end;
end;

procedure TFmrGalleryView.Execute(const APart: TFmrElementPart);
var
  E: TFmrGalleryEntry;
  G: TFmrGalleryItem;
begin
  if not FInRibbon then
  begin
    inherited;
    Exit;
  end;
  if not IsEnabled then
    Exit;
  if APart = TFmrElementPart.DropDown then
  begin
    Host.ElementDropDown(Self, False);
    Exit;
  end;
  case FSub of
    TFmrGalleryPart.ScrollUp:
      ScrollRows(-1);
    TFmrGalleryPart.ScrollDown:
      ScrollRows(1);
    TFmrGalleryPart.Cell:
      if (FHotCell >= 0) and (FHotCell < FGrid.Count) then
      begin
        E := FGrid[FHotCell].Entry;
        if not E.Enabled then
          Exit;
        G := Gallery;
        // The preview is reverted before the click applies the entry for good.
        EndPreview;
        GalleryTipHover(G, nil, TRectF.Empty, nil, nil);
        Host.ElementExecuted(Self);
        G.ClickEntry(E);
      end;
  end;
end;

function TFmrGalleryView.StripState(const APart: TFmrGalleryPart): TFmrPartState;
begin
  if not IsEnabled then
    Exit(TFmrPartState.Disabled);
  case APart of
    TFmrGalleryPart.ScrollUp:
      if FTopRow <= 0 then
        Exit(TFmrPartState.Disabled);
    TFmrGalleryPart.ScrollDown:
      if FTopRow >= MaxTopRow then
        Exit(TFmrPartState.Disabled);
    TFmrGalleryPart.DropDown:
      if Host.IsElementDroppedDown(Self) or (PressedPart = TFmrElementPart.DropDown) then
        Exit(TFmrPartState.Pressed);
  end;
  if (HotPart <> TFmrElementPart.None) and (FSub = APart) then
  begin
    if PressedPart <> TFmrElementPart.None then
      Result := TFmrPartState.Pressed
    else
      Result := TFmrPartState.Hot;
  end
  else
    Result := TFmrPartState.Normal;
end;

procedure TFmrGalleryView.Paint(const ACanvas: TCanvas);
var
  I: Integer;
  R, GR, S: TRectF;
  States: TFmrGalleryDrawStates;
  State: TCanvasSaveState;
  E: TFmrGalleryEntry;
  BorderCol: TAlphaColor;
  Hot: Boolean;
begin
  if not Visible then
    Exit;
  if not FInRibbon then
  begin
    inherited;
    Exit;
  end;
  if FGridDirty then
    RebuildGrid;
  Hot := (HotPart <> TFmrElementPart.None) or Focused or Host.IsElementDroppedDown(Self);
  Painter.DrawGalleryFrame(ACanvas, Bounds, Hot);
  GR := GridRect;
  State := ACanvas.SaveState;
  try
    ACanvas.IntersectClipRect(GR);
    for I := 0 to FGrid.Count - 1 do
    begin
      R := CellRect(I);
      if R.IsEmpty then
        Continue;
      E := FGrid[I].Entry;
      States := [TFmrGalleryDrawState.InRibbon];
      if E = Gallery.SelectedEntry then
        Include(States, TFmrGalleryDrawState.Selected);
      if (I = FHotCell) and (HotPart <> TFmrElementPart.None) then
      begin
        if PressedPart <> TFmrElementPart.None then
          Include(States, TFmrGalleryDrawState.Pressed)
        else
          Include(States, TFmrGalleryDrawState.Hot);
      end;
      if not E.Enabled or not IsEnabled then
        Include(States, TFmrGalleryDrawState.Disabled);
      FmrDrawGalleryEntry(ACanvas, Painter, Images, Gallery, E, R, States);
    end;
  finally
    ACanvas.RestoreState(State);
  end;
  // The strip: scroll up, scroll down and the drop-down button, separated by lines.
  BorderCol := Painter.Theme.Colors[TFmrToken.GalleryBorder];
  if Hot then
    BorderCol := Painter.Theme.Colors[TFmrToken.EditBorderHot];
  for var P in [TFmrGalleryPart.ScrollUp, TFmrGalleryPart.ScrollDown, TFmrGalleryPart.DropDown] do
  begin
    S := PartRect(P);
    S.Inflate(-1, 0);
    if P = TFmrGalleryPart.ScrollUp then
      S.Top := S.Top + 1;
    if P = TFmrGalleryPart.DropDown then
      S.Bottom := S.Bottom - 1;
    case P of
      TFmrGalleryPart.ScrollUp:
        Painter.DrawGalleryScroll(ACanvas, S, TFmrArrowDirection.Up, StripState(P), False);
      TFmrGalleryPart.ScrollDown:
        Painter.DrawGalleryScroll(ACanvas, S, TFmrArrowDirection.Down, StripState(P), False);
    else
      Painter.DrawGalleryScroll(ACanvas, S, TFmrArrowDirection.Down, StripState(P), True);
    end;
  end;
  S := PartRect(TFmrGalleryPart.None);
  Painter.Line(ACanvas, PointF(Round(S.Left) + 0.5, S.Top + 1), PointF(Round(S.Left) + 0.5, S.Bottom - 1), BorderCol);
  Painter.Line(ACanvas, PointF(S.Left, Round(PartRect(TFmrGalleryPart.ScrollDown).Top) + 0.5),
    PointF(S.Right - 1, Round(PartRect(TFmrGalleryPart.ScrollDown).Top) + 0.5), BorderCol);
  Painter.Line(ACanvas, PointF(S.Left, Round(PartRect(TFmrGalleryPart.DropDown).Top) + 0.5),
    PointF(S.Right - 1, Round(PartRect(TFmrGalleryPart.DropDown).Top) + 0.5), BorderCol);
  PaintFocus(ACanvas);
end;

function TFmrGalleryView.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  // Entries have their own tips (GalleryTipHover); the strip and the frame show the tip of the gallery item.
  if FInRibbon and (FSub = TFmrGalleryPart.Cell) then
  begin
    AInfo := Default(TFmrScreenTipInfo);
    Exit(False);
  end;
  Result := inherited GetScreenTip(AInfo);
  if FInRibbon and (FSub = TFmrGalleryPart.DropDown) and not Result then
  begin
    AInfo.Header := FmrStr(TFmrStringId.GalleryMore);
    Result := True;
  end;
end;

function TFmrGalleryView.KeyTipAnchor: TPointF;
var
  R: TRectF;
begin
  if not FInRibbon then
    Exit(inherited KeyTipAnchor);
  R := PartRect(TFmrGalleryPart.DropDown);
  Result := PointF(R.CenterPoint.X, Bounds.Bottom - 2);
end;

{ TFmrGallerySection }

destructor TFmrGallerySection.Destroy;
begin
  FreeAndNil(FMenu);
  FreeAndNil(FTemp);
  FreeAndNil(FGrid);
  inherited;
end;

type
  TMenuAccess = class(TFmrMenuControl);

  /// Popup list of the filter band: "All" and the group names, the current one checked.
  TFmrGalleryFilterList = class(TControl, IFmrPopupContent)
  private
    FContext: IFmrPopupContext;
    FItems: TArray<string>;
    FIndex: Integer;
    FHot: Integer;
    FOnPick: TProc<Integer>;
    FWidth: Single;
    function RowRect(const I: Integer): TRectF;
    procedure Pick(const I: Integer);
  protected
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor CreateList(const AContext: IFmrPopupContext; const AItems: TArray<string>; const AIndex: Integer;
      const AOnPick: TProc<Integer>);
  end;

{ TFmrGalleryFilterList }

constructor TFmrGalleryFilterList.CreateList(const AContext: IFmrPopupContext; const AItems: TArray<string>;
  const AIndex: Integer; const AOnPick: TProc<Integer>);
var
  S: string;
begin
  inherited Create(nil);
  FContext := AContext;
  FItems := AItems;
  FIndex := AIndex;
  FHot := -1;
  FOnPick := AOnPick;
  HitTest := True;
  FWidth := 140;
  for S in FItems do
    FWidth := Max(FWidth, FContext.Painter.TextWidth(S) + 48);
end;

function TFmrGalleryFilterList.RowRect(const I: Integer): TRectF;
var
  H: Single;
begin
  H := FContext.Painter.Metrics.MenuItemHeight;
  Result := RectF(1, 2 + I * H, FWidth - 1, 2 + (I + 1) * H);
end;

function TFmrGalleryFilterList.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FWidth + 2, Length(FItems) * FContext.Painter.Metrics.MenuItemHeight + 6);
end;

function TFmrGalleryFilterList.PaintsOwnBackground: Boolean;
begin
  Result := False;
end;

procedure TFmrGalleryFilterList.PopupShown(const AByKeyboard: Boolean);
begin
  if AByKeyboard then
  begin
    FHot := Max(0, FIndex);
    Repaint;
  end;
end;

procedure TFmrGalleryFilterList.PopupClosed;
begin
end;

procedure TFmrGalleryFilterList.Pick(const I: Integer);
var
  P: TFmrPopupForm;
  Proc: TProc<Integer>;
begin
  if (I < 0) or (I > High(FItems)) then
    Exit;
  Proc := FOnPick;
  P := FmrPopups.PopupOf(Self);
  if P <> nil then
    FmrPopups.Close(P);
  if Assigned(Proc) then
    Proc(I);
end;

procedure TFmrGalleryFilterList.Paint;
var
  P: TFmrRibbonPainter;
  I: Integer;
  R: TRectF;
begin
  P := FContext.Painter;
  for I := 0 to High(FItems) do
  begin
    R := RowRect(I);
    if I = FHot then
      P.DrawMenuItem(Canvas, R, TFmrPartState.Hot);
    if I = FIndex then
      P.DrawCheckMark(Canvas, RectF(R.Left + 4, R.Top, R.Left + 24, R.Bottom),
        P.Theme.Colors[TFmrToken.MenuItemText]);
    P.TextEx(Canvas, RectF(R.Left + 30, R.Top, R.Right - 6, R.Bottom), FItems[I],
      P.Theme.Colors[TFmrToken.MenuItemText], TTextAlign.Leading, TTextAlign.Center, 0, I = FIndex, False);
  end;
end;

procedure TFmrGalleryFilterList.MouseMove(Shift: TShiftState; X, Y: Single);
var
  I, H: Integer;
begin
  inherited;
  H := -1;
  for I := 0 to High(FItems) do
    if RowRect(I).Contains(PointF(X, Y)) then
      H := I;
  if H <> FHot then
  begin
    FHot := H;
    Repaint;
  end;
end;

procedure TFmrGalleryFilterList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  for I := 0 to High(FItems) do
    if RowRect(I).Contains(PointF(X, Y)) then
    begin
      Pick(I);
      Exit;
    end;
end;

procedure TFmrGalleryFilterList.DoMouseLeave;
begin
  inherited;
  FHot := -1;
  Repaint;
end;

function TFmrGalleryFilterList.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  Result := True;
  case Key of
    vkUp:
      FHot := Max(0, FHot - 1);
    vkDown:
      FHot := Min(High(FItems), FHot + 1);
    vkReturn, vkSpace:
      begin
        Pick(FHot);
        Exit;
      end;
    vkEscape:
      Exit(False);
  end;
  Repaint;
end;

{ TFmrGalleryPopupContent.TCellRef }

class function TFmrGalleryPopupContent.TCellRef.None: TCellRef;
begin
  Result.Section := -1;
  Result.Cell := -1;
end;

function TFmrGalleryPopupContent.TCellRef.IsNone: Boolean;
begin
  Result := (Section < 0) or (Cell < 0);
end;

function TFmrGalleryPopupContent.TCellRef.Same(const B: TCellRef): Boolean;
begin
  Result := (Section = B.Section) and (Cell = B.Cell);
end;

function CellRef(const ASection, ACell: Integer): TFmrGalleryPopupContent.TCellRef;
begin
  Result.Section := ASection;
  Result.Cell := ACell;
end;

{ TFmrGalleryPopupContent }

constructor TFmrGalleryPopupContent.CreateGallery(const AContext: IFmrPopupContext; const AGallery: TFmrGalleryItem);
begin
  inherited Create(nil);
  FContext := AContext;
  FOwnerItem := AGallery;
  FGallery := AGallery;
  FSections := TObjectList<TFmrGallerySection>.Create(True);
  FFilterGroup := -1;
  FHot := TCellRef.None;
  FFocus := TCellRef.None;
  FPressed := TCellRef.None;
  FDragSection := -1;
  FHotScrollSection := -1;
  if AGallery is TFmrRibbonGalleryItem then
  begin
    FResize := TFmrRibbonGalleryItem(AGallery).DropDownResize;
    FMinWidth := TFmrRibbonGalleryItem(AGallery).DropDownMinWidth;
  end
  else
    FResize := TFmrGalleryResizeMode.Both;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
  BuildSections;
  Layout(-1, -1);
end;

constructor TFmrGalleryPopupContent.CreateMenu(const AContext: IFmrPopupContext; const AOwnerItem: TFmrBarItem;
  const ALinks: TFmrItemLinks);
begin
  inherited Create(nil);
  FContext := AContext;
  FOwnerItem := AOwnerItem;
  FLinks := ALinks;
  FSections := TObjectList<TFmrGallerySection>.Create(True);
  FFilterGroup := -1;
  FHot := TCellRef.None;
  FFocus := TCellRef.None;
  FPressed := TCellRef.None;
  FDragSection := -1;
  FHotScrollSection := -1;
  FResize := TFmrGalleryResizeMode.None;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
  BuildSections;
  Layout(-1, -1);
end;

destructor TFmrGalleryPopupContent.Destroy;
begin
  EndPreview;
  if (GGalleryTip <> nil) then
    GalleryTipHover(nil, nil, TRectF.Empty, nil, nil);
  FMenuFocus := nil;
  FreeAndNil(FSections);
  FContext := nil;
  inherited;
end;

function TFmrGalleryPopupContent.Painter: TFmrRibbonPainter;
begin
  Result := FContext.Painter;
end;

function TFmrGalleryPopupContent.Images: TCustomImageList;
begin
  Result := FContext.Images;
end;

function TFmrGalleryPopupContent.MyPopup: TFmrPopupForm;
var
  F: TCommonCustomForm;
begin
  F := FmrFormOf(Self);
  if F is TFmrPopupForm then
    Result := TFmrPopupForm(F)
  else
    Result := nil;
end;

procedure TFmrGalleryPopupContent.AddMenuSection(const ALinks: TFmrItemLinks; const ATemp: TFmrTempMenu);
var
  S: TFmrGallerySection;
begin
  S := TFmrGallerySection.Create;
  S.FKind := TFmrGallerySectionKind.Menu;
  S.FTemp := ATemp;
  if ATemp <> nil then
    S.FLinks := ATemp.Links
  else
    S.FLinks := ALinks;
  FSections.Add(S);
end;

procedure TFmrGalleryPopupContent.BuildSections;
var
  S: TFmrGallerySection;
  I: Integer;
  L: TFmrItemLink;
  Temp: TFmrTempMenu;
begin
  FSections.Clear;
  if FLinks = nil then
  begin
    S := TFmrGallerySection.Create;
    S.FKind := TFmrGallerySectionKind.Gallery;
    S.FGallery := FGallery;
    S.FGrid := TFmrGalleryGrid.Create(FGallery);
    S.FPrimary := True;
    FSections.Add(S);
    if FGallery.DropDownLinks.VisibleCount > 0 then
      AddMenuSection(FGallery.DropDownLinks, nil);
    Exit;
  end;
  Temp := nil;
  for I := 0 to FLinks.Count - 1 do
  begin
    L := FLinks[I];
    if not L.IsVisible or (L.Item = nil) then
      Continue;
    if L.Item is TFmrGalleryItem then
    begin
      if Temp <> nil then
      begin
        AddMenuSection(nil, Temp);
        Temp := nil;
      end;
      S := TFmrGallerySection.Create;
      S.FKind := TFmrGallerySectionKind.Gallery;
      S.FGallery := TFmrGalleryItem(L.Item);
      S.FGrid := TFmrGalleryGrid.Create(S.FGallery);
      // A gallery at the top of the menu (a drop-down button whose content is a gallery) behaves like the drop-down
      // of a gallery item: filter band, scrolling within the work area, resize grip.
      if FSections.Count = 0 then
      begin
        S.FPrimary := True;
        FGallery := S.FGallery;
        if FGallery is TFmrRibbonGalleryItem then
        begin
          FResize := TFmrRibbonGalleryItem(FGallery).DropDownResize;
          FMinWidth := TFmrRibbonGalleryItem(FGallery).DropDownMinWidth;
        end
        else
          FResize := TFmrGalleryResizeMode.Both;
      end;
      FSections.Add(S);
    end
    else
    begin
      if Temp = nil then
        Temp := TFmrTempMenu.Create;
      Temp.AddLink(L.Item, L.BeginGroup and (Temp.Links.Count > 0));
    end;
  end;
  if Temp <> nil then
    AddMenuSection(nil, Temp);
end;

procedure TFmrGalleryPopupContent.CreateMenus(const AWidth: Single);
var
  S: TFmrGallerySection;
  Focused: Boolean;
begin
  for S in FSections do
    if S.FKind = TFmrGallerySectionKind.Menu then
    begin
      if (S.FMenu <> nil) and (Abs(S.FMenu.Width - AWidth) < 0.5) then
        Continue;
      Focused := (S.FMenu <> nil) and (FMenuFocus = S.FMenu);
      if Focused then
        FMenuFocus := nil;
      FreeAndNil(S.FMenu);
      S.FMenu := TFmrMenuControl.CreateMenu(FContext, S.FLinks, TFmrMenuItemStyle.Auto, AWidth + 2);
      S.FMenu.Parent := Self;
      S.FMenu.Width := AWidth;
      if Focused then
        FMenuFocus := S.FMenu;
    end;
end;

function TFmrGalleryPopupContent.ItemSizeOf(const AGallery: TFmrGalleryItem): TSizeF;
begin
  Result := FmrGalleryItemSize(AGallery, Painter);
end;

function TFmrGalleryPopupContent.NaturalColumns(const S: TFmrGallerySection): Integer;
var
  ItemW: Single;
begin
  if S.FGallery.DropDownColumns > 0 then
    Result := S.FGallery.DropDownColumns
  else
    Result := Max(1, S.FGallery.MaxColumns);
  ItemW := Max(1, ItemSizeOf(S.FGallery).Width);
  if S.FPrimary and (FMinWidth > 0) then
    Result := Max(Result, Floor((FMinWidth - 2 * PopupGridPad - ScrollBarWidth) / ItemW));
end;

function TFmrGalleryPopupContent.GalleryWidth(const S: TFmrGallerySection): Single;
begin
  Result := S.FColumns * ItemSizeOf(S.FGallery).Width + 2 * PopupGridPad;
  if S.FScrollBar then
    Result := Result + ScrollBarWidth;
end;

function TFmrGalleryPopupContent.FilterBandHeight: Single;
var
  I, J, N: Integer;
  Any: Boolean;
begin
  Result := 0;
  if (FGallery = nil) or not FGallery.AllowFilter then
    Exit;
  N := 0;
  for I := 0 to FGallery.Groups.Count - 1 do
    if FGallery.Groups[I].Visible and (FGallery.Groups[I].Caption <> '') then
    begin
      Any := False;
      for J := 0 to FGallery.Groups[I].Items.Count - 1 do
        Any := Any or FGallery.Groups[I].Items[J].Visible;
      if Any then
        Inc(N);
    end;
  if N >= 2 then
    Result := Painter.Metrics.MenuItemHeight + 2;
end;

function TFmrGalleryPopupContent.GripHeight: Single;
begin
  if (FGallery <> nil) and (FResize <> TFmrGalleryResizeMode.None) then
    Result := 11
  else
    Result := 0;
end;

procedure TFmrGalleryPopupContent.Layout(const AWidth, AHeight: Single);
var
  M: TFmrThemeMetrics;
  S, Primary: TFmrGallerySection;
  Sz: TSizeF;
  W, Fixed, H, ContentH, RowH, HeaderH: Single;
  Intf: IFmrPopupContent;
  Group: Integer;
begin
  FArranging := True;
  try
    M := Painter.Metrics;
    HeaderH := M.MenuItemHeight;
    Primary := nil;
    if AWidth > 0 then
      W := AWidth
    else
      W := FMinWidth;
    for S in FSections do
      if S.FKind = TFmrGallerySectionKind.Gallery then
      begin
        Sz := ItemSizeOf(S.FGallery);
        if S.FPrimary then
          Primary := S;
        S.FScrollBar := S.FPrimary or (S.FGallery.DropDownRows > 0);
        if S.FPrimary and (AWidth > 0) and (FResize = TFmrGalleryResizeMode.Both) then
          S.FColumns := Max(1, Floor((AWidth - 2 * PopupGridPad - ScrollBarWidth) / Max(1, Sz.Width)))
        else
          S.FColumns := NaturalColumns(S);
        if S.FPrimary then
          Group := FFilterGroup
        else
          Group := -1;
        S.FGrid.Build(Sz, S.FColumns, True, HeaderH, Group);
        if AWidth <= 0 then
          W := Max(W, GalleryWidth(S))
        else
          W := Max(W, Sz.Width + 2 * PopupGridPad + ScrollBarWidth);
      end;
    // The menus are at least as wide as their rows need.
    for S in FSections do
      if S.FKind = TFmrGallerySectionKind.Menu then
      begin
        if S.FNaturalWidth <= 0 then
        begin
          CreateMenus(0);
          if Supports(S.FMenu, IFmrPopupContent, Intf) then
            S.FNaturalWidth := Intf.GetPopupSize.Width - 2;
        end;
        W := Max(W, S.FNaturalWidth);
      end;
    W := Ceil(Max(W, 120));
    CreateMenus(W);
    // Heights: everything but the primary gallery is fixed.
    Fixed := FilterBandHeight + GripHeight + (FSections.Count - 1) * SectionGap;
    for S in FSections do
      if S.FKind = TFmrGallerySectionKind.Menu then
      begin
        if Supports(S.FMenu, IFmrPopupContent, Intf) then
          S.FHeight := Intf.GetPopupSize.Height - 2
        else
          S.FHeight := 0;
        Fixed := Fixed + S.FHeight;
      end
      else if not S.FPrimary then
      begin
        RowH := S.FGrid.ItemSize.Height;
        H := S.FGrid.Height + 2 * PopupGridPad;
        if S.FGallery.DropDownRows > 0 then
          H := Min(H, S.FGallery.DropDownRows * RowH + 2 * PopupGridPad + HeaderH);
        S.FHeight := H;
        S.FScroll := EnsureRange(S.FScroll, 0, MaxScroll(S));
        Fixed := Fixed + H;
      end;
    if Primary <> nil then
    begin
      RowH := Primary.FGrid.ItemSize.Height;
      ContentH := Primary.FGrid.Height + 2 * PopupGridPad;
      if AHeight > 0 then
        H := AHeight - Fixed
      else if Primary.FGallery.DropDownRows > 0 then
        H := Min(ContentH, Primary.FGallery.DropDownRows * RowH + 2 * PopupGridPad +
          IfThen(Length(Primary.FGrid.Headers) > 0, HeaderH, 0))
      else
        H := Min(ContentH, Max(3 * RowH, Screen.WorkAreaHeight * 0.6 - Fixed));
      H := Max(H, Min(ContentH, RowH + 2 * PopupGridPad));
      H := Max(H, RowH * 0.5);
      Primary.FHeight := Round(H);
      Primary.FScroll := EnsureRange(Primary.FScroll, 0, MaxScroll(Primary));
    end;
    FWidth := W;
    Arrange;
  finally
    FArranging := False;
  end;
end;

procedure TFmrGalleryPopupContent.Arrange;
var
  S: TFmrGallerySection;
  I: Integer;
  Y: Single;
begin
  Y := 0;
  FFilterRect := RectF(0, 0, FWidth, FilterBandHeight);
  Y := Y + FFilterRect.Height;
  for I := 0 to FSections.Count - 1 do
  begin
    S := FSections[I];
    if I > 0 then
      Y := Y + SectionGap;
    S.FTop := Y;
    if (S.FKind = TFmrGallerySectionKind.Menu) and (S.FMenu <> nil) then
      S.FMenu.SetBounds(0, Y, FWidth, S.FHeight);
    Y := Y + S.FHeight;
  end;
  FGripRect := RectF(0, Y, FWidth, Y + GripHeight);
  Y := Y + GripHeight;
  FHeight := Ceil(Y);
end;

function TFmrGalleryPopupContent.ViewRect(const S: TFmrGallerySection): TRectF;
begin
  Result := RectF(0, S.FTop, FWidth, S.FTop + S.FHeight);
end;

function TFmrGalleryPopupContent.MaxScroll(const S: TFmrGallerySection): Single;
begin
  if S.FKind <> TFmrGallerySectionKind.Gallery then
    Exit(0);
  Result := Max(0, S.FGrid.Height + 2 * PopupGridPad - S.FHeight);
end;

function TFmrGalleryPopupContent.ScrollTrack(const S: TFmrGallerySection): TRectF;
var
  V: TRectF;
begin
  V := ViewRect(S);
  Result := RectF(V.Right - ScrollBarWidth + 2, V.Top + 2, V.Right - 2, V.Bottom - 2);
end;

function TFmrGalleryPopupContent.ScrollThumb(const S: TFmrGallerySection): TRectF;
var
  T: TRectF;
  H, Content, MaxS: Single;
begin
  T := ScrollTrack(S);
  Content := S.FGrid.Height + 2 * PopupGridPad;
  MaxS := MaxScroll(S);
  if (Content <= 0) or (MaxS <= 0) then
    Exit(T);
  H := Max(16, T.Height * S.FHeight / Content);
  Result := RectF(T.Left, T.Top + (T.Height - H) * S.FScroll / MaxS, T.Right, 0);
  Result.Bottom := Result.Top + H;
end;

procedure TFmrGalleryPopupContent.SetScroll(const S: TFmrGallerySection; const AValue: Single);
var
  V: Single;
begin
  V := Round(EnsureRange(AValue, 0, MaxScroll(S)));
  if V <> S.FScroll then
  begin
    S.FScroll := V;
    GalleryTipHover(nil, nil, TRectF.Empty, nil, nil);
    Repaint;
  end;
end;

function TFmrGalleryPopupContent.CellRect(const ARef: TCellRef): TRectF;
var
  S: TFmrGallerySection;
  C: TFmrGalleryCell;
begin
  if ARef.IsNone or (ARef.Section >= FSections.Count) then
    Exit(TRectF.Empty);
  S := FSections[ARef.Section];
  if (S.FGrid = nil) or (ARef.Cell >= S.FGrid.Count) then
    Exit(TRectF.Empty);
  C := S.FGrid[ARef.Cell];
  Result := RectF(PopupGridPad + C.Rect.Left, S.FTop + PopupGridPad + C.Rect.Top - S.FScroll,
    PopupGridPad + C.Rect.Right, S.FTop + PopupGridPad + C.Rect.Bottom - S.FScroll);
end;

function TFmrGalleryPopupContent.CellScreenRect(const ARef: TCellRef): TRectF;
var
  R: TRectF;
  TL, BR: TPointF;
begin
  R := CellRect(ARef);
  TL := LocalToScreen(R.TopLeft);
  BR := LocalToScreen(R.BottomRight);
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

function TFmrGalleryPopupContent.HitAt(const P: TPointF; out ARef: TCellRef; out ASection: Integer): THit;
var
  I, C: Integer;
  S: TFmrGallerySection;
  V, R: TRectF;
begin
  ARef := TCellRef.None;
  ASection := -1;
  if (FFilterRect.Height > 0) and FFilterRect.Contains(P) then
    Exit(THit.Filter);
  if (FGripRect.Height > 0) and FGripRect.Contains(P) then
    Exit(THit.Grip);
  for I := 0 to FSections.Count - 1 do
  begin
    S := FSections[I];
    if S.FKind <> TFmrGallerySectionKind.Gallery then
      Continue;
    V := ViewRect(S);
    if not V.Contains(P) then
      Continue;
    ASection := I;
    if (MaxScroll(S) > 0) and (P.X >= ScrollTrack(S).Left - 2) then
    begin
      if ScrollThumb(S).Contains(PointF(ScrollThumb(S).CenterPoint.X, P.Y)) then
        Exit(THit.Thumb)
      else
        Exit(THit.ScrollBar);
    end;
    for C := 0 to S.FGrid.Count - 1 do
    begin
      R := CellRect(CellRef(I, C));
      if R.Contains(P) then
      begin
        ARef := CellRef(I, C);
        Exit(THit.Cell);
      end;
    end;
    Exit(THit.None);
  end;
  Result := THit.None;
end;

procedure TFmrGalleryPopupContent.UpdateTip;
var
  S: TFmrGallerySection;
  R: TRectF;
begin
  if FHot.IsNone then
  begin
    GalleryTipHover(nil, nil, TRectF.Empty, nil, nil);
    Exit;
  end;
  S := FSections[FHot.Section];
  R := CellScreenRect(FHot);
  R.Bottom := R.Bottom + 4;
  GalleryTipHover(S.FGallery, S.FGrid[FHot.Cell].Entry, R, Painter, FContext.OwnerForm);
end;

procedure TFmrGalleryPopupContent.Preview(const ARef: TCellRef);
var
  S: TFmrGallerySection;
  E: TFmrGalleryEntry;
begin
  if ARef.IsNone then
  begin
    EndPreview;
    Exit;
  end;
  S := FSections[ARef.Section];
  E := S.FGrid[ARef.Cell].Entry;
  if not E.Enabled or not S.FGallery.Enabled then
  begin
    EndPreview;
    Exit;
  end;
  if (FPreviewGallery <> nil) and (FPreviewGallery <> S.FGallery) then
    EndPreview;
  FPreviewGallery := S.FGallery;
  S.FGallery.HotTrack(E);
end;

procedure TFmrGalleryPopupContent.EndPreview;
var
  G: TFmrGalleryItem;
begin
  G := FPreviewGallery;
  FPreviewGallery := nil;
  if (G <> nil) and not (csDestroying in G.ComponentState) then
    G.HotTrack(nil);
end;

procedure TFmrGalleryPopupContent.SetHot(const ARef: TCellRef);
begin
  if ARef.Same(FHot) then
    Exit;
  FHot := ARef;
  if not ARef.IsNone then
  begin
    // The mouse takes over from the keyboard (like Office); arrows continue from the hot entry.
    if FMenuFocus <> nil then
    begin
      TMenuAccess(FMenuFocus).DoMouseLeave;
      FMenuFocus := nil;
    end;
    FFocus := TCellRef.None;
    Preview(ARef);
  end
  else if FFocus.IsNone then
    EndPreview
  else
    Preview(FFocus);
  UpdateTip;
  Repaint;
end;

procedure TFmrGalleryPopupContent.SetFocusCell(const ARef: TCellRef);
begin
  if FMenuFocus <> nil then
  begin
    TMenuAccess(FMenuFocus).DoMouseLeave;
    FMenuFocus := nil;
  end;
  FFocus := ARef;
  if not ARef.IsNone then
  begin
    EnsureVisible(ARef);
    Preview(ARef);
  end
  else
    EndPreview;
  Repaint;
end;

procedure TFmrGalleryPopupContent.EnsureVisible(const ARef: TCellRef);
var
  S: TFmrGallerySection;
  C: TFmrGalleryCell;
  Top, Bottom: Single;
begin
  if ARef.IsNone then
    Exit;
  S := FSections[ARef.Section];
  C := S.FGrid[ARef.Cell];
  if C.Row = 0 then
    Top := 0
  else
    Top := C.Rect.Top;
  Bottom := C.Rect.Bottom + 2 * PopupGridPad;
  if Top < S.FScroll then
    SetScroll(S, Top)
  else if Bottom > S.FScroll + S.FHeight then
    SetScroll(S, Bottom - S.FHeight);
end;

procedure TFmrGalleryPopupContent.ClickCell(const ARef: TCellRef);
var
  S: TFmrGallerySection;
  E: TFmrGalleryEntry;
  G: TFmrGalleryItem;
  Ctx: IFmrPopupContext;
begin
  if ARef.IsNone then
    Exit;
  S := FSections[ARef.Section];
  E := S.FGrid[ARef.Cell].Entry;
  G := S.FGallery;
  if not E.Enabled or not G.Enabled then
    Exit;
  Ctx := FContext;
  // The preview is reverted first, then the click applies the entry for good. The click runs from the message
  // loop: a handler that shows a modal dialog must not run inside the mouse handler of a popup that is freed
  // meanwhile.
  EndPreview;
  GalleryTipHover(nil, nil, TRectF.Empty, nil, nil);
  FmrPopups.CloseAll;
  TThread.ForceQueue(nil,
    procedure
    begin
      Ctx.ItemExecuting(G);
      G.ClickEntry(E);
    end);
end;

function TFmrGalleryPopupContent.FilterCaption: string;
begin
  if (FFilterGroup >= 0) and (FGallery <> nil) and (FFilterGroup < FGallery.Groups.Count) then
    Result := FGallery.Groups[FFilterGroup].Caption
  else
    Result := FmrStr(TFmrStringId.GalleryAll);
end;

procedure TFmrGalleryPopupContent.ShowFilterMenu;
var
  Names: TArray<string>;
  Groups: TArray<Integer>;
  I, Current: Integer;
  List: TFmrGalleryFilterList;
  Anchor: TRectF;
  TL, BR: TPointF;
begin
  if FGallery = nil then
    Exit;
  Names := [FmrStr(TFmrStringId.GalleryAll)];
  Groups := [-1];
  Current := 0;
  for I := 0 to FGallery.Groups.Count - 1 do
    if FGallery.Groups[I].Visible and (FGallery.Groups[I].Caption <> '') then
    begin
      Names := Names + [FGallery.Groups[I].Caption];
      Groups := Groups + [I];
      if I = FFilterGroup then
        Current := High(Names);
    end;
  List := TFmrGalleryFilterList.CreateList(FContext, Names, Current,
    procedure(AIndex: Integer)
    begin
      FFilterPopup := nil;
      ApplyFilter(Groups[AIndex]);
    end);
  FFilterPopup := TFmrPopupForm.CreatePopup(FContext, List);
  TL := LocalToScreen(PointF(FFilterRect.Left, FFilterRect.Top));
  BR := LocalToScreen(PointF(FFilterRect.Left + 160, FFilterRect.Bottom));
  Anchor := RectF(TL.X, TL.Y, BR.X, BR.Y);
  FmrPopups.Show(FFilterPopup, Anchor, TFmrPopupPlacement.Below, MyPopup, False);
end;

procedure TFmrGalleryPopupContent.ApplyFilter(const AGroup: Integer);
var
  S: TFmrGallerySection;
begin
  if AGroup = FFilterGroup then
    Exit;
  FFilterGroup := AGroup;
  FHot := TCellRef.None;
  FFocus := TCellRef.None;
  EndPreview;
  for S in FSections do
    S.FScroll := 0;
  if FUserWidth then
    Layout(FWidth, FHeight)
  else
    Layout(-1, FHeight);
  Repaint;
end;

procedure TFmrGalleryPopupContent.SetMinWidth(const AWidth: Single);
begin
  if Abs(AWidth - FMinWidth) < 0.5 then
    Exit;
  FMinWidth := AWidth;
  Layout(-1, -1);
end;

procedure TFmrGalleryPopupContent.ApplySize(const AWidth, AHeight: Single);
var
  P: TFmrPopupForm;
begin
  if FResize = TFmrGalleryResizeMode.Both then
  begin
    FUserWidth := True;
    Layout(AWidth, AHeight);
  end
  else
    Layout(-1, AHeight);
  P := MyPopup;
  FArranging := True;
  try
    if P <> nil then
      P.SetBoundsF(P.BoundsF.Left, P.BoundsF.Top, FWidth + 2 + 2 * P.ShadowSize, FHeight + 2 + 2 * P.ShadowSize + 2);
    SetBounds(Position.X, Position.Y, FWidth, FHeight);
  finally
    FArranging := False;
  end;
  Repaint;
end;

function TFmrGalleryPopupContent.FirstSelectableLink(const AMenu: TFmrMenuControl;
  const ALast: Boolean): TFmrItemLink;
var
  I: Integer;
  L: TFmrItemLink;
begin
  Result := nil;
  if (AMenu = nil) or (AMenu.Links = nil) then
    Exit;
  for I := 0 to AMenu.Links.Count - 1 do
  begin
    L := AMenu.Links[I];
    if not L.IsVisible or (L.Item = nil) or (L.Item is TFmrSeparatorItem) or (L.Item is TFmrStaticItem) then
      Continue;
    Result := L;
    if not ALast then
      Exit;
  end;
end;

procedure TFmrGalleryPopupContent.FocusMenu(const AMenu: TFmrMenuControl; const AFirst: Boolean);
var
  Intf: IFmrPopupContent;
  K: Word;
  Ch: WideChar;
begin
  FFocus := TCellRef.None;
  FHot := TCellRef.None;
  EndPreview;
  Repaint;
  FMenuFocus := AMenu;
  if AFirst then
    AMenu.SelectFirst
  else if Supports(AMenu, IFmrPopupContent, Intf) then
  begin
    K := vkEnd;
    Ch := #0;
    Intf.PopupKeyDown(K, Ch, []);
  end;
end;

procedure TFmrGalleryPopupContent.FocusSection(const AIndex: Integer; const AFirst: Boolean);
var
  S: TFmrGallerySection;
  I: Integer;
begin
  I := AIndex;
  while (I >= 0) and (I < FSections.Count) do
  begin
    S := FSections[I];
    if (S.FKind = TFmrGallerySectionKind.Gallery) and (S.FGrid.Count > 0) then
    begin
      if AFirst then
        SetFocusCell(CellRef(I, 0))
      else
        SetFocusCell(CellRef(I, S.FGrid.Count - 1));
      Exit;
    end;
    if (S.FKind = TFmrGallerySectionKind.Menu) and (S.FMenu <> nil) and (FirstSelectableLink(S.FMenu, False) <> nil) then
    begin
      FocusMenu(S.FMenu, AFirst);
      Exit;
    end;
    if AFirst then
      Inc(I)
    else
      Dec(I);
  end;
end;

function TFmrGalleryPopupContent.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FWidth + 2, FHeight + 2);
end;

function TFmrGalleryPopupContent.PaintsOwnBackground: Boolean;
begin
  Result := False;
end;

procedure TFmrGalleryPopupContent.PopupShown(const AByKeyboard: Boolean);
var
  P: TFmrPopupForm;
  A, R: TRectF;
  S: TFmrGallerySection;
  Intf: IFmrPopupContent;
  I, C: Integer;
begin
  P := MyPopup;
  // Over an in-ribbon gallery the drop-down opens at the gallery's top-left corner, at least as wide as it.
  if (P <> nil) and not FRelocated and (P.AnchorElement is TFmrGalleryView) and
    TFmrGalleryView(P.AnchorElement).InRibbon then
  begin
    FRelocated := True;
    A := P.Anchor;
    SetMinWidth(A.Width - 2);
    R := TFmrPopupManager.PlaceRect(RectF(A.Left, A.Top, A.Left, A.Top), TSizeF.Create(FWidth + 2, FHeight + 2),
      TFmrPopupPlacement.Below);
    FArranging := True;
    try
      P.SetBoundsF(R.Left - P.ShadowSize, R.Top - P.ShadowSize, R.Width + 2 * P.ShadowSize,
        R.Height + 2 * P.ShadowSize + 2);
      SetBounds(P.ShadowSize + 1, P.ShadowSize + 1, R.Width - 2, R.Height - 2);
    finally
      FArranging := False;
    end;
    if R.Height - 2 < FHeight - 0.5 then
      Layout(-1, R.Height - 2);
  end;
  for S in FSections do
    if (S.FMenu <> nil) and Supports(S.FMenu, IFmrPopupContent, Intf) then
      Intf.PopupShown(False);
  // The selected entry is scrolled into view (and focused when opened with the keyboard).
  for I := 0 to FSections.Count - 1 do
  begin
    S := FSections[I];
    if S.FKind <> TFmrGallerySectionKind.Gallery then
      Continue;
    C := S.FGrid.IndexOfEntry(S.FGallery.SelectedEntry);
    if C >= 0 then
    begin
      EnsureVisible(CellRef(I, C));
      if AByKeyboard then
      begin
        SetFocusCell(CellRef(I, C));
        Exit;
      end;
    end;
  end;
  if AByKeyboard then
    FocusSection(0, True);
end;

procedure TFmrGalleryPopupContent.PopupClosed;
var
  S: TFmrGallerySection;
  Intf: IFmrPopupContent;
begin
  EndPreview;
  GalleryTipHover(nil, nil, TRectF.Empty, nil, nil);
  FResizing := False;
  FDragSection := -1;
  for S in FSections do
    if (S.FMenu <> nil) and Supports(S.FMenu, IFmrPopupContent, Intf) then
      Intf.PopupClosed;
end;

function TFmrGalleryPopupContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar;
  const Shift: TShiftState): Boolean;
var
  Intf: IFmrPopupContent;
  S: TFmrGallerySection;
  I, N, Rows, Idx: Integer;
begin
  Result := True;
  if FMenuFocus <> nil then
  begin
    Idx := -1;
    for I := 0 to FSections.Count - 1 do
      if FSections[I].FMenu = FMenuFocus then
        Idx := I;
    if (Key = vkUp) and (Idx > 0) and (FMenuFocus.HotRow <> nil) and
      (FMenuFocus.HotRow.Link = FirstSelectableLink(FMenuFocus, False)) then
    begin
      FocusSection(Idx - 1, False);
      Exit;
    end;
    if (Key = vkDown) and (Idx >= 0) and (Idx < FSections.Count - 1) and (FMenuFocus.HotRow <> nil) and
      (FMenuFocus.HotRow.Link = FirstSelectableLink(FMenuFocus, True)) then
    begin
      FocusSection(Idx + 1, True);
      Exit;
    end;
    if Supports(FMenuFocus, IFmrPopupContent, Intf) then
      Exit(Intf.PopupKeyDown(Key, KeyChar, Shift));
  end;
  case Key of
    vkLeft, vkRight, vkUp, vkDown, vkHome, vkEnd, vkPrior, vkNext:
      begin
        if FFocus.IsNone and not FHot.IsNone then
          FFocus := FHot;
        if FFocus.IsNone then
        begin
          if Key in [vkUp, vkEnd, vkPrior] then
            FocusSection(FSections.Count - 1, False)
          else
            FocusSection(0, True);
          Exit;
        end;
        S := FSections[FFocus.Section];
        Rows := Max(1, Floor(S.FHeight / Max(1, S.FGrid.ItemSize.Height)));
        N := S.FGrid.Navigate(FFocus.Cell, Key, Rows - 1);
        if N < 0 then
        begin
          if (Key = vkDown) and (FFocus.Section < FSections.Count - 1) then
            FocusSection(FFocus.Section + 1, True)
          else if (Key = vkUp) and (FFocus.Section > 0) then
            FocusSection(FFocus.Section - 1, False);
        end
        else
          SetFocusCell(CellRef(FFocus.Section, N));
      end;
    vkTab:
      if FFocus.IsNone then
        FocusSection(0, True)
      else
        FocusSection(FFocus.Section + 1, True);
    vkReturn, vkSpace:
      if not FFocus.IsNone then
        ClickCell(FFocus);
    vkEscape:
      Result := False;
  else
    // Accelerators and key tips of the commands below the gallery.
    for I := FSections.Count - 1 downto 0 do
      if (FSections[I].FMenu <> nil) and Supports(FSections[I].FMenu, IFmrPopupContent, Intf) then
      begin
        Result := Intf.PopupKeyDown(Key, KeyChar, Shift);
        if FSections[I].FMenu.HotRow <> nil then
        begin
          FFocus := TCellRef.None;
          FMenuFocus := FSections[I].FMenu;
          Repaint;
        end;
        Exit;
      end;
  end;
end;

procedure TFmrGalleryPopupContent.Paint;
var
  P: TFmrRibbonPainter;
  I, C: Integer;
  S: TFmrGallerySection;
  V, R: TRectF;
  H: TFmrGalleryHeader;
  E: TFmrGalleryEntry;
  States: TFmrGalleryDrawStates;
  State: TCanvasSaveState;
  Ref: TCellRef;
  RightEdge: Single;
begin
  P := Painter;
  if FFilterRect.Height > 0 then
    P.DrawGalleryFilterBand(Canvas, FFilterRect, FilterCaption, FFilterHot);
  for I := 0 to FSections.Count - 1 do
  begin
    S := FSections[I];
    if I > 0 then
      P.DrawMenuSeparator(Canvas, RectF(0, S.FTop - SectionGap, FWidth, S.FTop), 0);
    if S.FKind <> TFmrGallerySectionKind.Gallery then
      Continue;
    V := ViewRect(S);
    P.Fill(Canvas, RectF(V.Left + 1, V.Top, V.Right - 1, V.Bottom), TFmrToken.GalleryFill);
    RightEdge := V.Right;
    if MaxScroll(S) > 0 then
      RightEdge := ScrollTrack(S).Left - 2;
    State := Canvas.SaveState;
    try
      Canvas.IntersectClipRect(V);
      for H in S.FGrid.Headers do
      begin
        R := RectF(V.Left + 1, S.FTop + PopupGridPad + H.Rect.Top - S.FScroll, RightEdge,
          S.FTop + PopupGridPad + H.Rect.Bottom - S.FScroll);
        if R.IntersectsWith(V) then
          P.DrawGalleryGroupHeader(Canvas, RectF(R.Left, R.Top + 1, R.Right, R.Bottom - 2), H.Caption);
      end;
      for C := 0 to S.FGrid.Count - 1 do
      begin
        Ref := CellRef(I, C);
        R := CellRect(Ref);
        if not R.IntersectsWith(V) then
          Continue;
        E := S.FGrid[C].Entry;
        States := [];
        if E = S.FGallery.SelectedEntry then
          Include(States, TFmrGalleryDrawState.Selected);
        if Ref.Same(FHot) or Ref.Same(FFocus) then
        begin
          if Ref.Same(FPressed) and Ref.Same(FHot) then
            Include(States, TFmrGalleryDrawState.Pressed)
          else
            Include(States, TFmrGalleryDrawState.Hot);
        end;
        if not E.Enabled or not S.FGallery.Enabled then
          Include(States, TFmrGalleryDrawState.Disabled);
        FmrDrawGalleryEntry(Canvas, P, Images, S.FGallery, E, R, States);
      end;
    finally
      Canvas.RestoreState(State);
    end;
    if MaxScroll(S) > 0 then
      P.DrawThinScrollBar(Canvas, ScrollTrack(S), ScrollThumb(S), (FHotScrollSection = I) or (FDragSection = I));
  end;
  if FGripRect.Height > 0 then
    P.DrawResizeGrip(Canvas, RectF(FGripRect.Left + 1, FGripRect.Top, FGripRect.Right - 1, FGripRect.Bottom),
      FResize = TFmrGalleryResizeMode.Both);
end;

procedure TFmrGalleryPopupContent.Resize;
begin
  inherited;
  if FArranging or (FWidth <= 0) then
    Exit;
  // The popup manager clamps the popup to the work area: the gallery gets the height that is left.
  if Height < FHeight - 0.5 then
  begin
    Layout(IfThen(FUserWidth, FWidth, -1), Height);
    Repaint;
  end;
end;

procedure TFmrGalleryPopupContent.MouseMove(Shift: TShiftState; X, Y: Single);
var
  P, Cur: TPointF;
  Ref: TCellRef;
  Sec, OldScroll: Integer;
  Hit: THit;
  S: TFmrGallerySection;
  T, Th: TRectF;
  NewW, NewH, MaxH: Single;
  Work: TRectF;
  Popup: TFmrPopupForm;
  Hot: Boolean;
begin
  inherited;
  P := PointF(X, Y);
  FLastMouse := P;
  if FResizing then
  begin
    Cur := LocalToScreen(P);
    NewW := FResizeSize.Width;
    if FResize = TFmrGalleryResizeMode.Both then
      NewW := FResizeSize.Width + Cur.X - FResizeOrigin.X;
    NewH := FResizeSize.Height + Cur.Y - FResizeOrigin.Y;
    Popup := MyPopup;
    if Popup <> nil then
    begin
      Work := Screen.DisplayFromRect(Popup.ContentScreenRect).WorkareaRect;
      MaxH := Work.Bottom - LocalToScreen(PointF(0, 0)).Y - 4;
      NewH := Min(NewH, MaxH);
      NewW := Min(NewW, Work.Right - LocalToScreen(PointF(0, 0)).X - 4);
    end;
    ApplySize(Max(NewW, 60), Max(NewH, 20));
    Exit;
  end;
  if FDragSection >= 0 then
  begin
    S := FSections[FDragSection];
    T := ScrollTrack(S);
    Th := ScrollThumb(S);
    if T.Height - Th.Height > 0 then
      SetScroll(S, (Y - FDragOffset - T.Top) / (T.Height - Th.Height) * MaxScroll(S));
    Exit;
  end;
  Hit := HitAt(P, Ref, Sec);
  Hot := Hit = THit.Filter;
  if Hot <> FFilterHot then
  begin
    FFilterHot := Hot;
    Repaint;
  end;
  OldScroll := FHotScrollSection;
  if Hit in [THit.ScrollBar, THit.Thumb] then
    FHotScrollSection := Sec
  else
    FHotScrollSection := -1;
  if OldScroll <> FHotScrollSection then
    Repaint;
  case Hit of
    THit.Grip:
      if FResize = TFmrGalleryResizeMode.Both then
        Cursor := crSizeNWSE
      else
        Cursor := crSizeNS;
  else
    Cursor := crDefault;
  end;
  SetHot(Ref);
end;

procedure TFmrGalleryPopupContent.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  P: TPointF;
  Ref: TCellRef;
  Sec: Integer;
  S: TFmrGallerySection;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  P := PointF(X, Y);
  case HitAt(P, Ref, Sec) of
    THit.Filter:
      ShowFilterMenu;
    THit.Grip:
      begin
        FResizing := True;
        FResizeOrigin := LocalToScreen(P);
        FResizeSize := TSizeF.Create(FWidth, FHeight);
      end;
    THit.Thumb:
      begin
        FDragSection := Sec;
        FDragOffset := Y - ScrollThumb(FSections[Sec]).Top;
      end;
    THit.ScrollBar:
      begin
        S := FSections[Sec];
        if Y < ScrollThumb(S).Top then
          SetScroll(S, S.FScroll - S.FHeight * 0.9)
        else
          SetScroll(S, S.FScroll + S.FHeight * 0.9);
      end;
    THit.Cell:
      begin
        FPressed := Ref;
        Repaint;
      end;
  end;
end;

procedure TFmrGalleryPopupContent.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Ref, Pressed: TCellRef;
  Sec: Integer;
begin
  inherited;
  if FResizing then
  begin
    FResizing := False;
    Exit;
  end;
  if FDragSection >= 0 then
  begin
    FDragSection := -1;
    Repaint;
    Exit;
  end;
  Pressed := FPressed;
  FPressed := TCellRef.None;
  if Button <> TMouseButton.mbLeft then
    Exit;
  if (HitAt(PointF(X, Y), Ref, Sec) = THit.Cell) and Ref.Same(Pressed) then
    ClickCell(Ref)
  else
    Repaint;
end;

procedure TFmrGalleryPopupContent.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
var
  I, Target: Integer;
  S: TFmrGallerySection;
begin
  inherited;
  if Handled then
    Exit;
  Target := -1;
  for I := 0 to FSections.Count - 1 do
    if (FSections[I].FKind = TFmrGallerySectionKind.Gallery) and (MaxScroll(FSections[I]) > 0) then
    begin
      if ViewRect(FSections[I]).Contains(FLastMouse) or (Target < 0) then
        Target := I;
    end;
  if Target < 0 then
    Exit;
  S := FSections[Target];
  SetScroll(S, S.FScroll - WheelDelta / 120 * S.FGrid.ItemSize.Height);
  Handled := True;
  FHot := TCellRef.None;
  MouseMove([], FLastMouse.X, FLastMouse.Y);
end;

procedure TFmrGalleryPopupContent.DoMouseLeave;
begin
  inherited;
  if FResizing or (FDragSection >= 0) then
    Exit;
  FFilterHot := False;
  FHotScrollSection := -1;
  Cursor := crDefault;
  FHot := TCellRef.None;
  if FFocus.IsNone then
    EndPreview;
  GalleryTipHover(nil, nil, TRectF.Empty, nil, nil);
  Repaint;
end;

{ drop-down factories }

function CreateGalleryDropDown(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
var
  G: TFmrGalleryItem;
begin
  G := TFmrGalleryItem(AItem);
  if (G.EntryCount = 0) and (G.DropDownLinks.VisibleCount = 0) then
    Exit(nil);
  Result := TFmrGalleryPopupContent.CreateGallery(AContext, G);
end;

function CreateLinksDropDown(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
var
  Links: TFmrItemLinks;
begin
  Result := nil;
  if AItem is TFmrButtonItem then
    Links := TFmrButtonItem(AItem).DropDownLinks
  else if AItem is TFmrSubItem then
    Links := TFmrSubItem(AItem).ItemLinks
  else
    Links := nil;
  if FmrLinksHaveGallery(Links) then
    Result := TFmrGalleryPopupContent.CreateMenu(AContext, AItem, Links);
end;

initialization
  FmrRegisterItemView(TFmrGalleryItem, TFmrGalleryView);
  FmrRegisterDropDown(TFmrGalleryItem, CreateGalleryDropDown);
  FmrRegisterDropDown(TFmrButtonItem, CreateLinksDropDown);
  FmrRegisterDropDown(TFmrSubItem, CreateLinksDropDown);
  RegisterFmxClasses([TFmrRibbonGalleryItem]);

finalization
  FreeAndNil(GGalleryTip);
  FreeAndNil(GGalleryTips);

end.
