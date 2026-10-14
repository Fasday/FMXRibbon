{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: ribbon structure editor                 }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.StructureEditor;

/// Non-modal window with the structure of a ribbon (any IFmrRibbonStructureOwner): quick access toolbar, tabs,
/// contextual tab groups with their tabs, groups, links and the menu links of drop-down items. Add tabs, context
/// groups, groups, new items or links to existing items; delete; move up/down; drag and drop inside the tree
/// (links between groups, the QAT and menus, groups between tabs, tabs) and items from the items editor; rename
/// with F2; edit link properties in the bottom panel; theme of the ribbon; templates.
///
/// Selection: tabs, groups and context groups are selected in the Object Inspector; a link selects its item (as in
/// DevExpress, so caption and glyph are at hand); the properties of the link itself are in the bottom panel ("Link
/// in Inspector" selects the TFmrItemLink collection item).

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.ImgList, Vcl.Menus, Vcl.Dialogs, Vcl.ToolWin, FMX.Types, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Images,
  FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Design.Bridge, FMR.Ribbon.Design.Window;

type
  TFmrStructureEditorForm = class(TFmrDesignWindow)
  private type
    TNodeInfo = record
      Level: Integer;
      Obj: TObject;
      Text: string;
      Image: Integer;
    end;

    TDropKind = (None, Link, Group, Tab);

    TDropTarget = record
      Kind: TDropKind;
      Links: TFmrItemLinks;
      Tab: TFmrRibbonTab;
      Index: Integer;
      ContextGroup: TFmrRibbonContextGroup;
      ContextGroupSet: Boolean;
    end;
  private
    FRibbon: TFmxObject;
    FTree: TTreeView;
    FImages: TImageList;
    FToolImages: TImageList;
    FToolBar, FToolBar2: TToolBar;
    FBtnItem, FBtnLink, FBtnQAT, FBtnDelete, FBtnUp, FBtnDown: TToolButton;
    FNewMenu: TPopupMenu;
    FTreeMenu: TPopupMenu;
    FThemeCombo: TComboBox;
    FLinkPanel: TPanel;
    FChkBeginGroup, FChkVisible, FChkDefault, FChkLarge, FChkSmallText, FChkSmall: TCheckBox;
    FCmbButtonGroup: TComboBox;
    FEdKeyTip: TEdit;
    FStatus: TStatusBar;
    FTimer: TTimer;
    FSignature: string;
    FDirty: Boolean;
    FSelecting: Boolean;
    FUpdatingPanel: Boolean;
    FDragNodes: TArray<TObject>;
    FDragStart: TPoint;
    FMouseDown: Boolean;
    FBaseImageCount: Integer;
    FGlyphImages: TDictionary<Cardinal, Integer>;
    FIconSize: Integer;
    procedure BuildControls;
    function NewCheck(const AParent: TWinControl; const ACaption: string; var ALeft: Integer): TCheckBox;
    { tree }
    procedure CollectNodes(const AList: TList<TNodeInfo>);
    procedure AddLinkNodes(const AList: TList<TNodeInfo>; const ALinks: TFmrItemLinks; const ALevel: Integer);
    function LinkText(const ALink: TFmrItemLink): string;
    function LinkImage(const ALink: TFmrItemLink): Integer;
    procedure ScheduleRefresh;
    procedure TimerTick(Sender: TObject);
    procedure RefreshTree;
    procedure EnsureFresh;
    function SelectedObjects: TArray<TObject>;
    function SelectedObject: TObject;
    procedure SelectTreeObjects(const AObjects: TArray<TObject>; const AFocus: Boolean = True);
    function FindNode(const AObj: TObject): TTreeNode;
    function ManagerOrNil: TFmrBarManager;
    function TargetTab: TFmrRibbonTab;
    function TargetLinks(out AIndex: Integer): TFmrItemLinks;
    function CategoryFor(const ALinks: TFmrItemLinks): string;
    procedure AfterChange(const ASelect: TArray<TObject>);
    { actions }
    procedure AddTabClick(Sender: TObject);
    procedure AddContextGroupClick(Sender: TObject);
    procedure AddGroupClick(Sender: TObject);
    procedure NewItemClick(Sender: TObject);
    procedure NewButtonClick(Sender: TObject);
    procedure AddExistingClick(Sender: TObject);
    procedure AddToQATClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure MoveUpClick(Sender: TObject);
    procedure MoveDownClick(Sender: TObject);
    procedure MoveSelected(const ADelta: Integer);
    procedure TemplateClick(Sender: TObject);
    procedure ExpandClick(Sender: TObject);
    procedure CollapseClick(Sender: TObject);
    procedure ThemeChange(Sender: TObject);
    procedure LinkInInspectorClick(Sender: TObject);
    { link panel }
    procedure UpdateLinkPanel;
    procedure LinkPanelChange(Sender: TObject);
    { tree events }
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
    procedure TreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TreeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TreeDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure TreeDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure TreeEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure TreeDblClick(Sender: TObject);
    function DropTargetAt(const X, Y: Integer; const ASource: TObject): TDropTarget;
    procedure UpdateButtons;
  protected
    procedure DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent); override;
    procedure DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent); override;
    procedure DesignItemsModified(const ARoot: TComponent); override;
    procedure DesignSelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>); override;
  public
    constructor CreateWindow(const ABridge: IFmrDesignBridge; const AKey: TComponent); override;
    destructor Destroy; override;
    property Ribbon: TFmxObject read FRibbon;
    property Tree: TTreeView read FTree;
  end;

/// <summary>Shows (or brings to front) the structure editor of ARibbon (a TFmxObject implementing
/// IFmrRibbonStructureOwner).</summary>
function FmrShowStructureEditor(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): TFmrStructureEditorForm;
/// <summary>Modal list of the items of AManager (with a filter); returns the checked items.</summary>
function FmrPickItems(const AManager: TFmrBarManager; out AItems: TArray<TFmrBarItem>): Boolean;

implementation

uses
  System.Math, System.TypInfo, Winapi.CommCtrl, FMR.Ribbon.Theme, FMR.Ribbon.Design.Graphics,
  FMR.Ribbon.Design.Templates;

const
  ImgRibbon = 0;
  ImgQAT = 1;
  ImgTab = 2;
  ImgContext = 3;
  ImgGroup = 4;
  ImgLink = 5;
  ImgSeparator = 6;

  TbAddTab = 0;
  TbAddContext = 1;
  TbAddGroup = 2;
  TbNewItem = 3;
  TbExisting = 4;
  TbDelete = 5;
  TbUp = 6;
  TbDown = 7;
  TbTemplate = 8;
  TbExpand = 9;
  TbCollapse = 10;
  TbQAT = 11;

function FmrShowStructureEditor(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): TFmrStructureEditorForm;
begin
  Result := TFmrStructureEditorForm(TFmrDesignWindow.FindWindow(TFmrStructureEditorForm, ARibbon));
  if Result = nil then
    Result := TFmrStructureEditorForm.CreateWindow(ABridge, ARibbon);
  Result.Show;
  Result.BringToFront;
end;

{ item picker }

type
  TPickDialog = class(TForm)
  private
    FManager: TFmrBarManager;
    FFilter: TEdit;
    FList: TListView;
    FChecked: TList<TFmrBarItem>;
    procedure Fill;
    procedure FilterChange(Sender: TObject);
    procedure ListItemChecked(Sender: TObject; Item: TListItem);
  public
    constructor CreatePicker(const AManager: TFmrBarManager);
    destructor Destroy; override;
  end;

constructor TPickDialog.CreatePicker(const AManager: TFmrBarManager);
var
  Bottom: TPanel;
  B: TButton;
  Col: TListColumn;
