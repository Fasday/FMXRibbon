{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Form frame: caption content in the title bar area    }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame;

interface

uses
  System.Types, System.UITypes, System.Classes, System.Messaging, FMX.Types, FMX.Controls, FMX.Forms,
  FMR.Frame.Types, FMR.Frame.Host;

const
  /// <summary>Default height (dp) of the caption content.</summary>
  FmrDefaultCaptionHeight = 32;

type
  TFmrFormFrame = class;

  /// <summary>Platform part of a frame (Windows: <c>FMR.Frame.Win</c>). A platform unit registers its class in
  /// <see cref="FmrFramePlatformClass"/>; without one the frame does nothing and the host stays an ordinary control
  /// at the top of the client area.</summary>
  TFmrFramePlatform = class abstract
  private
    FFrame: TFmrFormFrame;
  public
    constructor Create(const AFrame: TFmrFormFrame); virtual;
    /// <summary>Hooks the window of the frame's form (the handle exists).</summary>
    procedure Attach; virtual; abstract;
    /// <summary>Unhooks the window (before the handle is destroyed or when the frame is disabled).</summary>
    procedure Detach; virtual; abstract;
    function IsAttached: Boolean; virtual; abstract;
    /// <summary>Mode, CaptionHeight, Backdrop, DarkMode or colors changed: recalculate the frame.</summary>
    procedure FrameChanged; virtual; abstract;
    /// <summary>The host needs repainting (non-client modes). ARect: host scene coordinates.</summary>
    procedure HostInvalidated(const ARect: TRectF); virtual; abstract;
    procedure Minimize; virtual; abstract;
    procedure ToggleMaximize; virtual; abstract;
    procedure CloseForm; virtual; abstract;
    procedure ShowHelp; virtual; abstract;
    procedure ShowSystemMenu(const AScreenPoint: TPointF); virtual; abstract;
    property Frame: TFmrFormFrame read FFrame;
  end;

  TFmrFramePlatformClass = class of TFmrFramePlatform;

  /// <summary>Puts caption content (title, caption buttons, the ribbon's caption row and tab row) into the title bar
  /// area of its owner form. Drop it on a form or use <c>TFmrForm</c>.</summary>
  /// <remarks>
  /// <para><b>FullNC</b> (default): the caption content is the real non-client area: <c>GetClientRect</c> starts
  /// below it; it is painted into a bitmap and copied to the window DC in <c>WM_NCPAINT</c>.</para>
  /// <para><b>NCStrip</b>: the system title bar stays; the caption content is a real non-client strip below it.</para>
  /// <para><b>Dwm</b>: the top non-client area is removed; the caption content is an ordinary control at the top of
  /// the client area over the DWM frame (optional Mica/Acrylic, see <see cref="Backdrop"/>).</para>
  /// <para>The mode can be switched at run time. At design time nothing is hooked and the host is shown at the top of
  /// the client area. On platforms without a frame implementation the host stays at the top of the client area.</para>
  /// </remarks>
  TFmrFormFrame = class(TComponent, IFmrFrameCommands)
  private
    FForm: TCommonCustomForm;
    FHost: TFmrFrameHost;
    FPlatform: TFmrFramePlatform;
    FMode: TFmrFrameMode;
    FCaptionHeight: Single;
    FBackdrop: TFmrFrameBackdrop;
    FDarkMode: Boolean;
    FCaptionColor: TAlphaColor;
    FCaptionInactiveColor: TAlphaColor;
    FEnabled: Boolean;
    FState: TFmrFrameState;
    FAfterCreateHandleId: TMessageSubscriptionId;
    FBeforeDestroyHandleId: TMessageSubscriptionId;
    FBeforeShownId: TMessageSubscriptionId;
    FOnStateChanged: TNotifyEvent;
    procedure AfterCreateFormHandle(const Sender: TObject; const AMsg: TMessage);
    procedure BeforeDestroyFormHandle(const Sender: TObject; const AMsg: TMessage);
    procedure FormBeforeShown(const Sender: TObject; const AMsg: TMessage);
    procedure HostInvalidate(const ARect: TRectF);
    procedure SetMode(const Value: TFmrFrameMode);
    procedure SetCaptionHeight(const Value: Single);
    function IsCaptionHeightStored: Boolean;
    procedure SetBackdrop(const Value: TFmrFrameBackdrop);
    procedure SetDarkMode(const Value: Boolean);
    procedure SetCaptionColor(const Value: TAlphaColor);
    procedure SetCaptionInactiveColor(const Value: TAlphaColor);
    procedure SetEnabled(const Value: Boolean);
    function GetHooked: Boolean;
    function CanHook: Boolean;
    procedure Hook;
    procedure Unhook;
    procedure Changed;
    procedure RealignForm;
    function FindOwnerForm: TCommonCustomForm;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    { IFmrFrameCommands }
    /// <summary>Minimizes the form (with the system animation when the frame is hooked).</summary>
    procedure Minimize;
    /// <summary>Maximizes or restores the form.</summary>
    procedure ToggleMaximize;
    /// <summary>Closes the form (<c>WM_CLOSE</c>, so OnCloseQuery runs).</summary>
    procedure CloseForm;
    /// <summary>Enters the system context-help mode (Help caption button).</summary>
    procedure ShowHelp;
    /// <summary>Shows the system (window) menu at AScreenPoint (FMX screen coordinates, dp).</summary>
    procedure ShowSystemMenu(const AScreenPoint: TPointF);
    /// <summary>For platform implementations: stores the state, updates the host's controls
    /// (<c>IFmrFrameStateAware</c>), sends <c>TFmrFrameStateMessage</c> and calls OnStateChanged.</summary>
    procedure UpdateState(const AState: TFmrFrameState);
    /// <summary>For platform implementations: the host as an ordinary control at the top of the client area.</summary>
    procedure PlaceHostInClient(const AHeight: Single);
    /// <summary>For platform implementations: the host above the client area (AHeight dp of real non-client area
    /// directly above the client area), scene of its children.</summary>
    procedure PlaceHostInNonClient(const AWidth, AHeight: Single);
    /// <summary>For platform implementations: background colors of the host for the current state.</summary>
    procedure ApplyHostColors;
    /// <summary>The caption is transparent in the current mode (a backdrop is used and supported).</summary>
    function IsCaptionTransparent: Boolean;
    /// <summary>The form the frame works on (the first <c>TCommonCustomForm</c> among its owners).</summary>
    property Form: TCommonCustomForm read FForm;
    /// <summary>Container of the caption content. Put the caption controls into it (Align = Top/Left/Right/Client).</summary>
    property Host: TFmrFrameHost read FHost;
    /// <summary>State of the window (active, maximized, mode...).</summary>
    property State: TFmrFrameState read FState;
    /// <summary>True when the window is hooked by a platform implementation. The window is hooked synchronously as
    /// soon as it exists (in the constructor or Loaded of the frame, when the form's handle is created), so Hooked is
    /// already True before the form is shown; every change (attach, detach when the handle is recreated or the frame
    /// is disabled) sends a <c>TFmrFrameStateMessage</c> whose <c>State.Hooked</c> tells the new value.</summary>
    property Hooked: Boolean read GetHooked;
    property PlatformFrame: TFmrFramePlatform read FPlatform;
  published
    /// <summary>How the top of the form is made. Can be changed at run time.</summary>
    property Mode: TFmrFrameMode read FMode write SetMode default TFmrFrameMode.FullNC;
    /// <summary>Height (dp) of the caption content (the host). In FullNC and NCStrip this is the height of the real
    /// non-client strip; the ribbon puts its caption row and tab row there.</summary>
    property CaptionHeight: Single read FCaptionHeight write SetCaptionHeight stored IsCaptionHeightStored;
    /// <summary>System backdrop (Windows 11 22H2+) used in the Dwm mode: the caption and every transparent part of the
    /// client area show the material (the frame makes the form's fill transparent while it is on).</summary>
    property Backdrop: TFmrFrameBackdrop read FBackdrop write SetBackdrop default TFmrFrameBackdrop.None;
    /// <summary>Dark frame: DWM dark mode of the border and default dark colors of the caption.</summary>
    property DarkMode: Boolean read FDarkMode write SetDarkMode default False;
    /// <summary>Background of the caption (TAlphaColors.Null: default of the light/dark mode).</summary>
    property CaptionColor: TAlphaColor read FCaptionColor write SetCaptionColor default TAlphaColors.Null;
    /// <summary>Background of the caption of an inactive window (TAlphaColors.Null: as active).</summary>
    property CaptionInactiveColor: TAlphaColor read FCaptionInactiveColor write SetCaptionInactiveColor
      default TAlphaColors.Null;
    /// <summary>False: the window keeps its standard frame and the host is an ordinary top control.</summary>
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    /// <summary>The window state changed (active, maximized, minimized, mode, hooked).</summary>
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
  end;

