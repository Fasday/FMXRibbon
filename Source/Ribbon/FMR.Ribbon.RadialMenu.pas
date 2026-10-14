{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Radial menu                                          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.RadialMenu;

/// TFmrRibbonRadialMenu: a radial (pie) menu for touch. ItemLinks fill up to 8 sectors clockwise from the top;
/// links whose items have sub items (TFmrSubItem.ItemLinks, TFmrButtonItem.DropDownLinks) show an arrow in the outer
/// ring and open a nested ring; the center button closes the menu (top level) or goes back one ring. The popup is a
/// round transparent window painted with the Radial* tokens (RadialFill, RadialBorder, RadialSectorHotFill,
/// RadialText): hover highlights the sector, glyphs with captions around, checked items are marked. Keyboard:
/// arrows rotate the focus, Enter runs/opens, Backspace goes back, Esc closes. Opening and ring changes are animated
/// (Animation, default True).

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup;

const
  /// <summary>Sectors of a ring.</summary>
  FmrRadialSectors = 8;

type
  TFmrRibbonRadialMenu = class;

  /// <summary>Part of the radial menu under a point.</summary>
  TFmrRadialPart = (None, Center, Sector, Arrow);

  /// <summary>Content of the radial menu window.</summary>
  TFmrRadialMenuContent = class(TControl, IFmrPopupContent)
  private
    [Weak] FMenu: TFmrRibbonRadialMenu;
    FContext: IFmrPopupContext;
    FLevels: TList<TFmrItemLinks>;
    FLevelItems: TList<TFmrBarItem>;
    FHotPart: TFmrRadialPart;
    FHotIndex: Integer;
    FFocus: Integer;
    FPressedPart: TFmrRadialPart;
    FPressedIndex: Integer;
    FAnim: Single;
    FAnimStart: TDateTime;
    FTimer: TTimer;
    FDiameter: Single;
    function Painter: TFmrRibbonPainter; inline;
    function Images: TCustomImageList; inline;
    function Links: TFmrItemLinks;
    function SlotItem(const ASlot: Integer): TFmrBarItem;
    function SlotLink(const ASlot: Integer): TFmrItemLink;
    function SubLinksOf(const AItem: TFmrBarItem): TFmrItemLinks;
    function Center: TPointF;
    function OuterR: Single;
    function RingR: Single;
    function InnerR: Single;
    function SlotAngle(const ASlot: Integer): Single;
    function PartAt(const P: TPointF; out ASlot: Integer): TFmrRadialPart;
    procedure SetHot(const APart: TFmrRadialPart; const ASlot: Integer);
    procedure StartAnimation;
    procedure TimerProc(Sender: TObject);
    procedure Activate(const APart: TFmrRadialPart; const ASlot: Integer);
    procedure OpenLevel(const AItem: TFmrBarItem);
    procedure Back;
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
    constructor CreateContent(const AMenu: TFmrRibbonRadialMenu; const AContext: IFmrPopupContext);
    destructor Destroy; override;
    /// <summary>Depth of the shown ring (0 = ItemLinks).</summary>
    function Level: Integer;
    property HotPart: TFmrRadialPart read FHotPart;
    property HotIndex: Integer read FHotIndex;
    property FocusIndex: Integer read FFocus;
  end;

  /// <summary>Radial menu: Popup(ScreenPoint) shows a round menu centered at the point.</summary>
  TFmrRibbonRadialMenu = class(TFmxObject, IFmrItemLinksOwner)
  private
    FItemLinks: TFmrItemLinks;
    FBarManager: TFmrBarManager;
    FThemeSource: TFmxObject;
    FThemeName: string;
    FTheme: TFmrTheme;
    FPainter: TFmrRibbonPainter;
    FGlyph: TFmrImageSource;
    FDiameter: Single;
    FAnimation: Boolean;
    FPopup: TFmrPopupForm;
    FContent: TFmrRadialMenuContent;
    FOnPopup: TNotifyEvent;
    FOnCloseUp: TNotifyEvent;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetThemeSource(const Value: TFmxObject);
    procedure SetThemeName(const Value: string);
    procedure SetGlyph(const Value: TFmrImageSource);
    function IsThemeNameStored: Boolean;
    function IsDiameterStored: Boolean;
    function ResolvePainter: TFmrRibbonPainter;
    function ResolveImages: TCustomImageList;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Shows the menu centered at AScreenPoint (dp).</summary>
    procedure Popup(const AScreenPoint: TPointF; const AByKeyboard: Boolean = False);
    procedure ClosePopup;
    function IsOpen: Boolean;
    property Content: TFmrRadialMenuContent read FContent;
  published
    property Animation: Boolean read FAnimation write FAnimation default True;
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    /// <summary>Diameter of the menu in dp.</summary>
    property Diameter: Single read FDiameter write FDiameter stored IsDiameterStored;
    /// <summary>Glyph of the center button at the top level (empty: a close mark).</summary>
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    property Theme: string read FThemeName write SetThemeName stored IsThemeNameStored;
    property ThemeSource: TFmxObject read FThemeSource write SetThemeSource;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
  end;

implementation

uses
  System.Math.Vectors;

const
  RadialShadow = 8;
  AnimationMs = 170;

{ TFmrRadialMenuContent }

constructor TFmrRadialMenuContent.CreateContent(const AMenu: TFmrRibbonRadialMenu; const AContext: IFmrPopupContext);
begin
  inherited Create(nil);
  FMenu := AMenu;
  FContext := AContext;
  FDiameter := Max(160, AMenu.FDiameter);
  FLevels := TList<TFmrItemLinks>.Create;
  FLevelItems := TList<TFmrBarItem>.Create;
  FLevels.Add(AMenu.FItemLinks);
  FLevelItems.Add(nil);
  FHotIndex := -1;
  FFocus := -1;
  FPressedIndex := -1;
  FAnim := 1;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 15;
  FTimer.OnTimer := TimerProc;
  HitTest := True;
  AutoCapture := True;
  CanFocus := False;
end;

destructor TFmrRadialMenuContent.Destroy;
begin
  FreeAndNil(FLevels);
  FreeAndNil(FLevelItems);
  FContext := nil;
  inherited;
end;

function TFmrRadialMenuContent.Painter: TFmrRibbonPainter;
begin
  Result := FContext.Painter;
end;

function TFmrRadialMenuContent.Images: TCustomImageList;
begin
  Result := FContext.Images;
end;

function TFmrRadialMenuContent.Level: Integer;
begin
  Result := FLevels.Count - 1;
end;

function TFmrRadialMenuContent.Links: TFmrItemLinks;
begin
  Result := FLevels.Last;
end;

function TFmrRadialMenuContent.SlotLink(const ASlot: Integer): TFmrItemLink;
var
  I, N: Integer;
begin
  // Visible links that are not separators fill the slots in order.
  N := 0;
  for I := 0 to Links.Count - 1 do
    if Links[I].IsVisible and (Links[I].Item <> nil) and not (Links[I].Item is TFmrSeparatorItem) then
    begin
      if N = ASlot then
        Exit(Links[I]);
      Inc(N);
      if N >= FmrRadialSectors then
        Break;
    end;
  Result := nil;
end;

function TFmrRadialMenuContent.SlotItem(const ASlot: Integer): TFmrBarItem;
var
  L: TFmrItemLink;
begin
  L := SlotLink(ASlot);
  if L <> nil then
    Result := L.Item
  else
    Result := nil;
end;

function TFmrRadialMenuContent.SubLinksOf(const AItem: TFmrBarItem): TFmrItemLinks;
begin
  Result := nil;
  if AItem is TFmrSubItem then
    Result := TFmrSubItem(AItem).ItemLinks
  else if (AItem is TFmrButtonItem) and TFmrButtonItem(AItem).HasDropDown then
    Result := TFmrButtonItem(AItem).DropDownLinks;
  if (Result <> nil) and (Result.VisibleCount = 0) then
    Result := nil;
end;

function TFmrRadialMenuContent.Center: TPointF;
begin
  Result := PointF(Width / 2, Height / 2 - 2);
end;

function TFmrRadialMenuContent.OuterR: Single;
begin
  Result := FDiameter / 2;
end;

function TFmrRadialMenuContent.RingR: Single;
begin
  Result := FDiameter / 2 - 22;
end;

function TFmrRadialMenuContent.InnerR: Single;
begin
  Result := Max(24, FDiameter * 0.12);
end;

function TFmrRadialMenuContent.SlotAngle(const ASlot: Integer): Single;
begin
  // Slot 0 is at the top; clockwise (screen y grows downwards, so angles grow clockwise).
  Result := -90 + ASlot * (360 / FmrRadialSectors);
end;

function TFmrRadialMenuContent.PartAt(const P: TPointF; out ASlot: Integer): TFmrRadialPart;
var
  C: TPointF;
  D, A: Single;
begin
  ASlot := -1;
  C := Center;
  D := P.Distance(C);
  if D <= InnerR then
    Exit(TFmrRadialPart.Center);
  if D > OuterR then
    Exit(TFmrRadialPart.None);
  A := RadToDeg(ArcTan2(P.Y - C.Y, P.X - C.X)) + 90 + 180 / FmrRadialSectors;
  while A < 0 do
    A := A + 360;
  while A >= 360 do
    A := A - 360;
  ASlot := Trunc(A / (360 / FmrRadialSectors)) mod FmrRadialSectors;
  if SlotItem(ASlot) = nil then
  begin
    ASlot := -1;
    Exit(TFmrRadialPart.None);
  end;
  if (D > RingR) and (SubLinksOf(SlotItem(ASlot)) <> nil) then
    Result := TFmrRadialPart.Arrow
  else
    Result := TFmrRadialPart.Sector;
end;

function TFmrRadialMenuContent.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FDiameter + 2 * RadialShadow + 2, FDiameter + 2 * RadialShadow + 2);
end;

