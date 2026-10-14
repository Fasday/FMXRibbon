unit DesignPreviewMain;

/// Standalone check of the editor windows of the design package without the IDE: a fake form designer
/// (TPreviewBridge), a fake ribbon (TPreviewRibbon: any IFmrRibbonStructureOwner) filled with a template, and
/// buttons that open the structure editor, the items editor, the image dialog and the template chooser.
///
/// Command line (for automated screenshots):
///   /template=document|spreadsheet|simple|none   template applied at start (default document; the old switches word and
///                    excel still work)
///   /structure  /items  /image  /templates   open that window at start
///   /select=NAME     select the first tree node of the component NAME (or of a link to the item NAME)
///   /expand          expand the whole structure tree
///   /glyph=E8C8      glyph code of the image edited by /image
///   /shot=FILE       save a screenshot of the opened window (PNG) after /delay ms, then exit
///   /delay=MS        default 1200
///   /selftest[=LOG]  design controller + structure editor against the fake ribbon (exit code = failures)
///   /realtest[=LOG]  in-form design against a real TFmrRibbon on an FMX form in the design state (RealRibbonTest);
///                    screenshots in /shots=DIR (default shots\design)

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, FMX.Types, FMX.Controls, Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls,
  Vcl.ExtCtrls, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Images, FMR.Bars.Items, FMR.Ribbon.Structure,
  FMR.Ribbon.Templates, FMR.Ribbon.DesignSupport, FMR.Ribbon.Design.Bridge;

type
  /// <summary>The designed "form": owner of every component; reports deletions/insertions like the IDE.</summary>
  TPreviewRoot = class(TFmxObject)
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

  /// <summary>A ribbon stand-in: tabs and context groups are its children.</summary>
  TPreviewRibbon = class(TFmxObject, IFmrRibbonStructureOwner)
  private
    FBarManager: TFmrBarManager;
    FQAT: TFmrRibbonQuickAccessToolbar;
    FActiveTab: TFmrRibbonTab;
    FOptions: TFmrRibbonLayoutOptions;
    FTheme: string;
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetQAT(const Value: TFmrRibbonQuickAccessToolbar);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function GetStructureObject: TFmxObject;
    function GetBarManager: TFmrBarManager;
    function GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
    function GetActiveTab: TFmrRibbonTab;
    procedure SetActiveTab(const ATab: TFmrRibbonTab);
    function GetLayoutOptions: TFmrRibbonLayoutOptions;
    procedure SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
    procedure BeginStructureUpdate;
    procedure EndStructureUpdate;
    procedure StructureChanged(const ASender: TObject);
    procedure StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
    procedure StructureObjectRemoving(const AObject: TObject);
    procedure LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    property QuickAccessToolbar: TFmrRibbonQuickAccessToolbar read FQAT write SetQAT;
    property Theme: string read FTheme write FTheme;
  end;

  /// <summary>Stand-in of a ribbon with the design hooks (FMR.Ribbon.DesignSupport) for the self test of the
  /// in-form design controller: answers what the test sets.</summary>
  TFakeDesignRibbon = class(FMX.Controls.TControl, IFmrRibbonDesignSupport)
  public
    Hit: TFmrDesignHit;
    Target: TFmrDesignDropTarget;
    Shown: TFmrDesignDropTarget;
    SelectedTab: TFmrRibbonTab;
    Selection: TArray<TPersistent>;
    function DesignHitTest(const ALocalPoint: TPointF): TFmrDesignHit;
    function DesignObjectBounds(const AObject: TPersistent): TRectF;
    function DesignDropTarget(const ALocalPoint: TPointF; const AKind: TFmrDesignDragKind): TFmrDesignDropTarget;
    procedure DesignShowDropTarget(const ATarget: TFmrDesignDropTarget);
    procedure DesignSetSelection(const AObjects: TArray<TPersistent>);
    procedure DesignSelectTab(const ATab: TFmrRibbonTab);
  end;

  TPreviewForm = class;

  /// <summary>Fake form designer.</summary>
  TPreviewBridge = class(TInterfacedObject, IFmrDesignBridge)
  private
    FRoot: TPreviewRoot;
    FForm: TPreviewForm;
    FSelection: TArray<TPersistent>;
  public
    constructor Create(const ARoot: TPreviewRoot; const AForm: TPreviewForm);
    function Root: TComponent;
    function UniqueName(const ABaseName: string): string;
    function CreateComponent(const AClass: TComponentClass; const AParent: TFmxObject): TComponent;
    procedure Modified;
    procedure SelectObjects(const AObjects: TArray<TPersistent>);
    function SelectedObjects: TArray<TPersistent>;
    procedure ShowEvent(const AInstance: TPersistent; const AEventName: string);
  end;

  TPreviewForm = class(TForm)
  private
    FRoot: TPreviewRoot;
    FRibbon: TPreviewRibbon;
    FManager: TFmrBarManager;
    FBridge: IFmrDesignBridge;
    FLog: TMemo;
    FSelectionLabel: TLabel;
    FImage: TFmrImageSource;
    FStartupDone: Boolean;
    procedure StructureClick(Sender: TObject);
    procedure ItemsClick(Sender: TObject);
    procedure ImageClick(Sender: TObject);
    procedure TemplatesClick(Sender: TObject);
    procedure AppActivate(Sender: TObject);
    procedure Startup;
    procedure SaveShot(const AWindow: TCustomForm; const AFileName: string);
    /// <summary>Checks the selection sync and the in-form design controller with TFakeDesignRibbon; returns the
    /// number of failures (also written to the log).</summary>
    function RunSelfTest: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Log(const AText: string);
    procedure ShowSelection(const AObjects: TArray<TPersistent>);
  end;

