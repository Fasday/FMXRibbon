unit FMR.Tests.Structure;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, DUnitX.TestFramework, FMX.Types, FMR.Ribbon.Types, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Tests.Fakes;

type
  [TestFixture]
  TStructureTests = class
  private
    S: TTestStructure;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TabsAndGroupsAreFound;
    [Test] procedure AddingTabNotifiesOwner;
    [Test] procedure CaptionChangeNotifiesOwner;
    [Test] procedure GroupLinksNotifyOwner;
    [Test] procedure ItemChangeReachesOwnerThroughGroup;
    [Test] procedure QATNotifiesOwner;
    [Test] procedure FreeingGroupNotifiesOwner;
    [Test] procedure FreeingTabClearsActiveTab;
    [Test] procedure FreeingContextGroupClearsReference;
    [Test] procedure HidingContextGroupDeactivatesItsTab;
    [Test] procedure ContextGroupActivate;
    [Test] procedure ActiveGoesThroughOwner;
    [Test] procedure MoveTab;
    [Test] procedure MoveGroupBetweenTabs;
    [Test] procedure MoveAndCopyLink;
    [Test] procedure CreateHelpers;
    [Test] procedure DialogLauncherClick;
    [Test] procedure QATAddRemove;
  end;

  [TestFixture]
  TStreamingTests = class
  private
    function RoundTrip(const ARoot: TFmrTestRoot; out AText: string): TFmrTestRoot;
  public
    [Test] procedure ManagerAndRibbonRoundTrip;
    [Test] procedure DefaultsAreNotStored;
    [Test] procedure CloneOfItemKeepsProperties;
  end;

implementation

uses
  FMR.Bars.Images;

{ TStructureTests }

procedure TStructureTests.Setup;
begin
  S := TTestStructure.Create;
end;

procedure TStructureTests.TearDown;
begin
  FreeAndNil(S);
end;

procedure TStructureTests.TabsAndGroupsAreFound;
begin
  Assert.AreEqual(4, TFmrRibbonStructure.TabCount(S.Ribbon));
  Assert.AreSame(S.TabInsert, TFmrRibbonStructure.Tab(S.Ribbon, 1));
  Assert.AreEqual(1, S.TabInsert.TabIndex);
  Assert.AreEqual(3, S.TabHome.GroupCount);
  Assert.AreSame(S.GrpFont, S.TabHome.Groups[1]);
  Assert.AreEqual(1, S.GrpFont.GroupIndex);
  Assert.AreSame(S.TabHome, S.GrpFont.Tab);
  Assert.AreSame(S.TabView, TFmrRibbonStructure.FindTab(S.Ribbon, 'View'));
  Assert.AreSame(S.TabView, TFmrRibbonStructure.FindTab(S.Ribbon, 'tabview'));
  Assert.AreSame(S.GrpZoom, TFmrRibbonStructure.FindGroup(S.Ribbon, 'grpZoom'));
  Assert.AreSame(S.GrpFont, S.TabHome.FindGroup('Font'));
  Assert.AreEqual(6, Integer(Length(TFmrRibbonStructure.AllGroups(S.Ribbon))));
  Assert.AreEqual(1, Integer(Length(TFmrRibbonStructure.ContextGroups(S.Ribbon))));
  Assert.IsFalse(S.TabPicture.IsShown, 'a tab of a hidden context group is not shown');
  Assert.AreEqual(1, Integer(Length(S.CtxPicture.Tabs)));
end;

procedure TStructureTests.AddingTabNotifiesOwner;
var
  T: TFmrRibbonTab;
begin
  T := TFmrRibbonTab.Create(S.Root);
  T.Parent := S.Ribbon;
  Assert.IsTrue(S.Ribbon.StructureChangedCount > 0);
  S.Ribbon.ResetCounters;
  T.Visible := False;
  Assert.AreEqual(1, S.Ribbon.StructureChangedCount, 'visibility is a structure change');
end;

