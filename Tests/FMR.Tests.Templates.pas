unit FMR.Tests.Templates;

/// Run-time template builder (FMR.Ribbon.Templates) on the fake ribbon: structure, names, links, quick access
/// toolbar, categories, repeated application, replacement and streaming of the result.

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, DUnitX.TestFramework, FMX.Types,
  FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Images, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Templates,
  FMR.Tests.Fakes;

type
  [TestFixture]
  TTemplateTests = class
  private
    Root: TFmrTestRoot;
    Manager: TFmrBarManager;
    Ribbon: TFakeRibbon;
    function TabCaptions: string;
    function GroupCaptions(const ATab: TFmrRibbonTab): string;
    procedure CheckNamesUnique;
    procedure CheckLinks;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure DocumentStructure;
    [Test] procedure SpreadsheetStructure;
    [Test] procedure SimpleStructure;
    [Test] procedure TemplateCaptions;
    [Test] procedure ItemsHaveGlyphsAndCategories;
    [Test] procedure QuickAccessToolbar;
    [Test] procedure SecondApplicationGetsUniqueNames;
    [Test] procedure ReplaceDeletesOldTabs;
    [Test] procedure NamerIsUsed;
    [Test] procedure NoManagerRaises;
    [Test] procedure StreamingRoundTrip;
  end;

implementation

{ TTemplateTests }

procedure TTemplateTests.Setup;
begin
  Root := TFmrTestRoot.Create(nil);
  Root.Name := 'Root';
  Manager := TFmrBarManager.Create(Root);
  Manager.Name := 'BarManager';
  Manager.Parent := Root;
  Ribbon := TFakeRibbon.Create(Root);
  Ribbon.Name := 'Ribbon';
  Ribbon.Parent := Root;
  Ribbon.BarManager := Manager;
end;

procedure TTemplateTests.TearDown;
begin
  FreeAndNil(Root);
end;

function TTemplateTests.TabCaptions: string;
var
  T: TFmrRibbonTab;
begin
  Result := '';
  for T in TFmrRibbonStructure.Tabs(Ribbon) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + T.Caption;
  end;
end;

function TTemplateTests.GroupCaptions(const ATab: TFmrRibbonTab): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to ATab.GroupCount - 1 do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + ATab.Groups[I].Caption;
  end;
end;

procedure TTemplateTests.CheckNamesUnique;
var
  Names: TDictionary<string, Integer>;
  I: Integer;
  N: string;
begin
  Names := TDictionary<string, Integer>.Create;
  try
    for I := 0 to Root.ComponentCount - 1 do
    begin
      N := UpperCase(Root.Components[I].Name);
      Assert.IsFalse(N = '', 'component without a name: ' + Root.Components[I].ClassName);
      Assert.IsFalse(Names.ContainsKey(N), 'duplicate name ' + N);
      Names.Add(N, I);
    end;
  finally
    Names.Free;
  end;
end;

procedure TTemplateTests.CheckLinks;
var
  G: TFmrRibbonGroup;
  I: Integer;
begin
  for G in TFmrRibbonStructure.AllGroups(Ribbon) do
  begin
    Assert.IsTrue(G.ItemLinks.Count > 0, 'empty group ' + G.Name);
    for I := 0 to G.ItemLinks.Count - 1 do
    begin
      Assert.IsNotNull(G.ItemLinks[I].Item, 'link without item in ' + G.Name);
      Assert.AreSame(Manager, G.ItemLinks[I].Item.Manager, 'item of another manager in ' + G.Name);
    end;
  end;
end;

procedure TTemplateTests.DocumentStructure;
var
  First: TFmrRibbonTab;
  Ctx: TArray<TFmrRibbonContextGroup>;
