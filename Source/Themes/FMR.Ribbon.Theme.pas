{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Themes: tokens, fills, metrics, registry             }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Theme;

/// A theme is a table of tokens (fills: solid colors or vertical gradients), metrics and a few switches that select
/// the drawing variant (tab shape, group frame, application button). Built-in themes are built in code
/// (FMR.Ribbon.Themes.Builtin) from a palette and an accent color; any token can be overridden by a resource of a
/// StyleBook whose StyleName is the token's style name (TFmrTheme.TokenStyleName, e.g. 'fmr_tab_text'): a
/// TColorObject (solid color), a TBrushObject (solid or gradient brush) or, for the font, a TFontObject named
/// 'fmr_font'.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Messaging,
  FMX.Types, FMX.Graphics;

type
  /// <summary>Every color or fill a ribbon part is painted with.</summary>
  TFmrToken = (
    { window frame and caption }
    CaptionFill, CaptionFillInactive, CaptionText, CaptionTextInactive, CaptionButtonGlyph, CaptionButtonHotFill,
    CaptionButtonPressedFill, CloseButtonHotFill, CloseButtonPressedFill, CloseButtonHotGlyph, FrameBorder,
    FrameBorderInactive,
    { application button }
    AppButtonFill, AppButtonHotFill, AppButtonPressedFill, AppButtonText, AppButtonBorder,
    { tabs }
    TabRowFill, TabText, TabTextHot, TabTextActive, TabTextDisabled, TabHotFill, TabActiveFill, TabActiveBorder,
    TabActiveIndicator, TabSeparator,
    { body and groups }
    BodyFill, BodyBorder, BodyShadow, GroupFill, GroupHotFill, GroupBorder, GroupCaptionFill, GroupCaptionText,
    GroupSeparator, GroupLauncherGlyph, GroupCollapsedFill, GroupCollapsedHotFill,
    { buttons }
    ButtonText, ButtonTextDisabled, ButtonHotFill, ButtonHotBorder, ButtonPressedFill, ButtonPressedBorder,
    ButtonCheckedFill, ButtonCheckedBorder, ButtonCheckedHotFill, ButtonSplitLine, ButtonArrow, GlyphTint,
    GlyphTintDisabled, ButtonGroupFill, ButtonGroupBorder,
    { editors drawn by the ribbon itself (prompts, combo arrows) }
    EditFill, EditBorder, EditBorderHot, EditText, EditPromptText,
    { galleries }
    GalleryFill, GalleryBorder, GalleryItemHotFill, GalleryItemHotBorder, GalleryItemSelectedFill,
    GalleryItemSelectedBorder, GalleryScrollFill, GalleryScrollHotFill, GalleryScrollGlyph, GalleryGroupHeaderFill,
    GalleryGroupHeaderText,
    { menus and popups }
    MenuFill, MenuBorder, MenuGutterFill, MenuItemText, MenuItemTextDisabled, MenuItemHotFill, MenuItemHotBorder,
    MenuSeparator, MenuShortcutText, MenuHeaderFill, MenuHeaderText, PopupShadow,
    { quick access toolbar below the ribbon }
    QATBelowFill, QATBorder,
    { scroll buttons of tabs and groups }
    ScrollButtonFill, ScrollButtonHotFill, ScrollButtonGlyph,
    { key tips and screen tips }
    KeyTipFill, KeyTipBorder, KeyTipText, ScreenTipFill, ScreenTipBorder, ScreenTipTitleText, ScreenTipText,
    ScreenTipSeparator,
    { backstage view }
    BackstageFill, BackstageNavFill, BackstageNavText, BackstageNavHotFill, BackstageNavSelectedFill,
    BackstageNavSelectedText, BackstageNavSeparator, BackstageHeaderText, BackstageText,
    { status bar }
    StatusBarFill, StatusBarText, StatusBarSeparator, StatusBarItemHotFill,
    { search box in the caption }
    SearchBoxFill, SearchBoxHotFill, SearchBoxBorder, SearchBoxText, SearchBoxPrompt,
    { mini toolbar and radial menu }
    MiniToolbarFill, MiniToolbarBorder, RadialFill, RadialBorder, RadialSectorHotFill, RadialText,
    { misc }
    Accent, FocusBorder);

  TFmrFillKind = (Solid, Vertical);

  TFmrGradientStop = record
    Offset: Single;
    Color: TAlphaColor;
  end;

  /// <summary>A solid color or a vertical (top to bottom) gradient.</summary>
  TFmrFill = record
  public
    Kind: TFmrFillKind;
    Color: TAlphaColor;
    Stops: TArray<TFmrGradientStop>;
    class function Solid(const AColor: TAlphaColor): TFmrFill; static;
    /// <summary>Evenly spaced stops when AOffsets is empty.</summary>
    class function Vertical(const AColors: array of TAlphaColor; const AOffsets: array of Single): TFmrFill; static;
    /// <summary>The 2007 glass look: top half ATop1→ATop2, bottom half ABottom1→ABottom2.</summary>
    class function Glass(const ATop1, ATop2, ABottom1, ABottom2: TAlphaColor): TFmrFill; static;
    class function None: TFmrFill; static;
    function IsVisible: Boolean;
    /// <summary>Configures ABrush to paint this fill.</summary>
    procedure ApplyTo(const ABrush: TBrush);
    /// <summary>The color of a solid fill, the middle color of a gradient.</summary>
    function MainColor: TAlphaColor;
  end;

  TFmrThemeFamily = (Office2007, Office2010, Office2013, Office2016, Office365, Fluent);

  TFmrTabShape = (
    /// <summary>Office 2007: rounded top corners, glass fill.</summary>
    Rounded,
    /// <summary>Office 2010/2013/2016: a box open at the bottom, joined to the body.</summary>
    Box,
    /// <summary>Office 365 / Fluent: no box, the active tab has an accent line under its text.</summary>
    Underline);

  TFmrAppButtonShape = (
    /// <summary>Office 2007 round orb over the caption and the tab row.</summary>
    Orb,
    /// <summary>Office 2010: a colored "File" tab.</summary>
    ColoredTab,
    /// <summary>Office 2013+: a "File" tab colored like the caption.</summary>
    TextTab);

  TFmrGroupFrame = (
    /// <summary>Office 2007/2010: every group is a framed box with its caption in a band at the bottom.</summary>
    Boxed,
    /// <summary>Office 2013+: groups are separated by vertical lines, the caption is plain text.</summary>
    Separated);

  /// <summary>Switches that select the drawing variant of a theme.</summary>
  TFmrThemeStyle = record
    Family: TFmrThemeFamily;
    TabShape: TFmrTabShape;
    AppButton: TFmrAppButtonShape;
    GroupFrame: TFmrGroupFrame;
    /// <summary>Dark theme (text light, glyphs light).</summary>
    Dark: Boolean;
    /// <summary>The caption and the tab row are painted with the accent color (Office 2016/365 Colorful).</summary>
    ColoredCaption: Boolean;
    /// <summary>The body is a floating card with rounded corners (Office 365, Fluent).</summary>
    FloatingBody: Boolean;
    /// <summary>The caption may be transparent over a Mica/Acrylic backdrop (Fluent in Dwm frame mode).</summary>
    TransparentCaption: Boolean;
    /// <summary>Tab captions in capitals (Office 2013).</summary>
    UppercaseTabs: Boolean;
    /// <summary>Gradients with a glass highlight (Office 2007).</summary>
    Glossy: Boolean;
  end;

  /// <summary>Sizes in dp at 100 % scale (FMX scales them).</summary>
  TFmrThemeMetrics = record
    FontFamily: string;
    FontSize: Single;
    CaptionFontSize: Single;
    GroupCaptionFontSize: Single;
    CaptionHeight: Single;
    TabRowHeight: Single;
    TabPaddingH: Single;
    TabSpacing: Single;
    TabRadius: Single;
    /// <summary>Height of the group content (three rows of small buttons, one large button).</summary>
    ContentHeight: Single;
    GroupCaptionHeight: Single;
    GroupPaddingH: Single;
    GroupPaddingTop: Single;
    GroupSpacing: Single;
    GroupRadius: Single;
    BodyPaddingV: Single;
    BodyRadius: Single;
    BodyMargin: Single;
    SmallButtonHeight: Single;
    SmallGlyphSize: Single;
    LargeGlyphSize: Single;
    LargeButtonMinWidth: Single;
    ButtonPaddingH: Single;
    ButtonRadius: Single;
    ArrowSize: Single;
    SeparatorWidth: Single;
    SimplifiedBodyHeight: Single;
    QATButtonSize: Single;
    MenuItemHeight: Single;
    MenuGutterWidth: Single;
    MenuRadius: Single;
    KeyTipRadius: Single;
    ScrollButtonWidth: Single;
    StatusBarHeight: Single;
    /// <summary>Multiplier of interactive sizes in touch mode.</summary>
    TouchScale: Single;
    /// <summary>Body height (content + caption + paddings) of the classic layout.</summary>
    function BodyHeight: Single;
  end;

  TFmrTheme = class;
  TFmrThemeBuilder = reference to procedure(const ATheme: TFmrTheme; const AAccent: TAlphaColor);

  /// <summary>Tokens, metrics and style of one theme.</summary>
  TFmrTheme = class
  private
    FName: string;
    FDisplayName: string;
    FAccent: TAlphaColor;
    FFills: array [TFmrToken] of TFmrFill;
    FStyle: TFmrThemeStyle;
    FMetrics: TFmrThemeMetrics;
    FOverridden: set of TFmrToken;
    class var FRegistry: TList<TPair<string, TFmrThemeBuilder>>;
    class var FDisplayNames: TDictionary<string, string>;
    class var FDefaultAccents: TDictionary<string, TAlphaColor>;
    function GetFill(const AToken: TFmrToken): TFmrFill; inline;
    procedure SetFill(const AToken: TFmrToken; const AValue: TFmrFill);
    function GetColor(const AToken: TFmrToken): TAlphaColor; inline;
    procedure SetColor(const AToken: TFmrToken; const AValue: TAlphaColor);
  public
    class constructor Create;
    class destructor Destroy;
    constructor Create(const AName: string = '');
    procedure Assign(const ASource: TFmrTheme);
    function Clone: TFmrTheme;
    /// <summary>Replaces tokens by resources of a style (TStyleBook.Style or TStyleManager.ActiveStyle): a resource
    /// whose StyleName is TokenStyleName(Token) — TColorObject or TBrushObject; 'fmr_font' — TFontObject. Returns the
    /// number of tokens replaced.</summary>
    function ApplyStyleOverrides(const AStyleRoot: TFmxObject): Integer;
    /// <summary>Adds one TBrushObject per token (and a TFontObject) to AStyleRoot, so a StyleBook can start from a
    /// built-in theme.</summary>
    procedure ExportToStyle(const AStyleRoot: TFmxObject);
    procedure AssignFont(const AFont: TFont; const ASize: Single = 0);
    function IsOverridden(const AToken: TFmrToken): Boolean;

    property Name: string read FName write FName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Accent: TAlphaColor read FAccent write FAccent;
    property Fills[const AToken: TFmrToken]: TFmrFill read GetFill write SetFill; default;
    property Colors[const AToken: TFmrToken]: TAlphaColor read GetColor write SetColor;
    property Style: TFmrThemeStyle read FStyle write FStyle;
    property Metrics: TFmrThemeMetrics read FMetrics write FMetrics;

    { registry }
    /// <summary>Registers a theme by name. ADefaultAccent is used when the ribbon does not set an accent.</summary>
    class procedure RegisterTheme(const AName, ADisplayName: string; const ADefaultAccent: TAlphaColor;
      const ABuilder: TFmrThemeBuilder);
    class function ThemeNames: TArray<string>;
    class function ThemeDisplayName(const AName: string): string;
    class function ThemeExists(const AName: string): Boolean;
    class function DefaultAccent(const AName: string): TAlphaColor;
    /// <summary>Builds a registered theme; AAccent = 0 takes the theme's default accent. Unknown names give the
    /// default theme. The caller owns the result.</summary>
    class function CreateTheme(const AName: string; const AAccent: TAlphaColor = 0): TFmrTheme;
    class function TokenStyleName(const AToken: TFmrToken): string;
    class function TokenFromStyleName(const AStyleName: string; out AToken: TFmrToken): Boolean;
  end;

  /// <summary>Implemented by a control that owns a theme (the ribbon) so companion controls (backstage view, status
  /// bar, popups, mini toolbar) paint with the same theme. The provider sends TFmrThemeChangedMessage when its theme
  /// changes; the returned object stays valid until then.</summary>
  IFmrThemeProvider = interface
    ['{5B0E9C2D-7A13-4F6E-9D48-3C1A2B7E6F10}']
    function GetFmrTheme: TFmrTheme;
  end;

  /// <summary>Sent through TMessageManager.DefaultManager by a theme provider after its theme changed.</summary>
  TFmrThemeChangedMessage = class(System.Messaging.TMessage)
  private
    FProvider: TObject;
  public
    constructor Create(const AProvider: TObject);
    property Provider: TObject read FProvider;
  end;

