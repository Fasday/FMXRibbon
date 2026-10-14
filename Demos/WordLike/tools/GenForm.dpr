program GenForm;

// Writes Demos\WordLike\WordLikeMain.fmx: builds the main form of FMR Write in code (WordLikeBuild.pas) on an
// instance of the real form class (created with CreateNew, so no resource is read) and saves it with
// TStream.WriteComponent + ObjectBinaryToText, which is what the IDE does when it saves a designed form.
//
// Build:  .\build.ps1 -Project Demos\WordLike\tools\GenForm.dpr -Define WORDLIKE_GEN -SearchPath Demos\WordLike
// Run:    bin\Win64\Debug\GenForm.exe Demos\WordLike\WordLikeMain.fmx
//         GenForm.exe <file> /show   also shows the generated form (FormCreate is called by hand), to compare it
//                                    with the form loaded from the .fmx by WordLike.exe

uses
  System.StartUpCopy,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  FMX.Forms,
  WordLikeData,
  WordLikeLang,
  WordLikeMain,
  WordLikeBuild in 'WordLikeBuild.pas';

{$R WinApp.res}

procedure WriteFormFile(const AForm: TComponent; const AFileName: string);
var
  Bin: TMemoryStream;
  Txt: TStringStream;
begin
  Bin := TMemoryStream.Create;
  Txt := TStringStream.Create('', TEncoding.ASCII);
  try
    Bin.WriteComponent(AForm);
    Bin.Position := 0;
    ObjectBinaryToText(Bin, Txt);
    Txt.SaveToFile(AFileName);
  finally
    Txt.Free;
    Bin.Free;
  end;
end;

var
  FileName: string;
  Show: Boolean;
  Form: TWordLikeForm;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  FileName := ParamStr(1);
  if (FileName = '') or FileName.StartsWith('/') then
    FileName := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\..\Demos\WordLike\WordLikeMain.fmx');
  Show := FindCmdLineSwitch('show');
  Application.Initialize;
  try
    Form := TWordLikeForm.CreateNew(Application);
    BuildWordLikeForm(Form);
    WriteFormFile(Form, FileName);
    if Show then
    begin
      Form.FormCreate(Form);
      Form.Show;
      Application.MainForm := Form;
      Application.Run;
    end
    else
      Form.Free;
  except
    on E: Exception do
    begin
      TFile.WriteAllText(ChangeFileExt(ParamStr(0), '.err'), E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
