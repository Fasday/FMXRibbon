unit RealRibbonTest;

/// In-form design self test against the REAL TFmrRibbon (DesignPreview.exe /realtest=LOG).
///
/// The IDE creates a designed form, puts it into the design state (TComponent.SetDesigning) and then creates or
/// streams its components with the form as owner, so every constructor already sees csDesigning. This test does the
/// same with an FMX form inside this VCL program (as in the IDE, where the FMX designer runs inside the VCL IDE):
/// a bar manager and a ribbon built by the Word template, optionally a TFmrFormFrame (the caption row and the tab row
/// then live in the frame host). The design controller of the package (FMR.Ribbon.Design.Interactive) is installed
/// with a fake designer bridge whose root is that form.
///
/// Mouse input is sent to the form window as Windows messages (WM_LBUTTONDOWN...; the cursor is moved for
/// WM_MOUSEMOVE because FMX ignores moves when the cursor did not move). FMX routes them through ObjectAtPoint to the
/// design-interactive control, as the form designer does when it lets a control have the mouse. What the IDE adds
/// (its own selection on click, IDesignerHook.IsDesignMsg) is not simulated.

interface

uses
  System.SysUtils;

/// <summary>Runs the test; ALog receives one line per check ("PASS ..."/"FAIL ..."); screenshots go to AShotDir.
/// Returns the number of failures.</summary>
function RunRealRibbonTest(const ALog: TProc<string>; const AShotDir: string): Integer;

implementation

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.Types, System.UITypes, System.Math,
  Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Forms, FMX.Types, FMX.Controls, FMX.Forms, FMX.Platform.Win,
  FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon, FMR.Ribbon.Templates, FMR.Frame,
  FMR.Ribbon.DesignSupport, FMR.Ribbon.Design.Bridge, FMR.Ribbon.Design.Interactive, FMR.Ribbon.Design.ItemsEditor,
  FMR.Ribbon.Design.StructureEditor;

type
  TComponentAccess = class(TComponent);

  /// <summary>Fake form designer for the FMX form.</summary>
  TRealBridge = class(TInterfacedObject, IFmrDesignBridge)
  private
    FRoot: TComponent;
    FSelection: TArray<TPersistent>;
    FLog: TProc<string>;
  public
    LastEvent: string;
    Modifications: Integer;
    constructor Create(const ARoot: TComponent; const ALog: TProc<string>);
    function Root: TComponent;
    function UniqueName(const ABaseName: string): string;
    function CreateComponent(const AClass: TComponentClass; const AParent: TFmxObject): TComponent;
    procedure Modified;
    procedure SelectObjects(const AObjects: TArray<TPersistent>);
    function SelectedObjects: TArray<TPersistent>;
    procedure ShowEvent(const AInstance: TPersistent; const AEventName: string);
  end;

  TRealTest = class
  private
    FLog: TProc<string>;
    FShotDir: string;
    FFailures: Integer;
    FForm: FMX.Forms.TForm;
    FManager: TFmrBarManager;
    FFrame: TFmrFormFrame;
    FRibbon: TFmrRibbon;
    FBridge: TRealBridge;
    FBridgeIntf: IFmrDesignBridge;
    FTabChanged: Integer;
    procedure TabChanged(Sender: TObject);
    procedure Log(const AText: string);
    procedure Check(const ACondition: Boolean; const AName: string);
    procedure Pump(const AMs: Integer = 80);
    function Wnd: HWND;
    function Scale: Single;
    function ClientPx(const ALocal: TPointF): TPoint;
    function ScreenPx(const ALocal: TPointF): TPoint;
    procedure Send(const AMsg: UINT; const AKeys: WPARAM; const ALocal: TPointF);
    procedure MoveTo(const ALocal: TPointF; const AKeys: WPARAM);
    procedure Click(const ALocal: TPointF; const AKeys: WPARAM = 0);
    procedure RightClick(const ALocal: TPointF);
    procedure DoubleClick(const ALocal: TPointF);
    procedure Drag(const AFrom, ATo: TPointF; const AKeys: WPARAM = 0; const AShot: string = '');
    function Bounds(const AObject: TPersistent): TRectF;
    function Find(const AName: string): TComponent;
    function Selected: TPersistent;
    procedure Shot(const AName: string);
    procedure BuildForm(const AWithFrame: Boolean);
    procedure FreeForm;
    procedure TestRibbon;
    procedure TestFrameHost;
  public
    constructor Create(const ALog: TProc<string>; const AShotDir: string);
    function Run: Integer;
  end;