var
  PreviewForm: TPreviewForm;

implementation

uses
  System.StrUtils, Vcl.Imaging.pngimage, FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Design.Graphics,
  FMR.Ribbon.Design.Window, FMR.Ribbon.Design.ItemsEditor, FMR.Ribbon.Design.StructureEditor,
  FMR.Ribbon.Design.ImageDialog, FMR.Ribbon.Design.Templates, FMR.Ribbon.Design.Interactive, RealRibbonTest;

function Param(const AName: string; out AValue: string): Boolean;
var
  I: Integer;
  S: string;
begin
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if SameText(S, '/' + AName) then
    begin
      AValue := '';
      Exit(True);
    end;
    if StartsText('/' + AName + '=', S) then
    begin
      AValue := Copy(S, Length(AName) + 3, MaxInt);
      Exit(True);
    end;
  end;
  Result := False;
end;

function HasParam(const AName: string): Boolean;
var
  S: string;
begin
  Result := Param(AName, S);
end;

{ TPreviewRoot }

procedure TPreviewRoot.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
    TFmrDesignHub.ItemDeleted(Self, AComponent)
  else
    TFmrDesignHub.ItemInserted(Self, AComponent);
end;

{ TPreviewRibbon }

constructor TPreviewRibbon.Create(AOwner: TComponent);
begin
  inherited;
  FQAT := TFmrRibbonQuickAccessToolbar.Create(Self);
  FOptions := TFmrRibbonLayoutOptions.Default;
  FTheme := FmrDefaultThemeName;
end;

destructor TPreviewRibbon.Destroy;
begin
  FreeAndNil(FQAT);
  inherited;
end;

procedure TPreviewRibbon.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FBarManager) then
    FBarManager := nil;
end;

procedure TPreviewRibbon.SetBarManager(const Value: TFmrBarManager);
begin
  if FBarManager <> nil then
    FBarManager.RemoveFreeNotification(Self);
  FBarManager := Value;
  if FBarManager <> nil then
    FBarManager.FreeNotification(Self);
end;

