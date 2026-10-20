unit FMR.Tests.Bars;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Actions, DUnitX.TestFramework, FMX.Types,
  FMX.Graphics, FMX.ActnList, FMX.Controls,
  FMX.Objects,
  FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars, FMR.Bars.Items, FMR.Tests.Fakes;

type
  [TestFixture]
  TBarsTests = class
  private
    FRoot: TFmrTestRoot;
    FManager: TFmrBarManager;
    function NewButton(const AName: string; const ACaption: string = ''): TFmrButtonItem;
    procedure DoClickCount(Sender: TObject);
  public
    ClickCount: Integer;
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure ManagerChildrenAreItems;
    [Test] procedure FindItemAndItemByName;
    [Test] procedure CategoriesAreCollected;
    [Test] procedure ItemsInCategory;
    [Test] procedure UniqueItemName;
    [Test] procedure ItemChangeReachesLinkOwner;
    [Test] procedure ChangeKindsAreReported;
    [Test] procedure DestroyingItemDeletesItsLinks;
    [Test] procedure DeletingLinkUnregistersIt;
    [Test] procedure FreeingCollectionBeforeItemIsSafe;
    [Test] procedure ItemCannotBeLinkedIntoItself;
    [Test] procedure LinkEffectiveValues;
    [Test] procedure LinkMoveTo;
    [Test] procedure ManagerListenerAndBatching;
    [Test] procedure ManagerDestroyingNotifiesListener;
    [Test] procedure ActionLinkFollowsAction;
    [Test] procedure ClickRunsOnClickOrAction;
    [Test] procedure DisabledItemDoesNotClick;
    [Test] procedure CheckButtonToggles;
    [Test] procedure RadioGroupIsExclusive;
    [Test] procedure DropDownButtonCallsOnDropDown;
    [Test] procedure ComboItemTextAndIndex;
    [Test] procedure SpinItemClampsAndSteps;
    [Test] procedure CheckItemRadio;
    [Test] procedure GalleryEntriesAndSelection;
    [Test] procedure GalleryColumnsStayConsistent;
    [Test] procedure ImageSourceKinds;
    [Test] procedure GlyphChangeIsLayoutChange;
    [Test] procedure ScreenTipChangeNotifies;
    [Test] procedure DefaultViewLevels;
    [Test] procedure ControlItemFreeNotification;
    [Test] procedure CommandSearch;
    [Test] procedure ImageSourceDrawsPathAndSvg;
  end;

implementation

{ TBarsTests }

procedure TBarsTests.Setup;
begin
  FRoot := TFmrTestRoot.Create(nil);
  FManager := TFmrBarManager.Create(FRoot);
  FManager.Name := 'Manager';
  FManager.Parent := FRoot;
  ClickCount := 0;
end;

procedure TBarsTests.TearDown;
begin
  FreeAndNil(FRoot);
end;

function TBarsTests.NewButton(const AName, ACaption: string): TFmrButtonItem;
begin
  Result := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, AName));
  Result.Caption := ACaption;
end;

procedure TBarsTests.DoClickCount(Sender: TObject);
begin
  Inc(ClickCount);
end;

procedure TBarsTests.ManagerChildrenAreItems;
var
  A, B: TFmrButtonItem;
begin
  A := NewButton('btnA');
  B := NewButton('btnB');
  Assert.AreEqual(2, FManager.ItemCount);
  Assert.AreSame(A, FManager.Items[0]);
  Assert.AreSame(B, FManager.Items[1]);
  Assert.AreSame(FManager, A.Manager);
  Assert.AreSame(FRoot, TComponent(A.Owner), 'items are owned by the owner of the manager (the form)');
  A.Free;
  Assert.AreEqual(1, FManager.ItemCount);
  B.Parent := nil;
  Assert.AreEqual(0, FManager.ItemCount);
  Assert.IsNull(B.Manager);
end;

procedure TBarsTests.FindItemAndItemByName;
begin
  NewButton('btnCopy');
  Assert.IsNotNull(FManager.FindItem('BTNCOPY'));
  Assert.IsNull(FManager.FindItem('nothing'));
  Assert.WillRaise(
    procedure
    begin
      FManager.ItemByName('nothing');
    end, EFmrBarError);
