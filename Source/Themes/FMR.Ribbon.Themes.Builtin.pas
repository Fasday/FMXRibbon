{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Built-in themes                                      }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Themes.Builtin;

/// Registers the built-in themes in TFmrTheme (initialization section):
///   Office365Colorful, Office365White, Office365DarkGray, Office365Black,
///   Office2016Colorful, Office2016White, Office2016DarkGray,
///   Office2013White, Office2013LightGray, Office2013DarkGray,
///   Office2010Blue, Office2010Silver, Office2010Black,
///   Office2007Blue, Office2007Silver, Office2007Black,
///   FluentLight, FluentDark.
/// Colors are approximations of the look of the corresponding Office versions, built from an accent color.

interface

uses
  System.UITypes, FMR.Ribbon.Theme;

/// <summary>Registers the built-in themes (called from the initialization; safe to call again).</summary>
procedure FmrRegisterBuiltinThemes;

implementation

uses
  System.SysUtils;

type
  TFill = TFmrFill;

function S(const C: TAlphaColor): TFill; inline;
begin
  Result := TFmrFill.Solid(C);
end;

function V(const C1, C2: TAlphaColor): TFill; overload;
begin
  Result := TFmrFill.Vertical([C1, C2], []);
end;

function V(const C1, C2, C3: TAlphaColor): TFill; overload;
begin
  Result := TFmrFill.Vertical([C1, C2, C3], []);
end;

function G(const T1, T2, B1, B2: TAlphaColor): TFill;
begin
  Result := TFmrFill.Glass(T1, T2, B1, B2);
end;

function N: TFill; inline;
begin
  Result := TFmrFill.None;
end;

{ metrics }

procedure BaseMetrics(var M: TFmrThemeMetrics);
begin
  M.FontFamily := 'Segoe UI';
  M.FontSize := 12;
  M.CaptionFontSize := 12;
  M.GroupCaptionFontSize := 12;
  M.CaptionHeight := 30;
  M.TabRowHeight := 25;
  M.TabPaddingH := 10;
  M.TabSpacing := 2;
  M.TabRadius := 0;
  M.ContentHeight := 66;
  M.GroupCaptionHeight := 18;
  M.GroupPaddingH := 4;
  M.GroupPaddingTop := 3;
  M.GroupSpacing := 0;
  M.GroupRadius := 0;
  M.BodyPaddingV := 2;
  M.BodyRadius := 0;
  M.BodyMargin := 0;
  M.SmallButtonHeight := 22;
  M.SmallGlyphSize := 16;
  M.LargeGlyphSize := 32;
  M.LargeButtonMinWidth := 42;
  M.ButtonPaddingH := 4;
  M.ButtonRadius := 0;
  M.ArrowSize := 5;
  M.SeparatorWidth := 1;
  M.SimplifiedBodyHeight := 40;
  M.QATButtonSize := 24;
  M.MenuItemHeight := 24;
  M.MenuGutterWidth := 30;
  M.MenuRadius := 0;
  M.KeyTipRadius := 2;
  M.ScrollButtonWidth := 14;
  M.StatusBarHeight := 23;
  M.TouchScale := 1.3;
end;

function FamilyMetrics(const AFamily: TFmrThemeFamily): TFmrThemeMetrics;
begin
  BaseMetrics(Result);
  case AFamily of
    TFmrThemeFamily.Office2007:
      begin
        Result.CaptionHeight := 30;
        Result.TabRowHeight := 24;
        Result.TabRadius := 3;
        Result.GroupRadius := 3;
        Result.GroupSpacing := 3;
        Result.GroupCaptionHeight := 16;
        Result.BodyRadius := 3;
        Result.ButtonRadius := 3;
        Result.MenuGutterWidth := 26;
      end;
    TFmrThemeFamily.Office2010:
      begin
        Result.CaptionHeight := 28;
        Result.TabRowHeight := 24;
        Result.TabRadius := 2;
        Result.GroupRadius := 2;
        Result.GroupSpacing := 2;
        Result.GroupCaptionHeight := 16;
        Result.BodyRadius := 2;
        Result.ButtonRadius := 2;
      end;
    TFmrThemeFamily.Office2013, TFmrThemeFamily.Office2016:
      begin
        Result.CaptionHeight := 30;
        Result.TabRowHeight := 25;
      end;
    TFmrThemeFamily.Office365:
      begin
        Result.CaptionHeight := 32;
        Result.TabRowHeight := 30;
        Result.TabRadius := 4;
        Result.ButtonRadius := 4;
        Result.BodyRadius := 8;
        Result.BodyMargin := 6;
        Result.BodyPaddingV := 4;
        Result.MenuRadius := 6;
        Result.MenuGutterWidth := 32;
        Result.ScrollButtonWidth := 16;
      end;
    TFmrThemeFamily.Fluent:
      begin
        Result.CaptionHeight := 32;
        Result.TabRowHeight := 32;
        Result.TabRadius := 4;
        Result.ButtonRadius := 4;
        Result.BodyRadius := 8;
        Result.BodyMargin := 6;
        Result.BodyPaddingV := 4;
        Result.MenuRadius := 8;
        Result.MenuItemHeight := 28;
        Result.MenuGutterWidth := 36;
        Result.KeyTipRadius := 4;
        Result.ScrollButtonWidth := 16;
      end;
  end;
end;

function MakeStyle(const AFamily: TFmrThemeFamily; const ADark, AColoredCaption: Boolean): TFmrThemeStyle;
begin
  Result.Family := AFamily;
  Result.Dark := ADark;
  Result.ColoredCaption := AColoredCaption;
  Result.FloatingBody := AFamily in [TFmrThemeFamily.Office365, TFmrThemeFamily.Fluent];
  Result.TransparentCaption := AFamily = TFmrThemeFamily.Fluent;
  Result.UppercaseTabs := AFamily = TFmrThemeFamily.Office2013;
  Result.Glossy := AFamily = TFmrThemeFamily.Office2007;
  case AFamily of
    TFmrThemeFamily.Office2007:
      Result.TabShape := TFmrTabShape.Rounded;
    TFmrThemeFamily.Office2010, TFmrThemeFamily.Office2013, TFmrThemeFamily.Office2016:
      Result.TabShape := TFmrTabShape.Box;
  else
    Result.TabShape := TFmrTabShape.Underline;
  end;
  case AFamily of
    TFmrThemeFamily.Office2007:
      Result.AppButton := TFmrAppButtonShape.Orb;
    TFmrThemeFamily.Office2010, TFmrThemeFamily.Office2013:
      Result.AppButton := TFmrAppButtonShape.ColoredTab;
  else
    Result.AppButton := TFmrAppButtonShape.TextTab;
  end;
  if AFamily in [TFmrThemeFamily.Office2007, TFmrThemeFamily.Office2010] then
    Result.GroupFrame := TFmrGroupFrame.Boxed
  else
    Result.GroupFrame := TFmrGroupFrame.Separated;
end;

{ flat palettes (Office 2013, 2016, 365, Fluent) }

type
  /// The few colors a flat theme is made of; every token is derived from them.
  TFlat = record
    Dark: Boolean;
    Accent: TAlphaColor;
    /// accent readable as text/indicator on the body (lighter on dark themes)
    AccentText: TAlphaColor;
    Caption: TAlphaColor;          // caption and tab row background
    CaptionText: TAlphaColor;
    CaptionTextInactive: TAlphaColor;
    CaptionHot: TAlphaColor;       // hover over caption buttons / tabs on the caption background
    CaptionPressed: TAlphaColor;
    TabText: TAlphaColor;
    TabTextHot: TAlphaColor;
    TabTextActive: TAlphaColor;
    TabActiveFill: TAlphaColor;    // Box tabs: the active tab (= body); Underline tabs: none
    TabActiveBorder: TAlphaColor;
    Body: TAlphaColor;
    BodyBorder: TAlphaColor;
    Separator: TAlphaColor;
    Text: TAlphaColor;
    TextSecondary: TAlphaColor;
    TextDisabled: TAlphaColor;
    Hot: TAlphaColor;
    HotBorder: TAlphaColor;
    Pressed: TAlphaColor;
    PressedBorder: TAlphaColor;
    Checked: TAlphaColor;
    CheckedBorder: TAlphaColor;
    CheckedHot: TAlphaColor;
    Popup: TAlphaColor;
    PopupBorder: TAlphaColor;
    Edit: TAlphaColor;
    EditBorder: TAlphaColor;
    EditBorderHot: TAlphaColor;
  end;

