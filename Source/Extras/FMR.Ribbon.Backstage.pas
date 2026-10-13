{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Backstage view (Office "File" view)                  }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Backstage;

/// TFmrRibbonBackstageView: the Office 2010+/365 "File" view. When shown it covers its parent (normally the form;
/// Align = Contents, brought to front) with a navigation pane on the left and the active tab on the right.
/// Its children are the navigation items, in their child order:
///   - TFmrBackstageTab: a designable container (drop any FMX controls into it); clicking its item shows it;
///   - TFmrBackstageButton: a command (Save, Close, Options...); clicking it closes the view (unless KeepOpen) and
///     runs OnClick (or the linked bar item).
/// Items with NavAlign = Bottom are stacked at the bottom of the pane (Account, Options).
/// At design time the view is an ordinary control that can be sized and moved; clicking a navigation item shows
/// its tab. At run time the view is hidden after loading; Show / Hide (Esc, the back button) open and close it.
/// OnShow / OnHide and TFmrBackstageViewMessage tell the ribbon to hide its tab row while the view is open.
/// The view paints with the theme of its ThemeProvider (the TFmrRibbon) or its own Theme / AccentColor, and is a
/// theme provider itself for the helper controls of FMR.Ribbon.Backstage.Controls.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Messaging,
  System.Math.Vectors, FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types,
  FMR.Bars.Images, FMR.Bars, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Strings, FMR.Ribbon.KeyTips,
  FMR.Ribbon.ThemeLink, FMR.Ribbon.Extras.Layout, FMR.Frame.Host;

