{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  The ribbon control                                   }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon;

/// TFmrRibbon: an Office-style ribbon for FMX. The ribbon is made of four lightweight parts (TControl descendants
/// that paint lightweight elements, no control per button):
///   - the caption bar (quick access toolbar, title, contextual tab group headers, search box, caption buttons);
///   - the tab bar (application button, tabs, collapse and help buttons);
///   - the body (groups of the active tab laid out by FMR.Ribbon.Layout, collapsed groups, dialog launchers);
///   - the quick access toolbar bar below the ribbon (when the QAT is placed below).
/// When the form has a TFmrFormFrame (Windows) the caption bar and the tab bar live in Frame.Host: in the FullNC mode
/// they are painted in the real non-client area. Without a frame both bars are children of the ribbon above the body.
/// The ribbon implements IFmrRibbonStructureOwner (tabs, groups and context groups are its children) and listens to
/// its bar manager; every change only marks the structure, the layout or the arrangement invalid, the work is done
/// once on idle, on resize or before painting.
/// At design time the ribbon is design-interactive: it takes the mouse on all of its parts and passes it to the hook
/// of the design package (IFmrRibbonDesignHook), and implements IFmrRibbonDesignSupport (hit tests, bounds, drop
/// targets, insertion mark and selection frames) - see FMR.Ribbon.DesignSupport and Docs\DESIGNTIME.md.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Math,
  System.Messaging, System.JSON, FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMX.Edit,
  FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Layout,
  FMR.Ribbon.KeyTips, FMR.Ribbon.Persistence, FMR.Ribbon.Merge, FMR.Ribbon.Strings, FMR.Ribbon.Theme,
  FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.Editors,
  FMR.Ribbon.ScreenTips, FMR.Frame.Types, FMR.Frame.Host, FMR.Frame, FMR.Ribbon.BiDi, FMR.Ribbon.DesignSupport;

