{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Run-time customization form                          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Customize;

/// "Customize the Ribbon" and "Quick Access Toolbar" pages of an options dialog, created in code and
/// painted with the theme of the ribbon (FMR.Ribbon.CustomizeControls). The pages edit a TFmrRibbonCustomization
/// session (FMR.Ribbon.CustomizeModel): OK applies it to the ribbon, Cancel throws it away. Opened by
/// TFmrRibbon.ShowCustomizationForm, the "More Commands..." entry of the quick access toolbar menu and the
/// "Customize the Ribbon..." entry of the ribbon context menu.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Edit, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images,
  FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Strings, FMR.Ribbon.Theme, FMR.Ribbon.Painter,
  FMR.Ribbon.Popup, FMR.Ribbon.CustomizeModel, FMR.Ribbon.CustomizeControls, FMR.Ribbon;

type
  TFmrTabsFilter = (All, Main, Tool);

  /// <summary>The customization dialog.</summary>
  TFmrRibbonCustomizeForm = class(TForm)
  private type
    TCommandPane = record
      SourceLabel: TControl;
      SourceButton: TFmrCustButton;
      Search: TEdit;
      List: TFmrCustList;
      Source: TFmrCommandSource;
    end;
  private
    FRibbon: TFmrRibbon;
    FSession: TFmrRibbonCustomization;
    FTheme: TFmrCustTheme;
    FNav: TFmrCustNav;
    FRibbonPage, FQATPage: TControl;
    FTitle: TControl;
    { ribbon page }
    FRCmd: TCommandPane;
    FRAdd, FRRemove, FRUp, FRDown, FRNewTab, FRNewGroup, FRRename, FRReset, FRImport, FRFilter: TFmrCustButton;
    FRTreeLabel, FRHint: TControl;
    FTree: TFmrCustList;
    FFilter: TFmrTabsFilter;
    FExpanded: TList<TObject>;
    { QAT page }
    FQCmd: TCommandPane;
    FQAdd, FQRemove, FQUp, FQDown, FQReset, FQImport: TFmrCustButton;
    FQListLabel: TControl;
    FQList: TFmrCustList;
    FQBelow: TFmrCustCheck;
    { buttons }
    FOK, FCancel: TFmrCustButton;
    FPage: TFmrCustomizationPage;
    procedure BuildControls;
    procedure BuildCommandPane(var APane: TCommandPane; const AParent: TControl);
    procedure LayoutControls;
    procedure SetPage(const APage: TFmrCustomizationPage);
    procedure ApplyDarkCaption;
    function NewButton(const AParent: TFmxObject; const ACaption: string; const AClick: TNotifyEvent;
      const AGlyph: TFmrCustGlyph = TFmrCustGlyph.None): TFmrCustButton;
    procedure ShowMenu(const AButton: TFmrCustButton; const AMenu: TFmrTempMenu);
    function Confirm(const AText: string): Boolean;
    procedure ShowError(const AText: string);
    { command lists }
    procedure FillCommands(var APane: TCommandPane; const AWithSeparator: Boolean);
    procedure SourceClick(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    function SelectedCommand(const APane: TCommandPane): TFmrBarItem;
    { ribbon tree }
    procedure FillTree(const ASelect: TObject);
    function TreeSelection: TObject;
    function TabOfSelection: TFmrRibbonTab;
    procedure UpdateRibbonButtons;
    procedure TreeChange(Sender: TObject);
    procedure TreeCheck(AIndex: Integer);
    procedure TreeToggle(AIndex: Integer);
    procedure CommandsChange(Sender: TObject);
    procedure RibbonAddClick(Sender: TObject);
    procedure RibbonRemoveClick(Sender: TObject);
    procedure RibbonMove(const ADelta: Integer);
    procedure RibbonUpClick(Sender: TObject);
    procedure RibbonDownClick(Sender: TObject);
    procedure NewTabClick(Sender: TObject);
    procedure NewGroupClick(Sender: TObject);
    procedure RenameClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure ImportExportClick(Sender: TObject);
    procedure FilterClick(Sender: TObject);
    { quick access toolbar }
    procedure FillQAT(const ASelectIndex: Integer; const ASeparator: Boolean = False);
    function QATSelection(out AIndex: Integer; out ASeparator: Boolean): Boolean;
    procedure UpdateQATButtons;
    procedure QATChange(Sender: TObject);
    procedure QATAddClick(Sender: TObject);
    procedure QATRemoveClick(Sender: TObject);
    procedure QATUpClick(Sender: TObject);
    procedure QATDownClick(Sender: TObject);
    procedure QATResetClick(Sender: TObject);
    procedure QATBelowChange(Sender: TObject);
    procedure RefreshAll;
    procedure DoImport;
    procedure DoExport;
    { form }
    procedure NavChange(Sender: TObject);
    procedure OKClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure FormKey(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure FormResized(Sender: TObject);
  protected
    procedure DoShow; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    class var
      /// <summary>Called when a form is shown (drivers, screenshots, tests).</summary>
      OnShowHook: TProc<TFmrRibbonCustomizeForm>;
      /// <summary>When set, Import and Export use this file instead of the file dialogs (scripted demos).</summary>
      AutoFileName: string;
      /// <summary>Confirmations (reset all) are answered Yes without asking (scripted demos).</summary>
      AutoConfirm: Boolean;
    constructor CreateFor(const ARibbon: TFmrRibbon; const APage: TFmrCustomizationPage); reintroduce;
    destructor Destroy; override;
    /// <summary>Shows the dialog modally; True when the user pressed OK (the ribbon was changed).</summary>
    class function Execute(const ARibbon: TFmrRibbon; const APage: TFmrCustomizationPage): Boolean;
    /// <summary>Names and screen rectangles (dp) of the controls (diagnostics, drivers).</summary>
    function DebugDump: string;
    property Session: TFmrRibbonCustomization read FSession;
    property Page: TFmrCustomizationPage read FPage write SetPage;
    property Tree: TFmrCustList read FTree;
    property QATList: TFmrCustList read FQList;
  end;

  /// <summary>Rename dialog (display name, symbol of custom groups).</summary>
  TFmrRenameForm = class(TForm)
  private
    FTheme: TFmrCustTheme;
    FParentForm: TCommonCustomForm;
    FEdit: TEdit;
    FGrid: TFmrCustSymbolGrid;
    FOK, FCancel: TFmrCustButton;
    procedure OKClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure EditKey(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  protected
    procedure DoShow; override;
  public
    constructor CreateRename(const ATheme: TFmrCustTheme; const ACaption: string; const AWithSymbols: Boolean;
      const ACode: Cardinal); reintroduce;
    /// <summary>Shows the dialog; True with the new caption and symbol on OK.</summary>
    class function Execute(const ATheme: TFmrCustTheme; var ACaption: string; const AWithSymbols: Boolean;
      var ACode: Cardinal): Boolean;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows, Winapi.Dwmapi, FMX.Platform.Win,{$ENDIF} System.IOUtils, FMX.Dialogs,
  FMX.DialogService.Sync, FMR.Ribbon.EditorStyles, FMR.Ribbon.Persistence;

const
  SymbolCodes: array[0..47] of Cardinal = ($E8A5, $E70F, $E734, $E735, $E7C3, $E8B9, $E80F, $E713, $E721, $E74E,
    $E749, $E8C8, $E77F, $E8C6, $E8DD, $E8D3, $E71B, $E8A4, $E90A, $E7AD, $E740, $E80A, $E8F1, $E8EC, $E7B8, $E8D2,
    $E8E5, $E78B, $E71E, $E890, $E8FD, $E7E6, $E790, $E8C1, $E8B3, $E8AB, $E76E, $E946, $E7BA, $E91B, $E8F4, $E81C,
    $E9D9, $E8BC, $E7EF, $E710, $E73E, $E711);

function NewEdit(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme;
  const APrompt: string): TEdit;
begin
  Result := TFmrRibbonEdit.Create(AOwner);
  Result.Parent := AParent;
  Result.TextPrompt := APrompt;
  Result.Height := Max(24, Round(ATheme.Painter.Metrics.SmallButtonHeight + 2));
  FmrThemeEditor(Result, ATheme.Painter.Theme);
end;

procedure PrepareThemedForm(const AForm: TCustomForm; const ATheme: TFmrCustTheme);
begin
  AForm.Fill.Kind := TBrushKind.Solid;
  AForm.Fill.Color := ATheme.Background;
end;

{ TFmrRibbonCustomizeForm }

class function TFmrRibbonCustomizeForm.Execute(const ARibbon: TFmrRibbon;
  const APage: TFmrCustomizationPage): Boolean;
var
  F: TFmrRibbonCustomizeForm;
begin
  F := TFmrRibbonCustomizeForm.CreateFor(ARibbon, APage);
  try
    Result := F.ShowModal = mrOk;
  finally
    F.Free;
  end;
end;

constructor TFmrRibbonCustomizeForm.CreateFor(const ARibbon: TFmrRibbon; const APage: TFmrCustomizationPage);
var
  Images: TCustomImageList;
  Owner: TCommonCustomForm;
begin
  inherited CreateNew(nil);
  FRibbon := ARibbon;
  FExpanded := TList<TObject>.Create;
  Images := nil;
  if ARibbon.BarManager <> nil then
    Images := ARibbon.BarManager.Images;
  FTheme := TFmrCustTheme.Create(ARibbon.Painter, Images);
  FSession := TFmrRibbonCustomization.Create(ARibbon, ARibbon.DefaultLayout);
  BorderStyle := TFmxFormBorderStyle.Sizeable;
  BorderIcons := [TBorderIcon.biSystemMenu, TBorderIcon.biMaximize];
  Width := 900;
  Height := 620;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 480;
  Owner := nil;
  if ARibbon.Root <> nil then
    Owner := TCommonCustomForm(ARibbon.Root.GetObject);
  if Owner <> nil then
  begin
    Left := Owner.Left + (Owner.Width - Width) div 2;
    Top := Owner.Top + Max(0, (Owner.Height - Height) div 2);
    BiDiMode := Owner.BiDiMode;
  end
  else
    Position := TFormPosition.ScreenCenter;
  PrepareThemedForm(Self, FTheme);
  OnKeyDown := FormKey;
  OnResize := FormResized;
  BuildControls;
  // The tree starts with the active tab expanded.
  if (ARibbon.ActiveTab <> nil) and (FSession.ShadowOf(ARibbon.ActiveTab) <> nil) then
    FExpanded.Add(FSession.ShadowOf(ARibbon.ActiveTab));
  RefreshAll;
  SetPage(APage);
  LayoutControls;
end;

destructor TFmrRibbonCustomizeForm.Destroy;
begin
  if FmrPopupsAssigned then
    FmrPopups.CloseAll;
  inherited;
  FreeAndNil(FSession);
  FreeAndNil(FExpanded);
  FreeAndNil(FTheme);
end;

procedure TFmrRibbonCustomizeForm.DoShow;
begin
  inherited;
  ApplyDarkCaption;
  if Assigned(OnShowHook) then
    OnShowHook(Self);
end;

procedure TFmrRibbonCustomizeForm.DoClose(var CloseAction: TCloseAction);
begin
  if FmrPopupsAssigned then
    FmrPopups.CloseAll;
  inherited;
end;

procedure PrepareDialogWindow(const ADialog, AOwner: TCommonCustomForm; const ADark: Boolean);
{$IFDEF MSWINDOWS}
var
  Wnd, OwnerWnd: HWND;
  Dark: BOOL;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  try
    Wnd := FormToHWND(ADialog);
    if Wnd = 0 then
      Exit;
    // FMX dialogs are not owned windows: owned by the form they belong to, they stay above it (popup menus of the
    // dialog would otherwise bring the main form to the front).
    if (AOwner <> nil) and AOwner.IsHandleAllocated then
    begin
      OwnerWnd := FormToHWND(AOwner);
      if OwnerWnd <> 0 then
        SetWindowLongPtr(Wnd, GWLP_HWNDPARENT, LONG_PTR(OwnerWnd));
    end;
    // Dark themes get a dark title bar (DWMWA_USE_IMMERSIVE_DARK_MODE, Windows 10 2004+; ignored elsewhere).
    Dark := ADark;
    DwmSetWindowAttribute(Wnd, 20, @Dark, SizeOf(Dark));
  except
  end;
  {$ENDIF}
end;

procedure TFmrRibbonCustomizeForm.ApplyDarkCaption;
var
  Owner: TCommonCustomForm;
begin
  Owner := nil;
  if (FRibbon.Root <> nil) and (FRibbon.Root.GetObject is TCommonCustomForm) then
    Owner := TCommonCustomForm(FRibbon.Root.GetObject);
  PrepareDialogWindow(Self, Owner, FRibbon.Painter.Theme.Style.Dark);
end;

function TFmrRibbonCustomizeForm.NewButton(const AParent: TFmxObject; const ACaption: string;
  const AClick: TNotifyEvent; const AGlyph: TFmrCustGlyph): TFmrCustButton;
begin
  Result := TFmrCustButton.CreateThemed(Self, AParent, FTheme);
  Result.Caption := ACaption;
  Result.Glyph := AGlyph;
  Result.OnClick := AClick;
end;

procedure TFmrRibbonCustomizeForm.BuildCommandPane(var APane: TCommandPane; const AParent: TControl);
begin
  APane.SourceLabel := FmrCustLabel(Self, AParent, FTheme, FmrStr(TFmrStringId.CustChooseCommandsFrom));
  APane.SourceButton := NewButton(AParent, '', SourceClick, TFmrCustGlyph.DropDown);
  APane.Search := NewEdit(Self, AParent, FTheme, FmrStr(TFmrStringId.CustSearchPrompt));
  APane.Search.OnChangeTracking := SearchChange;
  APane.Search.OnKeyDown := SearchKeyDown;
  APane.List := TFmrCustList.CreateThemed(Self, AParent, FTheme);
  APane.List.EmptyText := FmrStr(TFmrStringId.CustNoCommands);
  APane.List.OnChange := CommandsChange;
  APane.Source := FSession.CommandSources[0];
end;

procedure TFmrRibbonCustomizeForm.BuildControls;
begin
  FNav := TFmrCustNav.CreateThemed(Self, Self, FTheme);
  FNav.Items := [FmrStr(TFmrStringId.CustRibbonCaption), FmrStr(TFmrStringId.AccQAT)];
  FNav.OnChange := NavChange;
  FTitle := FmrCustLabel(Self, Self, FTheme, '', True, FRibbon.Painter.Metrics.FontSize + 3);

  { ribbon page }
  FRibbonPage := TControl.Create(Self);
  FRibbonPage.Parent := Self;
  FRibbonPage.HitTest := False;
  BuildCommandPane(FRCmd, FRibbonPage);
  FRCmd.List.OnActivate := RibbonAddClick;
  FRAdd := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustAdd), RibbonAddClick);
  FRRemove := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustRemove), RibbonRemoveClick);
  FRTreeLabel := FmrCustLabel(Self, FRibbonPage, FTheme, FmrStr(TFmrStringId.CustCustomizeRibbonLabel));
  FRFilter := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustAllTabs), FilterClick, TFmrCustGlyph.DropDown);
  FTree := TFmrCustList.CreateThemed(Self, FRibbonPage, FTheme);
  FTree.OnChange := TreeChange;
  FTree.OnCheck := TreeCheck;
  FTree.OnToggle := TreeToggle;
  FRUp := NewButton(FRibbonPage, '', RibbonUpClick, TFmrCustGlyph.Up);
  FRDown := NewButton(FRibbonPage, '', RibbonDownClick, TFmrCustGlyph.Down);
  FRNewTab := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustNewTab), NewTabClick);
  FRNewGroup := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustNewGroup), NewGroupClick);
  FRRename := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustRename), RenameClick);
  FRReset := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustReset), ResetClick, TFmrCustGlyph.DropDown);
  FRImport := NewButton(FRibbonPage, FmrStr(TFmrStringId.CustImportExport), ImportExportClick, TFmrCustGlyph.DropDown);
  FRHint := FmrCustLabel(Self, FRibbonPage, FTheme, FmrStr(TFmrStringId.CustAddRuleHint));

  { quick access toolbar page }
  FQATPage := TControl.Create(Self);
  FQATPage.Parent := Self;
  FQATPage.HitTest := False;
  BuildCommandPane(FQCmd, FQATPage);
  FQCmd.List.OnActivate := QATAddClick;
  FQAdd := NewButton(FQATPage, FmrStr(TFmrStringId.CustAdd), QATAddClick);
  FQRemove := NewButton(FQATPage, FmrStr(TFmrStringId.CustRemove), QATRemoveClick);
  FQListLabel := FmrCustLabel(Self, FQATPage, FTheme, FmrStr(TFmrStringId.CustCustomizeQATLabel));
  FQList := TFmrCustList.CreateThemed(Self, FQATPage, FTheme);
  FQList.OnChange := QATChange;
  FQUp := NewButton(FQATPage, '', QATUpClick, TFmrCustGlyph.Up);
  FQDown := NewButton(FQATPage, '', QATDownClick, TFmrCustGlyph.Down);
  FQReset := NewButton(FQATPage, FmrStr(TFmrStringId.CustReset), QATResetClick, TFmrCustGlyph.DropDown);
  FQImport := NewButton(FQATPage, FmrStr(TFmrStringId.CustImportExport), ImportExportClick, TFmrCustGlyph.DropDown);
  FQBelow := TFmrCustCheck.CreateThemed(Self, FQATPage, FTheme);
  FQBelow.Caption := FmrStr(TFmrStringId.CustShowQATBelow);
  FQBelow.OnChange := QATBelowChange;

  FOK := NewButton(Self, FmrStr(TFmrStringId.CommonOK), OKClick);
  FOK.IsDefault := True;
  FCancel := NewButton(Self, FmrStr(TFmrStringId.CommonCancel), CancelClick);
