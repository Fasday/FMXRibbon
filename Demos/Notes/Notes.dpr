program Notes;

// FMR Notes: a notes editor, the showcase application of FMR Ribbon. The main form is a real form streamed from
// NotesMain.fmx (written by tools\GenForm, see NotesMain.pas for the command line).
// Build:            .\build.ps1 -Project Demos\Notes\Notes.dpr
// With FastCanvas:  .\build.ps1 -Project Demos\Notes\Notes.dpr -Define FMR_FASTCANVAS
//   -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src

uses
  System.StartUpCopy,
  FMX.Forms,
{$IFDEF FMR_FASTCANVAS}
  FastCanvas.Device,
  FastCanvas.Canvas,
{$ENDIF}
  NotesData in 'NotesData.pas',
  NotesLang in 'NotesLang.pas',
  NotesMain in 'NotesMain.pas' {NotesForm};

{$R WinApp.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
{$IFDEF FMR_FASTCANVAS}
  InstallFastCanvas;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TNotesForm, NotesForm);
  Application.Run;
end.
