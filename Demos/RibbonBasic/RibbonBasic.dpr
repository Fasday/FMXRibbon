program RibbonBasic;

// FMR Ribbon demo: a document-editor style ribbon built in code.
// Command line: /theme=<name> /frame=fullnc|dwm|ncstrip|none /minimized /simplified /width=N /height=N /qatbelow
//               /tabletools /keytips /touch /nosearch /tab=N /backstage /appmenu
//               /open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial|fontname
// Linux64 (FMXWayland, Docs\LINUX.md): .\build.ps1 -Project Demos\RibbonBasic\RibbonBasic.dpr -Platform Linux64;
//               /waylandframe=preview: a stand-in IFMXWaylandWindowFrame (RibbonBasicWayland) to preview the
//               integrated title bar (run with FMXWAYLAND_CSD=0)
// With FastCanvas on Linux (Vulkan): .\build.ps1 -Project Demos\RibbonBasic\RibbonBasic.dpr -Platform Linux64
//   -Define FMR_FASTCANVAS -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\pasvulkan\src

uses
  System.StartUpCopy,
  FMX.Forms,
  {$IFDEF FMR_FASTCANVAS}
  FastCanvas.Device,
  FastCanvas.Canvas,
  {$ENDIF}
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
  {$IFDEF FMR_FASTCANVAS}
  // Linux: on Vulkan, presenting to the windows' wl_surfaces itself (FastCanvasBackend is ignored there).
  InstallFastCanvas;
  {$ENDIF}
  {$IFDEF LINUX}
  {$IFNDEF FMR_FASTCANVAS}
  // Without FastCanvas FMXWayland draws with FMX's Skia canvas.
  GlobalUseSkia := True;
  {$ENDIF}
  RegisterWaylandFramePreview;
  {$ENDIF}
  Application.Initialize;
  Application.CreateForm(TRibbonBasicForm, RibbonBasicForm);
  Application.Run;
end.
