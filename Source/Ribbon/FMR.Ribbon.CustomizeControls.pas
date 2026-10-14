{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Themed controls of the customization form            }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.CustomizeControls;

/// Small controls painted with the ribbon painter, so the customization form looks right in every theme (FMX
/// standard controls would keep the platform style, white in dark themes): push and drop-down buttons, a check box,
/// a list/tree with glyphs, check boxes and expand arrows, the page navigation of the form and the symbol grid of
/// the rename dialog. They share a TFmrCustTheme (painter + images) that the form owns.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Math,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.ImgList, FMR.Bars.Images, FMR.Ribbon.Theme, FMR.Ribbon.Painter;

type
  /// <summary>Painter and images used by the controls of one form.</summary>
  TFmrCustTheme = class
  private
    FPainter: TFmrRibbonPainter;
    FImages: TCustomImageList;
  public
    constructor Create(const APainter: TFmrRibbonPainter; const AImages: TCustomImageList);
    function TextColor: TAlphaColor;
    function DimTextColor: TAlphaColor;
    function Background: TAlphaColor;
    property Painter: TFmrRibbonPainter read FPainter;
    property Images: TCustomImageList read FImages;
  end;

  /// <summary>Base of the themed controls.</summary>
  TFmrCustControl = class(TControl)
  private
    FTheme: TFmrCustTheme;
  protected
    function P: TFmrRibbonPainter; inline;
  public
    constructor CreateThemed(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme);
      virtual;
    property Theme: TFmrCustTheme read FTheme;
  end;

  TFmrCustGlyph = (None, Up, Down, DropDown);

  /// <summary>Push button (Default: accent border, Enter in the form); DropDown: arrow on the right.</summary>
  TFmrCustButton = class(TFmrCustControl)
  private
    FCaption: string;
    FGlyph: TFmrCustGlyph;
    FHot, FDown, FIsDefault: Boolean;
    FOnClick: TNotifyEvent;
    procedure SetCaption(const Value: string);
  protected
    procedure Paint; override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure EnabledChanged; override;
  public
    constructor CreateThemed(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme);
      override;
    procedure Click; override;
    /// <summary>Screen rectangle (dp) for a drop-down menu below the button.</summary>
    function ScreenRect: TRectF;
    /// <summary>Width (dp) that shows the whole caption.</summary>
    function NaturalWidth: Single;
    property Caption: string read FCaption write SetCaption;
    property Glyph: TFmrCustGlyph read FGlyph write FGlyph;
    property IsDefault: Boolean read FIsDefault write FIsDefault;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  /// <summary>Check box with a caption.</summary>
  TFmrCustCheck = class(TFmrCustControl)
  private
    FCaption: string;
    FChecked, FHot: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetChecked(const Value: Boolean);
  protected
    procedure Paint; override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
  public
    constructor CreateThemed(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme);
      override;
    property Caption: string read FCaption write FCaption;
    property Checked: Boolean read FChecked write SetChecked;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TFmrCustRowKind = (Item, Header, Separator);

  /// <summary>One row of a TFmrCustList.</summary>
  TFmrCustRow = record
    Kind: TFmrCustRowKind;
    Level: Integer;
    Caption: string;
    Glyph: TFmrImageSource;
    Data: TObject;
    Tag: Integer;
    HasCheck: Boolean;
    Checked: Boolean;
    Expandable: Boolean;
    Expanded: Boolean;
    Bold: Boolean;
    Dim: Boolean;
    class function Create(const ACaption: string; const AData: TObject; const ALevel: Integer = 0;
      const AGlyph: TFmrImageSource = nil): TFmrCustRow; static;
  end;

  /// <summary>List and tree: rows with indentation, expand arrows, check boxes and glyphs; mouse wheel, a thin
  /// scroll bar and keyboard navigation.</summary>
  TFmrCustList = class(TFmrCustControl)
  private
    FRows: TList<TFmrCustRow>;
    FItemIndex: Integer;
    FHot: Integer;
    FScroll: Single;
    FDragging: Boolean;
    FDragStart, FDragScroll: Single;
    FEmptyText: string;
    FOnChange: TNotifyEvent;
    FOnActivate: TNotifyEvent;
    FOnCheck: TProc<Integer>;
    FOnToggle: TProc<Integer>;
    function RowHeight: Single;
    function ContentHeight: Single;
    function MaxScroll: Single;
    function RowRect(const AIndex: Integer): TRectF;
    function RowAt(const Y: Single): Integer;
    function NeedsScrollBar: Boolean;
    function TrackRect: TRectF;
    function ThumbRect: TRectF;
    function ArrowRect(const AIndex: Integer): TRectF;
    function CheckRect(const AIndex: Integer): TRectF;
    procedure SetItemIndex(const Value: Integer);
    procedure SetScroll(const Value: Single);
    function IsSelectable(const AIndex: Integer): Boolean;
    procedure MoveSelection(const ADelta: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure DoMouseLeave; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
  public
    constructor CreateThemed(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme);
      override;
    destructor Destroy; override;
    procedure Clear;
    function Add(const ARow: TFmrCustRow): Integer;
    /// <summary>Call after Clear/Add: repaints and clamps the selection and the scroll position.</summary>
    procedure Changed;
    procedure EnsureVisible(const AIndex: Integer);
    function Count: Integer;
    function Row(const AIndex: Integer): TFmrCustRow;
    function SelectedData: TObject;
    function SelectedRow(out ARow: TFmrCustRow): Boolean;
    /// <summary>First row with AData (and ATag when ATag >= 0); -1 when none.</summary>
    function IndexOfData(const AData: TObject; const ATag: Integer = -1): Integer;
    /// <summary>Screen rectangle (dp) of a row (diagnostics and drivers).</summary>
    function RowScreenRect(const AIndex: Integer): TRectF;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    property EmptyText: string read FEmptyText write FEmptyText;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    /// <summary>Double click or Enter on a row.</summary>
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OnCheck: TProc<Integer> read FOnCheck write FOnCheck;
    property OnToggle: TProc<Integer> read FOnToggle write FOnToggle;
  end;

  /// <summary>Vertical page navigation (Office options dialog style).</summary>
  TFmrCustNav = class(TFmrCustControl)
  private
    FItems: TArray<string>;
    FItemIndex: Integer;
    FHot: Integer;
    FOnChange: TNotifyEvent;
    function ItemRect(const AIndex: Integer): TRectF;
    procedure SetItemIndex(const Value: Integer);
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    property Items: TArray<string> read FItems write FItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  /// <summary>Grid of icon font glyphs (symbols of custom groups).</summary>
  TFmrCustSymbolGrid = class(TFmrCustControl)
  private
    FCodes: TArray<Cardinal>;
    FItemIndex: Integer;
    FHot: Integer;
    FGlyph: TFmrImageSource;
    function CellSize: Single;
    function Columns: Integer;
    function CellRect(const AIndex: Integer): TRectF;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor CreateThemed(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme);
      override;
    destructor Destroy; override;
    function SelectedCode: Cardinal;
    procedure SelectCode(const ACode: Cardinal);
    property Codes: TArray<Cardinal> read FCodes write FCodes;
  end;

/// <summary>A TLabel-like text control colored by the theme.</summary>
function FmrCustLabel(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme;
  const AText: string; const ABold: Boolean = False; const ASize: Single = 0): TControl;
/// <summary>Sets the text of a control created by FmrCustLabel.</summary>
procedure FmrCustSetLabel(const ALabel: TControl; const AText: string; const ADim: Boolean = False);

implementation

uses
  FMX.Objects;

{ TFmrCustTheme }

constructor TFmrCustTheme.Create(const APainter: TFmrRibbonPainter; const AImages: TCustomImageList);
begin
  inherited Create;
  FPainter := APainter;
  FImages := AImages;
end;

function TFmrCustTheme.Background: TAlphaColor;
begin
  Result := FPainter.Theme.Fills[TFmrToken.MenuFill].MainColor;
  if TAlphaColorRec(Result).A < 255 then
    Result := FPainter.Theme.Fills[TFmrToken.BodyFill].MainColor;
end;

function TFmrCustTheme.TextColor: TAlphaColor;
begin
  Result := FPainter.Theme.Colors[TFmrToken.MenuItemText];
end;

function TFmrCustTheme.DimTextColor: TAlphaColor;
begin
  Result := FPainter.Theme.Colors[TFmrToken.MenuShortcutText];
end;

{ labels }

function FmrCustLabel(const AOwner: TComponent; const AParent: TFmxObject; const ATheme: TFmrCustTheme;
  const AText: string; const ABold: Boolean; const ASize: Single): TControl;
var
  T: TText;
begin
  T := TText.Create(AOwner);
  T.Parent := AParent;
  T.HitTest := False;
  T.TextSettings.HorzAlign := TTextAlign.Leading;
  T.TextSettings.VertAlign := TTextAlign.Center;
  T.TextSettings.WordWrap := True;
  T.TextSettings.Trimming := TTextTrimming.Character;
  T.TextSettings.FontColor := ATheme.TextColor;
  T.TextSettings.Font.Family := ATheme.Painter.Metrics.FontFamily;
  if ASize > 0 then
    T.TextSettings.Font.Size := ASize
  else
    T.TextSettings.Font.Size := ATheme.Painter.Metrics.FontSize;
  if ABold then
    T.TextSettings.Font.Style := [TFontStyle.fsBold];
  T.Text := AText;
  T.TagObject := ATheme;
  Result := T;
end;

procedure FmrCustSetLabel(const ALabel: TControl; const AText: string; const ADim: Boolean);
var
  Theme: TFmrCustTheme;
begin
  if not (ALabel is TText) then
    Exit;
  TText(ALabel).Text := AText;
  if ALabel.TagObject is TFmrCustTheme then
  begin
    Theme := TFmrCustTheme(ALabel.TagObject);
    if ADim then
      TText(ALabel).TextSettings.FontColor := Theme.DimTextColor
    else
      TText(ALabel).TextSettings.FontColor := Theme.TextColor;
  end;
end;

{ TFmrCustControl }

constructor TFmrCustControl.CreateThemed(const AOwner: TComponent; const AParent: TFmxObject;
  const ATheme: TFmrCustTheme);
begin
  inherited Create(AOwner);
  FTheme := ATheme;
  HitTest := True;
  Parent := AParent;
end;

function TFmrCustControl.P: TFmrRibbonPainter;
begin
  Result := FTheme.Painter;
end;

{ TFmrCustButton }

constructor TFmrCustButton.CreateThemed(const AOwner: TComponent; const AParent: TFmxObject;
  const ATheme: TFmrCustTheme);
begin
  inherited;
  CanFocus := True;
  TabStop := True;
  AutoCapture := True;
  Height := Max(26, Round(ATheme.Painter.Metrics.SmallButtonHeight + 4));
end;

procedure TFmrCustButton.SetCaption(const Value: string);
begin
  FCaption := Value;
  Repaint;
end;

function TFmrCustButton.ScreenRect: TRectF;
var
  TL, BR: TPointF;
begin
  TL := LocalToScreen(PointF(0, 0));
  BR := LocalToScreen(PointF(Width, Height));
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

procedure TFmrCustButton.Paint;
var
  R, TextR: TRectF;
  Rad: Single;
  Col: TAlphaColor;
  C: TPointF;
begin
  R := LocalRect;
  Rad := Max(2, Min(P.Metrics.ButtonRadius, 4));
  if not AbsoluteEnabled then
  begin
    P.Fill(Canvas, R, TFmrToken.MenuFill, Rad);
    P.Frame(Canvas, R, FmrWithAlpha(P.Theme.Colors[TFmrToken.EditBorder], 0.5), Rad);
    Col := P.Theme.Colors[TFmrToken.ButtonTextDisabled];
  end
  else
  begin
    if FDown and FHot then
      P.Fill(Canvas, R, TFmrToken.ButtonPressedFill, Rad)
    else if FHot then
      P.Fill(Canvas, R, TFmrToken.ButtonHotFill, Rad)
    else
      P.Fill(Canvas, R, TFmrToken.MenuFill, Rad);
    if FIsDefault or IsFocused then
      P.Frame(Canvas, R, TFmrToken.Accent, Rad, [], 1.5)
    else if FHot then
      P.Frame(Canvas, R, TFmrToken.EditBorderHot, Rad)
    else
      P.Frame(Canvas, R, TFmrToken.EditBorder, Rad);
    Col := P.Theme.Colors[TFmrToken.ButtonText];
  end;
  TextR := RectF(R.Left + 8, R.Top, R.Right - 8, R.Bottom);
  case FGlyph of
    TFmrCustGlyph.Up, TFmrCustGlyph.Down:
      begin
        C := R.CenterPoint;
        if FCaption = '' then
        begin
          if FGlyph = TFmrCustGlyph.Up then
            P.DrawSwitchChevron(Canvas, R, True, Col)
          else
            P.DrawSwitchChevron(Canvas, R, False, Col);
        end;
      end;
    TFmrCustGlyph.DropDown:
      begin
        P.Arrow(Canvas, PointF(R.Right - 11, R.CenterPoint.Y + 0.5), TFmrArrowDirection.Down, Col);
        TextR.Right := R.Right - 20;
      end;
  end;
  if FCaption <> '' then
    P.TextEx(Canvas, TextR, FCaption, Col, TTextAlign.Center, TTextAlign.Center, 0, False, False);
end;

function TFmrCustButton.NaturalWidth: Single;
begin
  Result := Ceil(P.TextWidth(FCaption)) + 24;
  if FGlyph = TFmrCustGlyph.DropDown then
    Result := Result + 12;
end;

procedure TFmrCustButton.DoMouseEnter;
begin
  inherited;
  FHot := True;
  Repaint;
end;

procedure TFmrCustButton.DoMouseLeave;
begin
  inherited;
  FHot := False;
  Repaint;
end;

procedure TFmrCustButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    FDown := True;
    FHot := True;
    Repaint;
  end;
end;

procedure TFmrCustButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  // FMX calls Click after the release over the control (TControl.MouseClick).
  inherited;
  FDown := False;
  Repaint;
end;

procedure TFmrCustButton.Click;
begin
  if Assigned(FOnClick) and AbsoluteEnabled then
    FOnClick(Self);
end;

procedure TFmrCustButton.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  inherited;
  if (Key = vkReturn) or (KeyChar = ' ') then
  begin
    Key := 0;
    KeyChar := #0;
    Click;
  end;
end;

procedure TFmrCustButton.EnabledChanged;
begin
  inherited;
  Repaint;
end;

{ TFmrCustCheck }

constructor TFmrCustCheck.CreateThemed(const AOwner: TComponent; const AParent: TFmxObject;
  const ATheme: TFmrCustTheme);
begin
  inherited;
  CanFocus := True;
  TabStop := True;
  Height := 24;
end;

procedure TFmrCustCheck.SetChecked(const Value: Boolean);
begin
  if FChecked <> Value then
  begin
    FChecked := Value;
    Repaint;
  end;
end;

procedure TFmrCustCheck.Paint;
var
  S: TFmrPartState;
  Col: TAlphaColor;
begin
  if not AbsoluteEnabled then
    S := TFmrPartState.Disabled
  else if FHot then
    S := TFmrPartState.Hot
  else
    S := TFmrPartState.Normal;
  P.DrawCheckBox(Canvas, RectF(0, 0, 16, Height), FChecked, False, S);
  if AbsoluteEnabled then
    Col := FTheme.TextColor
  else
    Col := P.Theme.Colors[TFmrToken.ButtonTextDisabled];
  P.TextEx(Canvas, RectF(22, 0, Width, Height), FCaption, Col, TTextAlign.Leading, TTextAlign.Center, 0, False,
    False);
  if IsFocused then
    P.Frame(Canvas, RectF(0, 2, Min(Width, 26 + P.TextWidth(FCaption)), Height - 2), TFmrToken.FocusBorder, 2,
      [], 1, 0.4);
end;

procedure TFmrCustCheck.DoMouseEnter;
begin
  inherited;
  FHot := True;
  Repaint;
end;

procedure TFmrCustCheck.DoMouseLeave;
begin
  inherited;
  FHot := False;
  Repaint;
end;

procedure TFmrCustCheck.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if (Button = TMouseButton.mbLeft) and AbsoluteEnabled and LocalRect.Contains(PointF(X, Y)) then
  begin
    Checked := not Checked;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure TFmrCustCheck.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  inherited;
  if KeyChar = ' ' then
  begin
    KeyChar := #0;
    Checked := not Checked;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

{ TFmrCustRow }

class function TFmrCustRow.Create(const ACaption: string; const AData: TObject; const ALevel: Integer;
  const AGlyph: TFmrImageSource): TFmrCustRow;
begin
  Result := Default(TFmrCustRow);
  Result.Caption := ACaption;
  Result.Data := AData;
  Result.Level := ALevel;
  Result.Glyph := AGlyph;
  Result.Tag := 0;
end;

{ TFmrCustList }

constructor TFmrCustList.CreateThemed(const AOwner: TComponent; const AParent: TFmxObject;
  const ATheme: TFmrCustTheme);
begin
  inherited;
  FRows := TList<TFmrCustRow>.Create;
  FItemIndex := -1;
  FHot := -1;
  CanFocus := True;
  TabStop := True;
  AutoCapture := True;
  ClipChildren := True;
end;

destructor TFmrCustList.Destroy;
begin
  FreeAndNil(FRows);
  inherited;
end;

function TFmrCustList.RowHeight: Single;
begin
  Result := Max(22, Round(P.Metrics.MenuItemHeight));
end;

function TFmrCustList.ContentHeight: Single;
begin
  Result := FRows.Count * RowHeight + 4;
end;

function TFmrCustList.MaxScroll: Single;
begin
  Result := Max(0, ContentHeight - Height);
end;

function TFmrCustList.NeedsScrollBar: Boolean;
begin
  Result := ContentHeight > Height + 0.5;
end;

function TFmrCustList.TrackRect: TRectF;
begin
  Result := RectF(Width - 9, 2, Width - 2, Height - 2);
end;

function TFmrCustList.ThumbRect: TRectF;
var
  T: TRectF;
  H, Y: Single;
begin
  T := TrackRect;
  H := Max(20, T.Height * Height / Max(1, ContentHeight));
  if MaxScroll > 0 then
    Y := T.Top + (T.Height - H) * FScroll / MaxScroll
  else
    Y := T.Top;
  Result := RectF(T.Left + 1, Y, T.Right - 1, Y + H);
end;

function TFmrCustList.RowRect(const AIndex: Integer): TRectF;
var
  Right: Single;
begin
  Right := Width - 2;
  if NeedsScrollBar then
    Right := Width - 11;
  Result := RectF(2, 2 + AIndex * RowHeight - FScroll, Right, 2 + (AIndex + 1) * RowHeight - FScroll);
end;

function TFmrCustList.RowAt(const Y: Single): Integer;
begin
  Result := Floor((Y - 2 + FScroll) / RowHeight);
  if (Result < 0) or (Result >= FRows.Count) then
    Result := -1;
end;

function TFmrCustList.ArrowRect(const AIndex: Integer): TRectF;
var
  R: TRectF;
begin
  R := RowRect(AIndex);
  Result := RectF(R.Left + 2 + FRows[AIndex].Level * 18, R.Top, R.Left + 2 + FRows[AIndex].Level * 18 + 16, R.Bottom);
end;

function TFmrCustList.CheckRect(const AIndex: Integer): TRectF;
var
  A: TRectF;
begin
  A := ArrowRect(AIndex);
  Result := RectF(A.Right + 1, A.Top, A.Right + 17, A.Bottom);
end;

function TFmrCustList.IsSelectable(const AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FRows.Count) and (FRows[AIndex].Kind = TFmrCustRowKind.Item);
end;

procedure TFmrCustList.Clear;
begin
  FRows.Clear;
  FHot := -1;
end;

function TFmrCustList.Add(const ARow: TFmrCustRow): Integer;
begin
  Result := FRows.Add(ARow);
end;

procedure TFmrCustList.Changed;
begin
  if FItemIndex >= FRows.Count then
    FItemIndex := -1;
  SetScroll(FScroll);
  Repaint;
end;

function TFmrCustList.Count: Integer;
begin
  Result := FRows.Count;
end;

function TFmrCustList.Row(const AIndex: Integer): TFmrCustRow;
begin
  Result := FRows[AIndex];
end;

function TFmrCustList.SelectedData: TObject;
begin
  if IsSelectable(FItemIndex) then
    Result := FRows[FItemIndex].Data
  else
    Result := nil;
end;

function TFmrCustList.SelectedRow(out ARow: TFmrCustRow): Boolean;
begin
  Result := IsSelectable(FItemIndex);
  if Result then
    ARow := FRows[FItemIndex]
  else
    ARow := Default(TFmrCustRow);
end;

function TFmrCustList.IndexOfData(const AData: TObject; const ATag: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to FRows.Count - 1 do
    if (FRows[I].Data = AData) and ((ATag < 0) or (FRows[I].Tag = ATag)) then
      Exit(I);
  Result := -1;
end;

function TFmrCustList.RowScreenRect(const AIndex: Integer): TRectF;
var
  R: TRectF;
  TL, BR: TPointF;
begin
  R := RowRect(AIndex);
  TL := LocalToScreen(R.TopLeft);
  BR := LocalToScreen(R.BottomRight);
  Result := RectF(TL.X, TL.Y, BR.X, BR.Y);
end;

procedure TFmrCustList.SetScroll(const Value: Single);
var
  V: Single;
begin
  V := EnsureRange(Value, 0, MaxScroll);
  if V <> FScroll then
  begin
    FScroll := V;
    Repaint;
  end;
end;

procedure TFmrCustList.SetItemIndex(const Value: Integer);
var
  V: Integer;
begin
  V := Value;
  if not IsSelectable(V) then
    V := -1;
  if V = FItemIndex then
    Exit;
  FItemIndex := V;
  EnsureVisible(V);
  Repaint;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TFmrCustList.EnsureVisible(const AIndex: Integer);
var
  Top, Bottom: Single;
begin
  if (AIndex < 0) or (AIndex >= FRows.Count) then
    Exit;
  Top := 2 + AIndex * RowHeight;
  Bottom := Top + RowHeight;
  if Top - FScroll < 2 then
    SetScroll(Top - 2)
  else if Bottom - FScroll > Height - 2 then
    SetScroll(Bottom - Height + 2);
end;

procedure TFmrCustList.MoveSelection(const ADelta: Integer);
var
  I, N: Integer;
begin
  N := FRows.Count;
  if N = 0 then
    Exit;
  I := FItemIndex;
  if I < 0 then
  begin
    if ADelta > 0 then
      I := -1
    else
      I := N;
  end;
  repeat
    I := I + Sign(ADelta);
  until (I < 0) or (I >= N) or IsSelectable(I);
  if (I >= 0) and (I < N) then
    ItemIndex := I;
end;

procedure TFmrCustList.Paint;
var
  I, First, Last: Integer;
  R, A, Cb, G, TextR: TRectF;
  Row: TFmrCustRow;
  Col: TAlphaColor;
  X, Rad: Single;
  State: TCanvasSaveState;
  Sel: Boolean;
begin
  Rad := Min(P.Metrics.ButtonRadius, 4);
  P.Fill(Canvas, LocalRect, TFmrToken.EditFill, Rad);
  if IsFocused then
    P.Frame(Canvas, LocalRect, TFmrToken.EditBorderHot, Rad)
  else
    P.Frame(Canvas, LocalRect, TFmrToken.EditBorder, Rad);
  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(RectF(1, 1, Width - 1, Height - 1));
    if FRows.Count = 0 then
    begin
      if FEmptyText <> '' then
        P.TextEx(Canvas, RectF(8, 6, Width - 8, 6 + RowHeight), FEmptyText, FTheme.DimTextColor, TTextAlign.Leading,
          TTextAlign.Center, 0, False, False);
      Exit;
    end;
    First := Max(0, Floor(FScroll / RowHeight));
    Last := Min(FRows.Count - 1, Ceil((FScroll + Height) / RowHeight));
    for I := First to Last do
    begin
      Row := FRows[I];
      R := RowRect(I);
      case Row.Kind of
        TFmrCustRowKind.Header:
          begin
            P.Fill(Canvas, R, TFmrToken.MenuHeaderFill);
            P.TextEx(Canvas, RectF(R.Left + 6 + Row.Level * 18, R.Top, R.Right - 4, R.Bottom), Row.Caption,
              P.Theme.Colors[TFmrToken.MenuHeaderText], TTextAlign.Leading, TTextAlign.Center, 0, True, False);
            Continue;
          end;
        TFmrCustRowKind.Separator:
          begin
            P.Line(Canvas, PointF(R.Left + 8, Round(R.CenterPoint.Y) + 0.5), PointF(R.Right - 8,
              Round(R.CenterPoint.Y) + 0.5), P.Theme.Colors[TFmrToken.MenuSeparator]);
            Continue;
          end;
      end;
      Sel := I = FItemIndex;
      if Sel then
      begin
        if IsFocused then
          P.Fill(Canvas, R, TFmrToken.GalleryItemSelectedFill, Rad)
        else
          P.Fill(Canvas, R, TFmrFill.Solid(FmrWithAlpha(P.Theme.Colors[TFmrToken.GalleryItemSelectedBorder], 0.12)),
            Rad);
        P.Frame(Canvas, R, TFmrToken.GalleryItemSelectedBorder, Rad);
      end
      else if I = FHot then
        P.Fill(Canvas, R, TFmrToken.MenuItemHotFill, Rad);
      A := ArrowRect(I);
      if Row.Expandable then
      begin
        if Row.Expanded then
          P.Arrow(Canvas, A.CenterPoint, TFmrArrowDirection.Down, P.Theme.Colors[TFmrToken.ButtonArrow])
        else
          P.Arrow(Canvas, A.CenterPoint, TFmrArrowDirection.Right, P.Theme.Colors[TFmrToken.ButtonArrow]);
      end;
      X := A.Right + 2;
      if Row.HasCheck then
      begin
        Cb := CheckRect(I);
        P.DrawCheckBox(Canvas, Cb, Row.Checked, False, TFmrPartState.Normal);
        X := Cb.Right + 4;
      end;
      if Row.Glyph <> nil then
      begin
        G := RectF(0, 0, P.Metrics.SmallGlyphSize, P.Metrics.SmallGlyphSize);
        G.Offset(Round(X), Round(R.CenterPoint.Y - G.Height / 2));
        if not Row.Glyph.IsEmpty(FTheme.Images) then
          Row.Glyph.Draw(Canvas, G, 1, P.GlyphTint(TFmrPartState.Normal), FTheme.Images);
        X := G.Right + 6;
      end;
      if Row.Dim then
        Col := FTheme.DimTextColor
      else
        Col := FTheme.TextColor;
      TextR := RectF(X, R.Top, R.Right - 4, R.Bottom);
      P.TextEx(Canvas, TextR, Row.Caption, Col, TTextAlign.Leading, TTextAlign.Center, 0, Row.Bold, False);
    end;
  finally
    Canvas.RestoreState(State);
  end;
  if NeedsScrollBar then
  begin
    P.Fill(Canvas, TrackRect, TFmrFill.Solid(FmrWithAlpha(FTheme.TextColor, 0.06)), 3);
    P.Fill(Canvas, ThumbRect, TFmrFill.Solid(FmrWithAlpha(FTheme.TextColor, 0.35)), 2.5);
  end;
end;

procedure TFmrCustList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
  Row: TFmrCustRow;
begin
  inherited;
  if CanFocus and not IsFocused then
    SetFocus;
  if Button <> TMouseButton.mbLeft then
    Exit;
  if NeedsScrollBar and (X >= TrackRect.Left - 1) then
  begin
    if ThumbRect.Contains(PointF(X, Y)) then
    begin
      FDragging := True;
      FDragStart := Y;
      FDragScroll := FScroll;
    end
    else if Y < ThumbRect.Top then
      SetScroll(FScroll - Height + RowHeight)
    else
      SetScroll(FScroll + Height - RowHeight);
    Exit;
  end;
  I := RowAt(Y);
  if not IsSelectable(I) then
    Exit;
  Row := FRows[I];
  if Row.Expandable and ArrowRect(I).Contains(PointF(X, Y)) then
  begin
    ItemIndex := I;
    if Assigned(FOnToggle) then
      FOnToggle(I);
    Exit;
  end;
  if Row.HasCheck and CheckRect(I).Contains(PointF(X, Y)) then
  begin
    ItemIndex := I;
    if Assigned(FOnCheck) then
      FOnCheck(I);
    Exit;
  end;
  ItemIndex := I;
  if ssDouble in Shift then
  begin
    if Row.Expandable and Assigned(FOnToggle) and not Assigned(FOnActivate) then
      FOnToggle(I)
    else if Assigned(FOnActivate) then
      FOnActivate(Self);
  end;
end;

procedure TFmrCustList.MouseMove(Shift: TShiftState; X, Y: Single);
var
  H: Integer;
  T: TRectF;
begin
  inherited;
  if FDragging then
  begin
    T := TrackRect;
    if T.Height - ThumbRect.Height > 0 then
      SetScroll(FDragScroll + (Y - FDragStart) * MaxScroll / (T.Height - ThumbRect.Height));
    Exit;
  end;
  H := RowAt(Y);
  if not IsSelectable(H) or (NeedsScrollBar and (X >= TrackRect.Left - 1)) then
    H := -1;
  if H <> FHot then
  begin
    FHot := H;
    Repaint;
  end;
end;

procedure TFmrCustList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  FDragging := False;
end;

procedure TFmrCustList.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if not Handled then
  begin
    SetScroll(FScroll - WheelDelta / 120 * RowHeight * 3);
    Handled := True;
  end;
end;

procedure TFmrCustList.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  Row: TFmrCustRow;
  Handled: Boolean;
begin
  inherited;
  Handled := True;
  case Key of
    vkUp: MoveSelection(-1);
    vkDown: MoveSelection(1);
    vkPrior: MoveSelection(-Max(1, Trunc(Height / RowHeight) - 1));
    vkNext: MoveSelection(Max(1, Trunc(Height / RowHeight) - 1));
    vkHome:
      begin
        FItemIndex := -1;
        MoveSelection(1);
      end;
    vkEnd:
      begin
        FItemIndex := -1;
        MoveSelection(-1);
      end;
    vkLeft, vkRight:
      if SelectedRow(Row) and Row.Expandable and (Row.Expanded = (Key = vkLeft)) and Assigned(FOnToggle) then
        FOnToggle(FItemIndex)
      else
        Handled := False;
    vkReturn:
      if Assigned(FOnActivate) and (FItemIndex >= 0) then
        FOnActivate(Self)
      else
        Handled := False;
  else
    if (KeyChar = ' ') and SelectedRow(Row) and Row.HasCheck and Assigned(FOnCheck) then
      FOnCheck(FItemIndex)
    else
      Handled := False;
  end;
  if Handled then
  begin
    Key := 0;
    KeyChar := #0;
  end;
end;

procedure TFmrCustList.DoMouseLeave;
begin
  inherited;
  if FHot <> -1 then
  begin
    FHot := -1;
    Repaint;
  end;
end;

procedure TFmrCustList.DoEnter;
begin
  inherited;
  Repaint;
end;

procedure TFmrCustList.DoExit;
begin
  inherited;
  Repaint;
end;

procedure TFmrCustList.Resize;
begin
  inherited;
  if FRows <> nil then
    SetScroll(FScroll);
end;

{ TFmrCustNav }

function TFmrCustNav.ItemRect(const AIndex: Integer): TRectF;
var
  H: Single;
begin
  H := Max(32, Round(P.Metrics.MenuItemHeight + 10));
  Result := RectF(0, 12 + AIndex * H, Width, 12 + (AIndex + 1) * H);
end;

procedure TFmrCustNav.SetItemIndex(const Value: Integer);
begin
  if FItemIndex <> Value then
  begin
    FItemIndex := Value;
    Repaint;
  end;
end;

procedure TFmrCustNav.Paint;
var
  I: Integer;
  R: TRectF;
  Col: TAlphaColor;
begin
  P.Fill(Canvas, LocalRect, TFmrToken.BackstageNavFill);
  P.Line(Canvas, PointF(Width - 0.5, 0), PointF(Width - 0.5, Height), P.Theme.Colors[TFmrToken.BackstageNavSeparator]);
  for I := 0 to High(FItems) do
  begin
    R := ItemRect(I);
    Col := P.Theme.Colors[TFmrToken.BackstageNavText];
    if I = FItemIndex then
    begin
      P.Fill(Canvas, RectF(R.Left, R.Top, R.Right - 1, R.Bottom), TFmrToken.BackstageNavSelectedFill);
      P.Fill(Canvas, RectF(R.Left, R.Top + 4, R.Left + 3, R.Bottom - 4), TFmrToken.Accent);
      Col := P.Theme.Colors[TFmrToken.BackstageNavSelectedText];
    end
    else if I = FHot then
      P.Fill(Canvas, RectF(R.Left, R.Top, R.Right - 1, R.Bottom), TFmrToken.BackstageNavHotFill);
    P.TextEx(Canvas, RectF(R.Left + 16, R.Top, R.Right - 8, R.Bottom), FItems[I], Col, TTextAlign.Leading,
      TTextAlign.Center, 0, False, False);
  end;
end;

procedure TFmrCustNav.MouseMove(Shift: TShiftState; X, Y: Single);
var
  I, H: Integer;
begin
  inherited;
  H := -1;
  for I := 0 to High(FItems) do
    if ItemRect(I).Contains(PointF(X, Y)) then
      H := I;
  if H <> FHot then
  begin
    FHot := H;
    Repaint;
  end;
end;

procedure TFmrCustNav.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  for I := 0 to High(FItems) do
    if ItemRect(I).Contains(PointF(X, Y)) and (I <> FItemIndex) then
    begin
      ItemIndex := I;
      if Assigned(FOnChange) then
        FOnChange(Self);
      Break;
    end;
end;

procedure TFmrCustNav.DoMouseLeave;
begin
  inherited;
  FHot := -1;
  Repaint;
end;

{ TFmrCustSymbolGrid }

constructor TFmrCustSymbolGrid.CreateThemed(const AOwner: TComponent; const AParent: TFmxObject;
  const ATheme: TFmrCustTheme);
begin
  inherited;
  FGlyph := TFmrImageSource.Create(nil);
  FItemIndex := -1;
  FHot := -1;
end;

destructor TFmrCustSymbolGrid.Destroy;
begin
  FreeAndNil(FGlyph);
  inherited;
end;

function TFmrCustSymbolGrid.CellSize: Single;
begin
  Result := 30;
end;

function TFmrCustSymbolGrid.Columns: Integer;
begin
  Result := Max(1, Trunc((Width - 4) / CellSize));
end;

function TFmrCustSymbolGrid.CellRect(const AIndex: Integer): TRectF;
var
  C, R: Integer;
begin
  C := AIndex mod Columns;
  R := AIndex div Columns;
  Result := RectF(2 + C * CellSize, 2 + R * CellSize, 2 + (C + 1) * CellSize, 2 + (R + 1) * CellSize);
end;

function TFmrCustSymbolGrid.SelectedCode: Cardinal;
begin
  if (FItemIndex >= 0) and (FItemIndex <= High(FCodes)) then
    Result := FCodes[FItemIndex]
  else
    Result := 0;
end;

procedure TFmrCustSymbolGrid.SelectCode(const ACode: Cardinal);
var
  I: Integer;
begin
  FItemIndex := -1;
  for I := 0 to High(FCodes) do
    if FCodes[I] = ACode then
      FItemIndex := I;
  Repaint;
end;

procedure TFmrCustSymbolGrid.Paint;
var
  I: Integer;
  R, G: TRectF;
begin
  P.Fill(Canvas, LocalRect, TFmrToken.EditFill, Min(P.Metrics.ButtonRadius, 4));
  P.Frame(Canvas, LocalRect, TFmrToken.EditBorder, Min(P.Metrics.ButtonRadius, 4));
  for I := 0 to High(FCodes) do
  begin
    R := CellRect(I);
    if R.Bottom > Height then
      Break;
    R.Inflate(-2, -2);
    if I = FItemIndex then
    begin
      P.Fill(Canvas, R, TFmrToken.GalleryItemSelectedFill, 2);
      P.Frame(Canvas, R, TFmrToken.GalleryItemSelectedBorder, 2);
    end
    else if I = FHot then
      P.Fill(Canvas, R, TFmrToken.MenuItemHotFill, 2);
    FGlyph.GlyphCode := FCodes[I];
    G := RectF(0, 0, 16, 16).CenterAt(R);
    FGlyph.Draw(Canvas, G, 1, P.GlyphTint(TFmrPartState.Normal), nil);
  end;
end;

procedure TFmrCustSymbolGrid.MouseMove(Shift: TShiftState; X, Y: Single);
var
  I, H: Integer;
begin
  inherited;
  H := -1;
  for I := 0 to High(FCodes) do
    if CellRect(I).Contains(PointF(X, Y)) then
      H := I;
  if H <> FHot then
  begin
    FHot := H;
    Repaint;
  end;
end;

procedure TFmrCustSymbolGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
begin
  inherited;
  for I := 0 to High(FCodes) do
    if CellRect(I).Contains(PointF(X, Y)) then
    begin
      FItemIndex := I;
      Repaint;
    end;
end;

procedure TFmrCustSymbolGrid.DoMouseLeave;
begin
  inherited;
  FHot := -1;
  Repaint;
end;

end.