type
  TFmrRibbon = class;
  TFmrRibbonPart = class;

  /// <summary>Implemented by an application menu or backstage view assigned to TFmrRibbon.ApplicationMenu.
  /// </summary>
  IFmrApplicationMenu = interface
    ['{8E3D2B5A-1C47-4F96-A0E2-6B9D4C1F7A35}']
    /// <summary>Shows the menu of ARibbon; AAnchor: screen rectangle of the application button.</summary>
    procedure ShowApplicationMenu(const ARibbon: TFmrRibbon; const AAnchor: TRectF; const AByKeyboard: Boolean);
    function IsApplicationMenuOpen: Boolean;
    procedure CloseApplicationMenu;
  end;

  /// <summary>The application button ("File" tab, Office 2007 orb).</summary>
  TFmrRibbonApplicationButton = class(TPersistent)
  private
    [Weak] FRibbon: TFmrRibbon;
    FVisible: Boolean;
    FCaption: string;
    FKeyTip: string;
    FScreenTip: TFmrScreenTip;
    procedure SetVisible(const Value: Boolean);
    procedure SetCaption(const Value: string);
    procedure SetKeyTip(const Value: string);
    procedure SetScreenTip(const Value: TFmrScreenTip);
    function IsCaptionStored: Boolean;
    function IsKeyTipStored: Boolean;
    procedure Changed;
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(const ARibbon: TFmrRibbon);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    /// <summary>Caption shown (the Caption property or the localized "File").</summary>
    function DisplayCaption: string;
  published
    property Caption: string read FCaption write SetCaption stored IsCaptionStored;
    property KeyTip: string read FKeyTip write SetKeyTip stored IsKeyTipStored;
    property ScreenTip: TFmrScreenTip read FScreenTip write SetScreenTip;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  TFmrRibbonTabChangingEvent = procedure(Sender: TObject; const ANewTab: TFmrRibbonTab;
    var AAllow: Boolean) of object;
  TFmrRibbonSearchEvent = procedure(Sender: TObject; const AText: string) of object;

  /// <summary>Kinds of the ribbon's own buttons.</summary>
  TFmrSysButtonKind = (CollapseRibbon, Help, QATCustomize, QATOverflow, ScrollLeft, ScrollRight, TabScrollLeft,
    TabScrollRight, SimplifiedOverflow, DisplayMode, DisplayOptions, AutoHideShow);

  /// <summary>Page of the customization form (TFmrRibbon.ShowCustomizationForm).</summary>
  TFmrCustomizationPage = (Ribbon, QuickAccessToolbar);

  /// <summary>Role of an element exposed to accessibility clients (UI Automation).</summary>
  TFmrAccRole = (QuickAccessToolbar, TabList, Tab, ApplicationButton, LowerRibbon, Group, Button, SplitButton,
    DropDownButton, CheckBox, Editor, CollapsedGroup, SystemButton, ComboBox, Spinner, Slider);

  /// <summary>One node of TFmrRibbon.AccessibilityNodes.</summary>
  TFmrAccNode = record
    Role: TFmrAccRole;
    Name: string;
    /// <summary>Stable identifier: the component name of the item, tab or group; a fixed name for the ribbon's own
    /// buttons and containers.</summary>
    AutomationId: string;
    HelpText: string;
    AccessKey: string;
    /// <summary>Index of the parent node; -1 for top-level nodes (children of the ribbon).</summary>
    Parent: Integer;
    /// <summary>Screen rectangle in dp.</summary>
    Bounds: TRectF;
    /// <summary>The element (nil for containers: toolbar, tab list, lower ribbon, groups).</summary>
    Element: TObject;
    /// <summary>Tab or group of the node, if any.</summary>
    Data: TObject;
    Enabled: Boolean;
    Selected: Boolean;
    Checked: Boolean;
    /// <summary>Text or number of editors (Editor, ComboBox, Spinner, Slider).</summary>
    Value: string;
    ReadOnly: Boolean;
  end;

  /// <summary>Glyph button of the ribbon itself (collapse, help, QAT customize, scroll buttons...).</summary>
  TFmrSysButtonElement = class(TFmrElement)
  private
    [Weak] FRibbon: TFmrRibbon;
    FKind: TFmrSysButtonKind;
  public
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Execute(const APart: TFmrElementPart); override;
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipCaption: string; override;
    property Kind: TFmrSysButtonKind read FKind;
  end;

  /// <summary>A tab of the tab bar.</summary>
  TFmrTabElement = class(TFmrElement)
  private
    [Weak] FRibbon: TFmrRibbon;
    FTab: TFmrRibbonTab;
    FFullWidth: Single;
    FMinWidth: Single;
  public
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Paint(const ACanvas: TCanvas); override;
    function KeyTipCaption: string; override;
    function ExplicitKeyTip: string; override;
    function KeyTipAnchor: TPointF; override;
    property Tab: TFmrRibbonTab read FTab;
  end;

  /// <summary>The application button.</summary>
  TFmrAppButtonElement = class(TFmrElement)
  private
    [Weak] FRibbon: TFmrRibbon;
  public
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipCaption: string; override;
    function ExplicitKeyTip: string; override;
    function KeyTipAnchor: TPointF; override;
  end;

  /// <summary>Button of a collapsed group (opens the group in a popup).</summary>
  TFmrCollapsedGroupElement = class(TFmrElement)
  private
    [Weak] FRibbon: TFmrRibbon;
    FGroup: TFmrRibbonGroup;
    FLine1, FLine2: string;
  public
    function OpensOnPress(const APart: TFmrElementPart): Boolean; override;
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipCaption: string; override;
    function ExplicitKeyTip: string; override;
    property Group: TFmrRibbonGroup read FGroup;
  end;

  /// <summary>Dialog launcher of a group.</summary>
  TFmrLauncherElement = class(TFmrElement)
  private
    [Weak] FRibbon: TFmrRibbon;
    FGroup: TFmrRibbonGroup;
  public
    procedure Execute(const APart: TFmrElementPart); override;
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
    function KeyTipCaption: string; override;
    function ExplicitKeyTip: string; override;
    property Group: TFmrRibbonGroup read FGroup;
  end;

  /// <summary>Geometry of one group of the body after arrangement.</summary>
  TFmrGroupBox = record
    Group: TFmrRibbonGroup;
    Rect: TRectF;
    Collapsed: Boolean;
    Separators: TArray<Single>;
    LayoutIndex: Integer;
  end;

  /// <summary>Base of the ribbon's parts: hosts elements, tracks the mouse, shows screen tips and key tips.
  /// </summary>
  TFmrRibbonPart = class(TControl, IFmrElementHost, IFmrMirroredHost)
  private
    [Weak] FRibbon: TFmrRibbon;
    FTracker: TFmrElementTracker;
    FTipOverlay: TControl;
    procedure TrackerHotChanged(Sender: TObject);
    { right to left: element bounds are logical, the canvas and the mouse are flipped }
    function IsMirrored: Boolean;
    function Logical(const X, Y: Single): TPointF;
    function PhysicalRect(const R: TRectF): TRectF;
    /// <summary>Key tip badges of the elements of this part (painted by an overlay above editor controls).
    /// </summary>
    procedure PaintKeyTips(const ACanvas: TCanvas);
    procedure UpdateTipOverlay;
  protected
    { IFmrElementHost }
    function GetPainter: TFmrRibbonPainter; virtual;
    function GetImages: TCustomImageList;
    function GetHostControl: TControl;
    procedure InvalidateElement(const AElement: TFmrElement);
    procedure ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean); virtual;
    procedure ElementExecuted(const AElement: TFmrElement); virtual;
    function IsElementDroppedDown(const AElement: TFmrElement): Boolean; virtual;
    { parts }
    function FindElement(const P: TPointF): TFmrElement; virtual;
    procedure PaintPart(const ACanvas: TCanvas); virtual;
    function ScreenTipAnchor(const AElement: TFmrElement): TRectF; virtual;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DoMouseLeave; override;
    procedure Resize; override;
    /// <summary>Design time: no editor control of the part takes the mouse; a part inside the ribbon leaves the
    /// clicks to the ribbon, a part in the frame host takes them and passes them on.</summary>
    function ObjectAtPoint(AScreenPoint: TPointF): IControl; override;
    /// <summary>Design time: a component dropped from the palette never lands in a part or an editor control.
    /// </summary>
    function FindTarget(P: TPointF; const Data: TDragObject): IControl; override;
    /// <summary>Design time: insertion mark and selection frames above the children.</summary>
    procedure AfterPaint; override;
    /// <summary>True when a click at P must still be processed while popups are open (it closed them first).
    /// </summary>
    function KeepClickWhenClosingPopups(const P: TPointF): Boolean; virtual;
  public
    constructor Create(const ARibbon: TFmrRibbon); reintroduce; virtual;
    destructor Destroy; override;
    property Ribbon: TFmrRibbon read FRibbon;
    property Tracker: TFmrElementTracker read FTracker;
  end;

  /// <summary>Window caption button painted with the ribbon theme (driven by the frame on Windows).</summary>
  TFmrRibbonCaptionButton = class(TControl, IFmrFrameButton, IFmrFrameHitTest, IFmrFrameStateAware)
  private
    [Weak] FRibbon: TFmrRibbon;
    FKind: TFmrHitArea;
    FHot, FDown, FFrameDriven, FActive, FMaximized: Boolean;
  protected
    function GetFrameButtonKind: TFmrHitArea;
    procedure SetFrameButtonState(const AHot, APressed: Boolean);
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
    procedure FrameStateChanged(const AState: TFmrFrameState);
    procedure Paint; override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    constructor CreateButton(const ARibbon: TFmrRibbon; const AKind: TFmrHitArea);
    procedure Execute;
  end;

  /// <summary>Caption row: quick access toolbar, title, contextual tab group headers, search box, caption buttons.
  /// </summary>
  TFmrRibbonCaptionBar = class(TFmrRibbonPart, IFmrFrameHitTest, IFmrFrameStateAware)
  private
    FSearchEdit: TEdit;
    FSearchRect: TRectF;
    FTitleRect: TRectF;
    FQATRect: TRectF;
    FButtons: TList<TFmrRibbonCaptionButton>;
    procedure SearchEditApplyStyle(Sender: TObject);
    procedure SearchEditChangeTracking(Sender: TObject);
    procedure SearchEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  protected
    function GetPainter: TFmrRibbonPainter; override;
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
    procedure FrameStateChanged(const AState: TFmrFrameState);
    function FindElement(const P: TPointF): TFmrElement; override;
    procedure PaintPart(const ACanvas: TCanvas); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(const ARibbon: TFmrRibbon); override;
    destructor Destroy; override;
    property SearchEdit: TEdit read FSearchEdit;
  end;

  /// <summary>Tab row: application button, tabs, collapse and help buttons.</summary>
  TFmrRibbonTabBar = class(TFmrRibbonPart, IFmrFrameHitTest, IFmrFrameStateAware)
  protected
    function GetPainter: TFmrRibbonPainter; override;
    function FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
    procedure FrameStateChanged(const AState: TFmrFrameState);
    function FindElement(const P: TPointF): TFmrElement; override;
    procedure PaintPart(const ACanvas: TCanvas); override;
    procedure ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean); override;
    function IsElementDroppedDown(const AElement: TFmrElement): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    function KeepClickWhenClosingPopups(const P: TPointF): Boolean; override;
  end;

  /// <summary>Body: the groups of the active tab (also the content of the popup of a minimized ribbon).</summary>
  TFmrRibbonBody = class(TFmrRibbonPart, IFmrPopupContent)
  protected
    function FindElement(const P: TPointF): TFmrElement; override;
    procedure PaintPart(const ACanvas: TCanvas); override;
    function ScreenTipAnchor(const AElement: TFmrElement): TRectF; override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    { IFmrPopupContent }
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
  end;

  /// <summary>Quick access toolbar below the ribbon.</summary>
  TFmrRibbonQATBar = class(TFmrRibbonPart)
  protected
    function FindElement(const P: TPointF): TFmrElement; override;
    procedure PaintPart(const ACanvas: TCanvas); override;
  end;

  /// <summary>Content of the popup of a collapsed group: the group fully expanded, with its own views moved in.
  /// </summary>
  TFmrGroupPopupContent = class(TFmrRibbonPart, IFmrPopupContent)
  private
    FGroup: TFmrRibbonGroup;
    FResult: TFmrLayoutGroupResult;
    FViews: TList<TFmrItemView>;
    FLauncher: TFmrLauncherElement;
    FSize: TSizeF;
    FGroupRect: TRectF;
  protected
    function FindElement(const P: TPointF): TFmrElement; override;
    procedure PaintPart(const ACanvas: TCanvas); override;
    procedure Resize; override;
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
  public
    constructor CreateFor(const ARibbon: TFmrRibbon; const AGroup: TFmrRibbonGroup);
    destructor Destroy; override;
    /// <summary>Gives the views back to the body.</summary>
    procedure ReturnViews;
  end;

  TFmrKeyTipLevel = (None, Top, Tab, GroupPopup);

  /// <summary>Microsoft Office style ribbon.</summary>
  TFmrRibbon = class(TControl, IFmrRibbonStructureOwner, IFmrBarManagerListener, IFmrKeyHandler, IFmrThemeSource,
    IFmrThemeProvider, IFmrRibbonDesignSupport)
  private type
    TKeyTipEntryRec = record
      Element: TFmrElement;
      Tip: string;
    end;

    TDesignMouseEvent = (Down, Move, Up);

    TRibbonPopupContext = class(TFmrPopupContext, IFmrMirroredHost)
    private
      [Weak] FRibbon: TFmrRibbon;
      FSearchResults: Boolean;
    protected
      procedure ItemExecuting(const AItem: TFmrBarItem); override;
      function ItemContextPopup(const AItem: TFmrBarItem; const AScreenPoint: TPointF): Boolean; override;
      { IFmrMirroredHost: popups of a right-to-left ribbon open to the left and mirror their menus }
      function IsMirrored: Boolean;
    end;
  private
    FBarManager: TFmrBarManager;
    FQAT: TFmrRibbonQuickAccessToolbar;
    FAppButton: TFmrRibbonApplicationButton;
    FApplicationMenu: TFmxObject;
    FActiveTab: TFmrRibbonTab;
    FThemeName: string;
    FAccentColor: TAlphaColor;
    FTheme: TFmrTheme;
    FPainter: TFmrRibbonPainter;
    FBarTheme: TFmrTheme;
    FBarPainter: TFmrRibbonPainter;
    FMinimized: Boolean;
    FShowMode: TFmrRibbonShowMode;
    FDisplayMode: TFmrRibbonDisplayMode;
    FTouchMode: Boolean;
    FShowTabGroups: Boolean;
    FFrame: TFmrFormFrame;
    FFrameAuto: Boolean;
    FFrameCheckPending: Boolean;
    FCaptionText: string;
    FShowCaption: Boolean;
    FShowSearchBox: Boolean;
    FShowKeyTips: Boolean;
    FShowScreenTips: Boolean;
    FShowHelpButton: Boolean;
    FShowCollapseButton: Boolean;
    FRightToLeft: Boolean;
    FOnTabChanging: TFmrRibbonTabChangingEvent;
    FOnTabChanged: TNotifyEvent;
    FOnMinimizedChanged: TNotifyEvent;
    FOnHelpButtonClick: TNotifyEvent;
    FOnApplicationButtonClick: TNotifyEvent;
    FOnSearch: TFmrRibbonSearchEvent;
    FOnCustomizeQAT: TNotifyEvent;
    FOnDisplayModeChanged: TNotifyEvent;
    { parts }
    FCaptionBar: TFmrRibbonCaptionBar;
    FTabBar: TFmrRibbonTabBar;
    FBody: TFmrRibbonBody;
    FQATBar: TFmrRibbonQATBar;
    FBarsInHost: Boolean;
    FFrameState: TFmrFrameState;
    { elements }
    FViews: TList<TFmrItemView>;
    FAppElement: TFmrAppButtonElement;
    FTabElements: TObjectList<TFmrTabElement>;
    FTabSysElements: TObjectList<TFmrSysButtonElement>;
    FCaptionSysElements: TObjectList<TFmrSysButtonElement>;
    FQATBarSysElements: TObjectList<TFmrSysButtonElement>;
    FBodyElements: TObjectList<TFmrElement>;
    FBodyViews: TList<TFmrItemView>;
    FQATViews: TList<TFmrItemView>;
    FQATOverflow: TList<TFmrItemView>;
    FGroupBoxes: TArray<TFmrGroupBox>;
    FLayoutGroups: TArray<TFmrRibbonGroup>;
    FCalc: TFmrRibbonLayoutCalculator;
    FLayoutResult: TFmrLayoutResult;
    FSimplifiedResult: TFmrSimplifiedLayoutResult;
    FSimplifiedOverflow: TArray<TFmrItemLink>;
    FScrollOffset: Single;
    FTabScroll: Single;
    FTabsFit: Boolean;
    FContextHeaders: TArray<TPair<TFmrRibbonContextGroup, TRectF>>;
    { state }
    FStructureValid: Boolean;
    FLayoutValid: Boolean;
    FArrangeValid: Boolean;
    FArrangedWidth: Single;
    FUpdateCount: Integer;
    FRebuilding: Boolean;
    FDroppedElement: TFmrElement;
    FDropPopup: TFmrPopupForm;
    FMinimizedPopup: TFmrPopupForm;
    FGroupPopup: TFmrPopupForm;
    FGroupPopupContent: TFmrGroupPopupContent;
    FSearchPopup: TFmrPopupForm;
    FScreenTips: TFmrScreenTipController;
    FMerger: TFmrRibbonMerger;
    FIdleId: TMessageSubscriptionId;
    FStyleId: TMessageSubscriptionId;
    FMenuLoopId: TMessageSubscriptionId;
    FDeactivateId: TMessageSubscriptionId;
    FLanguageId: TMessageSubscriptionId;
    FFrameStateId: TMessageSubscriptionId;
    FLastHooked: Boolean;
    FLastMode: TFmrFrameMode;
    FAltArmed: Boolean;
    FAppMenuTracking: Boolean;
    FAppMenuCovering: Boolean;
    FDestroying: Boolean;
    FPainting: Boolean;
    FNeedRepaint: Boolean;
    { key tips }
    FKeyTipLevel: TFmrKeyTipLevel;
    FKeyTips: TList<TKeyTipEntryRec>;
    FKeyTipMatcher: TFmrKeyTipMatcher;
    FKeyFocus: TFmrElement;
    { customization, display options, auto-hide, right to left }
    FDefaultLayout: string;
    FShowDisplayOptionsButton: Boolean;
    FShowDisplayModeButton: Boolean;
    FAutoHidePopup: TFmrPopupForm;
    FAutoHideClosedTick: Cardinal;
    FLastRTL: Boolean;
    FAccVersion: Integer;
    FTabTipOverlay: TControl;
    { design time }
    FDesignSelection: TArray<TPersistent>;
    FDesignTarget: TFmrDesignDropTarget;
    FDesignTab: TFmrRibbonTab;
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetQAT(const Value: TFmrRibbonQuickAccessToolbar);
    procedure SetAppButton(const Value: TFmrRibbonApplicationButton);
    procedure SetApplicationMenu(const Value: TFmxObject);
    procedure SetActiveTabProp(const Value: TFmrRibbonTab);
    procedure SetThemeName(const Value: string);
    function IsThemeNameStored: Boolean;
    procedure SetAccentColor(const Value: TAlphaColor);
    procedure SetMinimized(const Value: Boolean);
    procedure SetShowMode(const Value: TFmrRibbonShowMode);
    procedure SetDisplayMode(const Value: TFmrRibbonDisplayMode);
    procedure SetTouchMode(const Value: Boolean);
    procedure SetShowTabGroups(const Value: Boolean);
    procedure SetFrame(const Value: TFmrFormFrame);
    procedure SetCaptionText(const Value: string);
    procedure SetShowCaption(const Value: Boolean);
    procedure SetShowSearchBox(const Value: Boolean);
    procedure SetShowKeyTips(const Value: Boolean);
    procedure SetShowScreenTips(const Value: Boolean);
    procedure SetShowHelpButton(const Value: Boolean);
    procedure SetShowCollapseButton(const Value: Boolean);
    procedure SetRightToLeft(const Value: Boolean);
    function GetSearchText: string;
    procedure SetSearchText(const Value: string);
    { theme }
    procedure BuildTheme;
    function FindStyleRoot: TFmxObject;
    procedure ApplyFrameColors;
    { parts }
    procedure CreateParts;
    procedure UpdateFrameAttachment;
    function FindOwnerFrame: TFmrFormFrame;
    procedure PlaceBars;
    procedure UpdateHeights;
    function CaptionBarVisible: Boolean;
    function BodyVisible: Boolean;
    function IsCollapsed: Boolean;
    function CaptionBarHeight: Single;
    function TabBarHeight: Single;
    function BodyHeight: Single;
    function QATBarHeight: Single;
    procedure InvalidateParts;
    function OwnerForm: TCommonCustomForm;
    { structure and layout }
    procedure InvalidateStructure;
    procedure InvalidateLayout;
    procedure InvalidateArrange;
    procedure EnsureStructure;
    procedure EnsureLayout;
    procedure EnsureArrange;
    procedure EnsureAll;
    procedure RebuildStructure;
    function ViewFor(const ALink: TFmrItemLink; const AHost: IFmrElementHost; const APlace: TFmrViewPlace): TFmrItemView;
    procedure FreeView(const AView: TFmrItemView);
    procedure FreeViewsOf(const ALinks: TFmrItemLinks);
    procedure ValidateViews;
    function ShownTabs: TArray<TFmrRibbonTab>;
    procedure PickActiveTab;
    function LayoutMetrics: TFmrLayoutMetrics;
    function MeasureCollapsedWidth(const AGroup: TFmrRibbonGroup): Single;
    function GroupLayoutInput(const AGroup: TFmrRibbonGroup; out AViews: TArray<TFmrItemView>): TFmrLayoutGroup;
    procedure ArrangeTabBar;
    procedure ArrangeCaptionBar;
    procedure ArrangeBody;
    procedure ArrangeBodyClassic(const AContent: TRectF);
    procedure ArrangeBodySimplified(const AContent: TRectF);
    procedure ArrangeQATBar;
    procedure ArrangeQAT(const AArea: TRectF; const AHost: TFmrRibbonPart; const ASysList: TObjectList<TFmrSysButtonElement>;
      out AUsed: TRectF);
    function BodyCardRect: TRectF;
    function GroupAreaRect: TRectF;
    function NewSysButton(const AList: TObjectList<TFmrSysButtonElement>; const AHost: IFmrElementHost;
      const AKind: TFmrSysButtonKind): TFmrSysButtonElement;
    function ContextColor(const AGroup: TFmrRibbonContextGroup): TAlphaColor;
    function IsOrb: Boolean;
    /// <summary>Rectangle of the Office 2007 orb in the coordinates of a bar whose top is AOffsetY below the top
    /// of the caption row.</summary>
    function OrbRect(const AOffsetY: Single): TRectF;
    function TabBarOffset: Single;
    procedure PaintOrb(const ACanvas: TCanvas; const AOffsetY: Single);
    function ActiveTabRect: TRectF;
    function TitleText: string;
    function FrameActive: Boolean;
    { messages }
    procedure IdleHandler(const Sender: TObject; const M: TMessage);
    procedure StyleChangedHandler(const Sender: TObject; const M: TMessage);
    procedure MenuLoopHandler(const Sender: TObject; const M: TMessage);
    procedure DeactivateHandler(const Sender: TObject; const M: TMessage);
    procedure LanguageHandler(const Sender: TObject; const M: TMessage);
    procedure FrameStateHandler(const Sender: TObject; const M: TMessage);
    { actions }
    procedure TabElementPressed(const AElement: TFmrTabElement; const AByKeyboard: Boolean);
    procedure ShowMinimizedPopup(const AByKeyboard: Boolean);
    procedure ShowGroupPopup(const AElement: TFmrCollapsedGroupElement; const AByKeyboard: Boolean);
    procedure ShowDropDown(const AElement: TFmrElement; const AHost: TFmrRibbonPart; const AByKeyboard: Boolean);
    procedure ShowQATCustomizeMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
    procedure ShowQATOverflowMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
    procedure ShowSimplifiedOverflowMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
    procedure ShowRibbonContextMenu(const AItem: TFmrBarItem; const AScreenPoint: TPointF);
    procedure ShowPopupForElement(const AContent: TControl; const AElement: TFmrElement; const AHost: TFmrRibbonPart;
      const AByKeyboard: Boolean; const AOwned: TObject = nil;
      const APlacement: TFmrPopupPlacement = TFmrPopupPlacement.Below);
    procedure ApplicationButtonPressed(const AByKeyboard: Boolean);
    procedure InvokeApplicationMenu(const AAnchor: TRectF; const AByKeyboard: Boolean);
    function ApplicationMenuCovers: Boolean;
    procedure UpdateApplicationMenuState;
    procedure SysButtonExecute(const AElement: TFmrSysButtonElement; const AByKeyboard: Boolean);
    procedure ScrollGroups(const AForward: Boolean);
    procedure ScrollTabs(const AForward: Boolean);
    procedure SelectAdjacentTab(const ADelta: Integer);
    function NewPopupContext: IFmrPopupContext;
    function ElementScreenRect(const AElement: TFmrElement; const AHost: TControl): TRectF;
    procedure DropDownClosed(const APopup: TFmrPopupForm);
    procedure SearchChanged(const AText: string);
    procedure SearchExecute;
    procedure ExecuteShortcut(var Key: Word; const Shift: TShiftState);
    function FocusInRibbonEditor: Boolean;
    { key tips }
    procedure EnterKeyTips(const ALevel: TFmrKeyTipLevel);
    procedure BuildKeyTips(const ALevel: TFmrKeyTipLevel);
    procedure KeyTipExecute(const AElement: TFmrElement);
    procedure KeyTipBack;
    procedure MoveKeyFocus(const ADirection: TFmrArrowDirection);
    procedure SetKeyFocus(const AElement: TFmrElement);
    function KeyTipElements(const ALevel: TFmrKeyTipLevel): TArray<TFmrElement>;
    { customization, display options, auto-hide }
    procedure SetShowDisplayOptionsButton(const Value: Boolean);
    procedure SetShowDisplayModeButton(const Value: Boolean);
    procedure CaptureDefaultLayout;
    function AutoHideActive: Boolean;
    procedure ShowAutoHideRibbon(const AByKeyboard: Boolean);
    procedure ShowDisplayOptionsMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
    procedure AddDisplayModeButton(const ABounds: TRectF);
    procedure QueueCustomizationForm(const APage: TFmrCustomizationPage);
    /// <summary>Key tips of the tabs below the tab row while the body is hidden (minimized ribbon): painted by an
    /// overlay on the form, like Office.</summary>
    procedure UpdateTabTipOverlay;
    { design time }
    function TabShown(const T: TFmrRibbonTab): Boolean;
    function DesignParts: TArray<TFmrRibbonPart>;
    function DesignPartAt(const ALocalPoint: TPointF; out APart: TFmrRibbonPart; out ALogical: TPointF): Boolean;
    /// <summary>Logical rectangle of a part -> local rectangle of the ribbon (the part may be in the frame host).
    /// </summary>
    function PartToLocal(const APart: TFmrRibbonPart; const ALogical: TRectF): TRectF;
    /// <summary>Local rectangle of the ribbon -> physical rectangle of a part (painting).</summary>
    function LocalToPart(const APart: TControl; const ALocal: TRectF): TRectF;
    /// <summary>Groups shown in the body with their rectangles (body coordinates); simplified mode: the span of
    /// their views.</summary>
    function DesignGroupBoxes: TArray<TFmrGroupBox>;
    /// <summary>Every place where AObject (tab, context group, group, link, item) is shown, ribbon coordinates.
    /// Compares pointers only: AObject may already be freed.</summary>
    function DesignRectsOf(const AObject: TPersistent): TArray<TRectF>;
    function DesignHitAt(const ALocalPoint: TPointF): TFmrDesignHit;
    function DesignLinkTarget(const APart: TFmrRibbonPart; const P: TPointF): TFmrDesignDropTarget;
    function DesignGroupTarget(const APart: TFmrRibbonPart; const P: TPointF): TFmrDesignDropTarget;
    function DesignTabTarget(const P: TPointF): TFmrDesignDropTarget;
    procedure DesignMouseEvent(const AEvent: TDesignMouseEvent; const AButton: TMouseButton; const AShift: TShiftState;
      const ALocalPoint: TPointF);
    procedure PaintDesignFeedback(const APart: TControl; const ACanvas: TCanvas);
  protected
    { IFmrRibbonStructureOwner }
    function GetStructureObject: TFmxObject;
    function GetBarManager: TFmrBarManager;
    function GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
    function GetActiveTab: TFmrRibbonTab;
    procedure SetActiveTab(const ATab: TFmrRibbonTab);
    function GetLayoutOptions: TFmrRibbonLayoutOptions;
    procedure SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
    procedure StructureChanged(const ASender: TObject);
    procedure StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
    procedure StructureObjectRemoving(const AObject: TObject);
    procedure LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
    { IFmrBarManagerListener }
    procedure BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
      const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
    { IFmrKeyHandler }
    function HandleKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure KeyboardLost;
    { IFmrThemeSource }
    function GetThemePainter: TFmrRibbonPainter;
    function GetThemeImages: TCustomImageList;
    { IFmrThemeProvider }
    function GetFmrTheme: TFmrTheme;
    { TControl }
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ParentChanged; override;
    procedure Resize; override;
    procedure Paint; override;
    procedure DialogKey(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoAddObject(const AObject: TFmxObject); override;
    procedure DoRemoveObject(const AObject: TFmxObject); override;
    function GetDefaultSize: TSizeF; override;
    procedure DoTabChanged; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeforeDestruction; override;
    /// <summary>Brackets a batch of changes (building the ribbon in code, loading a layout): the ribbon is laid
    /// out once at the outermost EndStructureUpdate. Calls nest.</summary>
    procedure BeginStructureUpdate;
    procedure EndStructureUpdate;
    { structure helpers }
    function TabCount: Integer;
    function Tabs(const AIndex: Integer): TFmrRibbonTab;
    function AddTab(const ACaption: string; const AName: string = ''): TFmrRibbonTab;
    function AddContextGroup(const ACaption: string; const AColor: TAlphaColor; const AName: string = '')
      : TFmrRibbonContextGroup;
    { layout persistence and merging }
    function SaveLayoutToString(const AIndent: Boolean = True): string;
    procedure SaveLayoutToStream(const AStream: TStream);
    procedure SaveLayoutToFile(const AFileName: string);
    procedure LoadLayoutFromString(const AText: string);
    procedure LoadLayoutFromStream(const AStream: TStream);
    procedure LoadLayoutFromFile(const AFileName: string);
    /// <summary>Merges the tabs and groups of another ribbon (or structure owner) into this one.</summary>
    function Merge(const ASource: TFmxObject): Boolean;
    function Unmerge(const ASource: TFmxObject): Boolean;
    procedure UnmergeAll;
    { UI }
    /// <summary>Shows the key tips of the tabs (like pressing Alt).</summary>
    procedure ShowKeyTipsNow;
    procedure HideKeyTips;
    function KeyTipsVisible: Boolean;
    /// <summary>Closes every popup opened by the ribbon.</summary>
    procedure ClosePopups;
    /// <summary>Lays out the ribbon now (normally done on idle).</summary>
    procedure UpdateLayout;
    /// <summary>The tab under a screen point (design time: the design package switches tabs with it).</summary>
    function TabAtScreenPoint(const AScreenPoint: TPointF): TFmrRibbonTab;
    /// <summary>Screen rectangle of the application button (application menu, backstage).</summary>
    function ApplicationButtonScreenRect: TRectF;
    /// <summary>Text dump of the parts and elements with their bounds (diagnostics, tests).</summary>
    function DebugDump: string;
    { customization }
    /// <summary>Opens the customization form ("Customize the Ribbon" / "Quick Access Toolbar" pages); True when
    /// the user pressed OK.</summary>
    function ShowCustomizationForm(const APage: TFmrCustomizationPage = TFmrCustomizationPage.Ribbon): Boolean;
    /// <summary>Loads DefaultLayout (reset of every customization).</summary>
    procedure ResetLayout;
    /// <summary>The layout of the ribbon as designed: captured before the first LoadLayoutFrom* call, at Loaded,
    /// or on the first idle; the reset commands of the customization form return to it. Set it yourself when the
    /// ribbon is built or loaded in another way.</summary>
    property DefaultLayout: string read FDefaultLayout write FDefaultLayout;
    { right to left, auto-hide }
    /// <summary>RightToLeft, or the BiDiMode of the form is bdRightToLeft.</summary>
    function EffectiveRightToLeft: Boolean;
    /// <summary>ShowMode = AutoHide: shows the tabs and the commands over the form until the user clicks outside.
    /// </summary>
    procedure ShowAutoHiddenRibbon;
    function AutoHiddenRibbonShown: Boolean;
    { accessibility }
    /// <summary>Snapshot of the elements for accessibility clients (FMR.Ribbon.UIA.Win): quick access toolbar,
    /// tabs, groups and their commands with screen bounds (dp).</summary>
    function AccessibilityNodes: TArray<TFmrAccNode>;
    /// <summary>Runs the default action of an element of AccessibilityNodes (click, select a tab, open a drop-down);
    /// False when the element is gone.</summary>
    function AccessibilityInvoke(const AElement: TObject): Boolean;
    /// <summary>Sets the text (edit, combo) or the number (spin, track bar) of an editor element of
    /// AccessibilityNodes; False when the element is gone, read-only or the value is not a number.</summary>
    function AccessibilitySetValue(const AElement: TObject; const AValue: string): Boolean;
    /// <summary>Changes whenever the elements are rebuilt or rearranged.</summary>
    property AccessibilityVersion: Integer read FAccVersion;
    { IFmrRibbonDesignSupport (design time; local coordinates of the ribbon) }
    function DesignHitTest(const ALocalPoint: TPointF): TFmrDesignHit;
    function DesignObjectBounds(const AObject: TPersistent): TRectF;
    function DesignDropTarget(const ALocalPoint: TPointF; const AKind: TFmrDesignDragKind): TFmrDesignDropTarget;
    procedure DesignShowDropTarget(const ATarget: TFmrDesignDropTarget);
    procedure DesignSetSelection(const AObjects: TArray<TPersistent>);
    procedure DesignSelectTab(const ATab: TFmrRibbonTab);
    property Painter: TFmrRibbonPainter read FPainter;
    property ThemeObject: TFmrTheme read FTheme;
    property CaptionBar: TFmrRibbonCaptionBar read FCaptionBar;
    property TabBar: TFmrRibbonTabBar read FTabBar;
    property Body: TFmrRibbonBody read FBody;
    property QATBar: TFmrRibbonQATBar read FQATBar;
    property ScreenTips: TFmrScreenTipController read FScreenTips;
    property SearchText: string read GetSearchText write SetSearchText;
  published
    property AccentColor: TAlphaColor read FAccentColor write SetAccentColor default 0;
    property ActiveTab: TFmrRibbonTab read FActiveTab write SetActiveTabProp;
    property Align default TAlignLayout.Top;
    property ApplicationButton: TFmrRibbonApplicationButton read FAppButton write SetAppButton;
    /// <summary>Shown by the application button: a TFmrPopupMenu, an object implementing IFmrApplicationMenu, or an
    /// object with public ShowApplicationMenu(TFmxObject, TRectF, Boolean) / IsApplicationMenuOpen methods (the
    /// backstage view, called through RTTI). While such a control is open over the form, the tab row is hidden.
    /// </summary>
    property ApplicationMenu: TFmxObject read FApplicationMenu write SetApplicationMenu;
    property Anchors;
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    /// <summary>Title of the caption row; empty = the caption of the form.</summary>
    property CaptionText: string read FCaptionText write SetCaptionText;
    property DisplayMode: TFmrRibbonDisplayMode read FDisplayMode write SetDisplayMode
      default TFmrRibbonDisplayMode.Classic;
    property Enabled;
    /// <summary>Frame whose host receives the caption row and the tab row; found on the owner form when nil.
    /// </summary>
    property Frame: TFmrFormFrame read FFrame write SetFrame;
    property Height;
    property Margins;
    property Minimized: Boolean read FMinimized write SetMinimized default False;
    property Padding;
    property Position;
    property QuickAccessToolbar: TFmrRibbonQuickAccessToolbar read FQAT write SetQAT;
    property RightToLeft: Boolean read FRightToLeft write SetRightToLeft default False;
    property ShowCaption: Boolean read FShowCaption write SetShowCaption default True;
    property ShowCollapseButton: Boolean read FShowCollapseButton write SetShowCollapseButton default True;
    /// <summary>Office 2016 "Ribbon Display Options" button in the caption row (Auto-hide Ribbon, Show Tabs, Show
    /// Tabs and Commands).</summary>
    property ShowDisplayOptionsButton: Boolean read FShowDisplayOptionsButton write SetShowDisplayOptionsButton
      default False;
    /// <summary>Office 365 chevron at the right end of the body that switches between the classic and the
    /// simplified ribbon.</summary>
    property ShowDisplayModeButton: Boolean read FShowDisplayModeButton write SetShowDisplayModeButton default False;
    property ShowHelpButton: Boolean read FShowHelpButton write SetShowHelpButton default False;
    property ShowKeyTips: Boolean read FShowKeyTips write SetShowKeyTips default True;
    property ShowMode: TFmrRibbonShowMode read FShowMode write SetShowMode default TFmrRibbonShowMode.TabsAndCommands;
    property ShowScreenTips: Boolean read FShowScreenTips write SetShowScreenTips default True;
    property ShowSearchBox: Boolean read FShowSearchBox write SetShowSearchBox default False;
    /// <summary>Headers of the contextual tab groups in the caption row.</summary>
    property ShowTabGroups: Boolean read FShowTabGroups write SetShowTabGroups default True;
    property Size;
    property Theme: string read FThemeName write SetThemeName stored IsThemeNameStored;
    property TouchMode: Boolean read FTouchMode write SetTouchMode default False;
    property Visible;
    property Width;
    property OnApplicationButtonClick: TNotifyEvent read FOnApplicationButtonClick write FOnApplicationButtonClick;
    property OnCustomizeQuickAccessToolbar: TNotifyEvent read FOnCustomizeQAT write FOnCustomizeQAT;
    property OnDisplayModeChanged: TNotifyEvent read FOnDisplayModeChanged write FOnDisplayModeChanged;
    property OnHelpButtonClick: TNotifyEvent read FOnHelpButtonClick write FOnHelpButtonClick;
    property OnMinimizedChanged: TNotifyEvent read FOnMinimizedChanged write FOnMinimizedChanged;
    property OnSearch: TFmrRibbonSearchEvent read FOnSearch write FOnSearch;
    property OnTabChanged: TNotifyEvent read FOnTabChanged write FOnTabChanged;
    property OnTabChanging: TFmrRibbonTabChangingEvent read FOnTabChanging write FOnTabChanging;
  end;

implementation

uses
  System.Character, System.StrUtils, System.Math.Vectors, System.Rtti, System.TypInfo, FMX.Styles, FMX.Menus,
  FMX.Layouts,
  FMR.Ribbon.Fonts.Win, FMR.Ribbon.Customize,
  // Linked for their registrations: galleries and the color gallery work in every application with a ribbon.
  FMR.Ribbon.Gallery, FMR.Ribbon.ColorGallery;

const
  DefaultContextColors: array[0..3] of TAlphaColor = ($FFE8A33D, $FF5B9B4A, $FFB05CC6, $FF3D9FD6);
  CaptionButtonWidth = 46;

function IsVisibleTab(const T: TFmrRibbonTab): Boolean; inline;
begin
  Result := (T <> nil) and not (csDestroying in T.ComponentState) and T.IsShown;
end;

{ TFmrRibbonApplicationButton }

constructor TFmrRibbonApplicationButton.Create(const ARibbon: TFmrRibbon);
begin
  inherited Create;
  FRibbon := ARibbon;
  FVisible := True;
  FKeyTip := 'F';
  FScreenTip := TFmrScreenTip.Create(Self);
end;

destructor TFmrRibbonApplicationButton.Destroy;
begin
  FreeAndNil(FScreenTip);
  inherited;
end;

procedure TFmrRibbonApplicationButton.Assign(Source: TPersistent);
begin
  if Source is TFmrRibbonApplicationButton then
  begin
    FVisible := TFmrRibbonApplicationButton(Source).FVisible;
    FCaption := TFmrRibbonApplicationButton(Source).FCaption;
    FKeyTip := TFmrRibbonApplicationButton(Source).FKeyTip;
    FScreenTip.Assign(TFmrRibbonApplicationButton(Source).FScreenTip);
    Changed;
  end
  else
    inherited;
end;

function TFmrRibbonApplicationButton.GetOwner: TPersistent;
begin
  Result := FRibbon;
end;

procedure TFmrRibbonApplicationButton.Changed;
begin
  if FRibbon <> nil then
    FRibbon.InvalidateStructure;
end;

function TFmrRibbonApplicationButton.DisplayCaption: string;
begin
  if FCaption <> '' then
    Result := FCaption
  else
    Result := FmrStr(TFmrStringId.AppMenuFile);
end;

function TFmrRibbonApplicationButton.IsCaptionStored: Boolean;
begin
  Result := FCaption <> '';
end;

function TFmrRibbonApplicationButton.IsKeyTipStored: Boolean;
begin
  Result := FKeyTip <> 'F';
end;

procedure TFmrRibbonApplicationButton.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed;
  end;
end;

procedure TFmrRibbonApplicationButton.SetKeyTip(const Value: string);
begin
  FKeyTip := Value;
end;

procedure TFmrRibbonApplicationButton.SetScreenTip(const Value: TFmrScreenTip);
begin
  FScreenTip.Assign(Value);
end;

procedure TFmrRibbonApplicationButton.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed;
  end;
end;

{ TFmrSysButtonElement }

function TFmrSysButtonElement.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := FKind in [TFmrSysButtonKind.QATCustomize, TFmrSysButtonKind.QATOverflow,
    TFmrSysButtonKind.SimplifiedOverflow, TFmrSysButtonKind.DisplayOptions, TFmrSysButtonKind.AutoHideShow];
end;

procedure TFmrSysButtonElement.Execute(const APart: TFmrElementPart);
begin
  FRibbon.SysButtonExecute(Self, False);
end;

procedure TFmrSysButtonElement.Paint(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  S: TFmrPartState;
  Col: TAlphaColor;
  R: TRectF;
begin
  if not Visible then
    Exit;
  P := Painter;
  S := PartState(TFmrElementPart.Main);
  R := Bounds;
  Col := P.Theme.Colors[TFmrToken.GlyphTint];
  case FKind of
    TFmrSysButtonKind.ScrollLeft, TFmrSysButtonKind.TabScrollLeft:
      P.DrawScrollButton(ACanvas, R, TFmrArrowDirection.Left, S);
    TFmrSysButtonKind.ScrollRight, TFmrSysButtonKind.TabScrollRight:
      P.DrawScrollButton(ACanvas, R, TFmrArrowDirection.Right, S);
    TFmrSysButtonKind.DisplayOptions, TFmrSysButtonKind.AutoHideShow:
      begin
        // Caption-style buttons next to the window buttons (Office 2016).
        if FRibbon.FDroppedElement = Self then
          S := TFmrPartState.Pressed;
        P.DrawCaptionStyleButton(ACanvas, R, S);
        Col := P.Theme.Colors[TFmrToken.CaptionButtonGlyph];
        if not FRibbon.FrameActive and (S = TFmrPartState.Normal) then
          Col := P.Theme.Colors[TFmrToken.CaptionTextInactive];
        if FKind = TFmrSysButtonKind.DisplayOptions then
          P.DrawDisplayOptionsGlyph(ACanvas, R, Col)
        else
          P.DrawCaptionGlyph(ACanvas, R, TFmrCaptionGlyph.More, Col);
      end;
    TFmrSysButtonKind.DisplayMode:
      begin
        P.DrawButton(ACanvas, R, S);
        P.DrawSwitchChevron(ACanvas, R, FRibbon.FDisplayMode = TFmrRibbonDisplayMode.Classic, Col);
      end;
  else
    begin
      P.DrawButton(ACanvas, R, S);
      case FKind of
        TFmrSysButtonKind.CollapseRibbon:
          if FRibbon.IsCollapsed then
            P.Arrow(ACanvas, PointF(R.CenterPoint.X, R.CenterPoint.Y), TFmrArrowDirection.Down, Col, 8)
          else
            P.Arrow(ACanvas, PointF(R.CenterPoint.X, R.CenterPoint.Y), TFmrArrowDirection.Up, Col, 8);
        TFmrSysButtonKind.Help:
          P.DrawCaptionGlyph(ACanvas, R, TFmrCaptionGlyph.Help, Col);
        TFmrSysButtonKind.QATCustomize:
          P.DrawCustomizeGlyph(ACanvas, R, Col);
        TFmrSysButtonKind.QATOverflow:
          P.DrawChevron(ACanvas, R, Col);
        TFmrSysButtonKind.SimplifiedOverflow:
          P.DrawCaptionGlyph(ACanvas, R, TFmrCaptionGlyph.More, Col);
      end;
    end;
  end;
  PaintFocus(ACanvas);
end;

function TFmrSysButtonElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := System.Default(TFmrScreenTipInfo);
  case FKind of
    TFmrSysButtonKind.CollapseRibbon:
      if FRibbon.IsCollapsed then
        AInfo.Header := FmrStr(TFmrStringId.RibbonPin)
      else
        AInfo.Header := FmrStr(TFmrStringId.RibbonCollapse);
    TFmrSysButtonKind.Help:
      AInfo.Header := FmrStr(TFmrStringId.CommonHelp);
    TFmrSysButtonKind.QATCustomize:
      AInfo.Header := FmrStr(TFmrStringId.QATCustomize);
    TFmrSysButtonKind.QATOverflow, TFmrSysButtonKind.SimplifiedOverflow:
      AInfo.Header := FmrStr(TFmrStringId.RibbonMoreOptions);
    TFmrSysButtonKind.ScrollLeft, TFmrSysButtonKind.TabScrollLeft:
      AInfo.Header := FmrStr(TFmrStringId.RibbonScrollLeft);
    TFmrSysButtonKind.ScrollRight, TFmrSysButtonKind.TabScrollRight:
      AInfo.Header := FmrStr(TFmrStringId.RibbonScrollRight);
    TFmrSysButtonKind.DisplayOptions:
      AInfo.Header := FmrStr(TFmrStringId.RibbonDisplayOptions);
    TFmrSysButtonKind.AutoHideShow:
      AInfo.Header := FmrStr(TFmrStringId.RibbonShowRibbon);
    TFmrSysButtonKind.DisplayMode:
      if FRibbon.FDisplayMode = TFmrRibbonDisplayMode.Classic then
        AInfo.Header := FmrStr(TFmrStringId.RibbonSwitchToSimplified)
      else
        AInfo.Header := FmrStr(TFmrStringId.RibbonSwitchToClassic);
  end;
  if FKind = TFmrSysButtonKind.CollapseRibbon then
    AInfo.Shortcut := FmrShortCutText(FmrShortCut(vkF1, [ssCtrl]));
  Result := AInfo.Header <> '';
end;

function TFmrSysButtonElement.KeyTipCaption: string;
begin
  case FKind of
    TFmrSysButtonKind.QATCustomize: Result := 'Customize';
    TFmrSysButtonKind.SimplifiedOverflow, TFmrSysButtonKind.QATOverflow: Result := 'More';
    TFmrSysButtonKind.CollapseRibbon: Result := 'Collapse';
    TFmrSysButtonKind.DisplayMode: Result := 'Switch';
    TFmrSysButtonKind.DisplayOptions: Result := 'Display';
    TFmrSysButtonKind.AutoHideShow: Result := 'Ribbon';
  else
    Result := '';
  end;
end;

{ TFmrTabElement }

function TFmrTabElement.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := True;
end;

procedure TFmrTabElement.Paint(const ACanvas: TCanvas);
var
  Color: TAlphaColor;
  MinimizedLook: Boolean;
begin
  if not Visible or (FTab = nil) then
    Exit;
  Color := 0;
  if FTab.ContextGroup <> nil then
    Color := FRibbon.ContextColor(FTab.ContextGroup);
  MinimizedLook := FRibbon.IsCollapsed and (FRibbon.FMinimizedPopup = nil) and (FRibbon.FAutoHidePopup = nil);
  Painter.DrawTab(ACanvas, Bounds, FmrStripAccel(FTab.DisplayCaption), (HotPart <> TFmrElementPart.None) or Focused,
    FTab = FRibbon.FActiveTab, FRibbon.AbsoluteEnabled, MinimizedLook, Color);
  if Focused then
    PaintFocus(ACanvas);
end;

function TFmrTabElement.KeyTipCaption: string;
begin
  Result := FTab.DisplayCaption;
end;

function TFmrTabElement.ExplicitKeyTip: string;
begin
  Result := FTab.KeyTip;
end;

function TFmrTabElement.KeyTipAnchor: TPointF;
begin
  Result := PointF(Bounds.CenterPoint.X, Bounds.Bottom);
end;

{ TFmrAppButtonElement }

function TFmrAppButtonElement.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := True;
end;

procedure TFmrAppButtonElement.Paint(const ACanvas: TCanvas);
begin
  if Visible then
    Painter.DrawAppButton(ACanvas, Bounds, FRibbon.FAppButton.DisplayCaption, PartState(TFmrElementPart.Main));
end;

function TFmrAppButtonElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
var
  Tip: TFmrScreenTip;
begin
  AInfo := System.Default(TFmrScreenTipInfo);
  Tip := FRibbon.FAppButton.ScreenTip;
  AInfo.Header := Tip.Header;
  AInfo.Description := Tip.Description;
  AInfo.Footer := Tip.Footer;
  AInfo.ShowFooter := Tip.ShowFooter;
  Result := not Tip.IsEmpty;
end;

function TFmrAppButtonElement.KeyTipCaption: string;
begin
  Result := FRibbon.FAppButton.DisplayCaption;
end;

function TFmrAppButtonElement.ExplicitKeyTip: string;
begin
  Result := FRibbon.FAppButton.KeyTip;
end;

function TFmrAppButtonElement.KeyTipAnchor: TPointF;
begin
  Result := PointF(Bounds.CenterPoint.X, Bounds.Bottom);
end;

{ TFmrCollapsedGroupElement }

function TFmrCollapsedGroupElement.OpensOnPress(const APart: TFmrElementPart): Boolean;
begin
  Result := True;
end;

procedure TFmrCollapsedGroupElement.Paint(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  R, GR: TRectF;
  G: TFmrImageSource;
  I: Integer;
  S: TFmrPartState;
  TextColor, ArrowColor: TAlphaColor;
  Y, LineH, W2, X: Single;
begin
  if not Visible then
    Exit;
  P := Painter;
  M := P.Metrics;
  R := Bounds;
  S := PartState(TFmrElementPart.Main);
  P.DrawCollapsedGroup(ACanvas, R, S);
  G := nil;
  if not FGroup.Glyph.IsEmpty(Images) then
    G := FGroup.Glyph
  else
    for I := 0 to FGroup.ItemLinks.Count - 1 do
      if FGroup.ItemLinks[I].IsVisible then
      begin
        if not FGroup.ItemLinks[I].Item.LargeGlyph.IsEmpty(Images) then
          G := FGroup.ItemLinks[I].Item.LargeGlyph
        else if not FGroup.ItemLinks[I].Item.Glyph.IsEmpty(Images) then
          G := FGroup.ItemLinks[I].Item.Glyph;
        if G <> nil then
          Break;
      end;
  GR := RectF(0, 0, M.LargeGlyphSize, M.LargeGlyphSize);
  GR.Offset(Round(R.CenterPoint.X - M.LargeGlyphSize / 2), R.Top + 5);
  if P.Theme.Style.GroupFrame = TFmrGroupFrame.Boxed then
    P.DrawButton(ACanvas, GR, TFmrPartState.Checked);
  if G <> nil then
  begin
    if P.Theme.Style.GroupFrame = TFmrGroupFrame.Boxed then
      GR.Inflate(-6, -6);
    FmrDrawImage(ACanvas, G, GR, 1, P.GlyphTint(TFmrPartState.Normal), Images);
  end;
  TextColor := P.ButtonTextColor(TFmrPartState.Normal);
  ArrowColor := P.Theme.Colors[TFmrToken.ButtonArrow];
  if FLine1 = '' then
    FmrSplitLargeCaption(P, FmrStripAccel(FGroup.DisplayCaption), M.ArrowSize + 4, FLine1, FLine2);
  LineH := Ceil(P.TextSize('Wg').Height);
  Y := R.Top + 5 + M.LargeGlyphSize + 4;
  P.TextEx(ACanvas, RectF(R.Left + 2, Y, R.Right - 2, Y + LineH), FLine1, TextColor, TTextAlign.Center,
    TTextAlign.Center, 0, False, False);
  Y := Y + LineH;
  if FLine2 <> '' then
  begin
    W2 := P.TextWidth(FLine2) + 4 + M.ArrowSize;
    X := R.CenterPoint.X - W2 / 2;
    P.Text(ACanvas, RectF(X, Y, X + W2 - M.ArrowSize - 4, Y + LineH), FLine2, TextColor, TTextAlign.Leading,
      TTextAlign.Center);
    P.Arrow(ACanvas, PointF(X + W2 - M.ArrowSize / 2, Y + LineH / 2 + 1), TFmrArrowDirection.Down, ArrowColor);
  end
  else
    P.Arrow(ACanvas, PointF(R.CenterPoint.X, Y + LineH / 2 + 1), TFmrArrowDirection.Down, ArrowColor);
  PaintFocus(ACanvas);
end;

function TFmrCollapsedGroupElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := System.Default(TFmrScreenTipInfo);
  AInfo.Header := FmrStripAccel(FGroup.DisplayCaption);
  Result := True;
end;

function TFmrCollapsedGroupElement.KeyTipCaption: string;
begin
  Result := FGroup.DisplayCaption;
end;

function TFmrCollapsedGroupElement.ExplicitKeyTip: string;
begin
  Result := FGroup.KeyTip;
end;

{ TFmrLauncherElement }

procedure TFmrLauncherElement.Execute(const APart: TFmrElementPart);
var
  G: TFmrRibbonGroup;
begin
  G := FGroup;
  Host.ElementExecuted(Self);
  G.DialogLauncherClick;
end;

procedure TFmrLauncherElement.Paint(const ACanvas: TCanvas);
begin
  if Visible then
    Painter.DrawGroupLauncher(ACanvas, Bounds, PartState(TFmrElementPart.Main));
end;

function TFmrLauncherElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := System.Default(TFmrScreenTipInfo);
  AInfo.Header := FmrStripAccel(FGroup.DisplayCaption);
  AInfo.Description := FmrStr(TFmrStringId.RibbonDialogLauncher);
  Result := True;
end;

function TFmrLauncherElement.KeyTipCaption: string;
begin
  Result := FGroup.DisplayCaption + ' ' + FmrStr(TFmrStringId.RibbonDialogLauncher);
end;

function TFmrLauncherElement.ExplicitKeyTip: string;
begin
  Result := FGroup.DialogLauncherKeyTip;
end;

{ TFmrRibbonPart }

constructor TFmrRibbonPart.Create(const ARibbon: TFmrRibbon);
begin
  inherited Create(ARibbon);
  FRibbon := ARibbon;
  Stored := False;
  Locked := True;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
  // Design time: a part in the frame host (outside the ribbon) takes the mouse for the ribbon (ObjectAtPoint).
  FDesignInteractive := csDesigning in ComponentState;
  SetAcceptsControls(False);
  FTracker := TFmrElementTracker.Create(Self,
    function(const P: TPointF): TFmrElement
    begin
      Result := FindElement(P);
    end);
  FTracker.OnHotChanged := TrackerHotChanged;
end;

destructor TFmrRibbonPart.Destroy;
begin
  FreeAndNil(FTracker);
  inherited;
end;

function TFmrRibbonPart.GetPainter: TFmrRibbonPainter;
begin
  Result := FRibbon.FPainter;
end;

function TFmrRibbonPart.GetImages: TCustomImageList;
begin
  if FRibbon.FBarManager <> nil then
    Result := FRibbon.FBarManager.Images
  else
    Result := nil;
end;

function TFmrRibbonPart.GetHostControl: TControl;
begin
  Result := Self;
end;

procedure TFmrRibbonPart.InvalidateElement(const AElement: TFmrElement);
var
  R: TRectF;
begin
  if (FRibbon = nil) or FRibbon.FDestroying then
    Exit;
  R := PhysicalRect(AElement.Bounds);
  R.Inflate(2, 2);
  InvalidateRect(R);
  if (AElement = FRibbon.FAppElement) and (FRibbon.FPainter.Theme.Style.AppButton = TFmrAppButtonShape.Orb) and
    (FRibbon.FCaptionBar <> nil) then
    FRibbon.FCaptionBar.Repaint;
end;

procedure TFmrRibbonPart.ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean);
begin
  FRibbon.ShowDropDown(AElement, Self, AByKeyboard);
end;

procedure TFmrRibbonPart.ElementExecuted(const AElement: TFmrElement);
begin
  FRibbon.FScreenTips.Cancel;
  if FRibbon.KeyTipsVisible then
    FRibbon.HideKeyTips;
  if (FRibbon.FGroupPopup <> nil) or (FRibbon.FMinimizedPopup <> nil) or (FRibbon.FAutoHidePopup <> nil) then
    FRibbon.ClosePopups;
end;

function TFmrRibbonPart.IsElementDroppedDown(const AElement: TFmrElement): Boolean;
begin
  Result := (AElement <> nil) and (AElement = FRibbon.FDroppedElement);
end;

function TFmrRibbonPart.FindElement(const P: TPointF): TFmrElement;
begin
  Result := nil;
end;

procedure TFmrRibbonPart.PaintPart(const ACanvas: TCanvas);
begin
end;

function TFmrRibbonPart.ScreenTipAnchor(const AElement: TFmrElement): TRectF;
var
  TL, BR: TPointF;
  R: TRectF;
begin
  R := PhysicalRect(AElement.Bounds);
  TL := LocalToScreen(R.TopLeft);
  BR := LocalToScreen(R.BottomRight);
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

function TFmrRibbonPart.IsMirrored: Boolean;
begin
  Result := (FRibbon <> nil) and not FRibbon.FDestroying and FRibbon.EffectiveRightToLeft;
end;

function TFmrRibbonPart.Logical(const X, Y: Single): TPointF;
begin
  if IsMirrored then
    Result := PointF(Width - X, Y)
  else
    Result := PointF(X, Y);
end;

function TFmrRibbonPart.PhysicalRect(const R: TRectF): TRectF;
begin
  if IsMirrored then
    Result := FmrMirrorRect(R, Width)
  else
    Result := R;
end;

function TFmrRibbonPart.KeepClickWhenClosingPopups(const P: TPointF): Boolean;
begin
  Result := False;
end;

procedure TFmrRibbonPart.TrackerHotChanged(Sender: TObject);
var
  E: TFmrElement;
begin
  if (FRibbon = nil) or not FRibbon.FShowScreenTips or (csDesigning in ComponentState) then
    Exit;
  E := FTracker.Hot;
  if (E <> nil) and (FTracker.Pressed = nil) and not FRibbon.KeyTipsVisible then
    FRibbon.FScreenTips.Hover(E, ScreenTipAnchor(E), GetPainter, FRibbon.OwnerForm)
  else
    FRibbon.FScreenTips.Hover(nil, TRectF.Empty, GetPainter, FRibbon.OwnerForm);
end;

type
  /// The frame host paints the non-client strip with TCanvas.Offset only while an FMX drop-down of one of its
  /// controls is open (Docs\FRAME.md, "Coordinates while painting"); TCanvasSaveState would then apply the offset a
  /// second time after every RestoreState. The parts fold a non-zero offset into the matrix while they paint; in
  /// every other case the offset is zero and nothing happens.
  TFmrCanvasOffsetGuard = record
    Saved: TPointF;
    procedure Enter(const ACanvas: TCanvas);
    procedure Leave(const ACanvas: TCanvas);
  end;

procedure TFmrCanvasOffsetGuard.Enter(const ACanvas: TCanvas);
var
  M: TMatrix;
begin
  Saved := ACanvas.Offset;
  if not Saved.IsZero then
  begin
    M := ACanvas.Matrix;
    ACanvas.Offset := TPointF.Zero;
    ACanvas.SetMatrix(M);
  end;
end;

procedure TFmrCanvasOffsetGuard.Leave(const ACanvas: TCanvas);
begin
  if not Saved.IsZero then
    ACanvas.Offset := Saved;
end;

procedure TFmrRibbonPart.Paint;
var
  Guard: TFmrCanvasOffsetGuard;
  State: TCanvasSaveState;
begin
  if (FRibbon = nil) or (FRibbon.FPainter = nil) then
    Exit;
  if not FRibbon.FRebuilding then
  begin
    // Invalidations made while painting are lost in the non-client host: the next idle repaints the parts.
    FRibbon.FPainting := True;
    try
      FRibbon.EnsureAll;
    finally
      FRibbon.FPainting := False;
    end;
  end;
  Guard.Enter(Canvas);
  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(LocalRect);
    if IsMirrored then
      FmrMirrorCanvas(Canvas, Width);
    PaintPart(Canvas);
  finally
    Canvas.RestoreState(State);
    Guard.Leave(Canvas);
  end;
end;

procedure TFmrRibbonPart.AfterPaint;
begin
  inherited;
  if (FRibbon <> nil) and (csDesigning in ComponentState) and not FRibbon.FDestroying then
    FRibbon.PaintDesignFeedback(Self, Canvas);
end;

function TFmrRibbonPart.ObjectAtPoint(AScreenPoint: TPointF): IControl;
var
  P: TPointF;
begin
  if not (csDesigning in ComponentState) or (FRibbon = nil) then
    Exit(inherited ObjectAtPoint(AScreenPoint));
  // The form designer gives the mouse to the design-interactive control under it: the ribbon itself, or this part
  // when it lies in the frame host. Editor controls (not owned by the form) are never hit at design time.
  Result := nil;
  if (Parent = FRibbon) or not ShouldTestMouseHits then
    Exit;
  P := AScreenPoint;
  if Scene <> nil then
    P := Scene.ScreenToLocal(P);
  if PointInObject(P.X, P.Y) then
    Result := Self;
end;

function TFmrRibbonPart.FindTarget(P: TPointF; const Data: TDragObject): IControl;
begin
  if csDesigning in ComponentState then
    Result := nil
  else
    Result := inherited FindTarget(P, Data);
end;

procedure TFmrRibbonPart.PaintKeyTips(const ACanvas: TCanvas);
var
  I: Integer;
  K: TFmrRibbon.TKeyTipEntryRec;
  A, P: TPointF;
  Sz: TSizeF;
  R: TRectF;
  HostCtl, Disp: TControl;
begin
  if (FRibbon = nil) or (FRibbon.FKeyTipLevel = TFmrKeyTipLevel.None) then
    Exit;
  for I := 0 to FRibbon.FKeyTips.Count - 1 do
  begin
    K := FRibbon.FKeyTips[I];
    if (K.Element = nil) or (K.Element.Host = nil) or not K.Element.Visible or
      not FRibbon.FKeyTipMatcher.IsCandidate(I) then
      Continue;
    // Like Office, the tips of the tabs hang below the tab row (top of the body) and the tips of the quick access
    // toolbar below the caption row (top of the tab row).
    HostCtl := K.Element.Host.GetHostControl;
    Disp := HostCtl;
    if (HostCtl = FRibbon.FTabBar) and (FRibbon.FTabTipOverlay <> nil) and FRibbon.FTabTipOverlay.Visible then
      Continue // minimized ribbon: below the tab row (TFmrTabTipOverlay)
    else if (HostCtl = FRibbon.FTabBar) and (FRibbon.FBody <> nil) and FRibbon.FBody.Visible and
      ((FRibbon.FBody.Parent = FRibbon) or (FRibbon.FBody.Parent = HostCtl.Parent)) then
      Disp := FRibbon.FBody
    else if (HostCtl = FRibbon.FCaptionBar) and (FRibbon.FTabBar <> nil) and FRibbon.FTabBar.Visible then
      Disp := FRibbon.FTabBar;
    if Disp <> Self then
      Continue;
    Sz := GetPainter.KeyTipSize(K.Tip);
    if Disp <> HostCtl then
    begin
      // Logical X in the host -> physical -> screen -> physical here -> logical here.
      P := PointF(K.Element.Bounds.CenterPoint.X, 0);
      if (HostCtl is TFmrRibbonPart) and TFmrRibbonPart(HostCtl).IsMirrored then
        P.X := HostCtl.Width - P.X;
      P := ScreenToLocal(HostCtl.LocalToScreen(P));
      if IsMirrored then
        P.X := Width - P.X;
      A := PointF(P.X, Sz.Height / 2 + 1);
    end
    else
      A := K.Element.KeyTipAnchor;
    R := RectF(A.X - Sz.Width / 2, A.Y - Sz.Height / 2, A.X + Sz.Width / 2, A.Y + Sz.Height / 2);
    if R.Bottom > Height - 2 then
      R.Offset(0, Height - 2 - R.Bottom);
    if R.Top < 1 then
      R.Offset(0, 1 - R.Top);
    if R.Left < 2 then
      R.Offset(2 - R.Left, 0);
    if R.Right > Width - 2 then
      R.Offset(Width - 2 - R.Right, 0);
    R := RectF(Round(R.Left), Round(R.Top), Round(R.Left) + R.Width, Round(R.Top) + R.Height);
    GetPainter.DrawKeyTip(ACanvas, R, K.Tip, K.Element.IsEnabled);
  end;
end;

type
  /// Paints the key tips of a part above its children (editor controls).
  TFmrTipOverlay = class(TControl)
  private
    [Weak] FPart: TFmrRibbonPart;
  protected
    procedure Paint; override;
  end;

procedure TFmrTipOverlay.Paint;
var
  Guard: TFmrCanvasOffsetGuard;
  State: TCanvasSaveState;
begin
  if FPart = nil then
    Exit;
  Guard.Enter(Canvas);
  State := Canvas.SaveState;
  try
    if FPart.IsMirrored then
      FmrMirrorCanvas(Canvas, Width);
    FPart.PaintKeyTips(Canvas);
  finally
    Canvas.RestoreState(State);
    Guard.Leave(Canvas);
  end;
end;

type
  /// Key tips of the tabs while the body is hidden (minimized ribbon): a control on the form right below the tab
  /// row, so the badges do not cover the tab captions (Office shows them there too).
  TFmrTabTipOverlay = class(TControl)
  private
    [Weak] FRibbon: TFmrRibbon;
  protected
    procedure Paint; override;
  end;

procedure TFmrTabTipOverlay.Paint;
var
  I: Integer;
  K: TFmrRibbon.TKeyTipEntryRec;
  Bar: TFmrRibbonTabBar;
  Painter: TFmrRibbonPainter;
  P: TPointF;
  Sz: TSizeF;
  R: TRectF;
begin
  if (FRibbon = nil) or FRibbon.FDestroying or (FRibbon.FKeyTipLevel = TFmrKeyTipLevel.None) or
    (FRibbon.FTabBar = nil) then
    Exit;
  Bar := FRibbon.FTabBar;
  Painter := Bar.GetPainter;
  for I := 0 to FRibbon.FKeyTips.Count - 1 do
  begin
    K := FRibbon.FKeyTips[I];
    if (K.Element = nil) or (K.Element.Host = nil) or (K.Element.Host.GetHostControl <> Bar) or
      not K.Element.Visible or not FRibbon.FKeyTipMatcher.IsCandidate(I) then
      Continue;
    Sz := Painter.KeyTipSize(K.Tip);
    // Logical X in the tab row -> physical -> screen -> here.
    P := PointF(K.Element.Bounds.CenterPoint.X, 0);
    if Bar.IsMirrored then
      P.X := Bar.Width - P.X;
    P := ScreenToLocal(Bar.LocalToScreen(P));
    R := RectF(P.X - Sz.Width / 2, 1, P.X + Sz.Width / 2, 1 + Sz.Height);
    if R.Left < 2 then
      R.Offset(2 - R.Left, 0);
    if R.Right > Width - 2 then
      R.Offset(Width - 2 - R.Right, 0);
    R := RectF(Round(R.Left), R.Top, Round(R.Left) + R.Width, R.Bottom);
    Painter.DrawKeyTip(Canvas, R, K.Tip, K.Element.IsEnabled);
  end;
end;

procedure TFmrRibbonPart.UpdateTipOverlay;
var
  Show: Boolean;
begin
  Show := (FRibbon <> nil) and (FRibbon.FKeyTipLevel <> TFmrKeyTipLevel.None) and not FRibbon.FDestroying;
  if Show and (FTipOverlay = nil) then
  begin
    FTipOverlay := TFmrTipOverlay.Create(nil);
    TFmrTipOverlay(FTipOverlay).FPart := Self;
    FTipOverlay.Stored := False;
    FTipOverlay.Locked := True;
    FTipOverlay.HitTest := False;
    FTipOverlay.Parent := Self;
    FTipOverlay.Align := TAlignLayout.Contents;
  end;
  if FTipOverlay <> nil then
  begin
    FTipOverlay.Visible := Show;
    if Show then
    begin
      FTipOverlay.BringToFront;
      FTipOverlay.Repaint;
    end;
  end;
end;

procedure TFmrRibbonPart.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if FRibbon = nil then
    Exit;
  if csDesigning in ComponentState then
  begin
    // A part in the frame host at design time: the ribbon handles the mouse (ribbon coordinates).
    FRibbon.DesignMouseEvent(TFmrRibbon.TDesignMouseEvent.Move, TMouseButton.mbLeft, Shift,
      FRibbon.ScreenToLocal(LocalToScreen(PointF(X, Y))));
    Exit;
  end;
  FRibbon.EnsureAll;
  FTracker.MouseMove(Logical(X, Y));
end;

procedure TFmrRibbonPart.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  E: TFmrElement;
  P: TPointF;
  Item: TFmrBarItem;
begin
  inherited;
  if FRibbon = nil then
    Exit;
  if csDesigning in ComponentState then
  begin
    FRibbon.DesignMouseEvent(TFmrRibbon.TDesignMouseEvent.Down, Button, Shift,
      FRibbon.ScreenToLocal(LocalToScreen(PointF(X, Y))));
    Exit;
  end;
  FRibbon.EnsureAll;
  FRibbon.FScreenTips.Cancel;
  FRibbon.FAltArmed := False;
  P := Logical(X, Y);
  if FRibbon.KeyTipsVisible then
    FRibbon.HideKeyTips;
  if FmrPopups.IsOpen and (FmrPopups.PopupOf(Self) = nil) then
  begin
    if not KeepClickWhenClosingPopups(P) then
    begin
      FRibbon.ClosePopups;
      FmrPopups.CloseAll;
      FTracker.SuppressUntilUp;
      Exit;
    end;
  end;
  if Button = TMouseButton.mbRight then
  begin
    E := FindElement(P);
    Item := nil;
    if E is TFmrItemView then
      Item := TFmrItemView(E).Item;
    FRibbon.ShowRibbonContextMenu(Item, LocalToScreen(PointF(X, Y)));
    Exit;
  end;
  FTracker.MouseDown(Button, P);
end;

procedure TFmrRibbonPart.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if FRibbon = nil then
    Exit;
  if csDesigning in ComponentState then
  begin
    FRibbon.DesignMouseEvent(TFmrRibbon.TDesignMouseEvent.Up, Button, Shift,
      FRibbon.ScreenToLocal(LocalToScreen(PointF(X, Y))));
    Exit;
  end;
  FTracker.MouseUp(Button, Logical(X, Y));
end;

/// Gives the wheel to the drop-down list of an open popup form (a combo box list): returns True when a popup form
/// is visible, whether or not its list could scroll.
function RouteWheelToOpenPopup(const AShift: TShiftState; const AWheelDelta: Integer): Boolean;

  function FindScrollBox(const AObject: TFmxObject): TCustomScrollBox;
  var
    I: Integer;
  begin
    if (AObject is TCustomScrollBox) and TCustomScrollBox(AObject).Visible then
      Exit(TCustomScrollBox(AObject));
    for I := 0 to AObject.ChildrenCount - 1 do
    begin
      Result := FindScrollBox(AObject.Children[I]);
      if Result <> nil then
        Exit;
    end;
    Result := nil;
  end;

var
  I: Integer;
  F: TCommonCustomForm;
  Box: TCustomScrollBox;
  Handled: Boolean;
begin
  Result := False;
  if Screen = nil then
    Exit;
  for I := Screen.PopupFormCount - 1 downto 0 do
  begin
    F := Screen.PopupForms[I];
    if (F = nil) or not F.Visible then
      Continue;
    Result := True;
    Box := FindScrollBox(F);
    if Box <> nil then
    begin
      Handled := False;
      (Box as IControl).MouseWheel(AShift, AWheelDelta, Handled);
      Exit;
    end;
  end;
end;

procedure TFmrRibbonPart.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  // FMX offers the wheel to the popup forms only when the mouse is over them; otherwise (the mouse still over the
  // combo box that opened its list, or a list already scrolled to its end) the main form gets it and the ribbon
  // would switch tabs under an open drop-down. Like Office, the wheel scrolls the open list instead.
  if not (csDesigning in ComponentState) and RouteWheelToOpenPopup(Shift, WheelDelta) then
  begin
    Handled := True;
    Exit;
  end;
  inherited;
  // The element under the mouse first (an in-ribbon gallery scrolls its rows).
  if not Handled and not (csDesigning in ComponentState) and (FTracker <> nil) and (FTracker.Hot <> nil) and
    FTracker.Hot.Visible and FTracker.Hot.MouseWheel(WheelDelta) then
    Handled := True;
end;

procedure TFmrRibbonPart.DoMouseLeave;
begin
  inherited;
  if FTracker <> nil then
    FTracker.MouseLeave;
  if (FRibbon <> nil) and (FRibbon.FScreenTips <> nil) then
    FRibbon.FScreenTips.Hover(nil, TRectF.Empty, GetPainter, FRibbon.OwnerForm);
end;

procedure TFmrRibbonPart.Resize;
begin
  inherited;
  if (FRibbon <> nil) and not FRibbon.FDestroying then
    FRibbon.InvalidateArrange;
end;

{ TFmrRibbonCaptionButton }

constructor TFmrRibbonCaptionButton.CreateButton(const ARibbon: TFmrRibbon; const AKind: TFmrHitArea);
begin
  inherited Create(ARibbon);
  FRibbon := ARibbon;
  FKind := AKind;
  FActive := True;
  Stored := False;
  Locked := True;
  HitTest := True;
  CanFocus := False;
  AutoCapture := True;
  Width := CaptionButtonWidth;
end;

function TFmrRibbonCaptionButton.GetFrameButtonKind: TFmrHitArea;
begin
  Result := FKind;
end;

procedure TFmrRibbonCaptionButton.SetFrameButtonState(const AHot, APressed: Boolean);
begin
  FFrameDriven := True;
  if (FHot <> AHot) or (FDown <> APressed) then
  begin
    FHot := AHot;
    FDown := APressed;
    Repaint;
  end;
end;

function TFmrRibbonCaptionButton.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
begin
  Result := FKind;
end;

procedure TFmrRibbonCaptionButton.FrameStateChanged(const AState: TFmrFrameState);
begin
  if (FActive <> AState.Active) or (FMaximized <> AState.Maximized) then
  begin
    FActive := AState.Active;
    FMaximized := AState.Maximized;
    if AState.Minimized then
    begin
      FHot := False;
      FDown := False;
    end;
    Repaint;
  end;
end;

procedure TFmrRibbonCaptionButton.Paint;
var
  Glyph: TFmrCaptionGlyph;
  S: TFmrPartState;
  P: TFmrRibbonPainter;
begin
  if (FRibbon = nil) or (FRibbon.FPainter = nil) then
    Exit;
  P := FRibbon.FPainter;
  case FKind of
    TFmrHitArea.MinButton: Glyph := TFmrCaptionGlyph.Minimize;
    TFmrHitArea.MaxButton:
      if FMaximized then
        Glyph := TFmrCaptionGlyph.Restore
      else
        Glyph := TFmrCaptionGlyph.Maximize;
    TFmrHitArea.HelpButton: Glyph := TFmrCaptionGlyph.Help;
  else
    Glyph := TFmrCaptionGlyph.Close;
  end;
  if FDown then
    S := TFmrPartState.Pressed
  else if FHot then
    S := TFmrPartState.Hot
  else
    S := TFmrPartState.Normal;
  P.DrawCaptionButton(Canvas, LocalRect, Glyph, S, FActive);
end;

procedure TFmrRibbonCaptionButton.DoMouseEnter;
begin
  inherited;
  if not FFrameDriven then
  begin
    FHot := True;
    Repaint;
  end;
end;

procedure TFmrRibbonCaptionButton.DoMouseLeave;
begin
  inherited;
  if not FFrameDriven then
  begin
    FHot := False;
    FDown := False;
    Repaint;
  end;
end;

procedure TFmrRibbonCaptionButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and not FFrameDriven then
  begin
    FDown := True;
    Repaint;
  end;
end;

procedure TFmrRibbonCaptionButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  WasDown: Boolean;
begin
  inherited;
  if FFrameDriven then
    Exit;
  WasDown := FDown;
  FDown := False;
  Repaint;
  if WasDown and LocalRect.Contains(PointF(X, Y)) then
    Execute;
end;

procedure TFmrRibbonCaptionButton.Execute;
var
  Host: TFmrFrameHost;
  Form: TCommonCustomForm;
begin
  Host := FmrFindFrameHost(Self);
  if (Host <> nil) and (Host.Commands <> nil) then
  begin
    case FKind of
      TFmrHitArea.MinButton: Host.Commands.Minimize;
      TFmrHitArea.MaxButton: Host.Commands.ToggleMaximize;
      TFmrHitArea.HelpButton: Host.Commands.ShowHelp;
    else
      Host.Commands.CloseForm;
    end;
    Exit;
  end;
  Form := FmrFormOf(Self);
  if Form = nil then
    Exit;
  case FKind of
    TFmrHitArea.MinButton: Form.WindowState := TWindowState.wsMinimized;
    TFmrHitArea.MaxButton:
      if Form.WindowState = TWindowState.wsMaximized then
        Form.WindowState := TWindowState.wsNormal
      else
        Form.WindowState := TWindowState.wsMaximized;
    TFmrHitArea.CloseButton: Form.Close;
  end;
end;

{ TFmrRibbonCaptionBar }

constructor TFmrRibbonCaptionBar.Create(const ARibbon: TFmrRibbon);
begin
  inherited;
  FButtons := TList<TFmrRibbonCaptionButton>.Create;
end;

destructor TFmrRibbonCaptionBar.Destroy;
begin
  FreeAndNil(FButtons);
  inherited;
end;

function TFmrRibbonCaptionBar.GetPainter: TFmrRibbonPainter;
begin
  Result := FRibbon.FBarPainter;
end;

procedure TFmrRibbonCaptionBar.SearchEditApplyStyle(Sender: TObject);
var
  Obj: TFmxObject;
begin
  // The box is painted by the ribbon; the edit only shows the text.
  Obj := FSearchEdit.FindStyleResource('background');
  if Obj is TControl then
    TControl(Obj).Opacity := 0;
end;

procedure TFmrRibbonCaptionBar.SearchEditChangeTracking(Sender: TObject);
begin
  FRibbon.SearchChanged(FSearchEdit.Text);
end;

procedure TFmrRibbonCaptionBar.SearchEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  case Key of
    vkReturn:
      begin
        FRibbon.SearchExecute;
        Key := 0;
      end;
    vkEscape:
      begin
        FSearchEdit.Text := '';
        FRibbon.ClosePopups;
        Key := 0;
      end;
  end;
end;

function TFmrRibbonCaptionBar.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
var
  LP: TPointF;
begin
  LP := Logical(ALocalPoint.X, ALocalPoint.Y);
  if FindElement(LP) <> nil then
    Result := TFmrHitArea.Client
  else if FRibbon.FShowSearchBox and FSearchRect.Contains(LP) then
    Result := TFmrHitArea.Client
  else
    Result := TFmrHitArea.Caption;
end;

procedure TFmrRibbonCaptionBar.FrameStateChanged(const AState: TFmrFrameState);
begin
  FRibbon.FFrameState := AState;
  FRibbon.UpdateHeights;
  FRibbon.InvalidateArrange;
  Repaint;
  if FRibbon.FTabBar <> nil then
    FRibbon.FTabBar.Repaint;
end;

function TFmrRibbonCaptionBar.FindElement(const P: TPointF): TFmrElement;
var
  V: TFmrItemView;
  E: TFmrSysButtonElement;
  R: TRectF;
begin
  if FRibbon.IsOrb and (FRibbon.FAppElement <> nil) and FRibbon.FAppElement.Visible then
  begin
    R := FRibbon.OrbRect(0);
    if R.Contains(P) and (P.Distance(R.CenterPoint) <= R.Width / 2) then
      Exit(FRibbon.FAppElement);
  end;
  for V in FRibbon.FQATViews do
    if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = Self) and (V.PartAt(P) <> TFmrElementPart.None) then
      Exit(V);
  for E in FRibbon.FCaptionSysElements do
    if E.Visible and E.Bounds.Contains(P) then
      Exit(E);
  Result := nil;
end;

procedure TFmrRibbonCaptionBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  // Double click on the empty caption maximizes (the frame does it in the non-client modes).
  inherited;
  // Auto-hide without a frame: a click at the top of the window shows the ribbon (Office).
  if (Button = TMouseButton.mbLeft) and (FRibbon <> nil) and FRibbon.AutoHideActive and not FRibbon.FBarsInHost and
    (FRibbon.FAutoHidePopup = nil) and not FmrPopups.IsOpen and (FindElement(Logical(X, Y)) = nil) and
    (TThread.GetTickCount - FRibbon.FAutoHideClosedTick > 300) and not (csDesigning in ComponentState) then
    FRibbon.ShowAutoHideRibbon(False);
end;

procedure TFmrRibbonCaptionBar.PaintPart(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  R, G: TRectF;
  Pair: TPair<TFmrRibbonContextGroup, TRectF>;
  V: TFmrItemView;
  E: TFmrSysButtonElement;
  Active: Boolean;
  Color: TAlphaColor;
begin
  P := GetPainter;
  R := LocalRect;
  Active := FRibbon.FrameActive;
  if not FRibbon.FFrameState.Transparent then
    P.DrawCaption(ACanvas, R, Active);
  for Pair in FRibbon.FContextHeaders do
    P.DrawContextGroupHeader(ACanvas, Pair.Value, FmrStripAccel(Pair.Key.DisplayCaption),
      FRibbon.ContextColor(Pair.Key));
  if FRibbon.FShowSearchBox and not FSearchRect.IsEmpty then
  begin
    P.DrawSearchBox(ACanvas, FSearchRect, (FSearchEdit <> nil) and FSearchEdit.IsFocused);
    G := RectF(FSearchRect.Left + 4, FSearchRect.Top, FSearchRect.Left + 24, FSearchRect.Bottom);
    P.DrawSearchGlyph(ACanvas, G, P.Theme.Colors[TFmrToken.SearchBoxPrompt]);
  end;
  if not FTitleRect.IsEmpty then
  begin
    if Active then
      Color := P.Theme.Colors[TFmrToken.CaptionText]
    else
      Color := P.Theme.Colors[TFmrToken.CaptionTextInactive];
    P.TextEx(ACanvas, FTitleRect, FRibbon.TitleText, Color, TTextAlign.Center, TTextAlign.Center,
      P.Metrics.CaptionFontSize, False, False);
  end;
  for V in FRibbon.FQATViews do
    if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = Self) then
      V.Paint(ACanvas);
  for E in FRibbon.FCaptionSysElements do
    E.Paint(ACanvas);
  if FRibbon.IsOrb then
    FRibbon.PaintOrb(ACanvas, 0);
end;

{ TFmrRibbonTabBar }

function TFmrRibbonTabBar.GetPainter: TFmrRibbonPainter;
begin
  Result := FRibbon.FBarPainter;
end;

function TFmrRibbonTabBar.FrameHitTest(const ALocalPoint: TPointF): TFmrHitArea;
begin
  if FindElement(Logical(ALocalPoint.X, ALocalPoint.Y)) <> nil then
    Result := TFmrHitArea.Client
  else
    Result := TFmrHitArea.Caption;
end;

procedure TFmrRibbonTabBar.FrameStateChanged(const AState: TFmrFrameState);
begin
  FRibbon.FFrameState := AState;
  Repaint;
end;

function TFmrRibbonTabBar.FindElement(const P: TPointF): TFmrElement;
var
  T: TFmrTabElement;
  E: TFmrSysButtonElement;
  R: TRectF;
begin
  for E in FRibbon.FTabSysElements do
    if E.Visible and E.Bounds.Contains(P) then
      Exit(E);
  if (FRibbon.FAppElement <> nil) and FRibbon.FAppElement.Visible then
  begin
    if FRibbon.IsOrb then
    begin
      R := FRibbon.OrbRect(FRibbon.TabBarOffset);
      if R.Contains(P) and (P.Distance(R.CenterPoint) <= R.Width / 2) then
        Exit(FRibbon.FAppElement);
    end
    else if FRibbon.FAppElement.Bounds.Contains(P) then
      Exit(FRibbon.FAppElement);
  end;
  for T in FRibbon.FTabElements do
    if T.Visible and T.Bounds.Contains(P) then
      Exit(T);
  Result := nil;
end;

procedure TFmrRibbonTabBar.PaintPart(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  T: TFmrTabElement;
  E: TFmrSysButtonElement;
  State: TCanvasSaveState;
  Clip: TRectF;
begin
  P := GetPainter;
  if not FRibbon.FFrameState.Transparent or not FRibbon.FBarsInHost then
    P.DrawTabRow(ACanvas, LocalRect, FRibbon.FrameActive);
  if (FRibbon.FAppElement <> nil) and FRibbon.FAppElement.Visible and not FRibbon.IsOrb then
    FRibbon.FAppElement.Paint(ACanvas);
  State := ACanvas.SaveState;
  try
    Clip := LocalRect;
    for E in FRibbon.FTabSysElements do
      if E.Visible and (E.Kind = TFmrSysButtonKind.TabScrollLeft) then
        Clip.Left := E.Bounds.Right;
    for E in FRibbon.FTabSysElements do
      if E.Visible and (E.Kind = TFmrSysButtonKind.TabScrollRight) then
        Clip.Right := E.Bounds.Left;
    ACanvas.IntersectClipRect(Clip);
    for T in FRibbon.FTabElements do
      if T.Visible then
        T.Paint(ACanvas);
  finally
    ACanvas.RestoreState(State);
  end;
  for E in FRibbon.FTabSysElements do
    E.Paint(ACanvas);
  if FRibbon.IsOrb then
    FRibbon.PaintOrb(ACanvas, FRibbon.TabBarOffset);
end;

procedure TFmrRibbonTabBar.ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean);
begin
  if AElement is TFmrTabElement then
    FRibbon.TabElementPressed(TFmrTabElement(AElement), AByKeyboard)
  else
    inherited;
end;

function TFmrRibbonTabBar.IsElementDroppedDown(const AElement: TFmrElement): Boolean;
begin
  Result := inherited IsElementDroppedDown(AElement);
end;

procedure TFmrRibbonTabBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  E: TFmrElement;
begin
  if (Button = TMouseButton.mbLeft) and (ssDouble in Shift) and not (csDesigning in ComponentState) then
  begin
    E := FindElement(Logical(X, Y));
    if E is TFmrTabElement then
    begin
      FRibbon.ClosePopups;
      FRibbon.Minimized := not FRibbon.IsCollapsed;
      if FRibbon.ShowMode <> TFmrRibbonShowMode.TabsAndCommands then
        FRibbon.ShowMode := TFmrRibbonShowMode.TabsAndCommands;
      FTracker.SuppressUntilUp;
      Exit;
    end;
  end;
  inherited;
end;

procedure TFmrRibbonTabBar.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if not Handled and not FRibbon.IsCollapsed and not (csDesigning in ComponentState) then
  begin
    if WheelDelta > 0 then
      FRibbon.SelectAdjacentTab(-1)
    else
      FRibbon.SelectAdjacentTab(1);
    Handled := True;
  end;
end;

function TFmrRibbonTabBar.KeepClickWhenClosingPopups(const P: TPointF): Boolean;
begin
  Result := (FRibbon.FMinimizedPopup <> nil) and (FindElement(P) is TFmrTabElement);
end;

{ TFmrRibbonBody }

function TFmrRibbonBody.FindElement(const P: TPointF): TFmrElement;
var
  V: TFmrItemView;
  E: TFmrElement;
begin
  for E in FRibbon.FBodyElements do
    if E.Visible and (E.Host <> nil) and (E.Host.GetHostControl = Self) and E.Bounds.Contains(P) then
      Exit(E);
  for V in FRibbon.FBodyViews do
    if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = Self) and (V.PartAt(P) <> TFmrElementPart.None) then
      Exit(V);
  Result := nil;