const
  FmrDefaultThemeName = 'Office365White';
  FmrFontStyleName = 'fmr_font';

  { well-known accent colors (Office applications) }
  FmrAccentWord = TAlphaColor($FF2B579A);
  FmrAccentExcel = TAlphaColor($FF217346);
  FmrAccentPowerPoint = TAlphaColor($FFB7472A);
  FmrAccentOutlook = TAlphaColor($FF0072C6);
  FmrAccentOneNote = TAlphaColor($FF80397B);
  FmrAccentAccess = TAlphaColor($FFA4373A);
  FmrAccentFluent = TAlphaColor($FF0067C0);

{ color helpers }

/// <summary>Mixes A and B: T = 0 gives A, T = 1 gives B (alpha too).</summary>
function FmrBlend(const A, B: TAlphaColor; const T: Single): TAlphaColor;
function FmrLighten(const AColor: TAlphaColor; const AAmount: Single): TAlphaColor;
function FmrDarken(const AColor: TAlphaColor; const AAmount: Single): TAlphaColor;
function FmrWithAlpha(const AColor: TAlphaColor; const AAlpha: Single): TAlphaColor;
/// <summary>Relative luminance 0..1 (sRGB, WCAG).</summary>
function FmrLuminance(const AColor: TAlphaColor): Single;
/// <summary>Black or white, whichever reads better on ABackground.</summary>
function FmrContrastText(const ABackground: TAlphaColor): TAlphaColor;