begin
  inherited CreateNew(Application);
  FManager := AManager;
  FChecked := TList<TFmrBarItem>.Create;
  Caption := 'Add Links to Existing Items';
  Position := poScreenCenter;
  BorderIcons := [biSystemMenu];
  Font.Name := 'Segoe UI';
  Font.Height := -12;
  ClientWidth := 460;
  ClientHeight := 420;
  FFilter := TEdit.Create(Self);
  FFilter.Parent := Self;
  FFilter.Align := alTop;
  FFilter.AlignWithMargins := True;
  FFilter.TextHint := 'Filter (caption, name, category)';
  FFilter.OnChange := FilterChange;
  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 42;
  Bottom.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  B.SetBounds(ClientWidth - 92, 8, 80, 26);
  B.Anchors := [akRight, akTop];
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := 'Add';
  B.Default := True;
  B.ModalResult := mrOk;
  B.SetBounds(ClientWidth - 180, 8, 80, 26);
  B.Anchors := [akRight, akTop];
  FList := TListView.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.AlignWithMargins := True;
  FList.ViewStyle := vsReport;
  FList.Checkboxes := True;
  FList.ReadOnly := True;
  FList.RowSelect := True;
  Col := FList.Columns.Add;
  Col.Caption := 'Item';
  Col.Width := 200;
  Col := FList.Columns.Add;
  Col.Caption := 'Name';
  Col.Width := 130;
  Col := FList.Columns.Add;
  Col.Caption := 'Category';
  Col.Width := 90;
  FList.OnItemChecked := ListItemChecked;
  Fill;
  FmrDesignFinishForm(Self);
end;

destructor TPickDialog.Destroy;
begin
  FChecked.Free;
  inherited;
end;

procedure TPickDialog.Fill;
var
  I: Integer;
  Item: TFmrBarItem;
  F: string;
  LI: TListItem;
