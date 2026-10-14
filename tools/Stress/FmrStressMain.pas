unit FmrStressMain;

/// Stress and robustness checks of the real TFmrRibbon on real windows (the DUnitX tests cover the model only):
///   - loops: themes switched many times, frame modes and maximize/restore, popups and key tips opened and closed,
///     display modes (minimized, simplified, touch, right to left, auto-hide), with GDI/USER handle and heap
///     measurements before and after (growth = leak);
///   - destroy paths: ribbon or bar manager freed first, BarManager set to nil, items/groups/tabs deleted while their
///     views are hot, pressed or shown in open popups, the form closed with popups open, the frame or the
///     application menu freed, unknown theme names, StyleBook changes.
/// Command line: /log=<file> /only=<name>[,<name>...] /loops=N /keep (stay open at the end)
/// Exit code: number of failed checks. Debug builds also report leaks on exit (ReportMemoryLeaksOnShutdown).

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Memo, FMX.StdCtrls, FMX.Layouts, FMX.Graphics, FMR.Frame.Types, FMR.Frame,
  FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Types, FMR.Ribbon.Structure, FMR.Ribbon, FMR.Ribbon.Theme,
  FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.Templates, FMR.Ribbon.Strings, FMR.Ribbon.Backstage,
  FMR.Ribbon.StatusBar, FMR.Ribbon.MiniToolbar, FMR.Ribbon.RadialMenu, FMR.Ribbon.AppMenu;

type
  TStressForm = class(TForm)
  private
    FLog: TStringList;
    FLogFile: string;
    FLoops: Integer;
    FRepeat: Integer;
    FClearStyleCache: Boolean;
    FOnly: TArray<string>;
    FKeep: Boolean;
    FTimer: TTimer;
    FScenario: string;
    procedure Start(Sender: TObject);
    procedure Log(const S: string);
    procedure Fail(const S: string);
    procedure Check(const ACondition: Boolean; const AWhat: string);
    procedure AppException(Sender: TObject; E: Exception);
    function Selected(const AName: string): Boolean;
    procedure Run(const AName: string; const AProc: TProc; const ALeakCheck: Boolean = True);
    procedure RunAll;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  StressForm: TStressForm;
  StressFailures: Integer;

implementation

uses
  Winapi.Windows, Winapi.Messages, Winapi.PsAPI, System.Math, System.Messaging, FMX.Styles, FMX.Platform,
  FMX.Platform.Win, FmrStackTrace;

type
  TControlAccess = class(TControl);

  /// A form with a frame, a bar manager, a ribbon built from the Word template and a memo.
  TTestWindow = class
  public
    Form: TForm;
    Frame: TFmrFormFrame;
    Manager: TFmrBarManager;
    Ribbon: TFmrRibbon;
    Memo: TMemo;
    constructor Create(const AFrame: Boolean; const AWidth: Integer = 1100; const AHeight: Integer = 480;
      const ATemplate: TFmrRibbonTemplate = TFmrRibbonTemplate.Word);
    destructor Destroy; override;
    function Item(const AName: string): TFmrBarItem;
    function ViewOf(const AName: string): TFmrItemView;
    function FindNode(const AId: string; out ANode: TFmrAccNode): Boolean; overload;
    function FindNode(const ARole: TFmrAccRole; out ANode: TFmrAccNode): Boolean; overload;
    /// Opens the drop-down of the first view of an item like a mouse press on its arrow.
    function DropDown(const AName: string): Boolean;
    function Invoke(const AId: string): Boolean;
    /// Mouse over / down / up on the view of an item (through its host part).
    function MouseAt(const AName: string; const ADown, AUp: Boolean): Boolean;
  end;

procedure Pump(const AMs: Integer = 0);
var
  T: Cardinal;
  Done: Boolean;
begin
  T := TThread.GetTickCount;
  repeat
    Application.ProcessMessages;
    CheckSynchronize;
    Done := True;
    Application.DoIdle(Done);
    Application.ProcessMessages;
    if AMs > 0 then
      Sleep(5);
  until TThread.GetTickCount - T >= Cardinal(AMs);
end;

function HeapBytes: Int64;
var
  S: TMemoryManagerState;
  I: Integer;
begin
  {$WARN SYMBOL_PLATFORM OFF}
  GetMemoryManagerState(S);
  {$WARN SYMBOL_PLATFORM ON}
  Result := Int64(S.TotalAllocatedMediumBlockSize) + Int64(S.TotalAllocatedLargeBlockSize);
  for I := Low(S.SmallBlockTypeStates) to High(S.SmallBlockTypeStates) do
    Result := Result + Int64(S.SmallBlockTypeStates[I].UseableBlockSize) * Int64(S.SmallBlockTypeStates[I].AllocatedBlockCount);
end;

type
  TSnapshot = record
    Gdi, User, Kernel: Integer;
    Heap: Int64;
    WorkingSet: Int64;
    class function Take: TSnapshot; static;
    function Diff(const AFrom: TSnapshot): string;
  end;

class function TSnapshot.Take: TSnapshot;
var
  H: DWORD;
  Mem: TProcessMemoryCountersEx;
begin
  Result.Gdi := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
  Result.User := GetGuiResources(GetCurrentProcess, GR_USEROBJECTS);
  H := 0;
  GetProcessHandleCount(GetCurrentProcess, H);
  Result.Kernel := H;
  Result.Heap := HeapBytes;
  FillChar(Mem, SizeOf(Mem), 0);
  Mem.cb := SizeOf(Mem);
  if GetProcessMemoryInfo(GetCurrentProcess, @Mem, SizeOf(Mem)) then
    Result.WorkingSet := Mem.WorkingSetSize
  else
    Result.WorkingSet := 0;
end;

function Signed(const V: Int64): string;
begin
  if V > 0 then
    Result := '+' + IntToStr(V)
  else
    Result := IntToStr(V);
end;