type
  TFmrRibbonBackstageView = class;

  /// <summary>Where a navigation item is placed in the navigation pane.</summary>
  TFmrBackstageNavAlign = (Top, Bottom);

  /// <summary>How the view appears.</summary>
  TFmrBackstageAnimation = (None, Fade, Slide);

  /// <summary>Glyphs of the navigation items: Auto shows them for the Office 365 and Fluent themes.</summary>
  TFmrBackstageNavGlyphs = (Auto, Show, Hide);

  /// <summary>A page of the backstage view: a container for any FMX controls. The view sets its bounds and shows
  /// only the active tab (Visible is managed by the view and not stored).</summary>
  TFmrBackstageTab = class(TControl)
  private
    FCaption: string;
    FGlyph: TFmrImageSource;
    FBeginGroup: Boolean;
    FKeyTip: string;
    FTabVisible: Boolean;
    FNavAlign: TFmrBackstageNavAlign;
    procedure SetCaption(const Value: string);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetBeginGroup(const Value: Boolean);
    procedure SetKeyTip(const Value: string);
    procedure SetTabVisible(const Value: Boolean);
    procedure SetNavAlign(const Value: TFmrBackstageNavAlign);
    procedure GlyphChanged(Sender: TObject);
    function GetView: TFmrRibbonBackstageView;
    function GetIsActive: Boolean;
  protected
    function VisibleStored: Boolean; override;
    procedure Paint; override;
    procedure EnabledChanged; override;
    procedure Changed;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Makes this tab the active tab of its view.</summary>
    procedure Activate;
    property View: TFmrRibbonBackstageView read GetView;
    property IsActive: Boolean read GetIsActive;
  published
    /// <summary>Caption of the navigation item.</summary>
    property Caption: string read FCaption write SetCaption;
    /// <summary>Glyph of the navigation item (shown by the Office 365 / Fluent themes, see NavGlyphs).</summary>
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    /// <summary>A separator line is drawn above the navigation item.</summary>
    property BeginGroup: Boolean read FBeginGroup write SetBeginGroup default False;
    /// <summary>Explicit key tip; empty = generated from the caption.</summary>
    property KeyTip: string read FKeyTip write SetKeyTip;
    property NavAlign: TFmrBackstageNavAlign read FNavAlign write SetNavAlign default TFmrBackstageNavAlign.Top;
    /// <summary>The tab has an item in the navigation pane.</summary>
    property TabVisible: Boolean read FTabVisible write SetTabVisible default True;
    property ClipChildren default True;
    property Enabled;
    property Hint;
    property Padding;
    property TabOrder;
    property OnResize;
    property OnPaint;
  end;

  /// <summary>A command item of the navigation pane (Save, Print, Close, Options...).</summary>
  TFmrBackstageButton = class(TFmxObject)
  private
    FCaption: string;
    FGlyph: TFmrImageSource;
    FBeginGroup: Boolean;
    FKeyTip: string;
    FVisible: Boolean;
    FEnabled: Boolean;
    FHint: string;
    FKeepOpen: Boolean;
    FNavAlign: TFmrBackstageNavAlign;
    FItem: TFmrBarItem;
    FOnClick: TNotifyEvent;
    procedure SetCaption(const Value: string);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetBeginGroup(const Value: Boolean);
    procedure SetKeyTip(const Value: string);
    procedure SetVisible(const Value: Boolean);
    procedure SetEnabled(const Value: Boolean);
    procedure SetNavAlign(const Value: TFmrBackstageNavAlign);
    procedure SetItem(const Value: TFmrBarItem);
    procedure GlyphChanged(Sender: TObject);
    function GetView: TFmrRibbonBackstageView;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Changed;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Runs OnClick, or Item.Click when OnClick is not assigned.</summary>
    procedure Click; virtual;
    /// <summary>Caption, or the caption of Item when Caption is empty.</summary>
    function DisplayCaption: string;
    /// <summary>Glyph, or the glyph of Item when Glyph is empty.</summary>
    function DisplayGlyph: TFmrImageSource;
    /// <summary>Enabled and (no Item or Item.Enabled).</summary>
    function IsEnabled: Boolean;
    property View: TFmrRibbonBackstageView read GetView;
  published
    property Caption: string read FCaption write SetCaption;
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    property BeginGroup: Boolean read FBeginGroup write SetBeginGroup default False;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Hint: string read FHint write FHint;
    /// <summary>Clicking the button does not close the view.</summary>
    property KeepOpen: Boolean read FKeepOpen write FKeepOpen default False;
    property KeyTip: string read FKeyTip write SetKeyTip;
    property NavAlign: TFmrBackstageNavAlign read FNavAlign write SetNavAlign default TFmrBackstageNavAlign.Top;
    property Visible: Boolean read FVisible write SetVisible default True;
    /// <summary>Optional bar item: gives caption and glyph when those are empty and runs when OnClick is not
    /// assigned.</summary>
    property Item: TFmrBarItem read FItem write SetItem;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  TFmrBackstageTabChangingEvent = procedure(Sender: TObject; const ANewTab: TFmrBackstageTab;
    var AAllow: Boolean) of object;
  TFmrBackstageButtonEvent = procedure(Sender: TObject; const AButton: TFmrBackstageButton) of object;

  /// <summary>Sent through TMessageManager.DefaultManager after a backstage view was shown (IsOpen = True) or
  /// hidden. The ribbon uses it to hide its tab row while its application menu view is open.</summary>
  TFmrBackstageViewMessage = class(System.Messaging.TMessage)
  private
    FView: TFmrRibbonBackstageView;
    FIsOpen: Boolean;
  public
    constructor Create(const AView: TFmrRibbonBackstageView; const AIsOpen: Boolean);
    property View: TFmrRibbonBackstageView read FView;
    property IsOpen: Boolean read FIsOpen;
  end;

  /// <summary>The backstage view; see the unit description.</summary>
  TFmrRibbonBackstageView = class(TControl, IFmrThemeProvider, IFmrBarManagerListener)
  private type
    TNavEntry = record
      Item: TFmxObject;
      Rect: TRectF;
      SeparatorY: Single;
      Caption: string;
      Enabled: Boolean;
      Bottom: Boolean;
      function IsTab: Boolean;
    end;
    TNavMetrics = record
      BackHeight: Single;
      BackSize: Single;
      ItemHeight: Single;
      FontSize: Single;
      TextLeft: Single;
      GlyphSize: Single;
      ItemInset: Single;
      ItemRadius: Single;
      RoundBack: Boolean;
      SeparatorGap: Single;
      MinWidth: Single;
    end;
  public const
    /// <summary>Index of the back button in hit tests.</summary>
    BackButtonIndex = -2;
  private
    FThemeLink: TFmrThemeLink;
    FBarManager: TFmrBarManager;
    FActiveTab: TFmrBackstageTab;
    FNavigationWidth: Single;
    FShowBackButton: Boolean;
    FCaption: string;
    FAnimation: TFmrBackstageAnimation;
    FNavGlyphs: TFmrBackstageNavGlyphs;
    FKeepCaptionVisible: Boolean;
    FOnShow: TNotifyEvent;
    FOnHide: TNotifyEvent;
    FOnTabChanged: TNotifyEvent;
    FOnTabChanging: TFmrBackstageTabChangingEvent;
    FOnButtonClick: TFmrBackstageButtonEvent;
    // state
    FOpen: Boolean;
    FEntries: TArray<TNavEntry>;
    FNavValid: Boolean;
    FNavWidth: Single;
    FBackRect: TRectF;
    FHotIndex: Integer;
    FPressedIndex: Integer;
    FFocusIndex: Integer;
    FShowFocus: Boolean;
    FKeyTipsVisible: Boolean;
    FKeyTips: TArray<string>;
    FKeyTipMatcher: TFmrKeyTipMatcher;
    FAltDown: Boolean;
    FTimer: TTimer;
    FAnimStart: UInt64;
    FAnimProgress: Single;
    FSlideOffset: Single;
    FOpenOpacity: Single;
    FFocusBefore: TFmxObject;
    FUpdatingTabs: Boolean;
    function GetThemeName: string;
    procedure SetThemeName(const Value: string);
    function GetAccentColor: TAlphaColor;
    procedure SetAccentColor(const Value: TAlphaColor);
    function GetThemeProvider: TFmxObject;
    procedure SetThemeProvider(const Value: TFmxObject);
    function IsThemeNameStored: Boolean;
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetActiveTab(const Value: TFmrBackstageTab);
    procedure SetNavigationWidth(const Value: Single);
    function IsNavigationWidthStored: Boolean;
    procedure SetShowBackButton(const Value: Boolean);
    procedure SetCaption(const Value: string);
    procedure SetNavGlyphs(const Value: TFmrBackstageNavGlyphs);
    function GetTabCount: Integer;
    function GetTab(const AIndex: Integer): TFmrBackstageTab;
    function GetButtonCount: Integer;
    function GetButton(const AIndex: Integer): TFmrBackstageButton;
    procedure ThemeChanged(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure SetFocusBefore(const Value: TFmxObject);
    function Metrics: TNavMetrics;
    function ShowsGlyphs: Boolean;
    function ContentRect: TRectF;
    function EntryAt(const P: TPointF): Integer;
    function IndexOfItem(const AItem: TFmxObject): Integer;
    function SelectableEntries: TArray<Boolean>;
    function FrameHostOffset: Single;
    function RouteToActiveTab(const AObject: TFmxObject): Boolean;
    procedure UpdateNav;
    procedure UpdateTabs;
    procedure EnsureActiveTab;
    procedure SetHotIndex(const AIndex: Integer);
    procedure ActivateEntry(const AIndex: Integer; const AByKeyboard: Boolean);
    procedure MoveFocus(const ADelta: Integer);
    procedure FocusContent;
    procedure ShowKeyTips;
    procedure HideKeyTips;
    procedure PaintBackButton(const ACanvas: TCanvas; const M: TNavMetrics; const AOpacity: Single);
    procedure PaintEntry(const ACanvas: TCanvas; const AIndex: Integer; const M: TNavMetrics;
      const AOpacity: Single);
    { IFmrThemeProvider }
    function GetFmrTheme: TFmrTheme;
    { IFmrBarManagerListener }
    procedure BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
      const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
  protected
    procedure Paint; override;
    procedure DoRealign; override;
    procedure Resize; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoAddObject(const AObject: TFmxObject); override;
    procedure DoInsertObject(Index: Integer; const AObject: TFmxObject); override;
    procedure DoRemoveObject(const AObject: TFmxObject); override;
    procedure ChangeChildren; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure DialogKey(var Key: Word; Shift: TShiftState); override;
    procedure DoExit; override;
    function GetHintString: string; override;
    function HasHint: Boolean; override;
    function GetDefaultSize: TSizeF; override;
    procedure DoShow; virtual;
    procedure DoHide; virtual;
    function DoTabChanging(const ANewTab: TFmrBackstageTab): Boolean; virtual;
    procedure DoTabChanged; virtual;
    procedure DoButtonClick(const AButton: TFmrBackstageButton); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetBounds(X, Y, AWidth, AHeight: Single); override;
    /// <summary>Shows the view over its parent (run time only). AByKeyboard shows the key tips of the navigation
    /// items at once (Alt, F).</summary>
    procedure Show(const AByKeyboard: Boolean = False); reintroduce;
    /// <summary>Hides the view and gives the focus back to the control that had it.</summary>
    procedure Hide; reintroduce;
    /// <summary>Shows or hides the view.</summary>
    procedure Toggle;
    { application menu protocol of the ribbon (same shape as IFmrApplicationMenu of FMR.Ribbon, without a dependency
      on the ribbon unit; see Docs\EXTRAS.md) }
    /// <summary>Shows the view for a ribbon: ARibbon becomes the theme provider when ThemeProvider is not set and
    /// ARibbon supports IFmrThemeProvider. AAnchor (the application button) is not used: the view covers the form.
    /// </summary>
    procedure ShowApplicationMenu(const ARibbon: TFmxObject; const AAnchor: TRectF; const AByKeyboard: Boolean);
    function IsApplicationMenuOpen: Boolean;
    procedure CloseApplicationMenu;
    /// <summary>Clicks a navigation button: closes the view (unless KeepOpen) and runs the button.</summary>
    procedure ClickButton(const AButton: TFmrBackstageButton);
    /// <summary>Creates a tab as a child of the view, owned by the owner of the view.</summary>
    function AddTab(const ACaption: string): TFmrBackstageTab;
    /// <summary>Creates a navigation button as a child of the view, owned by the owner of the view.</summary>
    function AddButton(const ACaption: string; const AOnClick: TNotifyEvent = nil): TFmrBackstageButton;
    /// <summary>Recomputes the navigation pane (called automatically when items change).</summary>
    procedure InvalidateNavigation;
    /// <summary>The theme the view paints with.</summary>
    function CurrentTheme: TFmrTheme;
    /// <summary>The painter bound to CurrentTheme.</summary>
    function Painter: TFmrRibbonPainter;
    /// <summary>Screen-independent rectangle (local dp) of a navigation item (empty when not shown).</summary>
    function ItemRect(const AItem: TFmxObject): TRectF;
    /// <summary>Width of the navigation pane in use (NavigationWidth or the automatic width), dp.</summary>
    function NavigationPaneWidth: Single;
    /// <summary>True while the view is shown (run time).</summary>
    property IsOpen: Boolean read FOpen;
    property KeyTipsVisible: Boolean read FKeyTipsVisible;
    property TabCount: Integer read GetTabCount;
    property Tabs[const AIndex: Integer]: TFmrBackstageTab read GetTab;
    property ButtonCount: Integer read GetButtonCount;
    property Buttons[const AIndex: Integer]: TFmrBackstageButton read GetButton;
    property ThemeLink: TFmrThemeLink read FThemeLink;
  published
    property ActiveTab: TFmrBackstageTab read FActiveTab write SetActiveTab;
    /// <summary>Design time only: at run time the view always covers its parent (Contents).</summary>
    property Align;
    property Animation: TFmrBackstageAnimation read FAnimation write FAnimation default TFmrBackstageAnimation.Slide;
    /// <summary>Source of the images of glyphs with an ImageIndex (and of linked items).</summary>
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    /// <summary>Optional title at the top of the navigation pane, next to the back button.</summary>
    property Caption: string read FCaption write SetCaption;
    /// <summary>In the Dwm frame mode the caption content (TFmrFrameHost) lies in the client area: the view starts
    /// below it so the title bar stays visible.</summary>
    property KeepCaptionVisible: Boolean read FKeepCaptionVisible write FKeepCaptionVisible default True;
    property NavGlyphs: TFmrBackstageNavGlyphs read FNavGlyphs write SetNavGlyphs default TFmrBackstageNavGlyphs.Auto;
    /// <summary>Width of the navigation pane in dp; 0 = automatic (fits the captions, at least the theme's minimum).
    /// </summary>
    property NavigationWidth: Single read FNavigationWidth write SetNavigationWidth stored IsNavigationWidthStored;
    /// <summary>The round back arrow at the top of the navigation pane (closes the view).</summary>
    property ShowBackButton: Boolean read FShowBackButton write SetShowBackButton default True;
    /// <summary>Built-in theme used when no theme provider is set.</summary>
    property Theme: string read GetThemeName write SetThemeName stored IsThemeNameStored;
    /// <summary>Accent color of the own theme (0 = the theme's default).</summary>
    property AccentColor: TAlphaColor read GetAccentColor write SetAccentColor default TAlphaColors.Null;
    /// <summary>Object whose theme is used (an object implementing IFmrThemeProvider, normally the TFmrRibbon).
    /// </summary>
    property ThemeProvider: TFmxObject read GetThemeProvider write SetThemeProvider;
    property Enabled;
    property Hint;
    property Opacity;
    property Position;
    property Size;
    property Width;
    property Height;
    property Visible;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnTabChanging: TFmrBackstageTabChangingEvent read FOnTabChanging write FOnTabChanging;
    property OnTabChanged: TNotifyEvent read FOnTabChanged write FOnTabChanged;
    property OnButtonClick: TFmrBackstageButtonEvent read FOnButtonClick write FOnButtonClick;
    property OnKeyDown;
    property OnResize;
  end;

implementation

const
  AnimationDuration = 220; // ms
  SlideDistance = 48;

{ TFmrBackstageViewMessage }

constructor TFmrBackstageViewMessage.Create(const AView: TFmrRibbonBackstageView; const AIsOpen: Boolean);
begin
  inherited Create;
  FView := AView;
  FIsOpen := AIsOpen;
end;

{ TFmrBackstageTab }

constructor TFmrBackstageTab.Create(AOwner: TComponent);
begin
  inherited;
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
  FTabVisible := True;
  ClipChildren := True;
  HitTest := True;
  Padding.DefaultValue := RectF(40, 24, 40, 20);
  Padding.Rect := Padding.DefaultValue;
  SetBounds(0, 0, 400, 300);
end;

destructor TFmrBackstageTab.Destroy;
begin
  FGlyph.Free;
  inherited;
end;

function TFmrBackstageTab.VisibleStored: Boolean;
begin
  // Only the active tab is visible; the view decides
  Result := False;
end;

function TFmrBackstageTab.GetView: TFmrRibbonBackstageView;
begin
  if Parent is TFmrRibbonBackstageView then
    Result := TFmrRibbonBackstageView(Parent)
  else
    Result := nil;
end;

function TFmrBackstageTab.GetIsActive: Boolean;
begin
  Result := (View <> nil) and (View.ActiveTab = Self);
end;

procedure TFmrBackstageTab.Activate;
begin
  if View <> nil then
    View.ActiveTab := Self;
end;

procedure TFmrBackstageTab.Changed;
begin
  if (View <> nil) and ([csLoading, csDestroying] * ComponentState = []) then
    View.InvalidateNavigation;
end;

procedure TFmrBackstageTab.GlyphChanged(Sender: TObject);
begin
  Changed;
end;

procedure TFmrBackstageTab.EnabledChanged;
begin
  inherited;
  Changed;
end;

procedure TFmrBackstageTab.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed;
  end;
end;

procedure TFmrBackstageTab.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrBackstageTab.SetBeginGroup(const Value: Boolean);
begin
  if FBeginGroup <> Value then
  begin
    FBeginGroup := Value;
    Changed;
  end;
end;

procedure TFmrBackstageTab.SetKeyTip(const Value: string);
begin
  FKeyTip := Value.ToUpper;
end;

procedure TFmrBackstageTab.SetTabVisible(const Value: Boolean);
begin
  if FTabVisible <> Value then
  begin
    FTabVisible := Value;
    Changed;
    if (View <> nil) and not Value and IsActive and ([csLoading, csDestroying] * ComponentState = []) then
      View.EnsureActiveTab;
  end;
end;

procedure TFmrBackstageTab.SetNavAlign(const Value: TFmrBackstageNavAlign);
begin
  if FNavAlign <> Value then
  begin
    FNavAlign := Value;
    Changed;
  end;
end;

procedure TFmrBackstageTab.Paint;
begin
  if csDesigning in ComponentState then
    DrawDesignBorder;
end;

{ TFmrBackstageButton }

constructor TFmrBackstageButton.Create(AOwner: TComponent);
begin
  inherited;
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
  FVisible := True;
  FEnabled := True;
end;

destructor TFmrBackstageButton.Destroy;
begin
  SetItem(nil);
  FGlyph.Free;
  inherited;
end;

function TFmrBackstageButton.GetView: TFmrRibbonBackstageView;
begin
  if Parent is TFmrRibbonBackstageView then
    Result := TFmrRibbonBackstageView(Parent)
  else
    Result := nil;
end;

procedure TFmrBackstageButton.Changed;
begin
  if (View <> nil) and ([csLoading, csDestroying] * ComponentState = []) then
    View.InvalidateNavigation;
end;

procedure TFmrBackstageButton.GlyphChanged(Sender: TObject);
begin
  Changed;
end;

procedure TFmrBackstageButton.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FItem) then
  begin
    FItem := nil;
    Changed;
  end;