begin
  F := LowerCase(Trim(FFilter.Text));
  FList.OnItemChecked := nil;
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for I := 0 to FManager.ItemCount - 1 do
    begin
      Item := FManager.Items[I];
      if (F <> '') and (Pos(F, LowerCase(Item.Caption + #1 + Item.Name + #1 + Item.Category)) = 0) then
        Continue;
      LI := FList.Items.Add;
      LI.Caption := FmrDesignStripAccel(Item.Caption);
      LI.SubItems.Add(Item.Name);
      LI.SubItems.Add(Item.Category);
      LI.Data := Item;
      LI.Checked := FChecked.Contains(Item);
    end;
  finally
    FList.Items.EndUpdate;
    FList.OnItemChecked := ListItemChecked;
  end;
end;

procedure TPickDialog.FilterChange(Sender: TObject);
begin
  Fill;
end;

procedure TPickDialog.ListItemChecked(Sender: TObject; Item: TListItem);
var
  B: TFmrBarItem;
begin
  B := TFmrBarItem(Item.Data);
  if Item.Checked then
  begin
    if not FChecked.Contains(B) then
      FChecked.Add(B);
  end
  else
    FChecked.Remove(B);
end;

function FmrPickItems(const AManager: TFmrBarManager; out AItems: TArray<TFmrBarItem>): Boolean;
var
  D: TPickDialog;
  I: Integer;
begin
  AItems := nil;
  D := TPickDialog.CreatePicker(AManager);
  try
    Result := (D.ShowModal = mrOk) and (D.FChecked.Count > 0);
    if Result then
      // Keep the order of the manager.
      for I := 0 to AManager.ItemCount - 1 do
        if D.FChecked.Contains(AManager.Items[I]) then
          AItems := AItems + [AManager.Items[I]];
  finally
    D.Free;
  end;
end;

{ TFmrStructureEditorForm }

constructor TFmrStructureEditorForm.CreateWindow(const ABridge: IFmrDesignBridge; const AKey: TComponent);
begin
  inherited CreateWindow(ABridge, AKey);
  FRibbon := AKey as TFmxObject;
  if not Supports(FRibbon, IFmrRibbonStructureOwner) then
    raise EArgumentException.Create('The structure editor needs a ribbon (IFmrRibbonStructureOwner)');
  FGlyphImages := TDictionary<Cardinal, Integer>.Create;
  Caption := 'Ribbon Structure - ' + FmrDesignObjectName(FRibbon);
  Width := 520;
  Height := 640;
  FIconSize := 16;
  BuildControls;
  RefreshTree;
  if FTree.Items.Count > 0 then
  begin
    FTree.Items[0].Expand(False);
    FTree.Selected := FTree.Items[0];
  end;
  FinishLayout;
end;

destructor TFmrStructureEditorForm.Destroy;
begin
  FGlyphImages.Free;
  inherited;
end;

function TFmrStructureEditorForm.NewCheck(const AParent: TWinControl; const ACaption: string;
  var ALeft: Integer): TCheckBox;
begin
  Result := TCheckBox.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Left := ALeft;
  Result.Top := 4;
  Result.Width := Canvas.TextWidth(ACaption) + 28;
  Result.OnClick := LinkPanelChange;
  Inc(ALeft, Result.Width + 6);
end;

procedure TFmrStructureEditorForm.BuildControls;
var
  Row2: TPanel;
  Info: TFmrItemClassInfo;
  MI: TMenuItem;
  X: Integer;
  Lbl: TLabel;
  Btn: TButton;
  S: string;

  procedure AddMenu(const AMenu: TMenu; const ACaption: string; const AClick: TNotifyEvent;
    const AShortCut: TShortCut = 0);
  var
    Item: TMenuItem;
  begin
    Item := TMenuItem.Create(AMenu);
    Item.Caption := ACaption;
    Item.OnClick := AClick;
    Item.ShortCut := AShortCut;
    AMenu.Items.Add(Item);
  end;

begin
  FIconSize := MulDiv(16, FmrDesignMonitorPPI, 96);
  Canvas.Font := Font;

  FToolImages := TImageList.Create(Self);
  FToolImages.ColorDepth := cd32Bit;
  FToolImages.SetSize(FIconSize, FIconSize);
  FmrAddGlyph(FToolImages, $E7C4, clWindowText); // add tab
  FmrAddGlyph(FToolImages, $E790, clWindowText); // context group
  FmrAddGlyph(FToolImages, $E8A9, clWindowText); // add group
  FmrAddGlyph(FToolImages, $E710, clWindowText); // new item
  FmrAddGlyph(FToolImages, $E71B, clWindowText); // existing item
  FmrAddGlyph(FToolImages, $E74D, clWindowText); // delete
  FmrAddGlyph(FToolImages, $E74A, clWindowText); // up
  FmrAddGlyph(FToolImages, $E74B, clWindowText); // down
  FmrAddGlyph(FToolImages, $E8A5, clWindowText); // template
  FmrAddGlyph(FToolImages, $E70D, clWindowText); // expand
  FmrAddGlyph(FToolImages, $E70E, clWindowText); // collapse
  FmrAddGlyph(FToolImages, $E734, clWindowText); // QAT

  FImages := TImageList.Create(Self);
  FImages.ColorDepth := cd32Bit;
  FImages.SetSize(FIconSize, FIconSize);
  FmrAddGlyph(FImages, $E80F, $009A572B);     // ribbon
  FmrAddGlyph(FImages, $E734, $00007ACC);     // QAT
  FmrAddGlyph(FImages, $E7C4, $009A572B);     // tab
  FmrAddGlyph(FImages, $E790, $002A47B7);     // context group
  FmrAddGlyph(FImages, $E8A9, $00787878);     // group
  FmrAddGlyph(FImages, $E815, clGrayText);    // link without glyph
  FmrAddGlyph(FImages, $E738, clGrayText);    // separator
  FBaseImageCount := FImages.Count;

  FNewMenu := TPopupMenu.Create(Self);
  for Info in FmrDesignItemClasses do
  begin
    MI := TMenuItem.Create(FNewMenu);
    MI.Caption := 'New ' + Info.Caption;
    MI.Tag := NativeInt(Info.ItemClass);
    MI.OnClick := NewItemClick;
    FNewMenu.Items.Add(MI);
  end;

  // Two fixed rows (wrapping toolbars keep their 96 dpi rows after scaling).
  FToolBar2 := NewToolBar(Self, FToolImages);
  FToolBar2.Wrapable := False;
  FToolBar := NewToolBar(Self, FToolImages);
  FToolBar.Wrapable := False;
  FToolBar.Top := 0;
  NewToolButton(FToolBar, 'Tab', 'Add a tab', TbAddTab, AddTabClick);
  NewToolButton(FToolBar, 'Context', 'Add a contextual tab group', TbAddContext, AddContextGroupClick);
  NewToolButton(FToolBar, 'Group', 'Add a group to the selected tab', TbAddGroup, AddGroupClick);
  FBtnItem := NewToolButton(FToolBar, 'Item', 'New button in the selected group (the arrow: other item classes)',
    TbNewItem, NewButtonClick, tbsDropDown);
  FBtnItem.DropdownMenu := FNewMenu;
  FBtnLink := NewToolButton(FToolBar, 'Link', 'Add links to existing items', TbExisting, AddExistingClick);
  FBtnQAT := NewToolButton(FToolBar, 'QAT', 'Add the selected items to the quick access toolbar', TbQAT,
    AddToQATClick);
  FBtnDelete := NewToolButton(FToolBar2, 'Delete', 'Delete (Del)', TbDelete, DeleteClick);
  FBtnUp := NewToolButton(FToolBar2, 'Up', 'Move up (Ctrl+Up)', TbUp, MoveUpClick);
  FBtnDown := NewToolButton(FToolBar2, 'Down', 'Move down (Ctrl+Down)', TbDown, MoveDownClick);
  NewToolButton(FToolBar2, 'Expand', 'Expand all', TbExpand, ExpandClick);
  NewToolButton(FToolBar2, 'Collapse', 'Collapse all', TbCollapse, CollapseClick);
  NewToolButton(FToolBar2, 'Template', 'Apply a template (Word-like, Excel-like, simple)...', TbTemplate,
    TemplateClick);

  Row2 := TPanel.Create(Self);
  Row2.Parent := Self;
  Row2.Align := alTop;
  Row2.Top := FToolBar2.Top + FToolBar2.Height + 1;
  Row2.Height := 30;
  Row2.BevelOuter := bvNone;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Row2;
  Lbl.Caption := 'Theme:';
  Lbl.SetBounds(8, 8, 44, 16);
  FThemeCombo := TComboBox.Create(Self);
  FThemeCombo.Parent := Row2;
  FThemeCombo.Style := csDropDownList;
  FThemeCombo.SetBounds(56, 4, 200, 22);
  for S in TFmrTheme.ThemeNames do
    FThemeCombo.Items.Add(S);
  FThemeCombo.Enabled := IsPublishedProp(FRibbon, 'Theme');
  if FThemeCombo.Enabled then
    FThemeCombo.ItemIndex := FThemeCombo.Items.IndexOf(GetStrProp(FRibbon, 'Theme'));
  FThemeCombo.OnChange := ThemeChange;

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := True;

  FLinkPanel := TPanel.Create(Self);
  FLinkPanel.Parent := Self;
  FLinkPanel.Align := alBottom;
  FLinkPanel.Height := 58;
  FLinkPanel.BevelOuter := bvNone;
  FLinkPanel.Caption := '';
  X := 8;
  FChkBeginGroup := NewCheck(FLinkPanel, 'Begin group', X);
  FChkVisible := NewCheck(FLinkPanel, 'Visible', X);
  Lbl := TLabel.Create(Self);
  Lbl.Parent := FLinkPanel;
  Lbl.Caption := 'Key tip:';
  Lbl.SetBounds(X, 6, 46, 16);
  FEdKeyTip := TEdit.Create(Self);
  FEdKeyTip.Parent := FLinkPanel;
  FEdKeyTip.SetBounds(X + 48, 2, 40, 22);
  FEdKeyTip.CharCase := ecUpperCase;
  FEdKeyTip.MaxLength := 3;
  FEdKeyTip.OnChange := LinkPanelChange;
  Btn := TButton.Create(Self);
  Btn.Parent := FLinkPanel;
  Btn.Caption := 'Link in Inspector';
  Btn.SetBounds(X + 96, 1, 120, 24);
  Btn.OnClick := LinkInInspectorClick;
  X := 8;
  FChkDefault := NewCheck(FLinkPanel, 'Default sizes', X);
  FChkLarge := NewCheck(FLinkPanel, 'Large', X);
  FChkSmallText := NewCheck(FLinkPanel, 'Small + text', X);
  FChkSmall := NewCheck(FLinkPanel, 'Small', X);
  FChkDefault.Top := 30;
  FChkLarge.Top := 30;
  FChkSmallText.Top := 30;
  FChkSmall.Top := 30;
  FCmbButtonGroup := TComboBox.Create(Self);
  FCmbButtonGroup.Parent := FLinkPanel;
  FCmbButtonGroup.Style := csDropDownList;
  FCmbButtonGroup.Items.CommaText := '"No button group","Starts a button group","In the button group"';
  FCmbButtonGroup.SetBounds(X, 28, 150, 22);
  FCmbButtonGroup.OnChange := LinkPanelChange;
  FLinkPanel.Visible := False;

  FTreeMenu := TPopupMenu.Create(Self);
  AddMenu(FTreeMenu, 'Add Tab', AddTabClick);
  AddMenu(FTreeMenu, 'Add Contextual Tab Group', AddContextGroupClick);
  AddMenu(FTreeMenu, 'Add Group', AddGroupClick);
  AddMenu(FTreeMenu, 'New Button', NewButtonClick, ShortCut(VK_INSERT, []));
  AddMenu(FTreeMenu, 'Add Links to Existing Items...', AddExistingClick);
  AddMenu(FTreeMenu, 'Add to Quick Access Toolbar', AddToQATClick);
  AddMenu(FTreeMenu, '-', nil);
  AddMenu(FTreeMenu, 'Delete', DeleteClick, ShortCut(VK_DELETE, []));
  AddMenu(FTreeMenu, 'Move Up', MoveUpClick, ShortCut(VK_UP, [ssCtrl]));
  AddMenu(FTreeMenu, 'Move Down', MoveDownClick, ShortCut(VK_DOWN, [ssCtrl]));
  AddMenu(FTreeMenu, '-', nil);
  AddMenu(FTreeMenu, 'Link in Inspector', LinkInInspectorClick);

  FTree := TTreeView.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.Images := FImages;
  FTree.HideSelection := False;
  FTree.ReadOnly := False;
  FTree.RightClickSelect := True;
  FTree.MultiSelect := True;
  FTree.MultiSelectStyle := [msControlSelect, msShiftSelect];
  FTree.PopupMenu := FTreeMenu;
  FTree.DragMode := dmManual;
  FTree.OnChange := TreeChange;
  FTree.OnKeyDown := TreeKeyDown;
  FTree.OnEditing := TreeEditing;
  FTree.OnEdited := TreeEdited;
  FTree.OnMouseDown := TreeMouseDown;
  FTree.OnMouseMove := TreeMouseMove;
  FTree.OnDragOver := TreeDragOver;
  FTree.OnDragDrop := TreeDragDrop;
  FTree.OnEndDrag := TreeEndDrag;
  FTree.OnDblClick := TreeDblClick;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 30;
  FTimer.OnTimer := TimerTick;
end;

{ tree content }

function TFmrStructureEditorForm.LinkText(const ALink: TFmrItemLink): string;
begin
  if ALink.Item = nil then
    Result := '(no item)'
  else if ALink.Item is TFmrSeparatorItem then
  begin
    Result := '-- ' + ALink.Caption;
    Result := Result.Trim;
  end
  else
  begin
    Result := FmrDesignStripAccel(ALink.Caption);
    if Result = '' then
      Result := '(' + ALink.Item.Name + ')';
  end;
  if ALink.BeginGroup then
    Result := '| ' + Result;
  if not ALink.Visible then
    Result := Result + '  [hidden]';
end;

function TFmrStructureEditorForm.LinkImage(const ALink: TFmrItemLink): Integer;
var
  Src: TFmrImageSource;
  Item: TFmrBarItem;
  Key: Cardinal;
begin
  Item := ALink.Item;
  if Item = nil then
    Exit(ImgLink);
  if Item is TFmrSeparatorItem then
    Exit(ImgSeparator);
  Src := Item.Glyph;
  if (Src.EffectiveKind <> TFmrImageKind.Glyph) and (Item.LargeGlyph.EffectiveKind = TFmrImageKind.Glyph) then
    Src := Item.LargeGlyph;
  if (Src.EffectiveKind = TFmrImageKind.Glyph) and (Src.GlyphCode <> 0) and (Src.GlyphFontFamily = '') then
  begin
    Key := Src.GlyphCode;
    if not FGlyphImages.TryGetValue(Key, Result) then
    begin
      Result := FmrAddGlyph(FImages, Key, clWindowText);
      FGlyphImages.Add(Key, Result);
    end;
    Exit;
  end;
  Key := FmrDesignItemClassInfo(Item.ClassType).Glyph or $80000000;
  if not FGlyphImages.TryGetValue(Key, Result) then
  begin
    Result := FmrAddGlyph(FImages, Key and $7FFFFFFF, clGrayText);
    FGlyphImages.Add(Key, Result);
  end;
end;

procedure TFmrStructureEditorForm.AddLinkNodes(const AList: TList<TNodeInfo>; const ALinks: TFmrItemLinks;
  const ALevel: Integer);
var
  I: Integer;
  L: TFmrItemLink;
  N: TNodeInfo;
  Sub: TFmrItemLinks;
begin
  if ALinks = nil then
    Exit;
  for I := 0 to ALinks.Count - 1 do
  begin
    L := ALinks[I];
    N.Level := ALevel;
    N.Obj := L;
    N.Text := LinkText(L);
    N.Image := LinkImage(L);
    AList.Add(N);
    // Menu content of drop-down items (depth limited: indirect cycles are possible).
    if (L.Item <> nil) and (ALevel < 6) then
    begin
      Sub := nil;
      if L.Item is TFmrSubItem then
        Sub := TFmrSubItem(L.Item).ItemLinks
      else if L.Item is TFmrButtonItem then
        Sub := TFmrButtonItem(L.Item).DropDownLinks
      else if L.Item is TFmrGalleryItem then
        Sub := TFmrGalleryItem(L.Item).DropDownLinks;
      if (Sub <> nil) and (Sub.Count > 0) then
        AddLinkNodes(AList, Sub, ALevel + 1);
    end;
  end;
end;

procedure TFmrStructureEditorForm.CollectNodes(const AList: TList<TNodeInfo>);
var
  O: IFmrRibbonStructureOwner;
  N: TNodeInfo;
  T: TFmrRibbonTab;
  C: TFmrRibbonContextGroup;
  Contexts: TArray<TFmrRibbonContextGroup>;
  I: Integer;

  procedure Add(const ALevel: Integer; const AObj: TObject; const AText: string; const AImage: Integer);
  begin
    N.Level := ALevel;
    N.Obj := AObj;
    N.Text := AText;
    N.Image := AImage;
    AList.Add(N);
  end;

  function Cap(const AObj: TFmrRibbonStructureObject): string;
  begin
    Result := FmrDesignStripAccel(AObj.Caption);
    if Result = '' then
      Result := '(' + FmrDesignObjectName(AObj) + ')';
    if not AObj.Visible and not (AObj is TFmrRibbonContextGroup) then
      Result := Result + '  [hidden]';
  end;

  procedure AddTab(const ALevel: Integer; const ATab: TFmrRibbonTab);
  var
    J: Integer;
  begin
    Add(ALevel, ATab, Cap(ATab), ImgTab);
    for J := 0 to ATab.GroupCount - 1 do
    begin
      Add(ALevel + 1, ATab.Groups[J], Cap(ATab.Groups[J]), ImgGroup);
      AddLinkNodes(AList, ATab.Groups[J].ItemLinks, ALevel + 2);
    end;
  end;

begin
  if not Supports(FRibbon, IFmrRibbonStructureOwner, O) then
    Exit;
  Add(0, FRibbon, FmrDesignObjectName(FRibbon), ImgRibbon);
  if O.GetQuickAccessToolbar <> nil then
  begin
    Add(1, O.GetQuickAccessToolbar, 'Quick Access Toolbar', ImgQAT);
    AddLinkNodes(AList, O.GetQuickAccessToolbar.ItemLinks, 2);
  end;
  Contexts := TFmrRibbonStructure.ContextGroups(FRibbon);
  for T in TFmrRibbonStructure.Tabs(FRibbon) do
  begin
    C := T.ContextGroup;
    if C <> nil then
      for I := 0 to High(Contexts) do
        if Contexts[I] = C then
          C := nil;
    // Tabs of a context group of this ribbon are listed under the context group.
    if (T.ContextGroup = nil) or (C <> nil) then
      AddTab(1, T);
  end;
  for C in Contexts do
  begin
    Add(1, C, Cap(C), ImgContext);
    for T in TFmrRibbonStructure.Tabs(FRibbon) do
      if T.ContextGroup = C then
        AddTab(2, T);
  end;
end;

procedure TFmrStructureEditorForm.ScheduleRefresh;
begin
  FTimer.Enabled := False;
  FTimer.Enabled := True;
end;

procedure TFmrStructureEditorForm.TimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  RefreshTree;
end;

procedure TFmrStructureEditorForm.EnsureFresh;
begin
  if FDirty or FTimer.Enabled then
  begin
    FTimer.Enabled := False;
    RefreshTree;
  end;
end;

procedure TFmrStructureEditorForm.RefreshTree;
var
  List: TList<TNodeInfo>;
  Sig: TStringBuilder;
  N: TNodeInfo;
  Signature: string;
  Selected, Expanded: TList<TObject>;
  Stack: TList<TTreeNode>;
  Node: TTreeNode;
  I: Integer;
  Top: TObject;
begin
  // Key is cleared when the ribbon is destroyed (the window is closing then).
  if (Key = nil) or (FRibbon = nil) then
    Exit;
  List := TList<TNodeInfo>.Create;
  Sig := TStringBuilder.Create;
  try
    if FTree.Items.Count = 0 then
    begin
      FImages.BeginUpdate;
      try
        while FImages.Count > FBaseImageCount do
          FImages.Delete(FImages.Count - 1);
      finally
        FImages.EndUpdate;
      end;
      FGlyphImages.Clear;
    end;
    CollectNodes(List);
    for N in List do
      Sig.Append(N.Level).Append(':').Append(IntToHex(NativeUInt(N.Obj), 16)).Append(';');
    Signature := Sig.ToString;
    if (Signature = FSignature) and (FTree.Items.Count = List.Count) then
    begin
      // Same structure: only captions and images may have changed.
      for I := 0 to List.Count - 1 do
      begin
        Node := FTree.Items[I];
        if Node.Text <> List[I].Text then
          Node.Text := List[I].Text;
        if Node.ImageIndex <> List[I].Image then
        begin
          Node.ImageIndex := List[I].Image;
          Node.SelectedIndex := List[I].Image;
        end;
      end;
    end
    else
    begin
      Selected := TList<TObject>.Create;
      Expanded := TList<TObject>.Create;
      Stack := TList<TTreeNode>.Create;
      FSelecting := True;
      try
        Top := nil;
        if FTree.TopItem <> nil then
          Top := TObject(FTree.TopItem.Data);
        // Objects of the old tree may be gone: only their pointers are compared, never dereferenced.
        for I := 0 to FTree.Items.Count - 1 do
        begin
          if FTree.Items[I].Selected then
            Selected.Add(TObject(FTree.Items[I].Data));
          if FTree.Items[I].Expanded then
            Expanded.Add(TObject(FTree.Items[I].Data));
        end;
        FTree.Items.BeginUpdate;
        try
          FTree.Items.Clear;
          for N in List do
          begin
            while Stack.Count > N.Level do
              Stack.Delete(Stack.Count - 1);
            if Stack.Count = 0 then
              Node := FTree.Items.AddObject(nil, N.Text, N.Obj)
            else
              Node := FTree.Items.AddChildObject(Stack.Last, N.Text, N.Obj);
            Node.ImageIndex := N.Image;
            Node.SelectedIndex := N.Image;
            Stack.Add(Node);
          end;
          for I := 0 to FTree.Items.Count - 1 do
            if Expanded.Contains(TObject(FTree.Items[I].Data)) or (FTree.Items[I].Level = 0) or
              (TObject(FTree.Items[I].Data) is TFmrRibbonContextGroup) then
              FTree.Items[I].Expanded := True;
          for I := 0 to FTree.Items.Count - 1 do
            if Selected.Contains(TObject(FTree.Items[I].Data)) then
            begin
              FTree.Items[I].Selected := True;
              FTree.Items[I].MakeVisible;
            end;
          Node := FindNode(Top);
          if Node <> nil then
            FTree.TopItem := Node;
        finally
          FTree.Items.EndUpdate;
        end;
      finally
        FSelecting := False;
        Stack.Free;
        Expanded.Free;
        Selected.Free;
      end;
      FSignature := Signature;
    end;
  finally
    Sig.Free;
    List.Free;
  end;
  FDirty := False;
  if FThemeCombo.Enabled then
  begin
    I := FThemeCombo.Items.IndexOf(GetStrProp(FRibbon, 'Theme'));
    if I <> FThemeCombo.ItemIndex then
      FThemeCombo.ItemIndex := I;
  end;
  UpdateLinkPanel;
  UpdateButtons;
end;

function TFmrStructureEditorForm.FindNode(const AObj: TObject): TTreeNode;
var
  I: Integer;
begin
  if AObj <> nil then
    for I := 0 to FTree.Items.Count - 1 do
      if TObject(FTree.Items[I].Data) = AObj then
        Exit(FTree.Items[I]);
  Result := nil;
end;

function TFmrStructureEditorForm.SelectedObjects: TArray<TObject>;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FTree.SelectionCount - 1 do
    Result := Result + [TObject(FTree.Selections[I].Data)];
  if (Result = nil) and (FTree.Selected <> nil) then
    Result := [TObject(FTree.Selected.Data)];
end;

function TFmrStructureEditorForm.SelectedObject: TObject;
begin
  if FTree.Selected <> nil then
    Result := TObject(FTree.Selected.Data)
  else
    Result := nil;
end;

procedure TFmrStructureEditorForm.SelectTreeObjects(const AObjects: TArray<TObject>; const AFocus: Boolean);
var
  Nodes: TArray<TTreeNode>;
  Node: TTreeNode;
  O: TObject;
begin
  Nodes := nil;
  for O in AObjects do
  begin
    Node := FindNode(O);
    if Node <> nil then
      Nodes := Nodes + [Node];
  end;
  if Nodes = nil then
    Exit;
  FSelecting := True;
  try
    FTree.ClearSelection;
    FTree.Select(Nodes);
    Nodes[0].MakeVisible;
    if AFocus then
      FTree.Selected := Nodes[0];
  finally
    FSelecting := False;
  end;
end;

function TFmrStructureEditorForm.ManagerOrNil: TFmrBarManager;
begin
  Result := FmrDesignManagerOf(FRibbon);
end;

function TFmrStructureEditorForm.TargetTab: TFmrRibbonTab;
var
  O: TObject;
  P: TPersistent;
  Owner: IFmrRibbonStructureOwner;
begin
  O := SelectedObject;
  if O is TFmrRibbonTab then
    Exit(TFmrRibbonTab(O));
  if O is TFmrRibbonGroup then
    Exit(TFmrRibbonGroup(O).Tab);
  if O is TFmrItemLink then
  begin
    P := TFmrItemLink(O).LinksOwner;
    if P is TFmrRibbonGroup then
      Exit(TFmrRibbonGroup(P).Tab);
  end;
  if Supports(FRibbon, IFmrRibbonStructureOwner, Owner) and (Owner.GetActiveTab <> nil) then
    Exit(Owner.GetActiveTab);
  Result := TFmrRibbonStructure.Tab(FRibbon, 0);
end;

function TFmrStructureEditorForm.TargetLinks(out AIndex: Integer): TFmrItemLinks;
var
  O: TObject;
  Tab: TFmrRibbonTab;
begin
  O := SelectedObject;
  AIndex := -1;
  if O is TFmrItemLink then
  begin
    Result := TFmrItemLinks(TFmrItemLink(O).Collection);
    AIndex := TFmrItemLink(O).Index + 1;
  end
  else if O is TFmrRibbonGroup then
    Result := TFmrRibbonGroup(O).ItemLinks
  else if O is TFmrRibbonQuickAccessToolbar then
    Result := TFmrRibbonQuickAccessToolbar(O).ItemLinks
  else
  begin
    Tab := TargetTab;
    if (Tab <> nil) and (Tab.GroupCount > 0) then
      Result := Tab.Groups[Tab.GroupCount - 1].ItemLinks
    else
      Result := nil;
  end;
  if (Result <> nil) and ((AIndex < 0) or (AIndex > Result.Count)) then
    AIndex := Result.Count;
end;

function TFmrStructureEditorForm.CategoryFor(const ALinks: TFmrItemLinks): string;
var
  P: TPersistent;
begin
  Result := '';
  if ALinks = nil then
    Exit;
  P := ALinks.Owner;
  if (P is TFmrRibbonGroup) and (TFmrRibbonGroup(P).Tab <> nil) then
    Result := FmrDesignStripAccel(TFmrRibbonGroup(P).Tab.Caption)
  else if P is TFmrBarItem then
    Result := TFmrBarItem(P).Category;
end;

procedure TFmrStructureEditorForm.AfterChange(const ASelect: TArray<TObject>);
var
  P: TArray<TPersistent>;
  O: TObject;
begin
  Bridge.Modified;
  FDirty := False;
  RefreshTree;
  if ASelect <> nil then
  begin
    SelectTreeObjects(ASelect);
    P := nil;
    for O in ASelect do
      if O is TFmrItemLink then
      begin
        if TFmrItemLink(O).Item <> nil then
          P := P + [TFmrItemLink(O).Item];
      end
      else if O is TPersistent then
        P := P + [TPersistent(O)];
    if P <> nil then
    begin
      FSelecting := True;
      try
        Bridge.SelectObjects(P);
      finally
        FSelecting := False;
      end;
    end;
  end;
  UpdateLinkPanel;
  UpdateButtons;
end;

{ actions }

procedure TFmrStructureEditorForm.AddTabClick(Sender: TObject);
var
  O: TObject;
  Ctx: TFmrRibbonContextGroup;
  T: TFmrRibbonTab;
begin
  EnsureFresh;
  O := SelectedObject;
  Ctx := nil;
  if O is TFmrRibbonContextGroup then
    Ctx := TFmrRibbonContextGroup(O)
  else if O is TFmrRibbonTab then
    Ctx := TFmrRibbonTab(O).ContextGroup;
  T := FmrDesignNewTab(Bridge, FRibbon, Ctx);
  AfterChange([T]);
end;

procedure TFmrStructureEditorForm.AddContextGroupClick(Sender: TObject);
var
  C: TFmrRibbonContextGroup;
  T: TFmrRibbonTab;
begin
  EnsureFresh;
  C := FmrDesignNewContextGroup(Bridge, FRibbon);
  T := FmrDesignNewTab(Bridge, FRibbon, C);
  AfterChange([T]);
end;

procedure TFmrStructureEditorForm.AddGroupClick(Sender: TObject);
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  Index: Integer;
  O: TObject;
begin
  EnsureFresh;
  T := TargetTab;
  if T = nil then
    T := FmrDesignNewTab(Bridge, FRibbon);
  Index := -1;
  O := SelectedObject;
  if (O is TFmrRibbonGroup) and (TFmrRibbonGroup(O).Tab = T) then
    Index := TFmrRibbonGroup(O).GroupIndex + 1;
  G := FmrDesignNewGroup(Bridge, T, Index);
  AfterChange([G]);
end;

procedure TFmrStructureEditorForm.NewItemClick(Sender: TObject);
var
  Links: TFmrItemLinks;
  Index: Integer;
  Manager: TFmrBarManager;
  Item: TFmrBarItem;
  L: TFmrItemLink;
begin
  EnsureFresh;
  Links := TargetLinks(Index);
  if Links = nil then
  begin
    MessageDlg('Select a group (or a link, or the quick access toolbar) first.', mtInformation, [mbOK], 0);
    Exit;
  end;
  Manager := FmrDesignEnsureManager(Bridge, FRibbon);
  Item := FmrDesignNewItem(Bridge, Manager, TFmrBarItemClass(TMenuItem(Sender).Tag), CategoryFor(Links));
  if not Item.CanLinkInto(Links) then
  begin
    AfterChange([]);
    Exit;
  end;
  L := Links.InsertItem(Index, Item);
  AfterChange([L]);
end;

procedure TFmrStructureEditorForm.NewButtonClick(Sender: TObject);
begin
  NewItemClick(FNewMenu.Items[0]);
end;

procedure TFmrStructureEditorForm.AddExistingClick(Sender: TObject);
var
  Links: TFmrItemLinks;
  Index: Integer;
  Items: TArray<TFmrBarItem>;
  Item: TFmrBarItem;
  Added: TArray<TObject>;
begin
  EnsureFresh;
  Links := TargetLinks(Index);
  if Links = nil then
  begin
    MessageDlg('Select a group (or a link, or the quick access toolbar) first.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (ManagerOrNil = nil) or not FmrPickItems(ManagerOrNil, Items) then
    Exit;
  Added := nil;
  for Item in Items do
    if Item.CanLinkInto(Links) then
    begin
      Added := Added + [Links.InsertItem(Index, Item)];
      Inc(Index);
    end;
  AfterChange(Added);
end;

procedure TFmrStructureEditorForm.AddToQATClick(Sender: TObject);
var
  O: TObject;
  Owner: IFmrRibbonStructureOwner;
  Added: TArray<TObject>;
begin
  EnsureFresh;
  if not Supports(FRibbon, IFmrRibbonStructureOwner, Owner) or (Owner.GetQuickAccessToolbar = nil) then
    Exit;
  Added := nil;
  for O in SelectedObjects do
    if (O is TFmrItemLink) and (TFmrItemLink(O).Item <> nil) then
      Added := Added + [Owner.GetQuickAccessToolbar.AddItem(TFmrItemLink(O).Item)];
  if Added <> nil then
    AfterChange(Added);
end;

procedure TFmrStructureEditorForm.DeleteClick(Sender: TObject);
var
  Objs: TArray<TObject>;
  O: TObject;
  Pass: Integer;
  Next: TObject;
  Node: TTreeNode;
begin
  EnsureFresh;
  Objs := SelectedObjects;
  if Objs = nil then
    Exit;
  Next := nil;
  if FTree.Selected <> nil then
  begin
    Node := FTree.Selected.getNextSibling;
    if Node = nil then
      Node := FTree.Selected.getPrevSibling;
    if Node = nil then
      Node := FTree.Selected.Parent;
    if Node <> nil then
      Next := TObject(Node.Data);
  end;
  FSelecting := True;
  try
    Bridge.SelectObjects([FRibbon]);
    FTree.Items.Clear;
  finally
    FSelecting := False;
  end;
  FSignature := '';
  // Links first (their groups may be deleted too), then groups, tabs and context groups.
  for Pass := 0 to 3 do
    for O in Objs do
      case Pass of
        0:
          if O is TFmrItemLink then
            O.Free;
        1:
          if O is TFmrRibbonGroup then
            O.Free;
        2:
          if O is TFmrRibbonTab then
            O.Free;
        3:
          if O is TFmrRibbonContextGroup then
            O.Free;
      end;
  if Next <> nil then
    for O in Objs do
      if O = Next then
        Next := nil;
  Bridge.Modified;
  RefreshTree;
  if (Next <> nil) and (FindNode(Next) <> nil) then
    SelectTreeObjects([Next]);
end;

procedure TFmrStructureEditorForm.MoveSelected(const ADelta: Integer);
var
  O: TObject;
  L: TFmrItemLink;
  G: TFmrRibbonGroup;
  T: TFmrRibbonTab;
  NewIndex: Integer;
begin
  EnsureFresh;
  O := SelectedObject;
  if O is TFmrItemLink then
  begin
    L := TFmrItemLink(O);
    NewIndex := L.Index + ADelta;
    if (NewIndex >= 0) and (NewIndex < L.Collection.Count) then
      L.Index := NewIndex;
  end
  else if O is TFmrRibbonGroup then
  begin
    G := TFmrRibbonGroup(O);
    NewIndex := G.GroupIndex + ADelta;
    if (G.Tab <> nil) and (NewIndex >= 0) and (NewIndex < G.Tab.GroupCount) then
      TFmrRibbonStructure.MoveGroup(G, G.Tab, NewIndex);
  end
  else if O is TFmrRibbonTab then
  begin
    T := TFmrRibbonTab(O);
    NewIndex := T.TabIndex + ADelta;
    if (NewIndex >= 0) and (NewIndex < TFmrRibbonStructure.TabCount(FRibbon)) then
      TFmrRibbonStructure.MoveTab(T, NewIndex);
  end
  else
    Exit;
  Bridge.Modified;
  RefreshTree;
  SelectTreeObjects([O]);
end;

procedure TFmrStructureEditorForm.MoveUpClick(Sender: TObject);
begin
  MoveSelected(-1);
end;

procedure TFmrStructureEditorForm.MoveDownClick(Sender: TObject);
begin
  MoveSelected(1);
end;

procedure TFmrStructureEditorForm.TemplateClick(Sender: TObject);
begin
  EnsureFresh;
  if FmrDesignRunTemplateWizard(Bridge, FRibbon) then
  begin
    FSignature := '';
    RefreshTree;
    FTree.FullExpand;
    if FTree.Items.Count > 0 then
      FTree.TopItem := FTree.Items[0];
  end;
end;

procedure TFmrStructureEditorForm.ExpandClick(Sender: TObject);
begin
  FTree.FullExpand;
  if FTree.Selected <> nil then
    FTree.Selected.MakeVisible;
end;

procedure TFmrStructureEditorForm.CollapseClick(Sender: TObject);
var
  I: Integer;
begin
  FTree.Items.BeginUpdate;
  try
    for I := 0 to FTree.Items.Count - 1 do
      if FTree.Items[I].Level >= 1 then
        FTree.Items[I].Collapse(False);
  finally
    FTree.Items.EndUpdate;
  end;
end;

procedure TFmrStructureEditorForm.ThemeChange(Sender: TObject);
begin
  if (FThemeCombo.ItemIndex < 0) or not IsPublishedProp(FRibbon, 'Theme') then
    Exit;
  SetStrProp(FRibbon, 'Theme', FThemeCombo.Items[FThemeCombo.ItemIndex]);
  Bridge.Modified;
end;

procedure TFmrStructureEditorForm.LinkInInspectorClick(Sender: TObject);
var
  O: TObject;
begin
  O := SelectedObject;
  if O is TFmrItemLink then
  begin
    FSelecting := True;
    try
      Bridge.SelectObjects([TFmrItemLink(O)]);
    finally
      FSelecting := False;
    end;
  end;
end;

{ link panel }

procedure TFmrStructureEditorForm.UpdateLinkPanel;
var
  O: TObject;
  L: TFmrItemLink;
  Levels: TFmrViewLevels;
  IsDefault: Boolean;
begin
  O := nil;
  if FTree.SelectionCount <= 1 then
    O := SelectedObject;
  if (O is TFmrItemLink) and not FLinkPanel.Visible then
  begin
    // A bottom-aligned control that becomes visible goes where its Top says: keep it above the status bar.
    FLinkPanel.Top := FStatus.Top - FLinkPanel.Height;
    FLinkPanel.Visible := True;
  end
  else if not (O is TFmrItemLink) then
    FLinkPanel.Visible := False;
  if not (O is TFmrItemLink) then
    Exit;
  L := TFmrItemLink(O);
  FUpdatingPanel := True;
  try
    FChkBeginGroup.Checked := L.BeginGroup;
    FChkVisible.Checked := L.Visible;
    IsDefault := L.ViewLevels = [];
    Levels := L.EffectiveViewLevels;
    FChkDefault.Checked := IsDefault;
    FChkLarge.Checked := TFmrViewLevel.Large in Levels;
    FChkSmallText.Checked := TFmrViewLevel.SmallWithText in Levels;
    FChkSmall.Checked := TFmrViewLevel.Small in Levels;
    FChkLarge.Enabled := not IsDefault;
    FChkSmallText.Enabled := not IsDefault;
    FChkSmall.Enabled := not IsDefault;
    FCmbButtonGroup.ItemIndex := Ord(L.ButtonGroup);
    FEdKeyTip.Text := L.KeyTip;
  finally
    FUpdatingPanel := False;
  end;
end;

procedure TFmrStructureEditorForm.LinkPanelChange(Sender: TObject);
var
  O: TObject;
  L: TFmrItemLink;
  Levels: TFmrViewLevels;
begin
  if FUpdatingPanel then
    Exit;
  EnsureFresh;
  O := SelectedObject;
  if not (O is TFmrItemLink) then
    Exit;
  L := TFmrItemLink(O);
  if Sender = FChkBeginGroup then
    L.BeginGroup := FChkBeginGroup.Checked
  else if Sender = FChkVisible then
    L.Visible := FChkVisible.Checked
  else if Sender = FChkDefault then
  begin
    if FChkDefault.Checked then
      L.ViewLevels := []
    else
      L.ViewLevels := L.EffectiveViewLevels;
  end
  else if (Sender = FChkLarge) or (Sender = FChkSmallText) or (Sender = FChkSmall) then
  begin
    Levels := [];
    if FChkLarge.Checked then
      Include(Levels, TFmrViewLevel.Large);
    if FChkSmallText.Checked then
      Include(Levels, TFmrViewLevel.SmallWithText);
    if FChkSmall.Checked then
      Include(Levels, TFmrViewLevel.Small);
    if Levels = [] then
      Levels := [TFmrViewLevel.Small];
    L.ViewLevels := Levels;
  end
  else if Sender = FCmbButtonGroup then
    L.ButtonGroup := TFmrButtonGroupPosition(Max(0, FCmbButtonGroup.ItemIndex))
  else if Sender = FEdKeyTip then
    L.KeyTip := FEdKeyTip.Text;
  Bridge.Modified;
  RefreshTree;
end;

{ tree events }

procedure TFmrStructureEditorForm.UpdateButtons;
var
  O: TObject;
  HasLinks: Boolean;
  Idx: Integer;
begin
  O := SelectedObject;
  HasLinks := TargetLinks(Idx) <> nil;
  FBtnItem.Enabled := HasLinks;
  FBtnLink.Enabled := HasLinks and (ManagerOrNil <> nil);
  FBtnQAT.Enabled := O is TFmrItemLink;
  FBtnDelete.Enabled := (O is TFmrItemLink) or (O is TFmrRibbonGroup) or (O is TFmrRibbonTab) or
    (O is TFmrRibbonContextGroup);
  FBtnUp.Enabled := (O is TFmrItemLink) or (O is TFmrRibbonGroup) or (O is TFmrRibbonTab);
  FBtnDown.Enabled := FBtnUp.Enabled;
  if O is TFmrItemLink then
    FStatus.SimpleText := Format('Link to %s (%s) in %s', [FmrDesignObjectName(TFmrItemLink(O).Item),
      FmrDesignItemClassInfo(TFmrItemLink(O).Item.ClassType).Caption,
      FmrDesignObjectName(TFmrItemLink(O).LinksOwner)])
  else if O is TComponent then
    FStatus.SimpleText := Format('%s: %s', [TComponent(O).Name, O.ClassName])
  else
    FStatus.SimpleText := '';
end;

procedure TFmrStructureEditorForm.TreeChange(Sender: TObject; Node: TTreeNode);
var
  P: TArray<TPersistent>;
  O: TObject;
begin
  if FSelecting then
    Exit;
  UpdateLinkPanel;
  UpdateButtons;
  P := nil;
  for O in SelectedObjects do
    if O is TFmrItemLink then
    begin
      if TFmrItemLink(O).Item <> nil then
        P := P + [TFmrItemLink(O).Item];
    end
    else if O is TFmrRibbonQuickAccessToolbar then
      P := P + [FRibbon]
    else if O is TPersistent then
      P := P + [TPersistent(O)];
  if P = nil then
    Exit;
  FSelecting := True;
  try
    Bridge.SelectObjects(P);
  finally
    FSelecting := False;
  end;
end;

procedure TFmrStructureEditorForm.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FTree.IsEditing then
    Exit;
  case Key of
    VK_DELETE:
      begin
        DeleteClick(nil);
        Key := 0;
      end;
    VK_INSERT:
      begin
        NewButtonClick(nil);
        Key := 0;
      end;
    VK_UP, VK_DOWN:
      if ssCtrl in Shift then
      begin
        if Key = VK_UP then
          MoveSelected(-1)
        else
          MoveSelected(1);
        Key := 0;
      end;
  end;
end;

procedure TFmrStructureEditorForm.TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
var
  O: TObject;
  S: string;
  Edit: HWND;
begin
  O := TObject(Node.Data);
  AllowEdit := (O is TFmrRibbonStructureObject) or ((O is TFmrItemLink) and (TFmrItemLink(O).Item <> nil));
  if not AllowEdit then
    Exit;
  // Edit the plain caption, not the decorated node text (the edit control exists during TVN_BEGINLABELEDIT).
  if O is TFmrRibbonStructureObject then
    S := TFmrRibbonStructureObject(O).Caption
  else
    S := TFmrItemLink(O).Item.Caption;
  Edit := TreeView_GetEditControl(FTree.Handle);
  if Edit <> 0 then
    SetWindowText(Edit, PChar(S));
end;

procedure TFmrStructureEditorForm.TreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
var
  O: TObject;
begin
  O := TObject(Node.Data);
  if O is TFmrRibbonStructureObject then
    TFmrRibbonStructureObject(O).Caption := S
  else if (O is TFmrItemLink) and (TFmrItemLink(O).Item <> nil) then
    TFmrItemLink(O).Item.Caption := S
  else
    Exit;
  Bridge.Modified;
  ScheduleRefresh;
end;

procedure TFmrStructureEditorForm.TreeDblClick(Sender: TObject);
var
  O: TObject;
begin
  O := SelectedObject;
  if (O is TFmrItemLink) and (TFmrItemLink(O).Item <> nil) then
    Bridge.ShowEvent(TFmrItemLink(O).Item, 'OnClick');
end;

procedure TFmrStructureEditorForm.TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  FMouseDown := (Button = mbLeft) and (FTree.GetNodeAt(X, Y) <> nil);
  FDragStart := Point(X, Y);
end;

procedure TFmrStructureEditorForm.TreeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  O: TObject;
  Objs: TArray<TObject>;
begin
  if not FMouseDown or not (ssLeft in Shift) or FTree.IsEditing then
    Exit;
  if (Abs(X - FDragStart.X) <= 4) and (Abs(Y - FDragStart.Y) <= 4) then
    Exit;
  FMouseDown := False;
  Objs := nil;
  for O in SelectedObjects do
    if (O is TFmrItemLink) or (O is TFmrRibbonGroup) or (O is TFmrRibbonTab) then
      Objs := Objs + [O];
  // Only one kind at a time.
  if (Objs = nil) or ((Length(Objs) > 1) and not (Objs[0] is TFmrItemLink)) then
    Exit;
  FDragNodes := Objs;
  FTree.BeginDrag(True);
end;

procedure TFmrStructureEditorForm.TreeEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  FDragNodes := nil;
end;

function TFmrStructureEditorForm.DropTargetAt(const X, Y: Integer; const ASource: TObject): TDropTarget;
var
  Node: TTreeNode;
  R: TRect;
  After: Boolean;
  O, First: TObject;
  P: TPersistent;
begin
  Result := Default(TDropTarget);
  Result.Kind := TDropKind.None;
  Node := FTree.GetNodeAt(X, Y);
  if Node = nil then
    Exit;
  R := Node.DisplayRect(False);
  After := Y > (R.Top + R.Bottom) div 2;
  O := TObject(Node.Data);
  if ASource is TFmrItemDragObject then
    First := nil
  else if (ASource = FTree) and (FDragNodes <> nil) then
    First := FDragNodes[0]
  else
    Exit;

  if (First = nil) or (First is TFmrItemLink) then
  begin
    Result.Kind := TDropKind.Link;
    if O is TFmrItemLink then
    begin
      Result.Links := TFmrItemLinks(TFmrItemLink(O).Collection);
      Result.Index := TFmrItemLink(O).Index + Ord(After);
    end
    else if O is TFmrRibbonGroup then
    begin
      Result.Links := TFmrRibbonGroup(O).ItemLinks;
      Result.Index := Result.Links.Count;
    end
    else if O is TFmrRibbonQuickAccessToolbar then
    begin
      Result.Links := TFmrRibbonQuickAccessToolbar(O).ItemLinks;
      Result.Index := Result.Links.Count;
    end
    else
      Result.Kind := TDropKind.None;
  end
  else if First is TFmrRibbonGroup then
  begin
    Result.Kind := TDropKind.Group;
    if O is TFmrRibbonGroup then
    begin
      Result.Tab := TFmrRibbonGroup(O).Tab;
      Result.Index := TFmrRibbonGroup(O).GroupIndex + Ord(After);
    end
    else if O is TFmrRibbonTab then
    begin
      Result.Tab := TFmrRibbonTab(O);
      Result.Index := -1;
    end
    else if O is TFmrItemLink then
    begin
      P := TFmrItemLink(O).LinksOwner;
      if P is TFmrRibbonGroup then
      begin
        Result.Tab := TFmrRibbonGroup(P).Tab;
        Result.Index := TFmrRibbonGroup(P).GroupIndex + 1;
      end
      else
        Result.Kind := TDropKind.None;
    end
    else
      Result.Kind := TDropKind.None;
    if (Result.Kind = TDropKind.Group) and (Result.Tab = nil) then
      Result.Kind := TDropKind.None;
  end
  else if First is TFmrRibbonTab then
  begin
    Result.Kind := TDropKind.Tab;
    if O is TFmrRibbonTab then
    begin
      Result.Index := TFmrRibbonTab(O).TabIndex + Ord(After);
      Result.ContextGroup := TFmrRibbonTab(O).ContextGroup;
      Result.ContextGroupSet := True;
    end
    else if O is TFmrRibbonContextGroup then
    begin
      Result.Index := TFmrRibbonStructure.TabCount(FRibbon);
      Result.ContextGroup := TFmrRibbonContextGroup(O);
      Result.ContextGroupSet := True;
    end
    else if O = FRibbon then
    begin
      Result.Index := TFmrRibbonStructure.TabCount(FRibbon);
      Result.ContextGroup := nil;
      Result.ContextGroupSet := True;
    end
    else
      Result.Kind := TDropKind.None;
  end;
end;

procedure TFmrStructureEditorForm.TreeDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState;
  var Accept: Boolean);
var
  T: TDropTarget;
  O: TObject;
  Item: TFmrBarItem;
begin
  T := DropTargetAt(X, Y, Source);
  Accept := T.Kind <> TDropKind.None;
  if Accept and (T.Kind = TDropKind.Link) then
  begin
    if Source is TFmrItemDragObject then
    begin
      for Item in TFmrItemDragObject(Source).Items do
        if not Item.CanLinkInto(T.Links) or (Item.Manager <> ManagerOrNil) then
          Accept := False;
    end
    else
      for O in FDragNodes do
        if (TFmrItemLink(O).Item <> nil) and not TFmrItemLink(O).Item.CanLinkInto(T.Links) then
          Accept := False;
  end;
  if Accept and (T.Kind = TDropKind.Group) then
    for O in FDragNodes do
      if O = T.Tab then
        Accept := False;
end;

procedure TFmrStructureEditorForm.TreeDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  T: TDropTarget;
  O: TObject;
  L: TFmrItemLink;
  Item: TFmrBarItem;
  Index: Integer;
  Result: TArray<TObject>;
  Copy: Boolean;
  G: TFmrRibbonGroup;
  Tab: TFmrRibbonTab;
begin
  T := DropTargetAt(X, Y, Source);
  if T.Kind = TDropKind.None then
    Exit;
  Result := nil;
  Index := T.Index;
  case T.Kind of
    TDropKind.Link:
      if Source is TFmrItemDragObject then
      begin
        for Item in TFmrItemDragObject(Source).Items do
          if Item.CanLinkInto(T.Links) then
          begin
            Result := Result + [T.Links.InsertItem(Min(Index, T.Links.Count), Item)];
            Inc(Index);
          end;
      end
      else
      begin
        Copy := GetKeyState(VK_CONTROL) < 0;
        for O in FDragNodes do
        begin
          L := TFmrItemLink(O);
          if Copy then
          begin
            L := TFmrRibbonStructure.CopyLink(L, T.Links, Index);
            Inc(Index);
          end
          else
          begin
            if (L.Collection = T.Links) and (L.Index < Index) then
              Dec(Index);
            if Index >= T.Links.Count then
              TFmrRibbonStructure.MoveLink(L, T.Links, -1)
            else
              TFmrRibbonStructure.MoveLink(L, T.Links, Index);
            Index := L.Index + 1;
          end;
          Result := Result + [L];
        end;
      end;
    TDropKind.Group:
      begin
        G := TFmrRibbonGroup(FDragNodes[0]);
        if (G.Tab = T.Tab) and (Index > G.GroupIndex) then
          Dec(Index);
        TFmrRibbonStructure.MoveGroup(G, T.Tab, Index);
        Result := [G];
      end;
    TDropKind.Tab:
      begin
        Tab := TFmrRibbonTab(FDragNodes[0]);
        if Index > Tab.TabIndex then
          Dec(Index);
        if T.ContextGroupSet then
          Tab.ContextGroup := T.ContextGroup;
        TFmrRibbonStructure.MoveTab(Tab, Index);
        Result := [Tab];
      end;
  end;
  FDragNodes := nil;
  AfterChange(Result);
end;

{ designer events }

procedure TFmrStructureEditorForm.DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent);
begin
  inherited;
  if IsMyRoot(ARoot) and (FRibbon <> nil) and (AItem <> FRibbon) then
  begin
    FDirty := True;
    ScheduleRefresh;
  end;
end;

procedure TFmrStructureEditorForm.DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent);
begin
  if IsMyRoot(ARoot) and (FRibbon <> nil) then
    ScheduleRefresh;
end;

procedure TFmrStructureEditorForm.DesignItemsModified(const ARoot: TComponent);
begin
  if IsMyRoot(ARoot) and (FRibbon <> nil) then
    ScheduleRefresh;
end;

procedure TFmrStructureEditorForm.DesignSelectionChanged(const ARoot: TComponent;
  const AObjects: TArray<TPersistent>);
var
  Objs: TArray<TObject>;
  P: TPersistent;
  O: TObject;
  Cur: TObject;
  I: Integer;
begin
  if not IsMyRoot(ARoot) or FSelecting or (FRibbon = nil) then
    Exit;
  EnsureFresh;
  Objs := nil;
  for P in AObjects do
  begin
    if FindNode(P) <> nil then
    begin
      Objs := Objs + [P];
      Continue;
    end;
    if P is TFmrBarItem then
    begin
      // An item: keep the selected link when it is one of its links, otherwise its first link in the tree.
      Cur := SelectedObject;
      if (Cur is TFmrItemLink) and (TFmrItemLink(Cur).Item = P) then
      begin
        Objs := Objs + [Cur];
        Continue;
      end;
      for I := 0 to FTree.Items.Count - 1 do
      begin
        O := TObject(FTree.Items[I].Data);
        if (O is TFmrItemLink) and (TFmrItemLink(O).Item = P) then
        begin
          Objs := Objs + [O];
          Break;
        end;
      end;
    end;
  end;
  if Objs <> nil then
  begin
    SelectTreeObjects(Objs, False);
    UpdateLinkPanel;
    UpdateButtons;
  end;
end;

end.