function AccentOnDark(const AAccent: TAlphaColor): TAlphaColor;
begin
  if FmrLuminance(AAccent) < 0.25 then
    Result := FmrLighten(AAccent, 0.45)
  else
    Result := AAccent;
end;

function LightFlat(const AAccent: TAlphaColor): TFlat;
begin
  Result.Dark := False;
  Result.Accent := AAccent;
  Result.AccentText := AAccent;
  Result.Caption := $FFF3F3F3;
  Result.CaptionText := $FF1F1F1F;
  Result.CaptionTextInactive := $FF8A8A8A;
  Result.CaptionHot := $FFE0E0E0;
  Result.CaptionPressed := $FFCCCCCC;
  Result.TabText := $FF424242;
  Result.TabTextHot := $FF1F1F1F;
  Result.TabTextActive := AAccent;
  Result.TabActiveFill := TAlphaColors.Null;
  Result.TabActiveBorder := TAlphaColors.Null;
  Result.Body := $FFFFFFFF;
  Result.BodyBorder := $FFE1E1E1;
  Result.Separator := $FFE1E1E1;
  Result.Text := $FF262626;
  Result.TextSecondary := $FF616161;
  Result.TextDisabled := $FFA6A6A6;
  Result.Hot := $FFEBEBEB;
  Result.HotBorder := TAlphaColors.Null;
  Result.Pressed := $FFD6D6D6;
  Result.PressedBorder := TAlphaColors.Null;
  Result.Checked := $FFDEDEDE;
  Result.CheckedBorder := $FFC8C8C8;
  Result.CheckedHot := $FFD0D0D0;
  Result.Popup := $FFFFFFFF;
  Result.PopupBorder := $FFD6D6D6;
  Result.Edit := $FFFFFFFF;
  Result.EditBorder := $FFC8C8C8;
  Result.EditBorderHot := $FF8A8A8A;
end;

function DarkFlat(const AAccent: TAlphaColor; const ACaption, ABody, AHot, APressed, ASeparator: TAlphaColor): TFlat;
begin
  Result.Dark := True;
  Result.Accent := AAccent;
  Result.AccentText := AccentOnDark(AAccent);
  Result.Caption := ACaption;
  Result.CaptionText := $FFF5F5F5;
  Result.CaptionTextInactive := $FF9A9A9A;
  Result.CaptionHot := FmrLighten(ACaption, 0.12);
  Result.CaptionPressed := FmrLighten(ACaption, 0.2);
  Result.TabText := $FFD6D6D6;
  Result.TabTextHot := $FFFFFFFF;
  Result.TabTextActive := Result.AccentText;
  Result.TabActiveFill := TAlphaColors.Null;
  Result.TabActiveBorder := TAlphaColors.Null;
  Result.Body := ABody;
  Result.BodyBorder := ASeparator;
  Result.Separator := ASeparator;
  Result.Text := $FFF0F0F0;
  Result.TextSecondary := $FFC2C2C2;
  Result.TextDisabled := $FF808080;
  Result.Hot := AHot;
  Result.HotBorder := TAlphaColors.Null;
  Result.Pressed := APressed;
  Result.PressedBorder := TAlphaColors.Null;
  Result.Checked := FmrBlend(AHot, APressed, 0.5);
  Result.CheckedBorder := FmrLighten(APressed, 0.12);
  Result.CheckedHot := APressed;
  Result.Popup := FmrLighten(ACaption, 0.04);
  Result.PopupBorder := ASeparator;
  Result.Edit := FmrDarken(ABody, 0.15);
  Result.EditBorder := FmrLighten(ASeparator, 0.15);
  Result.EditBorderHot := FmrLighten(ASeparator, 0.35);
end;

procedure ApplyFlat(const T: TFmrTheme; const P: TFlat);
var
  KeyFill, KeyText: TAlphaColor;
