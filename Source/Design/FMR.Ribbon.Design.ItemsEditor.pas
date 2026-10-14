{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: items editor of a bar manager           }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.ItemsEditor;

/// Non-modal window listing the categories and items of a TFmrBarManager: add items of every class, delete,
/// reorder, manage categories (drag items onto a category to move them), select items in the Object Inspector,
/// double click to open the OnClick handler. Items can be dragged into the structure editor (TFmrItemDragObject)
/// and, with the ribbon's design hooks (phase B), onto the ribbon in the form designer.

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.ImgList, Vcl.Menus, Vcl.Dialogs, Vcl.ToolWin, FMR.Bars, FMR.Bars.Images, FMR.Bars.Items,
  FMR.Ribbon.Design.Bridge, FMR.Ribbon.Design.Window;

type
  /// <summary>Drop of bar items outside the VCL windows (onto a ribbon in the form designer). Installed by the
  /// interactive design unit; the items editor calls it while dragging.</summary>
  IFmrExternalItemDrop = interface
    ['{DD75D5B1-F65F-4A80-9F71-E0B26559D959}']
    /// <summary>The drag is over AScreenPoint (VCL screen pixels); True when a target accepts the items there (the
    /// target shows its insertion mark).</summary>
    function ExternalDragOver(const AScreenPoint: TPoint; const AItems: TArray<TFmrBarItem>): Boolean;
    /// <summary>The items were released at AScreenPoint; True when they were dropped.</summary>
    function ExternalDrop(const AScreenPoint: TPoint; const AItems: TArray<TFmrBarItem>): Boolean;
    /// <summary>The drag ended without a drop: hide every insertion mark.</summary>
    procedure ExternalDragCancel;
  end;

  /// <summary>Drag object of the items editor: reports the cursor position to the external drop handler.</summary>
  TFmrItemsEditorDragObject = class(TFmrItemDragObject)
  protected
    function GetDragCursor(Accepted: Boolean; X, Y: Integer): TCursor; override;
  end;

  TFmrItemsEditorForm = class(TFmrDesignWindow)
  private
    FManager: TFmrBarManager;
    FImages: TImageList;
    FToolImages: TImageList;
    FToolBar: TToolBar;
    FNewMenu: TPopupMenu;
    FCategories: TListBox;
    FCatToolBar: TToolBar;
    FList: TListView;
    FStatus: TStatusBar;
    FTimer: TTimer;
    FSelecting: Boolean;
    FDragStart: TPoint;
    FMouseDownInList: Boolean;
    FIconSize: Integer;
    procedure BuildControls;
    procedure ScheduleRefresh;
    procedure TimerTick(Sender: TObject);
    procedure RefreshAll;
    procedure RefreshCategories;
    procedure RefreshItems;
    function SelectedCategory: string;
    function CategoryFilterAll: Boolean;
    function SelectedItems: TArray<TFmrBarItem>;
    procedure SelectItems(const AItems: TArray<TPersistent>);
    function ItemImage(const AItem: TFmrBarItem): Integer;
    procedure NewItemClick(Sender: TObject);
    procedure NewButtonClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure MoveUpClick(Sender: TObject);
    procedure MoveDownClick(Sender: TObject);
    procedure MoveSelected(const ADelta: Integer);
    procedure AddCategoryClick(Sender: TObject);
    procedure RenameCategoryClick(Sender: TObject);
    procedure DeleteCategoryClick(Sender: TObject);
    procedure CategoriesClick(Sender: TObject);
    procedure CategoriesDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure CategoriesDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure ListDblClick(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ListMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ListStartDrag(Sender: TObject; var DragObject: TDragObject);
    procedure ListEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure UpdateButtons;
  protected
    procedure DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent); override;
    procedure DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent); override;
    procedure DesignItemsModified(const ARoot: TComponent); override;
    procedure DesignSelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>); override;
  public
    constructor CreateWindow(const ABridge: IFmrDesignBridge; const AKey: TComponent); override;
    property Manager: TFmrBarManager read FManager;
  end;

var
  /// <summary>Handler of drops outside the editor windows (set by FMR.Ribbon.Design.Interactive).</summary>
  FmrExternalItemDrop: IFmrExternalItemDrop;

/// <summary>Shows (or brings to front) the items editor of AManager.</summary>
function FmrShowItemsEditor(const ABridge: IFmrDesignBridge; const AManager: TFmrBarManager): TFmrItemsEditorForm;

