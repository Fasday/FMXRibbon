{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Color gallery and the "More Colors" dialog           }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.ColorGallery;

/// The drop-down of color items (FmrRegisterDropDown for TFmrColorItem, so plain color items use it too):
///   - "Automatic" row, Office theme colors (10 columns: the base colors and 5 rows of tints and shades), standard
///     colors, recent colors (colors picked with "More Colors..."), "No Color" and "More Colors..." rows;
///   - the highlight palette of Word (15 colors in 5 columns) for TFmrColorGalleryItem.Palette = Highlight;
///   - hot tracking with a screen tip naming the color ("Blue, Accent 1, Lighter 40%"), live preview
///     (TFmrColorGalleryItem.OnPreview), the current color selected, keyboard (arrows, Home/End, Enter, Esc).
/// Picking a color sets TFmrColorItem.Color and clicks the item, so the main part of the split button applies the
/// last color afterwards; the glyph of the button shows the color bar (TFmrButtonView). Automatic is
/// TAlphaColors.Null, No Color is FmrNoColor (alpha 0, not Null).
/// FmrShowColorDialog is a small FMX dialog (TColorPanel with a hue/saturation square, hex edit, new/current
/// preview) used by "More Colors...".

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Generics.Collections,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Theme,
  FMR.Ribbon.Painter, FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon.ScreenTips, FMR.Ribbon.Strings;

const
  /// <summary>Color of the "No Color" choice (transparent, but not TAlphaColors.Null = Automatic).</summary>
  FmrNoColor = TAlphaColor($00FFFFFF);

type
  /// <summary>Colors offered by a color gallery.</summary>
  TFmrColorPalette = (
    /// <summary>Office theme colors with tints/shades and the standard colors.</summary>
    Office,
    /// <summary>The 15 text highlight colors of Word.</summary>
    Highlight);

  TFmrColorPreviewEvent = procedure(Sender: TObject; const AColor: TAlphaColor; const AActive: Boolean) of object;
  TFmrMoreColorsEvent = procedure(Sender: TObject; var AColor: TAlphaColor; var AHandled: Boolean) of object;

  /// <summary>Color item with gallery options: palette, recent colors, live preview, custom "More Colors".</summary>
  TFmrColorGalleryItem = class(TFmrColorItem)
  private
    FPalette: TFmrColorPalette;
    FShowRecentColors: Boolean;
    FOnPreview: TFmrColorPreviewEvent;
    FOnMoreColors: TFmrMoreColorsEvent;
  public
    constructor Create(AOwner: TComponent); override;
    /// <summary>Live preview: AActive = True while the mouse (or the keyboard focus) is on a color, False when the
    /// preview ends (restore the original look).</summary>
    procedure Preview(const AColor: TAlphaColor; const AActive: Boolean);
  published
    property Palette: TFmrColorPalette read FPalette write FPalette default TFmrColorPalette.Office;
    property ShowRecentColors: Boolean read FShowRecentColors write FShowRecentColors default True;
    property OnPreview: TFmrColorPreviewEvent read FOnPreview write FOnPreview;
    /// <summary>Replaces the built-in "More Colors" dialog (set AHandled; AColor in/out).</summary>
    property OnMoreColors: TFmrMoreColorsEvent read FOnMoreColors write FOnMoreColors;
  end;

  TFmrColorCellKind = (Color, Automatic, NoColor, MoreColors);

  /// <summary>Content of the drop-down of a color item.</summary>
  TFmrColorGalleryControl = class(TControl, IFmrPopupContent)
  private type
    TCell = record
      Kind: TFmrColorCellKind;
      Color: TAlphaColor;
      Rect: TRectF;
      Name: string;
    end;
    THeader = record
      Caption: string;
      Rect: TRectF;
    end;
  private
    FContext: IFmrPopupContext;
    FItem: TFmrColorItem;
    FCells: TList<TCell>;
    FHeaders: TList<THeader>;
    FSeparators: TList<Single>;
    FHot: Integer;
    FWidth: Single;
    FHeight: Single;
    FPreviewing: Boolean;
    FByKeyboard: Boolean;
    procedure Build;
    procedure AddRow(const AKind: TFmrColorCellKind; const ACaption: string; var Y: Single);
    function CellAt(const P: TPointF): Integer;
    procedure SetHot(const AIndex: Integer);
    procedure Pick(const AIndex: Integer);
    procedure EndPreview;
    procedure UpdateTip;
    function IsSelected(const ACell: TCell): Boolean;
  protected
    function GetPopupSize: TSizeF;
    function PopupKeyDown(var Key: Word; var KeyChar: WideChar; const Shift: TShiftState): Boolean;
    procedure PopupShown(const AByKeyboard: Boolean);
    procedure PopupClosed;
    function PaintsOwnBackground: Boolean;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor CreateGallery(const AContext: IFmrPopupContext; const AItem: TFmrColorItem);
    destructor Destroy; override;
    /// <summary>Number of cells (colors and rows) and their colors (tests, automation).</summary>
    function CellCount: Integer;
    function CellColor(const AIndex: Integer): TAlphaColor;
    function CellKind(const AIndex: Integer): TFmrColorCellKind;
    property HotIndex: Integer read FHot;
  end;