var
  /// <summary>Platform implementation used by new frames (set by <c>FMR.Frame.Win</c>).</summary>
  FmrFramePlatformClass: TFmrFramePlatformClass = nil;

implementation

uses
  System.SysUtils, System.Math
  {$IFDEF MSWINDOWS}, FMR.Frame.Win{$ENDIF};

const
  DefaultLightCaption = $FFF3F3F3;
  DefaultDarkCaption = $FF202020;

{ TFmrFramePlatform }

constructor TFmrFramePlatform.Create(const AFrame: TFmrFormFrame);
begin
  inherited Create;
  FFrame := AFrame;
end;

{ TFmrFormFrame }

constructor TFmrFormFrame.Create(AOwner: TComponent);
begin
  inherited;
  FMode := TFmrFrameMode.FullNC;
  FCaptionHeight := FmrDefaultCaptionHeight;
  FCaptionColor := TAlphaColors.Null;
  FCaptionInactiveColor := TAlphaColors.Null;
  FEnabled := True;
  FState.Active := True;
  FState.Mode := FMode;
  FForm := FindOwnerForm;
  if FForm <> nil then
  begin
    FHost := TFmrFrameHost.Create(Self);
    FHost.Stored := False;
    FHost.FreeNotification(Self);
    FHost.Commands := Self;
    FHost.OnInvalidate := HostInvalidate;
    if csDesigning in ComponentState then
      FHost.Locked := True;
    FHost.Parent := FForm;
    PlaceHostInClient(FCaptionHeight);
    ApplyHostColors;
    FHost.UpdateState(FState);
    if not (csDesigning in ComponentState) then
    begin
      FAfterCreateHandleId := TMessageManager.DefaultManager.SubscribeToMessage(TAfterCreateFormHandle,
        AfterCreateFormHandle);
      FBeforeDestroyHandleId := TMessageManager.DefaultManager.SubscribeToMessage(TBeforeDestroyFormHandle,
        BeforeDestroyFormHandle);
      FBeforeShownId := TMessageManager.DefaultManager.SubscribeToMessage(TFormBeforeShownMessage, FormBeforeShown);
      // Hooked synchronously as soon as the window exists: now (frame created in code, TFmrForm), in Loaded (frame read
      // from a form resource) or when the handle is created; Hooked is reliable from then on and every change of it is
      // announced with TFmrFrameStateMessage.
      if not (csLoading in ComponentState) then
        Hook;
    end;
  end;
