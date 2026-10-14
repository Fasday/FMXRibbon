unit FMR.Tests.RibbonControl;

/// The real TFmrRibbon and its popups without a window: caption-row colors readable in every theme, destroy orders
/// of the ribbon and its bar manager, items deleted while shown, open menus told about deleted items and links,
/// style names of the themed editors (FMX style cache).

interface

uses
  System.SysUtils, System.Classes, System.UITypes, DUnitX.TestFramework, FMX.Types, FMX.Controls,
  FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Theme, FMR.Ribbon.Painter,
  FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.EditorStyles, FMR.Ribbon.Templates, FMR.Ribbon;

type
  [TestFixture]
  TRibbonControlTests = class
  private
    FRoot: TFmxObject;
    FManager: TFmrBarManager;
    FRibbon: TFmrRibbon;
    procedure BuildWord;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure CaptionRowGlyphsReadInEveryTheme;
    [Test] procedure UnknownThemeKeepsAWorkingTheme;
    [Test] procedure ManagerFreedBeforeRibbon;
    [Test] procedure RibbonFreedBeforeManager;
    [Test] procedure ManagerSetToNilAndBack;
    [Test] procedure ItemsDeletedWhileShown;
    [Test] procedure GroupAndTabDeletedWhileShown;
    [Test] procedure KeyTipRunsTheRightCommandAfterADelete;
    [Test] procedure MenuKnowsItsItemsAndLinks;
    [Test] procedure DestroyingHooksAreInstalled;
    [Test] procedure ThemedEditorsShareStyleNamesPerScheme;
  end;

implementation

uses
  FMR.Tests.Themes;

type
  TPartAccess = class(TFmrRibbonPart);

{ TRibbonControlTests }

procedure TRibbonControlTests.Setup;
begin
  FRoot := TFmxObject.Create(nil);
  FManager := TFmrBarManager.Create(FRoot);
  FManager.Parent := FRoot;
  FRibbon := TFmrRibbon.Create(FRoot);
  FRibbon.Width := 1000;
  FRibbon.BarManager := FManager;
end;

procedure TRibbonControlTests.TearDown;
begin
  FreeAndNil(FRoot);
  FManager := nil;
  FRibbon := nil;
end;

procedure TRibbonControlTests.BuildWord;
begin
  FRibbon.BeginStructureUpdate;
  try
    FmrApplyRibbonTemplate(FRibbon, TFmrRibbonTemplate.Word, FManager);
  finally
    FRibbon.EndStructureUpdate;
  end;
  FRibbon.UpdateLayout;
end;

procedure TRibbonControlTests.CaptionRowGlyphsReadInEveryTheme;
var
  N, Failures: string;
  P: TFmrRibbonPainter;
  Caption, Glyph: TAlphaColor;
begin
  Failures := '';
  for N in TFmrTheme.ThemeNames do
  begin
    FRibbon.Theme := N;
    // The caption bar paints the quick access toolbar and the tab bar the collapse button with the "bar" painter.
    P := TPartAccess(FRibbon.CaptionBar).GetPainter;
    Caption := FmrTestOver(P.Theme.Fills[TFmrToken.CaptionFill].MainColor, $FFFFFFFF);
    Glyph := FmrTestOver(P.Theme.Colors[TFmrToken.GlyphTint], Caption);
    if FmrTestContrast(Glyph, Caption) < 3 then
      Failures := Failures + Format('%s %.2f; ', [N, FmrTestContrast(Glyph, Caption)]);
    // The caption row has its own painter (its content dims when the window is inactive); while the window is
    // active it paints with the colors of the tab row.
    Assert.AreEqual(P.Theme.Colors[TFmrToken.GlyphTint],
      TPartAccess(FRibbon.TabBar).GetPainter.Theme.Colors[TFmrToken.GlyphTint], 'caption and tab rows: ' + N);
  end;
  Assert.AreEqual('', Failures);
end;

