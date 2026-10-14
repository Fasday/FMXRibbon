unit FMR.Tests.Customize;

/// Customization session (FMR.Ribbon.CustomizeModel): the shadow copy, the Office rules of the editing commands,
/// Apply / Cancel, import and export, reset, quick access toolbar.

interface

uses
  System.SysUtils, System.Classes, System.JSON, DUnitX.TestFramework, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Structure, FMR.Ribbon.Persistence, FMR.Ribbon.CustomizeModel, FMR.Tests.Fakes;

type
  [TestFixture]
  TCustomizeModelTests = class
  public
    [Test] procedure ShadowMirrorsTheRibbon;
    [Test] procedure CancelLeavesTheRibbonUntouched;
    [Test] procedure CommandsOnlyGoIntoCustomGroups;
    [Test] procedure NewTabAndGroupAreApplied;
    [Test] procedure HideRenameAndMoveAreApplied;
    [Test] procedure GroupMovesIntoTheNeighbourTab;
    [Test] procedure RemovingCustomObjects;
    [Test] procedure CustomLinksCanBeReorderedAndRenamed;
    [Test] procedure ExportImportRoundTrip;
    [Test] procedure ResetAllRestoresTheDefault;
    [Test] procedure ResetTabRestoresOneTab;
    [Test] procedure QuickAccessToolbarEditing;
    [Test] procedure CommandSourcesAndLists;
    [Test] procedure ApplyTwiceChangesNothing;
  end;

implementation

{ TCustomizeModelTests }

procedure TCustomizeModelTests.ShadowMirrorsTheRibbon;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
begin
  S := TTestStructure.Create;
  try
    S.GrpFont.UserCaption := 'Fonts';
    S.TabView.Visible := False;
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      Assert.AreEqual(DumpStructure(S.Ribbon), DumpStructure(C.Shadow));
      Assert.AreSame(TObject(S.TabHome), TObject(C.OriginalOf(C.Tabs[0])));
      Assert.AreEqual('tabHome', C.Tabs[0].Name, 'names are kept, so layouts apply to the shadow');
      Assert.IsTrue(TFmrRibbonCustomization.IsToolTab(C.Tabs[3]), 'contextual tabs keep their group');
      Assert.AreEqual(2, C.QuickAccessToolbar.ItemLinks.Count);
      Assert.AreEqual(0, S.Manager.FindItem('btnSave').LinkCount - 2, 'the shadow QAT links the same items');
    finally
      C.Free;
    end;
    Assert.AreEqual(1, S.Save.LinkCount, 'shadow links are released with the session');
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.CancelLeavesTheRibbonUntouched;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  Before: string;
  G: TFmrRibbonGroup;
