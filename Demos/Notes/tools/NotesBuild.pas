{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  FMR Notes demo: form builder of the generator        }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit NotesBuild;

/// Builds the main form of FMR Notes in code, the way a developer designs it in the IDE: every component is owned
/// by the form, has a name (the published fields of TNotesForm are bound by name) and its events point to
/// published methods of the form, so WriteComponent stores them as method names. GenForm.dpr writes the result to
/// NotesMain.fmx; the demo itself never runs this code.

interface

uses
  NotesMain;

procedure BuildNotesForm(const AForm: TNotesForm);

implementation

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Objects, FMX.Layouts, FMX.StdCtrls, FMX.Edit, FMX.ListBox, FMX.SpinBox, FMX.Effects,
  FMX.ImgList, FMX.MultiResBitmap, FMX.Dialogs, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Structure, FMR.Ribbon, FMR.Ribbon.Gallery, FMR.Ribbon.ColorGallery, FMR.Ribbon.MiniToolbar,
  FMR.Ribbon.Popup, FMR.Ribbon.Backstage, FMR.Ribbon.Backstage.Controls, FMR.Ribbon.StatusBar, FMR.Frame.Types,
  FMR.Frame, FMR.Ribbon.Theme, FMR.Ribbon.Templates, NotesData;

type
  TBuilder = class
  private
    F: TNotesForm;
    M: TFmrBarManager;
    R: TFmrRibbon;
    BS: TFmrRibbonBackstageView;
    FOrder: Integer;
    function NextPos: Single;
    function Btn(const AName, ACaption: string; const AGlyph: Cardinal; const AClick: TNotifyEvent;
      const AStyle: TFmrButtonStyle = TFmrButtonStyle.Default; const ALarge: Boolean = False): TFmrButtonItem;
    function Check(const AName, ACaption: string; const AChecked: Boolean; const AClick: TNotifyEvent): TFmrCheckItem;
    function Radio(const AParent: TFmrButtonItem; const AName, ACaption: string; const AGroupIndex, ATag: Integer;
      const ADown: Boolean; const AClick: TNotifyEvent): TFmrButtonItem;
    function Tab(const AName, ACaption, AKeyTip: string): TFmrRibbonTab;
    function Group(const ATab: TFmrRibbonTab; const AName, ACaption: string): TFmrRibbonGroup;
    function Link(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem; const ALevels: TFmrViewLevels = [];
      const AButtonGroup: TFmrButtonGroupPosition = TFmrButtonGroupPosition.None;
      const ABeginGroup: Boolean = False): TFmrItemLink;
    procedure Tip(const AItem: TFmrBarItem; const AHeader, ADescription: string);
    function BLabel(const AParent: TFmxObject; const AName, AText: string; const AStyle: TFmrBackstageTextStyle;
      const AAlign: TAlignLayout = TAlignLayout.Top; const ATopMargin: Single = 0): TFmrBackstageLabel;
    function BHeader(const AParent: TFmxObject; const AName, AText: string): TFmrBackstageHeader;
    function BTile(const AParent: TFmxObject; const AName, ACaption, ADescription: string; const AGlyph: Cardinal;
      const ALayout: TFmrBackstageTileLayout; const AAlign: TAlignLayout; const AW, AH: Single;
      const AClick: TNotifyEvent): TFmrBackstageTile;
    function Layout(const AParent: TFmxObject; const AName: string; const AAlign: TAlignLayout;
      const ASize: Single): TLayout;
    procedure BuildImages;
    procedure BuildItems;
    procedure BuildHome;
    procedure BuildInsert;
    procedure BuildLayout;
    procedure BuildView;
    procedure BuildSelectionTools;
    procedure BuildPopups;
    procedure BuildBackstage;
    procedure BuildInfo(const ATab: TFmrBackstageTab);
    procedure BuildNew(const ATab: TFmrBackstageTab);
    procedure BuildOpen(const ATab: TFmrBackstageTab);
    procedure BuildSaveAs(const ATab: TFmrBackstageTab);
    procedure BuildPrint(const ATab: TFmrBackstageTab);
    procedure BuildOptions(const ATab: TFmrBackstageTab);
    procedure BuildAbout(const ATab: TFmrBackstageTab);
    procedure BuildStatusBar;
    procedure BuildDocument;
    procedure BuildFindPanel;
  public
    constructor Create(const AForm: TNotesForm);
    procedure Build;
  end;

function Pick(const AValues: array of string; const AIndex: Integer): string;
begin
  Result := AValues[AIndex];
end;

function PickGlyph(const AValues: array of Cardinal; const AIndex: Integer): Cardinal;
begin
  Result := AValues[AIndex];
end;

procedure SetPath(const ASource: TFmrImageSource; const APath: string);
begin
  ASource.PathData := APath;
  ASource.PathViewBox := 24;
end;

procedure PlaceNonVisual(const AComponent: TComponent; const AX, AY: Integer);
begin
  // Position of a non-visual component on the IDE form designer (streamed as Left/Top).
  AComponent.DesignInfo := (AY shl 16) or AX;
end;

{ TBuilder }

constructor TBuilder.Create(const AForm: TNotesForm);
begin
  inherited Create;
  F := AForm;
end;

function TBuilder.NextPos: Single;
begin
  // FMX stacks Top/Left aligned controls by their position: a growing value, larger than any aligned position,
  // keeps the creation order (the .fmx then stores the aligned positions).
  Inc(FOrder);
  Result := FOrder * 1000;
end;

function TBuilder.Btn(const AName, ACaption: string; const AGlyph: Cardinal; const AClick: TNotifyEvent;
  const AStyle: TFmrButtonStyle; const ALarge: Boolean): TFmrButtonItem;
begin
  Result := TFmrButtonItem(M.CreateItem(TFmrButtonItem, AName));
  Result.Caption := ACaption;
  Result.ButtonStyle := AStyle;
  if AGlyph <> 0 then
  begin
    Result.Glyph.GlyphCode := AGlyph;
    if ALarge then
      Result.LargeGlyph.GlyphCode := AGlyph;
  end;
  Result.OnClick := AClick;
end;

function TBuilder.Check(const AName, ACaption: string; const AChecked: Boolean;
  const AClick: TNotifyEvent): TFmrCheckItem;
begin
  Result := TFmrCheckItem(M.CreateItem(TFmrCheckItem, AName));
  Result.Caption := ACaption;
  Result.Checked := AChecked;
  Result.OnClick := AClick;
end;

function TBuilder.Radio(const AParent: TFmrButtonItem; const AName, ACaption: string; const AGroupIndex,
  ATag: Integer; const ADown: Boolean; const AClick: TNotifyEvent): TFmrButtonItem;
begin
  Result := Btn(AName, ACaption, 0, AClick, TFmrButtonStyle.Check);
  Result.GroupIndex := AGroupIndex;
  Result.Tag := ATag;
  Result.Down := ADown;
  if AParent <> nil then
    AParent.DropDownLinks.AddItem(Result);
end;

function TBuilder.Tab(const AName, ACaption, AKeyTip: string): TFmrRibbonTab;
begin
  Result := R.AddTab(ACaption, AName);
  Result.KeyTip := AKeyTip;
end;

function TBuilder.Group(const ATab: TFmrRibbonTab; const AName, ACaption: string): TFmrRibbonGroup;
begin
  Result := ATab.AddGroup(ACaption);
  Result.Name := AName;
end;

function TBuilder.Link(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem; const ALevels: TFmrViewLevels;
  const AButtonGroup: TFmrButtonGroupPosition; const ABeginGroup: Boolean): TFmrItemLink;
begin
  Result := AGroup.ItemLinks.AddItem(AItem, ABeginGroup);
  Result.ViewLevels := ALevels;
  Result.ButtonGroup := AButtonGroup;
end;

procedure TBuilder.Tip(const AItem: TFmrBarItem; const AHeader, ADescription: string);
begin
  AItem.ScreenTip.Header := AHeader;
  AItem.ScreenTip.Description := ADescription;
end;

function TBuilder.BLabel(const AParent: TFmxObject; const AName, AText: string;
  const AStyle: TFmrBackstageTextStyle; const AAlign: TAlignLayout; const ATopMargin: Single): TFmrBackstageLabel;
begin
  Result := TFmrBackstageLabel.Create(F);
  Result.Name := AName;
  Result.TextStyle := AStyle;
  Result.Text := AText;
  Result.Align := AAlign;
  Result.Margins.Top := ATopMargin;
  Result.Position.Y := NextPos;
  Result.Parent := AParent;
end;

function TBuilder.BHeader(const AParent: TFmxObject; const AName, AText: string): TFmrBackstageHeader;
begin
  Result := TFmrBackstageHeader.Create(F);
  Result.Name := AName;
  Result.Text := AText;
  Result.Position.Y := NextPos;
  Result.Parent := AParent;
end;

function TBuilder.BTile(const AParent: TFmxObject; const AName, ACaption, ADescription: string;
  const AGlyph: Cardinal; const ALayout: TFmrBackstageTileLayout; const AAlign: TAlignLayout; const AW, AH: Single;
  const AClick: TNotifyEvent): TFmrBackstageTile;
begin
  Result := TFmrBackstageTile.Create(F);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Description := ADescription;
  if AGlyph <> 0 then
    Result.Glyph.GlyphCode := AGlyph;
  Result.Layout := ALayout;
  Result.Align := AAlign;
  Result.Width := AW;
  Result.Height := AH;
  Result.Position.Y := NextPos;
  Result.Position.X := NextPos;
  Result.OnClick := AClick;
  Result.Parent := AParent;
end;

function TBuilder.Layout(const AParent: TFmxObject; const AName: string; const AAlign: TAlignLayout;
  const ASize: Single): TLayout;
begin
  Result := TLayout.Create(F);
  Result.Name := AName;
  Result.Align := AAlign;
  if AAlign in [TAlignLayout.Left, TAlignLayout.Right] then
    Result.Width := ASize
  else if ASize > 0 then
    Result.Height := ASize;
  Result.Position.Y := NextPos;
  Result.Position.X := NextPos;
  Result.Parent := AParent;
end;

