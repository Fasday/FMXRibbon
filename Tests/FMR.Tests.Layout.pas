unit FMR.Tests.Layout;

/// Expected numbers use TFmrLayoutMetrics.Default: content 66, rows 3 x 22, group padding 4, group spacing 0,
/// column spacing 2, separator 9, segment spacing 4, dialog launcher 16, minimum group width 24.

interface

uses
  System.SysUtils, System.Types, System.Math, DUnitX.TestFramework, FMR.Ribbon.Types, FMR.Ribbon.Layout;

type
  [TestFixture]
  TLayoutTests = class
  private
    M: TFmrLayoutMetrics;
    function Large3(const ACaption: Single = 30): TFmrLayoutGroup;
    function Calc(const AGroups: TArray<TFmrLayoutGroup>; const AWidth: Single): TFmrLayoutResult;
    function MixedTab: TArray<TFmrLayoutGroup>;
  public
    [Setup] procedure Setup;
    [Test] procedure LargeButtonsFit;
    [Test] procedure SmallLinksStackInColumnsOfThree;
    [Test] procedure ButtonGroupsShareARow;
    [Test] procedure BeginGroupDrawsSeparator;
    [Test] procedure SeparatorLink;
    [Test] procedure CaptionWiderThanContentCentersContent;
    [Test] procedure DialogLauncherWidensCaption;
    [Test] procedure HiddenLinksAndGroupsAreIgnored;
    [Test] procedure GroupsArePlacedSideBySide;
    [Test] procedure ReductionStartsAtTheRight;
    [Test] procedure LargeRunsReduceByThree;
    [Test] procedure AllGroupsReachSmallWithTextBeforeSmall;
    [Test] procedure CollapseComesLast;
    [Test] procedure CanCollapseIsHonored;
    [Test] procedure PriorityDelaysReduction;
    [Test] procedure GalleryLosesColumnsFirst;
    [Test] procedure ControlsDropTheirCaption;
    [Test] procedure CollapsedGroupKeepsExpandedLayoutForPopup;
    [Test] procedure StepWidthsStrictlyDecrease;
    [Test] procedure WidthIsMonotonic;
    [Test] procedure ExpansionIsTheReverse;
    [Test] procedure Deterministic;
    [Test] procedure NotFittingLayoutReportsIt;
    [Test] procedure ExpandedGroupHelper;
    [Test] procedure SimplifiedFitsWithoutOverflow;
    [Test] procedure SimplifiedOverflowOrder;
    [Test] procedure SimplifiedNeverAndOverflowKinds;
    [Test] procedure ScrollInfoAndSteps;
    [Test] procedure TabsShrinkProportionally;
    [Test] procedure ViewLevelHelpers;
    [Test] procedure RightToLeftMirroring;
  end;

implementation

const
  Eps = 0.01;

{ TLayoutTests }

procedure TLayoutTests.Setup;
begin
  M := TFmrLayoutMetrics.Default;
end;

function TLayoutTests.Calc(const AGroups: TArray<TFmrLayoutGroup>; const AWidth: Single): TFmrLayoutResult;
begin
  Result := TFmrRibbonLayoutCalculator.Layout(AGroups, M, AWidth);
end;

function TLayoutTests.Large3(const ACaption: Single): TFmrLayoutGroup;
begin
  Result := TFmrLayoutGroup.Create(ACaption, 50, [TFmrLayoutLink.Button(40, 70, 24), TFmrLayoutLink.Button(40, 70, 24),
    TFmrLayoutLink.Button(40, 70, 24)]);
end;

function TLayoutTests.MixedTab: TArray<TFmrLayoutGroup>;
var
  G: TFmrLayoutGroup;