begin
  S := TTestStructure.Create;
  try
    Before := DumpStructure(S.Ribbon);
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      G := C.NewTab(C.Tabs[0]);
      C.AddCommand(S.Bold, G);
      C.SetVisible(C.Tabs[1], False);
      C.Move(C.Tabs[2], -2);
      C.AddToQAT(S.Redo);
      Assert.IsTrue(C.Modified);
    finally
      C.Free;
    end;
    Assert.AreEqual(Before, DumpStructure(S.Ribbon));
    Assert.AreEqual(2, S.Ribbon.QuickAccessToolbar.ItemLinks.Count);
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.CommandsOnlyGoIntoCustomGroups;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  Clip, G: TFmrRibbonGroup;
  L: TFmrItemLink;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      Clip := C.Groups(C.Tabs[0])[0];
      Assert.IsFalse(C.CanAddCommand(S.Bold, Clip), 'designed group');
      Assert.IsFalse(C.CanAddCommand(S.Bold, Clip.ItemLinks[0]), 'link of a designed group');
      Assert.IsFalse(C.CanRemove(Clip.ItemLinks[0]), 'commands of designed groups stay');
      Assert.IsFalse(C.CanMove(Clip.ItemLinks[1], -1));
      Assert.IsFalse(C.CanRemove(Clip), 'designed groups are hidden, not removed');
      Assert.IsFalse(C.CanRemove(C.Tabs[0]));
      G := C.NewGroup(Clip);
      Assert.AreEqual(1, G.GroupIndex, 'the new group follows the selected one');
      Assert.IsTrue(G.IsUserDefined);
      Assert.IsTrue(C.CanAddCommand(S.Bold, G));
      L := C.AddCommand(S.Bold, G);
      Assert.IsNotNull(L);
      Assert.IsFalse(C.CanAddCommand(S.Bold, G), 'no duplicates in a group');
      Assert.IsTrue(C.CanAddCommand(S.Italic, L));
      C.AddCommand(S.Italic, G);
      C.AddCommand(S.Cut, L);
      Assert.AreEqual('btnCut', G.ItemLinks[1].Item.Name, 'inserted after the selected command');
      Assert.IsFalse(C.CanAddCommand(nil, G));
    finally
      C.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.NewTabAndGroupAreApplied;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  G: TFmrRibbonGroup;
  T: TFmrRibbonTab;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      G := C.NewTab(C.Tabs[0]);
      C.Rename(G.Tab, 'My Tab');
      C.Rename(G, 'My Group');
      C.SetGroupGlyph(G, $E8A5);
      C.AddCommand(S.Bold, G);
      C.AddCommand(S.Zoom, G);
      C.Apply;
    finally
      C.Free;
    end;
    T := TFmrRibbonStructure.Tab(S.Ribbon, 1);
    Assert.IsTrue(T.IsUserDefined);
    Assert.AreEqual('My Tab', T.Caption);
    Assert.AreEqual('', T.UserCaption);
    Assert.StartsWith('tabCustom', T.Name);
    Assert.AreSame(TObject(S.Root), TObject(T.Owner), 'owned by the form like designed objects');
    Assert.AreEqual(1, T.GroupCount);
    G := T.Groups[0];
    Assert.AreEqual('My Group', G.Caption);
    Assert.AreEqual(Cardinal($E8A5), G.Glyph.GlyphCode);
    Assert.AreEqual(2, G.ItemLinks.Count);
    Assert.AreSame(TObject(S.Bold), TObject(G.ItemLinks[0].Item));
    // the result can be saved and contains the custom content
    Assert.Contains(TFmrRibbonLayoutStorage.SaveToString(S.Ribbon), '"My Group"');
    Assert.Contains(TFmrRibbonLayoutStorage.SaveToString(S.Ribbon), '"glyphCode"');
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.HideRenameAndMoveAreApplied;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      C.SetVisible(C.ShadowOf(S.GrpFont), False);
      C.Rename(C.ShadowOf(S.TabHome), 'Start');
      C.Rename(C.ShadowOf(S.GrpClipboard), 'Clipboard');
      C.Move(C.ShadowOf(S.TabView), -2);
      C.Move(C.ShadowOf(S.GrpStyles), -2);
      C.Apply;
    finally
      C.Free;
    end;
    Assert.IsFalse(S.GrpFont.Visible);
    Assert.AreEqual('Start', S.TabHome.DisplayCaption);
    Assert.AreEqual('Home', S.TabHome.Caption, 'designed captions are never overwritten');
    Assert.AreEqual('', S.GrpClipboard.UserCaption, 'renaming to the designed caption clears the user caption');
    Assert.AreEqual(0, S.TabView.TabIndex);
    Assert.AreEqual(0, S.GrpStyles.GroupIndex);
    Assert.AreEqual('View[Zoom(btnZoom)]Start[Styles(galStyles,btnFind),Clipboard(btnPaste,btnCut,btnCopy),' +
      '-Font(cbFontName,btnBold,btnItalic,btnUnderline)]Insert[Tables(btnPaste)]Format[Arrange(btnCopy)]',
      DumpStructure(S.Ribbon));
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.GroupMovesIntoTheNeighbourTab;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  G: TFmrRibbonGroup;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      G := TFmrRibbonGroup(C.ShadowOf(S.GrpStyles));
      Assert.IsTrue(C.CanMove(G, 1), 'the last group can move into the next tab');
      C.Move(G, 1);
      Assert.AreEqual('tabInsert', G.Tab.Name);
      Assert.AreEqual(0, G.GroupIndex);
      G := TFmrRibbonGroup(C.ShadowOf(S.GrpClipboard));
      Assert.IsFalse(C.CanMove(G, -1), 'no tab before the first one');
      C.Apply;
    finally
      C.Free;
    end;
    Assert.AreSame(TObject(S.TabInsert), TObject(S.GrpStyles.Tab));
    Assert.AreEqual(0, S.GrpStyles.GroupIndex);
    Assert.AreEqual(2, S.TabHome.GroupCount);
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.RemovingCustomObjects;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  T: TFmrRibbonTab;
  G, G2: TFmrRibbonGroup;
