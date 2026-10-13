{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Frame host: container of the caption content         }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame.Host;

interface

uses
  System.Types, System.UITypes, System.SysUtils, System.Classes, System.Messaging, FMX.Types, FMX.Controls,
  FMX.Graphics, FMX.Forms, FMR.Frame.Types;

type
  /// <summary>Called by a frame host whose caption content needs repainting while it lives in the non-client area.
  /// ARect: the dirty rectangle in the coordinates of the host's scene (client coordinates of the form, dp; the
  /// non-client area above the client area has negative Y).</summary>
  TFmrFrameHostInvalidateEvent = procedure(const ARect: TRectF) of object;

  /// <summary>Container of the caption content of a form (title, caption buttons, the ribbon's caption row and tab
  /// row). Created and placed by <c>TFmrFormFrame</c>.</summary>
  /// <remarks>
  /// <para>In the Dwm mode (and wherever the frame is not hooked: design time, other platforms) the host is an ordinary
  /// control aligned to the top of the client area; its children use the form's scene.</para>
  /// <para>In the FullNC and NCStrip modes the host lies above the client area (negative Y, inside the real
  /// non-client area) and is the <c>IScene</c> of its children, as <c>TCustomLayer3D</c> is for 2D controls on a 3D
  /// form: the children's <c>Root</c> stays the form, so focus, keyboard, IME, hints, actions and the StyleBook work
  /// unchanged; painting goes into <see cref="Buffer"/> (<see cref="PaintBuffer"/>), which the platform frame copies
  /// to the window DC, and invalidation goes through <see cref="OnInvalidate"/>. Absolute coordinates of the children
  /// stay client coordinates of the form, so all FMX conversions (popups, IME, hit tests) work.</para>
  /// <para>Limitation of the non-client modes: the buffer is painted with <c>TCanvas.Offset</c>, which FMX applies
  /// before the control's matrix; children must not be rotated or scaled.</para>
  /// </remarks>
  TFmrFrameHost = class(TControl, IStyleBookOwner, IScene)
  private
    FOwnScene: Boolean;
    FBuffer: TBitmap;
    FPaintingBuffer: Boolean;
    FInvalidatedWhilePainting: Boolean;
    FDisableUpdating: Integer;
    FDirtyRect: TRectF;
    FOnInvalidate: TFmrFrameHostInvalidateEvent;
    FFillColor: TAlphaColor;
    FInactiveFillColor: TAlphaColor;
    FState: TFmrFrameState;
    [Unsafe] FCommands: IFmrFrameCommands;
    FStyleChangedId: TMessageSubscriptionId;
    FFormCreatedId: TMessageSubscriptionId;
    procedure StyleChangedHandler(const Sender: TObject; const AMsg: TMessage);
    procedure FormHandleCreatedHandler(const Sender: TObject; const AMsg: TMessage);
    function GetForm: TCommonCustomForm;
    function GetFormScene: IScene;
    procedure SetFillColor(const Value: TAlphaColor);
    procedure SetInactiveFillColor(const Value: TAlphaColor);
    procedure EnsureBuffer(const AWidth, AHeight: Integer; const AScale: Single);
    function GetCurrentFillColor: TAlphaColor;
    procedure NotifyState(const AControl: TControl);
  protected
    { IScene }
    procedure AddUpdateRect(const R: TRectF);
    function GetUpdateRectsCount: Integer;
    function GetUpdateRect(const Index: Integer): TRectF;
    function GetSceneObject: TFmxObject;
    function GetSceneCanvas: TCanvas;
    function GetSceneScale: Single;
    function SceneLocalToScreen(const AScenePoint: TPointF): TPointF;
    function SceneScreenToLocal(const AScreenPoint: TPointF): TPointF;
    procedure ChangeScrollingState(const AControl: TControl; const AActive: Boolean);
    procedure DisableUpdating;
    procedure EnableUpdating;
    function IScene.GetObject = GetSceneObject;
    function IScene.GetCanvas = GetSceneCanvas;
    function IScene.LocalToScreen = SceneLocalToScreen;
    function IScene.ScreenToLocal = SceneScreenToLocal;
    { IStyleBookOwner }
    function GetStyleBook: TStyleBook;
    procedure SetStyleBook(const Value: TStyleBook);
    { TControl }
    procedure DoAddObject(const AObject: TFmxObject); override;
    procedure Paint; override;
    procedure PaintChildren; override;
    function GetDefaultSize: TSizeF; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetNewScene(AScene: IScene); override;
    /// <summary>Makes the host the scene of its children (True: non-client modes) or gives them the form's scene
    /// (False).</summary>
    procedure SetOwnScene(const AValue: Boolean);
    /// <summary>Paints the host and its children into <see cref="Buffer"/> of AWidth x AHeight pixels at AScale and
    /// returns it. Used by the platform frame in the non-client modes.</summary>
    function PaintBuffer(const AWidth, AHeight: Integer; const AScale: Single): TBitmap;
    /// <summary>Marks the whole host dirty (non-client modes) or repaints it (Dwm mode).</summary>
    procedure InvalidateHost;
    /// <summary>Stores the window state and passes it to every <c>IFmrFrameStateAware</c> control of the host.</summary>
    procedure UpdateState(const AState: TFmrFrameState);
    /// <summary>What the window manager should do at a point of the host. AScreenPoint: FMX screen coordinates (dp).
    /// Asks the deepest control under the point and its parents (<c>IFmrFrameHitTest</c>); default: the host itself
    /// or a control with HitTest = False is Caption, any other control is Client.</summary>
    function FrameHitTest(const AScreenPoint: TPointF): TFmrHitArea;
    /// <summary>The first caption button of the host of the given kind (MinButton, MaxButton, CloseButton,
    /// HelpButton) or nil.</summary>
    function FindFrameButton(const AKind: TFmrHitArea): IFmrFrameButton;
    /// <summary>Calls AProc for every control of the host (depth first).</summary>
    procedure ForEachControl(const AProc: TProc<TControl>);
    /// <summary>Prepares the popups of the caption content for the non-client area: FMX refuses to show (and closes) a
    /// popup whose placement target lies outside the form's client rectangle
    /// (<c>TPopup.HideWhenPlacementTargetInvisible</c>), which every control in the non-client area does. Called when
    /// the host gets its own scene and when a control is added; popups attached later (pickers of a TComboBox, date
    /// pickers) are caught when their popup form is created.</summary>
    procedure PreparePopups;
    /// <summary>Background color of the caption when the window is active (TAlphaColors.Null: transparent).</summary>
    property FillColor: TAlphaColor read FFillColor write SetFillColor;
    /// <summary>Background color of the caption when the window is inactive (TAlphaColors.Null: as
    /// <see cref="FillColor"/>).</summary>
    property InactiveFillColor: TAlphaColor read FInactiveFillColor write SetInactiveFillColor;
    /// <summary>True in the non-client modes: the host is the scene of its children.</summary>
    property OwnScene: Boolean read FOwnScene;
    /// <summary>The bitmap painted by <see cref="PaintBuffer"/> (nil before the first non-client paint).</summary>
    property Buffer: TBitmap read FBuffer;
    /// <summary>Union of the rectangles invalidated since the last <see cref="PaintBuffer"/> (scene coordinates).</summary>
    property DirtyRect: TRectF read FDirtyRect;
    property OnInvalidate: TFmrFrameHostInvalidateEvent read FOnInvalidate write FOnInvalidate;
    /// <summary>Window commands for the caption content (set by the frame).</summary>
    property Commands: IFmrFrameCommands read FCommands write FCommands;
    /// <summary>The last state passed to <see cref="UpdateState"/>.</summary>
    property State: TFmrFrameState read FState;
    /// <summary>The form the host lies on (nil if none).</summary>
    property Form: TCommonCustomForm read GetForm;
  end;