implementation

uses
  System.Math, System.TypInfo, System.Character;

{ color helpers }

function FmrBlend(const A, B: TAlphaColor; const T: Single): TAlphaColor;
var
  CA, CB, R: TAlphaColorRec;
  K: Single;
begin
  K := EnsureRange(T, 0, 1);
  CA := TAlphaColorRec(A);
  CB := TAlphaColorRec(B);
  R.A := Round(CA.A + (CB.A - CA.A) * K);
  R.R := Round(CA.R + (CB.R - CA.R) * K);
  R.G := Round(CA.G + (CB.G - CA.G) * K);
  R.B := Round(CA.B + (CB.B - CA.B) * K);
  Result := TAlphaColor(R);
end;

function FmrLighten(const AColor: TAlphaColor; const AAmount: Single): TAlphaColor;
begin
  Result := FmrBlend(AColor, (AColor and $FF000000) or $00FFFFFF, AAmount);
end;

function FmrDarken(const AColor: TAlphaColor; const AAmount: Single): TAlphaColor;
begin
  Result := FmrBlend(AColor, AColor and $FF000000, AAmount);
end;

function FmrWithAlpha(const AColor: TAlphaColor; const AAlpha: Single): TAlphaColor;
begin
  Result := (AColor and $00FFFFFF) or (Cardinal(Round(EnsureRange(AAlpha, 0, 1) * 255)) shl 24);
