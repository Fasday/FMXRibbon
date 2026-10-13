program ExtrasDemo;

// FMR Ribbon companion controls: backstage view (TFmrRibbonBackstageView) and status bar (TFmrStatusBar).
// Command line: /theme=<name> /accent=RRGGBB /backstage /tab=N (0-based) /standalone /noanim /keytips
//               /frame[=fullnc|dwm|ncstrip]
// Build: .\build.ps1 -Project Demos\Extras\ExtrasDemo.dpr [-Platform Win32]

uses
  System.StartUpCopy,
  FMX.Forms,
  ExtrasDemoMain in 'ExtrasDemoMain.pas';

{$R WinApp.res}

begin
  Application.Initialize;
  Application.CreateForm(TExtrasDemoForm, ExtrasDemoForm);
  Application.Run;
end.