function TFmrRadialMenuContent.PaintsOwnBackground: Boolean;
begin
  Result := True;
end;

procedure TFmrRadialMenuContent.PopupShown(const AByKeyboard: Boolean);
begin
  if AByKeyboard then
    FFocus := 0;
  StartAnimation;
end;

procedure TFmrRadialMenuContent.PopupClosed;
begin
  FTimer.Enabled := False;
end;

procedure TFmrRadialMenuContent.StartAnimation;
begin
  if not FMenu.FAnimation then
  begin
    FAnim := 1;
    Repaint;
    Exit;
  end;
  FAnim := 0;
  FAnimStart := Now;
  FTimer.Enabled := True;
  Repaint;
end;

procedure TFmrRadialMenuContent.TimerProc(Sender: TObject);
var
  T: Single;
begin
  T := (Now - FAnimStart) * MSecsPerDay / AnimationMs;
  if T >= 1 then
  begin
    T := 1;
    FTimer.Enabled := False;
  end;
  // ease-out
  FAnim := 1 - Sqr(1 - T);
  Repaint;
end;

procedure TFmrRadialMenuContent.SetHot(const APart: TFmrRadialPart; const ASlot: Integer);
begin
  if (APart = FHotPart) and (ASlot = FHotIndex) then
    Exit;
  FHotPart := APart;
  FHotIndex := ASlot;
  if APart in [TFmrRadialPart.Sector, TFmrRadialPart.Arrow] then
    FFocus := ASlot;
  Repaint;