end;

procedure TFmrRibbonCustomizeForm.FormResized(Sender: TObject);
begin
  LayoutControls;
end;

procedure TFmrRibbonCustomizeForm.LayoutControls;
const
  Pad = 16;
var
  W, H, NavW, X0, Y0, X1, Y1, BH, MidW, ColW, LX, RX, Y, ListTop, ListBottom, SideW, FlowW, HintH: Single;
  Rows1, Rows2: Integer;

  procedure Place(const AControl: TControl; const AX, AY, AW, AH: Single);
  begin
    if AControl <> nil then
      AControl.SetBounds(Round(AX), Round(AY), Round(Max(0, AW)), Round(Max(0, AH)));
  end;

  procedure PlacePane(const APane: TCommandPane; const AX, AW, ABottom: Single);
  var
    Yp: Single;
  begin
    Yp := Y0 + 36;
    Place(APane.SourceLabel, AX, Yp, AW, 20);
    Yp := Yp + 22;
    Place(APane.SourceButton, AX, Yp, AW, BH);
    Yp := Yp + BH + 6;
    Place(APane.Search, AX, Yp, AW, BH);
    Yp := Yp + BH + 6;
    Place(APane.List, AX, Yp, AW, ABottom - Yp);
  end;

  /// Buttons left to right in rows of width AW, each at least as wide as its caption; the buttons of a row share
  /// the spare width. Returns the number of rows (only counts them when APlace is False).
  function Flow(const AButtons: array of TFmrCustButton; const AX, AY, AW: Single; const APlace: Boolean): Integer;
  const
    Gap = 6;
  var
    I, J, First: Integer;
    Used, Extra, X, Wd: Single;
  begin
    Result := 0;
    First := 0;
    Used := 0;
    for I := 0 to Length(AButtons) do
    begin
      if (I < Length(AButtons)) and ((I = First) or (Used + Gap + AButtons[I].NaturalWidth <= AW)) then
      begin
        if I > First then
          Used := Used + Gap;
        Used := Used + AButtons[I].NaturalWidth;
        Continue;
      end;
      if APlace then
      begin
        Extra := Max(0, (AW - Used) / (I - First));
        X := AX;
        for J := First to I - 1 do
        begin
          Wd := Min(AButtons[J].NaturalWidth + Extra, AW);
          Place(AButtons[J], X, AY + Result * (BH + 8), Wd, BH);
          X := X + Wd + Gap;
        end;
      end;
      Inc(Result);
      if I < Length(AButtons) then
      begin
        First := I;
        Used := AButtons[I].NaturalWidth;
      end;
    end;
  end;