implementation

uses
  System.Math, FMR.Ribbon.Design.Graphics;

const
  SAllItems = '(All items)';
  SNoCategory = '(No category)';
  ImgNew = 0;
  ImgDelete = 1;
  ImgUp = 2;
  ImgDown = 3;
  ImgCategory = 4;
  ImgRename = 5;

function FmrShowItemsEditor(const ABridge: IFmrDesignBridge; const AManager: TFmrBarManager): TFmrItemsEditorForm;
begin
  Result := TFmrItemsEditorForm(TFmrDesignWindow.FindWindow(TFmrItemsEditorForm, AManager));
  if Result = nil then
    Result := TFmrItemsEditorForm.CreateWindow(ABridge, AManager);
  Result.Show;
  Result.BringToFront;
end;

{ TFmrItemsEditorDragObject }

function TFmrItemsEditorDragObject.GetDragCursor(Accepted: Boolean; X, Y: Integer): TCursor;
begin
  // The window under the mouse itself, not its parents: in the IDE the FMX form of the designer is a child window of
  // a VCL control (FindVCLWindow would find that one).
  if not Accepted and (FmrExternalItemDrop <> nil) and (FindControl(WindowFromPoint(Point(X, Y))) = nil) and
    FmrExternalItemDrop.ExternalDragOver(Point(X, Y), Items) then
    Result := crDrag
  else
    Result := inherited GetDragCursor(Accepted, X, Y);
end;

{ TFmrItemsEditorForm }

constructor TFmrItemsEditorForm.CreateWindow(const ABridge: IFmrDesignBridge; const AKey: TComponent);
begin
  inherited CreateWindow(ABridge, AKey);
  FManager := AKey as TFmrBarManager;
  Caption := 'Items - ' + FmrDesignObjectName(FManager);
  Width := 640;
  Height := 480;
  FIconSize := 16;
  BuildControls;
  RefreshAll;
  FinishLayout;
end;

procedure TFmrItemsEditorForm.BuildControls;
var
  Left: TPanel;
  Split: TSplitter;
  Lbl: TLabel;
  Col: TListColumn;
  Info: TFmrItemClassInfo;
  MI: TMenuItem;
  B: TToolButton;
begin
  FIconSize := MulDiv(16, FmrDesignMonitorPPI, 96);

  FToolImages := TImageList.Create(Self);
  FToolImages.ColorDepth := cd32Bit;
  FToolImages.SetSize(FIconSize, FIconSize);
  FmrAddGlyph(FToolImages, $E710, clWindowText);
  FmrAddGlyph(FToolImages, $E74D, clWindowText);
  FmrAddGlyph(FToolImages, $E74A, clWindowText);
  FmrAddGlyph(FToolImages, $E74B, clWindowText);
  FmrAddGlyph(FToolImages, $E8EC, clWindowText);
  FmrAddGlyph(FToolImages, $E8AC, clWindowText);

  FImages := TImageList.Create(Self);
  FImages.ColorDepth := cd32Bit;
  FImages.SetSize(FIconSize, FIconSize);

  FNewMenu := TPopupMenu.Create(Self);
  for Info in FmrDesignItemClasses do
  begin
    MI := TMenuItem.Create(FNewMenu);
    MI.Caption := Info.Caption;
    MI.Tag := NativeInt(Info.ItemClass);
    MI.OnClick := NewItemClick;
    FNewMenu.Items.Add(MI);
  end;

  FToolBar := NewToolBar(Self, FToolImages);
  B := NewToolButton(FToolBar, 'New Button', 'New button item (the arrow: other item classes)', ImgNew,
    NewButtonClick, tbsDropDown);
  B.DropdownMenu := FNewMenu;
  NewToolButton(FToolBar, 'Delete', 'Delete the selected items (Del)', ImgDelete, DeleteClick);
  NewSeparator(FToolBar);
  NewToolButton(FToolBar, 'Up', 'Move the selected items up (Ctrl+Up)', ImgUp, MoveUpClick);
  NewToolButton(FToolBar, 'Down', 'Move the selected items down (Ctrl+Down)', ImgDown, MoveDownClick);

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := True;

  Left := TPanel.Create(Self);
  Left.Parent := Self;
  Left.Align := alLeft;
  Left.Width := 170;
  Left.BevelOuter := bvNone;
  Left.ParentBackground := True;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Left;
  Lbl.Align := alTop;
  Lbl.Caption := 'Categories';
  Lbl.AlignWithMargins := True;

  FCatToolBar := NewToolBar(Left, FToolImages);
  FCatToolBar.Align := alBottom;
  FCatToolBar.ShowCaptions := False;
  FCatToolBar.EdgeBorders := [ebTop];
  NewToolButton(FCatToolBar, '', 'Add a category', ImgCategory, AddCategoryClick);
  NewToolButton(FCatToolBar, '', 'Rename the category (its items follow)', ImgRename, RenameCategoryClick);
  NewToolButton(FCatToolBar, '', 'Delete the category (its items get no category)', ImgDelete, DeleteCategoryClick);

  FCategories := TListBox.Create(Self);
  FCategories.Parent := Left;
  FCategories.Align := alClient;
  FCategories.OnClick := CategoriesClick;
  FCategories.OnDragOver := CategoriesDragOver;
  FCategories.OnDragDrop := CategoriesDragDrop;

  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alLeft;
  Split.Left := Left.Width + 1;
  Split.Width := 4;

  FList := TListView.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.ViewStyle := vsReport;
  FList.ReadOnly := True;
  FList.RowSelect := True;
  FList.MultiSelect := True;
  FList.HideSelection := False;
  FList.SmallImages := FImages;
  FList.DragMode := dmManual;
  Col := FList.Columns.Add;
  Col.Caption := 'Item';
  Col.Width := 220;
  Col := FList.Columns.Add;
  Col.Caption := 'Name';
  Col.Width := 160;
  Col := FList.Columns.Add;
  Col.Caption := 'Type';
  Col.Width := 120;
  Col := FList.Columns.Add;
  Col.Caption := 'Links';
  Col.Width := 50;
  FList.OnSelectItem := ListSelectItem;
  FList.OnDblClick := ListDblClick;
  FList.OnKeyDown := ListKeyDown;
  FList.OnMouseDown := ListMouseDown;
  FList.OnMouseMove := ListMouseMove;
  FList.OnStartDrag := ListStartDrag;
  FList.OnEndDrag := ListEndDrag;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 30;
  FTimer.OnTimer := TimerTick;