begin
  S := TTestStructure.Create;
  try
    // a ribbon that already has custom content (loaded layout)
    T := TFmrRibbonStructure.CreateTab(S.Ribbon, 'Mine', 3);
    T.Name := 'tabMine';
    T.IsUserDefined := True;
    G := TFmrRibbonStructure.CreateGroup(T, 'Mine 1');
    G.Name := 'grpMine1';
    G.IsUserDefined := True;
    G.ItemLinks.AddItem(S.Bold);
    G2 := TFmrRibbonStructure.CreateGroup(S.TabHome, 'Extra');
    G2.Name := 'grpExtra';
    G2.IsUserDefined := True;
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      Assert.IsTrue(C.CanRemove(C.ShadowOf(G2)));
      C.Remove(C.ShadowOf(G2));
      // a custom tab holding a designed group cannot be removed until the group leaves
      C.Move(C.ShadowOf(S.GrpZoom), 1);
      Assert.AreEqual('tabMine', TFmrRibbonGroup(C.ShadowOf(S.GrpZoom)).Tab.Name);
      Assert.IsFalse(C.CanRemove(C.ShadowOf(T)));
      C.Move(C.ShadowOf(S.GrpZoom), -1);
      Assert.IsTrue(C.CanRemove(C.ShadowOf(T)));
      C.Remove(C.ShadowOf(T));
      C.Apply;
    finally
      C.Free;
    end;
    Assert.IsNull(TFmrRibbonStructure.FindTab(S.Ribbon, 'tabMine'));
    Assert.IsNull(TFmrRibbonStructure.FindGroup(S.Ribbon, 'grpExtra'));
    Assert.AreSame(TObject(S.TabView), TObject(S.GrpZoom.Tab));
    Assert.AreEqual(0, S.Bold.LinkCount - 1, 'only the designed link of Bold is left');
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.CustomLinksCanBeReorderedAndRenamed;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  G: TFmrRibbonGroup;
  T: TFmrRibbonTab;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      G := C.NewTab(nil);
      C.AddCommand(S.Bold, G);
      C.AddCommand(S.Italic, G);
      C.AddCommand(S.Underline, G);
      Assert.IsTrue(C.CanMove(G.ItemLinks[2], -1));
      C.Move(G.ItemLinks[2], -2);
      Assert.IsTrue(C.CanRename(G.ItemLinks[0]));
      C.Rename(G.ItemLinks[0], 'U');
      C.Rename(G.ItemLinks[1], 'Bold');
      C.Remove(G.ItemLinks[2]);
      C.Apply;
    finally
      C.Free;
    end;
    T := TFmrRibbonStructure.Tab(S.Ribbon, TFmrRibbonStructure.TabCount(S.Ribbon) - 1);
    Assert.IsTrue(T.IsUserDefined, 'a new tab without a selection goes last');
    G := T.Groups[0];
    Assert.AreEqual(2, G.ItemLinks.Count);
    Assert.AreSame(TObject(S.Underline), TObject(G.ItemLinks[0].Item));
    Assert.AreEqual('U', G.ItemLinks[0].UserCaption);
    Assert.AreEqual('', G.ItemLinks[1].UserCaption, 'the item caption is not a user caption');
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.ExportImportRoundTrip;
var
  S1, S2: TTestStructure;
  C: TFmrRibbonCustomization;
  G: TFmrRibbonGroup;
  Json: string;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S1.Ribbon);
    try
      G := C.NewTab(C.Tabs[1]);
      C.Rename(G, 'Favorites');
      C.AddCommand(S1.Find, G);
      C.SetVisible(C.ShadowOf(S1.GrpTables), False);
      C.AddToQAT(S1.Redo, 0);
      C.QATBelow := True;
      Json := C.SaveToString;
    finally
      C.Free;
    end;
    Assert.AreEqual(2, S1.Ribbon.QuickAccessToolbar.ItemLinks.Count, 'export does not touch the ribbon');
    C := TFmrRibbonCustomization.Create(S2.Ribbon);
    try
      C.LoadFromString(Json);
      Assert.AreEqual(Json, C.SaveToString, 'import into a session is lossless');
      C.Apply;
    finally
      C.Free;
    end;
    Assert.AreEqual(Json, TFmrRibbonLayoutStorage.SaveToString(S2.Ribbon));
    Assert.IsFalse(S2.GrpTables.Visible);
    Assert.AreEqual(TFmrQATPosition.BelowRibbon, S2.Ribbon.QuickAccessToolbar.Position);
    Assert.AreSame(TObject(S2.Redo), TObject(S2.Ribbon.QuickAccessToolbar.ItemLinks[0].Item));
    C := TFmrRibbonCustomization.Create(S2.Ribbon);
    try
      Assert.WillRaise(
        procedure
        begin
          C.LoadFromString('{"format":"something else"}');
        end, EFmrLayoutError);
    finally
      C.Free;
    end;
  finally
    S2.Free;
    S1.Free;
  end;
