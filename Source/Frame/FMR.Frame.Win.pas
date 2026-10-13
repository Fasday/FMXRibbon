{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Form frame: Windows implementation                   }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Frame.Win;

interface

{$IFDEF MSWINDOWS}

uses
  Winapi.Windows, Winapi.Messages, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Forms, FMX.Graphics,
  FMR.Frame.Types, FMR.Frame.Host, FMR.Frame;

type
  /// <summary>How the FullNC mode keeps the system frame (diagnostics and experiments; see Docs\FRAME.md).</summary>
  TFmrWinFullNCStrategy = (
    /// <summary>The window keeps WS_THICKFRAME but loses WS_CAPTION: DWM draws only the border, the shadow and the
    /// rounded corners (Windows 11); the caption strip below the top sizing border is ours (default).</summary>
    NoCaptionStyle,
    /// <summary>The window keeps WS_CAPTION; the top non-client area is replaced by the caption strip. DWM draws its
    /// caption over the strip (kept for comparison).</summary>
    KeepCaptionStyle);

var
  /// <summary>Strategy of the FullNC mode for frames attached from now on.</summary>
  FmrWinFullNCStrategy: TFmrWinFullNCStrategy = TFmrWinFullNCStrategy.NoCaptionStyle;

type
  /// <summary>Windows part of <c>TFmrFormFrame</c>: subclasses the form's window (SetWindowSubclass) and handles the
  /// non-client messages, DWM attributes and painting of the caption content in the non-client area.</summary>
  TFmrWinFrame = class(TFmrFramePlatform)
  private
    FWnd: HWND;
    FAttached: Boolean;
    FMode: TFmrFrameMode;
    FCaptionStyleRemoved: Boolean;
    FThickFrameAdded: Boolean;
    FActive: Boolean;
    FHot: TFmrHitArea;
    FPressed: TFmrHitArea;
    FTrackingNC: Boolean;
    FPaintPosted: Boolean;
    FInPaint: Boolean;
    FChangingFrame: Boolean;
    FDib: HBITMAP;
    FDibDC: HDC;
    FDibBits: Pointer;
    FDibSize: TSize;
    FFillSaved: Boolean;
    FSavedFillKind: TBrushKind;
    FSavedFillColor: TAlphaColor;
    FLastHitTest: Integer;
    function HandleMessage(const AMsg: UINT; const AWParam: WPARAM; const ALParam: LPARAM;
      var AResult: LRESULT): Boolean;
    procedure WindowDestroyed;
    function GetScale: Single;
    function GetDpi: UINT;
    function FrameThickness: TSize;
    function CaptionPx: Integer;
    function IsNCMode: Boolean;
    function IsResizable: Boolean;
    function IsMaximized: Boolean;
    procedure AdjustClientRect(const AWindowRect: TRect; var AClientRect: TRect);
    procedure ApplyAutoHideTaskbar(var AClientRect: TRect);
    procedure AdjustMaximizedBounds(const AInfo: PMinMaxInfo);
    function NCHitTest(const AScreenPoint: TPoint; const ADefault: LRESULT): LRESULT;
    function HostRectOnScreen: TRect;
    function HostScreenPointFromPx(const AScreenPx: TPoint): TPointF;
    function StripRectInWindow: TRect;
    procedure PaintStrip(const ADC: HDC);
    procedure PaintNC;
    procedure DoNCPaint(const ARegion: HRGN);
    procedure PostPaint;
    procedure EnsureDib(const AWidth, AHeight: Integer);
    procedure FreeDib;
    procedure CopyToDib(const ABitmap: TBitmap);
    procedure ApplyWindowStyle;
    procedure RestoreWindowStyle;
    procedure ApplyDwmAttributes;
    procedure ApplyCaptionColor;
    procedure ResetDwmAttributes;
    procedure ApplyFormFill;
    procedure RestoreFormFill;
    procedure UpdateLayout;
    procedure UpdateFrameState;
    procedure SetButtonStates(const AHot, APressed: TFmrHitArea);
    procedure TrackNCLeave;
    procedure ExecuteButton(const AArea: TFmrHitArea);
    procedure UpdateCursor;
    function AreaFromHitCode(const ACode: LRESULT; const AScreenPoint: TPoint): TFmrHitArea;
    procedure SysCommand(const ACommand: WPARAM);
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
    /// <summary>Shows the system menu at a screen point in physical pixels.</summary>
    procedure ShowSystemMenuPx(const AScreenPx: TPoint);
    property Wnd: HWND read FWnd;
    /// <summary>Last code returned by WM_NCHITTEST (diagnostics).</summary>
    property LastHitTest: Integer read FLastHitTest;
  end;

/// <summary>Name of a WM_NCHITTEST result (HTCAPTION, HTCLIENT...), for diagnostics.</summary>
function FmrHitTestName(const ACode: Integer): string;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  System.SysUtils, System.Math, Winapi.CommCtrl, Winapi.Dwmapi, Winapi.UxTheme, Winapi.ShellAPI, Winapi.MultiMon,
  FMX.Controls, FMX.Platform, FMX.Platform.Win;

const
  SubclassId = $464D52; // 'FMR'

  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;
  DWMWA_USE_IMMERSIVE_DARK_MODE_NEW = 20;
  DWMWA_WINDOW_CORNER_PREF = 33;
  DWMWA_CAPTION_COLOR_ATTR = 35;
  DWMWA_SYSTEMBACKDROP = 38;
  DWMWA_COLOR_DEFAULT = $FFFFFFFF;
  DWMSBT_AUTO = 0;
  DWMSBT_MAINWINDOW = 2;
  DWMSBT_TRANSIENTWINDOW = 3;
  DWMSBT_TABBEDWINDOW = 4;

  ABM_GETAUTOHIDEBAREX = $0000000B;

var
  WM_FMR_NCPAINT: UINT = 0;