begin
  T.Colors[TFmrToken.Accent] := P.Accent;
  T.Colors[TFmrToken.FocusBorder] := P.Text;

  T.Colors[TFmrToken.CaptionFill] := P.Caption;
  T.Colors[TFmrToken.CaptionFillInactive] := P.Caption;
  T.Colors[TFmrToken.CaptionText] := P.CaptionText;
  T.Colors[TFmrToken.CaptionTextInactive] := P.CaptionTextInactive;
  T.Colors[TFmrToken.CaptionButtonGlyph] := P.CaptionText;
  T.Colors[TFmrToken.CaptionButtonHotFill] := P.CaptionHot;
  T.Colors[TFmrToken.CaptionButtonPressedFill] := P.CaptionPressed;
  T.Colors[TFmrToken.CloseButtonHotFill] := $FFC42B1C;
  T.Colors[TFmrToken.CloseButtonPressedFill] := $FFC74F43;
  T.Colors[TFmrToken.CloseButtonHotGlyph] := TAlphaColors.White;
  if P.Dark then
  begin
    T.Colors[TFmrToken.FrameBorder] := $FF5A5A5A;
    T.Colors[TFmrToken.FrameBorderInactive] := $FF464646;
  end
  else
  begin
    T.Colors[TFmrToken.FrameBorder] := $FFBDBDBD;
    T.Colors[TFmrToken.FrameBorderInactive] := $FFD6D6D6;
  end;

  T[TFmrToken.AppButtonFill] := N;
  T.Colors[TFmrToken.AppButtonHotFill] := P.CaptionHot;
  T.Colors[TFmrToken.AppButtonPressedFill] := P.CaptionPressed;
  T.Colors[TFmrToken.AppButtonText] := P.TabText;
  T[TFmrToken.AppButtonBorder] := N;

  T.Colors[TFmrToken.TabRowFill] := P.Caption;
  T.Colors[TFmrToken.TabText] := P.TabText;
  T.Colors[TFmrToken.TabTextHot] := P.TabTextHot;
  T.Colors[TFmrToken.TabTextActive] := P.TabTextActive;
  T.Colors[TFmrToken.TabTextDisabled] := P.TextDisabled;
  T.Colors[TFmrToken.TabHotFill] := P.CaptionHot;
  T.Colors[TFmrToken.TabActiveFill] := P.TabActiveFill;
  T.Colors[TFmrToken.TabActiveBorder] := P.TabActiveBorder;
  T.Colors[TFmrToken.TabActiveIndicator] := P.TabTextActive;
  T[TFmrToken.TabSeparator] := N;

  T.Colors[TFmrToken.BodyFill] := P.Body;
  T.Colors[TFmrToken.BodyBorder] := P.BodyBorder;
  if P.Dark then
    T.Colors[TFmrToken.BodyShadow] := $40000000
  else
    T.Colors[TFmrToken.BodyShadow] := $14000000;
  T[TFmrToken.GroupFill] := N;
  T[TFmrToken.GroupHotFill] := N;
  T[TFmrToken.GroupBorder] := N;
  T[TFmrToken.GroupCaptionFill] := N;
  T.Colors[TFmrToken.GroupCaptionText] := P.TextSecondary;
  T.Colors[TFmrToken.GroupSeparator] := P.Separator;
  T.Colors[TFmrToken.GroupLauncherGlyph] := P.TextSecondary;
  T[TFmrToken.GroupCollapsedFill] := N;
  T.Colors[TFmrToken.GroupCollapsedHotFill] := P.Hot;

  T.Colors[TFmrToken.ButtonText] := P.Text;
  T.Colors[TFmrToken.ButtonTextDisabled] := P.TextDisabled;
  T.Colors[TFmrToken.ButtonHotFill] := P.Hot;
  T.Colors[TFmrToken.ButtonHotBorder] := P.HotBorder;
  T.Colors[TFmrToken.ButtonPressedFill] := P.Pressed;
  T.Colors[TFmrToken.ButtonPressedBorder] := P.PressedBorder;
  T.Colors[TFmrToken.ButtonCheckedFill] := P.Checked;
  T.Colors[TFmrToken.ButtonCheckedBorder] := P.CheckedBorder;
  T.Colors[TFmrToken.ButtonCheckedHotFill] := P.CheckedHot;
  T.Colors[TFmrToken.ButtonSplitLine] := P.CheckedBorder;
  T.Colors[TFmrToken.ButtonArrow] := P.TextSecondary;
  T.Colors[TFmrToken.GlyphTint] := P.Text;
  T.Colors[TFmrToken.GlyphTintDisabled] := P.TextDisabled;
  T[TFmrToken.ButtonGroupFill] := N;
  T[TFmrToken.ButtonGroupBorder] := N;

  T.Colors[TFmrToken.EditFill] := P.Edit;
  T.Colors[TFmrToken.EditBorder] := P.EditBorder;
  T.Colors[TFmrToken.EditBorderHot] := P.EditBorderHot;
  T.Colors[TFmrToken.EditText] := P.Text;
  T.Colors[TFmrToken.EditPromptText] := P.TextSecondary;

  T.Colors[TFmrToken.GalleryFill] := P.Edit;
  T.Colors[TFmrToken.GalleryBorder] := P.Separator;
  T.Colors[TFmrToken.GalleryItemHotFill] := P.Hot;
  T.Colors[TFmrToken.GalleryItemHotBorder] := P.CheckedBorder;
  T.Colors[TFmrToken.GalleryItemSelectedFill] := FmrWithAlpha(P.AccentText, 0.18);
  T.Colors[TFmrToken.GalleryItemSelectedBorder] := P.AccentText;
  T.Colors[TFmrToken.GalleryScrollFill] := P.Body;
  T.Colors[TFmrToken.GalleryScrollHotFill] := P.Hot;
  T.Colors[TFmrToken.GalleryScrollGlyph] := P.TextSecondary;
  T.Colors[TFmrToken.GalleryGroupHeaderFill] := FmrBlend(P.Body, P.Caption, 0.6);
  T.Colors[TFmrToken.GalleryGroupHeaderText] := P.Text;

  T.Colors[TFmrToken.MenuFill] := P.Popup;
  T.Colors[TFmrToken.MenuBorder] := P.PopupBorder;
  T[TFmrToken.MenuGutterFill] := N;
  T.Colors[TFmrToken.MenuItemText] := P.Text;
  T.Colors[TFmrToken.MenuItemTextDisabled] := P.TextDisabled;
  T.Colors[TFmrToken.MenuItemHotFill] := P.Hot;
  T.Colors[TFmrToken.MenuItemHotBorder] := P.HotBorder;
  T.Colors[TFmrToken.MenuSeparator] := P.Separator;
  T.Colors[TFmrToken.MenuShortcutText] := P.TextSecondary;
  T.Colors[TFmrToken.MenuHeaderFill] := FmrBlend(P.Popup, P.Caption, 0.7);
  T.Colors[TFmrToken.MenuHeaderText] := P.Text;
  if P.Dark then
    T.Colors[TFmrToken.PopupShadow] := $66000000
  else
    T.Colors[TFmrToken.PopupShadow] := $38000000;

  T.Colors[TFmrToken.QATBelowFill] := P.Body;
  T.Colors[TFmrToken.QATBorder] := P.Separator;

  T.Colors[TFmrToken.ScrollButtonFill] := P.Body;
  T.Colors[TFmrToken.ScrollButtonHotFill] := P.Hot;
  T.Colors[TFmrToken.ScrollButtonGlyph] := P.TextSecondary;

  if P.Dark then
  begin
    KeyFill := $FF2B2B2B;
    KeyText := $FFFFFFFF;
  end
  else
  begin
    KeyFill := $FFFFFFFF;
    KeyText := $FF262626;
  end;
  T.Colors[TFmrToken.KeyTipFill] := KeyFill;
  T.Colors[TFmrToken.KeyTipBorder] := P.TextSecondary;
  T.Colors[TFmrToken.KeyTipText] := KeyText;
  T.Colors[TFmrToken.ScreenTipFill] := P.Popup;
  T.Colors[TFmrToken.ScreenTipBorder] := P.PopupBorder;
  T.Colors[TFmrToken.ScreenTipTitleText] := P.Text;
  T.Colors[TFmrToken.ScreenTipText] := P.TextSecondary;
  T.Colors[TFmrToken.ScreenTipSeparator] := P.Separator;

  T.Colors[TFmrToken.BackstageFill] := P.Body;
  T.Colors[TFmrToken.BackstageNavFill] := P.Caption;
  T.Colors[TFmrToken.BackstageNavText] := P.Text;
  T.Colors[TFmrToken.BackstageNavHotFill] := P.CaptionHot;
  T.Colors[TFmrToken.BackstageNavSelectedFill] := P.CaptionPressed;
  T.Colors[TFmrToken.BackstageNavSelectedText] := P.Text;
  T.Colors[TFmrToken.BackstageNavSeparator] := P.Separator;
  T.Colors[TFmrToken.BackstageHeaderText] := P.Text;
  T.Colors[TFmrToken.BackstageText] := P.TextSecondary;

  T.Colors[TFmrToken.StatusBarFill] := P.Caption;
  T.Colors[TFmrToken.StatusBarText] := P.TextSecondary;
  T.Colors[TFmrToken.StatusBarSeparator] := P.Separator;
  T.Colors[TFmrToken.StatusBarItemHotFill] := P.CaptionHot;

  T.Colors[TFmrToken.SearchBoxFill] := P.Edit;
  T.Colors[TFmrToken.SearchBoxHotFill] := P.Edit;
  T.Colors[TFmrToken.SearchBoxBorder] := P.EditBorder;
  T.Colors[TFmrToken.SearchBoxText] := P.Text;
  T.Colors[TFmrToken.SearchBoxPrompt] := P.TextSecondary;

  T.Colors[TFmrToken.MiniToolbarFill] := P.Popup;
  T.Colors[TFmrToken.MiniToolbarBorder] := P.PopupBorder;
  T.Colors[TFmrToken.RadialFill] := P.Popup;
  T.Colors[TFmrToken.RadialBorder] := P.AccentText;
  T.Colors[TFmrToken.RadialSectorHotFill] := P.Hot;
  T.Colors[TFmrToken.RadialText] := P.Text;
end;

/// Caption and tab row painted with the accent (Colorful themes): text and hover in white.
procedure ApplyColoredCaption(const T: TFmrTheme; const AAccent: TAlphaColor; const AUnderlineTabs: Boolean);
var
  Hot, Pressed: TAlphaColor;