end;

procedure TCustomizeModelTests.ResetAllRestoresTheDefault;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  Default, Before: string;
  G: TFmrRibbonGroup;
begin
  S := TTestStructure.Create;
  try
    Default := TFmrRibbonLayoutStorage.SaveToString(S.Ribbon);
    Before := DumpStructure(S.Ribbon);
    C := TFmrRibbonCustomization.Create(S.Ribbon, Default);
    try
      G := C.NewTab(nil);
      C.AddCommand(S.Bold, G);
      C.SetVisible(C.ShadowOf(S.TabInsert), False);
      C.Rename(C.ShadowOf(S.GrpZoom), 'Lupe');
      C.Move(C.ShadowOf(S.TabView), -1);
      C.RemoveFromQAT(0);
      C.Apply;
    finally
      C.Free;
    end;
    Assert.AreNotEqual(Before, DumpStructure(S.Ribbon));
    C := TFmrRibbonCustomization.Create(S.Ribbon, Default);
    try
      C.ResetAll;
      C.Apply;
    finally
      C.Free;
    end;
    Assert.AreEqual(Before, DumpStructure(S.Ribbon));
    Assert.AreEqual(Default, TFmrRibbonLayoutStorage.SaveToString(S.Ribbon));
    Assert.AreEqual(2, S.Ribbon.QuickAccessToolbar.ItemLinks.Count);
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.ResetTabRestoresOneTab;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  Default: string;
  Home: TFmrRibbonTab;
begin
  S := TTestStructure.Create;
  try
    Default := TFmrRibbonLayoutStorage.SaveToString(S.Ribbon);
    C := TFmrRibbonCustomization.Create(S.Ribbon, Default);
    try
      Home := TFmrRibbonTab(C.ShadowOf(S.TabHome));
      C.Rename(Home, 'Start');
      C.SetVisible(C.ShadowOf(S.GrpFont), False);
      C.Move(C.ShadowOf(S.GrpStyles), 1);          // into Insert
      C.Move(C.ShadowOf(S.GrpTables), -1);         // first in Insert
      C.Move(C.ShadowOf(S.GrpTables), -1);         // into Home (at the end)
      C.NewGroup(Home);
      C.SetVisible(C.ShadowOf(S.TabView), False);  // another tab: not reset
      Assert.IsTrue(C.CanResetTab(Home));
      C.ResetTab(Home);
      Assert.IsFalse(C.CanResetTab(TFmrRibbonTab(C.NewTab(nil).Tab)), 'custom tabs have no default');
      C.Remove(C.Tabs[High(C.Tabs)].Groups[0]);
      C.Remove(C.Tabs[High(C.Tabs)]);
      C.Apply;
    finally
      C.Free;
    end;
    Assert.AreEqual('Home', S.TabHome.DisplayCaption);
    Assert.AreEqual(3, S.TabHome.GroupCount);
    Assert.IsTrue(S.GrpFont.Visible);
    Assert.AreSame(TObject(S.TabHome), TObject(S.GrpStyles.Tab));
    Assert.AreEqual(2, S.GrpStyles.GroupIndex);
    Assert.AreSame(TObject(S.TabInsert), TObject(S.GrpTables.Tab), 'a group from another tab goes home');
    Assert.IsFalse(S.TabView.Visible, 'other tabs keep their customization');
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.QuickAccessToolbarEditing;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  Q: TFmrItemLinks;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon, TFmrRibbonLayoutStorage.SaveToString(S.Ribbon));
    try
      Assert.IsFalse(C.CanAddToQAT(S.Save), 'already there');
      Assert.IsTrue(C.CanAddToQAT(S.Redo));
      C.AddToQAT(S.Redo);
      C.AddToQAT(S.Bold, 0);
      Q := C.QuickAccessToolbar.ItemLinks;
      Assert.AreEqual('btnBold,btnSave,btnUndo,btnRedo', Q[0].Item.Name + ',' + Q[1].Item.Name + ',' +
        Q[2].Item.Name + ',' + Q[3].Item.Name);
      Assert.IsFalse(C.CanMoveInQAT(0, -1));
      C.MoveInQAT(0, 2);
      C.SetQATSeparator(1, True);
      C.RemoveFromQAT(0);
      C.QATBelow := True;
      C.Apply;
      Q := S.Ribbon.QuickAccessToolbar.ItemLinks;
      Assert.AreEqual(3, Q.Count);
      Assert.AreEqual('btnUndo', Q[0].Item.Name);
      Assert.IsTrue(Q[0].BeginGroup);
      Assert.AreEqual('btnBold', Q[1].Item.Name);
      Assert.AreEqual('btnRedo', Q[2].Item.Name);
      Assert.AreEqual(TFmrQATPosition.BelowRibbon, S.Ribbon.QuickAccessToolbar.Position);
      C.ResetQAT;
      Assert.AreEqual(2, C.QuickAccessToolbar.ItemLinks.Count);
      Assert.IsFalse(C.QATBelow);
    finally
      C.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.CommandSourcesAndLists;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  Sources: TArray<TFmrCommandSource>;
  Items: TArray<TFmrBarItem>;
  Unnamed: TFmrButtonItem;
  I: TFmrBarItem;
  Names: string;