/// <summary>The frame host that contains AControl (nil if AControl is not caption content).</summary>
function FmrFindFrameHost(const AControl: TFmxObject): TFmrFrameHost;

implementation

uses
  System.Math;

type
  TOpenControl = class(TControl);

function FmrFindFrameHost(const AControl: TFmxObject): TFmrFrameHost;
var
  Obj: TFmxObject;
begin
  Obj := AControl;
  while Obj <> nil do
  begin
    if Obj is TFmrFrameHost then
      Exit(TFmrFrameHost(Obj));
    Obj := Obj.Parent;
  end;
  Result := nil;
end;

{ TFmrFrameHost }

constructor TFmrFrameHost.Create(AOwner: TComponent);
begin
  inherited;
  HitTest := False;
  CanFocus := False;
  FFillColor := TAlphaColors.Null;
  FInactiveFillColor := TAlphaColors.Null;
  FStyleChangedId := TMessageManager.DefaultManager.SubscribeToMessage(TStyleChangedMessage, StyleChangedHandler);
  FFormCreatedId := TMessageManager.DefaultManager.SubscribeToMessage(TAfterCreateFormHandle,
    FormHandleCreatedHandler);
end;

destructor TFmrFrameHost.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TStyleChangedMessage, FStyleChangedId);
  TMessageManager.DefaultManager.Unsubscribe(TAfterCreateFormHandle, FFormCreatedId);
  FOnInvalidate := nil;
  FCommands := nil;
  inherited;
  // Children are gone; the buffer can go now (children ask the scene canvas while being destroyed).
  FreeAndNil(FBuffer);
