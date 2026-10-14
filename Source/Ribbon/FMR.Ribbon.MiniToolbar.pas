{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Mini toolbar                                         }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.MiniToolbar;

/// TFmrRibbonMiniToolbar: the floating formatting toolbar of Office. ItemLinks are shown with the ribbon's own item
/// views in the Toolbar place (glyph buttons, split and drop-down buttons, color items, editors such as the font name
/// and size combos); a TFmrSeparatorItem link starts a new row, BeginGroup leaves a gap.
///   - Popup(ScreenPoint): the toolbar appears above the point, semi-transparent; it fades in as the mouse comes near
///     and fades out as it goes away, and closes beyond FadeDistance (like Office after selecting text).
///   - Popup(ScreenPoint, True) with PopupMenu assigned: the context menu opens at the point and the toolbar above it,
///     fully opaque while the menu is open (Office right click). Choosing a command of the menu closes both; using the
///     toolbar closes the menu and keeps the toolbar.
/// The toolbar window is a popup outside the popup chain (menus of the ribbon do not close it); drop-downs of its
/// buttons are its child popups.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Layout, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup,
  FMR.Ribbon.ScreenTips;

type
  TFmrRibbonMiniToolbar = class;

  /// <summary>Content of the mini toolbar window: item views laid out in rows.</summary>
  TFmrMiniToolbarContent = class(TControl, IFmrElementHost, IFmrPopupContent)
  private
    [Weak] FToolbar: TFmrRibbonMiniToolbar;
    FContext: IFmrPopupContext;
    FViews: TObjectList<TFmrItemView>;
    FTracker: TFmrElementTracker;
    FTips: TFmrScreenTipController;
    FSize: TSizeF;
    FDropped: TFmrElement;
    FDropPopup: TFmrPopupForm;
    procedure Build;
    function FindElement(const P: TPointF): TFmrElement;
    procedure TrackerHotChanged(Sender: TObject);
    procedure PaintContent(const ACanvas: TCanvas);
    function ElementScreenRect(const AElement: TFmrElement): TRectF;
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
    procedure DoMouseLeave; override;
  public
    constructor CreateContent(const AToolbar: TFmrRibbonMiniToolbar; const AContext: IFmrPopupContext);
    destructor Destroy; override;
    /// <summary>The view of ALink (nil when the link is not shown).</summary>
    function ViewOf(const ALink: TFmrItemLink): TFmrItemView;
    /// <summary>The toolbar without the shadow margin (local and screen coordinates).</summary>
    function ToolbarRect: TRectF;
    function ToolbarScreenRect: TRectF;
    property Views: TObjectList<TFmrItemView> read FViews;
    property DropPopup: TFmrPopupForm read FDropPopup;
  end;

  /// <summary>Office mini toolbar (floating formatting toolbar near the mouse).</summary>
  TFmrRibbonMiniToolbar = class(TFmxObject, IFmrItemLinksOwner, IFmrKeyHandler)
  private
    FItemLinks: TFmrItemLinks;
    FBarManager: TFmrBarManager;
    FThemeSource: TFmxObject;
    FThemeName: string;
    FTheme: TFmrTheme;
    FPainter: TFmrRibbonPainter;
    FPopupMenu: TFmrPopupMenu;
    FFadeDistance: Single;
    FWindow: TFmrPopupForm;
    FContent: TFmrMiniToolbarContent;
    FTimer: TTimer;
    FWithMenu: Boolean;
    FMenuSeen: Boolean;
    FOpacity: Single;
    FKeyboard: Boolean;
    FOnPopup: TNotifyEvent;
    FOnCloseUp: TNotifyEvent;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetThemeSource(const Value: TFmxObject);
    procedure SetPopupMenu(const Value: TFmrPopupMenu);
    procedure SetThemeName(const Value: string);
    function IsThemeNameStored: Boolean;
    function IsFadeDistanceStored: Boolean;
    function ResolvePainter: TFmrRibbonPainter;
    function ResolveImages: TCustomImageList;
    procedure TimerProc(Sender: TObject);
    procedure SetWindowOpacity(const AValue: Single);
    /// <summary>The toolbar window never gets the keyboard focus: while one of its editors is focused (clicked),
    /// the keys of the owner form are routed to it (key handler of the popup manager).</summary>
    procedure UpdateKeyboard;
    procedure LeaveEditor;
    /// <summary>Enter, Tab and Escape in a focused editor of the toolbar (commit, back to the document).</summary>
    function EditorKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
    { IFmrKeyHandler }
    function HandleKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure KeyboardLost;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Shows the toolbar above AScreenPoint (dp). AWithMenu: also shows PopupMenu at the point (right
    /// click); the toolbar stays opaque while the menu is open.</summary>
    procedure Popup(const AScreenPoint: TPointF; const AWithMenu: Boolean = False);
    procedure ClosePopup;
    function IsOpen: Boolean;
    /// <summary>Current opacity of the window (fading).</summary>
    property Opacity: Single read FOpacity;
    property Content: TFmrMiniToolbarContent read FContent;
    property Window: TFmrPopupForm read FWindow;
  published
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    /// <summary>Distance in dp from the toolbar at which it has faded out and closes.</summary>
    property FadeDistance: Single read FFadeDistance write FFadeDistance stored IsFadeDistanceStored;
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    /// <summary>Context menu shown together with the toolbar by Popup(Point, True).</summary>
    property PopupMenu: TFmrPopupMenu read FPopupMenu write SetPopupMenu;
    /// <summary>Theme name used when ThemeSource is not set.</summary>
    property Theme: string read FThemeName write SetThemeName stored IsThemeNameStored;
    /// <summary>A ribbon (or any IFmrThemeSource) whose theme and images the toolbar uses.</summary>
    property ThemeSource: TFmxObject read FThemeSource write SetThemeSource;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
  end;

implementation

uses
  FMX.Platform;

const
  ToolbarPad = 4;
  /// Room for the soft shadow inside the content (the window has no frame shadow, so everything fades together).
  ToolbarMargin = 7;
  RowGap = 2;
  GroupGap = 5;

{ TFmrMiniToolbarContent }

constructor TFmrMiniToolbarContent.CreateContent(const AToolbar: TFmrRibbonMiniToolbar;
  const AContext: IFmrPopupContext);
begin
  inherited Create(nil);
  FToolbar := AToolbar;
  FContext := AContext;
  FViews := TObjectList<TFmrItemView>.Create(True);
  FTracker := TFmrElementTracker.Create(Self,
    function(const P: TPointF): TFmrElement
    begin
      Result := FindElement(P);
    end);
  FTracker.OnHotChanged := TrackerHotChanged;
  FTips := TFmrScreenTipController.Create;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
  Build;
end;

destructor TFmrMiniToolbarContent.Destroy;
begin
  if FDropPopup <> nil then
  begin
    FDropPopup.OnClosed := nil;
    if FmrPopupsAssigned then
      FmrPopups.Close(FDropPopup);
    FDropPopup := nil;
  end;
  FreeAndNil(FTips);
  FTracker.Reset;
  FreeAndNil(FTracker);
  FreeAndNil(FViews);
  FContext := nil;
  inherited;
end;

procedure TFmrMiniToolbarContent.Build;
var
  M: TFmrThemeMetrics;
  I: Integer;
  L: TFmrItemLink;
  V: TFmrItemView;
  X, Y, W, H, MaxW: Single;
  RowStart: Boolean;
begin
  M := GetPainter.Metrics;
  FViews.Clear;
  H := M.SmallButtonHeight + 2;
  X := ToolbarMargin + ToolbarPad;
  Y := ToolbarMargin + ToolbarPad;
  MaxW := 0;
  RowStart := True;
  for I := 0 to FToolbar.FItemLinks.Count - 1 do
  begin
    L := FToolbar.FItemLinks[I];
    if not L.IsVisible or (L.Item = nil) then
      Continue;
    if L.Item is TFmrSeparatorItem then
    begin
      // A separator starts a new row.
      if not RowStart then
      begin
        X := ToolbarMargin + ToolbarPad;
        Y := Y + H + RowGap;
        RowStart := True;
      end;
      Continue;
    end;
    V := FmrCreateItemView(Self, L, TFmrViewPlace.Toolbar);
    FViews.Add(V);
    if L.BeginGroup and not RowStart then
      X := X + GroupGap;
    W := V.MeasureWidth(TFmrViewLevel.Small);
    V.Place(RectF(X, Y, X + W, Y + H), TFmrViewLevel.Small, TFmrLayoutSegment.None);
    X := X + W + 1;
    MaxW := Max(MaxW, X);
    RowStart := False;
  end;
  if RowStart and (Y > ToolbarMargin + ToolbarPad) then
    Y := Y - H - RowGap;
  FSize := TSizeF.Create(Ceil(MaxW + ToolbarPad - 1 + ToolbarMargin), Ceil(Y + H + ToolbarPad + ToolbarMargin));
  if FViews.Count = 0 then
    FSize := TSizeF.Create(40 + 2 * ToolbarMargin, H + 2 * ToolbarPad + 2 * ToolbarMargin);
end;

function TFmrMiniToolbarContent.ViewOf(const ALink: TFmrItemLink): TFmrItemView;
var
  V: TFmrItemView;
begin
  for V in FViews do
    if V.Link = ALink then
      Exit(V);
  Result := nil;
end;

function TFmrMiniToolbarContent.FindElement(const P: TPointF): TFmrElement;
var
  V: TFmrItemView;
begin
  for V in FViews do
    if V.Visible and (V.PartAt(P) <> TFmrElementPart.None) then
      Exit(V);
  Result := nil;
end;

function TFmrMiniToolbarContent.ElementScreenRect(const AElement: TFmrElement): TRectF;
var
  TL, BR: TPointF;
begin
  TL := LocalToScreen(AElement.Bounds.TopLeft);
  BR := LocalToScreen(AElement.Bounds.BottomRight);
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

procedure TFmrMiniToolbarContent.TrackerHotChanged(Sender: TObject);
var
  E: TFmrElement;
  R: TRectF;
begin
  E := FTracker.Hot;
  if (E <> nil) and (FTracker.Pressed = nil) and (FDropPopup = nil) then
  begin
    R := ElementScreenRect(E);
    R.Bottom := Max(R.Bottom, LocalToScreen(PointF(0, Height)).Y + 2);
    FTips.Hover(E, R, GetPainter, FContext.OwnerForm);
  end
  else
    FTips.Hover(nil, TRectF.Empty, GetPainter, FContext.OwnerForm);
end;

function TFmrMiniToolbarContent.GetPainter: TFmrRibbonPainter;
begin
  Result := FContext.Painter;
end;

function TFmrMiniToolbarContent.GetImages: TCustomImageList;
begin
  Result := FContext.Images;
end;

function TFmrMiniToolbarContent.GetHostControl: TControl;
begin
  Result := Self;
end;

procedure TFmrMiniToolbarContent.InvalidateElement(const AElement: TFmrElement);
var
  R: TRectF;
begin
  R := AElement.Bounds;
  R.Inflate(2, 2);
  InvalidateRect(R);
end;

procedure TFmrMiniToolbarContent.ElementDropDown(const AElement: TFmrElement; const AByKeyboard: Boolean);
var
  Content: TControl;
  P: TFmrPopupForm;
  F: TCommonCustomForm;
begin
  if not (AElement is TFmrItemView) then
    Exit;
  if FDropped = AElement then
  begin
    if FDropPopup <> nil then
      FmrPopups.Close(FDropPopup);
    Exit;
  end;
  FTips.Cancel;
  Content := FmrCreateDropDownContent(TFmrItemView(AElement).Item, FContext);
  if Content = nil then
    Exit;
  F := FmrFormOf(Self);
  P := TFmrPopupForm.CreatePopup(FContext, Content);
  P.AnchorElement := AElement;
  FDropped := AElement;
  FDropPopup := P;
  P.OnClosed :=
    procedure
    begin
      if FDropPopup = P then
      begin
        FDropPopup := nil;
        if FDropped <> nil then
          FDropped.Invalidate;
        FDropped := nil;
      end;
    end;
  AElement.Invalidate;
  // The drop-down is a child of the toolbar window, so FMX keeps the toolbar while the user works in it.
  if F is TFmrPopupForm then
    FmrPopups.Show(P, ElementScreenRect(AElement), TFmrPopupPlacement.Below, TFmrPopupForm(F), AByKeyboard)
  else
    FmrPopups.Show(P, ElementScreenRect(AElement), TFmrPopupPlacement.Below, nil, AByKeyboard);
end;

procedure TFmrMiniToolbarContent.ElementExecuted(const AElement: TFmrElement);
begin
  FTips.Cancel;
  // Using the toolbar closes the context menu shown with it; the toolbar stays.
  if (FToolbar.FPopupMenu <> nil) and FToolbar.FPopupMenu.IsOpen then
    FToolbar.FPopupMenu.ClosePopup;
end;

function TFmrMiniToolbarContent.IsElementDroppedDown(const AElement: TFmrElement): Boolean;
begin
  Result := (AElement <> nil) and (AElement = FDropped);
end;

function TFmrMiniToolbarContent.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FSize.Width + 2, FSize.Height + 2);
end;

function TFmrMiniToolbarContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  Result := (FToolbar <> nil) and FToolbar.EditorKey(Key, KeyChar, Shift);
end;

procedure TFmrMiniToolbarContent.PopupShown(const AByKeyboard: Boolean);
begin
end;

procedure TFmrMiniToolbarContent.PopupClosed;
begin
  FTips.Cancel;
  if FDropPopup <> nil then
  begin
    FDropPopup.OnClosed := nil;
    FDropPopup := nil;
    FDropped := nil;
  end;
end;

function TFmrMiniToolbarContent.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

function TFmrMiniToolbarContent.ToolbarRect: TRectF;
begin
  Result := RectF(ToolbarMargin, ToolbarMargin, Width - ToolbarMargin, Height - ToolbarMargin);
end;

function TFmrMiniToolbarContent.ToolbarScreenRect: TRectF;
var
  R: TRectF;
  TL, BR: TPointF;
begin
  R := ToolbarRect;
  TL := LocalToScreen(R.TopLeft);
  BR := LocalToScreen(R.BottomRight);
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

procedure TFmrMiniToolbarContent.PaintContent(const ACanvas: TCanvas);
var
  V: TFmrItemView;
  R: TRectF;
begin
  R := ToolbarRect;
  GetPainter.DrawShadow(ACanvas, R, Max(GetPainter.Metrics.MenuRadius, 3), ToolbarMargin - 2);
  GetPainter.DrawMiniToolbar(ACanvas, R);
  for V in FViews do
    if V.Visible then
      V.Paint(ACanvas);