end;

procedure TFmrBackstageButton.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed;
  end;
end;

procedure TFmrBackstageButton.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrBackstageButton.SetBeginGroup(const Value: Boolean);
begin
  if FBeginGroup <> Value then
  begin
    FBeginGroup := Value;
    Changed;
  end;
end;

procedure TFmrBackstageButton.SetKeyTip(const Value: string);
begin
  FKeyTip := Value.ToUpper;
end;

procedure TFmrBackstageButton.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed;
  end;
end;

procedure TFmrBackstageButton.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    Changed;
  end;
end;

procedure TFmrBackstageButton.SetNavAlign(const Value: TFmrBackstageNavAlign);
begin
  if FNavAlign <> Value then
  begin
    FNavAlign := Value;
    Changed;
  end;
end;

procedure TFmrBackstageButton.SetItem(const Value: TFmrBarItem);
begin
  if FItem <> Value then
  begin
    if FItem <> nil then
      FItem.RemoveFreeNotification(Self);
    FItem := Value;
    if FItem <> nil then
      FItem.FreeNotification(Self);
    Changed;
  end;
end;

function TFmrBackstageButton.DisplayCaption: string;
begin
  Result := FCaption;
  if (Result = '') and (FItem <> nil) then
    Result := FItem.Caption;
end;

function TFmrBackstageButton.DisplayGlyph: TFmrImageSource;
begin
  Result := FGlyph;
  if (FItem <> nil) and FGlyph.IsEmpty and not FItem.Glyph.IsEmpty then
    Result := FItem.Glyph;
end;

function TFmrBackstageButton.IsEnabled: Boolean;
begin
  Result := FEnabled and ((FItem = nil) or FItem.Enabled);
end;

procedure TFmrBackstageButton.Click;
begin
  if not IsEnabled then
    Exit;
  if Assigned(FOnClick) then
    FOnClick(Self)
  else if FItem <> nil then
    FItem.Click;
end;

{ TFmrRibbonBackstageView.TNavEntry }

function TFmrRibbonBackstageView.TNavEntry.IsTab: Boolean;
begin
  Result := Item is TFmrBackstageTab;
end;

{ TFmrRibbonBackstageView }

constructor TFmrRibbonBackstageView.Create(AOwner: TComponent);
begin
  inherited;
  FThemeLink := TFmrThemeLink.Create(Self, ThemeChanged);
  FShowBackButton := True;
  FAnimation := TFmrBackstageAnimation.Slide;
  FKeepCaptionVisible := True;
  FHotIndex := -1;
  FPressedIndex := -1;
  FFocusIndex := -1;
  FAnimProgress := 1;
  FOpenOpacity := 1;
  CanFocus := True;
  HitTest := True;
  ClipChildren := True;
  // clicks reach the view in the designer, so a navigation item can be clicked to show its tab
  FDesignInteractive := True;
  SetBounds(0, 0, 640, 400);
  if not (csDesigning in ComponentState) then
  begin
    Visible := False;
    Align := TAlignLayout.Contents;
  end;
end;

destructor TFmrRibbonBackstageView.Destroy;
begin
  SetFocusBefore(nil);
  if FBarManager <> nil then
    FBarManager.RemoveListener(Self);
  if FThemeLink.Provider <> nil then
    FThemeLink.Provider.RemoveFreeNotification(Self);
  FTimer.Free;
  FKeyTipMatcher.Free;
  FThemeLink.Free;
  FThemeLink := nil;
  inherited;
end;

function TFmrRibbonBackstageView.GetDefaultSize: TSizeF;
begin
  Result := TSizeF.Create(640, 400);
end;

{ theme }

function TFmrRibbonBackstageView.CurrentTheme: TFmrTheme;
begin
  Result := FThemeLink.Theme;
end;

function TFmrRibbonBackstageView.Painter: TFmrRibbonPainter;
begin
  Result := FThemeLink.Painter;
end;

function TFmrRibbonBackstageView.GetFmrTheme: TFmrTheme;
begin
  Result := FThemeLink.Theme;
end;

function TFmrRibbonBackstageView.GetThemeName: string;
begin
  Result := FThemeLink.ThemeName;
end;

procedure TFmrRibbonBackstageView.SetThemeName(const Value: string);
begin
  FThemeLink.ThemeName := Value;
end;

function TFmrRibbonBackstageView.IsThemeNameStored: Boolean;
begin
  Result := FThemeLink.ThemeName <> FmrDefaultThemeName;
