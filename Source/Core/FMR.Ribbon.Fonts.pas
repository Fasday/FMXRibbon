{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Font families of the platform, private fonts         }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Fonts;

/// Platform-neutral font helpers of the library:
/// - which families are installed: FmrFontFamilies / FmrFontFamilyAvailable, filled by the platform unit
///   (FMR.Ribbon.Fonts.Win: EnumFontFamiliesEx; FMR.Ribbon.Fonts.Linux: fontconfig) and by FmrRegisterFont;
/// - FmrResolveFontFamily('Segoe UI, Noto Sans, DejaVu Sans'): the first installed family of a list, so a theme can
///   name the Windows font and still look right on Linux (FmrUIFontFamily: the UI font of the themes);
/// - FmrRegisterFont: a private font file or stream for the Skia canvas (FMX.Skia's TSkDefaultProviders; the canvas
///   of FMX on Linux, optional on Windows);
/// - FmrEnsureIconFont: registers "FMR Fluent Icons" (Assets\Fonts\FmrFluentIcons.ttf, icons of Microsoft's Fluent UI
///   System Icons, MIT), which TFmrImageSource uses instead of Segoe Fluent Icons where that font is missing.
/// Everything runs on the main thread.

interface

uses
  System.SysUtils, System.Classes;

const
  /// <summary>Family of Assets\Fonts\FmrFluentIcons.ttf.</summary>
  FmrIconFontFamily = 'FMR Fluent Icons';
  FmrIconFontFileName = 'FmrFluentIcons.ttf';
  /// <summary>Environment variable with the full path of the icon font file (overrides the search next to the
  /// program).</summary>
  FmrIconFontEnvVar = 'FMR_ICON_FONT';

type
  /// <summary>Adds the installed font families to AList (duplicates allowed).</summary>
  TFmrFontFamilyLister = reference to procedure(AList: TStrings);

var
  /// <summary>Lists the installed families; set by the platform unit (FMR.Ribbon.Fonts.Win, FMR.Ribbon.Fonts.Linux).
  /// nil: availability is unknown and every family counts as available.</summary>
  FmrFontFamilyLister: TFmrFontFamilyLister = nil;
  /// <summary>UI font of the themes: the first installed family of this list (FmrUIFontFamily). Change it before the
  /// first theme is built.</summary>
  FmrUIFontCandidates: string = 'Segoe UI, Noto Sans, Cantarell, Ubuntu, DejaVu Sans, Liberation Sans, Arial';
  /// <summary>Linux: families that FMX and Windows programs ask for (FMX's default TFont family 'Tahoma', 'Ubuntu' of
  /// FMX's Linux style, 'Segoe UI'). Skia's fontconfig font manager matches the family of every text layout again
  /// (no cache; opening a list of 200 fonts took 30-60 s). An installed one is registered with Skia
  /// (FmrPreloadFontFamily); for a missing one the UI font (FmrUIFontFamily) is registered under its name —
  /// fontconfig would substitute a sans font anyway, the alias answers at once and the text looks like the ribbon.
  /// Empty: none. Set before the first theme is built.</summary>
  FmrPreloadFamilies: string = 'Tahoma, Ubuntu, Segoe UI';