procedure TRibbonControlTests.UnknownThemeKeepsAWorkingTheme;
begin
  BuildWord;
  FRibbon.Theme := 'NoSuchTheme';
  FRibbon.UpdateLayout;
  Assert.IsNotNull(FRibbon.ThemeObject);
  Assert.IsNotNull(FRibbon.Painter);
  FRibbon.Theme := '';
  FRibbon.UpdateLayout;
  Assert.IsNotNull(FRibbon.ThemeObject);
end;

procedure TRibbonControlTests.ManagerFreedBeforeRibbon;
begin
  BuildWord;
  Assert.IsTrue(Length(FRibbon.AccessibilityNodes) > 20);
  FreeAndNil(FManager);
  Assert.IsNull(FRibbon.BarManager);
  FRibbon.UpdateLayout;
  FRibbon.ShowKeyTipsNow;
  FRibbon.HideKeyTips;
  Assert.IsTrue(Length(FRibbon.AccessibilityNodes) > 0, 'tabs and groups stay');
end;

procedure TRibbonControlTests.RibbonFreedBeforeManager;
var
  I: Integer;
begin
  BuildWord;
  FreeAndNil(FRibbon);
  // Items no longer have views: changing them must not reach the freed ribbon.
  for I := 0 to FManager.ItemCount - 1 do
    FManager.Items[I].Caption := 'X' + IntToStr(I);
  while FManager.ItemCount > 0 do
    FManager.Items[0].Free;
  Assert.AreEqual(0, FManager.ItemCount);
end;

procedure TRibbonControlTests.ManagerSetToNilAndBack;
var
  Before: Integer;
begin
  BuildWord;
  Before := Length(FRibbon.AccessibilityNodes);
  FRibbon.BarManager := nil;
  FRibbon.UpdateLayout;
  // The links still reference the items (the manager is alive): the ribbon keeps showing them.
  Assert.IsTrue(Length(FRibbon.AccessibilityNodes) > 0);
  FRibbon.ShowKeyTipsNow;
  FRibbon.HideKeyTips;
  FRibbon.BarManager := FManager;
  FRibbon.UpdateLayout;
  Assert.AreEqual<Integer>(Before, Length(FRibbon.AccessibilityNodes));
end;

procedure TRibbonControlTests.ItemsDeletedWhileShown;
var
  Before: Integer;
begin
  BuildWord;
  Before := Length(FRibbon.AccessibilityNodes);
  FRibbon.ShowKeyTipsNow;
  FManager.FindItem('btnCut').Free;
  FManager.FindItem('btnUndo').Free;
  FRibbon.UpdateLayout;
  FRibbon.HideKeyTips;
  Assert.AreEqual<Integer>(Before - 2, Length(FRibbon.AccessibilityNodes));
  FManager.BeginUpdate;
  try
    while FManager.ItemCount > 0 do
      FManager.Items[0].Free;
  finally
    FManager.EndUpdate;
  end;
  FRibbon.UpdateLayout;
  Assert.IsTrue(Length(FRibbon.AccessibilityNodes) < Before);
end;

procedure TRibbonControlTests.GroupAndTabDeletedWhileShown;
begin
  BuildWord;
  FRibbon.ActiveTab.Groups[0].Free;
  FRibbon.UpdateLayout;
  FRibbon.ActiveTab.Free;
  FRibbon.UpdateLayout;
  Assert.IsNotNull(FRibbon.ActiveTab, 'another tab becomes active');
  while FRibbon.TabCount > 0 do
    FRibbon.Tabs(0).Free;
  FRibbon.UpdateLayout;
  Assert.IsNull(FRibbon.ActiveTab);
end;

type
  TClickLog = class
  public
    Clicked: string;
    procedure Click(Sender: TObject);
  end;

procedure TClickLog.Click(Sender: TObject);
begin
  Clicked := Clicked + TComponent(Sender).Name + ';';
end;