end;

destructor TFmrFormFrame.Destroy;
begin
  if FAfterCreateHandleId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TAfterCreateFormHandle, FAfterCreateHandleId);
  if FBeforeDestroyHandleId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TBeforeDestroyFormHandle, FBeforeDestroyHandleId);
  if FBeforeShownId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TFormBeforeShownMessage, FBeforeShownId);
  Unhook;
  FreeAndNil(FPlatform);
  if FHost <> nil then
  begin
    FHost.OnInvalidate := nil;
    FHost.Commands := nil;
    FHost.RemoveFreeNotification(Self);
    if not (csDestroying in FHost.ComponentState) then
      FreeAndNil(FHost);
  end;
  inherited;
end;

function TFmrFormFrame.FindOwnerForm: TCommonCustomForm;
var
  C: TComponent;
begin
  C := Owner;
  while (C <> nil) and not (C is TCommonCustomForm) do
    C := C.Owner;
  Result := TCommonCustomForm(C);
end;

procedure TFmrFormFrame.Assign(Source: TPersistent);
var
  Src: TFmrFormFrame;
begin
  if Source is TFmrFormFrame then
  begin
    Src := TFmrFormFrame(Source);
    FMode := Src.Mode;
    FCaptionHeight := Src.CaptionHeight;
    FBackdrop := Src.Backdrop;
    FDarkMode := Src.DarkMode;
    FCaptionColor := Src.CaptionColor;
    FCaptionInactiveColor := Src.CaptionInactiveColor;
    Enabled := Src.Enabled;
    Changed;
  end
  else
    inherited;
end;

procedure TFmrFormFrame.Loaded;
begin
  inherited;
  if FHost <> nil then
  begin
    ApplyHostColors;
    if not Hooked then
      PlaceHostInClient(FCaptionHeight);
  end;
  if not (csDesigning in ComponentState) then
    Hook;
end;

procedure TFmrFormFrame.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FHost) then
  begin
    Unhook;
    FHost := nil;
  end;
end;

function TFmrFormFrame.CanHook: Boolean;
begin
  // A transparent (layered) form has no non-client area.
  Result := FEnabled and (FForm <> nil) and (FHost <> nil) and (FmrFramePlatformClass <> nil) and
    ([csDesigning, csDestroying, csLoading] * ComponentState = []) and
    not (csDestroying in FForm.ComponentState) and FForm.IsHandleAllocated and not FForm.Transparency;
end;

