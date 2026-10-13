unit FMR.Tests.Merge;

interface

uses
  System.SysUtils, System.Classes, DUnitX.TestFramework, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Structure, FMR.Ribbon.Merge, FMR.Tests.Fakes;

type
  /// <summary>A second form (an MDI child) with its own manager, items and ribbon.</summary>
  TSourceForm = class
  public
    Root: TFmrTestRoot;
    Manager: TFmrBarManager;
    Ribbon: TFakeRibbon;
    SpecialPaste, Document, Spelling, Comments: TFmrButtonItem;
    TabHome, TabReview: TFmrRibbonTab;
    GrpClipboard, GrpDocument, GrpProofing: TFmrRibbonGroup;
    constructor Create;
    destructor Destroy; override;
    function NewButton(const AName: string): TFmrButtonItem;
    function NewTab(const AName, ACaption: string): TFmrRibbonTab;
    function NewGroup(const ATab: TFmrRibbonTab; const AName, ACaption: string): TFmrRibbonGroup;
  end;

  [TestFixture]
  TMergeTests = class
  private
    T: TTestStructure;
    Src: TSourceForm;
    Merger: TFmrRibbonMerger;
    Original: string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure MergeAddsAndAppends;
    [Test] procedure UnmergeRestores;
    [Test] procedure MergeOrderPositionsTabs;
    [Test] procedure ReplaceHidesAndRestores;
    [Test] procedure RemoveHidesGroup;
    [Test] procedure SourceIsNotChanged;
    [Test] procedure MergeTwiceIsRefused;
    [Test] procedure DestroyedSourceIsUnmerged;
    [Test] procedure ContextGroupsAreMapped;
    [Test] procedure CopiesAreNotStored;
    [Test] procedure TwoSourcesUnmergeIndependently;
  end;

implementation

{ TSourceForm }

constructor TSourceForm.Create;
begin
  inherited;
  Root := TFmrTestRoot.Create(nil);
  Manager := TFmrBarManager.Create(Root);
  Manager.Parent := Root;
  Ribbon := TFakeRibbon.Create(Root);
  Ribbon.Parent := Root;
  Ribbon.BarManager := Manager;
  SpecialPaste := NewButton('srcSpecialPaste');
  Document := NewButton('srcDocument');
  Spelling := NewButton('srcSpelling');
  Comments := NewButton('srcComments');
  TabHome := NewTab('tabHome', 'Home');
  GrpClipboard := NewGroup(TabHome, 'grpClipboard', 'Clipboard');
  GrpClipboard.ItemLinks.AddItem(SpecialPaste);
  GrpDocument := NewGroup(TabHome, 'grpDocument', 'Document');
  GrpDocument.ItemLinks.AddItem(Document);
  TabReview := NewTab('tabReview', 'Review');
  TabReview.MergeOrder := 5;
  GrpProofing := NewGroup(TabReview, 'grpProofing', 'Proofing');
  GrpProofing.ItemLinks.AddItem(Spelling);
  GrpProofing.ItemLinks.AddItem(Comments);
end;

destructor TSourceForm.Destroy;
begin
  Root.Free;
  inherited;
end;

function TSourceForm.NewButton(const AName: string): TFmrButtonItem;
begin
  Result := TFmrButtonItem(Manager.CreateItem(TFmrButtonItem, AName));
  Result.Caption := AName;
end;

function TSourceForm.NewGroup(const ATab: TFmrRibbonTab; const AName, ACaption: string): TFmrRibbonGroup;
begin
  Result := TFmrRibbonGroup.Create(Root);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Parent := ATab;
end;

function TSourceForm.NewTab(const AName, ACaption: string): TFmrRibbonTab;
begin
  Result := TFmrRibbonTab.Create(Root);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Parent := Ribbon;
end;

{ TMergeTests }

procedure TMergeTests.Setup;
begin
  T := TTestStructure.Create;
  Src := TSourceForm.Create;
  Merger := TFmrRibbonMerger.Create(nil, T.Ribbon);
  Original := DumpStructure(T.Ribbon);
end;

procedure TMergeTests.TearDown;
begin
  FreeAndNil(Merger);
  FreeAndNil(Src);
  FreeAndNil(T);
end;

procedure TMergeTests.MergeAddsAndAppends;
begin
  Assert.IsTrue(Merger.Merge(Src.Ribbon));
  Assert.IsTrue(Merger.IsMerged(Src.Ribbon));
  Assert.AreEqual(
    'Home[Clipboard(btnPaste,btnCut,btnCopy,srcSpecialPaste),Font(cbFontName,btnBold,btnItalic,btnUnderline),' +
    'Styles(galStyles,btnFind),Document(srcDocument)]' +
    'Insert[Tables(btnPaste)]View[Zoom(btnZoom)]Format[Arrange(btnCopy)]Review[Proofing(srcSpelling,srcComments)]',
    DumpStructure(T.Ribbon));
  Assert.AreEqual(1, T.Ribbon.UpdateBatches, 'one structure batch');
end;

procedure TMergeTests.UnmergeRestores;
begin
  Merger.Merge(Src.Ribbon);
  Assert.IsTrue(Merger.Unmerge(Src.Ribbon));
  Assert.AreEqual(Original, DumpStructure(T.Ribbon));
  Assert.IsFalse(Merger.IsMerged(Src.Ribbon));
  Assert.IsFalse(Merger.Unmerge(Src.Ribbon));
  Assert.AreEqual(1, Src.SpecialPaste.LinkCount, 'only the source link is left');
end;

procedure TMergeTests.MergeOrderPositionsTabs;
var
  Review: TFmrRibbonTab;