end;

function FmrLuminance(const AColor: TAlphaColor): Single;

  function Channel(const V: Byte): Single;
  var
    C: Single;
  begin
    C := V / 255;
    if C <= 0.03928 then
      Result := C / 12.92
    else
      Result := Power((C + 0.055) / 1.055, 2.4);
  end;

var
  C: TAlphaColorRec;
begin
  C := TAlphaColorRec(AColor);
  Result := 0.2126 * Channel(C.R) + 0.7152 * Channel(C.G) + 0.0722 * Channel(C.B);
end;

function FmrContrastText(const ABackground: TAlphaColor): TAlphaColor;
begin
  // Contrast against white vs black, WCAG formula: (L1 + 0.05) / (L2 + 0.05)
  if (1.05 / (FmrLuminance(ABackground) + 0.05)) >= ((FmrLuminance(ABackground) + 0.05) / 0.05) then
    Result := TAlphaColors.White
  else
    Result := TAlphaColor($FF1F1F1F);
end;

{ TFmrThemeChangedMessage }

constructor TFmrThemeChangedMessage.Create(const AProvider: TObject);
begin
  inherited Create;
  FProvider := AProvider;
end;

{ TFmrFill }

class function TFmrFill.Solid(const AColor: TAlphaColor): TFmrFill;
begin
  Result.Kind := TFmrFillKind.Solid;
  Result.Color := AColor;
  Result.Stops := nil;