end;

procedure TFmrRadialMenuContent.OpenLevel(const AItem: TFmrBarItem);
var
  Sub: TFmrItemLinks;
begin
  if AItem is TFmrSubItem then
    TFmrSubItem(AItem).Popup
  else if AItem is TFmrButtonItem then
    TFmrButtonItem(AItem).DropDown;
  Sub := SubLinksOf(AItem);
  if Sub = nil then
    Exit;
  FLevels.Add(Sub);
  FLevelItems.Add(AItem);
  FHotPart := TFmrRadialPart.None;
  FHotIndex := -1;
  FFocus := -1;
  StartAnimation;
end;

procedure TFmrRadialMenuContent.Back;
begin
  if FLevels.Count <= 1 then
  begin
    FmrPopups.Close(FmrPopups.PopupOf(Self));
    Exit;
  end;
  FLevels.Delete(FLevels.Count - 1);
  FLevelItems.Delete(FLevelItems.Count - 1);
  FHotPart := TFmrRadialPart.None;
  FHotIndex := -1;
  FFocus := -1;
  StartAnimation;
end;

procedure TFmrRadialMenuContent.Activate(const APart: TFmrRadialPart; const ASlot: Integer);
var
  Item: TFmrBarItem;
  Ctx: IFmrPopupContext;
  Sub: TFmrItemLinks;
  OpensSub: Boolean;
