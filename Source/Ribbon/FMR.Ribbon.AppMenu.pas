{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Application menu                                     }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.AppMenu;

/// TFmrRibbonApplicationMenu: an application menu in the style of Office 2007 (TFmrRibbon.ApplicationMenu := AppMenu; it implements
/// IFmrApplicationMenu). Layout of the popup:
///   - the orb of the ribbon painted pressed over the top-left corner, so the orb appears to lie on the menu (the
///     menu starts at the middle of the orb; with themes without an orb the menu opens below the "File" tab);
///   - left column: ItemLinks as large rows (32 dp glyph, caption, submenu arrow, split rows);
///   - right pane: the recent documents (ExtraPaneCaption, numbered rows with pin buttons, OnRecentClick) or, while a
///     left row with a submenu is hot, that submenu with a header (the item's Description, else its caption) and
///     large rows with descriptions;
///   - bottom band: Buttons (e.g. "Options", "Exit") right-aligned.
/// Keyboard: Up/Down, Right/Left between the column and the pane, Tab to the buttons, Enter, Esc, accelerators (the
/// '&' letter or the first letter, digits for recent documents); opened with the keyboard it shows key tips.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.KeyTips,
  FMR.Ribbon.Strings, FMR.Ribbon;

type
  TFmrRibbonApplicationMenu = class;

  /// <summary>A recent document of the application menu.</summary>
  TFmrRecentDocument = class(TCollectionItem)
  private
    FCaption: string;
    FFileName: string;
    FPinned: Boolean;
    FTag: NativeInt;
    FData: TObject;
    procedure SetCaption(const Value: string);
    procedure SetPinned(const Value: Boolean);
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(Source: TPersistent); override;
    property Data: TObject read FData write FData;
  published
    property Caption: string read FCaption write SetCaption;
    /// <summary>Full path (shown as the screen tip of the row).</summary>
    property FileName: string read FFileName write FFileName;
    property Pinned: Boolean read FPinned write SetPinned default False;
    property Tag: NativeInt read FTag write FTag default 0;
  end;

  TFmrRecentDocuments = class(TOwnedCollection)
  private
    function GetDocument(const AIndex: Integer): TFmrRecentDocument;
  public
    constructor Create(const AOwner: TPersistent);
    function Add: TFmrRecentDocument; overload;
    function Add(const ACaption: string; const AFileName: string = ''; const APinned: Boolean = False)
      : TFmrRecentDocument; overload;
    property Items[const AIndex: Integer]: TFmrRecentDocument read GetDocument; default;
  end;

  TFmrRecentDocumentEvent = procedure(Sender: TObject; const ADocument: TFmrRecentDocument) of object;

  TFmrAppMenuArea = (None, Left, Pane, Recent, Pin, Button, Orb);

  /// <summary>Content of the application menu popup.</summary>
  TFmrAppMenuContent = class(TControl, IFmrPopupContent)
  private type
    TRow = record
      Link: TFmrItemLink;
      Item: TFmrBarItem;
      Rect: TRectF;
      Separator: Boolean;
    end;
  private
    FMenu: TFmrRibbonApplicationMenu;
    FContext: IFmrPopupContext;
    [Weak] FRibbon: TFmrRibbon;
    FOrbScreen: TRectF;
    FOrbMode: Boolean;
    FOrb: TRectF;
    FBody: TRectF;
    FInner: TRectF;
    FLeftRect: TRectF;
    FPaneRect: TRectF;
    FBandTop: Single;
    FLeft: TList<TRow>;
    FSub: TList<TRow>;
    FButtons: TList<TRow>;
    FRecentRects: TArray<TRectF>;
    FSubItem: TFmrBarItem;
    FSubHeader: string;
    FHotArea: TFmrAppMenuArea;
    FHotIndex: Integer;
    FHotSplitArrow: Boolean;
    FFocusArea: TFmrAppMenuArea;
    FFocusIndex: Integer;
    FTimer: TTimer;
    FPendingSub: Integer;
    FSize: TSizeF;
    FLeftW: Single;
    FPaneW: Single;
    FRowH: Single;
    FKeyTips: Boolean;
    FKeyTipText: TArray<string>;
    FKeyTipTargets: TArray<TPair<TFmrAppMenuArea, Integer>>;
    FMatcher: TFmrKeyTipMatcher;
    FSubPopup: TFmrPopupForm;
    function Painter: TFmrRibbonPainter; inline;
    function Images: TCustomImageList; inline;
    function TopBandHeight: Single;
    procedure Measure;
    procedure Arrange;
    procedure BuildSub(const AItem: TFmrBarItem);
    function SubLinks(const AItem: TFmrBarItem): TFmrItemLinks;
    function HasSub(const AItem: TFmrBarItem): Boolean;
    function IsSplit(const AItem: TFmrBarItem): Boolean;
    function SubRowHeight(const AItem: TFmrBarItem): Single;
    function AreaAt(const P: TPointF; out AIndex: Integer; out ASplitArrow: Boolean): TFmrAppMenuArea;
    procedure SetHot(const AArea: TFmrAppMenuArea; const AIndex: Integer; const ASplitArrow: Boolean);
    procedure TimerProc(Sender: TObject);
    procedure ShowSub(const AIndex: Integer);
    procedure ExecuteItem(const AItem: TFmrBarItem);
    procedure ActivateLeft(const AIndex: Integer; const ASplitArrow, AByKeyboard: Boolean);
    procedure ActivateRecent(const AIndex: Integer);
    procedure TogglePin(const AIndex: Integer);
    procedure MoveFocus(const ADelta: Integer);
    function AreaCount(const AArea: TFmrAppMenuArea): Integer;
    function IsSelectable(const AArea: TFmrAppMenuArea; const AIndex: Integer): Boolean;
    procedure AssignKeyTips;
    procedure PaintRow(const ACanvas: TCanvas; const ARow: TRow; const AHot, ALarge, ASplitArrowHot: Boolean;
      const ADescription: Boolean);
    procedure OpenNestedMenu(const AIndex: Integer; const AByKeyboard: Boolean);
  protected
    { IFmrPopupContent }
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
    { TControl }
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor CreateContent(const AMenu: TFmrRibbonApplicationMenu; const AContext: IFmrPopupContext;
      const ARibbon: TFmrRibbon; const AOrbScreen: TRectF; const AOrbMode: Boolean);
    destructor Destroy; override;
    /// <summary>The item whose submenu the right pane shows (nil: the recent documents).</summary>
    property SubItem: TFmrBarItem read FSubItem;
    property HotArea: TFmrAppMenuArea read FHotArea;
    property HotIndex: Integer read FHotIndex;
  end;

  /// <summary>Application menu in the style of Office 2007: assign it to TFmrRibbon.ApplicationMenu.</summary>
  TFmrRibbonApplicationMenu = class(TFmxObject, IFmrItemLinksOwner, IFmrApplicationMenu)
  private
    FItemLinks: TFmrItemLinks;
    FButtons: TFmrItemLinks;
    FRecent: TFmrRecentDocuments;
    FExtraPaneCaption: string;
    FExtraPaneWidth: Single;
    FShowExtraPane: Boolean;
    FBarManager: TFmrBarManager;
    FPopup: TFmrPopupForm;
    FContent: TFmrAppMenuContent;
    FOnRecentClick: TFmrRecentDocumentEvent;
    FOnRecentPinChanged: TFmrRecentDocumentEvent;
    FOnPopup: TNotifyEvent;
    FOnCloseUp: TNotifyEvent;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetButtons(const Value: TFmrItemLinks);
    procedure SetRecent(const Value: TFmrRecentDocuments);
    procedure SetBarManager(const Value: TFmrBarManager);
    function IsExtraPaneWidthStored: Boolean;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoRecentClick(const ADocument: TFmrRecentDocument); virtual;
    procedure DoRecentPinChanged(const ADocument: TFmrRecentDocument); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { IFmrApplicationMenu }
    procedure ShowApplicationMenu(const ARibbon: TFmrRibbon; const AAnchor: TRectF; const AByKeyboard: Boolean);
    function IsApplicationMenuOpen: Boolean;
    procedure CloseApplicationMenu;
    /// <summary>The content of the open menu (nil when closed).</summary>
    property Content: TFmrAppMenuContent read FContent;
  published
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    /// <summary>Commands at the bottom right ("Options", "Exit").</summary>
    property Buttons: TFmrItemLinks read FButtons write SetButtons;
    /// <summary>Title of the right pane; empty = "Recent Documents".</summary>
    property ExtraPaneCaption: string read FExtraPaneCaption write FExtraPaneCaption;
    property ExtraPaneWidth: Single read FExtraPaneWidth write FExtraPaneWidth stored IsExtraPaneWidthStored;
    /// <summary>Large rows of the left column.</summary>
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    property RecentDocuments: TFmrRecentDocuments read FRecent write SetRecent;
    property ShowExtraPane: Boolean read FShowExtraPane write FShowExtraPane default True;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
    property OnRecentClick: TFmrRecentDocumentEvent read FOnRecentClick write FOnRecentClick;
    property OnRecentPinChanged: TFmrRecentDocumentEvent read FOnRecentPinChanged write FOnRecentPinChanged;
  end;