end;

function TFmrRibbonBackstageView.GetAccentColor: TAlphaColor;
begin
  Result := FThemeLink.AccentColor;
end;

procedure TFmrRibbonBackstageView.SetAccentColor(const Value: TAlphaColor);
begin
  FThemeLink.AccentColor := Value;
end;

function TFmrRibbonBackstageView.GetThemeProvider: TFmxObject;
begin
  Result := FThemeLink.Provider;
end;

procedure TFmrRibbonBackstageView.SetThemeProvider(const Value: TFmxObject);
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

procedure TFmrRibbonBackstageView.ThemeChanged(Sender: TObject);
begin
  if csDestroying in ComponentState then
    Exit;
  InvalidateNavigation;
  Repaint;
  // helper controls inside the tabs take the theme of the view
  TMessageManager.DefaultManager.SendMessage(Self, TFmrThemeChangedMessage.Create(Self));
end;

procedure TFmrRibbonBackstageView.SetBarManager(const Value: TFmrBarManager);
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
    InvalidateNavigation;
  end;
end;

procedure TFmrRibbonBackstageView.BarManagerChanged(const AManager: TFmrBarManager;
  const AChange: TFmrManagerChange; const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
begin
  case AChange of
    TFmrManagerChange.Destroying:
      FBarManager := nil;
    TFmrManagerChange.ImagesChanged, TFmrManagerChange.Updated, TFmrManagerChange.ItemChanged:
      InvalidateNavigation;
  end;
end;

procedure TFmrRibbonBackstageView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if (FThemeLink <> nil) and (AComponent = FThemeLink.Provider) then
      FThemeLink.Provider := nil;
    if AComponent = FBarManager then
    begin
      FBarManager := nil;
      InvalidateNavigation;
    end;
    if AComponent = FFocusBefore then
      FFocusBefore := nil;
  end;
end;

{ properties }

procedure TFmrRibbonBackstageView.SetNavigationWidth(const Value: Single);
begin
  if not SameValue(FNavigationWidth, Value) then
  begin
    FNavigationWidth := Max(0, Value);
    InvalidateNavigation;
  end;
end;

function TFmrRibbonBackstageView.IsNavigationWidthStored: Boolean;
begin
  Result := FNavigationWidth <> 0;
end;

procedure TFmrRibbonBackstageView.SetShowBackButton(const Value: Boolean);
begin
  if FShowBackButton <> Value then
  begin
    FShowBackButton := Value;
    InvalidateNavigation;
  end;
end;

procedure TFmrRibbonBackstageView.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    InvalidateNavigation;
  end;
end;

procedure TFmrRibbonBackstageView.SetNavGlyphs(const Value: TFmrBackstageNavGlyphs);
begin
  if FNavGlyphs <> Value then
  begin
    FNavGlyphs := Value;
    InvalidateNavigation;
  end;
end;

procedure TFmrRibbonBackstageView.SetActiveTab(const Value: TFmrBackstageTab);
begin
  if FActiveTab = Value then
    Exit;
  if csLoading in ComponentState then
  begin
    FActiveTab := Value;
    Exit;
  end;
  if (Value <> nil) and (Value.Parent <> Self) then
    Exit;
  if not DoTabChanging(Value) then
    Exit;
  FActiveTab := Value;
  FNavValid := False;
  UpdateNav;
  if FActiveTab <> nil then
    FFocusIndex := IndexOfItem(FActiveTab);
  UpdateTabs;
  Repaint;
  DoTabChanged;
end;

function TFmrRibbonBackstageView.GetTabCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrBackstageTab then
      Inc(Result);
end;

function TFmrRibbonBackstageView.GetTab(const AIndex: Integer): TFmrBackstageTab;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrBackstageTab then
    begin
      if N = AIndex then
        Exit(TFmrBackstageTab(Children[I]));
      Inc(N);
    end;
  raise EArgumentOutOfRangeException.CreateFmt('Tab index %d out of range', [AIndex]);
end;

function TFmrRibbonBackstageView.GetButtonCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrBackstageButton then
      Inc(Result);
end;

function TFmrRibbonBackstageView.GetButton(const AIndex: Integer): TFmrBackstageButton;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to ChildrenCount - 1 do
    if Children[I] is TFmrBackstageButton then
    begin
      if N = AIndex then
        Exit(TFmrBackstageButton(Children[I]));
      Inc(N);
    end;
  raise EArgumentOutOfRangeException.CreateFmt('Button index %d out of range', [AIndex]);
end;

function TFmrRibbonBackstageView.AddTab(const ACaption: string): TFmrBackstageTab;
begin
  Result := TFmrBackstageTab.Create(Owner);
  Result.Caption := ACaption;
  Result.Parent := Self;
end;

function TFmrRibbonBackstageView.AddButton(const ACaption: string; const AOnClick: TNotifyEvent): TFmrBackstageButton;
begin
  Result := TFmrBackstageButton.Create(Owner);
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  Result.Parent := Self;
end;

{ children }

function TFmrRibbonBackstageView.RouteToActiveTab(const AObject: TFmxObject): Boolean;
var
  P: TPointF;
begin
  // Controls dropped on the view go into the active tab (the view itself only hosts tabs and buttons)
  Result := (AObject is TControl) and not (AObject is TFmrBackstageTab) and (FActiveTab <> nil) and
    not (csLoading in ComponentState) and not (csDestroying in FActiveTab.ComponentState);
  if not Result then
    Exit;
  P := TControl(AObject).Position.Point;
  FActiveTab.AddObject(AObject);
  if csDesigning in ComponentState then
    TControl(AObject).Position.Point := PointF(Max(0, P.X - FActiveTab.Position.X),
      Max(0, P.Y - FActiveTab.Position.Y));
end;

procedure TFmrRibbonBackstageView.DoAddObject(const AObject: TFmxObject);
begin
  if RouteToActiveTab(AObject) then
    Exit;
  inherited;
  if (AObject is TFmrBackstageTab) and not (csLoading in ComponentState) and
    ((csDesigning in ComponentState) or (FActiveTab = nil)) then
    // a tab dropped in the designer is shown at once (the first tab added in code becomes the active one)
    ActiveTab := TFmrBackstageTab(AObject)
  else if (AObject is TFmrBackstageTab) or (AObject is TFmrBackstageButton) then
    InvalidateNavigation;
end;

procedure TFmrRibbonBackstageView.DoInsertObject(Index: Integer; const AObject: TFmxObject);
begin
  if RouteToActiveTab(AObject) then
    Exit;
  inherited;
end;

procedure TFmrRibbonBackstageView.DoRemoveObject(const AObject: TFmxObject);
begin
  inherited;
  if AObject = FActiveTab then
  begin
    FActiveTab := nil;
    if not (csDestroying in ComponentState) then
      EnsureActiveTab;
  end;
  if not (csDestroying in ComponentState) then
    InvalidateNavigation;
end;

procedure TFmrRibbonBackstageView.ChangeChildren;
begin
  inherited;
  if not (csDestroying in ComponentState) then
    InvalidateNavigation;
end;

procedure TFmrRibbonBackstageView.InvalidateNavigation;
begin
  FNavValid := False;
  if [csLoading, csDestroying] * ComponentState <> [] then
    Exit;
  if FKeyTipsVisible then
    ShowKeyTips;
  Realign;
  Repaint;
end;

procedure TFmrRibbonBackstageView.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    Visible := False;
    Align := TAlignLayout.Contents;
  end;
  if (FActiveTab <> nil) and (FActiveTab.Parent <> Self) then
    FActiveTab := nil;
  EnsureActiveTab;
  FNavValid := False;
  Realign;
end;

procedure TFmrRibbonBackstageView.EnsureActiveTab;
var
  I: Integer;
  T: TFmrBackstageTab;
begin
  if [csLoading, csDestroying] * ComponentState <> [] then
    Exit;
  if (FActiveTab <> nil) and FActiveTab.TabVisible then
  begin
    UpdateTabs;
    Exit;
  end;
  for I := 0 to ChildrenCount - 1 do
    if (Children[I] is TFmrBackstageTab) then
    begin
      T := TFmrBackstageTab(Children[I]);
      if T.TabVisible and T.Enabled and not (csDestroying in T.ComponentState) then
      begin
        FActiveTab := T;
        Break;
      end;
    end;
  UpdateTabs;
end;

{ layout }

function TFmrRibbonBackstageView.Metrics: TNavMetrics;
var
  T: TFmrTheme;
begin
  T := CurrentTheme;
  Result.GlyphSize := 18;
  Result.SeparatorGap := 8;
  case T.Style.Family of
    TFmrThemeFamily.Office2007, TFmrThemeFamily.Office2010:
      begin
        Result.BackHeight := 46;
        Result.BackSize := 32;
        Result.ItemHeight := 34;
        Result.FontSize := T.Metrics.FontSize + 1;
        Result.TextLeft := 18;
        Result.ItemInset := 3;
        Result.ItemRadius := 3;
        Result.RoundBack := False;
        Result.MinWidth := 132;
        Result.GlyphSize := 16;
      end;
    TFmrThemeFamily.Office2013, TFmrThemeFamily.Office2016:
      begin
        Result.BackHeight := 76;
        Result.BackSize := 36;
        Result.ItemHeight := 40;
        Result.FontSize := T.Metrics.FontSize + 3;
        Result.TextLeft := 28;
        Result.ItemInset := 0;
        Result.ItemRadius := 0;
        Result.RoundBack := True;
        Result.MinWidth := 136;
      end;
  else
    begin
      Result.BackHeight := 56;
      Result.BackSize := 36;
      Result.ItemHeight := 40;
      Result.FontSize := T.Metrics.FontSize + 2;
      Result.TextLeft := 22;
      Result.ItemInset := 6;
      Result.ItemRadius := Max(4, T.Metrics.ButtonRadius);
      Result.RoundBack := False;
      Result.MinWidth := 172;
    end;
  end;
end;

function TFmrRibbonBackstageView.ShowsGlyphs: Boolean;
begin
  case FNavGlyphs of
    TFmrBackstageNavGlyphs.Show:
      Result := True;
    TFmrBackstageNavGlyphs.Hide:
      Result := False;
  else
    Result := CurrentTheme.Style.Family in [TFmrThemeFamily.Office365, TFmrThemeFamily.Fluent];
  end;
end;

function TFmrRibbonBackstageView.NavigationPaneWidth: Single;
begin
  UpdateNav;
  Result := FNavWidth;
end;

function TFmrRibbonBackstageView.ContentRect: TRectF;
begin
  UpdateNav;
  Result := RectF(FNavWidth, 0, Max(FNavWidth, Width), Height);
end;

procedure TFmrRibbonBackstageView.UpdateNav;
var
  M: TNavMetrics;
  I, N: Integer;
  Obj: TFmxObject;
  E: TNavEntry;
  Y, W, TextW, BottomHeight, BottomTop: Single;
  Glyphs: Boolean;
  P: TFmrRibbonPainter;

  procedure PlaceGroup(const ABottom: Boolean; const AStartY: Single);
  var
    J: Integer;
    GroupFirst: Boolean;
  begin
    Y := AStartY;
    GroupFirst := True;
    for J := 0 to High(FEntries) do
    begin
      if FEntries[J].Bottom <> ABottom then
        Continue;
      FEntries[J].SeparatorY := 0;
      if not GroupFirst and ((FEntries[J].Item is TFmrBackstageTab) and TFmrBackstageTab(FEntries[J].Item).BeginGroup
        or (FEntries[J].Item is TFmrBackstageButton) and TFmrBackstageButton(FEntries[J].Item).BeginGroup) then
      begin
        FEntries[J].SeparatorY := Round(Y + M.SeparatorGap) + 0.5;
        Y := Y + M.SeparatorGap * 2 + 1;
      end;
      FEntries[J].Rect := RectF(0, Y, FNavWidth, Y + M.ItemHeight);
      Y := Y + M.ItemHeight;
      GroupFirst := False;
    end;
  end;

  function GroupHeight(const ABottom: Boolean): Single;
  var
    J: Integer;
    GroupFirst: Boolean;
  begin
    Result := 0;
    GroupFirst := True;
    for J := 0 to High(FEntries) do
    begin
      if FEntries[J].Bottom <> ABottom then
        Continue;
      if not GroupFirst and ((FEntries[J].Item is TFmrBackstageTab) and TFmrBackstageTab(FEntries[J].Item).BeginGroup
        or (FEntries[J].Item is TFmrBackstageButton) and TFmrBackstageButton(FEntries[J].Item).BeginGroup) then
        Result := Result + M.SeparatorGap * 2 + 1;
      Result := Result + M.ItemHeight;
      GroupFirst := False;
    end;
  end;

begin
  if FNavValid then
    Exit;
  FNavValid := True;
  M := Metrics;
  P := Painter;
  Glyphs := ShowsGlyphs;
  // entries in child order
  FEntries := nil;
  N := 0;
  TextW := 0;
  for I := 0 to ChildrenCount - 1 do
  begin
    Obj := Children[I];
    if csDestroying in Obj.ComponentState then
      Continue;
    if Obj is TFmrBackstageTab then
    begin
      if not TFmrBackstageTab(Obj).TabVisible then
        Continue;
      E.Item := Obj;
      E.Caption := TFmrBackstageTab(Obj).Caption;
      E.Enabled := TFmrBackstageTab(Obj).Enabled;
      E.Bottom := TFmrBackstageTab(Obj).NavAlign = TFmrBackstageNavAlign.Bottom;
    end
    else if Obj is TFmrBackstageButton then
    begin
      if not TFmrBackstageButton(Obj).Visible then
        Continue;
      E.Item := Obj;
      E.Caption := TFmrBackstageButton(Obj).DisplayCaption;
      E.Enabled := TFmrBackstageButton(Obj).IsEnabled;
      E.Bottom := TFmrBackstageButton(Obj).NavAlign = TFmrBackstageNavAlign.Bottom;
    end
    else
      Continue;
    E.Rect := TRectF.Empty;
    E.SeparatorY := 0;
    FEntries := FEntries + [E];
    Inc(N);
    TextW := Max(TextW, P.TextWidth(E.Caption.Replace('&', ''), M.FontSize));
  end;
  // width
  if FNavigationWidth > 0 then
    FNavWidth := FNavigationWidth
  else
  begin
    W := M.TextLeft + TextW + M.TextLeft + M.ItemInset * 2;
    if Glyphs then
      W := W + M.GlyphSize + 12;
    FNavWidth := Max(M.MinWidth, Ceil(W));
  end;
  FNavWidth := Min(FNavWidth, Max(80, Width * 0.5));
  // back button
  if FShowBackButton then
  begin
    if M.RoundBack then
      FBackRect := RectF(M.TextLeft - 6, (M.BackHeight - M.BackSize) / 2 + 4, M.TextLeft - 6 + M.BackSize,
        (M.BackHeight - M.BackSize) / 2 + 4 + M.BackSize)
    else
      FBackRect := RectF(M.ItemInset + 2, (M.BackHeight - M.BackSize) / 2, M.ItemInset + 2 + M.BackSize + 6,
        (M.BackHeight - M.BackSize) / 2 + M.BackSize);
  end
  else
    FBackRect := TRectF.Empty;
  // items
  if FShowBackButton or (FCaption <> '') then
    Y := M.BackHeight
  else
    Y := 12;
  if N > 0 then
  begin
    PlaceGroup(False, Y);
    BottomHeight := GroupHeight(True);
    BottomTop := Max(Y, Height - 12 - BottomHeight);
    PlaceGroup(True, BottomTop);
  end;
  if (FFocusIndex >= Length(FEntries)) then
    FFocusIndex := -1;
  if FHotIndex >= Length(FEntries) then
    FHotIndex := -1;
end;

function TFmrRibbonBackstageView.ItemRect(const AItem: TFmxObject): TRectF;
var
  I: Integer;
begin
  UpdateNav;
  I := IndexOfItem(AItem);
  if I >= 0 then
    Result := FEntries[I].Rect
  else
    Result := TRectF.Empty;
end;

function TFmrRibbonBackstageView.IndexOfItem(const AItem: TFmxObject): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Item = AItem then
      Exit(I);
  Result := -1;
end;

function TFmrRibbonBackstageView.SelectableEntries: TArray<Boolean>;
var
  I: Integer;
begin
  SetLength(Result, Length(FEntries));
  for I := 0 to High(FEntries) do
    Result[I] := FEntries[I].Enabled;
end;

procedure TFmrRibbonBackstageView.UpdateTabs;
var
  I: Integer;
  R: TRectF;
  T: TFmrBackstageTab;
begin
  if FUpdatingTabs or ([csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  FUpdatingTabs := True;
  try
    R := ContentRect;
    for I := 0 to ChildrenCount - 1 do
      if Children[I] is TFmrBackstageTab then
      begin
        T := TFmrBackstageTab(Children[I]);
        if csDestroying in T.ComponentState then
          Continue;
        T.Align := TAlignLayout.None;
        T.SetBounds(R.Left + FSlideOffset, R.Top, R.Width, R.Height);
        T.Visible := T = FActiveTab;
      end;
  finally
    FUpdatingTabs := False;
  end;
end;

procedure TFmrRibbonBackstageView.DoRealign;
begin
  inherited;
  UpdateNav;
  UpdateTabs;
end;

procedure TFmrRibbonBackstageView.Resize;
begin
  inherited;
  FNavValid := False;
end;

function TFmrRibbonBackstageView.FrameHostOffset: Single;
var
  I: Integer;
  C: TFmxObject;
  H: TFmrFrameHost;
begin
  Result := 0;
  if not FKeepCaptionVisible or (Parent = nil) or (csDesigning in ComponentState) then
    Exit;
  // In the Dwm frame mode the caption content is an ordinary MostTop control of the form
  for I := 0 to Parent.ChildrenCount - 1 do
  begin
    C := Parent.Children[I];
    if C is TFmrFrameHost then
    begin
      H := TFmrFrameHost(C);
      if H.Visible and not H.OwnScene and (H.Align in [TAlignLayout.Top, TAlignLayout.MostTop]) then
        Result := Max(Result, H.Position.Y + H.Height);
    end;
  end;
end;

procedure TFmrRibbonBackstageView.SetBounds(X, Y, AWidth, AHeight: Single);
var
  Offset: Single;
begin
  if (Align = TAlignLayout.Contents) and not (csDesigning in ComponentState) then
  begin
    Offset := FrameHostOffset;
    if Offset > 0 then
    begin
      Y := Y + Offset;
      AHeight := Max(0, AHeight - Offset);
    end;
  end;
  inherited SetBounds(X, Y, AWidth, AHeight);
end;

{ show / hide }

procedure TFmrRibbonBackstageView.SetFocusBefore(const Value: TFmxObject);
begin
  if FFocusBefore <> Value then
  begin
    if FFocusBefore <> nil then
      FFocusBefore.RemoveFreeNotification(Self);
    FFocusBefore := Value;
    if FFocusBefore <> nil then
      FFocusBefore.FreeNotification(Self);
  end;
end;

procedure TFmrRibbonBackstageView.Show(const AByKeyboard: Boolean);
begin
  if FOpen or (csDesigning in ComponentState) then
    Exit;
  FOpen := True;
  if (Root <> nil) and (Root.Focused <> nil) then
    SetFocusBefore(Root.Focused.GetObject)
  else
    SetFocusBefore(nil);
  Align := TAlignLayout.Contents;
  EnsureActiveTab;
  FNavValid := False;
  FHotIndex := -1;
  FPressedIndex := -1;
  FShowFocus := AByKeyboard;
  BringToFront;
  FOpenOpacity := Opacity;
  if FAnimation <> TFmrBackstageAnimation.None then
  begin
    FAnimProgress := 0;
    Opacity := 0;
    if FAnimation = TFmrBackstageAnimation.Slide then
      FSlideOffset := -SlideDistance;
    if FTimer = nil then
    begin
      FTimer := TTimer.Create(nil);
      FTimer.Interval := 15;
      FTimer.OnTimer := TimerTick;
    end;
    FAnimStart := TThread.GetTickCount64;
    FTimer.Enabled := True;
  end
  else
  begin
    FAnimProgress := 1;
    FSlideOffset := 0;
  end;
  Visible := True;
  UpdateNav;
  if FActiveTab <> nil then
    FFocusIndex := IndexOfItem(FActiveTab)
  else
    FFocusIndex := FmrEdgeSelectable(SelectableEntries, False);
  Realign;
  DoShow;
  TMessageManager.DefaultManager.SendMessage(Self, TFmrBackstageViewMessage.Create(Self, True));
  if FOpen and CanFocus then
    SetFocus;
  if FOpen and AByKeyboard then
    ShowKeyTips;
end;

procedure TFmrRibbonBackstageView.Hide;
var
  F: TFmxObject;
begin
  if not FOpen then
    Exit;
  FOpen := False;
  if FTimer <> nil then
    FTimer.Enabled := False;
  if FAnimation <> TFmrBackstageAnimation.None then
    Opacity := FOpenOpacity;
  FAnimProgress := 1;
  FSlideOffset := 0;
  HideKeyTips;
  FHotIndex := -1;
  FPressedIndex := -1;
  Visible := False;
  F := FFocusBefore;
  SetFocusBefore(nil);
  if (F is TControl) and TControl(F).ParentedVisible and TControl(F).CanFocus and TControl(F).AbsoluteEnabled then
    TControl(F).SetFocus;
  DoHide;
  TMessageManager.DefaultManager.SendMessage(Self, TFmrBackstageViewMessage.Create(Self, False));
end;

procedure TFmrRibbonBackstageView.Toggle;
begin
  if FOpen then
    Hide
  else
    Show;
end;

procedure TFmrRibbonBackstageView.ShowApplicationMenu(const ARibbon: TFmxObject; const AAnchor: TRectF;
  const AByKeyboard: Boolean);
begin
  if (ThemeProvider = nil) and (ARibbon <> nil) and TFmrThemeLink.IsProvider(ARibbon) then
    ThemeProvider := ARibbon;
  Show(AByKeyboard);
end;

function TFmrRibbonBackstageView.IsApplicationMenuOpen: Boolean;
begin
  Result := FOpen;
end;

procedure TFmrRibbonBackstageView.CloseApplicationMenu;
begin
  Hide;
end;

procedure TFmrRibbonBackstageView.TimerTick(Sender: TObject);
var
  T, E: Single;
begin
  T := EnsureRange((TThread.GetTickCount64 - FAnimStart) / AnimationDuration, 0, 1);
  // ease out (cubic)
  E := 1 - Power(1 - T, 3);
  FAnimProgress := T;
  Opacity := FOpenOpacity * E;
  if FAnimation = TFmrBackstageAnimation.Slide then
    FSlideOffset := -SlideDistance * (1 - E)
  else
    FSlideOffset := 0;
  if T >= 1 then
  begin
    FTimer.Enabled := False;
    Opacity := FOpenOpacity;
    FSlideOffset := 0;
  end;
  UpdateTabs;
  Repaint;
end;

procedure TFmrRibbonBackstageView.DoShow;
begin
  if Assigned(FOnShow) then
    FOnShow(Self);
end;

procedure TFmrRibbonBackstageView.DoHide;
begin
  if Assigned(FOnHide) then
    FOnHide(Self);
end;

function TFmrRibbonBackstageView.DoTabChanging(const ANewTab: TFmrBackstageTab): Boolean;
begin
  Result := True;
  if Assigned(FOnTabChanging) then
    FOnTabChanging(Self, ANewTab, Result);
end;

procedure TFmrRibbonBackstageView.DoTabChanged;
begin
  if Assigned(FOnTabChanged) then
    FOnTabChanged(Self);
end;

procedure TFmrRibbonBackstageView.DoButtonClick(const AButton: TFmrBackstageButton);
begin
  if Assigned(FOnButtonClick) then
    FOnButtonClick(Self, AButton);
end;

procedure TFmrRibbonBackstageView.ClickButton(const AButton: TFmrBackstageButton);
begin
  if (AButton = nil) or not AButton.IsEnabled then
    Exit;
  // Office closes the view first, so a dialog opened by the command shows over the document
  if not AButton.KeepOpen then
    Hide;
  AButton.Click;
  DoButtonClick(AButton);
end;

procedure TFmrRibbonBackstageView.ActivateEntry(const AIndex: Integer; const AByKeyboard: Boolean);
var
  Obj: TFmxObject;
begin
  if (AIndex < 0) or (AIndex > High(FEntries)) or not FEntries[AIndex].Enabled then
    Exit;
  Obj := FEntries[AIndex].Item;
  FFocusIndex := AIndex;
  if Obj is TFmrBackstageTab then
  begin
    ActiveTab := TFmrBackstageTab(Obj);
    if AByKeyboard then
      FocusContent;
  end
  else if Obj is TFmrBackstageButton then
    ClickButton(TFmrBackstageButton(Obj));
  Repaint;
end;

procedure TFmrRibbonBackstageView.MoveFocus(const ADelta: Integer);
var
  I: Integer;
begin
  UpdateNav;
  if ADelta = 0 then
    Exit;
  if Abs(ADelta) > 1 then
    I := FmrEdgeSelectable(SelectableEntries, ADelta > 0)
  else
    I := FmrNextSelectable(SelectableEntries, FFocusIndex, ADelta, True);
  if I < 0 then
    Exit;
  FFocusIndex := I;
  FShowFocus := True;
  // like Office: moving over a tab shows it
  if FEntries[I].IsTab then
    ActiveTab := TFmrBackstageTab(FEntries[I].Item);
  Repaint;
end;

procedure TFmrRibbonBackstageView.FocusContent;
var
  Next: IControl;
begin
  if FActiveTab = nil then
    Exit;
  Next := FActiveTab.GetTabList.FindNextTabStop(nil, True, False);
  if Next <> nil then
    Next.SetFocus;
end;

{ key tips }

procedure TFmrRibbonBackstageView.ShowKeyTips;
var
  Entries: TArray<TFmrKeyTipEntry>;
  I: Integer;
  Explicit: string;
begin
  UpdateNav;
  SetLength(Entries, Length(FEntries));
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Item is TFmrBackstageTab then
      Explicit := TFmrBackstageTab(FEntries[I].Item).KeyTip
    else if FEntries[I].Item is TFmrBackstageButton then
      Explicit := TFmrBackstageButton(FEntries[I].Item).KeyTip
    else
      Explicit := '';
    Entries[I] := TFmrKeyTipEntry.Create(FEntries[I].Caption, Explicit, I);
  end;
  TFmrKeyTipAssigner.Assign(Entries);
  SetLength(FKeyTips, Length(Entries));
  for I := 0 to High(Entries) do
    FKeyTips[I] := Entries[I].KeyTip;
  if FKeyTipMatcher = nil then
    FKeyTipMatcher := TFmrKeyTipMatcher.Create(FKeyTips)
  else
    FKeyTipMatcher.Reset(FKeyTips);
  FKeyTipsVisible := True;
  Repaint;
end;

procedure TFmrRibbonBackstageView.HideKeyTips;
begin
  if FKeyTipsVisible then
  begin
    FKeyTipsVisible := False;
    Repaint;
  end;
end;

{ mouse }

function TFmrRibbonBackstageView.EntryAt(const P: TPointF): Integer;
var
  I: Integer;
begin
  UpdateNav;
  if not FBackRect.IsEmpty and FBackRect.Contains(P) then
    Exit(BackButtonIndex);
  if P.X >= FNavWidth then
    Exit(-1);
  for I := 0 to High(FEntries) do
    if FEntries[I].Rect.Contains(P) then
      Exit(I);
  Result := -1;
end;

procedure TFmrRibbonBackstageView.SetHotIndex(const AIndex: Integer);
begin
  if FHotIndex <> AIndex then
  begin
    FHotIndex := AIndex;
    if (AIndex <> -1) and not (csDesigning in ComponentState) and (Application <> nil) then
      Application.HideHint;
    Repaint;
  end;
end;

procedure TFmrRibbonBackstageView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
{$IFDEF MSWINDOWS}
  Form: TComponent;
{$ENDIF}
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  I := EntryAt(PointF(X, Y));
  if csDesigning in ComponentState then
  begin
    if (I >= 0) and FEntries[I].IsTab then
    begin
      ActiveTab := TFmrBackstageTab(FEntries[I].Item);
{$IFDEF MSWINDOWS}
      Form := Owner;
      while (Form <> nil) and not (Form is TCommonCustomForm) do
        Form := Form.Owner;
      if (Form <> nil) and (TCommonCustomForm(Form).Designer <> nil) then
      begin
        TCommonCustomForm(Form).Designer.SelectComponent(FActiveTab);
        TCommonCustomForm(Form).Designer.Modified;
      end;
{$ENDIF}
    end;
    Exit;
  end;
  HideKeyTips;
  FShowFocus := False;
  FPressedIndex := I;
  if (I >= 0) and FEntries[I].IsTab and FEntries[I].Enabled then
    ActivateEntry(I, False);
  if CanFocus and not IsFocused then
    SetFocus;
  Repaint;
end;

procedure TFmrRibbonBackstageView.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if csDesigning in ComponentState then
    Exit;
  SetHotIndex(EntryAt(PointF(X, Y)));
end;

procedure TFmrRibbonBackstageView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I, Pressed: Integer;
begin
  inherited;
  if (Button <> TMouseButton.mbLeft) or (csDesigning in ComponentState) then
    Exit;
  Pressed := FPressedIndex;
  FPressedIndex := -1;
  I := EntryAt(PointF(X, Y));
  if (I = Pressed) and (I <> -1) then
  begin
    if I = BackButtonIndex then
      Hide
    else if (I >= 0) and not FEntries[I].IsTab then
      ActivateEntry(I, False);
  end;
  Repaint;
end;

procedure TFmrRibbonBackstageView.DoMouseLeave;
begin
  inherited;
  FHotIndex := -1;
  Repaint;
end;

function TFmrRibbonBackstageView.GetHintString: string;
begin
  if FHotIndex = BackButtonIndex then
    Result := FmrStr(TFmrStringId.BackstageBack)
  else if (FHotIndex >= 0) and (FHotIndex <= High(FEntries)) then
  begin
    if FEntries[FHotIndex].Item is TFmrBackstageButton then
      Result := TFmrBackstageButton(FEntries[FHotIndex].Item).Hint
    else
      Result := TFmrBackstageTab(FEntries[FHotIndex].Item).Hint;
  end
  else
    Result := '';
end;

function TFmrRibbonBackstageView.HasHint: Boolean;
begin
  Result := CanShowHint and (FHotIndex <> -1) and (GetHintString <> '');
end;

{ keyboard }

procedure TFmrRibbonBackstageView.DialogKey(var Key: Word; Shift: TShiftState);
begin
  if FOpen then
  begin
    if (Key = vkEscape) and (Shift * [ssAlt, ssCtrl, ssShift] = []) then
    begin
      if FKeyTipsVisible and (FKeyTipMatcher <> nil) and (FKeyTipMatcher.Typed <> '') then
      begin
        FKeyTipMatcher.Reset;
        Repaint;
      end
      else
        Hide;
      Key := 0;
      Exit;
    end;
    if Key = vkMenu then
      FAltDown := True
    else
      FAltDown := False;
  end;
  inherited;
end;

procedure TFmrRibbonBackstageView.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  Match: TFmrKeyTipMatch;
begin
  inherited;
  if not FOpen or ((Key = 0) and (KeyChar = #0)) then
    Exit;
  if FKeyTipsVisible and (FKeyTipMatcher <> nil) then
  begin
    if (KeyChar <> #0) and (KeyChar > ' ') then
    begin
      Match := FKeyTipMatcher.Press(KeyChar);
      if Match = TFmrKeyTipMatch.Complete then
      begin
        HideKeyTips;
        ActivateEntry(FKeyTipMatcher.MatchedIndex, True);
      end
      else
        Repaint;
      KeyChar := #0;
      Key := 0;
      Exit;
    end;
    if Key = vkBack then
    begin
      if not FKeyTipMatcher.Backspace then
        HideKeyTips;
      Repaint;
      Key := 0;
      Exit;
    end;
  end;
  case Key of
    vkUp:
      MoveFocus(-1);
    vkDown:
      MoveFocus(1);
    vkHome:
      MoveFocus(-2);
    vkEnd:
      MoveFocus(2);
    vkReturn, vkSpace:
      ActivateEntry(FFocusIndex, True);
    vkRight:
      FocusContent;
  else
    Exit;
  end;
  HideKeyTips;
  Key := 0;
  KeyChar := #0;
end;

procedure TFmrRibbonBackstageView.KeyUp(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  inherited;
  if FOpen and (Key = vkMenu) and FAltDown then
  begin
    FAltDown := False;
    if FKeyTipsVisible then
      HideKeyTips
    else
      ShowKeyTips;
    Key := 0;
  end;
end;

procedure TFmrRibbonBackstageView.DoExit;
begin
  inherited;
  HideKeyTips;
  Repaint;
end;

{ painting }

procedure TFmrRibbonBackstageView.PaintBackButton(const ACanvas: TCanvas; const M: TNavMetrics;
  const AOpacity: Single);
var
  P: TFmrRibbonPainter;
  T: TFmrTheme;
  R: TRectF;
  C: TPointF;
  Col: TAlphaColor;
  Stroke: TStrokeBrush;
  Hot, Pressed: Boolean;
  A: Single;
begin
  if FBackRect.IsEmpty then
    Exit;
  P := Painter;
  T := CurrentTheme;
  Hot := FHotIndex = BackButtonIndex;
  Pressed := Hot and (FPressedIndex = BackButtonIndex);
  R := FBackRect;
  Col := T.Colors[TFmrToken.BackstageNavText];
  Stroke := TStrokeBrush.Create(TBrushKind.Solid, Col);
  try
    Stroke.Cap := TStrokeCap.Round;
    Stroke.Join := TStrokeJoin.Round;
    if M.RoundBack then
    begin
      if Pressed then
        P.Fill(ACanvas, R, TFmrToken.BackstageNavSelectedFill, R.Width / 2, [], AOpacity)
      else if Hot then
        P.Fill(ACanvas, R, TFmrToken.BackstageNavHotFill, R.Width / 2, [], AOpacity);
      Stroke.Thickness := 1.5;
      ACanvas.DrawEllipse(RectF(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1), AOpacity, Stroke);
      A := 7;
    end
    else
    begin
      if Pressed then
        P.Fill(ACanvas, R, TFmrToken.BackstageNavSelectedFill, M.ItemRadius, [], AOpacity)
      else if Hot then
        P.Fill(ACanvas, R, TFmrToken.BackstageNavHotFill, M.ItemRadius, [], AOpacity);
      Stroke.Thickness := 1.5;
      A := 8;
    end;
    C := R.CenterPoint;
    ACanvas.DrawLine(PointF(C.X - A, C.Y), PointF(C.X + A, C.Y), AOpacity, Stroke);
    ACanvas.DrawLine(PointF(C.X - A, C.Y), PointF(C.X - A + 5.5, C.Y - 5.5), AOpacity, Stroke);
    ACanvas.DrawLine(PointF(C.X - A, C.Y), PointF(C.X - A + 5.5, C.Y + 5.5), AOpacity, Stroke);
  finally
    Stroke.Free;
  end;
end;

procedure TFmrRibbonBackstageView.PaintEntry(const ACanvas: TCanvas; const AIndex: Integer; const M: TNavMetrics;
  const AOpacity: Single);
var
  P: TFmrRibbonPainter;
  T: TFmrTheme;
  E: TNavEntry;
  R, HR, TR, GR, KR: TRectF;
  Selected, Hot, Pressed, Colored: Boolean;
  TextCol, Indicator: TAlphaColor;
  Op: Single;
  Glyph: TFmrImageSource;
  Images: TCustomImageList;
  KS: TSizeF;
begin
  P := Painter;
  T := CurrentTheme;
  E := FEntries[AIndex];
  R := E.Rect;
  if R.IsEmpty then
    Exit;
  Selected := E.IsTab and (E.Item = FActiveTab);
  Hot := E.Enabled and (FHotIndex = AIndex);
  Pressed := Hot and (FPressedIndex = AIndex) and not E.IsTab;
  HR := R;
  HR.Inflate(-M.ItemInset, 0);
  if M.ItemInset > 0 then
    HR.Inflate(0, -1);
  if Selected or Pressed then
    P.Fill(ACanvas, HR, TFmrToken.BackstageNavSelectedFill, M.ItemRadius, [], AOpacity)
  else if Hot then
    P.Fill(ACanvas, HR, TFmrToken.BackstageNavHotFill, M.ItemRadius, [], AOpacity);
  // Office 365 / Fluent: an accent bar marks the selected item when the pane is not colored
  if Selected and (T.Style.Family in [TFmrThemeFamily.Office365, TFmrThemeFamily.Fluent]) then
  begin
    Colored := T.Fills[TFmrToken.BackstageNavFill].MainColor = T.Colors[TFmrToken.Accent];
    if not Colored then
    begin
      Indicator := T.Colors[TFmrToken.TabActiveIndicator];
      P.Fill(ACanvas, RectF(HR.Left + 1, HR.CenterPoint.Y - 8, HR.Left + 4, HR.CenterPoint.Y + 8),
        TFmrFill.Solid(Indicator), 1.5, [], AOpacity);
    end;
  end;
  if Selected then
    TextCol := T.Colors[TFmrToken.BackstageNavSelectedText]
  else
    TextCol := T.Colors[TFmrToken.BackstageNavText];
  Op := AOpacity;
  if not E.Enabled then
    Op := Op * 0.45;
  TR := RectF(HR.Left + M.TextLeft - M.ItemInset, R.Top, HR.Right - 6, R.Bottom);
  GR := TRectF.Empty;
  if ShowsGlyphs then
  begin
    if E.Item is TFmrBackstageTab then
      Glyph := TFmrBackstageTab(E.Item).Glyph
    else
      Glyph := TFmrBackstageButton(E.Item).DisplayGlyph;
    if FBarManager <> nil then
      Images := FBarManager.Images
    else
      Images := nil;
    GR := RectF(TR.Left, R.CenterPoint.Y - M.GlyphSize / 2, TR.Left + M.GlyphSize, R.CenterPoint.Y + M.GlyphSize / 2);
    if not Glyph.IsEmpty(Images) then
      Glyph.Draw(ACanvas, GR, Op, TextCol, Images);
    TR.Left := GR.Right + 12;
  end;
  P.TextEx(ACanvas, TR, E.Caption.Replace('&', ''), TextCol, TTextAlign.Leading, TTextAlign.Center, M.FontSize,
    False, False, TTextTrimming.Character, Op);
  // keyboard focus
  if FShowFocus and IsFocused and (AIndex = FFocusIndex) then
    P.Frame(ACanvas, RectF(HR.Left + 2, HR.Top + 2, HR.Right - 2, HR.Bottom - 2),
      FmrWithAlpha(T.Colors[TFmrToken.BackstageNavText], 0.85), M.ItemRadius, [], 1, AOpacity);
  // key tip
  if FKeyTipsVisible and (AIndex <= High(FKeyTips)) and (FKeyTips[AIndex] <> '') and
    ((FKeyTipMatcher = nil) or FKeyTipMatcher.IsCandidate(AIndex)) then
  begin
    // over the glyph when glyphs are shown, otherwise in the margin left of the text
    KS := P.KeyTipSize(FKeyTips[AIndex]);
    if ShowsGlyphs then
      KR := RectF(0, 0, KS.Width, KS.Height).CenterAt(GR)
    else
      KR := RectF(TR.Left - 4 - KS.Width, R.CenterPoint.Y - KS.Height / 2, TR.Left - 4,
        R.CenterPoint.Y + KS.Height / 2);
    if KR.Left < 2 then
      KR.Offset(2 - KR.Left, 0);
    KR := RectF(Round(KR.Left), Round(KR.Top), Round(KR.Left) + KS.Width, Round(KR.Top) + KS.Height);
    P.DrawKeyTip(ACanvas, KR, FKeyTips[AIndex], E.Enabled);
  end;
end;

procedure TFmrRibbonBackstageView.Paint;
var
  P: TFmrRibbonPainter;
  T: TFmrTheme;
  M: TNavMetrics;
  R, NavR, CR: TRectF;
  Op, X: Single;
  I: Integer;
  SepCol: TAlphaColor;
begin
  UpdateNav;
  P := Painter;
  T := CurrentTheme;
  M := Metrics;
  Op := AbsoluteOpacity;
  R := LocalRect;
  P.Fill(Canvas, R, TFmrToken.BackstageFill, 0, [], Op);
  if FSlideOffset <> 0 then
    Canvas.SetMatrix(TMatrix.CreateTranslation(FSlideOffset, 0) * AbsoluteMatrix);
  try
    NavR := RectF(Min(0, FSlideOffset * 2), 0, FNavWidth, R.Height);
    P.Fill(Canvas, NavR, TFmrToken.BackstageNavFill, 0, [], Op);
    SepCol := T.Colors[TFmrToken.BackstageNavSeparator];
    if not (T.Style.Family in [TFmrThemeFamily.Office2013, TFmrThemeFamily.Office2016]) then
    begin
      X := Round(FNavWidth) - 0.5;
      P.Line(Canvas, PointF(X, 0), PointF(X, R.Height), SepCol, 1, Op);
    end;
    PaintBackButton(Canvas, M, Op);
    if FCaption <> '' then
    begin
      if FBackRect.IsEmpty then
        CR := RectF(M.TextLeft, 0, FNavWidth - 8, M.BackHeight)
      else
        CR := RectF(FBackRect.Right + 10, FBackRect.Top, FNavWidth - 8, FBackRect.Bottom);
      P.TextEx(Canvas, CR, FCaption, T.Colors[TFmrToken.BackstageNavText], TTextAlign.Leading, TTextAlign.Center,
        M.FontSize, True, False, TTextTrimming.Character, Op);
    end;
    for I := 0 to High(FEntries) do
    begin
      if FEntries[I].SeparatorY > 0 then
        P.Line(Canvas, PointF(M.TextLeft - 8, FEntries[I].SeparatorY),
          PointF(FNavWidth - M.TextLeft + 8, FEntries[I].SeparatorY), SepCol, 1, Op);
      PaintEntry(Canvas, I, M, Op);
    end;
  finally
    if FSlideOffset <> 0 then
      Canvas.SetMatrix(AbsoluteMatrix);
  end;
  if (csDesigning in ComponentState) and (TabCount = 0) then
    P.TextEx(Canvas, RectF(FNavWidth + 24, 24, R.Width - 24, R.Height - 24),
      'Add TFmrBackstageTab and TFmrBackstageButton children to build the view.',
      T.Colors[TFmrToken.BackstageText], TTextAlign.Leading, TTextAlign.Leading, T.Metrics.FontSize, False, True);
end;

initialization
  RegisterFmxClasses([TFmrRibbonBackstageView, TFmrBackstageTab, TFmrBackstageButton]);

end.