end;

procedure TFmrItemsEditorForm.ScheduleRefresh;
begin
  FTimer.Enabled := False;
  FTimer.Enabled := True;
end;

procedure TFmrItemsEditorForm.TimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  RefreshAll;
end;

procedure TFmrItemsEditorForm.RefreshAll;
begin
  // Key is cleared when the manager is destroyed (the window is closing then).
  if (Key = nil) or (FManager = nil) then
    Exit;
  RefreshCategories;
  RefreshItems;
end;

procedure TFmrItemsEditorForm.RefreshCategories;
var
  Old: string;
  OldIndex, I: Integer;
  Names: TStringList;
begin
  OldIndex := FCategories.ItemIndex;
  if OldIndex >= 0 then
    Old := FCategories.Items[OldIndex]
  else
    Old := SAllItems;
  Names := TStringList.Create;
  try
    Names.CaseSensitive := False;
    Names.Duplicates := dupIgnore;
    for I := 0 to FManager.Categories.Count - 1 do
      if (FManager.Categories[I] <> '') and (Names.IndexOf(FManager.Categories[I]) < 0) then
        Names.Add(FManager.Categories[I]);
    for I := 0 to FManager.ItemCount - 1 do
      if (FManager.Items[I].Category <> '') and (Names.IndexOf(FManager.Items[I].Category) < 0) then
        Names.Add(FManager.Items[I].Category);
    FCategories.Items.BeginUpdate;
    try
      FCategories.Items.Clear;
      FCategories.Items.Add(SAllItems);
      FCategories.Items.AddStrings(Names);
      FCategories.Items.Add(SNoCategory);
    finally
      FCategories.Items.EndUpdate;
    end;
  finally
    Names.Free;
  end;
  I := FCategories.Items.IndexOf(Old);
  if I < 0 then
    I := 0;
  FCategories.ItemIndex := I;
end;

function TFmrItemsEditorForm.CategoryFilterAll: Boolean;
begin
  Result := (FCategories.ItemIndex <= 0);
end;

function TFmrItemsEditorForm.SelectedCategory: string;
begin
  if (FCategories.ItemIndex <= 0) or (FCategories.Items[FCategories.ItemIndex] = SNoCategory) then
    Result := ''
  else
    Result := FCategories.Items[FCategories.ItemIndex];