/// <summary>Shows a modal color dialog (hue/saturation square, hex edit, new/current preview); AOnDone gets True
/// and the color when the user pressed OK.</summary>
procedure FmrShowColorDialog(const AInitial: TAlphaColor; const ATitle: string;
  const AOnDone: TProc<Boolean, TAlphaColor>);
/// <summary>The recently picked custom colors (newest first, at most 10).</summary>
function FmrRecentColors: TArray<TAlphaColor>;
procedure FmrAddRecentColor(const AColor: TAlphaColor);
/// <summary>Office theme color of column ACol (0..9) and tint/shade row ARow (0 = base color, 1..5).</summary>
function FmrThemeColor(const ACol, ARow: Integer): TAlphaColor;

implementation

uses
  System.UIConsts, FMX.Colors, FMX.StdCtrls, FMX.Edit, FMX.Objects;

resourcestring
  SColorNew = 'New';
  SColorCurrent = 'Current';
  SColorHex = 'Hex:';
  SColorStopHighlighting = 'Stop Highlighting';
  SColorLighter = 'Lighter %d%%';
  SColorDarker = 'Darker %d%%';

const
  ThemeBase: array[0..9] of TAlphaColor = ($FFFFFFFF, $FF000000, $FFE7E6E6, $FF44546A, $FF4472C4, $FFED7D31,
    $FFA5A5A5, $FFFFC000, $FF5B9BD5, $FF70AD47);
  ThemeNames: array[0..9] of string = ('White, Background 1', 'Black, Text 1', 'Light Gray, Background 2',
    'Blue-Gray, Text 2', 'Blue, Accent 1', 'Orange, Accent 2', 'Gray, Accent 3', 'Gold, Accent 4',
    'Light Blue, Accent 5', 'Green, Accent 6');
  StandardColors: array[0..9] of TAlphaColor = ($FFC00000, $FFFF0000, $FFFFC000, $FFFFFF00, $FF92D050, $FF00B050,
    $FF00B0F0, $FF0070C0, $FF002060, $FF7030A0);
  StandardNames: array[0..9] of string = ('Dark Red', 'Red', 'Orange', 'Yellow', 'Light Green', 'Green',
    'Light Blue', 'Blue', 'Dark Blue', 'Purple');
  HighlightColors: array[0..14] of TAlphaColor = ($FFFFFF00, $FF00FF00, $FF00FFFF, $FFFF00FF, $FF0000FF, $FFFF0000,
    $FF000080, $FF008080, $FF008000, $FF800080, $FF800000, $FF808000, $FF808080, $FFC0C0C0, $FF000000);
  HighlightNames: array[0..14] of string = ('Yellow', 'Bright Green', 'Turquoise', 'Pink', 'Blue', 'Red',
    'Dark Blue', 'Teal', 'Green', 'Violet', 'Dark Red', 'Dark Yellow', 'Gray 50%', 'Gray 25%', 'Black');

var
  GRecent: TList<TAlphaColor>;
  GColorTips: TFmrScreenTipController;
  GColorTip: TFmrElement;

type
  /// Element handed to the screen tip controller for one color cell.
  TFmrColorTipElement = class(TFmrElement)
  private
    FName: string;
  public
    procedure Paint(const ACanvas: TCanvas); override;
    function GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean; override;
  end;

procedure TFmrColorTipElement.Paint(const ACanvas: TCanvas);
begin
end;

function TFmrColorTipElement.GetScreenTip(out AInfo: TFmrScreenTipInfo): Boolean;
begin
  AInfo := Default(TFmrScreenTipInfo);
  AInfo.Header := FName;
  Result := FName <> '';
end;

procedure ColorTipHover(const AName: string; const AScreenRect: TRectF; const APainter: TFmrRibbonPainter;
  const AForm: TCommonCustomForm);