begin
  case APart of
    TFmrRadialPart.Center:
      Back;
    TFmrRadialPart.Sector, TFmrRadialPart.Arrow:
      begin
        Item := SlotItem(ASlot);
        if (Item = nil) or not Item.Enabled then
          Exit;
        Sub := SubLinksOf(Item);
        // The arrow, sub items and whole drop-down buttons open the nested ring; split buttons run their command.
        OpensSub := (Sub <> nil) and ((APart = TFmrRadialPart.Arrow) or (Item is TFmrSubItem) or
          ((Item is TFmrButtonItem) and (TFmrButtonItem(Item).ButtonStyle = TFmrButtonStyle.DropDown)));
        if OpensSub then
        begin
          OpenLevel(Item);
          Exit;
        end;
        Ctx := FContext;
        FmrPopups.CloseAll;
        // From the message loop: the menu is freed soon and a command may show a modal dialog.
        TThread.ForceQueue(nil,
          procedure
          begin
            Ctx.ItemExecuting(Item);
            Item.Click;
          end);
      end;
  end;
end;

procedure TFmrRadialMenuContent.Paint;
var
  P: TFmrRibbonPainter;
  C, GP, AP: TPointF;
  I: Integer;
  Item: TFmrBarItem;
  A, Sweep, Mid, R, Scale, Op, GS, TextR: Single;
  Hot: Boolean;
  G: TFmrImageSource;
  TextColor, Accent, HotColor: TAlphaColor;
  M: TMatrix;
  State, ArrowState: TCanvasSaveState;
  Caption: string;
