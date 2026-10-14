{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Editor views: FMX controls created per link          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Editors;

/// Views of editor items. Editor items (TFmrEditItem, TFmrComboItem, TFmrFontNameItem, TFmrSpinItem,
/// TFmrTrackBarItem) only hold data: TFmrEditorView creates a real FMX control for its link (TEdit, TComboBox or
/// TComboEdit, TSpinBox, TTrackBar), parents it to the control of its host (ribbon body, group popup), positions it
/// where the layout put the link and keeps it in sync with the item in both directions (TFmrItemChange.Value from the
/// item, OnChange of the control back to the item, which notifies the other links). TFmrControlItem shows its own
/// control (one parent: the last view placed shows it). The caption (and glyph) of the item is painted in front of
/// the control at the SmallWithText level.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, FMX.Types, FMX.Graphics, FMX.Controls,
  FMX.ImgList, FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Layout, FMR.Ribbon.Theme, FMR.Ribbon.Painter,
  FMR.Ribbon.Views;

type
  /// <summary>View of editor items and control items.</summary>
  TFmrEditorView = class(TFmrItemView)
  private type
    TNotifier = class(TComponent)
    private
      FView: TFmrEditorView;
    protected
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    end;
  private
    FControl: TControl;
    FOwnsControl: Boolean;
    FSyncing: Boolean;
    FNotifier: TNotifier;
    FPlaced: Boolean;
    function EditorWidth: Single;
    function LabelWidth: Single;
    function HasGlyph: Boolean;
    procedure EnsureControl;
    procedure ReleaseControl;
    procedure SyncToControl;
    procedure ControlChanged(Sender: TObject);
    function EditorRect: TRectF;
  public
    constructor Create(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
      const APlace: TFmrViewPlace); override;
    destructor Destroy; override;
    function MeasureWidth(const ALevel: TFmrViewLevel): Single; override;
    function LayoutLink: TFmrLayoutLink; override;
    procedure Place(const ABounds: TRectF; const ALevel: TFmrViewLevel; const ASegment: TFmrLayoutSegment); override;
    procedure Hide; override;
    procedure ItemChanged(const AChange: TFmrItemChange); override;
    procedure SetHost(const AHost: IFmrElementHost); override;
    function FocusControl: Boolean; override;
    function PartAt(const P: TPointF): TFmrElementPart; override;
    procedure Paint(const ACanvas: TCanvas); override;
    function KeyTipAnchor: TPointF; override;
    /// <summary>The FMX control of the view (nil before the view is first shown).</summary>
    property Control: TControl read FControl;
  end;

implementation

uses
  FMX.Edit, FMX.EditBox, FMX.ComboEdit, FMX.ListBox, FMX.SpinBox, FMX.StdCtrls, FMX.Forms, FMR.Ribbon.EditorStyles,
  FMR.Ribbon.BiDi;

{ TFmrEditorView.TNotifier }

procedure TFmrEditorView.TNotifier.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (FView <> nil) and (AComponent = FView.FControl) then
  begin
    FView.FControl := nil;
    FView.FOwnsControl := False;
  end;
end;

{ TFmrEditorView }

constructor TFmrEditorView.Create(const AHost: IFmrElementHost; const ALink: TFmrItemLink;
  const APlace: TFmrViewPlace);
begin
  inherited;
  FNotifier := TNotifier.Create(nil);
  FNotifier.FView := Self;
end;

destructor TFmrEditorView.Destroy;
begin
  ReleaseControl;
  FNotifier.FView := nil;
  FreeAndNil(FNotifier);
  inherited;
end;

procedure TFmrEditorView.ReleaseControl;
var
  C: TControl;
begin
  C := FControl;
  FControl := nil;
  if C = nil then
    Exit;
  C.RemoveFreeNotification(FNotifier);
  if FOwnsControl then
  begin
    if not (csDestroying in C.ComponentState) then
      C.Free;
  end
  else if not (csDestroying in C.ComponentState) then
  begin
    // A control of TFmrControlItem stays alive; it is only hidden.
    C.Visible := False;
  end;
  FOwnsControl := False;
end;

function TFmrEditorView.EditorWidth: Single;
begin
  Result := 100;
  if Item is TFmrCustomEditItem then
    Result := TFmrCustomEditItem(Item).Width
  else if Item is TFmrControlItem then
  begin
    Result := TFmrControlItem(Item).Width;
    if (Result <= 0) and (TFmrControlItem(Item).Control <> nil) then
      Result := TFmrControlItem(Item).Control.Width;
  end;
  if Result <= 0 then
    Result := 100;
end;

function TFmrEditorView.HasGlyph: Boolean;
begin
  Result := (Item <> nil) and not Item.Glyph.IsEmpty(Images);
end;

function TFmrEditorView.LabelWidth: Single;
var
  M: TFmrThemeMetrics;
begin
  M := Metrics;
  Result := M.ButtonPaddingH;
  if HasGlyph then
    Result := Result + M.SmallGlyphSize + 4;
  if Caption <> '' then
    Result := Result + Painter.TextWidth(Caption) + 6;
  Result := Ceil(Result);
end;

function TFmrEditorView.MeasureWidth(const ALevel: TFmrViewLevel): Single;
begin
  if ALevel = TFmrViewLevel.Small then
    Result := EditorWidth
  else
    Result := LabelWidth + EditorWidth;
  if ViewPlace = TFmrViewPlace.Toolbar then
    Result := EditorWidth;
end;

function TFmrEditorView.LayoutLink: TFmrLayoutLink;
begin
  Result := TFmrLayoutLink.Control(MeasureWidth(TFmrViewLevel.SmallWithText), MeasureWidth(TFmrViewLevel.Small));
  Result.Levels := Link.EffectiveViewLevels - [TFmrViewLevel.Large];
  if Result.Levels = [] then
    Result.Levels := [TFmrViewLevel.Small];
  Result.Hidden := not Link.IsVisible;
  Result.BeginGroup := Link.BeginGroup;
  Result.ButtonGroup := Link.ButtonGroup;
  Result.SimplifiedVisibility := Link.SimplifiedVisibility;
  Result.SimplifiedWidth := EditorWidth;
end;

function TFmrEditorView.EditorRect: TRectF;
var
  W, H: Single;
begin
  W := Min(EditorWidth, Bounds.Width);
  H := Min(Metrics.SmallButtonHeight, Bounds.Height);
  Result := RectF(Bounds.Right - W, Bounds.CenterPoint.Y - H / 2, Bounds.Right, Bounds.CenterPoint.Y + H / 2);
end;

procedure TFmrEditorView.EnsureControl;
var
  HostCtl: TControl;
  E: TEdit;
  CB: TComboBox;
  CE: TComboEdit;
  SB: TSpinBox;
  TB: TTrackBar;
begin
  if Item = nil then
    Exit;
  HostCtl := nil;
  if Host <> nil then
    HostCtl := Host.GetHostControl;
  if FControl = nil then
  begin
    if Item is TFmrControlItem then
    begin
      FControl := TFmrControlItem(Item).Control;
      FOwnsControl := False;
    end
    else if Item is TFmrEditItem then
    begin
      E := TFmrRibbonEdit.Create(nil);
      E.OnChange := ControlChanged;
      FControl := E;
      FOwnsControl := True;
    end
    else if Item is TFmrComboItem then
    begin
      if (Item is TFmrFontNameItem) and (TFmrComboItem(Item).Items.Count = 0) then
        TFmrFontNameItem(Item).RefreshFonts;
      if TFmrComboItem(Item).Editable then
      begin
        CE := TFmrRibbonComboEdit.Create(nil);
        CE.OnChange := ControlChanged;
        FControl := CE;
      end
      else
      begin
        CB := TFmrRibbonComboBox.Create(nil);
        CB.OnChange := ControlChanged;
        FControl := CB;
      end;
      FOwnsControl := True;
    end
    else if Item is TFmrSpinItem then
    begin
      SB := TFmrRibbonSpinBox.Create(nil);
      SB.OnChange := ControlChanged;
      FControl := SB;
      FOwnsControl := True;
    end
    else if Item is TFmrTrackBarItem then
    begin
      TB := TFmrRibbonTrackBar.Create(nil);
      TB.OnChange := ControlChanged;
      FControl := TB;
      FOwnsControl := True;
    end;
    if FControl = nil then
      Exit;
    FControl.FreeNotification(FNotifier);
    if FOwnsControl then
    begin
      FControl.Stored := False;
      FControl.Locked := True;
    end;
    SyncToControl;
  end;
  if (HostCtl <> nil) and (FControl.Parent <> HostCtl) then
    FControl.Parent := HostCtl;
end;

procedure TFmrEditorView.SyncToControl;
var
  CI: TFmrComboItem;
begin
  if (FControl = nil) or (Item = nil) or FSyncing then
    Exit;
  FSyncing := True;
  try
    FControl.Enabled := Item.Enabled;
    if FControl is TEdit then
    begin
      TEdit(FControl).Text := TFmrEditItem(Item).Text;
      TEdit(FControl).TextPrompt := TFmrEditItem(Item).TextPrompt;
      TEdit(FControl).MaxLength := TFmrEditItem(Item).MaxLength;
      TEdit(FControl).ReadOnly := TFmrEditItem(Item).ReadOnly;
    end
    else if FControl is TComboEdit then
    begin
      CI := TFmrComboItem(Item);
      if TComboEdit(FControl).Items.Text <> CI.Items.Text then
        TComboEdit(FControl).Items.Assign(CI.Items);
      TComboEdit(FControl).DropDownCount := CI.DropDownCount;
      TComboEdit(FControl).ReadOnly := CI.ReadOnly;
      if TComboEdit(FControl).Text <> CI.Text then
        TComboEdit(FControl).Text := CI.Text;
    end
    else if FControl is TComboBox then
    begin
      CI := TFmrComboItem(Item);
      if TComboBox(FControl).Items.Text <> CI.Items.Text then
        TComboBox(FControl).Items.Assign(CI.Items);
      TComboBox(FControl).DropDownCount := CI.DropDownCount;
      TComboBox(FControl).ItemIndex := CI.ItemIndex;
    end
    else if FControl is TSpinBox then
    begin
      TSpinBox(FControl).Min := TFmrSpinItem(Item).Min;
      if TFmrSpinItem(Item).Max > TFmrSpinItem(Item).Min then
        TSpinBox(FControl).Max := TFmrSpinItem(Item).Max
      else
        TSpinBox(FControl).Max := MaxInt;
      TSpinBox(FControl).Increment := TFmrSpinItem(Item).Increment;
      TSpinBox(FControl).DecimalDigits := TFmrSpinItem(Item).DecimalDigits;
      TSpinBox(FControl).Value := TFmrSpinItem(Item).Value;
      TSpinBox(FControl).ReadOnly := TFmrSpinItem(Item).ReadOnly;
    end
    else if FControl is TTrackBar then
    begin
      TTrackBar(FControl).Min := TFmrTrackBarItem(Item).Min;
      TTrackBar(FControl).Max := TFmrTrackBarItem(Item).Max;
      TTrackBar(FControl).Value := TFmrTrackBarItem(Item).Value;
    end;
  finally
    FSyncing := False;
  end;
end;

procedure TFmrEditorView.ControlChanged(Sender: TObject);
begin
  if FSyncing or (Item = nil) or (Sender <> FControl) then
    Exit;
  FSyncing := True;
  try
    if FControl is TEdit then
      TFmrEditItem(Item).Text := TEdit(FControl).Text
    else if FControl is TComboEdit then
      TFmrComboItem(Item).Text := TComboEdit(FControl).Text
    else if FControl is TComboBox then
      TFmrComboItem(Item).ItemIndex := TComboBox(FControl).ItemIndex
    else if FControl is TSpinBox then
      TFmrSpinItem(Item).Value := TSpinBox(FControl).Value
    else if FControl is TTrackBar then
      TFmrTrackBarItem(Item).Value := TTrackBar(FControl).Value;
  finally
    FSyncing := False;
  end;
end;

procedure TFmrEditorView.Place(const ABounds: TRectF; const ALevel: TFmrViewLevel;
  const ASegment: TFmrLayoutSegment);
var
  R: TRectF;
begin
  inherited;
  EnsureControl;
  if FControl = nil then
    Exit;
  if FOwnsControl and (Host <> nil) then
    FmrThemeEditor(FControl, Painter.Theme);
  R := EditorRect;
  if FControl is TTrackBar then
    R := RectF(R.Left, R.CenterPoint.Y - 10, R.Right, R.CenterPoint.Y + 10);
  // A right-to-left host flips its painting; the real control needs the mirrored position.
  if (Host <> nil) and FmrIsMirrored(Host) and (Host.GetHostControl <> nil) then
    R := FmrMirrorRect(R, Host.GetHostControl.Width);
  FControl.SetBounds(R.Left, R.Top, R.Width, R.Height);
  FControl.Visible := True;
  FPlaced := True;
end;

procedure TFmrEditorView.Hide;
begin
  inherited;
  if FControl <> nil then
    FControl.Visible := False;
  FPlaced := False;
end;

procedure TFmrEditorView.ItemChanged(const AChange: TFmrItemChange);
begin
  inherited;
  if FControl = nil then
    Exit;
  case AChange of
    TFmrItemChange.Value, TFmrItemChange.Paint:
      SyncToControl;
    TFmrItemChange.Layout:
      SyncToControl;
  end;
end;

procedure TFmrEditorView.SetHost(const AHost: IFmrElementHost);
begin
  inherited;
  if (FControl <> nil) and (AHost <> nil) and (AHost.GetHostControl <> nil) then
    FControl.Parent := AHost.GetHostControl;
end;

function TFmrEditorView.FocusControl: Boolean;
begin
  Result := False;
  if (FControl <> nil) and FControl.Visible and FControl.CanFocus then
  begin
    FControl.SetFocus;
    Result := FControl.IsFocused;
  end;
end;

function TFmrEditorView.PartAt(const P: TPointF): TFmrElementPart;
begin
  Result := TFmrElementPart.None;
end;

procedure TFmrEditorView.Paint(const ACanvas: TCanvas);
var
  M: TFmrThemeMetrics;
  X: Single;
  GlyphR: TRectF;
  State: TFmrPartState;
  Color: TAlphaColor;
begin
  if not Visible or (Level = TFmrViewLevel.Small) or (ViewPlace = TFmrViewPlace.Toolbar) then
    Exit;
  M := Metrics;
  if IsEnabled then
    State := TFmrPartState.Normal
  else
    State := TFmrPartState.Disabled;
  X := Bounds.Left + M.ButtonPaddingH;
  if HasGlyph then
  begin
    GlyphR := RectF(0, 0, M.SmallGlyphSize, M.SmallGlyphSize);
    GlyphR.Offset(Round(X), Round(Bounds.CenterPoint.Y - M.SmallGlyphSize / 2));
    FmrDrawImage(ACanvas, Item.Glyph, GlyphR, 1, Painter.GlyphTint(State), Images);
    X := GlyphR.Right + 4;
  end;
  Color := Painter.ButtonTextColor(State);
  Painter.TextEx(ACanvas, RectF(X, Bounds.Top, EditorRect.Left - 2, Bounds.Bottom), Caption, Color,
    TTextAlign.Leading, TTextAlign.Center, 0, False, False);
  PaintFocus(ACanvas);
end;

function TFmrEditorView.KeyTipAnchor: TPointF;
var
  R: TRectF;
begin
  R := EditorRect;
  Result := PointF(R.Left + 10, R.Bottom - 2);
end;

initialization
  FmrRegisterItemView(TFmrCustomEditItem, TFmrEditorView);
  FmrRegisterItemView(TFmrControlItem, TFmrEditorView);

end.
