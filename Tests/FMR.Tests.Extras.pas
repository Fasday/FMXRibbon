unit FMR.Tests.Extras;

/// Pure layout logic of the companion controls (FMR.Ribbon.Extras.Layout): status bar panel placement, the zoom
/// slider scale, zoom steps, keyboard navigation over selectable entries and scroll clamping.

interface

uses
  System.SysUtils, System.Math, DUnitX.TestFramework, FMR.Ribbon.Extras.Layout;

type
  [TestFixture]
  TExtrasLayoutTests = class
  public
    [Test] procedure PanelsLeftAndRight;
    [Test] procedure StretchTakesFreeSpace;
    [Test] procedure InvisiblePanelsAreSkipped;
    [Test] procedure OverflowShrinksThenHidesLeftPanels;
    [Test] procedure OverflowHidesRightPanelsLast;
    [Test] procedure ZoomScaleHasHundredInTheMiddle;
    [Test] procedure ZoomScaleRoundTrip;
    [Test] procedure ZoomScaleLinearWithoutHundred;
    [Test] procedure ZoomSteps;
    [Test] procedure NavigationSkipsDisabled;
    [Test] procedure NavigationWrapsAndEdges;
    [Test] procedure ScrollHelpers;
  end;

implementation

const
  L = TFmrStatusPanelSide.Left;
  R = TFmrStatusPanelSide.Right;

{ TExtrasLayoutTests }

procedure TExtrasLayoutTests.PanelsLeftAndRight;
var
  S: TArray<TFmrStatusPanelSlot>;
begin
  S := FmrLayoutStatusPanels([TFmrStatusPanelMeasure.Create(L, 50), TFmrStatusPanelMeasure.Create(L, 30),
    TFmrStatusPanelMeasure.Create(R, 40), TFmrStatusPanelMeasure.Create(R, 60)], 0, 500, 2);
  Assert.AreEqual(Single(0), S[0].Left);
  Assert.AreEqual(Single(52), S[1].Left);
  // right panels end at the right edge, in their order
  Assert.AreEqual(Single(500), S[3].Right);
  Assert.AreEqual(Single(500 - 60 - 2 - 40), S[2].Left);
  Assert.IsTrue(S[0].Shown and S[1].Shown and S[2].Shown and S[3].Shown);
end;

procedure TExtrasLayoutTests.StretchTakesFreeSpace;
var
  S: TArray<TFmrStatusPanelSlot>;
begin
  S := FmrLayoutStatusPanels([TFmrStatusPanelMeasure.Create(L, 50), TFmrStatusPanelMeasure.Create(L, 10, 0, True),
    TFmrStatusPanelMeasure.Create(R, 40)], 0, 300, 0);
  Assert.AreEqual(Single(300 - 50 - 40), S[1].Width, 0.01);
  Assert.AreEqual(S[2].Left, S[1].Right, 0.01);
end;

procedure TExtrasLayoutTests.InvisiblePanelsAreSkipped;
var
  S: TArray<TFmrStatusPanelSlot>;
begin
  S := FmrLayoutStatusPanels([TFmrStatusPanelMeasure.Create(L, 50), TFmrStatusPanelMeasure.Create(L, 80, 0, False,
    False), TFmrStatusPanelMeasure.Create(L, 30)], 10, 400, 4);
  Assert.IsFalse(S[1].Shown);
  Assert.AreEqual(Single(10 + 50 + 4), S[2].Left);
end;

procedure TExtrasLayoutTests.OverflowShrinksThenHidesLeftPanels;
var
  S: TArray<TFmrStatusPanelSlot>;
begin
  // 100 + 100 + 100 = 300 in 250: the last left panel shrinks to its minimum (60), then the next one
  S := FmrLayoutStatusPanels([TFmrStatusPanelMeasure.Create(L, 100, 80), TFmrStatusPanelMeasure.Create(L, 100, 60),
    TFmrStatusPanelMeasure.Create(R, 100)], 0, 250, 0);
  Assert.AreEqual(Single(60), S[1].Width, 0.01);
  Assert.AreEqual(Single(90), S[0].Width, 0.01);
  Assert.AreEqual(Single(250), S[2].Right, 0.01);
  // much narrower: left panels are hidden from the last one, the right panel stays
  S := FmrLayoutStatusPanels([TFmrStatusPanelMeasure.Create(L, 100, 80), TFmrStatusPanelMeasure.Create(L, 100, 60),
    TFmrStatusPanelMeasure.Create(R, 100)], 0, 190, 0);
  Assert.IsTrue(S[0].Shown);
  Assert.IsFalse(S[1].Shown);
  Assert.IsTrue(S[2].Shown);
  Assert.IsTrue(S[0].Right <= S[2].Left + 0.01, 'no overlap');
end;

procedure TExtrasLayoutTests.OverflowHidesRightPanelsLast;
var
  S: TArray<TFmrStatusPanelSlot>;