begin
  P := Painter;
  C := Center;
  Scale := 0.7 + 0.3 * FAnim;
  Op := FAnim;
  State := Canvas.SaveState;
  try
    if Scale < 0.999 then
    begin
      M := TMatrix.CreateTranslation(-C.X, -C.Y) * TMatrix.CreateScaling(Scale, Scale) *
        TMatrix.CreateTranslation(C.X, C.Y);
      Canvas.MultiplyMatrix(M);
    end;
    // soft round shadow
    for I := RadialShadow downto 1 do
    begin
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := P.Theme.Colors[TFmrToken.PopupShadow];
      Canvas.FillEllipse(RectF(C.X - OuterR - I, C.Y - OuterR - I + I * 0.4, C.X + OuterR + I, C.Y + OuterR + I +
        I * 0.4), Op * 0.5 * Sqr(1 - (I - 1) / RadialShadow) / RadialShadow * 2);
    end;
    P.DrawRadialBackground(Canvas, C, OuterR, RingR, InnerR);
    Accent := P.Theme.Colors[TFmrToken.RadialBorder];
    HotColor := P.Theme.Fills[TFmrToken.RadialSectorHotFill].MainColor;
    TextColor := P.Theme.Colors[TFmrToken.RadialText];
    Sweep := 360 / FmrRadialSectors;
    // sector dividers
    for I := 0 to FmrRadialSectors - 1 do
    begin
      A := DegToRad(SlotAngle(I) - Sweep / 2);
      P.Line(Canvas, PointF(C.X + (InnerR + 3) * Cos(A), C.Y + (InnerR + 3) * Sin(A)),
        PointF(C.X + (RingR - 3) * Cos(A), C.Y + (RingR - 3) * Sin(A)), FmrWithAlpha(Accent, 0.18), 1, Op);
    end;
    GS := P.Metrics.LargeGlyphSize * 0.75;
    for I := 0 to FmrRadialSectors - 1 do
    begin
      Item := SlotItem(I);
      if Item = nil then
        Continue;
      Mid := SlotAngle(I);
      Hot := ((FHotPart = TFmrRadialPart.Sector) and (FHotIndex = I)) or ((FHotPart = TFmrRadialPart.None) and
        (FFocus = I));
      if Item.IsChecked then
        P.DrawRadialSector(Canvas, C, InnerR + 2, RingR - 2, Mid - Sweep / 2 + 1, Sweep - 2, Accent, 0.22 * Op);
      if Hot and Item.Enabled then
        P.DrawRadialSector(Canvas, C, InnerR + 2, RingR - 2, Mid - Sweep / 2 + 1, Sweep - 2, HotColor, Op);
      // submenu arrow in the outer ring
      if SubLinksOf(Item) <> nil then
      begin
        if (FHotPart = TFmrRadialPart.Arrow) and (FHotIndex = I) then
          P.DrawRadialSector(Canvas, C, RingR + 1, OuterR - 2, Mid - Sweep / 2 + 1, Sweep - 2, Accent, 0.45 * Op);
        R := (RingR + OuterR) / 2;
        AP := PointF(C.X + R * Cos(DegToRad(Mid)), C.Y + R * Sin(DegToRad(Mid)));
        ArrowState := Canvas.SaveState;
        try
          M := TMatrix.CreateTranslation(-AP.X, -AP.Y) * TMatrix.CreateRotation(DegToRad(Mid)) *
            TMatrix.CreateTranslation(AP.X, AP.Y);
          Canvas.MultiplyMatrix(M);
          P.Arrow(Canvas, AP, TFmrArrowDirection.Right, Accent, 7, Op);
        finally
          Canvas.RestoreState(ArrowState);
        end;
      end;
      // glyph and caption
      R := (InnerR + RingR) / 2;
      GP := PointF(C.X + R * Cos(DegToRad(Mid)), C.Y + R * Sin(DegToRad(Mid)) - 7);
      G := nil;
      if not Item.LargeGlyph.IsEmpty(Images) then
        G := Item.LargeGlyph
      else if not Item.Glyph.IsEmpty(Images) then
        G := Item.Glyph;
      if G <> nil then
      begin
        if Item.Enabled then
          G.Draw(Canvas, RectF(GP.X - GS / 2, GP.Y - GS / 2, GP.X + GS / 2, GP.Y + GS / 2), Op,
            P.GlyphTint(TFmrPartState.Normal), Images)
        else
          G.Draw(Canvas, RectF(GP.X - GS / 2, GP.Y - GS / 2, GP.X + GS / 2, GP.Y + GS / 2), 0.45 * Op,
            P.GlyphTint(TFmrPartState.Disabled), Images);
      end;
      Caption := FmrStripAccel(SlotLink(I).Caption);
      TextR := (RingR - InnerR) * 0.95;
      P.TextEx(Canvas, RectF(GP.X - TextR / 2, GP.Y + GS / 2, GP.X + TextR / 2, GP.Y + GS / 2 + 16), Caption,
        TextColor, TTextAlign.Center, TTextAlign.Leading, P.Metrics.FontSize - 1, False, False,
        TTextTrimming.Character, IfThen(Item.Enabled, Op, 0.45 * Op));
    end;
    // center button: close at the top level, back in nested rings
    if FHotPart = TFmrRadialPart.Center then
    begin
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := HotColor;
      Canvas.FillEllipse(RectF(C.X - InnerR + 2, C.Y - InnerR + 2, C.X + InnerR - 2, C.Y + InnerR - 2), Op);
    end;
    if Level > 0 then
    begin
      // back arrow
      P.Line(Canvas, PointF(C.X - 8, C.Y), PointF(C.X + 9, C.Y), Accent, 2, Op);
      P.Line(Canvas, PointF(C.X - 8, C.Y), PointF(C.X - 2, C.Y - 6), Accent, 2, Op);
      P.Line(Canvas, PointF(C.X - 8, C.Y), PointF(C.X - 2, C.Y + 6), Accent, 2, Op);
    end
    else if not FMenu.FGlyph.IsEmpty(Images) then
      FMenu.FGlyph.Draw(Canvas, RectF(C.X - GS / 2, C.Y - GS / 2, C.X + GS / 2, C.Y + GS / 2), Op, Accent, Images)
    else
    begin
      P.Line(Canvas, PointF(C.X - 6, C.Y - 6), PointF(C.X + 6, C.Y + 6), Accent, 2, Op);
      P.Line(Canvas, PointF(C.X + 6, C.Y - 6), PointF(C.X - 6, C.Y + 6), Accent, 2, Op);
    end;
  finally
    Canvas.RestoreState(State);
  end;
