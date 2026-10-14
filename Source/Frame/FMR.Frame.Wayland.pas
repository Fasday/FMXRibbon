{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Form frame: Linux (FMXWayland) implementation        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame.Wayland;

/// The frame on Linux under FMXWayland, a native Wayland backend of FMX (Docs\LINUX.md).
///
/// A Wayland client draws its own title bar unless the compositor offers server-side decorations; FMXWayland draws one
/// (a subsurface above the client area). For the ribbon to own the title bar, as in the FullNC mode on Windows, the
/// platform has to turn its decorations off and start interactive moves and resizes for the program
/// (xdg_toplevel.move/resize need the seat and the serial of the pressing input event, which only the platform
/// knows). This unit declares that contract as an FMX platform service, IFMXWaylandWindowFrame, the way FMXWayland
/// publishes IFMXWaylandNativeWindow: a library declares the same interface (same GUID, same methods in the same order,
/// same signatures) and asks TPlatformServices for it, so neither depends on the other.
///
/// TFmrWaylandFrame is the TFmrFormFrame platform class registered on Linux:
/// - with the service (FullNC or Dwm mode): FMXWayland's decorations are switched off for the form, the host is at the
///   top of the client area, the ribbon draws the caption row with the window buttons and the tab row; a press on empty
///   caption space moves the window, a double click maximizes or restores, a right click (or a click on the icon)
///   shows the compositor's window menu, thin grips at the window edges resize it; the active/maximized state comes
///   from the compositor (listener);
/// - with the service in the NCStrip mode: the platform's title bar stays, the host is below it (ribbon: no title);
/// - without the service (FMXWayland today): the frame does not attach (Hooked = False); the host is an ordinary
///   control at the top of the client area under FMXWayland's own title bar, and the ribbon draws no second title.
/// The unit compiles on every platform (the contract is plain FMX); the class is registered on Linux only.

interface

uses
  System.Types, System.UITypes, System.Classes, System.Messaging, FMX.Types, FMX.Controls, FMX.Forms,
  FMR.Frame.Types, FMR.Frame;

const
  { Edges of IFMXWaylandWindowFrame.BeginResize: the values of xdg_toplevel.resize_edge. }
  FmxwEdgeNone = 0;
  FmxwEdgeTop = 1;
  FmxwEdgeBottom = 2;
  FmxwEdgeLeft = 4;
  FmxwEdgeTopLeft = 5;
  FmxwEdgeBottomLeft = 6;
  FmxwEdgeRight = 8;
  FmxwEdgeTopRight = 9;
  FmxwEdgeBottomRight = 10;

  { Bits of IFMXWaylandWindowFrame.GetStates: 1 shl <xdg_toplevel.state> of the last configure. }
  FmxwStateMaximized = 1 shl 1;
  FmxwStateFullscreen = 1 shl 2;
  FmxwStateResizing = 1 shl 3;
  FmxwStateActivated = 1 shl 4;
  FmxwStateTiledLeft = 1 shl 5;
  FmxwStateTiledRight = 1 shl 6;
  FmxwStateTiledTop = 1 shl 7;
  FmxwStateTiledBottom = 1 shl 8;
  FmxwStateSuspended = 1 shl 9;
  FmxwStateTiled = FmxwStateTiledLeft or FmxwStateTiledRight or FmxwStateTiledTop or FmxwStateTiledBottom;

  { Bits of IFMXWaylandWindowFrame.GetCapabilities: 1 shl <xdg_toplevel.wm_capabilities>; FmxwCapsUnknown when the
    compositor does not send them (xdg_wm_base before version 5: everything may work). }
  FmxwCapWindowMenu = 1 shl 1;
  FmxwCapMaximize = 1 shl 2;
  FmxwCapFullscreen = 1 shl 3;
  FmxwCapMinimize = 1 shl 4;
  FmxwCapsUnknown = Cardinal($FFFFFFFF);

type
  /// <summary>Told by the platform about the window states of a toplevel (IFMXWaylandWindowFrame.SetFrameListener).
  /// </summary>
  IFMXWaylandWindowFrameListener = interface
    ['{785C5760-E413-4153-82DF-E857D1AA70AC}']
    /// <summary>Called on the main thread when an xdg_toplevel.configure changed the states or the capabilities of
    /// the window (once at once from SetFrameListener). AStates: FmxwState* bits; ACapabilities: FmxwCap* bits or
    /// FmxwCapsUnknown.</summary>
    procedure WindowFrameChanged(const AHandle: TWindowHandle; const AStates, ACapabilities: Cardinal);
  end;

  /// <summary>Window frame services of a Wayland FMX platform (FMXWayland) for programs that draw their own title bar.
  /// Registered by the platform as an FMX platform service; ask with
  /// <c>TPlatformServices.Current.SupportsPlatformService(IFMXWaylandWindowFrame, Svc)</c>. Contract: Docs\LINUX.md
  /// (never change this declaration; extensions get a new interface with a new GUID). AHandle is the form's Handle;
  /// methods given a handle that is not a toplevel of the platform do nothing and return False/0. Main thread only.
  /// </summary>
  IFMXWaylandWindowFrame = interface
    ['{547B5786-5639-43A4-A598-1A03B465783A}']
    /// <summary>False: no decorations for the window — neither the platform's client-side title bar and borders nor
    /// server-side ones (zxdg_toplevel_decoration_v1.set_mode(client_side)); the window's surface is all client area
    /// and FMX's window rectangle equals the client rectangle. True (default): the platform's decorations.</summary>
    procedure SetDecorated(const AHandle: TWindowHandle; const AValue: Boolean);
    function GetDecorated(const AHandle: TWindowHandle): Boolean;
    /// <summary>xdg_toplevel.move with the seat and the serial of the latest pointer button press (or touch down) on
    /// the window. Call it while handling that press (MouseDown). False when there is no such press.</summary>
    function BeginMove(const AHandle: TWindowHandle): Boolean;
    /// <summary>xdg_toplevel.resize with the seat, the serial of the latest press and AEdges (FmxwEdge*).</summary>
    function BeginResize(const AHandle: TWindowHandle; const AEdges: Cardinal): Boolean;
    /// <summary>xdg_toplevel.show_window_menu at a point of the client area (dp = surface coordinates) with the seat
    /// and the serial of the latest press. False without a press or without the window_menu capability.</summary>
    function ShowWindowMenu(const AHandle: TWindowHandle; const AClientPoint: TPointF): Boolean;
    /// <summary>xdg_toplevel.set_minimized.</summary>
    procedure Minimize(const AHandle: TWindowHandle);
    /// <summary>xdg_toplevel.set_maximized / unset_maximized (the state follows with the next configure).</summary>
    procedure SetMaximized(const AHandle: TWindowHandle; const AValue: Boolean);
    /// <summary>FmxwState* bits of the last configure.</summary>
    function GetStates(const AHandle: TWindowHandle): Cardinal;
    /// <summary>FmxwCap* bits (xdg_toplevel.wm_capabilities) or FmxwCapsUnknown.</summary>
    function GetCapabilities(const AHandle: TWindowHandle): Cardinal;
    /// <summary>Sets (nil: removes) the listener of the window; the platform keeps a reference until it is replaced or
    /// the window is destroyed, and calls it once right away.</summary>
    procedure SetFrameListener(const AHandle: TWindowHandle; const AListener: IFMXWaylandWindowFrameListener);
  end;

  TFmrWaylandFrame = class;

  /// <summary>Resize grip at an edge or corner of a window without decorations: a press starts an interactive
  /// resize (IFMXWaylandWindowFrame.BeginResize).</summary>
  TFmrWaylandResizeGrip = class(TControl)
  private
    [Unsafe] FPlatform: TFmrWaylandFrame;
    FEdges: Cardinal;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  public
    property Edges: Cardinal read FEdges;
  end;

  /// <summary>Linux part of <c>TFmrFormFrame</c> (see the unit description).</summary>
  TFmrWaylandFrame = class(TFmrFramePlatform)
  private
    FService: IFMXWaylandWindowFrame;
    FListener: IFMXWaylandWindowFrameListener;
    FHandle: TWindowHandle;
    FAttached: Boolean;
    FIntegrated: Boolean;
    FStates: Cardinal;
    FCapabilities: Cardinal;
    FGrips: TArray<TFmrWaylandResizeGrip>;
    FSizeChangedId: TMessageSubscriptionId;
    procedure HostMouseDown(const AArea: TFmrHitArea; const AButton: TMouseButton; const AShift: TShiftState;
      const AScreenPoint: TPointF; var AHandled: Boolean);
    procedure SizeChanged(const Sender: TObject; const AMsg: TMessage);
    procedure CreateGrips;
    procedure FreeGrips;
    procedure PlaceGrips;
    procedure SendState;
  public
    destructor Destroy; override;
    procedure Attach; override;
    procedure Detach; override;
    function IsAttached: Boolean; override;
    procedure FrameChanged; override;
    procedure HostInvalidated(const ARect: TRectF); override;
    procedure Minimize; override;
    procedure ToggleMaximize; override;
    procedure CloseForm; override;
    procedure ShowHelp; override;
    procedure ShowSystemMenu(const AScreenPoint: TPointF); override;
    /// <summary>Called by the platform's listener (and by tests).</summary>
    procedure WindowFrameChanged(const AStates, ACapabilities: Cardinal);
    procedure BeginResize(const AEdges: Cardinal);
    property Service: IFMXWaylandWindowFrame read FService;
    /// <summary>True when the platform's decorations are off and the ribbon draws the title bar.</summary>
    property Integrated: Boolean read FIntegrated;
    property States: Cardinal read FStates;
    property Capabilities: Cardinal read FCapabilities;
  end;

/// <summary>True when the running FMX platform offers IFMXWaylandWindowFrame.</summary>
function FmrWaylandFrameServiceAvailable: Boolean;

implementation

uses
  System.SysUtils, System.Math, FMX.Platform, FMR.Frame.Host;

const
  GripThickness = 5;
  GripCorner = 14;

type
  TFmrWaylandFrameListener = class(TInterfacedObject, IFMXWaylandWindowFrameListener)
  private
    [Unsafe] FPlatform: TFmrWaylandFrame;
  public
    procedure WindowFrameChanged(const AHandle: TWindowHandle; const AStates, ACapabilities: Cardinal);
  end;

function FmrWaylandFrameServiceAvailable: Boolean;
begin
  Result := TPlatformServices.Current.SupportsPlatformService(IFMXWaylandWindowFrame);
end;

{ TFmrWaylandFrameListener }

procedure TFmrWaylandFrameListener.WindowFrameChanged(const AHandle: TWindowHandle; const AStates,
  ACapabilities: Cardinal);
begin
  if (FPlatform <> nil) and (AHandle = FPlatform.FHandle) then
    FPlatform.WindowFrameChanged(AStates, ACapabilities);
end;

{ TFmrWaylandResizeGrip }

procedure TFmrWaylandResizeGrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and (FPlatform <> nil) then
    FPlatform.BeginResize(FEdges);
end;

{ TFmrWaylandFrame }

destructor TFmrWaylandFrame.Destroy;
begin
  Detach;
  inherited;
end;

function TFmrWaylandFrame.IsAttached: Boolean;
begin
  Result := FAttached;
end;

procedure TFmrWaylandFrame.Attach;
var
  Form: TCommonCustomForm;
  Listener: TFmrWaylandFrameListener;
begin
  if FAttached then
    Exit;
  Form := Frame.Form;
  if (Form = nil) or (Frame.Host = nil) or (Form.Handle = nil) or (Form.FormStyle = TFormStyle.Popup) then
    Exit;
  // FMXWayland without the frame service: stay detached, the platform's title bar stays.
  if not TPlatformServices.Current.SupportsPlatformService(IFMXWaylandWindowFrame, FService) then
    Exit;
  FHandle := Form.Handle;
  FStates := FmxwStateActivated;
  FCapabilities := FmxwCapsUnknown;
  FAttached := True;
  Listener := TFmrWaylandFrameListener.Create;
  Listener.FPlatform := Self;
  FListener := Listener;
  FService.SetFrameListener(FHandle, FListener);
  FStates := FService.GetStates(FHandle);
  FCapabilities := FService.GetCapabilities(FHandle);
  Frame.Host.OnFrameMouseDown := HostMouseDown;
  // Presses on the empty host (between the caption controls) must reach it.
  Frame.Host.HitTest := True;
  FSizeChangedId := TMessageManager.DefaultManager.SubscribeToMessage(TSizeChangedMessage, SizeChanged);
  FrameChanged;
end;

procedure TFmrWaylandFrame.Detach;
begin
  if not FAttached then
    Exit;
  FAttached := False;
  if FSizeChangedId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TSizeChangedMessage, FSizeChangedId);
  FSizeChangedId := 0;
  FreeGrips;
  if FListener <> nil then
    TFmrWaylandFrameListener(FListener).FPlatform := nil;
  if FService <> nil then
  begin
    FService.SetFrameListener(FHandle, nil);
    if FIntegrated then
      FService.SetDecorated(FHandle, True);
  end;
  FIntegrated := False;
  FListener := nil;
  FService := nil;
  FHandle := nil;
  if (Frame.Host <> nil) and not (csDestroying in Frame.ComponentState) then
  begin
    Frame.Host.OnFrameMouseDown := nil;
    Frame.Host.HitTest := False;
    if (Frame.Form <> nil) and not (csDestroying in Frame.Form.ComponentState) then
      Frame.PlaceHostInClient(Frame.CaptionHeight);
  end;