var
  Old: TFmrElement;
begin
  if AName = '' then
  begin
    if GColorTips <> nil then
      GColorTips.Cancel;
    FreeAndNil(GColorTip);
    Exit;
  end;
  if (GColorTip <> nil) and (TFmrColorTipElement(GColorTip).FName = AName) then
    Exit;
  if GColorTips = nil then
    GColorTips := TFmrScreenTipController.Create;
  Old := GColorTip;
  GColorTip := TFmrColorTipElement.Create(nil);
  TFmrColorTipElement(GColorTip).FName := AName;
  GColorTips.Hover(GColorTip, AScreenRect, APainter, AForm);
  Old.Free;
end;

{ colors }

function FmrRecentColors: TArray<TAlphaColor>;
begin
  if GRecent = nil then
    Result := nil
  else
    Result := GRecent.ToArray;
end;

procedure FmrAddRecentColor(const AColor: TAlphaColor);
begin
  if TAlphaColorRec(AColor).A = 0 then
    Exit;
  if GRecent = nil then
    GRecent := TList<TAlphaColor>.Create;
  GRecent.Remove(AColor);
  GRecent.Insert(0, AColor);
  while GRecent.Count > 10 do
    GRecent.Delete(GRecent.Count - 1);
end;

/// Amount of the tint (> 0: lighter) or shade (< 0: darker) of row ARow (1..5) for a base color of luminance AL,
/// like the Office palette: light colors only get darker, very dark colors only lighter.
function TintOf(const AL: Single; const ARow: Integer): Single;
const
  Normal: array[1..5] of Single = (0.8, 0.6, 0.4, -0.25, -0.5);
  VeryLight: array[1..5] of Single = (-0.05, -0.15, -0.25, -0.35, -0.5);
  Light: array[1..5] of Single = (-0.1, -0.25, -0.5, -0.75, -0.9);
  Dark: array[1..5] of Single = (0.5, 0.35, 0.25, 0.15, 0.05);
begin
  if AL > 0.95 then
    Result := VeryLight[ARow]
  else if AL > 0.8 then
    Result := Light[ARow]
  else if AL < 0.15 then
    Result := Dark[ARow]
  else
    Result := Normal[ARow];
end;

function FmrThemeColor(const ACol, ARow: Integer): TAlphaColor;
var
  H, S, L, T: Single;
begin
  Result := ThemeBase[EnsureRange(ACol, 0, 9)];
  if ARow <= 0 then
    Exit;
  RGBtoHSL(Result, H, S, L);
  T := TintOf(L, EnsureRange(ARow, 1, 5));
  if T > 0 then
    L := L + (1 - L) * T
  else
    L := L * (1 + T);
  Result := HSLtoRGB(H, S, EnsureRange(L, 0, 1)) or $FF000000;
end;

function ThemeColorName(const ACol, ARow: Integer): string;
var
  H, S, L, T: Single;
begin
  Result := ThemeNames[ACol];
  if ARow <= 0 then
    Exit;
  RGBtoHSL(ThemeBase[ACol], H, S, L);
  T := TintOf(L, ARow);
  if T > 0 then
    Result := Result + ', ' + Format(SColorLighter, [Round(T * 100)])
  else
    Result := Result + ', ' + Format(SColorDarker, [Round(-T * 100)]);
end;

{ TFmrColorGalleryItem }

constructor TFmrColorGalleryItem.Create(AOwner: TComponent);
begin
  inherited;
  FShowRecentColors := True;
end;

procedure TFmrColorGalleryItem.Preview(const AColor: TAlphaColor; const AActive: Boolean);
begin
  if Assigned(FOnPreview) then
    FOnPreview(Self, AColor, AActive);
end;

{ TFmrColorGalleryControl }

constructor TFmrColorGalleryControl.CreateGallery(const AContext: IFmrPopupContext; const AItem: TFmrColorItem);
begin
  inherited Create(nil);
  FContext := AContext;
  FItem := AItem;
  FCells := TList<TCell>.Create;
  FHeaders := TList<THeader>.Create;
  FSeparators := TList<Single>.Create;
  FHot := -1;
  HitTest := True;
  Build;
end;

destructor TFmrColorGalleryControl.Destroy;
begin
  EndPreview;
  ColorTipHover('', TRectF.Empty, nil, nil);
  FreeAndNil(FCells);
  FreeAndNil(FHeaders);
  FreeAndNil(FSeparators);
  FContext := nil;
  inherited;
end;

function TFmrColorGalleryControl.CellCount: Integer;
begin
  Result := FCells.Count;