type
  TSetWindowSubclass = function(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR;
    dwRefData: DWORD_PTR): BOOL; stdcall;
  TRemoveWindowSubclass = function(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR): BOOL; stdcall;
  TDefSubclassProc = function(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

var
  // comctl32 is loaded on demand: Winapi.CommCtrl's wrappers only work when the DLL is already loaded, and version 5
  // (no manifest) exports the subclass functions by ordinal only.
  ComCtl: HMODULE = 0;
  _SetWindowSubclass: TSetWindowSubclass = nil;
  _RemoveWindowSubclass: TRemoveWindowSubclass = nil;
  _DefSubclassProc: TDefSubclassProc = nil;

function LoadSubclassApi: Boolean;

  function GetProc(const AName: string; const AOrdinal: Word): Pointer;
  begin
    Result := GetProcAddress(ComCtl, PChar(AName));
    if Result = nil then
      Result := GetProcAddress(ComCtl, PChar(NativeUInt(AOrdinal)));
  end;

begin
  if not Assigned(_DefSubclassProc) then
  begin
    if ComCtl = 0 then
      ComCtl := LoadLibrary('comctl32.dll');
    if ComCtl <> 0 then
    begin
      @_SetWindowSubclass := GetProc('SetWindowSubclass', 410);
      @_RemoveWindowSubclass := GetProc('RemoveWindowSubclass', 412);
      @_DefSubclassProc := GetProc('DefSubclassProc', 413);
    end;
  end;
  Result := Assigned(_SetWindowSubclass) and Assigned(_RemoveWindowSubclass) and Assigned(_DefSubclassProc);
end;

function SetWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): BOOL;
begin
  Result := LoadSubclassApi and _SetWindowSubclass(hWnd, pfnSubclass, uIdSubclass, dwRefData);
end;

function RemoveWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR): BOOL;
begin
  Result := LoadSubclassApi and _RemoveWindowSubclass(hWnd, pfnSubclass, uIdSubclass);
end;

function DefSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
begin
  Result := _DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;

function FmrHitTestName(const ACode: Integer): string;
begin
  case ACode of
    HTERROR: Result := 'HTERROR';
    HTTRANSPARENT: Result := 'HTTRANSPARENT';
    HTNOWHERE: Result := 'HTNOWHERE';
    HTCLIENT: Result := 'HTCLIENT';
    HTCAPTION: Result := 'HTCAPTION';
    HTSYSMENU: Result := 'HTSYSMENU';
    HTGROWBOX: Result := 'HTGROWBOX';
    HTMENU: Result := 'HTMENU';
    HTHSCROLL: Result := 'HTHSCROLL';
    HTVSCROLL: Result := 'HTVSCROLL';
    HTMINBUTTON: Result := 'HTMINBUTTON';
    HTMAXBUTTON: Result := 'HTMAXBUTTON';
    HTLEFT: Result := 'HTLEFT';
    HTRIGHT: Result := 'HTRIGHT';
    HTTOP: Result := 'HTTOP';
    HTTOPLEFT: Result := 'HTTOPLEFT';
    HTTOPRIGHT: Result := 'HTTOPRIGHT';
    HTBOTTOM: Result := 'HTBOTTOM';
    HTBOTTOMLEFT: Result := 'HTBOTTOMLEFT';
    HTBOTTOMRIGHT: Result := 'HTBOTTOMRIGHT';
    HTBORDER: Result := 'HTBORDER';
    HTCLOSE: Result := 'HTCLOSE';
    HTHELP: Result := 'HTHELP';
  else
    Result := IntToStr(ACode);
  end;
end;

function FrameSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Frame: TFmrWinFrame;
begin
  Frame := TFmrWinFrame(dwRefData);
  if uMsg = WM_NCDESTROY then
  begin
    Frame.WindowDestroyed;
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
  end;
  Result := 0;
  try
    if not Frame.HandleMessage(uMsg, wParam, lParam, Result) then
      Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
  except
    on E: Exception do
    begin
      Application.HandleException(E);
      Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
    end;
  end;
end;

function PointFromLParam(const ALParam: LPARAM): TPoint; inline;
begin
  Result := TPoint.Create(SmallInt(LoWord(Cardinal(ALParam))), SmallInt(HiWord(Cardinal(ALParam))));
end;

{ TFmrWinFrame }

destructor TFmrWinFrame.Destroy;
begin
  Detach;
  FreeDib;
  inherited;
end;

function TFmrWinFrame.IsAttached: Boolean;
begin
  Result := FAttached;
end;

procedure TFmrWinFrame.Attach;
var
  Form: TCommonCustomForm;
begin
  if FAttached then
    Exit;
  Form := Frame.Form;
  if (Form = nil) or not Form.IsHandleAllocated then
    Exit;
  FWnd := FormToHWND(Form);
  if FWnd = 0 then
    Exit;
  // The styled border of FMX (TWinWindowBorder) would take over every WM_NC* message. Only switched off when it is
  // really active (switching it off recreates the window region and the OS menu).
  if Form.Border.IsSupported then
    Form.Border.Styling := False;
  if not SetWindowSubclass(FWnd, @FrameSubclassProc, SubclassId, DWORD_PTR(Self)) then
  begin
    FWnd := 0;
    Exit;
  end;
  FAttached := True;
  FActive := GetActiveWindow = FWnd;
  FHot := TFmrHitArea.Default;
  FPressed := TFmrHitArea.Default;
  FMode := Frame.Mode;
  FrameChanged;
end;

procedure TFmrWinFrame.Detach;
var
  Alive: Boolean;
begin
  if not FAttached then
    Exit;
  FAttached := False;
  Alive := IsWindow(FWnd) and (Frame.Form <> nil) and not (csDestroying in Frame.Form.ComponentState);
  RemoveWindowSubclass(FWnd, @FrameSubclassProc, SubclassId);
  if Alive then
  begin
    RestoreFormFill;
    RestoreWindowStyle;
    ResetDwmAttributes;
    SetWindowPos(FWnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or
      SWP_NOACTIVATE or SWP_NOOWNERZORDER);
    if not (csDestroying in Frame.ComponentState) then
      Frame.PlaceHostInClient(Frame.CaptionHeight);
    RedrawWindow(FWnd, nil, 0, RDW_FRAME or RDW_INVALIDATE or RDW_UPDATENOW);
  end;
  FWnd := 0;
end;

procedure TFmrWinFrame.WindowDestroyed;
begin
  if FAttached then
  begin
    RemoveWindowSubclass(FWnd, @FrameSubclassProc, SubclassId);
    FAttached := False;
    FWnd := 0;
  end;
end;