begin
  Result := nil;
  // Clipboard: large paste + three small
  G := TFmrLayoutGroup.Create(50, 52, [TFmrLayoutLink.Button(44, 70, 24, [TFmrViewLevel.Large]),
    TFmrLayoutLink.Button(42, 60, 24), TFmrLayoutLink.Button(42, 62, 24), TFmrLayoutLink.Button(50, 96, 24)]);
  Result := Result + [G];
  // Font: editors and a button group
  G := TFmrLayoutGroup.Create(30, 48, [TFmrLayoutLink.Control(150, 110), TFmrLayoutLink.Control(70, 50),
    TFmrLayoutLink.Button(0, 22, 22, FmrSmallViewLevels).WithButtonGroup(TFmrButtonGroupPosition.Start),
    TFmrLayoutLink.Button(0, 22, 22, FmrSmallViewLevels).WithButtonGroup(TFmrButtonGroupPosition.Member),
    TFmrLayoutLink.Button(0, 22, 22, FmrSmallViewLevels).WithButtonGroup(TFmrButtonGroupPosition.Member)]);
  G.HasDialogLauncher := True;
  Result := Result + [G];
  // Paragraph: six large
  G := TFmrLayoutGroup.Create(60, 64, [TFmrLayoutLink.Button(40, 80, 24), TFmrLayoutLink.Button(46, 84, 24),
    TFmrLayoutLink.Button(38, 70, 24), TFmrLayoutLink.Button(40, 90, 24).WithBeginGroup,
    TFmrLayoutLink.Button(52, 100, 24), TFmrLayoutLink.Button(40, 72, 24)]);
  Result := Result + [G];
  // Styles: gallery + one button
  G := TFmrLayoutGroup.Create(40, 56, [TFmrLayoutLink.Gallery(56, 2, 7, 18, 56), TFmrLayoutLink.Button(44, 80, 24)]);
  Result := Result + [G];
  // Editing: three small with text
  G := TFmrLayoutGroup.Create(44, 54, [TFmrLayoutLink.Button(40, 60, 24), TFmrLayoutLink.Button(50, 76, 24),
    TFmrLayoutLink.Button(46, 70, 24)]);
  G.Priority := 1;
  Result := Result + [G];
end;

procedure TLayoutTests.LargeButtonsFit;
var
  R: TFmrLayoutResult;
  G: TFmrLayoutGroupResult;
begin
  R := Calc([Large3], 1000);
  Assert.IsTrue(R.Fits);
  Assert.AreEqual(0, R.Step);
  G := R.Groups[0];
  Assert.AreEqual(Single(132), G.Width, Eps, '3 x 40 + 2 x 2 spacing + 2 x 4 padding');
  Assert.AreEqual(Single(124), G.ContentWidth, Eps);
  Assert.AreEqual(Single(132), R.TotalWidth, Eps);
  Assert.AreEqual(TFmrViewLevel.Large, G.Links[0].Level);
  Assert.AreEqual(Single(4), G.Links[0].Bounds.Left, Eps);
  Assert.AreEqual(Single(46), G.Links[1].Bounds.Left, Eps);
  Assert.AreEqual(Single(88), G.Links[2].Bounds.Left, Eps);
  Assert.AreEqual(Single(66), G.Links[2].Bounds.Height, Eps, 'large links take the full height');
  Assert.AreEqual(-1, G.Links[0].Row);
  Assert.AreEqual(2, G.Links[2].Column);
end;

procedure TLayoutTests.SmallLinksStackInColumnsOfThree;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutGroupResult;
  W: TArray<Single>;
  I: Integer;
begin
  W := [60, 70, 50, 80, 40];
  G := TFmrLayoutGroup.Create(10, 40, []);
  for I := 0 to High(W) do
    G.Links := G.Links + [TFmrLayoutLink.Button(0, W[I], 0, [TFmrViewLevel.SmallWithText])];
  R := Calc([G], 1000).Groups[0];
  Assert.AreEqual(Single(160), R.Width, Eps, 'columns 70 and 80, spacing 2, padding 8');
  Assert.AreEqual(Single(0), R.Links[0].Bounds.Top, Eps);
  Assert.AreEqual(Single(22), R.Links[1].Bounds.Top, Eps);
  Assert.AreEqual(Single(44), R.Links[2].Bounds.Top, Eps);
  Assert.AreEqual(Single(4), R.Links[2].Bounds.Left, Eps);
  Assert.AreEqual(Single(76), R.Links[3].Bounds.Left, Eps);
  Assert.AreEqual(Single(22 / 3), R.Links[3].Bounds.Top, Eps, 'two rows are spread over the height');
  Assert.AreEqual(Single(22 / 3 * 2 + 22), R.Links[4].Bounds.Top, Eps);
  Assert.AreEqual(1, R.Links[4].Column);
  Assert.AreEqual(1, R.Links[4].Row);
  M.DistributeRows := False;
  R := Calc([G], 1000).Groups[0];
  Assert.AreEqual(Single(0), R.Links[3].Bounds.Top, Eps, 'top-aligned without DistributeRows');
end;