end;

procedure TFmrMiniToolbarContent.Paint;
var
  Op, S: Single;
  Bmp: TBitmap;
  State: TCanvasSaveState;
begin
  // The painter draws opaque; while the toolbar fades it is painted into a bitmap drawn with the opacity (the
  // editor controls fade by themselves with the opacity of the frame).
  Op := AbsoluteOpacity;
  if Op >= 0.99 then
  begin
    State := Canvas.SaveState;
    try
      PaintContent(Canvas);
    finally
      Canvas.RestoreState(State);
    end;
    Exit;
  end;
  S := Canvas.Scale;
  Bmp := TBitmap.Create(Max(1, Ceil(Width * S)), Max(1, Ceil(Height * S)));
  try
    Bmp.BitmapScale := S;
    Bmp.Clear(0);
    if Bmp.Canvas.BeginScene then
    try
      PaintContent(Bmp.Canvas);
    finally
      Bmp.Canvas.EndScene;
    end;
    Canvas.DrawBitmap(Bmp, RectF(0, 0, Bmp.Width, Bmp.Height), LocalRect, Op, False);
  finally
    Bmp.Free;
  end;
end;

procedure TFmrMiniToolbarContent.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  FTracker.MouseMove(PointF(X, Y));
end;

procedure TFmrMiniToolbarContent.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  FTips.Cancel;
  FTracker.MouseDown(Button, PointF(X, Y));
