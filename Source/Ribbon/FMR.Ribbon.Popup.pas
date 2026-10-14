{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Popup windows, menus and keyboard routing            }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Popup;

/// Popup infrastructure used by every part of the ribbon: menus, drop-down buttons, collapsed group popups, the
/// popup of a minimized ribbon, the quick access toolbar menus, color palettes and later galleries and the
/// application menu.
///
/// Windows: TFmrPopupForm is a borderless FMX form with FormStyle = Popup (non-activating, top-most, layered for the
/// shadow and the rounded corners drawn by the painter). FMX closes such forms when the user clicks anywhere else
/// (TScreen.PrepareClosePopups / ClosePopupForms) and when the application is deactivated; a popup whose Parent is
/// another popup is kept while the user clicks in its descendants, which gives the submenu chain. TFmrPopupManager
/// keeps the chain in order (closing a popup closes its descendants), places popups below/beside a screen rectangle
/// and flips them at the edges of the work area, and frees closed windows later (FMX may still hold them in its
/// prepared popup list until the mouse button is released).
///
/// Keyboard: popup forms never get the keyboard focus, so keys are routed from the owner form. While a popup chain is
/// open (or key tips are shown) an invisible focusable control (key sink) holds the focus of the owner form; it gives
/// every key to the top popup (menu navigation, accelerators, key tips) or to the editor focused inside the popup
/// (editors in collapsed groups accept typing), and restores the previously focused control afterwards.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Math,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Painter, FMR.Ribbon.Views,
  FMR.Ribbon.KeyTips, FMR.Ribbon.Strings;