end;

function TFmrItemsEditorForm.ItemImage(const AItem: TFmrBarItem): Integer;
var
  B: Vcl.Graphics.TBitmap;
  Src: TFmrImageSource;
begin
  Src := AItem.Glyph;
  if Src.IsEmpty(FManager.Images) then
    Src := AItem.LargeGlyph;
  if (Src.EffectiveKind = TFmrImageKind.Glyph) and (Src.GlyphCode <> 0) then
    Exit(FmrAddGlyph(FImages, Src.GlyphCode, clWindowText, Src.GlyphFontFamily));
  if not Src.IsEmpty(FManager.Images) then
  begin
    B := FmrRenderImageSource(Src, FManager.Images, FIconSize, TAlphaColors.Black);
    if B <> nil then
    try
      Exit(FmrAddBitmap(FImages, B));
    finally
      B.Free;
    end;
  end;
  Result := FmrAddGlyph(FImages, FmrDesignItemClassInfo(AItem.ClassType).Glyph, clGrayText);
end;

procedure TFmrItemsEditorForm.RefreshItems;
var
  Selected: TArray<TPersistent>;
  I: Integer;
  Item: TFmrBarItem;
  LI: TListItem;
  All, NoCat: Boolean;
  Cat: string;
  Count: Integer;
begin
  Selected := TArray<TPersistent>(SelectedItems);
  All := CategoryFilterAll;
  NoCat := (FCategories.ItemIndex >= 0) and (FCategories.Items[FCategories.ItemIndex] = SNoCategory);
  Cat := SelectedCategory;
  FSelecting := True;
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    FImages.Clear;
    Count := 0;
    for I := 0 to FManager.ItemCount - 1 do
    begin
      Item := FManager.Items[I];
      if not All then
      begin
        if NoCat and (Item.Category <> '') then
          Continue;
        if not NoCat and not SameText(Item.Category, Cat) then
          Continue;
      end;
      LI := FList.Items.Add;
      LI.Caption := FmrDesignStripAccel(Item.Caption);
      if LI.Caption = '' then
        LI.Caption := '(' + FmrDesignItemClassInfo(Item.ClassType).Caption + ')';
      LI.SubItems.Add(Item.Name);
      LI.SubItems.Add(FmrDesignItemClassInfo(Item.ClassType).Caption);
      LI.SubItems.Add(IntToStr(Item.LinkCount));
      LI.Data := Item;
      LI.ImageIndex := ItemImage(Item);
      Inc(Count);
    end;
  finally
    FList.Items.EndUpdate;
    FSelecting := False;
  end;
  FSelecting := True;
  try
    SelectItems(Selected);
  finally
    FSelecting := False;
  end;
  FStatus.SimpleText := Format('%d of %d items', [Count, FManager.ItemCount]);
  UpdateButtons;
end;

function TFmrItemsEditorForm.SelectedItems: TArray<TFmrBarItem>;
var
  LI: TListItem;
begin
  Result := nil;
  LI := FList.Selected;
  while LI <> nil do
  begin
    Result := Result + [TFmrBarItem(LI.Data)];
    LI := FList.GetNextItem(LI, sdAll, [isSelected]);
  end;
end;

procedure TFmrItemsEditorForm.SelectItems(const AItems: TArray<TPersistent>);
var
  I: Integer;
  P: TPersistent;
  Sel: Boolean;
  First: TListItem;
begin
  First := nil;
  for I := 0 to FList.Items.Count - 1 do
  begin
    Sel := False;
    for P in AItems do
      if FList.Items[I].Data = Pointer(P) then
        Sel := True;
    FList.Items[I].Selected := Sel;
    if Sel and (First = nil) then
      First := FList.Items[I];
  end;
  if First <> nil then
  begin
    First.Focused := True;
    First.MakeVisible(False);
  end;
end;

procedure TFmrItemsEditorForm.UpdateButtons;
var
  HasSel: Boolean;
  I: Integer;
begin
  HasSel := FList.SelCount > 0;
  for I := 1 to FToolBar.ButtonCount - 1 do
    if FToolBar.Buttons[I].Style = tbsButton then
      FToolBar.Buttons[I].Enabled := HasSel;
  FCatToolBar.Buttons[1].Enabled := SelectedCategory <> '';
  FCatToolBar.Buttons[2].Enabled := SelectedCategory <> '';
end;

