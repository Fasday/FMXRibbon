unit FMR.Tests.Themes;

/// Built-in themes: every text and glyph token reads on the fill it is painted on (contrast ratio, WCAG formula,
/// translucent fills composed over their base); unknown theme names give the default theme.

interface

uses
  System.SysUtils, System.UITypes, System.Math, DUnitX.TestFramework, FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin;

type
  [TestFixture]
  TThemeTests = class
  private
    FFailures: TStringBuilder;
    procedure CheckPair(const ATheme: TFmrTheme; const AName: string; const AFg, ABg, ABase: TFmrToken;
      const AMin: Single = 3);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TextReadsOnItsFill;
    [Test] procedure UnknownNameGivesDefaultTheme;
    [Test] procedure Office2024AccentRamp;
    [Test] procedure Office2024Themes;
  end;

/// Color of ATop (with alpha) painted over the opaque ABase.
function FmrTestOver(const ATop, ABase: TAlphaColor): TAlphaColor;
function FmrTestContrast(const A, B: TAlphaColor): Single;

implementation

function FmrTestOver(const ATop, ABase: TAlphaColor): TAlphaColor;
var
  A: Single;
  T, B, R: TAlphaColorRec;
begin
  T := TAlphaColorRec(ATop);
  B := TAlphaColorRec(ABase);
  A := T.A / 255;
  R.R := Round(T.R * A + B.R * (1 - A));
  R.G := Round(T.G * A + B.G * (1 - A));
  R.B := Round(T.B * A + B.B * (1 - A));
  R.A := 255;
  Result := TAlphaColor(R);
end;

function FmrTestContrast(const A, B: TAlphaColor): Single;
var
  LA, LB: Single;
begin
  LA := FmrLuminance(A);
  LB := FmrLuminance(B);
  Result := (Max(LA, LB) + 0.05) / (Min(LA, LB) + 0.05);
end;

{ TThemeTests }

procedure TThemeTests.Setup;
begin
  FFailures := TStringBuilder.Create;
end;

procedure TThemeTests.TearDown;
begin
  FreeAndNil(FFailures);
end;

procedure TThemeTests.CheckPair(const ATheme: TFmrTheme; const AName: string; const AFg, ABg, ABase: TFmrToken;
  const AMin: Single);
var
  Base, Bg, Fg: TAlphaColor;
  R: Single;
begin
  Base := FmrTestOver(ATheme.Fills[ABase].MainColor, $FFFFFFFF);
  if ATheme.Fills[ABg].IsVisible then
    Bg := FmrTestOver(ATheme.Fills[ABg].MainColor, Base)
  else
    Bg := Base;
  Fg := FmrTestOver(ATheme.Colors[AFg], Bg);
  R := FmrTestContrast(Fg, Bg);
  if R < AMin then
    FFailures.AppendFormat('%s %s: %.2f; ', [ATheme.Name, AName, R]);
end;

procedure TThemeTests.TextReadsOnItsFill;
var
  N: string;
  T: TFmrTheme;