end;

function TFmrColorGalleryControl.CellColor(const AIndex: Integer): TAlphaColor;
begin
  Result := FCells[AIndex].Color;
end;

function TFmrColorGalleryControl.CellKind(const AIndex: Integer): TFmrColorCellKind;
begin
  Result := FCells[AIndex].Kind;
end;

procedure TFmrColorGalleryControl.AddRow(const AKind: TFmrColorCellKind; const ACaption: string; var Y: Single);
var
  Cell: TCell;
  RowH: Single;
begin
  RowH := FContext.Painter.Metrics.MenuItemHeight;
  Cell.Kind := AKind;
  case AKind of
    TFmrColorCellKind.Automatic: Cell.Color := TAlphaColors.Null;
    TFmrColorCellKind.NoColor: Cell.Color := FmrNoColor;
  else
    Cell.Color := TAlphaColors.Null;
  end;
  Cell.Name := ACaption;
  Cell.Rect := RectF(1, Y, FWidth - 1, Y + RowH);
  FCells.Add(Cell);
  Y := Y + RowH + 1;
end;

procedure TFmrColorGalleryControl.Build;
var
  Cell: TCell;
  H: THeader;
  X, Y, CellS, Gap, Pad, RowH: Single;
  I, J, Cols: Integer;
  Highlight: Boolean;
  Recent: TArray<TAlphaColor>;
begin
  RowH := FContext.Painter.Metrics.MenuItemHeight;
  FCells.Clear;
  FHeaders.Clear;
  FSeparators.Clear;
  Highlight := (FItem is TFmrColorGalleryItem) and (TFmrColorGalleryItem(FItem).Palette = TFmrColorPalette.Highlight);
  Pad := 7;
  if Highlight then
  begin
    CellS := 22;
    Gap := 6;
    Cols := 5;
  end
  else
  begin
    CellS := 16;
    Gap := 5;
    Cols := 10;
  end;
  FWidth := Max(Pad * 2 + Cols * CellS + (Cols - 1) * Gap, 150);
  Y := 4;
  if FItem.ShowAutomatic and not Highlight then
  begin
    AddRow(TFmrColorCellKind.Automatic, FmrStr(TFmrStringId.ColorAutomatic), Y);
    Y := Y + 2;
  end;
  if Highlight then
  begin
    for I := 0 to High(HighlightColors) do
    begin
      Cell.Kind := TFmrColorCellKind.Color;
      Cell.Color := HighlightColors[I];
      Cell.Name := HighlightNames[I];
      X := Pad + (I mod Cols) * (CellS + Gap);
      Cell.Rect := RectF(X, Y + (I div Cols) * (CellS + Gap), X + CellS, Y + (I div Cols) * (CellS + Gap) + CellS);
      FCells.Add(Cell);
    end;
    Y := Y + 3 * (CellS + Gap) + 2;
  end
  else
  begin
    H.Caption := FmrStr(TFmrStringId.ColorThemeColors);
    H.Rect := RectF(1, Y, FWidth - 1, Y + RowH);
    FHeaders.Add(H);
    Y := Y + RowH + 4;
    for I := 0 to 5 do
    begin
      X := Pad;
      for J := 0 to 9 do
      begin
        Cell.Kind := TFmrColorCellKind.Color;
        Cell.Color := FmrThemeColor(J, I);
        Cell.Name := ThemeColorName(J, I);
        Cell.Rect := RectF(X, Y, X + CellS, Y + CellS);
        FCells.Add(Cell);
        X := X + CellS + Gap;
      end;
      // The base row stands apart; the tints and shades form one block.
      if I = 0 then
        Y := Y + CellS + 5
      else
        Y := Y + CellS;
    end;
    Y := Y + 6;
    H.Caption := FmrStr(TFmrStringId.ColorStandardColors);
    H.Rect := RectF(1, Y, FWidth - 1, Y + RowH);
    FHeaders.Add(H);
    Y := Y + RowH + 4;
    X := Pad;
    for J := 0 to 9 do
    begin
      Cell.Kind := TFmrColorCellKind.Color;
      Cell.Color := StandardColors[J];
      Cell.Name := StandardNames[J];
      Cell.Rect := RectF(X, Y, X + CellS, Y + CellS);
      FCells.Add(Cell);
      X := X + CellS + Gap;
    end;
    Y := Y + CellS + 6;
    Recent := FmrRecentColors;
    if (Length(Recent) > 0) and (not (FItem is TFmrColorGalleryItem) or
      TFmrColorGalleryItem(FItem).ShowRecentColors) then
    begin
      H.Caption := FmrStr(TFmrStringId.ColorRecentColors);
      H.Rect := RectF(1, Y, FWidth - 1, Y + RowH);
      FHeaders.Add(H);
      Y := Y + RowH + 4;
      X := Pad;
      for J := 0 to Min(9, High(Recent)) do
      begin
        Cell.Kind := TFmrColorCellKind.Color;
        Cell.Color := Recent[J];
        Cell.Name := '#' + IntToHex(Recent[J] and $FFFFFF, 6);
        Cell.Rect := RectF(X, Y, X + CellS, Y + CellS);
        FCells.Add(Cell);
        X := X + CellS + Gap;
      end;
      Y := Y + CellS + 6;
    end;
  end;
  if FItem.ShowNoColor or (FItem.ShowMoreColors and not Highlight) or Highlight then
  begin
    FSeparators.Add(Y + 3);
    Y := Y + 7;
  end;
  if FItem.ShowNoColor or Highlight then
  begin
    if Highlight then
      AddRow(TFmrColorCellKind.NoColor, SColorStopHighlighting, Y)
    else
      AddRow(TFmrColorCellKind.NoColor, FmrStr(TFmrStringId.ColorNoColor), Y);
  end;
  if FItem.ShowMoreColors and not Highlight then
    AddRow(TFmrColorCellKind.MoreColors, FmrStr(TFmrStringId.ColorMoreColors), Y);
  FHeight := Y + 3;
