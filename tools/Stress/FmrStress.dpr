program FmrStress;

// Stress and robustness checks of the real TFmrRibbon (see FmrStressMain.pas).
// .\build.ps1 -Project tools\Stress\FmrStress.dpr; bin\Win64\Debug\FmrStress.exe /log=stress.log

uses
  System.StartUpCopy,
  FMX.Forms,
  FmrStressMain in 'FmrStressMain.pas';

{$R WinApp.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
  Application.CreateForm(TStressForm, StressForm);
  Application.Run;
  ExitCode := StressFailures;
end.