/// <summary>Installed and registered font families, sorted (cached; FmrFontFamiliesChanged drops the cache).</summary>
function FmrFontFamilies: TArray<string>;
/// <summary>Installed and registered families without the private icon font (for font name pickers).</summary>
function FmrTextFontFamilies: TArray<string>;
procedure FmrFontFamiliesChanged;
/// <summary>Incremented by every change of the known families (for caches of availability answers).</summary>
function FmrFontFamiliesGeneration: Integer;
/// <summary>True when the families of the platform are known (a lister is installed).</summary>
function FmrFontFamiliesKnown: Boolean;
/// <summary>The family is installed or registered (case-insensitive). True for every non-empty family when the
/// families are not known.</summary>
function FmrFontFamilyAvailable(const AFamily: string): Boolean;
/// <summary>The first available family of a comma-separated list ('Segoe UI, Noto Sans'); the first one when none is
/// available or the families are not known. A single name is returned as is.</summary>
function FmrResolveFontFamily(const AFamilies: string): string;
/// <summary>UI font of the themes: 'Segoe UI' on Windows, elsewhere the first available of FmrUIFontCandidates.
/// </summary>
function FmrUIFontFamily: string;
/// <summary>Registers a private font for the Skia canvas. Returns its family name ('' when the file cannot be read or
/// Skia is not linked: FMR_NO_SKIA).</summary>
function FmrRegisterFont(const AFileName: string): string; overload;
function FmrRegisterFont(const AStream: TStream): string; overload;
/// <summary>Registers the regular, bold, italic and bold italic typefaces of an installed family with the Skia
/// canvas's typeface provider (TSkDefaultProviders). On Linux FMX's Skia text layout asks fontconfig for the family
/// of every paragraph (a fontconfig match of every installed font, a few ms each, without a cache); a registered
/// family is found at once. Called for the theme font (FmrUIFontFamily) on Linux. Returns False when the family is
/// not installed or Skia is not linked.</summary>
function FmrPreloadFontFamily(const AFamily: string): Boolean;
/// <summary>Registers the typefaces of the installed family AFamily with Skia under the family name AAlias too (a
/// family the system does not have). Returns False when AFamily is not installed or Skia is not linked.</summary>
function FmrAliasFontFamily(const AAlias, AFamily: string): Boolean;
/// <summary>Makes FmrIconFontFamily available: True when it is installed or registered; otherwise registers the
/// first file found: $FMR_ICON_FONT, then FmrFluentIcons.ttf in 'fonts' next to the program, next to the program,
/// in '../share/fmr-ribbon/fonts'. Searches once.</summary>
function FmrEnsureIconFont: Boolean;
/// <summary>Where FmrEnsureIconFont looks for the icon font file, in order.</summary>
function FmrIconFontSearchPaths: TArray<string>;

implementation

uses
  System.IOUtils, System.Generics.Collections, System.Generics.Defaults
  {$IFNDEF FMR_NO_SKIA}, System.Skia, FMX.Skia{$ENDIF}
  {$IFDEF MSWINDOWS}, FMR.Ribbon.Fonts.Win{$ENDIF}
  {$IFDEF LINUX}, FMR.Ribbon.Fonts.Linux{$ENDIF};

var
  GFamilies: TArray<string>;
  GFamilySet: TDictionary<string, string>;
  GRegistered: TList<string>;
  GLoaded: Boolean;
  GUIFont: string;
  GIconFontTried: Boolean;
  GIconFontOK: Boolean;
  GGeneration: Integer = 1;
  GPreloaded: TList<string>;

{$IFDEF LINUX}
procedure PreloadUIFont(const AFamily: string); forward;
{$ENDIF}

procedure LoadFamilies;
var
  L: TStringList;
  S, Key: string;
begin
  if GLoaded then
    Exit;
  GLoaded := True;
  if GFamilySet = nil then
    GFamilySet := TDictionary<string, string>.Create;
  GFamilySet.Clear;
  L := TStringList.Create;
  try
    L.Sorted := True;
    L.Duplicates := dupIgnore;
    L.CaseSensitive := False;
    if Assigned(FmrFontFamilyLister) then
      try
        FmrFontFamilyLister(L);
      except
        // A broken platform list must not break painting: the families stay unknown.
      end;
    if GRegistered <> nil then
      for S in GRegistered do
        L.Add(S);
    for S in L do
    begin
      Key := S.Trim.ToLower;
      if (Key <> '') and not GFamilySet.ContainsKey(Key) then
        GFamilySet.Add(Key, S.Trim);
    end;
    GFamilies := L.ToStringArray;
  finally
    L.Free;
  end;
end;

function FmrFontFamilies: TArray<string>;
begin
  LoadFamilies;
  Result := GFamilies;
end;