procedure TFmrFormFrame.Hook;
begin
  if not CanHook then
    Exit;
  if FPlatform = nil then
    FPlatform := FmrFramePlatformClass.Create(Self);
  if not FPlatform.IsAttached then
  begin
    FPlatform.Attach;
    // Attach sends the state of the attached frame already; this covers a platform that did not attach.
    if not FPlatform.IsAttached then
      UpdateState(FState);
  end;
end;

procedure TFmrFormFrame.Unhook;
begin
  if (FPlatform <> nil) and FPlatform.IsAttached then
  begin
    FPlatform.Detach;
    if not (csDestroying in ComponentState) and ((FForm = nil) or not (csDestroying in FForm.ComponentState)) then
      UpdateState(FState);
  end;
end;

function TFmrFormFrame.GetHooked: Boolean;
begin
  Result := (FPlatform <> nil) and FPlatform.IsAttached;
end;

procedure TFmrFormFrame.AfterCreateFormHandle(const Sender: TObject; const AMsg: TMessage);
begin
  // A recreated handle (BorderStyle, FormStyle changed...) is hooked at once, before anybody paints it.
  if (AMsg is TAfterCreateFormHandle) and (TAfterCreateFormHandle(AMsg).Value = FForm) then
    Hook;
end;

procedure TFmrFormFrame.FormBeforeShown(const Sender: TObject; const AMsg: TMessage);
begin
  // Normally hooked long before; this catches a frame that could not hook earlier (Enabled set to True while the form
  // was loading...).
  if (AMsg is TFormBeforeShownMessage) and (TFormBeforeShownMessage(AMsg).Value = FForm) then
    Hook;
end;

procedure TFmrFormFrame.BeforeDestroyFormHandle(const Sender: TObject; const AMsg: TMessage);
begin
  if (AMsg is TBeforeDestroyFormHandle) and (TBeforeDestroyFormHandle(AMsg).Value = FForm) then
    Unhook;
end;

procedure TFmrFormFrame.HostInvalidate(const ARect: TRectF);
begin
  if Hooked then
    FPlatform.HostInvalidated(ARect);
end;

procedure TFmrFormFrame.Changed;
begin
  FState.Mode := FMode;
  FState.DarkMode := FDarkMode;
  FState.Transparent := IsCaptionTransparent;
  if FHost = nil then
    Exit;
  ApplyHostColors;
  if Hooked then
    FPlatform.FrameChanged
  else
    PlaceHostInClient(FCaptionHeight);
  UpdateState(FState);
end;

