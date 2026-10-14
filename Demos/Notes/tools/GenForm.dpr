program GenForm;

// Writes Demos\Notes\NotesMain.fmx: builds the main form of FMR Notes in code (NotesBuild.pas) on an
// instance of the real form class (created with CreateNew, so no resource is read) and saves it with
// TStream.WriteComponent + ObjectBinaryToText, which is what the IDE does when it saves a designed form.
//
// Build:  .\build.ps1 -Project Demos\Notes\tools\GenForm.dpr -Define NOTES_GEN -SearchPath Demos\Notes
// Run:    bin\Win64\Debug\GenForm.exe Demos\Notes\NotesMain.fmx
//         GenForm.exe <file> /show   also shows the generated form (FormCreate is called by hand), to compare it
//                                    with the form loaded from the .fmx by Notes.exe

uses
  System.StartUpCopy,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  FMX.Forms,
  NotesData,
  NotesLang,
  NotesMain,
  NotesBuild in 'NotesBuild.pas';

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
  Form: TNotesForm;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  FileName := ParamStr(1);
  if (FileName = '') or FileName.StartsWith('/') then
    FileName := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\..\Demos\Notes\NotesMain.fmx');
  Show := FindCmdLineSwitch('show');
  Application.Initialize;
  try
    Form := TNotesForm.CreateNew(Application);
    BuildNotesForm(Form);
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