procedure TStructureTests.CaptionChangeNotifiesOwner;
begin
  S.TabHome.Caption := 'Start';
  Assert.AreEqual(1, S.Ribbon.ObjectChangedCount);
  Assert.AreEqual(TFmrItemChange.Layout, S.Ribbon.LastChange);
  S.GrpFont.KeyTip := 'FN';
  Assert.AreEqual(2, S.Ribbon.ObjectChangedCount);
  Assert.AreEqual(TFmrItemChange.Paint, S.Ribbon.LastChange);
  S.CtxPicture.Color := TAlphaColors.Orange;
  Assert.AreEqual(3, S.Ribbon.ObjectChangedCount);
  S.GrpFont.UserCaption := 'My font';
  Assert.AreEqual('My font', S.GrpFont.DisplayCaption);
end;

procedure TStructureTests.GroupLinksNotifyOwner;
begin
  S.GrpClipboard.ItemLinks.AddItem(S.Find);
  Assert.IsTrue(S.Ribbon.LinksChangedCount > 0);
  S.Ribbon.ResetCounters;
  S.GrpClipboard.ItemLinks.Delete(0);
  Assert.IsTrue(S.Ribbon.LinksChangedCount > 0);
  Assert.AreEqual(1, S.Ribbon.LinkRemovingCount);
end;

procedure TStructureTests.ItemChangeReachesOwnerThroughGroup;
begin
  S.Copy.Caption := 'Copy!';
  // btnCopy is linked from grpClipboard and grpArrange
  Assert.AreEqual(2, S.Ribbon.LinkItemChangedCount);
end;

procedure TStructureTests.QATNotifiesOwner;
begin
  S.Ribbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon;
  Assert.AreEqual(1, S.Ribbon.ObjectChangedCount);
  S.Save.Caption := 'Save!';
  Assert.AreEqual(1, S.Ribbon.LinkItemChangedCount);
  S.Undo.Free;
  Assert.AreEqual(1, S.Ribbon.QuickAccessToolbar.ItemLinks.Count);
  Assert.AreEqual(1, S.Ribbon.LinkRemovingCount);
end;

procedure TStructureTests.FreeingGroupNotifiesOwner;
begin
  S.GrpFont.Free;
  Assert.IsTrue(S.Ribbon.Removed.Contains(S.GrpFont));
  Assert.IsTrue(S.Ribbon.StructureChangedCount > 0);
  Assert.AreEqual(2, S.TabHome.GroupCount);
  Assert.AreEqual(0, S.Bold.LinkCount, 'links of a destroyed group are gone');
  S.GrpFont := nil;
end;

procedure TStructureTests.FreeingTabClearsActiveTab;
begin
  S.TabView.Active := True;
  Assert.IsTrue(S.TabView.Active);
  S.TabView.Free;
  Assert.IsNull(S.Ribbon.ActiveTab);
  Assert.AreEqual(0, S.Zoom.LinkCount);
  S.TabView := nil;
end;

procedure TStructureTests.FreeingContextGroupClearsReference;
begin
  S.CtxPicture.Free;
  Assert.IsNull(S.TabPicture.ContextGroup);
  Assert.IsTrue(S.TabPicture.IsShown);
end;

procedure TStructureTests.HidingContextGroupDeactivatesItsTab;
begin
  S.CtxPicture.Visible := True;
  S.TabPicture.Active := True;
  S.CtxPicture.Visible := False;
  Assert.IsNull(S.Ribbon.ActiveTab);
end;

procedure TStructureTests.ContextGroupActivate;
begin
  S.CtxPicture.Activate;
  Assert.IsTrue(S.CtxPicture.Visible);
  Assert.AreSame(S.TabPicture, S.Ribbon.ActiveTab);
end;

procedure TStructureTests.ActiveGoesThroughOwner;
begin
  S.TabInsert.Active := True;
  Assert.AreSame(S.TabInsert, S.Ribbon.ActiveTab);
  S.TabHome.Active := False;
  Assert.AreSame(S.TabInsert, S.Ribbon.ActiveTab, 'deactivating another tab changes nothing');
  S.TabInsert.Active := False;
  Assert.IsNull(S.Ribbon.ActiveTab);
end;

procedure TStructureTests.MoveTab;
begin
  TFmrRibbonStructure.MoveTab(S.TabView, 0);
  Assert.AreEqual('View[Zoom(btnZoom)]Home', DumpStructure(S.Ribbon).Substring(0, 23));
  Assert.AreEqual(0, S.TabView.TabIndex);
  S.TabView.TabIndex := 3;
  Assert.AreEqual(3, S.TabView.TabIndex);
  Assert.AreEqual(0, S.TabHome.TabIndex);
  Assert.IsTrue(S.Ribbon.StructureChangedCount > 0);