end;

procedure TFmrMiniToolbarContent.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  FTracker.MouseUp(Button, PointF(X, Y));
end;

procedure TFmrMiniToolbarContent.DoMouseLeave;
begin
  inherited;
  FTracker.MouseLeave;
  FTips.Hover(nil, TRectF.Empty, GetPainter, FContext.OwnerForm);
end;

{ TFmrRibbonMiniToolbar }

constructor TFmrRibbonMiniToolbar.Create(AOwner: TComponent);
begin
  inherited;
  FItemLinks := TFmrItemLinks.Create(Self);
  FThemeName := FmrDefaultThemeName;
  FFadeDistance := 120;
  FOpacity := 1;
end;

destructor TFmrRibbonMiniToolbar.Destroy;
begin
  ClosePopup;
  FreeAndNil(FTimer);
  FreeAndNil(FItemLinks);
  FreeAndNil(FPainter);
  FreeAndNil(FTheme);
  inherited;
end;

procedure TFmrRibbonMiniToolbar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FBarManager then
      FBarManager := nil;
    if AComponent = FPopupMenu then
      FPopupMenu := nil;
    if AComponent = FThemeSource then
    begin
      ClosePopup;
      FThemeSource := nil;
    end;
  end;
end;

procedure TFmrRibbonMiniToolbar.SetBarManager(const Value: TFmrBarManager);
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