end;

procedure TFmrRadialMenuContent.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Slot: Integer;
  Part: TFmrRadialPart;
begin
  inherited;
  Part := PartAt(PointF(X, Y), Slot);
  SetHot(Part, Slot);
end;

procedure TFmrRadialMenuContent.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if Button = TMouseButton.mbLeft then
    FPressedPart := PartAt(PointF(X, Y), FPressedIndex);
end;

procedure TFmrRadialMenuContent.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Slot: Integer;
  Part: TFmrRadialPart;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  Part := PartAt(PointF(X, Y), Slot);
  if (Part = FPressedPart) and (Slot = FPressedIndex) and (Part <> TFmrRadialPart.None) then
    Activate(Part, Slot);
  FPressedPart := TFmrRadialPart.None;
  FPressedIndex := -1;
end;

procedure TFmrRadialMenuContent.DoMouseLeave;
begin
  inherited;
  SetHot(TFmrRadialPart.None, -1);
end;

function TFmrRadialMenuContent.PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;

  procedure MoveFocus(const ADelta: Integer);
  var
    I, S: Integer;
  begin
    S := FFocus;
    if S < 0 then
      if ADelta > 0 then
        S := -1
      else
        S := 0;
    for I := 1 to FmrRadialSectors do
    begin
      S := (S + ADelta + FmrRadialSectors) mod FmrRadialSectors;
      if SlotItem(S) <> nil then
      begin
        FFocus := S;
        FHotPart := TFmrRadialPart.None;
        FHotIndex := -1;
        Repaint;
        Exit;
      end;
    end;
  end;

begin
  Result := True;
  case Key of
    vkRight, vkDown:
      MoveFocus(1);
    vkLeft, vkUp:
      MoveFocus(-1);
    vkReturn, vkSpace:
      if FFocus >= 0 then
        Activate(TFmrRadialPart.Sector, FFocus);
    vkBack:
      Back;
    vkEscape:
      if Level > 0 then
        Back
      else
        Result := False;
  end;
end;

{ TFmrRibbonRadialMenu }

constructor TFmrRibbonRadialMenu.Create(AOwner: TComponent);
begin
  inherited;
  FItemLinks := TFmrItemLinks.Create(Self);
  FGlyph := TFmrImageSource.Create(Self);
  FThemeName := FmrDefaultThemeName;
  FDiameter := 260;
  FAnimation := True;
end;

destructor TFmrRibbonRadialMenu.Destroy;
begin
  ClosePopup;
  FreeAndNil(FItemLinks);
  FreeAndNil(FGlyph);
  FreeAndNil(FPainter);
  FreeAndNil(FTheme);
  inherited;
end;

procedure TFmrRibbonRadialMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FBarManager then
      FBarManager := nil;
    if AComponent = FThemeSource then
    begin
      ClosePopup;
      FThemeSource := nil;
    end;
  end;