end;

procedure TFmrWaylandFrame.FrameChanged;
var
  W, H: Integer;
begin
  if not FAttached then
    Exit;
  // FullNC and Dwm: the ribbon draws the title bar; NCStrip: the platform's title bar stays above the caption content.
  FIntegrated := Frame.Mode <> TFmrFrameMode.NCStrip;
  if TFmxFormState.WasNotShown in Frame.Form.FormState then
  begin
    // Before the first show FMX keeps the bounds the program set (Width/Height in the constructor) and applies them
    // when it shows the window; the platform must not replace them with its own initial size (FMXWayland's
    // windowframe branch reported 640x480 minus its title bar back to FMX here).
    // (Form.Bounds asks the platform; Width and Height are FMX's own values.)
    W := Frame.Form.Width;
    H := Frame.Form.Height;
    FService.SetDecorated(FHandle, not FIntegrated);
    if (Frame.Form.Width <> W) or (Frame.Form.Height <> H) then
    begin
      Frame.Form.Width := W;
      Frame.Form.Height := H;
    end;
  end
  else
    FService.SetDecorated(FHandle, not FIntegrated);
  Frame.PlaceHostInClient(Frame.CaptionHeight);
  if FIntegrated then
    CreateGrips
  else
    FreeGrips;
  PlaceGrips;
  SendState;