procedure TFmrItemsEditorForm.NewItemClick(Sender: TObject);
var
  Item: TFmrBarItem;
begin
  Item := FmrDesignNewItem(Bridge, FManager, TFmrBarItemClass(TMenuItem(Sender).Tag), SelectedCategory);
  Bridge.Modified;
  RefreshAll;
  FSelecting := True;
  try
    SelectItems([Item]);
  finally
    FSelecting := False;
  end;
  Bridge.SelectObjects([Item]);
end;

procedure TFmrItemsEditorForm.NewButtonClick(Sender: TObject);
begin
  NewItemClick(FNewMenu.Items[0]);
end;

procedure TFmrItemsEditorForm.DeleteClick(Sender: TObject);
var
  Items: TArray<TFmrBarItem>;
  Item: TFmrBarItem;
begin
  Items := SelectedItems;
  if Length(Items) = 0 then
    Exit;
  Bridge.SelectObjects([FManager]);
  for Item in Items do
    Item.Free;
  Bridge.Modified;
  RefreshAll;
end;

procedure TFmrItemsEditorForm.MoveSelected(const ADelta: Integer);
var
  Items: TArray<TFmrBarItem>;
  Visible: TList<TFmrBarItem>;
  I, J, Pos: Integer;
begin
  Items := SelectedItems;
  if Length(Items) = 0 then
    Exit;
  Visible := TList<TFmrBarItem>.Create;
  try
    for I := 0 to FList.Items.Count - 1 do
      Visible.Add(TFmrBarItem(FList.Items[I].Data));
    if ADelta < 0 then
    begin
      for I := 0 to High(Items) do
      begin
        Pos := Visible.IndexOf(Items[I]);
        if Pos > 0 then
        begin
          J := Visible[Pos - 1].Index;
          Items[I].Index := J;
          Visible.Exchange(Pos, Pos - 1);
        end;
      end;
    end
    else
    begin
      for I := High(Items) downto 0 do
      begin
        Pos := Visible.IndexOf(Items[I]);
        if (Pos >= 0) and (Pos < Visible.Count - 1) then
        begin
          J := Visible[Pos + 1].Index;
          Items[I].Index := J;
          Visible.Exchange(Pos, Pos + 1);
        end;
      end;
    end;
  finally
    Visible.Free;
  end;
  Bridge.Modified;
  RefreshItems;
end;

procedure TFmrItemsEditorForm.MoveUpClick(Sender: TObject);
begin
  MoveSelected(-1);
end;

procedure TFmrItemsEditorForm.MoveDownClick(Sender: TObject);
begin
  MoveSelected(1);
end;

procedure TFmrItemsEditorForm.AddCategoryClick(Sender: TObject);
var
  S: string;
begin
  S := '';
  if not InputQuery('New Category', 'Category name:', S) then
    Exit;
  S := S.Trim;
  if (S = '') or (FManager.Categories.IndexOf(S) >= 0) then
    Exit;
  FManager.Categories.Add(S);
  Bridge.Modified;
  RefreshCategories;
  FCategories.ItemIndex := FCategories.Items.IndexOf(S);
  RefreshItems;
end;

procedure TFmrItemsEditorForm.RenameCategoryClick(Sender: TObject);
var
  Old, S: string;
  I: Integer;
begin
  Old := SelectedCategory;
  if Old = '' then
    Exit;
  S := Old;
  if not InputQuery('Rename Category', 'Category name:', S) then
    Exit;
  S := S.Trim;
  if (S = '') or (S = Old) then
    Exit;
  I := FManager.Categories.IndexOf(Old);
  if I >= 0 then
    FManager.Categories[I] := S
  else
    FManager.Categories.Add(S);
  for I := 0 to FManager.ItemCount - 1 do
    if SameText(FManager.Items[I].Category, Old) then
      FManager.Items[I].Category := S;
  Bridge.Modified;
  RefreshCategories;
  FCategories.ItemIndex := FCategories.Items.IndexOf(S);
  RefreshItems;
end;

procedure TFmrItemsEditorForm.DeleteCategoryClick(Sender: TObject);
var
  Cat: string;
  I: Integer;
begin
  Cat := SelectedCategory;
  if Cat = '' then
    Exit;
  I := FManager.Categories.IndexOf(Cat);
  if I >= 0 then
    FManager.Categories.Delete(I);
  for I := 0 to FManager.ItemCount - 1 do
    if SameText(FManager.Items[I].Category, Cat) then
      FManager.Items[I].Category := '';
  Bridge.Modified;
  FCategories.ItemIndex := 0;
  RefreshAll;