end;

procedure TBarsTests.CategoriesAreCollected;
var
  A: TFmrButtonItem;
begin
  A := NewButton('btnA');
  A.Category := 'File';
  NewButton('btnB').Category := 'Edit';
  NewButton('btnC').Category := 'File';
  Assert.AreEqual(2, FManager.Categories.Count);
  Assert.AreEqual('File', FManager.Categories[0]);
  Assert.AreEqual('Edit', FManager.Categories[1]);
end;

procedure TBarsTests.ItemsInCategory;
var
  Items: TArray<TFmrBarItem>;
begin
  NewButton('btnA').Category := 'File';
  NewButton('btnB').Category := 'Edit';
  NewButton('btnC').Category := 'file';
  Items := FManager.ItemsInCategory('File');
  Assert.AreEqual(2, Integer(Length(Items)));
  Assert.AreEqual('btnA', Items[0].Name);
  Assert.AreEqual('btnC', Items[1].Name);
end;

procedure TBarsTests.UniqueItemName;
begin
  NewButton('Button1');
  NewButton('Button2');
  Assert.AreEqual('Button3', FManager.UniqueItemName('Button'));
end;

procedure TBarsTests.ItemChangeReachesLinkOwner;
var
  Item: TFmrButtonItem;
  Owner1, Owner2: TFakeLinksOwner;
begin
  Item := NewButton('btnA', 'A');
  Owner1 := TFakeLinksOwner.Create;
  Owner2 := TFakeLinksOwner.Create;
  try
    Owner1.Links.AddItem(Item);
    Owner2.Links.AddItem(Item);
    Owner2.Links.AddItem(Item);
    Assert.AreEqual(3, Item.LinkCount);
    Assert.IsTrue(Owner1.LinksChangedCount > 0, 'adding a link notifies');
    Owner1.ItemChangedCount := 0;
    Owner2.ItemChangedCount := 0;
    Item.Caption := 'B';
    Assert.AreEqual(1, Owner1.ItemChangedCount);
    Assert.AreEqual(2, Owner2.ItemChangedCount, 'one notification per link');
    Item.Caption := 'B';
    Assert.AreEqual(1, Owner1.ItemChangedCount, 'no notification without a change');
  finally
    Owner1.Free;
    Owner2.Free;
  end;
  Assert.AreEqual(0, Item.LinkCount);
end;

procedure TBarsTests.ChangeKindsAreReported;
var
  Item: TFmrButtonItem;
  Edit: TFmrEditItem;
  Owner: TFakeLinksOwner;
begin
  Item := NewButton('btnA', 'A');
  Edit := TFmrEditItem(FManager.CreateItem(TFmrEditItem, 'edA'));
  Owner := TFakeLinksOwner.Create;
  try
    Owner.Links.AddItem(Item);
    Owner.Links.AddItem(Edit);
    Item.Enabled := False;
    Assert.AreEqual(TFmrItemChange.Paint, Owner.LastChange);
    Item.Visible := False;
    Assert.AreEqual(TFmrItemChange.Layout, Owner.LastChange);
    Item.ButtonStyle := TFmrButtonStyle.Split;
    Assert.AreEqual(TFmrItemChange.Layout, Owner.LastChange);
    Item.Down := True;
    Assert.AreEqual(TFmrItemChange.Paint, Owner.LastChange);
    Edit.Text := 'abc';
    Assert.AreEqual(TFmrItemChange.Value, Owner.LastChange);
    Edit.Width := 150;
    Assert.AreEqual(TFmrItemChange.Layout, Owner.LastChange);
  finally
    Owner.Free;
  end;
end;

procedure TBarsTests.DestroyingItemDeletesItsLinks;
var
  Item, Other: TFmrButtonItem;
  Owner1, Owner2: TFakeLinksOwner;