begin
  Hot := FmrLighten(AAccent, 0.15);
  Pressed := FmrDarken(AAccent, 0.15);
  T.Colors[TFmrToken.CaptionFill] := AAccent;
  T.Colors[TFmrToken.CaptionFillInactive] := FmrBlend(AAccent, $FFFFFFFF, 0.1);
  T.Colors[TFmrToken.CaptionText] := TAlphaColors.White;
  T.Colors[TFmrToken.CaptionTextInactive] := $C0FFFFFF;
  T.Colors[TFmrToken.CaptionButtonGlyph] := TAlphaColors.White;
  T.Colors[TFmrToken.CaptionButtonHotFill] := Hot;
  T.Colors[TFmrToken.CaptionButtonPressedFill] := Pressed;
  T.Colors[TFmrToken.FrameBorder] := FmrDarken(AAccent, 0.2);
  T.Colors[TFmrToken.TabRowFill] := AAccent;
  T.Colors[TFmrToken.TabText] := TAlphaColors.White;
  T.Colors[TFmrToken.TabTextHot] := TAlphaColors.White;
  T.Colors[TFmrToken.TabHotFill] := Hot;
  T.Colors[TFmrToken.AppButtonText] := TAlphaColors.White;
  T.Colors[TFmrToken.AppButtonHotFill] := Hot;
  T.Colors[TFmrToken.AppButtonPressedFill] := Pressed;
  if AUnderlineTabs then
  begin
    T.Colors[TFmrToken.TabTextActive] := TAlphaColors.White;
    T.Colors[TFmrToken.TabActiveIndicator] := TAlphaColors.White;
  end;
  T.Colors[TFmrToken.SearchBoxFill] := FmrLighten(AAccent, 0.22);
  T.Colors[TFmrToken.SearchBoxHotFill] := FmrLighten(AAccent, 0.32);
  T[TFmrToken.SearchBoxBorder] := N;
  T.Colors[TFmrToken.SearchBoxText] := TAlphaColors.White;
  T.Colors[TFmrToken.SearchBoxPrompt] := $D0FFFFFF;
  T.Colors[TFmrToken.BackstageNavFill] := AAccent;
  T.Colors[TFmrToken.BackstageNavText] := TAlphaColors.White;
  T.Colors[TFmrToken.BackstageNavHotFill] := Hot;
  T.Colors[TFmrToken.BackstageNavSelectedFill] := Pressed;
  T.Colors[TFmrToken.BackstageNavSelectedText] := TAlphaColors.White;
  T.Colors[TFmrToken.BackstageNavSeparator] := FmrLighten(AAccent, 0.3);
  T.Colors[TFmrToken.StatusBarFill] := AAccent;
  T.Colors[TFmrToken.StatusBarText] := TAlphaColors.White;
  T.Colors[TFmrToken.StatusBarSeparator] := FmrLighten(AAccent, 0.3);
  T.Colors[TFmrToken.StatusBarItemHotFill] := Hot;
end;

/// Backstage of Office 2016: the navigation pane is the accent color in every variant.
procedure ApplyAccentBackstage(const T: TFmrTheme; const AAccent: TAlphaColor);
begin
  T.Colors[TFmrToken.BackstageNavFill] := AAccent;
  T.Colors[TFmrToken.BackstageNavText] := TAlphaColors.White;
  T.Colors[TFmrToken.BackstageNavHotFill] := FmrLighten(AAccent, 0.15);
  T.Colors[TFmrToken.BackstageNavSelectedFill] := FmrDarken(AAccent, 0.18);
  T.Colors[TFmrToken.BackstageNavSelectedText] := TAlphaColors.White;
  T.Colors[TFmrToken.BackstageNavSeparator] := FmrLighten(AAccent, 0.3);
end;

/// Office 2013/2010 highlights: tinted with the accent (light fill, accent border).
procedure ApplyTintedButtons(const T: TFmrTheme; const AAccent: TAlphaColor);
begin
  T.Colors[TFmrToken.ButtonHotFill] := FmrLighten(AAccent, 0.85);
  T.Colors[TFmrToken.ButtonHotBorder] := FmrLighten(AAccent, 0.55);
  T.Colors[TFmrToken.ButtonPressedFill] := FmrLighten(AAccent, 0.6);
  T.Colors[TFmrToken.ButtonPressedBorder] := FmrLighten(AAccent, 0.2);
  T.Colors[TFmrToken.ButtonCheckedFill] := FmrLighten(AAccent, 0.75);
  T.Colors[TFmrToken.ButtonCheckedBorder] := FmrLighten(AAccent, 0.2);
  T.Colors[TFmrToken.ButtonCheckedHotFill] := FmrLighten(AAccent, 0.65);
  T.Colors[TFmrToken.MenuItemHotFill] := FmrLighten(AAccent, 0.85);
  T.Colors[TFmrToken.MenuItemHotBorder] := FmrLighten(AAccent, 0.55);
  T.Colors[TFmrToken.GalleryItemHotFill] := FmrLighten(AAccent, 0.85);
  T.Colors[TFmrToken.GalleryItemHotBorder] := FmrLighten(AAccent, 0.55);
  T.Colors[TFmrToken.GroupCollapsedHotFill] := FmrLighten(AAccent, 0.85);
end;

procedure ColoredFileTab(const T: TFmrTheme; const AAccent: TAlphaColor; const AGradient: Boolean);
begin
  if AGradient then
  begin
    T[TFmrToken.AppButtonFill] := V(FmrLighten(AAccent, 0.12), FmrDarken(AAccent, 0.08));
    T[TFmrToken.AppButtonHotFill] := V(FmrLighten(AAccent, 0.25), FmrLighten(AAccent, 0.05));
    T[TFmrToken.AppButtonPressedFill] := V(FmrDarken(AAccent, 0.1), FmrDarken(AAccent, 0.25));
  end
  else
  begin
    T.Colors[TFmrToken.AppButtonFill] := AAccent;
    T.Colors[TFmrToken.AppButtonHotFill] := FmrLighten(AAccent, 0.12);
    T.Colors[TFmrToken.AppButtonPressedFill] := FmrDarken(AAccent, 0.15);
  end;
  T.Colors[TFmrToken.AppButtonText] := TAlphaColors.White;
  T.Colors[TFmrToken.AppButtonBorder] := FmrDarken(AAccent, 0.25);
end;

procedure Init(const T: TFmrTheme; const AFamily: TFmrThemeFamily; const ADark, AColoredCaption: Boolean);
begin
  T.Style := MakeStyle(AFamily, ADark, AColoredCaption);
  T.Metrics := FamilyMetrics(AFamily);
end;

{ Office 365 }

procedure BuildOffice365White(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Office365, False, False);
  P := LightFlat(A);
  ApplyFlat(T, P);
end;

procedure BuildOffice365Colorful(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Office365, False, True);
  P := LightFlat(A);
  P.Body := $FFFFFFFF;
  ApplyFlat(T, P);
  ApplyColoredCaption(T, A, True);
  T[TFmrToken.BodyBorder] := N;
end;

procedure BuildOffice365DarkGray(const T: TFmrTheme; const A: TAlphaColor);
begin
  Init(T, TFmrThemeFamily.Office365, True, False);
  ApplyFlat(T, DarkFlat(A, $FF3C3C3C, $FF4A4A4A, $FF5C5C5C, $FF6A6A6A, $FF5E5E5E));
end;

procedure BuildOffice365Black(const T: TFmrTheme; const A: TAlphaColor);
begin
  Init(T, TFmrThemeFamily.Office365, True, False);
  ApplyFlat(T, DarkFlat(A, $FF1F1F1F, $FF292929, $FF3D3D3D, $FF4A4A4A, $FF3A3A3A));
end;

{ Office 2016 }

procedure BuildOffice2016Colorful(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Office2016, False, True);
  P := LightFlat(A);
  P.Body := $FFF1F1F1;
  P.BodyBorder := $FFD4D4D4;
  P.Separator := $FFD4D4D4;
  P.TabActiveFill := P.Body;
  P.Hot := $FFD9D9D9;
  P.Pressed := $FFC6C6C6;
  P.Checked := $FFCDCDCD;
  P.CheckedBorder := $FFABABAB;
  P.CheckedHot := $FFC0C0C0;
  P.TextSecondary := $FF666666;
  ApplyFlat(T, P);
  ApplyColoredCaption(T, A, False);
  T.Colors[TFmrToken.TabTextActive] := A;
  T.Colors[TFmrToken.TabActiveFill] := P.Body;
  ApplyAccentBackstage(T, A);
end;

procedure BuildOffice2016White(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Office2016, False, False);
  P := LightFlat(A);
  P.Caption := $FFFFFFFF;
  P.CaptionHot := $FFE5E5E5;
  P.CaptionPressed := $FFCACACA;
  P.Body := $FFFFFFFF;
  P.BodyBorder := $FFD4D4D4;
  P.Separator := $FFE1E1E1;
  P.TabActiveFill := $FFFFFFFF;
  P.TabActiveBorder := $FFD4D4D4;
  P.Hot := $FFE5E5E5;
  P.Pressed := $FFCACACA;
  P.TextSecondary := $FF666666;
  ApplyFlat(T, P);
  ApplyAccentBackstage(T, A);