end;

procedure TFmrWaylandFrame.HostInvalidated(const ARect: TRectF);
begin
  // The host is an ordinary control of the client area: FMX paints it.
end;

procedure TFmrWaylandFrame.WindowFrameChanged(const AStates, ACapabilities: Cardinal);
begin
  if not FAttached then
    Exit;
  FStates := AStates;
  FCapabilities := ACapabilities;
  PlaceGrips;
  SendState;
end;

procedure TFmrWaylandFrame.SendState;
var
  State: TFmrFrameState;
begin
  State := Frame.State;
  State.Active := (FStates and FmxwStateActivated) <> 0;
  State.Maximized := (FStates and (FmxwStateMaximized or FmxwStateFullscreen)) <> 0;
  State.Minimized := False;
  State.MaximizedTopOffset := 0;
  Frame.UpdateState(State);
end;

procedure TFmrWaylandFrame.HostMouseDown(const AArea: TFmrHitArea; const AButton: TMouseButton;
  const AShift: TShiftState; const AScreenPoint: TPointF; var AHandled: Boolean);
begin
  if not FAttached or not FIntegrated then
    Exit;
  case AButton of
    TMouseButton.mbLeft:
      if AArea = TFmrHitArea.SysMenu then
      begin
        ShowSystemMenu(AScreenPoint);
        AHandled := True;
      end
      else if ssDouble in AShift then
      begin
        if (FCapabilities and FmxwCapMaximize) <> 0 then
          ToggleMaximize;
        AHandled := True;
      end
      else
        // True at once; the platform starts the move only when the pointer is dragged past a few pixels (FMXWayland:
        // 4 px, as GTK), so a click stays a click and the second press of a double click comes back with ssDouble.
        AHandled := FService.BeginMove(FHandle);
    TMouseButton.mbRight:
      begin
        ShowSystemMenu(AScreenPoint);
        AHandled := True;
      end;
  end;