end;

procedure TFmrItemsEditorForm.CategoriesClick(Sender: TObject);
begin
  RefreshItems;
end;

procedure TFmrItemsEditorForm.CategoriesDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState;
  var Accept: Boolean);
var
  I: Integer;
begin
  I := FCategories.ItemAtPos(Point(X, Y), True);
  Accept := (Source is TFmrItemDragObject) and (I > 0);
end;

procedure TFmrItemsEditorForm.CategoriesDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  I: Integer;
  Cat: string;
  Item: TFmrBarItem;
begin
  I := FCategories.ItemAtPos(Point(X, Y), True);
  if (I <= 0) or not (Source is TFmrItemDragObject) then
    Exit;
  if FCategories.Items[I] = SNoCategory then
    Cat := ''
  else
    Cat := FCategories.Items[I];
  for Item in TFmrItemDragObject(Source).Items do
    if Item.Manager = FManager then
      Item.Category := Cat;
  Bridge.Modified;
  RefreshAll;
end;

procedure TFmrItemsEditorForm.ListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  UpdateButtons;
  if FSelecting then
    Exit;
  FSelecting := True;
  try
    if FList.SelCount > 0 then
      Bridge.SelectObjects(TArray<TPersistent>(SelectedItems));
  finally
    FSelecting := False;
  end;
end;

procedure TFmrItemsEditorForm.ListDblClick(Sender: TObject);
var
  Items: TArray<TFmrBarItem>;
begin
  Items := SelectedItems;
  if Length(Items) = 1 then
    Bridge.ShowEvent(Items[0], 'OnClick');
end;

procedure TFmrItemsEditorForm.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
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
    VK_UP:
      if ssCtrl in Shift then
      begin
        MoveSelected(-1);
        Key := 0;
      end;
    VK_DOWN:
      if ssCtrl in Shift then
      begin
        MoveSelected(1);
        Key := 0;
      end;
  end;
end;

procedure TFmrItemsEditorForm.ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  FMouseDownInList := (Button = mbLeft) and (FList.GetItemAt(X, Y) <> nil);
  FDragStart := Point(X, Y);
end;

procedure TFmrItemsEditorForm.ListMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FMouseDownInList and (ssLeft in Shift) and ((Abs(X - FDragStart.X) > 4) or (Abs(Y - FDragStart.Y) > 4)) then
  begin
    FMouseDownInList := False;
    if FList.SelCount > 0 then
      FList.BeginDrag(True);
  end;
end;

procedure TFmrItemsEditorForm.ListStartDrag(Sender: TObject; var DragObject: TDragObject);
begin
  DragObject := TFmrItemsEditorDragObject.CreateFor(FList, SelectedItems);
end;

procedure TFmrItemsEditorForm.ListEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  if FmrExternalItemDrop = nil then
    Exit;
  if Target = nil then
  begin
    if not FmrExternalItemDrop.ExternalDrop(Mouse.CursorPos, SelectedItems) then
      FmrExternalItemDrop.ExternalDragCancel;
  end
  else
    FmrExternalItemDrop.ExternalDragCancel;
end;

procedure TFmrItemsEditorForm.DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent);
begin
  inherited;
  if IsMyRoot(ARoot) and (FManager <> nil) and (AItem <> FManager) then
  begin
    // Items being destroyed are still children of the manager: never touch the list until the refresh.
    FSelecting := True;
    FList.Items.BeginUpdate;
    try
      FList.Items.Clear;
    finally
      FList.Items.EndUpdate;
      FSelecting := False;
    end;
    ScheduleRefresh;
  end;
end;

procedure TFmrItemsEditorForm.DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent);
begin
  if IsMyRoot(ARoot) and (FManager <> nil) then
    ScheduleRefresh;
end;

procedure TFmrItemsEditorForm.DesignItemsModified(const ARoot: TComponent);
begin
  if IsMyRoot(ARoot) and (FManager <> nil) then
    ScheduleRefresh;
end;

procedure TFmrItemsEditorForm.DesignSelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>);
begin
  if not IsMyRoot(ARoot) or FSelecting or (FManager = nil) then
    Exit;
  FSelecting := True;
  try
    SelectItems(AObjects);
  finally
    FSelecting := False;
  end;
  UpdateButtons;
end;

end.
