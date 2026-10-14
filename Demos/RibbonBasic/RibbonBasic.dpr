program RibbonBasic;

// FMR Ribbon demo: a Word-like ribbon built in code.
// Command line: /theme=<name> /frame=fullnc|dwm|ncstrip|none /minimized /simplified /width=N /height=N /qatbelow
//               /tabletools /keytips /touch /nosearch /tab=N /backstage /appmenu
//               /open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial|fontname
// Linux64 (FMXWayland, Docs\LINUX.md): .\build.ps1 -Project Demos\RibbonBasic\RibbonBasic.dpr -Platform Linux64;
//               /waylandframe=preview: a stand-in IFMXWaylandWindowFrame (RibbonBasicWayland) to preview the
//               integrated title bar (run with FMXWAYLAND_CSD=0)

uses
  System.StartUpCopy,
  FMX.Forms,
  {$IFDEF LINUX}
  FMX.Types,
  FMX.Skia,
  RibbonBasicWayland in 'RibbonBasicWayland.pas',
  {$ENDIF}
  RibbonBasicMain in 'RibbonBasicMain.pas';

{$IFDEF MSWINDOWS}
{$R WinApp.res}
{$ENDIF}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  {$IFDEF LINUX}
  // FMXWayland draws with FMX's Skia canvas only.
  GlobalUseSkia := True;
  RegisterWaylandFramePreview;
  {$ENDIF}
  Application.Initialize;
  Application.CreateForm(TRibbonBasicForm, RibbonBasicForm);
  Application.Run;
end.