procedure TFmrFormFrame.SetMode(const Value: TFmrFrameMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
    Changed;
  end;
end;

procedure TFmrFormFrame.SetCaptionHeight(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(0, Value);
  if not SameValue(FCaptionHeight, NewValue, 0.01) then
  begin
    FCaptionHeight := NewValue;
    Changed;
  end;
end;

function TFmrFormFrame.IsCaptionHeightStored: Boolean;
begin
  Result := not SameValue(FCaptionHeight, FmrDefaultCaptionHeight, 0.01);
end;

procedure TFmrFormFrame.SetBackdrop(const Value: TFmrFrameBackdrop);
begin
  if FBackdrop <> Value then
  begin
    FBackdrop := Value;
    Changed;
  end;
end;

procedure TFmrFormFrame.SetDarkMode(const Value: Boolean);
begin
  if FDarkMode <> Value then
  begin
    FDarkMode := Value;
    Changed;
  end;
end;

procedure TFmrFormFrame.SetCaptionColor(const Value: TAlphaColor);
begin
  if FCaptionColor <> Value then
  begin
    FCaptionColor := Value;
    Changed;
  end;
end;

procedure TFmrFormFrame.SetCaptionInactiveColor(const Value: TAlphaColor);
begin
  if FCaptionInactiveColor <> Value then
  begin
    FCaptionInactiveColor := Value;
    Changed;
  end;
end;

procedure TFmrFormFrame.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    if FEnabled then
      Hook
    else
    begin
      Unhook;
      if FHost <> nil then
        PlaceHostInClient(FCaptionHeight);
    end;
  end;
end;

function TFmrFormFrame.IsCaptionTransparent: Boolean;
begin
  Result := (FMode = TFmrFrameMode.Dwm) and (FBackdrop <> TFmrFrameBackdrop.None) and Hooked;
end;

procedure TFmrFormFrame.ApplyHostColors;
var
  Active, Inactive: TAlphaColor;
begin
  if FHost = nil then
    Exit;
  if IsCaptionTransparent then
  begin
    Active := TAlphaColors.Null;
    Inactive := TAlphaColors.Null;
  end
  else
  begin
    Active := FCaptionColor;
    if Active = TAlphaColors.Null then
    begin
      if FDarkMode then
        Active := DefaultDarkCaption
      else
        Active := DefaultLightCaption;
    end;
    Inactive := FCaptionInactiveColor;
  end;
  FHost.FillColor := Active;
  FHost.InactiveFillColor := Inactive;
end;

procedure TFmrFormFrame.PlaceHostInClient(const AHeight: Single);
var
  Focused: IControl;
  FocusedObj: TFmxObject;
  NeedRealign: Boolean;
begin
  if FHost = nil then
    Exit;
  Focused := nil;
  if (FForm <> nil) and FHost.OwnScene then
  begin
    Focused := FForm.Focused;
    if (Focused <> nil) and (FmrFindFrameHost(Focused.GetObject) <> FHost) then
      Focused := nil;
  end;
  NeedRealign := FHost.OwnScene or (FHost.Align <> TAlignLayout.MostTop) or not SameValue(FHost.Height, AHeight, 0.01) or
    (FHost.Visible <> (AHeight > 0));
  FHost.SetOwnScene(False);
  FHost.Align := TAlignLayout.MostTop;
  FHost.Height := AHeight;
  FHost.Visible := AHeight > 0;
  if NeedRealign then
    RealignForm;
  if Focused <> nil then
  begin
    FocusedObj := Focused.GetObject;
    FForm.Focused := nil;
    if FocusedObj is TControl then
      TControl(FocusedObj).SetFocus;
  end;
end;

procedure TFmrFormFrame.PlaceHostInNonClient(const AWidth, AHeight: Single);
var
  Focused: IControl;
  FocusedObj: TFmxObject;
  WasAligned: Boolean;
begin
  if FHost = nil then
    Exit;
  Focused := nil;
  if (FForm <> nil) and not FHost.OwnScene then
  begin
    Focused := FForm.Focused;
    if (Focused <> nil) and (FmrFindFrameHost(Focused.GetObject) <> FHost) then
      Focused := nil;
  end;
  WasAligned := FHost.Align <> TAlignLayout.None;
  FHost.Align := TAlignLayout.None;
  FHost.Visible := True;
  FHost.SetBounds(0, -AHeight, AWidth, AHeight);
  FHost.SetOwnScene(True);
  // The client controls were aligned below the host while it was in the client area.
  if WasAligned then
    RealignForm;
  if Focused <> nil then
  begin
    FocusedObj := Focused.GetObject;
    FForm.Focused := nil;
    if FocusedObj is TControl then
      TControl(FocusedObj).SetFocus;
  end;
end;

procedure TFmrFormFrame.RealignForm;
var
  AlignRoot: IAlignRoot;
begin
  if (FForm <> nil) and not (csDestroying in FForm.ComponentState) and Supports(FForm, IAlignRoot, AlignRoot) then
    AlignRoot.Realign;
end;

procedure TFmrFormFrame.UpdateState(const AState: TFmrFrameState);
begin
  FState := AState;
  FState.Hooked := Hooked;
  FState.Mode := FMode;
  FState.DarkMode := FDarkMode;
  FState.Transparent := IsCaptionTransparent;
  if FHost <> nil then
  begin
    FHost.UpdateState(FState);
    TMessageManager.DefaultManager.SendMessage(Self, TFmrFrameStateMessage.Create(FHost, FState), True);
  end;
  if Assigned(FOnStateChanged) and not (csDestroying in ComponentState) then
    FOnStateChanged(Self);
end;

procedure TFmrFormFrame.Minimize;
begin
  if Hooked then
    FPlatform.Minimize
  else if FForm <> nil then
    FForm.WindowState := TWindowState.wsMinimized;
end;

procedure TFmrFormFrame.ToggleMaximize;
begin
  if Hooked then
    FPlatform.ToggleMaximize
  else if FForm <> nil then
  begin
    if FForm.WindowState = TWindowState.wsMaximized then
      FForm.WindowState := TWindowState.wsNormal
    else
      FForm.WindowState := TWindowState.wsMaximized;
  end;
end;

procedure TFmrFormFrame.CloseForm;
begin
  if Hooked then
    FPlatform.CloseForm
  else if FForm <> nil then
    FForm.Close;
end;

procedure TFmrFormFrame.ShowHelp;
begin
  if Hooked then
    FPlatform.ShowHelp;
end;

procedure TFmrFormFrame.ShowSystemMenu(const AScreenPoint: TPointF);
begin
  if Hooked then
    FPlatform.ShowSystemMenu(AScreenPoint);
end;

end.