end;

function TFmrColorGalleryControl.GetPopupSize: TSizeF;
begin
  Result := TSizeF.Create(FWidth + 2, FHeight + 2);
end;

function TFmrColorGalleryControl.PaintsOwnBackground: Boolean;
begin
  Result := False;
end;

procedure TFmrColorGalleryControl.PopupShown(const AByKeyboard: Boolean);
var
  I: Integer;
begin
  FByKeyboard := AByKeyboard;
  if not AByKeyboard then
    Exit;
  for I := 0 to FCells.Count - 1 do
    if IsSelected(FCells[I]) then
    begin
      SetHot(I);
      Exit;
    end;
  if FCells.Count > 0 then
    SetHot(0);
end;

procedure TFmrColorGalleryControl.PopupClosed;
begin
  EndPreview;
  ColorTipHover('', TRectF.Empty, nil, nil);
end;

function TFmrColorGalleryControl.IsSelected(const ACell: TCell): Boolean;
begin
  case ACell.Kind of
    TFmrColorCellKind.Color: Result := (TAlphaColorRec(FItem.Color).A > 0) and (ACell.Color = FItem.Color);
    TFmrColorCellKind.Automatic: Result := FItem.Color = TAlphaColors.Null;
  else
    Result := False;
  end;
end;

function TFmrColorGalleryControl.CellAt(const P: TPointF): Integer;
var
  I: Integer;
  R: TRectF;
begin
  for I := 0 to FCells.Count - 1 do
  begin
    R := FCells[I].Rect;
    if FCells[I].Kind = TFmrColorCellKind.Color then
      R.Inflate(2, 2);
    if R.Contains(P) then
      Exit(I);
  end;
  Result := -1;
end;

procedure TFmrColorGalleryControl.EndPreview;
begin
  if FPreviewing then
  begin
    FPreviewing := False;
    if (FItem is TFmrColorGalleryItem) and not (csDestroying in FItem.ComponentState) then
      TFmrColorGalleryItem(FItem).Preview(FItem.Color, False);
  end;
end;

procedure TFmrColorGalleryControl.UpdateTip;
var
  R: TRectF;
  TL, BR: TPointF;
begin
  if (FHot < 0) or (FCells[FHot].Kind <> TFmrColorCellKind.Color) then
  begin
    ColorTipHover('', TRectF.Empty, nil, nil);
    Exit;
  end;
  R := FCells[FHot].Rect;
  TL := LocalToScreen(R.TopLeft);
  BR := LocalToScreen(PointF(R.Right, R.Bottom + 4));
  ColorTipHover(FCells[FHot].Name, RectF(TL.X, TL.Y, BR.X, BR.Y), FContext.Painter, FContext.OwnerForm);
end;

procedure TFmrColorGalleryControl.SetHot(const AIndex: Integer);
var
  C: TCell;