function TFmrWinFrame.GetScale: Single;
begin
  if (Frame.Form <> nil) and (Frame.Form.Handle <> nil) then
    Result := Frame.Form.Handle.Scale
  else
    Result := 1;
end;

function TFmrWinFrame.GetDpi: UINT;
begin
  if (FWnd <> 0) and CheckWin32Version(10) then
  begin
    Result := GetDpiForWindow(FWnd);
    if Result = 0 then
      Result := Round(96 * GetScale);
  end
  else
    Result := Round(96 * GetScale);
end;

function TFmrWinFrame.FrameThickness: TSize;
var
  R: TRect;
  Style, ExStyle: DWORD;
begin
  // The sizing border the window really has (it differs by a pixel with and without WS_CAPTION), the same the
  // default WM_NCCALCSIZE uses: left/right and bottom of the adjusted rectangle.
  Style := DWORD(GetWindowLong(FWnd, GWL_STYLE));
  ExStyle := DWORD(GetWindowLong(FWnd, GWL_EXSTYLE));
  R := TRect.Empty;
  if CheckWin32Version(10) then
    AdjustWindowRectExForDpi(R, Style and not WS_MAXIMIZE, False, ExStyle, GetDpi)
  else
    AdjustWindowRectEx(R, Style and not WS_MAXIMIZE, False, ExStyle);
  Result.cx := -R.Left;
  Result.cy := R.Bottom;
end;

function TFmrWinFrame.CaptionPx: Integer;
begin
  Result := Max(0, Round(Frame.CaptionHeight * GetScale));
end;

function TFmrWinFrame.IsNCMode: Boolean;
begin
  Result := FMode in [TFmrFrameMode.FullNC, TFmrFrameMode.NCStrip];
end;

function TFmrWinFrame.IsResizable: Boolean;
begin
  Result := not FThickFrameAdded and ((GetWindowLong(FWnd, GWL_STYLE) and WS_THICKFRAME) <> 0);
end;

function TFmrWinFrame.IsMaximized: Boolean;
begin
  Result := IsZoomed(FWnd);
end;

{ Frame geometry }

procedure TFmrWinFrame.AdjustClientRect(const AWindowRect: TRect; var AClientRect: TRect);
var
  Thickness: TSize;
begin
  if IsIconic(FWnd) then
    Exit;
  Thickness := FrameThickness;
  case FMode of
    TFmrFrameMode.Dwm:
      // No top non-client area; a maximized window lies beyond the monitor by the frame thickness.
      if IsMaximized then
        AClientRect.Top := AWindowRect.Top + Thickness.cy
      else
        AClientRect.Top := AWindowRect.Top;
    TFmrFrameMode.FullNC:
      if FCaptionStyleRemoved then
        // The default calculation left the top sizing border; the caption strip follows it.
        AClientRect.Top := AClientRect.Top + CaptionPx
      else if IsMaximized then
        AClientRect.Top := AWindowRect.Top + Thickness.cy + CaptionPx
      else
        AClientRect.Top := AWindowRect.Top + CaptionPx;
    TFmrFrameMode.NCStrip:
      AClientRect.Top := AClientRect.Top + CaptionPx;
  end;
  if IsMaximized then
    ApplyAutoHideTaskbar(AClientRect);
  if AClientRect.Top > AClientRect.Bottom then
    AClientRect.Top := AClientRect.Bottom;
end;

procedure TFmrWinFrame.ApplyAutoHideTaskbar(var AClientRect: TRect);
const
  AutoHideGap = 2;
var
  Monitor: HMONITOR;
  Info: TMonitorInfo;
  Data: TAppBarData;

  function HasAutoHideBar(const AEdge: UINT): Boolean;
  begin
    FillChar(Data, SizeOf(Data), 0);
    Data.cbSize := SizeOf(Data);
    Data.uEdge := AEdge;
    Data.rc := Info.rcMonitor;
    Result := SHAppBarMessage(ABM_GETAUTOHIDEBAREX, Data) <> 0;
  end;

begin
  Monitor := MonitorFromWindow(FWnd, MONITOR_DEFAULTTONEAREST);
  Info.cbSize := SizeOf(Info);
  if not GetMonitorInfo(Monitor, @Info) then
    Exit;
  // Only when the work area is the whole monitor (an auto-hide taskbar takes no space).
  if Info.rcMonitor <> Info.rcWork then
    Exit;
  if HasAutoHideBar(ABE_BOTTOM) then
    Dec(AClientRect.Bottom, AutoHideGap)
  else if HasAutoHideBar(ABE_LEFT) then
    Inc(AClientRect.Left, AutoHideGap)
  else if HasAutoHideBar(ABE_TOP) then
    Inc(AClientRect.Top, AutoHideGap)
  else if HasAutoHideBar(ABE_RIGHT) then
    Dec(AClientRect.Right, AutoHideGap);
end;

procedure TFmrWinFrame.AdjustMaximizedBounds(const AInfo: PMinMaxInfo);
var
  Monitor: HMONITOR;
  Info: TMonitorInfo;
  Thickness: TSize;
begin
  // Without WS_CAPTION Windows maximizes a window over the whole monitor (taskbar included), as for a full screen
  // window: maximize it into the work area, beyond it by the frame thickness as a captioned window.
  Monitor := MonitorFromWindow(FWnd, MONITOR_DEFAULTTONEAREST);
  Info.cbSize := SizeOf(Info);
  if not GetMonitorInfo(Monitor, @Info) then
    Exit;
  Thickness := FrameThickness;
  AInfo.ptMaxPosition.X := Info.rcWork.Left - Info.rcMonitor.Left - Thickness.cx;
  AInfo.ptMaxPosition.Y := Info.rcWork.Top - Info.rcMonitor.Top - Thickness.cy;
  AInfo.ptMaxSize.X := Info.rcWork.Width + 2 * Thickness.cx;
  AInfo.ptMaxSize.Y := Info.rcWork.Height + 2 * Thickness.cy;
end;

function TFmrWinFrame.HostRectOnScreen: TRect;
var
  Origin: TPoint;
  ClientRect: TRect;