end;

procedure TFmrWaylandFrame.BeginResize(const AEdges: Cardinal);
begin
  if FAttached and FIntegrated then
    FService.BeginResize(FHandle, AEdges);
end;

procedure TFmrWaylandFrame.Minimize;
begin
  if FAttached then
    FService.Minimize(FHandle);
end;

procedure TFmrWaylandFrame.ToggleMaximize;
begin
  if FAttached then
    FService.SetMaximized(FHandle, (FStates and FmxwStateMaximized) = 0);
end;

procedure TFmrWaylandFrame.CloseForm;
begin
  if Frame.Form <> nil then
    Frame.Form.Close;
end;

procedure TFmrWaylandFrame.ShowHelp;
begin
  // No context help mode on Wayland.
end;

procedure TFmrWaylandFrame.ShowSystemMenu(const AScreenPoint: TPointF);
begin
  if FAttached and (Frame.Form <> nil) and ((FCapabilities and FmxwCapWindowMenu) <> 0) then
    FService.ShowWindowMenu(FHandle, Frame.Form.ScreenToClient(AScreenPoint));
end;

procedure TFmrWaylandFrame.CreateGrips;
const
  AllEdges: array [0..7] of Cardinal = (FmxwEdgeTop, FmxwEdgeBottom, FmxwEdgeLeft, FmxwEdgeRight, FmxwEdgeTopLeft,
    FmxwEdgeTopRight, FmxwEdgeBottomLeft, FmxwEdgeBottomRight);