begin
  if AIndex = FHot then
    Exit;
  FHot := AIndex;
  if FItem is TFmrColorGalleryItem then
  begin
    if (FHot >= 0) and (FCells[FHot].Kind in [TFmrColorCellKind.Color, TFmrColorCellKind.Automatic,
      TFmrColorCellKind.NoColor]) then
    begin
      C := FCells[FHot];
      FPreviewing := True;
      if C.Kind = TFmrColorCellKind.Automatic then
        TFmrColorGalleryItem(FItem).Preview(FItem.AutomaticColor, True)
      else
        TFmrColorGalleryItem(FItem).Preview(C.Color, True);
    end
    else
      EndPreview;
  end;
  UpdateTip;
  Repaint;
end;

procedure TFmrColorGalleryControl.Pick(const AIndex: Integer);
var
  Item: TFmrColorItem;
  Ctx: IFmrPopupContext;
  C: TAlphaColor;
  Kind: TFmrColorCellKind;
begin
  if (AIndex < 0) or (AIndex >= FCells.Count) then
    Exit;
  Item := FItem;
  Ctx := FContext;
  Kind := FCells[AIndex].Kind;
  C := FCells[AIndex].Color;
  EndPreview;
  ColorTipHover('', TRectF.Empty, nil, nil);
  FmrPopups.CloseAll;
  // The rest runs from the message loop: the popup (and this control) is freed soon, and the "More Colors" dialog
  // or a handler showing a dialog must not run inside its mouse handler.
  TThread.ForceQueue(nil,
    procedure
    var
      NewColor: TAlphaColor;
      Handled: Boolean;
    begin
      case Kind of
        TFmrColorCellKind.MoreColors:
          begin
            NewColor := Item.Color;
            if TAlphaColorRec(NewColor).A = 0 then
              NewColor := Item.AutomaticColor;
            Handled := False;
            if (Item is TFmrColorGalleryItem) and Assigned(TFmrColorGalleryItem(Item).OnMoreColors) then
            begin
              TFmrColorGalleryItem(Item).OnMoreColors(Item, NewColor, Handled);
              if Handled then
              begin
                FmrAddRecentColor(NewColor);
                Ctx.ItemExecuting(Item);
                Item.Color := NewColor;
                Item.Click;
              end;
              Exit;
            end;
            FmrShowColorDialog(NewColor, FmrStripAccel(FmrStr(TFmrStringId.ColorMoreColors)).TrimRight(['.']),
              procedure(AOk: Boolean; AColor: TAlphaColor)
              begin
                if not AOk then
                  Exit;
                FmrAddRecentColor(AColor);
                Ctx.ItemExecuting(Item);
                Item.Color := AColor;
                Item.Click;
              end);
            Exit;
          end;
        TFmrColorCellKind.Automatic:
          NewColor := TAlphaColors.Null;
        TFmrColorCellKind.NoColor:
          NewColor := FmrNoColor;
      else
        NewColor := C;
      end;
      Ctx.ItemExecuting(Item);
      Item.Color := NewColor;
      Item.Click;
    end);
end;

procedure TFmrColorGalleryControl.Paint;
var
  P: TFmrRibbonPainter;
  I: Integer;
  Cell: TCell;
  H: THeader;
  Y: Single;
  TextColor: TAlphaColor;
  SwatchR: TRectF;
begin
  P := FContext.Painter;
  TextColor := P.Theme.Colors[TFmrToken.MenuItemText];
  for H in FHeaders do
    P.DrawMenuHeader(Canvas, H.Rect, H.Caption);
  for Y in FSeparators do
    P.DrawMenuSeparator(Canvas, RectF(0, Y - 3, FWidth, Y + 3), 0);
  for I := 0 to FCells.Count - 1 do
  begin
    Cell := FCells[I];
    if Cell.Kind = TFmrColorCellKind.Color then
    begin
      P.DrawColorCell(Canvas, Cell.Rect, Cell.Color, I = FHot, IsSelected(Cell));
      Continue;
    end;
    if I = FHot then
      P.DrawMenuItem(Canvas, Cell.Rect, TFmrPartState.Hot);
    SwatchR := RectF(10, Cell.Rect.CenterPoint.Y - 7, 24, Cell.Rect.CenterPoint.Y + 7);
    case Cell.Kind of
      TFmrColorCellKind.Automatic:
        P.DrawColorCell(Canvas, SwatchR, FItem.AutomaticColor, False, IsSelected(Cell));
      TFmrColorCellKind.NoColor:
        begin
          P.DrawColorCell(Canvas, SwatchR, TAlphaColors.White, False, False);
          P.Line(Canvas, PointF(SwatchR.Left + 1, SwatchR.Bottom - 1), PointF(SwatchR.Right - 1, SwatchR.Top + 1),
            TAlphaColors.Red, 1.2);
        end;
      TFmrColorCellKind.MoreColors:
        begin
          // A small color wheel made of four quarters.
          P.DrawRadialSector(Canvas, SwatchR.CenterPoint, 0, 7, 180, 90, $FFE81123);
          P.DrawRadialSector(Canvas, SwatchR.CenterPoint, 0, 7, 270, 90, $FFFFB900);
          P.DrawRadialSector(Canvas, SwatchR.CenterPoint, 0, 7, 0, 90, $FF16C60C);
          P.DrawRadialSector(Canvas, SwatchR.CenterPoint, 0, 7, 90, 90, $FF0078D7);
        end;
    end;
    P.TextEx(Canvas, RectF(32, Cell.Rect.Top, Cell.Rect.Right - 4, Cell.Rect.Bottom), Cell.Name, TextColor,
      TTextAlign.Leading, TTextAlign.Center, 0, False, False);
  end;