end;

class function TFmrFill.Vertical(const AColors: array of TAlphaColor; const AOffsets: array of Single): TFmrFill;
var
  I: Integer;
begin
  if Length(AColors) = 0 then
    Exit(None);
  if Length(AColors) = 1 then
    Exit(Solid(AColors[0]));
  Result.Kind := TFmrFillKind.Vertical;
  SetLength(Result.Stops, Length(AColors));
  for I := 0 to High(AColors) do
  begin
    Result.Stops[I].Color := AColors[I];
    if I <= High(AOffsets) then
      Result.Stops[I].Offset := AOffsets[I]
    else
      Result.Stops[I].Offset := I / High(AColors);
  end;
  Result.Color := Result.MainColor;
end;

class function TFmrFill.Glass(const ATop1, ATop2, ABottom1, ABottom2: TAlphaColor): TFmrFill;
begin
  Result := Vertical([ATop1, ATop2, ABottom1, ABottom2], [0, 0.4999, 0.5, 1]);
end;

class function TFmrFill.None: TFmrFill;
begin
  Result := Solid(TAlphaColors.Null);
end;

function TFmrFill.IsVisible: Boolean;
var
  S: TFmrGradientStop;
begin
  if Kind = TFmrFillKind.Solid then
    Exit(TAlphaColorRec(Color).A > 0);
  for S in Stops do
    if TAlphaColorRec(S.Color).A > 0 then
      Exit(True);
  Result := False;
end;

procedure TFmrFill.ApplyTo(const ABrush: TBrush);
var
  I: Integer;
  P: TGradientPoint;
begin
  if Kind = TFmrFillKind.Solid then
  begin
    ABrush.Kind := TBrushKind.Solid;
    ABrush.Color := Color;
    Exit;
  end;
  ABrush.Kind := TBrushKind.Gradient;
  ABrush.Gradient.Style := TGradientStyle.Linear;
  ABrush.Gradient.StartPosition.Point := TPointF.Create(0, 0);
  ABrush.Gradient.StopPosition.Point := TPointF.Create(0, 1);
  ABrush.Gradient.Points.BeginUpdate;
  try
    ABrush.Gradient.Points.Clear;
    for I := 0 to High(Stops) do
    begin
      P := TGradientPoint(ABrush.Gradient.Points.Add);
      P.Color := Stops[I].Color;
      P.Offset := Stops[I].Offset;
    end;
  finally
    ABrush.Gradient.Points.EndUpdate;
  end;
end;

function TFmrFill.MainColor: TAlphaColor;
begin
  if (Kind = TFmrFillKind.Solid) or (Length(Stops) = 0) then
    Result := Color
  else
    Result := FmrBlend(Stops[0].Color, Stops[High(Stops)].Color, 0.5);
end;

{ TFmrThemeMetrics }

function TFmrThemeMetrics.BodyHeight: Single;
begin
  Result := BodyPaddingV * 2 + GroupPaddingTop + ContentHeight + GroupCaptionHeight;
end;

{ TFmrTheme }

class constructor TFmrTheme.Create;
begin
  FRegistry := TList<TPair<string, TFmrThemeBuilder>>.Create;
  FDisplayNames := TDictionary<string, string>.Create;
  FDefaultAccents := TDictionary<string, TAlphaColor>.Create;
end;

class destructor TFmrTheme.Destroy;
begin
  FRegistry.Free;
  FDisplayNames.Free;
  FDefaultAccents.Free;
end;

constructor TFmrTheme.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FDisplayName := AName;
  FAccent := FmrAccentWord;
end;

procedure TFmrTheme.Assign(const ASource: TFmrTheme);
var
  T: TFmrToken;