begin
  Origin := TPoint.Zero;
  Winapi.Windows.ClientToScreen(FWnd, Origin);
  Winapi.Windows.GetClientRect(FWnd, ClientRect);
  if IsNCMode then
    Result := TRect.Create(Origin.X, Origin.Y - CaptionPx, Origin.X + ClientRect.Right, Origin.Y)
  else
    Result := TRect.Create(Origin.X, Origin.Y, Origin.X + ClientRect.Right, Origin.Y + CaptionPx);
end;

function TFmrWinFrame.HostScreenPointFromPx(const AScreenPx: TPoint): TPointF;
var
  ClientPx: TPoint;
  Scale: Single;
begin
  ClientPx := AScreenPx;
  Winapi.Windows.ScreenToClient(FWnd, ClientPx);
  Scale := GetScale;
  Result := Frame.Form.ClientToScreen(TPointF.Create(ClientPx.X / Scale, ClientPx.Y / Scale));
end;

function TFmrWinFrame.StripRectInWindow: TRect;
var
  WindowRect: TRect;
begin
  GetWindowRect(FWnd, WindowRect);
  Result := HostRectOnScreen;
  Result.Offset(-WindowRect.Left, -WindowRect.Top);
end;

{ Hit testing }

function TFmrWinFrame.AreaFromHitCode(const ACode: LRESULT; const AScreenPoint: TPoint): TFmrHitArea;
begin
  // Only the caption buttons of the host; the system caption buttons (NCStrip) belong to the default procedure.
  if not HostRectOnScreen.Contains(AScreenPoint) then
    Exit(TFmrHitArea.Default);
  case ACode of
    HTMINBUTTON: Result := TFmrHitArea.MinButton;
    HTMAXBUTTON: Result := TFmrHitArea.MaxButton;
    HTCLOSE: Result := TFmrHitArea.CloseButton;
    HTHELP: Result := TFmrHitArea.HelpButton;
  else
    Result := TFmrHitArea.Default;
  end;
end;

function TFmrWinFrame.NCHitTest(const AScreenPoint: TPoint; const ADefault: LRESULT): LRESULT;
var
  WindowRect, HostRect, ClientRect: TRect;
  Origin: TPoint;
  Thickness: TSize;
  Area: TFmrHitArea;
  TopEdgeInHost: Boolean;
begin
  GetWindowRect(FWnd, WindowRect);
  HostRect := HostRectOnScreen;
  Thickness := FrameThickness;
  if (Frame.Host <> nil) and Frame.Host.Visible and (CaptionPx > 0) and HostRect.Contains(AScreenPoint) then
  begin
    // The host starts at the top of the window when nothing (sizing border, system caption) lies above it.
    TopEdgeInHost := (FMode = TFmrFrameMode.Dwm) or
      ((FMode = TFmrFrameMode.FullNC) and not FCaptionStyleRemoved);
    if TopEdgeInHost and IsResizable and not IsMaximized and (AScreenPoint.Y < WindowRect.Top + Thickness.cy) then
    begin
      if AScreenPoint.X < WindowRect.Left + Thickness.cx * 2 then
        Exit(HTTOPLEFT)
      else if AScreenPoint.X >= WindowRect.Right - Thickness.cx * 2 then
        Exit(HTTOPRIGHT)
      else
        Exit(HTTOP);
    end;
    Area := Frame.Host.FrameHitTest(HostScreenPointFromPx(AScreenPoint));
    case Area of
      TFmrHitArea.Client: Result := HTCLIENT;
      TFmrHitArea.SysMenu: Result := HTSYSMENU;
      TFmrHitArea.MinButton: Result := HTMINBUTTON;
      TFmrHitArea.MaxButton: Result := HTMAXBUTTON;
      TFmrHitArea.CloseButton: Result := HTCLOSE;
      TFmrHitArea.HelpButton: Result := HTHELP;
      TFmrHitArea.Nowhere:
        if ADefault = HTCLIENT then
          Result := HTNOWHERE
        else
          Result := ADefault;
    else
      Result := HTCAPTION;
    end;
    Exit;
  end;
  Origin := TPoint.Zero;
  Winapi.Windows.ClientToScreen(FWnd, Origin);
  Winapi.Windows.GetClientRect(FWnd, ClientRect);
  ClientRect.Offset(Origin);
  if ClientRect.Contains(AScreenPoint) then
    Exit(HTCLIENT);
  Result := ADefault;
  // Without a caption style the default procedure does not know the strip; above the client area it is ours.
  if (Result in [HTNOWHERE, HTBORDER, HTCLIENT]) and IsResizable and not IsMaximized then
  begin
    if AScreenPoint.Y < WindowRect.Top + Thickness.cy then
    begin
      if AScreenPoint.X < WindowRect.Left + Thickness.cx * 2 then
        Result := HTTOPLEFT
      else if AScreenPoint.X >= WindowRect.Right - Thickness.cx * 2 then
        Result := HTTOPRIGHT
      else
        Result := HTTOP;
    end;
  end;
end;

{ Message handling }

function TFmrWinFrame.HandleMessage(const AMsg: UINT; const AWParam: WPARAM; const ALParam: LPARAM;
  var AResult: LRESULT): Boolean;
var
  WindowRect: TRect;
  Params: PNCCalcSizeParams;
  Area: TFmrHitArea;
  P: TPoint;