end;

procedure BuildOffice2016DarkGray(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Office2016, False, False);
  P := LightFlat(A);
  P.Caption := $FF444444;
  P.CaptionText := $FFFFFFFF;
  P.CaptionTextInactive := $FFB0B0B0;
  P.CaptionHot := $FF5A5A5A;
  P.CaptionPressed := $FF6E6E6E;
  P.TabText := $FFFFFFFF;
  P.TabTextHot := $FFFFFFFF;
  P.Body := $FFC6C6C6;
  P.BodyBorder := $FF9A9A9A;
  P.Separator := $FFA6A6A6;
  P.TabActiveFill := P.Body;
  P.TabTextActive := $FF262626;
  P.Hot := $FFB0B0B0;
  P.Pressed := $FF9C9C9C;
  P.Checked := $FFA8A8A8;
  P.CheckedBorder := $FF808080;
  P.CheckedHot := $FF9A9A9A;
  P.TextSecondary := $FF3C3C3C;
  P.Edit := $FFE8E8E8;
  P.EditBorder := $FF9A9A9A;
  ApplyFlat(T, P);
  T.Colors[TFmrToken.AppButtonText] := TAlphaColors.White;
  ApplyAccentBackstage(T, A);
end;

{ Office 2013 }

procedure Build2013(const T: TFmrTheme; const A: TAlphaColor; const ACaption, ABody: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Office2013, False, False);
  P := LightFlat(A);
  P.Caption := ACaption;
  P.CaptionText := $FF444444;
  P.CaptionHot := FmrDarken(ACaption, 0.1);
  P.CaptionPressed := FmrDarken(ACaption, 0.2);
  P.TabText := $FF444444;
  P.TabTextHot := A;
  P.Body := ABody;
  P.BodyBorder := $FFD4D4D4;
  P.Separator := $FFE1E1E1;
  P.TabActiveFill := ABody;
  P.TabActiveBorder := $FFD4D4D4;
  P.TextSecondary := $FF666666;
  ApplyFlat(T, P);
  T[TFmrToken.TabHotFill] := N;
  ApplyTintedButtons(T, A);
  ColoredFileTab(T, A, False);
  ApplyAccentBackstage(T, A);
end;

procedure BuildOffice2013White(const T: TFmrTheme; const A: TAlphaColor);
begin
  Build2013(T, A, $FFFFFFFF, $FFFFFFFF);
end;

procedure BuildOffice2013LightGray(const T: TFmrTheme; const A: TAlphaColor);
begin
  Build2013(T, A, $FFF3F3F3, $FFF8F8F8);
end;

procedure BuildOffice2013DarkGray(const T: TFmrTheme; const A: TAlphaColor);
begin
  Build2013(T, A, $FFDEDEDE, $FFEBEBEB);
end;

{ Office 2010 }

type
  TGradientSet = record
    CaptionTop, CaptionBottom, CaptionInactive, CaptionText: TAlphaColor;
    TabRowTop, TabRowBottom, TabText, TabTextActive: TAlphaColor;
    BodyTop, BodyBottom, BodyBorder: TAlphaColor;
    GroupTop, GroupBottom, GroupHotTop, GroupHotBottom, GroupBorder: TAlphaColor;
    CaptionBandTop, CaptionBandBottom, GroupCaptionText: TAlphaColor;
    Text, TextDisabled, Glyph: TAlphaColor;
    MenuFill, MenuBorder, MenuGutter, MenuSeparator: TAlphaColor;
    PopupHeaderTop, PopupHeaderBottom: TAlphaColor;
  end;

procedure ApplyGradient(const T: TFmrTheme; const A: TAlphaColor; const P: TGradientSet; const AGlass: Boolean);
var
  Hot, Pressed, Checked, CheckedHot: TFill;
