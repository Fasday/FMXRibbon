{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: template chooser                        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.Templates;

/// "Apply Template..." of the ribbon: a modal chooser (template list, description, replace option) and the
/// application of FMR.Ribbon.Templates through the designer (names from the designer, a bar manager created when
/// the ribbon has none).

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMR.Ribbon.Templates, FMR.Ribbon.Design.Bridge;

/// <summary>Shows the template chooser. AHasTabs: the ribbon already has tabs (the "replace" option is offered).
/// </summary>
function FmrChooseTemplate(var ATemplate: TFmrRibbonTemplate; var AReplace: Boolean;
  const AHasTabs: Boolean): Boolean;
/// <summary>Builds ATemplate into ARibbon through the designer; returns the first new tab.</summary>
function FmrDesignApplyTemplate(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject;
  const ATemplate: TFmrRibbonTemplate; const AReplace: Boolean): TComponent;
/// <summary>Chooser + application; True when a template was applied.</summary>
function FmrDesignRunTemplateWizard(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): Boolean;

implementation

uses
  Winapi.Windows, System.Types, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  FMR.Bars, FMR.Ribbon.Structure;

type
  TTemplateDialog = class(TForm)
  private
    FList: TListBox;
    FDescription: TLabel;
    FReplace: TCheckBox;
    procedure ListClick(Sender: TObject);
  public
    constructor CreateDialog(const AHasTabs: Boolean);
  end;

constructor TTemplateDialog.CreateDialog(const AHasTabs: Boolean);
var
  T: TFmrRibbonTemplate;
  Bottom, Right: TPanel;
  B: TButton;
  Lbl: TLabel;
begin
  inherited CreateNew(Application);
  Caption := 'Apply Ribbon Template';
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Height := -12;
  ClientWidth := 560;
  ClientHeight := 300;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 44;
  Bottom.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'Cancel';
  B.ModalResult := mrCancel;
  B.Cancel := True;
  B.SetBounds(ClientWidth - 92, 10, 80, 26);
  B.Anchors := [akRight, akBottom];
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'Apply';
  B.ModalResult := mrOk;
  B.Default := True;
  B.SetBounds(ClientWidth - 180, 10, 80, 26);
  B.Anchors := [akRight, akBottom];
  FReplace := TCheckBox.Create(Self);
  FReplace.Parent := Bottom;
  FReplace.Caption := 'Replace the existing tabs and the quick access toolbar';
  FReplace.SetBounds(12, 14, 340, 20);
  FReplace.Enabled := AHasTabs;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Self;
  Lbl.Align := alTop;
  Lbl.AlignWithMargins := True;
  Lbl.Margins.SetBounds(12, 10, 12, 4);
  Lbl.Caption := 'Creates tabs, groups, items with icons of the Segoe Fluent Icons font and links. ' +
    'Existing items are not reused; new names are unique.';
  Lbl.WordWrap := True;

  FList := TListBox.Create(Self);
  FList.Parent := Self;
  FList.Align := alLeft;
  FList.AlignWithMargins := True;
  FList.Margins.SetBounds(12, 4, 6, 4);
  FList.Width := 200;
  for T := Low(TFmrRibbonTemplate) to High(TFmrRibbonTemplate) do
    FList.Items.Add(TFmrRibbonTemplateBuilder.TemplateCaption(T));
  FList.OnClick := ListClick;

  Right := TPanel.Create(Self);
  Right.Parent := Self;
  Right.Align := alClient;
  Right.BevelOuter := bvNone;
  Right.AlignWithMargins := True;
  Right.Margins.SetBounds(6, 4, 12, 4);
  FDescription := TLabel.Create(Self);
  FDescription.Parent := Right;
  FDescription.Align := alClient;
  FDescription.WordWrap := True;
  FDescription.ShowAccelChar := False;

  FmrDesignFinishForm(Self);
end;

procedure TTemplateDialog.ListClick(Sender: TObject);
begin
  if FList.ItemIndex >= 0 then
    FDescription.Caption := TFmrRibbonTemplateBuilder.TemplateDescription(TFmrRibbonTemplate(FList.ItemIndex));
end;

function FmrChooseTemplate(var ATemplate: TFmrRibbonTemplate; var AReplace: Boolean;
  const AHasTabs: Boolean): Boolean;
var
  D: TTemplateDialog;
begin
  D := TTemplateDialog.CreateDialog(AHasTabs);
  try
    D.FList.ItemIndex := Ord(ATemplate);
    D.ListClick(nil);
    D.FReplace.Checked := AReplace and AHasTabs;
    Result := D.ShowModal = mrOk;
    if Result and (D.FList.ItemIndex >= 0) then
    begin
      ATemplate := TFmrRibbonTemplate(D.FList.ItemIndex);
      AReplace := D.FReplace.Checked;
    end;
  finally
    D.Free;
  end;
end;

function FmrDesignApplyTemplate(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject;
  const ATemplate: TFmrRibbonTemplate; const AReplace: Boolean): TComponent;
var
  Manager: TFmrBarManager;
  Builder: TFmrRibbonTemplateBuilder;
  Bridge: IFmrDesignBridge;
begin
  Manager := FmrDesignEnsureManager(ABridge, ARibbon);
  Bridge := ABridge;
  Builder := TFmrRibbonTemplateBuilder.Create(ARibbon, Manager,
    function(const ABaseName: string): string
    begin
      Result := Bridge.UniqueName(ABaseName);
    end);
  try
    if AReplace then
      Builder.ClearStructure;
    Builder.Build(ATemplate);
    Result := Builder.FirstTab;
    if Builder.FirstTab <> nil then
      Builder.FirstTab.Active := True;
  finally
    Builder.Free;
  end;
  ABridge.Modified;
end;

function FmrDesignRunTemplateWizard(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): Boolean;
var
  T: TFmrRibbonTemplate;
  Replace: Boolean;
  First: TComponent;
begin
  T := TFmrRibbonTemplate.Word;
  Replace := False;
  Result := FmrChooseTemplate(T, Replace, TFmrRibbonStructure.TabCount(ARibbon) > 0);
  if Result then
  begin
    First := FmrDesignApplyTemplate(ABridge, ARibbon, T, Replace);
    if First <> nil then
      ABridge.SelectObjects([First])
    else
      ABridge.SelectObjects([ARibbon]);
  end;
end;

end.
