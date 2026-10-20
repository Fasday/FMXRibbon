unit FMR.Tests.Gallery;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  DUnitX.TestFramework, FMX.Types, FMX.Graphics, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Types,
  FMR.Ribbon.Structure, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Gallery, FMR.Ribbon.Popup, FMR.Ribbon;

type
  [TestFixture]
  TGalleryTests = class
  private
    FRoot: TFmxObject;
    FManager: TFmrBarManager;
    FRibbon: TFmrRibbon;
    FGallery: TFmrRibbonGalleryItem;
    FView: TFmrGalleryView;
    FDrawn: TList<TFmrGalleryEntry>;
    FRects: TList<TRectF>;
    FClicks: Integer;
    FClicked: string;
    FDeleteOnPreview: Boolean;
    FDeleteOnRevert: Boolean;
    procedure Click(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure Preview(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure Draw(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure PaintView;
    procedure QueueClick(const ADeleteOnExecuting: Boolean);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [TestCase('Normal', '0,1')]
    [TestCase('EntryDeleted', '1,0')]
    [TestCase('GroupDeleted', '2,0')]
    [TestCase('GalleryDeleted', '3,0')]
    [TestCase('EntryReordered', '4,1')]
    [TestCase('EntryReplaced', '5,0')]
    [TestCase('GroupReplaced', '6,0')]
    [TestCase('DeletedByContext', '7,0')]
    [TestCase('DeletedByPreviewRevert', '8,0')]
    procedure DeferredClickKeepsItsTarget(const AMutation, AExpectedClicks: Integer);
    [Test] procedure PreviewCanDeleteItsEntry;
    [Test] procedure RebuildDoesNotRedirectHoveredClick;
    [Test] procedure ValueAndPaintChangesKeepHover;
    [Test] procedure HitTestingMatchesVisibleCellsAfterScrolling;
    [Test] procedure InRibbonClickCanDeleteEntryWhenRevertingPreview;
  end;

implementation

type
  TDeletingContext = class(TFmrPopupContext)
  protected
    procedure ItemExecuting(const AItem: TFmrBarItem); override;
  end;

procedure TDeletingContext.ItemExecuting(const AItem: TFmrBarItem);
begin
  TFmrGalleryItem(AItem).Groups.Clear;
end;

procedure TGalleryTests.Setup;
var
  Tab: TFmrRibbonTab;
  Group: TFmrRibbonGroup;
  Entries: TFmrGalleryGroup;
  Link: TFmrItemLink;
  I: Integer;
begin
  FClicks := 0;
  FClicked := '';
  FDeleteOnPreview := False;
  FDeleteOnRevert := False;
  FDrawn := TList<TFmrGalleryEntry>.Create;
  FRects := TList<TRectF>.Create;
  FRoot := TFmxObject.Create(nil);
  FManager := TFmrBarManager.Create(FRoot);
  FManager.Parent := FRoot;
  FRibbon := TFmrRibbon.Create(FRoot);
  FRibbon.Width := 1000;
  FRibbon.BarManager := FManager;
  FGallery := TFmrRibbonGalleryItem(FManager.CreateItem(TFmrRibbonGalleryItem, 'gallery'));
  FGallery.ItemWidth := 40;
  FGallery.ItemHeight := 20;
  FGallery.MinColumns := 2;
  FGallery.MaxColumns := 2;
  FGallery.OnItemClick := Click;
  FGallery.OnHotTrack := Preview;
  FGallery.OnDrawItem := Draw;
  Entries := FGallery.Groups.Add('Entries');
  for I := 0 to 20 do
    Entries.Items.Add('Entry' + IntToStr(I));
  Tab := TFmrRibbonTab.Create(FRoot);
  Tab.Parent := FRibbon;
  Group := TFmrRibbonGroup.Create(FRoot);
  Group.Parent := Tab;
  Link := Group.ItemLinks.AddItem(FGallery);
  FRibbon.ActiveTab := Tab;
  FRibbon.UpdateLayout;
  Assert.IsTrue(Link.ViewObject is TFmrGalleryView);
  FView := TFmrGalleryView(Link.ViewObject);
  Assert.IsTrue(FView.InRibbon);
end;

procedure TGalleryTests.TearDown;
begin
  CheckSynchronize;
  FreeAndNil(FRoot);
  FRects.Free;
  FDrawn.Free;
end;

procedure TGalleryTests.Click(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  Inc(FClicks);
  FClicked := AEntry.Caption;
end;

procedure TGalleryTests.Preview(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  if FDeleteOnPreview and (AEntry <> nil) then
    AEntry.Free
  else if FDeleteOnRevert and (AEntry = nil) then
    TFmrGalleryItem(Sender).Groups.Clear;
end;

procedure TGalleryTests.Draw(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
begin
  FDrawn.Add(AEntry);
  FRects.Add(ARect);
  AHandled := True;
end;

procedure TGalleryTests.PaintView;
var
  Bitmap: TBitmap;
begin
  FDrawn.Clear;
  FRects.Clear;
  Bitmap := TBitmap.Create(1200, 400);
  try
    Assert.IsTrue(Bitmap.Canvas.BeginScene);
    try
      FView.Paint(Bitmap.Canvas);
    finally
      Bitmap.Canvas.EndScene;
    end;
  finally
    Bitmap.Free;
  end;
  Assert.IsTrue(FDrawn.Count > 0);
end;

procedure TGalleryTests.QueueClick(const ADeleteOnExecuting: Boolean);
var
  Context: IFmrPopupContext;
  Popup: TFmrGalleryPopupContent;
  Content: IFmrPopupContent;
  Key: Word;
  Ch: WideChar;
begin
  if ADeleteOnExecuting then
    Context := TDeletingContext.Create(FRibbon.Painter, nil, nil)
  else
    Context := TFmrPopupContext.Create(FRibbon.Painter, nil, nil);
  Popup := TFmrGalleryPopupContent.CreateGallery(Context, FGallery);
  try
    Assert.IsTrue(Supports(Popup, IFmrPopupContent, Content));
    Key := vkHome;
    Ch := #0;
    Assert.IsTrue(Content.PopupKeyDown(Key, Ch, []));
    Key := vkReturn;
    Assert.IsTrue(Content.PopupKeyDown(Key, Ch, []));
    Assert.AreEqual(0, FClicks, 'The click must wait for the message loop');
  finally
    Content := nil;
    Popup.Free;
  end;
end;

procedure TGalleryTests.DeferredClickKeepsItsTarget(const AMutation, AExpectedClicks: Integer);
begin
  FDeleteOnRevert := AMutation = 8;
  QueueClick(AMutation = 7);
  case AMutation of
    1: FGallery.Entries[0].Free;
    2: FGallery.Groups[0].Free;
    3: FreeAndNil(FGallery);
    4: FGallery.Entries[0].Index := 5;
    5:
      begin
        FGallery.Entries[0].Free;
        FGallery.Groups[0].Items.Add('Replacement').Index := 0;
      end;
    6:
      begin
        FGallery.Groups.Clear;
        FGallery.Groups.Add('Replacement').Items.Add('Replacement');
      end;
  end;
  CheckSynchronize;
  Assert.AreEqual(AExpectedClicks, FClicks);
  if AExpectedClicks > 0 then
    Assert.AreEqual('Entry0', FClicked);
end;

procedure TGalleryTests.PreviewCanDeleteItsEntry;
begin
  PaintView;
  FDeleteOnPreview := True;
  FView.HotPart := TFmrElementPart.Main;
  FView.MouseMoveAt(FRects[0].CenterPoint);
  Assert.AreEqual(20, FGallery.EntryCount);
  FView.Execute(TFmrElementPart.Main);
  Assert.AreEqual(0, FClicks, 'A deleted hot entry must not become a click on its successor');
end;

procedure TGalleryTests.RebuildDoesNotRedirectHoveredClick;
begin
  PaintView;
  FView.HotPart := TFmrElementPart.Main;
  FView.MouseMoveAt(FRects[0].CenterPoint);
  FGallery.Entries[0].Visible := False;
  FView.Execute(TFmrElementPart.Main);
  Assert.AreEqual(0, FClicks);
  FView.MouseMoveAt(FRects[0].CenterPoint);
  FView.Execute(TFmrElementPart.Main);
  Assert.AreEqual(1, FClicks);
  Assert.AreEqual('Entry1', FClicked);
end;

procedure TGalleryTests.ValueAndPaintChangesKeepHover;
begin
  PaintView;
  FView.HotPart := TFmrElementPart.Main;
  FView.MouseMoveAt(FRects[0].CenterPoint);
  FGallery.SelectedEntry := FGallery.Entries[1];
  FGallery.Enabled := False;
  FGallery.Enabled := True;
  FView.Execute(TFmrElementPart.Main);
  Assert.AreEqual(1, FClicks);
  Assert.AreEqual('Entry0', FClicked);
end;

procedure TGalleryTests.HitTestingMatchesVisibleCellsAfterScrolling;
var
  I: Integer;
  Expected: string;
begin
  FGallery.SelectionMode := TFmrGallerySelectionMode.None;
  FView.ScrollRows(1000);
  PaintView;
  Assert.IsTrue(FView.TopRow > 0);
  Assert.IsTrue(FDrawn.Count <= FView.Columns * FView.VisibleRows);
  for I := 0 to FRects.Count - 1 do
  begin
    Expected := FDrawn[I].Caption;
    FView.HotPart := TFmrElementPart.Main;
    FView.MouseMoveAt(FRects[I].CenterPoint);
    FView.Execute(TFmrElementPart.Main);
    Assert.AreEqual(Expected, FClicked);
  end;
  Assert.AreEqual<Integer>(FRects.Count, FClicks);
  // The last row contains one cell: the blank second column must not execute anything.
  FView.MouseMoveAt(FRects.Last.CenterPoint + PointF(FGallery.ItemWidth, 0));
  FView.Execute(TFmrElementPart.Main);
  Assert.AreEqual<Integer>(FRects.Count, FClicks);
end;

procedure TGalleryTests.InRibbonClickCanDeleteEntryWhenRevertingPreview;
begin
  PaintView;
  FView.HotPart := TFmrElementPart.Main;
  FView.MouseMoveAt(FRects[0].CenterPoint);
  FDeleteOnRevert := True;
  FView.Execute(TFmrElementPart.Main);
  Assert.AreEqual(0, FGallery.EntryCount);
  Assert.AreEqual(0, FClicks);
end;

initialization
  TDUnitX.RegisterTestFixture(TGalleryTests);

end.