function TSnapshot.Diff(const AFrom: TSnapshot): string;
begin
  Result := Format('gdi %d->%d (%s), user %d->%d (%s), handles %s, heap %s KB, ws %s KB',
    [AFrom.Gdi, Gdi, Signed(Gdi - AFrom.Gdi), AFrom.User, User, Signed(User - AFrom.User),
     Signed(Kernel - AFrom.Kernel), Signed((Heap - AFrom.Heap) div 1024),
     Signed((WorkingSet - AFrom.WorkingSet) div 1024)]);
end;

function ShortStack(const E: Exception): string;
var
  L: TArray<string>;
  I: Integer;
begin
  Result := '';
  L := E.StackTrace.Split([sLineBreak], TStringSplitOptions.ExcludeEmpty);
  for I := 0 to Min(High(L), {$IFDEF CPUX86}45{$ELSE}15{$ENDIF}) do
    Result := Result + sLineBreak + L[I];
  if E is EInvalidPointer then
    Result := Result + sLineBreak + '    bad free:' + sLineBreak + FmrLastBadFree.TrimRight;
end;

{ TTestWindow }

constructor TTestWindow.Create(const AFrame: Boolean; const AWidth, AHeight: Integer;
  const ATemplate: TFmrRibbonTemplate);
begin
  inherited Create;
  Form := TForm.CreateNew(nil);
  Form.Caption := 'FMR stress';
  Form.SetBounds(60, 60, AWidth, AHeight);
  if AFrame then
    Frame := TFmrFormFrame.Create(Form);
  Manager := TFmrBarManager.Create(Form);
  Manager.Parent := Form;
  Ribbon := TFmrRibbon.Create(Form);
  Ribbon.Parent := Form;
  Ribbon.BarManager := Manager;
  Ribbon.ShowSearchBox := True;
  Ribbon.ShowDisplayOptionsButton := True;
  Ribbon.ShowDisplayModeButton := True;
  Ribbon.BeginStructureUpdate;
  try
    FmrApplyRibbonTemplate(Ribbon, ATemplate, Manager);
  finally
    Ribbon.EndStructureUpdate;
  end;
  Memo := TMemo.Create(Form);
  Memo.Parent := Form;
  Memo.Align := TAlignLayout.Client;
  Memo.Lines.Text := 'Stress';
  Form.Show;
  Pump(150);
end;

destructor TTestWindow.Destroy;
begin
  Form.Free;
  inherited;
end;

function TTestWindow.Item(const AName: string): TFmrBarItem;
begin
  Result := nil;
  if Manager <> nil then
    Result := Manager.FindItem(AName);
end;

function TTestWindow.ViewOf(const AName: string): TFmrItemView;
var
  I: Integer;
  It: TFmrBarItem;
begin
  Result := nil;
  It := Item(AName);
  if It = nil then
    Exit;
  for I := 0 to It.LinkCount - 1 do
    if It.Links[I].ViewObject is TFmrItemView then
      Exit(TFmrItemView(It.Links[I].ViewObject));
end;

function TTestWindow.FindNode(const AId: string; out ANode: TFmrAccNode): Boolean;
var
  N: TFmrAccNode;
begin
  Ribbon.UpdateLayout;
  for N in Ribbon.AccessibilityNodes do
    if SameText(N.AutomationId, AId) then
    begin
      ANode := N;
      Exit(True);
    end;
  Result := False;
end;

function TTestWindow.FindNode(const ARole: TFmrAccRole; out ANode: TFmrAccNode): Boolean;
var
  N: TFmrAccNode;
begin
  Ribbon.UpdateLayout;
  for N in Ribbon.AccessibilityNodes do
    if (N.Role = ARole) and (N.Element <> nil) then
    begin
      ANode := N;
      Exit(True);
    end;
  Result := False;
end;

function TTestWindow.DropDown(const AName: string): Boolean;
var
  V: TFmrItemView;
begin
  Ribbon.UpdateLayout;
  V := ViewOf(AName);
  Result := (V <> nil) and (V.Host <> nil);
  if Result then
    V.Host.ElementDropDown(V, False);
  Pump(30);
end;

function TTestWindow.Invoke(const AId: string): Boolean;
var
  N: TFmrAccNode;
begin
  Result := FindNode(AId, N) and Ribbon.AccessibilityInvoke(N.Element);
  Pump(30);
end;

function TTestWindow.MouseAt(const AName: string; const ADown, AUp: Boolean): Boolean;
var
  V: TFmrItemView;
  C: TControl;
  P: TPointF;
begin
  Ribbon.UpdateLayout;
  V := ViewOf(AName);
  Result := (V <> nil) and (V.Host <> nil) and V.Visible;
  if not Result then
    Exit;
  C := V.Host.GetHostControl;
  P := V.Bounds.CenterPoint;
  TControlAccess(C).MouseMove([], P.X, P.Y);
  if ADown then
    TControlAccess(C).MouseDown(TMouseButton.mbLeft, [ssLeft], P.X, P.Y);
  if AUp then
    TControlAccess(C).MouseUp(TMouseButton.mbLeft, [], P.X, P.Y);
end;

{ TStressForm }

constructor TStressForm.Create(AOwner: TComponent);
var
  I: Integer;
  S: string;
begin
  inherited CreateNew(AOwner);
  Caption := 'FMR stress runner';
  SetBounds(10, 10, 420, 120);
  FLog := TStringList.Create;
  FLoops := 50;
  FRepeat := 1;
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if S.StartsWith('/log=', True) then
      FLogFile := S.Substring(5)
    else if S.StartsWith('/only=', True) then
      FOnly := S.Substring(6).ToLower.Split([','])
    else if S.StartsWith('/loops=', True) then
      FLoops := StrToIntDef(S.Substring(7), 50)
    else if S.StartsWith('/repeat=', True) then
      FRepeat := StrToIntDef(S.Substring(8), 1)
    else if S.StartsWith('/repeat=', True) then
      FRepeat := StrToIntDef(S.Substring(8), 1)
    else if SameText(S, '/clearstylecache') then
      FClearStyleCache := True
    else if SameText(S, '/keep') then
      FKeep := True;
  end;
  if FLogFile = '' then
    FLogFile := ChangeFileExt(ParamStr(0), '.log');
  Application.OnException := AppException;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 300;
  FTimer.OnTimer := Start;