implementation

uses
  System.Character;

resourcestring
  SPinToList = 'Pin to list';
  SUnpinFromList = 'Unpin from list';

const
  BottomBandH = 34;
  ShadowM = 6;
  PinW = 24;

{ TFmrRecentDocument }

procedure TFmrRecentDocument.Assign(Source: TPersistent);
begin
  if Source is TFmrRecentDocument then
  begin
    FCaption := TFmrRecentDocument(Source).FCaption;
    FFileName := TFmrRecentDocument(Source).FFileName;
    FPinned := TFmrRecentDocument(Source).FPinned;
    FTag := TFmrRecentDocument(Source).FTag;
    FData := TFmrRecentDocument(Source).FData;
    Changed(False);
  end
  else
    inherited;
end;

function TFmrRecentDocument.GetDisplayName: string;
begin
  if FCaption <> '' then
    Result := FCaption
  else
    Result := inherited GetDisplayName;
end;

procedure TFmrRecentDocument.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed(False);
  end;
end;

procedure TFmrRecentDocument.SetPinned(const Value: Boolean);
begin
  if FPinned <> Value then
  begin
    FPinned := Value;
    Changed(False);
  end;
end;

{ TFmrRecentDocuments }

constructor TFmrRecentDocuments.Create(const AOwner: TPersistent);
begin
  inherited Create(AOwner, TFmrRecentDocument);
end;

function TFmrRecentDocuments.Add: TFmrRecentDocument;
begin
  Result := TFmrRecentDocument(inherited Add);
end;

function TFmrRecentDocuments.Add(const ACaption, AFileName: string; const APinned: Boolean): TFmrRecentDocument;
begin
  Result := Add;
  Result.FCaption := ACaption;
  Result.FFileName := AFileName;
  Result.FPinned := APinned;
end;

function TFmrRecentDocuments.GetDocument(const AIndex: Integer): TFmrRecentDocument;
begin
  Result := TFmrRecentDocument(inherited Items[AIndex]);
end;

{ TFmrAppMenuContent }

constructor TFmrAppMenuContent.CreateContent(const AMenu: TFmrRibbonApplicationMenu;
  const AContext: IFmrPopupContext; const ARibbon: TFmrRibbon; const AOrbScreen: TRectF; const AOrbMode: Boolean);
begin
  inherited Create(nil);
  FMenu := AMenu;
  FContext := AContext;
  FRibbon := ARibbon;
  FOrbScreen := AOrbScreen;
  FOrbMode := AOrbMode;
  FLeft := TList<TRow>.Create;
  FSub := TList<TRow>.Create;
  FButtons := TList<TRow>.Create;
  FMatcher := TFmrKeyTipMatcher.Create(nil);
  FHotIndex := -1;
  FFocusIndex := -1;
  FPendingSub := -1;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 350;
  FTimer.OnTimer := TimerProc;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
  Measure;
  Arrange;
end;

destructor TFmrAppMenuContent.Destroy;
begin
  if FSubPopup <> nil then
  begin
    FSubPopup.OnClosed := nil;
    if FmrPopupsAssigned then
      FmrPopups.Close(FSubPopup);
    FSubPopup := nil;
  end;
  FreeAndNil(FMatcher);
  FreeAndNil(FLeft);
  FreeAndNil(FSub);
  FreeAndNil(FButtons);
  FContext := nil;
  inherited;
end;

function TFmrAppMenuContent.Painter: TFmrRibbonPainter;
begin
  Result := FContext.Painter;
end;

function TFmrAppMenuContent.Images: TCustomImageList;
begin
  Result := FContext.Images;
end;

function TFmrAppMenuContent.TopBandHeight: Single;
begin
  // The band right of the lower half of the orb; a thin band without an orb.
  if FOrbMode then
    Result := Max(FOrbScreen.Height / 2, 18)
  else
    Result := 8;
end;

function TFmrAppMenuContent.SubLinks(const AItem: TFmrBarItem): TFmrItemLinks;
begin
  if AItem is TFmrSubItem then
    Result := TFmrSubItem(AItem).ItemLinks
  else if (AItem is TFmrButtonItem) and TFmrButtonItem(AItem).HasDropDown then
    Result := TFmrButtonItem(AItem).DropDownLinks
  else
    Result := nil;
end;

function TFmrAppMenuContent.HasSub(const AItem: TFmrBarItem): Boolean;
var
  L: TFmrItemLinks;
begin
  L := SubLinks(AItem);
  Result := (L <> nil) and (L.VisibleCount > 0);
end;

function TFmrAppMenuContent.IsSplit(const AItem: TFmrBarItem): Boolean;
begin
  Result := (AItem is TFmrButtonItem) and (TFmrButtonItem(AItem).ButtonStyle = TFmrButtonStyle.Split);
end;

function TFmrAppMenuContent.SubRowHeight(const AItem: TFmrBarItem): Single;
var
  P: TFmrRibbonPainter;
  TextW: Single;
begin
  P := Painter;
  if AItem is TFmrSeparatorItem then
  begin
    if AItem.Caption <> '' then
      Exit(P.Metrics.MenuItemHeight);
    Exit(7);
  end;
  TextW := FPaneW - P.Metrics.LargeGlyphSize - 30;
  Result := P.Metrics.LargeGlyphSize + 14;
  if AItem.Description <> '' then
    Result := Max(Result, 6 + P.TextSize('Wg', 0, True).Height + 2 +
      P.TextSize(AItem.Description, 0, False, TextW, True).Height + 8);
  Result := Ceil(Result);