begin
  if (FNav = nil) or (FOK = nil) then
    Exit;
  W := ClientWidth;
  H := ClientHeight;
  NavW := 190;
  BH := FOK.Height;
  Place(FNav, 0, 0, NavW, H);
  X0 := NavW + Pad + 4;
  Y0 := Pad;
  X1 := W - Pad;
  Y1 := H - Pad - BH - 12;
  Place(FTitle, X0, Y0, X1 - X0, 28);
  Place(FCancel, X1 - 90, H - Pad - BH, 90, BH);
  Place(FOK, X1 - 186, H - Pad - BH, 90, BH);
  Place(FRibbonPage, 0, 0, W, H);
  Place(FQATPage, 0, 0, W, H);

  MidW := 112;
  SideW := 36;
  ColW := (X1 - X0 - MidW - SideW - 16) / 2;
  LX := X0;
  RX := X0 + ColW + MidW + 8;
  ListTop := Y0 + 36 + 22 + BH + 6 + BH + 6;

  { ribbon page: the buttons below the tree take as many rows as their captions need (translations), using the
    width below the up/down buttons too when that saves a row }
  FlowW := ColW;
  Rows1 := Flow([FRNewTab, FRNewGroup, FRRename], RX, 0, ColW, False);
  Rows2 := Flow([FRReset, FRImport], RX, 0, ColW, False);
  if Flow([FRNewTab, FRNewGroup, FRRename], RX, 0, X1 - RX, False) +
    Flow([FRReset, FRImport], RX, 0, X1 - RX, False) < Rows1 + Rows2 then
  begin
    FlowW := X1 - RX;
    Rows1 := Flow([FRNewTab, FRNewGroup, FRRename], RX, 0, FlowW, False);
    Rows2 := Flow([FRReset, FRImport], RX, 0, FlowW, False);
  end;
  HintH := Max(FTheme.Painter.TextSize(FmrStr(TFmrStringId.CustAddRuleHint), 0, False, ColW, True).Height,
    FTheme.Painter.TextSize(FmrStr(TFmrStringId.CustDesignedHint), 0, False, ColW, True).Height);
  HintH := Max(40, Ceil(HintH) + 8);
  ListBottom := Y1 - (Rows1 + Rows2) * (BH + 8) - HintH - 2;
  PlacePane(FRCmd, LX, ColW, Y1);
  Y := (ListTop + ListBottom) / 2 - BH - 4;
  Place(FRAdd, LX + ColW + 10, Y, MidW - 20, BH);
  Place(FRRemove, LX + ColW + 10, Y + BH + 8, MidW - 20, BH);
  Place(FRTreeLabel, RX, Y0 + 36, ColW, 20);
  Place(FRFilter, RX, Y0 + 58, ColW, BH);
  Place(FTree, RX, Y0 + 58 + BH + 6, ColW, ListBottom - (Y0 + 58 + BH + 6));
  Y := (Y0 + 58 + BH + 6 + ListBottom) / 2 - BH - 4;
  Place(FRUp, RX + ColW + 6, Y, SideW - 4, BH);
  Place(FRDown, RX + ColW + 6, Y + BH + 8, SideW - 4, BH);
  Place(FRHint, RX, ListBottom + 2, ColW, HintH);
  Y := ListBottom + HintH + 4;
  Flow([FRNewTab, FRNewGroup, FRRename], RX, Y, FlowW, True);
  Y := Y + Rows1 * (BH + 8);
  Flow([FRReset, FRImport], RX, Y, FlowW, True);

  { quick access toolbar page }
  FlowW := ColW;
  Rows1 := Flow([FQReset, FQImport], RX, 0, ColW, False);
  if Flow([FQReset, FQImport], RX, 0, X1 - RX, False) < Rows1 then
  begin
    FlowW := X1 - RX;
    Rows1 := Flow([FQReset, FQImport], RX, 0, FlowW, False);
  end;
  ListBottom := Y1 - Rows1 * (BH + 8);
  PlacePane(FQCmd, LX, ColW, Y1 - 30);
  Place(FQBelow, LX, Y1 - 24, ColW + MidW, 24);
  Y := (ListTop + ListBottom) / 2 - BH - 4;
  Place(FQAdd, LX + ColW + 10, Y, MidW - 20, BH);
  Place(FQRemove, LX + ColW + 10, Y + BH + 8, MidW - 20, BH);
  Place(FQListLabel, RX, Y0 + 36, ColW, 20);
  Place(FQList, RX, Y0 + 58, ColW, ListBottom - (Y0 + 58));
  Y := (Y0 + 58 + ListBottom) / 2 - BH - 4;
  Place(FQUp, RX + ColW + 6, Y, SideW - 4, BH);
  Place(FQDown, RX + ColW + 6, Y + BH + 8, SideW - 4, BH);
  Flow([FQReset, FQImport], RX, ListBottom + 8, FlowW, True);