begin
  First := FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Document);
  Assert.AreEqual('Home,Insert,Layout,View,Table Design,Table Layout', TabCaptions);
  Assert.AreEqual('Clipboard,Font,Paragraph,Styles,Editing', GroupCaptions(TFmrRibbonStructure.Tab(Ribbon, 0)));
  Assert.AreEqual('Pages,Tables,Illustrations,Links,Comments,Header && Footer,Text,Symbols',
    GroupCaptions(TFmrRibbonStructure.Tab(Ribbon, 1)));
  Ctx := TFmrRibbonStructure.ContextGroups(Ribbon);
  Assert.AreEqual(1, Integer(Length(Ctx)));
  Assert.AreEqual('Table Tools', Ctx[0].Caption);
  Assert.AreEqual(2, Integer(Length(Ctx[0].Tabs)));
  Assert.AreEqual('tabHome', First.Name);
  Assert.AreSame(First, Ribbon.ActiveTab, 'the first tab becomes active');
  Assert.AreEqual('H', First.KeyTip);
  CheckNamesUnique;
  CheckLinks;
end;

procedure TTemplateTests.SpreadsheetStructure;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Spreadsheet);
  Assert.AreEqual('Home,Insert,Formulas,Data,View', TabCaptions);
  Assert.AreEqual('Clipboard,Font,Alignment,Number,Styles,Cells,Editing',
    GroupCaptions(TFmrRibbonStructure.Tab(Ribbon, 0)));
  Assert.AreEqual(0, Integer(Length(TFmrRibbonStructure.ContextGroups(Ribbon))));
  CheckNamesUnique;
  CheckLinks;
end;

procedure TTemplateTests.SimpleStructure;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Simple);
  Assert.AreEqual('Home,View', TabCaptions);
  Assert.AreEqual('Clipboard,Font,Editing', GroupCaptions(TFmrRibbonStructure.Tab(Ribbon, 0)));
  CheckNamesUnique;
  CheckLinks;
end;

procedure TTemplateTests.TemplateCaptions;
begin
  Assert.AreEqual('Simple', TFmrRibbonTemplateBuilder.TemplateCaption(TFmrRibbonTemplate.Simple));
  Assert.AreEqual('Document', TFmrRibbonTemplateBuilder.TemplateCaption(TFmrRibbonTemplate.Document));
  Assert.AreEqual('Spreadsheet', TFmrRibbonTemplateBuilder.TemplateCaption(TFmrRibbonTemplate.Spreadsheet));
end;

procedure TTemplateTests.ItemsHaveGlyphsAndCategories;
var
  Paste, Bold: TFmrBarItem;
  G: TFmrRibbonGroup;
  I: Integer;
  L: TFmrItemLink;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Document);
  Paste := Manager.ItemByName('btnPaste');
  Assert.AreEqual(Cardinal(FmrGlyphPaste), Paste.Glyph.GlyphCode, 'one glyph for large and small buttons');
  Assert.IsTrue(TFmrViewLevel.Large in Paste.DefaultViewLevels);
  Assert.AreEqual('Home', Paste.Category);
  Assert.AreEqual(TFmrButtonStyle.Split, TFmrButtonItem(Paste).ButtonStyle);
  Assert.IsTrue(TFmrButtonItem(Paste).DropDownLinks.Count >= 2, 'paste menu');
  G := TFmrRibbonStructure.FindGroup(Ribbon, 'grpClipboard');
  Assert.IsTrue(TFmrViewLevel.Large in G.ItemLinks.FindByItem(Paste).EffectiveViewLevels);
  Assert.IsFalse(TFmrViewLevel.Large in G.ItemLinks.FindByItem(Manager.ItemByName('btnCut')).EffectiveViewLevels,
    'compact links stay compact even though the same glyph can be drawn large');
  Bold := Manager.ItemByName('btnBold');
  Assert.AreEqual(Cardinal(FmrGlyphBold), Bold.Glyph.GlyphCode);
  Assert.AreEqual(TFmrImageKind.Glyph, Bold.Glyph.EffectiveKind);
  Assert.IsTrue(Manager.Categories.IndexOf('Insert') >= 0);
  // Bold is an icon-only member of a button group row.
  G := TFmrRibbonStructure.FindGroup(Ribbon, 'grpFont');
  L := G.ItemLinks.FindByItem(Bold);
  Assert.IsTrue(L.ViewLevels = [TFmrViewLevel.Small]);
  Assert.AreEqual(TFmrButtonGroupPosition.Start, L.ButtonGroup);
  // Every button of the ribbon (not the menu entries) has a glyph.
  for G in TFmrRibbonStructure.AllGroups(Ribbon) do
    for I := 0 to G.ItemLinks.Count - 1 do
      if (G.ItemLinks[I].Item is TFmrButtonItem) then
        Assert.IsFalse(G.ItemLinks[I].Item.Glyph.IsEmpty, 'no glyph: ' + G.ItemLinks[I].Item.Name);
