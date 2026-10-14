program TemplateDemo;

/// A real TFmrRibbon built by FMR.Ribbon.Templates (checks the templates visually).
///   TemplateDemo.exe [/template=document|spreadsheet|simple] [/tab=N] [/theme=NAME] [/context]
///   (/template=word and /template=excel, the switches of the first release, still work)
/// Build: .\build.ps1 -Project tools\DesignPreview\TemplateDemo.dpr

{$R WinApp.res}

uses
  System.SysUtils, System.StrUtils, System.Classes, System.UITypes, FMX.Types, FMX.Forms, FMX.Controls,
  FMX.Graphics, FMX.Objects, FMR.Bars, FMR.Ribbon.Structure, FMR.Ribbon, FMR.Ribbon.Templates;

type
  TDemoForm = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

function Param(const AName: string; out AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if StartsText('/' + AName, ParamStr(I)) then
    begin
      AValue := Copy(ParamStr(I), Length(AName) + 3, MaxInt);
      Exit(True);
    end;
  Result := False;
end;

constructor TDemoForm.Create(AOwner: TComponent);
var
  Manager: TFmrBarManager;
  Ribbon: TFmrRibbon;
  T: TFmrRibbonTemplate;
  S: string;
  Doc: TRectangle;
  Tab: Integer;
  Ctx: TArray<TFmrRibbonContextGroup>;
begin
  inherited CreateNew(AOwner);
  Caption := 'FMR Ribbon - template';
  Width := 1500;
  Height := 520;
  Position := TFormPosition.ScreenCenter;
  Manager := TFmrBarManager.Create(Self);
  Manager.Parent := Self;
  Ribbon := TFmrRibbon.Create(Self);
  Ribbon.Parent := Self;
  Ribbon.BarManager := Manager;
  if Param('theme', S) then
    Ribbon.Theme := S;
  T := TFmrRibbonTemplate.Document;
  if Param('template', S) then
    if SameText(S, 'spreadsheet') or SameText(S, 'excel') then
      T := TFmrRibbonTemplate.Spreadsheet
    else if SameText(S, 'simple') then
      T := TFmrRibbonTemplate.Simple;
  FmrApplyRibbonTemplate(Ribbon, T);
  if Param('context', S) then
  begin
    Ctx := TFmrRibbonStructure.ContextGroups(Ribbon);
    if Ctx <> nil then
      Ctx[0].Visible := True;
  end;
  if Param('tab', S) then
  begin
    Tab := StrToIntDef(S, 0);
    if (Tab >= 0) and (Tab < Ribbon.TabCount) then
      Ribbon.ActiveTab := Ribbon.Tabs(Tab);
  end;
  Doc := TRectangle.Create(Self);
  Doc.Parent := Self;
  Doc.Align := TAlignLayout.Client;
  Doc.Fill.Color := $FFF5F5F5;
  Doc.Stroke.Kind := TBrushKind.None;
end;

var
  Form: TDemoForm;

begin
  Application.Initialize;
  Application.CreateForm(TDemoForm, Form);
  Application.Run;
end.