end;

procedure TFmrAppMenuContent.Measure;
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  I, J: Integer;
  L: TFmrItemLink;
  LeftH, PaneH, H, W, BtnW: Single;
  Sub: TFmrItemLinks;
begin
  P := Painter;
  M := P.Metrics;
  FRowH := M.LargeGlyphSize + 10;
  FLeftW := 190;
  LeftH := 8;
  for I := 0 to FMenu.FItemLinks.Count - 1 do
  begin
    L := FMenu.FItemLinks[I];
    if not L.IsVisible or (L.Item = nil) then
      Continue;
    if L.Item is TFmrSeparatorItem then
      LeftH := LeftH + 8
    else
    begin
      if L.BeginGroup then
        LeftH := LeftH + 8;
      LeftH := LeftH + FRowH;
      FLeftW := Max(FLeftW, M.LargeGlyphSize + 22 + P.TextWidth(FmrStripAccel(L.Caption)) + 34);
    end;
  end;
  FLeftW := Ceil(FLeftW);
  if FMenu.FShowExtraPane then
    FPaneW := Max(220, FMenu.FExtraPaneWidth)
  else
    FPaneW := 0;
  // The pane is as tall as the tallest of the recent list and the submenus, so switching never resizes the menu.
  PaneH := M.MenuItemHeight + 10 + FMenu.FRecent.Count * M.MenuItemHeight + 8;
  if FMenu.FShowExtraPane then
    for I := 0 to FMenu.FItemLinks.Count - 1 do
    begin
      L := FMenu.FItemLinks[I];
      if not L.IsVisible or not HasSub(L.Item) then
        Continue;
      Sub := SubLinks(L.Item);
      H := M.MenuItemHeight + 10;
      for J := 0 to Sub.Count - 1 do
        if Sub[J].IsVisible and (Sub[J].Item <> nil) then
          H := H + SubRowHeight(Sub[J].Item);
      PaneH := Max(PaneH, H + 8);
    end;
  BtnW := 0;
  for I := 0 to FMenu.FButtons.Count - 1 do
    if FMenu.FButtons[I].IsVisible and (FMenu.FButtons[I].Item <> nil) then
      BtnW := BtnW + P.TextWidth(FmrStripAccel(FMenu.FButtons[I].Caption)) + M.SmallGlyphSize + 26;
  W := FLeftW + FPaneW + 14;
  W := Max(W, BtnW + 20);
  if FPaneW > 0 then
    FPaneW := W - FLeftW - 14;
  H := Max(LeftH, PaneH);
  FBandTop := 0;
  if FOrbMode then
    FBandTop := Round(FOrbScreen.Height / 2);
  FBody := RectF(0, FBandTop, W, FBandTop + TopBandHeight + H + BottomBandH);
  FSize := TSizeF.Create(Ceil(FBody.Right + ShadowM), Ceil(FBody.Bottom + ShadowM));
end;

procedure TFmrAppMenuContent.Arrange;
var
  I: Integer;
  L: TFmrItemLink;
  Row: TRow;
  Y, X, W: Single;
  M: TFmrThemeMetrics;
  TopBand: Single;
begin
  M := Painter.Metrics;
  TopBand := TopBandHeight;
  FInner := RectF(FBody.Left + 6, FBody.Top + TopBand, FBody.Right - 6, FBody.Bottom - BottomBandH);
  FLeftRect := RectF(FInner.Left, FInner.Top, FInner.Left + FLeftW, FInner.Bottom);
  if FPaneW > 0 then
    FPaneRect := RectF(FLeftRect.Right + 1, FInner.Top, FInner.Right, FInner.Bottom)
  else
    FPaneRect := TRectF.Empty;
  FLeft.Clear;
  Y := FInner.Top + 4;
  for I := 0 to FMenu.FItemLinks.Count - 1 do
  begin
    L := FMenu.FItemLinks[I];
    if not L.IsVisible or (L.Item = nil) then
      Continue;
    Row := Default(TRow);
    Row.Link := L;
    Row.Item := L.Item;
    if L.Item is TFmrSeparatorItem then
    begin
      Row.Separator := True;
      Row.Rect := RectF(FLeftRect.Left, Y, FLeftRect.Right, Y + 8);
      Y := Y + 8;
    end
    else
    begin
      if L.BeginGroup and (FLeft.Count > 0) then
      begin
        Row.Separator := True;
        Row.Rect := RectF(FLeftRect.Left, Y, FLeftRect.Right, Y + 8);
        FLeft.Add(Row);
        Y := Y + 8;
        Row.Separator := False;
      end;
      Row.Rect := RectF(FLeftRect.Left + 2, Y, FLeftRect.Right - 2, Y + FRowH);
      Y := Y + FRowH;
    end;
    FLeft.Add(Row);
  end;
  // recent documents
  SetLength(FRecentRects, FMenu.FRecent.Count);
  Y := FPaneRect.Top + M.MenuItemHeight + 10;
  for I := 0 to FMenu.FRecent.Count - 1 do
  begin
    FRecentRects[I] := RectF(FPaneRect.Left + 4, Y, FPaneRect.Right - 4, Y + M.MenuItemHeight);
    Y := Y + M.MenuItemHeight;
  end;
  // bottom buttons, right aligned
  FButtons.Clear;
  X := FBody.Right - 8;
  for I := FMenu.FButtons.Count - 1 downto 0 do
  begin
    L := FMenu.FButtons[I];
    if not L.IsVisible or (L.Item = nil) then
      Continue;
    W := Ceil(Painter.TextWidth(FmrStripAccel(L.Caption)) + M.SmallGlyphSize + 22);
    Row := Default(TRow);
    Row.Link := L;
    Row.Item := L.Item;
    Row.Rect := RectF(X - W, FBody.Bottom - BottomBandH + 5, X, FBody.Bottom - 5);
    FButtons.Insert(0, Row);
    X := X - W - 6;
  end;
  if FSubItem <> nil then
    BuildSub(FSubItem);
end;

procedure TFmrAppMenuContent.BuildSub(const AItem: TFmrBarItem);
var
  Links: TFmrItemLinks;
  I: Integer;
  Row: TRow;
  Y, H: Single;
begin
  FSub.Clear;
  FSubItem := AItem;
  if AItem = nil then
    Exit;
  FSubHeader := AItem.Description;
  if FSubHeader = '' then
    FSubHeader := FmrStripAccel(AItem.Caption);
  Links := SubLinks(AItem);
  if Links = nil then
    Exit;
  Y := FPaneRect.Top + Painter.Metrics.MenuItemHeight + 10;
  for I := 0 to Links.Count - 1 do
  begin
    if not Links[I].IsVisible or (Links[I].Item = nil) then
      Continue;
    Row := Default(TRow);
    Row.Link := Links[I];
    Row.Item := Links[I].Item;
    Row.Separator := (Row.Item is TFmrSeparatorItem) and (Row.Item.Caption = '');
    H := SubRowHeight(Row.Item);
    Row.Rect := RectF(FPaneRect.Left + 4, Y, FPaneRect.Right - 4, Y + H);
    FSub.Add(Row);
    Y := Y + H;
  end;
end;

