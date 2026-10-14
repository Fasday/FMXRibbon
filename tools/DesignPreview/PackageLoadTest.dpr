program PackageLoadTest;

/// Loads the FMR Ribbon packages like the IDE does (LoadPackage runs the initialization of every unit), then looks
/// for the registered classes and the Register procedure of the design package. Built with runtime packages:
///   dcc64 -LUrtl -U<dcp folder> PackageLoadTest.dpr   (see Docs\DESIGNTIME.md)
/// Run with bin64 (or bin for Win32) and bin\packages\<Platform> on the PATH.

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes;

procedure Check(const AName: string; const AOk: Boolean);
begin
  if AOk then
    Writeln('PASS ', AName)
  else
  begin
    Writeln('FAIL ', AName);
    ExitCode := 1;
  end;
end;

var
  Runtime, Design: HMODULE;
  Dir: string;
begin
  try
    Dir := ParamStr(1);
    Runtime := LoadPackage(IncludeTrailingPathDelimiter(Dir) + 'FMRRibbon370.bpl');
    Check('runtime package loaded', Runtime <> 0);
    Check('TFmrRibbon registered', GetClass('TFmrRibbon') <> nil);
    Check('TFmrBarManager registered', GetClass('TFmrBarManager') <> nil);
    Check('TFmrButtonItem registered', GetClass('TFmrButtonItem') <> nil);
    Check('TFmrRibbonTab registered', GetClass('TFmrRibbonTab') <> nil);
    if ParamCount > 1 then
    begin
      Design := LoadPackage(IncludeTrailingPathDelimiter(Dir) + 'dclFMRRibbon370.bpl');
      Check('design package loaded', Design <> 0);
      // Win32 and Win64 packages mangle differently (Borland / Itanium style).
      Check('Register exported', (GetProcAddress(Design, '@Fmr@Ribbon@Reg@Register$qqrv') <> nil) or
        (GetProcAddress(Design, '_ZN3Fmr6Ribbon3Reg8RegisterEv') <> nil));
      UnloadPackage(Design);
      Writeln('design package unloaded');
    end;
    UnloadPackage(Runtime);
    Writeln('runtime package unloaded');
  except
    on E: Exception do
    begin
      Writeln('ERROR ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