end;

function TFmrFrameHost.GetDefaultSize: TSizeF;
begin
  Result := TSizeF.Create(200, 32);
end;

function TFmrFrameHost.GetForm: TCommonCustomForm;
var
  Obj: TFmxObject;
begin
  Obj := Parent;
  while (Obj <> nil) and not (Obj is TCommonCustomForm) do
    Obj := Obj.Parent;
  Result := TCommonCustomForm(Obj);
end;

function TFmrFrameHost.GetFormScene: IScene;
begin
  Result := Scene;
end;

procedure TFmrFrameHost.SetNewScene(AScene: IScene);
var
  I: Integer;
begin
  inherited;
  if FOwnScene then
    for I := 0 to ControlsCount - 1 do
      Controls[I].SetNewScene(Self);
end;

procedure TFmrFrameHost.SetOwnScene(const AValue: Boolean);
var
  I: Integer;
  ChildScene: IScene;
begin
  if FOwnScene = AValue then
    Exit;
  FOwnScene := AValue;
  if FOwnScene then
  begin
    EnsureBuffer(1, 1, GetSceneScale);
    ChildScene := Self;
  end
  else
    ChildScene := Scene;
  for I := 0 to ControlsCount - 1 do
  begin
    Controls[I].SetNewScene(ChildScene);
    TOpenControl(Controls[I]).RecalcUpdateRect;
  end;
  PreparePopups;
  InvalidateHost;
end;

procedure TFmrFrameHost.DoAddObject(const AObject: TFmxObject);
begin
  inherited;
  if FOwnScene and (AObject is TControl) then
  begin
    TControl(AObject).SetNewScene(Self);
    PreparePopups;
    InvalidateHost;
  end;
  if AObject is TControl then
    NotifyState(TControl(AObject));
end;

procedure TFmrFrameHost.NotifyState(const AControl: TControl);
var
  Aware: IFmrFrameStateAware;
  I: Integer;
begin
  if Supports(AControl, IFmrFrameStateAware, Aware) then
    Aware.FrameStateChanged(FState);
  for I := 0 to AControl.ControlsCount - 1 do
    NotifyState(AControl.Controls[I]);
end;

procedure TFmrFrameHost.StyleChangedHandler(const Sender: TObject; const AMsg: TMessage);
var
  Msg: TStyleChangedMessage;
  FormScene: IScene;
begin
  // Children of an own scene ignore style changes sent for the form's scene: forward them with this scene.
  if not FOwnScene or (csDestroying in ComponentState) then
    Exit;
  Msg := TStyleChangedMessage(AMsg);
  FormScene := GetFormScene;
  if (Msg.Scene = nil) or (FormScene = nil) or (Msg.Scene <> FormScene) then
    Exit;
  TMessageManager.DefaultManager.SendMessage(Self, TStyleChangedMessage.Create(Msg.Value, Self), True);
  InvalidateHost;
end;

function TFmrFrameHost.GetCurrentFillColor: TAlphaColor;
begin
  if not FState.Active and (FInactiveFillColor <> TAlphaColors.Null) then
    Result := FInactiveFillColor
  else
    Result := FFillColor;
end;

procedure TFmrFrameHost.SetFillColor(const Value: TAlphaColor);
begin
  if FFillColor <> Value then
  begin
    FFillColor := Value;
    InvalidateHost;
  end;
end;

procedure TFmrFrameHost.SetInactiveFillColor(const Value: TAlphaColor);
begin
  if FInactiveFillColor <> Value then
  begin
    FInactiveFillColor := Value;
    InvalidateHost;
  end;
end;

procedure TFmrFrameHost.InvalidateHost;
begin
  if csDestroying in ComponentState then
    Exit;
  if FOwnScene then
    AddUpdateRect(AbsoluteRect)
  else
    Repaint;
end;

procedure TFmrFrameHost.Paint;
var
  Color: TAlphaColor;
begin
  // In the non-client modes the host is painted by PaintBuffer, not by the form.
  if FOwnScene then
    Exit;
  Color := GetCurrentFillColor;
  if (Color and $FF000000) <> 0 then
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := Color;
    Canvas.FillRect(LocalRect, 0, 0, [], AbsoluteOpacity);
  end;