function FmrTextFontFamilies: TArray<string>;
var
  S: string;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    for S in FmrFontFamilies do
      if not SameText(S, FmrIconFontFamily) then
        L.Add(S);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

procedure FmrFontFamiliesChanged;
begin
  GLoaded := False;
  GUIFont := '';
  Inc(GGeneration);
end;

function FmrFontFamiliesGeneration: Integer;
begin
  Result := GGeneration;
end;

function FmrFontFamiliesKnown: Boolean;
begin
  Result := Assigned(FmrFontFamilyLister) or ((GRegistered <> nil) and (GRegistered.Count > 0));
end;

function FmrFontFamilyAvailable(const AFamily: string): Boolean;
begin
  if AFamily.Trim = '' then
    Exit(False);
  LoadFamilies;
  if GFamilySet.ContainsKey(AFamily.Trim.ToLower) then
    Exit(True);
  // Without a platform list only the registered families are known for sure; the others may be installed.
  Result := not Assigned(FmrFontFamilyLister);
end;

function FmrResolveFontFamily(const AFamilies: string): string;
var
  Parts: TArray<string>;
  S: string;
begin
  if not AFamilies.Contains(',') then
    Exit(AFamilies.Trim);
  Parts := AFamilies.Split([',']);
  Result := '';
  for S in Parts do
    if S.Trim <> '' then
    begin
      if Result = '' then
        Result := S.Trim;
      if not Assigned(FmrFontFamilyLister) then
        Exit;
      if FmrFontFamilyAvailable(S) then
        Exit(S.Trim);
    end;
end;

function FmrUIFontFamily: string;
begin
  {$IFDEF MSWINDOWS}
  Result := 'Segoe UI';
  {$ELSE}
  if GUIFont = '' then
  begin
    GUIFont := FmrResolveFontFamily(FmrUIFontCandidates);
    {$IFDEF LINUX}
    PreloadUIFont(GUIFont);
    {$ENDIF}
  end;
  Result := GUIFont;
  {$ENDIF}
end;

function RegisterFamilyTypefaces(const AFamily, AName: string): Boolean;
{$IFNDEF FMR_NO_SKIA}
var
  Styles: array [0..3] of TSkFontStyle;
  Style: TSkFontStyle;
  Typeface: ISkTypeface;
{$ENDIF}
begin
  Result := False;
  {$IFNDEF FMR_NO_SKIA}
  Styles[0] := TSkFontStyle.Normal;
  Styles[1] := TSkFontStyle.Bold;
  Styles[2] := TSkFontStyle.Italic;
  Styles[3] := TSkFontStyle.BoldItalic;
  for Style in Styles do
  begin
    Typeface := TSkTypeface.MakeFromName(AFamily, Style);
    // MakeFromName falls back to another family when this one is missing.
    if (Typeface <> nil) and SameText(Typeface.FamilyName, AFamily) then
    begin
      if SameText(AName, AFamily) then
        TSkDefaultProviders.TypefaceFont.RegisterTypeface(Typeface)
      else
        TSkDefaultProviders.TypefaceFont.RegisterTypeface(Typeface, AName);
      Result := True;
    end;
  end;
  {$ENDIF}
end;

function FmrPreloadFontFamily(const AFamily: string): Boolean;
begin
  if AFamily.Trim = '' then
    Exit(False);
  if (GPreloaded <> nil) and (GPreloaded.IndexOf(AFamily.Trim.ToLower) >= 0) then
    Exit(True);
  Result := RegisterFamilyTypefaces(AFamily.Trim, AFamily.Trim);
  if Result then
  begin
    if GPreloaded = nil then
      GPreloaded := TList<string>.Create;
    GPreloaded.Add(AFamily.Trim.ToLower);
  end;
end;

