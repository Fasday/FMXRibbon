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
  ShowcaseMain in 'ShowcaseMain.pas';

{$R WinApp.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
{$IFDEF FMR_FASTCANVAS}
  InstallFastCanvas;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TShowcaseForm, ShowcaseForm);
  Application.Run;
end.
