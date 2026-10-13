program NCProof;

// FMR Ribbon frame proof: FMX controls (buttons, TEdit, TComboBox, a tab row) in the real non-client area.
// Command line: /mode=dwm|fullnc|ncstrip  /dark  /backdrop=mica|acrylic|tabbed  /notabs  /maximized
//               /strategy=keepcaption (FullNC experiment: keep WS_CAPTION)
// Build with FastCanvas: .\build.ps1 -Project Demos\NCProof\NCProof.dpr -Define FMR_FASTCANVAS
//   -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src

uses
  System.StartUpCopy,
  FMX.Forms,
{$IFDEF FMR_FASTCANVAS}
  FastCanvas.Device,
  FastCanvas.Canvas,
{$ENDIF}
  NCProofMain in 'NCProofMain.pas';

{$R WinApp.res}

begin
{$IFDEF FMR_FASTCANVAS}
  InstallFastCanvas;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TNCProofForm, NCProofForm);
  Application.Run;
end.