begin
  Result := False;
  case AMsg of
    WM_NCCALCSIZE:
      begin
        if AWParam <> 0 then
        begin
          Params := PNCCalcSizeParams(ALParam);
          WindowRect := Params.rgrc[0];
          AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
          AdjustClientRect(WindowRect, Params.rgrc[0]);
        end
        else
        begin
          WindowRect := PRect(ALParam)^;
          AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
          AdjustClientRect(WindowRect, PRect(ALParam)^);
        end;
        Result := True;
      end;

    WM_NCHITTEST:
      begin
        if FMode = TFmrFrameMode.Dwm then
        begin
          if DwmDefWindowProc(FWnd, AMsg, AWParam, ALParam, AResult) then
          begin
            FLastHitTest := AResult;
            Exit(True);
          end;
        end;
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        AResult := NCHitTest(PointFromLParam(ALParam), AResult);
        // The sizing frame added to a fixed size window only gives it the DWM border.
        if FThickFrameAdded and (AResult >= HTLEFT) and (AResult <= HTBOTTOMRIGHT) then
          AResult := HTBORDER;
        FLastHitTest := AResult;
        Result := True;
      end;

    WM_NCPAINT:
      if IsNCMode then
      begin
        DoNCPaint(HRGN(AWParam));
        AResult := 0;
        Result := True;
      end;

    WM_NCACTIVATE:
      begin
        FActive := AWParam <> 0;
        if FMode = TFmrFrameMode.NCStrip then
          AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam)
        else
          // -1: the default procedure updates the state without repainting the non-client area.
          AResult := DefSubclassProc(FWnd, AMsg, AWParam, LPARAM(-1));
        UpdateFrameState;
        ApplyCaptionColor;
        if IsNCMode then
          PaintNC;
        Result := True;
      end;

    WM_NCMOUSEMOVE:
      begin
        Area := AreaFromHitCode(AWParam, PointFromLParam(ALParam));
        if Area <> TFmrHitArea.Default then
        begin
          TrackNCLeave;
          if (FPressed <> TFmrHitArea.Default) and (FPressed <> Area) then
            SetButtonStates(Area, TFmrHitArea.Default)
          else
            SetButtonStates(Area, FPressed);
          AResult := 0;
          Result := True;
        end
        else
          SetButtonStates(TFmrHitArea.Default, TFmrHitArea.Default);
      end;

    WM_NCLBUTTONDOWN, WM_NCLBUTTONDBLCLK:
      begin
        Area := AreaFromHitCode(AWParam, PointFromLParam(ALParam));
        if Area <> TFmrHitArea.Default then
        begin
          // The default procedure would run its own modal loop and draw a classic button.
          SetButtonStates(Area, Area);
          AResult := 0;
          Result := True;
        end
        else
          SetButtonStates(TFmrHitArea.Default, TFmrHitArea.Default);
      end;

    WM_NCLBUTTONUP:
      begin
        Area := AreaFromHitCode(AWParam, PointFromLParam(ALParam));
        if Area <> TFmrHitArea.Default then
        begin
          if FPressed = Area then
          begin
            SetButtonStates(Area, TFmrHitArea.Default);
            ExecuteButton(Area);
          end;
          AResult := 0;
          Result := True;
        end
        else
          SetButtonStates(FHot, TFmrHitArea.Default);
      end;

    WM_NCRBUTTONUP:
      if (AWParam = HTCAPTION) or (AWParam = HTSYSMENU) then
      begin
        ShowSystemMenuPx(PointFromLParam(ALParam));
        AResult := 0;
        Result := True;
      end;

    WM_NCMOUSELEAVE:
      begin
        FTrackingNC := False;
        SetButtonStates(TFmrHitArea.Default, TFmrHitArea.Default);
      end;

    WM_MOUSEMOVE:
      begin
        // FMX asks for client leave tracking on every move, which ends our non-client tracking.
        FTrackingNC := False;
        if FHot <> TFmrHitArea.Default then
          SetButtonStates(TFmrHitArea.Default, TFmrHitArea.Default);
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        if IsNCMode and (SmallInt(HiWord(Cardinal(ALParam))) < 0) then
          UpdateCursor;
        Result := True;
      end;

    WM_SETCURSOR:
      if (LoWord(Cardinal(ALParam)) = HTCLIENT) and (HWND(AWParam) = FWnd) and IsNCMode then
      begin
        GetCursorPos(P);
        if HostRectOnScreen.Contains(P) then
        begin
          UpdateCursor;
          AResult := 1;
          Result := True;
        end;
      end;

    WM_SIZE:
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        if AWParam <> SIZE_MINIMIZED then
          UpdateLayout;
        UpdateFrameState;
        Result := True;
      end;

    WM_WINDOWPOSCHANGED:
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        if (PWindowPos(ALParam).flags and SWP_FRAMECHANGED) <> 0 then
          UpdateLayout;
        Result := True;
      end;

    WM_GETMINMAXINFO:
      if FCaptionStyleRemoved then
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        AdjustMaximizedBounds(PMinMaxInfo(ALParam));
        Result := True;
      end;

    WM_DPICHANGED:
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        FrameChanged;
        Result := True;
      end;

    WM_SETTINGCHANGE:
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        // Frame metrics, the work area (maximized size, auto-hide taskbar) or the light/dark colors changed.
        if not FChangingFrame and ((AWParam = SPI_SETNONCLIENTMETRICS) or (AWParam = SPI_SETWORKAREA) or
          ((ALParam <> 0) and SameText(PChar(ALParam), 'ImmersiveColorSet'))) then
          FrameChanged;
        Result := True;
      end;

    WM_THEMECHANGED, WM_DWMCOMPOSITIONCHANGED:
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        if not FChangingFrame then
          FrameChanged;
        Result := True;
      end;

    WM_SETTEXT:
      if IsNCMode then
      begin
        AResult := DefSubclassProc(FWnd, AMsg, AWParam, ALParam);
        PaintNC;
        Result := True;
      end;
  else
    if (AMsg = WM_FMR_NCPAINT) and (WM_FMR_NCPAINT <> 0) then
    begin
      FPaintPosted := False;
      PaintNC;
      AResult := 0;
      Result := True;
    end;
  end;
end;

procedure TFmrWinFrame.UpdateCursor;
var
  P: TPoint;
  Obj: IControl;
  CursorService: IFMXCursorService;
  Cursor: TCursor;
begin
  if (Frame.Host = nil) or not TPlatformServices.Current.SupportsPlatformService(IFMXCursorService, CursorService) then
    Exit;
  GetCursorPos(P);
  Obj := Frame.Form.Captured;
  if Obj = nil then
    Obj := (Frame.Host as IControl).ObjectAtPoint(HostScreenPointFromPx(P));
  if Obj <> nil then
    Cursor := Obj.InheritedCursor
  else
    Cursor := crDefault;
  CursorService.SetCursor(Cursor);
end;

procedure TFmrWinFrame.TrackNCLeave;
var
  Track: TTrackMouseEvent;
begin
  if FTrackingNC then
    Exit;
  Track.cbSize := SizeOf(Track);
  Track.dwFlags := TME_LEAVE or TME_NONCLIENT;
  Track.hwndTrack := FWnd;
  Track.dwHoverTime := HOVER_DEFAULT;
  FTrackingNC := TrackMouseEvent(Track);