{ TRealBridge }

constructor TRealBridge.Create(const ARoot: TComponent; const ALog: TProc<string>);
begin
  inherited Create;
  FRoot := ARoot;
  FLog := ALog;
end;

function TRealBridge.Root: TComponent;
begin
  Result := FRoot;
end;

function TRealBridge.UniqueName(const ABaseName: string): string;
var
  N: Integer;
begin
  Result := ABaseName;
  N := 0;
  while FRoot.FindComponent(Result) <> nil do
  begin
    Inc(N);
    Result := ABaseName + IntToStr(N);
  end;
end;

function TRealBridge.CreateComponent(const AClass: TComponentClass; const AParent: TFmxObject): TComponent;
var
  Base: string;
begin
  Result := AClass.Create(FRoot);
  Base := AClass.ClassName.Substring(1);
  Result.Name := UniqueName(Base + '1');
  if (AParent <> nil) and (Result is TFmxObject) then
    TFmxObject(Result).Parent := AParent;
end;

procedure TRealBridge.Modified;
begin
  Inc(Modifications);
  TFmrDesignHub.ItemsModified(FRoot);
end;

procedure TRealBridge.SelectObjects(const AObjects: TArray<TPersistent>);
var
  S: string;
  P: TPersistent;
begin
  FSelection := AObjects;
  S := '';
  for P in AObjects do
    S := S + FmrDesignObjectName(P) + ' ';
  FLog('  selected: ' + S.Trim);
  TFmrDesignHub.SelectionChanged(FRoot, AObjects);
  // What the IDE notifier does: the ribbon shows the tab of the selection and frames it.
  FmrDesignSyncSelection(FRoot, AObjects);
end;

function TRealBridge.SelectedObjects: TArray<TPersistent>;
begin
  Result := FSelection;
end;

procedure TRealBridge.ShowEvent(const AInstance: TPersistent; const AEventName: string);
begin
  LastEvent := FmrDesignObjectName(AInstance) + '.' + AEventName;
  FLog('  show event ' + LastEvent);
end;

{ TRealTest }

constructor TRealTest.Create(const ALog: TProc<string>; const AShotDir: string);
begin
  inherited Create;
  FLog := ALog;
  FShotDir := AShotDir;
end;

procedure TRealTest.TabChanged(Sender: TObject);
begin
  Inc(FTabChanged);
end;

procedure TRealTest.Log(const AText: string);
begin
  FLog(AText);
end;

procedure TRealTest.Check(const ACondition: Boolean; const AName: string);
begin
  if ACondition then
    Log('PASS ' + AName)
  else
  begin
    Log('FAIL ' + AName);
    Inc(FFailures);
  end;
end;

procedure TRealTest.Pump(const AMs: Integer);
var
  T: Cardinal;
  Done: Boolean;
begin
  T := GetTickCount;
  repeat
    Vcl.Forms.Application.ProcessMessages;
    CheckSynchronize;
    Done := True;
    FMX.Forms.Application.DoIdle(Done);
    Sleep(10);
  until GetTickCount - T >= Cardinal(AMs);
end;

function TRealTest.Wnd: HWND;
begin
  Result := FormToHWND(FForm);
end;

function TRealTest.Scale: Single;
begin
  Result := FForm.Handle.Scale;
  if Result <= 0 then
    Result := 1;
end;

function TRealTest.ClientPx(const ALocal: TPointF): TPoint;
var
  P: TPointF;
begin
  P := FRibbon.LocalToAbsolute(ALocal);
  Result := Point(Round(P.X * Scale), Round(P.Y * Scale));