procedure TFmrRibbonMiniToolbar.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrRibbonMiniToolbar.SetPopupMenu(const Value: TFmrPopupMenu);
begin
  if FPopupMenu <> Value then
  begin
    if FPopupMenu <> nil then
      FPopupMenu.RemoveFreeNotification(Self);
    FPopupMenu := Value;
    if FPopupMenu <> nil then
      FPopupMenu.FreeNotification(Self);
  end;
end;

procedure TFmrRibbonMiniToolbar.SetThemeName(const Value: string);
begin
  if FThemeName <> Value then
  begin
    ClosePopup;
    FThemeName := Value;
    FreeAndNil(FPainter);
    FreeAndNil(FTheme);
  end;
end;

function TFmrRibbonMiniToolbar.IsThemeNameStored: Boolean;
begin
  Result := not SameText(FThemeName, FmrDefaultThemeName);
end;

function TFmrRibbonMiniToolbar.IsFadeDistanceStored: Boolean;
begin
  Result := FFadeDistance <> 120;
end;

procedure TFmrRibbonMiniToolbar.SetThemeSource(const Value: TFmxObject);
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

function TFmrRibbonMiniToolbar.ResolvePainter: TFmrRibbonPainter;
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

function TFmrRibbonMiniToolbar.ResolveImages: TCustomImageList;
var
  Src: IFmrThemeSource;
begin
  Result := nil;
  if FBarManager <> nil then
    Result := FBarManager.Images;
  if (Result = nil) and (FThemeSource <> nil) and Supports(FThemeSource, IFmrThemeSource, Src) then
    Result := Src.GetThemeImages;
end;

procedure TFmrRibbonMiniToolbar.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
var
  V: TFmrItemView;
begin
  if FContent = nil then
    Exit;
  V := FContent.ViewOf(ALink);
  if V <> nil then
  begin
    V.ItemChanged(AChange);
    V.Invalidate;
  end;
end;

procedure TFmrRibbonMiniToolbar.LinkRemoving(const ALink: TFmrItemLink);
begin
  if (FContent <> nil) and (FContent.ViewOf(ALink) <> nil) then
    ClosePopup;
end;

procedure TFmrRibbonMiniToolbar.LinksChanged(const ALinks: TFmrItemLinks);
begin
  ClosePopup;
end;

procedure TFmrRibbonMiniToolbar.SetWindowOpacity(const AValue: Single);
var
  V: Single;
begin
  V := EnsureRange(AValue, 0.05, 1);
  if Abs(V - FOpacity) < 0.01 then
    Exit;
  FOpacity := V;
  if (FContent <> nil) and (FContent.ParentControl <> nil) then
    FContent.ParentControl.Opacity := V;
end;

