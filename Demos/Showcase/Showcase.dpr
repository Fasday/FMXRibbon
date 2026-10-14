program Showcase;

// FMR Ribbon feature gallery: the ribbon on top, one page per feature on the left, live controls on every page.
// Command line: /page=N /theme=<name> /accent=RRGGBB /frame=fullnc|dwm|ncstrip /lang=ru /auto (runs the demo action
//               of the page after start) /width=N /height=N
// With FastCanvas:  .\build.ps1 -Project Demos\Showcase\Showcase.dpr -Define FMR_FASTCANVAS
//   -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src

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
{$ENDIF}
  ShowcaseMain in 'ShowcaseMain.pas';

{$IFDEF MSWINDOWS}
{$R WinApp.res}
{$ENDIF}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
{$IFDEF FMR_FASTCANVAS}
  InstallFastCanvas;
{$ENDIF}
{$IFDEF LINUX}
  // FMXWayland (Docs\LINUX.md) draws with FMX's Skia canvas only.
  GlobalUseSkia := True;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TShowcaseForm, ShowcaseForm);
  Application.Run;
end.