procedure TLayoutTests.ButtonGroupsShareARow;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutGroupResult;
begin
  G := TFmrLayoutGroup.Create(10, 40, [
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Start),
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Member),
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Member),
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Member)
      .WithBeginGroup,
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Member),
    TFmrLayoutLink.Button(0, 50, 22, [TFmrViewLevel.SmallWithText])]);
  R := Calc([G], 1000).Groups[0];
  Assert.AreEqual(Single(122), R.Width, Eps, 'row of 5 x 22 + segment gap 4, padding 8');
  Assert.AreEqual(0, R.Links[4].Row, 'members continue the row');
  Assert.AreEqual(Single(4 + 22 * 3 + 4), R.Links[3].Bounds.Left, Eps, 'BeginGroup on a member: segment gap');
  Assert.AreEqual(1, R.Links[5].Row, 'a link without ButtonGroup starts a new row');
  Assert.AreEqual(TFmrLayoutSegment.First, R.Links[0].Segment);
  Assert.AreEqual(TFmrLayoutSegment.Middle, R.Links[1].Segment);
  Assert.AreEqual(TFmrLayoutSegment.Last, R.Links[2].Segment);
  Assert.AreEqual(TFmrLayoutSegment.First, R.Links[3].Segment);
  Assert.AreEqual(TFmrLayoutSegment.Last, R.Links[4].Segment);
  Assert.AreEqual(TFmrLayoutSegment.None, R.Links[5].Segment);
end;

procedure TLayoutTests.BeginGroupDrawsSeparator;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutGroupResult;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Button(40, 70, 24),
    TFmrLayoutLink.Button(40, 70, 24).WithBeginGroup]);
  R := Calc([G], 1000).Groups[0];
  Assert.AreEqual(Single(97), R.Width, Eps, '40 + separator 9 + 40 + padding 8');
  Assert.AreEqual(1, Integer(Length(R.Separators)));
  Assert.AreEqual(Single(4 + 40 + 4.5), R.Separators[0], Eps);
  Assert.AreEqual(Single(53), R.Links[1].Bounds.Left, Eps);
end;

procedure TLayoutTests.SeparatorLink;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutGroupResult;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Separator, TFmrLayoutLink.Button(40, 70, 24),
    TFmrLayoutLink.Separator, TFmrLayoutLink.Button(40, 70, 24), TFmrLayoutLink.Separator]);
  R := Calc([G], 1000).Groups[0];
  Assert.AreEqual(1, Integer(Length(R.Separators)), 'leading and trailing separators are not drawn');
  Assert.AreEqual(Single(97), R.Width, Eps);
  Assert.IsFalse(R.Links[0].Visible);
end;

procedure TLayoutTests.CaptionWiderThanContentCentersContent;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutGroupResult;
begin
  G := TFmrLayoutGroup.Create(100, 40, [TFmrLayoutLink.Button(40, 70, 24, [TFmrViewLevel.Large])]);
  R := Calc([G], 1000).Groups[0];
  Assert.AreEqual(Single(108), R.Width, Eps);
  Assert.AreEqual(Single(34), R.Links[0].Bounds.Left, Eps, 'content centered: 4 + (100 - 40) / 2');
end;

procedure TLayoutTests.DialogLauncherWidensCaption;
var
  G: TFmrLayoutGroup;
begin
  G := TFmrLayoutGroup.Create(100, 40, [TFmrLayoutLink.Button(40, 70, 24, [TFmrViewLevel.Large])]);
  G.HasDialogLauncher := True;
  Assert.AreEqual(Single(124), Calc([G], 1000).Groups[0].Width, Eps);
end;

procedure TLayoutTests.HiddenLinksAndGroupsAreIgnored;
var
  G, H: TFmrLayoutGroup;
  R: TFmrLayoutResult;
begin
  G := Large3;
  G.Links[1].Hidden := True;
  H := Large3;
  H.Hidden := True;
  R := Calc([H, G], 1000);
  Assert.IsFalse(R.Groups[0].Visible);
  Assert.IsFalse(R.Groups[1].Links[1].Visible);
  Assert.AreEqual(Single(90), R.Groups[1].Width, Eps, '2 x 40 + 2 + 8');
  Assert.AreEqual(Single(90), R.TotalWidth, Eps);
  Assert.AreEqual(Single(0), R.Groups[1].Left, Eps);
end;

procedure TLayoutTests.GroupsArePlacedSideBySide;
var
  R: TFmrLayoutResult;
begin
  M.GroupSpacing := 6;
  R := Calc([Large3, Large3, Large3], 1000);
  Assert.AreEqual(Single(0), R.Groups[0].Left, Eps);
  Assert.AreEqual(Single(138), R.Groups[1].Left, Eps);
  Assert.AreEqual(Single(276), R.Groups[2].Left, Eps);
  Assert.AreEqual(Single(132 * 3 + 12), R.TotalWidth, Eps);