end;

procedure TStructureTests.MoveGroupBetweenTabs;
begin
  TFmrRibbonStructure.MoveGroup(S.GrpZoom, S.TabHome, 1);
  Assert.AreEqual(4, S.TabHome.GroupCount);
  Assert.AreSame(S.GrpZoom, S.TabHome.Groups[1]);
  Assert.AreEqual(0, S.TabView.GroupCount);
  TFmrRibbonStructure.MoveGroup(S.GrpZoom, S.TabHome, -1);
  Assert.AreEqual(3, S.GrpZoom.GroupIndex);
  S.GrpZoom.GroupIndex := 0;
  Assert.AreSame(S.GrpZoom, S.TabHome.Groups[0]);
  Assert.AreSame(S.Zoom, S.GrpZoom.ItemLinks[0].Item, 'links move with the group');
end;

procedure TStructureTests.MoveAndCopyLink;
var
  L, C: TFmrItemLink;
begin
  L := S.GrpClipboard.ItemLinks[2];
  L.BeginGroup := True;
  TFmrRibbonStructure.MoveLink(L, S.GrpZoom.ItemLinks, 0);
  Assert.AreEqual(2, S.GrpClipboard.ItemLinks.Count);
  Assert.AreSame(S.Copy, S.GrpZoom.ItemLinks[0].Item);
  TFmrRibbonStructure.MoveLink(S.GrpZoom.ItemLinks[0], S.GrpZoom.ItemLinks, -1);
  Assert.AreSame(S.Copy, S.GrpZoom.ItemLinks[1].Item);
  C := TFmrRibbonStructure.CopyLink(S.GrpZoom.ItemLinks[1], S.GrpTables.ItemLinks, 0);
  Assert.AreSame(S.Copy, C.Item);
  Assert.IsTrue(C.BeginGroup);
  Assert.AreEqual(3, S.Copy.LinkCount);
end;

procedure TStructureTests.CreateHelpers;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  C: TFmrRibbonContextGroup;
begin
  T := TFmrRibbonStructure.CreateTab(S.Ribbon, 'Review', 1);
  Assert.AreEqual(1, T.TabIndex);
  Assert.AreSame(TComponent(S.Root), T.Owner, 'created like the designer: owned by the form');
  G := TFmrRibbonStructure.CreateGroup(T, 'Proofing');
  Assert.AreSame(T, G.Tab);
  G := T.AddGroup('Comments');
  Assert.AreEqual(1, G.GroupIndex);
  G := TFmrRibbonStructure.CreateGroup(T, 'First', 0);
  Assert.AreEqual(0, G.GroupIndex);
  C := TFmrRibbonStructure.CreateContextGroup(S.Ribbon, 'Table Tools', TAlphaColors.Green);
  Assert.IsFalse(C.Visible, 'context groups start hidden');
  Assert.AreSame(C, TFmrRibbonStructure.FindContextGroup(S.Ribbon, 'Table Tools'));
end;

type
  TLauncherCounter = class
    Count: Integer;
    procedure Click(Sender: TObject);
  end;

procedure TLauncherCounter.Click(Sender: TObject);
begin
  Inc(Count);
end;

procedure TStructureTests.DialogLauncherClick;
var
  C: TLauncherCounter;
begin
  C := TLauncherCounter.Create;
  try
    S.GrpFont.ShowDialogLauncher := True;
    S.GrpFont.OnDialogLauncherClick := C.Click;
    S.GrpFont.DialogLauncherClick;
    Assert.AreEqual(1, C.Count);
  finally
    C.Free;
  end;
end;

procedure TStructureTests.QATAddRemove;
var
  QAT: TFmrRibbonQuickAccessToolbar;
begin
  QAT := S.Ribbon.QuickAccessToolbar;
  Assert.IsTrue(QAT.ContainsItem(S.Save));
  Assert.AreSame(QAT.ItemLinks[0], QAT.AddItem(S.Save), 'no duplicates');
  QAT.AddItem(S.Redo);
  Assert.AreEqual(3, QAT.ItemLinks.Count);
  QAT.RemoveItem(S.Save);
  Assert.IsFalse(QAT.ContainsItem(S.Save));