end;

procedure TFmrWinFrame.SetButtonStates(const AHot, APressed: TFmrHitArea);

  procedure Apply(const AKind: TFmrHitArea);
  var
    Button: IFmrFrameButton;
  begin
    if Frame.Host = nil then
      Exit;
    Button := Frame.Host.FindFrameButton(AKind);
    if Button <> nil then
      Button.SetFrameButtonState(AHot = AKind, APressed = AKind);
  end;

var
  Kind: TFmrHitArea;
begin
  if (FHot = AHot) and (FPressed = APressed) then
    Exit;
  FHot := AHot;
  FPressed := APressed;
  for Kind in [TFmrHitArea.MinButton, TFmrHitArea.MaxButton, TFmrHitArea.CloseButton, TFmrHitArea.HelpButton] do
    Apply(Kind);
end;

procedure TFmrWinFrame.ExecuteButton(const AArea: TFmrHitArea);
begin
  case AArea of
    TFmrHitArea.MinButton: Frame.Minimize;
    TFmrHitArea.MaxButton: Frame.ToggleMaximize;
    TFmrHitArea.CloseButton: Frame.CloseForm;
    TFmrHitArea.HelpButton: Frame.ShowHelp;
  end;
end;

{ Window commands }

procedure TFmrWinFrame.SysCommand(const ACommand: WPARAM);
begin
  if FWnd <> 0 then
    PostMessage(FWnd, WM_SYSCOMMAND, ACommand, 0);
end;

procedure TFmrWinFrame.Minimize;
begin
  SysCommand(SC_MINIMIZE);
end;

procedure TFmrWinFrame.ToggleMaximize;
begin
  if IsMaximized then
    SysCommand(SC_RESTORE)
  else
    SysCommand(SC_MAXIMIZE);
end;

procedure TFmrWinFrame.CloseForm;
begin
  SysCommand(SC_CLOSE);
end;

procedure TFmrWinFrame.ShowHelp;
begin
  SysCommand(SC_CONTEXTHELP);
end;

procedure TFmrWinFrame.ShowSystemMenu(const AScreenPoint: TPointF);
var
  ClientPt: TPointF;
  P: TPoint;
  Scale: Single;
begin
  if FWnd = 0 then
    Exit;
  ClientPt := Frame.Form.ScreenToClient(AScreenPoint);
  Scale := GetScale;
  P := TPoint.Create(Round(ClientPt.X * Scale), Round(ClientPt.Y * Scale));
  Winapi.Windows.ClientToScreen(FWnd, P);
  ShowSystemMenuPx(P);
end;

procedure TFmrWinFrame.ShowSystemMenuPx(const AScreenPx: TPoint);
const
  Enabled: array [Boolean] of UINT = (MF_GRAYED or MF_DISABLED, MF_ENABLED);
var
  Menu: HMENU;
  Command: BOOL;
  Maximized, Resizable: Boolean;
  Style: NativeInt;
  Flags: UINT;
begin
  if FWnd = 0 then
    Exit;
  Menu := GetSystemMenu(FWnd, False);
  if Menu = 0 then
    Exit;
  Maximized := IsMaximized;
  Resizable := IsResizable;
  Style := GetWindowLong(FWnd, GWL_STYLE);
  EnableMenuItem(Menu, SC_RESTORE, MF_BYCOMMAND or Enabled[Maximized or IsIconic(FWnd)]);
  EnableMenuItem(Menu, SC_MOVE, MF_BYCOMMAND or Enabled[not Maximized]);
  EnableMenuItem(Menu, SC_SIZE, MF_BYCOMMAND or Enabled[Resizable and not Maximized]);
  EnableMenuItem(Menu, SC_MINIMIZE, MF_BYCOMMAND or Enabled[(Style and WS_MINIMIZEBOX) <> 0]);
  EnableMenuItem(Menu, SC_MAXIMIZE, MF_BYCOMMAND or Enabled[((Style and WS_MAXIMIZEBOX) <> 0) and not Maximized]);
  EnableMenuItem(Menu, SC_CLOSE, MF_BYCOMMAND or MF_ENABLED);
  SetMenuDefaultItem(Menu, SC_CLOSE, 0);
  Flags := TPM_RETURNCMD or TPM_RIGHTBUTTON;
  if GetSystemMetrics(SM_MENUDROPALIGNMENT) <> 0 then
    Flags := Flags or TPM_RIGHTALIGN;
  Command := TrackPopupMenu(Menu, Flags, AScreenPx.X, AScreenPx.Y, 0, FWnd, nil);
  if Command then
    PostMessage(FWnd, WM_SYSCOMMAND, WPARAM(Integer(Command)), 0);
end;

{ Painting }

procedure TFmrWinFrame.HostInvalidated(const ARect: TRectF);
begin
  if IsNCMode then
    PostPaint;
end;

procedure TFmrWinFrame.PostPaint;
begin
  if FPaintPosted or (FWnd = 0) or (WM_FMR_NCPAINT = 0) then
    Exit;
  FPaintPosted := PostMessage(FWnd, WM_FMR_NCPAINT, 0, 0);
end;

procedure TFmrWinFrame.FreeDib;
begin
  if FDibDC <> 0 then
  begin
    DeleteDC(FDibDC);
    FDibDC := 0;
  end;
  if FDib <> 0 then
  begin
    DeleteObject(FDib);
    FDib := 0;
  end;
  FDibBits := nil;
  FDibSize := TSize.Create(0, 0);
end;

procedure TFmrWinFrame.EnsureDib(const AWidth, AHeight: Integer);
var
  Info: TBitmapInfo;
begin
  if (FDib <> 0) and (FDibSize.cx = AWidth) and (FDibSize.cy = AHeight) then
    Exit;
  FreeDib;
  FillChar(Info, SizeOf(Info), 0);
  Info.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  Info.bmiHeader.biWidth := AWidth;
  Info.bmiHeader.biHeight := -AHeight;
  Info.bmiHeader.biPlanes := 1;
  Info.bmiHeader.biBitCount := 32;
  Info.bmiHeader.biCompression := BI_RGB;
  FDib := CreateDIBSection(0, Info, DIB_RGB_COLORS, FDibBits, 0, 0);
  if FDib = 0 then
    Exit;
  FDibDC := CreateCompatibleDC(0);
  SelectObject(FDibDC, FDib);
  FDibSize := TSize.Create(AWidth, AHeight);