begin
  Item := NewButton('btnA');
  Other := NewButton('btnB');
  Owner1 := TFakeLinksOwner.Create;
  Owner2 := TFakeLinksOwner.Create;
  try
    Owner1.Links.AddItem(Other);
    Owner1.Links.AddItem(Item);
    Owner2.Links.AddItem(Item);
    Owner1.LinksChangedCount := 0;
    Item.Free;
    Assert.AreEqual(1, Owner1.Links.Count);
    Assert.AreSame(Other, Owner1.Links[0].Item);
    Assert.AreEqual(0, Owner2.Links.Count);
    Assert.AreEqual(1, Owner1.RemovingCount, 'LinkRemoving is called for the deleted link');
    Assert.IsTrue(Owner1.LinksChangedCount > 0);
  finally
    Owner1.Free;
    Owner2.Free;
  end;
end;

procedure TBarsTests.DeletingLinkUnregistersIt;
var
  Item: TFmrButtonItem;
  Owner: TFakeLinksOwner;
begin
  Item := NewButton('btnA');
  Owner := TFakeLinksOwner.Create;
  try
    Owner.Links.AddItem(Item);
    Owner.Links.AddItem(Item);
    Owner.Links.Delete(0);
    Assert.AreEqual(1, Item.LinkCount);
    Owner.Links[0].Item := nil;
    Assert.AreEqual(0, Item.LinkCount);
    Owner.Links[0].Item := Item;
    Assert.AreEqual(1, Item.LinkCount);
    Owner.Links.RemoveItem(Item);
    Assert.AreEqual(0, Owner.Links.Count);
    Assert.AreEqual(0, Item.LinkCount);
  finally
    Owner.Free;
  end;
end;

procedure TBarsTests.FreeingCollectionBeforeItemIsSafe;
var
  Item: TFmrButtonItem;
  Owner: TFakeLinksOwner;
begin
  Item := NewButton('btnA');
  Owner := TFakeLinksOwner.Create;
  Owner.Links.AddItem(Item);
  Owner.Free;
  Assert.AreEqual(0, Item.LinkCount);
  Item.Caption := 'x';
  Item.Free;
  Assert.Pass;
end;

procedure TBarsTests.ItemCannotBeLinkedIntoItself;
var
  Sub: TFmrSubItem;
begin
  Sub := TFmrSubItem(FManager.CreateItem(TFmrSubItem, 'subA'));
  Sub.ItemLinks.AddItem(NewButton('btnA'));
  Assert.WillRaise(
    procedure
    begin
      Sub.ItemLinks.AddItem(Sub);
    end, EFmrBarError);
  Assert.WillRaise(
    procedure
    begin
      Sub.ItemLinks[0].Item := Sub;
    end, EFmrBarError);
end;

procedure TBarsTests.LinkEffectiveValues;
var
  Item: TFmrButtonItem;
  Owner: TFakeLinksOwner;
  L: TFmrItemLink;
begin
  Item := NewButton('btnA', 'Paste');
  Item.KeyTip := 'V';
  Owner := TFakeLinksOwner.Create;
  try
    L := Owner.Links.AddItem(Item);
    Assert.AreEqual('Paste', L.Caption);
    Assert.AreEqual('V', L.EffectiveKeyTip);
    L.UserCaption := 'Insert';
    L.KeyTip := 'I';
    Assert.AreEqual('Insert', L.Caption);
    Assert.AreEqual('I', L.EffectiveKeyTip);
    Assert.IsTrue(L.IsVisible);
    Item.Visible := False;
    Assert.IsFalse(L.IsVisible);
    Assert.AreEqual(0, Owner.Links.VisibleCount);
    Assert.IsTrue(L.EffectiveViewLevels = Item.DefaultViewLevels);
    L.ViewLevels := [TFmrViewLevel.Large];
    Assert.IsTrue(L.EffectiveViewLevels = [TFmrViewLevel.Large]);
    Assert.AreSame(Owner, L.LinksOwner);
  finally
    Owner.Free;
  end;
end;

procedure TBarsTests.LinkMoveTo;
var
  A, B: TFmrButtonItem;
  O1, O2: TFakeLinksOwner;
  L: TFmrItemLink;