end;

procedure TFmrRibbonBody.PaintPart(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  Card, Area, R, Tab: TRectF;
  I, J: Integer;
  Box: TFmrGroupBox;
  V: TFmrItemView;
  E: TFmrElement;
  X, ContentTop: Single;
  State: TCanvasSaveState;
  Caption: string;
begin
  P := GetPainter;
  M := P.Metrics;
  if P.Theme.Style.FloatingBody or (Parent is TFmrPopupFrame) then
    P.DrawBodyBackground(ACanvas, LocalRect, FRibbon.FrameActive);
  Card := FRibbon.BodyCardRect;
  P.DrawBody(ACanvas, Card);
  if not P.Theme.Style.FloatingBody and (P.Theme.Style.TabShape <> TFmrTabShape.Underline) and
    not FRibbon.IsCollapsed then
  begin
    // The active tab is open towards the body: no line below it.
    Tab := FRibbon.ActiveTabRect;
    if not Tab.IsEmpty then
      P.Fill(ACanvas, RectF(Tab.Left + 1, Card.Top, Tab.Right - 1, Card.Top + 1), TFmrToken.TabActiveFill);
  end;
  Area := FRibbon.GroupAreaRect;
  State := ACanvas.SaveState;
  try
    ACanvas.IntersectClipRect(RectF(Card.Left + 1, Card.Top, Card.Right - 1, Card.Bottom));
    if FRibbon.FDisplayMode = TFmrRibbonDisplayMode.Classic then
    begin
      for I := 0 to High(FRibbon.FGroupBoxes) do
      begin
        Box := FRibbon.FGroupBoxes[I];
        if Box.Collapsed then
        begin
          if P.Theme.Style.GroupFrame = TFmrGroupFrame.Separated then
            P.Line(ACanvas, PointF(Round(Box.Rect.Right) - 0.5, Box.Rect.Top + 4), PointF(Round(Box.Rect.Right) - 0.5,
              Box.Rect.Bottom - 4), P.Theme.Colors[TFmrToken.GroupSeparator]);
          Continue;
        end;
        if Box.Group.ShowCaption then
          Caption := FmrStripAccel(Box.Group.DisplayCaption)
        else
          Caption := '';
        R := Box.Rect;
        if Box.Group.ShowDialogLauncher then
          P.DrawGroup(ACanvas, R, '', False, M.GroupCaptionHeight, I = High(FRibbon.FGroupBoxes))
        else
          P.DrawGroup(ACanvas, R, Caption, False, M.GroupCaptionHeight, I = High(FRibbon.FGroupBoxes));
        if Box.Group.ShowDialogLauncher then
          P.TextEx(ACanvas, RectF(R.Left + 4, R.Bottom - M.GroupCaptionHeight, R.Right - 18, R.Bottom - 1), Caption,
            P.Theme.Colors[TFmrToken.GroupCaptionText], TTextAlign.Center, TTextAlign.Center, M.GroupCaptionFontSize,
            False, False);
        ContentTop := R.Top + M.GroupPaddingTop;
        for J := 0 to High(Box.Separators) do
        begin
          X := R.Left + Box.Separators[J];
          P.DrawSeparator(ACanvas, RectF(X - 1, ContentTop + 2, X + 1, ContentTop + M.ContentHeight - 2), True);
        end;
      end;
    end
    else
      for X in FRibbon.FSimplifiedResult.Separators do
        P.DrawSeparator(ACanvas, RectF(Area.Left + X - FRibbon.FScrollOffset - 1, Area.Top + 6,
          Area.Left + X - FRibbon.FScrollOffset + 1, Area.Bottom - 6), True);
    for V in FRibbon.FBodyViews do
      if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = Self) then
        V.Paint(ACanvas);
    for E in FRibbon.FBodyElements do
      if E.Visible and (E.Host <> nil) and (E.Host.GetHostControl = Self) and
        not ((E is TFmrSysButtonElement) and (TFmrSysButtonElement(E).Kind in [TFmrSysButtonKind.ScrollLeft,
        TFmrSysButtonKind.ScrollRight])) then
        E.Paint(ACanvas);
  finally
    ACanvas.RestoreState(State);
  end;
  for E in FRibbon.FBodyElements do
    if E.Visible and (E is TFmrSysButtonElement) and (TFmrSysButtonElement(E).Kind in [TFmrSysButtonKind.ScrollLeft,
      TFmrSysButtonKind.ScrollRight]) then
      E.Paint(ACanvas);
end;

function TFmrRibbonBody.ScreenTipAnchor(const AElement: TFmrElement): TRectF;
var
  TL, BR: TPointF;
  Card, R: TRectF;
begin
  Card := FRibbon.BodyCardRect;
  R := PhysicalRect(AElement.Bounds);
  TL := LocalToScreen(PointF(R.Left, Card.Bottom));
  BR := LocalToScreen(PointF(R.Right, Card.Bottom));
  Result := RectF(TL.X, TL.Y - 1, BR.X, BR.Y);
end;

procedure TFmrRibbonBody.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if not Handled and not FRibbon.IsCollapsed and not (csDesigning in ComponentState) then
  begin
    if WheelDelta > 0 then
      FRibbon.SelectAdjacentTab(-1)
    else
      FRibbon.SelectAdjacentTab(1);
    Handled := True;
  end;
end;

function TFmrRibbonBody.GetPopupSize: TSizeF;
var
  W: Single;
begin
  if FRibbon.FTabBar <> nil then
    W := FRibbon.FTabBar.Width
  else
    W := FRibbon.Width;
  Result := TSizeF.Create(W, FRibbon.BodyHeight + 2);
end;

function TFmrRibbonBody.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

procedure TFmrRibbonBody.PopupClosed;
begin
end;

function TFmrRibbonBody.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  Result := False;
end;

procedure TFmrRibbonBody.PopupShown(const AByKeyboard: Boolean);
begin
end;

{ TFmrRibbonQATBar }

function TFmrRibbonQATBar.FindElement(const P: TPointF): TFmrElement;
var
  V: TFmrItemView;
  E: TFmrSysButtonElement;
begin
  for V in FRibbon.FQATViews do
    if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = Self) and (V.PartAt(P) <> TFmrElementPart.None) then
      Exit(V);
  for E in FRibbon.FQATBarSysElements do
    if E.Visible and E.Bounds.Contains(P) then
      Exit(E);
  Result := nil;
end;

procedure TFmrRibbonQATBar.PaintPart(const ACanvas: TCanvas);
var
  V: TFmrItemView;
  E: TFmrSysButtonElement;
begin
  GetPainter.DrawQATBelow(ACanvas, LocalRect);
  for V in FRibbon.FQATViews do
    if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = Self) then
      V.Paint(ACanvas);
  for E in FRibbon.FQATBarSysElements do
    E.Paint(ACanvas);
end;

{ TFmrGroupPopupContent }

constructor TFmrGroupPopupContent.CreateFor(const ARibbon: TFmrRibbon; const AGroup: TFmrRibbonGroup);
var
  Input: TFmrLayoutGroup;
  Views: TArray<TFmrItemView>;
  M: TFmrThemeMetrics;
  I: Integer;
  V: TFmrItemView;
  L: TFmrLayoutLinkResult;
  ContentTop, PadH, GroupH: Single;
begin
  inherited Create(ARibbon);
  FGroup := AGroup;
  FViews := TList<TFmrItemView>.Create;
  M := ARibbon.FPainter.Metrics;
  Input := ARibbon.GroupLayoutInput(AGroup, Views);
  FResult := ARibbon.FCalc.CalculateExpandedGroup(Input);
  PadH := 3;
  GroupH := M.GroupPaddingTop + M.ContentHeight + M.GroupCaptionHeight;
  FGroupRect := RectF(PadH, M.BodyPaddingV, PadH + FResult.Width, M.BodyPaddingV + GroupH);
  FSize := TSizeF.Create(Ceil(FResult.Width + 2 * PadH), Ceil(GroupH + 2 * M.BodyPaddingV));
  ContentTop := FGroupRect.Top + M.GroupPaddingTop;
  for I := 0 to High(Views) do
  begin
    V := Views[I];
    if V = nil then
      Continue;
    V.SetHost(Self);
    FViews.Add(V);
    if I <= High(FResult.Links) then
    begin
      L := FResult.Links[I];
      if L.Visible then
        V.Place(RectF(FGroupRect.Left + L.Bounds.Left, ContentTop + L.Bounds.Top, FGroupRect.Left + L.Bounds.Right,
          ContentTop + L.Bounds.Bottom), L.Level, L.Segment)
      else
        V.Hide;
    end;
  end;
  if AGroup.ShowDialogLauncher then
  begin
    FLauncher := TFmrLauncherElement.Create(Self);
    FLauncher.FRibbon := ARibbon;
    FLauncher.FGroup := AGroup;
    FLauncher.Bounds := RectF(FGroupRect.Right - 16, FGroupRect.Bottom - M.GroupCaptionHeight + 2,
      FGroupRect.Right - 2, FGroupRect.Bottom - 2);
  end;
  Width := FSize.Width;
  Height := FSize.Height;
end;

destructor TFmrGroupPopupContent.Destroy;
begin
  ReturnViews;
  FreeAndNil(FLauncher);
  FreeAndNil(FViews);
  inherited;
end;

procedure TFmrGroupPopupContent.ReturnViews;
var
  V: TFmrItemView;
begin
  if FViews = nil then
    Exit;
  for V in FViews do
  begin
    FTracker.Forget(V);
    V.Hide;
    if (FRibbon <> nil) and (FRibbon.FBody <> nil) then
      V.SetHost(FRibbon.FBody);
  end;
  FViews.Clear;
  if (FRibbon <> nil) and not FRibbon.FDestroying then
    FRibbon.InvalidateArrange;
end;

function TFmrGroupPopupContent.FindElement(const P: TPointF): TFmrElement;
var
  V: TFmrItemView;
begin
  if (FLauncher <> nil) and FLauncher.Bounds.Contains(P) then
    Exit(FLauncher);
  for V in FViews do
    if V.Visible and (V.PartAt(P) <> TFmrElementPart.None) then
      Exit(V);
  Result := nil;
end;

procedure TFmrGroupPopupContent.PaintPart(const ACanvas: TCanvas);
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  V: TFmrItemView;
  X, ContentTop: Single;
  Caption: string;
  R: TRectF;
begin
  // Closed and waiting to be freed: the group or the ribbon may be gone.
  if (FRibbon = nil) or (FGroup = nil) then
    Exit;
  P := GetPainter;
  M := P.Metrics;
  R := LocalRect;
  P.Fill(ACanvas, R, TFmrToken.BodyFill, M.MenuRadius);
  P.Frame(ACanvas, R, TFmrToken.BodyBorder, M.MenuRadius);
  if FGroup.ShowCaption then
    Caption := FmrStripAccel(FGroup.DisplayCaption)
  else
    Caption := '';
  if P.Theme.Style.GroupFrame = TFmrGroupFrame.Boxed then
    P.DrawGroup(ACanvas, FGroupRect, Caption, False, M.GroupCaptionHeight, True)
  else
    P.TextEx(ACanvas, RectF(FGroupRect.Left + 4, FGroupRect.Bottom - M.GroupCaptionHeight, FGroupRect.Right - 18,
      FGroupRect.Bottom - 1), Caption, P.Theme.Colors[TFmrToken.GroupCaptionText], TTextAlign.Center,
      TTextAlign.Center, M.GroupCaptionFontSize, False, False);
  ContentTop := FGroupRect.Top + M.GroupPaddingTop;
  for X in FResult.Separators do
    P.DrawSeparator(ACanvas, RectF(FGroupRect.Left + X - 1, ContentTop + 2, FGroupRect.Left + X + 1,
      ContentTop + M.ContentHeight - 2), True);
  for V in FViews do
    if V.Visible then
      V.Paint(ACanvas);
  if FLauncher <> nil then
    FLauncher.Paint(ACanvas);
end;

function TFmrGroupPopupContent.GetPopupSize: TSizeF;
begin
  Result := FSize;
end;

procedure TFmrGroupPopupContent.Resize;
begin
  // The popup sets the size of the content; the ribbon body is not affected.
end;

function TFmrGroupPopupContent.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

procedure TFmrGroupPopupContent.PopupClosed;
begin
end;

function TFmrGroupPopupContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  F: TCommonCustomForm;
begin
  Result := False;
  F := FmrFormOf(Self);
  if (Key = vkReturn) and (F <> nil) and (F.Focused <> nil) then
  begin
    // Enter commits the editor and closes the group, like Office.
    F.KeyDown(Key, KeyChar, Shift);
    FmrPopups.CloseAll;
    Exit(True);
  end;
  if (FRibbon.FKeyTipLevel = TFmrKeyTipLevel.GroupPopup) and ((F = nil) or (F.Focused = nil)) then
    Result := FRibbon.HandleKey(Key, KeyChar, Shift);
end;

procedure TFmrGroupPopupContent.PopupShown(const AByKeyboard: Boolean);
begin
  if AByKeyboard and (FRibbon.FKeyTipLevel <> TFmrKeyTipLevel.None) then
    FRibbon.BuildKeyTips(TFmrKeyTipLevel.GroupPopup);
end;

{ TFmrRibbon.TRibbonPopupContext }

procedure TFmrRibbon.TRibbonPopupContext.ItemExecuting(const AItem: TFmrBarItem);
begin
  if (FRibbon <> nil) and FRibbon.KeyTipsVisible then
    FRibbon.HideKeyTips;
  // A command run from the search results clears the search box, like Office.
  if FSearchResults and (FRibbon <> nil) then
    FRibbon.SearchText := '';
end;

function TFmrRibbon.TRibbonPopupContext.ItemContextPopup(const AItem: TFmrBarItem;
  const AScreenPoint: TPointF): Boolean;
begin
  Result := FRibbon <> nil;
  if Result then
    FRibbon.ShowRibbonContextMenu(AItem, AScreenPoint);
end;

function TFmrRibbon.TRibbonPopupContext.IsMirrored: Boolean;
begin
  Result := (FRibbon <> nil) and FRibbon.EffectiveRightToLeft;
end;

{ TFmrRibbon }

constructor TFmrRibbon.Create(AOwner: TComponent);
begin
  inherited;
  FThemeName := FmrDefaultThemeName;
  FShowCaption := True;
  FShowTabGroups := True;
  FShowKeyTips := True;
  FShowScreenTips := True;
  FShowCollapseButton := True;
  FFrameAuto := True;
  FFrameState.Active := True;
  FQAT := TFmrRibbonQuickAccessToolbar.Create(Self);
  FAppButton := TFmrRibbonApplicationButton.Create(Self);
  FViews := TList<TFmrItemView>.Create;
  FTabElements := TObjectList<TFmrTabElement>.Create(True);
  FTabSysElements := TObjectList<TFmrSysButtonElement>.Create(True);
  FCaptionSysElements := TObjectList<TFmrSysButtonElement>.Create(True);
  FQATBarSysElements := TObjectList<TFmrSysButtonElement>.Create(True);
  FBodyElements := TObjectList<TFmrElement>.Create(True);
  FBodyViews := TList<TFmrItemView>.Create;
  FQATViews := TList<TFmrItemView>.Create;
  FQATOverflow := TList<TFmrItemView>.Create;
  FKeyTips := TList<TKeyTipEntryRec>.Create;
  FKeyTipMatcher := TFmrKeyTipMatcher.Create(nil);
  FScreenTips := TFmrScreenTipController.Create;
  FCalc := TFmrRibbonLayoutCalculator.Create;
  Align := TAlignLayout.Top;
  HitTest := False;
  CanFocus := False;
  ClipChildren := True;
  BuildTheme;
  CreateParts;
  FAppElement := TFmrAppButtonElement.Create(FTabBar);
  FAppElement.FRibbon := Self;
  FIdleId := TMessageManager.DefaultManager.SubscribeToMessage(TIdleMessage, IdleHandler);
  FStyleId := TMessageManager.DefaultManager.SubscribeToMessage(TStyleChangedMessage, StyleChangedHandler);
  FLanguageId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrLanguageChangedMessage, LanguageHandler);
  FFrameStateId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrFrameStateMessage, FrameStateHandler);
  if not (csDesigning in ComponentState) then
  begin
    FMenuLoopId := TMessageManager.DefaultManager.SubscribeToMessage(TStartMenuLoopMessage, MenuLoopHandler);
    FDeactivateId := TMessageManager.DefaultManager.SubscribeToMessage(TFormDeactivateMessage, DeactivateHandler);
  end
  else
  begin
    // Like TTabItem: the form designer passes the mouse to a design-interactive control; the parts leave it to the
    // ribbon (ObjectAtPoint), which gives it to the design package (TFmrRibbonDesignHooks). Controls dropped from
    // the palette do not become children of the ribbon (its children are tabs and context groups).
    FDesignInteractive := True;
    AutoCapture := True;
    SetAcceptsControls(False);
  end;
  FDesignTarget := TFmrDesignDropTarget.Empty;
  UpdateHeights;
end;

procedure TFmrRibbon.BeforeDestruction;
begin
  // csDestroying may be set already (the form destroys its components): HookFor would answer nil.
  if (csDesigning in ComponentState) and (TFmrRibbonDesignHooks.Hook <> nil) then
    TFmrRibbonDesignHooks.Hook.DesignRibbonDestroying(Self);
  FDestroying := True;
  if FIdleId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TIdleMessage, FIdleId);
  if FStyleId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TStyleChangedMessage, FStyleId);
  if FLanguageId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TFmrLanguageChangedMessage, FLanguageId);
  if FMenuLoopId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TStartMenuLoopMessage, FMenuLoopId);
  if FDeactivateId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TFormDeactivateMessage, FDeactivateId);
  if FFrameStateId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TFmrFrameStateMessage, FFrameStateId);
  FFrameStateId := 0;
  FIdleId := 0;
  FStyleId := 0;
  FLanguageId := 0;
  FMenuLoopId := 0;
  FDeactivateId := 0;
  if FScreenTips <> nil then
    FScreenTips.Cancel;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    HideKeyTips;
  ClosePopups;
  inherited;
end;

destructor TFmrRibbon.Destroy;
var
  V: TFmrItemView;
