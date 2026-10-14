{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Editor controls painted with the ribbon theme        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.EditorStyles;

/// The ribbon creates real FMX controls for editor items (FMR.Ribbon.Editors). With the platform style they are
/// white boxes in dark themes. The classes of this unit are those controls with a style built in code from the theme
/// tokens (EditFill, EditBorder, EditBorderHot, EditText, ButtonArrow, Menu*...): every themed control overrides
/// GetStyleObject and returns a fresh tree of TRectangle/TText/TPath objects with the resource names the FMX
/// presentations look for ('background', 'content', 'foreground', 'selection', 'prompt', 'arrow', 'minusbutton',
/// 'plusbutton', 'htrack', 'thumb'...). A theme change gives the control a new unique StyleLookup, so FMX looks the
/// style up again (and never reuses a cached resource of the old colors). Styles of objects that FMX creates itself
/// (combo box list items and popups, spin buttons, track bar thumbs) are registered in the global FMX resource pool
/// (FMX.Types.AddResource) under unique names, one set per color scheme.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, FMX.Types, FMX.Controls, FMX.Graphics, FMX.Edit,
  FMX.ComboEdit, FMX.ListBox, FMX.SpinBox, FMX.StdCtrls, FMR.Ribbon.Theme;

type
  /// <summary>Colors and font of themed editors (taken from a ribbon theme).</summary>
  TFmrEditorColors = record
    Fill: TAlphaColor;
    Border: TAlphaColor;
    BorderHot: TAlphaColor;
    BorderFocused: TAlphaColor;
    Text: TAlphaColor;
    Selection: TAlphaColor;
    Arrow: TAlphaColor;
    ButtonHot: TAlphaColor;
    ButtonPressed: TAlphaColor;
    PopupFill: TAlphaColor;
    PopupBorder: TAlphaColor;
    ItemText: TAlphaColor;
    Track: TAlphaColor;
    TrackHighlight: TAlphaColor;
    Thumb: TAlphaColor;
    ThumbHot: TAlphaColor;
    Radius: Single;
    FontFamily: string;
    FontSize: Single;
    class function FromTheme(const ATheme: TFmrTheme): TFmrEditorColors; static;
    /// <summary>Identity of the scheme (equal keys = equal styles).</summary>
    function Key: string;
  end;

  /// <summary>Implemented by the themed editor controls.</summary>
  IFmrThemedEditor = interface
    ['{3D6A1F84-2C5B-4E07-9A3D-8B1C6E2F4A75}']
    procedure SetEditorColors(const AColors: TFmrEditorColors);
  end;

  TFmrRibbonEdit = class(TEdit, IFmrThemedEditor)
  private
    FColors: TFmrEditorColors;
    FThemed: Boolean;
  protected
    function GetStyleObject(const Clone: Boolean): TFmxObject; override;
  public
    procedure SetEditorColors(const AColors: TFmrEditorColors);
  end;

  TFmrRibbonComboEdit = class(TComboEdit, IFmrThemedEditor)
  private
    FColors: TFmrEditorColors;
    FThemed: Boolean;
    procedure ListPopup(Sender: TObject);
  protected
    function GetStyleObject(const Clone: Boolean): TFmxObject; override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetEditorColors(const AColors: TFmrEditorColors);
  end;

  TFmrRibbonComboBox = class(TComboBox, IFmrThemedEditor)
  private
    FColors: TFmrEditorColors;
    FThemed: Boolean;
    procedure ListPopup(Sender: TObject);
  protected
    function GetStyleObject(const Clone: Boolean): TFmxObject; override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetEditorColors(const AColors: TFmrEditorColors);
  end;

  TFmrRibbonSpinBox = class(TSpinBox, IFmrThemedEditor)
  private
    FColors: TFmrEditorColors;
    FThemed: Boolean;
  protected
    function GetStyleObject(const Clone: Boolean): TFmxObject; override;
  public
    procedure SetEditorColors(const AColors: TFmrEditorColors);
  end;

  TFmrRibbonTrackBar = class(TTrackBar, IFmrThemedEditor)
  private
    FColors: TFmrEditorColors;
    FThemed: Boolean;
  protected
    function GetStyleObject(const Clone: Boolean): TFmxObject; override;
  public
    procedure SetEditorColors(const AColors: TFmrEditorColors);
  end;

/// <summary>Applies the colors of ATheme to a themed editor (does nothing for other controls).</summary>
procedure FmrThemeEditor(const AControl: TControl; const ATheme: TFmrTheme);

/// <summary>Style trees of the themed controls (exposed for other themed controls, e.g. the customization form).
/// The caller owns the result.</summary>
function FmrBuildEditStyle(const AColors: TFmrEditorColors; const AArrow, ASpin: Boolean): TFmxObject;
function FmrBuildComboBoxStyle(const AColors: TFmrEditorColors): TFmxObject;
function FmrBuildTrackBarStyle(const AColors: TFmrEditorColors): TFmxObject;
/// <summary>StyleLookup names of pooled styles (list item, combo popup) for a color scheme.</summary>
function FmrListItemStyleName(const AColors: TFmrEditorColors): string;
function FmrPopupStyleName(const AColors: TFmrEditorColors): string;

implementation

uses
  System.Generics.Collections, System.Math, FMX.Objects, FMX.Layouts, FMX.Ani, FMX.ComboEdit.Style, FMX.Pickers,
  FMX.Controls.Presentation;

type
  TStyledControlAccess = class(TStyledControl);

var
  GCounter: Integer;
  GPool: TDictionary<string, string>;
  GPooled: TList<TFmxObject>;
  GSchemeLookups: TDictionary<string, string>;

function NextLookup(const AKind: string): string;
begin
  Inc(GCounter);
  Result := 'fmrribbon' + AKind + IntToStr(GCounter);
end;

/// FMX recycles the style tree of a control into its global style cache when the control is reparented, out of view
/// or gets another StyleLookup (TStyledControl.NeedStyleLookup), and takes a tree from there only when its TagString
/// is the StyleLookup asked for. The themed controls build their trees in GetStyleObject: the trees are tagged with
/// the lookup, and the lookup names a color scheme (equal names = equal trees), so a recycled tree is taken again by
/// any control of that scheme instead of staying in the cache until the application ends. A control that changes
/// its scheme frees its old tree.
procedure DropStyleTree(const AControl: TStyledControl);
var
  P: TObject;
begin
  TStyledControlAccess(AControl).KillResourceLink;
  if AControl is TPresentedControl then
  begin
    P := TPresentedControl(AControl).Presentation;
    if P is TStyledControl then
      TStyledControlAccess(P).KillResourceLink;
  end;
end;

procedure SetSchemeLookup(const AControl: TStyledControl; const AKind: string; const AColors: TFmrEditorColors);
var
  K, Name: string;
begin
  K := AKind + '|' + AColors.Key;
  if not GSchemeLookups.TryGetValue(K, Name) then
  begin
    Name := NextLookup(AKind);
    GSchemeLookups.Add(K, Name);
  end;
  if SameText(AControl.StyleLookup, Name) then
    Exit;
  DropStyleTree(AControl);
  AControl.StyleLookup := Name;
end;

/// TCustomListBox.ApplyStyle adds two clones of 'selection' to its style tree; a tree FMX recycled and hands out
/// again (the pooled list box styles) gets two more every time. A list box that changes its style frees its tree.
procedure DropListBoxTree(const AListBox: TControl);
begin
  if AListBox is TStyledControl then
    TStyledControlAccess(AListBox).KillResourceLink;
end;

function TaggedTree(const ATree: TFmxObject; const AControl: TStyledControl): TFmxObject;
begin
  Result := ATree;
  if Result <> nil then
    Result.TagString := AControl.StyleLookup;
end;

{ building blocks }

function NewRect(const AParent: TFmxObject; const AName: string; const AFill, AStroke: TAlphaColor;
  const ARadius: Single; const AAlign: TAlignLayout): TRectangle;
begin
  Result := TRectangle.Create(nil);
  Result.StyleName := AName;
  Result.Align := AAlign;
  Result.HitTest := False;
  Result.Locked := True;
  if TAlphaColorRec(AFill).A = 0 then
    Result.Fill.Kind := TBrushKind.None
  else
  begin
    Result.Fill.Kind := TBrushKind.Solid;
    Result.Fill.Color := AFill;
  end;
  if TAlphaColorRec(AStroke).A = 0 then
    Result.Stroke.Kind := TBrushKind.None
  else
  begin
    Result.Stroke.Kind := TBrushKind.Solid;
    Result.Stroke.Color := AStroke;
  end;
  Result.XRadius := ARadius;
  Result.YRadius := ARadius;
  Result.Parent := AParent;
end;

function NewLayout(const AParent: TFmxObject; const AName: string; const AAlign: TAlignLayout;
  const AWidth: Single = 0): TLayout;
begin
  Result := TLayout.Create(nil);
  Result.StyleName := AName;
  Result.Align := AAlign;
  Result.Locked := True;
  if AWidth > 0 then
    Result.Width := AWidth;
  Result.Parent := AParent;
end;

procedure NewBrush(const AParent: TFmxObject; const AName: string; const AColor: TAlphaColor);
var
  B: TBrushObject;
begin
  B := TBrushObject.Create(nil);
  B.StyleName := AName;
  B.Brush.Kind := TBrushKind.Solid;
  B.Brush.Color := AColor;
  B.Parent := AParent;
end;

procedure NewColor(const AParent: TFmxObject; const AName: string; const AColor: TAlphaColor);
var
  C: TColorObject;
begin
  C := TColorObject.Create(nil);
  C.StyleName := AName;
  C.Color := AColor;
  C.Parent := AParent;
end;

procedure NewFont(const AParent: TFmxObject; const AColors: TFmrEditorColors);
var
  F: TFontObject;
begin
  F := TFontObject.Create(nil);
  F.StyleName := 'font';
  if AColors.FontFamily <> '' then
    F.Font.Family := AColors.FontFamily;
  if AColors.FontSize > 0 then
    F.Font.Size := AColors.FontSize;
  F.Parent := AParent;
end;

procedure NewColorAnimation(const AParent: TFmxObject; const AProperty: string; const AFrom, ATo: TAlphaColor;
  const ATrigger, AInverse: string);
var
  A: TColorAnimation;
begin
  A := TColorAnimation.Create(nil);
  A.PropertyName := AProperty;
  A.StartValue := AFrom;
  A.StopValue := ATo;
  A.Duration := 0.08;
  A.Trigger := ATrigger;
  A.TriggerInverse := AInverse;
  A.Parent := AParent;
end;

function NewArrow(const AParent: TFmxObject; const AColor: TAlphaColor; const AUp: Boolean = False): TPath;
begin
  Result := TPath.Create(nil);
  Result.Align := TAlignLayout.Center;
  Result.Width := 7;
  Result.Height := 4;
  Result.HitTest := False;
  Result.Locked := True;
  Result.WrapMode := TPathWrapMode.Stretch;
  if AUp then
    Result.Data.Data := 'M0,4 L4,0 L8,4 Z'
  else
    Result.Data.Data := 'M0,0 L8,0 L4,4 Z';
  Result.Fill.Kind := TBrushKind.Solid;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  Result.Parent := AParent;
end;

function NewBackground(const AParent: TFmxObject; const AColors: TFmrEditorColors): TRectangle;
begin
  Result := NewRect(AParent, 'background', AColors.Fill, AColors.Border, AColors.Radius, TAlignLayout.Contents);
  NewColorAnimation(Result, 'Stroke.Color', AColors.Border, AColors.BorderHot, 'IsMouseOver=true',
    'IsMouseOver=false');
  NewColorAnimation(Result, 'Stroke.Color', AColors.Border, AColors.BorderFocused, 'IsFocused=true',
    'IsFocused=false');
end;

{ pooled styles: objects FMX creates itself and styles by name }

function Pooled(const AKind: string; const AColors: TFmrEditorColors;
  const ABuild: TFunc<TFmrEditorColors, TFmxObject>): string;
var
  K: string;
  Obj: TFmxObject;
begin
  K := AKind + '|' + AColors.Key;
  if GPool.TryGetValue(K, Result) then
    Exit;
  Result := NextLookup(AKind);
  Obj := ABuild(AColors);
  Obj.StyleName := Result;
  AddResource(Obj);
  GPooled.Add(Obj);
  GPool.Add(K, Result);
end;

function BuildFlatButton(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  BG: TRectangle;
begin
  Root := TLayout.Create(nil);
  Root.Width := 16;
  Root.Height := 11;
  BG := NewRect(Root, 'background', TAlphaColors.Null, TAlphaColors.Null, Max(0, AColors.Radius - 1),
    TAlignLayout.Contents);
  BG.Fill.Kind := TBrushKind.Solid;
  BG.Fill.Color := TAlphaColors.Null;
  NewColorAnimation(BG, 'Fill.Color', TAlphaColors.Null, AColors.ButtonHot, 'IsMouseOver=true', 'IsMouseOver=false');
  NewColorAnimation(BG, 'Fill.Color', AColors.ButtonHot, AColors.ButtonPressed, 'IsPressed=true', 'IsPressed=false');
  Result := Root;
end;

function BuildThumb(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  R: TRectangle;
begin
  Root := TLayout.Create(nil);
  Root.Width := 8;
  Root.Height := 16;
  R := NewRect(Root, 'background', AColors.Thumb, TAlphaColors.Null, 2, TAlignLayout.Contents);
  R.Margins.Rect := RectF(1, 1, 1, 1);
  NewColorAnimation(R, 'Fill.Color', AColors.Thumb, AColors.ThumbHot, 'IsMouseOver=true', 'IsMouseOver=false');
  Result := Root;
end;

function BuildListItem(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  T: TText;
begin
  Root := TLayout.Create(nil);
  Root.Width := 100;
  Root.Height := 20;
  T := TText.Create(nil);
  T.StyleName := 'text';
  T.Align := TAlignLayout.Client;
  T.Margins.Rect := RectF(6, 0, 4, 0);
  T.HitTest := False;
  T.Locked := True;
  T.TextSettings.HorzAlign := TTextAlign.Leading;
  T.TextSettings.WordWrap := False;
  T.TextSettings.FontColor := AColors.ItemText;
  if AColors.FontFamily <> '' then
    T.TextSettings.Font.Family := AColors.FontFamily;
  if AColors.FontSize > 0 then
    T.TextSettings.Font.Size := AColors.FontSize;
  T.Parent := Root;
  Result := Root;
end;

function BuildPopup(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
begin
  Root := TLayout.Create(nil);
  Root.Width := 100;
  Root.Height := 100;
  NewRect(Root, 'background', AColors.PopupFill, AColors.PopupBorder, Min(AColors.Radius, 4), TAlignLayout.Contents);
  Result := Root;
end;

function BuildScrollThumb(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  R: TRectangle;
begin
  Root := TLayout.Create(nil);
  Root.Width := 10;
  Root.Height := 30;
  R := NewRect(Root, 'background', FmrWithAlpha(AColors.ItemText, 0.32), TAlphaColors.Null, 3, TAlignLayout.Contents);
  R.Margins.Rect := RectF(3, 2, 3, 2);
  NewColorAnimation(R, 'Fill.Color', FmrWithAlpha(AColors.ItemText, 0.32), FmrWithAlpha(AColors.ItemText, 0.55),
    'IsMouseOver=true', 'IsMouseOver=false');
  Result := Root;
end;

function BuildScrollTrack(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  Thumb: TThumb;
begin
  Root := TLayout.Create(nil);
  Root.Width := 12;
  Root.Height := 100;
  Thumb := TThumb.Create(nil);
  Thumb.StyleName := 'thumb';
  Thumb.StyleLookup := Pooled('scrollthumb', AColors, BuildScrollThumb);
  Thumb.Locked := True;
  Thumb.Parent := Root;
  Result := Root;
end;

function BuildScrollBar(AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  T: TTrack;
  Lookup: string;
begin
  // Track and thumb only (no arrow buttons), in the colors of the drop-down: the platform scroll bar is light.
  Root := TLayout.Create(nil);
  Root.Width := 12;
  Root.Height := 100;
  NewRect(Root, 'background', AColors.PopupFill, TAlphaColors.Null, 0, TAlignLayout.Contents);
  Lookup := Pooled('scrolltrack', AColors, BuildScrollTrack);
  T := TTrack.Create(nil);
  T.StyleName := 'vtrack';
  T.Orientation := TOrientation.Vertical;
  T.StyleLookup := Lookup;
  T.Align := TAlignLayout.Client;
  T.Locked := True;
  T.Parent := Root;
  T := TTrack.Create(nil);
  T.StyleName := 'htrack';
  T.Orientation := TOrientation.Horizontal;
  T.StyleLookup := Lookup;
  T.Align := TAlignLayout.Client;
  T.Locked := True;
  T.Parent := Root;
  Result := Root;
end;

function BuildListBox(AColors: TFmrEditorColors): TFmxObject;
var
  Root, Content: TLayout;
  BG, Sel: TRectangle;
  SB: TScrollBar;
  ScrollLookup: string;
begin
  ScrollLookup := Pooled('scrollbar', AColors, BuildScrollBar);
  // Same resources as the platform 'listboxstyle': background > content (selection templates), scroll bars.
  Root := TLayout.Create(nil);
  Root.Width := 100;
  Root.Height := 100;
  BG := NewRect(Root, 'background', AColors.PopupFill, TAlphaColors.Null, 0, TAlignLayout.Contents);
  Content := NewLayout(BG, 'content', TAlignLayout.Client);
  Content.Margins.Rect := RectF(1, 1, 1, 1);
  Sel := NewRect(Content, 'selection', AColors.Selection, TAlphaColors.Null, 2, TAlignLayout.None);
  Sel.Visible := False;
  Sel := NewRect(Content, 'focusedselection', AColors.Selection, TAlphaColors.Null, 2, TAlignLayout.None);
  Sel.Visible := False;
  SB := TScrollBar.Create(nil);
  SB.StyleName := 'vscrollbar';
  SB.StyleLookup := ScrollLookup;
  SB.Align := TAlignLayout.Right;
  SB.Orientation := TOrientation.Vertical;
  SB.Width := 12;
  SB.SmallChange := 19;
  SB.Locked := True;
  SB.Parent := BG;
  SB := TScrollBar.Create(nil);
  SB.StyleName := 'hscrollbar';
  SB.StyleLookup := ScrollLookup;
  SB.Align := TAlignLayout.Bottom;
  SB.Height := 12;
  SB.Visible := False;
  SB.Locked := True;
  SB.Parent := BG;
  Result := Root;
end;

function FmrListItemStyleName(const AColors: TFmrEditorColors): string;
begin
  Result := Pooled('listitem', AColors, BuildListItem);
end;

function FmrListBoxStyleName(const AColors: TFmrEditorColors): string;
begin
  Result := Pooled('listbox', AColors, BuildListBox);
end;

function FmrPopupStyleName(const AColors: TFmrEditorColors): string;
begin
  Result := Pooled('popup', AColors, BuildPopup);
end;

{ style trees }

function FmrBuildEditStyle(const AColors: TFmrEditorColors; const AArrow, ASpin: Boolean): TFmxObject;
var
  Root, Content, Col: TLayout;
  Prompt: TText;
  Arrow: TLayout;
  Plus, Minus: TButton;
  Lookup: string;
begin
  Root := TLayout.Create(nil);
  Root.Width := 100;
  Root.Height := 22;
  NewBackground(Root, AColors);
  NewBrush(Root, 'foreground', AColors.Text);
  NewBrush(Root, 'selection', AColors.Selection);
  NewColor(Root, 'caretcolor', AColors.Text);
  NewFont(Root, AColors);
  Content := NewLayout(Root, 'content', TAlignLayout.Client);
  if AArrow or ASpin then
    Content.Margins.Rect := RectF(4, 2, 18, 2)
  else
    Content.Margins.Rect := RectF(4, 2, 3, 2);
  NewLayout(Root, 'buttons', TAlignLayout.Right);
  Prompt := TText.Create(nil);
  Prompt.StyleName := 'prompt';
  Prompt.Opacity := 0.55;
  Prompt.Visible := False;
  Prompt.HitTest := False;
  Prompt.Locked := True;
  Prompt.Parent := Root;
  if AArrow then
  begin
    Arrow := NewLayout(Root, 'arrow', TAlignLayout.Right, 18);
    Arrow.HitTest := True;
    NewArrow(Arrow, AColors.Arrow);
  end;
  if ASpin then
  begin
    Lookup := Pooled('flatbutton', AColors, BuildFlatButton);
    Col := NewLayout(Root, '', TAlignLayout.Right, 16);
    Col.Margins.Rect := RectF(0, 1, 1, 1);
    Plus := TButton.Create(nil);
    Plus.StyleName := 'plusbutton';
    Plus.StyleLookup := Lookup;
    Plus.Align := TAlignLayout.Top;
    Plus.Height := 10;
    Plus.CanFocus := False;
    Plus.Text := '';
    Plus.Parent := Col;
    NewArrow(Plus, AColors.Arrow, True);
    Minus := TButton.Create(nil);
    Minus.StyleName := 'minusbutton';
    Minus.StyleLookup := Lookup;
    Minus.Align := TAlignLayout.Client;
    Minus.CanFocus := False;
    Minus.Text := '';
    Minus.Parent := Col;
    NewArrow(Minus, AColors.Arrow, False);
  end;
  Result := Root;
end;

function FmrBuildComboBoxStyle(const AColors: TFmrEditorColors): TFmxObject;
var
  Root, Content, Arrow: TLayout;
begin
  Root := TLayout.Create(nil);
  Root.Width := 100;
  Root.Height := 22;
  NewBackground(Root, AColors);
  NewBrush(Root, 'foreground', AColors.Text);
  Arrow := NewLayout(Root, '', TAlignLayout.Right, 18);
  NewArrow(Arrow, AColors.Arrow);
  Content := NewLayout(Root, 'content', TAlignLayout.Contents);
  Content.Margins.Rect := RectF(1, 1, 18, 1);
  Result := Root;
end;

function FmrBuildTrackBarStyle(const AColors: TFmrEditorColors): TFmxObject;
var
  Root: TLayout;
  Track, Highlight, VTrack: TRectangle;
  Thumb: TThumb;
begin
  Root := TLayout.Create(nil);
  Root.Width := 100;
  Root.Height := 20;
  Track := NewRect(Root, 'htrack', AColors.Track, TAlphaColors.Null, 1, TAlignLayout.VertCenter);
  Track.Height := 3;
  Track.Margins.Rect := RectF(4, 0, 4, 0);
  Highlight := NewRect(Track, 'highlight', AColors.TrackHighlight, TAlphaColors.Null, 1, TAlignLayout.Left);
  Highlight.Width := 0;
  VTrack := NewRect(Root, 'vtrack', AColors.Track, TAlphaColors.Null, 1, TAlignLayout.HorzCenter);
  VTrack.Width := 3;
  VTrack.Visible := False;
  Thumb := TThumb.Create(nil);
  Thumb.StyleName := 'thumb';
  Thumb.StyleLookup := Pooled('thumb', AColors, BuildThumb);
  Thumb.Width := 8;
  Thumb.Height := 16;
  Thumb.Locked := True;
  Thumb.Parent := Root;
  Result := Root;
end;

{ TFmrEditorColors }

class function TFmrEditorColors.FromTheme(const ATheme: TFmrTheme): TFmrEditorColors;
var
  M: TFmrThemeMetrics;
begin
  M := ATheme.Metrics;
  Result.Fill := ATheme.Fills[TFmrToken.EditFill].MainColor;
  Result.Border := ATheme.Colors[TFmrToken.EditBorder];
  Result.BorderHot := ATheme.Colors[TFmrToken.EditBorderHot];
  Result.BorderFocused := ATheme.Colors[TFmrToken.Accent];
  if ATheme.Style.Dark then
    Result.BorderFocused := FmrLighten(Result.BorderFocused, 0.35);
  Result.Text := ATheme.Colors[TFmrToken.EditText];
  Result.Selection := FmrWithAlpha(ATheme.Colors[TFmrToken.Accent], 0.4);
  Result.Arrow := ATheme.Colors[TFmrToken.ButtonArrow];
  Result.ButtonHot := ATheme.Fills[TFmrToken.ButtonHotFill].MainColor;
  Result.ButtonPressed := ATheme.Fills[TFmrToken.ButtonPressedFill].MainColor;
  Result.PopupFill := ATheme.Fills[TFmrToken.MenuFill].MainColor;
  Result.PopupBorder := ATheme.Colors[TFmrToken.MenuBorder];
  Result.ItemText := ATheme.Colors[TFmrToken.MenuItemText];
  Result.Track := ATheme.Colors[TFmrToken.EditBorder];
  Result.TrackHighlight := ATheme.Colors[TFmrToken.ButtonArrow];
  Result.Thumb := ATheme.Colors[TFmrToken.ButtonArrow];
  Result.ThumbHot := ATheme.Colors[TFmrToken.ButtonText];
  Result.Radius := Min(M.ButtonRadius, 4);
  Result.FontFamily := M.FontFamily;
  Result.FontSize := M.FontSize;
end;

function TFmrEditorColors.Key: string;
begin
  Result := Format('%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%x.%g.%s.%g', [Fill, Border, BorderHot,
    BorderFocused, Text, Selection, Arrow, ButtonHot, ButtonPressed, PopupFill, PopupBorder, ItemText, Track,
    TrackHighlight, Thumb, ThumbHot, Radius, FontFamily, FontSize]);
end;

procedure FmrThemeEditor(const AControl: TControl; const ATheme: TFmrTheme);
var
  E: IFmrThemedEditor;
begin
  if (AControl <> nil) and (ATheme <> nil) and Supports(AControl, IFmrThemedEditor, E) then
    E.SetEditorColors(TFmrEditorColors.FromTheme(ATheme));
end;

procedure ThemeListBox(const AListBox: TCustomListBox; const AColors: TFmrEditorColors);
var
  I: Integer;
  Item: TListBoxItem;
  Name: string;
  Obj: TFmxObject;
begin
  if AListBox = nil then
    Exit;
  Name := FmrListItemStyleName(AColors);
  AListBox.DefaultItemStyles.ItemStyle := Name;
  for I := 0 to AListBox.Count - 1 do
  begin
    Item := AListBox.ListItems[I];
    if (Item <> nil) and (Item.StyleLookup <> Name) then
      Item.StyleLookup := Name;
  end;
  // The list box keeps the platform style; only its background goes, the popup paints the themed one.
  Obj := AListBox.FindStyleResource('background');
  if Obj is TControl then
    TControl(Obj).Opacity := 0;
end;

{ TFmrRibbonEdit }

function TFmrRibbonEdit.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  if FThemed then
    Result := TaggedTree(FmrBuildEditStyle(FColors, False, False), Self)
  else
    Result := inherited GetStyleObject(Clone);
end;

procedure TFmrRibbonEdit.SetEditorColors(const AColors: TFmrEditorColors);
begin
  if FThemed and (FColors.Key = AColors.Key) then
    Exit;
  FColors := AColors;
  FThemed := True;
  SetSchemeLookup(Self, 'edit', FColors);
end;

{ TFmrRibbonComboEdit }

constructor TFmrRibbonComboEdit.Create(AOwner: TComponent);
begin
  inherited;
  // The FMX list (not the platform picker), so its items and popup can take the themed styles.
  DropDownKind := TDropDownKind.Custom;
  OnPopup := ListPopup;
end;

function TFmrRibbonComboEdit.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  if FThemed then
    Result := TaggedTree(FmrBuildEditStyle(FColors, True, False), Self)
  else
    Result := inherited GetStyleObject(Clone);
end;

procedure TFmrRibbonComboEdit.ListPopup(Sender: TObject);
var
  P: TStyledComboEdit;
  Index: Integer;
begin
  if not FThemed or not (Presentation is TStyledComboEdit) then
    Exit;
  P := TStyledComboEdit(Presentation);
  ThemeListBox(P.ListBox, FColors);
  if (P.ListBox <> nil) and (P.ListBox.Parent is TPopup) then
    TPopup(P.ListBox.Parent).StyleLookup := FmrPopupStyleName(FColors);
  // The FMX list does not scroll to the current text by itself (the platform picker did).
  Index := Items.IndexOf(Text);
  if (P.ListBox <> nil) and (Index >= 0) and (Index < P.ListBox.Count) then
  begin
    P.ListBox.ItemIndex := Index;
    P.ListBox.ScrollToItem(P.ListBox.ListItems[Index]);
  end;
end;

procedure TFmrRibbonComboEdit.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
var
  L: TCustomListBox;
begin
  // While the list is open the wheel scrolls it (Office), also when the combo box holds the mouse capture or the
  // list cannot scroll further; it must not change the text or reach the ribbon behind.
  if DroppedDown and (Presentation is TStyledComboEdit) then
  begin
    L := TStyledComboEdit(Presentation).ListBox;
    if L <> nil then
      (L as IControl).MouseWheel(Shift, WheelDelta, Handled);
    Handled := True;
    Exit;
  end;
  inherited;
end;

procedure TFmrRibbonComboEdit.SetEditorColors(const AColors: TFmrEditorColors);
begin
  if FThemed and (FColors.Key = AColors.Key) then
    Exit;
  FColors := AColors;
  FThemed := True;
  if Presentation is TStyledComboEdit then
    DropListBoxTree(TStyledComboEdit(Presentation).ListBox);
  ListBoxResource := FmrListBoxStyleName(FColors);
  SetSchemeLookup(Self, 'comboedit', FColors);
end;

{ TFmrRibbonComboBox }

constructor TFmrRibbonComboBox.Create(AOwner: TComponent);
begin
  inherited;
  DropDownKind := TDropDownKind.Custom;
  OnPopup := ListPopup;
end;

function TFmrRibbonComboBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  if FThemed then
    Result := TaggedTree(FmrBuildComboBoxStyle(FColors), Self)
  else
    Result := inherited GetStyleObject(Clone);
end;

procedure TFmrRibbonComboBox.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  if DroppedDown then
  begin
    if ListBox <> nil then
      (ListBox as IControl).MouseWheel(Shift, WheelDelta, Handled);
    Handled := True;
    Exit;
  end;
  inherited;
end;

procedure TFmrRibbonComboBox.ListPopup(Sender: TObject);
begin
  if FThemed then
    ThemeListBox(ListBox, FColors);
end;

procedure TFmrRibbonComboBox.SetEditorColors(const AColors: TFmrEditorColors);
begin
  if FThemed and (FColors.Key = AColors.Key) then
    Exit;
  FColors := AColors;
  FThemed := True;
  // The face shows the selected list item, so the items need the themed style before the face is painted.
  DropListBoxTree(ListBox);
  ListBoxResource := FmrListBoxStyleName(FColors);
  ThemeListBox(ListBox, FColors);
  if Popup <> nil then
    Popup.StyleLookup := FmrPopupStyleName(FColors);
  SetSchemeLookup(Self, 'combobox', FColors);
end;

{ TFmrRibbonSpinBox }

function TFmrRibbonSpinBox.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  if FThemed then
    Result := TaggedTree(FmrBuildEditStyle(FColors, False, True), Self)
  else
    Result := inherited GetStyleObject(Clone);
end;

procedure TFmrRibbonSpinBox.SetEditorColors(const AColors: TFmrEditorColors);
begin
  if FThemed and (FColors.Key = AColors.Key) then
    Exit;
  FColors := AColors;
  FThemed := True;
  SetSchemeLookup(Self, 'spinbox', FColors);
end;

{ TFmrRibbonTrackBar }

function TFmrRibbonTrackBar.GetStyleObject(const Clone: Boolean): TFmxObject;
begin
  if FThemed then
    Result := TaggedTree(FmrBuildTrackBarStyle(FColors), Self)
  else
    Result := inherited GetStyleObject(Clone);
end;

procedure TFmrRibbonTrackBar.SetEditorColors(const AColors: TFmrEditorColors);
begin
  if FThemed and (FColors.Key = AColors.Key) then
    Exit;
  FColors := AColors;
  FThemed := True;
  SetSchemeLookup(Self, 'trackbar', FColors);
end;

procedure FreePool;
var
  Obj: TFmxObject;
begin
  if GPooled <> nil then
    for Obj in GPooled do
    begin
      RemoveResource(Obj);
      Obj.Free;
    end;
  FreeAndNil(GPooled);
  FreeAndNil(GPool);
  FreeAndNil(GSchemeLookups);
end;

initialization
  GPool := TDictionary<string, string>.Create;
  GPooled := TList<TFmxObject>.Create;
  GSchemeLookups := TDictionary<string, string>.Create;

finalization
  FreePool;

end.