procedure TRibbonControlTests.KeyTipRunsTheRightCommandAfterADelete;
var
  Log: TClickLog;
  Keys: IFmrKeyHandler;
  Key: Word;
  Ch: WideChar;
  I: Integer;
begin
  BuildWord;
  Log := TClickLog.Create;
  try
    for I := 0 to FManager.ItemCount - 1 do
      FManager.Items[I].OnClick := Log.Click;
    Assert.IsTrue(Supports(FRibbon, IFmrKeyHandler, Keys));
    FRibbon.ShowKeyTipsNow;
    // H: the Home tab level (Cut = X, Copy = C)
    Key := Ord('H');
    Ch := 'H';
    Keys.HandleKey(Key, Ch, []);
    // A command before Copy goes away while its tip is shown: the tips after it move up in the list.
    FManager.FindItem('btnCut').Free;
    Key := Ord('C');
    Ch := 'C';
    Keys.HandleKey(Key, Ch, []);
    Assert.AreEqual('btnCopy;', Log.Clicked);
  finally
    Keys := nil;
    FRibbon.HideKeyTips;
    Log.Free;
  end;
end;

procedure TRibbonControlTests.MenuKnowsItsItemsAndLinks;
var
  Button, Sub1, Sub2, Other: TFmrButtonItem;
  Theme: TFmrTheme;
  Painter: TFmrRibbonPainter;
  Menu: TFmrMenuControl;
  D: IFmrItemDisplay;
begin
  Button := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnMenu'));
  Button.ButtonStyle := TFmrButtonStyle.DropDown;
  Sub1 := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnSub1'));
  Sub2 := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnSub2'));
  Other := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, 'btnOther'));
  Button.DropDownLinks.AddItem(Sub1);
  Button.DropDownLinks.AddItem(Sub2);
  Theme := TFmrTheme.CreateTheme('');
  Painter := TFmrRibbonPainter.Create(Theme);
  Menu := TFmrMenuControl.CreateMenu(TFmrPopupContext.Create(Painter, nil, nil), Button.DropDownLinks);
  try
    Assert.IsTrue(Supports(Menu, IFmrItemDisplay, D));
    Assert.IsTrue(D.ShowsItem(Sub1));
    Assert.IsTrue(D.ShowsItem(Button), 'the owner of the links');
    Assert.IsFalse(D.ShowsItem(Other));
    Assert.IsTrue(D.ShowsLink(Button.DropDownLinks[1]));
    Assert.IsFalse(D.ShowsLink(nil));
  finally
    D := nil;
    Menu.Free;
    Painter.Free;
    Theme.Free;
  end;
end;

procedure TRibbonControlTests.DestroyingHooksAreInstalled;
begin
  Assert.IsTrue(Assigned(FmrItemDestroyingHook));
  Assert.IsTrue(Assigned(FmrLinkDestroyingHook));
end;

procedure TRibbonControlTests.ThemedEditorsShareStyleNamesPerScheme;
var
  A, B: TFmrRibbonEdit;
  Light, Dark: TFmrTheme;
  First: string;
begin
  Light := TFmrTheme.CreateTheme('Office365White');
  Dark := TFmrTheme.CreateTheme('Office365Black');
  A := TFmrRibbonEdit.Create(nil);
  B := TFmrRibbonEdit.Create(nil);
  try
    FmrThemeEditor(A, Light);
    FmrThemeEditor(B, Light);
    First := A.StyleLookup;
    Assert.AreNotEqual('', First);
    // Equal colors, equal name: a tree FMX recycles into its style cache is found again by that name.
    Assert.AreEqual(First, B.StyleLookup);
    FmrThemeEditor(A, Dark);
    Assert.AreNotEqual(First, A.StyleLookup);
    FmrThemeEditor(A, Light);
    Assert.AreEqual(First, A.StyleLookup, 'a scheme keeps its name');
  finally
    A.Free;
    B.Free;
    Light.Free;
    Dark.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRibbonControlTests);

end.