var
  I: Integer;
  G: TFmrWaylandResizeGrip;
begin
  if (Length(FGrips) > 0) or (Frame.Form = nil) or
    not (Frame.Form.BorderStyle in [TFmxFormBorderStyle.Sizeable, TFmxFormBorderStyle.SizeToolWin]) then
    Exit;
  SetLength(FGrips, Length(AllEdges));
  for I := 0 to High(AllEdges) do
  begin
    G := TFmrWaylandResizeGrip.Create(nil);
    G.FPlatform := Self;
    G.FEdges := AllEdges[I];
    G.Stored := False;
    G.Locked := True;
    G.HitTest := True;
    case AllEdges[I] of
      FmxwEdgeTop, FmxwEdgeBottom: G.Cursor := crSizeNS;
      FmxwEdgeLeft, FmxwEdgeRight: G.Cursor := crSizeWE;
      FmxwEdgeTopLeft, FmxwEdgeBottomRight: G.Cursor := crSizeNWSE;
    else
      G.Cursor := crSizeNESW;
    end;
    G.Parent := Frame.Form;
    FGrips[I] := G;
  end;
end;

procedure TFmrWaylandFrame.FreeGrips;
var
  G: TFmrWaylandResizeGrip;
begin
  for G in FGrips do
  begin
    G.FPlatform := nil;
    G.Free;
  end;
  FGrips := nil;
end;

procedure TFmrWaylandFrame.PlaceGrips;
var
  G: TFmrWaylandResizeGrip;
  W, H: Single;
  Show: Boolean;
begin
  if (Length(FGrips) = 0) or (Frame.Form = nil) then
    Exit;
  W := Frame.Form.ClientWidth;
  H := Frame.Form.ClientHeight;
  // No resizing of a maximized, full screen or tiled window.
  Show := FIntegrated and ((FStates and (FmxwStateMaximized or FmxwStateFullscreen or FmxwStateTiled)) = 0);
  for G in FGrips do
  begin
    G.Visible := Show;
    if not Show then
      Continue;
    case G.Edges of
      FmxwEdgeTop: G.SetBounds(GripCorner, 0, W - 2 * GripCorner, GripThickness);
      FmxwEdgeBottom: G.SetBounds(GripCorner, H - GripThickness, W - 2 * GripCorner, GripThickness);
      FmxwEdgeLeft: G.SetBounds(0, GripCorner, GripThickness, H - 2 * GripCorner);
      FmxwEdgeRight: G.SetBounds(W - GripThickness, GripCorner, GripThickness, H - 2 * GripCorner);
      FmxwEdgeTopLeft: G.SetBounds(0, 0, GripCorner, GripThickness);
      FmxwEdgeTopRight: G.SetBounds(W - GripCorner, 0, GripCorner, GripThickness);
      FmxwEdgeBottomLeft: G.SetBounds(0, H - GripThickness, GripCorner, GripThickness);
      FmxwEdgeBottomRight: G.SetBounds(W - GripCorner, H - GripThickness, GripCorner, GripThickness);
    end;
    // Above every control of the form (hit tests look at the last child first).
    G.BringToFront;
  end;
end;

procedure TFmrWaylandFrame.SizeChanged(const Sender: TObject; const AMsg: TMessage);
begin
  if FAttached and (Sender = Frame.Form) then
    PlaceGrips;
end;

initialization
  {$IFDEF LINUX}
  if FmrFramePlatformClass = nil then
    FmrFramePlatformClass := TFmrWaylandFrame;
  {$ENDIF}

end.