type
  TFmrPopupForm = class;
  TFmrMenuControl = class;

  /// <summary>Where a popup goes relative to its anchor rectangle (screen coordinates).</summary>
  TFmrPopupPlacement = (
    /// <summary>Below the anchor, left aligned (above when there is no room below).</summary>
    Below,
    /// <summary>Right of the anchor, top aligned (left when there is no room): submenus.</summary>
    Right,
    /// <summary>At the top-left corner of the anchor (context menus).</summary>
    AtPoint,
    /// <summary>Above the anchor, left aligned.</summary>
    Above,
    /// <summary>Below the anchor, right aligned (buttons at the right end of a bar).</summary>
    BelowEnd);

  /// <summary>Row style of a menu.</summary>
  TFmrMenuItemStyle = (
    /// <summary>Large rows (32 dp glyph, bold caption, description) when an item has a large glyph and a
    /// description; normal rows otherwise.</summary>
    Auto,
    Normal,
    /// <summary>Office 2007 style rows: large glyph, bold caption and the description below it.</summary>
    Large);

  /// <summary>Services shared by the popups of one chain (painter, images, key tips); implemented by the ribbon and
  /// by TFmrPopupMenu.</summary>
  IFmrPopupContext = interface
    ['{0F6E0B2C-5D7A-4C8E-AE3B-8B9A3F0C7D51}']
    function GetPainter: TFmrRibbonPainter;
    function GetImages: TCustomImageList;
    function GetOwnerForm: TCommonCustomForm;
    function GetKeyTipsActive: Boolean;
    procedure SetKeyTipsActive(const AValue: Boolean);
    /// <summary>An item of a popup is about to run (the popups are closed already).</summary>
    procedure ItemExecuting(const AItem: TFmrBarItem);
    /// <summary>Right click on an item of a popup; True when a context menu was shown.</summary>
    function ItemContextPopup(const AItem: TFmrBarItem; const AScreenPoint: TPointF): Boolean;
    property Painter: TFmrRibbonPainter read GetPainter;
    property Images: TCustomImageList read GetImages;
    property OwnerForm: TCommonCustomForm read GetOwnerForm;
    property KeyTipsActive: Boolean read GetKeyTipsActive write SetKeyTipsActive;
  end;

  /// <summary>Default popup context: a painter, images and the owner form.</summary>
  TFmrPopupContext = class(TInterfacedObject, IFmrPopupContext)
  private
    FPainter: TFmrRibbonPainter;
    FImages: TCustomImageList;
    FOwnerForm: TCommonCustomForm;
    FKeyTips: Boolean;
  protected
    function GetPainter: TFmrRibbonPainter; virtual;
    function GetImages: TCustomImageList; virtual;
    function GetOwnerForm: TCommonCustomForm; virtual;
    function GetKeyTipsActive: Boolean; virtual;
    procedure SetKeyTipsActive(const AValue: Boolean); virtual;
    procedure ItemExecuting(const AItem: TFmrBarItem); virtual;
    function ItemContextPopup(const AItem: TFmrBarItem; const AScreenPoint: TPointF): Boolean; virtual;
  public
    constructor Create(const APainter: TFmrRibbonPainter; const AImages: TCustomImageList;
      const AOwnerForm: TCommonCustomForm);
  end;

  /// <summary>Optional interface of the content control of a popup.</summary>
  IFmrPopupContent = interface
    ['{7A2D9C41-3E0B-4B6F-9F55-2C8E1A7B6D02}']
    /// <summary>Size of the content (dp) without the shadow.</summary>
    function GetPopupSize: TSizeF;
    /// <summary>A key routed from the owner form; True when handled.</summary>
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    /// <summary>The popup was shown (AByKeyboard: opened with the keyboard: select the first item).</summary>
    procedure PopupShown(const AByKeyboard: Boolean);
    /// <summary>The popup closed (synchronously, before its window is freed).</summary>
    procedure PopupClosed;
    /// <summary>True when the content paints its own background (the window paints only the shadow).</summary>
    function PaintsOwnBackground: Boolean;
  end;

  /// <summary>Receives the keys of a form while it captures the keyboard (key tips).</summary>
  IFmrKeyHandler = interface
    ['{C3B1E6A8-9D24-4F0E-8A6C-5E7F2B1D9A63}']
    function HandleKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    /// <summary>The capture ended because the user moved the focus elsewhere (a click into an editor...).</summary>
    procedure KeyboardLost;
  end;

  /// <summary>Paints the shadow and the background of a popup window and holds its content.</summary>
  TFmrPopupFrame = class(TControl)
  private
    [Weak] FPopup: TFmrPopupForm;
  protected
    procedure Paint; override;
  end;

  /// <summary>Borderless popup window (FormStyle = Popup) with one content control.</summary>
  TFmrPopupForm = class(TCustomForm)
  private
    FFrame: TFmrPopupFrame;
    FContent: TControl;
    FContext: IFmrPopupContext;
    [Weak] FParentPopup: TFmrPopupForm;
    FOnClosed: TProc;
    FShadow: Single;
    FOwnedObjects: TObjectList<TObject>;
    FAnchor: TRectF;
    FByKeyboard: Boolean;
    FCaptureKeyboard: Boolean;
    FClosed: Boolean;
    FCloseTime: TDateTime;
    FAnchorElement: TObject;
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    /// <summary>Creates a hidden popup around AContent (the popup becomes its parent).</summary>
    constructor CreatePopup(const AContext: IFmrPopupContext; const AContent: TControl);
    destructor Destroy; override;
    /// <summary>The content as IFmrPopupContent (nil when it does not implement it).</summary>
    function ContentIntf: IFmrPopupContent;
    /// <summary>Frees AObject with the window (temporary items of context menus...).</summary>
    procedure OwnObject(const AObject: TObject);
    /// <summary>Screen rectangle of the content (without the shadow).</summary>
    function ContentScreenRect: TRectF;
    property Content: TControl read FContent;
    property Context: IFmrPopupContext read FContext;
    property ParentPopup: TFmrPopupForm read FParentPopup;
    /// <summary>Called once when the popup closes (by the user, the manager or FMX).</summary>
    property OnClosed: TProc read FOnClosed write FOnClosed;
    /// <summary>Width of the shadow around the content (dp).</summary>
    property ShadowSize: Single read FShadow write FShadow;
    /// <summary>The popup takes the keys of its owner form while it is open (default True).</summary>
    property CaptureKeyboard: Boolean read FCaptureKeyboard write FCaptureKeyboard;
    /// <summary>Takes the content back (a borrowed control the opener reparents when the popup closes).</summary>
    procedure ReleaseContent;
    property Anchor: TRectF read FAnchor;
    property ByKeyboard: Boolean read FByKeyboard;
    /// <summary>Free for the opener (the element whose drop-down this popup is).</summary>
    property AnchorElement: TObject read FAnchorElement write FAnchorElement;
  end;

  TFmrKeySink = class;

  /// <summary>Chain of open popups, placement, keyboard routing and lazy freeing.</summary>
  TFmrPopupManager = class
  private type
    TNotifier = class(TComponent)
    private
      FManager: TFmrPopupManager;
    protected
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    end;
  private
    FChain: TList<TFmrPopupForm>;
    FGraveyard: TList<TFmrPopupForm>;
    FTimer: TTimer;
    FNotifier: TNotifier;
    FSink: TFmrKeySink;
    FSinkForm: TCommonCustomForm;
    FSavedFocus: TControl;
    FHandlers: TList<IFmrKeyHandler>;
    FUpdatingSink: Boolean;
    FClosingAll: Boolean;
    procedure TimerProc(Sender: TObject);
    procedure Forget(const AComponent: TComponent);
    procedure PopupClosing(const APopup: TFmrPopupForm);
    procedure Bury(const APopup: TFmrPopupForm);
    procedure UpdateSink;
    procedure RemoveSink(const ARestoreFocus: Boolean);
    procedure SinkLostFocus;
    function NeedsSink(out AForm: TCommonCustomForm): Boolean;
    function SinkKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    function SinkKeyUp(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Shows APopup next to AAnchor (screen dp). AParent: the popup this one belongs to (submenu); nil closes
    /// every open popup first.</summary>
    procedure Show(const APopup: TFmrPopupForm; const AAnchor: TRectF; const APlacement: TFmrPopupPlacement;
      const AParent: TFmrPopupForm = nil; const AByKeyboard: Boolean = False);
    /// <summary>Closes APopup and every popup opened from it.</summary>
    procedure Close(const APopup: TFmrPopupForm);
    procedure CloseChildrenOf(const APopup: TFmrPopupForm);
    procedure CloseAll;
    function IsOpen: Boolean;
    function Top: TFmrPopupForm;
    function Contains(const APopup: TFmrPopupForm): Boolean;
    /// <summary>The open popup that contains AObject (nil when none).</summary>
    function PopupOf(const AObject: TFmxObject): TFmrPopupForm;
    /// <summary>A key for the open popups (the ribbon passes the dialog keys of a non-capturing chain, e.g. the
    /// command search); True when handled.</summary>
    function KeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    /// <summary>AHandler receives every key of AForm until it is removed (key tips).</summary>
    procedure AddKeyHandler(const AForm: TCommonCustomForm; const AHandler: IFmrKeyHandler);
    procedure RemoveKeyHandler(const AHandler: IFmrKeyHandler);
    function HasKeyHandler(const AHandler: IFmrKeyHandler): Boolean;
    /// <summary>Screen rectangle of a popup of ASize placed at AAnchor, flipped and clamped to the work area.
    /// </summary>
    class function PlaceRect(const AAnchor: TRectF; const ASize: TSizeF; const APlacement: TFmrPopupPlacement): TRectF;
  end;

  /// <summary>Invisible focusable control that receives the keys of a form while popups or key tips are active.
  /// </summary>
  TFmrKeySink = class(TControl)
  private
    FManager: TFmrPopupManager;
    FReleasing: Boolean;
  protected
    procedure DialogKey(var Key: Word; Shift: TShiftState); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  /// <summary>Button item whose click runs an anonymous method (commands of the ribbon's own menus).</summary>
  TFmrCommandItem = class(TFmrButtonItem)
  private
    FOnExecute: TProc;
  protected
    procedure DoClick; override;
  public
    property OnExecute: TProc read FOnExecute write FOnExecute;
  end;

  /// <summary>Temporary items and links of a menu built in code; freed with the popup that shows them.</summary>
  TFmrTempMenu = class(TPersistent)
  private
    FLinks: TFmrItemLinks;
    FItems: TObjectList<TFmrBarItem>;
  public
    constructor Create;
    destructor Destroy; override;
    function AddCommand(const ACaption: string; const AExecute: TProc; const AChecked: Boolean = False;
      const ABeginGroup: Boolean = False; const AEnabled: Boolean = True): TFmrCommandItem;
    function AddHeader(const ACaption: string): TFmrSeparatorItem;
    function AddLink(const AItem: TFmrBarItem; const ABeginGroup: Boolean = False): TFmrItemLink;
    property Links: TFmrItemLinks read FLinks;
  end;

  TFmrMenuRowKind = (Item, Separator, Header, Static);

  /// <summary>One row of a menu.</summary>
  TFmrMenuRow = class(TFmrElement)
  private
    [Weak] FMenu: TFmrMenuControl;
    FLink: TFmrItemLink;
    FItem: TFmrBarItem;
    FKind: TFmrMenuRowKind;
    FLarge: Boolean;
    function Caption: string;
  protected
    function PartState(const APart: TFmrElementPart): TFmrPartState; override;
  public
    function IsEnabled: Boolean; override;
    function IsChecked: Boolean; override;
    function IsSelectable: Boolean;
    function HasSubMenu: Boolean;
    function IsSplit: Boolean;
    function ArrowRect: TRectF;
    function PartAt(const P: TPointF): TFmrElementPart; override;
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Execute(const APart: TFmrElementPart); override;
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipCaption: string; override;
    function ExplicitKeyTip: string; override;
    function KeyTipAnchor: TPointF; override;
    property Link: TFmrItemLink read FLink;
    property Item: TFmrBarItem read FItem;
    property Kind: TFmrMenuRowKind read FKind;
  end;

  /// <summary>Menu content: rows built from item links (glyph gutter, caption, shortcut, check marks, submenu
  /// arrows, separators and headers, large rows with descriptions). Submenus open on hover after a delay or with
  /// the keyboard.</summary>
  TFmrMenuControl = class(TControl, IFmrElementHost, IFmrPopupContent)
  private
    FContext: IFmrPopupContext;
    FLinks: TFmrItemLinks;
    FRows: TObjectList<TFmrMenuRow>;
    FStyle: TFmrMenuItemStyle;
    FLarge: Boolean;
    FHot: TFmrMenuRow;
    FHotPart: TFmrElementPart;
    FPressed: TFmrMenuRow;
    FSubRow: TFmrMenuRow;
    FSubPopup: TFmrPopupForm;
    FTimer: TTimer;
    FGutter: Single;
    FContentHeight: Single;
    FMenuWidth: Single;
    FScroll: Single;
    FMaxHeight: Single;
    FPad: Single;
    FMatcher: TFmrKeyTipMatcher;
    FKeyTipRows: TList<TFmrMenuRow>;
    FMinWidth: Single;
    FOwned: TObject;
    procedure Build;
    procedure Arrange;
    function RowAt(const P: TPointF): TFmrMenuRow;
    procedure SetHot(const ARow: TFmrMenuRow; const APart: TFmrElementPart);
    procedure TimerProc(Sender: TObject);
    procedure OpenSubMenu(const ARow: TFmrMenuRow; const AByKeyboard: Boolean);
    procedure CloseSubMenu;
    procedure ExecuteRow(const ARow: TFmrMenuRow);
    procedure MoveHot(const ADelta: Integer);
    procedure EnsureVisible(const ARow: TFmrMenuRow);
    procedure AssignKeyTips;
    function MyPopup: TFmrPopupForm;
    procedure SetScroll(const AValue: Single);
  protected
    { IFmrElementHost }
    function GetPainter: TFmrRibbonPainter;
    function GetImages: TCustomImageList;
    function GetHostControl: TControl;
    procedure InvalidateElement(const AElement: TFmrElement);
    procedure ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean);
    procedure ElementExecuted(const AElement: TFmrElement);
    function IsElementDroppedDown(const AElement: TFmrElement): Boolean;
    { IFmrPopupContent }
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
    { TControl }
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DoMouseLeave; override;
  public
    constructor CreateMenu(const AContext: IFmrPopupContext; const ALinks: TFmrItemLinks;
      const AStyle: TFmrMenuItemStyle = TFmrMenuItemStyle.Auto; const AMinWidth: Single = 0);
    destructor Destroy; override;
    /// <summary>Selects the first selectable row (keyboard).</summary>
    procedure SelectFirst;
    property Context: IFmrPopupContext read FContext;
    property Links: TFmrItemLinks read FLinks;
    property HotRow: TFmrMenuRow read FHot;
    /// <summary>Freed with the menu (a TFmrTempMenu whose links the menu shows).</summary>
    property OwnedObject: TObject read FOwned write FOwned;
  end;

  /// <summary>Color palette of a TFmrColorItem: automatic color, theme colors with tints and shades, standard
  /// colors, no color.</summary>
  TFmrColorPaletteControl = class(TControl, IFmrPopupContent)
  private type
    TCell = record
      Color: TAlphaColor;
      Rect: TRectF;
      Kind: Integer; // 0 color, 1 automatic, 2 no color
    end;
  private
    FContext: IFmrPopupContext;
    FItem: TFmrColorItem;
    FCells: TList<TCell>;
    FHot: Integer;
    FWidth, FHeight: Single;
    FHeaders: TList<TPair<Single, string>>;
    procedure Build;
    function CellAt(const P: TPointF): Integer;
    procedure SetHot(const AIndex: Integer);
    procedure Pick(const AIndex: Integer);
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
    constructor CreatePalette(const AContext: IFmrPopupContext; const AItem: TFmrColorItem);
    destructor Destroy; override;
  end;

  /// <summary>Creates the content of the drop-down of an item (nil: the item has none).</summary>
  TFmrDropDownFactory = reference to function(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;

  /// <summary>Supplies the painter and images of a ribbon to standalone popup menus.</summary>
  IFmrThemeSource = interface
    ['{2E8C5A17-4B3D-4E9F-B6A2-1D7C3F8E5B94}']
    function GetThemePainter: TFmrRibbonPainter;
    function GetThemeImages: TCustomImageList;
  end;

  /// <summary>Popup menu component (context menus): links to items of a bar manager, painted with the theme of a
  /// ribbon (ThemeSource) or its own built-in theme.</summary>
  TFmrPopupMenu = class(TFmxObject, IFmrItemLinksOwner)
  private
    FItemLinks: TFmrItemLinks;
    FBarManager: TFmrBarManager;
    FThemeSource: TFmxObject;
    FThemeName: string;
    FItemStyle: TFmrMenuItemStyle;
    FTheme: TFmrTheme;
    FPainter: TFmrRibbonPainter;
    FOnPopup: TNotifyEvent;
    FOnClose: TNotifyEvent;
    FPopupForm: TFmrPopupForm;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetThemeSource(const Value: TFmxObject);
    procedure SetThemeName(const Value: string);
    function IsThemeNameStored: Boolean;
    function ResolvePainter: TFmrRibbonPainter;
    function ResolveImages: TCustomImageList;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Shows the menu at a screen point (dp).</summary>
    procedure Popup(const X, Y: Single);
    /// <summary>Shows the menu below a screen rectangle.</summary>
    procedure PopupBelow(const AScreenRect: TRectF);
    procedure ClosePopup;
    function IsOpen: Boolean;
  published
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    property ItemStyle: TFmrMenuItemStyle read FItemStyle write FItemStyle default TFmrMenuItemStyle.Auto;
    /// <summary>Theme name used when ThemeSource is not set.</summary>
    property Theme: string read FThemeName write SetThemeName stored IsThemeNameStored;
    /// <summary>A ribbon (or any object implementing IFmrThemeSource) whose theme and images the menu uses.
    /// </summary>
    property ThemeSource: TFmxObject read FThemeSource write SetThemeSource;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
  end;

  /// <summary>Called when the hot row of a menu changes (ARow = nil: no hot row, the menu closes or is freed).
  /// </summary>
  TFmrMenuHotRowHook = procedure(const AMenu: TFmrMenuControl; const ARow: TFmrMenuRow);

var
  /// <summary>Menu screen tips: FMR.Ribbon.ScreenTips installs a handler that shows the screen tip of the hot row.
  /// </summary>
  FmrMenuHotRowHook: TFmrMenuHotRowHook;

/// <summary>The popup manager of the application (created on first use).</summary>
function FmrPopups: TFmrPopupManager;
/// <summary>True while the popup manager exists (False after finalization).</summary>
function FmrPopupsAssigned: Boolean;

/// <summary>Registers the drop-down content factory of AItemClass (and descendants without their own).</summary>
procedure FmrRegisterDropDown(const AItemClass: TFmrBarItemClass; const AFactory: TFmrDropDownFactory);
/// <summary>Content of the drop-down of AItem: a registered factory, otherwise a menu of its links
/// (TFmrButtonItem.DropDownLinks, TFmrSubItem.ItemLinks). Calls DropDown/Popup of the item first (lazy filling).
/// Returns nil when there is nothing to show.</summary>
function FmrCreateDropDownContent(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
/// <summary>True when AItem has a drop-down (submenu arrow in menus).</summary>
function FmrItemHasDropDown(const AItem: TFmrBarItem): Boolean;
/// <summary>The form that contains AObject (nil when none).</summary>
function FmrFormOf(const AObject: TFmxObject): TCommonCustomForm;

implementation

uses
  System.Character{$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF}, FMR.Ribbon.BiDi;

function MenuMirrored(const AContext: IFmrPopupContext): Boolean;
begin
  // Popups of a right-to-left ribbon: their context implements IFmrMirroredHost (FMR.Ribbon.BiDi).
  Result := FmrIsMirrored(AContext);
end;

/// Right-to-left placement: drop-downs align their right edges with the anchor, submenus open to the left.
function MirrorPlacement(const ARect, AAnchor: TRectF; const APlacement: TFmrPopupPlacement): TRectF;
var
  Work: TRectF;
  X, W: Single;
begin
  Result := ARect;
  W := ARect.Width;
  Work := Screen.DisplayFromRect(AAnchor).WorkareaRect;
  if Work.IsEmpty then
    Work := Screen.WorkAreaRect;
  case APlacement of
    TFmrPopupPlacement.Right:
      begin
        X := AAnchor.Left - W;
        if (X < Work.Left) and (AAnchor.Right + W <= Work.Right) then
          X := AAnchor.Right;
      end;
    TFmrPopupPlacement.AtPoint:
      begin
        X := AAnchor.Left - W;
        if X < Work.Left then
          X := AAnchor.Left;
      end;
    TFmrPopupPlacement.BelowEnd:
      X := AAnchor.Left;
  else
    X := AAnchor.Right - W;
  end;
  X := EnsureRange(X, Work.Left, Max(Work.Left, Work.Right - W));
  Result := RectF(X, ARect.Top, X + W, ARect.Bottom);
end;

var
  GPopups: TFmrPopupManager;
  GDropDowns: TList<TPair<TFmrBarItemClass, TFmrDropDownFactory>>;

const
  PopupShadowSize = 8;

function FmrPopups: TFmrPopupManager;
begin
  if GPopups = nil then
    GPopups := TFmrPopupManager.Create;
  Result := GPopups;
end;

function FmrPopupsAssigned: Boolean;
begin
  Result := GPopups <> nil;
end;

function FmrFormOf(const AObject: TFmxObject): TCommonCustomForm;
var
  O: TFmxObject;
begin
  O := AObject;
  while (O <> nil) and not (O is TCommonCustomForm) do
    O := O.Parent;
  Result := TCommonCustomForm(O);
end;

procedure FmrRegisterDropDown(const AItemClass: TFmrBarItemClass; const AFactory: TFmrDropDownFactory);
var
  I: Integer;
begin
  for I := 0 to GDropDowns.Count - 1 do
    if GDropDowns[I].Key = AItemClass then
    begin
      GDropDowns[I] := TPair<TFmrBarItemClass, TFmrDropDownFactory>.Create(AItemClass, AFactory);
      Exit;
    end;
  GDropDowns.Add(TPair<TFmrBarItemClass, TFmrDropDownFactory>.Create(AItemClass, AFactory));
end;

function FindDropDownFactory(const AItem: TFmrBarItem; out AFactory: TFmrDropDownFactory): Boolean;
var
  C: TClass;
  I: Integer;
begin
  C := AItem.ClassType;
  while (C <> nil) and C.InheritsFrom(TFmrBarItem) do
  begin
    for I := 0 to GDropDowns.Count - 1 do
      if GDropDowns[I].Key = C then
      begin
        AFactory := GDropDowns[I].Value;
        Exit(True);
      end;
    C := C.ClassParent;
  end;
  Result := False;
end;

function FmrItemHasDropDown(const AItem: TFmrBarItem): Boolean;
begin
  Result := (AItem is TFmrSubItem) or (AItem is TFmrGalleryItem) or
    ((AItem is TFmrButtonItem) and TFmrButtonItem(AItem).HasDropDown);
end;

function FmrCreateDropDownContent(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
var
  Factory: TFmrDropDownFactory;
  Links: TFmrItemLinks;
begin
  Result := nil;
  if AItem = nil then
    Exit;
  if AItem is TFmrButtonItem then
    TFmrButtonItem(AItem).DropDown
  else if AItem is TFmrSubItem then
    TFmrSubItem(AItem).Popup;
  if FindDropDownFactory(AItem, Factory) then
  begin
    Result := Factory(AItem, AContext);
    if Result <> nil then
      Exit;
  end;
  Links := nil;
  if AItem is TFmrButtonItem then
    Links := TFmrButtonItem(AItem).DropDownLinks
  else if AItem is TFmrSubItem then
    Links := TFmrSubItem(AItem).ItemLinks
  else if AItem is TFmrGalleryItem then
    Links := TFmrGalleryItem(AItem).DropDownLinks;
  if (Links <> nil) and (Links.VisibleCount > 0) then
    Result := TFmrMenuControl.CreateMenu(AContext, Links);
end;

{ TFmrPopupContext }

constructor TFmrPopupContext.Create(const APainter: TFmrRibbonPainter; const AImages: TCustomImageList;
  const AOwnerForm: TCommonCustomForm);
begin
  inherited Create;
  FPainter := APainter;
  FImages := AImages;
  FOwnerForm := AOwnerForm;
end;

function TFmrPopupContext.GetImages: TCustomImageList;
begin
  Result := FImages;
end;

function TFmrPopupContext.GetKeyTipsActive: Boolean;
begin
  Result := FKeyTips;
end;

function TFmrPopupContext.GetOwnerForm: TCommonCustomForm;
begin
  Result := FOwnerForm;
end;

function TFmrPopupContext.GetPainter: TFmrRibbonPainter;
begin
  Result := FPainter;
end;

function TFmrPopupContext.ItemContextPopup(const AItem: TFmrBarItem; const AScreenPoint: TPointF): Boolean;
begin
  Result := False;
end;

procedure TFmrPopupContext.ItemExecuting(const AItem: TFmrBarItem);
begin
end;

procedure TFmrPopupContext.SetKeyTipsActive(const AValue: Boolean);
begin
  FKeyTips := AValue;
end;

{ TFmrPopupFrame }

procedure TFmrPopupFrame.Paint;
var
  R: TRectF;
  Painter: TFmrRibbonPainter;
  C: IFmrPopupContent;
begin
  if (FPopup = nil) or (FPopup.FContext = nil) then
    Exit;
  Painter := FPopup.FContext.Painter;
  R := LocalRect;
  R.Inflate(-FPopup.FShadow, -FPopup.FShadow);
  R.Bottom := R.Bottom - 2;
  Painter.DrawShadow(Canvas, R, Painter.Metrics.MenuRadius, FPopup.FShadow - 1);
  C := FPopup.ContentIntf;
  if (C = nil) or not C.PaintsOwnBackground then
    Painter.DrawPopupBackground(Canvas, R);
end;

{ TFmrPopupForm }

constructor TFmrPopupForm.CreatePopup(const AContext: IFmrPopupContext; const AContent: TControl);
begin
  inherited CreateNew(nil);
  FContext := AContext;
  FShadow := PopupShadowSize;
  FCaptureKeyboard := True;
  FOwnedObjects := TObjectList<TObject>.Create(True);
  BeginUpdate;
  try
    FormStyle := TFormStyle.Popup;
    BorderStyle := TFmxFormBorderStyle.None;
    Position := TFormPosition.Designed;
    Fill.Kind := TBrushKind.None;
    Transparency := True;
    Visible := False;
    FFrame := TFmrPopupFrame.Create(Self);
    FFrame.FPopup := Self;
    FFrame.Align := TAlignLayout.Contents;
    FFrame.HitTest := False;
    FFrame.Parent := Self;
    FContent := AContent;
    if FContent <> nil then
      FContent.Parent := FFrame;
  finally
    EndUpdate;
  end;
end;

destructor TFmrPopupForm.Destroy;
begin
  // Destroyed while open (its owner form is going away): closing returns borrowed controls to their owners.
  if not FClosed and (GPopups <> nil) then
    GPopups.PopupClosing(Self);
  if FContent <> nil then
  begin
    FContent.Free;
    FContent := nil;
  end;
  inherited;
  FreeAndNil(FOwnedObjects);
  FContext := nil;
end;

function TFmrPopupForm.ContentIntf: IFmrPopupContent;
begin
  if (FContent = nil) or not Supports(FContent, IFmrPopupContent, Result) then
    Result := nil;
end;

procedure TFmrPopupForm.OwnObject(const AObject: TObject);
begin
  FOwnedObjects.Add(AObject);
end;

procedure TFmrPopupForm.ReleaseContent;
var
  C: TControl;
begin
  C := FContent;
  FContent := nil;
  if C <> nil then
    C.Parent := nil;
end;

function TFmrPopupForm.ContentScreenRect: TRectF;
begin
  Result := RectF(Left + FShadow, Top + FShadow, Left + Width - FShadow, Top + Height - FShadow - 2);
end;

procedure TFmrPopupForm.DoClose(var CloseAction: TCloseAction);
begin
  inherited;
  CloseAction := TCloseAction.caHide;
  if not FClosed then
    FmrPopups.PopupClosing(Self);
end;

{ TFmrPopupManager.TNotifier }

procedure TFmrPopupManager.TNotifier.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (FManager <> nil) then
    FManager.Forget(AComponent);
end;

{ TFmrPopupManager }

constructor TFmrPopupManager.Create;
begin
  inherited Create;
  FChain := TList<TFmrPopupForm>.Create;
  FGraveyard := TList<TFmrPopupForm>.Create;
  FHandlers := TList<IFmrKeyHandler>.Create;
  FNotifier := TNotifier.Create(nil);
  FNotifier.FManager := Self;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 250;
  FTimer.OnTimer := TimerProc;
end;

destructor TFmrPopupManager.Destroy;
var
  P: TFmrPopupForm;
begin
  FTimer.Enabled := False;
  FreeAndNil(FTimer);
  FHandlers.Clear;
  if FSink <> nil then
  begin
    FSink.FManager := nil;
    FSink.RemoveFreeNotification(FNotifier);
    FSink := nil;
  end;
  for P in FChain.ToArray + FGraveyard.ToArray do
  begin
    P.RemoveFreeNotification(FNotifier);
    P.FClosed := True;
  end;
  FChain.Clear;
  FGraveyard.Clear;
  FNotifier.FManager := nil;
  FreeAndNil(FNotifier);
  FreeAndNil(FChain);
  FreeAndNil(FGraveyard);
  FreeAndNil(FHandlers);
  inherited;
end;

procedure TFmrPopupManager.Forget(const AComponent: TComponent);
begin
  if AComponent is TFmrPopupForm then
  begin
    FChain.Remove(TFmrPopupForm(AComponent));
    FGraveyard.Remove(TFmrPopupForm(AComponent));
    UpdateSink;
  end;
  if AComponent = FSink then
  begin
    FSink := nil;
    FSinkForm := nil;
  end;
  if AComponent = FSavedFocus then
    FSavedFocus := nil;
  if AComponent = FSinkForm then
  begin
    FSinkForm := nil;
    FSink := nil;
  end;
end;

class function TFmrPopupManager.PlaceRect(const AAnchor: TRectF; const ASize: TSizeF;
  const APlacement: TFmrPopupPlacement): TRectF;
var
  Work: TRectF;
  X, Y, W, H: Single;
begin
  Work := Screen.DisplayFromRect(AAnchor).WorkareaRect;
  if Work.IsEmpty then
    Work := Screen.WorkAreaRect;
  W := Min(ASize.Width, Work.Width);
  H := Min(ASize.Height, Work.Height);
  case APlacement of
    TFmrPopupPlacement.Right:
      begin
        X := AAnchor.Right;
        Y := AAnchor.Top;
        if (X + W > Work.Right) and (AAnchor.Left - W >= Work.Left) then
          X := AAnchor.Left - W;
        if Y + H > Work.Bottom then
          Y := Work.Bottom - H;
      end;
    TFmrPopupPlacement.AtPoint:
      begin
        X := AAnchor.Left;
        Y := AAnchor.Top;
        if (X + W > Work.Right) and (X - W >= Work.Left) then
          X := X - W;
        if (Y + H > Work.Bottom) and (Y - H >= Work.Top) then
          Y := Y - H;
      end;
    TFmrPopupPlacement.Above:
      begin
        X := AAnchor.Left;
        Y := AAnchor.Top - H;
        if (Y < Work.Top) and (AAnchor.Bottom + H <= Work.Bottom) then
          Y := AAnchor.Bottom;
      end;
  else
    begin
      if APlacement = TFmrPopupPlacement.BelowEnd then
        X := AAnchor.Right - W
      else
        X := AAnchor.Left;
      Y := AAnchor.Bottom;
      if (Y + H > Work.Bottom) and (AAnchor.Top - H >= Work.Top) then
        Y := AAnchor.Top - H;
    end;
  end;
  X := EnsureRange(X, Work.Left, Max(Work.Left, Work.Right - W));
  Y := EnsureRange(Y, Work.Top, Max(Work.Top, Work.Bottom - H));
  Result := RectF(X, Y, X + W, Y + H);
end;

procedure TFmrPopupManager.Show(const APopup: TFmrPopupForm; const AAnchor: TRectF;
  const APlacement: TFmrPopupPlacement; const AParent: TFmrPopupForm; const AByKeyboard: Boolean);
var
  Size: TSizeF;
  R: TRectF;
  C: IFmrPopupContent;
  OwnerForm: TCommonCustomForm;
begin
  if APopup = nil then
    Exit;
  if AParent = nil then
    CloseAll
  else
    CloseChildrenOf(AParent);
  C := APopup.ContentIntf;
  if C <> nil then
    Size := C.GetPopupSize
  else if APopup.Content <> nil then
    Size := TSizeF.Create(APopup.Content.Width, APopup.Content.Height)
  else
    Size := TSizeF.Create(100, 100);
  R := PlaceRect(AAnchor, Size, APlacement);
  if (APopup.Context <> nil) and MenuMirrored(APopup.Context) then
    R := MirrorPlacement(R, AAnchor, APlacement);
  APopup.FAnchor := AAnchor;
  APopup.FByKeyboard := AByKeyboard;
  APopup.FParentPopup := AParent;
  if AParent <> nil then
    APopup.Parent := AParent
  else
  begin
    OwnerForm := nil;
    if APopup.Context <> nil then
      OwnerForm := APopup.Context.OwnerForm;
    if OwnerForm <> nil then
      APopup.Parent := OwnerForm;
  end;
  if APopup.Content <> nil then
  begin
    APopup.Content.Align := TAlignLayout.None;
    APopup.Content.SetBounds(APopup.FShadow + 1, APopup.FShadow + 1, R.Width - 2, R.Height - 2);
  end;
  APopup.SetBoundsF(R.Left - APopup.FShadow, R.Top - APopup.FShadow, R.Width + 2 * APopup.FShadow,
    R.Height + 2 * APopup.FShadow + 2);
  APopup.FreeNotification(FNotifier);
  FChain.Add(APopup);
  APopup.Show;
  UpdateSink;
  if C <> nil then
    C.PopupShown(AByKeyboard);
end;

procedure TFmrPopupManager.PopupClosing(const APopup: TFmrPopupForm);
var
  I: Integer;
  Child: TFmrPopupForm;
  C: IFmrPopupContent;
  Proc: TProc;
begin
  if APopup.FClosed then
    Exit;
  APopup.FClosed := True;
  // Descendants first (FMX may close them in any order).
  for I := FChain.Count - 1 downto 0 do
    if I < FChain.Count then
    begin
      Child := FChain[I];
      if Child.FParentPopup = APopup then
        Close(Child);
    end;
  FChain.Remove(APopup);
  C := APopup.ContentIntf;
  if C <> nil then
    C.PopupClosed;
  Proc := APopup.FOnClosed;
  APopup.FOnClosed := nil;
  if Assigned(Proc) then
    Proc();
  if not (csDestroying in APopup.ComponentState) then
    Bury(APopup)
  else
    FGraveyard.Remove(APopup);
  UpdateSink;
end;

procedure TFmrPopupManager.Bury(const APopup: TFmrPopupForm);
begin
  APopup.FCloseTime := Now;
  if not FGraveyard.Contains(APopup) then
    FGraveyard.Add(APopup);
  FTimer.Enabled := True;
end;

procedure TFmrPopupManager.TimerProc(Sender: TObject);
var
  P: TFmrPopupForm;
  Busy: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Busy := (GetAsyncKeyState(VK_LBUTTON) < 0) or (GetAsyncKeyState(VK_RBUTTON) < 0) or
    (GetAsyncKeyState(VK_MBUTTON) < 0);
  {$ELSE}
  Busy := False;
  {$ENDIF}
  if Busy then
    Exit;
  for P in FGraveyard.ToArray do
    if (Now - P.FCloseTime) * SecsPerDay > 0.2 then
    begin
      FGraveyard.Remove(P);
      P.RemoveFreeNotification(FNotifier);
      P.Free;
    end;
  FTimer.Enabled := FGraveyard.Count > 0;
end;

procedure TFmrPopupManager.Close(const APopup: TFmrPopupForm);
begin
  if (APopup = nil) or APopup.FClosed then
    Exit;
  if APopup.Visible then
    APopup.Close;
  // Close does not reach DoClose when the window is not visible.
  if not APopup.FClosed then
    PopupClosing(APopup);
end;

procedure TFmrPopupManager.CloseChildrenOf(const APopup: TFmrPopupForm);
var
  I: Integer;
begin
  for I := FChain.Count - 1 downto 0 do
    if (I < FChain.Count) and (FChain[I].FParentPopup = APopup) then
      Close(FChain[I]);
end;

procedure TFmrPopupManager.CloseAll;
begin
  if FClosingAll then
    Exit;
  FClosingAll := True;
  try
    while FChain.Count > 0 do
      Close(FChain[0]);
  finally
    FClosingAll := False;
  end;
end;

function TFmrPopupManager.IsOpen: Boolean;
begin
  Result := FChain.Count > 0;
end;

function TFmrPopupManager.Top: TFmrPopupForm;
begin
  if FChain.Count > 0 then
    Result := FChain.Last
  else
    Result := nil;
end;

function TFmrPopupManager.Contains(const APopup: TFmrPopupForm): Boolean;
begin
  Result := FChain.Contains(APopup);
end;

function TFmrPopupManager.PopupOf(const AObject: TFmxObject): TFmrPopupForm;
var
  F: TCommonCustomForm;
begin
  F := FmrFormOf(AObject);
  if (F is TFmrPopupForm) and FChain.Contains(TFmrPopupForm(F)) then
    Result := TFmrPopupForm(F)
  else
    Result := nil;
end;

function TFmrPopupManager.KeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  P: TFmrPopupForm;
  C: IFmrPopupContent;
  Focused: IControl;
begin
  Result := False;
  P := Top;
  if P = nil then
    Exit;
  // Alt (menu key) closes every popup, like Windows menus.
  if (Key = vkMenu) then
  begin
    CloseAll;
    Exit(True);
  end;
  C := P.ContentIntf;
  // An editor focused inside the popup gets the keys first (except Escape).
  Focused := P.Focused;
  if (Focused <> nil) and (Key <> vkEscape) then
  begin
    if (C <> nil) and C.PopupKeyDown(Key, KeyChar, Shift) then
      Exit(True);
    P.KeyDown(Key, KeyChar, Shift);
    Exit(True);
  end;
  if (C <> nil) and C.PopupKeyDown(Key, KeyChar, Shift) then
    Exit(True);
  if Key = vkEscape then
  begin
    Close(P);
    Exit(True);
  end;
  // Every other key is swallowed while a capturing popup is open.
  Result := P.CaptureKeyboard;
end;

procedure TFmrPopupManager.AddKeyHandler(const AForm: TCommonCustomForm; const AHandler: IFmrKeyHandler);
begin
  if (AHandler = nil) or FHandlers.Contains(AHandler) then
    Exit;
  FHandlers.Add(AHandler);
  if (FSinkForm <> nil) and (FSinkForm <> AForm) then
    RemoveSink(True);
  FSinkForm := AForm;
  if AForm <> nil then
    AForm.FreeNotification(FNotifier);
  UpdateSink;
end;

procedure TFmrPopupManager.RemoveKeyHandler(const AHandler: IFmrKeyHandler);
begin
  if FHandlers.Remove(AHandler) >= 0 then
    UpdateSink;
end;

function TFmrPopupManager.HasKeyHandler(const AHandler: IFmrKeyHandler): Boolean;
begin
  Result := FHandlers.Contains(AHandler);
end;

function TFmrPopupManager.NeedsSink(out AForm: TCommonCustomForm): Boolean;
var
  P: TFmrPopupForm;
begin
  AForm := nil;
  for P in FChain do
    if P.CaptureKeyboard and (P.Context <> nil) and (P.Context.OwnerForm <> nil) then
    begin
      AForm := P.Context.OwnerForm;
      Exit(True);
    end;
  if (FHandlers.Count > 0) and (FSinkForm <> nil) then
  begin
    AForm := FSinkForm;
    Exit(True);
  end;
  Result := False;
end;

procedure TFmrPopupManager.UpdateSink;
var
  Form: TCommonCustomForm;
  Focused: IControl;
begin
  if FUpdatingSink then
    Exit;
  FUpdatingSink := True;
  try
    if not NeedsSink(Form) or (csDestroying in Form.ComponentState) then
    begin
      RemoveSink(True);
      Exit;
    end;
    if (FSink <> nil) and (FSink.Parent = Form) then
      Exit;
    RemoveSink(True);
    FSinkForm := Form;
    Form.FreeNotification(FNotifier);
    Focused := Form.Focused;
    FSavedFocus := nil;
    if (Focused <> nil) and (Focused.GetObject is TControl) then
    begin
      FSavedFocus := TControl(Focused.GetObject);
      FSavedFocus.FreeNotification(FNotifier);
    end;
    FSink := TFmrKeySink.Create(nil);
    FSink.FManager := Self;
    FSink.FreeNotification(FNotifier);
    FSink.Parent := Form;
    try
      FSink.SetFocus;
    except
      // A form that cannot focus (closing): keys are not captured.
    end;
  finally
    FUpdatingSink := False;
  end;
end;

procedure TFmrPopupManager.RemoveSink(const ARestoreFocus: Boolean);
var
  Sink: TFmrKeySink;
  Saved: TControl;
begin
  if FSink = nil then
    Exit;
  Sink := FSink;
  FSink := nil;
  Saved := FSavedFocus;
  FSavedFocus := nil;
  Sink.FReleasing := True;
  Sink.FManager := nil;
  Sink.RemoveFreeNotification(FNotifier);
  if Saved <> nil then
    Saved.RemoveFreeNotification(FNotifier);
  try
    if ARestoreFocus and Sink.IsFocused and (Saved <> nil) and not (csDestroying in Saved.ComponentState) and
      Saved.CanFocus and Saved.ParentedVisible then
      Saved.SetFocus
    else if Sink.IsFocused and (Sink.Root <> nil) then
      Sink.Root.SetFocused(nil);
  except
  end;
  Sink.Parent := nil;
  TThread.ForceQueue(nil,
    procedure
    begin
      Sink.Free;
    end);
end;

procedure TFmrPopupManager.SinkLostFocus;
var
  H: IFmrKeyHandler;
  Handlers: TArray<IFmrKeyHandler>;
begin
  // The user moved the focus (clicked an editor): popups close, handlers are told.
  RemoveSink(False);
  CloseAll;
  Handlers := FHandlers.ToArray;
  FHandlers.Clear;
  for H in Handlers do
    H.KeyboardLost;
end;

function TFmrPopupManager.SinkKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  I: Integer;
  P: TFmrPopupForm;
begin
  P := Top;
  if P <> nil then
  begin
    Result := KeyDown(Key, KeyChar, Shift);
    if Result then
      Exit;
  end;
  for I := FHandlers.Count - 1 downto 0 do
    if (I < FHandlers.Count) and FHandlers[I].HandleKey(Key, KeyChar, Shift) then
      Exit(True);
  Result := True;
end;

function TFmrPopupManager.SinkKeyUp(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  P: TFmrPopupForm;
begin
  P := Top;
  Result := (P <> nil) and (P.Focused <> nil);
  if Result then
    P.KeyUp(Key, KeyChar, Shift);
end;

{ TFmrKeySink }

constructor TFmrKeySink.Create(AOwner: TComponent);
begin
  inherited;
  CanFocus := True;
  TabStop := False;
  HitTest := False;
  Stored := False;
  Opacity := 0;
  SetBounds(-10, -10, 1, 1);
end;

procedure TFmrKeySink.DialogKey(var Key: Word; Shift: TShiftState);
var
  Ch: WideChar;
begin
  if (FManager = nil) or FReleasing then
    Exit;
  Ch := #0;
  if FManager.SinkKey(Key, Ch, Shift) then
    Key := 0;
end;

procedure TFmrKeySink.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (FManager = nil) or FReleasing then
    Exit;
  if FManager.SinkKey(Key, KeyChar, Shift) then
  begin
    Key := 0;
    KeyChar := #0;
  end;
end;

procedure TFmrKeySink.KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (FManager <> nil) and not FReleasing then
    FManager.SinkKeyUp(Key, KeyChar, Shift);
end;

procedure TFmrKeySink.DoExit;
begin
  inherited;
  if (FManager <> nil) and not FReleasing then
    TThread.ForceQueue(nil,
      procedure
      begin
        if (GPopups <> nil) and (GPopups.FSink = Self) and not FReleasing and not IsFocused then
          GPopups.SinkLostFocus;
      end);
end;

{ TFmrCommandItem }

procedure TFmrCommandItem.DoClick;
begin
  if ButtonStyle = TFmrButtonStyle.Check then
    Down := not Down;
  if Assigned(FOnExecute) then
    FOnExecute()
  else
    inherited;
end;

{ TFmrTempMenu }

constructor TFmrTempMenu.Create;
begin
  inherited Create;
  FLinks := TFmrItemLinks.Create(Self);
  FItems := TObjectList<TFmrBarItem>.Create(True);
end;

destructor TFmrTempMenu.Destroy;
begin
  FreeAndNil(FLinks);
  FreeAndNil(FItems);
  inherited;
end;

function TFmrTempMenu.AddCommand(const ACaption: string; const AExecute: TProc; const AChecked, ABeginGroup,
  AEnabled: Boolean): TFmrCommandItem;
begin
  Result := TFmrCommandItem.Create(nil);
  FItems.Add(Result);
  Result.Caption := ACaption;
  Result.OnExecute := AExecute;
  Result.Enabled := AEnabled;
  if AChecked then
  begin
    Result.ButtonStyle := TFmrButtonStyle.Check;
    Result.Down := True;
  end;
  FLinks.AddItem(Result, ABeginGroup);
end;

function TFmrTempMenu.AddHeader(const ACaption: string): TFmrSeparatorItem;
begin
  Result := TFmrSeparatorItem.Create(nil);
  FItems.Add(Result);
  Result.Caption := ACaption;
  FLinks.AddItem(Result);
end;

function TFmrTempMenu.AddLink(const AItem: TFmrBarItem; const ABeginGroup: Boolean): TFmrItemLink;
begin
  Result := FLinks.AddItem(AItem, ABeginGroup);
end;

{ TFmrMenuRow }

function TFmrMenuRow.Caption: string;
begin
  if FLink <> nil then
    Result := FmrStripAccel(FLink.Caption)
  else
    Result := '';
end;

function TFmrMenuRow.IsEnabled: Boolean;
begin
  Result := (FKind = TFmrMenuRowKind.Item) and (FItem <> nil) and FItem.Enabled;
end;

function TFmrMenuRow.IsChecked: Boolean;
begin
  Result := (FItem <> nil) and FItem.IsChecked;
end;

function TFmrMenuRow.IsSelectable: Boolean;
begin
  Result := FKind = TFmrMenuRowKind.Item;
end;

function TFmrMenuRow.HasSubMenu: Boolean;
begin
  Result := (FKind = TFmrMenuRowKind.Item) and FmrItemHasDropDown(FItem);
end;

function TFmrMenuRow.IsSplit: Boolean;
begin
  Result := (FItem is TFmrButtonItem) and (TFmrButtonItem(FItem).ButtonStyle = TFmrButtonStyle.Split);
end;

function TFmrMenuRow.ArrowRect: TRectF;
begin
  Result := Bounds;
  Result.Left := Result.Right - 24;
end;

function TFmrMenuRow.PartAt(const P: TPointF): TFmrElementPart;
begin
  if not Bounds.Contains(P) or not IsSelectable then
    Exit(TFmrElementPart.None);
  if HasSubMenu and (not IsSplit or ArrowRect.Contains(P)) then
    Result := TFmrElementPart.DropDown
  else
    Result := TFmrElementPart.Main;
end;

function TFmrMenuRow.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := APart = TFmrElementPart.DropDown;
end;

procedure TFmrMenuRow.Execute(const APart: TFmrElementPart);
begin
  if APart = TFmrElementPart.DropDown then
    FMenu.OpenSubMenu(Self, False)
  else
    FMenu.ExecuteRow(Self);
end;

function TFmrMenuRow.PartState(const APart: TFmrElementPart): TFmrPartState;
begin
  if (FMenu.FSubRow = Self) then
    Exit(TFmrPartState.Hot);
  if HotPart <> TFmrElementPart.None then
  begin
    if IsSplit and (HotPart <> APart) then
      Result := TFmrPartState.Normal
    else
      Result := TFmrPartState.Hot;
  end
  else
    Result := TFmrPartState.Normal;
end;

procedure TFmrMenuRow.Paint(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  R, Gutter, GlyphR, TextR, ArrowR: TRectF;
  G: TFmrImageSource;
  TextColor, DimColor: TAlphaColor;
  Shortcut, Desc: string;
  ShortW, ArrowW, CapH: Single;
  S: TFmrPartState;
  Enabled: Boolean;
begin
  P := FMenu.GetPainter;
  M := P.Metrics;
  R := Bounds;
  case FKind of
    TFmrMenuRowKind.Separator:
      begin
        if FLarge then
          P.DrawMenuSeparator(ACanvas, R, 0)
        else
          P.DrawMenuSeparator(ACanvas, R, FMenu.FGutter);
        Exit;
      end;
    TFmrMenuRowKind.Header:
      begin
        P.DrawMenuHeader(ACanvas, RectF(R.Left + 1, R.Top, R.Right - 1, R.Bottom), Caption);
        Exit;
      end;
  end;
  Enabled := IsEnabled or (FKind = TFmrMenuRowKind.Static);
  if Enabled and (FKind <> TFmrMenuRowKind.Static) then
    TextColor := P.Theme.Colors[TFmrToken.MenuItemText]
  else if FKind = TFmrMenuRowKind.Static then
    TextColor := P.Theme.Colors[TFmrToken.MenuShortcutText]
  else
    TextColor := P.Theme.Colors[TFmrToken.MenuItemTextDisabled];
  DimColor := P.Theme.Colors[TFmrToken.MenuShortcutText];
  if FKind = TFmrMenuRowKind.Item then
  begin
    if IsSplit then
    begin
      S := PartState(TFmrElementPart.Main);
      if S = TFmrPartState.Hot then
        P.DrawMenuItem(ACanvas, RectF(R.Left, R.Top, ArrowRect.Left, R.Bottom), S);
      S := PartState(TFmrElementPart.DropDown);
      if S = TFmrPartState.Hot then
        P.DrawMenuItem(ACanvas, ArrowRect, S);
      if HotPart <> TFmrElementPart.None then
        P.Line(ACanvas, PointF(Round(ArrowRect.Left) + 0.5, R.Top + 4), PointF(Round(ArrowRect.Left) + 0.5,
          R.Bottom - 4), P.Theme.Colors[TFmrToken.MenuSeparator]);
    end
    else
      P.DrawMenuItem(ACanvas, R, PartState(TFmrElementPart.Main));
  end;
  Gutter := RectF(R.Left, R.Top, R.Left + FMenu.FGutter, R.Bottom);
  G := nil;
  if FItem <> nil then
  begin
    if FLarge and not FItem.LargeGlyph.IsEmpty(FMenu.GetImages) then
      G := FItem.LargeGlyph
    else if not FItem.Glyph.IsEmpty(FMenu.GetImages) then
      G := FItem.Glyph
    else if not FItem.LargeGlyph.IsEmpty(FMenu.GetImages) then
      G := FItem.LargeGlyph;
  end;
  if IsChecked then
  begin
    GlyphR := RectF(0, 0, Min(Gutter.Width - 6, R.Height - 4), Min(Gutter.Width - 6, R.Height - 4));
    if not FLarge then
      GlyphR := RectF(0, 0, Min(22, R.Height - 4), Min(22, R.Height - 4));
    P.DrawMenuCheckBackground(ACanvas, GlyphR.CenterAt(Gutter));
    if G = nil then
      P.DrawCheckMark(ACanvas, Gutter, TextColor, ((FItem is TFmrButtonItem) and
        (TFmrButtonItem(FItem).GroupIndex <> 0)) or ((FItem is TFmrCheckItem) and
        (TFmrCheckItem(FItem).GroupIndex <> 0)));
  end;
  if G <> nil then
  begin
    if FLarge then
      GlyphR := RectF(0, 0, M.LargeGlyphSize, M.LargeGlyphSize)
    else
      GlyphR := RectF(0, 0, M.SmallGlyphSize, M.SmallGlyphSize);
    GlyphR := GlyphR.CenterAt(Gutter);
    GlyphR := RectF(Round(GlyphR.Left), Round(GlyphR.Top), Round(GlyphR.Left) + GlyphR.Width,
      Round(GlyphR.Top) + GlyphR.Height);
    if Enabled then
      FmrDrawImage(ACanvas, G, GlyphR, 1, P.GlyphTint(TFmrPartState.Normal), FMenu.GetImages)
    else
      FmrDrawImage(ACanvas, G, GlyphR, 0.45, P.GlyphTint(TFmrPartState.Disabled), FMenu.GetImages);
    if FItem is TFmrColorItem then
    begin
      if TFmrColorItem(FItem).Color = TAlphaColors.Null then
        P.DrawColorBar(ACanvas, RectF(GlyphR.Left, GlyphR.Bottom - 3, GlyphR.Right, GlyphR.Bottom + 1),
          TFmrColorItem(FItem).AutomaticColor)
      else
        P.DrawColorBar(ACanvas, RectF(GlyphR.Left, GlyphR.Bottom - 3, GlyphR.Right, GlyphR.Bottom + 1),
          TFmrColorItem(FItem).Color);
    end;
  end;
  if HasSubMenu then
    ArrowW := 24
  else
    ArrowW := 8;
  Shortcut := '';
  if (FItem <> nil) and (FItem.ShortCut <> 0) then
    Shortcut := FmrShortCutText(FItem.ShortCut);
  ShortW := 0;
  if Shortcut <> '' then
    ShortW := P.TextWidth(Shortcut) + 20;
  TextR := RectF(Gutter.Right + 8, R.Top, R.Right - ArrowW - ShortW, R.Bottom);
  if FLarge then
  begin
    CapH := P.TextSize('Wg', 0, True).Height;
    Desc := '';
    if FItem <> nil then
      Desc := FItem.Description;
    if Desc <> '' then
    begin
      P.TextEx(ACanvas, RectF(TextR.Left, R.Top + 5, TextR.Right, R.Top + 5 + CapH), Caption, TextColor,
        TTextAlign.Leading, TTextAlign.Leading, 0, True, False);
      P.TextEx(ACanvas, RectF(TextR.Left, R.Top + 5 + CapH + 1, TextR.Right, R.Bottom - 3), Desc, DimColor,
        TTextAlign.Leading, TTextAlign.Leading, 0, False, True);
    end
    else
      P.TextEx(ACanvas, TextR, Caption, TextColor, TTextAlign.Leading, TTextAlign.Center, 0, True, False);
  end
  else
    P.TextEx(ACanvas, TextR, Caption, TextColor, TTextAlign.Leading, TTextAlign.Center, 0, False, False);
  if Shortcut <> '' then
    P.Text(ACanvas, RectF(R.Right - ArrowW - ShortW, R.Top, R.Right - ArrowW, R.Bottom), Shortcut, DimColor,
      TTextAlign.Trailing, TTextAlign.Center);
  if HasSubMenu then
  begin
    ArrowR := ArrowRect;
    if Enabled then
      P.Arrow(ACanvas, PointF(ArrowR.CenterPoint.X, R.CenterPoint.Y), TFmrArrowDirection.Right, TextColor)
    else
      P.Arrow(ACanvas, PointF(ArrowR.CenterPoint.X, R.CenterPoint.Y), TFmrArrowDirection.Right,
        P.Theme.Colors[TFmrToken.MenuItemTextDisabled]);
  end;
end;

function TFmrMenuRow.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := Default(TFmrScreenTipInfo);
  Result := False;
  if (FItem = nil) or (FKind <> TFmrMenuRowKind.Item) then
    Exit;
  if FItem.ScreenTip.IsEmpty and (FItem.Hint = '') then
    Exit;
  AInfo.Header := FItem.ScreenTip.Header;
  if AInfo.Header = '' then
    AInfo.Header := Caption;
  AInfo.Description := FItem.ScreenTip.Description;
  if AInfo.Description = '' then
    AInfo.Description := FItem.Hint;
  AInfo.Footer := FItem.ScreenTip.Footer;
  AInfo.Disabled := not FItem.Enabled;
  Result := True;
end;

function TFmrMenuRow.KeyTipCaption: string;
begin
  if FLink <> nil then
    Result := FLink.Caption
  else
    Result := '';
end;

function TFmrMenuRow.ExplicitKeyTip: string;
begin
  if FLink <> nil then
    Result := FLink.EffectiveKeyTip
  else
    Result := '';
end;

function TFmrMenuRow.KeyTipAnchor: TPointF;
begin
  Result := PointF(Bounds.Left + FMenu.FGutter / 2 + 2, Bounds.CenterPoint.Y);
end;

{ TFmrMenuControl }

constructor TFmrMenuControl.CreateMenu(const AContext: IFmrPopupContext; const ALinks: TFmrItemLinks;
  const AStyle: TFmrMenuItemStyle; const AMinWidth: Single);
begin
  inherited Create(nil);
  FContext := AContext;
  FLinks := ALinks;
  FStyle := AStyle;
  FMinWidth := AMinWidth;
  FRows := TObjectList<TFmrMenuRow>.Create(True);
  FKeyTipRows := TList<TFmrMenuRow>.Create;
  FMatcher := TFmrKeyTipMatcher.Create(nil);
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 350;
  FTimer.OnTimer := TimerProc;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
  Build;
end;

destructor TFmrMenuControl.Destroy;
begin
  if FSubPopup <> nil then
  begin
    FSubPopup.OnClosed := nil;
    if GPopups <> nil then
      GPopups.Close(FSubPopup);
    FSubPopup := nil;
  end;
  FSubRow := nil;
  FHot := nil;
  FPressed := nil;
  if Assigned(FmrMenuHotRowHook) then
    FmrMenuHotRowHook(Self, nil);
  FreeAndNil(FMatcher);
  FreeAndNil(FKeyTipRows);
  FreeAndNil(FRows);
  FreeAndNil(FOwned);
  FContext := nil;
  inherited;
end;

function TFmrMenuControl.MyPopup: TFmrPopupForm;
var
  F: TCommonCustomForm;
begin
  F := FmrFormOf(Self);
  if F is TFmrPopupForm then
    Result := TFmrPopupForm(F)
  else
    Result := nil;
end;

procedure TFmrMenuControl.Build;
var
  I: Integer;
  L: TFmrItemLink;
  Row: TFmrMenuRow;
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  W, H, TextW, Extra: Single;
  Desc, Shortcut: string;
  Last: TFmrMenuRow;
  AnyLarge: Boolean;
begin
  P := FContext.Painter;
  M := P.Metrics;
  FRows.Clear;
  // Large rows: explicitly, or automatically when an item has a large glyph and a description.
  AnyLarge := False;
  if FStyle = TFmrMenuItemStyle.Auto then
    for I := 0 to FLinks.Count - 1 do
    begin
      L := FLinks[I];
      if L.IsVisible and not (L.Item is TFmrSeparatorItem) and (L.Item.Description <> '') and
        not L.Item.LargeGlyph.IsEmpty(FContext.Images) then
      begin
        AnyLarge := True;
        Break;
      end;
    end;
  FLarge := (FStyle = TFmrMenuItemStyle.Large) or AnyLarge;
  if FLarge then
    FGutter := M.LargeGlyphSize + 16
  else
    FGutter := M.MenuGutterWidth;
  if M.MenuRadius > 0 then
    FPad := 4
  else
    FPad := 2;
  W := Max(FMinWidth - 2, 120);
  Last := nil;
  for I := 0 to FLinks.Count - 1 do
  begin
    L := FLinks[I];
    if not L.IsVisible then
      Continue;
    if L.BeginGroup and (Last <> nil) and (Last.FKind <> TFmrMenuRowKind.Separator) then
    begin
      Row := TFmrMenuRow.Create(Self);
      Row.FMenu := Self;
      Row.FKind := TFmrMenuRowKind.Separator;
      Row.Tag := 7;
      FRows.Add(Row);
      Last := Row;
    end;
    Row := TFmrMenuRow.Create(Self);
    Row.FMenu := Self;
    Row.FLink := L;
    Row.FItem := L.Item;
    Row.FLarge := FLarge;
    if L.Item is TFmrSeparatorItem then
    begin
      if L.Item.Caption <> '' then
      begin
        Row.FKind := TFmrMenuRowKind.Header;
        Row.Tag := Round(M.MenuItemHeight);
        W := Max(W, P.TextWidth(Row.Caption, 0, True) + 24);
      end
      else
      begin
        if (Last = nil) or (Last.FKind = TFmrMenuRowKind.Separator) then
        begin
          Row.Free;
          Continue;
        end;
        Row.FKind := TFmrMenuRowKind.Separator;
        Row.Tag := 7;
      end;
    end
    else
    begin
      if L.Item is TFmrStaticItem then
        Row.FKind := TFmrMenuRowKind.Static
      else
        Row.FKind := TFmrMenuRowKind.Item;
      Shortcut := FmrShortCutText(L.Item.ShortCut);
      Extra := 8;
      if FmrItemHasDropDown(L.Item) then
        Extra := 24;
      if Shortcut <> '' then
        Extra := Extra + P.TextWidth(Shortcut) + 20;
      if FLarge then
      begin
        TextW := P.TextWidth(Row.Caption, 0, True);
        Desc := L.Item.Description;
        H := M.LargeGlyphSize + 12;
        if Desc <> '' then
        begin
          TextW := Max(TextW, Min(260, P.TextWidth(Desc)));
          H := Max(H, 5 + P.TextSize('Wg', 0, True).Height + 1 + P.TextSize(Desc, 0, False, 260, True).Height + 6);
        end;
        Row.Tag := Ceil(H);
      end
      else
      begin
        TextW := P.TextWidth(Row.Caption);
        Row.Tag := Round(M.MenuItemHeight);
      end;
      W := Max(W, FGutter + 8 + TextW + Extra + 4);
    end;
    FRows.Add(Row);
    Last := Row;
  end;
  // No trailing separator.
  while (FRows.Count > 0) and (FRows.Last.FKind = TFmrMenuRowKind.Separator) do
    FRows.Delete(FRows.Count - 1);
  FMenuWidth := Ceil(W);
  FContentHeight := 2 * FPad;
  for Row in FRows do
    FContentHeight := FContentHeight + Row.Tag;
  FMaxHeight := Screen.WorkAreaHeight - 2 * PopupShadowSize - 8;
  if FMaxHeight < 100 then
    FMaxHeight := FContentHeight;
  FScroll := 0;
  Arrange;
end;

procedure TFmrMenuControl.Arrange;
var
  Y: Single;
  Row: TFmrMenuRow;
begin
  Y := FPad - FScroll;
  for Row in FRows do
  begin
    Row.Bounds := RectF(1, Y, FMenuWidth - 1, Y + Row.Tag);
    Y := Y + Row.Tag;
  end;
end;

procedure TFmrMenuControl.SetScroll(const AValue: Single);
var
  V: Single;
begin
  V := EnsureRange(AValue, 0, Max(0, FContentHeight - Height));
  if V <> FScroll then
  begin
    FScroll := V;
    Arrange;
    Repaint;
  end;
end;

function TFmrMenuControl.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FMenuWidth + 2, Min(FContentHeight, FMaxHeight) + 2);
end;

function TFmrMenuControl.PaintsOwnBackground: Boolean;
begin
  Result := False;
end;

function TFmrMenuControl.GetPainter: TFmrRibbonPainter;
begin
  Result := FContext.Painter;
end;

function TFmrMenuControl.GetImages: TCustomImageList;
begin
  Result := FContext.Images;
end;

function TFmrMenuControl.GetHostControl: TControl;
begin
  Result := Self;
end;

procedure TFmrMenuControl.InvalidateElement(const AElement: TFmrElement);
begin
  if MenuMirrored(FContext) then
    InvalidateRect(FmrMirrorRect(AElement.Bounds, Width))
  else
    InvalidateRect(AElement.Bounds);
end;

procedure TFmrMenuControl.ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean);
begin
  if AElement is TFmrMenuRow then
    OpenSubMenu(TFmrMenuRow(AElement), AByKeyboard);
end;

procedure TFmrMenuControl.ElementExecuted(const AElement: TFmrElement);
begin
end;

function TFmrMenuControl.IsElementDroppedDown(const AElement: TFmrElement): Boolean;
begin
  Result := AElement = FSubRow;
end;

function TFmrMenuControl.RowAt(const P: TPointF): TFmrMenuRow;
var
  Row: TFmrMenuRow;
begin
  for Row in FRows do
    if Row.Bounds.Contains(P) then
      Exit(Row);
  Result := nil;
end;

procedure TFmrMenuControl.SetHot(const ARow: TFmrMenuRow; const APart: TFmrElementPart);
begin
  if (ARow = FHot) and (APart = FHotPart) then
    Exit;
  if FHot <> nil then
  begin
    FHot.HotPart := TFmrElementPart.None;
    InvalidateElement(FHot);
  end;
  FHot := ARow;
  FHotPart := APart;
  if FHot <> nil then
  begin
    FHot.HotPart := APart;
    InvalidateElement(FHot);
  end;
  if Assigned(FmrMenuHotRowHook) then
    FmrMenuHotRowHook(Self, FHot);
end;

procedure TFmrMenuControl.Paint;
var
  Row: TFmrMenuRow;
  Clip: TRectF;
  State: TCanvasSaveState;
  I: Integer;
  Tip: string;
  Sz: TSizeF;
  A: TPointF;
  P: TFmrRibbonPainter;
begin
  P := GetPainter;
  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(LocalRect);
    // Right to left: rows keep their left-to-right geometry, the canvas is flipped (gutter on the right).
    if MenuMirrored(FContext) then
      FmrMirrorCanvas(Canvas, Width);
    Clip := LocalRect;
    for Row in FRows do
      if Row.Bounds.IntersectsWith(Clip) then
        Row.Paint(Canvas);
    if FContext.KeyTipsActive and (FKeyTipRows.Count > 0) then
      for I := 0 to FKeyTipRows.Count - 1 do
      begin
        Row := FKeyTipRows[I];
        Tip := Row.KeyTip;
        if (Tip = '') or not FMatcher.IsCandidate(I) then
          Continue;
        Sz := P.KeyTipSize(Tip);
        A := Row.KeyTipAnchor;
        P.DrawKeyTip(Canvas, RectF(A.X - Sz.Width / 2, A.Y - Sz.Height / 2, A.X + Sz.Width / 2, A.Y + Sz.Height / 2),
          Tip, Row.IsEnabled);
      end;
    if FContentHeight > Height + 1 then
    begin
      if FScroll > 0 then
        P.Arrow(Canvas, PointF(Width / 2, 5), TFmrArrowDirection.Up, P.Theme.Colors[TFmrToken.MenuShortcutText]);
      if FScroll < FContentHeight - Height - 1 then
        P.Arrow(Canvas, PointF(Width / 2, Height - 5), TFmrArrowDirection.Down,
          P.Theme.Colors[TFmrToken.MenuShortcutText]);
    end;
  finally
    Canvas.RestoreState(State);
  end;
end;

procedure TFmrMenuControl.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Row: TFmrMenuRow;
  Part: TFmrElementPart;
begin
  inherited;
  if MenuMirrored(FContext) then
    X := Width - X;
  Row := RowAt(PointF(X, Y));
  if (Row <> nil) and not Row.IsSelectable then
    Row := nil;
  if Row <> nil then
    Part := Row.PartAt(PointF(X, Y))
  else
    Part := TFmrElementPart.None;
  if (Row = nil) and (FSubRow <> nil) then
    Exit;
  if (Row <> FHot) or (Part <> FHotPart) then
  begin
    SetHot(Row, Part);
    FTimer.Enabled := False;
    if ((Row <> nil) and Row.HasSubMenu and Row.IsEnabled and (Part = TFmrElementPart.DropDown) and
      (Row <> FSubRow)) or ((FSubRow <> nil) and (Row <> FSubRow)) then
      FTimer.Enabled := True;
  end;
end;

procedure TFmrMenuControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Row: TFmrMenuRow;
  Part: TFmrElementPart;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  if MenuMirrored(FContext) then
    X := Width - X;
  Row := RowAt(PointF(X, Y));
  if (Row = nil) or not Row.IsSelectable then
    Exit;
  Part := Row.PartAt(PointF(X, Y));
  SetHot(Row, Part);
  if Row.IsEnabled and Row.OpensOnPress(Part) then
  begin
    FTimer.Enabled := False;
    if FSubRow <> Row then
      OpenSubMenu(Row, False);
    FPressed := nil;
  end
  else
    FPressed := Row;
end;

procedure TFmrMenuControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Row: TFmrMenuRow;
  Part: TFmrElementPart;
  Pressed: TFmrMenuRow;
  PX: Single;
begin
  inherited;
  Pressed := FPressed;
  FPressed := nil;
  PX := X;
  if MenuMirrored(FContext) then
    X := Width - X;
  Row := RowAt(PointF(X, Y));
  if (Row = nil) or not Row.IsSelectable then
    Exit;
  Part := Row.PartAt(PointF(X, Y));
  if Button = TMouseButton.mbRight then
  begin
    if (Row.Item <> nil) and FContext.ItemContextPopup(Row.Item, LocalToScreen(PointF(PX, Y))) then
      Exit;
    Exit;
  end;
  if Button <> TMouseButton.mbLeft then
    Exit;
  if (Part = TFmrElementPart.Main) and Row.IsEnabled and ((Pressed = nil) or (Pressed = Row)) then
    ExecuteRow(Row);
end;

procedure TFmrMenuControl.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if FContentHeight > Height + 1 then
  begin
    SetScroll(FScroll - WheelDelta / 120 * GetPainter.Metrics.MenuItemHeight * 2);
    Handled := True;
  end;
end;

procedure TFmrMenuControl.DoMouseLeave;
begin
  inherited;
  if FSubRow = nil then
    SetHot(nil, TFmrElementPart.None)
  else
    SetHot(FSubRow, TFmrElementPart.DropDown);
  FTimer.Enabled := False;
end;

procedure TFmrMenuControl.TimerProc(Sender: TObject);
begin
  FTimer.Enabled := False;
  if (FHot <> nil) and FHot.HasSubMenu and FHot.IsEnabled and (FHotPart = TFmrElementPart.DropDown) then
  begin
    if FSubRow <> FHot then
      OpenSubMenu(FHot, False);
  end
  else if FSubRow <> nil then
    CloseSubMenu;
end;

procedure TFmrMenuControl.OpenSubMenu(const ARow: TFmrMenuRow; const AByKeyboard: Boolean);
var
  Content: TControl;
  Popup, Mine: TFmrPopupForm;
  Anchor: TRectF;
  TL, BR: TPointF;
begin
  if (ARow = nil) or not ARow.IsEnabled then
    Exit;
  CloseSubMenu;
  Mine := MyPopup;
  Content := FmrCreateDropDownContent(ARow.Item, FContext);
  if Content = nil then
    Exit;
  Popup := TFmrPopupForm.CreatePopup(FContext, Content);
  FSubRow := ARow;
  FSubPopup := Popup;
  Popup.OnClosed :=
    procedure
    begin
      if FSubPopup = Popup then
      begin
        FSubPopup := nil;
        FSubRow := nil;
        Repaint;
      end;
    end;
  if MenuMirrored(FContext) then
  begin
    TL := LocalToScreen(PointF(Width - ARow.Bounds.Right, ARow.Bounds.Top - FPad - 1));
    BR := LocalToScreen(PointF(Width - ARow.Bounds.Left, ARow.Bounds.Bottom));
    Anchor := RectF(TL.X - 2, TL.Y, BR.X, BR.Y);
  end
  else
  begin
    TL := LocalToScreen(PointF(ARow.Bounds.Left, ARow.Bounds.Top - FPad - 1));
    BR := LocalToScreen(PointF(ARow.Bounds.Right, ARow.Bounds.Bottom));
    Anchor := RectF(TL.X, TL.Y, BR.X + 2, BR.Y);
  end;
  Repaint;
  FmrPopups.Show(Popup, Anchor, TFmrPopupPlacement.Right, Mine, AByKeyboard);
end;

procedure TFmrMenuControl.CloseSubMenu;
var
  P: TFmrPopupForm;
begin
  P := FSubPopup;
  FSubPopup := nil;
  FSubRow := nil;
  if P <> nil then
  begin
    FmrPopups.Close(P);
    Repaint;
  end;
end;

procedure TFmrMenuControl.ExecuteRow(const ARow: TFmrMenuRow);
var
  Item: TFmrBarItem;
  Ctx: IFmrPopupContext;
begin
  if (ARow = nil) or not ARow.IsEnabled then
    Exit;
  if ARow.HasSubMenu and not ARow.IsSplit then
  begin
    OpenSubMenu(ARow, True);
    Exit;
  end;
  Item := ARow.Item;
  Ctx := FContext;
  FmrPopups.CloseAll;
  // The command runs from the message loop: a command that shows a modal dialog must not run inside the mouse
  // handler of this popup, which the popup manager frees while the dialog is open.
  TThread.ForceQueue(nil,
    procedure
    begin
      Ctx.ItemExecuting(Item);
      Item.Click;
    end);
end;

procedure TFmrMenuControl.MoveHot(const ADelta: Integer);
var
  I, Start, N: Integer;
begin
  N := FRows.Count;
  if N = 0 then
    Exit;
  if FHot <> nil then
    Start := FRows.IndexOf(FHot)
  else if ADelta > 0 then
    Start := -1
  else
    Start := N;
  I := Start;
  repeat
    I := I + ADelta;
    if I >= N then
      I := 0
    else if I < 0 then
      I := N - 1;
    if FRows[I].IsSelectable then
    begin
      if FRows[I].HasSubMenu and not FRows[I].IsSplit then
        SetHot(FRows[I], TFmrElementPart.DropDown)
      else
        SetHot(FRows[I], TFmrElementPart.Main);
      EnsureVisible(FRows[I]);
      Exit;
    end;
  until I = Start;
end;

procedure TFmrMenuControl.EnsureVisible(const ARow: TFmrMenuRow);
begin
  if ARow.Bounds.Top < 0 then
    SetScroll(FScroll + ARow.Bounds.Top - FPad)
  else if ARow.Bounds.Bottom > Height then
    SetScroll(FScroll + ARow.Bounds.Bottom - Height + FPad);
end;

procedure TFmrMenuControl.SelectFirst;
begin
  SetHot(nil, TFmrElementPart.None);
  MoveHot(1);
end;

procedure TFmrMenuControl.AssignKeyTips;
var
  Entries: TArray<TFmrKeyTipEntry>;
  Tips: TArray<string>;
  Row: TFmrMenuRow;
  I: Integer;
begin
  FKeyTipRows.Clear;
  for Row in FRows do
    if Row.IsSelectable then
      FKeyTipRows.Add(Row);
  SetLength(Entries, FKeyTipRows.Count);
  for I := 0 to FKeyTipRows.Count - 1 do
    Entries[I] := TFmrKeyTipEntry.Create(FKeyTipRows[I].KeyTipCaption, FKeyTipRows[I].ExplicitKeyTip, I);
  TFmrKeyTipAssigner.Assign(Entries);
  SetLength(Tips, Length(Entries));
  for I := 0 to High(Entries) do
  begin
    FKeyTipRows[I].KeyTip := Entries[I].KeyTip;
    Tips[I] := Entries[I].KeyTip;
  end;
  FMatcher.Reset(Tips);
end;

procedure TFmrMenuControl.PopupShown(const AByKeyboard: Boolean);
begin
  if FContext.KeyTipsActive then
    AssignKeyTips;
  if AByKeyboard then
    SelectFirst;
end;

procedure TFmrMenuControl.PopupClosed;
begin
  FTimer.Enabled := False;
  if Assigned(FmrMenuHotRowHook) then
    FmrMenuHotRowHook(Self, nil);
  if FSubPopup <> nil then
  begin
    FSubPopup.OnClosed := nil;
    FSubPopup := nil;
    FSubRow := nil;
  end;
end;

function TFmrMenuControl.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  Mine: TFmrPopupForm;
  Ch, Latin: Char;
  Match: TFmrKeyTipMatch;
  I, Found, Count: Integer;
  Row: TFmrMenuRow;
  Caption: string;
begin
  Result := True;
  Mine := MyPopup;
  // Right to left: Left opens a submenu and Right closes it, like Windows menus.
  if MenuMirrored(FContext) then
    case Key of
      vkLeft: Key := vkRight;
      vkRight: Key := vkLeft;
    end;
  case Key of
    vkUp: MoveHot(-1);
    vkDown: MoveHot(1);
    vkHome:
      begin
        SetHot(nil, TFmrElementPart.None);
        MoveHot(1);
      end;
    vkEnd:
      begin
        SetHot(nil, TFmrElementPart.None);
        MoveHot(-1);
      end;
    vkRight:
      if (FHot <> nil) and FHot.HasSubMenu and FHot.IsEnabled then
        OpenSubMenu(FHot, True)
      else
        Result := False;
    vkLeft:
      if (Mine <> nil) and (Mine.ParentPopup <> nil) then
        FmrPopups.Close(Mine)
      else
        Result := False;
    vkReturn, vkSpace:
      if FHot <> nil then
      begin
        if FHot.HasSubMenu and (not FHot.IsSplit or (FHotPart = TFmrElementPart.DropDown)) then
          OpenSubMenu(FHot, True)
        else
          ExecuteRow(FHot);
      end;
    vkBack:
      if FContext.KeyTipsActive then
      begin
        if not FMatcher.Backspace then
          FmrPopups.Close(Mine)
        else
          Repaint;
      end;
    vkEscape:
      Result := False;
  else
    begin
      if (KeyChar = #0) and (Key >= Ord('A')) and (Key <= Ord('Z')) and ([ssCtrl, ssAlt] * Shift = []) then
        KeyChar := Char(Key);
      if (KeyChar = #0) or ([ssCtrl, ssAlt] * Shift <> []) then
        Exit(True);
      Ch := Char(KeyChar).ToUpper;
      Latin := FmrLatinKeyChar(Key, KeyChar);
      if FContext.KeyTipsActive and (FKeyTipRows.Count > 0) then
      begin
        Match := FMatcher.Press(Ch);
        if (Match = TFmrKeyTipMatch.None) and (Latin <> #0) and (Latin <> Ch) then
          Match := FMatcher.Press(Latin);
        case Match of
          TFmrKeyTipMatch.Complete:
            begin
              Row := FKeyTipRows[FMatcher.MatchedIndex];
              SetHot(Row, TFmrElementPart.Main);
              if Row.HasSubMenu and not Row.IsSplit then
              begin
                FMatcher.Reset;
                OpenSubMenu(Row, True);
              end
              else
                ExecuteRow(Row);
            end;
          TFmrKeyTipMatch.Partial:
            Repaint;
        end;
        Exit(True);
      end;
      // Accelerators: the letter after '&', else the first letter; a unique match runs the item. The typed character
      // first, then the Latin letter of the key (captions in English typed with another layout).
      Found := -1;
      Count := 0;
      repeat
        for I := 0 to FRows.Count - 1 do
        begin
          Row := FRows[I];
          if not Row.IsSelectable or (Row.FLink = nil) then
            Continue;
          Caption := Row.FLink.Caption;
          if (Caption.IndexOf('&' + Ch) >= 0) or (Caption.ToUpper.IndexOf('&' + Ch) >= 0) or
            ((Caption.IndexOf('&') < 0) and Caption.ToUpper.StartsWith(Ch)) then
          begin
            Inc(Count);
            if Found < 0 then
              Found := I;
          end;
        end;
        if (Found >= 0) or (Latin = #0) or (Latin = Ch) then
          Break;
        Ch := Latin;
      until False;
      if Found >= 0 then
      begin
        Row := FRows[Found];
        SetHot(Row, TFmrElementPart.Main);
        if Count = 1 then
        begin
          if Row.HasSubMenu and not Row.IsSplit then
            OpenSubMenu(Row, True)
          else
            ExecuteRow(Row);
        end;
      end;
      Result := True;
    end;
  end;
end;

{ TFmrColorPaletteControl }

constructor TFmrColorPaletteControl.CreatePalette(const AContext: IFmrPopupContext; const AItem: TFmrColorItem);
begin
  inherited Create(nil);
  FContext := AContext;
  FItem := AItem;
  FCells := TList<TCell>.Create;
  FHeaders := TList<TPair<Single, string>>.Create;
  FHot := -1;
  HitTest := True;
  Build;
end;

destructor TFmrColorPaletteControl.Destroy;
begin
  FreeAndNil(FCells);
  FreeAndNil(FHeaders);
  FContext := nil;
  inherited;
end;

procedure TFmrColorPaletteControl.Build;
const
  Base: array[0..9] of TAlphaColor = ($FFFFFFFF, $FF000000, $FFE7E6E6, $FF44546A, $FF4472C4, $FFED7D31, $FFA5A5A5,
    $FFFFC000, $FF5B9BD5, $FF70AD47);
  Standard: array[0..9] of TAlphaColor = ($FFC00000, $FFFF0000, $FFFFC000, $FFFFFF00, $FF92D050, $FF00B050,
    $FF00B0F0, $FF0070C0, $FF002060, $FF7030A0);
  Lighter: array[0..2] of Single = (0.8, 0.6, 0.4);
  Darker: array[0..1] of Single = (0.25, 0.5);
var
  Cell: TCell;
  X, Y, CellS, Gap, Pad, RowH: Single;
  I, J: Integer;
  C: TAlphaColor;
  M: TFmrThemeMetrics;
begin
  M := FContext.Painter.Metrics;
  FCells.Clear;
  FHeaders.Clear;
  CellS := 15;
  Gap := 5;
  Pad := 6;
  RowH := M.MenuItemHeight;
  FWidth := Pad * 2 + 10 * CellS + 9 * Gap;
  Y := Pad;
  if FItem.ShowAutomatic then
  begin
    Cell.Color := FItem.AutomaticColor;
    Cell.Kind := 1;
    Cell.Rect := RectF(1, Y, FWidth - 1, Y + RowH);
    FCells.Add(Cell);
    Y := Y + RowH + 2;
  end;
  FHeaders.Add(TPair<Single, string>.Create(Y, FmrStr(TFmrStringId.ColorThemeColors)));
  Y := Y + RowH + 3;
  for I := 0 to 5 do
  begin
    X := Pad;
    for J := 0 to 9 do
    begin
      C := Base[J];
      if I > 0 then
      begin
        if J = 0 then
          C := FmrDarken(C, 0.05 + (I - 1) * 0.1 + IfThen(I = 5, 0.1, 0))
        else if J = 1 then
          C := FmrLighten(C, 0.5 - (I - 1) * 0.11)
        else if I <= 3 then
          C := FmrLighten(C, Lighter[I - 1])
        else
          C := FmrDarken(C, Darker[I - 4]);
      end;
      Cell.Color := C;
      Cell.Kind := 0;
      Cell.Rect := RectF(X, Y, X + CellS, Y + CellS);
      FCells.Add(Cell);
      X := X + CellS + Gap;
    end;
    if I = 0 then
      Y := Y + CellS + 5
    else
      Y := Y + CellS + 1;
  end;
  Y := Y + 4;
  FHeaders.Add(TPair<Single, string>.Create(Y, FmrStr(TFmrStringId.ColorStandardColors)));
  Y := Y + RowH + 3;
  X := Pad;
  for J := 0 to 9 do
  begin
    Cell.Color := Standard[J];
    Cell.Kind := 0;
    Cell.Rect := RectF(X, Y, X + CellS, Y + CellS);
    FCells.Add(Cell);
    X := X + CellS + Gap;
  end;
  Y := Y + CellS + Pad;
  if FItem.ShowNoColor then
  begin
    Cell.Color := TAlphaColors.Null;
    Cell.Kind := 2;
    Cell.Rect := RectF(1, Y, FWidth - 1, Y + RowH);
    FCells.Add(Cell);
    Y := Y + RowH + 2;
  end;
  FHeight := Y + 2;
end;

function TFmrColorPaletteControl.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FWidth, FHeight);
end;

function TFmrColorPaletteControl.PaintsOwnBackground: Boolean;
begin
  Result := False;
end;

procedure TFmrColorPaletteControl.PopupShown(const AByKeyboard: Boolean);
begin
  if AByKeyboard and (FCells.Count > 0) then
    SetHot(0);
end;

procedure TFmrColorPaletteControl.PopupClosed;
begin
end;

function TFmrColorPaletteControl.CellAt(const P: TPointF): Integer;
var
  I: Integer;
  R: TRectF;
begin
  for I := 0 to FCells.Count - 1 do
  begin
    R := FCells[I].Rect;
    R.Inflate(2, 2);
    if R.Contains(P) then
      Exit(I);
  end;
  Result := -1;
end;

procedure TFmrColorPaletteControl.SetHot(const AIndex: Integer);
begin
  if AIndex <> FHot then
  begin
    FHot := AIndex;
    Repaint;
  end;
end;

procedure TFmrColorPaletteControl.Pick(const AIndex: Integer);
var
  Item: TFmrColorItem;
  Ctx: IFmrPopupContext;
  C: TAlphaColor;
begin
  if (AIndex < 0) or (AIndex >= FCells.Count) then
    Exit;
  Item := FItem;
  Ctx := FContext;
  case FCells[AIndex].Kind of
    1: C := TAlphaColors.Null;
    2: C := TAlphaColors.Null;
  else
    C := FCells[AIndex].Color;
  end;
  FmrPopups.CloseAll;
  Ctx.ItemExecuting(Item);
  Item.Color := C;
  Item.Click;
end;

procedure TFmrColorPaletteControl.Paint;
var
  P: TFmrRibbonPainter;
  I: Integer;
  Cell: TCell;
  Pair: TPair<Single, string>;
  M: TFmrThemeMetrics;
  Text: string;
  Selected: Boolean;
begin
  P := FContext.Painter;
  M := P.Metrics;
  for Pair in FHeaders do
    P.DrawMenuHeader(Canvas, RectF(1, Pair.Key, FWidth - 1, Pair.Key + M.MenuItemHeight), Pair.Value);
  for I := 0 to FCells.Count - 1 do
  begin
    Cell := FCells[I];
    if Cell.Kind = 0 then
    begin
      Selected := (FItem.Color <> TAlphaColors.Null) and (Cell.Color = FItem.Color);
      P.DrawColorCell(Canvas, Cell.Rect, Cell.Color, I = FHot, Selected);
    end
    else
    begin
      if I = FHot then
        P.DrawMenuItem(Canvas, Cell.Rect, TFmrPartState.Hot);
      if Cell.Kind = 1 then
      begin
        P.DrawColorCell(Canvas, RectF(10, Cell.Rect.CenterPoint.Y - 7, 24, Cell.Rect.CenterPoint.Y + 7), Cell.Color,
          False, FItem.Color = TAlphaColors.Null);
        Text := FmrStr(TFmrStringId.ColorAutomatic);
      end
      else
        Text := FmrStr(TFmrStringId.ColorNoColor);
      P.Text(Canvas, RectF(32, Cell.Rect.Top, Cell.Rect.Right - 4, Cell.Rect.Bottom), Text,
        P.Theme.Colors[TFmrToken.MenuItemText], TTextAlign.Leading, TTextAlign.Center);
    end;
  end;
end;

procedure TFmrColorPaletteControl.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  SetHot(CellAt(PointF(X, Y)));
end;

procedure TFmrColorPaletteControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if Button = TMouseButton.mbLeft then
    Pick(CellAt(PointF(X, Y)));
end;

procedure TFmrColorPaletteControl.DoMouseLeave;
begin
  inherited;
  SetHot(-1);
end;

function TFmrColorPaletteControl.PopupKeyDown(var Key: Word; var KeyChar: WideChar;
  const Shift: TShiftState): Boolean;
var
  I, Best: Integer;
  Cur, C: TPointF;
  D, BestD: Single;
  Dir: TPointF;
begin
  Result := True;
  case Key of
    vkReturn, vkSpace:
      Pick(FHot);
    vkLeft, vkRight, vkUp, vkDown:
      begin
        if FHot < 0 then
        begin
          SetHot(0);
          Exit;
        end;
        case Key of
          vkLeft: Dir := PointF(-1, 0);
          vkRight: Dir := PointF(1, 0);
          vkUp: Dir := PointF(0, -1);
        else
          Dir := PointF(0, 1);
        end;
        Cur := FCells[FHot].Rect.CenterPoint;
        Best := -1;
        BestD := MaxSingle;
        for I := 0 to FCells.Count - 1 do
        begin
          if I = FHot then
            Continue;
          C := FCells[I].Rect.CenterPoint;
          if ((C.X - Cur.X) * Dir.X + (C.Y - Cur.Y) * Dir.Y) <= 0.5 then
            Continue;
          D := Abs((C.X - Cur.X) * Dir.X + (C.Y - Cur.Y) * Dir.Y) +
            3 * Abs((C.X - Cur.X) * Dir.Y + (C.Y - Cur.Y) * Dir.X);
          if FCells[I].Kind <> 0 then
            D := Abs(C.Y - Cur.Y) * 1.5;
          if D < BestD then
          begin
            BestD := D;
            Best := I;
          end;
        end;
        if Best >= 0 then
          SetHot(Best);
      end;
    vkEscape:
      Result := False;
  end;
end;

{ TFmrPopupMenu }

constructor TFmrPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  FItemLinks := TFmrItemLinks.Create(Self);
  FThemeName := FmrDefaultThemeName;
end;

destructor TFmrPopupMenu.Destroy;
begin
  ClosePopup;
  FreeAndNil(FItemLinks);
  FreeAndNil(FPainter);
  FreeAndNil(FTheme);
  inherited;
end;

procedure TFmrPopupMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FBarManager then
      FBarManager := nil;
    if AComponent = FThemeSource then
    begin
      ClosePopup;
      FThemeSource := nil;
    end;
  end;
end;

procedure TFmrPopupMenu.SetBarManager(const Value: TFmrBarManager);
begin
  if FBarManager <> Value then
  begin
    if FBarManager <> nil then
      FBarManager.RemoveFreeNotification(Self);
    FBarManager := Value;
    if FBarManager <> nil then
      FBarManager.FreeNotification(Self);
  end;
end;

procedure TFmrPopupMenu.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrPopupMenu.SetThemeName(const Value: string);
begin
  if FThemeName <> Value then
  begin
    FThemeName := Value;
    FreeAndNil(FPainter);
    FreeAndNil(FTheme);
  end;
end;

function TFmrPopupMenu.IsThemeNameStored: Boolean;
begin
  Result := not SameText(FThemeName, FmrDefaultThemeName);
end;

procedure TFmrPopupMenu.SetThemeSource(const Value: TFmxObject);
begin
  if FThemeSource <> Value then
  begin
    if FThemeSource <> nil then
      FThemeSource.RemoveFreeNotification(Self);
    FThemeSource := Value;
    if FThemeSource <> nil then
      FThemeSource.FreeNotification(Self);
  end;
end;

function TFmrPopupMenu.ResolvePainter: TFmrRibbonPainter;
var
  Src: IFmrThemeSource;
begin
  if (FThemeSource <> nil) and Supports(FThemeSource, IFmrThemeSource, Src) and (Src.GetThemePainter <> nil) then
    Exit(Src.GetThemePainter);
  if FPainter = nil then
  begin
    FTheme := TFmrTheme.CreateTheme(FThemeName);
    FPainter := TFmrRibbonPainter.Create(FTheme);
  end;
  Result := FPainter;
end;

function TFmrPopupMenu.ResolveImages: TCustomImageList;
var
  Src: IFmrThemeSource;
begin
  Result := nil;
  if FBarManager <> nil then
    Result := FBarManager.Images;
  if (Result = nil) and (FThemeSource <> nil) and Supports(FThemeSource, IFmrThemeSource, Src) then
    Result := Src.GetThemeImages;
end;

procedure TFmrPopupMenu.Popup(const X, Y: Single);
begin
  PopupBelow(RectF(X, Y, X, Y));
end;

procedure TFmrPopupMenu.PopupBelow(const AScreenRect: TRectF);
var
  Ctx: IFmrPopupContext;
  Content: TFmrMenuControl;
  Form: TCommonCustomForm;
  Placement: TFmrPopupPlacement;
begin
  ClosePopup;
  if csDesigning in ComponentState then
    Exit;
  if Assigned(FOnPopup) then
    FOnPopup(Self);
  if FItemLinks.VisibleCount = 0 then
    Exit;
  Form := FmrFormOf(Self);
  if Form = nil then
    Form := Screen.ActiveForm;
  Ctx := TFmrPopupContext.Create(ResolvePainter, ResolveImages, Form);
  Content := TFmrMenuControl.CreateMenu(Ctx, FItemLinks, FItemStyle);
  FPopupForm := TFmrPopupForm.CreatePopup(Ctx, Content);
  FPopupForm.OnClosed :=
    procedure
    begin
      FPopupForm := nil;
      if Assigned(FOnClose) then
        FOnClose(Self);
    end;
  if AScreenRect.Height = 0 then
    Placement := TFmrPopupPlacement.AtPoint
  else
    Placement := TFmrPopupPlacement.Below;
  FmrPopups.Show(FPopupForm, AScreenRect, Placement);
end;

procedure TFmrPopupMenu.ClosePopup;
var
  P: TFmrPopupForm;
begin
  P := FPopupForm;
  FPopupForm := nil;
  if P <> nil then
  begin
    P.OnClosed := nil;
    FmrPopups.Close(P);
  end;
end;

function TFmrPopupMenu.IsOpen: Boolean;
begin
  Result := FPopupForm <> nil;
end;

procedure TFmrPopupMenu.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
end;

procedure TFmrPopupMenu.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

procedure TFmrPopupMenu.LinksChanged(const ALinks: TFmrItemLinks);
begin
end;

{ default drop-downs }

function CreateColorDropDown(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
begin
  Result := TFmrColorPaletteControl.CreatePalette(AContext, TFmrColorItem(AItem));
end;

function GalleryEntryClick(const AGallery: TFmrGalleryItem; const AEntry: TFmrGalleryEntry): TProc;
begin
  Result :=
    procedure
    begin
      AGallery.ClickEntry(AEntry);
    end;
end;

function CreateGalleryDropDown(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
var
  G: TFmrGalleryItem;
  Temp: TFmrTempMenu;
  I, J: Integer;
  Entry: TFmrGalleryEntry;
  Menu: TFmrMenuControl;
begin
  // Placeholder until the gallery unit registers its own drop-down: entries as menu items, then the commands.
  G := TFmrGalleryItem(AItem);
  Temp := TFmrTempMenu.Create;
  for I := 0 to G.Groups.Count - 1 do
  begin
    if not G.Groups[I].Visible then
      Continue;
    if G.ShowGroupHeaders and (G.Groups[I].Caption <> '') then
      Temp.AddHeader(G.Groups[I].Caption);
    for J := 0 to G.Groups[I].Items.Count - 1 do
    begin
      Entry := G.Groups[I].Items[J];
      if not Entry.Visible then
        Continue;
      Temp.AddCommand(Entry.Caption, GalleryEntryClick(G, Entry), G.SelectedEntry = Entry, False,
        Entry.Enabled).Glyph := Entry.Glyph;
    end;
  end;
  for I := 0 to G.DropDownLinks.Count - 1 do
    if G.DropDownLinks[I].IsVisible then
      Temp.AddLink(G.DropDownLinks[I].Item, (I = 0) or G.DropDownLinks[I].BeginGroup);
  if Temp.Links.VisibleCount = 0 then
  begin
    Temp.Free;
    Exit(nil);
  end;
  Menu := TFmrMenuControl.CreateMenu(AContext, Temp.Links);
  Menu.OwnedObject := Temp;
  Result := Menu;
end;

initialization
  GDropDowns := TList<TPair<TFmrBarItemClass, TFmrDropDownFactory>>.Create;
  FmrRegisterDropDown(TFmrColorItem, CreateColorDropDown);
  FmrRegisterDropDown(TFmrGalleryItem, CreateGalleryDropDown);
  RegisterFmxClasses([TFmrPopupMenu]);

finalization
  FreeAndNil(GPopups);
  FreeAndNil(GDropDowns);

end.