end;

{ TStreamingTests }

function TStreamingTests.RoundTrip(const ARoot: TFmrTestRoot; out AText: string): TFmrTestRoot;
var
  Bin, Txt: TMemoryStream;
  SS: TStringStream;
begin
  Bin := TMemoryStream.Create;
  Txt := TMemoryStream.Create;
  try
    Bin.WriteComponent(ARoot);
    Bin.Position := 0;
    ObjectBinaryToText(Bin, Txt);
    SS := TStringStream.Create('', TEncoding.UTF8);
    try
      Txt.Position := 0;
      SS.CopyFrom(Txt, 0);
      AText := SS.DataString;
    finally
      SS.Free;
    end;
    Bin.Position := 0;
    Result := TFmrTestRoot.Create(nil);
    try
      Bin.ReadComponent(Result);
    except
      Result.Free;
      raise;
    end;
  finally
    Txt.Free;
    Bin.Free;
  end;
end;

procedure TStreamingTests.ManagerAndRibbonRoundTrip;
var
  S: TTestStructure;
  R: TFmrTestRoot;
  Text: string;
  Manager: TFmrBarManager;
  Ribbon: TFakeRibbon;
  Home, Picture: TFmrRibbonTab;
  Font: TFmrRibbonGroup;
  Paste, Bold: TFmrButtonItem;
  Styles: TFmrGalleryItem;
begin
  S := TTestStructure.Create;
  try
    S.Paste.Glyph.ImageIndex := 7;
    S.Paste.ButtonStyle := TFmrButtonStyle.Split;
    S.Paste.DropDownLinks.AddItem(S.Copy);
    S.Paste.ScreenTip.Header := 'Paste (Ctrl+V)';
    S.Paste.Category := 'Clipboard';
    S.Bold.Glyph.PathData := 'M0,0 L8,0 L8,8 Z';
    S.Bold.Glyph.PathViewBox := 16;
    S.Bold.ButtonStyle := TFmrButtonStyle.Check;
    S.Bold.Down := True;
    S.Styles.Groups.Add('Built-in').Items.Add('Normal', 1);
    S.Styles.Groups[0].Items.Add('Heading 1', 2);
    S.Styles.MaxColumns := 5;
    S.Styles.SelectedIndex := 1;
    S.GrpFont.ShowDialogLauncher := True;
    S.GrpFont.ReductionPriority := 3;
    S.GrpFont.ItemLinks[1].BeginGroup := True;
    S.CtxPicture.Color := TAlphaColors.Orange;
    S.Ribbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon;

    R := RoundTrip(S.Root, Text);
    try
      Assert.IsTrue(Text.Contains('object btnPaste: TFmrButtonItem'), 'items are children of the manager');
      Assert.IsTrue(Text.Contains('Item = btnPaste'), 'links reference items by name');
      Assert.IsTrue(Text.Contains('ContextGroup = ctxPicture'));

      Manager := R.FindComponent('BarManager') as TFmrBarManager;
      Ribbon := R.FindComponent('Ribbon') as TFakeRibbon;
      Assert.IsNotNull(Manager);
      Assert.IsNotNull(Ribbon);
      Assert.AreSame(Manager, Ribbon.BarManager);
      Assert.AreEqual(S.Manager.ItemCount, Manager.ItemCount);
      Assert.AreEqual('Clipboard', Manager.Categories[0]);

      Paste := Manager.FindItem('btnPaste') as TFmrButtonItem;
      Bold := Manager.FindItem('btnBold') as TFmrButtonItem;
      Styles := Manager.FindItem('galStyles') as TFmrGalleryItem;
      Assert.AreEqual('Paste', Paste.Caption);
      Assert.AreEqual(7, Integer(Paste.Glyph.ImageIndex));
      Assert.AreEqual(TFmrButtonStyle.Split, Paste.ButtonStyle);
      Assert.AreEqual(1, Paste.DropDownLinks.Count);
      Assert.AreSame(Manager.FindItem('btnCopy'), Paste.DropDownLinks[0].Item);
      Assert.AreEqual('Paste (Ctrl+V)', Paste.ScreenTip.Header);
      Assert.AreEqual('M0,0 L8,0 L8,8 Z', Bold.Glyph.PathData);
      Assert.AreEqual(Single(16), Bold.Glyph.PathViewBox, 0.001);
      Assert.IsTrue(Bold.Down);
      Assert.AreEqual(2, Styles.EntryCount);
      Assert.AreEqual('Heading 1', Styles.Entries[1].Caption);
      Assert.AreEqual(2, Integer(Styles.Entries[1].Glyph.ImageIndex));
      Assert.AreEqual(5, Styles.MaxColumns);
      Assert.AreEqual(1, Styles.SelectedIndex);

      Assert.AreEqual(DumpStructure(S.Ribbon), DumpStructure(Ribbon));
      Home := TFmrRibbonStructure.FindTab(Ribbon, 'tabHome');
      Picture := TFmrRibbonStructure.FindTab(Ribbon, 'tabPicture');
      Font := Home.FindGroup('grpFont');
      Assert.IsTrue(Font.ShowDialogLauncher);
      Assert.AreEqual(3, Font.ReductionPriority);
      Assert.IsTrue(Font.ItemLinks[1].BeginGroup);
      Assert.AreEqual(TFmrButtonGroupPosition.Member, Font.ItemLinks[2].ButtonGroup);
      Assert.IsTrue(Home.FindGroup('grpClipboard').ItemLinks[0].ViewLevels = [TFmrViewLevel.Large]);
      Assert.AreSame(Paste, Home.FindGroup('grpClipboard').ItemLinks[0].Item);
      Assert.AreEqual(S.Paste.LinkCount, Paste.LinkCount, 'the item knows its streamed links');
      Assert.IsNotNull(Picture.ContextGroup);
      Assert.AreEqual('ctxPicture', Picture.ContextGroup.Name);
      Assert.AreEqual(TAlphaColor(TAlphaColors.Orange), Picture.ContextGroup.Color);
      Assert.AreEqual(TFmrQATPosition.BelowRibbon, Ribbon.QuickAccessToolbar.Position);
      Assert.AreEqual(2, Ribbon.QuickAccessToolbar.ItemLinks.Count);
      Assert.AreSame(Manager.FindItem('btnUndo'), Ribbon.QuickAccessToolbar.ItemLinks[1].Item);

      // the copy is live: changes reach its own ribbon
      Ribbon.ResetCounters;
      Bold.Caption := 'B';
      Assert.AreEqual(1, Ribbon.LinkItemChangedCount);
    finally
      R.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure TStreamingTests.DefaultsAreNotStored;
