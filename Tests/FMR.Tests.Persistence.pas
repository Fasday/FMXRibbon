unit FMR.Tests.Persistence;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON, DUnitX.TestFramework, FMR.Ribbon.Types,
  FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Persistence, FMR.Tests.Fakes;

type
  [TestFixture]
  TPersistenceTests = class
  private
    procedure Customize(const S: TTestStructure);
  public
    [Test] procedure RoundTripIsLossless;
    [Test] procedure LoadingTwiceDoesNotDuplicate;
    [Test] procedure UnknownNamesAreSkipped;
    [Test] procedure NewTabsKeepTheirPosition;
    [Test] procedure DesignedLinksAreNotOverwritten;
    [Test] procedure StreamAndFile;
    [Test] procedure InvalidInputRaises;
    [Test] procedure LoadIsOneStructureBatch;
  end;

implementation

{ TPersistenceTests }

procedure TPersistenceTests.Customize(const S: TTestStructure);
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  Options: TFmrRibbonLayoutOptions;
begin
  S.TabView.Visible := False;
  S.GrpFont.UserCaption := 'My Font';
  S.TabHome.UserCaption := 'Start';
  S.GrpStyles.Visible := False;
  TFmrRibbonStructure.MoveTab(S.TabInsert, 0);
  TFmrRibbonStructure.MoveGroup(S.GrpStyles, S.TabHome, 0);

  T := TFmrRibbonStructure.CreateTab(S.Ribbon, 'My Tab', 1);
  T.Name := 'tabCustom1';
  T.IsUserDefined := True;
  T.KeyTip := 'Y';
  G := TFmrRibbonStructure.CreateGroup(T, 'My Group');
  G.Name := 'grpCustom1';
  G.IsUserDefined := True;
  G.ItemLinks.AddItem(S.Bold).ViewLevels := [TFmrViewLevel.Large];
  G.ItemLinks.AddItem(S.Italic, True).UserCaption := 'Slanted';
  G.ItemLinks.AddItem(S.Underline).ButtonGroup := TFmrButtonGroupPosition.Start;
  G.ItemLinks.AddItem(S.Find).SimplifiedVisibility := TFmrSimplifiedVisibility.Overflow;
  // a designed group moved into the user-defined tab
  TFmrRibbonStructure.MoveGroup(S.GrpZoom, T);
  // an unnamed user-defined group in a designed tab
  G := TFmrRibbonStructure.CreateGroup(S.TabHome, 'Extra', 1);
  G.IsUserDefined := True;
  G.ItemLinks.AddItem(S.Cut).KeyTip := 'XC';
  G.ItemLinks.AddItem(S.Copy).Visible := False;

  S.Ribbon.QuickAccessToolbar.ItemLinks.AddItem(S.Redo, True);
  S.Ribbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon;
  Options := S.Ribbon.Options;
  Options.DisplayMode := TFmrRibbonDisplayMode.Simplified;
  Options.Minimized := True;
  Options.ShowMode := TFmrRibbonShowMode.TabsOnly;
  S.Ribbon.Options := Options;
end;