end;

procedure TFmrColorGalleryControl.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  SetHot(CellAt(PointF(X, Y)));
end;

procedure TFmrColorGalleryControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if Button = TMouseButton.mbLeft then
    Pick(CellAt(PointF(X, Y)));
end;

procedure TFmrColorGalleryControl.DoMouseLeave;
begin
  inherited;
  SetHot(-1);
end;

function TFmrColorGalleryControl.PopupKeyDown(var Key: Word; var KeyChar: WideChar;
  const Shift: TShiftState): Boolean;
var
  I, Best: Integer;
  Cur, C, Dir: TPointF;
  D, BestD, Along, Across: Single;
begin
  Result := True;
  case Key of
    vkReturn, vkSpace:
      Pick(FHot);
    vkHome:
      SetHot(0);
    vkEnd:
      SetHot(FCells.Count - 1);
    vkLeft, vkRight, vkUp, vkDown:
      begin
        if FHot < 0 then
        begin
          SetHot(0);
          Exit;
        end;
        case Key of
          vkLeft: Dir := PointF(-1, 0);
          vkRight: Dir := PointF(1, 0);
          vkUp: Dir := PointF(0, -1);
        else
          Dir := PointF(0, 1);
        end;
        Cur := FCells[FHot].Rect.CenterPoint;
        if FCells[FHot].Kind <> TFmrColorCellKind.Color then
          Cur.X := FWidth / 2;
        Best := -1;
        BestD := MaxSingle;
        for I := 0 to FCells.Count - 1 do
        begin
          if I = FHot then
            Continue;
          C := FCells[I].Rect.CenterPoint;
          if FCells[I].Kind <> TFmrColorCellKind.Color then
          begin
            // Rows are reached vertically only.
            if Dir.Y = 0 then
              Continue;
            C.X := Cur.X;
          end;
          Along := (C.X - Cur.X) * Dir.X + (C.Y - Cur.Y) * Dir.Y;
          if Along <= 0.5 then
            Continue;
          Across := Abs((C.X - Cur.X) * Dir.Y + (C.Y - Cur.Y) * Dir.X);
          D := Along + 3 * Across;
          if D < BestD then
          begin
            BestD := D;
            Best := I;
          end;
        end;
        if Best >= 0 then
          SetHot(Best);
      end;
    vkEscape:
      Result := False;
  end;
end;

{ color dialog }

type
  /// The modal "More Colors" dialog.
  TFmrColorDialogForm = class(TForm)
  private
    FPanel: TColorPanel;
    FHex: TEdit;
    FNew: TRectangle;
    FCurrent: TRectangle;
    FUpdating: Boolean;
    procedure PanelChange(Sender: TObject);
    procedure HexChange(Sender: TObject);
    procedure CurrentClick(Sender: TObject);
    function GetColor: TAlphaColor;
    procedure SetColor(const AValue: TAlphaColor);
  public
    constructor CreateDialog(const AInitial: TAlphaColor; const ATitle: string);
    property Color: TAlphaColor read GetColor write SetColor;
  end;

constructor TFmrColorDialogForm.CreateDialog(const AInitial: TAlphaColor; const ATitle: string);

  function NewLabel(const AText: string; const X, Y: Single): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(X, Y, 80, 20);
    Result.Text := AText;
  end;

  function NewButton(const AText: string; const X, Y: Single; const AResult: TModalResult): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(X, Y, 84, 26);
    Result.Text := AText;
    Result.ModalResult := AResult;
  end;