begin
  S := FmrLayoutStatusPanels([TFmrStatusPanelMeasure.Create(L, 100, 100), TFmrStatusPanelMeasure.Create(R, 100, 100),
    TFmrStatusPanelMeasure.Create(R, 100, 100)], 0, 150, 0);
  Assert.IsFalse(S[0].Shown);
  Assert.IsFalse(S[1].Shown, 'the first right panel goes before the rightmost one');
  Assert.IsTrue(S[2].Shown);
  Assert.AreEqual(Single(150), S[2].Right, 0.01);
end;

procedure TExtrasLayoutTests.ZoomScaleHasHundredInTheMiddle;
begin
  Assert.AreEqual(Single(0.5), FmrZoomToFraction(100, 10, 500), 0.0001);
  Assert.AreEqual(Single(0), FmrZoomToFraction(10, 10, 500), 0.0001);
  Assert.AreEqual(Single(1), FmrZoomToFraction(500, 10, 500), 0.0001);
  Assert.AreEqual(Single(0.25), FmrZoomToFraction(55, 10, 500), 0.0001);
  Assert.AreEqual(Single(0.75), FmrZoomToFraction(300, 10, 500), 0.0001);
  Assert.AreEqual(Single(1), FmrZoomToFraction(900, 10, 500), 0.0001, 'clamped');
end;

procedure TExtrasLayoutTests.ZoomScaleRoundTrip;
var
  Z: Integer;
begin
  for Z := 10 to 500 do
    Assert.AreEqual(Z, FmrFractionToZoom(FmrZoomToFraction(Z, 10, 500), 10, 500), 'zoom ' + IntToStr(Z));
  Assert.AreEqual(10, FmrFractionToZoom(-1, 10, 500));
  Assert.AreEqual(500, FmrFractionToZoom(2, 10, 500));
end;

procedure TExtrasLayoutTests.ZoomScaleLinearWithoutHundred;
begin
  Assert.AreEqual(Single(0.5), FmrZoomToFraction(150, 100, 200), 0.0001);
  Assert.AreEqual(150, FmrFractionToZoom(0.5, 100, 200));
  Assert.AreEqual(Single(0), FmrZoomToFraction(5, 10, 10), 0.0001, 'empty range');
end;

procedure TExtrasLayoutTests.ZoomSteps;
begin
  Assert.AreEqual(110, FmrZoomStep(100, 10, 10, 500, True));
  Assert.AreEqual(90, FmrZoomStep(100, 10, 10, 500, False));
  Assert.AreEqual(130, FmrZoomStep(123, 10, 10, 500, True), 'next multiple');
  Assert.AreEqual(120, FmrZoomStep(123, 10, 10, 500, False), 'previous multiple');
  Assert.AreEqual(500, FmrZoomStep(500, 10, 10, 500, True), 'clamped at max');
  Assert.AreEqual(10, FmrZoomStep(10, 10, 10, 500, False), 'clamped at min');
end;

procedure TExtrasLayoutTests.NavigationSkipsDisabled;
var
  Sel: TArray<Boolean>;
begin
  Sel := [True, False, True, True, False];
  Assert.AreEqual(2, FmrNextSelectable(Sel, 0, 1, False));
  Assert.AreEqual(0, FmrNextSelectable(Sel, 2, -1, False));
  Assert.AreEqual(3, FmrNextSelectable(Sel, 3, 1, False), 'stays at the end without wrapping');
  Assert.AreEqual(0, FmrNextSelectable(Sel, -1, 1, False), 'from nothing: first');
  Assert.AreEqual(3, FmrNextSelectable(Sel, -1, -1, False), 'from nothing up: last');
  Assert.AreEqual(-1, FmrNextSelectable([False, False], -1, 1, True), 'nothing selectable');
  Assert.AreEqual(-1, FmrNextSelectable([], 0, 1, True), 'empty');
end;

procedure TExtrasLayoutTests.NavigationWrapsAndEdges;
var
  Sel: TArray<Boolean>;
begin
  Sel := [False, True, True, False];
  Assert.AreEqual(1, FmrNextSelectable(Sel, 2, 1, True), 'wraps to the first selectable');
  Assert.AreEqual(2, FmrNextSelectable(Sel, 1, -1, True), 'wraps to the last selectable');
  Assert.AreEqual(1, FmrEdgeSelectable(Sel, False));
  Assert.AreEqual(2, FmrEdgeSelectable(Sel, True));
  Assert.AreEqual(1, FmrNextSelectable([False, True, False], 1, 1, True), 'single selectable entry');
end;

procedure TExtrasLayoutTests.ScrollHelpers;
begin
  Assert.AreEqual(Single(0), FmrClampScroll(-5, 100, 50));
  Assert.AreEqual(Single(50), FmrClampScroll(80, 100, 50));
  Assert.AreEqual(Single(0), FmrClampScroll(30, 40, 50), 'content fits');
  Assert.AreEqual(Single(10), FmrScrollIntoView(20, 10, 30, 50), 'above: scroll up');
  Assert.AreEqual(Single(30), FmrScrollIntoView(0, 60, 80, 50), 'below: scroll down');
  Assert.AreEqual(Single(20), FmrScrollIntoView(20, 30, 60, 50), 'visible: unchanged');
end;

initialization
  TDUnitX.RegisterTestFixture(TExtrasLayoutTests);

end.