begin
  FName := ASource.FName;
  FDisplayName := ASource.FDisplayName;
  FAccent := ASource.FAccent;
  for T := Low(TFmrToken) to High(TFmrToken) do
    FFills[T] := ASource.FFills[T];
  FStyle := ASource.FStyle;
  FMetrics := ASource.FMetrics;
  FOverridden := ASource.FOverridden;
end;

function TFmrTheme.Clone: TFmrTheme;
begin
  Result := TFmrTheme.Create;
  Result.Assign(Self);
end;

function TFmrTheme.GetFill(const AToken: TFmrToken): TFmrFill;
begin
  Result := FFills[AToken];
end;

procedure TFmrTheme.SetFill(const AToken: TFmrToken; const AValue: TFmrFill);
begin
  FFills[AToken] := AValue;
end;

function TFmrTheme.GetColor(const AToken: TFmrToken): TAlphaColor;
begin
  Result := FFills[AToken].MainColor;
end;

procedure TFmrTheme.SetColor(const AToken: TFmrToken; const AValue: TAlphaColor);
begin
  FFills[AToken] := TFmrFill.Solid(AValue);
end;

function TFmrTheme.IsOverridden(const AToken: TFmrToken): Boolean;
begin
  Result := AToken in FOverridden;
end;

class function TFmrTheme.TokenStyleName(const AToken: TFmrToken): string;
var
  S: string;
  I: Integer;
begin
  // CaptionButtonHotFill -> fmr_caption_button_hot_fill
  S := GetEnumName(TypeInfo(TFmrToken), Ord(AToken));
  Result := 'fmr';
  for I := 1 to Length(S) do
  begin
    if S[I].IsUpper and ((I = 1) or not S[I - 1].IsUpper or ((I < Length(S)) and S[I + 1].IsLower)) then
      Result := Result + '_';
    Result := Result + S[I].ToLower;
  end;
end;

class function TFmrTheme.TokenFromStyleName(const AStyleName: string; out AToken: TFmrToken): Boolean;
var
  T: TFmrToken;
begin
  for T := Low(TFmrToken) to High(TFmrToken) do
    if SameText(TokenStyleName(T), AStyleName) then
    begin
      AToken := T;
      Exit(True);
    end;
  Result := False;
end;

function TFmrTheme.ApplyStyleOverrides(const AStyleRoot: TFmxObject): Integer;

  function FillFromBrush(const ABrush: TBrush; out AFill: TFmrFill): Boolean;
  var
    I: Integer;
    Colors: TArray<TAlphaColor>;
    Offsets: TArray<Single>;
  begin
    case ABrush.Kind of
      TBrushKind.None:
        AFill := TFmrFill.None;
      TBrushKind.Solid:
        AFill := TFmrFill.Solid(ABrush.Color);
      TBrushKind.Gradient:
        begin
          SetLength(Colors, ABrush.Gradient.Points.Count);
          SetLength(Offsets, ABrush.Gradient.Points.Count);
          for I := 0 to ABrush.Gradient.Points.Count - 1 do
          begin
            Colors[I] := ABrush.Gradient.Points[I].Color;
            Offsets[I] := ABrush.Gradient.Points[I].Offset;
          end;
          AFill := TFmrFill.Vertical(Colors, Offsets);
        end;
    else
      Exit(False);
    end;
    Result := True;
  end;

var
  T: TFmrToken;
  Res: TFmxObject;
  Fill: TFmrFill;
begin
  Result := 0;
  if AStyleRoot = nil then
    Exit;
  for T := Low(TFmrToken) to High(TFmrToken) do
  begin
    Res := AStyleRoot.FindStyleResource(TokenStyleName(T));
    if Res is TColorObject then
    begin
      FFills[T] := TFmrFill.Solid(TColorObject(Res).Color);
      Include(FOverridden, T);
      Inc(Result);
    end
    else if (Res is TBrushObject) and FillFromBrush(TBrushObject(Res).Brush, Fill) then
    begin
      FFills[T] := Fill;
      Include(FOverridden, T);
      Inc(Result);
    end;
  end;
  Res := AStyleRoot.FindStyleResource(FmrFontStyleName);
  if Res is TFontObject then
  begin
    FMetrics.FontFamily := TFontObject(Res).Font.Family;
    if TFontObject(Res).Font.Size > 0 then
      FMetrics.FontSize := TFontObject(Res).Font.Size;
    Inc(Result);
  end;