begin
  // Warm highlights shared by Office 2007 and 2010
  if AGlass then
  begin
    Hot := G($FFFFFCD9, $FFFFE894, $FFFFD34B, $FFFFE496);
    Pressed := G($FFF8B667, $FFF79D4A, $FFF5841F, $FFFBAE4F);
    Checked := G($FFFDDB96, $FFFCCB6B, $FFF9B23B, $FFFBD077);
    CheckedHot := G($FFFBC27C, $FFF9AA57, $FFF7922E, $FFFAB866);
  end
  else
  begin
    Hot := V($FFFFFCE6, $FFFFE69B);
    Pressed := V($FFFFE594, $FFFFC44D);
    Checked := V($FFFFE48C, $FFFFD45A);
    CheckedHot := V($FFFFD95E, $FFFFC43B);
  end;

  T.Colors[TFmrToken.Accent] := A;
  T.Colors[TFmrToken.FocusBorder] := P.Text;

  T[TFmrToken.CaptionFill] := V(P.CaptionTop, P.CaptionBottom);
  T.Colors[TFmrToken.CaptionFillInactive] := P.CaptionInactive;
  T.Colors[TFmrToken.CaptionText] := P.CaptionText;
  T.Colors[TFmrToken.CaptionTextInactive] := FmrBlend(P.CaptionText, P.CaptionInactive, 0.45);
  T.Colors[TFmrToken.CaptionButtonGlyph] := P.CaptionText;
  T.Colors[TFmrToken.CaptionButtonHotFill] := FmrWithAlpha($FFFFFFFF, 0.45);
  T.Colors[TFmrToken.CaptionButtonPressedFill] := FmrWithAlpha($FF000000, 0.12);
  T.Colors[TFmrToken.CloseButtonHotFill] := $FFD9442F;
  T.Colors[TFmrToken.CloseButtonPressedFill] := $FFA8301F;
  T.Colors[TFmrToken.CloseButtonHotGlyph] := TAlphaColors.White;
  T.Colors[TFmrToken.FrameBorder] := P.BodyBorder;
  T.Colors[TFmrToken.FrameBorderInactive] := FmrBlend(P.BodyBorder, P.CaptionInactive, 0.5);

  T[TFmrToken.TabRowFill] := V(P.TabRowTop, P.TabRowBottom);
  T.Colors[TFmrToken.TabText] := P.TabText;
  T.Colors[TFmrToken.TabTextHot] := P.TabText;
  T.Colors[TFmrToken.TabTextActive] := P.TabTextActive;
  T.Colors[TFmrToken.TabTextDisabled] := P.TextDisabled;
  T[TFmrToken.TabHotFill] := V(FmrWithAlpha($FFFFFFFF, 0.75), FmrWithAlpha($FFFFFFFF, 0.25));
  T[TFmrToken.TabActiveFill] := V(FmrLighten(P.BodyTop, 0.5), P.BodyTop);
  T.Colors[TFmrToken.TabActiveBorder] := P.BodyBorder;
  T[TFmrToken.TabActiveIndicator] := N;
  T[TFmrToken.TabSeparator] := N;

  T[TFmrToken.BodyFill] := V(P.BodyTop, P.BodyBottom);
  T.Colors[TFmrToken.BodyBorder] := P.BodyBorder;
  T.Colors[TFmrToken.BodyShadow] := $18000000;
  T[TFmrToken.GroupFill] := V(P.GroupTop, P.GroupBottom);
  T[TFmrToken.GroupHotFill] := V(P.GroupHotTop, P.GroupHotBottom);
  T.Colors[TFmrToken.GroupBorder] := P.GroupBorder;
  if P.CaptionBandTop <> 0 then
    T[TFmrToken.GroupCaptionFill] := V(P.CaptionBandTop, P.CaptionBandBottom)
  else
    T[TFmrToken.GroupCaptionFill] := N;
  T.Colors[TFmrToken.GroupCaptionText] := P.GroupCaptionText;
  T.Colors[TFmrToken.GroupSeparator] := P.GroupBorder;
  T.Colors[TFmrToken.GroupLauncherGlyph] := P.GroupCaptionText;
  T[TFmrToken.GroupCollapsedFill] := V(P.GroupTop, P.GroupBottom);
  T[TFmrToken.GroupCollapsedHotFill] := Hot;

  T.Colors[TFmrToken.ButtonText] := P.Text;
  T.Colors[TFmrToken.ButtonTextDisabled] := P.TextDisabled;
  T[TFmrToken.ButtonHotFill] := Hot;
  T.Colors[TFmrToken.ButtonHotBorder] := $FFDDCF9B;
  T[TFmrToken.ButtonPressedFill] := Pressed;
  T.Colors[TFmrToken.ButtonPressedBorder] := $FFC29B4E;
  T[TFmrToken.ButtonCheckedFill] := Checked;
  T.Colors[TFmrToken.ButtonCheckedBorder] := $FFC29B4E;
  T[TFmrToken.ButtonCheckedHotFill] := CheckedHot;
  T.Colors[TFmrToken.ButtonSplitLine] := $FFC9A867;
  T.Colors[TFmrToken.ButtonArrow] := P.Text;
  T.Colors[TFmrToken.GlyphTint] := P.Glyph;
  T.Colors[TFmrToken.GlyphTintDisabled] := P.TextDisabled;
  T[TFmrToken.ButtonGroupFill] := V(FmrWithAlpha($FFFFFFFF, 0.6), FmrWithAlpha($FFFFFFFF, 0.2));
  T.Colors[TFmrToken.ButtonGroupBorder] := P.GroupBorder;

  T.Colors[TFmrToken.EditFill] := $FFFFFFFF;
  T.Colors[TFmrToken.EditBorder] := P.GroupBorder;
  T.Colors[TFmrToken.EditBorderHot] := $FFDDCF9B;
  T.Colors[TFmrToken.EditText] := P.Text;
  T.Colors[TFmrToken.EditPromptText] := P.TextDisabled;

  T.Colors[TFmrToken.GalleryFill] := $FFFFFFFF;
  T.Colors[TFmrToken.GalleryBorder] := P.GroupBorder;
  T[TFmrToken.GalleryItemHotFill] := N;
  T.Colors[TFmrToken.GalleryItemHotBorder] := $FFF2C45A;
  T[TFmrToken.GalleryItemSelectedFill] := N;
  T.Colors[TFmrToken.GalleryItemSelectedBorder] := $FFE89E3A;
  T[TFmrToken.GalleryScrollFill] := V(P.GroupTop, P.GroupBottom);
  T[TFmrToken.GalleryScrollHotFill] := Hot;
  T.Colors[TFmrToken.GalleryScrollGlyph] := P.Text;
  T[TFmrToken.GalleryGroupHeaderFill] := V(P.PopupHeaderTop, P.PopupHeaderBottom);
  T.Colors[TFmrToken.GalleryGroupHeaderText] := P.Text;

  T.Colors[TFmrToken.MenuFill] := P.MenuFill;
  T.Colors[TFmrToken.MenuBorder] := P.MenuBorder;
  T.Colors[TFmrToken.MenuGutterFill] := P.MenuGutter;
  T.Colors[TFmrToken.MenuItemText] := P.Text;
  T.Colors[TFmrToken.MenuItemTextDisabled] := P.TextDisabled;
  T[TFmrToken.MenuItemHotFill] := Hot;
  T.Colors[TFmrToken.MenuItemHotBorder] := $FFE5C365;
  T.Colors[TFmrToken.MenuSeparator] := P.MenuSeparator;
  T.Colors[TFmrToken.MenuShortcutText] := P.Text;
  T[TFmrToken.MenuHeaderFill] := V(P.PopupHeaderTop, P.PopupHeaderBottom);
  T.Colors[TFmrToken.MenuHeaderText] := P.Text;
  T.Colors[TFmrToken.PopupShadow] := $40000000;

  T[TFmrToken.QATBelowFill] := V(P.BodyTop, P.BodyBottom);
  T.Colors[TFmrToken.QATBorder] := P.BodyBorder;

  T[TFmrToken.ScrollButtonFill] := V(P.GroupTop, P.GroupBottom);
  T[TFmrToken.ScrollButtonHotFill] := Hot;
  T.Colors[TFmrToken.ScrollButtonGlyph] := P.Text;

  T[TFmrToken.KeyTipFill] := V($FFFFFFFF, P.BodyBottom);
  T.Colors[TFmrToken.KeyTipBorder] := $FF767676;
  T.Colors[TFmrToken.KeyTipText] := P.Text;
  T[TFmrToken.ScreenTipFill] := V($FFFFFFFF, $FFE4E5F0);
  T.Colors[TFmrToken.ScreenTipBorder] := $FF767676;
  T.Colors[TFmrToken.ScreenTipTitleText] := $FF4C4C4C;
  T.Colors[TFmrToken.ScreenTipText] := $FF4C4C4C;
  T.Colors[TFmrToken.ScreenTipSeparator] := $FF9EBBDD;

  T.Colors[TFmrToken.BackstageFill] := $FFFFFFFF;
  T[TFmrToken.BackstageNavFill] := V(P.BodyTop, P.BodyBottom);
  T.Colors[TFmrToken.BackstageNavText] := P.Text;
  T[TFmrToken.BackstageNavHotFill] := Hot;
  T[TFmrToken.BackstageNavSelectedFill] := V(FmrLighten(A, 0.15), A);
  T.Colors[TFmrToken.BackstageNavSelectedText] := TAlphaColors.White;
  T.Colors[TFmrToken.BackstageNavSeparator] := P.GroupBorder;
  T.Colors[TFmrToken.BackstageHeaderText] := P.Text;
  T.Colors[TFmrToken.BackstageText] := $FF3C3C3C;

  T[TFmrToken.StatusBarFill] := V(P.TabRowTop, P.TabRowBottom);
  T.Colors[TFmrToken.StatusBarText] := P.TabText;
  T.Colors[TFmrToken.StatusBarSeparator] := P.BodyBorder;
  T[TFmrToken.StatusBarItemHotFill] := Hot;

  T.Colors[TFmrToken.SearchBoxFill] := $FFFFFFFF;
  T.Colors[TFmrToken.SearchBoxHotFill] := $FFFFFFFF;
  T.Colors[TFmrToken.SearchBoxBorder] := P.BodyBorder;
  T.Colors[TFmrToken.SearchBoxText] := P.Text;
  T.Colors[TFmrToken.SearchBoxPrompt] := P.TextDisabled;

  T.Colors[TFmrToken.MiniToolbarFill] := P.MenuFill;
  T.Colors[TFmrToken.MiniToolbarBorder] := P.MenuBorder;
  T.Colors[TFmrToken.RadialFill] := P.MenuFill;
  T.Colors[TFmrToken.RadialBorder] := A;
  T[TFmrToken.RadialSectorHotFill] := Hot;
  T.Colors[TFmrToken.RadialText] := P.Text;

  ColoredFileTab(T, A, True);
end;