begin
  for N in TFmrTheme.ThemeNames do
  begin
    T := TFmrTheme.CreateTheme(N);
    try
      CheckPair(T, 'caption text', TFmrToken.CaptionText, TFmrToken.CaptionFill, TFmrToken.CaptionFill);
      CheckPair(T, 'caption buttons', TFmrToken.CaptionButtonGlyph, TFmrToken.CaptionFill, TFmrToken.CaptionFill);
      CheckPair(T, 'tab text', TFmrToken.TabText, TFmrToken.TabRowFill, TFmrToken.TabRowFill);
      CheckPair(T, 'active tab', TFmrToken.TabTextActive, TFmrToken.TabActiveFill, TFmrToken.TabRowFill);
      // The Office 2007 orb is glass: its text has a gradient behind it, not one color.
      if T.Style.AppButton <> TFmrAppButtonShape.Orb then
        CheckPair(T, 'application button', TFmrToken.AppButtonText, TFmrToken.AppButtonFill, TFmrToken.TabRowFill);
      CheckPair(T, 'button text', TFmrToken.ButtonText, TFmrToken.GroupFill, TFmrToken.BodyFill);
      CheckPair(T, 'glyphs', TFmrToken.GlyphTint, TFmrToken.GroupFill, TFmrToken.BodyFill);
      CheckPair(T, 'hot button', TFmrToken.ButtonText, TFmrToken.ButtonHotFill, TFmrToken.BodyFill);
      CheckPair(T, 'checked button', TFmrToken.ButtonText, TFmrToken.ButtonCheckedFill, TFmrToken.BodyFill);
      CheckPair(T, 'group caption', TFmrToken.GroupCaptionText, TFmrToken.GroupCaptionFill, TFmrToken.BodyFill);
      CheckPair(T, 'edit text', TFmrToken.EditText, TFmrToken.EditFill, TFmrToken.BodyFill);
      CheckPair(T, 'menu text', TFmrToken.MenuItemText, TFmrToken.MenuFill, TFmrToken.MenuFill);
      CheckPair(T, 'hot menu row', TFmrToken.MenuItemText, TFmrToken.MenuItemHotFill, TFmrToken.MenuFill);
      CheckPair(T, 'menu header', TFmrToken.MenuHeaderText, TFmrToken.MenuHeaderFill, TFmrToken.MenuFill);
      CheckPair(T, 'gallery header', TFmrToken.GalleryGroupHeaderText, TFmrToken.GalleryGroupHeaderFill,
        TFmrToken.MenuFill);
      CheckPair(T, 'key tip', TFmrToken.KeyTipText, TFmrToken.KeyTipFill, TFmrToken.KeyTipFill);
      CheckPair(T, 'screen tip title', TFmrToken.ScreenTipTitleText, TFmrToken.ScreenTipFill,
        TFmrToken.ScreenTipFill);
      CheckPair(T, 'screen tip text', TFmrToken.ScreenTipText, TFmrToken.ScreenTipFill, TFmrToken.ScreenTipFill);
      CheckPair(T, 'backstage navigation', TFmrToken.BackstageNavText, TFmrToken.BackstageNavFill,
        TFmrToken.BackstageNavFill);
      CheckPair(T, 'selected backstage tab', TFmrToken.BackstageNavSelectedText, TFmrToken.BackstageNavSelectedFill,
        TFmrToken.BackstageNavFill);
      CheckPair(T, 'hot backstage tab', TFmrToken.BackstageNavText, TFmrToken.BackstageNavHotFill,
        TFmrToken.BackstageNavFill);
      CheckPair(T, 'backstage header', TFmrToken.BackstageHeaderText, TFmrToken.BackstageFill,
        TFmrToken.BackstageFill);
      CheckPair(T, 'backstage text', TFmrToken.BackstageText, TFmrToken.BackstageFill, TFmrToken.BackstageFill);
      CheckPair(T, 'status bar', TFmrToken.StatusBarText, TFmrToken.StatusBarFill, TFmrToken.StatusBarFill);
      CheckPair(T, 'hot status bar item', TFmrToken.StatusBarText, TFmrToken.StatusBarItemHotFill,
        TFmrToken.StatusBarFill);
      CheckPair(T, 'search box', TFmrToken.SearchBoxText, TFmrToken.SearchBoxFill, TFmrToken.CaptionFill);
      CheckPair(T, 'search prompt', TFmrToken.SearchBoxPrompt, TFmrToken.SearchBoxFill, TFmrToken.CaptionFill, 2.2);
      CheckPair(T, 'radial menu', TFmrToken.RadialText, TFmrToken.RadialFill, TFmrToken.RadialFill);
      CheckPair(T, 'scroll buttons', TFmrToken.ScrollButtonGlyph, TFmrToken.ScrollButtonFill, TFmrToken.BodyFill,
        2.5);
      CheckPair(T, 'dialog launcher', TFmrToken.GroupLauncherGlyph, TFmrToken.GroupCaptionFill, TFmrToken.BodyFill,
        2.5);
      CheckPair(T, 'gallery scroll', TFmrToken.GalleryScrollGlyph, TFmrToken.GalleryScrollFill, TFmrToken.BodyFill,
        2.5);
      CheckPair(T, 'inactive tab text', TFmrToken.TabTextInactive, TFmrToken.TabRowFill, TFmrToken.TabRowFill);
      CheckPair(T, 'primary button', TFmrToken.PrimaryButtonText, TFmrToken.PrimaryButtonFill,
        TFmrToken.PrimaryButtonFill);
      CheckPair(T, 'hot primary button', TFmrToken.PrimaryButtonText, TFmrToken.PrimaryButtonHotFill,
        TFmrToken.PrimaryButtonHotFill);
      CheckPair(T, 'toggle switch thumb', TFmrToken.ToggleSwitchThumbOn, TFmrToken.ToggleSwitchFill,
        TFmrToken.ToggleSwitchFill, 2);
    finally
      T.Free;
    end;
  end;
  Assert.AreEqual('', FFailures.ToString);