end;

procedure TFmrTheme.ExportToStyle(const AStyleRoot: TFmxObject);
var
  T: TFmrToken;
  B: TBrushObject;
  F: TFontObject;
begin
  for T := Low(TFmrToken) to High(TFmrToken) do
  begin
    B := TBrushObject.Create(AStyleRoot);
    B.StyleName := TokenStyleName(T);
    FFills[T].ApplyTo(B.Brush);
    B.Parent := AStyleRoot;
  end;
  F := TFontObject.Create(AStyleRoot);
  F.StyleName := FmrFontStyleName;
  F.Font.Family := FMetrics.FontFamily;
  F.Font.Size := FMetrics.FontSize;
  F.Parent := AStyleRoot;
end;

procedure TFmrTheme.AssignFont(const AFont: TFont; const ASize: Single);
begin
  AFont.Family := FMetrics.FontFamily;
  if ASize > 0 then
    AFont.Size := ASize
  else
    AFont.Size := FMetrics.FontSize;
end;

class procedure TFmrTheme.RegisterTheme(const AName, ADisplayName: string; const ADefaultAccent: TAlphaColor;
  const ABuilder: TFmrThemeBuilder);
var
  I: Integer;
begin
  for I := 0 to FRegistry.Count - 1 do
    if SameText(FRegistry[I].Key, AName) then
    begin
      FRegistry[I] := TPair<string, TFmrThemeBuilder>.Create(AName, ABuilder);
      FDisplayNames.AddOrSetValue(AName.ToLower, ADisplayName);
      FDefaultAccents.AddOrSetValue(AName.ToLower, ADefaultAccent);
      Exit;
    end;
  FRegistry.Add(TPair<string, TFmrThemeBuilder>.Create(AName, ABuilder));
  FDisplayNames.AddOrSetValue(AName.ToLower, ADisplayName);
  FDefaultAccents.AddOrSetValue(AName.ToLower, ADefaultAccent);
end;

class function TFmrTheme.ThemeNames: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, FRegistry.Count);
  for I := 0 to FRegistry.Count - 1 do
    Result[I] := FRegistry[I].Key;
end;

class function TFmrTheme.ThemeDisplayName(const AName: string): string;
begin
  if not FDisplayNames.TryGetValue(AName.ToLower, Result) then
    Result := AName;
end;

class function TFmrTheme.ThemeExists(const AName: string): Boolean;
var
  P: TPair<string, TFmrThemeBuilder>;
begin
  for P in FRegistry do
    if SameText(P.Key, AName) then
      Exit(True);
  Result := False;
end;

class function TFmrTheme.DefaultAccent(const AName: string): TAlphaColor;
begin
  if not FDefaultAccents.TryGetValue(AName.ToLower, Result) then
    Result := FmrAccentWord;
end;

class function TFmrTheme.CreateTheme(const AName: string; const AAccent: TAlphaColor): TFmrTheme;
var
  P: TPair<string, TFmrThemeBuilder>;
  Builder: TFmrThemeBuilder;
  Name: string;
  Accent: TAlphaColor;
begin
  Builder := nil;
  Name := AName;
  for P in FRegistry do
    if SameText(P.Key, AName) then
    begin
      Builder := P.Value;
      Name := P.Key;
      Break;
    end;
  if not Assigned(Builder) then
    for P in FRegistry do
      if SameText(P.Key, FmrDefaultThemeName) then
      begin
        Builder := P.Value;
        Name := P.Key;
        Break;
      end;
  if not Assigned(Builder) and (FRegistry.Count > 0) then
  begin
    Builder := FRegistry[0].Value;
    Name := FRegistry[0].Key;
  end;
  Accent := AAccent;
  if Accent = 0 then
    Accent := DefaultAccent(Name);
  Result := TFmrTheme.Create(Name);
  try
    Result.FDisplayName := ThemeDisplayName(Name);
    Result.FAccent := Accent;
    if Assigned(Builder) then
      Builder(Result, Accent);
  except
    Result.Free;
    raise;
  end;
end;

end.
