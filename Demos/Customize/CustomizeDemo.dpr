program CustomizeDemo;

// FMR Ribbon demo: run-time customization form, display options, auto-hide, simplified switch, right to left,
// themed editors, touch mode and the UI Automation provider.
// Command line: see CustomizeDemoMain.pas.

uses
  System.StartUpCopy,
  FMX.Forms,
  CustomizeDemoMain in 'CustomizeDemoMain.pas';

{$R WinApp.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
  Application.CreateForm(TCustomizeDemoForm, CustomizeDemoForm);
  Application.Run;
end.