end;

procedure TFmrFrameHost.PaintChildren;
begin
  if FOwnScene and not FPaintingBuffer then
    Exit;
  inherited;
end;

procedure TFmrFrameHost.EnsureBuffer(const AWidth, AHeight: Integer; const AScale: Single);
var
  W, H: Integer;
begin
  W := Max(1, AWidth);
  H := Max(1, AHeight);
  if FBuffer = nil then
    FBuffer := TBitmap.Create;
  if not SameValue(FBuffer.BitmapScale, AScale, 0.001) then
    FBuffer.BitmapScale := AScale;
  if (FBuffer.Width <> W) or (FBuffer.Height <> H) then
    FBuffer.SetSize(W, H);
end;

function TFmrFrameHost.PaintBuffer(const AWidth, AHeight: Integer; const AScale: Single): TBitmap;
var
  I: Integer;
  Child: TControl;
  LCanvas: TCanvas;
  Origin: TPointF;
begin
  EnsureBuffer(AWidth, AHeight, AScale);
  Result := FBuffer;
  FDirtyRect := TRectF.Empty;
  for I := 0 to ControlsCount - 1 do
    if Controls[I].Visible then
      TOpenControl(Controls[I]).PrepareForPaint;
  LCanvas := FBuffer.Canvas;
  // Absolute coordinates of the children are client coordinates of the form; the bitmap starts at the host.
  Origin := LocalToAbsolute(TPointF.Zero);
  LCanvas.Offset := TPointF.Create(-Origin.X, -Origin.Y);
  FPaintingBuffer := True;
  try
    if LCanvas.BeginScene then
    try
      // The host's own Canvas is the form's: its background is the cleared bitmap, not Paint.
      LCanvas.Clear(GetCurrentFillColor);
      for I := 0 to ControlsCount - 1 do
      begin
        Child := Controls[I];
        if Child.Visible and not Child.UpdateRect.IsEmpty then
          TOpenControl(Child).PaintInternal;
      end;
    finally
      LCanvas.EndScene;
    end;
  finally
    FPaintingBuffer := False;
    LCanvas.Offset := TPointF.Zero;
  end;
  if FInvalidatedWhilePainting then
  begin
    FInvalidatedWhilePainting := False;
    AddUpdateRect(AbsoluteRect);
  end;
end;

procedure TFmrFrameHost.UpdateState(const AState: TFmrFrameState);
var
  I: Integer;
begin
  FState := AState;
  for I := 0 to ControlsCount - 1 do
    NotifyState(Controls[I]);
  InvalidateHost;
end;

procedure TFmrFrameHost.ForEachControl(const AProc: TProc<TControl>);

  procedure Walk(const AParent: TControl);
  var
    I: Integer;
  begin
    for I := 0 to AParent.ControlsCount - 1 do
    begin
      AProc(AParent.Controls[I]);
      Walk(AParent.Controls[I]);
    end;
  end;

begin
  Walk(Self);
end;

procedure TFmrFrameHost.PreparePopups;

  procedure Walk(const AObject: TFmxObject);
  var
    I: Integer;
  begin
    if AObject is TPopup then
      TPopup(AObject).HideWhenPlacementTargetInvisible := False;
    for I := 0 to AObject.ChildrenCount - 1 do
      Walk(AObject.Children[I]);
  end;

begin
  if FOwnScene then
    Walk(Self);
end;

procedure TFmrFrameHost.FormHandleCreatedHandler(const Sender: TObject; const AMsg: TMessage);
var
  I: Integer;
  Popup: TPopup;
begin
  // TPopup.Popup registers the popup in FMX's popup list, then creates its form (this message) and copies
  // HideWhenPlacementTargetInvisible to it: pickers (the list of a TComboBox, date pickers) attach their TPopup to the
  // control only just before, so this is the moment to catch them.
  if not FOwnScene or not (AMsg is TAfterCreateFormHandle) or
    not (TAfterCreateFormHandle(AMsg).Value is TCustomPopupForm) then
    Exit;
  for I := 0 to GetPopupCount - 1 do
    if GetPopup(I) is TPopup then
    begin
      Popup := TPopup(GetPopup(I));
      if ((Popup.PlacementTarget <> nil) and (FmrFindFrameHost(Popup.PlacementTarget) = Self)) or
        (FmrFindFrameHost(Popup) = Self) then
        Popup.HideWhenPlacementTargetInvisible := False;
    end;
end;