end;

procedure TLayoutTests.ReductionStartsAtTheRight;
var
  R: TFmrLayoutResult;
begin
  // expanded 3 x 132 = 396; a group with its three links as one column of small-with-text is 70 + 8 = 78
  R := Calc([Large3, Large3, Large3], 390);
  Assert.IsTrue(R.Fits);
  Assert.AreEqual(1, R.Step);
  Assert.AreEqual(0, R.Groups[0].Steps);
  Assert.AreEqual(0, R.Groups[1].Steps);
  Assert.AreEqual(1, R.Groups[2].Steps);
  Assert.AreEqual(TFmrViewLevel.SmallWithText, R.Groups[2].Links[0].Level);
  Assert.AreEqual(Single(78), R.Groups[2].Width, Eps);
  Assert.AreEqual(Single(342), R.TotalWidth, Eps);
  R := Calc([Large3, Large3, Large3], 300);
  Assert.AreEqual(1, R.Groups[1].Steps, 'then the next group to the left');
  Assert.AreEqual(0, R.Groups[0].Steps);
end;

procedure TLayoutTests.LargeRunsReduceByThree;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutResult;
  I: Integer;
begin
  G := TFmrLayoutGroup.Create(10, 40, []);
  for I := 1 to 5 do
    G.Links := G.Links + [TFmrLayoutLink.Button(40, 70, 24)];
  // expanded 5 x 40 + 4 x 2 + 8 = 216
  R := Calc([G], 215);
  Assert.AreEqual(TFmrViewLevel.Large, R.Groups[0].Links[0].Level);
  Assert.AreEqual(TFmrViewLevel.Large, R.Groups[0].Links[1].Level);
  for I := 2 to 4 do
    Assert.AreEqual(TFmrViewLevel.SmallWithText, R.Groups[0].Links[I].Level, 'the rightmost three first');
  Assert.AreEqual(Single(40 + 2 + 40 + 2 + 70 + 8), R.Groups[0].Width, Eps);
end;

procedure TLayoutTests.AllGroupsReachSmallWithTextBeforeSmall;
var
  Groups: TArray<TFmrLayoutGroup>;
  Calc: TFmrRibbonLayoutCalculator;
  Widths: TArray<Single>;
  R: TFmrLayoutResult;
  K, G, L: Integer;
  AnySmall, AnyLarge, AnyCollapsed, AllSmallest: Boolean;
begin
  Groups := [Large3, Large3, Large3, Large3];
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare(Groups);
    Widths := Calc.StepWidths;
    for K := 0 to High(Widths) do
    begin
      R := Calc.Calculate(Widths[K]);
      Assert.AreEqual(K, R.Step);
      AnySmall := False;
      AnyLarge := False;
      AnyCollapsed := False;
      AllSmallest := True;
      for G := 0 to High(R.Groups) do
      begin
        if R.Groups[G].Collapsed then
        begin
          AnyCollapsed := True;
          Continue;
        end;
        for L := 0 to High(R.Groups[G].Links) do
        begin
          AnySmall := AnySmall or (R.Groups[G].Links[L].Level = TFmrViewLevel.Small);
          AnyLarge := AnyLarge or (R.Groups[G].Links[L].Level = TFmrViewLevel.Large);
          AllSmallest := AllSmallest and (R.Groups[G].Links[L].Level = TFmrViewLevel.Small);
        end;
      end;
      Assert.IsFalse(AnySmall and AnyLarge, Format('step %d: Small while a group is still Large', [K]));
      Assert.IsFalse(AnyCollapsed and not AllSmallest, Format('step %d: collapse before full reduction', [K]));
    end;
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.CollapseComesLast;
var
  R: TFmrLayoutResult;
begin
  // fully reduced group: one column of three small links (24) but the caption needs 30 + 8 = 38; the collapsed
  // button (50) is not narrower, so it does not collapse
  R := Calc([Large3, Large3], 10);
  Assert.IsFalse(R.Fits);
  Assert.IsFalse(R.Groups[0].Collapsed, 'collapsing is skipped when it would not save space');
  Assert.AreEqual(Single(76), R.TotalWidth, Eps);
  // caption 100: steps 264, 240, 216 (small with text), 158, 100 (collapse right to left)
  R := Calc([Large3(100), Large3(100)], 200);
  Assert.IsTrue(R.Groups[1].Collapsed);
  Assert.IsFalse(R.Groups[0].Collapsed);
  Assert.AreEqual(Single(50), R.Groups[1].Width, Eps);
  Assert.AreEqual(Single(158), R.TotalWidth, Eps);
  Assert.IsTrue(R.Fits);
  R := Calc([Large3(100), Large3(100)], 100);
  Assert.IsTrue(R.Groups[0].Collapsed and R.Groups[1].Collapsed);
  Assert.IsTrue(R.Fits);