end;

procedure TThemeTests.UnknownNameGivesDefaultTheme;
var
  T, D: TFmrTheme;
begin
  T := TFmrTheme.CreateTheme('NoSuchTheme');
  D := TFmrTheme.CreateTheme(FmrDefaultThemeName);
  try
    Assert.IsNotNull(T);
    Assert.AreEqual(D.Colors[TFmrToken.CaptionFill], T.Colors[TFmrToken.CaptionFill]);
    Assert.AreEqual(D.Colors[TFmrToken.BodyFill], T.Colors[TFmrToken.BodyFill]);
  finally
    T.Free;
    D.Free;
  end;
end;

procedure TThemeTests.Office2024AccentRamp;

  function Near(const A, B: TAlphaColor; const ATolerance: Integer): Boolean;
  begin
    Result := (Abs(TAlphaColorRec(A).R - TAlphaColorRec(B).R) <= ATolerance) and
      (Abs(TAlphaColorRec(A).G - TAlphaColorRec(B).G) <= ATolerance) and
      (Abs(TAlphaColorRec(A).B - TAlphaColorRec(B).B) <= ATolerance);
  end;

begin
  // The light brand shades of Microsoft 365 (measured on Word and Excel, Black and Dark Gray themes).
  Assert.IsTrue(Near(FmrAccentShade(FmrAccentWord2024, 1), $FF598FEC, 8), 'Word 1');
  Assert.IsTrue(Near(FmrAccentShade(FmrAccentWord2024, 2), $FF82ABF1, 8), 'Word 2');
  Assert.IsTrue(Near(FmrAccentShade(FmrAccentWord2024, 3), $FFAEC6F0, 8), 'Word 3');
  Assert.IsTrue(Near(FmrAccentShade(FmrAccentExcel, 2), $FF60BD82, 18), 'Excel 2');
  Assert.IsTrue(Near(FmrAccentShade(FmrAccentExcel, 3), $FFA0D8B9, 12), 'Excel 3');
end;

procedure TThemeTests.Office2024Themes;
var
  N: string;
  T: TFmrTheme;
begin
  for N in ['Office2024Light', 'Office2024DarkGray', 'Office2024Dark'] do
  begin
    Assert.IsTrue(TFmrTheme.ThemeExists(N), N);
    T := TFmrTheme.CreateTheme(N);
    try
      Assert.AreEqual(Ord(TFmrThemeFamily.Office2024), Ord(T.Style.Family), N);
      Assert.IsTrue(T.Style.BoldActiveTab and T.Style.ChevronArrows and T.Style.TransparentCaption, N);
      // only the caption content dims when the window is inactive: tabs keep their color
      Assert.AreEqual(T.Colors[TFmrToken.TabText], T.Colors[TFmrToken.TabTextInactive], N);
      Assert.AreNotEqual(T.Colors[TFmrToken.CaptionText], T.Colors[TFmrToken.CaptionTextInactive], N);
      Assert.AreEqual(48.0, Double(T.Metrics.CaptionHeight), 0.01, N);
      Assert.AreEqual(30.0, Double(T.Metrics.TabRowHeight), 0.01, N);
    finally
      T.Free;
    end;
  end;
  // White: the active tab line is the "Share" fill x 0.9 (Word #185ABD -> #1651AA)
  T := TFmrTheme.CreateTheme('Office2024Light');
  try
    Assert.AreEqual(TAlphaColor($FF185ABD), T.Colors[TFmrToken.PrimaryButtonFill]);
    Assert.AreEqual(TAlphaColor($FF1651AA), T.Colors[TFmrToken.TabActiveIndicator]);
  finally
    T.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TThemeTests);

end.