function TFmrAppMenuContent.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FSize.Width + 2, FSize.Height + 2);
end;

function TFmrAppMenuContent.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

procedure TFmrAppMenuContent.PopupShown(const AByKeyboard: Boolean);
var
  TL: TPointF;
begin
  // The orb is painted where the ribbon paints it, whatever position the popup got.
  TL := ScreenToLocal(FOrbScreen.TopLeft);
  FOrb := RectF(TL.X, TL.Y, TL.X + FOrbScreen.Width, TL.Y + FOrbScreen.Height);
  FKeyTips := AByKeyboard;
  if FKeyTips then
    AssignKeyTips;
  if AByKeyboard then
  begin
    FFocusArea := TFmrAppMenuArea.Left;
    FFocusIndex := -1;
    MoveFocus(1);
  end;
  Repaint;
end;

procedure TFmrAppMenuContent.PopupClosed;
begin
  FTimer.Enabled := False;
  if FSubPopup <> nil then
  begin
    FSubPopup.OnClosed := nil;
    FSubPopup := nil;
  end;
end;

procedure TFmrAppMenuContent.AssignKeyTips;
var
  Entries: TArray<TFmrKeyTipEntry>;
  Targets: TList<TPair<TFmrAppMenuArea, Integer>>;
  Tips: TArray<string>;
  I, N: Integer;
begin
  Targets := TList<TPair<TFmrAppMenuArea, Integer>>.Create;
  try
    for I := 0 to FLeft.Count - 1 do
      if not FLeft[I].Separator then
        Targets.Add(TPair<TFmrAppMenuArea, Integer>.Create(TFmrAppMenuArea.Left, I));
    for I := 0 to FButtons.Count - 1 do
      Targets.Add(TPair<TFmrAppMenuArea, Integer>.Create(TFmrAppMenuArea.Button, I));
    N := Targets.Count;
    SetLength(Entries, N);
    for I := 0 to N - 1 do
      if Targets[I].Key = TFmrAppMenuArea.Left then
        Entries[I] := TFmrKeyTipEntry.Create(FLeft[Targets[I].Value].Link.Caption,
          FLeft[Targets[I].Value].Link.EffectiveKeyTip, I)
      else
        Entries[I] := TFmrKeyTipEntry.Create(FButtons[Targets[I].Value].Link.Caption,
          FButtons[Targets[I].Value].Link.EffectiveKeyTip, I);
    // Recent documents get the digits 1..9 (reserved, so letters never collide with them).
    TFmrKeyTipAssigner.Assign(Entries, TFmrKeyTipStyle.Letters, ['1', '2', '3', '4', '5', '6', '7', '8', '9']);
    if FPaneW > 0 then
      for I := 0 to Min(8, FMenu.FRecent.Count - 1) do
      begin
        Targets.Add(TPair<TFmrAppMenuArea, Integer>.Create(TFmrAppMenuArea.Recent, I));
        Entries := Entries + [TFmrKeyTipEntry.Create('', IntToStr(I + 1), Targets.Count - 1)];
        Entries[High(Entries)].KeyTip := IntToStr(I + 1);
      end;
    SetLength(Tips, Length(Entries));
    for I := 0 to High(Entries) do
      Tips[I] := Entries[I].KeyTip;
    FKeyTipText := Tips;
    FKeyTipTargets := Targets.ToArray;
    FMatcher.Reset(Tips);
  finally
    Targets.Free;
  end;
end;

function TFmrAppMenuContent.AreaAt(const P: TPointF; out AIndex: Integer; out ASplitArrow: Boolean)
  : TFmrAppMenuArea;
var
  I: Integer;
  R: TRectF;
begin
  AIndex := -1;
  ASplitArrow := False;
  if FOrbMode and not FOrb.IsEmpty and (P.Y < FBody.Top + 2) then
  begin
    if FOrb.Contains(P) then
      Exit(TFmrAppMenuArea.Orb);
    Exit(TFmrAppMenuArea.None);
  end;
  if FOrbMode and not FOrb.IsEmpty and (P.Distance(FOrb.CenterPoint) <= FOrb.Width / 2) then
    Exit(TFmrAppMenuArea.Orb);
  for I := 0 to FLeft.Count - 1 do
    if not FLeft[I].Separator and FLeft[I].Rect.Contains(P) then
    begin
      AIndex := I;
      ASplitArrow := IsSplit(FLeft[I].Item) and HasSub(FLeft[I].Item) and (P.X >= FLeft[I].Rect.Right - 26);
      Exit(TFmrAppMenuArea.Left);
    end;
  if FSubItem <> nil then
  begin
    for I := 0 to FSub.Count - 1 do
      if not FSub[I].Separator and not (FSub[I].Item is TFmrSeparatorItem) and FSub[I].Rect.Contains(P) then
      begin
        AIndex := I;
        Exit(TFmrAppMenuArea.Pane);
      end;
  end
  else
    for I := 0 to High(FRecentRects) do
      if FRecentRects[I].Contains(P) then
      begin
        AIndex := I;
        R := FRecentRects[I];
        if P.X >= R.Right - PinW then
          Exit(TFmrAppMenuArea.Pin);
        Exit(TFmrAppMenuArea.Recent);
      end;
  for I := 0 to FButtons.Count - 1 do
    if FButtons[I].Rect.Contains(P) then
    begin
      AIndex := I;
      Exit(TFmrAppMenuArea.Button);
    end;
  Result := TFmrAppMenuArea.None;
end;

procedure TFmrAppMenuContent.SetHot(const AArea: TFmrAppMenuArea; const AIndex: Integer;
  const ASplitArrow: Boolean);
begin
  if (AArea = FHotArea) and (AIndex = FHotIndex) and (ASplitArrow = FHotSplitArrow) then
    Exit;
  FHotArea := AArea;
  FHotIndex := AIndex;
  FHotSplitArrow := ASplitArrow;
  if AArea <> TFmrAppMenuArea.None then
  begin
    FFocusArea := AArea;
    FFocusIndex := AIndex;
    if AArea = TFmrAppMenuArea.Pin then
      FFocusArea := TFmrAppMenuArea.Recent;
  end;
  // Hovering a left row switches the pane after a short delay: its submenu, or back to the recent documents.
  if AArea = TFmrAppMenuArea.Left then
  begin
    FPendingSub := AIndex;
    FTimer.Enabled := False;
    FTimer.Enabled := True;
  end
  else if AArea <> TFmrAppMenuArea.None then
    FTimer.Enabled := False;
  Repaint;
end;

procedure TFmrAppMenuContent.TimerProc(Sender: TObject);
begin
  FTimer.Enabled := False;
  if (FPendingSub >= 0) and (FHotArea = TFmrAppMenuArea.Left) and (FHotIndex = FPendingSub) then
    ShowSub(FPendingSub);
end;

procedure TFmrAppMenuContent.ShowSub(const AIndex: Integer);
var
  Item: TFmrBarItem;
begin
  if (AIndex < 0) or (AIndex >= FLeft.Count) or (FPaneW <= 0) then
    Exit;
  Item := FLeft[AIndex].Item;
  if not HasSub(Item) or not Item.Enabled then
    Item := nil;
  if Item <> FSubItem then
  begin
    if Item is TFmrSubItem then
      TFmrSubItem(Item).Popup
    else if Item is TFmrButtonItem then
      TFmrButtonItem(Item).DropDown;
    BuildSub(Item);
    Repaint;
  end;
