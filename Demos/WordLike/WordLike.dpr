program WordLike;

// FMR Write: a Word-like showcase application of FMR Ribbon. The main form is a real form streamed from
// WordLikeMain.fmx (written by tools\GenForm, see WordLikeMain.pas for the command line).
// Build:            .\build.ps1 -Project Demos\WordLike\WordLike.dpr
// With FastCanvas:  .\build.ps1 -Project Demos\WordLike\WordLike.dpr -Define FMR_FASTCANVAS
//   -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src

uses
  System.StartUpCopy,
  FMX.Forms,
{$IFDEF FMR_FASTCANVAS}
  FastCanvas.Device,
  FastCanvas.Canvas,
{$ENDIF}
  WordLikeData in 'WordLikeData.pas',
  WordLikeLang in 'WordLikeLang.pas',
  WordLikeMain in 'WordLikeMain.pas' {WordLikeForm};

{$R WinApp.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
{$IFDEF FMR_FASTCANVAS}
  InstallFastCanvas;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TWordLikeForm, WordLikeForm);
  Application.Run;
end.
