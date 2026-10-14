{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Font families of Linux for TFmrFontNameItem          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Fonts.Linux;

/// Font families of Linux from fontconfig — the library Skia's font manager uses on Linux (libsk4d.so links
/// libfontconfig.so.1, so it is always there when the Skia canvas works). Delphi's System.Skia wraps no font manager
/// enumeration and sk4d exports none, so the families are listed with FcFontList, loaded at run time (no link-time
/// dependency). Sets FMR.Ribbon.Fonts.FmrFontFamilyLister (theme fonts, icon font fallback) and
/// TFmrFontNameItem.FontListProvider (without the private icon font). The unit compiles to nothing on other platforms.

interface

implementation

{$IFDEF LINUX}
uses
  System.SysUtils, System.Classes, FMR.Ribbon.Fonts, FMR.Bars.Items;

type
  TFcFontSet = record
    nfont: Integer;
    sfont: Integer;
    fonts: PPointer;
  end;
  PFcFontSet = ^TFcFontSet;

const
  FcResultMatch = 0;
  FC_FAMILY: MarshaledAString = 'family';

var
  GLib: HMODULE = 0;
  GLoadTried: Boolean = False;
  FcPatternCreate: function: Pointer; cdecl;
  FcPatternDestroy: procedure(P: Pointer); cdecl;
  FcObjectSetCreate: function: Pointer; cdecl;
  FcObjectSetAdd: function(OS: Pointer; const AObject: MarshaledAString): Integer; cdecl;
  FcObjectSetDestroy: procedure(OS: Pointer); cdecl;
  FcFontList: function(Config: Pointer; P: Pointer; OS: Pointer): PFcFontSet; cdecl;
  FcFontSetDestroy: procedure(S: PFcFontSet); cdecl;
  FcPatternGetString: function(P: Pointer; const AObject: MarshaledAString; N: Integer;
    out S: MarshaledAString): Integer; cdecl;

function LoadFontconfig: Boolean;

  function Bind(const AName: string): Pointer;
  begin
    Result := GetProcAddress(GLib, PChar(AName));
    if Result = nil then
      Abort;
  end;

begin
  if not GLoadTried then
  begin
    GLoadTried := True;
    GLib := SafeLoadLibrary('libfontconfig.so.1');
    if GLib <> 0 then
      try
        @FcPatternCreate := Bind('FcPatternCreate');
        @FcPatternDestroy := Bind('FcPatternDestroy');
        @FcObjectSetCreate := Bind('FcObjectSetCreate');
        @FcObjectSetAdd := Bind('FcObjectSetAdd');
        @FcObjectSetDestroy := Bind('FcObjectSetDestroy');
        @FcFontList := Bind('FcFontList');
        @FcFontSetDestroy := Bind('FcFontSetDestroy');
        @FcPatternGetString := Bind('FcPatternGetString');
      except
        on EAbort do
        begin
          FreeLibrary(GLib);
          GLib := 0;
        end;
      end;
  end;
  Result := GLib <> 0;
end;

procedure LinuxFontList(AList: TStrings);
var
  Pattern, ObjectSet: Pointer;
  FontSet: PFcFontSet;
  I: Integer;
  Font: PPointer;
  Name: MarshaledAString;
begin
  if not LoadFontconfig then
    Exit;
  Pattern := FcPatternCreate;
  ObjectSet := FcObjectSetCreate;
  try
    FcObjectSetAdd(ObjectSet, FC_FAMILY);
    // nil config: the current one (FcInit on first use).
    FontSet := FcFontList(nil, Pattern, ObjectSet);
    if FontSet <> nil then
      try
        Font := FontSet.fonts;
        for I := 0 to FontSet.nfont - 1 do
        begin
          // Index 0 is the family's default (usually English) name; localized names follow.
          if FcPatternGetString(Font^, FC_FAMILY, 0, Name) = FcResultMatch then
            AList.Add(UTF8ToString(Name));
          Inc(Font);
        end;
      finally
        FcFontSetDestroy(FontSet);
      end;
  finally
    FcObjectSetDestroy(ObjectSet);
    FcPatternDestroy(Pattern);
  end;
end;

initialization
  if not Assigned(FmrFontFamilyLister) then
    FmrFontFamilyLister :=
      procedure(AList: TStrings)
      begin
        LinuxFontList(AList);
      end;
  if not Assigned(TFmrFontNameItem.FontListProvider) then
    TFmrFontNameItem.FontListProvider :=
      procedure(AList: TStrings)
      var
        S: string;
      begin
        for S in FmrTextFontFamilies do
          AList.Add(S);
      end;

finalization
  if GLib <> 0 then
    FreeLibrary(GLib);
{$ENDIF}

end.