begin
  A := NewButton('btnA');
  B := NewButton('btnB');
  O1 := TFakeLinksOwner.Create;
  O2 := TFakeLinksOwner.Create;
  try
    L := O1.Links.AddItem(A);
    O2.Links.AddItem(B);
    L.BeginGroup := True;
    L.MoveTo(O2.Links, 0);
    Assert.AreEqual(0, O1.Links.Count);
    Assert.AreEqual(2, O2.Links.Count);
    Assert.AreSame(A, O2.Links[0].Item);
    Assert.IsTrue(O2.Links[0].BeginGroup, 'link properties move with the link');
    Assert.AreEqual(1, A.LinkCount);
    Assert.AreEqual(1, O1.RemovingCount, 'the old owner releases what it created for the link');
  finally
    O1.Free;
    O2.Free;
  end;
end;

procedure TBarsTests.ManagerListenerAndBatching;
var
  Listener: TFakeListener;
  Ref: IFmrBarManagerListener;
  A: TFmrButtonItem;
begin
  Listener := TFakeListener.Create;
  Ref := Listener;
  FManager.AddListener(Ref);
  A := NewButton('btnA');
  Assert.AreEqual(1, Listener.Count(TFmrManagerChange.ItemAdded));
  A.Caption := 'x';
  Assert.AreEqual(1, Listener.Count(TFmrManagerChange.ItemChanged));
  Assert.AreSame(TFmrBarItem(A), Listener.LastItem);
  Listener.Log.Clear;
  FManager.BeginUpdate;
  try
    A.Caption := 'y';
    NewButton('btnB');
    A.Enabled := False;
    Assert.AreEqual(0, Integer(Listener.Log.Count), 'nothing while updating');
  finally
    FManager.EndUpdate;
  end;
  Assert.AreEqual(1, Integer(Listener.Log.Count));
  Assert.AreEqual(TFmrManagerChange.Updated, Listener.Log[0]);
  A.Free;
  Assert.AreEqual(1, Listener.Count(TFmrManagerChange.ItemRemoved));
  FManager.RemoveListener(Ref);
end;

procedure TBarsTests.ManagerDestroyingNotifiesListener;
var
  Listener: TFakeListener;
  Ref: IFmrBarManagerListener;
begin
  Listener := TFakeListener.Create;
  Ref := Listener;
  NewButton('btnA');
  FManager.AddListener(Ref);
  FManager.Free;
  FManager := nil;
  Assert.AreEqual(1, Listener.Count(TFmrManagerChange.Destroying));
end;

procedure TBarsTests.ActionLinkFollowsAction;
var
  ActionList: TActionList;
  Action: TAction;
  Item: TFmrButtonItem;
begin
  ActionList := TActionList.Create(FRoot);
  Action := TAction.Create(FRoot);
  Action.ActionList := ActionList;
  Action.Text := 'Save';
  Action.Hint := 'Save the document';
  Action.ShortCut := scCtrl or Ord('S');
  Action.ImageIndex := 3;
  Action.Checked := True;
  Item := NewButton('btnSave');
  Item.Action := Action;
  Assert.AreEqual('Save', Item.Caption);
  Assert.AreEqual('Save the document', Item.Hint);
  Assert.AreEqual(Integer(scCtrl or Ord('S')), Integer(Item.ShortCut));
  Assert.AreEqual(3, Integer(Item.ImageIndex));
  Assert.IsTrue(Item.Down, 'Checked follows to Down');
  Action.Enabled := False;
  Assert.IsFalse(Item.Enabled);
  Action.Visible := False;
  Assert.IsFalse(Item.Visible);
  Action.Text := 'Save As';
  Assert.AreEqual('Save As', Item.Caption);
  Action.Checked := False;
  Assert.IsFalse(Item.Down);
  Action.Free;
  Assert.IsNull(Item.Action, 'the item forgets a destroyed action');
end;

procedure TBarsTests.ClickRunsOnClickOrAction;
var
  Action: TAction;
  Item: TFmrButtonItem;