procedure TFmrRibbonMiniToolbar.Popup(const AScreenPoint: TPointF; const AWithMenu: Boolean);
var
  Ctx: IFmrPopupContext;
  Form: TCommonCustomForm;
  Size: TSizeF;
  R: TRectF;
  W: TFmrPopupForm;
begin
  ClosePopup;
  if (csDesigning in ComponentState) or (FItemLinks.VisibleCount = 0) then
    Exit;
  if Assigned(FOnPopup) then
    FOnPopup(Self);
  Form := FmrFormOf(Self);
  if Form = nil then
    Form := Screen.ActiveForm;
  FWithMenu := AWithMenu and (FPopupMenu <> nil);
  FMenuSeen := False;
  // The context menu first (it closes the other popups of the chain), then the toolbar above it.
  if FWithMenu then
  begin
    if FPopupMenu.ThemeSource = nil then
      FPopupMenu.ThemeSource := FThemeSource;
    FPopupMenu.Popup(AScreenPoint.X, AScreenPoint.Y);
  end
  else
    FmrPopups.CloseAll;
  Ctx := TFmrPopupContext.Create(ResolvePainter, ResolveImages, Form);
  FContent := TFmrMiniToolbarContent.CreateContent(Self, Ctx);
  W := TFmrPopupForm.CreatePopup(Ctx, FContent);
  W.CaptureKeyboard := False;
  W.ShadowSize := 0;
  if Form <> nil then
    W.Parent := Form;
  FWindow := W;
  W.OnClosed :=
    procedure
    begin
      if FWindow = W then
      begin
        FWindow := nil;
        FContent := nil;
        if FTimer <> nil then
          FTimer.Enabled := False;
        if Assigned(FOnCloseUp) then
          FOnCloseUp(Self);
      end;
    end;
  Size := FContent.GetPopupSize;
  R := TFmrPopupManager.PlaceRect(RectF(AScreenPoint.X - 8 - ToolbarMargin, AScreenPoint.Y - 8 + ToolbarMargin,
    AScreenPoint.X - 8 - ToolbarMargin, AScreenPoint.Y - 8 + ToolbarMargin), Size, TFmrPopupPlacement.Above);
  FContent.Align := TAlignLayout.None;
  FContent.SetBounds(W.ShadowSize + 1, W.ShadowSize + 1, R.Width - 2, R.Height - 2);
  W.SetBoundsF(R.Left - W.ShadowSize, R.Top - W.ShadowSize, R.Width + 2 * W.ShadowSize,
    R.Height + 2 * W.ShadowSize + 2);
  FOpacity := 1;
  if not FWithMenu then
    SetWindowOpacity(0.55);
  W.Show;
  if FTimer = nil then
  begin
    FTimer := TTimer.Create(nil);
    FTimer.Interval := 40;
    FTimer.OnTimer := TimerProc;
  end;
  FTimer.Enabled := True;
end;

procedure TFmrRibbonMiniToolbar.TimerProc(Sender: TObject);
var
  Svc: IFMXMouseService;
  P: TPointF;
  R: TRectF;
  DX, DY, D: Single;
begin
  if (FWindow = nil) or (FContent = nil) then
  begin
    FTimer.Enabled := False;
    Exit;
  end;
  // Opaque (and kept) while one of its editors has the focus.
  UpdateKeyboard;
  if FKeyboard then
  begin
    SetWindowOpacity(1);
    Exit;
  end;
  // Opaque while the context menu shown with it or one of its drop-downs is open.
  if FWithMenu and (FPopupMenu <> nil) and FPopupMenu.IsOpen then
  begin
    FMenuSeen := True;
    SetWindowOpacity(1);
    Exit;
  end;
  if FContent.DropPopup <> nil then
  begin
    SetWindowOpacity(1);
    Exit;
  end;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXMouseService, Svc) then
    Exit;
  P := Svc.GetMousePos;
  R := FContent.ToolbarScreenRect;
  DX := Max(0, Max(R.Left - P.X, P.X - R.Right));
  DY := Max(0, Max(R.Top - P.Y, P.Y - R.Bottom));
  D := Sqrt(DX * DX + DY * DY);
  // Fades in as the mouse approaches, out as it goes away; closes beyond FadeDistance.
  if D >= FFadeDistance then
  begin
    ClosePopup;
    Exit;
  end;
  if D <= 6 then
    SetWindowOpacity(1)
  else
    SetWindowOpacity(1 - 0.9 * (D - 6) / Max(1, FFadeDistance - 6));