procedure TPreviewRibbon.SetQAT(const Value: TFmrRibbonQuickAccessToolbar);
begin
  FQAT.Assign(Value);
end;

function TPreviewRibbon.GetStructureObject: TFmxObject;
begin
  Result := Self;
end;

function TPreviewRibbon.GetBarManager: TFmrBarManager;
begin
  Result := FBarManager;
end;

function TPreviewRibbon.GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
begin
  Result := FQAT;
end;

function TPreviewRibbon.GetActiveTab: TFmrRibbonTab;
begin
  Result := FActiveTab;
end;

procedure TPreviewRibbon.SetActiveTab(const ATab: TFmrRibbonTab);
begin
  FActiveTab := ATab;
end;

function TPreviewRibbon.GetLayoutOptions: TFmrRibbonLayoutOptions;
begin
  Result := FOptions;
end;

procedure TPreviewRibbon.SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
begin
  FOptions := AOptions;
end;

procedure TPreviewRibbon.BeginStructureUpdate;
begin
end;

procedure TPreviewRibbon.EndStructureUpdate;
begin
end;

procedure TPreviewRibbon.StructureChanged(const ASender: TObject);
begin
end;

procedure TPreviewRibbon.StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
begin
end;

procedure TPreviewRibbon.StructureObjectRemoving(const AObject: TObject);
begin
  if AObject = FActiveTab then
    FActiveTab := nil;
end;

procedure TPreviewRibbon.LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
begin
end;

procedure TPreviewRibbon.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
end;

procedure TPreviewRibbon.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

{ TFakeDesignRibbon }

function TFakeDesignRibbon.DesignHitTest(const ALocalPoint: TPointF): TFmrDesignHit;
begin
  Result := Hit;
end;

function TFakeDesignRibbon.DesignObjectBounds(const AObject: TPersistent): TRectF;
begin
  Result := TRectF.Empty;
end;

function TFakeDesignRibbon.DesignDropTarget(const ALocalPoint: TPointF;
  const AKind: TFmrDesignDragKind): TFmrDesignDropTarget;
begin
  Result := Target;
  if Result.Kind <> AKind then
    Result := TFmrDesignDropTarget.Empty;
end;

procedure TFakeDesignRibbon.DesignShowDropTarget(const ATarget: TFmrDesignDropTarget);
begin
  Shown := ATarget;
end;

procedure TFakeDesignRibbon.DesignSetSelection(const AObjects: TArray<TPersistent>);
begin
  Selection := AObjects;
end;

procedure TFakeDesignRibbon.DesignSelectTab(const ATab: TFmrRibbonTab);
begin
  SelectedTab := ATab;
end;

{ TPreviewBridge }

constructor TPreviewBridge.Create(const ARoot: TPreviewRoot; const AForm: TPreviewForm);
begin
  inherited Create;
  FRoot := ARoot;
  FForm := AForm;
end;

function TPreviewBridge.Root: TComponent;
begin
  Result := FRoot;
end;

function TPreviewBridge.UniqueName(const ABaseName: string): string;
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

function TPreviewBridge.CreateComponent(const AClass: TComponentClass; const AParent: TFmxObject): TComponent;
var
  Base: string;
  N: Integer;
begin
  Result := AClass.Create(FRoot);
  Base := AClass.ClassName;
  if Base.StartsWith('T') then
    Base := Base.Substring(1);
  N := 1;
  while FRoot.FindComponent(Base + IntToStr(N)) <> nil do
    Inc(N);
  Result.Name := Base + IntToStr(N);
  if (AParent <> nil) and (Result is TFmxObject) then
    TFmxObject(Result).Parent := AParent;
  FForm.Log('created ' + Result.Name);
end;

procedure TPreviewBridge.Modified;
begin
  FForm.Log('modified');
  TFmrDesignHub.ItemsModified(FRoot);
end;