end;

procedure TLayoutTests.CanCollapseIsHonored;
var
  A, B: TFmrLayoutGroup;
  R: TFmrLayoutResult;
begin
  A := Large3(100);
  B := Large3(100);
  B.CanCollapse := False;
  R := Calc([A, B], 10);
  Assert.IsTrue(R.Groups[0].Collapsed);
  Assert.IsFalse(R.Groups[1].Collapsed);
end;

procedure TLayoutTests.PriorityDelaysReduction;
var
  A, B: TFmrLayoutGroup;
  R: TFmrLayoutResult;
begin
  A := Large3;
  B := Large3;
  B.Priority := 10;
  R := Calc([A, B], 260);
  Assert.AreEqual(1, R.Groups[0].Steps, 'the low-priority group on the left is reduced first');
  Assert.AreEqual(0, R.Groups[1].Steps);
end;

procedure TLayoutTests.GalleryLosesColumnsFirst;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutResult;
begin
  G := TFmrLayoutGroup.Create(30, 50, [TFmrLayoutLink.Gallery(50, 2, 6, 20, 60), TFmrLayoutLink.Button(40, 70, 24),
    TFmrLayoutLink.Button(40, 70, 24), TFmrLayoutLink.Button(40, 70, 24)]);
  // expanded: 6 x 50 + 20 = 320, + 2 + 3 x 40 + 2 x 2 = 446 content, 454 group
  R := Calc([G], 1000);
  Assert.AreEqual(6, R.Groups[0].Links[0].GalleryColumns);
  Assert.AreEqual(Single(454), R.TotalWidth, Eps);
  Assert.AreEqual(Single(4), R.Groups[0].Links[0].Bounds.Left, Eps);
  Assert.AreEqual(Single(320), R.Groups[0].Links[0].Bounds.Width, Eps);
  R := Calc([G], 404);
  Assert.AreEqual(5, R.Groups[0].Links[0].GalleryColumns);
  Assert.AreEqual(TFmrViewLevel.Large, R.Groups[0].Links[1].Level, 'buttons wait for the gallery');
  R := Calc([G], 300);
  Assert.AreEqual(2, R.Groups[0].Links[0].GalleryColumns, 'down to MinColumns');
  Assert.AreEqual(TFmrViewLevel.Large, R.Groups[0].Links[3].Level);
  Assert.AreEqual(Single(254), R.TotalWidth, Eps);
  R := Calc([G], 200);
  Assert.AreEqual(2, R.Groups[0].Links[0].GalleryColumns);
  Assert.AreEqual(TFmrViewLevel.SmallWithText, R.Groups[0].Links[3].Level);
  Assert.AreEqual(Single(200), R.TotalWidth, Eps);
  R := Calc([G], 150);
  Assert.AreEqual(0, R.Groups[0].Links[0].GalleryColumns, 'the gallery becomes a drop-down button');
  Assert.AreEqual(TFmrViewLevel.Small, R.Groups[0].Links[3].Level);
  Assert.AreEqual(Single(60 + 2 + 24 + 8), R.TotalWidth, Eps);
  Assert.IsFalse(R.Groups[0].Collapsed);
  R := Calc([G], 80);
  Assert.IsTrue(R.Groups[0].Collapsed);
  Assert.AreEqual(Single(50), R.TotalWidth, Eps);
end;

procedure TLayoutTests.ControlsDropTheirCaption;
var
  G: TFmrLayoutGroup;
  R: TFmrLayoutResult;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Control(120, 80), TFmrLayoutLink.Control(100, 70)]);
  R := Calc([G], 1000);
  Assert.AreEqual(TFmrViewLevel.SmallWithText, R.Groups[0].Links[0].Level);
  Assert.AreEqual(Single(128), R.TotalWidth, Eps);
  R := Calc([G], 100);
  Assert.AreEqual(TFmrViewLevel.Small, R.Groups[0].Links[0].Level);
  Assert.AreEqual(Single(88), R.TotalWidth, Eps);
end;