end;

procedure TFmrAppMenuContent.ExecuteItem(const AItem: TFmrBarItem);
var
  Ctx: IFmrPopupContext;
begin
  if (AItem = nil) or not AItem.Enabled then
    Exit;
  Ctx := FContext;
  FmrPopups.CloseAll;
  // From the message loop: the menu is freed soon and a command may show a modal dialog.
  TThread.ForceQueue(nil,
    procedure
    begin
      Ctx.ItemExecuting(AItem);
      AItem.Click;
    end);
end;

procedure TFmrAppMenuContent.ActivateLeft(const AIndex: Integer; const ASplitArrow, AByKeyboard: Boolean);
var
  Item: TFmrBarItem;
begin
  if (AIndex < 0) or (AIndex >= FLeft.Count) or FLeft[AIndex].Separator then
    Exit;
  Item := FLeft[AIndex].Item;
  if not Item.Enabled then
    Exit;
  if HasSub(Item) and (not IsSplit(Item) or ASplitArrow) then
  begin
    if FPaneW > 0 then
    begin
      ShowSub(AIndex);
      if AByKeyboard then
      begin
        FFocusArea := TFmrAppMenuArea.Pane;
        FFocusIndex := -1;
        MoveFocus(1);
      end;
    end;
    Exit;
  end;
  ExecuteItem(Item);
end;

procedure TFmrAppMenuContent.ActivateRecent(const AIndex: Integer);
var
  Menu: TFmrRibbonApplicationMenu;
  Doc: TFmrRecentDocument;
begin
  if (AIndex < 0) or (AIndex >= FMenu.FRecent.Count) then
    Exit;
  Menu := FMenu;
  Doc := Menu.FRecent[AIndex];
  FmrPopups.CloseAll;
  TThread.ForceQueue(nil,
    procedure
    begin
      Menu.DoRecentClick(Doc);
    end);
end;

procedure TFmrAppMenuContent.TogglePin(const AIndex: Integer);
var
  Doc: TFmrRecentDocument;
begin
  if (AIndex < 0) or (AIndex >= FMenu.FRecent.Count) then
    Exit;
  Doc := FMenu.FRecent[AIndex];
  Doc.Pinned := not Doc.Pinned;
  FMenu.DoRecentPinChanged(Doc);
  Repaint;
end;

procedure TFmrAppMenuContent.OpenNestedMenu(const AIndex: Integer; const AByKeyboard: Boolean);
var
  Content: TControl;
  TL, BR: TPointF;
  P, Mine: TFmrPopupForm;
  F: TCommonCustomForm;
begin
  // A row of the right pane with its own submenu opens a normal menu to its right.
  if (AIndex < 0) or (AIndex >= FSub.Count) then
    Exit;
  Content := FmrCreateDropDownContent(FSub[AIndex].Item, FContext);
  if Content = nil then
    Exit;
  F := FmrFormOf(Self);
  Mine := nil;
  if F is TFmrPopupForm then
    Mine := TFmrPopupForm(F);
  P := TFmrPopupForm.CreatePopup(FContext, Content);
  FSubPopup := P;
  P.OnClosed :=
    procedure
    begin
      if FSubPopup = P then
        FSubPopup := nil;
    end;
  TL := LocalToScreen(PointF(FSub[AIndex].Rect.Left, FSub[AIndex].Rect.Top));
  BR := LocalToScreen(PointF(FSub[AIndex].Rect.Right, FSub[AIndex].Rect.Bottom));
  FmrPopups.Show(P, RectF(TL.X, TL.Y, BR.X, BR.Y), TFmrPopupPlacement.Right, Mine, AByKeyboard);
end;

function TFmrAppMenuContent.AreaCount(const AArea: TFmrAppMenuArea): Integer;
begin
  case AArea of
    TFmrAppMenuArea.Left: Result := FLeft.Count;
    TFmrAppMenuArea.Pane: Result := FSub.Count;
    TFmrAppMenuArea.Recent: Result := Length(FRecentRects);
    TFmrAppMenuArea.Button: Result := FButtons.Count;
  else
    Result := 0;
  end;
end;

function TFmrAppMenuContent.IsSelectable(const AArea: TFmrAppMenuArea; const AIndex: Integer): Boolean;
begin
  case AArea of
    TFmrAppMenuArea.Left: Result := not FLeft[AIndex].Separator;
    TFmrAppMenuArea.Pane: Result := not FSub[AIndex].Separator and not (FSub[AIndex].Item is TFmrSeparatorItem);
    TFmrAppMenuArea.Recent, TFmrAppMenuArea.Button: Result := True;
  else
    Result := False;
  end;
end;

procedure TFmrAppMenuContent.MoveFocus(const ADelta: Integer);
var
  N, I, K: Integer;
begin
  N := AreaCount(FFocusArea);
  if N = 0 then
    Exit;
  I := FFocusIndex;
  for K := 1 to N do
  begin
    I := I + ADelta;
    if I >= N then
      I := 0
    else if I < 0 then
      I := N - 1;
    if IsSelectable(FFocusArea, I) then
    begin
      FFocusIndex := I;
      FHotArea := FFocusArea;
      FHotIndex := I;
      FHotSplitArrow := False;
      if FFocusArea = TFmrAppMenuArea.Left then
        ShowSub(I);
      Repaint;
      Exit;
    end;
  end;
end;

procedure TFmrAppMenuContent.PaintRow(const ACanvas: TCanvas; const ARow: TRow; const AHot, ALarge,
  ASplitArrowHot: Boolean; const ADescription: Boolean);
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  R, GR, TR, AR: TRectF;
  G: TFmrImageSource;
  Enabled: Boolean;
  TextColor, DimColor: TAlphaColor;
  CapH, GS: Single;
  Caption: string;