procedure TPreviewBridge.SelectObjects(const AObjects: TArray<TPersistent>);
var
  Ribbon: TPreviewRibbon;
begin
  FSelection := AObjects;
  FForm.ShowSelection(AObjects);
  TFmrDesignHub.SelectionChanged(FRoot, AObjects);
  // What the IDE notifier does: the ribbon shows the tab of the selection.
  FmrDesignSyncSelection(FRoot, AObjects);
  Ribbon := FRoot.FindComponent('Ribbon1') as TPreviewRibbon;
  if (Ribbon <> nil) and (Ribbon.GetActiveTab <> nil) then
    FForm.Log('active tab: ' + Ribbon.GetActiveTab.Caption);
end;

function TPreviewBridge.SelectedObjects: TArray<TPersistent>;
begin
  Result := FSelection;
end;

procedure TPreviewBridge.ShowEvent(const AInstance: TPersistent; const AEventName: string);
begin
  FForm.Log('show event ' + FmrDesignObjectName(AInstance) + '.' + AEventName);
end;

{ TPreviewForm }

constructor TPreviewForm.Create(AOwner: TComponent);
var
  P: TPanel;
  B: TButton;
  T: TFmrRibbonTemplate;
  S: string;

  procedure AddButton(const ACaption: string; const AClick: TNotifyEvent);
  begin
    B := TButton.Create(Self);
    B.Parent := P;
    B.Caption := ACaption;
    B.Align := alLeft;
    B.AlignWithMargins := True;
    B.Width := 130;
    B.OnClick := AClick;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'FMR Ribbon - design-time preview';
  Font.Name := 'Segoe UI';
  Font.Height := -12;
  Width := 720;
  Height := 420;
  Position := poScreenCenter;

  P := TPanel.Create(Self);
  P.Parent := Self;
  P.Align := alTop;
  P.Height := 40;
  P.BevelOuter := bvNone;
  AddButton('Structure editor...', StructureClick);
  AddButton('Items editor...', ItemsClick);
  AddButton('Image dialog...', ImageClick);
  AddButton('Templates...', TemplatesClick);
  FSelectionLabel := TLabel.Create(Self);
  FSelectionLabel.Parent := Self;
  FSelectionLabel.Align := alTop;
  FSelectionLabel.AlignWithMargins := True;
  FSelectionLabel.Caption := 'Selection: -';
  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.Align := alClient;
  FLog.ScrollBars := ssVertical;
  FLog.ReadOnly := True;

  FRoot := TPreviewRoot.Create(nil);
  FRoot.Name := 'Form1';
  FManager := TFmrBarManager.Create(FRoot);
  FManager.Name := 'BarManager1';
  FManager.Parent := FRoot;
  FRibbon := TPreviewRibbon.Create(FRoot);
  FRibbon.Name := 'Ribbon1';
  FRibbon.Parent := FRoot;
  FRibbon.BarManager := FManager;
  FBridge := TPreviewBridge.Create(FRoot, Self);
  FImage := TFmrImageSource.Create(nil);
  FImage.GlyphCode := $E8C8;

  T := TFmrRibbonTemplate.Document;
  if Param('template', S) then
  begin
    if SameText(S, 'spreadsheet') or SameText(S, 'excel') then
      T := TFmrRibbonTemplate.Spreadsheet
    else if SameText(S, 'simple') then
      T := TFmrRibbonTemplate.Simple
    else if SameText(S, 'none') then
      S := 'none';
  end;
  if not SameText(S, 'none') then
    FmrDesignApplyTemplate(FBridge, FRibbon, T, False);
  Log(Format('template: %d tabs, %d items', [TFmrRibbonStructure.TabCount(FRibbon), FManager.ItemCount]));
  Application.OnActivate := AppActivate;
end;

destructor TPreviewForm.Destroy;
begin
  Application.OnActivate := nil;
  FImage.Free;
  FBridge := nil;
  FreeAndNil(FRoot);
  inherited;
end;