procedure TLayoutTests.CollapsedGroupKeepsExpandedLayoutForPopup;
var
  R: TFmrLayoutResult;
begin
  R := Calc([Large3(100)], 60);
  Assert.IsTrue(R.Groups[0].Collapsed);
  Assert.AreEqual(Single(50), R.Groups[0].Width, Eps);
  Assert.AreEqual(Single(132), R.Groups[0].ExpandedWidth, Eps);
  Assert.AreEqual(TFmrViewLevel.Large, R.Groups[0].Links[0].Level, 'the popup shows the expanded group');
  Assert.IsTrue(R.Groups[0].Links[2].Visible);
end;

procedure TLayoutTests.StepWidthsStrictlyDecrease;
var
  Calc: TFmrRibbonLayoutCalculator;
  W: TArray<Single>;
  I: Integer;
begin
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare(MixedTab);
    W := Calc.StepWidths;
    Assert.IsTrue(Length(W) > 10, 'a real tab has many steps');
    for I := 1 to High(W) do
      Assert.IsTrue(W[I] < W[I - 1], Format('step %d: %.2f !< %.2f', [I, W[I], W[I - 1]]));
    Assert.AreEqual(W[0], Calc.ExpandedWidth, Eps);
    Assert.AreEqual(W[High(W)], Calc.MinimumWidth, Eps);
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.WidthIsMonotonic;
var
  Calc: TFmrRibbonLayoutCalculator;
  R: TFmrLayoutResult;
  W, Prev: Single;
begin
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare(MixedTab);
    Prev := -1;
    W := 0;
    while W < Calc.ExpandedWidth + 60 do
    begin
      R := Calc.Calculate(W);
      Assert.AreEqual(Calc.StepWidths[R.Step], R.TotalWidth, Eps, 'arranged width = width of the step');
      Assert.IsTrue(R.TotalWidth >= Prev - Eps, Format('width %.0f: %.2f < %.2f', [W, R.TotalWidth, Prev]));
      if R.Fits then
        Assert.IsTrue(R.TotalWidth <= W + Eps, Format('width %.0f: layout %.2f is wider', [W, R.TotalWidth]))
      else
        Assert.AreEqual(Calc.MinimumWidth, R.TotalWidth, Eps);
      Prev := R.TotalWidth;
      W := W + 3;
    end;
    Assert.AreEqual(0, Calc.Calculate(10000).Step);
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.ExpansionIsTheReverse;
var
  Calc: TFmrRibbonLayoutCalculator;
  A, B: TFmrLayoutResult;
  G, L: Integer;
begin
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare(MixedTab);
    A := Calc.Calculate(420);
    Calc.Calculate(200);
    Calc.Calculate(900);
    B := Calc.Calculate(420);
    Assert.AreEqual(A.Step, B.Step);
    for G := 0 to High(A.Groups) do
    begin
      Assert.AreEqual(A.Groups[G].Collapsed, B.Groups[G].Collapsed);
      for L := 0 to High(A.Groups[G].Links) do
        Assert.AreEqual(A.Groups[G].Links[L].Level, B.Groups[G].Links[L].Level);
    end;
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.Deterministic;
var
  A, B: TFmrLayoutResult;
  G, L: Integer;
begin
  A := Calc(MixedTab, 500);
  B := Calc(MixedTab, 500);
  Assert.AreEqual(A.TotalWidth, B.TotalWidth, Eps);
  for G := 0 to High(A.Groups) do
    for L := 0 to High(A.Groups[G].Links) do
    begin
      Assert.AreEqual(A.Groups[G].Links[L].Level, B.Groups[G].Links[L].Level);
      Assert.AreEqual(A.Groups[G].Links[L].Bounds.Left, B.Groups[G].Links[L].Bounds.Left, Eps);
    end;
end;

procedure TLayoutTests.NotFittingLayoutReportsIt;
var
  R: TFmrLayoutResult;
  G: TFmrLayoutGroup;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Button(92, 92, 92, [TFmrViewLevel.Large])]);
  G.CanCollapse := False;
  R := Calc([G, G, G], 250);
  Assert.IsFalse(R.Fits);
  Assert.AreEqual(Single(300), R.TotalWidth, Eps);
  Assert.AreEqual(R.StepCount - 1, R.Step);
end;

procedure TLayoutTests.ExpandedGroupHelper;
var
  Calc: TFmrRibbonLayoutCalculator;
  R: TFmrLayoutGroupResult;