end;

procedure TFmrRibbonRadialMenu.SetBarManager(const Value: TFmrBarManager);
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

procedure TFmrRibbonRadialMenu.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrRibbonRadialMenu.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrRibbonRadialMenu.SetThemeName(const Value: string);
begin
  if FThemeName <> TFmrTheme.ResolveThemeName(Value) then
  begin
    ClosePopup;
    FThemeName := TFmrTheme.ResolveThemeName(Value);
    FreeAndNil(FPainter);
    FreeAndNil(FTheme);
  end;
end;

procedure TFmrRibbonRadialMenu.SetThemeSource(const Value: TFmxObject);
begin
  if FThemeSource <> Value then
  begin
    if FThemeSource <> nil then
      FThemeSource.RemoveFreeNotification(Self);
    FThemeSource := Value;
    if FThemeSource <> nil then
      FThemeSource.FreeNotification(Self);
  end;
end;

function TFmrRibbonRadialMenu.IsThemeNameStored: Boolean;
begin
  Result := not SameText(FThemeName, FmrDefaultThemeName);
end;

function TFmrRibbonRadialMenu.IsDiameterStored: Boolean;
begin
  Result := FDiameter <> 260;
end;

function TFmrRibbonRadialMenu.ResolvePainter: TFmrRibbonPainter;
var
  Src: IFmrThemeSource;
begin
  if (FThemeSource <> nil) and Supports(FThemeSource, IFmrThemeSource, Src) and (Src.GetThemePainter <> nil) then
    Exit(Src.GetThemePainter);
  if FPainter = nil then
  begin
    FTheme := TFmrTheme.CreateTheme(FThemeName);
    FPainter := TFmrRibbonPainter.Create(FTheme);
  end;
  Result := FPainter;
end;

function TFmrRibbonRadialMenu.ResolveImages: TCustomImageList;
var
  Src: IFmrThemeSource;
begin
  Result := nil;
  if FBarManager <> nil then
    Result := FBarManager.Images;
  if (Result = nil) and (FThemeSource <> nil) and Supports(FThemeSource, IFmrThemeSource, Src) then
    Result := Src.GetThemeImages;
end;

procedure TFmrRibbonRadialMenu.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  if FContent <> nil then
    FContent.Repaint;
end;

procedure TFmrRibbonRadialMenu.LinkRemoving(const ALink: TFmrItemLink);
begin
  ClosePopup;
end;

procedure TFmrRibbonRadialMenu.LinksChanged(const ALinks: TFmrItemLinks);
begin
  if FContent <> nil then
    FContent.Repaint;
end;

procedure TFmrRibbonRadialMenu.Popup(const AScreenPoint: TPointF; const AByKeyboard: Boolean);
var
  Ctx: IFmrPopupContext;
  Form: TCommonCustomForm;
  Size: TSizeF;
begin
  ClosePopup;
  if (csDesigning in ComponentState) or (FItemLinks.VisibleCount = 0) then
    Exit;
  if Assigned(FOnPopup) then
    FOnPopup(Self);
  Form := FmrFormOf(Self);
  if Form = nil then
    Form := Screen.ActiveForm;
  Ctx := TFmrPopupContext.Create(ResolvePainter, ResolveImages, Form);
  FContent := TFmrRadialMenuContent.CreateContent(Self, Ctx);
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
  Size := FContent.GetPopupSize;
  FmrPopups.Show(FPopup, RectF(AScreenPoint.X - Size.Width / 2, AScreenPoint.Y - Size.Height / 2,
    AScreenPoint.X - Size.Width / 2, AScreenPoint.Y - Size.Height / 2), TFmrPopupPlacement.AtPoint, nil, AByKeyboard);
end;

procedure TFmrRibbonRadialMenu.ClosePopup;
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

function TFmrRibbonRadialMenu.IsOpen: Boolean;
begin
  Result := FPopup <> nil;
end;

initialization
  RegisterFmxClasses([TFmrRibbonRadialMenu]);

end.