begin
  Action := TAction.Create(FRoot);
  Action.OnExecute := DoClickCount;
  Item := NewButton('btnA');
  Item.Action := Action;
  Item.Click;
  Assert.AreEqual(1, ClickCount, 'the action is executed');
  Item.OnClick := DoClickCount;
  Item.Click;
  Assert.AreEqual(2, ClickCount, 'OnClick runs once instead of the action');
  Item.Action := nil;
  Item.Click;
  Assert.AreEqual(3, ClickCount);
end;

procedure TBarsTests.DisabledItemDoesNotClick;
var
  Item: TFmrButtonItem;
begin
  Item := NewButton('btnA');
  Item.OnClick := DoClickCount;
  Item.Enabled := False;
  Item.Click;
  Assert.AreEqual(0, ClickCount);
end;

procedure TBarsTests.CheckButtonToggles;
var
  Item: TFmrButtonItem;
begin
  Item := NewButton('btnA');
  Item.ButtonStyle := TFmrButtonStyle.Check;
  Item.Click;
  Assert.IsTrue(Item.Down);
  Item.Click;
  Assert.IsFalse(Item.Down);
end;

procedure TBarsTests.RadioGroupIsExclusive;
var
  Left, Center, Right: TFmrButtonItem;
begin
  Left := NewButton('btnLeft');
  Center := NewButton('btnCenter');
  Right := NewButton('btnRight');
  for var B in [Left, Center, Right] do
  begin
    B.ButtonStyle := TFmrButtonStyle.Check;
    B.GroupIndex := 1;
  end;
  Left.Down := True;
  Center.Click;
  Assert.IsFalse(Left.Down);
  Assert.IsTrue(Center.Down);
  Center.Click;
  Assert.IsTrue(Center.Down, 'a radio button stays down without AllowAllUp');
  Center.AllowAllUp := True;
  Center.Click;
  Assert.IsFalse(Center.Down);
  Right.Down := True;
  Assert.IsFalse(Left.Down or Center.Down);
end;

procedure TBarsTests.DropDownButtonCallsOnDropDown;
var
  Item: TFmrButtonItem;
begin
  Item := NewButton('btnA');
  Item.ButtonStyle := TFmrButtonStyle.DropDown;
  Item.OnDropDown := DoClickCount;
  Item.DropDownLinks.AddItem(NewButton('btnB'));
  Assert.IsTrue(Item.HasDropDown);
  Item.Click;
  Assert.AreEqual(1, ClickCount);
  Item.ButtonStyle := TFmrButtonStyle.Split;
  Item.OnClick := DoClickCount;
  Item.Click;
  Assert.AreEqual(2, ClickCount, 'the main part of a split button runs OnClick');
end;

procedure TBarsTests.ComboItemTextAndIndex;
var
  Combo: TFmrComboItem;
begin
  Combo := TFmrComboItem(FManager.CreateItem(TFmrComboItem, 'cbA'));
  Combo.Items.CommaText := 'One,Two,Three';
  Combo.OnChange := DoClickCount;
  Combo.ItemIndex := 1;
  Assert.AreEqual('Two', Combo.Text);
  Combo.Text := 'Three';
  Assert.AreEqual(2, Combo.ItemIndex);
  Combo.Text := 'Free text';
  Assert.AreEqual(-1, Combo.ItemIndex);
  Assert.AreEqual('Free text', Combo.Text);
  Combo.ItemIndex := 10;
  Assert.AreEqual(-1, Combo.ItemIndex);
  Assert.AreEqual(3, ClickCount);
end;

procedure TBarsTests.SpinItemClampsAndSteps;
var
  Spin: TFmrSpinItem;
begin
  Spin := TFmrSpinItem(FManager.CreateItem(TFmrSpinItem, 'spA'));
  Spin.Min := 0;
  Spin.Max := 10;
  Spin.Increment := 4;
  Spin.Value := 20;
  Assert.AreEqual(Double(10), Spin.Value, 0.0001);
  Spin.StepDown;
  Assert.AreEqual(Double(6), Spin.Value, 0.0001);
  Spin.StepDown;
  Spin.StepDown;
  Assert.AreEqual(Double(0), Spin.Value, 0.0001);
end;