begin
  inherited CreateNew(nil);
  Caption := ATitle;
  BorderStyle := TFmxFormBorderStyle.Single;
  BorderIcons := [TBorderIcon.biSystemMenu];
  Position := TFormPosition.MainFormCenter;
  ClientWidth := 392;
  ClientHeight := 286;
  FPanel := TColorPanel.Create(Self);
  FPanel.Parent := Self;
  FPanel.SetBounds(16, 16, 250, 220);
  FPanel.UseAlpha := False;
  FPanel.OnChange := PanelChange;
  NewLabel(SColorNew, 284, 16).TextSettings.HorzAlign := TTextAlign.Center;
  FNew := TRectangle.Create(Self);
  FNew.Parent := Self;
  FNew.SetBounds(284, 38, 92, 36);
  FNew.Stroke.Color := $FF808080;
  FCurrent := TRectangle.Create(Self);
  FCurrent.Parent := Self;
  FCurrent.SetBounds(284, 74, 92, 36);
  FCurrent.Stroke.Color := $FF808080;
  FCurrent.Fill.Color := AInitial or $FF000000;
  FCurrent.HitTest := True;
  FCurrent.OnClick := CurrentClick;
  NewLabel(SColorCurrent, 284, 112).TextSettings.HorzAlign := TTextAlign.Center;
  NewLabel(SColorHex, 284, 150);
  FHex := TEdit.Create(Self);
  FHex.Parent := Self;
  FHex.SetBounds(284, 172, 92, 24);
  FHex.MaxLength := 7;
  FHex.OnChangeTracking := HexChange;
  NewButton(FmrStr(TFmrStringId.CommonOK), 196, 248, mrOk).Default := True;
  NewButton(FmrStr(TFmrStringId.CommonCancel), 292, 248, mrCancel).Cancel := True;
  SetColor(AInitial or $FF000000);
end;

function TFmrColorDialogForm.GetColor: TAlphaColor;
begin
  Result := FPanel.Color or $FF000000;
end;

procedure TFmrColorDialogForm.SetColor(const AValue: TAlphaColor);
begin
  FUpdating := True;
  try
    FPanel.Color := AValue;
    FNew.Fill.Color := AValue;
    FHex.Text := '#' + IntToHex(AValue and $FFFFFF, 6);
  finally
    FUpdating := False;
  end;
end;

procedure TFmrColorDialogForm.PanelChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FUpdating := True;
  try
    FNew.Fill.Color := GetColor;
    FHex.Text := '#' + IntToHex(GetColor and $FFFFFF, 6);
  finally
    FUpdating := False;
  end;
end;

procedure TFmrColorDialogForm.HexChange(Sender: TObject);
var
  S: string;
  V: Integer;
begin
  if FUpdating then
    Exit;
  S := FHex.Text.Trim.TrimLeft(['#']);
  if (Length(S) = 6) and TryStrToInt('$' + S, V) then
  begin
    FUpdating := True;
    try
      FPanel.Color := TAlphaColor(V) or $FF000000;
      FNew.Fill.Color := TAlphaColor(V) or $FF000000;
    finally
      FUpdating := False;
    end;
  end;
end;

procedure TFmrColorDialogForm.CurrentClick(Sender: TObject);
begin
  SetColor(FCurrent.Fill.Color);
end;

procedure FmrShowColorDialog(const AInitial: TAlphaColor; const ATitle: string;
  const AOnDone: TProc<Boolean, TAlphaColor>);
var
  F: TFmrColorDialogForm;
begin
  F := TFmrColorDialogForm.CreateDialog(AInitial, ATitle);
  F.ShowModal(
    procedure(AResult: TModalResult)
    var
      C: TAlphaColor;
    begin
      C := F.Color;
      TThread.ForceQueue(nil,
        procedure
        begin
          F.Free;
        end);
      if Assigned(AOnDone) then
        AOnDone(AResult = mrOk, C);
    end);
end;

{ drop-down factory }

function CreateColorGalleryDropDown(const AItem: TFmrBarItem; const AContext: IFmrPopupContext): TControl;
begin
  Result := TFmrColorGalleryControl.CreateGallery(AContext, TFmrColorItem(AItem));
end;

initialization
  FmrRegisterDropDown(TFmrColorItem, CreateColorGalleryDropDown);
  RegisterFmxClasses([TFmrColorGalleryItem]);

finalization
  FreeAndNil(GColorTip);
  FreeAndNil(GColorTips);
  FreeAndNil(GRecent);

end.