procedure BuildOffice2010Blue(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TGradientSet;
begin
  Init(T, TFmrThemeFamily.Office2010, False, False);
  P.CaptionTop := $FFE4EDF8; P.CaptionBottom := $FFD7E4F4; P.CaptionInactive := $FFEBF1F8; P.CaptionText := $FF1E395B;
  P.TabRowTop := $FFD7E4F4; P.TabRowBottom := $FFCCDCF0; P.TabText := $FF1E395B; P.TabTextActive := $FF1E395B;
  P.BodyTop := $FFFFFFFF; P.BodyBottom := $FFDDE7F4; P.BodyBorder := $FFA7BAD7;
  P.GroupTop := $00FFFFFF; P.GroupBottom := $00FFFFFF; P.GroupHotTop := $60FFFFFF; P.GroupHotBottom := $30FFFFFF;
  P.GroupBorder := $FFC5D2DF; P.CaptionBandTop := 0; P.CaptionBandBottom := 0; P.GroupCaptionText := $FF3E6AAA;
  P.Text := $FF1F1F1F; P.TextDisabled := $FF8D8D8D; P.Glyph := $FF2E4D7B;
  P.MenuFill := $FFFCFCFC; P.MenuBorder := $FFA7ABB0; P.MenuGutter := $FFF1F4FA; P.MenuSeparator := $FFE2E4E7;
  P.PopupHeaderTop := $FFE8EEF6; P.PopupHeaderBottom := $FFDDE7EE;
  ApplyGradient(T, A, P, False);
end;

procedure BuildOffice2010Silver(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TGradientSet;
begin
  Init(T, TFmrThemeFamily.Office2010, False, False);
  P.CaptionTop := $FFEFF1F4; P.CaptionBottom := $FFE1E5EA; P.CaptionInactive := $FFF2F3F5; P.CaptionText := $FF3B3B3B;
  P.TabRowTop := $FFE1E5EA; P.TabRowBottom := $FFD6DBE2; P.TabText := $FF3B3B3B; P.TabTextActive := $FF3B3B3B;
  P.BodyTop := $FFFFFFFF; P.BodyBottom := $FFE7EAEE; P.BodyBorder := $FFA9B1BC;
  P.GroupTop := $00FFFFFF; P.GroupBottom := $00FFFFFF; P.GroupHotTop := $60FFFFFF; P.GroupHotBottom := $30FFFFFF;
  P.GroupBorder := $FFC6CBD2; P.CaptionBandTop := 0; P.CaptionBandBottom := 0; P.GroupCaptionText := $FF4C535C;
  P.Text := $FF1F1F1F; P.TextDisabled := $FF8D8D8D; P.Glyph := $FF4C535C;
  P.MenuFill := $FFFCFCFC; P.MenuBorder := $FFA7ABB0; P.MenuGutter := $FFF1F2F4; P.MenuSeparator := $FFE2E4E7;
  P.PopupHeaderTop := $FFEEF0F3; P.PopupHeaderBottom := $FFE1E4E8;
  ApplyGradient(T, A, P, False);
end;

procedure BuildOffice2010Black(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TGradientSet;
begin
  Init(T, TFmrThemeFamily.Office2010, False, False);
  P.CaptionTop := $FF525252; P.CaptionBottom := $FF3D3D3D; P.CaptionInactive := $FF5E5E5E; P.CaptionText := $FFF2F2F2;
  P.TabRowTop := $FF3D3D3D; P.TabRowBottom := $FF2F2F2F; P.TabText := $FFF2F2F2; P.TabTextActive := $FF262626;
  P.BodyTop := $FFEFEFEF; P.BodyBottom := $FFCFCFCF; P.BodyBorder := $FF4C4C4C;
  P.GroupTop := $00FFFFFF; P.GroupBottom := $00FFFFFF; P.GroupHotTop := $50FFFFFF; P.GroupHotBottom := $20FFFFFF;
  P.GroupBorder := $FFA8A8A8; P.CaptionBandTop := 0; P.CaptionBandBottom := 0; P.GroupCaptionText := $FF404040;
  P.Text := $FF1F1F1F; P.TextDisabled := $FF8D8D8D; P.Glyph := $FF333333;
  P.MenuFill := $FFFAFAFA; P.MenuBorder := $FF6E6E6E; P.MenuGutter := $FFEFEFEF; P.MenuSeparator := $FFDADADA;
  P.PopupHeaderTop := $FFE6E6E6; P.PopupHeaderBottom := $FFD6D6D6;
  ApplyGradient(T, A, P, False);
  T.Colors[TFmrToken.CaptionButtonHotFill] := FmrWithAlpha($FFFFFFFF, 0.18);
  T.Colors[TFmrToken.CaptionButtonPressedFill] := FmrWithAlpha($FFFFFFFF, 0.1);
  T[TFmrToken.TabHotFill] := V(FmrWithAlpha($FFFFFFFF, 0.3), FmrWithAlpha($FFFFFFFF, 0.1));
  T.Colors[TFmrToken.StatusBarText] := $FFF2F2F2;
end;

{ Office 2007 }

procedure Apply2007(const T: TFmrTheme; const A: TAlphaColor; const P: TGradientSet);
begin
  Init(T, TFmrThemeFamily.Office2007, False, False);
  ApplyGradient(T, A, P, True);
  // Orb: blue glass at rest, orange glass on hover/press (painted radially by the painter)
  T[TFmrToken.AppButtonFill] := G($FFA9C6EE, $FF6B9BE0, $FF285DAF, $FF4B86D6);
  T[TFmrToken.AppButtonHotFill] := G($FFFFE7A2, $FFFFCB57, $FFF39A1B, $FFFDBA3E);
  T[TFmrToken.AppButtonPressedFill] := G($FFF9B868, $FFF39531, $FFD86808, $FFEE8C25);
  T.Colors[TFmrToken.AppButtonBorder] := $FF3F6CA8;
  T.Colors[TFmrToken.AppButtonText] := TAlphaColors.White;
  T[TFmrToken.TabHotFill] := G($C0FFFFFF, $80F0F6FD, $60D2E3F9, $90E6F0FC);
  T[TFmrToken.TabActiveFill] := V($FFFFFFFF, P.BodyTop);
  T[TFmrToken.BackstageNavSelectedFill] := G($FFFFFCD9, $FFFFE894, $FFFFD34B, $FFFFE496);
  T.Colors[TFmrToken.BackstageNavSelectedText] := P.Text;
end;

procedure BuildOffice2007Blue(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TGradientSet;
begin
  P.CaptionTop := $FFE3EEFD; P.CaptionBottom := $FFC4DAF7; P.CaptionInactive := $FFE3EBF6; P.CaptionText := $FF3E6AAA;
  P.TabRowTop := $FFC4DAF7; P.TabRowBottom := $FFBFD6F5; P.TabText := $FF15428B; P.TabTextActive := $FF15428B;
  P.BodyTop := $FFDCE9F8; P.BodyBottom := $FFC3D9F2; P.BodyBorder := $FF8DB2E3;
  P.GroupTop := $FFE7F0FB; P.GroupBottom := $FFD2E2F5; P.GroupHotTop := $FFF3F8FE; P.GroupHotBottom := $FFDEEAFA;
  P.GroupBorder := $FFA2BFE3; P.CaptionBandTop := $FFC2D8F1; P.CaptionBandBottom := $FFB3CDEC;
  P.GroupCaptionText := $FF3E6AAA;
  P.Text := $FF15428B; P.TextDisabled := $FF8D8D8D; P.Glyph := $FF1E4E8F;
  P.MenuFill := $FFFAFAFA; P.MenuBorder := $FF868686; P.MenuGutter := $FFE9EEF4; P.MenuSeparator := $FFC5C5C5;
  P.PopupHeaderTop := $FFE6EEF7; P.PopupHeaderBottom := $FFDDE7EE;
  Apply2007(T, A, P);
end;

procedure BuildOffice2007Silver(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TGradientSet;
begin
  P.CaptionTop := $FFF1F3F6; P.CaptionBottom := $FFDDE1E8; P.CaptionInactive := $FFF0F1F3; P.CaptionText := $FF4C535C;
  P.TabRowTop := $FFDDE1E8; P.TabRowBottom := $FFD6DAE1; P.TabText := $FF4C535C; P.TabTextActive := $FF4C535C;
  P.BodyTop := $FFF0F2F5; P.BodyBottom := $FFDADEE5; P.BodyBorder := $FFA9B0BA;
  P.GroupTop := $FFF4F5F7; P.GroupBottom := $FFE1E4E9; P.GroupHotTop := $FFFAFBFC; P.GroupHotBottom := $FFEAECEF;
  P.GroupBorder := $FFB3B9C3; P.CaptionBandTop := $FFD8DCE3; P.CaptionBandBottom := $FFC9CED7;
  P.GroupCaptionText := $FF4C535C;
  P.Text := $FF2E2E2E; P.TextDisabled := $FF8D8D8D; P.Glyph := $FF4C535C;
  P.MenuFill := $FFFAFAFA; P.MenuBorder := $FF868686; P.MenuGutter := $FFEFF0F2; P.MenuSeparator := $FFC5C5C5;
  P.PopupHeaderTop := $FFEFF0F2; P.PopupHeaderBottom := $FFE1E3E7;
  Apply2007(T, A, P);
end;

procedure BuildOffice2007Black(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TGradientSet;
begin
  P.CaptionTop := $FF575757; P.CaptionBottom := $FF3B3B3B; P.CaptionInactive := $FF5F5F5F; P.CaptionText := $FFF0F0F0;
  P.TabRowTop := $FF3B3B3B; P.TabRowBottom := $FF333333; P.TabText := $FFF0F0F0; P.TabTextActive := $FF262626;
  P.BodyTop := $FFE6E6E6; P.BodyBottom := $FFC8C8C8; P.BodyBorder := $FF5C5C5C;
  P.GroupTop := $FFEEEEEE; P.GroupBottom := $FFD6D6D6; P.GroupHotTop := $FFF7F7F7; P.GroupHotBottom := $FFE2E2E2;
  P.GroupBorder := $FFA0A0A0; P.CaptionBandTop := $FF6E6E6E; P.CaptionBandBottom := $FF575757;
  P.GroupCaptionText := $FFFFFFFF;
  P.Text := $FF1F1F1F; P.TextDisabled := $FF8D8D8D; P.Glyph := $FF333333;
  P.MenuFill := $FFFAFAFA; P.MenuBorder := $FF6E6E6E; P.MenuGutter := $FFEFEFEF; P.MenuSeparator := $FFC5C5C5;
  P.PopupHeaderTop := $FFE6E6E6; P.PopupHeaderBottom := $FFD6D6D6;
  Apply2007(T, A, P);
  T.Colors[TFmrToken.CaptionButtonHotFill] := FmrWithAlpha($FFFFFFFF, 0.18);
  T.Colors[TFmrToken.CaptionButtonPressedFill] := FmrWithAlpha($FFFFFFFF, 0.1);
  T.Colors[TFmrToken.StatusBarText] := $FFF0F0F0;
end;

{ Fluent }

procedure BuildFluentLight(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
begin
  Init(T, TFmrThemeFamily.Fluent, False, False);
  P := LightFlat(A);
  P.Caption := $FFF3F3F3;
  P.CaptionText := $FF1A1A1A;
  P.CaptionHot := $0F000000;
  P.CaptionPressed := $08000000;
  P.TabText := $FF5C5C5C;
  P.TabTextHot := $FF1A1A1A;
  P.TabTextActive := $FF1A1A1A;
  P.Body := $FFFBFBFB;
  P.BodyBorder := $14000000;
  P.Separator := $14000000;
  P.Text := $FF1A1A1A;
  P.TextSecondary := $FF5C5C5C;
  P.TextDisabled := $61000000;
  P.Hot := $0A000000;
  P.Pressed := $06000000;
  P.Checked := FmrWithAlpha(A, 0.14);
  P.CheckedBorder := TAlphaColors.Null;
  P.CheckedHot := FmrWithAlpha(A, 0.22);
  P.Popup := $FFF9F9F9;
  P.PopupBorder := $1F000000;
  P.Edit := $B3FFFFFF;
  P.EditBorder := $1F000000;
  P.EditBorderHot := $40000000;
  ApplyFlat(T, P);
  T.Colors[TFmrToken.TabActiveIndicator] := A;
  T.Colors[TFmrToken.CloseButtonHotFill] := $FFC42B1C;
  T.Colors[TFmrToken.PopupShadow] := $24000000;
  T.Colors[TFmrToken.BackstageNavSelectedFill] := $0F000000;
end;

procedure BuildFluentDark(const T: TFmrTheme; const A: TAlphaColor);
var
  P: TFlat;
  AL: TAlphaColor;
begin
  Init(T, TFmrThemeFamily.Fluent, True, False);
  AL := AccentOnDark(A);
  P := DarkFlat(A, $FF202020, $FF2B2B2B, $0FFFFFFF, $0AFFFFFF, $14FFFFFF);
  P.CaptionHot := $0FFFFFFF;
  P.CaptionPressed := $0AFFFFFF;
  P.TabText := $FFC5C5C5;
  P.TabTextActive := $FFFFFFFF;
  P.Text := $FFFFFFFF;
  P.TextSecondary := $FFC5C5C5;
  P.TextDisabled := $5DFFFFFF;
  P.Checked := FmrWithAlpha(AL, 0.24);
  P.CheckedBorder := TAlphaColors.Null;
  P.CheckedHot := FmrWithAlpha(AL, 0.32);
  P.Popup := $FF2C2C2C;
  P.PopupBorder := $33000000;
  P.Edit := $0FFFFFFF;
  P.EditBorder := $14FFFFFF;
  P.EditBorderHot := $2EFFFFFF;
  ApplyFlat(T, P);
  T.Colors[TFmrToken.TabActiveIndicator] := AL;
  T.Colors[TFmrToken.PopupShadow] := $5C000000;
  T.Colors[TFmrToken.BackstageNavSelectedFill] := $0FFFFFFF;
end;

procedure FmrRegisterBuiltinThemes;
begin
  TFmrTheme.RegisterTheme('Office365Colorful', 'Office 365 Colorful', FmrAccentWord, BuildOffice365Colorful);
  TFmrTheme.RegisterTheme('Office365White', 'Office 365 White', FmrAccentWord, BuildOffice365White);
  TFmrTheme.RegisterTheme('Office365DarkGray', 'Office 365 Dark Gray', FmrAccentWord, BuildOffice365DarkGray);
  TFmrTheme.RegisterTheme('Office365Black', 'Office 365 Black', FmrAccentWord, BuildOffice365Black);
  TFmrTheme.RegisterTheme('Office2016Colorful', 'Office 2016 Colorful', FmrAccentWord, BuildOffice2016Colorful);
  TFmrTheme.RegisterTheme('Office2016White', 'Office 2016 White', FmrAccentWord, BuildOffice2016White);
  TFmrTheme.RegisterTheme('Office2016DarkGray', 'Office 2016 Dark Gray', FmrAccentWord, BuildOffice2016DarkGray);
  TFmrTheme.RegisterTheme('Office2013White', 'Office 2013 White', FmrAccentWord, BuildOffice2013White);
  TFmrTheme.RegisterTheme('Office2013LightGray', 'Office 2013 Light Gray', FmrAccentWord, BuildOffice2013LightGray);
  TFmrTheme.RegisterTheme('Office2013DarkGray', 'Office 2013 Dark Gray', FmrAccentWord, BuildOffice2013DarkGray);
  TFmrTheme.RegisterTheme('Office2010Blue', 'Office 2010 Blue', $FF2B579A, BuildOffice2010Blue);
  TFmrTheme.RegisterTheme('Office2010Silver', 'Office 2010 Silver', $FF2B579A, BuildOffice2010Silver);
  TFmrTheme.RegisterTheme('Office2010Black', 'Office 2010 Black', $FF2B579A, BuildOffice2010Black);
  TFmrTheme.RegisterTheme('Office2007Blue', 'Office 2007 Blue', $FF2B579A, BuildOffice2007Blue);
  TFmrTheme.RegisterTheme('Office2007Silver', 'Office 2007 Silver', $FF2B579A, BuildOffice2007Silver);
  TFmrTheme.RegisterTheme('Office2007Black', 'Office 2007 Black', $FF2B579A, BuildOffice2007Black);
  TFmrTheme.RegisterTheme('FluentLight', 'Windows 11 Light', FmrAccentFluent, BuildFluentLight);
  TFmrTheme.RegisterTheme('FluentDark', 'Windows 11 Dark', FmrAccentFluent, BuildFluentDark);
end;

initialization
  FmrRegisterBuiltinThemes;

end.