end;

procedure TTemplateTests.QuickAccessToolbar;
var
  QAT: TFmrRibbonQuickAccessToolbar;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Document);
  QAT := Ribbon.QuickAccessToolbar;
  Assert.AreEqual(3, QAT.ItemLinks.Count);
  Assert.AreEqual('btnSave', QAT.ItemLinks[0].Item.Name);
  Assert.AreEqual('btnUndo', QAT.ItemLinks[1].Item.Name);
  Assert.AreEqual('btnRedo', QAT.ItemLinks[2].Item.Name);
  Assert.AreEqual(Integer(TShortCut($4000 or Ord('S'))), Integer(QAT.ItemLinks[0].Item.ShortCut));
end;

procedure TTemplateTests.SecondApplicationGetsUniqueNames;
var
  Count: Integer;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Simple);
  Count := Manager.ItemCount;
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Simple);
  Assert.AreEqual(2 * Count, Manager.ItemCount);
  Assert.AreEqual('Home,View,Home,View', TabCaptions);
  Assert.IsNotNull(Manager.FindItem('btnPaste1'));
  Assert.IsNotNull(Root.FindComponent('tabHome1'));
  CheckNamesUnique;
end;

procedure TTemplateTests.ReplaceDeletesOldTabs;
var
  Items: Integer;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Document);
  Items := Manager.ItemCount;
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Simple, nil, True);
  Assert.AreEqual('Home,View', TabCaptions);
  Assert.AreEqual(0, Integer(Length(TFmrRibbonStructure.ContextGroups(Ribbon))), 'context groups deleted');
  Assert.AreEqual(3, Ribbon.QuickAccessToolbar.ItemLinks.Count, 'QAT replaced, not appended');
  Assert.IsTrue(Manager.ItemCount > Items, 'items of the old structure are kept');
  CheckNamesUnique;
  CheckLinks;
end;

procedure TTemplateTests.NamerIsUsed;
var
  Calls: Integer;
begin
  Calls := 0;
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Simple, nil, False,
    function(const ABaseName: string): string
    begin
      Inc(Calls);
      Result := 'x' + ABaseName;
    end);
  Assert.IsTrue(Calls > 10);
  Assert.IsNotNull(Root.FindComponent('xtabHome'));
  Assert.IsNotNull(Manager.FindItem('xbtnPaste'));
end;

procedure TTemplateTests.NoManagerRaises;
begin
  Ribbon.BarManager := nil;
  Assert.WillRaise(
    procedure
    begin
      FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Simple);
    end, EFmrTemplateError);
end;

procedure TTemplateTests.StreamingRoundTrip;
var
  S: TMemoryStream;
  Copy: TFmrTestRoot;
  R: TFakeRibbon;
  Before, After: string;
begin
  FmrApplyRibbonTemplate(Ribbon, TFmrRibbonTemplate.Document);
  Before := DumpStructure(Ribbon);
  S := TMemoryStream.Create;
  Copy := nil;
  try
    S.WriteComponent(Root);
    S.Position := 0;
    Copy := TFmrTestRoot.Create(nil);
    S.ReadComponent(Copy);
    R := Copy.FindComponent('Ribbon') as TFakeRibbon;
    After := DumpStructure(R);
    Assert.AreEqual(Before, After);
    Assert.AreEqual(3, R.QuickAccessToolbar.ItemLinks.Count);
    Assert.AreEqual(Cardinal(FmrGlyphCopy), (Copy.FindComponent('btnCopy') as TFmrBarItem).Glyph.GlyphCode);
  finally
    Copy.Free;
    S.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTemplateTests);

end.