begin
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare([Large3, Large3]);
    Calc.Calculate(100);
    R := Calc.CalculateExpandedGroup(Large3);
    Assert.AreEqual(Single(132), R.Width, Eps);
    Assert.AreEqual(Single(132), Calc.Calculate(1000).Groups[0].Width, Eps, 'the prepared input is kept');
  finally
    Calc.Free;
  end;
end;

function SimplifiedGroups: TArray<TFmrLayoutGroup>;
var
  G0, G1: TFmrLayoutGroup;
  L: TFmrLayoutLink;
begin
  L := TFmrLayoutLink.Button(40, 60, 30);
  G0 := TFmrLayoutGroup.Create(10, 40, [L, L, L]);
  G0.Links[1].SimplifiedVisibility := TFmrSimplifiedVisibility.Always;
  G0.Links[2].SimplifiedVisibility := TFmrSimplifiedVisibility.Overflow;
  L.SimplifiedWidth := 40;
  G1 := TFmrLayoutGroup.Create(10, 40, [L, L, L]);
  G1.Links[1].SimplifiedVisibility := TFmrSimplifiedVisibility.Never;
  Result := [G0, G1];
end;

procedure TLayoutTests.SimplifiedFitsWithoutOverflow;
var
  Calc: TFmrRibbonLayoutCalculator;
  R: TFmrSimplifiedLayoutResult;
  G: TFmrLayoutGroup;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Button(40, 60, 30), TFmrLayoutLink.Button(40, 60, 30)]);
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare([G, G]);
    R := Calc.CalculateSimplified(1000);
    Assert.IsFalse(R.OverflowButtonVisible);
    Assert.AreEqual(Single(30 + 2 + 30 + 9 + 30 + 2 + 30), R.TotalWidth, Eps);
    Assert.AreEqual(1, Integer(Length(R.Separators)));
    Assert.AreEqual(Single(71), R.Groups[1].Left, Eps);
    Assert.AreEqual(Single(32), R.Groups[0].Links[1].Bounds.Left, Eps);
    Assert.AreEqual(M.SimplifiedHeight, R.Groups[0].Links[1].Bounds.Height, Eps);
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.SimplifiedOverflowOrder;
var
  Calc: TFmrRibbonLayoutCalculator;
  R: TFmrSimplifiedLayoutResult;
begin
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare(SimplifiedGroups);
    // line: 30 + 2 + 30 + 9 + 40 + 2 + 40 = 153; limit = width - 32 - 2
    R := Calc.CalculateSimplified(150);
    Assert.IsTrue(R.OverflowButtonVisible);
    Assert.AreEqual(2, Integer(Length(R.Overflow)));
    Assert.AreEqual(0, R.Overflow[0].Group, 'ribbon order');
    Assert.AreEqual(2, R.Overflow[0].Link);
    Assert.AreEqual(1, R.Overflow[1].Group);
    Assert.AreEqual(2, R.Overflow[1].Link, 'the rightmost Auto link goes first');
    Assert.IsTrue(R.Groups[1].Links[0].Visible);
    Assert.AreEqual(Single(111 + 2), R.OverflowButtonBounds.Left, Eps);
    Assert.IsTrue(R.TotalWidth <= 150);
    R := Calc.CalculateSimplified(60);
    Assert.IsTrue(R.Groups[0].Links[1].Visible = False);
    Assert.AreEqual(5, Integer(Length(R.Overflow)));
    R := Calc.CalculateSimplified(70);
    Assert.IsTrue(R.Groups[0].Links[1].Visible, 'Always links stay longest');
    Assert.IsFalse(R.Groups[0].Links[0].Visible);
    Assert.IsFalse(R.Groups[1].Visible);
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.SimplifiedNeverAndOverflowKinds;
var
  Calc: TFmrRibbonLayoutCalculator;
  R: TFmrSimplifiedLayoutResult;
begin
  Calc := TFmrRibbonLayoutCalculator.Create(M);
  try
    Calc.Prepare(SimplifiedGroups);
    R := Calc.CalculateSimplified(1000);
    Assert.IsTrue(R.OverflowButtonVisible, 'an Overflow link always needs the button');
    Assert.AreEqual(1, Integer(Length(R.Overflow)));
    Assert.IsTrue(R.Groups[0].Links[2].InOverflow);
    Assert.IsFalse(R.Groups[1].Links[1].Visible or R.Groups[1].Links[1].InOverflow, 'Never links are nowhere');
    Assert.AreEqual(Single(153 + 2 + 32), R.TotalWidth, Eps);
  finally
    Calc.Free;
  end;
end;