procedure TBarsTests.CheckItemRadio;
var
  A, B: TFmrCheckItem;
begin
  A := TFmrCheckItem(FManager.CreateItem(TFmrCheckItem, 'chkA'));
  B := TFmrCheckItem(FManager.CreateItem(TFmrCheckItem, 'chkB'));
  A.Click;
  Assert.IsTrue(A.Checked);
  A.Click;
  Assert.IsFalse(A.Checked);
  A.GroupIndex := 5;
  B.GroupIndex := 5;
  A.Checked := True;
  B.Click;
  Assert.IsTrue(B.Checked);
  Assert.IsFalse(A.Checked);
end;

type
  TGalleryEvents = class
    Clicked, Hot: TFmrGalleryEntry;
    HotCalls: Integer;
    procedure ItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure HotTrack(Sender: TObject; const AEntry: TFmrGalleryEntry);
  end;

procedure TGalleryEvents.HotTrack(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  Hot := AEntry;
  Inc(HotCalls);
end;

procedure TGalleryEvents.ItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  Clicked := AEntry;
end;

procedure TBarsTests.GalleryEntriesAndSelection;
var
  Gallery: TFmrGalleryItem;
  G1, G2: TFmrGalleryGroup;
  Events: TGalleryEvents;
  Owner: TFakeLinksOwner;
begin
  Gallery := TFmrGalleryItem(FManager.CreateItem(TFmrGalleryItem, 'galA'));
  G1 := Gallery.Groups.Add('Built-in');
  G1.Items.Add('Normal', 0);
  G1.Items.Add('Title', 1);
  G2 := Gallery.Groups.Add('Custom');
  G2.Items.Add('Quote', 2);
  Assert.AreEqual(3, Gallery.EntryCount);
  Assert.AreEqual('Quote', Gallery.Entries[2].Caption);
  Assert.AreEqual(2, Gallery.IndexOfEntry(G2.Items[0]));
  Assert.AreSame(Gallery, G2.Items[0].Gallery);
  Events := TGalleryEvents.Create;
  Owner := TFakeLinksOwner.Create;
  try
    Owner.Links.AddItem(Gallery);
    Gallery.OnItemClick := Events.ItemClick;
    Gallery.OnHotTrack := Events.HotTrack;
    Gallery.ClickEntry(G1.Items[1]);
    Assert.AreSame(G1.Items[1], Events.Clicked);
    Assert.AreEqual(1, Gallery.SelectedIndex);
    Assert.AreSame(G1.Items[1], Gallery.SelectedEntry);
    Gallery.HotTrack(G2.Items[0]);
    Gallery.HotTrack(nil);
    Assert.AreEqual(2, Events.HotCalls);
    Assert.IsNull(Events.Hot, 'nil when the mouse leaves: revert the live preview');
    Owner.ItemChangedCount := 0;
    G2.Items.Add('New');
    Assert.IsTrue(Owner.ItemChangedCount > 0, 'entry changes reach the links of the gallery');
    Gallery.SelectedEntry := G2.Items[1];
    G1.Items.Clear;
    Assert.AreEqual(1, Gallery.SelectedIndex, 'the selection follows its entry');
    Assert.AreEqual('New', Gallery.SelectedEntry.Caption);
    G2.Items.Delete(1);
    Assert.AreEqual(-1, Gallery.SelectedIndex, 'selection is dropped when its entry is deleted');
  finally
    Owner.Free;
    Events.Free;
  end;
end;

procedure TBarsTests.GalleryColumnsStayConsistent;
var
  Gallery: TFmrGalleryItem;
begin
  Gallery := TFmrGalleryItem(FManager.CreateItem(TFmrGalleryItem, 'galA'));
  Gallery.MinColumns := 8;
  Assert.AreEqual(8, Gallery.MaxColumns);
  Gallery.MaxColumns := 3;
  Assert.AreEqual(3, Gallery.MinColumns);
  Assert.AreEqual(TFmrLayoutItemKind.Gallery, Gallery.LayoutKind);
  Gallery.ShowInRibbon := False;
  Assert.AreEqual(TFmrLayoutItemKind.Button, Gallery.LayoutKind);
end;

procedure TBarsTests.ImageSourceKinds;
var
  A, B: TFmrImageSource;
begin
  A := TFmrImageSource.Create(nil);
  B := TFmrImageSource.Create(nil);
  try
    Assert.AreEqual(TFmrImageKind.None, A.EffectiveKind);
    Assert.IsTrue(A.IsEmpty);
    A.ImageIndex := 2;
    Assert.AreEqual(TFmrImageKind.ImageList, A.EffectiveKind);
    A.PathData := 'M0,0 L10,0 L10,10 Z';
    Assert.AreEqual(TFmrImageKind.Path, A.EffectiveKind);
    Assert.IsNotNull(A.Path);
    A.GlyphCode := $E8C8;
    Assert.AreEqual(TFmrImageKind.Glyph, A.EffectiveKind);
    Assert.AreEqual(1, A.GlyphText.Length);
    A.SvgSource := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><rect width="16" height="16"/></svg>';
    Assert.AreEqual(TFmrImageKind.Svg, A.EffectiveKind);
    A.Kind := TFmrImageKind.Path;
    Assert.AreEqual(TFmrImageKind.Path, A.EffectiveKind, 'an explicit kind wins');
    B.Assign(A);
    Assert.IsTrue(B.SameAs(A));
    B.Color := TAlphaColors.Red;
    Assert.IsFalse(B.SameAs(A));
    A.GlyphCode := $1F600;
    Assert.AreEqual(2, A.GlyphText.Length, 'code points above $FFFF become a surrogate pair');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TBarsTests.GlyphChangeIsLayoutChange;
var
  Item: TFmrButtonItem;
  Owner: TFakeLinksOwner;
begin
  Item := NewButton('btnA');
  Owner := TFakeLinksOwner.Create;
  try
    Owner.Links.AddItem(Item);
    Owner.ItemChangedCount := 0;
    Item.Glyph.ImageIndex := 4;
    Assert.AreEqual(1, Owner.ItemChangedCount);
    Assert.AreEqual(TFmrItemChange.Layout, Owner.LastChange);
    Item.ImageIndex := 5;
    Assert.AreEqual(5, Integer(Item.Glyph.ImageIndex));
  finally
    Owner.Free;
  end;
end;

procedure TBarsTests.ScreenTipChangeNotifies;
var
  Item: TFmrButtonItem;
  Owner: TFakeLinksOwner;
begin
  Item := NewButton('btnA');
  Owner := TFakeLinksOwner.Create;
  try
    Owner.Links.AddItem(Item);
    Owner.ItemChangedCount := 0;
    Assert.IsTrue(Item.ScreenTip.IsEmpty);
    Item.ScreenTip.Header := 'Paste';
    Item.ScreenTip.Description := 'Paste from the clipboard';
    Assert.AreEqual(2, Owner.ItemChangedCount);
    Assert.IsFalse(Item.ScreenTip.IsEmpty);
  finally
    Owner.Free;
  end;
end;

procedure TBarsTests.DefaultViewLevels;
var
  Item: TFmrButtonItem;
  Sep: TFmrSeparatorItem;
  Edit: TFmrEditItem;
begin
  Item := NewButton('btnA', 'A');
  Assert.IsTrue(Item.DefaultViewLevels = [TFmrViewLevel.SmallWithText], 'no glyph: text only');
  Item.Glyph.ImageIndex := 0;
  Assert.IsTrue(Item.DefaultViewLevels = FmrAllViewLevels, 'one image supports every button size');
  Sep := TFmrSeparatorItem(FManager.CreateItem(TFmrSeparatorItem, 'sepA'));
  Assert.AreEqual(TFmrLayoutItemKind.Separator, Sep.LayoutKind);
  Edit := TFmrEditItem(FManager.CreateItem(TFmrEditItem, 'edA'));
  Assert.AreEqual(TFmrLayoutItemKind.Control, Edit.LayoutKind);
  Assert.IsTrue(Edit.DefaultViewLevels = [TFmrViewLevel.Small]);
  Edit.Caption := 'Find';
  Assert.IsTrue(Edit.DefaultViewLevels = FmrSmallViewLevels);
end;

procedure TBarsTests.ControlItemFreeNotification;
var
  Item: TFmrControlItem;
  Control: TRectangle;
begin
  Item := TFmrControlItem(FManager.CreateItem(TFmrControlItem, 'ctlA'));
  Assert.AreEqual(TFmrLayoutItemKind.Control, Item.LayoutKind);
  Control := TRectangle.Create(nil);
  Item.Control := Control;
  Assert.AreSame(TControl(Control), Item.Control);
  Control.Free;
  Assert.IsNull(Item.Control, 'a destroyed control is forgotten');
end;

procedure TBarsTests.CommandSearch;
var
  Found: TArray<TFmrBarItem>;
  Hidden: TFmrButtonItem;
begin
  NewButton('btnPrintPreview', 'Print Pre&view');
  NewButton('btnQuickPrint', 'Quick Print');
  NewButton('btnPrint', '&Print').Keywords := 'printer paper';
  NewButton('btnPageSetup', 'Page Setup').Description := 'Margins, paper size and orientation';
  Hidden := NewButton('btnPrintHidden', 'Print hidden');
  Hidden.Visible := False;
  Found := FManager.SearchItems('print');
  Assert.AreEqual(3, Integer(Length(Found)));
  Assert.AreEqual('btnPrintPreview', Found[0].Name, 'captions starting with the text first, in item order');
  Assert.AreEqual('btnPrint', Found[1].Name);
  Assert.AreEqual('btnQuickPrint', Found[2].Name, 'then captions containing it');
  Found := FManager.SearchItems('PAPER');
  Assert.AreEqual(2, Integer(Length(Found)), 'keywords and descriptions are searched');
  Found := FManager.SearchItems('print view');
  Assert.AreEqual(1, Integer(Length(Found)), 'every word must match');
  Assert.AreEqual(1, Integer(Length(FManager.SearchItems('print', 1))));
  Assert.AreEqual(0, Integer(Length(FManager.SearchItems('  '))));
end;

function PixelAt(const ABitmap: TBitmap; const X, Y: Integer): TAlphaColor;
var
  D: TBitmapData;
begin
  Result := 0;
  if ABitmap.Map(TMapAccess.Read, D) then
  try
    Result := D.GetPixel(X, Y);
  finally
    ABitmap.Unmap(D);
  end;
end;

procedure TBarsTests.ImageSourceDrawsPathAndSvg;
const
  Svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">' +
    '<rect x="0" y="0" width="16" height="16" fill="#0000FF"/></svg>';
var
  B: TBitmap;
  Img: TFmrImageSource;

  procedure Render;
  begin
    if B.Canvas.BeginScene then
    try
      B.Canvas.Clear(0);
      Img.Draw(B.Canvas, TRectF.Create(0, 0, 32, 32), 1, TAlphaColors.Null, nil);
    finally
      B.Canvas.EndScene;
    end;
  end;

begin
  B := TBitmap.Create(32, 32);
  Img := TFmrImageSource.Create(nil);
  try
    Img.PathData := 'M0,0 L16,0 L16,16 L0,16 Z';
    Img.Color := TAlphaColors.Red;
    Render;
    Assert.AreEqual(TAlphaColor(TAlphaColors.Red), PixelAt(B, 16, 16), 'the path is fitted into the rectangle');
    Img.PathData := '';
    Img.Color := TAlphaColors.Null;
    Img.SvgSource := Svg;
    Render;
    Assert.AreEqual(TAlphaColor(TAlphaColors.Blue), PixelAt(B, 16, 16), 'SVG rendered with Skia');
    Img.Recolor := True;
    Img.Color := TAlphaColors.Lime;
    Render;
    Assert.AreEqual(TAlphaColor(TAlphaColors.Lime), PixelAt(B, 16, 16), 'recolored SVG');
    Render;
    Assert.AreEqual(TAlphaColor(TAlphaColors.Lime), PixelAt(B, 16, 16), 'drawn again from the cache');
  finally
    Img.Free;
    B.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBarsTests);

end.