begin
  P := Painter;
  M := P.Metrics;
  R := ARow.Rect;
  Enabled := ARow.Item.Enabled;
  if Enabled then
    TextColor := P.Theme.Colors[TFmrToken.MenuItemText]
  else
    TextColor := P.Theme.Colors[TFmrToken.MenuItemTextDisabled];
  DimColor := P.Theme.Colors[TFmrToken.MenuShortcutText];
  if AHot and Enabled then
  begin
    if IsSplit(ARow.Item) and HasSub(ARow.Item) and ALarge and not ADescription then
    begin
      AR := RectF(R.Right - 26, R.Top, R.Right, R.Bottom);
      if ASplitArrowHot then
        P.DrawMenuItem(ACanvas, AR, TFmrPartState.Hot)
      else
        P.DrawMenuItem(ACanvas, RectF(R.Left, R.Top, AR.Left, R.Bottom), TFmrPartState.Hot);
      P.Line(ACanvas, PointF(Round(AR.Left) + 0.5, R.Top + 5), PointF(Round(AR.Left) + 0.5, R.Bottom - 5),
        P.Theme.Colors[TFmrToken.MenuSeparator]);
    end
    else
      P.DrawMenuItem(ACanvas, R, TFmrPartState.Hot);
  end;
  if ALarge then
    GS := M.LargeGlyphSize
  else
    GS := M.SmallGlyphSize;
  G := nil;
  if not ARow.Item.Glyph.IsEmpty(Images) then
    G := ARow.Item.Glyph;
  TR := RectF(R.Left + 8, R.Top, R.Right - 8, R.Bottom);
  if ALarge then
  begin
    GR := RectF(0, 0, GS, GS);
    if ADescription then
      GR.Offset(Round(R.Left + 6), Round(R.Top + 6))
    else
      GR.Offset(Round(R.Left + 6), Round(R.CenterPoint.Y - GS / 2));
    TR.Left := GR.Right + 10;
  end
  else
  begin
    GR := RectF(0, 0, GS, GS);
    GR.Offset(Round(R.Left + 6), Round(R.CenterPoint.Y - GS / 2));
    TR.Left := GR.Right + 6;
  end;
  if G <> nil then
  begin
    if Enabled then
      G.Draw(ACanvas, GR, 1, P.GlyphTint(TFmrPartState.Normal), Images)
    else
      G.Draw(ACanvas, GR, 0.45, P.GlyphTint(TFmrPartState.Disabled), Images);
  end;
  Caption := FmrStripAccel(ARow.Link.Caption);
  if ADescription then
  begin
    CapH := P.TextSize('Wg', 0, True).Height;
    P.TextEx(ACanvas, RectF(TR.Left, R.Top + 6, TR.Right, R.Top + 6 + CapH), Caption, TextColor, TTextAlign.Leading,
      TTextAlign.Leading, 0, True, False);
    if ARow.Item.Description <> '' then
      P.TextEx(ACanvas, RectF(TR.Left, R.Top + 8 + CapH, TR.Right, R.Bottom - 2), ARow.Item.Description, DimColor,
        TTextAlign.Leading, TTextAlign.Leading, 0, False, True);
  end
  else
  begin
    if ALarge and HasSub(ARow.Item) then
      TR.Right := R.Right - 28;
    P.TextEx(ACanvas, TR, Caption, TextColor, TTextAlign.Leading, TTextAlign.Center, 0, False, False);
    if ALarge and HasSub(ARow.Item) then
      P.Arrow(ACanvas, PointF(R.Right - 13, R.CenterPoint.Y), TFmrArrowDirection.Right, TextColor);
  end;
end;

procedure TFmrAppMenuContent.Paint;
var
  P: TFmrRibbonPainter;
  M: TFmrThemeMetrics;
  I, K: Integer;
  Row: TRow;
  R, HR, PR: TRectF;
  Doc: TFmrRecentDocument;
  Caption, Tip: string;
  TextColor: TAlphaColor;
  Hot: Boolean;
  Sz: TSizeF;
  A: TPointF;
  Target: TPair<TFmrAppMenuArea, Integer>;
begin
  P := Painter;
  M := P.Metrics;
  P.DrawShadow(Canvas, FBody, Max(M.MenuRadius, 3), ShadowM - 1);
  P.DrawAppMenuFrame(Canvas, FBody, FInner);
  TextColor := P.Theme.Colors[TFmrToken.MenuItemText];
  // left column
  for I := 0 to FLeft.Count - 1 do
  begin
    Row := FLeft[I];
    if Row.Separator then
    begin
      P.DrawMenuSeparator(Canvas, RectF(Row.Rect.Left + 4, Row.Rect.Top, Row.Rect.Right - 4, Row.Rect.Bottom), 0);
      Continue;
    end;
    Hot := (FHotArea = TFmrAppMenuArea.Left) and (FHotIndex = I);
    PaintRow(Canvas, Row, Hot or (FSubItem = Row.Item), True, Hot and FHotSplitArrow, False);
  end;
  // right pane: a submenu or the recent documents
  if FPaneW > 0 then
  begin
    PR := FPaneRect;
    P.Fill(Canvas, PR, TFmrToken.MenuHeaderFill);
    P.Line(Canvas, PointF(Round(PR.Left) - 0.5, PR.Top), PointF(Round(PR.Left) - 0.5, PR.Bottom),
      P.Theme.Colors[TFmrToken.MenuBorder]);
    HR := RectF(PR.Left + 8, PR.Top + 4, PR.Right - 8, PR.Top + 4 + M.MenuItemHeight);
    if FSubItem <> nil then
      Caption := FSubHeader
    else if FMenu.FExtraPaneCaption <> '' then
      Caption := FMenu.FExtraPaneCaption
    else
      Caption := FmrStr(TFmrStringId.AppMenuRecent);
    P.TextEx(Canvas, HR, Caption, P.Theme.Colors[TFmrToken.MenuHeaderText], TTextAlign.Leading, TTextAlign.Center, 0,
      True, False);
    P.Line(Canvas, PointF(PR.Left + 6, Round(HR.Bottom + 3) + 0.5), PointF(PR.Right - 6, Round(HR.Bottom + 3) + 0.5),
      P.Theme.Colors[TFmrToken.MenuSeparator]);
    if FSubItem <> nil then
    begin
      for I := 0 to FSub.Count - 1 do
      begin
        Row := FSub[I];
        if Row.Item is TFmrSeparatorItem then
        begin
          if Row.Item.Caption <> '' then
            P.DrawMenuHeader(Canvas, Row.Rect, Row.Item.Caption)
          else
            P.DrawMenuSeparator(Canvas, Row.Rect, 0);
          Continue;
        end;
        PaintRow(Canvas, Row, (FHotArea = TFmrAppMenuArea.Pane) and (FHotIndex = I), True, False, True);
      end;
    end
    else
      for I := 0 to FMenu.FRecent.Count - 1 do
      begin
        R := FRecentRects[I];
        Doc := FMenu.FRecent[I];
        Hot := (FHotArea in [TFmrAppMenuArea.Recent, TFmrAppMenuArea.Pin]) and (FHotIndex = I);
        if Hot then
          P.DrawMenuItem(Canvas, R, TFmrPartState.Hot);
        if (FHotArea = TFmrAppMenuArea.Pin) and (FHotIndex = I) then
          P.DrawButton(Canvas, RectF(R.Right - PinW + 1, R.Top + 1, R.Right - 1, R.Bottom - 1), TFmrPartState.Hot);
        // The number is the accelerator of the row; with key tips the badge shows it instead.
        if (I < 9) and not FKeyTips then
          P.Text(Canvas, RectF(R.Left + 4, R.Top, R.Left + 18, R.Bottom), IntToStr(I + 1), TextColor,
            TTextAlign.Leading, TTextAlign.Center);
        P.TextEx(Canvas, RectF(R.Left + 20, R.Top, R.Right - PinW - 2, R.Bottom), Doc.Caption, TextColor,
          TTextAlign.Leading, TTextAlign.Center, 0, False, False);
        if Hot or Doc.Pinned then
          P.DrawPinGlyph(Canvas, RectF(R.Right - PinW, R.Top, R.Right, R.Bottom), Doc.Pinned,
            P.Theme.Colors[TFmrToken.MenuShortcutText]);
      end;
  end;
  // bottom buttons
  for I := 0 to FButtons.Count - 1 do
  begin
    Row := FButtons[I];
    Hot := (FHotArea = TFmrAppMenuArea.Button) and (FHotIndex = I);
    if Hot then
      P.DrawButton(Canvas, Row.Rect, TFmrPartState.Hot)
    else
    begin
      P.Fill(Canvas, Row.Rect, TFmrToken.MenuFill, M.ButtonRadius);
      P.Frame(Canvas, Row.Rect, TFmrToken.MenuBorder, M.ButtonRadius);
    end;
    PaintRow(Canvas, Row, False, False, False, False);
  end;
  // the orb lies on the menu
  if FOrbMode and not FOrb.IsEmpty and (FRibbon <> nil) then
    P.DrawAppButton(Canvas, FOrb, FRibbon.ApplicationButton.DisplayCaption, TFmrPartState.Pressed);
  // key tips
  if FKeyTips then
    for K := 0 to High(FKeyTipText) do
    begin
      if not FMatcher.IsCandidate(K) or (FKeyTipText[K] = '') then
        Continue;
      Target := FKeyTipTargets[K];
      case Target.Key of
        TFmrAppMenuArea.Left: R := FLeft[Target.Value].Rect;
        TFmrAppMenuArea.Button: R := FButtons[Target.Value].Rect;
        TFmrAppMenuArea.Recent:
          begin
            if FSubItem <> nil then
              Continue;
            R := FRecentRects[Target.Value];
          end;
      else
        Continue;
      end;
      Tip := FKeyTipText[K];
      Sz := P.KeyTipSize(Tip);
      case Target.Key of
        TFmrAppMenuArea.Left: A := PointF(R.Left + 6 + M.LargeGlyphSize - 4, R.Bottom - 6);
        TFmrAppMenuArea.Recent: A := PointF(R.Left + 11, R.CenterPoint.Y);
      else
        A := PointF(R.Left + 10, R.Bottom - 4);
      end;
      P.DrawKeyTip(Canvas, RectF(Round(A.X - Sz.Width / 2), Round(A.Y - Sz.Height / 2), Round(A.X - Sz.Width / 2) +
        Sz.Width, Round(A.Y - Sz.Height / 2) + Sz.Height), Tip, True);
    end;