function FmrAliasFontFamily(const AAlias, AFamily: string): Boolean;
begin
  if (AAlias.Trim = '') or (AFamily.Trim = '') then
    Exit(False);
  if (GPreloaded <> nil) and (GPreloaded.IndexOf(AAlias.Trim.ToLower) >= 0) then
    Exit(True);
  Result := RegisterFamilyTypefaces(AFamily.Trim, AAlias.Trim);
  if Result then
  begin
    if GPreloaded = nil then
      GPreloaded := TList<string>.Create;
    GPreloaded.Add(AAlias.Trim.ToLower);
  end;
end;

{$IFDEF LINUX}
procedure PreloadUIFont(const AFamily: string);
var
  S: string;
begin
  if not FmrPreloadFontFamily(AFamily) then
    Exit;
  // Installed: its own typefaces (fontconfig is slow for every family, not only for missing ones); missing: the UI
  // font under its name.
  for S in FmrPreloadFamilies.Split([',']) do
    if (S.Trim <> '') and Assigned(FmrFontFamilyLister) then
    begin
      if FmrFontFamilyAvailable(S) then
        FmrPreloadFontFamily(S)
      else
        FmrAliasFontFamily(S, AFamily);
    end;
end;
{$ENDIF}

procedure AddRegistered(const AFamily: string);
begin
  if AFamily = '' then
    Exit;
  if GRegistered = nil then
    GRegistered := TList<string>.Create;
  if GRegistered.IndexOf(AFamily) < 0 then
    GRegistered.Add(AFamily);
  FmrFontFamiliesChanged;
end;

function FmrRegisterFont(const AFileName: string): string;
{$IFNDEF FMR_NO_SKIA}
var
  Typeface: ISkTypeface;
{$ENDIF}
begin
  Result := '';
  {$IFNDEF FMR_NO_SKIA}
  if (AFileName = '') or not TFile.Exists(AFileName) then
    Exit;
  Typeface := TSkTypeface.MakeFromFile(AFileName);
  if Typeface = nil then
    Exit;
  TSkDefaultProviders.TypefaceFont.RegisterTypeface(Typeface);
  Result := Typeface.FamilyName;
  AddRegistered(Result);
  {$ENDIF}
end;

function FmrRegisterFont(const AStream: TStream): string;
{$IFNDEF FMR_NO_SKIA}
var
  Typeface: ISkTypeface;
{$ENDIF}
begin
  Result := '';
  {$IFNDEF FMR_NO_SKIA}
  if AStream = nil then
    Exit;
  Typeface := TSkTypeface.MakeFromStream(AStream);
  if Typeface = nil then
    Exit;
  TSkDefaultProviders.TypefaceFont.RegisterTypeface(Typeface);
  Result := Typeface.FamilyName;
  AddRegistered(Result);
  {$ENDIF}
end;

function FmrIconFontSearchPaths: TArray<string>;
var
  Dir, Env: string;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    Env := GetEnvironmentVariable(FmrIconFontEnvVar);
    if Env <> '' then
      L.Add(Env);
    Dir := ExtractFilePath(ParamStr(0));
    L.Add(TPath.Combine(TPath.Combine(Dir, 'fonts'), FmrIconFontFileName));
    L.Add(TPath.Combine(Dir, FmrIconFontFileName));
    L.Add(TPath.Combine(TPath.Combine(TPath.Combine(TPath.Combine(Dir, '..'), 'share'), 'fmr-ribbon'),
      TPath.Combine('fonts', FmrIconFontFileName)));
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function FmrEnsureIconFont: Boolean;
var
  F: string;
begin
  if GIconFontTried then
    Exit(GIconFontOK);
  GIconFontTried := True;
  LoadFamilies;
  if GFamilySet.ContainsKey(FmrIconFontFamily.ToLower) then
    GIconFontOK := True
  else
    for F in FmrIconFontSearchPaths do
      if TFile.Exists(F) and SameText(FmrRegisterFont(F), FmrIconFontFamily) then
      begin
        GIconFontOK := True;
        Break;
      end;
  Result := GIconFontOK;
end;

initialization

finalization
  FreeAndNil(GFamilySet);
  FreeAndNil(GRegistered);
  FreeAndNil(GPreloaded);

end.