procedure TBuilder.Build;
begin
  F.Name := 'NotesForm';
  F.Caption := 'Note1 - FMR Notes';
  F.ClientWidth := 1280;
  F.ClientHeight := 800;
  F.Position := TFormPosition.ScreenCenter;
  F.OnCreate := F.FormCreate;
  F.OnClose := F.FormClose;
  F.OnDestroy := F.FormDestroy;

  // non-visual components; the frame paints the caption over a Mica backdrop
  F.Frame1 := TFmrFormFrame.Create(F);
  F.Frame1.Name := 'Frame1';
  F.Frame1.Mode := TFmrFrameMode.Dwm;
  F.Frame1.Backdrop := TFmrFrameBackdrop.Mica;
  PlaceNonVisual(F.Frame1, 400, 520);
  BuildImages;
  M := TFmrBarManager.Create(F);
  M.Name := 'BarManager1';
  M.Parent := F;
  M.Images := F.ImageList1;
  M.Categories.CommaText := 'File,Home,Insert,Layout,View,Selection';
  PlaceNonVisual(M, 520, 520);
  F.SelectionTimer := TTimer.Create(F);
  F.SelectionTimer.Name := 'SelectionTimer';
  F.SelectionTimer.Interval := 150;
  F.SelectionTimer.OnTimer := F.SelectionTimerTimer;
  PlaceNonVisual(F.SelectionTimer, 640, 520);
  F.OpenDialog1 := TOpenDialog.Create(F);
  F.OpenDialog1.Name := 'OpenDialog1';
  F.OpenDialog1.Filter := 'Text documents (*.txt;*.md)|*.txt;*.md|All files (*.*)|*.*';
  PlaceNonVisual(F.OpenDialog1, 760, 520);
  F.SaveDialog1 := TSaveDialog.Create(F);
  F.SaveDialog1.Name := 'SaveDialog1';
  F.SaveDialog1.Filter := 'Plain text (*.txt)|*.txt|Markdown (*.md)|*.md';
  F.SaveDialog1.DefaultExt := 'txt';
  PlaceNonVisual(F.SaveDialog1, 880, 520);

  // the ribbon: caption row and tab row go into the frame (non-client area), the body stays on the form
  R := TFmrRibbon.Create(F);
  R.Name := 'Ribbon1';
  R.Parent := F;
  R.BarManager := M;
  R.Frame := F.Frame1;
  R.Theme := 'Modern2024Light';
  R.ShowSearchBox := True;
  R.ApplicationIcon.SvgSource := SvgAppIcon;
  R.OnSearch := F.RibbonSearch;
  R.OnDisplayModeChanged := F.RibbonDisplayModeChanged;
  R.ApplicationButton.ScreenTip.Header := 'File';
  R.ApplicationButton.ScreenTip.Description := 'Open the backstage view: new, open, save, print and options.';

  BuildStatusBar;
  BuildDocument;
  M.BeginUpdate;
  R.BeginStructureUpdate;
  try
    BuildItems;
  finally
    R.EndStructureUpdate;
    M.EndUpdate;
  end;
  BuildPopups;
  BuildBackstage;
  R.ApplicationMenu := BS;
  R.ActiveTab := F.tabHome;
  // the size of the client area as designed (the frame and the ribbon may have changed it meanwhile); a fixed
  // position keeps the generated file the same on every run (Position = ScreenCenter decides at run time)
  F.Left := 100;
  F.Top := 100;
  F.ClientWidth := 1280;
  F.ClientHeight := 800;
end;

procedure TBuilder.BuildImages;
const
  W = 96;
  H = 128;
  Colors: array [0..5] of TAlphaColor = ($FFFFFFFF, $FF2B579A, $FF217346, $FFB7472A, $FF80397B, $FF0072C6);
var
  IL: TImageList;
  I, K: Integer;
  Src: TCustomSourceItem;
  Item: TCustomBitmapItem;
  Dst: TCustomDestinationItem;
  Layer: TLayer;
  C: TCanvas;
begin
  // Miniature pages of the templates (New tab of the backstage view): an image list streamed in the .fmx.
  IL := TImageList.Create(F);
  IL.Name := 'ImageList1';
  PlaceNonVisual(IL, 280, 520);
  for I := 0 to High(NoteTemplates) do
  begin
    Src := IL.Source.Add;
    Src.Name := 'Template' + IntToStr(I);
    Item := Src.MultiResBitmap.ItemByScale(1, True, True);
    if Item = nil then
      Item := Src.MultiResBitmap.Add;
    Item.Scale := 1;
    Item.Bitmap.SetSize(W, H);
    C := Item.Bitmap.Canvas;
    if C.BeginScene then
    try
      C.Clear(TAlphaColors.White);
      C.Stroke.Kind := TBrushKind.Solid;
      C.Stroke.Color := $FFB0B0B0;
      C.Stroke.Thickness := 1;
      C.DrawRect(RectF(0.5, 0.5, W - 0.5, H - 0.5), 0, 0, [], 1);
      C.Fill.Kind := TBrushKind.Solid;
      if I > 0 then
      begin
        C.Fill.Color := Colors[I];
        case I of
          1: C.FillRect(RectF(12, 12, 52, 18), 0, 0, [], 1);
          2: C.FillRect(RectF(1, 1, W - 1, 30), 0, 0, [], 1);
          3: C.FillRect(RectF(1, 1, 22, H - 1), 0, 0, [], 1);
          4: C.FillRect(RectF(12, 12, W - 12, 22), 0, 0, [], 1);
        else
          C.FillRect(RectF(12, 12, 40, 40), 4, 4, AllCorners, 1);
        end;
        C.Fill.Color := $FFC8C8C8;
        for K := 0 to 7 do
          C.FillRect(RectF(IfThen(I = 3, 30, 12), 46 + K * 9, W - 12 - (K mod 3) * 12, 50 + K * 9), 0, 0, [], 1);
      end;
    finally
      C.EndScene;
    end;
    Dst := IL.Destination.Add;
    Layer := Dst.Layers.Add;
    Layer.Name := Src.Name;
    Layer.SourceRect.Rect := RectF(0, 0, W, H);
  end;
end;

procedure TBuilder.BuildItems;
var
  Save, Undo, Redo, B: TFmrButtonItem;
  AutoSave: TFmrCheckItem;
  Account: TFmrAvatarItem;
  Info: TFmrStaticItem;
begin
  { quick access toolbar and file commands: AutoSave (a toggle switch), Save, Undo with its menu, Redo }
  AutoSave := Check('chkAutoSave', 'AutoSave', False, F.AutoSaveClick);
  AutoSave.CheckStyle := TFmrCheckStyle.ToggleSwitch;
  AutoSave.Category := 'File';
  Tip(AutoSave, 'AutoSave', 'Save the document on every change (a Save of the demo when it has a file name).');
  Save := Btn('btnSave', 'Save', FmrGlyphSave, F.SaveClick);
  Save.ShortCut := scCtrl or Ord('S');
  Save.Category := 'File';
  Tip(Save, 'Save (Ctrl+S)', 'Save the document. A new document opens Save As in the backstage view.');
  Undo := Btn('btnUndo', 'Undo', FmrGlyphUndo, F.UndoClick, TFmrButtonStyle.Split);
  Undo.ShortCut := scCtrl or Ord('Z');
  Undo.Category := 'File';
  Undo.DropDownLinks.AddItem(Btn('btnUndoAll', 'Undo All Changes', 0, F.UndoAllClick));
  M.ItemByName('btnUndoAll').Category := 'File';
  Redo := Btn('btnRedo', 'Redo', FmrGlyphRedo, F.RedoClick);
  Redo.ShortCut := scCtrl or Ord('Y');
  Redo.Category := 'File';
  Btn('btnNew', 'New', FmrGlyphCoverPage, F.NewClick).Category := 'File';
  Btn('btnOpen', 'Open', FmrGlyphOpen, F.OpenClick).Category := 'File';
  Btn('btnPrint', 'Print', FmrGlyphPrint, F.PrintClick).Category := 'File';
  M.ItemByName('btnNew').ShortCut := scCtrl or Ord('N');
  M.ItemByName('btnOpen').ShortCut := scCtrl or Ord('O');
  M.ItemByName('btnPrint').ShortCut := scCtrl or Ord('P');
  R.QuickAccessToolbar.AddItem(AutoSave);
  R.QuickAccessToolbar.AddItem(Save);
  R.QuickAccessToolbar.AddItem(Undo);
  R.QuickAccessToolbar.AddItem(Redo);

  { caption row, right end: the account picture with its menu }
  Account := TFmrAvatarItem(M.CreateItem(TFmrAvatarItem, 'btnAccount'));
  Account.Caption := 'Account';
  Account.Initials := 'FN';
  Account.Color := $FFA4262C;
  Account.ButtonStyle := TFmrButtonStyle.DropDown;
  Account.Category := 'File';
  Tip(Account, 'FMR Notes user', 'The account of the document (a demo menu).');
  Info := TFmrStaticItem(M.CreateItem(TFmrStaticItem, 'btnAccountName'));
  Info.Caption := 'FMR Notes user';
  Account.DropDownLinks.AddItem(Info);
  Account.DropDownLinks.AddItem(Btn('btnAccountSwitch', 'Switch account', $E748, F.CommandClick), True);
  R.CaptionToolbar.AddItem(Account);

  { tab row, right end: Comments (hidden) and the accent "Share" button }
  B := Btn('btnComments', 'Comments', FmrGlyphComment, F.CommandClick);
  B.Category := 'File';
  R.TabAreaToolbar.AddItem(B).ViewLevels := [TFmrViewLevel.SmallWithText];
  R.TabAreaToolbar.ItemLinks[0].Visible := False;
  B := Btn('btnShare', 'Share', $E72D, F.CommandClick, TFmrButtonStyle.Split);
  B.Primary := True;
  B.Category := 'File';
  Tip(B, 'Share', 'Invite others to work on the document together.');
  B.DropDownLinks.AddItem(Btn('btnShareLink', 'Copy Link', FmrGlyphLink, F.CommandClick));
  B.DropDownLinks.AddItem(Btn('btnShareCopy', 'Send a Copy', $E724, F.CommandClick));
  R.TabAreaToolbar.AddItem(B).ViewLevels := [TFmrViewLevel.SmallWithText];

  BuildHome;
  BuildInsert;
  BuildLayout;
  BuildView;
  BuildSelectionTools;
end;

procedure TBuilder.BuildHome;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B, ChangeCase, Spacing: TFmrButtonItem;
  FontName: TFmrFontNameItem;
  FontSize: TFmrComboItem;
  FontColor, Highlight: TFmrColorGalleryItem;
  Shading: TFmrColorItem;
  Styles: TFmrRibbonGalleryItem;
  E: TFmrGalleryEntry;
  GG: TFmrGalleryGroup;
  I: Integer;