end;

procedure TFmrRibbonMiniToolbar.UpdateKeyboard;
var
  Want: Boolean;
  Form: TCommonCustomForm;
begin
  Form := nil;
  if (FWindow <> nil) and (FWindow.Context <> nil) then
    Form := FWindow.Context.OwnerForm;
  Want := (FWindow <> nil) and (FContent <> nil) and (FWindow.Focused <> nil) and (FContent.DropPopup = nil) and
    (Form <> nil) and FmrPopupsAssigned and not (csDestroying in ComponentState);
  if Want = FKeyboard then
    Exit;
  FKeyboard := Want;
  if Want then
  begin
    // Working in the toolbar closes the context menu shown with it (it would keep the keys).
    if (FPopupMenu <> nil) and FPopupMenu.IsOpen then
      FPopupMenu.ClosePopup;
    FmrPopups.AddKeyHandler(Form, Self);
  end
  else if FmrPopupsAssigned then
    FmrPopups.RemoveKeyHandler(Self);
end;

procedure TFmrRibbonMiniToolbar.LeaveEditor;
var
  Form: TCommonCustomForm;
begin
  Form := nil;
  if (FWindow <> nil) and (FWindow.Context <> nil) then
    Form := FWindow.Context.OwnerForm;
  if (FWindow <> nil) and (FWindow.Focused <> nil) then
    FWindow.Focused := nil;
  UpdateKeyboard;
  // The toolbar window took the keyboard for the editor (FmrFocusControl): back to the form of the document.
  if (Form <> nil) and not (csDestroying in Form.ComponentState) and Form.Visible then
    Form.Activate;
end;

function TFmrRibbonMiniToolbar.EditorKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  Result := False;
  if (FWindow = nil) or (FWindow.Focused = nil) then
    Exit;
  case Key of
    vkEscape:
      begin
        // Back to the document; the toolbar stays.
        LeaveEditor;
        Result := True;
      end;
    vkReturn, vkTab:
      begin
        // Enter commits the value (the editor's OnChange) and gives the keyboard back, like Office.
        FWindow.KeyDown(Key, KeyChar, Shift);
        LeaveEditor;
        Result := True;
      end;
  end;
end;

function TFmrRibbonMiniToolbar.HandleKey(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
begin
  // Keys of the owner form while the toolbar window does not have the keyboard itself (TFmrPopupForm.KeyDown gives
  // them to the content first: EditorKey).
  Result := (FWindow <> nil) and (FWindow.Focused <> nil);
  if Result then
    FWindow.KeyDown(Key, KeyChar, Shift);
end;

procedure TFmrRibbonMiniToolbar.KeyboardLost;
begin
  // The user clicked into the form: the editor of the toolbar loses the focus.
  FKeyboard := False;
  if (FWindow <> nil) and (FWindow.Focused <> nil) then
    FWindow.Focused := nil;
end;

procedure TFmrRibbonMiniToolbar.ClosePopup;
var
  W: TFmrPopupForm;
begin
  if FKeyboard then
  begin
    FKeyboard := False;
    if FmrPopupsAssigned then
      FmrPopups.RemoveKeyHandler(Self);
  end;
  if FTimer <> nil then
    FTimer.Enabled := False;
  W := FWindow;
  FWindow := nil;
  FContent := nil;
  if (W <> nil) and FmrPopupsAssigned then
  begin
    W.OnClosed := nil;
    FmrPopups.Close(W);
    if Assigned(FOnCloseUp) then
      FOnCloseUp(Self);
  end;
end;

function TFmrRibbonMiniToolbar.IsOpen: Boolean;
begin
  Result := FWindow <> nil;
end;

initialization
  RegisterFmxClasses([TFmrRibbonMiniToolbar]);

end.