end;

procedure TFmrWinFrame.CopyToDib(const ABitmap: TBitmap);
var
  Data: TBitmapData;
  Y, W, H: Integer;
  Dest: PByte;
begin
  W := Min(ABitmap.Width, FDibSize.cx);
  H := Min(ABitmap.Height, FDibSize.cy);
  if (W <= 0) or (H <= 0) or (FDibBits = nil) then
    Exit;
  if ABitmap.Map(TMapAccess.Read, Data) then
  try
    for Y := 0 to H - 1 do
    begin
      Dest := PByte(FDibBits) + Y * FDibSize.cx * 4;
      if Data.PixelFormat = TPixelFormat.BGRA then
        Move(Data.GetScanline(Y)^, Dest^, W * 4)
      else
        ScanlineToAlphaColor(Data.GetScanline(Y), PAlphaColor(Dest), W, Data.PixelFormat);
    end;
  finally
    ABitmap.Unmap(Data);
  end;
end;

procedure TFmrWinFrame.PaintStrip(const ADC: HDC);
var
  R: TRect;
  Bitmap: TBitmap;
begin
  if (Frame.Host = nil) or not Frame.Host.OwnScene then
    Exit;
  R := StripRectInWindow;
  if (R.Width <= 0) or (R.Height <= 0) then
    Exit;
  Bitmap := Frame.Host.PaintBuffer(R.Width, R.Height, GetScale);
  EnsureDib(R.Width, R.Height);
  if FDibDC = 0 then
    Exit;
  CopyToDib(Bitmap);
  BitBlt(ADC, R.Left, R.Top, R.Width, R.Height, FDibDC, 0, 0, SRCCOPY);
end;

procedure TFmrWinFrame.PaintNC;
var
  DC: HDC;
begin
  if not IsNCMode or (FWnd = 0) or FInPaint or IsIconic(FWnd) or not IsWindowVisible(FWnd) then
    Exit;
  FInPaint := True;
  try
    DC := GetWindowDC(FWnd);
    if DC <> 0 then
    try
      PaintStrip(DC);
    finally
      ReleaseDC(FWnd, DC);
    end;
  finally
    FInPaint := False;
  end;
end;

procedure TFmrWinFrame.DoNCPaint(const ARegion: HRGN);
begin
  // A window with WS_CAPTION must pass WM_NCPAINT to the default procedure unchanged: if it does not (or passes
  // another region), Windows 11 turns the DWM frame rendering off for it (classic "basic" frame, no shadow). The
  // default procedure leaves the extra non-client strip alone; it is painted right after. Without WS_CAPTION
  // (FullNC) DWM keeps rendering the border without the default call.
  if (GetWindowLong(FWnd, GWL_STYLE) and WS_CAPTION) = WS_CAPTION then
    DefSubclassProc(FWnd, WM_NCPAINT, WPARAM(ARegion), 0);
  PaintNC;
end;

{ Frame state }

procedure TFmrWinFrame.ApplyWindowStyle;
var
  Style: NativeInt;
  WantRemoved: Boolean;
begin
  Style := GetWindowLong(FWnd, GWL_STYLE);
  // FullNC: DWM would draw its caption over the strip. Dwm with a backdrop: the frame is extended over the whole
  // window, and DWM draws its caption buttons over the caption content of a window with WS_CAPTION.
  // (Once removed, WS_CAPTION is no longer in Style: the decision must not depend on it, otherwise every later
  // FrameChanged - CaptionHeight, colors, dark mode - would put the caption style back.)
  WantRemoved := ((FMode = TFmrFrameMode.FullNC) and (FmrWinFullNCStrategy = TFmrWinFullNCStrategy.NoCaptionStyle)) or
    ((FMode = TFmrFrameMode.Dwm) and (Frame.Backdrop <> TFmrFrameBackdrop.None));
  if WantRemoved and not FCaptionStyleRemoved and ((Style and WS_CAPTION) = WS_CAPTION) then
  begin
    // A fixed size window (BorderStyle Single) gets a sizing frame for the DWM border and shadow; IsResizable keeps
    // it from being resized.
    FThickFrameAdded := (Style and WS_THICKFRAME) = 0;
    SetWindowLong(FWnd, GWL_STYLE, (Style and not WS_CAPTION) or WS_THICKFRAME);
    FCaptionStyleRemoved := True;
  end
  else if not WantRemoved and FCaptionStyleRemoved then
    RestoreWindowStyle;
end;

procedure TFmrWinFrame.RestoreWindowStyle;
var
  Style: NativeInt;
begin
  if FCaptionStyleRemoved then
  begin
    Style := GetWindowLong(FWnd, GWL_STYLE) or WS_CAPTION;
    if FThickFrameAdded then
      Style := Style and not WS_THICKFRAME;
    SetWindowLong(FWnd, GWL_STYLE, Style);
    FCaptionStyleRemoved := False;
    FThickFrameAdded := False;
  end;
end;

procedure TFmrWinFrame.ApplyDwmAttributes;
var
  Dark: BOOL;
  Corner, Backdrop: DWORD;
  Margins: TMargins;
begin
  Dark := Frame.DarkMode;
  if Failed(DwmSetWindowAttribute(FWnd, DWMWA_USE_IMMERSIVE_DARK_MODE_NEW, @Dark, SizeOf(Dark))) then
    DwmSetWindowAttribute(FWnd, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, @Dark, SizeOf(Dark));

  Corner := DWMWCP_DEFAULT;
  if FMode <> TFmrFrameMode.NCStrip then
    Corner := DWMWCP_ROUND;
  DwmSetWindowAttribute(FWnd, DWMWA_WINDOW_CORNER_PREF, @Corner, SizeOf(Corner));

  Backdrop := DWMSBT_AUTO;
  FillChar(Margins, SizeOf(Margins), 0);
  if (FMode = TFmrFrameMode.Dwm) and (Frame.Backdrop <> TFmrFrameBackdrop.None) then
  begin
    case Frame.Backdrop of
      TFmrFrameBackdrop.Mica: Backdrop := DWMSBT_MAINWINDOW;
      TFmrFrameBackdrop.Acrylic: Backdrop := DWMSBT_TRANSIENTWINDOW;
      TFmrFrameBackdrop.Tabbed: Backdrop := DWMSBT_TABBEDWINDOW;
    end;
    // Sheet of glass: the material shows wherever FMX leaves the client area transparent.
    Margins.cxLeftWidth := -1;
    Margins.cxRightWidth := -1;
    Margins.cyTopHeight := -1;
    Margins.cyBottomHeight := -1;
  end;
  DwmSetWindowAttribute(FWnd, DWMWA_SYSTEMBACKDROP, @Backdrop, SizeOf(Backdrop));
  DwmExtendFrameIntoClientArea(FWnd, Margins);
  ApplyCaptionColor;