end;

function TRealTest.ScreenPx(const ALocal: TPointF): TPoint;
begin
  Result := ClientPx(ALocal);
  Winapi.Windows.ClientToScreen(Wnd, Result);
end;

procedure TRealTest.Send(const AMsg: UINT; const AKeys: WPARAM; const ALocal: TPointF);
var
  P: TPoint;
begin
  P := ClientPx(ALocal);
  SendMessage(Wnd, AMsg, AKeys, LPARAM(Word(SmallInt(P.X)) or (Cardinal(Word(SmallInt(P.Y))) shl 16)));
end;

procedure TRealTest.MoveTo(const ALocal: TPointF; const AKeys: WPARAM);
var
  P: TPoint;
begin
  P := ScreenPx(ALocal);
  SetCursorPos(P.X, P.Y);
  Send(WM_MOUSEMOVE, AKeys, ALocal);
end;

procedure TRealTest.Click(const ALocal: TPointF; const AKeys: WPARAM);
begin
  MoveTo(ALocal, AKeys);
  Send(WM_LBUTTONDOWN, MK_LBUTTON or AKeys, ALocal);
  Send(WM_LBUTTONUP, AKeys, ALocal);
  Pump;
end;

procedure TRealTest.RightClick(const ALocal: TPointF);
begin
  MoveTo(ALocal, 0);
  Send(WM_RBUTTONDOWN, MK_RBUTTON, ALocal);
end;

procedure TRealTest.DoubleClick(const ALocal: TPointF);
begin
  MoveTo(ALocal, 0);
  Send(WM_LBUTTONDOWN, MK_LBUTTON, ALocal);
  Send(WM_LBUTTONUP, 0, ALocal);
  Send(WM_LBUTTONDBLCLK, MK_LBUTTON, ALocal);
  Send(WM_LBUTTONUP, 0, ALocal);
  Pump;
end;

procedure TRealTest.Drag(const AFrom, ATo: TPointF; const AKeys: WPARAM; const AShot: string);
var
  I: Integer;
  P: TPointF;
begin
  MoveTo(AFrom, AKeys);
  Send(WM_LBUTTONDOWN, MK_LBUTTON or AKeys, AFrom);
  for I := 1 to 6 do
  begin
    P := AFrom + (ATo - AFrom) * (I / 6);
    MoveTo(P, MK_LBUTTON or AKeys);
    Pump(20);
  end;
  if AShot <> '' then
    Shot(AShot);
  Send(WM_LBUTTONUP, AKeys, ATo);
  Pump;
end;

function TRealTest.Bounds(const AObject: TPersistent): TRectF;
begin
  Result := (FRibbon as IFmrRibbonDesignSupport).DesignObjectBounds(AObject);
end;

function TRealTest.Find(const AName: string): TComponent;
begin
  Result := FForm.FindComponent(AName);
  if Result = nil then
    Log('  (component not found: ' + AName + ')');
end;

function TRealTest.Selected: TPersistent;
begin
  if Length(FBridge.SelectedObjects) = 1 then
    Result := FBridge.SelectedObjects[0]
  else
    Result := nil;
end;

procedure TRealTest.Shot(const AName: string);
var
  R: TRect;
  B: Vcl.Graphics.TBitmap;
  DC: HDC;
  Png: TPngImage;
  FileName: string;
begin
  if FShotDir = '' then
    Exit;
  FForm.Invalidate;
  Pump(250);
  GetWindowRect(Wnd, R);
  B := Vcl.Graphics.TBitmap.Create;
  try
    B.PixelFormat := pf24bit;
    B.SetSize(R.Width, R.Height);
    DC := GetDC(0);
    try
      BitBlt(B.Canvas.Handle, 0, 0, R.Width, R.Height, DC, R.Left, R.Top, SRCCOPY);
    finally
      ReleaseDC(0, DC);
    end;
    Png := TPngImage.Create;
    try
      Png.Assign(B);
      ForceDirectories(FShotDir);
      FileName := IncludeTrailingPathDelimiter(FShotDir) + AName + '.png';
      Png.SaveToFile(FileName);
      Log('  shot ' + FileName);
    finally
      Png.Free;
    end;
  finally
    B.Free;
  end;