procedure TPreviewForm.Log(const AText: string);
begin
  if FLog <> nil then
    FLog.Lines.Add(AText);
end;

procedure TPreviewForm.ShowSelection(const AObjects: TArray<TPersistent>);
var
  S: string;
  P: TPersistent;
begin
  S := '';
  for P in AObjects do
    S := S + FmrDesignObjectName(P) + ' (' + P.ClassName + ') ';
  FSelectionLabel.Caption := 'Selection: ' + S;
end;

procedure TPreviewForm.StructureClick(Sender: TObject);
begin
  FmrShowStructureEditor(FBridge, FRibbon);
end;

procedure TPreviewForm.ItemsClick(Sender: TObject);
begin
  FmrShowItemsEditor(FBridge, FManager);
end;

procedure TPreviewForm.ImageClick(Sender: TObject);
begin
  if FmrEditImageSource(FImage, FManager.Images, 'Glyph of the preview') then
    Log(Format('image: kind %d, glyph $%x', [Ord(FImage.EffectiveKind), FImage.GlyphCode]));
end;

procedure TPreviewForm.TemplatesClick(Sender: TObject);
begin
  if FmrDesignRunTemplateWizard(FBridge, FRibbon) then
    Log(Format('template applied: %d tabs, %d items', [TFmrRibbonStructure.TabCount(FRibbon), FManager.ItemCount]));
end;

procedure TPreviewForm.AppActivate(Sender: TObject);
begin
  if not FStartupDone then
  begin
    FStartupDone := True;
    TThread.ForceQueue(nil, Startup);
  end;
end;

procedure TPreviewForm.SaveShot(const AWindow: TCustomForm; const AFileName: string);
var
  R: TRect;
  B: Vcl.Graphics.TBitmap;
  DC: HDC;
  Png: TPngImage;
  T: Cardinal;