procedure TPersistenceTests.RoundTripIsLossless;
var
  S1, S2: TTestStructure;
  Json1, Json2: string;
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  try
    Customize(S1);
    Json1 := TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon);
    TFmrRibbonLayoutStorage.LoadFromString(S2.Ribbon, Json1);
    Json2 := TFmrRibbonLayoutStorage.SaveToString(S2.Ribbon);
    Assert.AreEqual(Json1, Json2);
    Assert.AreEqual(DumpStructure(S1.Ribbon), DumpStructure(S2.Ribbon));

    Assert.IsFalse(S2.TabView.Visible);
    Assert.AreEqual('My Font', S2.GrpFont.DisplayCaption);
    Assert.AreEqual('Start', S2.TabHome.DisplayCaption);
    Assert.AreEqual('Home', S2.TabHome.Caption, 'the designed caption is kept');
    Assert.AreEqual(0, S2.TabInsert.TabIndex);
    Assert.AreSame(S2.TabHome, S2.GrpStyles.Tab);
    Assert.AreEqual(0, S2.GrpStyles.GroupIndex);

    T := TFmrRibbonStructure.FindTab(S2.Ribbon, 'tabCustom1');
    Assert.IsNotNull(T);
    Assert.IsTrue(T.IsUserDefined);
    Assert.AreEqual(1, T.TabIndex);
    Assert.AreEqual('Y', T.KeyTip);
    Assert.AreEqual(2, T.GroupCount);
    Assert.AreSame(S2.GrpZoom, T.Groups[1], 'the designed group was moved, not copied');
    G := T.Groups[0];
    Assert.AreEqual('grpCustom1', G.Name);
    Assert.AreEqual(4, G.ItemLinks.Count);
    Assert.AreSame(TFmrBarItem(S2.Bold), G.ItemLinks[0].Item, 'links reference the items of the loading form');
    Assert.IsTrue(G.ItemLinks[0].ViewLevels = [TFmrViewLevel.Large]);
    Assert.IsTrue(G.ItemLinks[1].BeginGroup);
    Assert.AreEqual('Slanted', G.ItemLinks[1].UserCaption);
    Assert.AreEqual(TFmrButtonGroupPosition.Start, G.ItemLinks[2].ButtonGroup);
    Assert.AreEqual(TFmrSimplifiedVisibility.Overflow, G.ItemLinks[3].SimplifiedVisibility);

    G := S2.TabHome.Groups[1];
    Assert.IsTrue(G.IsUserDefined);
    Assert.AreEqual('Extra', G.Caption);
    Assert.AreEqual('XC', G.ItemLinks[0].KeyTip);
    Assert.IsFalse(G.ItemLinks[1].Visible);

    Assert.AreEqual(3, S2.Ribbon.QuickAccessToolbar.ItemLinks.Count);
    Assert.IsTrue(S2.Ribbon.QuickAccessToolbar.ItemLinks[2].BeginGroup);
    Assert.AreEqual(TFmrQATPosition.BelowRibbon, S2.Ribbon.QuickAccessToolbar.Position);
    Assert.AreEqual(TFmrRibbonDisplayMode.Simplified, S2.Ribbon.Options.DisplayMode);
    Assert.IsTrue(S2.Ribbon.Options.Minimized);
    Assert.AreEqual(TFmrRibbonShowMode.TabsOnly, S2.Ribbon.Options.ShowMode);
  finally
    S2.Free;
    S1.Free;
  end;
end;

procedure TPersistenceTests.LoadingTwiceDoesNotDuplicate;
var
  S1, S2: TTestStructure;
  Json: string;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  try
    Customize(S1);
    Json := TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon);
    TFmrRibbonLayoutStorage.LoadFromString(S2.Ribbon, Json);
    TFmrRibbonLayoutStorage.LoadFromString(S2.Ribbon, Json);
    Assert.AreEqual(DumpStructure(S1.Ribbon), DumpStructure(S2.Ribbon));
    Assert.AreEqual(Json, TFmrRibbonLayoutStorage.SaveToString(S2.Ribbon));
    // loading into the customized form itself changes nothing either
    TFmrRibbonLayoutStorage.LoadFromString(S1.Ribbon, Json);
    Assert.AreEqual(Json, TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon));
  finally
    S2.Free;
    S1.Free;
  end;
end;

procedure TPersistenceTests.UnknownNamesAreSkipped;
const
  Layout =
    '{"format":"FMR.RibbonLayout","version":1,' +
    '"qat":{"position":"Nowhere","visible":true,"links":[{"item":"btnSave"},{"item":"btnGone"},{"item":"btnRedo"}]},' +
    '"tabs":[{"name":"tabGone","visible":false,"groups":[]},' +
    '{"name":"tabView","visible":false,"groups":[{"name":"grpGone"},{"name":"grpZoom","visible":false}]},' +
    '{"name":"tabUser","userDefined":true,"caption":"Mine","visible":true,"groups":[' +
    '{"userDefined":true,"caption":"G","links":[{"item":"nope"},{"item":"btnCut","viewLevels":"Small,Bogus"}]}]}]}';
var
  S: TTestStructure;
  T: TFmrRibbonTab;
begin
  S := TTestStructure.Create;
  try
    TFmrRibbonLayoutStorage.LoadFromString(S.Ribbon, Layout);
    Assert.AreEqual(2, S.Ribbon.QuickAccessToolbar.ItemLinks.Count);
    Assert.AreSame(TFmrBarItem(S.Redo), S.Ribbon.QuickAccessToolbar.ItemLinks[1].Item);
    Assert.AreEqual(TFmrQATPosition.AboveRibbon, S.Ribbon.QuickAccessToolbar.Position, 'unknown enum value ignored');
    Assert.IsFalse(S.TabView.Visible);
    Assert.IsFalse(S.GrpZoom.Visible);
    T := TFmrRibbonStructure.FindTab(S.Ribbon, 'Mine');
    Assert.IsNotNull(T);
    Assert.AreEqual(1, T.Groups[0].ItemLinks.Count);
    Assert.AreSame(TFmrBarItem(S.Cut), T.Groups[0].ItemLinks[0].Item);
    Assert.IsTrue(T.Groups[0].ItemLinks[0].ViewLevels = [TFmrViewLevel.Small]);
    Assert.AreEqual(5, TFmrRibbonStructure.TabCount(S.Ribbon));
  finally
    S.Free;
  end;