end;

procedure TFmrAppMenuContent.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Area: TFmrAppMenuArea;
  Idx: Integer;
  Arrow: Boolean;
begin
  inherited;
  Area := AreaAt(PointF(X, Y), Idx, Arrow);
  if Area = TFmrAppMenuArea.Orb then
    Area := TFmrAppMenuArea.None;
  if (Area = TFmrAppMenuArea.None) and (FHotArea = TFmrAppMenuArea.None) then
    Exit;
  SetHot(Area, Idx, Arrow);
end;

procedure TFmrAppMenuContent.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Idx: Integer;
  Arrow: Boolean;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  case AreaAt(PointF(X, Y), Idx, Arrow) of
    TFmrAppMenuArea.Orb:
      FmrPopups.CloseAll;
    TFmrAppMenuArea.Left:
      // Submenus open on press, like the arrows of menus.
      if HasSub(FLeft[Idx].Item) and (not IsSplit(FLeft[Idx].Item) or Arrow) then
        ActivateLeft(Idx, Arrow, False);
  end;
end;

procedure TFmrAppMenuContent.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Idx: Integer;
  Arrow: Boolean;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  case AreaAt(PointF(X, Y), Idx, Arrow) of
    TFmrAppMenuArea.Left:
      if not HasSub(FLeft[Idx].Item) or (IsSplit(FLeft[Idx].Item) and not Arrow) then
        ActivateLeft(Idx, Arrow, False);
    TFmrAppMenuArea.Pane:
      if FmrItemHasDropDown(FSub[Idx].Item) and not IsSplit(FSub[Idx].Item) then
        OpenNestedMenu(Idx, False)
      else
        ExecuteItem(FSub[Idx].Item);
    TFmrAppMenuArea.Recent:
      ActivateRecent(Idx);
    TFmrAppMenuArea.Pin:
      TogglePin(Idx);
    TFmrAppMenuArea.Button:
      ExecuteItem(FButtons[Idx].Item);
  end;
end;

procedure TFmrAppMenuContent.DoMouseLeave;
begin
  inherited;
  FTimer.Enabled := False;
  FHotArea := TFmrAppMenuArea.None;
  FHotIndex := -1;
  Repaint;
end;

function TFmrAppMenuContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
var
  Ch: Char;
  Latin: Char;
  I, Found: Integer;
  Match: TFmrKeyTipMatch;
  Target: TPair<TFmrAppMenuArea, Integer>;
  Caption: string;