end;

procedure TFmrRibbonCustomizeForm.SetPage(const APage: TFmrCustomizationPage);
begin
  FPage := APage;
  FRibbonPage.Visible := APage = TFmrCustomizationPage.Ribbon;
  FQATPage.Visible := APage = TFmrCustomizationPage.QuickAccessToolbar;
  if APage = TFmrCustomizationPage.Ribbon then
  begin
    FNav.ItemIndex := 0;
    Caption := FmrStr(TFmrStringId.CustRibbonCaption);
  end
  else
  begin
    FNav.ItemIndex := 1;
    Caption := FmrStr(TFmrStringId.CustQATCaption);
  end;
  FmrCustSetLabel(FTitle, Caption);
end;

procedure TFmrRibbonCustomizeForm.NavChange(Sender: TObject);
begin
  if FNav.ItemIndex = 0 then
    SetPage(TFmrCustomizationPage.Ribbon)
  else
    SetPage(TFmrCustomizationPage.QuickAccessToolbar);
end;

procedure TFmrRibbonCustomizeForm.OKClick(Sender: TObject);
begin
  FSession.Apply;
  ModalResult := mrOk;
end;

procedure TFmrRibbonCustomizeForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFmrRibbonCustomizeForm.FormKey(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  if (Key = vkEscape) and not FmrPopups.IsOpen then
  begin
    Key := 0;
    ModalResult := mrCancel;
  end;
end;

procedure TFmrRibbonCustomizeForm.ShowMenu(const AButton: TFmrCustButton; const AMenu: TFmrTempMenu);
var
  Ctx: IFmrPopupContext;
  Content: TFmrMenuControl;
  Popup: TFmrPopupForm;
begin
  Ctx := TFmrPopupContext.Create(FTheme.Painter, FTheme.Images, Self);
  Content := TFmrMenuControl.CreateMenu(Ctx, AMenu.Links, TFmrMenuItemStyle.Normal, AButton.Width);
  Content.OwnedObject := AMenu;
  Popup := TFmrPopupForm.CreatePopup(Ctx, Content);
  FmrPopups.Show(Popup, AButton.ScreenRect, TFmrPopupPlacement.Below);
  // Showing a top-most popup owned by this modal form lets Windows raise the main form above it: raise it again.
  BringToFront;
end;

function TFmrRibbonCustomizeForm.Confirm(const AText: string): Boolean;
begin
  if AutoConfirm then
    Exit(True);
  Result := TDialogServiceSync.MessageDialog(AText, TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes,
    TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes;
end;

procedure TFmrRibbonCustomizeForm.ShowError(const AText: string);
begin
  TDialogServiceSync.MessageDialog(AText, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

procedure TFmrRibbonCustomizeForm.RefreshAll;
begin
  // A tab of the source list may have been removed (reset, import): fall back to all commands.
  if (FRCmd.Source.Kind = TFmrCommandSourceKind.Tab) and
    (TArray.IndexOf<TFmrRibbonTab>(FSession.Tabs, FRCmd.Source.Tab) < 0) then
    FRCmd.Source := FSession.CommandSources[0];
  if (FQCmd.Source.Kind = TFmrCommandSourceKind.Tab) and
    (TArray.IndexOf<TFmrRibbonTab>(FSession.Tabs, FQCmd.Source.Tab) < 0) then
    FQCmd.Source := FSession.CommandSources[0];
  FillCommands(FRCmd, False);
  FillCommands(FQCmd, True);
  FillTree(TreeSelection);
  FillQAT(FQList.ItemIndex);
  FQBelow.Checked := FSession.QATBelow;
end;

{ command lists }

procedure TFmrRibbonCustomizeForm.FillCommands(var APane: TCommandPane; const AWithSeparator: Boolean);
var
  Item, Keep: TFmrBarItem;
  G: TFmrRibbonGroup;
  I, J, Index: Integer;
  Filter: string;
  Row: TFmrCustRow;
  Groups: TArray<TFmrRibbonGroup>;
  Added: Boolean;
begin
  APane.SourceButton.Caption := APane.Source.Caption;
  Filter := APane.Search.Text.Trim.ToLower;
  Keep := SelectedCommand(APane);
  APane.List.Clear;
  if AWithSeparator and (Filter = '') then
  begin
    Row := TFmrCustRow.Create(FmrStr(TFmrStringId.CustSeparator), nil);
    Row.Tag := 1;
    APane.List.Add(Row);
  end;
  if APane.Source.Kind = TFmrCommandSourceKind.Tab then
  begin
    Groups := FSession.Groups(APane.Source.Tab);
    for G in Groups do
    begin
      Added := False;
      for J := 0 to G.ItemLinks.Count - 1 do
      begin
        Item := G.ItemLinks[J].Item;
        if not TFmrRibbonCustomization.IsCustomizableItem(Item) then
          Continue;
        if (Filter <> '') and not FmrCustStripAmp(Item.Caption).ToLower.Contains(Filter) then
          Continue;
        if not Added then
        begin
          Row := TFmrCustRow.Create(FSession.CaptionOf(G), G);
          Row.Kind := TFmrCustRowKind.Header;
          APane.List.Add(Row);
          Added := True;
        end;
        APane.List.Add(TFmrCustRow.Create(FmrCustStripAmp(Item.Caption), Item, 1, Item.Glyph));
      end;
    end;
  end
  else
    for Item in FSession.Commands(APane.Source, Filter) do
      APane.List.Add(TFmrCustRow.Create(FmrCustStripAmp(Item.Caption), Item, 0, Item.Glyph));
  Index := -1;
  if Keep <> nil then
    Index := APane.List.IndexOfData(Keep);
  if Index < 0 then
    for I := 0 to APane.List.Count - 1 do
      if APane.List.Row(I).Kind = TFmrCustRowKind.Item then
      begin
        Index := I;
        Break;
      end;
  APane.List.Changed;
  APane.List.ItemIndex := Index;
end;

function TFmrRibbonCustomizeForm.SelectedCommand(const APane: TCommandPane): TFmrBarItem;
begin
  if (APane.List <> nil) and (APane.List.SelectedData is TFmrBarItem) then
    Result := TFmrBarItem(APane.List.SelectedData)
  else
    Result := nil;
end;

procedure TFmrRibbonCustomizeForm.SourceClick(Sender: TObject);
var
  Menu: TFmrTempMenu;
  S: TFmrCommandSource;
  LastKind: TFmrCommandSourceKind;
  Btn: TFmrCustButton;
  QAT: Boolean;
begin
  Btn := Sender as TFmrCustButton;
  QAT := Btn = FQCmd.SourceButton;
  Menu := TFmrTempMenu.Create;
  LastKind := TFmrCommandSourceKind.AllCommands;
  for S in FSession.CommandSources do
  begin
    if (S.Kind <> LastKind) and (S.Kind in [TFmrCommandSourceKind.Tab, TFmrCommandSourceKind.Category]) then
    begin
      if S.Kind = TFmrCommandSourceKind.Tab then
        Menu.AddHeader(FmrStr(TFmrStringId.CustTabsHeader))
      else
        Menu.AddHeader(FmrStr(TFmrStringId.CustCategoriesHeader));
    end;
    LastKind := S.Kind;
    Menu.AddCommand(S.Caption,
      procedure
      begin
        if QAT then
        begin
          FQCmd.Source := S;
          FillCommands(FQCmd, True);
        end
        else
        begin
          FRCmd.Source := S;
          FillCommands(FRCmd, False);
        end;
        UpdateRibbonButtons;
        UpdateQATButtons;
      end, (QAT and (S.Caption = FQCmd.Source.Caption)) or (not QAT and (S.Caption = FRCmd.Source.Caption)));
  end;
  ShowMenu(Btn, Menu);
end;

procedure TFmrRibbonCustomizeForm.SearchChange(Sender: TObject);
begin
  if Sender = FQCmd.Search then
    FillCommands(FQCmd, True)
  else
    FillCommands(FRCmd, False);
  UpdateRibbonButtons;
  UpdateQATButtons;
end;

procedure TFmrRibbonCustomizeForm.SearchKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
var
  List: TFmrCustList;
begin
  if Sender = FQCmd.Search then
    List := FQCmd.List
  else
    List := FRCmd.List;
  if (Key = vkDown) or (Key = vkReturn) then
  begin
    Key := 0;
    List.SetFocus;
  end;
end;

procedure TFmrRibbonCustomizeForm.CommandsChange(Sender: TObject);
begin
  UpdateRibbonButtons;
  UpdateQATButtons;
end;

{ ribbon tree }

function TFmrRibbonCustomizeForm.TreeSelection: TObject;
begin
  if FTree <> nil then
    Result := FTree.SelectedData
  else
    Result := nil;
end;

function TFmrRibbonCustomizeForm.TabOfSelection: TFmrRibbonTab;
var
  O: TObject;
begin
  O := TreeSelection;
  if O is TFmrRibbonTab then
    Result := TFmrRibbonTab(O)
  else if O is TFmrRibbonGroup then
    Result := TFmrRibbonGroup(O).Tab
  else if (O is TFmrItemLink) and (TFmrItemLink(O).LinksOwner is TFmrRibbonGroup) then
    Result := TFmrRibbonGroup(TFmrItemLink(O).LinksOwner).Tab
  else
    Result := nil;
end;

procedure TFmrRibbonCustomizeForm.FillTree(const ASelect: TObject);
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  L: TFmrItemLink;
  I, J, Index: Integer;
  Row: TFmrCustRow;
  Caption: string;
begin
  FTree.Clear;
  for T in FSession.Tabs do
  begin
    if (FFilter = TFmrTabsFilter.Main) and TFmrRibbonCustomization.IsToolTab(T) then
      Continue;
    if (FFilter = TFmrTabsFilter.Tool) and not TFmrRibbonCustomization.IsToolTab(T) then
      Continue;
    Caption := FSession.CaptionOf(T);
    if T.IsUserDefined then
      Caption := Caption + FmrStr(TFmrStringId.CustCustomSuffix);
    if T.ContextGroup <> nil then
      Caption := Caption + ' (' + FmrCustStripAmp(T.ContextGroup.DisplayCaption) + ')';
    Row := TFmrCustRow.Create(Caption, T, 0);
    Row.HasCheck := True;
    Row.Checked := T.Visible;
    Row.Expandable := T.GroupCount > 0;
    Row.Expanded := FExpanded.Contains(T);
    Row.Bold := True;
    FTree.Add(Row);
    if not Row.Expanded then
      Continue;
    for I := 0 to T.GroupCount - 1 do
    begin
      G := T.Groups[I];
      Caption := FSession.CaptionOf(G);
      if G.IsUserDefined then
        Caption := Caption + FmrStr(TFmrStringId.CustCustomSuffix);
      if G.Glyph.IsEmpty(FTheme.Images) then
        Row := TFmrCustRow.Create(Caption, G, 1)
      else
        Row := TFmrCustRow.Create(Caption, G, 1, G.Glyph);
      Row.HasCheck := True;
      Row.Checked := G.Visible;
      Row.Expandable := G.ItemLinks.Count > 0;
      Row.Expanded := FExpanded.Contains(G);
      FTree.Add(Row);
      if not Row.Expanded then
        Continue;
      for J := 0 to G.ItemLinks.Count - 1 do
      begin
        L := G.ItemLinks[J];
        if L.Item = nil then
          Continue;
        if L.Item is TFmrSeparatorItem then
          Continue;
        Row := TFmrCustRow.Create(FSession.CaptionOf(L), L, 2, L.Item.Glyph);
        Row.Dim := not G.IsUserDefined;
        FTree.Add(Row);
      end;
    end;
  end;
  FTree.Changed;
  Index := FTree.IndexOfData(ASelect);
  if (Index < 0) and (FTree.Count > 0) then
    Index := 0;
  FTree.ItemIndex := Index;
  FTree.EnsureVisible(Index);
  UpdateRibbonButtons;
end;

procedure TFmrRibbonCustomizeForm.UpdateRibbonButtons;
var
  Sel: TObject;
  Item: TFmrBarItem;
  Designed: Boolean;
begin
  if FTree = nil then
    Exit;
  Sel := TreeSelection;
  Item := SelectedCommand(FRCmd);
  FRAdd.Enabled := (Item <> nil) and FSession.CanAddCommand(Item, Sel);
  FRRemove.Enabled := FSession.CanRemove(Sel);
  FRUp.Enabled := FSession.CanMove(Sel, -1);
  FRDown.Enabled := FSession.CanMove(Sel, 1);
  FRNewGroup.Enabled := TabOfSelection <> nil;
  FRRename.Enabled := FSession.CanRename(Sel);
  Designed := ((Sel is TFmrRibbonGroup) and not TFmrRibbonGroup(Sel).IsUserDefined) or ((Sel is TFmrItemLink) and
    (TFmrItemLink(Sel).LinksOwner is TFmrRibbonGroup) and
    not TFmrRibbonGroup(TFmrItemLink(Sel).LinksOwner).IsUserDefined);
  if Designed then
    FmrCustSetLabel(FRHint, FmrStr(TFmrStringId.CustDesignedHint), True)
  else
    FmrCustSetLabel(FRHint, FmrStr(TFmrStringId.CustAddRuleHint), True);
end;

procedure TFmrRibbonCustomizeForm.TreeChange(Sender: TObject);
begin
  UpdateRibbonButtons;
end;

procedure TFmrRibbonCustomizeForm.TreeCheck(AIndex: Integer);
var
  Row: TFmrCustRow;
begin
  Row := FTree.Row(AIndex);
  FSession.SetVisible(Row.Data, not FSession.IsVisible(Row.Data));
  FillTree(Row.Data);
end;

procedure TFmrRibbonCustomizeForm.TreeToggle(AIndex: Integer);
var
  Row: TFmrCustRow;
begin
  Row := FTree.Row(AIndex);
  if FExpanded.Contains(Row.Data) then
    FExpanded.Remove(Row.Data)
  else
    FExpanded.Add(Row.Data);
  FillTree(Row.Data);
end;

procedure TFmrRibbonCustomizeForm.RibbonAddClick(Sender: TObject);
var
  Item: TFmrBarItem;
  Sel: TObject;
  L: TFmrItemLink;
  G: TFmrRibbonGroup;
begin
  Item := SelectedCommand(FRCmd);
  Sel := TreeSelection;
  if (Item = nil) or not FSession.CanAddCommand(Item, Sel) then
    Exit;
  L := FSession.AddCommand(Item, Sel);
  if L = nil then
    Exit;
  G := TFmrRibbonGroup(L.LinksOwner);
  if not FExpanded.Contains(G) then
    FExpanded.Add(G);
  if (G.Tab <> nil) and not FExpanded.Contains(G.Tab) then
    FExpanded.Add(G.Tab);
  FillTree(L);
  FillCommands(FRCmd, False);
end;

procedure TFmrRibbonCustomizeForm.RibbonRemoveClick(Sender: TObject);
var
  Sel, Next: TObject;
  Index: Integer;
begin
  Sel := TreeSelection;
  if not FSession.CanRemove(Sel) then
    Exit;
  // The row above (usually the parent or the previous sibling) gets the selection.
  Index := FTree.ItemIndex;
  Next := nil;
  if Index > 0 then
    Next := FTree.Row(Index - 1).Data;
  FExpanded.Remove(Sel);
  FSession.Remove(Sel);
  FillTree(Next);
  FillCommands(FRCmd, False);
end;

procedure TFmrRibbonCustomizeForm.RibbonMove(const ADelta: Integer);
var
  Sel: TObject;
begin
  Sel := TreeSelection;
  if not FSession.CanMove(Sel, ADelta) then
    Exit;
  FSession.Move(Sel, ADelta);
  if (Sel is TFmrRibbonGroup) and (TFmrRibbonGroup(Sel).Tab <> nil) and
    not FExpanded.Contains(TFmrRibbonGroup(Sel).Tab) then
    FExpanded.Add(TFmrRibbonGroup(Sel).Tab);
  FillTree(Sel);
end;

procedure TFmrRibbonCustomizeForm.RibbonUpClick(Sender: TObject);
begin
  RibbonMove(-1);
end;

procedure TFmrRibbonCustomizeForm.RibbonDownClick(Sender: TObject);
begin
  RibbonMove(1);
end;

procedure TFmrRibbonCustomizeForm.NewTabClick(Sender: TObject);
var
  G: TFmrRibbonGroup;
begin
  G := FSession.NewTab(TreeSelection);
  FExpanded.Add(G.Tab);
  FExpanded.Add(G);
  if FFilter = TFmrTabsFilter.Tool then
    FFilter := TFmrTabsFilter.All;
  FillTree(G);
  FillCommands(FRCmd, False);
end;

procedure TFmrRibbonCustomizeForm.NewGroupClick(Sender: TObject);
var
  G: TFmrRibbonGroup;
begin
  if TabOfSelection = nil then
    Exit;
  G := FSession.NewGroup(TreeSelection);
  if not FExpanded.Contains(G.Tab) then
    FExpanded.Add(G.Tab);
  FExpanded.Add(G);
  FillTree(G);
end;

procedure TFmrRibbonCustomizeForm.RenameClick(Sender: TObject);
var
  Sel: TObject;
  Caption: string;
  Code: Cardinal;
  WithSymbols: Boolean;
begin
  Sel := TreeSelection;
  if not FSession.CanRename(Sel) then
    Exit;
  Caption := FSession.CaptionOf(Sel);
  WithSymbols := (Sel is TFmrRibbonGroup) and TFmrRibbonGroup(Sel).IsUserDefined;
  Code := 0;
  if WithSymbols then
    Code := TFmrRibbonGroup(Sel).Glyph.GlyphCode;
  if not TFmrRenameForm.Execute(FTheme, Caption, WithSymbols, Code) then
    Exit;
  FSession.Rename(Sel, Caption);
  if WithSymbols then
    FSession.SetGroupGlyph(TFmrRibbonGroup(Sel), Code);
  FillTree(Sel);
  FillCommands(FRCmd, False);
end;

procedure TFmrRibbonCustomizeForm.ResetClick(Sender: TObject);
var
  Menu: TFmrTempMenu;
  T: TFmrRibbonTab;
begin
  Menu := TFmrTempMenu.Create;
  T := TabOfSelection;
  Menu.AddCommand(FmrStr(TFmrStringId.CustResetTab),
    procedure
    begin
      if T <> nil then
      begin
        FSession.ResetTab(T);
        FillTree(T);
        FillCommands(FRCmd, False);
      end;
    end, False, False, FSession.CanResetTab(T));
  Menu.AddCommand(FmrStr(TFmrStringId.CustResetAll),
    procedure
    begin
      if Confirm(FmrStr(TFmrStringId.CustResetConfirm)) then
      begin
        FSession.ResetAll;
        FExpanded.Clear;
        RefreshAll;
      end;
    end);
  ShowMenu(FRReset, Menu);
end;

procedure TFmrRibbonCustomizeForm.DoImport;
var
  Dlg: TOpenDialog;
  FileName: string;
begin
  FileName := AutoFileName;
  if FileName = '' then
  begin
    Dlg := TOpenDialog.Create(nil);
    try
      Dlg.Filter := FmrStr(TFmrStringId.CustFileFilter);
      Dlg.DefaultExt := 'json';
      if not Dlg.Execute then
        Exit;
      FileName := Dlg.FileName;
    finally
      Dlg.Free;
    end;
  end;
  try
    FSession.LoadFromFile(FileName);
  except
    on E: Exception do
    begin
      ShowError(FmrFmt(TFmrStringId.CustImportError, [E.Message]));
      Exit;
    end;
  end;
  FExpanded.Clear;
  RefreshAll;
end;

procedure TFmrRibbonCustomizeForm.DoExport;
var
  Dlg: TSaveDialog;
  FileName: string;
begin
  FileName := AutoFileName;
  if FileName = '' then
  begin
    Dlg := TSaveDialog.Create(nil);
    try
      Dlg.Filter := FmrStr(TFmrStringId.CustFileFilter);
      Dlg.DefaultExt := 'json';
      Dlg.FileName := 'Ribbon customizations.json';
      if not Dlg.Execute then
        Exit;
      FileName := Dlg.FileName;
    finally
      Dlg.Free;
    end;
  end;
  FSession.SaveToFile(FileName);
end;

procedure TFmrRibbonCustomizeForm.ImportExportClick(Sender: TObject);
var
  Menu: TFmrTempMenu;
begin
  Menu := TFmrTempMenu.Create;
  Menu.AddCommand(FmrStr(TFmrStringId.CustImport),
    procedure
    begin
      DoImport;
    end);
  Menu.AddCommand(FmrStr(TFmrStringId.CustExport),
    procedure
    begin
      DoExport;
    end);
  ShowMenu(Sender as TFmrCustButton, Menu);
end;

procedure TFmrRibbonCustomizeForm.FilterClick(Sender: TObject);
var
  Menu: TFmrTempMenu;
  F: TFmrTabsFilter;
  Ids: array[TFmrTabsFilter] of TFmrStringId;
begin
  Ids[TFmrTabsFilter.All] := TFmrStringId.CustAllTabs;
  Ids[TFmrTabsFilter.Main] := TFmrStringId.CustMainTabs;
  Ids[TFmrTabsFilter.Tool] := TFmrStringId.CustToolTabs;
  Menu := TFmrTempMenu.Create;
  for F := Low(TFmrTabsFilter) to High(TFmrTabsFilter) do
    Menu.AddCommand(FmrStr(Ids[F]),
      procedure
      begin
        FFilter := F;
        FRFilter.Caption := FmrStr(Ids[F]);
        FillTree(TreeSelection);
      end, F = FFilter);
  ShowMenu(FRFilter, Menu);
end;

{ quick access toolbar }

procedure TFmrRibbonCustomizeForm.FillQAT(const ASelectIndex: Integer; const ASeparator: Boolean);
var
  Links: TFmrItemLinks;
  I, Index: Integer;
  L: TFmrItemLink;
  Row: TFmrCustRow;
  SelLink: TObject;
begin
  Links := FSession.QuickAccessToolbar.ItemLinks;
  SelLink := nil;
  if (ASelectIndex >= 0) and (ASelectIndex < Links.Count) then
    SelLink := Links[ASelectIndex];
  FQList.Clear;
  for I := 0 to Links.Count - 1 do
  begin
    L := Links[I];
    if L.Item = nil then
      Continue;
    if L.BeginGroup and (I > 0) then
    begin
      Row := TFmrCustRow.Create(FmrStr(TFmrStringId.CustSeparator), L);
      Row.Tag := 1;
      Row.Dim := True;
      FQList.Add(Row);
    end;
    Row := TFmrCustRow.Create(FSession.CaptionOf(L), L, 0, L.Item.Glyph);
    Row.Dim := not L.Visible;
    FQList.Add(Row);
  end;
  FQList.Changed;
  if ASeparator then
    Index := FQList.IndexOfData(SelLink, 1)
  else
    Index := FQList.IndexOfData(SelLink, 0);
  if (Index < 0) and (FQList.Count > 0) then
    Index := Min(Max(0, FQList.ItemIndex), FQList.Count - 1);
  FQList.ItemIndex := Index;
  UpdateQATButtons;
end;

function TFmrRibbonCustomizeForm.QATSelection(out AIndex: Integer; out ASeparator: Boolean): Boolean;
var
  Row: TFmrCustRow;
begin
  AIndex := -1;
  ASeparator := False;
  Result := FQList.SelectedRow(Row) and (Row.Data is TFmrItemLink);
  if Result then
  begin
    AIndex := TFmrItemLink(Row.Data).Index;
    ASeparator := Row.Tag = 1;
  end;
end;

procedure TFmrRibbonCustomizeForm.UpdateQATButtons;
var
  Index: Integer;
  Sep, HasSel: Boolean;
  Row: TFmrCustRow;
  Item: TFmrBarItem;
begin
  if FQList = nil then
    Exit;
  HasSel := QATSelection(Index, Sep);
  Item := SelectedCommand(FQCmd);
  if FQCmd.List.SelectedRow(Row) and (Row.Tag = 1) then
    FQAdd.Enabled := HasSel and not Sep and (Index + 1 < FSession.QuickAccessToolbar.ItemLinks.Count)
  else
    FQAdd.Enabled := FSession.CanAddToQAT(Item);
  FQRemove.Enabled := HasSel;
  FQUp.Enabled := HasSel and not Sep and FSession.CanMoveInQAT(Index, -1);
  FQDown.Enabled := HasSel and not Sep and FSession.CanMoveInQAT(Index, 1);
end;

procedure TFmrRibbonCustomizeForm.QATChange(Sender: TObject);
begin
  UpdateQATButtons;
end;

procedure TFmrRibbonCustomizeForm.QATAddClick(Sender: TObject);
var
  Index: Integer;
  Sep: Boolean;
  Row: TFmrCustRow;
  L: TFmrItemLink;
begin
  if not FQAdd.Enabled then
    Exit;
  if not QATSelection(Index, Sep) then
    Index := FSession.QuickAccessToolbar.ItemLinks.Count - 1;
  if FQCmd.List.SelectedRow(Row) and (Row.Tag = 1) then
  begin
    // "<Separator>": a separator before the command that follows the selection.
    FSession.SetQATSeparator(Index + 1, True);
    FillQAT(Index + 1, True);
    Exit;
  end;
  if not (Row.Data is TFmrBarItem) then
    Exit;
  L := FSession.AddToQAT(TFmrBarItem(Row.Data), Index + 1);
  if L <> nil then
    FillQAT(L.Index);
end;

procedure TFmrRibbonCustomizeForm.QATRemoveClick(Sender: TObject);
var
  Index: Integer;
  Sep: Boolean;
begin
  if not QATSelection(Index, Sep) then
    Exit;
  if Sep then
  begin
    FSession.SetQATSeparator(Index, False);
    FillQAT(Index);
  end
  else
  begin
    FSession.RemoveFromQAT(Index);
    FillQAT(Min(Index, FSession.QuickAccessToolbar.ItemLinks.Count - 1));
  end;
end;

procedure TFmrRibbonCustomizeForm.QATUpClick(Sender: TObject);
var
  Index: Integer;
  Sep: Boolean;
begin
  if QATSelection(Index, Sep) and not Sep and FSession.CanMoveInQAT(Index, -1) then
  begin
    FSession.MoveInQAT(Index, -1);
    FillQAT(Index - 1);
  end;
end;

procedure TFmrRibbonCustomizeForm.QATDownClick(Sender: TObject);
var
  Index: Integer;
  Sep: Boolean;
begin
  if QATSelection(Index, Sep) and not Sep and FSession.CanMoveInQAT(Index, 1) then
  begin
    FSession.MoveInQAT(Index, 1);
    FillQAT(Index + 1);
  end;
end;

procedure TFmrRibbonCustomizeForm.QATResetClick(Sender: TObject);
var
  Menu: TFmrTempMenu;
begin
  Menu := TFmrTempMenu.Create;
  Menu.AddCommand(FmrStr(TFmrStringId.CustResetQAT),
    procedure
    begin
      FSession.ResetQAT;
      RefreshAll;
    end, False, False, FSession.DefaultLayout <> '');
  Menu.AddCommand(FmrStr(TFmrStringId.CustResetAll),
    procedure
    begin
      if Confirm(FmrStr(TFmrStringId.CustResetConfirm)) then
      begin
        FSession.ResetAll;
        FExpanded.Clear;
        RefreshAll;
      end;
    end);
  ShowMenu(FQReset, Menu);
end;

procedure TFmrRibbonCustomizeForm.QATBelowChange(Sender: TObject);
begin
  FSession.QATBelow := FQBelow.Checked;
end;

function TFmrRibbonCustomizeForm.DebugDump: string;
var
  SB: TStringBuilder;
  S: Single;
  Origin: TPointF;

  // Centers in physical pixels relative to the main form window (the coordinates of tools\drive.ps1).
  procedure Line(const AName: string; const C: TControl);
  var
    TL, BR: TPointF;
  begin
    if (C = nil) or not C.ParentedVisible then
      Exit;
    TL := C.LocalToScreen(PointF(0, 0));
    BR := C.LocalToScreen(PointF(C.Width, C.Height));
    SB.AppendLine(Format('%s %.0f,%.0f enabled=%s', [AName, (TL.X + BR.X) / 2 * S - Origin.X,
      (TL.Y + BR.Y) / 2 * S - Origin.Y, BoolToStr(C.Enabled, True)]));
  end;

  procedure Rows(const AName: string; const L: TFmrCustList);
  var
    K: Integer;
    R: TRectF;
  begin
    if not L.ParentedVisible then
      Exit;
    for K := 0 to Min(L.Count, 60) - 1 do
    begin
      R := L.RowScreenRect(K);
      SB.AppendLine(Format('%s[%d] %.0f,%.0f %s', [AName, K, (R.Left + 40) * S - Origin.X,
        R.CenterPoint.Y * S - Origin.Y, L.Row(K).Caption]));
    end;
  end;

{$IFDEF MSWINDOWS}
var
  WR: TRect;
{$ENDIF}
begin
  S := Handle.Scale;
  Origin := TPointF.Zero;
  {$IFDEF MSWINDOWS}
  if (Application.MainForm <> nil) and GetWindowRect(FormToHWND(Application.MainForm), WR) then
    Origin := PointF(WR.Left, WR.Top);
  {$ENDIF}
  SB := TStringBuilder.Create;
  try
    SB.AppendLine(Format('form %d %d %d %d scale=%.2f', [Left, Top, Left + Width, Top + Height, S]));
    Line('nav', FNav);
    Line('ok', FOK);
    Line('cancel', FCancel);
    Line('r.source', FRCmd.SourceButton);
    Line('r.search', FRCmd.Search);
    Line('r.commands', FRCmd.List);
    Line('r.add', FRAdd);
    Line('r.remove', FRRemove);
    Line('r.filter', FRFilter);
    Line('r.tree', FTree);
    Line('r.up', FRUp);
    Line('r.down', FRDown);
    Line('r.newtab', FRNewTab);
    Line('r.newgroup', FRNewGroup);
    Line('r.rename', FRRename);
    Line('r.reset', FRReset);
    Line('r.importexport', FRImport);
    Line('q.source', FQCmd.SourceButton);
    Line('q.search', FQCmd.Search);
    Line('q.commands', FQCmd.List);
    Line('q.add', FQAdd);
    Line('q.remove', FQRemove);
    Line('q.list', FQList);
    Line('q.up', FQUp);
    Line('q.down', FQDown);
    Line('q.reset', FQReset);
    Line('q.importexport', FQImport);
    Line('q.below', FQBelow);
    Rows('r.commands', FRCmd.List);
    Rows('r.tree', FTree);
    Rows('q.commands', FQCmd.List);
    Rows('q.list', FQList);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ TFmrRenameForm }

class function TFmrRenameForm.Execute(const ATheme: TFmrCustTheme; var ACaption: string;
  const AWithSymbols: Boolean; var ACode: Cardinal): Boolean;
var
  F: TFmrRenameForm;
begin
  F := TFmrRenameForm.CreateRename(ATheme, ACaption, AWithSymbols, ACode);
  try
    Result := F.ShowModal = mrOk;
    if Result then
    begin
      ACaption := F.FEdit.Text;
      if AWithSymbols then
        ACode := F.FGrid.SelectedCode;
    end;
  finally
    F.Free;
  end;
end;

constructor TFmrRenameForm.CreateRename(const ATheme: TFmrCustTheme; const ACaption: string;
  const AWithSymbols: Boolean; const ACode: Cardinal);
var
  Y: Single;
  L: TControl;
  I: Integer;
  Codes: TArray<Cardinal>;
begin
  inherited CreateNew(nil);
  FTheme := ATheme;
  FParentForm := Screen.ActiveForm;
  Caption := FmrStr(TFmrStringId.CustRenameCaption);
  BorderStyle := TFmxFormBorderStyle.Single;
  BorderIcons := [TBorderIcon.biSystemMenu];
  Position := TFormPosition.MainFormCenter;
  PrepareThemedForm(Self, ATheme);
  Width := 420;
  Y := 14;
  if AWithSymbols then
  begin
    L := FmrCustLabel(Self, Self, ATheme, FmrStr(TFmrStringId.CustSymbol));
    L.SetBounds(16, Y, 380, 20);
    Y := Y + 24;
    FGrid := TFmrCustSymbolGrid.CreateThemed(Self, Self, ATheme);
    SetLength(Codes, Length(SymbolCodes));
    for I := 0 to High(SymbolCodes) do
      Codes[I] := SymbolCodes[I];
    FGrid.Codes := Codes;
    FGrid.SetBounds(16, Y, 30 * 12 + 4, 30 * 4 + 4);
    FGrid.SelectCode(ACode);
    Y := Y + FGrid.Height + 12;
  end;
  L := FmrCustLabel(Self, Self, ATheme, FmrStr(TFmrStringId.CustDisplayName));
  L.SetBounds(16, Y, 380, 20);
  Y := Y + 24;
  FEdit := NewEdit(Self, Self, ATheme, '');
  FEdit.Text := ACaption;
  FEdit.SetBounds(16, Y, 380, FEdit.Height);
  FEdit.OnKeyDown := EditKey;
  Y := Y + FEdit.Height + 20;
  FCancel := TFmrCustButton.CreateThemed(Self, Self, ATheme);
  FCancel.Caption := FmrStr(TFmrStringId.CommonCancel);
  FCancel.OnClick := CancelClick;
  FCancel.SetBounds(306, Y, 90, FCancel.Height);
  FOK := TFmrCustButton.CreateThemed(Self, Self, ATheme);
  FOK.Caption := FmrStr(TFmrStringId.CommonOK);
  FOK.IsDefault := True;
  FOK.OnClick := OKClick;
  FOK.SetBounds(210, Y, 90, FOK.Height);
  ClientHeight := Round(Y + FOK.Height + 16);
end;

procedure TFmrRenameForm.DoShow;
begin
  inherited;
  PrepareDialogWindow(Self, FParentForm, FTheme.Painter.Theme.Style.Dark);
  FEdit.SetFocus;
  FEdit.SelectAll;
end;

procedure TFmrRenameForm.EditKey(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    Key := 0;
    OKClick(nil);
  end
  else if Key = vkEscape then
  begin
    Key := 0;
    CancelClick(nil);
  end;
end;

procedure TFmrRenameForm.OKClick(Sender: TObject);
begin
  if FEdit.Text.Trim = '' then
    Exit;
  ModalResult := mrOk;
end;

procedure TFmrRenameForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