begin
  T.TabView.MergeOrder := 10;
  T.TabPicture.MergeOrder := 10;
  Merger.Merge(Src.Ribbon);
  Review := TFmrRibbonStructure.FindTab(T.Ribbon, 'Review');
  Assert.AreEqual(2, Review.TabIndex, 'before the first target tab with a greater MergeOrder');
  Assert.AreSame(TFmrRibbonStructureObject(Src.TabReview), Review.MergedFrom);
  Src.GrpDocument.MergeOrder := -1;
  Merger.Unmerge(Src.Ribbon);
  Merger.Merge(Src.Ribbon);
  Assert.AreEqual('Document', T.TabHome.Groups[0].Caption, 'groups are positioned by MergeOrder as well');
end;

procedure TMergeTests.ReplaceHidesAndRestores;
var
  Insert: TFmrRibbonTab;
begin
  Insert := Src.NewTab('tabInsert', 'Insert');
  Insert.MergeKind := TFmrMergeKind.Replace;
  Src.NewGroup(Insert, 'grpPictures', 'Pictures').ItemLinks.AddItem(Src.Document);
  Merger.Merge(Src.Ribbon);
  Assert.IsFalse(T.TabInsert.Visible);
  Assert.AreEqual('Pictures', TFmrRibbonStructure.Tab(T.Ribbon, 2).Groups[0].Caption, 'the copy takes its place');
  Merger.Unmerge(Src.Ribbon);
  Assert.IsTrue(T.TabInsert.Visible);
  Assert.AreEqual(Original, DumpStructure(T.Ribbon));
end;

procedure TMergeTests.RemoveHidesGroup;
var
  G: TFmrRibbonGroup;
begin
  G := Src.NewGroup(Src.TabHome, 'grpFont', 'Font');
  G.MergeKind := TFmrMergeKind.Remove;
  T.GrpStyles.Visible := False;
  Merger.Merge(Src.Ribbon);
  Assert.IsFalse(T.GrpFont.Visible);
  Merger.Unmerge(Src.Ribbon);
  Assert.IsTrue(T.GrpFont.Visible);
  Assert.IsFalse(T.GrpStyles.Visible, 'what was hidden before stays hidden');
end;

procedure TMergeTests.SourceIsNotChanged;
var
  Before: string;
begin
  Before := DumpStructure(Src.Ribbon);
  Merger.Merge(Src.Ribbon);
  Assert.AreEqual(Before, DumpStructure(Src.Ribbon));
  Merger.Unmerge(Src.Ribbon);
  Assert.AreEqual(Before, DumpStructure(Src.Ribbon));
end;

procedure TMergeTests.MergeTwiceIsRefused;
begin
  Assert.IsTrue(Merger.Merge(Src.Ribbon));
  Assert.IsFalse(Merger.Merge(Src.Ribbon));
  Assert.IsFalse(Merger.Merge(T.Ribbon), 'the target cannot be merged into itself');
  Assert.AreEqual(1, Merger.MergedCount);
end;

procedure TMergeTests.DestroyedSourceIsUnmerged;
begin
  Merger.Merge(Src.Ribbon);
  FreeAndNil(Src);
  Assert.AreEqual(Original, DumpStructure(T.Ribbon));
  Assert.AreEqual(0, Merger.MergedCount);
end;

procedure TMergeTests.ContextGroupsAreMapped;
var
  Ctx: TFmrRibbonContextGroup;
  Tab, Copy: TFmrRibbonTab;
begin
  Ctx := TFmrRibbonContextGroup.Create(Src.Root);
  Ctx.Name := 'ctxTable';
  Ctx.Caption := 'Table Tools';
  Ctx.Parent := Src.Ribbon;
  Tab := Src.NewTab('tabTableDesign', 'Table Design');
  Tab.ContextGroup := Ctx;
  Tab := Src.NewTab('tabPicture', 'Format');
  Tab.ContextGroup := Ctx;
  Merger.Merge(Src.Ribbon);
  Copy := TFmrRibbonStructure.FindTab(T.Ribbon, 'Table Design');
  Assert.IsNotNull(Copy.ContextGroup);
  Assert.AreEqual('Table Tools', Copy.ContextGroup.Caption);
  Assert.AreEqual(2, Integer(Length(TFmrRibbonStructure.ContextGroups(T.Ribbon))));
  Merger.Unmerge(Src.Ribbon);
  Assert.AreEqual(1, Integer(Length(TFmrRibbonStructure.ContextGroups(T.Ribbon))));
end;

procedure TMergeTests.CopiesAreNotStored;
var
  Review: TFmrRibbonTab;
begin
  Merger.Merge(Src.Ribbon);
  Review := TFmrRibbonStructure.FindTab(T.Ribbon, 'Review');
  Assert.IsFalse(Review.Stored);
  Assert.IsFalse(Review.Groups[0].Stored);
end;

procedure TMergeTests.TwoSourcesUnmergeIndependently;
var
  Src2: TSourceForm;
  WithFirst: string;
begin
  Merger.Merge(Src.Ribbon);
  WithFirst := DumpStructure(T.Ribbon);
  Src2 := TSourceForm.Create;
  try
    Src2.TabReview.Caption := 'Review';
    Merger.Merge(Src2.Ribbon);
    Assert.AreEqual(2, Merger.MergedCount);
    Merger.Unmerge(Src2.Ribbon);
    Assert.AreEqual(WithFirst, DumpStructure(T.Ribbon));
    Merger.Merge(Src2.Ribbon);
    Merger.UnmergeAll;
    Assert.AreEqual(Original, DumpStructure(T.Ribbon));
  finally
    Src2.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMergeTests);

end.