end;

destructor TStressForm.Destroy;
begin
  FLog.Free;
  inherited;
end;

procedure TStressForm.Log(const S: string);
begin
  FLog.Add(S);
  FLog.SaveToFile(FLogFile, TEncoding.UTF8);
end;

procedure TStressForm.Fail(const S: string);
begin
  Inc(StressFailures);
  Log('FAIL [' + FScenario + '] ' + S);
end;

procedure TStressForm.Check(const ACondition: Boolean; const AWhat: string);
begin
  if not ACondition then
    Fail(AWhat);
end;

procedure TStressForm.AppException(Sender: TObject; E: Exception);
begin
  Fail('unhandled ' + E.ClassName + ': ' + E.Message + ShortStack(E));
end;

function TStressForm.Selected(const AName: string): Boolean;
var
  S: string;
begin
  if Length(FOnly) = 0 then
    Exit(True);
  for S in FOnly do
    if SameText(S, AName) then
      Exit(True);
  Result := False;
end;

/// Contents of FMX's global style cache (TStyleCache, implementation-only): style names and counts.
function StyleCacheSummary: string;
var
  P: PPointer;
  Cache: Pointer;
  List: TList<TControl>;
  Counts: TDictionary<string, Integer>;
  C: TControl;
  K: string;
  N: Integer;
begin
  Result := '';
  P := FmrMapSymbol('FMX.Controls.TStyleCache.FCurrent');
  if P = nil then
    Exit('no map');
  Cache := P^;
  if Cache = nil then
    Exit('empty');
  // TStyleCache = class: FStyleList is the first field after the VMT pointer
  List := TList<TControl>(PPointer(NativeUInt(Cache) + SizeOf(Pointer))^);
  if List = nil then
    Exit('empty');
  Counts := TDictionary<string, Integer>.Create;
  try
    for C in List do
    begin
      K := C.TagString;
      while (K <> '') and CharInSet(K[High(K)], ['0'..'9']) do
        Delete(K, High(K), 1);
      K := K + ':' + C.ClassName;
      Counts.TryGetValue(K, N);
      Counts.AddOrSetValue(K, N + 1);
    end;
    Result := Format('%d cached', [List.Count]);
    for K in Counts.Keys do
      Result := Result + Format(', %s x%d', [K, Counts[K]]);
  finally
    Counts.Free;
  end;
end;

procedure TStressForm.Run(const AName: string; const AProc: TProc; const ALeakCheck: Boolean);
var
  S0, S1: TSnapshot;
  T: Cardinal;
  I: Integer;

  procedure Once;
  begin
    try
      AProc();
      Pump(50);
    except
      on E: Exception do
        Fail(E.ClassName + ': ' + E.Message + ShortStack(E));
    end;
    // closed popups are freed by the popup manager after 0.2 s
    Pump(350);
    if FClearStyleCache then
      TMessageManager.DefaultManager.SendMessage(nil, TBeforeStyleChangingMessage.Create, True);
  end;

begin
  if not Selected(AName) then
    Exit;
  FScenario := AName;
  T := TThread.GetTickCount;
  Log('== ' + AName);
  if ALeakCheck then
    Once;
  S0 := TSnapshot.Take;
  Once;
  S1 := TSnapshot.Take;
  for I := 2 to FRepeat do
  begin
    Log('   ' + S1.Diff(S0));
    Once;
    S1 := TSnapshot.Take;
  end;
  Log(Format('   %s (%d ms)', [S1.Diff(S0), TThread.GetTickCount - T]));
  Log('   style cache: ' + StyleCacheSummary);
  if ALeakCheck then
  begin
    Check(S1.Gdi - S0.Gdi <= 3, Format('GDI objects grew by %d', [S1.Gdi - S0.Gdi]));
    Check(S1.User - S0.User <= 3, Format('USER objects grew by %d', [S1.User - S0.User]));
    Check(S1.Heap - S0.Heap <= 128 * 1024, Format('heap grew by %d KB', [(S1.Heap - S0.Heap) div 1024]));
  end;
end;

procedure TStressForm.Start(Sender: TObject);
begin
  FTimer.Enabled := False;
  try
    RunAll;
  except
    on E: Exception do
      Fail('runner: ' + E.ClassName + ': ' + E.Message);
  end;
  Log(Format('done: %d failure(s)', [StressFailures]));
  if not FKeep then
    Close;
end;

procedure TStressForm.RunAll;
var
  Loops: Integer;