begin
  // The Home tab: Clipboard, Font and Paragraph in two rows, the Styles gallery, Editing, Add-ins.
  T := Tab('tabHome', 'Home', 'H');

  { Clipboard }
  G := Group(T, 'grpClipboard', 'Clipboard');
  B := Btn('btnPaste', 'Paste', FmrGlyphPaste, F.PasteClick, TFmrButtonStyle.Split, True);
  B.KeyTip := 'V';
  Tip(B, 'Paste (Ctrl+V)', 'Add content from the clipboard to the document.');
  B.ScreenTip.ShowShortcut := False;
  B.DropDownLinks.AddItem(Btn('btnPasteKeep', 'Keep Source Formatting', FmrGlyphPaste, F.PasteClick));
  B.DropDownLinks.AddItem(Btn('btnPasteText', 'Keep Text Only', $E8E9, F.PasteTextClick));
  M.ItemByName('btnPasteKeep').Description := 'Paste the clipboard as it is.';
  M.ItemByName('btnPasteText').Description := 'Paste plain text: line breaks normalized, spaces trimmed.';
  Link(G, B, [TFmrViewLevel.Large]);
  B := Btn('btnCut', 'Cut', FmrGlyphCut, F.CutClick);
  B.KeyTip := 'X';
  Tip(B, 'Cut (Ctrl+X)', 'Remove the selection and put it on the clipboard.');
  Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
  B := Btn('btnCopy', 'Copy', FmrGlyphCopy, F.CopyClick);
  B.KeyTip := 'C';
  Tip(B, 'Copy (Ctrl+C)', 'Put a copy of the selection on the clipboard.');
  Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
  B := Btn('btnFormatPainter', 'Format Painter', FmrGlyphFormatPainter, F.FormatPainterClick,
    TFmrButtonStyle.Check);
  B.KeyTip := 'FP';
  Tip(B, 'Format Painter', 'Copy the formatting of the selection and apply it to other text.');
  Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
  B := Btn('btnSelectAll', 'Select All', FmrGlyphSelect, F.SelectAllClick);
  B.KeyTip := 'SA';
  G.ShowDialogLauncher := True;
  G.DialogLauncherKeyTip := 'FO';
  G.OnDialogLauncherClick := F.ClipboardLauncherClick;

  { Font: the font and its size, sizes and case in the first row; styles, scripts and colors in the second }
  G := Group(T, 'grpFont', 'Font');
  FontName := TFmrFontNameItem(M.CreateItem(TFmrFontNameItem, 'cbFontName'));
  FontName.Caption := 'Font';
  FontName.Text := 'Segoe UI';
  FontName.Width := 112;
  FontName.KeyTip := 'FF';
  FontName.OnChange := F.FontNameChange;
  Tip(FontName, 'Font', 'Pick a new font for the document.');
  Link(G, FontName, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
  FontSize := TFmrComboItem(M.CreateItem(TFmrComboItem, 'cbFontSize'));
  FontSize.Caption := 'Font Size';
  FontSize.Editable := True;
  for I in [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72] do
    FontSize.Items.Add(IntToStr(I));
  FontSize.Text := '12';
  FontSize.Width := 62;
  FontSize.KeyTip := 'FS';
  FontSize.OnChange := F.FontSizeChange;
  Tip(FontSize, 'Font Size', 'Change the size of the text.');
  Link(G, FontSize, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnGrowFont', 'Grow Font', FmrGlyphFontIncrease, F.GrowFontClick);
  B.KeyTip := 'FG';
  Tip(B, 'Increase Font Size', 'Make the text a bit larger.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnShrinkFont', 'Shrink Font', FmrGlyphFontDecrease, F.ShrinkFontClick);
  B.KeyTip := 'FK';
  Tip(B, 'Decrease Font Size', 'Make the text a bit smaller.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  ChangeCase := Btn('btnChangeCase', 'Change Case', FmrGlyphChangeCase, nil, TFmrButtonStyle.DropDown);
  ChangeCase.KeyTip := '7';
  Tip(ChangeCase, 'Change Case', 'Change the selected text to uppercase, lowercase or other capitalizations.');
  for I := 0 to 4 do
  begin
    B := Btn(Pick(['btnCaseSentence', 'btnCaseLower', 'btnCaseUpper', 'btnCaseTitle', 'btnCaseToggle'], I),
      Pick(['Sentence case.', 'lowercase', 'UPPERCASE', 'Capitalize Each Word', 'tOGGLE cASE'], I), 0, F.ChangeCaseClick);
    B.Tag := I;
    B.Category := 'Home';
    ChangeCase.DropDownLinks.AddItem(B);
  end;
  M.ItemByName('btnCaseUpper').Glyph.GlyphCode := FmrGlyphChangeCase;
  M.ItemByName('btnCaseUpper').LargeGlyph.GlyphCode := FmrGlyphChangeCase;
  M.ItemByName('btnCaseLower').Glyph.GlyphCode := $E8D2;
  M.ItemByName('btnCaseLower').LargeGlyph.GlyphCode := $E8D2;
  Link(G, ChangeCase, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnClearFormatting', 'Clear Formatting', FmrGlyphClearFormatting, F.ClearFormattingClick);
  B.KeyTip := 'E';
  Tip(B, 'Clear All Formatting', 'Remove all the formatting: back to the Normal style.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnBold', 'Bold', FmrGlyphBold, F.FontStyleClick, TFmrButtonStyle.Check);
  B.ShortCut := scCtrl or Ord('B');
  B.KeyTip := '1';
  Tip(B, 'Bold (Ctrl+B)', 'Make the text bold.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
  B := Btn('btnItalic', 'Italic', FmrGlyphItalic, F.FontStyleClick, TFmrButtonStyle.Check);
  B.ShortCut := scCtrl or Ord('I');
  B.KeyTip := '2';
  Tip(B, 'Italic (Ctrl+I)', 'Italicize the text.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnUnderline', 'Underline', FmrGlyphUnderline, F.FontStyleClick, TFmrButtonStyle.Check);
  B.ShortCut := scCtrl or Ord('U');
  B.KeyTip := '3';
  Tip(B, 'Underline (Ctrl+U)', 'Underline the text.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnStrike', 'Strikethrough', FmrGlyphStrikethrough, F.FontStyleClick, TFmrButtonStyle.Check);
  B.KeyTip := '4';
  Tip(B, 'Strikethrough', 'Cross something out by drawing a line through it.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnSubscript', 'x₂', 0, F.CommandClick, TFmrButtonStyle.Check);
  B.GroupIndex := 21;
  B.AllowAllUp := True;
  B.KeyTip := '5';
  Tip(B, 'Subscript (Ctrl+=)', 'Type very small letters just below the line of text.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnSuperscript', 'x²', 0, F.CommandClick, TFmrButtonStyle.Check);
  B.GroupIndex := 21;
  B.AllowAllUp := True;
  B.KeyTip := '6';
  Tip(B, 'Superscript (Ctrl+Shift++)', 'Type very small letters just above the line of text.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnTextEffects', 'Text Effects and Typography', FmrGlyphTextEffects, nil, TFmrButtonStyle.DropDown);
  B.KeyTip := 'FT';
  B.DropDownLinks.AddItem(M.ItemByName('btnClearFormatting'));
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  Highlight := TFmrColorGalleryItem(M.CreateItem(TFmrColorGalleryItem, 'clrHighlight'));
  Highlight.Caption := 'Text Highlight Color';
  Highlight.KeyTip := 'I';
  Highlight.Glyph.GlyphCode := FmrGlyphHighlight;
  Highlight.Color := TAlphaColors.Yellow;
  Highlight.OnClick := F.CommandClick;
  Tip(Highlight, 'Text Highlight Color', 'Make the text look like it was marked with a highlighter pen.');
  Link(G, Highlight, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  FontColor := TFmrColorGalleryItem(M.CreateItem(TFmrColorGalleryItem, 'clrFontColor'));
  FontColor.Caption := 'Font Color';
  FontColor.KeyTip := 'FC';
  FontColor.Glyph.GlyphCode := FmrGlyphFontColor;
  FontColor.Color := TAlphaColors.Red;
  FontColor.OnClick := F.FontColorClick;
  FontColor.OnPreview := F.FontColorPreview;
  Tip(FontColor, 'Font Color', 'Change the color of the text. Point at a color to preview it.');
  Link(G, FontColor, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  G.ShowDialogLauncher := True;
  G.DialogLauncherKeyTip := 'FN';
  G.OnDialogLauncherClick := F.FontLauncherClick;

  { Paragraph: lists, indents, sort and marks; alignment, spacing, shading and borders }
  G := Group(T, 'grpParagraph', 'Paragraph');
  B := Btn('btnBullets', 'Bullets', FmrGlyphBullets, F.BulletsClick, TFmrButtonStyle.Split);
  B.KeyTip := 'U';
  Tip(B, 'Bullets', 'Start a bulleted list (or remove the bullets of the selected lines).');
  B.DropDownLinks.AddItem(Btn('btnBulletDot', '•  Bullet', 0, F.BulletsClick));
  B.DropDownLinks.AddItem(Btn('btnBulletDash', '–  Dash', 0, F.BulletsClick));
  M.ItemByName('btnBulletDash').Tag := 1;
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
  B := Btn('btnNumbering', 'Numbering', FmrGlyphNumbering, F.NumberingClick, TFmrButtonStyle.Split);
  B.KeyTip := 'N';
  Tip(B, 'Numbering', 'Start a numbered list (or remove the numbers of the selected lines).');
  B.DropDownLinks.AddItem(Btn('btnNumber1', '1.  2.  3.', 0, F.NumberingClick));
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnMultilevel', 'Multilevel List', FmrGlyphMultilevel, F.CommandClick, TFmrButtonStyle.DropDown);
  B.KeyTip := 'M';
  B.DropDownLinks.AddItem(M.ItemByName('btnBulletDot'));
  B.DropDownLinks.AddItem(M.ItemByName('btnNumber1'));
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnIndentDec', 'Decrease Indent', FmrGlyphIndentDecrease, F.IndentClick);
  B.Tag := -1;
  B.KeyTip := 'AO';
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnIndentInc', 'Increase Indent', FmrGlyphIndentIncrease, F.IndentClick);
  B.Tag := 1;
  B.KeyTip := 'AI';
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  B := Btn('btnSort', 'Sort', FmrGlyphSort, F.SortClick);
  B.KeyTip := 'SO';
  Tip(B, 'Sort', 'Sort the selected lines alphabetically.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnShowMarks', 'Show/Hide', 0, F.CommandClick, TFmrButtonStyle.Check);
  SetPath(B.Glyph, 'M18,4 L18,5.6 L16.4,5.6 L16.4,20 L14.8,20 L14.8,5.6 L12.8,5.6 L12.8,20 L11.2,20 L11.2,12.4 ' +
    'A4.2,4.2 0 0 1 11.2,4 Z');
  B.KeyTip := '8';
  Tip(B, 'Show/Hide ¶ (Ctrl+*)', 'Show paragraph marks and other hidden formatting symbols.');
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  for I := 0 to 3 do
  begin
    B := Btn(Pick(['btnAlignLeft', 'btnAlignCenter', 'btnAlignRight', 'btnJustify'], I),
      Pick(['Align Left', 'Center', 'Align Right', 'Justify'], I),
      PickGlyph([FmrGlyphAlignLeft, FmrGlyphAlignCenter, FmrGlyphAlignRight, FmrGlyphJustify], I), F.AlignClick,
      TFmrButtonStyle.Check);
    B.GroupIndex := 1;
    B.Tag := I;
    B.Down := I = 0;
    B.KeyTip := Pick(['AL', 'AC', 'AR', 'AJ'], I);
    B.ShortCut := scCtrl or Ord(string('LERJ')[I + 1]);
    if I = 0 then
      Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start)
    else
      Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
  end;
  Spacing := Btn('btnLineSpacing', 'Line and Paragraph Spacing', FmrGlyphLineSpacing, nil, TFmrButtonStyle.DropDown);
  Spacing.KeyTip := 'K';
  for I := 0 to 3 do
    Radio(Spacing, Pick(['btnSpacing10', 'btnSpacing115', 'btnSpacing15', 'btnSpacing20'], I),
      Pick(['1.0', '1.15', '1.5', '2.0'], I), 22, I, I = 1, F.CommandClick);
  Link(G, Spacing, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  Shading := TFmrColorItem(M.CreateItem(TFmrColorItem, 'clrShading'));
  Shading.Caption := 'Shading';
  Shading.KeyTip := 'H';
  Shading.Glyph.GlyphCode := FmrGlyphShading;
  Shading.Color := TAlphaColors.Null;
  Shading.AutomaticColor := TAlphaColors.Null;
  Shading.OnClick := F.CommandClick;
  Link(G, Shading, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  B := Btn('btnBorders', 'Borders', FmrGlyphBorders, F.CommandClick, TFmrButtonStyle.Split);
  B.KeyTip := 'B';
  B.DropDownLinks.AddItem(Btn('btnBorderBottom', 'Bottom Border', FmrGlyphBorders, F.CommandClick));
  B.DropDownLinks.AddItem(Btn('btnBorderNone', 'No Border', 0, F.CommandClick));
  Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
  G.ShowDialogLauncher := True;
  G.DialogLauncherKeyTip := 'PG';
  G.OnDialogLauncherClick := F.FontLauncherClick;

  { Styles: white cells with a sample and the name }
  G := Group(T, 'grpStyles', 'Styles');
  G.ReductionPriority := -1;
  Styles := TFmrRibbonGalleryItem(M.CreateItem(TFmrRibbonGalleryItem, 'galStyles'));
  Styles.Caption := 'Styles';
  Styles.KeyTip := 'L';
  SetPath(Styles.Glyph, PathStyle);
  SetPath(Styles.LargeGlyph, PathStyle);
  Styles.ItemWidth := 72;
  Styles.ItemHeight := 56;
  Styles.MinColumns := 2;
  Styles.MaxColumns := 16;
  Styles.DropDownColumns := 6;
  Styles.ShowGroupHeaders := False;
  Tip(Styles, 'Styles', 'Choose a style for the document. Point at a style to preview it.');
  GG := Styles.Groups.Add('Styles');
  for I := 0 to High(NoteStyles) do
  begin
    E := GG.Items.Add(NoteStyles[I].Name);
    E.Tag := I;
  end;
  Styles.SelectedIndex := 0;
  Styles.OnDrawItem := F.StylesDrawItem;
  Styles.OnHotTrack := F.StylesHotTrack;
  Styles.OnItemClick := F.StylesItemClick;
  Styles.DropDownLinks.AddItem(M.ItemByName('btnClearFormatting'));
  Link(G, Styles);
  G.ShowDialogLauncher := True;
  G.DialogLauncherKeyTip := 'FY';
  G.OnDialogLauncherClick := F.FontLauncherClick;

  { Editing }
  G := Group(T, 'grpEditing', 'Editing');
  B := Btn('btnFind', 'Find', FmrGlyphFind, F.FindClick, TFmrButtonStyle.Split);
  B.ShortCut := scCtrl or Ord('F');
  B.KeyTip := 'FD';
  Tip(B, 'Find (Ctrl+F)', 'Find text in the document.');
  B.DropDownLinks.AddItem(Btn('btnAdvancedFind', 'Advanced Find...', FmrGlyphFind, F.FindClick));
  B.DropDownLinks.AddItem(Btn('btnGoTo', 'Go To...', $E8AD, F.CommandClick));
  Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
  B := Btn('btnReplace', 'Replace', FmrGlyphReplace, F.ReplaceClick);
  B.ShortCut := scCtrl or Ord('H');
  B.KeyTip := 'R';
  Tip(B, 'Replace (Ctrl+H)', 'Search for text and replace it.');
  Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
  B := Btn('btnSelect', 'Select', FmrGlyphSelect, nil, TFmrButtonStyle.DropDown);
  B.KeyTip := 'SL';
  B.DropDownLinks.AddItem(M.ItemByName('btnSelectAll'));
  B.DropDownLinks.AddItem(Btn('btnSelectSimilar', 'Select Text with Similar Formatting', 0, F.CommandClick));
  M.ItemByName('btnSelectSimilar').Enabled := False;
  Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);

  { Add-ins }
  G := Group(T, 'grpAddins', 'Add-ins');
  B := Btn('btnAddins', 'Add-ins', 0, F.CommandClick, TFmrButtonStyle.Default, True);
  B.Glyph.SvgSource := SvgAddins;
  B.LargeGlyph.SvgSource := SvgAddins;
  B.KeyTip := 'Y2';
  Tip(B, 'Add-ins', 'Find add-ins and manage them.');
  Link(G, B, [TFmrViewLevel.Large]);
end;

procedure TBuilder.BuildInsert;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B: TFmrButtonItem;
  Table, Symbols: TFmrRibbonGalleryItem;
  Shapes: TFmrGalleryItem;
  GG: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
  I: Integer;

  procedure AddShapes(const ACaption: string; const AFirst, ALast: Integer);
  var
    K: Integer;
  begin
    GG := Shapes.Groups.Add(ACaption);
    for K := AFirst to ALast do
    begin
      E := GG.Items.Add(NoteShapes[K].Name);
      SetPath(E.Glyph, NoteShapes[K].Path);
      E.Tag := K;
    end;
  end;

begin
  T := Tab('tabInsert', 'Insert', 'N');

  { Pages }
  G := Group(T, 'grpPages', 'Pages');
  B := Btn('btnBlankPage', 'Blank Page', FmrGlyphBlankPage, F.InsertTextClick, TFmrButtonStyle.Default, True);
  B.Tag := 1;
  Tip(B, 'Blank Page', 'Insert empty lines at the cursor.');
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B := Btn('btnPageBreak', 'Page Break', FmrGlyphPageBreak, F.InsertTextClick, TFmrButtonStyle.Default, True);
  B.Tag := 0;
  Tip(B, 'Page Break', 'Insert a page break line at the cursor.');
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);

  { Tables: a drop-down gallery of quick tables (owner drawn) }
  G := Group(T, 'grpTables', 'Tables');
  Table := TFmrRibbonGalleryItem(M.CreateItem(TFmrRibbonGalleryItem, 'galTable'));
  Table.Caption := 'Table';
  Table.KeyTip := 'T';
  SetPath(Table.Glyph, PathTable);
  SetPath(Table.LargeGlyph, PathTable);
  Table.ShowInRibbon := False;
  Table.ItemWidth := 84;
  Table.ItemHeight := 70;
  Table.DropDownColumns := 3;
  Table.SelectionMode := TFmrGallerySelectionMode.None;
  Table.DropDownResize := TFmrGalleryResizeMode.None;
  Tip(Table, 'Add a Table', 'Insert a text table: pick its number of columns and rows.');
  GG := Table.Groups.Add('Quick Tables');
  for I := 0 to High(NoteTables) do
  begin
    E := GG.Items.Add(Format('Table %d x %d', [NoteTables[I].X, NoteTables[I].Y]));
    E.Tag := I;
  end;
  Table.OnDrawItem := F.TableDrawItem;
  Table.OnItemClick := F.TableItemClick;
  B := Btn('btnInsertTable', 'Insert Table...', FmrGlyphTable, F.InsertTableClick);
  Table.DropDownLinks.AddItem(B);
  Link(G, Table, [TFmrViewLevel.Large]);

  { Illustrations: a menu with an inline gallery }
  G := Group(T, 'grpIllustrations', 'Illustrations');
  B := Btn('btnShapes', 'Shapes', 0, nil, TFmrButtonStyle.DropDown);
  SetPath(B.Glyph, PathShapes);
  SetPath(B.LargeGlyph, PathShapes);
  B.KeyTip := 'SH';
  Tip(B, 'Shapes', 'Insert a symbol shape (square, circle, arrow, star...) at the cursor.');
  Shapes := TFmrGalleryItem(M.CreateItem(TFmrGalleryItem, 'galShapes'));
  Shapes.Caption := 'Shapes';
  Shapes.ShowInRibbon := False;
  Shapes.ItemWidth := 30;
  Shapes.ItemHeight := 30;
  Shapes.DropDownColumns := 8;
  Shapes.SelectionMode := TFmrGallerySelectionMode.None;
  AddShapes('Basic Shapes', 0, 7);
  AddShapes('Arrows', 8, 12);
  AddShapes('Marks', 13, 14);
  Shapes.OnItemClick := F.ShapesItemClick;
  B.DropDownLinks.AddItem(Shapes);
  B.DropDownLinks.AddItem(Btn('btnHorizontalLine', 'Horizontal Line', $E738, F.InsertTextClick), True);
  M.ItemByName('btnHorizontalLine').Tag := 7;
  Link(G, B, [TFmrViewLevel.Large]);

  { Text }
  G := Group(T, 'grpText', 'Text');
  B := Btn('btnTextBox', 'Text Box', FmrGlyphTextBox, F.InsertTextClick, TFmrButtonStyle.Default, True);
  B.Tag := 4;
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B := Btn('btnDateTime', 'Date && Time', $E787, F.InsertTextClick);
  B.Caption := 'Date && Time';
  B.Tag := 2;
  Link(G, B);
  B := Btn('btnSignature', 'Signature Line', $E70F, F.InsertTextClick);
  B.Tag := 3;
  Link(G, B);
  B := Btn('btnComment', 'Comment', FmrGlyphComment, F.InsertTextClick);
  B.Tag := 6;
  Link(G, B);

  { Links }
  G := Group(T, 'grpLinks', 'Links');
  B := Btn('btnLink', 'Link', FmrGlyphLink, F.InsertTextClick, TFmrButtonStyle.Default, True);
  B.Tag := 5;
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);

  { Symbols: an in-ribbon gallery (owner drawn characters) }
  G := Group(T, 'grpSymbols', 'Symbols');
  Symbols := TFmrRibbonGalleryItem(M.CreateItem(TFmrRibbonGalleryItem, 'galSymbols'));
  Symbols.Caption := 'Symbol';
  Symbols.KeyTip := 'U';
  Symbols.Glyph.GlyphCode := FmrGlyphSymbol;
  Symbols.LargeGlyph.GlyphCode := FmrGlyphSymbol;
  Symbols.ItemWidth := 32;
  Symbols.ItemHeight := 30;
  Symbols.MinColumns := 3;
  Symbols.MaxColumns := 8;
  Symbols.DropDownColumns := 8;
  Symbols.SelectionMode := TFmrGallerySelectionMode.None;
  Symbols.ShowGroupHeaders := False;
  Tip(Symbols, 'Symbol', 'Insert a symbol at the cursor.');
  GG := Symbols.Groups.Add('Symbols');
  for I := 0 to High(NoteSymbols) do
  begin
    E := GG.Items.Add(NoteSymbols[I]);
    E.Tag := I;
  end;
  Symbols.OnDrawItem := F.SymbolDrawItem;
  Symbols.OnItemClick := F.SymbolItemClick;
  Link(G, Symbols);
end;

procedure TBuilder.BuildLayout;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B: TFmrButtonItem;
  PageColor: TFmrColorItem;
  Spin: TFmrSpinItem;
  I: Integer;
begin
  T := Tab('tabLayout', 'Layout', 'P');

  { Page Setup: drop-down menus with radio items }
  G := Group(T, 'grpPageSetup', 'Page Setup');
  B := Btn('btnMargins', 'Margins', FmrGlyphMargins, nil, TFmrButtonStyle.DropDown, True);
  B.KeyTip := 'M';
  Tip(B, 'Adjust Margins', 'Set the margins of the page.');
  for I := 0 to 3 do
    Radio(B, Pick(['btnMarginsNormal', 'btnMarginsNarrow', 'btnMarginsModerate', 'btnMarginsWide'], I),
      Pick(['Normal', 'Narrow', 'Moderate', 'Wide'], I), 10, I, I = 0, F.MarginsClick);
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B := Btn('btnOrientation', 'Orientation', FmrGlyphOrientation, nil, TFmrButtonStyle.DropDown, True);
  B.KeyTip := 'O';
  Radio(B, 'btnPortrait', 'Portrait', 11, 0, True, F.OrientationClick);
  Radio(B, 'btnLandscape', 'Landscape', 11, 1, False, F.OrientationClick);
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B := Btn('btnSize', 'Size', FmrGlyphSize, nil, TFmrButtonStyle.DropDown, True);
  B.KeyTip := 'SZ';
  Radio(B, 'btnSizeLetter', 'Letter (21.59 x 27.94 cm)', 12, 0, False, F.PageSizeClick);
  Radio(B, 'btnSizeA4', 'A4 (21 x 29.7 cm)', 12, 1, True, F.PageSizeClick);
  Radio(B, 'btnSizeA5', 'A5 (14.8 x 21 cm)', 12, 2, False, F.PageSizeClick);
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);

  { Page Background }
  G := Group(T, 'grpPageBackground', 'Page Background');
  B := Btn('btnWatermark', 'Watermark', 0, nil, TFmrButtonStyle.DropDown);
  SetPath(B.Glyph, PathWatermark);
  SetPath(B.LargeGlyph, PathWatermark);
  B.KeyTip := 'W';
  Tip(B, 'Watermark', 'Add ghosted text behind the content of the page.');
  for I := 0 to 3 do
    Radio(B, Pick(['btnWmNone', 'btnWmDraft', 'btnWmConfidential', 'btnWmSample'], I),
      Pick(['No Watermark', 'DRAFT', 'CONFIDENTIAL', 'SAMPLE'], I), 13, I, I = 0, F.WatermarkClick);
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  PageColor := TFmrColorItem(M.CreateItem(TFmrColorItem, 'clrPageColor'));
  PageColor.Caption := 'Page Color';
  PageColor.KeyTip := 'PC';
  SetPath(PageColor.Glyph, PathPalette);
  SetPath(PageColor.LargeGlyph, PathPalette);
  PageColor.AutomaticColor := TAlphaColors.White;
  PageColor.Color := TAlphaColors.Null;
  PageColor.OnClick := F.PageColorClick;
  Tip(PageColor, 'Page Color', 'Change the color of the page.');
  Link(G, PageColor, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B := Btn('btnPageBorders', 'Page Borders', FmrGlyphBorders, F.PageBordersClick, TFmrButtonStyle.Check, True);
  B.KeyTip := 'PB';
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);

  { Paragraph: spin editors }
  G := Group(T, 'grpIndent', 'Paragraph');
  Spin := TFmrSpinItem(M.CreateItem(TFmrSpinItem, 'spIndentLeft'));
  Spin.Caption := 'Indent Left';
  Spin.Min := 0;
  Spin.Max := 240;
  Spin.Increment := 12;
  Spin.Width := 70;
  Spin.KeyTip := 'IL';
  Spin.OnChange := F.IndentSpinChange;
  Link(G, Spin);
  Spin := TFmrSpinItem(M.CreateItem(TFmrSpinItem, 'spIndentRight'));
  Spin.Caption := 'Indent Right';
  Spin.Min := 0;
  Spin.Max := 240;
  Spin.Increment := 12;
  Spin.Width := 70;
  Spin.KeyTip := 'IR';
  Spin.OnChange := F.IndentSpinChange;
  Link(G, Spin);
end;

procedure TBuilder.BuildView;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B, Zoom: TFmrButtonItem;
  Themes, Accent: TFmrRibbonGalleryItem;
  GG: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
  Names: TArray<string>;
  I: Integer;
begin
  T := Tab('tabView', 'View', 'W');

  { Views: radio buttons, mirrored by the view buttons of the status bar }
  G := Group(T, 'grpViews', 'Views');
  for I := 0 to 2 do
  begin
    B := Btn(Pick(['btnReadMode', 'btnPrintLayout', 'btnWebLayout'], I), Pick(['Read Mode', 'Print Layout', 'Web Layout'], I),
      PickGlyph([FmrGlyphReadMode, FmrGlyphPrintLayout, FmrGlyphWebLayout], I), F.ViewModeClick, TFmrButtonStyle.Check, True);
    B.GroupIndex := 3;
    B.Tag := I;
    B.Down := I = 1;
    B.KeyTip := Pick(['F', 'P', 'L'], I);
    Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  end;

  { Show }
  G := Group(T, 'grpShow', 'Show');
  Link(G, Check('chkStatusBar', 'Status Bar', True, F.ShowCheckClick));
  Link(G, Check('chkWordWrap', 'Word Wrap', True, F.ShowCheckClick));
  Link(G, Check('chkFindPane', 'Find Pane', False, F.ShowCheckClick));

  { Zoom }
  G := Group(T, 'grpZoom', 'Zoom');
  Zoom := Btn('btnZoom', 'Zoom', FmrGlyphZoom, nil, TFmrButtonStyle.DropDown, True);
  Zoom.KeyTip := 'Q';
  for I in [50, 75, 125, 150, 200] do
  begin
    B := Btn('btnZoom' + IntToStr(I), IntToStr(I) + '%', 0, F.ZoomClick);
    B.Tag := I;
    Zoom.DropDownLinks.AddItem(B);
  end;
  Link(G, Zoom, [TFmrViewLevel.Large]);
  B := Btn('btnZoom100', '100%', FmrGlyphPercent, F.ZoomClick, TFmrButtonStyle.Default, True);
  B.Tag := 100;
  B.KeyTip := 'J';
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
  B := Btn('btnZoomIn', 'Zoom In', FmrGlyphZoomIn, F.ZoomClick);
  B.Tag := 1;
  Link(G, B);
  B := Btn('btnZoomOut', 'Zoom Out', FmrGlyphZoomOut, F.ZoomClick);
  B.Tag := 2;
  Link(G, B);
  B := Btn('btnPageWidth', 'Page Width', FmrGlyphPageWidth, F.ZoomClick);
  B.Tag := 3;
  Link(G, B);

  { Themes: every registered theme with a preview, and the accent colors }
  G := Group(T, 'grpThemes', 'Themes');
  G.ReductionPriority := -1;
  Themes := TFmrRibbonGalleryItem(M.CreateItem(TFmrRibbonGalleryItem, 'galThemes'));
  Themes.Caption := 'Themes';
  Themes.KeyTip := 'TH';
  SetPath(Themes.Glyph, PathPalette);
  SetPath(Themes.LargeGlyph, PathPalette);
  Themes.ItemWidth := 78;
  Themes.ItemHeight := 60;
  Themes.MinColumns := 2;
  Themes.MaxColumns := 5;
  Themes.DropDownColumns := 4;
  Tip(Themes, 'Themes', 'Switch the theme of the whole window: ribbon, backstage view, status bar and popups.');
  // The demo refills the entries from the theme registry at run time (FillThemeGallery).
  GG := Themes.Groups.Add('Themes');
  Names := TFmrTheme.ThemeNames;
  for I := 0 to High(Names) do
  begin
    E := GG.Items.Add(TFmrTheme.ThemeDisplayName(Names[I]));
    E.Hint := Names[I];
    E.Tag := I;
  end;
  Themes.OnDrawItem := F.ThemeDrawItem;
  Themes.OnItemClick := F.ThemeItemClick;
  Link(G, Themes);
  // The Modern 2024 themes and "use the system setting" (light or dark like the Windows apps).
  B := Btn('btnTheme', 'Theme', $E790, nil, TFmrButtonStyle.DropDown, True);
  B.KeyTip := 'OT';
  Tip(B, 'Theme', 'Modern 2024 Light, Dark Gray or Dark, or the light or dark mode of Windows.');
  for I := 0 to 3 do
    Radio(B, Pick(['btnThemeLight', 'btnThemeDarkGray', 'btnThemeDark', 'btnThemeSystem'], I),
      Pick(['Light', 'Dark Gray', 'Dark', 'Use System Setting'], I), 23, I, I = 3, F.ThemeMenuClick);
  Link(G, B, [TFmrViewLevel.Large]);
  Accent := TFmrRibbonGalleryItem(M.CreateItem(TFmrRibbonGalleryItem, 'galAccent'));
  Accent.Caption := 'Accent';
  Accent.KeyTip := 'AC';
  Accent.Glyph.GlyphCode := $E790;
  Accent.LargeGlyph.GlyphCode := $E790;
  Accent.ShowInRibbon := False;
  Accent.ItemWidth := 150;
  Accent.ItemHeight := 30;
  Accent.DropDownColumns := 1;
  Accent.DropDownResize := TFmrGalleryResizeMode.None;
  Tip(Accent, 'Accent Color', 'The color of Colorful captions, active tabs, the File tab and selections.');
  GG := Accent.Groups.Add('Accent');
  for I := 0 to High(NoteAccents) do
  begin
    E := GG.Items.Add(NoteAccents[I].Name);
    E.Tag := I;
  end;
  Accent.SelectedIndex := 0;
  Accent.OnDrawItem := F.AccentDrawItem;
  Accent.OnItemClick := F.AccentItemClick;
  Link(G, Accent, [TFmrViewLevel.Large]);

  { Ribbon }
  G := Group(T, 'grpRibbon', 'Ribbon');
  Link(G, Check('chkSimplified', 'Simplified Ribbon', False, F.RibbonOptionClick));
  Link(G, Check('chkTouch', 'Touch Mode', False, F.RibbonOptionClick));
  B := Btn('btnLanguage', 'Language', $E774, nil, TFmrButtonStyle.DropDown);
  B.KeyTip := 'LA';
  Tip(B, 'Language', 'Switch the user interface between English and Russian.');
  Radio(B, 'btnLangEn', 'English', 15, 0, True, F.LanguageClick);
  Radio(B, 'btnLangRu', 'Русский', 15, 1, False, F.LanguageClick);
  Link(G, B);
  B := Btn('btnCustomize', 'Customize Ribbon...', $E713, F.CustomizeClick, TFmrButtonStyle.Default, True);
  B.KeyTip := 'CR';
  Tip(B, 'Customize the Ribbon', 'Add, remove, rename and reorder tabs, groups and commands.');
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText], TFmrButtonGroupPosition.None, True);
  B := Btn('btnResetRibbon', 'Reset Ribbon', $E72C, F.ResetRibbonClick, TFmrButtonStyle.Default, True);
  B.KeyTip := 'RR';
  Tip(B, 'Reset the Ribbon', 'Go back to the designed layout (undoes every customization).');
  Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
end;

procedure TBuilder.BuildSelectionTools;
var
  Ctx: TFmrRibbonContextGroup;
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B: TFmrButtonItem;
  Info: TFmrStaticItem;
begin
  // Contextual tab group shown while the document has a selection (FMR Notes polls the memo).
  Ctx := R.AddContextGroup('Selection Tools', TAlphaColor($FFE07B25), 'ctxSelection');
  T := Tab('tabSelection', 'Text', 'JT');
  T.ContextGroup := Ctx;
  G := Group(T, 'grpSelCase', 'Change Case');
  Link(G, M.ItemByName('btnCaseUpper'), [TFmrViewLevel.Large]);
  Link(G, M.ItemByName('btnCaseLower'), [TFmrViewLevel.Large]);
  Link(G, M.ItemByName('btnCaseTitle'), [TFmrViewLevel.SmallWithText]);
  Link(G, M.ItemByName('btnCaseSentence'), [TFmrViewLevel.SmallWithText]);
  Link(G, M.ItemByName('btnCaseToggle'), [TFmrViewLevel.SmallWithText]);
  G := Group(T, 'grpSelEdit', 'Edit');
  M.ItemByName('btnCut').LargeGlyph.GlyphCode := FmrGlyphCut;
  M.ItemByName('btnCopy').LargeGlyph.GlyphCode := FmrGlyphCopy;
  Link(G, M.ItemByName('btnCut'), [TFmrViewLevel.Large]);
  Link(G, M.ItemByName('btnCopy'), [TFmrViewLevel.Large]);
  B := Btn('btnDeleteSel', 'Delete', FmrGlyphDelete, F.DeleteSelClick, TFmrButtonStyle.Default, True);
  B.Category := 'Selection';
  Link(G, B, [TFmrViewLevel.Large]);
  B := Btn('btnQuote', 'Add Quotes', $E9B2, F.QuoteClick, TFmrButtonStyle.Default, True);
  B.Category := 'Selection';
  Link(G, B, [TFmrViewLevel.Large]);
  G := Group(T, 'grpSelInfo', 'Selection');
  Info := TFmrStaticItem(M.CreateItem(TFmrStaticItem, 'stSelInfo'));
  Info.Caption := '0 words, 0 characters';
  Info.Width := 170;
  Link(G, Info);

  // a second tab of the same contextual group
  T := Tab('tabSelLines', 'Lines', 'JL');
  T.ContextGroup := Ctx;
  G := Group(T, 'grpSelLines', 'Lines');
  M.ItemByName('btnSort').LargeGlyph.GlyphCode := FmrGlyphSort;
  Link(G, M.ItemByName('btnSort'), [TFmrViewLevel.Large]);
  B := Btn('btnReverse', 'Reverse Lines', $E8CB, F.ReverseLinesClick, TFmrButtonStyle.Default, True);
  B.Category := 'Selection';
  Link(G, B, [TFmrViewLevel.Large]);
  B := Btn('btnTrim', 'Trim Spaces', $E75C, F.TrimClick, TFmrButtonStyle.Default, True);
  B.Category := 'Selection';
  Link(G, B, [TFmrViewLevel.Large]);
  G := Group(T, 'grpSelLists', 'Lists');
  Link(G, M.ItemByName('btnBullets'));
  Link(G, M.ItemByName('btnNumbering'));
  Link(G, M.ItemByName('btnIndentInc'));
end;

procedure TBuilder.BuildPopups;
var
  Mini: TFmrRibbonMiniToolbar;
  Menu: TFmrPopupMenu;
begin
  // Mini toolbar (selection, right click) and the context menu of the document: links to the same items.
  Menu := TFmrPopupMenu.Create(F);
  Menu.Name := 'ContextMenu1';
  Menu.Parent := F;
  Menu.BarManager := M;
  Menu.ThemeSource := R;
  Menu.ItemLinks.AddItem(M.ItemByName('btnCut'));
  Menu.ItemLinks.AddItem(M.ItemByName('btnCopy'));
  Menu.ItemLinks.AddItem(M.ItemByName('btnPaste'));
  Menu.ItemLinks.AddItem(M.ItemByName('btnPasteText'));
  Menu.ItemLinks.AddItem(M.ItemByName('btnSelectAll'), True);
  Menu.ItemLinks.AddItem(M.ItemByName('btnChangeCase'));
  Menu.ItemLinks.AddItem(M.ItemByName('btnFind'), True);
  PlaceNonVisual(Menu, 1000, 520);
  Mini := TFmrRibbonMiniToolbar.Create(F);
  Mini.Name := 'MiniToolbar1';
  Mini.Parent := F;
  Mini.BarManager := M;
  Mini.ThemeSource := R;
  Mini.PopupMenu := Menu;
  Mini.ItemLinks.AddItem(M.ItemByName('cbFontName'));
  Mini.ItemLinks.AddItem(M.ItemByName('cbFontSize'));
  Mini.ItemLinks.AddItem(M.ItemByName('btnGrowFont'));
  Mini.ItemLinks.AddItem(M.ItemByName('btnShrinkFont'));
  Mini.ItemLinks.AddItem(M.ItemByName('galStyles'), True);
  // a separator item starts the second row
  Mini.ItemLinks.AddItem(M.CreateItem(TFmrSeparatorItem, 'sepMini'));
  Mini.ItemLinks.AddItem(M.ItemByName('btnBold'));
  Mini.ItemLinks.AddItem(M.ItemByName('btnItalic'));
  Mini.ItemLinks.AddItem(M.ItemByName('btnUnderline'));
  Mini.ItemLinks.AddItem(M.ItemByName('clrFontColor'));
  Mini.ItemLinks.AddItem(M.ItemByName('btnBullets'), True);
  Mini.ItemLinks.AddItem(M.ItemByName('btnNumbering'));
  PlaceNonVisual(Mini, 1120, 520);
end;

procedure TBuilder.BuildBackstage;

  function AddTab(const AName, ACaption: string; const AGlyph: Cardinal; const AKeyTip: string): TFmrBackstageTab;
  begin
    Result := TFmrBackstageTab.Create(F);
    Result.Name := AName;
    Result.Caption := ACaption;
    Result.Glyph.GlyphCode := AGlyph;
    Result.KeyTip := AKeyTip;
    Result.Parent := BS;
  end;

  function AddButton(const AName, ACaption: string; const AGlyph: Cardinal; const AClick: TNotifyEvent;
    const AKeyTip: string): TFmrBackstageButton;
  begin
    Result := TFmrBackstageButton.Create(F);
    Result.Name := AName;
    Result.Caption := ACaption;
    Result.Glyph.GlyphCode := AGlyph;
    Result.OnClick := AClick;
    Result.KeyTip := AKeyTip;
    Result.Parent := BS;
  end;

var
  Info, New, Open, SaveAs, Print, About, Options: TFmrBackstageTab;
begin
  BS := TFmrRibbonBackstageView.Create(F);
  BS.Name := 'BackstageView1';
  BS.Parent := F;
  BS.BarManager := M;
  BS.ThemeProvider := R;
  BS.OnShow := F.BackstageShow;
  BS.OnTabChanged := F.BackstageTabChanged;
  // children in navigation order: tabs and command buttons
  Info := AddTab('bsInfo', 'Info', $E946, 'I');
  New := AddTab('bsNew', 'New', $E7C3, 'N');
  Open := AddTab('bsOpen', 'Open', $E838, 'O');
  AddButton('bbSave', 'Save', FmrGlyphSave, F.SaveClick, 'S').BeginGroup := True;
  SaveAs := AddTab('bsSaveAs', 'Save As', FmrGlyphSaveAs, 'A');
  Print := AddTab('bsPrint', 'Print', FmrGlyphPrint, 'P');
  AddButton('bbClose', 'Close', $E711, F.CloseDocClick, 'C').BeginGroup := True;
  About := AddTab('bsAbout', 'About', $E897, 'B');
  About.NavAlign := TFmrBackstageNavAlign.Bottom;
  Options := AddTab('bsOptions', 'Options', $E713, 'T');
  Options.NavAlign := TFmrBackstageNavAlign.Bottom;
  BuildInfo(Info);
  BuildNew(New);
  BuildOpen(Open);
  BuildSaveAs(SaveAs);
  BuildPrint(Print);
  BuildOptions(Options);
  BuildAbout(About);
  BS.ActiveTab := Info;
end;

procedure TBuilder.BuildInfo(const ATab: TFmrBackstageTab);
const
  Rows: array [0..2] of record
    Tile, Caption, Title, Text: string;
    Glyph: Cardinal;
  end = (
    (Tile: 'tileProtect'; Caption: 'Protect Document'; Title: 'Protect Document'; Text: 'lblInfoProtect';
     Glyph: $E72E),
    (Tile: 'tileInspect'; Caption: 'Check for Issues'; Title: 'Inspect Document'; Text: 'lblInfoIssues';
     Glyph: $E721),
    (Tile: 'tileHistory'; Caption: 'Version History'; Title: 'Version History'; Text: 'lblInfoHistory';
     Glyph: $E81C));
var
  Props, Left, Row, Box: TLayout;
  Tile: TFmrBackstageTile;
  I: Integer;
begin
  BHeader(ATab, 'hdrInfo', 'Info');
  BLabel(ATab, 'lblInfoTitle', 'Note1', TFmrBackstageTextStyle.Title);
  BLabel(ATab, 'lblInfoPath', 'This note has not been saved yet', TFmrBackstageTextStyle.Secondary)
    .Margins.Bottom := 16;
  Props := Layout(ATab, 'layInfoProps', TAlignLayout.Right, 260);
  Props.Margins.Left := 24;
  BLabel(Props, 'lblInfoProperties', 'Properties', TFmrBackstageTextStyle.Subtitle);
  BLabel(Props, 'lblInfoWords', 'Words: 0', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 8);
  BLabel(Props, 'lblInfoChars', 'Characters: 0', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  BLabel(Props, 'lblInfoLines', 'Lines: 0', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  BLabel(Props, 'lblInfoPages', 'Pages: 1', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 4);
  BLabel(Props, 'lblInfoRelated', 'Related People', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 20);
  BLabel(Props, 'lblInfoAuthor', 'Author: FMR Notes user', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 8);
  BLabel(Props, 'lblInfoStreamed', 'Everything on this page is streamed from NotesMain.fmx.',
    TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 20);
  Left := Layout(ATab, 'layInfoLeft', TAlignLayout.Client, 0);
  for I := 0 to High(Rows) do
  begin
    Row := Layout(Left, 'layInfoRow' + IntToStr(I), TAlignLayout.Top, 108);
    Row.Margins.Bottom := 12;
    Tile := BTile(Row, Rows[I].Tile, Rows[I].Caption, '', Rows[I].Glyph, TFmrBackstageTileLayout.Vertical,
      TAlignLayout.Left, 104, 104, nil);
    case I of
      0: Tile.OnClick := F.ProtectTileClick;
      1: Tile.OnClick := F.InspectTileClick;
    else
      Tile.OnClick := F.HistoryTileClick;
    end;
    Box := Layout(Row, 'layInfoText' + IntToStr(I), TAlignLayout.Client, 0);
    Box.Margins.Left := 18;
    BLabel(Box, 'lblInfoTitle' + IntToStr(I), Rows[I].Title, TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 6);
    BLabel(Box, Rows[I].Text, '', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 6);
  end;
end;

procedure TBuilder.BuildNew(const ATab: TFmrBackstageTab);
var
  Flow: TFlowLayout;
  Tile: TFmrBackstageTile;
  I: Integer;
begin
  BHeader(ATab, 'hdrNew', 'New');
  BLabel(ATab, 'lblNewHint', 'Start from a template. The page images come from a TImageList stored in the form.',
    TFmrBackstageTextStyle.Secondary).Margins.Bottom := 14;
  Flow := TFlowLayout.Create(F);
  Flow.Name := 'flowTemplates';
  Flow.Align := TAlignLayout.Client;
  Flow.HorizontalGap := 16;
  Flow.VerticalGap := 16;
  Flow.Position.Y := NextPos;
  Flow.Parent := ATab;
  for I := 0 to High(NoteTemplates) do
  begin
    Tile := BTile(Flow, 'tileTemplate' + IntToStr(I), NoteTemplates[I].Name, '', 0,
      TFmrBackstageTileLayout.Vertical, TAlignLayout.None, 136, 168, F.TemplateTileClick);
    Tile.Glyph.ImageIndex := I;
    Tile.GlyphSize := 96;
    Tile.Tag := I;
    Tile.Hint := NoteTemplates[I].Description;
  end;
end;

procedure TBuilder.BuildOpen(const ATab: TFmrBackstageTab);
var
  Left: TLayout;
  Tile: TFmrBackstageTile;
  List: TFmrBackstageGalleryList;
begin
  BHeader(ATab, 'hdrOpen', 'Open');
  Left := Layout(ATab, 'layOpenLeft', TAlignLayout.Left, 250);
  Left.Margins.Right := 24;
  Tile := BTile(Left, 'tileOpenRecent', 'Recent', '', $E823, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top,
    250, 52, nil);
  Tile.Selected := True;
  Tile.ShowFrame := False;
  Tile := BTile(Left, 'tileOpenBrowse', 'Browse', '', $E838, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top,
    250, 52, F.BrowseOpenClick);
  Tile.ShowFrame := False;
  List := TFmrBackstageGalleryList.Create(F);
  List.Name := 'lstRecent';
  List.Align := TAlignLayout.Client;
  List.Position.X := NextPos;
  List.OnItemClick := F.RecentItemClick;
  List.Parent := ATab;
end;

procedure TBuilder.BuildSaveAs(const ATab: TFmrBackstageTab);
var
  Left, Right, Row: TLayout;
  Tile: TFmrBackstageTile;
  Edit: TEdit;
  Combo: TComboBox;
  Button: TButton;
begin
  BHeader(ATab, 'hdrSaveAs', 'Save As');
  Left := Layout(ATab, 'laySaveLeft', TAlignLayout.Left, 260);
  Left.Margins.Right := 28;
  Tile := BTile(Left, 'tileSavePC', 'This PC', 'Documents\FMR Notes', $E7F4, TFmrBackstageTileLayout.Horizontal,
    TAlignLayout.Top, 260, 60, nil);
  Tile.Selected := True;
  Tile.ShowFrame := False;
  Tile := BTile(Left, 'tileSaveBrowse', 'Browse', '', $E838, TFmrBackstageTileLayout.Horizontal, TAlignLayout.Top,
    260, 60, F.BrowseSaveClick);
  Tile.ShowFrame := False;
  Right := Layout(ATab, 'laySaveRight', TAlignLayout.Client, 0);
  BLabel(Right, 'lblSaveTitle', 'Documents', TFmrBackstageTextStyle.Title);
  BLabel(Right, 'lblSaveFolder', '', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 2);
  Edit := TEdit.Create(F);
  Edit.Name := 'edSaveName';
  Edit.Align := TAlignLayout.Top;
  Edit.Margins.Rect := RectF(0, 18, 120, 0);
  Edit.TextPrompt := 'File name';
  Edit.Position.Y := NextPos;
  Edit.Parent := Right;
  Combo := TComboBox.Create(F);
  Combo.Name := 'cbSaveFormat';
  Combo.Align := TAlignLayout.Top;
  Combo.Margins.Rect := RectF(0, 10, 120, 0);
  Combo.Position.Y := NextPos;
  Combo.Parent := Right;
  Row := Layout(Right, 'laySaveButtons', TAlignLayout.Top, 50);
  Button := TButton.Create(F);
  Button.Name := 'btnSaveAsGo';
  Button.Text := 'Save';
  Button.Align := TAlignLayout.Left;
  Button.Width := 110;
  Button.Margins.Rect := RectF(0, 14, 0, 4);
  Button.OnClick := F.SaveAsGoClick;
  Button.Parent := Row;
end;

procedure TBuilder.BuildPrint(const ATab: TFmrBackstageTab);
var
  Left, Top: TLayout;
  Spin: TSpinBox;
  Combo: TComboBox;
  Image: TImage;
begin
  BHeader(ATab, 'hdrPrint', 'Print');
  Left := Layout(ATab, 'layPrintLeft', TAlignLayout.Left, 300);
  Left.Margins.Right := 32;
  Top := Layout(Left, 'layPrintTop', TAlignLayout.Top, 104);
  BTile(Top, 'tilePrint', 'Print', '', FmrGlyphPrint, TFmrBackstageTileLayout.Vertical, TAlignLayout.Left, 96, 96,
    F.PrintTileClick);
  BLabel(Top, 'lblCopies', 'Copies', TFmrBackstageTextStyle.Secondary, TAlignLayout.None).SetBounds(116, 6, 120, 20);
  Spin := TSpinBox.Create(F);
  Spin.Name := 'spCopies';
  Spin.Min := 1;
  Spin.Max := 99;
  Spin.Value := 1;
  Spin.SetBounds(116, 30, 110, 30);
  Spin.Parent := Top;
  BLabel(Left, 'lblPrinterTitle', 'Printer', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 18);
  Combo := TComboBox.Create(F);
  Combo.Name := 'cbPrinter';
  Combo.Align := TAlignLayout.Top;
  Combo.Margins.Top := 8;
  Combo.Position.Y := NextPos;
  Combo.Parent := Left;
  BLabel(Left, 'lblPrintSettings', 'Settings', TFmrBackstageTextStyle.Subtitle, TAlignLayout.Top, 18);
  BLabel(Left, 'lblPrintInfo', '', TFmrBackstageTextStyle.Normal, TAlignLayout.Top, 8);
  BLabel(Left, 'lblPrintNote', 'Printing is simulated in this demo: nothing is sent to a printer.',
    TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 8);
  Image := TImage.Create(F);
  Image.Name := 'imgPreview';
  Image.Align := TAlignLayout.Client;
  Image.WrapMode := TImageWrapMode.Fit;
  Image.HitTest := False;
  Image.Position.X := NextPos;
  Image.Parent := ATab;
end;

procedure TBuilder.BuildOptions(const ATab: TFmrBackstageTab);
var
  Box: TVertScrollBox;
  Row: TLayout;

  procedure ComboRow(const AName, ALabel: string; const AWidth: Single);
  var
    Combo: TComboBox;
    Lbl: TFmrBackstageLabel;
  begin
    Row := Layout(Box, 'layOpt' + AName, TAlignLayout.Top, 38);
    Lbl := BLabel(Row, 'lblOpt' + AName, ALabel, TFmrBackstageTextStyle.Normal, TAlignLayout.Left);
    Lbl.Width := 220;
    Lbl.AutoSize := False;
    Lbl.VertAlign := TTextAlign.Center;
    Combo := TComboBox.Create(F);
    Combo.Name := 'cbOpt' + AName;
    Combo.Align := TAlignLayout.Left;
    Combo.Width := AWidth;
    Combo.Margins.Rect := RectF(0, 5, 0, 5);
    Combo.Position.X := 1000;
    Combo.OnChange := F.OptComboChange;
    Combo.Parent := Row;
  end;

  procedure CheckRow(const AName, AText: string);
  var
    C: TCheckBox;
  begin
    C := TCheckBox.Create(F);
    C.Name := 'chkOpt' + AName;
    C.Text := AText;
    C.Align := TAlignLayout.Top;
    C.Height := 30;
    C.StyledSettings := C.StyledSettings - [TStyledSetting.FontColor];
    C.Position.Y := NextPos;
    C.OnChange := F.OptCheckChange;
    C.Parent := Box;
  end;

var
  Button: TButton;
begin
  BHeader(ATab, 'hdrOptions', 'Options');
  Box := TVertScrollBox.Create(F);
  Box.Name := 'boxOptions';
  Box.Align := TAlignLayout.Client;
  Box.Position.Y := NextPos;
  Box.Parent := ATab;
  BLabel(Box, 'lblOptGeneral', 'General', TFmrBackstageTextStyle.Title);
  ComboRow('Theme', 'Theme', 300);
  ComboRow('Accent', 'Accent color', 300);
  ComboRow('Frame', 'Window frame', 380);
  ComboRow('Backdrop', 'Backdrop (Dwm frame, Windows 11)', 300);
  ComboRow('Language', 'Language', 300);
  BLabel(Box, 'lblOptRibbon', 'Ribbon', TFmrBackstageTextStyle.Title, TAlignLayout.Top, 18);
  CheckRow('Simplified', 'Simplified ribbon (a single line of commands)');
  CheckRow('Touch', 'Touch mode (larger commands)');
  CheckRow('QATBelow', 'Show the Quick Access Toolbar below the ribbon');
  CheckRow('Search', 'Show the search box in the caption row');
  CheckRow('ScreenTips', 'Show screen tips');
  Row := Layout(Box, 'layOptButtons', TAlignLayout.Top, 48);
  Button := TButton.Create(F);
  Button.Name := 'btnOptCustomize';
  Button.Text := 'Customize the Ribbon...';
  Button.Align := TAlignLayout.Left;
  Button.Width := 200;
  Button.Margins.Rect := RectF(0, 10, 12, 4);
  Button.OnClick := F.CustomizeClick;
  Button.Parent := Row;
  Button := TButton.Create(F);
  Button.Name := 'btnOptReset';
  Button.Text := 'Reset customizations';
  Button.Align := TAlignLayout.Left;
  Button.Width := 180;
  Button.Margins.Rect := RectF(0, 10, 0, 4);
  Button.Position.X := 1000;
  Button.OnClick := F.ResetRibbonClick;
  Button.Parent := Row;
  BLabel(Box, 'lblOptNote', 'Theme, accent, frame, language, zoom and the ribbon layout (layout.json) are saved to ' +
    '%APPDATA%\FMRNotes when the window closes.', TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 12);
end;

procedure TBuilder.BuildAbout(const ATab: TFmrBackstageTab);
begin
  BHeader(ATab, 'hdrAbout', 'About');
  BLabel(ATab, 'lblAboutTitle', 'FMR Notes', TFmrBackstageTextStyle.Title);
  BLabel(ATab, 'lblAboutText', 'A notes editor, showcase application of FMR Ribbon, an open-source (MIT) ' +
    'ribbon for Delphi FireMonkey: bar manager with items and links, ribbon with galleries, contextual tabs and the ' +
    'quick access toolbar, window frame with the tab row in the non-client area, backstage view and status bar.',
    TFmrBackstageTextStyle.Normal, TAlignLayout.Top, 10);
  BLabel(ATab, 'lblAboutForm', 'The whole window is loaded from NotesMain.fmx: it was written by ' +
    'Demos\Notes\tools\GenForm and can be opened in the form designer of the IDE.',
    TFmrBackstageTextStyle.Secondary, TAlignLayout.Top, 10);
end;

procedure TBuilder.BuildStatusBar;
var
  SB: TFmrStatusBar;

  function Panel(const AName: string; const AKind: TFmrStatusPanelKind; const AText: string;
    const ASide: TFmrStatusPanelSide = TFmrStatusPanelSide.Left): TFmrStatusBarPanel;
  begin
    Result := SB.AddPanel(AKind, AText, ASide);
    Result.Name := AName;
  end;

begin
  SB := TFmrStatusBar.Create(F);
  SB.Name := 'StatusBar1';
  SB.Parent := F;
  SB.BarManager := M;
  SB.ThemeProvider := R;
  // The status bar: page, words, language, accessibility; display settings, focus, views, zoom.
  Panel('spPage', TFmrStatusPanelKind.Text, 'Page 1 of 1').Hint := 'Page number in the document';
  Panel('spWords', TFmrStatusPanelKind.Text, '0 words').OnClick := F.StatusWordsClick;
  F.spWords.Hint := 'Word count. Click for details.';
  Panel('spChars', TFmrStatusPanelKind.Text, '0 characters').Visible := False;
  Panel('spLanguage', TFmrStatusPanelKind.Text, 'English (United States)').OnClick := F.StatusLanguageClick;
  F.spLanguage.Hint := 'Click to switch the user interface language (English / Russian)';
  Panel('spAccessibility', TFmrStatusPanelKind.Text, 'Accessibility: OK').Glyph.GlyphCode := $E776;
  Panel('spMessage', TFmrStatusPanelKind.Text, '').Stretch := True;
  Panel('spDisplay', TFmrStatusPanelKind.Text, 'Display Settings', TFmrStatusPanelSide.Right).Glyph.GlyphCode :=
    $E7F4;
  Panel('spFocus', TFmrStatusPanelKind.Text, 'Focus', TFmrStatusPanelSide.Right).Glyph.GlyphCode := $E740;
  Panel('spView', TFmrStatusPanelKind.ViewButtons, '', TFmrStatusPanelSide.Right).OnViewChange :=
    F.StatusViewChange;
  Panel('spZoom', TFmrStatusPanelKind.ZoomSlider, '', TFmrStatusPanelSide.Right).OnZoomChange := F.StatusZoomChange;
  F.spZoom.OnZoomClick := F.StatusZoomClick;
end;

procedure TBuilder.BuildFindPanel;
var
  P: TRectangle;
  X: Single;

  function AddLabel(const AName, AText: string; const AWidth: Single): TLabel;
  begin
    Result := TLabel.Create(F);
    Result.Name := AName;
    Result.Text := AText;
    Result.Align := TAlignLayout.Left;
    Result.Width := AWidth;
    Result.Margins.Left := 6;
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor];
    X := X + 1000;
    Result.Position.X := X;
    Result.Parent := P;
  end;

  function AddEdit(const AName, APrompt: string; const AWidth: Single): TEdit;
  begin
    Result := TEdit.Create(F);
    Result.Name := AName;
    Result.TextPrompt := APrompt;
    Result.Align := TAlignLayout.Left;
    Result.Width := AWidth;
    Result.Margins.Rect := RectF(4, 4, 4, 4);
    Result.OnKeyDown := F.FindEditKeyDown;
    X := X + 1000;
    Result.Position.X := X;
    Result.Parent := P;
  end;

  function AddButton(const AName, AText: string; const AWidth: Single; const AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(F);
    Result.Name := AName;
    Result.Text := AText;
    Result.Align := TAlignLayout.Left;
    Result.Width := AWidth;
    Result.Margins.Rect := RectF(2, 4, 2, 4);
    Result.OnClick := AClick;
    X := X + 1000;
    Result.Position.X := X;
    Result.Parent := P;
  end;

begin
  X := 0;
  P := TRectangle.Create(F);
  P.Name := 'FindPanel';
  P.Align := TAlignLayout.Top;
  P.Height := 42;
  P.Sides := [TSide.Bottom];
  P.Fill.Color := $FFF3F3F3;
  P.Stroke.Color := $FFE1E1E1;
  P.Padding.Rect := RectF(8, 3, 8, 3);
  P.Visible := False;
  P.Parent := F.DocArea;
  AddLabel('lblFind', 'Find', 44);
  AddEdit('edFind', 'Search the document', 220);
  AddButton('btnFindPrev', 'Previous', 84, F.FindPrevClick);
  AddButton('btnFindNext', 'Next', 72, F.FindNextClick);
  AddLabel('lblReplace', 'Replace with', 96).Margins.Left := 18;
  AddEdit('edReplace', 'Replacement text', 180);
  AddButton('btnReplaceOne', 'Replace', 80, F.ReplaceOneClick);
  AddButton('btnReplaceAll', 'Replace All', 96, F.ReplaceAllClick);
  AddButton('btnFindClose', '✕', 34, F.FindCloseClick).Align := TAlignLayout.Right;
  AddLabel('lblFindResult', '', 100).Align := TAlignLayout.Client;
  F.lblFindResult.Margins.Left := 14;
end;

procedure TBuilder.BuildDocument;
var
  Area, Page: TRectangle;
  Shadow: TShadowEffect;
  Memo: TMemo;
  Mark: TText;
begin
  Area := TRectangle.Create(F);
  Area.Name := 'DocArea';
  Area.Align := TAlignLayout.Client;
  Area.Fill.Color := $FFE6E6E6;
  Area.Stroke.Kind := TBrushKind.None;
  Area.ClipChildren := True;
  Area.OnResize := F.DocAreaResize;
  Area.Parent := F;
  BuildFindPanel;
  Page := TRectangle.Create(F);
  Page.Name := 'Page';
  Page.Fill.Color := TAlphaColors.White;
  Page.Stroke.Color := $FFD4D4D4;
  Page.SetBounds(232, 20, 794, 700);
  Page.Parent := Area;
  Shadow := TShadowEffect.Create(F);
  Shadow.Name := 'PageShadow';
  Shadow.Distance := 2;
  Shadow.Direction := 90;
  Shadow.Softness := 0.25;
  Shadow.Opacity := 0.3;
  Shadow.Parent := Page;
  Memo := TMemo.Create(F);
  Memo.Name := 'Memo';
  Memo.Align := TAlignLayout.Client;
  Memo.Margins.Rect := RectF(96, 96, 96, 4);
  Memo.StyledSettings := [];
  Memo.TextSettings.Font.Family := 'Segoe UI';
  Memo.TextSettings.Font.Size := 12 * 96 / 72;
  Memo.TextSettings.FontColor := TAlphaColors.Black;
  Memo.WordWrap := True;
  Memo.HideSelectionOnExit := False;
  Memo.ShowScrollBars := True;
  Memo.Lines.Text :=
    'Welcome to FMR Notes' + sLineBreak + sLineBreak +
    'FMR Notes is a small notes editor, a showcase of FMR Ribbon for Delphi FireMonkey. The whole window - the ' +
    'ribbon, the backstage view, the status bar and this page - is loaded from NotesMain.fmx, exactly as if it had ' +
    'been designed in the IDE.' + sLineBreak + sLineBreak +
    'Things to try:' + sLineBreak +
    '• Home: paste, cut and copy; choose a font, a size, Bold, Italic, Underline, a font color or a style - the ' +
    'page follows. Point at a style or a color to preview it.' + sLineBreak +
    '• Select some text: the "Selection Tools" contextual tab appears and the mini toolbar fades in.' + sLineBreak +
    '• Insert: quick tables, shapes, symbols, the date, a text box.' + sLineBreak +
    '• Layout: margins, orientation, page size, watermark, page color and borders.' + sLineBreak +
    '• View: zoom, read mode, web layout, every theme with a preview, accent colors, simplified ribbon, touch ' +
    'mode, English and Russian.' + sLineBreak +
    '• File: the backstage view with note templates, recent notes, Save As, a print preview and the options.' +
    sLineBreak +
    '• Press Alt for key tips, Ctrl+F1 to collapse the ribbon, right-click a command to add it to the Quick ' +
    'Access Toolbar, or customize the whole ribbon (View > Customize Ribbon).';
  Memo.OnChangeTracking := F.MemoChangeTracking;
  Memo.OnKeyDown := F.MemoKeyDown;
  Memo.OnMouseUp := F.MemoMouseUp;
  Memo.OnApplyStyleLookup := F.MemoApplyStyleLookup;
  Memo.Parent := Page;
  Mark := TText.Create(F);
  Mark.Name := 'Watermark';
  Mark.HitTest := False;
  Mark.Text := 'DRAFT';
  Mark.RotationAngle := -32;
  Mark.Opacity := 0.12;
  Mark.TextSettings.Font.Size := 88;
  Mark.TextSettings.Font.Style := [TFontStyle.fsBold];
  Mark.TextSettings.FontColor := $FF404040;
  Mark.SetBounds(0, 260, 794, 160);
  Mark.Visible := False;
  Mark.Parent := Page;
end;

procedure BuildNotesForm(const AForm: TNotesForm);
var
  B: TBuilder;
begin
  B := TBuilder.Create(AForm);
  try
    B.Build;
  finally
    B.Free;
  end;
end;

end.