begin
  Result := True;
  case Key of
    vkUp:
      MoveFocus(-1);
    vkDown:
      MoveFocus(1);
    vkRight:
      if (FFocusArea = TFmrAppMenuArea.Left) and (FFocusIndex >= 0) then
      begin
        if HasSub(FLeft[FFocusIndex].Item) then
          ActivateLeft(FFocusIndex, True, True)
        else if (FPaneW > 0) and (FSubItem = nil) and (FMenu.FRecent.Count > 0) then
        begin
          FFocusArea := TFmrAppMenuArea.Recent;
          FFocusIndex := -1;
          MoveFocus(1);
        end;
      end
      else if FFocusArea = TFmrAppMenuArea.Button then
        MoveFocus(1);
    vkLeft:
      if FFocusArea in [TFmrAppMenuArea.Pane, TFmrAppMenuArea.Recent] then
      begin
        FFocusArea := TFmrAppMenuArea.Left;
        for I := 0 to FLeft.Count - 1 do
          if (FSubItem <> nil) and (FLeft[I].Item = FSubItem) then
            FFocusIndex := I;
        FHotArea := FFocusArea;
        FHotIndex := FFocusIndex;
        Repaint;
      end
      else if FFocusArea = TFmrAppMenuArea.Button then
        MoveFocus(-1);
    vkTab:
      begin
        if FFocusArea = TFmrAppMenuArea.Button then
          FFocusArea := TFmrAppMenuArea.Left
        else
          FFocusArea := TFmrAppMenuArea.Button;
        FFocusIndex := -1;
        MoveFocus(1);
      end;
    vkReturn, vkSpace:
      case FFocusArea of
        TFmrAppMenuArea.Left:
          ActivateLeft(FFocusIndex, False, True);
        TFmrAppMenuArea.Pane:
          if (FFocusIndex >= 0) and (FFocusIndex < FSub.Count) then
          begin
            if FmrItemHasDropDown(FSub[FFocusIndex].Item) and not IsSplit(FSub[FFocusIndex].Item) then
              OpenNestedMenu(FFocusIndex, True)
            else
              ExecuteItem(FSub[FFocusIndex].Item);
          end;
        TFmrAppMenuArea.Recent:
          ActivateRecent(FFocusIndex);
        TFmrAppMenuArea.Button:
          if (FFocusIndex >= 0) and (FFocusIndex < FButtons.Count) then
            ExecuteItem(FButtons[FFocusIndex].Item);
      end;
    vkEscape:
      Result := False;
    vkBack:
      if FKeyTips and not FMatcher.Backspace then
        Result := False
      else
        Repaint;
  else
    begin
      if (KeyChar = #0) and (((Key >= Ord('A')) and (Key <= Ord('Z'))) or ((Key >= Ord('0')) and (Key <= Ord('9'))))
        and ([ssCtrl, ssAlt] * Shift = []) then
        KeyChar := Char(Key);
      if (KeyChar = #0) or ([ssCtrl, ssAlt] * Shift <> []) then
        Exit(True);
      Ch := Char(KeyChar).ToUpper;
      Latin := FmrLatinKeyChar(Key, KeyChar);
      if FKeyTips and (Length(FKeyTipText) > 0) then
      begin
        Match := FMatcher.Press(Ch);
        if (Match = TFmrKeyTipMatch.None) and (Latin <> #0) and (Latin <> Ch) then
          Match := FMatcher.Press(Latin);
        case Match of
          TFmrKeyTipMatch.Complete:
            begin
              Target := FKeyTipTargets[FMatcher.MatchedIndex];
              FMatcher.Reset;
              case Target.Key of
                TFmrAppMenuArea.Left:
                  begin
                    FFocusArea := TFmrAppMenuArea.Left;
                    FFocusIndex := Target.Value;
                    FHotArea := FFocusArea;
                    FHotIndex := FFocusIndex;
                    ActivateLeft(Target.Value, True, True);
                  end;
                TFmrAppMenuArea.Button:
                  ExecuteItem(FButtons[Target.Value].Item);
                TFmrAppMenuArea.Recent:
                  ActivateRecent(Target.Value);
              end;
            end;
          TFmrKeyTipMatch.Partial:
            ;
        end;
        Repaint;
        Exit(True);
      end;
      // Digits open recent documents; letters are accelerators of the left column.
      if CharInSet(Ch, ['1'..'9']) and (FSubItem = nil) then
      begin
        ActivateRecent(Ord(Ch) - Ord('1'));
        Exit(True);
      end;
      Found := -1;
      for I := 0 to FLeft.Count - 1 do
      begin
        if FLeft[I].Separator then
          Continue;
        Caption := FLeft[I].Link.Caption;
        if (Caption.ToUpper.IndexOf('&' + Ch) >= 0) or ((Caption.IndexOf('&') < 0) and
          Caption.ToUpper.StartsWith(Ch)) or ((Latin <> #0) and (Caption.ToUpper.IndexOf('&' + Latin) >= 0)) then
        begin
          Found := I;
          Break;
        end;
      end;
      if Found >= 0 then
      begin
        FFocusArea := TFmrAppMenuArea.Left;
        FFocusIndex := Found;
        FHotArea := FFocusArea;
        FHotIndex := Found;
        ActivateLeft(Found, True, True);
      end;
    end;
  end;
end;

{ TFmrRibbonApplicationMenu }

constructor TFmrRibbonApplicationMenu.Create(AOwner: TComponent);
begin
  inherited;
  FItemLinks := TFmrItemLinks.Create(Self);
  FButtons := TFmrItemLinks.Create(Self);
  FRecent := TFmrRecentDocuments.Create(Self);
  FExtraPaneWidth := 300;
  FShowExtraPane := True;
end;

destructor TFmrRibbonApplicationMenu.Destroy;
begin
  CloseApplicationMenu;
  FreeAndNil(FItemLinks);
  FreeAndNil(FButtons);
  FreeAndNil(FRecent);
  inherited;
end;

procedure TFmrRibbonApplicationMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FBarManager) then
    FBarManager := nil;
end;

procedure TFmrRibbonApplicationMenu.SetBarManager(const Value: TFmrBarManager);
begin
  if FBarManager <> Value then
  begin
    if FBarManager <> nil then
      FBarManager.RemoveFreeNotification(Self);
    FBarManager := Value;
    if FBarManager <> nil then
      FBarManager.FreeNotification(Self);
  end;
end;

procedure TFmrRibbonApplicationMenu.SetButtons(const Value: TFmrItemLinks);
begin
  FButtons.Assign(Value);
end;

procedure TFmrRibbonApplicationMenu.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrRibbonApplicationMenu.SetRecent(const Value: TFmrRecentDocuments);
begin
  FRecent.Assign(Value);
end;

function TFmrRibbonApplicationMenu.IsExtraPaneWidthStored: Boolean;
begin
  Result := FExtraPaneWidth <> 300;
end;

procedure TFmrRibbonApplicationMenu.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
end;

procedure TFmrRibbonApplicationMenu.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

procedure TFmrRibbonApplicationMenu.LinksChanged(const ALinks: TFmrItemLinks);
begin
end;

procedure TFmrRibbonApplicationMenu.DoRecentClick(const ADocument: TFmrRecentDocument);
begin
  if Assigned(FOnRecentClick) then
    FOnRecentClick(Self, ADocument);
end;

procedure TFmrRibbonApplicationMenu.DoRecentPinChanged(const ADocument: TFmrRecentDocument);
begin
  if Assigned(FOnRecentPinChanged) then
    FOnRecentPinChanged(Self, ADocument);
end;

procedure TFmrRibbonApplicationMenu.ShowApplicationMenu(const ARibbon: TFmrRibbon; const AAnchor: TRectF;
  const AByKeyboard: Boolean);
var
  Ctx: IFmrPopupContext;
  Images: TCustomImageList;
  Form: TCommonCustomForm;
  OrbMode: Boolean;
  Anchor: TRectF;
begin
  CloseApplicationMenu;
  if (ARibbon = nil) or (csDesigning in ComponentState) then
    Exit;
  if Assigned(FOnPopup) then
    FOnPopup(Self);
  Images := nil;
  if FBarManager <> nil then
    Images := FBarManager.Images;
  if (Images = nil) and (ARibbon.BarManager <> nil) then
    Images := ARibbon.BarManager.Images;
  Form := FmrFormOf(ARibbon);
  Ctx := TFmrPopupContext.Create(ARibbon.Painter, Images, Form);
  Ctx.KeyTipsActive := AByKeyboard;
  OrbMode := ARibbon.Painter.Theme.Style.AppButton = TFmrAppButtonShape.Orb;
  FContent := TFmrAppMenuContent.CreateContent(Self, Ctx, ARibbon, AAnchor, OrbMode);
  FPopup := TFmrPopupForm.CreatePopup(Ctx, FContent);
  FPopup.ShadowSize := 0;
  FPopup.OnClosed :=
    procedure
    begin
      FPopup := nil;
      FContent := nil;
      if Assigned(FOnCloseUp) then
        FOnCloseUp(Self);
    end;
  // Orb: the content starts at the top of the orb (its upper half stays transparent); the menu body starts at the
  // middle of the orb. Without an orb the menu opens below the application button.
  if OrbMode then
    Anchor := RectF(AAnchor.Left - 5, AAnchor.Top - 1, AAnchor.Left - 5, AAnchor.Top - 1)
  else
    Anchor := RectF(AAnchor.Left - 1, AAnchor.Bottom - 1, AAnchor.Left - 1, AAnchor.Bottom - 1);
  FmrPopups.Show(FPopup, Anchor, TFmrPopupPlacement.Below, nil, AByKeyboard);
end;

function TFmrRibbonApplicationMenu.IsApplicationMenuOpen: Boolean;
begin
  Result := FPopup <> nil;
end;

procedure TFmrRibbonApplicationMenu.CloseApplicationMenu;
var
  P: TFmrPopupForm;
begin
  P := FPopup;
  FPopup := nil;
  FContent := nil;
  if (P <> nil) and FmrPopupsAssigned then
  begin
    P.OnClosed := nil;
    FmrPopups.Close(P);
  end;
end;

initialization
  RegisterFmxClasses([TFmrRibbonApplicationMenu]);
  RegisterClasses([TFmrRecentDocuments, TFmrRecentDocument]);

end.