begin
  FDestroying := True;
  FreeAndNil(FTabTipOverlay);
  FreeAndNil(FScreenTips);
  if FBarManager <> nil then
  begin
    FBarManager.RemoveListener(Self);
    FBarManager.RemoveFreeNotification(Self);
    FBarManager := nil;
  end;
  for V in FViews do
    V.Free;
  FViews.Clear;
  FBodyViews.Clear;
  FQATViews.Clear;
  FQATOverflow.Clear;
  FreeAndNil(FAppElement);
  FreeAndNil(FTabElements);
  FreeAndNil(FTabSysElements);
  FreeAndNil(FCaptionSysElements);
  FreeAndNil(FQATBarSysElements);
  FreeAndNil(FBodyElements);
  FreeAndNil(FCaptionBar);
  FreeAndNil(FTabBar);
  FreeAndNil(FQATBar);
  FreeAndNil(FBody);
  FreeAndNil(FViews);
  FreeAndNil(FBodyViews);
  FreeAndNil(FQATViews);
  FreeAndNil(FQATOverflow);
  FreeAndNil(FKeyTips);
  FreeAndNil(FKeyTipMatcher);
  FreeAndNil(FCalc);
  FreeAndNil(FQAT);
  FreeAndNil(FAppButton);
  inherited;
  FreeAndNil(FBarPainter);
  FreeAndNil(FPainter);
  FreeAndNil(FBarTheme);
  FreeAndNil(FTheme);
end;

function TFmrRibbon.GetDefaultSize: TSizeF;
begin
  Result := TSizeF.Create(600, 150);
end;

function TFmrRibbon.OwnerForm: TCommonCustomForm;
var
  C: TComponent;
begin
  Result := FmrFormOf(Self);
  if Result = nil then
  begin
    C := Owner;
    while (C <> nil) and not (C is TCommonCustomForm) do
      C := C.Owner;
    Result := TCommonCustomForm(C);
  end;
end;

{ theme }

function TFmrRibbon.FindStyleRoot: TFmxObject;
var
  Form: TCommonCustomForm;
  SBO: IStyleBookOwner;
begin
  Result := nil;
  Form := OwnerForm;
  if Form = nil then
    Exit;
  if Supports(Form, IStyleBookOwner, SBO) and (SBO.StyleBook <> nil) then
    Result := SBO.StyleBook.Style;
  if Result = nil then
    Result := TStyleManager.ActiveStyle(Form);
end;

function FmrContrastRatio(const A, B: TAlphaColor): Single;
var
  LA, LB: Single;
begin
  LA := FmrLuminance(A);
  LB := FmrLuminance(B);
  Result := (Max(LA, LB) + 0.05) / (Min(LA, LB) + 0.05);
end;

/// The caption and tab rows need their own button colors when they are painted with the accent (Colorful themes)
/// or when the body glyph color does not read on the caption (dark caption of a light theme: Office 2007/2010
/// Black, Office 2016 Dark Gray, or a StyleBook override).
function FmrCaptionNeedsBarColors(const T: TFmrTheme): Boolean;
var
  Bg: TAlphaColor;
  GlyphContrast: Single;
begin
  if T.Style.ColoredCaption then
    Exit(True);
  Bg := T.Fills[TFmrToken.CaptionFill].MainColor or $FF000000;
  GlyphContrast := FmrContrastRatio(T.Colors[TFmrToken.GlyphTint] or $FF000000, Bg);
  Result := (GlyphContrast < 3) and (FmrContrastRatio(T.Colors[TFmrToken.CaptionText] or $FF000000, Bg) >
    GlyphContrast);
end;

procedure TFmrRibbon.BuildTheme;
var
  NewTheme, NewBar: TFmrTheme;
  M: TFmrThemeMetrics;
  Root: TFmxObject;
  S: Single;
begin
  NewTheme := TFmrTheme.CreateTheme(FThemeName, FAccentColor);
  try
    Root := FindStyleRoot;
    if Root <> nil then
      NewTheme.ApplyStyleOverrides(Root);
  except
    // A broken style must not break the ribbon.
  end;
  if FTouchMode then
  begin
    M := NewTheme.Metrics;
    S := M.TouchScale;
    M.CaptionHeight := Round(M.CaptionHeight * S);
    M.TabRowHeight := Round(M.TabRowHeight * S);
    M.SmallButtonHeight := Round(M.SmallButtonHeight * S);
    M.ContentHeight := Round(M.SmallButtonHeight * 3 + 6);
    M.QATButtonSize := Round(M.QATButtonSize * S);
    M.MenuItemHeight := Round(M.MenuItemHeight * S);
    M.ButtonPaddingH := Round(M.ButtonPaddingH * S);
    M.LargeButtonMinWidth := Round(M.LargeButtonMinWidth * S);
    M.SimplifiedBodyHeight := Round(M.SimplifiedBodyHeight * S);
    M.ScrollButtonWidth := Round(M.ScrollButtonWidth * S);
    M.TabPaddingH := Round(M.TabPaddingH * S);
    NewTheme.Metrics := M;
  end;
  NewBar := NewTheme.Clone;
  if FmrCaptionNeedsBarColors(NewTheme) then
  begin
    NewBar.Colors[TFmrToken.GlyphTint] := NewTheme.Colors[TFmrToken.CaptionText];
    NewBar.Colors[TFmrToken.ButtonText] := NewTheme.Colors[TFmrToken.CaptionText];
    NewBar.Colors[TFmrToken.ButtonArrow] := NewTheme.Colors[TFmrToken.CaptionText];
    NewBar.Colors[TFmrToken.GlyphTintDisabled] := FmrWithAlpha(NewTheme.Colors[TFmrToken.CaptionText], 0.45);
    NewBar.Colors[TFmrToken.ButtonTextDisabled] := FmrWithAlpha(NewTheme.Colors[TFmrToken.CaptionText], 0.45);
    NewBar.Fills[TFmrToken.ButtonHotFill] := NewTheme.Fills[TFmrToken.CaptionButtonHotFill];
    NewBar.Fills[TFmrToken.ButtonPressedFill] := NewTheme.Fills[TFmrToken.CaptionButtonPressedFill];
    NewBar.Fills[TFmrToken.ButtonCheckedFill] := NewTheme.Fills[TFmrToken.CaptionButtonPressedFill];
    NewBar.Colors[TFmrToken.ButtonHotBorder] := TAlphaColors.Null;
    NewBar.Colors[TFmrToken.ButtonPressedBorder] := TAlphaColors.Null;
    NewBar.Colors[TFmrToken.ButtonCheckedBorder] := TAlphaColors.Null;
  end;
  if FPainter = nil then
    FPainter := TFmrRibbonPainter.Create(NewTheme)
  else
    FPainter.Theme := NewTheme;
  if FBarPainter = nil then
    FBarPainter := TFmrRibbonPainter.Create(NewBar)
  else
    FBarPainter.Theme := NewBar;
  FTheme.Free;
  FTheme := NewTheme;
  FBarTheme.Free;
  FBarTheme := NewBar;
  FCalc.Metrics := LayoutMetrics;
  ApplyFrameColors;
  // Companion controls (backstage view, status bar) paint with the theme of the ribbon.
  if not FDestroying and not (csLoading in ComponentState) then
    TMessageManager.DefaultManager.SendMessage(Self, TFmrThemeChangedMessage.Create(Self), True);
end;

function TFmrRibbon.GetFmrTheme: TFmrTheme;
begin
  Result := FTheme;
end;

procedure TFmrRibbon.ApplyFrameColors;
var
  C, CI: TAlphaColor;
begin
  if (FFrame = nil) or FDestroying or (csDesigning in ComponentState) or (csDestroying in FFrame.ComponentState) then
    Exit;
  C := FTheme.Fills[TFmrToken.CaptionFill].MainColor;
  CI := FTheme.Fills[TFmrToken.CaptionFillInactive].MainColor;
  if FFrame.CaptionColor <> C then
    FFrame.CaptionColor := C;
  if FFrame.CaptionInactiveColor <> CI then
    FFrame.CaptionInactiveColor := CI;
  if FFrame.DarkMode <> FTheme.Style.Dark then
    FFrame.DarkMode := FTheme.Style.Dark;
end;

function TFmrRibbon.GetThemePainter: TFmrRibbonPainter;
begin
  Result := FPainter;
end;

function TFmrRibbon.GetThemeImages: TCustomImageList;
begin
  if FBarManager <> nil then
    Result := FBarManager.Images
  else
    Result := nil;
end;

{ parts and frame }

procedure TFmrRibbon.CreateParts;
begin
  FCaptionBar := TFmrRibbonCaptionBar.Create(Self);
  FTabBar := TFmrRibbonTabBar.Create(Self);
  FBody := TFmrRibbonBody.Create(Self);
  FQATBar := TFmrRibbonQATBar.Create(Self);
  FCaptionBar.Parent := Self;
  FTabBar.Parent := Self;
  FBody.Parent := Self;
  FQATBar.Parent := Self;
  FQATBar.Visible := False;
end;

function TFmrRibbon.FindOwnerFrame: TFmrFormFrame;
var
  Form: TCommonCustomForm;
  I: Integer;
begin
  Result := nil;
  Form := OwnerForm;
  if Form = nil then
    Exit;
  for I := 0 to Form.ComponentCount - 1 do
    if (Form.Components[I] is TFmrFormFrame) and not (csDestroying in Form.Components[I].ComponentState) then
      Exit(TFmrFormFrame(Form.Components[I]));
end;

procedure TFmrRibbon.UpdateFrameAttachment;
var
  F: TFmrFormFrame;
begin
  if FDestroying or (csLoading in ComponentState) then
    Exit;
  if FFrameAuto then
  begin
    F := FindOwnerFrame;
    if F <> FFrame then
    begin
      if FFrame <> nil then
        FFrame.RemoveFreeNotification(Self);
      FFrame := F;
      if FFrame <> nil then
        FFrame.FreeNotification(Self);
      ApplyFrameColors;
    end;
  end;
  PlaceBars;
end;

procedure TFmrRibbon.PlaceBars;
var
  InHost: Boolean;
  Target: TFmxObject;
begin
  if FDestroying or (FCaptionBar = nil) or (FTabBar = nil) then
    Exit;
  // The auto-hide overlay holds the tab bar: give it back first.
  if FAutoHidePopup <> nil then
    ClosePopups;
  InHost := (FFrame <> nil) and (FFrame.Host <> nil) and not (csDestroying in FFrame.ComponentState) and
    not (csDestroying in FFrame.Host.ComponentState) and (Parent <> nil);
  if InHost then
    Target := FFrame.Host
  else
    Target := Self;
  FBarsInHost := InHost;
  if FCaptionBar.Parent <> Target then
    FCaptionBar.Parent := Target;
  if FTabBar.Parent <> Target then
    FTabBar.Parent := Target;
  if InHost then
  begin
    FCaptionBar.Align := TAlignLayout.None;
    FTabBar.Align := TAlignLayout.None;
    FCaptionBar.Position.Y := 0;
    FTabBar.Position.Y := 1;
    FCaptionBar.Align := TAlignLayout.Top;
    FTabBar.Align := TAlignLayout.Top;
  end
  else
  begin
    FCaptionBar.Align := TAlignLayout.None;
    FTabBar.Align := TAlignLayout.None;
  end;
  UpdateHeights;
  InvalidateStructure;
end;

function TFmrRibbon.IsCollapsed: Boolean;
begin
  Result := FMinimized or (FShowMode <> TFmrRibbonShowMode.TabsAndCommands);
end;

function TFmrRibbon.CaptionBarVisible: Boolean;
begin
  // Auto-hide keeps the caption row: it holds the button that shows the ribbon.
  Result := FShowCaption or AutoHideActive;
  if Result and FBarsInHost and (FFrame <> nil) and FFrame.Hooked and (FFrame.Mode = TFmrFrameMode.NCStrip) then
    Result := AutoHideActive or (FQAT.Visible and (FQAT.Position = TFmrQATPosition.AboveRibbon) and
      (FQAT.ItemLinks.VisibleCount > 0));
end;

function TFmrRibbon.BodyVisible: Boolean;
begin
  Result := not IsCollapsed;
end;

function TFmrRibbon.CaptionBarHeight: Single;
begin
  Result := FPainter.Metrics.CaptionHeight;
  if FBarsInHost and FFrameState.Maximized then
    Result := Result + FFrameState.MaximizedTopOffset;
end;

function TFmrRibbon.TabBarHeight: Single;
begin
  Result := FPainter.Metrics.TabRowHeight;
end;

function TFmrRibbon.BodyHeight: Single;
var
  M: TFmrThemeMetrics;
begin
  M := FPainter.Metrics;
  if FDisplayMode = TFmrRibbonDisplayMode.Simplified then
    Result := M.SimplifiedBodyHeight
  else
    Result := M.BodyHeight;
  if FTheme.Style.FloatingBody then
    Result := Result + M.BodyMargin;
end;

function TFmrRibbon.QATBarHeight: Single;
begin
  Result := FPainter.Metrics.QATButtonSize + 6;
end;

procedure TFmrRibbon.UpdateHeights;
var
  W, Y, CapH, TabH, BH, QH, H: Single;
  CapVisible, TabVisible, QATBelow: Boolean;
begin
  if FDestroying or (FCaptionBar = nil) or (FPainter = nil) then
    Exit;
  CapVisible := CaptionBarVisible;
  // A backstage view covers the client area; the frame keeps only the caption row. Auto-hide hides the tab row too
  // (the overlay shows it).
  TabVisible := not (FAppMenuCovering and FBarsInHost and CapVisible) and not AutoHideActive;
  CapH := CaptionBarHeight;
  TabH := TabBarHeight;
  BH := BodyHeight;
  QH := QATBarHeight;
  QATBelow := FQAT.Visible and not ((FQAT.Position = TFmrQATPosition.AboveRibbon) and CapVisible) and
    (FQAT.ItemLinks.VisibleCount > 0) and not FAppMenuCovering;
  W := Width;
  FCaptionBar.Visible := CapVisible;
  FCaptionBar.Height := CapH;
  FTabBar.Height := TabH;
  if FBarsInHost then
  begin
    if FAutoHidePopup = nil then
      FTabBar.Visible := TabVisible;
    H := 0;
    if TabVisible then
      H := TabH;
    if CapVisible then
      H := H + CapH;
    if not SameValue(FFrame.CaptionHeight, H, 0.01) then
      FFrame.CaptionHeight := H;
    Y := 0;
  end
  else
  begin
    Y := 0;
    if CapVisible then
    begin
      FCaptionBar.SetBounds(0, Y, W, CapH);
      Y := Y + CapH;
    end;
    if FAutoHidePopup = nil then
    begin
      FTabBar.Visible := TabVisible;
      if TabVisible then
      begin
        FTabBar.SetBounds(0, Y, W, TabH);
        Y := Y + TabH;
      end;
    end;
  end;
  if FBody.Parent = Self then
  begin
    FBody.Visible := BodyVisible;
    if FBody.Visible then
    begin
      FBody.SetBounds(0, Y, W, BH);
      Y := Y + BH;
    end;
  end;
  FQATBar.Visible := QATBelow;
  if QATBelow then
  begin
    FQATBar.SetBounds(0, Y, W, QH);
    Y := Y + QH;
  end;
  if not SameValue(Height, Y, 0.01) then
    Height := Y;
end;

procedure TFmrRibbon.InvalidateParts;
begin
  if FDestroying then
    Exit;
  if FCaptionBar <> nil then
  begin
    FCaptionBar.Repaint;
    FCaptionBar.UpdateTipOverlay;
  end;
  if FTabBar <> nil then
  begin
    FTabBar.Repaint;
    FTabBar.UpdateTipOverlay;
  end;
  if FBody <> nil then
  begin
    FBody.Repaint;
    FBody.UpdateTipOverlay;
  end;
  if (FQATBar <> nil) and FQATBar.Visible then
  begin
    FQATBar.Repaint;
    FQATBar.UpdateTipOverlay;
  end;
  if FGroupPopupContent <> nil then
  begin
    FGroupPopupContent.Repaint;
    FGroupPopupContent.UpdateTipOverlay;
  end;
  UpdateTabTipOverlay;
end;

procedure TFmrRibbon.UpdateTabTipOverlay;
var
  Show: Boolean;
  Form: TCommonCustomForm;
  P: TPointF;
begin
  Form := nil;
  Show := not FDestroying and (FKeyTipLevel = TFmrKeyTipLevel.Top) and (FTabBar <> nil) and FTabBar.Visible and
    (FTabBar.Parent <> nil) and (FBarPainter <> nil);
  // The badges hang into the body when it is shown below the tab row.
  if Show and (FBody <> nil) and FBody.Visible and ((FBody.Parent = Self) or (FBody.Parent = FTabBar.Parent)) then
    Show := False;
  if Show then
  begin
    Form := OwnerForm;
    Show := (Form <> nil) and not (csDestroying in Form.ComponentState);
  end;
  if not Show then
  begin
    if FTabTipOverlay <> nil then
      FTabTipOverlay.Visible := False;
    Exit;
  end;
  if FTabTipOverlay = nil then
  begin
    FTabTipOverlay := TFmrTabTipOverlay.Create(nil);
    TFmrTabTipOverlay(FTabTipOverlay).FRibbon := Self;
    FTabTipOverlay.Stored := False;
    FTabTipOverlay.Locked := True;
    FTabTipOverlay.HitTest := False;
    FTabTipOverlay.FreeNotification(Self);
  end;
  if FTabTipOverlay.Parent <> Form then
    FTabTipOverlay.Parent := Form;
  // Below the tab row; in the non-client modes the tab row ends at the top of the client area.
  P := Form.ScreenToClient(FTabBar.LocalToScreen(PointF(0, FTabBar.Height)));
  FTabTipOverlay.SetBounds(P.X, Max(0, P.Y), FTabBar.Width, FBarPainter.KeyTipSize('W').Height + 4);
  FTabTipOverlay.Visible := True;
  FTabTipOverlay.BringToFront;
  FTabTipOverlay.Repaint;
end;

procedure TFmrRibbon.Resize;
begin
  inherited;
  if FDestroying then
    Exit;
  UpdateHeights;
  InvalidateArrange;
  if (FMinimizedPopup <> nil) or (FGroupPopup <> nil) or (FDropPopup <> nil) or (FAutoHidePopup <> nil) then
    ClosePopups;
end;

procedure TFmrRibbon.Paint;
begin
  inherited;
  if csDesigning in ComponentState then
  begin
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := $40808080;
    Canvas.Stroke.Dash := TStrokeDash.Dash;
    Canvas.DrawRect(LocalRect, 0, 0, [], 1);
  end;
end;

procedure TFmrRibbon.Loaded;
begin
  inherited;
  BuildTheme;
  UpdateFrameAttachment;
  InvalidateStructure;
  // A ribbon streamed from a form: its designed layout is complete now.
  CaptureDefaultLayout;
  UpdateHeights;
end;

procedure TFmrRibbon.ParentChanged;
begin
  inherited;
  if not FDestroying and not (csLoading in ComponentState) then
  begin
    UpdateFrameAttachment;
    BuildTheme;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation <> opRemove then
    Exit;
  if AComponent = FBarManager then
  begin
    FBarManager := nil;
    InvalidateStructure;
  end;
  if AComponent = FFrame then
  begin
    FFrame := nil;
    FBarsInHost := False;
    if not FDestroying then
    begin
      if (FCaptionBar <> nil) and (FCaptionBar.Parent <> Self) then
        FCaptionBar.Parent := Self;
      if (FTabBar <> nil) and (FTabBar.Parent <> Self) then
        FTabBar.Parent := Self;
      UpdateHeights;
      InvalidateStructure;
    end;
  end;
  if AComponent = FApplicationMenu then
    FApplicationMenu := nil;
  if AComponent = FTabTipOverlay then
    FTabTipOverlay := nil;
  if AComponent = FCaptionBar then
    FCaptionBar := nil;
  if AComponent = FTabBar then
    FTabBar := nil;
  if AComponent = FBody then
    FBody := nil;
  if AComponent = FQATBar then
    FQATBar := nil;
  if AComponent = FGroupPopupContent then
    FGroupPopupContent := nil;
  if (FCaptionBar = nil) and (FTabBar = nil) and not FDestroying and not (csDestroying in ComponentState) then
  begin
    // The frame host destroyed the bars: create them again inside the ribbon.
    FCaptionBar := TFmrRibbonCaptionBar.Create(Self);
    FTabBar := TFmrRibbonTabBar.Create(Self);
    FCaptionBar.Parent := Self;
    FTabBar.Parent := Self;
    FreeAndNil(FAppElement);
    FAppElement := TFmrAppButtonElement.Create(FTabBar);
    FAppElement.FRibbon := Self;
    FBarsInHost := False;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.DoAddObject(const AObject: TFmxObject);
begin
  inherited;
  if (AObject is TFmrRibbonStructureObject) and not FDestroying then
    InvalidateStructure;
end;

procedure TFmrRibbon.DoRemoveObject(const AObject: TFmxObject);
begin
  inherited;
  if (AObject = FActiveTab) then
    FActiveTab := nil;
  if AObject = FDesignTab then
    FDesignTab := nil;
  if (AObject is TFmrRibbonStructureObject) and not FDestroying then
    InvalidateStructure;
end;

{ property setters }

procedure TFmrRibbon.SetBarManager(const Value: TFmrBarManager);
begin
  if FBarManager = Value then
    Exit;
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
  InvalidateStructure;
end;

procedure TFmrRibbon.SetQAT(const Value: TFmrRibbonQuickAccessToolbar);
begin
  FQAT.Assign(Value);
end;

procedure TFmrRibbon.SetAppButton(const Value: TFmrRibbonApplicationButton);
begin
  FAppButton.Assign(Value);
end;

procedure TFmrRibbon.SetApplicationMenu(const Value: TFmxObject);
begin
  if FApplicationMenu <> Value then
  begin
    if FApplicationMenu <> nil then
      FApplicationMenu.RemoveFreeNotification(Self);
    FApplicationMenu := Value;
    if FApplicationMenu <> nil then
      FApplicationMenu.FreeNotification(Self);
  end;
end;

procedure TFmrRibbon.SetActiveTabProp(const Value: TFmrRibbonTab);
begin
  SetActiveTab(Value);
end;

procedure TFmrRibbon.SetThemeName(const Value: string);
begin
  if FThemeName <> Value then
  begin
    FThemeName := Value;
    ClosePopups;
    BuildTheme;
    InvalidateStructure;
    UpdateHeights;
    InvalidateParts;
  end;
end;

function TFmrRibbon.IsThemeNameStored: Boolean;
begin
  Result := not SameText(FThemeName, FmrDefaultThemeName);
end;

procedure TFmrRibbon.SetAccentColor(const Value: TAlphaColor);
begin
  if FAccentColor <> Value then
  begin
    FAccentColor := Value;
    BuildTheme;
    InvalidateParts;
  end;
end;

procedure TFmrRibbon.SetMinimized(const Value: Boolean);
begin
  if FMinimized <> Value then
  begin
    ClosePopups;
    FMinimized := Value;
    UpdateHeights;
    InvalidateArrange;
    InvalidateParts;
    if Assigned(FOnMinimizedChanged) and ([csLoading, csDesigning] * ComponentState = []) then
      FOnMinimizedChanged(Self);
  end;
end;

procedure TFmrRibbon.SetShowMode(const Value: TFmrRibbonShowMode);
begin
  if FShowMode <> Value then
  begin
    ClosePopups;
    FShowMode := Value;
    // The caption row gets or loses the auto-hide button.
    InvalidateStructure;
    UpdateHeights;
    InvalidateArrange;
    InvalidateParts;
  end;
end;

procedure TFmrRibbon.SetDisplayMode(const Value: TFmrRibbonDisplayMode);
begin
  if FDisplayMode <> Value then
  begin
    ClosePopups;
    FDisplayMode := Value;
    FScrollOffset := 0;
    UpdateHeights;
    InvalidateLayout;
    InvalidateParts;
    if Assigned(FOnDisplayModeChanged) and ([csLoading, csDesigning] * ComponentState = []) then
      FOnDisplayModeChanged(Self);
  end;
end;

procedure TFmrRibbon.SetTouchMode(const Value: Boolean);
begin
  if FTouchMode <> Value then
  begin
    FTouchMode := Value;
    ClosePopups;
    BuildTheme;
    InvalidateStructure;
    UpdateHeights;
  end;
end;

procedure TFmrRibbon.SetShowTabGroups(const Value: Boolean);
begin
  if FShowTabGroups <> Value then
  begin
    FShowTabGroups := Value;
    InvalidateArrange;
    InvalidateParts;
  end;
end;

procedure TFmrRibbon.SetFrame(const Value: TFmrFormFrame);
begin
  FFrameAuto := Value = nil;
  if FFrame <> Value then
  begin
    if FFrame <> nil then
      FFrame.RemoveFreeNotification(Self);
    FFrame := Value;
    if FFrame <> nil then
      FFrame.FreeNotification(Self);
    ApplyFrameColors;
  end;
  if not (csLoading in ComponentState) then
    UpdateFrameAttachment;
end;

procedure TFmrRibbon.SetCaptionText(const Value: string);
begin
  if FCaptionText <> Value then
  begin
    FCaptionText := Value;
    InvalidateArrange;
    if FCaptionBar <> nil then
      FCaptionBar.Repaint;
  end;
end;

procedure TFmrRibbon.SetShowCaption(const Value: Boolean);
begin
  if FShowCaption <> Value then
  begin
    FShowCaption := Value;
    UpdateHeights;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.SetShowSearchBox(const Value: Boolean);
begin
  if FShowSearchBox <> Value then
  begin
    FShowSearchBox := Value;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.SetShowKeyTips(const Value: Boolean);
begin
  FShowKeyTips := Value;
  if not Value then
    HideKeyTips;
end;

procedure TFmrRibbon.SetShowScreenTips(const Value: Boolean);
begin
  FShowScreenTips := Value;
  if not Value then
    FScreenTips.Cancel;
end;

procedure TFmrRibbon.SetShowHelpButton(const Value: Boolean);
begin
  if FShowHelpButton <> Value then
  begin
    FShowHelpButton := Value;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.SetShowCollapseButton(const Value: Boolean);
begin
  if FShowCollapseButton <> Value then
  begin
    FShowCollapseButton := Value;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.SetRightToLeft(const Value: Boolean);
begin
  if FRightToLeft <> Value then
  begin
    FRightToLeft := Value;
    ClosePopups;
    InvalidateStructure;
  end;
end;

function TFmrRibbon.GetSearchText: string;
begin
  if (FCaptionBar <> nil) and (FCaptionBar.FSearchEdit <> nil) then
    Result := FCaptionBar.FSearchEdit.Text
  else
    Result := '';
end;

procedure TFmrRibbon.SetSearchText(const Value: string);
begin
  if (FCaptionBar <> nil) and (FCaptionBar.FSearchEdit <> nil) then
    FCaptionBar.FSearchEdit.Text := Value;
end;

{ IFmrRibbonStructureOwner }

function TFmrRibbon.GetStructureObject: TFmxObject;
begin
  Result := Self;
end;

function TFmrRibbon.GetBarManager: TFmrBarManager;
begin
  Result := FBarManager;
end;

function TFmrRibbon.GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
begin
  Result := FQAT;
end;

function TFmrRibbon.GetActiveTab: TFmrRibbonTab;
begin
  Result := FActiveTab;
end;

procedure TFmrRibbon.SetActiveTab(const ATab: TFmrRibbonTab);
var
  Allow: Boolean;
begin
  if ATab = FActiveTab then
    Exit;
  if (ATab <> nil) and not (csLoading in ComponentState) and not (csDesigning in ComponentState) and
    Assigned(FOnTabChanging) then
  begin
    Allow := True;
    FOnTabChanging(Self, ATab, Allow);
    if not Allow then
      Exit;
  end;
  FActiveTab := ATab;
  FScrollOffset := 0;
  if FActiveTab = nil then
    InvalidateStructure
  else
    InvalidateLayout;
  InvalidateParts;
  if not (csLoading in ComponentState) then
    DoTabChanged;
end;

procedure TFmrRibbon.DoTabChanged;
begin
  // At design time the event properties hold the designer's method references, not code.
  if csDesigning in ComponentState then
    Exit;
  if Assigned(FOnTabChanged) then
    FOnTabChanged(Self);
end;

function TFmrRibbon.GetLayoutOptions: TFmrRibbonLayoutOptions;
begin
  Result.Minimized := FMinimized;
  Result.ShowMode := FShowMode;
  Result.DisplayMode := FDisplayMode;
end;

procedure TFmrRibbon.SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
begin
  Minimized := AOptions.Minimized;
  ShowMode := AOptions.ShowMode;
  DisplayMode := AOptions.DisplayMode;
end;

procedure TFmrRibbon.BeginStructureUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TFmrRibbon.EndStructureUpdate;
begin
  if FUpdateCount > 0 then
  begin
    Dec(FUpdateCount);
    if FUpdateCount = 0 then
    begin
      InvalidateStructure;
      UpdateHeights;
    end;
  end;
end;

procedure TFmrRibbon.StructureChanged(const ASender: TObject);
begin
  InvalidateStructure;
end;

procedure TFmrRibbon.StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
begin
  if ASender = FQAT then
  begin
    ClosePopups;
    InvalidateStructure;
    UpdateHeights;
    Exit;
  end;
  if (ASender is TFmrRibbonContextGroup) or (ASender is TFmrRibbonTab) then
    InvalidateStructure
  else if AChange = TFmrItemChange.Layout then
    InvalidateLayout
  else
    InvalidateParts;
end;

procedure TFmrRibbon.StructureObjectRemoving(const AObject: TObject);
var
  I: Integer;
  Content: TFmrGroupPopupContent;
begin
  if AObject = FActiveTab then
    FActiveTab := nil;
  if AObject = FDesignTab then
    FDesignTab := nil;
  if AObject is TFmrRibbonGroup then
  begin
    if (FGroupPopupContent <> nil) and (FGroupPopupContent.FGroup = AObject) then
    begin
      Content := FGroupPopupContent;
      ClosePopups;
      // The closed popup is freed later: it must not reach the group any more.
      Content.FGroup := nil;
    end;
    // Links of a destroyed group go away silently: release their views now.
    FreeViewsOf(TFmrRibbonGroup(AObject).ItemLinks);
    for I := 0 to High(FLayoutGroups) do
      if FLayoutGroups[I] = AObject then
        FLayoutGroups[I] := nil;
  end;
  InvalidateStructure;
end;

procedure TFmrRibbon.LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
begin
  if AOwner = FQAT then
  begin
    InvalidateStructure;
    UpdateHeights;
  end
  else
    InvalidateStructure;
end;

procedure TFmrRibbon.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
var
  V: TFmrItemView;
begin
  V := nil;
  if (ALink.ViewObject is TFmrItemView) and FViews.Contains(TFmrItemView(ALink.ViewObject)) then
    V := TFmrItemView(ALink.ViewObject);
  if V <> nil then
  begin
    if not V.IsValidFor(ALink) then
    begin
      InvalidateStructure;
      Exit;
    end;
    V.ItemChanged(AChange);
  end;
  case AChange of
    TFmrItemChange.Layout:
      InvalidateLayout;
    TFmrItemChange.Paint, TFmrItemChange.Value:
      if (V <> nil) and V.Visible then
        V.Invalidate;
  end;
end;

procedure TFmrRibbon.LinkRemoving(const ALink: TFmrItemLink);
begin
  if (ALink.ViewObject is TFmrItemView) and FViews.Contains(TFmrItemView(ALink.ViewObject)) then
  begin
    FreeView(TFmrItemView(ALink.ViewObject));
    ALink.ViewObject := nil;
  end;
  InvalidateStructure;
end;

{ IFmrBarManagerListener }

procedure TFmrRibbon.BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
  const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
begin
  case AChange of
    TFmrManagerChange.Destroying:
      begin
        FBarManager := nil;
        InvalidateStructure;
      end;
    TFmrManagerChange.ImagesChanged:
      begin
        InvalidateLayout;
        InvalidateParts;
      end;
    TFmrManagerChange.Updated, TFmrManagerChange.Reordered, TFmrManagerChange.ItemRemoved:
      InvalidateStructure;
  end;
end;

{ invalidation }

procedure TFmrRibbon.InvalidateStructure;
begin
  FStructureValid := False;
  FLayoutValid := False;
  FArrangeValid := False;
  if not FDestroying then
    InvalidateParts;
end;

procedure TFmrRibbon.InvalidateLayout;
begin
  FLayoutValid := False;
  FArrangeValid := False;
  if not FDestroying and (FBody <> nil) then
  begin
    FBody.Repaint;
    if FTabBar <> nil then
      FTabBar.Repaint;
  end;
end;

procedure TFmrRibbon.InvalidateArrange;
begin
  FArrangeValid := False;
end;

procedure TFmrRibbon.EnsureStructure;
begin
  if not FStructureValid then
    RebuildStructure;
end;

procedure TFmrRibbon.EnsureLayout;
var
  Groups: TArray<TFmrLayoutGroup>;
  Views: TArray<TFmrItemView>;
  I: Integer;
  T: TFmrRibbonTab;
begin
  if FLayoutValid then
    Exit;
  T := FActiveTab;
  if T <> nil then
  begin
    SetLength(FLayoutGroups, T.GroupCount);
    SetLength(Groups, T.GroupCount);
    for I := 0 to T.GroupCount - 1 do
    begin
      FLayoutGroups[I] := T.Groups[I];
      Groups[I] := GroupLayoutInput(T.Groups[I], Views);
      Groups[I].Data := I;
    end;
  end
  else
    FLayoutGroups := nil;
  FCalc.Metrics := LayoutMetrics;
  FCalc.Prepare(Groups);
  FLayoutValid := True;
  FArrangeValid := False;
end;

procedure TFmrRibbon.EnsureArrange;
begin
  if FArrangeValid and SameValue(FArrangedWidth, Width, 0.01) then
    Exit;
  FRebuilding := True;
  try
    ArrangeTabBar;
    ArrangeCaptionBar;
    ArrangeBody;
    ArrangeQATBar;
  finally
    FRebuilding := False;
  end;
  FArrangedWidth := Width;
  FArrangeValid := True;
  Inc(FAccVersion);
  if FPainting then
    FNeedRepaint := True;
end;