var
  S: TTestStructure;
  R: TFmrTestRoot;
  Text: string;
begin
  S := TTestStructure.Create;
  try
    R := RoundTrip(S.Root, Text);
    R.Free;
    Assert.IsFalse(Text.Contains('Enabled = True'));
    Assert.IsFalse(Text.Contains('Visible = True'));
    Assert.IsFalse(Text.Contains('ImageIndex = -1'));
    Assert.IsFalse(Text.Contains('CanCollapse'));
    Assert.IsFalse(Text.Contains('BeginGroup = False'));
    Assert.IsFalse(Text.Contains('DropDownLinks'), 'empty drop-down links are not stored');
    Assert.IsFalse(Text.Contains('Width = 100'), 'default editor width is not stored');
  finally
    S.Free;
  end;
end;

procedure TStreamingTests.CloneOfItemKeepsProperties;
var
  S: TTestStructure;
  Clone: TFmxObject;
begin
  S := TTestStructure.Create;
  try
    S.Bold.Glyph.GlyphCode := $E8DD;
    S.Bold.Hint := 'Bold text';
    Clone := S.Bold.Clone(nil);
    try
      Assert.IsTrue(Clone is TFmrButtonItem);
      Assert.AreEqual('Bold text', TFmrButtonItem(Clone).Hint);
      Assert.AreEqual(Cardinal($E8DD), TFmrButtonItem(Clone).Glyph.GlyphCode);
    finally
      Clone.Free;
    end;
  finally
    S.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TStructureTests);
  TDUnitX.RegisterTestFixture(TStreamingTests);

end.