begin
  // Other programs' windows may cover the desktop: bring the window to the top-most band while it is copied.
  SetWindowPos(AWindow.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  T := GetTickCount;
  while GetTickCount - T < 400 do
  begin
    Application.ProcessMessages;
    Sleep(20);
  end;
  GetWindowRect(AWindow.Handle, R);
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
    SetWindowPos(AWindow.Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
    Png := TPngImage.Create;
    try
      Png.Assign(B);
      ForceDirectories(ExtractFilePath(ExpandFileName(AFileName)));
      Png.SaveToFile(AFileName);
    finally
      Png.Free;
    end;
  finally
    B.Free;
  end;
end;

function TPreviewForm.RunSelfTest: Integer;
var
  Failures: Integer;
  Fake: TFakeDesignRibbon;
  Hook: IFmrRibbonDesignHook;
  Clipboard, Editing, Styles: TFmrRibbonGroup;
  Home, View: TFmrRibbonTab;
  Cut, Copy: TFmrBarItem;
  L: TFmrItemLink;
  Bridge: IFmrDesignBridge;
  Editor: TFmrStructureEditorForm;
  Count, Items, I: Integer;
  Found: Boolean;

  procedure SelectNode(const AEditor: TFmrStructureEditorForm; const AObject: TObject);
  var
    J: Integer;
  begin
    for J := 0 to AEditor.Tree.Items.Count - 1 do
      if TObject(AEditor.Tree.Items[J].Data) = AObject then
      begin
        AEditor.Tree.Selected := AEditor.Tree.Items[J];
        Exit;
      end;
  end;

  procedure Check(const ACondition: Boolean; const AName: string);
  begin
    if ACondition then
      Log('PASS ' + AName)
    else
    begin
      Log('FAIL ' + AName);
      Inc(Failures);
    end;
  end;

  function LinkHit(const ALink: TFmrItemLink): TFmrDesignHit;
  begin
    Result := TFmrDesignHit.Empty;
    Result.Kind := TFmrDesignHitKind.Link;
    Result.Link := ALink;
  end;

  function LinkTarget(const ALinks: TFmrItemLinks; const AIndex: Integer): TFmrDesignDropTarget;
  begin
    Result := TFmrDesignDropTarget.Empty;
    Result.Kind := TFmrDesignDragKind.Link;
    Result.Links := ALinks;
    Result.Index := AIndex;
  end;

  procedure Drag(const AShift: TShiftState = []);
  begin
    Hook.DesignMouseDown(Fake, TMouseButton.mbLeft, [ssLeft] + AShift, PointF(10, 10));
    Hook.DesignMouseMove(Fake, [ssLeft] + AShift, PointF(60, 10));
    Hook.DesignMouseUp(Fake, TMouseButton.mbLeft, AShift, PointF(60, 10));
  end;

begin
  Failures := 0;
  Bridge := FBridge;
  Home := FRoot.FindComponent('tabHome') as TFmrRibbonTab;
  View := FRoot.FindComponent('tabView') as TFmrRibbonTab;
  Clipboard := FRoot.FindComponent('grpClipboard') as TFmrRibbonGroup;
  Editing := FRoot.FindComponent('grpEditing') as TFmrRibbonGroup;
  Styles := FRoot.FindComponent('grpStyles') as TFmrRibbonGroup;
  Cut := FManager.FindItem('btnCut');
  Copy := FManager.FindItem('btnCopy');

  { selection sync without design hooks: the tab of the selection becomes active }
  FmrDesignSyncSelection(FRoot, [FRoot.FindComponent('grpPageSetup')]);
  Check(FRibbon.GetActiveTab = FRoot.FindComponent('tabLayout'), 'group selects its tab');
  FmrDesignSyncSelection(FRoot, [Cut]);
  Check(FRibbon.GetActiveTab = Home, 'item selects the tab of its link');
  FmrDesignSyncSelection(FRoot, [View]);
  Check(FRibbon.GetActiveTab = View, 'tab selects itself');
  FmrDesignSyncSelection(FRoot, [FRoot.FindComponent('ctxTableTools')]);
  Check(FRibbon.GetActiveTab = FRoot.FindComponent('tabTableDesign'), 'context group selects its first tab');

  { in-form design controller }
  FmrInstallDesignHooks;
  FmrDesignBridgeFor :=
    function(const AComponent: TComponent): IFmrDesignBridge
    begin
      Result := Bridge;
    end;
  Hook := TFmrRibbonDesignHooks.Hook;
  Check(Hook <> nil, 'hook installed');
  Fake := TFakeDesignRibbon.Create(FRoot);
  try
    // Link into another group.
    L := Clipboard.ItemLinks.FindByItem(Cut);
    Fake.Hit := LinkHit(L);
    Fake.Target := LinkTarget(Editing.ItemLinks, 0);
    Drag;
    Check((Editing.ItemLinks.Count > 0) and (Editing.ItemLinks[0].Item = Cut), 'link dragged into another group');
    Check(not Clipboard.ItemLinks.ContainsItem(Cut), 'link left its group');
    Check(not Fake.Shown.IsValid, 'insertion mark hidden after the drop');
    // Inside the same group: before index 3 of [Paste, Copy, FormatPainter] -> after FormatPainter? (3 = append)
    L := Clipboard.ItemLinks.FindByItem(Copy);
    Fake.Hit := LinkHit(L);
    Fake.Target := LinkTarget(Clipboard.ItemLinks, Clipboard.ItemLinks.Count);
    Drag;
    Check(Clipboard.ItemLinks[Clipboard.ItemLinks.Count - 1].Item = Copy, 'link moved to the end of its group');
    // Ctrl copies.
    Fake.Hit := LinkHit(Clipboard.ItemLinks.FindByItem(Copy));
    Fake.Target := LinkTarget(Editing.ItemLinks, 1);
    Drag([ssCtrl]);
    Check(Clipboard.ItemLinks.ContainsItem(Copy) and (Editing.ItemLinks[1].Item = Copy), 'Ctrl+drag copies');
    // Group to the front of its tab.
    Fake.Hit := TFmrDesignHit.Empty;
    Fake.Hit.Kind := TFmrDesignHitKind.Group;
    Fake.Hit.Group := Styles;
    Fake.Target := TFmrDesignDropTarget.Empty;
    Fake.Target.Kind := TFmrDesignDragKind.Group;
    Fake.Target.Tab := Home;
    Fake.Target.Index := 0;
    Drag;
    Check(Home.Groups[0] = Styles, 'group dragged to the front');
    // Tab to the front: the press also selects (activates) it.
    Fake.Hit := TFmrDesignHit.Empty;
    Fake.Hit.Kind := TFmrDesignHitKind.Tab;
    Fake.Hit.Tab := View;
    Fake.Target := TFmrDesignDropTarget.Empty;
    Fake.Target.Kind := TFmrDesignDragKind.Tab;
    Fake.Target.Index := 0;
    Drag;
    Check(Fake.SelectedTab = View, 'pressing a tab activates it');
    Check(TFmrRibbonStructure.Tab(FRibbon, 0) = View, 'tab dragged to the front');
    // A click without moving does not move anything.
    Fake.Hit := LinkHit(Editing.ItemLinks[0]);
    Fake.Target := LinkTarget(Clipboard.ItemLinks, 0);
    Hook.DesignMouseDown(Fake, TMouseButton.mbLeft, [ssLeft], PointF(10, 10));
    Hook.DesignMouseUp(Fake, TMouseButton.mbLeft, [], PointF(11, 10));
    Check(Editing.ItemLinks[0].Item = Cut, 'a click does not move');
    // Double click on a link opens OnClick.
    Hook.DesignDblClick(Fake, PointF(10, 10));
    Check(Pos('btnCut.OnClick', FLog.Lines[FLog.Lines.Count - 1]) > 0, 'double click opens OnClick');
  finally
    Fake.Free;
    FmrRemoveDesignHooks;
    FmrDesignBridgeFor := nil;
  end;
  { structure editor driven through the keyboard and designer notifications }
  Editor := FmrShowStructureEditor(FBridge, FRibbon);
  try
    SelectNode(Editor, FRoot.FindComponent('grpEditing'));
    Count := Editing.ItemLinks.Count;
    Items := FManager.ItemCount;
    Editor.Tree.Perform(WM_KEYDOWN, VK_INSERT, 0);
    Check(Editing.ItemLinks.Count = Count + 1, 'Insert adds a link to the selected group');
    Check(FManager.ItemCount = Items + 1, 'Insert creates a button item');
    Check((Editing.ItemLinks.Count > 0) and (Editing.ItemLinks[Editing.ItemLinks.Count - 1].Item.Category = 'Home'),
      'the new item gets the category of the tab');
    Check((Editor.Tree.Selected <> nil) and (TObject(Editor.Tree.Selected.Data) is TFmrItemLink), 'new link selected');
    Editor.Tree.Perform(WM_KEYDOWN, VK_DELETE, 0);
    Check(Editing.ItemLinks.Count = Count, 'Del deletes the selected link');
    Check(FManager.ItemCount = Items + 1, 'deleting a link keeps the item');
    Count := TFmrRibbonStructure.TabCount(FRibbon);
    SelectNode(Editor, FRoot.FindComponent('tabLayout'));
    Editor.Tree.Perform(WM_KEYDOWN, VK_DELETE, 0);
    Check(TFmrRibbonStructure.TabCount(FRibbon) = Count - 1, 'Del deletes the selected tab');
    Check(FRoot.FindComponent('grpPageSetup') = nil, 'groups of a deleted tab are gone');
    // Deleted behind the editor's back (the designer, the Object Inspector): the tree follows.
    FManager.FindItem('btnPaste').Free;
    for I := 1 to 10 do
    begin
      Application.ProcessMessages;
      Sleep(20);
    end;
    Found := False;
    for I := 0 to Editor.Tree.Items.Count - 1 do
      if (TObject(Editor.Tree.Items[I].Data) is TFmrItemLink) and
        (TFmrItemLink(Editor.Tree.Items[I].Data).Item = nil) then
        Found := True;
    Check(not Found and (Editor.Tree.Items.Count > 10), 'tree refreshed after an item was deleted elsewhere');
    // The selection of the designer selects the tree node.
    FBridge.SelectObjects([FRoot.FindComponent('grpZoom')]);
    Check((Editor.Tree.Selected <> nil) and (TObject(Editor.Tree.Selected.Data) = FRoot.FindComponent('grpZoom')),
      'designer selection selects the node');
  finally
    Editor.Close;
    Application.ProcessMessages;
  end;

  Result := Failures;
  Log(Format('self test: %d failure(s)', [Failures]));
end;

procedure TPreviewForm.Startup;
var
  S, ShotFile: string;
  Window: TCustomForm;
  Structure: TFmrStructureEditorForm;
  Delay: Integer;
  I: Integer;
  Node: TObject;
  C: TComponent;
  Dialog: TCustomForm;
begin
  Window := nil;
  if Param('selftest', S) then
  begin
    I := RunSelfTest;
    if S <> '' then
      FLog.Lines.SaveToFile(S);
    ExitCode := I;
    Close;
    Exit;
  end;
  if Param('realtest', S) then
  begin
    if not Param('shots', ShotFile) then
      ShotFile := 'shots\design';
    I := RunRealRibbonTest(
      procedure(Line: string)
      begin
        Log(Line);
      end, ShotFile);
    if S <> '' then
      FLog.Lines.SaveToFile(S);
    ExitCode := I;
    Close;
    Exit;
  end;
  if HasParam('structure') then
  begin
    Structure := FmrShowStructureEditor(FBridge, FRibbon);
    Window := Structure;
    if HasParam('expand') then
      Structure.Tree.FullExpand;
    if Param('select', S) then
    begin
      C := FRoot.FindComponent(S);
      for I := 0 to Structure.Tree.Items.Count - 1 do
      begin
        Node := TObject(Structure.Tree.Items[I].Data);
        if (Node = C) or ((Node is TFmrItemLink) and (TFmrItemLink(Node).Item = C)) then
        begin
          Structure.Tree.Selected := Structure.Tree.Items[I];
          Structure.Tree.Items[I].MakeVisible;
          Break;
        end;
      end;
    end;
  end
  else if HasParam('items') then
    Window := FmrShowItemsEditor(FBridge, FManager);

  Delay := 1200;
  if Param('delay', S) then
    Delay := StrToIntDef(S, Delay);

  if HasParam('image') or HasParam('templates') then
  begin
    if Param('glyph', S) then
      FImage.GlyphCode := StrToIntDef('$' + S, $E8C8);
    if Param('shot', ShotFile) then
      TThread.CreateAnonymousThread(
        procedure
        begin
          Sleep(Delay);
          TThread.Synchronize(nil,
            procedure
            begin
              Dialog := Screen.ActiveCustomForm;
              if Dialog <> nil then
              begin
                SaveShot(Dialog, ShotFile);
                PostMessage(Dialog.Handle, WM_CLOSE, 0, 0);
              end;
              TThread.ForceQueue(nil, procedure begin Close; end);
            end);
        end).Start;
    if HasParam('image') then
      ImageClick(nil)
    else
      TemplatesClick(nil);
    Exit;
  end;

  if (Window <> nil) and Param('shot', ShotFile) then
    TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(Delay);
        TThread.Synchronize(nil,
          procedure
          begin
            Window.BringToFront;
            Window.Update;
            SaveShot(Window, ShotFile);
            Close;
          end);
      end).Start;
end;

end.