procedure TLayoutTests.ScrollInfoAndSteps;
var
  R: TFmrLayoutResult;
  G: TFmrLayoutGroup;
  Info: TFmrGroupScrollInfo;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Button(92, 92, 92, [TFmrViewLevel.Large])]);
  G.CanCollapse := False;
  R := Calc([G, G, G], 250);
  Info := FmrGroupScrollInfo(R, 250, 0);
  Assert.AreEqual(Single(50), Info.MaxOffset, Eps);
  Assert.IsFalse(Info.CanScrollLeft);
  Assert.IsTrue(Info.CanScrollRight);
  Assert.AreEqual(0, Info.FirstVisible);
  Assert.AreEqual(1, Info.LastVisible);
  Assert.AreEqual(Single(50), FmrGroupScrollStep(R, 250, 0, True), Eps);
  Info := FmrGroupScrollInfo(R, 250, 80);
  Assert.AreEqual(Single(50), Info.Offset, Eps, 'clamped');
  Assert.AreEqual(1, Info.FirstVisible);
  Assert.AreEqual(2, Info.LastVisible);
  Assert.AreEqual(Single(0), FmrGroupScrollStep(R, 250, 50, False), Eps);
end;

procedure TLayoutTests.TabsShrinkProportionally;
var
  W: TArray<Single>;
  Fits: Boolean;
begin
  W := FmrLayoutTabs([60, 80, 100], [30, 40, 50], 300, Fits);
  Assert.IsTrue(Fits);
  Assert.AreEqual(Single(80), W[1], Eps);
  W := FmrLayoutTabs([60, 80, 100], [30, 40, 50], 180, Fits);
  Assert.IsTrue(Fits);
  Assert.AreEqual(Single(45), W[0], Eps);
  Assert.AreEqual(Single(60), W[1], Eps);
  Assert.AreEqual(Single(75), W[2], Eps);
  W := FmrLayoutTabs([60, 80, 100], [30, 40, 50], 100, Fits);
  Assert.IsFalse(Fits);
  Assert.AreEqual(Single(50), W[2], Eps);
end;

procedure TLayoutTests.ViewLevelHelpers;
var
  L: TFmrViewLevel;
begin
  Assert.AreEqual(TFmrViewLevel.Large, FmrLargestViewLevel(FmrAllViewLevels));
  Assert.AreEqual(TFmrViewLevel.Small, FmrLargestViewLevel([TFmrViewLevel.Small]));
  Assert.IsTrue(FmrNextSmallerViewLevel([TFmrViewLevel.Large, TFmrViewLevel.Small], TFmrViewLevel.Large, L));
  Assert.AreEqual(TFmrViewLevel.Small, L);
  Assert.IsFalse(FmrNextSmallerViewLevel(FmrAllViewLevels, TFmrViewLevel.Small, L));
  Assert.AreEqual('Large,Small', FmrViewLevelsToString([TFmrViewLevel.Large, TFmrViewLevel.Small]));
  Assert.IsTrue(FmrStringToViewLevels('Large, SmallWithText,bogus') = [TFmrViewLevel.Large,
    TFmrViewLevel.SmallWithText]);
end;

procedure TLayoutTests.RightToLeftMirroring;
var
  R: TFmrLayoutResult;
  G: TFmrLayoutGroup;
begin
  G := TFmrLayoutGroup.Create(10, 40, [TFmrLayoutLink.Button(40, 70, 24),
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Start)
      .WithBeginGroup,
    TFmrLayoutLink.Button(0, 22, 22, [TFmrViewLevel.Small]).WithButtonGroup(TFmrButtonGroupPosition.Member)]);
  // group 0: 40 + separator 9 + 44 + padding 8 = 101; group 1: 132
  R := Calc([G, Large3], 1000);
  FmrMirrorLayout(R);
  Assert.AreEqual(Single(132), R.Groups[0].Left, Eps, 'the first group is at the right');
  Assert.AreEqual(Single(0), R.Groups[1].Left, Eps);
  Assert.AreEqual(Single(101 - 4 - 40), R.Groups[0].Links[0].Bounds.Left, Eps);
  Assert.AreEqual(Single(101 - 4 - 40 - 4.5), R.Groups[0].Separators[0], Eps);
  Assert.AreEqual(TFmrLayoutSegment.Last, R.Groups[0].Links[1].Segment, 'segments swap ends');
  Assert.IsTrue(R.Groups[0].Links[1].Bounds.Left > R.Groups[0].Links[2].Bounds.Left);
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutTests);

end.