end;

procedure TPersistenceTests.NewTabsKeepTheirPosition;
var
  S1, S2: TTestStructure;
  NewTab: TFmrRibbonTab;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  try
    Customize(S1);
    // a newer version of the application has one more tab
    NewTab := TFmrRibbonStructure.CreateTab(S2.Ribbon, 'New', 1);
    NewTab.Name := 'tabNew';
    TFmrRibbonLayoutStorage.LoadFromString(S2.Ribbon, TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon));
    Assert.AreEqual(1, NewTab.TabIndex);
    Assert.AreEqual(0, S2.TabInsert.TabIndex);
    Assert.AreEqual(2, TFmrRibbonStructure.FindTab(S2.Ribbon, 'tabCustom1').TabIndex);
    Assert.AreEqual(3, S2.TabHome.TabIndex);
  finally
    S2.Free;
    S1.Free;
  end;
end;

procedure TPersistenceTests.DesignedLinksAreNotOverwritten;
var
  S1, S2: TTestStructure;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  try
    // the new version added a command to a designed group
    S2.GrpClipboard.ItemLinks.AddItem(S2.Redo);
    TFmrRibbonLayoutStorage.LoadFromString(S2.Ribbon, TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon));
    Assert.AreEqual(4, S2.GrpClipboard.ItemLinks.Count);
  finally
    S2.Free;
    S1.Free;
  end;
end;

procedure TPersistenceTests.StreamAndFile;
var
  S1, S2: TTestStructure;
  Stream: TMemoryStream;
  FileName: string;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  Stream := TMemoryStream.Create;
  try
    Customize(S1);
    TFmrRibbonLayoutStorage.SaveToStream(S1.Ribbon, Stream);
    Stream.Position := 0;
    TFmrRibbonLayoutStorage.LoadFromStream(S2.Ribbon, Stream);
    Assert.AreEqual(DumpStructure(S1.Ribbon), DumpStructure(S2.Ribbon));
    FileName := TPath.Combine(TPath.GetTempPath, 'FmrLayoutTest.json');
    TFmrRibbonLayoutStorage.SaveToFile(S1.Ribbon, FileName);
    try
      TFmrRibbonLayoutStorage.LoadFromFile(S2.Ribbon, FileName);
      Assert.AreEqual(TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon),
        TFmrRibbonLayoutStorage.SaveToString(S2.Ribbon));
    finally
      TFile.Delete(FileName);
    end;
  finally
    Stream.Free;
    S2.Free;
    S1.Free;
  end;
end;

procedure TPersistenceTests.InvalidInputRaises;
var
  S: TTestStructure;
begin
  S := TTestStructure.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        TFmrRibbonLayoutStorage.LoadFromString(S.Ribbon, 'not json');
      end, EFmrLayoutError);
    Assert.WillRaise(
      procedure
      begin
        TFmrRibbonLayoutStorage.LoadFromString(S.Ribbon, '{"format":"Other"}');
      end, EFmrLayoutError);
    Assert.WillRaise(
      procedure
      begin
        TFmrRibbonLayoutStorage.LoadFromString(S.Ribbon, '{"format":"FMR.RibbonLayout","version":99}');
      end, EFmrLayoutError);
  finally
    S.Free;
  end;
end;

procedure TPersistenceTests.LoadIsOneStructureBatch;
var
  S1, S2: TTestStructure;
begin
  S1 := TTestStructure.Create;
  S2 := TTestStructure.Create;
  try
    Customize(S1);
    S2.Ribbon.ResetCounters;
    TFmrRibbonLayoutStorage.LoadFromString(S2.Ribbon, TFmrRibbonLayoutStorage.SaveToString(S1.Ribbon));
    Assert.AreEqual(1, S2.Ribbon.UpdateBatches);
  finally
    S2.Free;
    S1.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPersistenceTests);

end.
