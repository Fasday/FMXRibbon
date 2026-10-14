program DesignPreview;

/// Standalone preview of the VCL editor windows of the design package (no IDE needed). See DesignPreviewMain.
/// Build: .\build.ps1 -Project tools\DesignPreview\DesignPreview.dpr

{$R WinApp.res}

uses
  Vcl.Forms,
  DesignPreviewMain in 'DesignPreviewMain.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TPreviewForm, PreviewForm);
  Application.Run;
end.