end;

procedure TRealTest.BuildForm(const AWithFrame: Boolean);
var
  Frm: FMX.Forms.TForm;
begin
  Frm := FMX.Forms.TForm.CreateNew(nil);
  FForm := Frm;
  FForm.Caption := 'FMR Ribbon - design-time simulation';
  FForm.SetBounds(40, 40, 1180, 470);
  FForm.Show;
  SetWindowPos(Wnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetForegroundWindow(Wnd);
  // What the IDE does with a designed form before its components exist.
  TComponentAccess(FForm).SetDesigning(True);
  FBridge := TRealBridge.Create(FForm, FLog);
  FBridgeIntf := FBridge;
  if AWithFrame then
  begin
    FFrame := TFmrFormFrame.Create(FForm);
    FFrame.Name := 'FormFrame1';
  end
  else
    FFrame := nil;
  FManager := TFmrBarManager.Create(FForm);
  FManager.Name := 'BarManager1';
  FManager.Parent := FForm;
  FRibbon := TFmrRibbon.Create(FForm);
  FRibbon.Name := 'Ribbon1';
  FRibbon.Parent := FForm;
  FRibbon.BarManager := FManager;
  FRibbon.OnTabChanged := TabChanged;
  FmrApplyRibbonTemplate(FRibbon, TFmrRibbonTemplate.Word);
  FRibbon.UpdateLayout;
  FmrInstallDesignHooks;
  FmrDesignBridgeFor :=
    function(const AComponent: TComponent): IFmrDesignBridge
    begin
      Result := FBridgeIntf;
    end;
  Pump(400);
end;

procedure TRealTest.FreeForm;
begin
  FmrRemoveDesignHooks;
  FmrDesignBridgeFor := nil;
  if FForm <> nil then
  begin
    SetWindowPos(Wnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
    FForm.Free;
    FForm := nil;
  end;
  FBridge := nil;
  FBridgeIntf := nil;
  FRibbon := nil;
  FManager := nil;
  FFrame := nil;
  Pump(100);
end;

procedure TRealTest.TestRibbon;
var
  DS: IFmrRibbonDesignSupport;
  Home, Insert, View, Layout, TableDesign: TFmrRibbonTab;
  Clipboard, Editing, Styles, Font: TFmrRibbonGroup;
  Cut, Copy, Paste, Bold: TFmrBarItem;
  Hit: TFmrDesignHit;
  Target: TFmrDesignDropTarget;
  R, R2: TRectF;
  P: TPointF;
  Obj: IControl;
  I, Count, Mods: Integer;
  Internal: Boolean;
  W: Vcl.Forms.TForm;
begin
  DS := FRibbon as IFmrRibbonDesignSupport;
  Home := Find('tabHome') as TFmrRibbonTab;
  Insert := Find('tabInsert') as TFmrRibbonTab;
  View := Find('tabView') as TFmrRibbonTab;
  Layout := Find('tabLayout') as TFmrRibbonTab;
  TableDesign := Find('tabTableDesign') as TFmrRibbonTab;
  Clipboard := Find('grpClipboard') as TFmrRibbonGroup;
  Editing := Find('grpEditing') as TFmrRibbonGroup;
  Styles := Find('grpStyles') as TFmrRibbonGroup;
  Font := Find('grpFont') as TFmrRibbonGroup;
  Cut := FManager.FindItem('btnCut');
  Copy := FManager.FindItem('btnCopy');
  Paste := FManager.FindItem('btnPaste');
  Bold := FManager.FindItem('btnBold');

  { design state, parts }
  Check(csDesigning in FRibbon.ComponentState, 'ribbon created in the design state');
  Check((FRibbon as IControl).DesignInteractive, 'ribbon is design-interactive');
  Check(FRibbon.Body.Locked and not FRibbon.Body.Stored and (FRibbon.Body.Owner = FRibbon), 'body locked, not stored');
  Check(FRibbon.TabBar.Locked and FRibbon.CaptionBar.Locked, 'tab and caption rows locked');
  Internal := False;
  for I := 0 to FForm.ComponentCount - 1 do
    if (FForm.Components[I] is TFmrRibbonPart) or (FForm.Components[I].ClassName.StartsWith('TFmrRibbonEdit')) or
      (FForm.Components[I].ClassName.StartsWith('TFmrRibbonCombo')) then
      Internal := True;
  Check(not Internal, 'no internal control is owned by the form (not selectable, not streamed)');
  Check((Home <> nil) and (Clipboard <> nil) and (Cut <> nil), 'Word template built');
  Check(FRibbon.ActiveTab = Home, 'Home is the active tab');

  { hit test }
  R := Bounds(Insert);
  Check(not R.IsEmpty, 'bounds of the Insert tab');
  Hit := DS.DesignHitTest(R.CenterPoint);
  Check((Hit.Kind = TFmrDesignHitKind.Tab) and (Hit.Tab = Insert), 'hit test: tab');
  Hit := DS.DesignHitTest(Bounds(Clipboard.ItemLinks.FindByItem(Cut)).CenterPoint);
  Check((Hit.Kind = TFmrDesignHitKind.Link) and (Hit.Item = Cut) and (Hit.Group = Clipboard), 'hit test: link');
  R := Bounds(Clipboard);
  Hit := DS.DesignHitTest(PointF(R.CenterPoint.X - 10, R.Bottom - 5));
  Check((Hit.Kind in [TFmrDesignHitKind.Group, TFmrDesignHitKind.GroupLauncher]) and (Hit.Group = Clipboard),
    'hit test: group caption');
  // The FMX hit test: the ribbon takes the mouse over its parts and over its editor controls.
  Obj := FForm.ObjectAtPoint(FRibbon.LocalToScreen(Bounds(Insert).CenterPoint));
  Check((Obj <> nil) and (Obj.GetObject = FRibbon), 'ObjectAtPoint over a tab = the ribbon');
  R := Bounds(FManager.FindItem('cmbFontName'));
  Obj := FForm.ObjectAtPoint(FRibbon.LocalToScreen(R.CenterPoint));
  Check(not R.IsEmpty and (Obj <> nil) and (Obj.GetObject = FRibbon), 'ObjectAtPoint over the font combo = the ribbon');

  { click a tab: active tab changes, the hook selects it, no OnTabChanged }
  Click(Bounds(Insert).CenterPoint);
  Check(FRibbon.ActiveTab = Insert, 'click on a tab activates it');
  Check(Selected = Insert, 'click on a tab selects it in the designer');
  Check(FTabChanged = 0, 'no OnTabChanged at design time');
  Shot('real_01_insert_selected');
  Click(Bounds(Home).CenterPoint);
  Check(FRibbon.ActiveTab = Home, 'click on Home');

  { click a link: the item is selected and framed }
  Click(Bounds(Clipboard.ItemLinks.FindByItem(Cut)).CenterPoint);
  Check(Selected = Cut, 'click on a link selects its item');
  Check(not Bounds(Cut).IsEmpty, 'the selected item is shown');
  { right click: selected at once (the designer's context menu shows the verbs of the object) }
  R := Bounds(Font);
  RightClick(PointF(R.CenterPoint.X, R.Bottom - 5));
  Check(Selected = Font, 'right click selects the group at once');
  Send(WM_RBUTTONUP, 0, PointF(R.CenterPoint.X, R.Bottom - 5));
  Pump;
  Shot('real_02_group_selected');

  { drag a link into another group, with the insertion mark }
  R := Bounds(Editing.ItemLinks[0]);
  P := PointF(R.Left + 3, R.CenterPoint.Y);
  Target := DS.DesignDropTarget(P, TFmrDesignDragKind.Link);
  Check((Target.Kind = TFmrDesignDragKind.Link) and (Target.Links = Editing.ItemLinks) and (Target.Index = 0) and
    not Target.Mark.IsEmpty, 'drop target: before the first link of Editing');
  Mods := FBridge.Modifications;
  Drag(Bounds(Clipboard.ItemLinks.FindByItem(Cut)).CenterPoint, P, 0, 'real_03_drag_link_mark');
  Check((Editing.ItemLinks.Count > 0) and (Editing.ItemLinks[0].Item = Cut), 'link dragged into another group');
  Check(not Clipboard.ItemLinks.ContainsItem(Cut), 'the link left its group');
  Check(FBridge.Modifications > Mods, 'form marked modified');
  { Ctrl+drag copies }
  R := Bounds(Editing.ItemLinks[1]);
  Count := Editing.ItemLinks.Count;
  Drag(Bounds(Clipboard.ItemLinks.FindByItem(Copy)).CenterPoint, PointF(R.Left + 3, R.CenterPoint.Y), MK_CONTROL);
  Check(Clipboard.ItemLinks.ContainsItem(Copy) and (Editing.ItemLinks.Count = Count + 1) and
    (Editing.ItemLinks[1].Item = Copy), 'Ctrl+drag copies a link');
  { inside the same group: to the end }
  R := Bounds(Editing);
  R2 := Bounds(Editing.ItemLinks[Editing.ItemLinks.Count - 1]);
  Drag(Bounds(Editing.ItemLinks[0]).CenterPoint, PointF(R2.Right - 2, R2.CenterPoint.Y));
  Check(Editing.ItemLinks[Editing.ItemLinks.Count - 1].Item = Cut, 'link moved to the end of its group');
  { a click without moving moves nothing }
  Count := Editing.ItemLinks.Count;
  Click(Bounds(Editing.ItemLinks[0]).CenterPoint);
  Check((Editing.ItemLinks.Count = Count) and (Editing.ItemLinks[Count - 1].Item = Cut), 'a click does not move');

  { drag a group to the front of its tab }
  R := Bounds(Styles);
  R2 := Bounds(Clipboard);
  Drag(PointF(R.CenterPoint.X, R.Bottom - 5), PointF(R2.Left + 4, R2.CenterPoint.Y), 0, 'real_04_drag_group_mark');
  Check(Home.Groups[0] = Styles, 'group dragged to the front');
  { drag a tab to the front }
  Drag(Bounds(View).CenterPoint, PointF(Bounds(Home).Left + 3, Bounds(Home).CenterPoint.Y), 0, 'real_05_drag_tab_mark');
  Check(TFmrRibbonStructure.Tab(FRibbon, 0) = View, 'tab dragged to the front');
  Check(FTabChanged = 0, 'still no OnTabChanged');
  Click(Bounds(Home).CenterPoint);

  { an item dragged from the items editor onto the ribbon (IFmrExternalItemDrop, screen coordinates) }
  R := Bounds(Editing.ItemLinks[0]);
  P := PointF(R.Left + 3, R.CenterPoint.Y);
  Check((FmrExternalItemDrop <> nil) and FmrExternalItemDrop.ExternalDragOver(ScreenPx(P), [Paste]),
    'items editor drag over the ribbon accepted');
  Shot('real_06_external_drag_mark');
  Check(FmrExternalItemDrop.ExternalDrop(ScreenPx(P), [Paste]) and (Editing.ItemLinks[0].Item = Paste),
    'items editor drop inserts a link');

  { double click: OnClick of an item, the structure editor on a tab }
  DoubleClick(Bounds(Font.ItemLinks.FindByItem(Bold)).CenterPoint);
  Check(FBridge.LastEvent = 'btnBold.OnClick', 'double click on a link opens OnClick');
  DoubleClick(Bounds(Insert).CenterPoint);
  W := nil;
  for I := 0 to Vcl.Forms.Screen.FormCount - 1 do
    if Vcl.Forms.Screen.Forms[I] is TFmrStructureEditorForm then
      W := Vcl.Forms.Screen.Forms[I];
  Check(W <> nil, 'double click on a tab opens the structure editor');
  if W <> nil then
  begin
    W.Close;
    Pump;
  end;

  { selection sync from the designer }
  FBridge.SelectObjects([Find('grpPageSetup')]);
  Pump;
  Check(FRibbon.ActiveTab = Layout, 'selecting a group shows its tab');
  FBridge.SelectObjects([TableDesign]);
  Pump;
  Check((FRibbon.ActiveTab = TableDesign) and not Bounds(TableDesign).IsEmpty,
    'a tab of a hidden contextual group is shown while selected');
  Shot('real_07_hidden_context_tab');
  FBridge.SelectObjects([Home]);
  Pump;
  Check((FRibbon.ActiveTab = Home) and Bounds(TableDesign).IsEmpty, 'the hidden contextual tab disappears again');
  FBridge.SelectObjects([Styles, Bold]);
  Pump;
  Shot('real_08_selection_frames');
  Check(FTabChanged = 0, 'no OnTabChanged during the whole test');
  Log(FRibbon.DebugDump);
end;

procedure TRealTest.TestFrameHost;
var
  DS: IFmrRibbonDesignSupport;
  Home, Insert, View: TFmrRibbonTab;
  Obj: IControl;
  R: TRectF;
  Hit: TFmrDesignHit;
begin
  DS := FRibbon as IFmrRibbonDesignSupport;
  Home := Find('tabHome') as TFmrRibbonTab;
  Insert := Find('tabInsert') as TFmrRibbonTab;
  View := Find('tabView') as TFmrRibbonTab;
  Check((FFrame <> nil) and not FFrame.Hooked and (FRibbon.TabBar.Parent = FFrame.Host),
    'frame host: the tab row is in the (unhooked) host');
  R := Bounds(Insert);
  Check(not R.IsEmpty and (R.Bottom <= 0.5), 'tab bounds above the ribbon (negative local Y)');
  Hit := DS.DesignHitTest(R.CenterPoint);
  Check((Hit.Kind = TFmrDesignHitKind.Tab) and (Hit.Tab = Insert), 'hit test in the host');
  Obj := FForm.ObjectAtPoint(FRibbon.LocalToScreen(R.CenterPoint));
  Check((Obj <> nil) and (Obj.GetObject = FRibbon.TabBar) and Obj.DesignInteractive,
    'ObjectAtPoint over a tab in the host = the design-interactive tab row');
  Click(R.CenterPoint);
  Check((FRibbon.ActiveTab = Insert) and (Selected = Insert), 'click on a tab in the host');
  Drag(Bounds(View).CenterPoint, PointF(Bounds(Home).Left + 3, Bounds(Home).CenterPoint.Y), 0, 'real_09_host_drag_tab');
  Check(TFmrRibbonStructure.Tab(FRibbon, 0) = View, 'tab dragged in the host');
  FBridge.SelectObjects([Insert, Find('grpTables')]);
  Pump;
  Shot('real_10_host_selection');
  Check(FTabChanged = 0, 'no OnTabChanged (frame host)');
end;

function TRealTest.Run: Integer;
begin
  FFailures := 0;
  Log('--- real TFmrRibbon, rows inside the ribbon ---');
  BuildForm(False);
  try
    TestRibbon;
  finally
    FreeForm;
  end;
  Log('--- real TFmrRibbon, rows in the frame host ---');
  BuildForm(True);
  try
    TestFrameHost;
  finally
    FreeForm;
  end;
  Result := FFailures;
  Log(Format('real ribbon test: %d failure(s)', [FFailures]));
end;

function RunRealRibbonTest(const ALog: TProc<string>; const AShotDir: string): Integer;
var
  T: TRealTest;
begin
  T := TRealTest.Create(ALog, AShotDir);
  try
    try
      Result := T.Run;
    except
      on E: Exception do
      begin
        ALog('FAIL exception ' + E.ClassName + ': ' + E.Message);
        Result := 1000;
      end;
    end;
  finally
    T.Free;
  end;
end;

end.
