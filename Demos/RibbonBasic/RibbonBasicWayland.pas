unit RibbonBasicWayland;

/// Linux only: a stand-in for the IFMXWaylandWindowFrame service (FMR.Frame.Wayland, Docs\LINUX.md) that FMXWayland
/// does not offer yet, to preview the integrated title bar: RibbonBasic /waylandframe=preview registers it before the
/// form is created, so TFmrFormFrame attaches (Hooked = True) and the ribbon draws the caption row with the window
/// buttons. Run it with FMXWAYLAND_CSD=0 (no FMXWayland title bar): tools\linux-run.ps1 -CsdOff. Minimize, maximize
/// and restore go through FMX (FMXWayland's xdg_toplevel requests); moving, resizing and the window menu need the
/// press serial only the platform has: they are logged and do nothing.

interface

/// <summary>Registers the stand-in service when the command line has /waylandframe=preview.</summary>
procedure RegisterWaylandFramePreview;

implementation

uses
  System.SysUtils, System.Types, System.UITypes, System.Generics.Collections, FMX.Types, FMX.Forms, FMX.Platform,
  FMR.Frame.Wayland;

type
  TPreviewFrameService = class(TInterfacedObject, IFMXWaylandWindowFrame)
  private
    FDecorated: TDictionary<TWindowHandle, Boolean>;
    FListeners: TDictionary<TWindowHandle, IFMXWaylandWindowFrameListener>;
    function FormOf(const AHandle: TWindowHandle): TCommonCustomForm;
    procedure Notify(const AHandle: TWindowHandle);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetDecorated(const AHandle: TWindowHandle; const AValue: Boolean);
    function GetDecorated(const AHandle: TWindowHandle): Boolean;
    function BeginMove(const AHandle: TWindowHandle): Boolean;
    function BeginResize(const AHandle: TWindowHandle; const AEdges: Cardinal): Boolean;
    function ShowWindowMenu(const AHandle: TWindowHandle; const AClientPoint: TPointF): Boolean;
    procedure Minimize(const AHandle: TWindowHandle);
    procedure SetMaximized(const AHandle: TWindowHandle; const AValue: Boolean);
    function GetStates(const AHandle: TWindowHandle): Cardinal;
    function GetCapabilities(const AHandle: TWindowHandle): Cardinal;
    procedure SetFrameListener(const AHandle: TWindowHandle; const AListener: IFMXWaylandWindowFrameListener);
  end;

procedure Log(const AText: string);
begin
  WriteLn('[waylandframe preview] ' + AText);
end;

constructor TPreviewFrameService.Create;
begin
  inherited;
  FDecorated := TDictionary<TWindowHandle, Boolean>.Create;
  FListeners := TDictionary<TWindowHandle, IFMXWaylandWindowFrameListener>.Create;
end;

destructor TPreviewFrameService.Destroy;
begin
  FListeners.Free;
  FDecorated.Free;
  inherited;
end;

function TPreviewFrameService.FormOf(const AHandle: TWindowHandle): TCommonCustomForm;
var
  I: Integer;
begin
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].Handle = AHandle then
      Exit(Screen.Forms[I]);
  Result := nil;
end;

procedure TPreviewFrameService.Notify(const AHandle: TWindowHandle);
var
  L: IFMXWaylandWindowFrameListener;
begin
  if FListeners.TryGetValue(AHandle, L) then
    L.WindowFrameChanged(AHandle, GetStates(AHandle), GetCapabilities(AHandle));
end;

procedure TPreviewFrameService.SetDecorated(const AHandle: TWindowHandle; const AValue: Boolean);
begin
  FDecorated.AddOrSetValue(AHandle, AValue);
  Log('SetDecorated ' + BoolToStr(AValue, True) + ' (FMXWAYLAND_CSD=0 shows the result)');
end;

function TPreviewFrameService.GetDecorated(const AHandle: TWindowHandle): Boolean;
begin
  if not FDecorated.TryGetValue(AHandle, Result) then
    Result := True;
end;

function TPreviewFrameService.BeginMove(const AHandle: TWindowHandle): Boolean;
begin
  Log('BeginMove');
  Result := False;
end;

function TPreviewFrameService.BeginResize(const AHandle: TWindowHandle; const AEdges: Cardinal): Boolean;
begin
  Log('BeginResize ' + IntToStr(AEdges));
  Result := False;
end;

function TPreviewFrameService.ShowWindowMenu(const AHandle: TWindowHandle; const AClientPoint: TPointF): Boolean;
begin
  Log(Format('ShowWindowMenu %.0f,%.0f', [AClientPoint.X, AClientPoint.Y]));
  Result := False;
end;

procedure TPreviewFrameService.Minimize(const AHandle: TWindowHandle);
var
  F: TCommonCustomForm;
begin
  Log('Minimize');
  F := FormOf(AHandle);
  if F <> nil then
    F.WindowState := TWindowState.wsMinimized;
end;

procedure TPreviewFrameService.SetMaximized(const AHandle: TWindowHandle; const AValue: Boolean);
var
  F: TCommonCustomForm;
begin
  Log('SetMaximized ' + BoolToStr(AValue, True));
  F := FormOf(AHandle);
  if F <> nil then
  begin
    if AValue then
      F.WindowState := TWindowState.wsMaximized
    else
      F.WindowState := TWindowState.wsNormal;
  end;
  Notify(AHandle);
end;

function TPreviewFrameService.GetStates(const AHandle: TWindowHandle): Cardinal;
var
  F: TCommonCustomForm;
begin
  Result := FmxwStateActivated;
  F := FormOf(AHandle);
  if (F <> nil) and (F.WindowState = TWindowState.wsMaximized) then
    Result := Result or FmxwStateMaximized;
end;

function TPreviewFrameService.GetCapabilities(const AHandle: TWindowHandle): Cardinal;
begin
  Result := FmxwCapsUnknown;
end;

procedure TPreviewFrameService.SetFrameListener(const AHandle: TWindowHandle;
  const AListener: IFMXWaylandWindowFrameListener);
begin
  if AListener = nil then
    FListeners.Remove(AHandle)
  else
  begin
    FListeners.AddOrSetValue(AHandle, AListener);
    Notify(AHandle);
  end;
end;

procedure RegisterWaylandFramePreview;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '/waylandframe=preview') then
    begin
      if not TPlatformServices.Current.SupportsPlatformService(IFMXWaylandWindowFrame) then
        TPlatformServices.Current.AddPlatformService(IFMXWaylandWindowFrame, TPreviewFrameService.Create);
      Log('registered');
      Exit;
    end;
end;

end.