procedure TFmrRibbon.EnsureAll;
begin
  if FDestroying or FRebuilding or (FUpdateCount > 0) or (FPainter = nil) or (FBody = nil) or (FTabBar = nil) or
    (FCaptionBar = nil) or ([csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  EnsureStructure;
  EnsureLayout;
  EnsureArrange;
end;

procedure TFmrRibbon.UpdateLayout;
begin
  InvalidateLayout;
  EnsureAll;
  InvalidateParts;
end;

function TFmrRibbon.ShownTabs: TArray<TFmrRibbonTab>;
var
  T: TFmrRibbonTab;
begin
  Result := nil;
  for T in TFmrRibbonStructure.Tabs(Self) do
    if TabShown(T) then
      Result := Result + [T];
end;

function TFmrRibbon.TabShown(const T: TFmrRibbonTab): Boolean;
begin
  // Design time: a hidden tab (of a hidden contextual group) is shown while it is selected, so its groups can be
  // designed.
  Result := IsVisibleTab(T) or ((T <> nil) and (T = FDesignTab) and (csDesigning in ComponentState) and
    not (csDestroying in T.ComponentState));
end;

procedure TFmrRibbon.PickActiveTab;
var
  A: TArray<TFmrRibbonTab>;
begin
  if (FActiveTab <> nil) and ((FActiveTab.Parent <> Self) or not TabShown(FActiveTab)) then
    FActiveTab := nil;
  if FActiveTab = nil then
  begin
    A := ShownTabs;
    if Length(A) > 0 then
      FActiveTab := A[0];
  end;
end;

function TFmrRibbon.ViewFor(const ALink: TFmrItemLink; const AHost: IFmrElementHost;
  const APlace: TFmrViewPlace): TFmrItemView;
var
  Old: TFmrItemView;
begin
  Result := nil;
  if ALink.Item = nil then
    Exit;
  Old := nil;
  if (ALink.ViewObject is TFmrItemView) and (FViews.IndexOf(TFmrItemView(ALink.ViewObject)) >= 0) then
    Old := TFmrItemView(ALink.ViewObject);
  if (Old <> nil) and Old.IsValidFor(ALink) and (Old.ViewPlace = APlace) then
  begin
    if (Old.Host = nil) or ((Old.Host.GetHostControl <> AHost.GetHostControl) and
      not (Old.Host.GetHostControl is TFmrGroupPopupContent)) then
      Old.SetHost(AHost);
    Exit(Old);
  end;
  if Old <> nil then
    FreeView(Old);
  Result := FmrCreateItemView(AHost, ALink, APlace);
  ALink.ViewObject := Result;
  FViews.Add(Result);
end;

procedure TFmrRibbon.FreeView(const AView: TFmrItemView);
var
  I: Integer;
  Removed: Boolean;
  Tips: TArray<string>;
begin
  if AView = nil then
    Exit;
  FViews.Remove(AView);
  FBodyViews.Remove(AView);
  FQATViews.Remove(AView);
  FQATOverflow.Remove(AView);
  if FDroppedElement = AView then
    FDroppedElement := nil;
  if FKeyFocus = AView then
    FKeyFocus := nil;
  Removed := False;
  for I := FKeyTips.Count - 1 downto 0 do
    if FKeyTips[I].Element = AView then
    begin
      FKeyTips.Delete(I);
      Removed := True;
    end;
  // The matcher answers indexes into FKeyTips: it must see the same list.
  if Removed then
  begin
    SetLength(Tips, FKeyTips.Count);
    for I := 0 to FKeyTips.Count - 1 do
      Tips[I] := FKeyTips[I].Tip;
    FKeyTipMatcher.Reset(Tips);
  end;
  if FScreenTips <> nil then
    FScreenTips.Cancel;
  if FCaptionBar <> nil then
    FCaptionBar.Tracker.Forget(AView);
  if FBody <> nil then
    FBody.Tracker.Forget(AView);
  if FQATBar <> nil then
    FQATBar.Tracker.Forget(AView);
  if (FGroupPopupContent <> nil) then
  begin
    FGroupPopupContent.Tracker.Forget(AView);
    FGroupPopupContent.FViews.Remove(AView);
  end;
  AView.Free;
end;

procedure TFmrRibbon.FreeViewsOf(const ALinks: TFmrItemLinks);
var
  I: Integer;
  L: TFmrItemLink;
begin
  if ALinks = nil then
    Exit;
  for I := 0 to ALinks.Count - 1 do
  begin
    L := ALinks[I];
    if (L.ViewObject is TFmrItemView) and (FViews.IndexOf(TFmrItemView(L.ViewObject)) >= 0) then
    begin
      FreeView(TFmrItemView(L.ViewObject));
      L.ViewObject := nil;
    end;
  end;
end;

procedure TFmrRibbon.ValidateViews;
var
  Seen: TList<TFmrItemView>;
  T: TFmrRibbonTab;
  I, J: Integer;
  G: TFmrRibbonGroup;
  V: TFmrItemView;
  QATHost: IFmrElementHost;
begin
  Seen := TList<TFmrItemView>.Create;
  try
    for T in TFmrRibbonStructure.Tabs(Self) do
      for I := 0 to T.GroupCount - 1 do
      begin
        G := T.Groups[I];
        for J := 0 to G.ItemLinks.Count - 1 do
        begin
          V := ViewFor(G.ItemLinks[J], FBody, TFmrViewPlace.Group);
          if V <> nil then
          begin
            Seen.Add(V);
            if T <> FActiveTab then
              V.Hide;
          end;
        end;
      end;
    if (FQAT.Position = TFmrQATPosition.AboveRibbon) and CaptionBarVisible then
      QATHost := FCaptionBar
    else
      QATHost := FQATBar;
    FQATViews.Clear;
    for J := 0 to FQAT.ItemLinks.Count - 1 do
    begin
      V := ViewFor(FQAT.ItemLinks[J], QATHost, TFmrViewPlace.Toolbar);
      if V <> nil then
      begin
        Seen.Add(V);
        FQATViews.Add(V);
        V.Hide;
      end;
    end;
    for I := FViews.Count - 1 downto 0 do
      if (I < FViews.Count) and (Seen.IndexOf(FViews[I]) < 0) then
      begin
        V := FViews[I];
        FViews.Delete(I);
        FBodyViews.Remove(V);
        FQATOverflow.Remove(V);
        FreeView(V);
      end;
  finally
    Seen.Free;
  end;
end;

function TFmrRibbon.NewSysButton(const AList: TObjectList<TFmrSysButtonElement>; const AHost: IFmrElementHost;
  const AKind: TFmrSysButtonKind): TFmrSysButtonElement;
begin
  Result := TFmrSysButtonElement.Create(AHost);
  Result.FRibbon := Self;
  Result.FKind := AKind;
  AList.Add(Result);
end;

procedure TFmrRibbon.RebuildStructure;
var
  T: TFmrRibbonTab;
  E: TFmrTabElement;
  Btn: TFmrRibbonCaptionButton;
  NeedButtons: Boolean;
  Kind: TFmrHitArea;
  Edit: TEdit;
begin
  if FRebuilding then
    Exit;
  FRebuilding := True;
  try
    if FScreenTips <> nil then
      FScreenTips.Cancel;
    if FKeyTipLevel <> TFmrKeyTipLevel.None then
    begin
      FKeyTips.Clear;
      FKeyFocus := nil;
    end;
    FCaptionBar.Tracker.Reset;
    FTabBar.Tracker.Reset;
    FBody.Tracker.Reset;
    FQATBar.Tracker.Reset;
    if (FDroppedElement <> nil) and not (FDroppedElement is TFmrItemView) then
      FDroppedElement := nil;
    PickActiveTab;
    FTabElements.Clear;
    for T in ShownTabs do
    begin
      E := TFmrTabElement.Create(FTabBar);
      E.FRibbon := Self;
      E.FTab := T;
      FTabElements.Add(E);
    end;
    FAppElement.Visible := FAppButton.Visible;
    FAppElement.Host := FTabBar;
    FTabSysElements.Clear;
    NewSysButton(FTabSysElements, FTabBar, TFmrSysButtonKind.TabScrollLeft).Visible := False;
    NewSysButton(FTabSysElements, FTabBar, TFmrSysButtonKind.TabScrollRight).Visible := False;
    if FShowHelpButton then
      NewSysButton(FTabSysElements, FTabBar, TFmrSysButtonKind.Help);
    if FShowCollapseButton then
      NewSysButton(FTabSysElements, FTabBar, TFmrSysButtonKind.CollapseRibbon);
    ValidateViews;
    FCaptionSysElements.Clear;
    FQATBarSysElements.Clear;
    if FQAT.Visible and FQAT.ShowCustomizeButton then
    begin
      if (FQAT.Position = TFmrQATPosition.AboveRibbon) and CaptionBarVisible then
        NewSysButton(FCaptionSysElements, FCaptionBar, TFmrSysButtonKind.QATCustomize)
      else
        NewSysButton(FQATBarSysElements, FQATBar, TFmrSysButtonKind.QATCustomize);
    end;
    NewSysButton(FCaptionSysElements, FCaptionBar, TFmrSysButtonKind.QATOverflow).Visible := False;
    NewSysButton(FQATBarSysElements, FQATBar, TFmrSysButtonKind.QATOverflow).Visible := False;
    // Caption-style buttons: "..." of the auto-hidden ribbon and the display options (Office 2016).
    if AutoHideActive then
      NewSysButton(FCaptionSysElements, FCaptionBar, TFmrSysButtonKind.AutoHideShow);
    if FShowDisplayOptionsButton and not (csDesigning in ComponentState) then
      NewSysButton(FCaptionSysElements, FCaptionBar, TFmrSysButtonKind.DisplayOptions);
    // Search box: a real edit over the box painted by the caption bar.
    if FShowSearchBox and (FCaptionBar.FSearchEdit = nil) and not (csDesigning in ComponentState) then
    begin
      Edit := TEdit.Create(Self);
      Edit.Stored := False;
      Edit.Locked := True;
      Edit.Parent := FCaptionBar;
      Edit.TextPrompt := FmrStr(TFmrStringId.SearchPromptLong);
      Edit.StyledSettings := Edit.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size,
        TStyledSetting.Family];
      Edit.TextSettings.Font.Family := FTheme.Metrics.FontFamily;
      Edit.TextSettings.Font.Size := FTheme.Metrics.FontSize;
      Edit.OnApplyStyleLookup := FCaptionBar.SearchEditApplyStyle;
      Edit.OnChangeTracking := FCaptionBar.SearchEditChangeTracking;
      Edit.OnKeyDown := FCaptionBar.SearchEditKeyDown;
      FCaptionBar.FSearchEdit := Edit;
    end
    else if not FShowSearchBox and (FCaptionBar.FSearchEdit <> nil) then
      FreeAndNil(FCaptionBar.FSearchEdit);
    if FCaptionBar.FSearchEdit <> nil then
    begin
      FCaptionBar.FSearchEdit.TextSettings.FontColor := FTheme.Colors[TFmrToken.SearchBoxText];
      FCaptionBar.FSearchEdit.TextPrompt := FmrStr(TFmrStringId.SearchPromptLong);
    end;
    // Caption buttons when the ribbon draws the title bar.
    NeedButtons := FBarsInHost and (FFrame <> nil) and FFrame.Hooked and (FFrame.Mode <> TFmrFrameMode.NCStrip) and
      not (csDesigning in ComponentState);
    if NeedButtons and (FCaptionBar.FButtons.Count = 0) then
    begin
      for Kind in [TFmrHitArea.CloseButton, TFmrHitArea.MaxButton, TFmrHitArea.MinButton] do
      begin
        Btn := TFmrRibbonCaptionButton.CreateButton(Self, Kind);
        Btn.Parent := FCaptionBar;
        FCaptionBar.FButtons.Add(Btn);
      end;
      if FFrame <> nil then
        FCaptionBar.FrameStateChanged(FFrame.State);
    end
    else if not NeedButtons and (FCaptionBar.FButtons.Count > 0) then
    begin
      for Btn in FCaptionBar.FButtons.ToArray do
        Btn.Free;
      FCaptionBar.FButtons.Clear;
    end;
    FStructureValid := True;
    FLayoutValid := False;
    FArrangeValid := False;
  finally
    FRebuilding := False;
  end;
  UpdateHeights;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    BuildKeyTips(FKeyTipLevel);
end;

function TFmrRibbon.LayoutMetrics: TFmrLayoutMetrics;
var
  M: TFmrThemeMetrics;
begin
  M := FPainter.Metrics;
  Result := TFmrLayoutMetrics.Default;
  Result.ContentHeight := M.ContentHeight;
  Result.RowHeight := M.SmallButtonHeight;
  Result.RowCount := 3;
  Result.GroupPaddingH := M.GroupPaddingH;
  Result.GroupSpacing := M.GroupSpacing;
  Result.ColumnSpacing := 2;
  Result.SeparatorWidth := 9;
  Result.SegmentSpacing := 4;
  Result.DialogLauncherWidth := 16;
  Result.MinGroupWidth := 24;
  Result.SimplifiedHeight := Max(24, M.SimplifiedBodyHeight - 2 * M.BodyPaddingV - 4);
  Result.SimplifiedItemSpacing := 2;
  Result.SimplifiedSeparatorWidth := 13;
  Result.OverflowButtonWidth := 32;
end;

function TFmrRibbon.MeasureCollapsedWidth(const AGroup: TFmrRibbonGroup): Single;
var
  L1, L2: string;
  M: TFmrThemeMetrics;
begin
  M := FPainter.Metrics;
  FmrSplitLargeCaption(FPainter, FmrStripAccel(AGroup.DisplayCaption), M.ArrowSize + 4, L1, L2);
  Result := Max(FPainter.TextWidth(L1), FPainter.TextWidth(L2) + M.ArrowSize + 4) + 12;
  Result := Ceil(Max(Result, M.LargeButtonMinWidth + 8));
end;

function TFmrRibbon.GroupLayoutInput(const AGroup: TFmrRibbonGroup; out AViews: TArray<TFmrItemView>): TFmrLayoutGroup;
var
  I: Integer;
  L: TFmrItemLink;
  V: TFmrItemView;
  M: TFmrThemeMetrics;
begin
  M := FPainter.Metrics;
  Result := System.Default(TFmrLayoutGroup);
  Result.Hidden := not AGroup.Visible;
  if AGroup.ShowCaption then
    Result.CaptionWidth := FPainter.TextWidth(FmrStripAccel(AGroup.DisplayCaption), M.GroupCaptionFontSize);
  Result.HasDialogLauncher := AGroup.ShowDialogLauncher;
  Result.CanCollapse := AGroup.CanCollapse;
  Result.Priority := AGroup.ReductionPriority;
  Result.CollapsedWidth := MeasureCollapsedWidth(AGroup);
  SetLength(Result.Links, AGroup.ItemLinks.Count);
  SetLength(AViews, AGroup.ItemLinks.Count);
  for I := 0 to AGroup.ItemLinks.Count - 1 do
  begin
    L := AGroup.ItemLinks[I];
    V := nil;
    if (L.ViewObject is TFmrItemView) and (FViews.IndexOf(TFmrItemView(L.ViewObject)) >= 0) then
      V := TFmrItemView(L.ViewObject)
    else if L.Item <> nil then
      V := ViewFor(L, FBody, TFmrViewPlace.Group);
    AViews[I] := V;
    if V <> nil then
      Result.Links[I] := V.LayoutLink
    else
    begin
      Result.Links[I] := TFmrLayoutLink.Separator;
      Result.Links[I].Hidden := True;
    end;
    Result.Links[I].Data := I;
  end;
end;

function TFmrRibbon.BodyCardRect: TRectF;
var
  M: TFmrThemeMetrics;
  W, H: Single;
begin
  M := FPainter.Metrics;
  W := FBody.Width;
  if FDisplayMode = TFmrRibbonDisplayMode.Simplified then
    H := M.SimplifiedBodyHeight
  else
    H := M.BodyHeight;
  if FTheme.Style.FloatingBody then
    Result := RectF(M.BodyMargin, 0, W - M.BodyMargin, H)
  else
    Result := RectF(0, 0, W, H);
end;

function TFmrRibbon.GroupAreaRect: TRectF;
var
  M: TFmrThemeMetrics;
  C: TRectF;
  PadH: Single;
begin
  M := FPainter.Metrics;
  C := BodyCardRect;
  if FTheme.Style.FloatingBody then
    PadH := 4
  else
    PadH := 2;
  if FDisplayMode = TFmrRibbonDisplayMode.Simplified then
    Result := RectF(C.Left + 6, C.Top + M.BodyPaddingV, C.Right - 6, C.Bottom - M.BodyPaddingV)
  else
    Result := RectF(C.Left + PadH, C.Top + M.BodyPaddingV, C.Right - PadH,
      C.Top + M.BodyPaddingV + M.GroupPaddingTop + M.ContentHeight + M.GroupCaptionHeight);
  // Room for the classic/simplified switch at the right end of the body.
  if FShowDisplayModeButton then
    Result.Right := Result.Right - 26;
end;

function TFmrRibbon.IsOrb: Boolean;
begin
  Result := (FTheme <> nil) and (FTheme.Style.AppButton = TFmrAppButtonShape.Orb) and FAppButton.Visible;
end;

function TFmrRibbon.TabBarOffset: Single;
begin
  if CaptionBarVisible then
    Result := CaptionBarHeight
  else
    Result := 0;
end;

function TFmrRibbon.OrbRect(const AOffsetY: Single): TRectF;
var
  M: TFmrThemeMetrics;
  D, CX, CY, Top: Single;
begin
  M := FPainter.Metrics;
  if CaptionBarVisible then
  begin
    Top := CaptionBarHeight - M.CaptionHeight;
    D := Min(M.CaptionHeight + M.TabRowHeight - 8, 46);
    CY := Top + (M.CaptionHeight + M.TabRowHeight) / 2 - 1;
  end
  else
  begin
    D := M.TabRowHeight - 2;
    CY := M.TabRowHeight / 2;
  end;
  CX := 6 + D / 2;
  Result := RectF(CX - D / 2, CY - D / 2 - AOffsetY, CX + D / 2, CY + D / 2 - AOffsetY);
end;

procedure TFmrRibbon.PaintOrb(const ACanvas: TCanvas; const AOffsetY: Single);
var
  S: TFmrPartState;
begin
  if not IsOrb or (FAppElement = nil) then
    Exit;
  if FDroppedElement = FAppElement then
    S := TFmrPartState.Pressed
  else if (FAppElement.HotPart <> TFmrElementPart.None) or FAppElement.Focused then
    S := TFmrPartState.Hot
  else
    S := TFmrPartState.Normal;
  FPainter.DrawAppButton(ACanvas, OrbRect(AOffsetY), FAppButton.DisplayCaption, S);
end;

function TFmrRibbon.ActiveTabRect: TRectF;
var
  E: TFmrTabElement;
  TL, BR: TPointF;
begin
  Result := TRectF.Empty;
  for E in FTabElements do
    if (E.FTab = FActiveTab) and E.Visible then
    begin
      TL := FBody.ScreenToLocal(FTabBar.LocalToScreen(E.Bounds.TopLeft));
      BR := FBody.ScreenToLocal(FTabBar.LocalToScreen(E.Bounds.BottomRight));
      Exit(RectF(TL.X, 0, BR.X, 1));
    end;
end;

function TFmrRibbon.TitleText: string;
var
  F: TCommonCustomForm;
begin
  Result := FCaptionText;
  if Result = '' then
  begin
    F := OwnerForm;
    if F <> nil then
      Result := F.Caption;
  end;
end;

function TFmrRibbon.FrameActive: Boolean;
begin
  if FBarsInHost and (FFrame <> nil) and FFrame.Hooked then
    Result := FFrameState.Active
  else
    Result := True;
end;

function TFmrRibbon.ContextColor(const AGroup: TFmrRibbonContextGroup): TAlphaColor;
var
  A: TArray<TFmrRibbonContextGroup>;
  I: Integer;
begin
  if AGroup.Color <> TAlphaColors.Null then
    Exit(AGroup.Color);
  A := TFmrRibbonStructure.ContextGroups(Self);
  Result := DefaultContextColors[0];
  for I := 0 to High(A) do
    if A[I] = AGroup then
      Exit(DefaultContextColors[I mod Length(DefaultContextColors)]);
end;

{ arrangement }

procedure TFmrRibbon.ArrangeTabBar;
var
  M: TFmrThemeMetrics;
  H, W, X, RightX, B, Avail: Single;
  E: TFmrSysButtonElement;
  T: TFmrTabElement;
  Full, Mins, Widths: TArray<Single>;
  I: Integer;
  Caption: string;
  LeftScroll, RightScroll: TFmrSysButtonElement;
  TotalW: Single;
  R: TRectF;
begin
  M := FPainter.Metrics;
  H := FTabBar.Height;
  W := FTabBar.Width;
  X := 4;
  if (FAppElement <> nil) and FAppElement.Visible then
  begin
    if IsOrb then
    begin
      R := OrbRect(TabBarOffset);
      FAppElement.Bounds := R;
      X := R.Right + 8;
    end
    else
    begin
      B := Max(54, FPainter.TextWidth(FAppButton.DisplayCaption) + 2 * M.TabPaddingH + 6);
      FAppElement.Bounds := RectF(2, 1, 2 + B, H);
      X := 2 + B + M.TabSpacing + 2;
    end;
  end;
  RightX := W - 2;
  LeftScroll := nil;
  RightScroll := nil;
  for E in FTabSysElements do
    case E.Kind of
      TFmrSysButtonKind.Help, TFmrSysButtonKind.CollapseRibbon:
        begin
          B := H - 6;
          E.Bounds := RectF(RightX - B, (H - B) / 2, RightX, (H + B) / 2);
          E.Visible := True;
          RightX := RightX - B - 2;
        end;
      TFmrSysButtonKind.TabScrollLeft:
        LeftScroll := E;
      TFmrSysButtonKind.TabScrollRight:
        RightScroll := E;
    end;
  SetLength(Full, FTabElements.Count);
  SetLength(Mins, FTabElements.Count);
  for I := 0 to FTabElements.Count - 1 do
  begin
    Caption := FmrStripAccel(FTabElements[I].FTab.DisplayCaption);
    if FTheme.Style.UppercaseTabs then
      Caption := Caption.ToUpper;
    Full[I] := Ceil(FPainter.TextWidth(Caption) + 2 * M.TabPaddingH);
    Mins[I] := Ceil(Min(Full[I], FPainter.TextWidth(Caption) + 10));
  end;
  Avail := RightX - X - 4;
  Widths := FmrLayoutTabs(Full, Mins, Avail, FTabsFit);
  TotalW := 0;
  for I := 0 to High(Widths) do
    TotalW := TotalW + Widths[I] + M.TabSpacing;
  if FTabsFit then
    FTabScroll := 0
  else
    FTabScroll := EnsureRange(FTabScroll, 0, Max(0, TotalW - Avail + 2 * M.ScrollButtonWidth));
  if LeftScroll <> nil then
  begin
    LeftScroll.Visible := not FTabsFit and (FTabScroll > 0);
    LeftScroll.Bounds := RectF(X, 2, X + M.ScrollButtonWidth, H - 2);
  end;
  if RightScroll <> nil then
  begin
    RightScroll.Visible := not FTabsFit and (FTabScroll < TotalW - Avail + 2 * M.ScrollButtonWidth - 0.5);
    RightScroll.Bounds := RectF(RightX - M.ScrollButtonWidth - 2, 2, RightX - 2, H - 2);
  end;
  if not FTabsFit then
    X := X + M.ScrollButtonWidth;
  for I := 0 to FTabElements.Count - 1 do
  begin
    T := FTabElements[I];
    T.FFullWidth := Full[I];
    T.FMinWidth := Mins[I];
    T.Bounds := RectF(X - FTabScroll, 1, X - FTabScroll + Widths[I], H);
    T.Visible := True;
    X := X + Widths[I] + M.TabSpacing;
  end;
end;

procedure TFmrRibbon.ArrangeQAT(const AArea: TRectF; const AHost: TFmrRibbonPart;
  const ASysList: TObjectList<TFmrSysButtonElement>; out AUsed: TRectF);
var
  M: TFmrThemeMetrics;
  V: TFmrItemView;
  E, Customize, Overflow: TFmrSysButtonElement;
  X, Y, S, W, Reserve: Single;
  Shown: Boolean;
begin
  M := FPainter.Metrics;
  S := M.QATButtonSize;
  Y := Round(AArea.Top + (AArea.Height - S) / 2);
  X := AArea.Left;
  Customize := nil;
  Overflow := nil;
  for E in ASysList do
    case E.Kind of
      TFmrSysButtonKind.QATCustomize: Customize := E;
      TFmrSysButtonKind.QATOverflow: Overflow := E;
    end;
  Reserve := 0;
  if Customize <> nil then
    Reserve := Reserve + 18;
  FQATOverflow.Clear;
  Shown := FQAT.Visible and (((FQAT.Position = TFmrQATPosition.AboveRibbon) and CaptionBarVisible) =
    (AHost = FCaptionBar));
  for V in FQATViews do
  begin
    if not Shown or (V.Host = nil) or (V.Host.GetHostControl <> AHost) or not V.Link.IsVisible then
    begin
      if (V.Host <> nil) and (V.Host.GetHostControl = AHost) then
        V.Hide;
      Continue;
    end;
    W := V.MeasureWidth(TFmrViewLevel.Small);
    if (FQATOverflow.Count = 0) and (X + W <= AArea.Right - Reserve - 18) then
    begin
      V.Place(RectF(X, Y, X + W, Y + S), TFmrViewLevel.Small, TFmrLayoutSegment.None);
      X := X + W;
    end
    else
    begin
      V.Hide;
      FQATOverflow.Add(V);
    end;
  end;
  if Overflow <> nil then
  begin
    Overflow.Visible := Shown and (FQATOverflow.Count > 0);
    if Overflow.Visible then
    begin
      Overflow.Bounds := RectF(X, Y, X + 16, Y + S);
      X := X + 16;
    end;
  end;
  if Customize <> nil then
  begin
    Customize.Visible := Shown;
    Customize.Bounds := RectF(X + 1, Y, X + 17, Y + S);
    if Shown then
      X := X + 18;
  end;
  AUsed := RectF(AArea.Left, AArea.Top, X, AArea.Bottom);
end;

procedure TFmrRibbon.ArrangeCaptionBar;
var
  M: TFmrThemeMetrics;
  W, CH, Top, X, RightX, SW, SX, TW, TL: Single;
  Used, R, Free, Best, Seg: TRectF;
  CG: TFmrRibbonContextGroup;
  T: TFmrTabElement;
  Btn: TFmrRibbonCaptionButton;
  L, Rt: Single;
  Found: Boolean;
  Headers: TList<TPair<TFmrRibbonContextGroup, TRectF>>;
  Spans: TArray<TRectF>;
  I: Integer;
  Title: string;
  Segs: TList<TRectF>;
  SysKind: TFmrSysButtonKind;
  SysE: TFmrSysButtonElement;
  SysW: Single;
begin
  M := FPainter.Metrics;
  W := FCaptionBar.Width;
  CH := FCaptionBar.Height;
  Top := CH - M.CaptionHeight;
  X := 6;
  if IsOrb then
    X := OrbRect(0).Right + 6;
  // Caption buttons from the right: close, maximize, minimize (created in that order). They are real controls: in
  // a right-to-left ribbon they get mirrored bounds (on the left, like Windows).
  RightX := W;
  for Btn in FCaptionBar.FButtons do
  begin
    RightX := RightX - CaptionButtonWidth;
    if EffectiveRightToLeft then
      Btn.SetBounds(W - RightX - CaptionButtonWidth, Top, CaptionButtonWidth, M.CaptionHeight)
    else
      Btn.SetBounds(RightX, Top, CaptionButtonWidth, M.CaptionHeight);
  end;
  // Display options, then the "..." of the auto-hidden ribbon, left of the window buttons.
  for SysKind in [TFmrSysButtonKind.DisplayOptions, TFmrSysButtonKind.AutoHideShow] do
    for SysE in FCaptionSysElements do
      if SysE.Kind = SysKind then
      begin
        if FCaptionBar.FButtons.Count > 0 then
          SysW := CaptionButtonWidth
        else
          SysW := Round(M.CaptionHeight + 8);
        RightX := RightX - SysW;
        SysE.Bounds := RectF(RightX, Top, RightX + SysW, CH);
        SysE.Visible := True;
      end;
  // quick access toolbar above the ribbon
  if FQAT.Visible and (FQAT.Position = TFmrQATPosition.AboveRibbon) then
  begin
    ArrangeQAT(RectF(X, Top, Max(X, Min(W * 0.5, RightX - 120)), CH), FCaptionBar, FCaptionSysElements, Used);
    FCaptionBar.FQATRect := Used;
    if Used.Width > 0 then
      X := Used.Right + 8;
  end
  else
    FCaptionBar.FQATRect := TRectF.Empty;
  // contextual tab group headers above their tabs
  Headers := TList<TPair<TFmrRibbonContextGroup, TRectF>>.Create;
  try
    if FShowTabGroups and FTabBar.Visible and (FAutoHidePopup = nil) then
      for CG in TFmrRibbonStructure.ContextGroups(Self) do
      begin
        if not CG.Visible and not ((FDesignTab <> nil) and (FDesignTab.ContextGroup = CG)) then
          Continue;
        Found := False;
        L := 0;
        Rt := 0;
        for T in FTabElements do
          if T.Visible and (T.FTab.ContextGroup = CG) then
          begin
            if not Found then
            begin
              L := T.Bounds.Left;
              Rt := T.Bounds.Right;
              Found := True;
            end
            else
            begin
              L := Min(L, T.Bounds.Left);
              Rt := Max(Rt, T.Bounds.Right);
            end;
          end;
        if Found then
        begin
          R := RectF(L, Top, Rt, CH);
          // The caption bar and the tab bar may have different origins (different parents).
          R.Left := FCaptionBar.ScreenToLocal(FTabBar.LocalToScreen(PointF(L, 0))).X;
          R.Right := FCaptionBar.ScreenToLocal(FTabBar.LocalToScreen(PointF(Rt, 0))).X;
          Headers.Add(TPair<TFmrRibbonContextGroup, TRectF>.Create(CG, R));
        end;
      end;
    FContextHeaders := Headers.ToArray;
  finally
    Headers.Free;
  end;
  // search box
  if FShowSearchBox then
  begin
    SW := Min(360, Max(150, (RightX - X) * 0.36));
    SX := Round((W - SW) / 2);
    if SX < X + 30 then
      SX := X + 30;
    // Keep clear of the contextual tab group headers.
    for I := 0 to High(FContextHeaders) do
      if (SX < FContextHeaders[I].Value.Right + 8) and (SX + SW > FContextHeaders[I].Value.Left - 8) then
        SX := Round(FContextHeaders[I].Value.Right + 12);
    if SX + SW > RightX - 8 then
      SW := Max(60, RightX - 8 - SX);
    FCaptionBar.FSearchRect := RectF(SX, Top + 4, SX + SW, CH - 4);
    if FCaptionBar.FSearchEdit <> nil then
    begin
      if EffectiveRightToLeft then
        FCaptionBar.FSearchEdit.SetBounds(W - (SX + 24) - (SW - 28), Top + 4, SW - 28, M.CaptionHeight - 8)
      else
        FCaptionBar.FSearchEdit.SetBounds(SX + 24, Top + 4, SW - 28, M.CaptionHeight - 8);
      FCaptionBar.FSearchEdit.Visible := SW > 60;
    end;
    RightX := SX - 8;
  end
  else
    FCaptionBar.FSearchRect := TRectF.Empty;
  // title: centered in the window, inside the free space that avoids the QAT, the search box and the headers
  Title := TitleText;
  FCaptionBar.FTitleRect := TRectF.Empty;
  // No title in the strip under the system caption (NCStrip) nor in a caption row inside the ribbon under a native
  // title bar, unless CaptionText asks for one.
  if (Title <> '') and not (FBarsInHost and (FFrame <> nil) and FFrame.Hooked and
    (FFrame.Mode = TFmrFrameMode.NCStrip)) and (FBarsInHost or (FCaptionText <> '') or (OwnerForm = nil) or
    (OwnerForm.BorderStyle = TFmxFormBorderStyle.None)) then
  begin
    TW := FPainter.TextWidth(Title, M.CaptionFontSize) + 16;
    Free := RectF(X, Top, RightX - 4, CH);
    SetLength(Spans, Length(FContextHeaders));
    for I := 0 to High(FContextHeaders) do
      Spans[I] := FContextHeaders[I].Value;
    Segs := TList<TRectF>.Create;
    try
      Segs.Add(Free);
      for R in Spans do
        for I := Segs.Count - 1 downto 0 do
        begin
          Seg := Segs[I];
          if (R.Right <= Seg.Left) or (R.Left >= Seg.Right) then
            Continue;
          Segs.Delete(I);
          if R.Left - Seg.Left > 20 then
            Segs.Add(RectF(Seg.Left, Seg.Top, R.Left - 4, Seg.Bottom));
          if Seg.Right - R.Right > 20 then
            Segs.Add(RectF(R.Right + 4, Seg.Top, Seg.Right, Seg.Bottom));
        end;
      Best := TRectF.Empty;
      TL := (W - TW) / 2;
      for Seg in Segs do
        if (TL >= Seg.Left) and (TL + TW <= Seg.Right) then
        begin
          Best := RectF(TL, Top, TL + TW, CH);
          Break;
        end;
      if Best.IsEmpty then
        for Seg in Segs do
          if Seg.Width > Best.Width then
            Best := Seg;
      if not Best.IsEmpty and (Best.Width > 30) then
      begin
        if Best.Width > TW then
        begin
          TL := EnsureRange((W - TW) / 2, Best.Left, Best.Right - TW);
          Best := RectF(TL, Top, TL + TW, CH);
        end;
        FCaptionBar.FTitleRect := Best;
      end;
    finally
      Segs.Free;
    end;
  end;
end;

procedure TFmrRibbon.ArrangeBody;
var
  V: TFmrItemView;
  E: TFmrElement;
begin
  FBody.Tracker.Reset;
  for E in FBodyElements do
  begin
    if FDroppedElement = E then
      FDroppedElement := nil;
    if FKeyFocus = E then
      FKeyFocus := nil;
  end;
  if FScreenTips <> nil then
    FScreenTips.Cancel;
  FBodyElements.Clear;
  for V in FBodyViews do
    if (V.Host <> nil) and (V.Host.GetHostControl = FBody) then
      V.Hide;
  FBodyViews.Clear;
  FGroupBoxes := nil;
  FSimplifiedOverflow := nil;
  if (FActiveTab = nil) or (FBody.Width <= 0) then
    Exit;
  if FDisplayMode = TFmrRibbonDisplayMode.Simplified then
    ArrangeBodySimplified(GroupAreaRect)
  else
    ArrangeBodyClassic(GroupAreaRect);
  if FShowDisplayModeButton and not (csDesigning in ComponentState) then
    AddDisplayModeButton(GroupAreaRect);
  if FKeyTipLevel = TFmrKeyTipLevel.Tab then
    BuildKeyTips(TFmrKeyTipLevel.Tab);
end;

procedure TFmrRibbon.ArrangeBodyClassic(const AContent: TRectF);
var
  M: TFmrThemeMetrics;
  R: TFmrLayoutResult;
  Info: TFmrGroupScrollInfo;
  GI, LI, N: Integer;
  Res: TFmrLayoutGroupResult;
  LR: TFmrLayoutLinkResult;
  GX, ContentTop, GroupH: Single;
  GR: TRectF;
  Box: TFmrGroupBox;
  Group: TFmrRibbonGroup;
  Views: TArray<TFmrItemView>;
  Coll: TFmrCollapsedGroupElement;
  Launcher: TFmrLauncherElement;
  Card: TRectF;
  Scroll: TFmrSysButtonElement;
begin
  M := FPainter.Metrics;
  R := FCalc.Calculate(AContent.Width);
  // Right to left: the layout stays left to right here; the body flips its canvas and the mouse (FMR.Ribbon.BiDi).
  FLayoutResult := R;
  if R.Fits then
    FScrollOffset := 0
  else
  begin
    Info := FmrGroupScrollInfo(R, AContent.Width, FScrollOffset);
    FScrollOffset := Info.Offset;
  end;
  GroupH := M.GroupPaddingTop + M.ContentHeight + M.GroupCaptionHeight;
  SetLength(FGroupBoxes, Length(R.Groups));
  N := 0;
  for GI := 0 to High(R.Groups) do
  begin
    Res := R.Groups[GI];
    if not Res.Visible or (GI > High(FLayoutGroups)) or (FLayoutGroups[GI] = nil) then
      Continue;
    Group := FLayoutGroups[GI];
    GX := Round(AContent.Left + Res.Left - FScrollOffset);
    GR := RectF(GX, AContent.Top, GX + Res.Width, AContent.Top + GroupH);
    Box.Group := Group;
    Box.Rect := GR;
    Box.Collapsed := Res.Collapsed;
    Box.Separators := Res.Separators;
    Box.LayoutIndex := GI;
    FGroupBoxes[N] := Box;
    Inc(N);
    GroupLayoutInput(Group, Views);
    if Res.Collapsed then
    begin
      // Views shown by the open popup of this group stay there.
      for LI := 0 to High(Views) do
        if (Views[LI] <> nil) and not ((Views[LI].Host <> nil) and
          (Views[LI].Host.GetHostControl is TFmrGroupPopupContent)) then
          Views[LI].Hide;
      Coll := TFmrCollapsedGroupElement.Create(FBody);
      Coll.FRibbon := Self;
      Coll.FGroup := Group;
      Coll.Bounds := RectF(GR.Left + 1, GR.Top, GR.Right - 1, GR.Bottom);
      FBodyElements.Add(Coll);
      if (FGroupPopupContent <> nil) and (FGroupPopupContent.FGroup = Group) and (FDropPopup = FGroupPopup) then
        FDroppedElement := Coll;
      Continue;
    end;
    ContentTop := GR.Top + M.GroupPaddingTop;
    for LI := 0 to High(Views) do
    begin
      if Views[LI] = nil then
        Continue;
      if LI <= High(Res.Links) then
        LR := Res.Links[LI]
      else
        LR := System.Default(TFmrLayoutLinkResult);
      if LR.Visible and (Views[LI].Host <> nil) and not (Views[LI].Host.GetHostControl is TFmrGroupPopupContent) then
      begin
        if Views[LI].Host.GetHostControl <> FBody then
          Views[LI].SetHost(FBody);
        Views[LI].Place(RectF(GX + LR.Bounds.Left, ContentTop + LR.Bounds.Top, GX + LR.Bounds.Right,
          ContentTop + LR.Bounds.Bottom), LR.Level, LR.Segment);
        FBodyViews.Add(Views[LI]);
      end
      else
        Views[LI].Hide;
    end;
    if Group.ShowDialogLauncher then
    begin
      Launcher := TFmrLauncherElement.Create(FBody);
      Launcher.FRibbon := Self;
      Launcher.FGroup := Group;
      Launcher.Bounds := RectF(GR.Right - 16, GR.Bottom - M.GroupCaptionHeight + 2, GR.Right - 2, GR.Bottom - 2);
      FBodyElements.Add(Launcher);
    end;
  end;
  SetLength(FGroupBoxes, N);
  if not R.Fits then
  begin
    Card := BodyCardRect;
    Info := FmrGroupScrollInfo(R, AContent.Width, FScrollOffset);
    if Info.CanScrollLeft then
    begin
      Scroll := TFmrSysButtonElement.Create(FBody);
      Scroll.FRibbon := Self;
      Scroll.FKind := TFmrSysButtonKind.ScrollLeft;
      Scroll.Bounds := RectF(Card.Left + 1, AContent.Top, Card.Left + 1 + M.ScrollButtonWidth, AContent.Bottom);
      FBodyElements.Add(Scroll);
    end;
    if Info.CanScrollRight then
    begin
      Scroll := TFmrSysButtonElement.Create(FBody);
      Scroll.FRibbon := Self;
      Scroll.FKind := TFmrSysButtonKind.ScrollRight;
      Scroll.Bounds := RectF(Card.Right - 1 - M.ScrollButtonWidth, AContent.Top, Card.Right - 1, AContent.Bottom);
      FBodyElements.Add(Scroll);
    end;
  end;
end;

procedure TFmrRibbon.ArrangeBodySimplified(const AContent: TRectF);
var
  M: TFmrThemeMetrics;
  LM: TFmrLayoutMetrics;
  SR: TFmrSimplifiedLayoutResult;
  GI, LI: Integer;
  Views: TArray<TFmrItemView>;
  LR: TFmrSimplifiedLinkResult;
  V: TFmrItemView;
  Level: TFmrViewLevel;
  LineTop, H, Y: Single;
  Overflow: TFmrSysButtonElement;
  Ref: TFmrLinkRef;
  Group: TFmrRibbonGroup;
begin
  M := FPainter.Metrics;
  LM := LayoutMetrics;
  SR := FCalc.CalculateSimplified(AContent.Width);
  FSimplifiedResult := SR;
  FScrollOffset := 0;
  LineTop := AContent.Top + (AContent.Height - LM.SimplifiedHeight) / 2;
  H := Min(LM.SimplifiedHeight, M.SmallButtonHeight + 6);
  Y := Round(LineTop + (LM.SimplifiedHeight - H) / 2);
  for GI := 0 to High(SR.Groups) do
  begin
    if (GI > High(FLayoutGroups)) or (FLayoutGroups[GI] = nil) then
      Continue;
    GroupLayoutInput(FLayoutGroups[GI], Views);
    for LI := 0 to High(Views) do
    begin
      V := Views[LI];
      if V = nil then
        Continue;
      if LI <= High(SR.Groups[GI].Links) then
        LR := SR.Groups[GI].Links[LI]
      else
        LR := System.Default(TFmrSimplifiedLinkResult);
      if not LR.Visible then
      begin
        V.Hide;
        Continue;
      end;
      if LR.Bounds.Width >= V.MeasureWidth(TFmrViewLevel.SmallWithText) - 0.5 then
        Level := TFmrViewLevel.SmallWithText
      else
        Level := TFmrViewLevel.Small;
      if V.Host.GetHostControl <> FBody then
        V.SetHost(FBody);
      V.Place(RectF(AContent.Left + LR.Bounds.Left, Y, AContent.Left + LR.Bounds.Right, Y + H), Level,
        TFmrLayoutSegment.None);
      FBodyViews.Add(V);
    end;
  end;
  SetLength(FSimplifiedOverflow, Length(SR.Overflow));
  for LI := 0 to High(SR.Overflow) do
  begin
    Ref := SR.Overflow[LI];
    Group := FLayoutGroups[Ref.Group];
    if (Group <> nil) and (Ref.Link < Group.ItemLinks.Count) then
      FSimplifiedOverflow[LI] := Group.ItemLinks[Ref.Link]
    else
      FSimplifiedOverflow[LI] := nil;
  end;
  if SR.OverflowButtonVisible then
  begin
    Overflow := TFmrSysButtonElement.Create(FBody);
    Overflow.FRibbon := Self;
    Overflow.FKind := TFmrSysButtonKind.SimplifiedOverflow;
    Overflow.Bounds := RectF(AContent.Left + SR.OverflowButtonBounds.Left, Y, AContent.Left +
      SR.OverflowButtonBounds.Right, Y + H);
    FBodyElements.Add(Overflow);
  end;
end;

procedure TFmrRibbon.ArrangeQATBar;
var
  Used: TRectF;
begin
  if (FQATBar = nil) or not FQATBar.Visible then
  begin
    if FQATBar <> nil then
      ArrangeQAT(RectF(0, 0, 0, 0), FQATBar, FQATBarSysElements, Used);
    Exit;
  end;
  ArrangeQAT(RectF(6, 0, FQATBar.Width - 6, FQATBar.Height), FQATBar, FQATBarSysElements, Used);
end;

{ messages }

procedure TFmrRibbon.IdleHandler(const Sender: TObject; const M: TMessage);
var
  V: TFmrItemView;
begin
  if FDestroying or (csDestroying in ComponentState) then
    Exit;
  if FFrameCheckPending then
  begin
    FFrameCheckPending := False;
    UpdateFrameAttachment;
  end;
  if not FArrangeValid or not FLayoutValid or not FStructureValid then
  begin
    EnsureAll;
    if FArrangeValid and FLayoutValid and FStructureValid then
      FNeedRepaint := True;
  end;
  if FNeedRepaint then
  begin
    FNeedRepaint := False;
    InvalidateParts;
  end;
  if not (csDesigning in ComponentState) then
  begin
    // A ribbon built in code: its designed layout is the one of the first idle (before any customization).
    if (FDefaultLayout = '') and FStructureValid and (FUpdateCount = 0) then
      CaptureDefaultLayout;
    // The BiDiMode of the form has no change notification.
    if EffectiveRightToLeft <> FLastRTL then
    begin
      FLastRTL := EffectiveRightToLeft;
      ClosePopups;
      InvalidateStructure;
    end;
  end;
  if FAppMenuTracking or FAppMenuCovering or (FApplicationMenu is TControl) then
    UpdateApplicationMenuState;
  if not (csDesigning in ComponentState) then
    for V in FBodyViews.ToArray + FQATViews.ToArray do
      if V.Visible and (V.Item <> nil) and (V.Item.Action <> nil) then
        V.Item.UpdateFromAction;
end;

procedure TFmrRibbon.StyleChangedHandler(const Sender: TObject; const M: TMessage);
var
  Msg: TStyleChangedMessage;
  Form: TCommonCustomForm;
begin
  if FDestroying then
    Exit;
  Msg := TStyleChangedMessage(M);
  Form := OwnerForm;
  if (Msg.Scene <> nil) and ((Form = nil) or (Msg.Scene.GetObject <> Form)) then
    Exit;
  BuildTheme;
  InvalidateStructure;
  UpdateHeights;
end;

procedure TFmrRibbon.MenuLoopHandler(const Sender: TObject; const M: TMessage);
var
  Msg: TStartMenuLoopMessage;
begin
  if FDestroying or not FShowKeyTips or not Visible or (csDesigning in ComponentState) or FAppMenuCovering then
    Exit;
  Msg := TStartMenuLoopMessage(M);
  if (Msg.Root = nil) or (Msg.Root.GetObject <> OwnerForm) then
    Exit;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    HideKeyTips
  else if FAltArmed and not FmrPopups.IsOpen then
    ShowKeyTipsNow;
  FAltArmed := False;
end;

procedure TFmrRibbon.DeactivateHandler(const Sender: TObject; const M: TMessage);
begin
  if FDestroying then
    Exit;
  if (M is TFormDeactivateMessage) and (TFormDeactivateMessage(M).Value = OwnerForm) then
  begin
    FAltArmed := False;
    if FKeyTipLevel <> TFmrKeyTipLevel.None then
      HideKeyTips;
    if FScreenTips <> nil then
      FScreenTips.Cancel;
  end;
end;

procedure TFmrRibbon.FrameStateHandler(const Sender: TObject; const M: TMessage);
var
  State: TFmrFrameState;
begin
  // Sent after the frame finished attaching or detaching (State.Hooked) and on every change of the window state:
  // the caption buttons, the title and the heights depend on Hooked and Mode.
  // A frame created on the form after the ribbon is found on the next idle.
  if not FDestroying and (FFrame = nil) and FFrameAuto and (Sender is TFmrFormFrame) and
    (TFmrFormFrame(Sender).Form <> nil) and (TFmrFormFrame(Sender).Form = OwnerForm) then
    FFrameCheckPending := True;
  if FDestroying or (FFrame = nil) or not (M is TFmrFrameStateMessage) or
    (TFmrFrameStateMessage(M).Host <> FFrame.Host) then
    Exit;
  State := TFmrFrameStateMessage(M).State;
  if (State.Hooked <> FLastHooked) or (State.Mode <> FLastMode) then
  begin
    FLastHooked := State.Hooked;
    FLastMode := State.Mode;
    InvalidateStructure;
    UpdateHeights;
  end;
end;

procedure TFmrRibbon.LanguageHandler(const Sender: TObject; const M: TMessage);
begin
  if not FDestroying then
  begin
    InvalidateStructure;
    InvalidateLayout;
  end;
end;

{ popups and commands }

function TFmrRibbon.NewPopupContext: IFmrPopupContext;
var
  Ctx: TRibbonPopupContext;
begin
  Ctx := TRibbonPopupContext.Create(FPainter, GetThemeImages, OwnerForm);
  Ctx.FRibbon := Self;
  Result := Ctx;
  Result.KeyTipsActive := FKeyTipLevel <> TFmrKeyTipLevel.None;
end;

function TFmrRibbon.ElementScreenRect(const AElement: TFmrElement; const AHost: TControl): TRectF;
var
  TL, BR: TPointF;
  R: TRectF;
begin
  R := AElement.Bounds;
  if (AHost is TFmrRibbonPart) and TFmrRibbonPart(AHost).IsMirrored then
    R := FmrMirrorRect(R, AHost.Width);
  TL := AHost.LocalToScreen(R.TopLeft);
  BR := AHost.LocalToScreen(R.BottomRight);
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

procedure TFmrRibbon.ClosePopups;
begin
  if FScreenTips <> nil then
    FScreenTips.Cancel;
  if FmrPopupsAssigned then
    FmrPopups.CloseAll;
end;

procedure TFmrRibbon.DropDownClosed(const APopup: TFmrPopupForm);
var
  E: TFmrElement;
begin
  if FDropPopup <> APopup then
    Exit;
  E := FDroppedElement;
  FDropPopup := nil;
  FDroppedElement := nil;
  if E <> nil then
    E.Invalidate;
  if FDestroying then
    Exit;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    InvalidateParts;
end;

procedure TFmrRibbon.ShowPopupForElement(const AContent: TControl; const AElement: TFmrElement;
  const AHost: TFmrRibbonPart; const AByKeyboard: Boolean; const AOwned: TObject;
  const APlacement: TFmrPopupPlacement);
var
  Ctx: IFmrPopupContext;
  Popup: TFmrPopupForm;
  ParentPopup: TFmrPopupForm;
begin
  if AContent = nil then
  begin
    AOwned.Free;
    Exit;
  end;
  if AContent is TFmrMenuControl then
    Ctx := TFmrMenuControl(AContent).Context
  else
    Ctx := NewPopupContext;
  ParentPopup := FmrPopups.PopupOf(AHost);
  Popup := TFmrPopupForm.CreatePopup(Ctx, AContent);
  if AOwned <> nil then
    Popup.OwnObject(AOwned);
  Popup.AnchorElement := AElement;
  FDroppedElement := AElement;
  FDropPopup := Popup;
  if AElement <> nil then
    AElement.Invalidate;
  Popup.OnClosed :=
    procedure
    begin
      DropDownClosed(Popup);
    end;
  FScreenTips.Cancel;
  if AElement <> nil then
    FmrPopups.Show(Popup, ElementScreenRect(AElement, AHost), APlacement, ParentPopup, AByKeyboard)
  else
    FmrPopups.Show(Popup, AHost.AbsoluteRect, APlacement, ParentPopup, AByKeyboard);
end;

procedure TFmrRibbon.ShowDropDown(const AElement: TFmrElement; const AHost: TFmrRibbonPart;
  const AByKeyboard: Boolean);
var
  Ctx: IFmrPopupContext;
  Content: TControl;
begin
  if (csDesigning in ComponentState) or FDestroying then
    Exit;
  if FDroppedElement = AElement then
  begin
    ClosePopups;
    Exit;
  end;
  if AElement is TFmrTabElement then
    TabElementPressed(TFmrTabElement(AElement), AByKeyboard)
  else if AElement is TFmrAppButtonElement then
    ApplicationButtonPressed(AByKeyboard)
  else if AElement is TFmrCollapsedGroupElement then
    ShowGroupPopup(TFmrCollapsedGroupElement(AElement), AByKeyboard)
  else if AElement is TFmrSysButtonElement then
    SysButtonExecute(TFmrSysButtonElement(AElement), AByKeyboard)
  else if AElement is TFmrItemView then
  begin
    Ctx := NewPopupContext;
    Content := FmrCreateDropDownContent(TFmrItemView(AElement).Item, Ctx);
    if Content <> nil then
    begin
      if not (Content is TFmrMenuControl) then
        ShowPopupForElement(Content, AElement, AHost, AByKeyboard)
      else
        ShowPopupForElement(Content, AElement, AHost, AByKeyboard);
    end;
  end;
end;

procedure TFmrRibbon.TabElementPressed(const AElement: TFmrTabElement; const AByKeyboard: Boolean);
begin
  if (AElement = nil) or (AElement.FTab = nil) then
    Exit;
  if csDesigning in ComponentState then
  begin
    SetActiveTab(AElement.FTab);
    Exit;
  end;
  // The auto-hide overlay shows the tabs and the body together: a tab only switches.
  if FAutoHidePopup <> nil then
  begin
    SetActiveTab(AElement.FTab);
    Exit;
  end;
  if IsCollapsed then
  begin
    if (FMinimizedPopup <> nil) and (AElement.FTab = FActiveTab) then
    begin
      ClosePopups;
      Exit;
    end;
    ClosePopups;
    SetActiveTab(AElement.FTab);
    if FActiveTab = AElement.FTab then
      ShowMinimizedPopup(AByKeyboard);
  end
  else
    SetActiveTab(AElement.FTab);
end;

procedure TFmrRibbon.ShowMinimizedPopup(const AByKeyboard: Boolean);
var
  Ctx: IFmrPopupContext;
  Popup: TFmrPopupForm;
  Anchor: TRectF;
  TL, BR: TPointF;
begin
  if (FBody = nil) or (FMinimizedPopup <> nil) or (FAutoHidePopup <> nil) then
    Exit;
  EnsureAll;
  Ctx := NewPopupContext;
  FBody.Visible := True;
  Popup := TFmrPopupForm.CreatePopup(Ctx, FBody);
  Popup.ShadowSize := 6;
  FMinimizedPopup := Popup;
  Popup.OnClosed :=
    procedure
    begin
      Popup.ReleaseContent;
      if FMinimizedPopup = Popup then
        FMinimizedPopup := nil;
      if FDestroying or (FBody = nil) then
        Exit;
      FBody.Parent := Self;
      UpdateHeights;
      InvalidateArrange;
      InvalidateParts;
      if FKeyTipLevel = TFmrKeyTipLevel.Tab then
        BuildKeyTips(TFmrKeyTipLevel.Top);
    end;
  TL := FTabBar.LocalToScreen(PointF(0, 0));
  BR := FTabBar.LocalToScreen(PointF(FTabBar.Width, FTabBar.Height));
  Anchor := RectF(TL.X - 7, TL.Y, BR.X, BR.Y - 1);
  FmrPopups.Show(Popup, Anchor, TFmrPopupPlacement.Below, nil, AByKeyboard);
  InvalidateArrange;
  EnsureAll;
  FBody.Repaint;
  FTabBar.Repaint;
end;

procedure TFmrRibbon.ShowGroupPopup(const AElement: TFmrCollapsedGroupElement; const AByKeyboard: Boolean);
var
  Content: TFmrGroupPopupContent;
  Ctx: IFmrPopupContext;
  Popup: TFmrPopupForm;
  ParentPopup: TFmrPopupForm;
begin
  if AElement = nil then
    Exit;
  ParentPopup := FmrPopups.PopupOf(FBody);
  Content := TFmrGroupPopupContent.CreateFor(Self, AElement.FGroup);
  // The popup window owns the content.
  RemoveComponent(Content);
  Ctx := NewPopupContext;
  Popup := TFmrPopupForm.CreatePopup(Ctx, Content);
  FGroupPopup := Popup;
  FGroupPopupContent := Content;
  FDroppedElement := AElement;
  FDropPopup := Popup;
  AElement.Invalidate;
  Popup.OnClosed :=
    procedure
    begin
      Content.ReturnViews;
      if FGroupPopup = Popup then
      begin
        FGroupPopup := nil;
        FGroupPopupContent := nil;
      end;
      DropDownClosed(Popup);
      if not FDestroying and (FKeyTipLevel = TFmrKeyTipLevel.GroupPopup) then
        BuildKeyTips(TFmrKeyTipLevel.Tab);
    end;
  FScreenTips.Cancel;
  FmrPopups.Show(Popup, ElementScreenRect(AElement, FBody), TFmrPopupPlacement.Below, ParentPopup, AByKeyboard);
end;

procedure TFmrRibbon.ApplicationButtonPressed(const AByKeyboard: Boolean);
var
  AM: IFmrApplicationMenu;
  R: TRectF;
begin
  if csDesigning in ComponentState then
    Exit;
  ClosePopups;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    HideKeyTips;
  if Assigned(FOnApplicationButtonClick) then
  begin
    FOnApplicationButtonClick(Self);
    Exit;
  end;
  R := ApplicationButtonScreenRect;
  if (FApplicationMenu <> nil) and Supports(FApplicationMenu, IFmrApplicationMenu, AM) then
    AM.ShowApplicationMenu(Self, R, AByKeyboard)
  else if FApplicationMenu is TFmrPopupMenu then
  begin
    if TFmrPopupMenu(FApplicationMenu).ThemeSource = nil then
      TFmrPopupMenu(FApplicationMenu).ThemeSource := Self;
    TFmrPopupMenu(FApplicationMenu).PopupBelow(R);
  end
  else if FApplicationMenu <> nil then
    InvokeApplicationMenu(R, AByKeyboard);
  FAppMenuTracking := True;
  UpdateApplicationMenuState;
end;

function TFmrRibbon.ApplicationMenuCovers: Boolean;
var
  AM: IFmrApplicationMenu;
  Ctx: TRttiContext;
  M: TRttiMethod;
  Open: Boolean;
begin
  // A backstage view (a control of the form shown over the client area) hides the tab row of the frame while it is
  // open; popup menus leave the ribbon as it is.
  if not (FApplicationMenu is TControl) or not TControl(FApplicationMenu).Visible then
    Exit(False);
  if Supports(FApplicationMenu, IFmrApplicationMenu, AM) then
    Open := AM.IsApplicationMenuOpen
  else
  begin
    M := Ctx.GetType(FApplicationMenu.ClassType).GetMethod('IsApplicationMenuOpen');
    Open := (M <> nil) and (Length(M.GetParameters) = 0) and (M.ReturnType <> nil) and
      (M.ReturnType.Handle = TypeInfo(Boolean)) and M.Invoke(FApplicationMenu, []).AsBoolean;
  end;
  Result := Open;
end;

procedure TFmrRibbon.UpdateApplicationMenuState;
var
  Covers: Boolean;
begin
  if FDestroying then
    Exit;
  Covers := ApplicationMenuCovers;
  if not Covers then
    FAppMenuTracking := False;
  if Covers <> FAppMenuCovering then
  begin
    FAppMenuCovering := Covers;
    if Covers then
    begin
      ClosePopups;
      if FKeyTipLevel <> TFmrKeyTipLevel.None then
        HideKeyTips;
    end;
    UpdateHeights;
    InvalidateParts;
  end;
end;

procedure TFmrRibbon.InvokeApplicationMenu(const AAnchor: TRectF; const AByKeyboard: Boolean);
var
  Ctx: TRttiContext;
  M: TRttiMethod;
  Params: TArray<TRttiParameter>;
begin
  // Companion units (the backstage view) cannot use this unit, so they cannot implement IFmrApplicationMenu: they
  // publish ShowApplicationMenu(ARibbon: TFmxObject; AAnchor: TRectF; AByKeyboard: Boolean), called through RTTI.
  M := Ctx.GetType(FApplicationMenu.ClassType).GetMethod('ShowApplicationMenu');
  if M = nil then
    Exit;
  Params := M.GetParameters;
  if (Length(Params) = 3) and (Params[0].ParamType <> nil) and (Params[0].ParamType.TypeKind = tkClass) and
    Self.InheritsFrom(TRttiInstanceType(Params[0].ParamType).MetaclassType) then
    M.Invoke(FApplicationMenu, [TValue.From<TObject>(Self), TValue.From<TRectF>(AAnchor), AByKeyboard]);
end;

function TFmrRibbon.ApplicationButtonScreenRect: TRectF;
begin
  EnsureAll;
  if (FAppElement = nil) or (FTabBar = nil) then
    Exit(TRectF.Empty);
  Result := ElementScreenRect(FAppElement, FTabBar);
end;

procedure TFmrRibbon.SysButtonExecute(const AElement: TFmrSysButtonElement; const AByKeyboard: Boolean);
begin
  case AElement.Kind of
    TFmrSysButtonKind.CollapseRibbon:
      begin
        ClosePopups;
        if FShowMode <> TFmrRibbonShowMode.TabsAndCommands then
        begin
          ShowMode := TFmrRibbonShowMode.TabsAndCommands;
          Minimized := False;
        end
        else
          Minimized := not FMinimized;
      end;
    TFmrSysButtonKind.DisplayOptions:
      ShowDisplayOptionsMenu(AElement, AByKeyboard);
    TFmrSysButtonKind.AutoHideShow:
      ShowAutoHideRibbon(AByKeyboard);
    TFmrSysButtonKind.Help:
      if Assigned(FOnHelpButtonClick) then
        FOnHelpButtonClick(Self);
    TFmrSysButtonKind.QATCustomize:
      ShowQATCustomizeMenu(AElement, AByKeyboard);
    TFmrSysButtonKind.QATOverflow:
      ShowQATOverflowMenu(AElement, AByKeyboard);
    TFmrSysButtonKind.SimplifiedOverflow:
      ShowSimplifiedOverflowMenu(AElement, AByKeyboard);
    TFmrSysButtonKind.ScrollLeft:
      ScrollGroups(False);
    TFmrSysButtonKind.ScrollRight:
      ScrollGroups(True);
    TFmrSysButtonKind.TabScrollLeft:
      ScrollTabs(False);
    TFmrSysButtonKind.TabScrollRight:
      ScrollTabs(True);
    TFmrSysButtonKind.DisplayMode:
      if FDisplayMode = TFmrRibbonDisplayMode.Classic then
        DisplayMode := TFmrRibbonDisplayMode.Simplified
      else
        DisplayMode := TFmrRibbonDisplayMode.Classic;
  end;
end;

function ToggleLinkVisible(const ALink: TFmrItemLink): TProc;
begin
  Result :=
    procedure
    begin
      ALink.Visible := not ALink.Visible;
    end;
end;

procedure TFmrRibbon.ShowQATCustomizeMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
var
  Temp: TFmrTempMenu;
  I: Integer;
  L: TFmrItemLink;
  Cmd: TFmrCommandItem;
  Content: TFmrMenuControl;
  Host: TFmrRibbonPart;
begin
  Temp := TFmrTempMenu.Create;
  Temp.AddHeader(FmrStr(TFmrStringId.QATCustomize));
  for I := 0 to FQAT.ItemLinks.Count - 1 do
  begin
    L := FQAT.ItemLinks[I];
    if (L.Item = nil) or not L.Item.Visible or (L.Item is TFmrSeparatorItem) then
      Continue;
    Cmd := Temp.AddCommand(FmrStripAccel(L.Caption), ToggleLinkVisible(L), L.Visible);
    Cmd.Glyph := L.Item.Glyph;
  end;
  Temp.AddCommand(FmrStr(TFmrStringId.QATMoreCommands),
    procedure
    begin
      if Assigned(FOnCustomizeQAT) then
        FOnCustomizeQAT(Self)
      else
        QueueCustomizationForm(TFmrCustomizationPage.QuickAccessToolbar);
    end, False, True);
  if FQAT.Position = TFmrQATPosition.AboveRibbon then
    Temp.AddCommand(FmrStr(TFmrStringId.QATShowBelow),
      procedure
      begin
        FQAT.Position := TFmrQATPosition.BelowRibbon;
      end)
  else
    Temp.AddCommand(FmrStr(TFmrStringId.QATShowAbove),
      procedure
      begin
        FQAT.Position := TFmrQATPosition.AboveRibbon;
      end);
  if IsCollapsed then
    Temp.AddCommand(FmrStr(TFmrStringId.RibbonExpand),
      procedure
      begin
        ShowMode := TFmrRibbonShowMode.TabsAndCommands;
        Minimized := False;
      end, False, True)
  else
    Temp.AddCommand(FmrStr(TFmrStringId.RibbonCollapse),
      procedure
      begin
        Minimized := True;
      end, False, True);
  Content := TFmrMenuControl.CreateMenu(NewPopupContext, Temp.Links, TFmrMenuItemStyle.Normal, 180);
  Content.OwnedObject := Temp;
  Host := FCaptionBar;
  if (AElement <> nil) and (AElement.Host <> nil) and (AElement.Host.GetHostControl is TFmrRibbonPart) then
    Host := TFmrRibbonPart(AElement.Host.GetHostControl);
  ShowPopupForElement(Content, AElement, Host, AByKeyboard);
end;

procedure TFmrRibbon.ShowQATOverflowMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
var
  Temp: TFmrTempMenu;
  V: TFmrItemView;
  Content: TFmrMenuControl;
  Host: TFmrRibbonPart;
begin
  if FQATOverflow.Count = 0 then
    Exit;
  Temp := TFmrTempMenu.Create;
  for V in FQATOverflow do
    if V.Item <> nil then
      Temp.AddLink(V.Item);
  Content := TFmrMenuControl.CreateMenu(NewPopupContext, Temp.Links);
  Content.OwnedObject := Temp;
  Host := FCaptionBar;
  if (AElement <> nil) and (AElement.Host <> nil) and (AElement.Host.GetHostControl is TFmrRibbonPart) then
    Host := TFmrRibbonPart(AElement.Host.GetHostControl);
  ShowPopupForElement(Content, AElement, Host, AByKeyboard);
end;

procedure TFmrRibbon.ShowSimplifiedOverflowMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
var
  Temp: TFmrTempMenu;
  L: TFmrItemLink;
  Content: TFmrMenuControl;
  LastGroup, G: TPersistent;
begin
  if Length(FSimplifiedOverflow) = 0 then
    Exit;
  Temp := TFmrTempMenu.Create;
  LastGroup := nil;
  for L in FSimplifiedOverflow do
    if (L <> nil) and (L.Item <> nil) and L.IsVisible and not (L.Item is TFmrCustomEditItem) and
      not (L.Item is TFmrControlItem) and not ((L.Item is TFmrSeparatorItem) and (L.Item.Caption = '')) then
    begin
      G := L.LinksOwner;
      Temp.AddLink(L.Item, (LastGroup <> nil) and (G <> LastGroup));
      LastGroup := G;
    end;
  if Temp.Links.VisibleCount = 0 then
  begin
    Temp.Free;
    Exit;
  end;
  // Plain rows: the overflow menu lists commands, not the large gallery-like rows of drop-down menus.
  Content := TFmrMenuControl.CreateMenu(NewPopupContext, Temp.Links, TFmrMenuItemStyle.Normal);
  Content.OwnedObject := Temp;
  ShowPopupForElement(Content, AElement, FBody, AByKeyboard);
end;

procedure TFmrRibbon.ShowRibbonContextMenu(const AItem: TFmrBarItem; const AScreenPoint: TPointF);
var
  Temp: TFmrTempMenu;
  Content: TFmrMenuControl;
  Popup: TFmrPopupForm;
  Item: TFmrBarItem;
begin
  if (csDesigning in ComponentState) or FDestroying then
    Exit;
  ClosePopups;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    HideKeyTips;
  Temp := TFmrTempMenu.Create;
  Item := AItem;
  if (Item <> nil) and not (Item is TFmrSeparatorItem) and not (Item is TFmrCustomEditItem) and
    not (Item is TFmrControlItem) and not (Item is TFmrCommandItem) then
  begin
    if FQAT.ContainsItem(Item) then
      Temp.AddCommand(FmrStr(TFmrStringId.QATRemoveItem),
        procedure
        begin
          FQAT.RemoveItem(Item);
        end)
    else
      Temp.AddCommand(FmrStr(TFmrStringId.QATAddItem),
        procedure
        begin
          FQAT.AddItem(Item);
          FQAT.ItemLinks.FindByItem(Item).Visible := True;
        end);
  end;
  Temp.AddCommand(FmrStr(TFmrStringId.QATCustomizeDots),
    procedure
    begin
      if Assigned(FOnCustomizeQAT) then
        FOnCustomizeQAT(Self)
      else
        QueueCustomizationForm(TFmrCustomizationPage.QuickAccessToolbar);
    end, False, True);
  if FQAT.Position = TFmrQATPosition.AboveRibbon then
    Temp.AddCommand(FmrStr(TFmrStringId.QATShowBelowLong),
      procedure
      begin
        FQAT.Position := TFmrQATPosition.BelowRibbon;
      end)
  else
    Temp.AddCommand(FmrStr(TFmrStringId.QATShowAboveLong),
      procedure
      begin
        FQAT.Position := TFmrQATPosition.AboveRibbon;
      end);
  Temp.AddCommand(FmrStr(TFmrStringId.RibbonCustomize),
    procedure
    begin
      QueueCustomizationForm(TFmrCustomizationPage.Ribbon);
    end, False, True);
  if IsCollapsed then
    Temp.AddCommand(FmrStr(TFmrStringId.RibbonExpand),
      procedure
      begin
        ShowMode := TFmrRibbonShowMode.TabsAndCommands;
        Minimized := False;
      end, False, True)
  else
    Temp.AddCommand(FmrStr(TFmrStringId.RibbonCollapse),
      procedure
      begin
        Minimized := True;
      end, False, True);
  Content := TFmrMenuControl.CreateMenu(NewPopupContext, Temp.Links, TFmrMenuItemStyle.Normal);
  Content.OwnedObject := Temp;
  Popup := TFmrPopupForm.CreatePopup(Content.Context, Content);
  FScreenTips.Cancel;
  FmrPopups.Show(Popup, RectF(AScreenPoint.X, AScreenPoint.Y, AScreenPoint.X, AScreenPoint.Y),
    TFmrPopupPlacement.AtPoint);
end;

procedure TFmrRibbon.ScrollGroups(const AForward: Boolean);
begin
  FScrollOffset := FmrGroupScrollStep(FLayoutResult, GroupAreaRect.Width, FScrollOffset, AForward);
  InvalidateArrange;
  EnsureAll;
  FBody.Repaint;
end;

procedure TFmrRibbon.ScrollTabs(const AForward: Boolean);
begin
  if AForward then
    FTabScroll := FTabScroll + 80
  else
    FTabScroll := Max(0, FTabScroll - 80);
  InvalidateArrange;
  EnsureAll;
  FTabBar.Repaint;
  FCaptionBar.Repaint;
end;

procedure TFmrRibbon.SelectAdjacentTab(const ADelta: Integer);
var
  A: TArray<TFmrRibbonTab>;
  I, N: Integer;
begin
  A := ShownTabs;
  if Length(A) = 0 then
    Exit;
  N := -1;
  for I := 0 to High(A) do
    if A[I] = FActiveTab then
      N := I;
  N := EnsureRange(N + ADelta, 0, High(A));
  SetActiveTab(A[N]);
end;

procedure TFmrRibbon.SearchChanged(const AText: string);
var
  Items: TArray<TFmrBarItem>;
  Item: TFmrBarItem;
  Temp: TFmrTempMenu;
  Content: TFmrMenuControl;
  Popup: TFmrPopupForm;
  R: TRectF;
  TL, BR: TPointF;
  Ctx: IFmrPopupContext;
begin
  if FSearchPopup <> nil then
  begin
    Popup := FSearchPopup;
    FSearchPopup := nil;
    Popup.OnClosed := nil;
    FmrPopups.Close(Popup);
  end;
  if (AText.Trim = '') or (FBarManager = nil) then
    Exit;
  Items := FBarManager.SearchItems(AText, 12);
  Temp := TFmrTempMenu.Create;
  Temp.AddHeader(FmrStr(TFmrStringId.SearchCommands));
  if Length(Items) = 0 then
    Temp.AddCommand(FmrStr(TFmrStringId.SearchNoResults), nil, False, False, False)
  else
    for Item in Items do
      if not (Item is TFmrSeparatorItem) then
        Temp.AddLink(Item);
  R := FCaptionBar.FSearchRect;
  Ctx := NewPopupContext;
  (Ctx as TRibbonPopupContext).FSearchResults := True;
  Content := TFmrMenuControl.CreateMenu(Ctx, Temp.Links, TFmrMenuItemStyle.Normal, R.Width);
  Content.OwnedObject := Temp;
  Popup := TFmrPopupForm.CreatePopup(Content.Context, Content);
  Popup.CaptureKeyboard := False;
  FSearchPopup := Popup;
  Popup.OnClosed :=
    procedure
    begin
      if FSearchPopup = Popup then
        FSearchPopup := nil;
    end;
  TL := FCaptionBar.LocalToScreen(R.TopLeft);
  BR := FCaptionBar.LocalToScreen(R.BottomRight);
  FmrPopups.Show(Popup, RectF(TL.X, TL.Y, BR.X, BR.Y), TFmrPopupPlacement.Below);
end;

procedure TFmrRibbon.SearchExecute;
var
  Text: string;
begin
  Text := SearchText;
  if (FSearchPopup <> nil) and (FSearchPopup.Content is TFmrMenuControl) and
    (TFmrMenuControl(FSearchPopup.Content).HotRow <> nil) then
    Exit;
  ClosePopups;
  if Assigned(FOnSearch) then
    FOnSearch(Self, Text);
end;

procedure TFmrRibbon.ExecuteShortcut(var Key: Word; const Shift: TShiftState);
var
  SC: TShortCut;
  I: Integer;
  Item: TFmrBarItem;
begin
  if (FBarManager = nil) or (Key = 0) then
    Exit;
  SC := FmrShortCut(Key, Shift);
  for I := 0 to FBarManager.ItemCount - 1 do
  begin
    Item := FBarManager.Items[I];
    if (Item.ShortCut = SC) and Item.Enabled and Item.Visible then
    begin
      Key := 0;
      Item.Click;
      Exit;
    end;
  end;
end;

function TFmrRibbon.FocusInRibbonEditor: Boolean;
var
  Form: TCommonCustomForm;
  O: TFmxObject;
begin
  Result := False;
  Form := OwnerForm;
  if (Form = nil) or (Form.Focused = nil) then
    Exit;
  O := Form.Focused.GetObject as TFmxObject;
  while O <> nil do
  begin
    if (O = FBody) or (O = FCaptionBar) or (O = FTabBar) or (O = FQATBar) then
      Exit(True);
    O := O.Parent;
  end;
end;

procedure TFmrRibbon.DialogKey(var Key: Word; Shift: TShiftState);

  // Editing keys stay with an editor of the ribbon (the font box) instead of running a command with that shortcut.
  function IsEditorKey: Boolean;
  begin
    Result := (Shift * [ssCtrl, ssAlt] = [ssCtrl]) and ((Key = vkA) or (Key = vkC) or (Key = vkV) or (Key = vkX) or
      (Key = vkZ) or (Key = vkY) or (Key = vkInsert) or (Key = vkLeft) or (Key = vkRight) or (Key = vkBack) or
      (Key = vkDelete) or (Key = vkHome) or (Key = vkEnd)) and FocusInRibbonEditor;
  end;

var
  Ch: WideChar;
begin
  if not (csDesigning in ComponentState) and not FDestroying and AbsoluteEnabled then
  begin
    if Key = vkMenu then
      FAltArmed := Shift * [ssCtrl, ssShift] = []
    else if (Key = vkF10) and (Shift = []) then
      FAltArmed := True
    else
    begin
      FAltArmed := False;
      if (FSearchPopup <> nil) and (Key in [vkUp, vkDown, vkEscape]) then
      begin
        Ch := #0;
        if FmrPopups.KeyDown(Key, Ch, Shift) then
          Key := 0;
      end
      else if (FSearchPopup <> nil) and (Key = vkReturn) and (FSearchPopup.Content is TFmrMenuControl) and
        (TFmrMenuControl(FSearchPopup.Content).HotRow <> nil) then
      begin
        Ch := #0;
        if FmrPopups.KeyDown(Key, Ch, Shift) then
          Key := 0;
      end
      else if (Key = vkF1) and (Shift = [ssCtrl]) then
      begin
        ClosePopups;
        if FShowMode <> TFmrRibbonShowMode.TabsAndCommands then
          ShowMode := TFmrRibbonShowMode.TabsAndCommands
        else
          Minimized := not FMinimized;
        Key := 0;
      end
      else if Shift * [ssCtrl, ssAlt] <> [] then
      begin
        if not IsEditorKey then
          ExecuteShortcut(Key, Shift);
      end
      else if (Key >= vkF1) and (Key <= vkF24) then
        ExecuteShortcut(Key, Shift);
    end;
  end;
  if Key <> 0 then
    inherited;
end;

{ key tips }

function TFmrRibbon.KeyTipsVisible: Boolean;
begin
  Result := FKeyTipLevel <> TFmrKeyTipLevel.None;
end;

procedure TFmrRibbon.ShowKeyTipsNow;
begin
  if (csDesigning in ComponentState) or not FShowKeyTips then
    Exit;
  EnterKeyTips(TFmrKeyTipLevel.Top);
end;

procedure TFmrRibbon.EnterKeyTips(const ALevel: TFmrKeyTipLevel);
begin
  EnsureAll;
  // Auto-hide: Alt shows the ribbon first, so the tabs have somewhere to show their tips.
  if AutoHideActive and (FAutoHidePopup = nil) and (ALevel = TFmrKeyTipLevel.Top) then
    ShowAutoHideRibbon(True);
  FScreenTips.Cancel;
  if not FmrPopups.HasKeyHandler(Self) then
    FmrPopups.AddKeyHandler(OwnerForm, Self);
  BuildKeyTips(ALevel);
end;

function TFmrRibbon.KeyTipElements(const ALevel: TFmrKeyTipLevel): TArray<TFmrElement>;
var
  L: TList<TFmrElement>;
  T: TFmrTabElement;
  V: TFmrItemView;
  E: TFmrElement;
  S: TFmrSysButtonElement;
begin
  L := TList<TFmrElement>.Create;
  try
    case ALevel of
      TFmrKeyTipLevel.Top:
        begin
          if (FAppElement <> nil) and FAppElement.Visible then
            L.Add(FAppElement);
          for T in FTabElements do
            if T.Visible then
              L.Add(T);
        end;
      TFmrKeyTipLevel.Tab:
        begin
          for V in FBodyViews do
            if V.Visible and not (V is TFmrSeparatorView) and (V.Host <> nil) and (V.Host.GetHostControl = FBody) then
              L.Add(V);
          for E in FBodyElements do
            if E.Visible and not ((E is TFmrSysButtonElement) and (TFmrSysButtonElement(E).Kind in
              [TFmrSysButtonKind.ScrollLeft, TFmrSysButtonKind.ScrollRight])) then
              L.Add(E);
        end;
      TFmrKeyTipLevel.GroupPopup:
        if FGroupPopupContent <> nil then
        begin
          for V in FGroupPopupContent.FViews do
            if V.Visible and not (V is TFmrSeparatorView) then
              L.Add(V);
          if FGroupPopupContent.FLauncher <> nil then
            L.Add(FGroupPopupContent.FLauncher);
        end;
    end;
    if ALevel = TFmrKeyTipLevel.Top then
    begin
      for V in FQATViews do
        if V.Visible then
          L.Add(V);
      for S in FCaptionSysElements do
        if S.Visible and (S.Kind = TFmrSysButtonKind.QATCustomize) then
          L.Add(S);
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

procedure TFmrRibbon.BuildKeyTips(const ALevel: TFmrKeyTipLevel);
var
  Elements: TArray<TFmrElement>;
  Letters, Numbers: TArray<TFmrKeyTipEntry>;
  LIdx, NIdx: TArray<Integer>;
  I: Integer;
  Rec: TKeyTipEntryRec;
  Tips, Reserved: TArray<string>;
  IsQAT: Boolean;
begin
  SetKeyFocus(nil);
  FKeyTipLevel := ALevel;
  FKeyTips.Clear;
  if ALevel = TFmrKeyTipLevel.None then
    Exit;
  Elements := KeyTipElements(ALevel);
  Letters := nil;
  Numbers := nil;
  LIdx := nil;
  NIdx := nil;
  for I := 0 to High(Elements) do
  begin
    IsQAT := (ALevel = TFmrKeyTipLevel.Top) and (((Elements[I] is TFmrItemView) and
      (TFmrItemView(Elements[I]).ViewPlace = TFmrViewPlace.Toolbar)) or (Elements[I] is TFmrSysButtonElement));
    if IsQAT then
    begin
      Numbers := Numbers + [TFmrKeyTipEntry.Create(Elements[I].KeyTipCaption, Elements[I].ExplicitKeyTip, I)];
      NIdx := NIdx + [I];
    end
    else
    begin
      Letters := Letters + [TFmrKeyTipEntry.Create(Elements[I].KeyTipCaption, Elements[I].ExplicitKeyTip, I)];
      LIdx := LIdx + [I];
    end;
  end;
  TFmrKeyTipAssigner.Assign(Letters, TFmrKeyTipStyle.Letters);
  Reserved := nil;
  for I := 0 to High(Letters) do
    Reserved := Reserved + [Letters[I].KeyTip];
  TFmrKeyTipAssigner.Assign(Numbers, TFmrKeyTipStyle.Numbers, Reserved);
  for I := 0 to High(Elements) do
  begin
    Rec.Element := Elements[I];
    Rec.Tip := '';
    FKeyTips.Add(Rec);
  end;
  for I := 0 to High(Letters) do
  begin
    Rec := FKeyTips[LIdx[I]];
    Rec.Tip := Letters[I].KeyTip;
    FKeyTips[LIdx[I]] := Rec;
  end;
  for I := 0 to High(Numbers) do
  begin
    Rec := FKeyTips[NIdx[I]];
    Rec.Tip := Numbers[I].KeyTip;
    FKeyTips[NIdx[I]] := Rec;
  end;
  SetLength(Tips, FKeyTips.Count);
  for I := 0 to FKeyTips.Count - 1 do
  begin
    Tips[I] := FKeyTips[I].Tip;
    FKeyTips[I].Element.KeyTip := FKeyTips[I].Tip;
  end;
  FKeyTipMatcher.Reset(Tips);
  InvalidateParts;
end;

procedure TFmrRibbon.HideKeyTips;
begin
  SetKeyFocus(nil);
  FKeyTipLevel := TFmrKeyTipLevel.None;
  if FKeyTips <> nil then
    FKeyTips.Clear;
  if FmrPopupsAssigned then
    FmrPopups.RemoveKeyHandler(Self);
  if not FDestroying then
    InvalidateParts;
end;

procedure TFmrRibbon.KeyboardLost;
begin
  SetKeyFocus(nil);
  FKeyTipLevel := TFmrKeyTipLevel.None;
  FKeyTips.Clear;
  InvalidateParts;
end;

procedure TFmrRibbon.KeyTipBack;
begin
  case FKeyTipLevel of
    TFmrKeyTipLevel.Top:
      HideKeyTips;
    TFmrKeyTipLevel.Tab:
      begin
        if FMinimizedPopup <> nil then
          ClosePopups;
        BuildKeyTips(TFmrKeyTipLevel.Top);
      end;
    TFmrKeyTipLevel.GroupPopup:
      begin
        if FGroupPopup <> nil then
          FmrPopups.Close(FGroupPopup);
        BuildKeyTips(TFmrKeyTipLevel.Tab);
      end;
  end;
end;

procedure TFmrRibbon.KeyTipExecute(const AElement: TFmrElement);
var
  V: TFmrItemView;
  Host: TFmrRibbonPart;
begin
  if AElement = nil then
    Exit;
  if AElement is TFmrTabElement then
  begin
    SetActiveTab(TFmrTabElement(AElement).FTab);
    EnsureAll;
    if IsCollapsed then
      ShowMinimizedPopup(True);
    BuildKeyTips(TFmrKeyTipLevel.Tab);
  end
  else if AElement = FAppElement then
    ApplicationButtonPressed(True)
  else if AElement is TFmrCollapsedGroupElement then
  begin
    BuildKeyTips(TFmrKeyTipLevel.GroupPopup);
    FKeyTips.Clear;
    ShowGroupPopup(TFmrCollapsedGroupElement(AElement), True);
    BuildKeyTips(TFmrKeyTipLevel.GroupPopup);
  end
  else if AElement is TFmrItemView then
  begin
    V := TFmrItemView(AElement);
    Host := nil;
    if (V.Host <> nil) and (V.Host.GetHostControl is TFmrRibbonPart) then
      Host := TFmrRibbonPart(V.Host.GetHostControl);
    if V is TFmrEditorView then
    begin
      HideKeyTips;
      ClosePopups;
      V.FocusControl;
    end
    else if FmrItemHasDropDown(V.Item) and (Host <> nil) then
    begin
      FKeyTipMatcher.Reset;
      ShowDropDown(V, Host, True);
    end
    else if V.IsEnabled then
    begin
      HideKeyTips;
      V.Execute(TFmrElementPart.Main);
    end;
  end
  else if AElement is TFmrSysButtonElement then
  begin
    if TFmrSysButtonElement(AElement).OpensOnPress(TFmrElementPart.Main) then
    begin
      FKeyTipMatcher.Reset;
      SysButtonExecute(TFmrSysButtonElement(AElement), True);
    end
    else
    begin
      HideKeyTips;
      SysButtonExecute(TFmrSysButtonElement(AElement), True);
    end;
  end
  else
  begin
    HideKeyTips;
    AElement.Execute(TFmrElementPart.Main);
  end;
end;

procedure TFmrRibbon.SetKeyFocus(const AElement: TFmrElement);
begin
  if FKeyFocus = AElement then
    Exit;
  if FKeyFocus <> nil then
    FKeyFocus.Focused := False;
  FKeyFocus := AElement;
  if FKeyFocus <> nil then
    FKeyFocus.Focused := True;
end;

procedure TFmrRibbon.MoveKeyFocus(const ADirection: TFmrArrowDirection);
var
  I: Integer;
  Cur, C: TPointF;
  E, Best: TFmrElement;
  D, BestD, Along, Across: Single;
begin
  if FKeyTipLevel = TFmrKeyTipLevel.Top then
  begin
    case ADirection of
      TFmrArrowDirection.Left: SelectAdjacentTab(-1);
      TFmrArrowDirection.Right: SelectAdjacentTab(1);
      TFmrArrowDirection.Down:
        begin
          EnsureAll;
          if IsCollapsed then
            ShowMinimizedPopup(True);
          BuildKeyTips(TFmrKeyTipLevel.Tab);
          if FKeyTips.Count > 0 then
            SetKeyFocus(FKeyTips[0].Element);
        end;
    end;
    Exit;
  end;
  if FKeyTips.Count = 0 then
    Exit;
  if FKeyFocus = nil then
  begin
    SetKeyFocus(FKeyTips[0].Element);
    Exit;
  end;
  Cur := FKeyFocus.Bounds.CenterPoint;
  Best := nil;
  BestD := MaxSingle;
  for I := 0 to FKeyTips.Count - 1 do
  begin
    E := FKeyTips[I].Element;
    if (E = FKeyFocus) or not E.Visible then
      Continue;
    C := E.Bounds.CenterPoint;
    case ADirection of
      TFmrArrowDirection.Left:
        begin
          Along := Cur.X - C.X;
          Across := Abs(C.Y - Cur.Y);
        end;
      TFmrArrowDirection.Right:
        begin
          Along := C.X - Cur.X;
          Across := Abs(C.Y - Cur.Y);
        end;
      TFmrArrowDirection.Up:
        begin
          Along := Cur.Y - C.Y;
          Across := Abs(C.X - Cur.X);
        end;
    else
      begin
        Along := C.Y - Cur.Y;
        Across := Abs(C.X - Cur.X);
      end;
    end;
    if Along <= 1 then
      Continue;
    D := Along + Across * 2;
    if D < BestD then
    begin
      BestD := D;
      Best := E;
    end;
  end;
  if Best <> nil then
    SetKeyFocus(Best)
  else if (ADirection = TFmrArrowDirection.Up) and (FKeyTipLevel = TFmrKeyTipLevel.Tab) then
    BuildKeyTips(TFmrKeyTipLevel.Top);
end;

function TFmrRibbon.HandleKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  Ch, Latin: Char;
  E: TFmrElement;
  Match: TFmrKeyTipMatch;
begin
  Result := FKeyTipLevel <> TFmrKeyTipLevel.None;
  if not Result then
    Exit;
  case Key of
    vkEscape:
      KeyTipBack;
    vkMenu, vkF10:
      HideKeyTips;
    vkBack:
      if not FKeyTipMatcher.Backspace then
        KeyTipBack
      else
        InvalidateParts;
    vkLeft: MoveKeyFocus(TFmrArrowDirection.Left);
    vkRight: MoveKeyFocus(TFmrArrowDirection.Right);
    vkUp: MoveKeyFocus(TFmrArrowDirection.Up);
    vkDown: MoveKeyFocus(TFmrArrowDirection.Down);
    vkTab:
      if ssShift in Shift then
        MoveKeyFocus(TFmrArrowDirection.Left)
      else
        MoveKeyFocus(TFmrArrowDirection.Right);
    vkReturn, vkSpace:
      if FKeyFocus <> nil then
        KeyTipExecute(FKeyFocus);
  else
    begin
      Ch := KeyChar;
      if (Ch = #0) and (((Key >= Ord('A')) and (Key <= Ord('Z'))) or ((Key >= Ord('0')) and (Key <= Ord('9')))) then
        Ch := Char(Key);
      if (Ch = #0) or (Shift * [ssCtrl, ssAlt] <> []) then
        Exit;
      Match := FKeyTipMatcher.Press(Ch.ToUpper);
      Latin := FmrLatinKeyChar(Key, KeyChar);
      if (Match = TFmrKeyTipMatch.None) and (Latin <> #0) and (Latin <> Ch.ToUpper) then
        Match := FKeyTipMatcher.Press(Latin);
      case Match of
        TFmrKeyTipMatch.Complete:
          begin
            E := FKeyTips[FKeyTipMatcher.MatchedIndex].Element;
            FKeyTipMatcher.Reset;
            KeyTipExecute(E);
          end;
        TFmrKeyTipMatch.Partial:
          InvalidateParts;
      end;
    end;
  end;
end;

{ structure helpers and API }

function TFmrRibbon.TabCount: Integer;
begin
  Result := TFmrRibbonStructure.TabCount(Self);
end;

function TFmrRibbon.Tabs(const AIndex: Integer): TFmrRibbonTab;
begin
  Result := TFmrRibbonStructure.Tab(Self, AIndex);
end;

function TFmrRibbon.AddTab(const ACaption, AName: string): TFmrRibbonTab;
begin
  Result := TFmrRibbonStructure.CreateTab(Self, ACaption);
  if AName <> '' then
    Result.Name := AName;
end;

function TFmrRibbon.AddContextGroup(const ACaption: string; const AColor: TAlphaColor;
  const AName: string): TFmrRibbonContextGroup;
begin
  Result := TFmrRibbonStructure.CreateContextGroup(Self, ACaption, AColor);
  if AName <> '' then
    Result.Name := AName;
end;

function TFmrRibbon.SaveLayoutToString(const AIndent: Boolean): string;
begin
  Result := TFmrRibbonLayoutStorage.SaveToString(Self, AIndent);
end;

procedure TFmrRibbon.SaveLayoutToStream(const AStream: TStream);
begin
  TFmrRibbonLayoutStorage.SaveToStream(Self, AStream);
end;

procedure TFmrRibbon.SaveLayoutToFile(const AFileName: string);
begin
  TFmrRibbonLayoutStorage.SaveToFile(Self, AFileName);
end;

procedure TFmrRibbon.LoadLayoutFromString(const AText: string);
begin
  ClosePopups;
  CaptureDefaultLayout;
  TFmrRibbonLayoutStorage.LoadFromString(Self, AText);
  InvalidateStructure;
  UpdateHeights;
end;

procedure TFmrRibbon.LoadLayoutFromStream(const AStream: TStream);
begin
  ClosePopups;
  CaptureDefaultLayout;
  TFmrRibbonLayoutStorage.LoadFromStream(Self, AStream);
  InvalidateStructure;
  UpdateHeights;
end;

procedure TFmrRibbon.LoadLayoutFromFile(const AFileName: string);
begin
  ClosePopups;
  CaptureDefaultLayout;
  TFmrRibbonLayoutStorage.LoadFromFile(Self, AFileName);
  InvalidateStructure;
  UpdateHeights;
end;

function TFmrRibbon.Merge(const ASource: TFmxObject): Boolean;
begin
  ClosePopups;
  if FMerger = nil then
    FMerger := TFmrRibbonMerger.Create(Self, Self);
  Result := FMerger.Merge(ASource);
  InvalidateStructure;
end;

function TFmrRibbon.Unmerge(const ASource: TFmxObject): Boolean;
begin
  ClosePopups;
  Result := (FMerger <> nil) and FMerger.Unmerge(ASource);
  InvalidateStructure;
end;

procedure TFmrRibbon.UnmergeAll;
begin
  ClosePopups;
  if FMerger <> nil then
    FMerger.UnmergeAll;
  InvalidateStructure;
end;

function TFmrRibbon.TabAtScreenPoint(const AScreenPoint: TPointF): TFmrRibbonTab;
var
  P: TPointF;
  T: TFmrTabElement;
begin
  Result := nil;
  if FTabBar = nil then
    Exit;
  EnsureAll;
  P := FTabBar.ScreenToLocal(AScreenPoint);
  P := FTabBar.Logical(P.X, P.Y);
  for T in FTabElements do
    if T.Visible and T.Bounds.Contains(P) then
      Exit(T.FTab);
end;

{ design time (IFmrRibbonDesignSupport) }

procedure TFmrRibbon.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if csDesigning in ComponentState then
    DesignMouseEvent(TDesignMouseEvent.Down, Button, Shift, PointF(X, Y));
end;

procedure TFmrRibbon.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if csDesigning in ComponentState then
    DesignMouseEvent(TDesignMouseEvent.Move, TMouseButton.mbLeft, Shift, PointF(X, Y));
end;

procedure TFmrRibbon.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if csDesigning in ComponentState then
    DesignMouseEvent(TDesignMouseEvent.Up, Button, Shift, PointF(X, Y));
end;

procedure TFmrRibbon.DesignMouseEvent(const AEvent: TDesignMouseEvent; const AButton: TMouseButton;
  const AShift: TShiftState; const ALocalPoint: TPointF);
var
  Hook: IFmrRibbonDesignHook;
  Hit: TFmrDesignHit;
begin
  if FDestroying then
    Exit;
  Hook := TFmrRibbonDesignHooks.HookFor(Self);
  if Hook <> nil then
    case AEvent of
      TDesignMouseEvent.Down:
        // FMX reports a double click as a second MouseDown with ssDouble.
        if (AButton = TMouseButton.mbLeft) and (ssDouble in AShift) then
        begin
          if Hook.DesignDblClick(Self, ALocalPoint) then
            Exit;
        end
        else if Hook.DesignMouseDown(Self, AButton, AShift, ALocalPoint) then
          Exit;
      TDesignMouseEvent.Move:
        if Hook.DesignMouseMove(Self, AShift, ALocalPoint) then
          Exit;
      TDesignMouseEvent.Up:
        if Hook.DesignMouseUp(Self, AButton, AShift, ALocalPoint) then
          Exit;
    end;
  // Without the design package: a click on a tab shows it.
  if (AEvent = TDesignMouseEvent.Down) and (AButton = TMouseButton.mbLeft) and not (ssDouble in AShift) then
  begin
    Hit := DesignHitTest(ALocalPoint);
    if Hit.Kind = TFmrDesignHitKind.Tab then
      DesignSelectTab(Hit.Tab);
  end;
end;

function TFmrRibbon.DesignParts: TArray<TFmrRibbonPart>;
var
  P: TFmrRibbonPart;
begin
  Result := nil;
  for P in TArray<TFmrRibbonPart>.Create(FCaptionBar, FTabBar, FBody, FQATBar) do
    if (P <> nil) and P.Visible and (P.Parent <> nil) and not (csDestroying in P.ComponentState) then
      Result := Result + [P];
end;

function TFmrRibbon.DesignPartAt(const ALocalPoint: TPointF; out APart: TFmrRibbonPart; out ALogical: TPointF): Boolean;
var
  P: TFmrRibbonPart;
  SP, LP: TPointF;
begin
  APart := nil;
  ALogical := TPointF.Zero;
  // Screen coordinates: the caption row and the tab row may be in the frame host (above the ribbon).
  SP := LocalToScreen(ALocalPoint);
  for P in DesignParts do
  begin
    LP := P.ScreenToLocal(SP);
    if P.LocalRect.Contains(LP) then
    begin
      APart := P;
      ALogical := P.Logical(LP.X, LP.Y);
      Exit(True);
    end;
  end;
  Result := False;
end;

function TFmrRibbon.PartToLocal(const APart: TFmrRibbonPart; const ALogical: TRectF): TRectF;
var
  R: TRectF;
begin
  R := APart.PhysicalRect(ALogical);
  Result := TRectF.Create(ScreenToLocal(APart.LocalToScreen(R.TopLeft)),
    ScreenToLocal(APart.LocalToScreen(R.BottomRight)), True);
end;

function TFmrRibbon.LocalToPart(const APart: TControl; const ALocal: TRectF): TRectF;
begin
  Result := TRectF.Create(APart.ScreenToLocal(LocalToScreen(ALocal.TopLeft)),
    APart.ScreenToLocal(LocalToScreen(ALocal.BottomRight)), True);
end;

function TFmrRibbon.DesignGroupBoxes: TArray<TFmrGroupBox>;
var
  V: TFmrItemView;
  G: TFmrRibbonGroup;
  I: Integer;
  Area, R: TRectF;
  Found: Boolean;
  Box: TFmrGroupBox;
begin
  if FDisplayMode = TFmrRibbonDisplayMode.Classic then
    Exit(Copy(FGroupBoxes));
  Result := nil;
  Area := GroupAreaRect;
  for V in FBodyViews do
  begin
    if not V.Visible or (V.Link = nil) or not (V.Link.LinksOwner is TFmrRibbonGroup) then
      Continue;
    G := TFmrRibbonGroup(V.Link.LinksOwner);
    R := RectF(V.Bounds.Left, Area.Top, V.Bounds.Right, Area.Bottom);
    Found := False;
    for I := 0 to High(Result) do
      if Result[I].Group = G then
      begin
        Result[I].Rect := TRectF.Union(Result[I].Rect, R);
        Found := True;
        Break;
      end;
    if not Found then
    begin
      Box := System.Default(TFmrGroupBox);
      Box.Group := G;
      Box.Rect := R;
      Result := Result + [Box];
    end;
  end;
end;

function TFmrRibbon.DesignRectsOf(const AObject: TPersistent): TArray<TRectF>;
var
  E: TFmrTabElement;
  Pair: TPair<TFmrRibbonContextGroup, TRectF>;
  Box: TFmrGroupBox;
  V: TFmrItemView;
  Host: TControl;
begin
  Result := nil;
  if (AObject = nil) or (AObject = Self) or FDestroying then
    Exit;
  if (FTabBar <> nil) and FTabBar.Visible then
    for E in FTabElements do
      if E.Visible and (E.FTab = AObject) then
        Result := Result + [PartToLocal(FTabBar, E.Bounds)];
  if (FCaptionBar <> nil) and FCaptionBar.Visible then
    for Pair in FContextHeaders do
      if Pair.Key = AObject then
        Result := Result + [PartToLocal(FCaptionBar, Pair.Value)];
  if (FBody <> nil) and FBody.Visible then
    for Box in DesignGroupBoxes do
      if Box.Group = AObject then
        Result := Result + [PartToLocal(FBody, Box.Rect)];
  for V in FBodyViews.ToArray + FQATViews.ToArray do
    if V.Visible and ((V.Link = AObject) or (V.Item = AObject)) and (V.Host <> nil) then
    begin
      Host := V.Host.GetHostControl;
      if (Host is TFmrRibbonPart) and Host.Visible then
        Result := Result + [PartToLocal(TFmrRibbonPart(Host), V.Bounds)];
    end;
end;

function TFmrRibbon.DesignHitAt(const ALocalPoint: TPointF): TFmrDesignHit;
var
  Part: TFmrRibbonPart;
  P: TPointF;
  E: TFmrElement;
  Pair: TPair<TFmrRibbonContextGroup, TRectF>;
  Box: TFmrGroupBox;
  V: TFmrItemView;
begin
  Result := TFmrDesignHit.Empty;
  if not DesignPartAt(ALocalPoint, Part, P) then
  begin
    if LocalRect.Contains(ALocalPoint) then
    begin
      Result.Kind := TFmrDesignHitKind.Ribbon;
      Result.Bounds := LocalRect;
    end;
    Exit;
  end;
  Result.Kind := TFmrDesignHitKind.Ribbon;
  Result.Bounds := PartToLocal(Part, Part.LocalRect);
  E := Part.FindElement(P);
  if Part = FCaptionBar then
  begin
    for Pair in FContextHeaders do
      if Pair.Value.Contains(P) then
      begin
        Result.Kind := TFmrDesignHitKind.ContextGroup;
        Result.ContextGroup := Pair.Key;
        Result.Bounds := PartToLocal(Part, Pair.Value);
        Exit;
      end;
    if (E <> nil) and (E = FAppElement) then
    begin
      Result.Kind := TFmrDesignHitKind.ApplicationButton;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else if E is TFmrItemView then
    begin
      Result.Kind := TFmrDesignHitKind.QATLink;
      Result.Link := TFmrItemView(E).Link;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else if FCaptionBar.FQATRect.Contains(P) then
    begin
      Result.Kind := TFmrDesignHitKind.QAT;
      Result.Bounds := PartToLocal(Part, FCaptionBar.FQATRect);
    end;
  end
  else if Part = FTabBar then
  begin
    if E is TFmrTabElement then
    begin
      Result.Kind := TFmrDesignHitKind.Tab;
      Result.Tab := TFmrTabElement(E).FTab;
      Result.ContextGroup := Result.Tab.ContextGroup;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else if (E <> nil) and (E = FAppElement) then
    begin
      Result.Kind := TFmrDesignHitKind.ApplicationButton;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end;
  end
  else if Part = FBody then
  begin
    Result.Tab := FActiveTab;
    if E is TFmrCollapsedGroupElement then
    begin
      Result.Kind := TFmrDesignHitKind.CollapsedGroup;
      Result.Group := TFmrCollapsedGroupElement(E).FGroup;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else if E is TFmrLauncherElement then
    begin
      Result.Kind := TFmrDesignHitKind.GroupLauncher;
      Result.Group := TFmrLauncherElement(E).FGroup;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else if (E is TFmrItemView) and (TFmrItemView(E).Link <> nil) then
    begin
      V := TFmrItemView(E);
      Result.Kind := TFmrDesignHitKind.Link;
      Result.Link := V.Link;
      if V.Link.LinksOwner is TFmrRibbonGroup then
        Result.Group := TFmrRibbonGroup(V.Link.LinksOwner);
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else
      for Box in DesignGroupBoxes do
        if Box.Rect.Contains(P) then
        begin
          Result.Kind := TFmrDesignHitKind.Group;
          Result.Group := Box.Group;
          Result.Bounds := PartToLocal(Part, Box.Rect);
          Break;
        end;
  end
  else if Part = FQATBar then
  begin
    if E is TFmrItemView then
    begin
      Result.Kind := TFmrDesignHitKind.QATLink;
      Result.Link := TFmrItemView(E).Link;
      Result.Bounds := PartToLocal(Part, E.Bounds);
    end
    else
      Result.Kind := TFmrDesignHitKind.QAT;
  end;
end;

function TFmrRibbon.DesignHitTest(const ALocalPoint: TPointF): TFmrDesignHit;
begin
  EnsureAll;
  Result := DesignHitAt(ALocalPoint);
end;

function TFmrRibbon.DesignObjectBounds(const AObject: TPersistent): TRectF;
var
  Rects: TArray<TRectF>;
begin
  EnsureAll;
  Rects := DesignRectsOf(AObject);
  if Rects = nil then
    Result := TRectF.Empty
  else
    Result := Rects[0];
end;

function TFmrRibbon.DesignLinkTarget(const APart: TFmrRibbonPart; const P: TPointF): TFmrDesignDropTarget;
var
  M: TFmrThemeMetrics;
  Boxes: TArray<TFmrGroupBox>;
  Box: TFmrGroupBox;
  I, BI: Integer;
  D, BestD, X, Y, ContentTop, ContentBottom: Single;
  Views: TList<TFmrItemView>;
  V, Prev, Before: TFmrItemView;
  R, Area, Mark: TRectF;
  Links: TFmrItemLinks;
  IsBefore: Boolean;
begin
  Result := TFmrDesignDropTarget.Empty;
  M := FPainter.Metrics;
  Views := TList<TFmrItemView>.Create;
  try
    if (APart = FCaptionBar) or (APart = FQATBar) then
    begin
      // Quick access toolbar: before the first button whose center is right of the point.
      if APart = FCaptionBar then
      begin
        Area := FCaptionBar.FQATRect;
        Area.Inflate(6, 0);
        if (FCaptionBar.FQATRect.Width <= 0) or not Area.Contains(P) then
          Exit;
      end
      else
        Area := RectF(6, 0, FQATBar.Width - 6, FQATBar.Height);
      for V in FQATViews do
        if V.Visible and (V.Host <> nil) and (V.Host.GetHostControl = APart) then
          Views.Add(V);
      Links := FQAT.ItemLinks;
      Before := nil;
      for V in Views do
        if P.X < V.Bounds.CenterPoint.X then
        begin
          Before := V;
          Break;
        end;
      if Before <> nil then
      begin
        Result.Index := Before.Link.Index;
        R := Before.Bounds;
        Mark := RectF(R.Left - 1, R.Top, R.Left + 1, R.Bottom);
      end
      else
      begin
        Result.Index := Links.Count;
        if Views.Count > 0 then
        begin
          R := Views.Last.Bounds;
          Mark := RectF(R.Right - 1, R.Top, R.Right + 1, R.Bottom);
        end
        else
        begin
          Y := (Area.Top + Area.Bottom) / 2;
          Mark := RectF(Area.Left + 5, Y - M.QATButtonSize / 2, Area.Left + 7, Y + M.QATButtonSize / 2);
        end;
      end;
      Result.Kind := TFmrDesignDragKind.Link;
      Result.Links := Links;
      Result.Mark := PartToLocal(APart, Mark);
      Exit;
    end;
    if APart <> FBody then
      Exit;
    // Body: the group under the point, or the nearest one when the point is in a gap.
    Boxes := DesignGroupBoxes;
    BI := -1;
    BestD := MaxSingle;
    for I := 0 to High(Boxes) do
    begin
      R := Boxes[I].Rect;
      if (P.X >= R.Left) and (P.X <= R.Right) then
        D := 0
      else
        D := Min(Abs(P.X - R.Left), Abs(P.X - R.Right));
      if D < BestD then
      begin
        BestD := D;
        BI := I;
      end;
    end;
    if (BI < 0) or (BestD > M.GroupSpacing + 12) then
      Exit;
    Box := Boxes[BI];
    Links := Box.Group.ItemLinks;
    Result.Kind := TFmrDesignDragKind.Link;
    Result.Links := Links;
    if FDisplayMode = TFmrRibbonDisplayMode.Classic then
    begin
      ContentTop := Box.Rect.Top + M.GroupPaddingTop;
      ContentBottom := ContentTop + M.ContentHeight;
    end
    else
    begin
      ContentTop := Box.Rect.Top + 4;
      ContentBottom := Box.Rect.Bottom - 4;
    end;
    if Box.Collapsed then
    begin
      // A collapsed group takes the link at its end.
      Result.Index := Links.Count;
      Result.Mark := PartToLocal(APart, RectF(Box.Rect.Right - 4, ContentTop, Box.Rect.Right - 2, ContentBottom));
      Exit;
    end;
    // The views of the group in link order (the body lists them in that order).
    for V in FBodyViews do
      if V.Visible and (V.Link <> nil) and (V.Link.Collection = Links) and not (V is TFmrSeparatorView) and
        (V.Host <> nil) and (V.Host.GetHostControl = FBody) then
        Views.Add(V);
    // Before the first view right of the point; in a column of small buttons: below the point.
    Before := nil;
    Prev := nil;
    for I := 0 to Views.Count - 1 do
    begin
      R := Views[I].Bounds;
      if (P.Y >= R.Top) and (P.Y <= R.Bottom) then
        IsBefore := P.X < R.CenterPoint.X
      else if (P.X >= R.Left) and (P.X <= R.Right) then
        IsBefore := P.Y < R.CenterPoint.Y
      else
        IsBefore := P.X < R.CenterPoint.X;
      if IsBefore then
      begin
        Before := Views[I];
        if I > 0 then
          Prev := Views[I - 1];
        Break;
      end;
    end;
    if Before <> nil then
    begin
      Result.Index := Before.Link.Index;
      R := Before.Bounds;
      if (Prev <> nil) and (Prev.Bounds.Left < R.Right - 2) and (Prev.Bounds.Right > R.Left + 2) and
        (Prev.Bounds.Bottom <= R.Top + 2) then
      begin
        // Stacked in a column: a horizontal bar between the two rows.
        Y := (Prev.Bounds.Bottom + R.Top) / 2;
        Mark := RectF(R.Left, Y - 1, R.Right, Y + 1);
      end
      else
      begin
        if (Prev <> nil) and (Prev.Bounds.Right <= R.Left + 0.5) and (R.Left - Prev.Bounds.Right < 12) then
          X := (Prev.Bounds.Right + R.Left) / 2
        else
          X := R.Left - 1;
        Mark := RectF(X - 1, R.Top, X + 1, R.Bottom);
      end;
    end
    else
    begin
      Result.Index := Links.Count;
      if Views.Count > 0 then
      begin
        R := Views.Last.Bounds;
        if (R.Height < M.ContentHeight * 0.6) and (P.Y > R.Bottom) and (P.X <= R.Right) and
          (R.Bottom + R.Height <= ContentBottom + 1) then
          Mark := RectF(R.Left, R.Bottom, R.Right, R.Bottom + 2)
        else
          Mark := RectF(R.Right, R.Top, R.Right + 2, R.Bottom);
      end
      else
        Mark := RectF(Box.Rect.Left + 4, ContentTop, Box.Rect.Left + 6, ContentBottom);
    end;
    Result.Mark := PartToLocal(APart, Mark);
  finally
    Views.Free;
  end;
end;

function TFmrRibbon.DesignGroupTarget(const APart: TFmrRibbonPart; const P: TPointF): TFmrDesignDropTarget;
var
  M: TFmrThemeMetrics;
  E: TFmrElement;
  Boxes: TArray<TFmrGroupBox>;
  Area: TRectF;
  X: Single;
  I: Integer;
begin
  Result := TFmrDesignDropTarget.Empty;
  M := FPainter.Metrics;
  if APart = FTabBar then
  begin
    // Over a tab: the group goes to the end of that tab.
    E := FTabBar.FindElement(P);
    if E is TFmrTabElement then
    begin
      Result.Kind := TFmrDesignDragKind.Group;
      Result.Tab := TFmrTabElement(E).FTab;
      Result.Index := -1;
      Result.Mark := PartToLocal(FTabBar, RectF(E.Bounds.Left + 2, E.Bounds.Bottom - 3, E.Bounds.Right - 2,
        E.Bounds.Bottom - 1));
    end;
    Exit;
  end;
  if (APart <> FBody) or (FActiveTab = nil) then
    Exit;
  Boxes := DesignGroupBoxes;
  Area := GroupAreaRect;
  Result.Kind := TFmrDesignDragKind.Group;
  Result.Tab := FActiveTab;
  Result.Index := FActiveTab.GroupCount;
  if Length(Boxes) = 0 then
    X := Area.Left + 2
  else
    X := Boxes[High(Boxes)].Rect.Right + M.GroupSpacing / 2;
  for I := 0 to High(Boxes) do
    if P.X < Boxes[I].Rect.CenterPoint.X then
    begin
      Result.Index := Boxes[I].Group.GroupIndex;
      if I > 0 then
        X := (Boxes[I - 1].Rect.Right + Boxes[I].Rect.Left) / 2
      else
        X := Max(Area.Left, Boxes[I].Rect.Left - M.GroupSpacing / 2);
      Break;
    end;
  Result.Mark := PartToLocal(FBody, RectF(X - 1, Area.Top, X + 1, Area.Bottom));
end;

function TFmrRibbon.DesignTabTarget(const P: TPointF): TFmrDesignDropTarget;
var
  M: TFmrThemeMetrics;
  T, Last: TFmrTabElement;
  X: Single;
begin
  Result := TFmrDesignDropTarget.Empty;
  M := FPainter.Metrics;
  Last := nil;
  for T in FTabElements do
    if T.Visible then
    begin
      if P.X < T.Bounds.CenterPoint.X then
      begin
        if Last <> nil then
          X := (Last.Bounds.Right + T.Bounds.Left) / 2
        else
          X := T.Bounds.Left - M.TabSpacing / 2 - 1;
        Result.Kind := TFmrDesignDragKind.Tab;
        Result.Index := T.FTab.TabIndex;
        Result.Mark := PartToLocal(FTabBar, RectF(X - 1, 2, X + 1, FTabBar.Height - 1));
        Exit;
      end;
      Last := T;
    end;
  if Last <> nil then
  begin
    X := Last.Bounds.Right + M.TabSpacing / 2 + 1;
    Result.Kind := TFmrDesignDragKind.Tab;
    Result.Index := TabCount;
    Result.Mark := PartToLocal(FTabBar, RectF(X - 1, 2, X + 1, FTabBar.Height - 1));
  end;
end;

function TFmrRibbon.DesignDropTarget(const ALocalPoint: TPointF;
  const AKind: TFmrDesignDragKind): TFmrDesignDropTarget;
var
  Part: TFmrRibbonPart;
  P: TPointF;
begin
  Result := TFmrDesignDropTarget.Empty;
  EnsureAll;
  if FDestroying or not DesignPartAt(ALocalPoint, Part, P) then
    Exit;
  case AKind of
    TFmrDesignDragKind.Link:
      Result := DesignLinkTarget(Part, P);
    TFmrDesignDragKind.Group:
      Result := DesignGroupTarget(Part, P);
    TFmrDesignDragKind.Tab:
      if Part = FTabBar then
        Result := DesignTabTarget(P);
  end;
end;

procedure TFmrRibbon.DesignShowDropTarget(const ATarget: TFmrDesignDropTarget);
begin
  if (FDesignTarget.Kind = ATarget.Kind) and (FDesignTarget.Links = ATarget.Links) and
    (FDesignTarget.Tab = ATarget.Tab) and (FDesignTarget.Index = ATarget.Index) and
    (FDesignTarget.Mark = ATarget.Mark) then
    Exit;
  FDesignTarget := ATarget;
  if not FDestroying then
    InvalidateParts;
end;

procedure TFmrRibbon.DesignSetSelection(const AObjects: TArray<TPersistent>);
begin
  FDesignSelection := Copy(AObjects);
  if not FDestroying then
    InvalidateParts;
end;

procedure TFmrRibbon.DesignSelectTab(const ATab: TFmrRibbonTab);
var
  OldDesignTab: TFmrRibbonTab;
begin
  if (ATab = nil) or (ATab.Parent <> Self) or FDestroying or (csDestroying in ATab.ComponentState) then
    Exit;
  OldDesignTab := FDesignTab;
  if (csDesigning in ComponentState) and not IsVisibleTab(ATab) then
    FDesignTab := ATab
  else
    FDesignTab := nil;
  if FActiveTab <> ATab then
  begin
    // No OnTabChanging/OnTabChanged, no popups.
    ClosePopups;
    FActiveTab := ATab;
    FScrollOffset := 0;
    InvalidateLayout;
  end;
  if OldDesignTab <> FDesignTab then
    InvalidateStructure;
  EnsureAll;
  InvalidateParts;
end;

procedure TFmrRibbon.PaintDesignFeedback(const APart: TControl; const ACanvas: TCanvas);
var
  Obj: TPersistent;
  R, F, Clip: TRectF;
  Accent: TAlphaColor;
  State: TCanvasSaveState;
  C: TPointF;
begin
  if (FTheme = nil) or ((FDesignSelection = nil) and FDesignTarget.Mark.IsEmpty) then
    Exit;
  Accent := FTheme.Colors[TFmrToken.Accent];
  Clip := APart.LocalRect;
  State := ACanvas.SaveState;
  try
    ACanvas.IntersectClipRect(Clip);
    ACanvas.Stroke.Kind := TBrushKind.Solid;
    ACanvas.Stroke.Thickness := 1;
    // Selected objects: a dashed frame (accent on a light line, visible on light and dark themes).
    for Obj in FDesignSelection do
      for R in DesignRectsOf(Obj) do
      begin
        F := LocalToPart(APart, R);
        if not F.IntersectsWith(Clip) then
          Continue;
        F := RectF(Round(F.Left) + 0.5, Round(F.Top) + 0.5, Round(F.Right) - 0.5, Round(F.Bottom) - 0.5);
        ACanvas.Stroke.Dash := TStrokeDash.Solid;
        ACanvas.Stroke.Color := $B0FFFFFF;
        ACanvas.DrawRect(F, 0, 0, AllCorners, 1);
        ACanvas.Stroke.Dash := TStrokeDash.Dash;
        ACanvas.Stroke.Color := Accent;
        ACanvas.DrawRect(F, 0, 0, AllCorners, 1);
      end;
    // Insertion mark: a bar in the accent color with small triangles at both ends.
    if not FDesignTarget.Mark.IsEmpty then
    begin
      F := LocalToPart(APart, FDesignTarget.Mark);
      R := F;
      R.Inflate(5, 5);
      if R.IntersectsWith(Clip) then
      begin
        ACanvas.Fill.Kind := TBrushKind.Solid;
        ACanvas.Fill.Color := Accent;
        ACanvas.FillRect(F, 0, 0, AllCorners, 1);
        if F.Height >= F.Width then
        begin
          C := PointF(F.CenterPoint.X, F.Top);
          ACanvas.FillPolygon([PointF(C.X - 4, C.Y - 1), PointF(C.X + 4, C.Y - 1), PointF(C.X, C.Y + 4)], 1);
          C := PointF(F.CenterPoint.X, F.Bottom);
          ACanvas.FillPolygon([PointF(C.X - 4, C.Y + 1), PointF(C.X + 4, C.Y + 1), PointF(C.X, C.Y - 4)], 1);
        end
        else
        begin
          C := PointF(F.Left, F.CenterPoint.Y);
          ACanvas.FillPolygon([PointF(C.X - 1, C.Y - 4), PointF(C.X - 1, C.Y + 4), PointF(C.X + 4, C.Y)], 1);
          C := PointF(F.Right, F.CenterPoint.Y);
          ACanvas.FillPolygon([PointF(C.X + 1, C.Y - 4), PointF(C.X + 1, C.Y + 4), PointF(C.X - 4, C.Y)], 1);
        end;
      end;
    end;
  finally
    ACanvas.RestoreState(State);
  end;
end;

function TFmrRibbon.DebugDump: string;
var
  SB: TStringBuilder;

  procedure Part(const AName: string; const C: TControl);
  var
    P: TPointF;
  begin
    if C = nil then
    begin
      SB.AppendLine(AName + ': nil');
      Exit;
    end;
    P := C.LocalToScreen(PointF(0, 0));
    SB.AppendLine(Format('%s: parent=%s visible=%s bounds=(%.1f,%.1f %.1fx%.1f) screen=(%.1f,%.1f)', [AName,
      C.Parent.ClassName, BoolToStr(C.Visible, True), C.Position.X, C.Position.Y, C.Width, C.Height, P.X, P.Y]));
  end;

  procedure Elem(const AName: string; const E: TFmrElement);
  var
    Host: string;
  begin
    if (E.Host <> nil) and (E.Host.GetHostControl <> nil) then
      Host := E.Host.GetHostControl.ClassName
    else
      Host := '-';
    SB.AppendLine(Format('  %s [%s] visible=%s (%.1f,%.1f,%.1f,%.1f)', [AName, Host, BoolToStr(E.Visible, True),
      E.Bounds.Left, E.Bounds.Top, E.Bounds.Right, E.Bounds.Bottom]));
  end;

var
  V: TFmrItemView;
  E: TFmrElement;
  I: Integer;
begin
  EnsureAll;
  SB := TStringBuilder.Create;
  try
    SB.AppendLine(Format('ribbon: theme=%s inHost=%s collapsed=%s height=%.1f', [FThemeName,
      BoolToStr(FBarsInHost, True), BoolToStr(IsCollapsed, True), Height]));
    Part('caption', FCaptionBar);
    Part('tabs', FTabBar);
    Part('body', FBody);
    Part('qat', FQATBar);
    if FAppElement <> nil then
      Elem('app', FAppElement);
    for E in FTabElements do
      Elem('tab ' + TFmrTabElement(E).FTab.Caption, E);
    for E in FTabSysElements do
      Elem('tabsys', E);
    for E in FCaptionSysElements do
      Elem('capsys', E);
    for V in FQATViews do
      Elem('qat ' + V.Link.Caption, V);
    for V in FBodyViews do
      Elem('view ' + V.Link.Caption, V);
    for E in FBodyElements do
      Elem('body ' + E.ClassName, E);
    for I := 0 to High(FSimplifiedOverflow) do
      if FSimplifiedOverflow[I] <> nil then
        SB.AppendLine('  overflow ' + FSimplifiedOverflow[I].Caption);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ customization, display options, auto-hide, accessibility }

type
  /// Content of the auto-hide overlay: the tab bar above the body, both borrowed from the ribbon while it is open.
  TFmrAutoHideContent = class(TControl, IFmrPopupContent)
  private
    [Weak] FRibbon: TFmrRibbon;
  protected
    procedure Resize; override;
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
  end;

procedure TFmrAutoHideContent.Resize;
var
  TabH: Single;
begin
  inherited;
  if (FRibbon = nil) or FRibbon.FDestroying then
    Exit;
  TabH := FRibbon.TabBarHeight;
  if (FRibbon.FTabBar <> nil) and (FRibbon.FTabBar.Parent = Self) then
    FRibbon.FTabBar.SetBounds(0, 0, Width, TabH);
  if (FRibbon.FBody <> nil) and (FRibbon.FBody.Parent = Self) then
    FRibbon.FBody.SetBounds(0, TabH, Width, Max(0, Height - TabH));
end;

function TFmrAutoHideContent.GetPopupSize: TSizeF;
var
  W: Single;
begin
  if (FRibbon.FCaptionBar <> nil) and (FRibbon.FCaptionBar.Width > 0) then
    W := FRibbon.FCaptionBar.Width
  else
    W := FRibbon.Width;
  Result := TSizeF.Create(W, FRibbon.TabBarHeight + FRibbon.BodyHeight + 2);
end;

function TFmrAutoHideContent.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

procedure TFmrAutoHideContent.PopupClosed;
begin
end;

function TFmrAutoHideContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  Result := False;
end;

procedure TFmrAutoHideContent.PopupShown(const AByKeyboard: Boolean);
begin
end;

function TFmrRibbon.EffectiveRightToLeft: Boolean;
var
  F: TCommonCustomForm;
begin
  Result := FRightToLeft;
  if not Result and not (csDesigning in ComponentState) then
  begin
    F := OwnerForm;
    Result := (F <> nil) and (F.BiDiMode = TBiDiMode.bdRightToLeft);
  end;
end;

function TFmrRibbon.AutoHideActive: Boolean;
begin
  Result := (FShowMode = TFmrRibbonShowMode.AutoHide) and not (csDesigning in ComponentState);
end;

procedure TFmrRibbon.SetShowDisplayOptionsButton(const Value: Boolean);
begin
  if FShowDisplayOptionsButton <> Value then
  begin
    FShowDisplayOptionsButton := Value;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.SetShowDisplayModeButton(const Value: Boolean);
begin
  if FShowDisplayModeButton <> Value then
  begin
    FShowDisplayModeButton := Value;
    InvalidateStructure;
  end;
end;

procedure TFmrRibbon.CaptureDefaultLayout;
begin
  if (FDefaultLayout <> '') or FDestroying or ([csDesigning, csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  try
    FDefaultLayout := SaveLayoutToString(False);
  except
    FDefaultLayout := '';
  end;
end;

function TFmrRibbon.ShowCustomizationForm(const APage: TFmrCustomizationPage): Boolean;
begin
  Result := False;
  if FDestroying or (csDesigning in ComponentState) then
    Exit;
  ClosePopups;
  if FKeyTipLevel <> TFmrKeyTipLevel.None then
    HideKeyTips;
  EnsureAll;
  CaptureDefaultLayout;
  Result := TFmrRibbonCustomizeForm.Execute(Self, APage);
  if Result and not FDestroying then
  begin
    InvalidateStructure;
    UpdateHeights;
  end;
end;

procedure TFmrRibbon.QueueCustomizationForm(const APage: TFmrCustomizationPage);
begin
  // Menus call this from their click: the modal form runs after the menu has gone.
  TThread.ForceQueue(nil,
    procedure
    begin
      if not FDestroying then
        ShowCustomizationForm(APage);
    end);
end;

procedure TFmrRibbon.ResetLayout;
begin
  if FDefaultLayout = '' then
    Exit;
  ClosePopups;
  TFmrRibbonLayoutStorage.LoadFromString(Self, FDefaultLayout);
  InvalidateStructure;
  UpdateHeights;
end;

procedure TFmrRibbon.ShowAutoHiddenRibbon;
begin
  ShowAutoHideRibbon(False);
end;

function TFmrRibbon.AutoHiddenRibbonShown: Boolean;
begin
  Result := FAutoHidePopup <> nil;
end;

procedure TFmrRibbon.ShowAutoHideRibbon(const AByKeyboard: Boolean);
var
  Content: TFmrAutoHideContent;
  Popup: TFmrPopupForm;
  TL, BR: TPointF;
begin
  if (FAutoHidePopup <> nil) or not AutoHideActive or FDestroying or (FBody = nil) or (FTabBar = nil) or
    (FCaptionBar = nil) then
    Exit;
  ClosePopups;
  EnsureAll;
  Content := TFmrAutoHideContent.Create(nil);
  Content.FRibbon := Self;
  FTabBar.Align := TAlignLayout.None;
  FTabBar.Parent := Content;
  FTabBar.Visible := True;
  FBody.Parent := Content;
  FBody.Visible := True;
  Popup := TFmrPopupForm.CreatePopup(NewPopupContext, Content);
  Popup.ShadowSize := 6;
  FAutoHidePopup := Popup;
  Popup.OnClosed :=
    procedure
    begin
      if FAutoHidePopup = Popup then
        FAutoHidePopup := nil;
      FAutoHideClosedTick := TThread.GetTickCount;
      // The bars go home: the tab bar into the frame host (below the caption bar) or the ribbon, the body into the
      // ribbon; the content control is freed with the popup.
      if (FTabBar <> nil) and not (csDestroying in FTabBar.ComponentState) then
      begin
        if FBarsInHost and (FFrame <> nil) and (FFrame.Host <> nil) and
          not (csDestroying in FFrame.Host.ComponentState) then
        begin
          FTabBar.Parent := FFrame.Host;
          FTabBar.Position.Y := FCaptionBar.Height + 1;
          FTabBar.Align := TAlignLayout.Top;
        end
        else
          FTabBar.Parent := Self;
      end;
      if (FBody <> nil) and not (csDestroying in FBody.ComponentState) then
        FBody.Parent := Self;
      if FDestroying then
        Exit;
      if FKeyTipLevel <> TFmrKeyTipLevel.None then
        HideKeyTips;
      UpdateHeights;
      InvalidateArrange;
      InvalidateParts;
    end;
  TL := FCaptionBar.LocalToScreen(PointF(0, 0));
  BR := FCaptionBar.LocalToScreen(PointF(FCaptionBar.Width, FCaptionBar.Height));
  FmrPopups.Show(Popup, RectF(TL.X - 1, TL.Y, BR.X, BR.Y), TFmrPopupPlacement.Below, nil, AByKeyboard);
  InvalidateArrange;
  EnsureAll;
  FTabBar.Repaint;
  FBody.Repaint;
end;

procedure TFmrRibbon.ShowDisplayOptionsMenu(const AElement: TFmrElement; const AByKeyboard: Boolean);
const
  PathFrame = 'M2,4 L22,4 L22,20 L2,20 Z M3.5,5.5 L3.5,18.5 L20.5,18.5 L20.5,5.5 Z ';
  PathAutoHide = PathFrame + 'M12,7.5 L16.5,12 L13,12 L13,16.5 L11,16.5 L11,12 L7.5,12 Z';
  PathTabs = PathFrame + 'M5,7 L8.5,7 L8.5,9 L5,9 Z M10,7 L13.5,7 L13.5,9 L10,9 Z M15,7 L18.5,7 L18.5,9 L15,9 Z';
  PathTabsCommands = PathFrame + 'M5,7 L8.5,7 L8.5,9 L5,9 Z M10,7 L13.5,7 L13.5,9 L10,9 Z M15,7 L18.5,7 L18.5,9 ' +
    'L15,9 Z M5,10.5 L19,10.5 L19,14 L5,14 Z';
var
  Temp: TFmrTempMenu;
  Content: TFmrMenuControl;
  Host: TFmrRibbonPart;

  procedure Add(const ACaption, ADescription: TFmrStringId; const APath: string; const AMode: TFmrRibbonShowMode);
  var
    C: TFmrCommandItem;
    Checked: Boolean;
  begin
    Checked := (FShowMode = AMode) and ((AMode <> TFmrRibbonShowMode.TabsAndCommands) or not FMinimized);
    C := Temp.AddCommand(FmrStr(ACaption),
      procedure
      begin
        ShowMode := AMode;
        if AMode = TFmrRibbonShowMode.TabsAndCommands then
          Minimized := False;
      end, Checked);
    C.Description := FmrStr(ADescription);
    C.LargeGlyph.PathData := APath;
    C.LargeGlyph.PathViewBox := 24;
    C.Glyph.PathData := APath;
    C.Glyph.PathViewBox := 24;
  end;

begin
  Temp := TFmrTempMenu.Create;
  Add(TFmrStringId.RibbonAutoHide, TFmrStringId.RibbonAutoHideDesc, PathAutoHide, TFmrRibbonShowMode.AutoHide);
  Add(TFmrStringId.RibbonShowTabs, TFmrStringId.RibbonShowTabsDesc, PathTabs, TFmrRibbonShowMode.TabsOnly);
  Add(TFmrStringId.RibbonShowTabsAndCommands, TFmrStringId.RibbonShowTabsAndCommandsDesc, PathTabsCommands,
    TFmrRibbonShowMode.TabsAndCommands);
  Content := TFmrMenuControl.CreateMenu(NewPopupContext, Temp.Links, TFmrMenuItemStyle.Large, 300);
  Content.OwnedObject := Temp;
  Host := FCaptionBar;
  if (AElement <> nil) and (AElement.Host <> nil) and (AElement.Host.GetHostControl is TFmrRibbonPart) then
    Host := TFmrRibbonPart(AElement.Host.GetHostControl);
  ShowPopupForElement(Content, AElement, Host, AByKeyboard, nil, TFmrPopupPlacement.BelowEnd);
end;

procedure TFmrRibbon.AddDisplayModeButton(const ABounds: TRectF);
var
  E: TFmrSysButtonElement;
  S: Single;
begin
  S := 22;
  E := TFmrSysButtonElement.Create(FBody);
  E.FRibbon := Self;
  E.FKind := TFmrSysButtonKind.DisplayMode;
  if FDisplayMode = TFmrRibbonDisplayMode.Simplified then
    E.Bounds := RectF(ABounds.Right + 3, Round(ABounds.CenterPoint.Y - S / 2), ABounds.Right + 3 + S,
      Round(ABounds.CenterPoint.Y - S / 2) + S)
  else
    E.Bounds := RectF(ABounds.Right + 3, ABounds.Bottom - S - 1, ABounds.Right + 3 + S, ABounds.Bottom - 1);
  FBodyElements.Add(E);
end;

function TFmrRibbon.AccessibilityNodes: TArray<TFmrAccNode>;
var
  L: TList<TFmrAccNode>;
  QATIndex, TabsIndex, BodyIndex, GroupIndex, I: Integer;
  V: TFmrItemView;
  E: TFmrElement;
  T: TFmrTabElement;
  S: TFmrSysButtonElement;
  Box: TFmrGroupBox;
  Groups: TDictionary<TObject, Integer>;
  Info: TFmrScreenTipInfo;
  Owner: TPersistent;

  function ControlRect(const C: TControl): TRectF;
  var
    TL, BR: TPointF;
  begin
    TL := C.LocalToScreen(PointF(0, 0));
    BR := C.LocalToScreen(PointF(C.Width, C.Height));
    Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
  end;

  function HostRect(const AElement: TFmrElement; const ABounds: TRectF): TRectF;
  var
    C: TControl;
    R: TRectF;
    TL, BR: TPointF;
  begin
    Result := TRectF.Empty;
    if (AElement.Host = nil) or (AElement.Host.GetHostControl = nil) then
      Exit;
    C := AElement.Host.GetHostControl;
    R := ABounds;
    if (C is TFmrRibbonPart) and TFmrRibbonPart(C).IsMirrored then
      R := FmrMirrorRect(R, C.Width);
    TL := C.LocalToScreen(R.TopLeft);
    BR := C.LocalToScreen(R.BottomRight);
    Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
  end;

  function BodyRect(const ABounds: TRectF): TRectF;
  var
    R: TRectF;
    TL, BR: TPointF;
  begin
    R := ABounds;
    if FBody.IsMirrored then
      R := FmrMirrorRect(R, FBody.Width);
    TL := FBody.LocalToScreen(R.TopLeft);
    BR := FBody.LocalToScreen(R.BottomRight);
    Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
  end;

  function Add(const ARole: TFmrAccRole; const AName: string; const AParent: Integer; const ABounds: TRectF;
    const AElement, AData: TObject): Integer;
  var
    N: TFmrAccNode;
    Item: TFmrBarItem;
  begin
    N := System.Default(TFmrAccNode);
    N.Role := ARole;
    N.Name := AName;
    N.Parent := AParent;
    N.Bounds := ABounds;
    N.Element := AElement;
    N.Data := AData;
    N.Enabled := True;
    if (AElement is TFmrItemView) and (TFmrItemView(AElement).Item <> nil) then
      N.AutomationId := TFmrItemView(AElement).Item.Name
    else if AElement is TFmrSysButtonElement then
      N.AutomationId := GetEnumName(TypeInfo(TFmrSysButtonKind), Ord(TFmrSysButtonElement(AElement).Kind))
    else if AElement is TFmrLauncherElement then
      N.AutomationId := TFmrLauncherElement(AElement).FGroup.Name + '.Launcher'
    else if AElement = FAppElement then
      N.AutomationId := 'ApplicationButton'
    else if AData is TComponent then
      N.AutomationId := TComponent(AData).Name;
    if (AElement = nil) and (ARole in [TFmrAccRole.QuickAccessToolbar, TFmrAccRole.TabList,
      TFmrAccRole.LowerRibbon]) then
      N.AutomationId := GetEnumName(TypeInfo(TFmrAccRole), Ord(ARole));
    if (AElement is TFmrEditorView) and (TFmrItemView(AElement).Item is TFmrCustomEditItem) then
    begin
      Item := TFmrItemView(AElement).Item;
      N.ReadOnly := TFmrCustomEditItem(Item).ReadOnly;
      if Item is TFmrEditItem then
        N.Value := TFmrEditItem(Item).Text
      else if Item is TFmrComboItem then
        N.Value := TFmrComboItem(Item).Text
      else if Item is TFmrSpinItem then
        N.Value := FloatToStr(TFmrSpinItem(Item).Value)
      else if Item is TFmrTrackBarItem then
        N.Value := FloatToStr(TFmrTrackBarItem(Item).Value);
    end;
    if AElement is TFmrElement then
    begin
      N.Enabled := TFmrElement(AElement).IsEnabled;
      N.Checked := TFmrElement(AElement).IsChecked;
      N.AccessKey := TFmrElement(AElement).KeyTip;
      if N.AccessKey = '' then
        N.AccessKey := TFmrElement(AElement).ExplicitKeyTip;
      if TFmrElement(AElement).GetScreenTip(Info) then
      begin
        N.HelpText := Info.Description;
        if N.Name = '' then
          N.Name := Info.Header;
      end;
    end;
    Result := L.Add(N);
  end;

  function ViewRole(const AView: TFmrItemView): TFmrAccRole;
  begin
    if (AView is TFmrEditorView) and (AView.Item is TFmrComboItem) then
      Result := TFmrAccRole.ComboBox
    else if (AView is TFmrEditorView) and (AView.Item is TFmrSpinItem) then
      Result := TFmrAccRole.Spinner
    else if (AView is TFmrEditorView) and (AView.Item is TFmrTrackBarItem) then
      Result := TFmrAccRole.Slider
    else if AView is TFmrEditorView then
      Result := TFmrAccRole.Editor
    else if AView.Item is TFmrCheckItem then
      Result := TFmrAccRole.CheckBox
    else if (AView.Item is TFmrButtonItem) and (TFmrButtonItem(AView.Item).ButtonStyle = TFmrButtonStyle.Split) then
      Result := TFmrAccRole.SplitButton
    else if FmrItemHasDropDown(AView.Item) then
      Result := TFmrAccRole.DropDownButton
    else
      Result := TFmrAccRole.Button;
  end;

  procedure AddSys(const AList: TObjectList<TFmrSysButtonElement>; const AParent: Integer);
  var
    X: TFmrSysButtonElement;
  begin
    for X in AList do
      if X.Visible then
        Add(TFmrAccRole.SystemButton, '', AParent, HostRect(X, X.Bounds), X, nil);
  end;

begin
  Result := nil;
  if FDestroying or (csDesigning in ComponentState) then
    Exit;
  EnsureAll;
  L := TList<TFmrAccNode>.Create;
  Groups := TDictionary<TObject, Integer>.Create;
  try
    { quick access toolbar }
    QATIndex := -1;
    for V in FQATViews do
      if V.Visible and (V.Host <> nil) then
      begin
        if QATIndex < 0 then
          QATIndex := Add(TFmrAccRole.QuickAccessToolbar, FmrStr(TFmrStringId.AccQAT), -1,
            ControlRect(V.Host.GetHostControl), nil, FQAT);
        Add(ViewRole(V), FmrStripAccel(V.Link.Caption), QATIndex, HostRect(V, V.Bounds), V, nil);
      end;
    if QATIndex >= 0 then
    begin
      for S in FCaptionSysElements do
        if S.Visible and (S.Kind in [TFmrSysButtonKind.QATCustomize, TFmrSysButtonKind.QATOverflow]) then
          Add(TFmrAccRole.SystemButton, '', QATIndex, HostRect(S, S.Bounds), S, nil);
      for S in FQATBarSysElements do
        if S.Visible then
          Add(TFmrAccRole.SystemButton, '', QATIndex, HostRect(S, S.Bounds), S, nil);
    end;
    if (FCaptionBar <> nil) and (FCaptionBar.FSearchEdit <> nil) and FCaptionBar.FSearchEdit.ParentedVisible then
    begin
      I := Add(TFmrAccRole.Editor, FmrStr(TFmrStringId.SearchPromptLong), -1, ControlRect(FCaptionBar.FSearchEdit),
        FCaptionBar.FSearchEdit, nil);
      L.List[I].AutomationId := 'SearchBox';
      L.List[I].Value := FCaptionBar.FSearchEdit.Text;
    end;
    for S in FCaptionSysElements do
      if S.Visible and (S.Kind in [TFmrSysButtonKind.DisplayOptions, TFmrSysButtonKind.AutoHideShow]) then
        Add(TFmrAccRole.SystemButton, '', -1, HostRect(S, S.Bounds), S, nil);

    { tabs }
    if (FTabBar <> nil) and FTabBar.ParentedVisible then
    begin
      TabsIndex := Add(TFmrAccRole.TabList, FmrStr(TFmrStringId.AccRibbonTabs), -1, ControlRect(FTabBar), nil, nil);
      if (FAppElement <> nil) and FAppElement.Visible then
        Add(TFmrAccRole.ApplicationButton, FmrStripAccel(FAppButton.DisplayCaption), TabsIndex,
          HostRect(FAppElement, FAppElement.Bounds), FAppElement, nil);
      for T in FTabElements do
        if T.Visible then
        begin
          I := Add(TFmrAccRole.Tab, FmrStripAccel(T.FTab.DisplayCaption), TabsIndex, HostRect(T, T.Bounds), T,
            T.FTab);
          L.List[I].Selected := T.FTab = FActiveTab;
        end;
      AddSys(FTabSysElements, TabsIndex);
    end;

    { the commands of the active tab }
    if (FBody <> nil) and FBody.ParentedVisible and (FActiveTab <> nil) then
    begin
      BodyIndex := Add(TFmrAccRole.LowerRibbon, FmrStr(TFmrStringId.AccLowerRibbon), -1, ControlRect(FBody), nil,
        FActiveTab);
      for Box in FGroupBoxes do
      begin
        if Box.Collapsed then
        begin
          for E in FBodyElements do
            if (E is TFmrCollapsedGroupElement) and (TFmrCollapsedGroupElement(E).FGroup = Box.Group) then
              Add(TFmrAccRole.CollapsedGroup, FmrStripAccel(Box.Group.DisplayCaption), BodyIndex,
                HostRect(E, E.Bounds), E, Box.Group);
          Continue;
        end;
        GroupIndex := Add(TFmrAccRole.Group, FmrStripAccel(Box.Group.DisplayCaption), BodyIndex,
          BodyRect(Box.Rect), nil, Box.Group);
        Groups.AddOrSetValue(Box.Group, GroupIndex);
      end;
      for V in FBodyViews do
      begin
        if not V.Visible or (V is TFmrSeparatorView) or (V.Host = nil) or (V.Host.GetHostControl <> FBody) then
          Continue;
        Owner := V.Link.LinksOwner;
        if not Groups.TryGetValue(Owner, GroupIndex) then
        begin
          // Simplified ribbon: no group boxes; a group node per group of the line.
          if Owner is TFmrRibbonGroup then
            GroupIndex := Add(TFmrAccRole.Group, FmrStripAccel(TFmrRibbonGroup(Owner).DisplayCaption), BodyIndex,
              TRectF.Empty, nil, Owner)
          else
            GroupIndex := BodyIndex;
          Groups.AddOrSetValue(Owner, GroupIndex);
        end;
        Add(ViewRole(V), FmrStripAccel(V.Link.Caption), GroupIndex, HostRect(V, V.Bounds), V, nil);
      end;
      for E in FBodyElements do
        if E.Visible then
        begin
          if E is TFmrLauncherElement then
          begin
            if Groups.TryGetValue(TFmrLauncherElement(E).FGroup, GroupIndex) then
              Add(TFmrAccRole.Button, '', GroupIndex, HostRect(E, E.Bounds), E, nil);
          end
          else if E is TFmrSysButtonElement then
            Add(TFmrAccRole.SystemButton, '', BodyIndex, HostRect(E, E.Bounds), E, nil);
        end;
      // Groups of the simplified line: the union of their children (screen rectangles).
      for I := 0 to L.Count - 1 do
        if (L[I].Parent >= 0) and (L[L[I].Parent].Role = TFmrAccRole.Group) and not L[I].Bounds.IsEmpty and
          (FDisplayMode = TFmrRibbonDisplayMode.Simplified) then
        begin
          if L[L[I].Parent].Bounds.IsEmpty then
            L.List[L[I].Parent].Bounds := L[I].Bounds
          else
            L.List[L[I].Parent].Bounds := TRectF.Union(L[L[I].Parent].Bounds, L[I].Bounds);
        end;
    end;
    Result := L.ToArray;
  finally
    Groups.Free;
    L.Free;
  end;
end;

function TFmrRibbon.AccessibilityInvoke(const AElement: TObject): Boolean;
var
  V: TFmrItemView;
  HostPart: TFmrRibbonPart;
  Alive: Boolean;
begin
  Result := False;
  if (AElement = nil) or FDestroying then
    Exit;
  Alive := (AElement = FAppElement) or FTabElements.Contains(TFmrTabElement(AElement)) or
    FViews.Contains(TFmrItemView(AElement)) or FBodyElements.Contains(TFmrElement(AElement));
  if not Alive then
    Alive := FTabSysElements.Contains(TFmrSysButtonElement(AElement)) or
      FCaptionSysElements.Contains(TFmrSysButtonElement(AElement)) or
      FQATBarSysElements.Contains(TFmrSysButtonElement(AElement));
  if not Alive and (FCaptionBar <> nil) and (FCaptionBar.FSearchEdit <> nil) and
    (AElement = FCaptionBar.FSearchEdit) then
  begin
    FCaptionBar.FSearchEdit.SetFocus;
    Exit(True);
  end;
  if not Alive then
    Exit;
  Result := True;
  if AElement is TFmrTabElement then
  begin
    if IsCollapsed and (FAutoHidePopup = nil) then
      TabElementPressed(TFmrTabElement(AElement), True)
    else
      SetActiveTab(TFmrTabElement(AElement).FTab);
  end
  else if AElement = FAppElement then
    ApplicationButtonPressed(True)
  else if AElement is TFmrCollapsedGroupElement then
    ShowGroupPopup(TFmrCollapsedGroupElement(AElement), True)
  else if AElement is TFmrItemView then
  begin
    V := TFmrItemView(AElement);
    HostPart := nil;
    if (V.Host <> nil) and (V.Host.GetHostControl is TFmrRibbonPart) then
      HostPart := TFmrRibbonPart(V.Host.GetHostControl);
    if V is TFmrEditorView then
      V.FocusControl
    else if FmrItemHasDropDown(V.Item) and (HostPart <> nil) and not ((V.Item is TFmrButtonItem) and
      (TFmrButtonItem(V.Item).ButtonStyle = TFmrButtonStyle.Split)) then
      ShowDropDown(V, HostPart, True)
    else if V.IsEnabled then
      V.Execute(TFmrElementPart.Main);
  end
  else if AElement is TFmrSysButtonElement then
    SysButtonExecute(TFmrSysButtonElement(AElement), True)
  else if AElement is TFmrElement then
    TFmrElement(AElement).Execute(TFmrElementPart.Main);
end;

function TFmrRibbon.AccessibilitySetValue(const AElement: TObject; const AValue: string): Boolean;
var
  Item: TFmrBarItem;
  D: Double;
begin
  Result := False;
  if (AElement <> nil) and not FDestroying and (FCaptionBar <> nil) and (FCaptionBar.FSearchEdit <> nil) and
    (AElement = FCaptionBar.FSearchEdit) then
  begin
    SetSearchText(AValue);
    Exit(True);
  end;
  if (AElement = nil) or FDestroying or not FViews.Contains(TFmrItemView(AElement)) or
    not (AElement is TFmrEditorView) then
    Exit;
  Item := TFmrItemView(AElement).Item;
  if not (Item is TFmrCustomEditItem) or TFmrCustomEditItem(Item).ReadOnly or not Item.Enabled then
    Exit;
  Result := True;
  if Item is TFmrEditItem then
    TFmrEditItem(Item).Text := AValue
  else if Item is TFmrComboItem then
  begin
    if not TFmrComboItem(Item).Editable and (TFmrComboItem(Item).Items.IndexOf(AValue) < 0) then
      Exit(False);
    TFmrComboItem(Item).Text := AValue;
  end
  else if TryStrToFloat(AValue, D) or TryStrToFloat(AValue, D, TFormatSettings.Invariant) then
  begin
    if Item is TFmrSpinItem then
      TFmrSpinItem(Item).Value := D
    else if Item is TFmrTrackBarItem then
      TFmrTrackBarItem(Item).Value := D
    else
      Result := False;
  end
  else
    Result := False;
end;

initialization
  RegisterFmxClasses([TFmrRibbon]);

end.
