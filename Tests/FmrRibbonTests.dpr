program FmrRibbonTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  FMR.Ribbon.Types,
  FMR.Ribbon.Strings,
  FMR.Bars.Images,
  FMR.Bars,
  FMR.Bars.Items,
  FMR.Ribbon.Structure,
  FMR.Ribbon.Layout,
  FMR.Ribbon.KeyTips,
  FMR.Ribbon.Persistence,
  FMR.Ribbon.Merge,
  FMR.Tests.Fakes in 'FMR.Tests.Fakes.pas',
  FMR.Tests.Bars in 'FMR.Tests.Bars.pas',
  FMR.Tests.Structure in 'FMR.Tests.Structure.pas',
  FMR.Tests.Layout in 'FMR.Tests.Layout.pas',
  FMR.Tests.Persistence in 'FMR.Tests.Persistence.pas',
  FMR.Tests.Merge in 'FMR.Tests.Merge.pas',
  FMR.Tests.KeyTips in 'FMR.Tests.KeyTips.pas',
  FMR.Tests.Extras in 'FMR.Tests.Extras.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    ExitCode := Results.FailureCount + Results.ErrorCount;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