begin
  Loops := FLoops;

  Run('themes',
    procedure
    var
      W: TTestWindow;
      Names: TArray<string>;
      I: Integer;
    begin
      W := TTestWindow.Create(True);
      try
        Names := TFmrTheme.ThemeNames;
        for I := 0 to Loops - 1 do
        begin
          W.Ribbon.Theme := Names[I mod Length(Names)];
          if Odd(I) then
            W.Ribbon.AccentColor := $FF217346
          else
            W.Ribbon.AccentColor := 0;
          Pump(5);
        end;
        // with a popup open while the theme changes
        Check(W.DropDown('btnPaste'), 'paste drop-down');
        W.Ribbon.Theme := 'FluentDark';
        Pump(30);
        W.Ribbon.ClosePopups;
        W.Ribbon.ShowKeyTipsNow;
        W.Ribbon.Theme := 'Office2007Blue';
        Pump(30);
        W.Ribbon.HideKeyTips;
      finally
        W.Free;
      end;
    end);

  Run('theme-growth',
    procedure
    const
      Pairs: array[0..4, 0..1] of Integer = ((0, 1), (0, 10), (0, 2), (7, 8), (10, 13));
    var
      W: TTestWindow;
      Names: TArray<string>;
      I, P: Integer;
      H: Int64;
      Fr: Boolean;
    begin
      Names := TFmrTheme.ThemeNames;
      H := HeapBytes;
      for I := 0 to 39 do
        TFmrTheme.CreateTheme(Names[I mod 18]).Free;
      Log(Format('   CreateTheme x40: heap %s KB', [Signed((HeapBytes - H) div 1024)]));
      for Fr in [True, False] do
      begin
        W := TTestWindow.Create(Fr, 1100, 480, TFmrRibbonTemplate.Word);
        try
          if not Fr then
          begin
            W.Ribbon.ShowSearchBox := False;
            W.Ribbon.ShowDisplayOptionsButton := False;
            W.Ribbon.ShowDisplayModeButton := False;
            W.Memo.Visible := False;
          end;
          for P := 0 to High(Pairs) do
          begin
            for I := 0 to 3 do
            begin
              W.Ribbon.Theme := Names[Pairs[P, I mod 2]];
              Pump(5);
            end;
            H := HeapBytes;
            for I := 0 to 19 do
            begin
              W.Ribbon.Theme := Names[Pairs[P, I mod 2]];
              Pump(5);
            end;
            Log(Format('   frame %s %s <-> %s x20: heap %s KB', [BoolToStr(Fr, True), Names[Pairs[P, 0]],
              Names[Pairs[P, 1]], Signed((HeapBytes - H) div 1024)]));
          end;
          H := HeapBytes;
          for I := 0 to 39 do
          begin
            W.Ribbon.Theme := Names[Pairs[2, I mod 2]];
            W.Ribbon.UpdateLayout;
          end;
          Log(Format('   frame %s no paint x40: heap %s KB', [BoolToStr(Fr, True), Signed((HeapBytes - H) div 1024)]));
          Pump(200);
          Log(Format('   frame %s after pump: heap %s KB', [BoolToStr(Fr, True), Signed((HeapBytes - H) div 1024)]));
          H := HeapBytes;
          for I := 0 to 39 do
          begin
            W.Ribbon.Theme := Names[Pairs[2, I mod 2]];
            Pump(5);
          end;
          Log(Format('   frame %s paint x40: heap %s KB', [BoolToStr(Fr, True), Signed((HeapBytes - H) div 1024)]));
          H := HeapBytes;
          for I := 0 to 19 do
          begin
            W.Ribbon.TouchMode := not W.Ribbon.TouchMode;
            Pump(5);
          end;
          Log(Format('   frame %s touch x20: heap %s KB', [BoolToStr(Fr, True), Signed((HeapBytes - H) div 1024)]));
          H := HeapBytes;
          for I := 0 to 19 do
          begin
            W.Ribbon.AccentColor := TAlphaColor($FF000000 or Cardinal(Random($FFFFFF)));
            Pump(5);
          end;
          Log(Format('   frame %s accents x20: heap %s KB', [BoolToStr(Fr, True), Signed((HeapBytes - H) div 1024)]));
        finally
          W.Free;
        end;
      end;
    end, False);
  Run('window-cycle',
    procedure
    var
      W: TTestWindow;
      I, J: Integer;
    begin
      for J := 1 to 3 do
      begin
        W := TTestWindow.Create(True);
        try
          for I := 0 to W.Ribbon.TabCount - 1 do
            if W.Ribbon.Tabs(I).Visible then
            begin
              W.Ribbon.ActiveTab := W.Ribbon.Tabs(I);
              Pump(5);
            end;
          W.Ribbon.ActiveTab := W.Ribbon.Tabs(0);
          Pump(5);
        finally
          W.Free;
        end;
      end;
    end);

  Run('frames',
    procedure
    var
      W: TTestWindow;
      I: Integer;
    begin
      W := TTestWindow.Create(True);
      try
        for I := 0 to Loops div 2 - 1 do
        begin
          W.Frame.Mode := TFmrFrameMode(I mod 3);
          Pump(10);
          if I mod 5 = 0 then
          begin
            W.Form.WindowState := TWindowState.wsMaximized;
            Pump(30);
            W.Form.WindowState := TWindowState.wsNormal;
            Pump(30);
          end;
        end;
        W.Frame.Mode := TFmrFrameMode.FullNC;
        Pump(20);
        Check(W.Frame.Hooked, 'frame hooked after mode switches');
        Check(W.Ribbon.TabBar.Parent = W.Frame.Host, 'tab bar in the frame host');
        W.Frame.Enabled := False;
        Pump(20);
        W.Frame.Enabled := True;
        Pump(20);
        Check(W.Frame.Hooked, 'frame hooked after Enabled off/on');
      finally
        W.Free;
      end;
    end);

  Run('menus',
    procedure
    var
      W: TTestWindow;
      I: Integer;
      N: TFmrAccNode;
    begin
      W := TTestWindow.Create(True, 640);
      try
        for I := 0 to Loops - 1 do
        begin
          case I mod 8 of
            0: W.DropDown('btnPaste');
            1: W.DropDown('clrFontColor');
            2: W.DropDown('galStyles');
            3: W.DropDown('btnChangeCase');
            4: if W.FindNode(TFmrAccRole.CollapsedGroup, N) then
                 W.Ribbon.AccessibilityInvoke(N.Element);
            5: W.Invoke('QATCustomize');
            6: begin
                 W.Ribbon.ShowKeyTipsNow;
                 Pump(10);
                 W.Ribbon.HideKeyTips;
               end;
            7: W.Invoke('DisplayOptions');
          end;
          Pump(10);
          W.Ribbon.ClosePopups;
          Pump(5);
        end;
        Check(not FmrPopups.IsOpen, 'no popup open after the loop');
      finally
        W.Free;
      end;
    end);

  Run('modes',
    procedure
    var
      W: TTestWindow;
      I: Integer;
      N: TFmrAccNode;
    begin
      W := TTestWindow.Create(True);
      try
        for I := 0 to Loops div 2 - 1 do
        begin
          case I mod 7 of
            0: begin
                 W.Ribbon.Minimized := True;
                 Pump(10);
                 if W.FindNode(TFmrAccRole.Tab, N) then
                   W.Ribbon.AccessibilityInvoke(N.Element);
                 Pump(10);
                 W.Ribbon.Minimized := False;
               end;
            1: W.Ribbon.DisplayMode := TFmrRibbonDisplayMode.Simplified;
            2: W.Ribbon.DisplayMode := TFmrRibbonDisplayMode.Classic;
            3: W.Ribbon.TouchMode := not W.Ribbon.TouchMode;
            4: W.Ribbon.RightToLeft := not W.Ribbon.RightToLeft;
            5: begin
                 W.Ribbon.ShowMode := TFmrRibbonShowMode.AutoHide;
                 Pump(10);
                 W.Ribbon.ShowAutoHiddenRibbon;
                 Pump(10);
                 W.Ribbon.ShowMode := TFmrRibbonShowMode.TabsAndCommands;
               end;
            6: if W.Ribbon.QuickAccessToolbar.Position = TFmrQATPosition.AboveRibbon then
                 W.Ribbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon
               else
                 W.Ribbon.QuickAccessToolbar.Position := TFmrQATPosition.AboveRibbon;
          end;
          Pump(10);
          W.Ribbon.ClosePopups;
        end;
        W.Form.Width := 380;
        Pump(30);
        W.Form.Width := 1600;
        Pump(30);
        FmrSetLanguage('ru');
        Pump(20);
        FmrSetLanguage('en');
        Pump(20);
      finally
        W.Free;
      end;
    end);

  Run('focus-restore',
    procedure
    var
      W: TTestWindow;
      H: HWND;

      function FocusName: string;
      begin
        if W.Form.Focused = nil then
          Result := 'nil'
        else
          Result := W.Form.Focused.GetObject.ClassName;
      end;

    begin
      W := TTestWindow.Create(True);
      try
        H := FmxHandleToHWND(W.Form.Handle);
        W.Memo.SetFocus;
        Pump(20);
        Check(W.Form.Focused = IControl(W.Memo), 'memo focused at start: ' + FocusName);
        W.DropDown('btnPaste');
        Check(FmrPopups.IsOpen, 'menu open');
        W.Ribbon.ClosePopups;
        Pump(30);
        Check(W.Form.Focused = IControl(W.Memo), 'memo focused after ClosePopups: ' + FocusName);
        W.Ribbon.ShowKeyTipsNow;
        Pump(20);
        W.Ribbon.HideKeyTips;
        Pump(30);
        Check(W.Form.Focused = IControl(W.Memo), 'memo focused after key tips: ' + FocusName);
        // The window is deactivated while a menu is open (Alt+Tab): the menu closes, the editor keeps the focus.
        W.DropDown('btnPaste');
        Log('   before deactivation: open ' + BoolToStr(FmrPopups.IsOpen, True) + ', focus ' + FocusName);
        SendMessage(H, WM_ACTIVATE, WA_INACTIVE, 0);
        Log('   after WM_ACTIVATE: open ' + BoolToStr(FmrPopups.IsOpen, True) + ', focus ' + FocusName);
        SendMessage(H, WM_ACTIVATEAPP, 0, 0);
        Log('   after WM_ACTIVATEAPP: open ' + BoolToStr(FmrPopups.IsOpen, True) + ', focus ' + FocusName);
        Pump(60);
        Log('   after pump: open ' + BoolToStr(FmrPopups.IsOpen, True) + ', focus ' + FocusName);
        W.Ribbon.ClosePopups;
        Pump(30);
        Check(W.Form.Focused = IControl(W.Memo), 'memo focused after deactivation: ' + FocusName);
        SendMessage(H, WM_ACTIVATE, WA_ACTIVE, 0);
        Pump(30);
        W.Ribbon.ShowKeyTipsNow;
        Pump(20);
        SendMessage(H, WM_ACTIVATE, WA_INACTIVE, 0);
        Pump(60);
        Check(not W.Ribbon.KeyTipsVisible, 'key tips hidden on deactivation');
        Check(W.Form.Focused = IControl(W.Memo), 'memo focused after deactivation with key tips: ' + FocusName);
      finally
        W.Free;
      end;
    end);

  Run('companions',
    procedure
    var
      Step: Integer;
      W: TTestWindow;
      BS: TFmrRibbonBackstageView;
      SB: TFmrStatusBar;
      Menu: TFmrPopupMenu;
      Mini: TFmrRibbonMiniToolbar;
      Radial: TFmrRibbonRadialMenu;
      App: TFmrRibbonApplicationMenu;
      P: TFmrStatusBarPanel;
      I: Integer;
      Names: TArray<string>;
      Center: TPointF;
    begin
      Names := TFmrTheme.ThemeNames;
      for Step := 0 to 6 do
      begin
        W := TTestWindow.Create(True, 1000, 600);
        try
          BS := TFmrRibbonBackstageView.Create(W.Form);
          BS.Parent := W.Form;
          BS.BarManager := W.Manager;
          BS.AddTab('Info');
          BS.AddTab('Open');
          BS.AddButton('Save');
          BS.ThemeProvider := W.Ribbon;
          W.Ribbon.ApplicationMenu := BS;
          SB := TFmrStatusBar.Create(W.Form);
          SB.Parent := W.Form;
          SB.BarManager := W.Manager;
          SB.ThemeProvider := W.Ribbon;
          SB.AddPanel(TFmrStatusPanelKind.Text, 'Ready').Stretch := True;
          P := SB.AddPanel(TFmrStatusPanelKind.ItemLinks, '', TFmrStatusPanelSide.Right);
          P.ItemLinks.AddItem(W.Item('btnBold'));
          P.ItemLinks.AddItem(W.Item('btnItalic'));
          SB.AddPanel(TFmrStatusPanelKind.ZoomSlider, '', TFmrStatusPanelSide.Right);
          Menu := TFmrPopupMenu.Create(W.Form);
          Menu.Parent := W.Form;
          Menu.BarManager := W.Manager;
          Menu.ThemeSource := W.Ribbon;
          Menu.ItemLinks.AddItem(W.Item('btnCut'));
          Menu.ItemLinks.AddItem(W.Item('btnPaste'));
          Mini := TFmrRibbonMiniToolbar.Create(W.Form);
          Mini.Parent := W.Form;
          Mini.BarManager := W.Manager;
          Mini.ThemeSource := W.Ribbon;
          Mini.PopupMenu := Menu;
          Mini.ItemLinks.AddItem(W.Item('cmbFontName'));
          Mini.ItemLinks.AddItem(W.Item('btnBold'));
          Mini.ItemLinks.AddItem(W.Item('clrFontColor'));
          Radial := TFmrRibbonRadialMenu.Create(W.Form);
          Radial.Parent := W.Form;
          Radial.BarManager := W.Manager;
          Radial.ThemeSource := W.Ribbon;
          Radial.ItemLinks.AddItem(W.Item('btnBold'));
          Radial.ItemLinks.AddItem(W.Item('btnItalic'));
          App := TFmrRibbonApplicationMenu.Create(W.Form);
          App.Parent := W.Form;
          App.BarManager := W.Manager;
          App.ItemLinks.AddItem(W.Item('btnCut'));
          App.RecentDocuments.Add('A.docx', 'C:\A.docx', True);
          Pump(30);
          Center := W.Memo.LocalToScreen(PointF(200, 100));
          case Step of
            0:
              begin
                // themes with every companion listening to the ribbon
                for I := 0 to 17 do
                begin
                  W.Ribbon.Theme := Names[I mod Length(Names)];
                  Pump(5);
                end;
                W.Invoke('ApplicationButton');
                Pump(30);
                W.Ribbon.Theme := 'FluentDark';
                Pump(30);
                BS.Hide;
                Pump(20);
              end;
            1:
              begin
                // the theme provider goes away while the backstage is open
                W.Invoke('ApplicationButton');
                Pump(30);
                FreeAndNil(W.Ribbon);
                Pump(30);
                SB.Repaint;
                BS.Hide;
                Pump(30);
              end;
            2:
              begin
                Mini.Popup(Center, True);
                Pump(40);
                FreeAndNil(W.Manager);
                Pump(40);
                Mini.ClosePopup;
                Pump(20);
              end;
            3:
              begin
                Mini.Popup(Center, True);
                Pump(40);
                Menu.Free;
                Pump(40);
                Mini.Popup(Center, True);
                Pump(40);
                Mini.Free;
                Pump(40);
              end;
            4:
              begin
                Radial.Popup(Center);
                Pump(40);
                Radial.Free;
                Pump(40);
              end;
            5:
              begin
                W.Ribbon.ApplicationMenu := App;
                W.Invoke('ApplicationButton');
                Pump(40);
                App.Free;
                Pump(40);
                W.Invoke('ApplicationButton');
                Pump(40);
              end;
            6:
              begin
                W.Invoke('ApplicationButton');
                Pump(30);
                BS.Free;
                Pump(40);
                Check(W.Ribbon.ApplicationMenu = nil, 'backstage cleared from the ribbon');
                W.Ribbon.UpdateLayout;
                Check(W.Ribbon.TabBar.Visible, 'tab row back after the backstage was freed');
                SB.BarManager := nil;
                Pump(20);
                FreeAndNil(W.Manager);
                Pump(20);
              end;
          end;
        finally
          W.Free;
        end;
        Pump(30);
      end;
    end);

  Run('free-ribbon-first',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        W.DropDown('btnPaste');
        FreeAndNil(W.Ribbon);
        Pump(30);
        Check(not FmrPopups.IsOpen, 'popups closed with the ribbon');
        W.Manager.Items[0].Caption := 'x';
        Pump(10);
      finally
        W.Free;
      end;
    end);

  Run('free-manager-first',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        W.MouseAt('btnCut', False, False);
        W.DropDown('btnPaste');
        FreeAndNil(W.Manager);
        Pump(30);
        W.Ribbon.UpdateLayout;
        W.Ribbon.Repaint;
        Pump(30);
        Check(W.Ribbon.BarManager = nil, 'BarManager nil after the manager was freed');
        W.Ribbon.ShowKeyTipsNow;
        Pump(10);
        W.Ribbon.HideKeyTips;
      finally
        W.Free;
      end;
    end);

  Run('manager-nil',
    procedure
    var
      W: TTestWindow;
      Before: Integer;
    begin
      W := TTestWindow.Create(True);
      try
        Before := Length(W.Ribbon.AccessibilityNodes);
        W.MouseAt('btnCopy', True, False);
        W.Ribbon.BarManager := nil;
        Pump(30);
        W.Ribbon.BarManager := W.Manager;
        Pump(30);
        W.Ribbon.UpdateLayout;
        Check(Length(W.Ribbon.AccessibilityNodes) = Before, Format('nodes after reassigning the manager: %d, was %d',
          [Length(W.Ribbon.AccessibilityNodes), Before]));
      finally
        W.Free;
      end;
    end);

  Run('delete-hot-pressed-item',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        Check(W.MouseAt('btnCut', False, False), 'hover Cut');
        W.Item('btnCut').Free;
        Pump(20);
        Check(W.MouseAt('btnCopy', True, False), 'press Copy');
        W.Item('btnCopy').Free;
        Pump(20);
        TControlAccess(W.Ribbon.Body).MouseUp(TMouseButton.mbLeft, [], 30, 30);
        TControlAccess(W.Ribbon.Body).MouseMove([], 40, 40);
        Pump(20);
        // the item whose drop-down is open
        W.DropDown('btnPaste');
        W.Item('btnPaste').Free;
        Pump(30);
        // a QAT item
        W.Item('btnUndo').Free;
        Pump(20);
      finally
        W.Free;
      end;
    end);

  Run('delete-menu-row-item',
    procedure
    var
      W: TTestWindow;
      Top: TFmrPopupForm;
      C: TControl;
    begin
      W := TTestWindow.Create(True);
      try
        Check(W.DropDown('btnPaste'), 'paste menu');
        Top := FmrPopups.Top;
        Check(Top <> nil, 'menu open');
        W.Item('btnPasteKeepText').Free;
        Pump(20);
        if (Top <> nil) and FmrPopups.Contains(Top) then
        begin
          C := Top.Content;
          TControlAccess(C).MouseMove([], 20, 12);
          TControlAccess(C).MouseMove([], 20, 40);
          C.Repaint;
          Pump(30);
        end;
        W.Ribbon.ClosePopups;
        Pump(20);
        // the gallery drop-down: its commands below the entries
        Check(W.DropDown('galStyles'), 'styles drop-down');
        W.Item('btnApplyStyles').Free;
        Pump(30);
        W.Ribbon.ClosePopups;
      finally
        W.Free;
      end;
    end);

  Run('delete-group-tab-while-open',
    procedure
    var
      W: TTestWindow;
      N: TFmrAccNode;
      G: TFmrRibbonGroup;
    begin
      W := TTestWindow.Create(True, 600);
      try
        if W.FindNode(TFmrAccRole.CollapsedGroup, N) then
        begin
          G := TFmrRibbonGroup(N.Data);
          W.Ribbon.AccessibilityInvoke(N.Element);
          Pump(20);
          G.Free;
          Pump(30);
        end
        else
          Fail('no collapsed group at 600 px');
        W.DropDown('btnPaste');
        W.Ribbon.ActiveTab.Free;
        Pump(30);
        Check(W.Ribbon.ActiveTab <> nil, 'another tab active');
        W.Ribbon.ShowKeyTipsNow;
        Pump(10);
        W.Ribbon.ActiveTab.Free;
        Pump(30);
        W.Ribbon.HideKeyTips;
        // every tab
        while W.Ribbon.TabCount > 0 do
          W.Ribbon.Tabs(0).Free;
        Pump(30);
        Check(W.Ribbon.ActiveTab = nil, 'no active tab without tabs');
      finally
        W.Free;
      end;
    end);

  Run('clear-items',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        W.Ribbon.ShowKeyTipsNow;
        Pump(10);
        W.Manager.BeginUpdate;
        try
          while W.Manager.ItemCount > 0 do
            W.Manager.Items[0].Free;
        finally
          W.Manager.EndUpdate;
        end;
        Pump(30);
        W.Ribbon.HideKeyTips;
        W.Ribbon.UpdateLayout;
        Pump(20);
      finally
        W.Free;
      end;
    end);

  Run('unknown-theme',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        W.Ribbon.Theme := 'NoSuchTheme';
        Pump(20);
        Check(W.Ribbon.ThemeObject <> nil, 'theme object for an unknown name');
        W.Ribbon.Theme := '';
        Pump(20);
        W.Ribbon.AccentColor := TAlphaColors.Null;
        Pump(20);
        W.Ribbon.Theme := 'office2007black';
        Pump(20);
      finally
        W.Free;
      end;
    end);

  Run('stylebook',
    procedure
    const
      StyleText =
        'object TStyleContainer'#13#10 +
        '  object TBrushObject'#13#10 +
        '    StyleName = ''fmr_tab_row_fill'''#13#10 +
        '    Brush.Color = xFF8B0000'#13#10 +
        '  end'#13#10 +
        '  object TColorObject'#13#10 +
        '    StyleName = ''fmr_tab_text'''#13#10 +
        '    Color = xFFFFFF00'#13#10 +
        '  end'#13#10 +
        'end'#13#10;
    var
      W: TTestWindow;
      SB: TStyleBook;
      S: TStringStream;
    begin
      W := TTestWindow.Create(True);
      try
        SB := TStyleBook.Create(W.Form);
        S := TStringStream.Create(StyleText);
        try
          SB.LoadFromStream(S);
        finally
          S.Free;
        end;
        W.Form.StyleBook := SB;
        Pump(30);
        Check(W.Ribbon.ThemeObject.IsOverridden(TFmrToken.TabText), 'StyleBook token override applied');
        W.Form.StyleBook := nil;
        Pump(30);
        Check(not W.Ribbon.ThemeObject.IsOverridden(TFmrToken.TabText), 'override gone without the StyleBook');
        W.Form.StyleBook := SB;
        Pump(30);
        SB.Free;
        Pump(30);
        Check(not W.Ribbon.ThemeObject.IsOverridden(TFmrToken.TabText), 'override gone after the StyleBook was freed');
        W.Ribbon.Theme := 'FluentDark';
        Pump(20);
      finally
        W.Free;
      end;
    end);

  Run('close-with-popups',
    procedure
    var
      Kind: Integer;
      W: TTestWindow;
      N: TFmrAccNode;
    begin
      for Kind := 0 to 7 do
      begin
        W := TTestWindow.Create(True, 640);
        try
          case Kind of
            0: W.DropDown('btnPaste');
            1: W.DropDown('galStyles');
            2: if W.FindNode(TFmrAccRole.CollapsedGroup, N) then
                 W.Ribbon.AccessibilityInvoke(N.Element);
            3: begin
                 W.Ribbon.ShowKeyTipsNow;
                 Pump(10);
               end;
            4: begin
                 W.Ribbon.Minimized := True;
                 Pump(10);
                 if W.FindNode(TFmrAccRole.Tab, N) then
                   W.Ribbon.AccessibilityInvoke(N.Element);
               end;
            5: W.Invoke('QATCustomize');
            6: W.DropDown('clrFontColor');
            7: begin
                 W.Ribbon.SearchText := 'bo';
                 Pump(20);
               end;
          end;
          Pump(20);
          if Kind mod 2 = 0 then
          begin
            W.Form.Close;
            Pump(20);
          end;
        finally
          W.Free;
        end;
        Pump(20);
      end;
      Check(not FmrPopups.IsOpen, 'no popup open after closing the forms');
    end);

  Run('free-frame',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        W.DropDown('btnPaste');
        FreeAndNil(W.Frame);
        Pump(30);
        Check((W.Ribbon.TabBar <> nil) and (W.Ribbon.TabBar.Parent = W.Ribbon), 'tab bar back in the ribbon');
        W.Ribbon.UpdateLayout;
        Pump(20);
        W.Frame := TFmrFormFrame.Create(W.Form);
        Pump(30);
        W.Ribbon.UpdateLayout;
        Pump(20);
        Check((W.Ribbon.TabBar <> nil) and (W.Ribbon.TabBar.Parent = W.Frame.Host), 'tab bar in the new frame host');
      finally
        W.Free;
      end;
    end);

  Run('free-appmenu',
    procedure
    var
      W: TTestWindow;
      Menu: TFmrPopupMenu;
    begin
      W := TTestWindow.Create(True);
      try
        Menu := TFmrPopupMenu.Create(W.Form);
        Menu.Parent := W.Form;
        Menu.BarManager := W.Manager;
        Menu.ThemeSource := W.Ribbon;
        Menu.ItemLinks.AddItem(W.Item('btnCut'));
        Menu.ItemLinks.AddItem(W.Item('btnCopy'));
        W.Ribbon.ApplicationMenu := Menu;
        W.Invoke('ApplicationButton');
        Pump(20);
        Menu.Free;
        Pump(30);
        Check(W.Ribbon.ApplicationMenu = nil, 'ApplicationMenu cleared');
        W.Invoke('ApplicationButton');
        Pump(20);
        // a menu whose theme source (the ribbon) goes away
        Menu := TFmrPopupMenu.Create(W.Form);
        Menu.Parent := W.Form;
        Menu.BarManager := W.Manager;
        Menu.ThemeSource := W.Ribbon;
        Menu.ItemLinks.AddItem(W.Item('btnCut'));
        Menu.Popup(200, 200);
        Pump(20);
        FreeAndNil(W.Ribbon);
        Pump(30);
        Menu.Popup(220, 220);
        Pump(20);
        Menu.ClosePopup;
        FreeAndNil(W.Manager);
        Pump(20);
        Menu.Popup(220, 220);
        Pump(20);
        Menu.ClosePopup;
      finally
        W.Free;
      end;
    end);

  Run('free-ribbon-with-group-popup',
    procedure
    var
      W: TTestWindow;
      N: TFmrAccNode;
    begin
      W := TTestWindow.Create(True, 600);
      try
        if W.FindNode(TFmrAccRole.CollapsedGroup, N) then
          W.Ribbon.AccessibilityInvoke(N.Element);
        Pump(20);
        FreeAndNil(W.Ribbon);
        Pump(30);
      finally
        W.Free;
      end;
    end);

  Run('ribbon-in-layout',
    procedure
    var
      W: TTestWindow;
      L: TLayout;
      R: TFmrRibbon;
    begin
      W := TTestWindow.Create(False);
      try
        L := TLayout.Create(W.Form);
        L.Parent := W.Form;
        L.Align := TAlignLayout.Bottom;
        L.Height := 200;
        R := TFmrRibbon.Create(W.Form);
        R.Parent := L;
        R.BarManager := W.Manager;
        FmrApplyRibbonTemplate(R, TFmrRibbonTemplate.Simple, W.Manager);
        Pump(30);
        R.Parent := W.Form;
        Pump(30);
        R.Parent := L;
        Pump(30);
        L.Free;
        Pump(30);
      finally
        W.Free;
      end;
    end);

  Run('recreate-handle',
    procedure
    var
      W: TTestWindow;
    begin
      W := TTestWindow.Create(True);
      try
        W.Form.BorderStyle := TFmxFormBorderStyle.Single;
        Pump(50);
        W.Form.BorderStyle := TFmxFormBorderStyle.Sizeable;
        Pump(50);
        Check(W.Frame.Hooked, 'frame hooked after the handle was recreated');
        W.Form.Hide;
        Pump(30);
        W.Form.Show;
        Pump(50);
        W.DropDown('btnPaste');
        W.Form.WindowState := TWindowState.wsMinimized;
        Pump(50);
        W.Form.WindowState := TWindowState.wsNormal;
        Pump(50);
      finally
        W.Free;
      end;
    end);

  Run('merge-unmerge',
    procedure
    var
      W, W2: TTestWindow;
      I: Integer;
    begin
      W := TTestWindow.Create(True);
      W2 := TTestWindow.Create(False, 600, 300);
      try
        for I := 0 to 9 do
        begin
          W.Ribbon.Merge(W2.Ribbon);
          Pump(10);
          W.Ribbon.Unmerge(W2.Ribbon);
          Pump(10);
        end;
        W.Ribbon.Merge(W2.Ribbon);
        Pump(20);
        // the merged source goes away while merged
        FreeAndNil(W2);
        Pump(30);
        W.Ribbon.UpdateLayout;
        W.Ribbon.UnmergeAll;
        Pump(20);
      finally
        W2.Free;
        W.Free;
      end;
    end);

  Run('layout-roundtrip',
    procedure
    var
      W: TTestWindow;
      S: string;
      I: Integer;
    begin
      W := TTestWindow.Create(True);
      try
        for I := 0 to 9 do
        begin
          W.Ribbon.Minimized := Odd(I);
          S := W.Ribbon.SaveLayoutToString;
          W.Ribbon.LoadLayoutFromString(S);
          Pump(5);
        end;
        for S in ['{}', 'not json', '{"format":"FMR.RibbonLayout","version":1,"tabs":[{"name":42,"groups":7},5,null,{"caption":[]}],"qat":{"links":[1,{"item":"nope"}]},"options":{"minimized":"x"}}'] do
          try
            W.Ribbon.LoadLayoutFromString(S);
            Pump(5);
          except
            on E: Exception do
              Log('   invalid layout raised ' + E.ClassName + ': ' + E.Message);
          end;
        Check(W.Ribbon.TabCount > 0, 'tabs left after invalid layouts');
        Pump(10);
        W.Ribbon.ResetLayout;
        Pump(10);
      finally
        W.Free;
      end;
    end);
end;

end.