begin
  S := TTestStructure.Create;
  try
    S.Bold.Category := 'Format';
    S.Italic.Category := 'Format';
    S.Save.Category := 'File';
    Unnamed := TFmrButtonItem(S.Manager.CreateItem(TFmrButtonItem));
    Unnamed.Caption := 'Unnamed';
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      Sources := C.CommandSources;
      Assert.AreEqual(TFmrCommandSourceKind.AllCommands, Sources[0].Kind);
      Assert.AreEqual(TFmrCommandSourceKind.NotInRibbon, Sources[1].Kind);
      Assert.AreEqual(TFmrCommandSourceKind.Tab, Sources[2].Kind);
      Assert.AreEqual(2 + 4 + 2, Integer(Length(Sources)), 'two lists, four tabs, two categories');
      Assert.AreEqual('Format (Picture Tools)', Sources[5].Caption);
      Assert.AreEqual('File', Sources[6].Category, 'categories sorted');

      Items := C.Commands(Sources[0]);
      Assert.AreEqual(13, Integer(Length(Items)), 'every named item; unnamed items cannot be stored in a layout');
      Assert.AreEqual('Bold', Items[0].Caption, 'sorted by caption');
      Names := '';
      for I in C.Commands(Sources[1]) do
        Names := Names + I.Name + ' ';
      Assert.AreEqual('btnRedo btnSave btnUndo ', Names, 'commands not in the ribbon');
      Items := C.Commands(Sources[2]);
      Assert.AreEqual('btnPaste', Items[0].Name, 'a tab lists its commands in ribbon order');
      Assert.AreEqual(9, Integer(Length(Items)));
      Items := C.Commands(Sources[7]);
      Assert.AreEqual(2, Integer(Length(Items)));
      Items := C.Commands(Sources[0], 'ITAL');
      Assert.AreEqual(1, Integer(Length(Items)));
      Assert.AreEqual('btnItalic', Items[0].Name);
    finally
      C.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure TCustomizeModelTests.ApplyTwiceChangesNothing;
var
  S: TTestStructure;
  C: TFmrRibbonCustomization;
  G: TFmrRibbonGroup;
  First: string;
begin
  S := TTestStructure.Create;
  try
    C := TFmrRibbonCustomization.Create(S.Ribbon);
    try
      G := C.NewTab(nil);
      C.AddCommand(S.Bold, G);
      C.Apply;
      First := TFmrRibbonLayoutStorage.SaveToString(S.Ribbon);
      S.Ribbon.ResetCounters;
      C.Apply;
      Assert.AreEqual(First, TFmrRibbonLayoutStorage.SaveToString(S.Ribbon));
      Assert.AreEqual(0, S.Ribbon.LinkRemovingCount, 'unchanged links are not rebuilt');
      Assert.AreEqual(1, S.Ribbon.UpdateBatches, 'one structure update');
    finally
      C.Free;
    end;
  finally
    S.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCustomizeModelTests);

end.