function TFmrFrameHost.FrameHitTest(const AScreenPoint: TPointF): TFmrHitArea;
var
  Obj: IControl;
  Current: TFmxObject;
  HitTestIntf: IFmrFrameHitTest;
begin
  Obj := ObjectAtPoint(AScreenPoint);
  if (Obj = nil) or (Obj.GetObject = Self) then
    Exit(TFmrHitArea.Caption);
  Current := Obj.GetObject;
  while (Current <> nil) and (Current <> Self) do
  begin
    if (Current is TControl) and Supports(Current, IFmrFrameHitTest, HitTestIntf) then
    begin
      Result := HitTestIntf.FrameHitTest(TControl(Current).ScreenToLocal(AScreenPoint));
      if Result <> TFmrHitArea.Default then
        Exit;
    end;
    Current := Current.Parent;
  end;
  Result := TFmrHitArea.Client;
end;

function TFmrFrameHost.FindFrameButton(const AKind: TFmrHitArea): IFmrFrameButton;
var
  Found: IFmrFrameButton;
begin
  Found := nil;
  ForEachControl(
    procedure(AControl: TControl)
    var
      Button: IFmrFrameButton;
    begin
      if (Found = nil) and AControl.Visible and Supports(AControl, IFmrFrameButton, Button) and
        (Button.GetFrameButtonKind = AKind) then
        Found := Button;
    end);
  Result := Found;
end;

{ IScene }

procedure TFmrFrameHost.AddUpdateRect(const R: TRectF);
begin
  if (FDisableUpdating > 0) or (csDestroying in ComponentState) then
    Exit;
  // A control that changes while it is being painted (style animations) is painted again afterwards.
  if FPaintingBuffer then
  begin
    FInvalidatedWhilePainting := True;
    Exit;
  end;
  if FDirtyRect.IsEmpty then
    FDirtyRect := R
  else
    FDirtyRect := TRectF.Union(FDirtyRect, R);
  if Assigned(FOnInvalidate) then
    FOnInvalidate(R);
end;

function TFmrFrameHost.GetUpdateRectsCount: Integer;
begin
  Result := 1;
end;

function TFmrFrameHost.GetUpdateRect(const Index: Integer): TRectF;
begin
  Result := AbsoluteRect;
end;

function TFmrFrameHost.GetSceneObject: TFmxObject;
begin
  // Code that asks the scene for its object expects the form (font behaviors, "is the form visible/active").
  Result := Form;
  if Result = nil then
    Result := Self;
end;

function TFmrFrameHost.GetSceneCanvas: TCanvas;
begin
  if FBuffer = nil then
    EnsureBuffer(1, 1, GetSceneScale);
  Result := FBuffer.Canvas;
end;

function TFmrFrameHost.GetSceneScale: Single;
var
  FormScene: IScene;
begin
  FormScene := GetFormScene;
  if FormScene <> nil then
    Result := FormScene.GetSceneScale
  else
    Result := 1;
end;

function TFmrFrameHost.SceneLocalToScreen(const AScenePoint: TPointF): TPointF;
var
  FormScene: IScene;
begin
  FormScene := GetFormScene;
  if FormScene <> nil then
    Result := FormScene.LocalToScreen(AScenePoint)
  else
    Result := AScenePoint;
end;

function TFmrFrameHost.SceneScreenToLocal(const AScreenPoint: TPointF): TPointF;
var
  FormScene: IScene;
begin
  FormScene := GetFormScene;
  if FormScene <> nil then
    Result := FormScene.ScreenToLocal(AScreenPoint)
  else
    Result := AScreenPoint;
end;

procedure TFmrFrameHost.ChangeScrollingState(const AControl: TControl; const AActive: Boolean);
var
  FormScene: IScene;
begin
  FormScene := GetFormScene;
  if FormScene <> nil then
    FormScene.ChangeScrollingState(AControl, AActive);
end;

procedure TFmrFrameHost.DisableUpdating;
begin
  Inc(FDisableUpdating);
end;

procedure TFmrFrameHost.EnableUpdating;
begin
  Dec(FDisableUpdating);
  if FDisableUpdating < 0 then
    FDisableUpdating := 0;
end;

{ IStyleBookOwner }

function TFmrFrameHost.GetStyleBook: TStyleBook;
var
  Owner: IStyleBookOwner;
begin
  if Supports(Form, IStyleBookOwner, Owner) then
    Result := Owner.StyleBook
  else
    Result := nil;
end;

procedure TFmrFrameHost.SetStyleBook(const Value: TStyleBook);
begin
  // The host always uses the StyleBook of its form.
end;

end.
