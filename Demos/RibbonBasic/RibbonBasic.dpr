program RibbonBasic;

// FMR Ribbon demo: a Word-like ribbon built in code.
// Command line: /theme=<name> /frame=fullnc|dwm|ncstrip|none /minimized /simplified /width=N /height=N /qatbelow
//               /tabletools /keytips /touch /nosearch /tab=N

uses
  System.StartUpCopy,
  FMX.Forms,
  RibbonBasicMain in 'RibbonBasicMain.pas';

{$R WinApp.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
  Application.CreateForm(TRibbonBasicForm, RibbonBasicForm);
  Application.Run;
end.