end;

procedure TFmrWinFrame.ApplyCaptionColor;
var
  Color: TAlphaColor;
  Ref: DWORD;
begin
  // Without WS_CAPTION, DWM (Windows 11) paints the top sizing border above the strip with its caption color: make
  // it the color of the strip so the frame looks like one piece.
  Ref := DWMWA_COLOR_DEFAULT;
  if (FMode = TFmrFrameMode.FullNC) and FCaptionStyleRemoved and (Frame.Host <> nil) then
  begin
    if not FActive and (Frame.Host.InactiveFillColor <> TAlphaColors.Null) then
      Color := Frame.Host.InactiveFillColor
    else
      Color := Frame.Host.FillColor;
    if (Color and $FF000000) <> 0 then
      Ref := TAlphaColorRec(Color).R or (TAlphaColorRec(Color).G shl 8) or (TAlphaColorRec(Color).B shl 16);
  end;
  DwmSetWindowAttribute(FWnd, DWMWA_CAPTION_COLOR_ATTR, @Ref, SizeOf(Ref));
end;

procedure TFmrWinFrame.ResetDwmAttributes;
var
  Corner, Backdrop, Color: DWORD;
  Margins: TMargins;
begin
  Corner := DWMWCP_DEFAULT;
  DwmSetWindowAttribute(FWnd, DWMWA_WINDOW_CORNER_PREF, @Corner, SizeOf(Corner));
  Backdrop := DWMSBT_AUTO;
  DwmSetWindowAttribute(FWnd, DWMWA_SYSTEMBACKDROP, @Backdrop, SizeOf(Backdrop));
  FillChar(Margins, SizeOf(Margins), 0);
  DwmExtendFrameIntoClientArea(FWnd, Margins);
  Color := DWMWA_COLOR_DEFAULT;
  DwmSetWindowAttribute(FWnd, DWMWA_CAPTION_COLOR_ATTR, @Color, SizeOf(Color));
end;

procedure TFmrWinFrame.ApplyFormFill;
var
  Form: TCustomForm;
  Want: Boolean;
begin
  if not (Frame.Form is TCustomForm) then
    Exit;
  Form := TCustomForm(Frame.Form);
  Want := (FMode = TFmrFrameMode.Dwm) and (Frame.Backdrop <> TFmrFrameBackdrop.None);
  if Want and not FFillSaved then
  begin
    FSavedFillKind := Form.Fill.Kind;
    FSavedFillColor := Form.Fill.Color;
    FFillSaved := True;
    // A solid transparent fill clears the client area with alpha 0 and skips the style background.
    Form.Fill.Kind := TBrushKind.Solid;
    Form.Fill.Color := TAlphaColors.Null;
  end
  else if not Want then
    RestoreFormFill;
end;

procedure TFmrWinFrame.RestoreFormFill;
var
  Form: TCustomForm;
begin
  if not FFillSaved then
    Exit;
  FFillSaved := False;
  if Frame.Form is TCustomForm then
  begin
    Form := TCustomForm(Frame.Form);
    Form.Fill.Kind := FSavedFillKind;
    Form.Fill.Color := FSavedFillColor;
  end;
end;

procedure TFmrWinFrame.FrameChanged;
begin
  if not FAttached or FChangingFrame then
    Exit;
  FChangingFrame := True;
  try
    FMode := Frame.Mode;
    ApplyWindowStyle;
    Frame.ApplyHostColors;
    ApplyDwmAttributes;
    ApplyFormFill;
    SetWindowPos(FWnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or
      SWP_NOACTIVATE or SWP_NOOWNERZORDER);
    UpdateLayout;
    UpdateFrameState;
    RedrawWindow(FWnd, nil, 0, RDW_FRAME or RDW_INVALIDATE or RDW_UPDATENOW);
  finally
    FChangingFrame := False;
  end;
end;

procedure TFmrWinFrame.UpdateLayout;
var
  ClientRect: TRect;
  Scale: Single;
  Host: TFmrFrameHost;
begin
  Host := Frame.Host;
  if (Host = nil) or (csDestroying in Host.ComponentState) then
    Exit;
  Scale := GetScale;
  if IsNCMode then
  begin
    Winapi.Windows.GetClientRect(FWnd, ClientRect);
    Frame.PlaceHostInNonClient(ClientRect.Width / Scale, CaptionPx / Scale);
    PostPaint;
  end
  else
    Frame.PlaceHostInClient(CaptionPx / Scale);
end;

procedure TFmrWinFrame.UpdateFrameState;
var
  State: TFmrFrameState;
begin
  if FWnd = 0 then
    Exit;
  State := Frame.State;
  State.Active := FActive;
  State.Maximized := IsMaximized;
  State.Minimized := IsIconic(FWnd);
  State.MaximizedTopOffset := 0;
  if (State.Active <> Frame.State.Active) or (State.Maximized <> Frame.State.Maximized) or
    (State.Minimized <> Frame.State.Minimized) or (State.Mode <> FMode) or (Frame.State.Mode <> Frame.Mode) or
    (Frame.State.DarkMode <> Frame.DarkMode) or FChangingFrame then
    Frame.UpdateState(State);
end;

initialization
  WM_FMR_NCPAINT := RegisterWindowMessage('FMR.Frame.NCPaint');
  FmrFramePlatformClass := TFmrWinFrame;

finalization
  if FmrFramePlatformClass = TFmrWinFrame then
    FmrFramePlatformClass := nil;

{$ENDIF}

end.
