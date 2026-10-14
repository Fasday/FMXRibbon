unit RibbonBasicMain;

/// Word-like ribbon built in code (no .fmx): tabs Home, Insert, Layout, View, a contextual group "Table Tools" with
/// Design/Layout tabs (toggled by a check button), split/drop-down/check/radio buttons, editors (font name, font
/// size, edit, spin, track bar), color items, a dialog launcher, the quick access toolbar and the search box.
/// Icons are icon font glyphs (Segoe Fluent Icons / Segoe MDL2 Assets) and vector paths, so no image files are needed.
///
/// Command line (for tools\shot.ps1):
///   /theme=<name>  /frame=fullnc|dwm|ncstrip|none  /minimized  /simplified  /width=N  /height=N  /qatbelow
///   /tabletools (show the contextual tabs)  /keytips (show key tips after start)  /touch  /nosearch  /tab=N
///   /topmost (stay on top while tools\shot.ps1 drives it)  /dump=<file> (write TFmrRibbon.DebugDump)
///   /backstage (the File tab opens a TFmrRibbonBackstageView of FMR.Ribbon.Backstage instead of a menu)
///   /appmenu (the Office 2007 application menu in any theme; Office 2007 themes always get it)
///   /open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial (opens the popup
///   about a second after start, for screenshots)
/// Galleries (FMR.Ribbon.Gallery, FMR.Ribbon.ColorGallery): Home > Styles (in-ribbon, owner drawn, live preview),
/// Home > Font Color / Text Highlight Color, Insert > Cover Page (drop-down gallery with filter and grip), Insert >
/// Shapes (menu with an inline gallery). Right click on the document: mini toolbar + context menu; selecting text
/// with the mouse: the fading mini toolbar. View > Touch > Radial Menu.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Memo, FMX.StdCtrls, FMX.Layouts, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Structure, FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon, FMR.Ribbon.Backstage, FMR.Frame.Types,
  FMR.Frame, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon.Gallery, FMR.Ribbon.ColorGallery,
  FMR.Ribbon.AppMenu, FMR.Ribbon.MiniToolbar, FMR.Ribbon.RadialMenu;

type
  /// The document memo: a right click shows the mini toolbar with the context menu instead of the FMX menu.
  TDemoMemo = class(TMemo)
  private
    FOnContext: TProc<TPointF>;
  public
    function ShowContextMenu(const ScreenPosition: TPointF): Boolean; override;
    property OnContext: TProc<TPointF> read FOnContext write FOnContext;
  end;

  TRibbonBasicForm = class(TForm)
  private
    FFrame: TFmrFormFrame;
    FManager: TFmrBarManager;
    FRibbon: TFmrRibbon;
    FMemo: TMemo;
    FStatus: TLabel;
    FTableTools: TFmrRibbonContextGroup;
    FShowTableTools: TFmrButtonItem;
    FAppMenu: TFmrPopupMenu;
    FBackstage: TFmrRibbonBackstageView;
    FTimer: TTimer;
    FOptKeyTips: Boolean;
    FDumpFile: string;
    FStyles: TFmrRibbonGalleryItem;
    FCover: TFmrRibbonGalleryItem;
    FShapes: TFmrGalleryItem;
    FShapesButton: TFmrButtonItem;
    FFontColor: TFmrColorGalleryItem;
    FHighlight: TFmrColorGalleryItem;
    FAppliedStyle: Integer;
    FAppliedColor: TAlphaColor;
    FOpen: string;
    FAppMenu07: TFmrRibbonApplicationMenu;
    FForceAppMenu: Boolean;
    FMiniToolbar: TFmrRibbonMiniToolbar;
    FContextMenu: TFmrPopupMenu;
    FRadial: TFmrRibbonRadialMenu;
    procedure BuildAppMenu2007;
    procedure BuildMiniToolbar;
    procedure BuildRadialMenu;
    procedure RecentClick(Sender: TObject; const ADocument: TFmrRecentDocument);
    procedure RadialClick(Sender: TObject);
    procedure StyleCommandClick(Sender: TObject);
    procedure MemoMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    function BuildStylesGallery: TFmrRibbonGalleryItem;
    function BuildCoverGallery: TFmrRibbonGalleryItem;
    function BuildShapesGallery: TFmrGalleryItem;
    procedure StylesDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure CoverDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure StylesHotTrack(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure StylesItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure GalleryItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure ShowStyle(const AIndex: Integer);
    procedure FontColorPreview(Sender: TObject; const AColor: TAlphaColor; const AActive: Boolean);
    procedure FontColorClick(Sender: TObject);
    procedure OpenPopup(const AWhat: string);
    procedure DropDownOf(const AItem: TFmrBarItem; const ATab: TFmrRibbonTab);
    function Glyph(const AItem: TFmrBarItem; const ACode: Cardinal): TFmrBarItem;
    function PathGlyph(const AItem: TFmrBarItem; const APath: string): TFmrBarItem;
    function Btn(const AName, ACaption: string; const ACode: Cardinal = 0; const ALarge: Boolean = False;
      const AStyle: TFmrButtonStyle = TFmrButtonStyle.Default): TFmrButtonItem;
    function Group(const ATab: TFmrRibbonTab; const ACaption: string): TFmrRibbonGroup;
    procedure Link(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem; const ALevels: TFmrViewLevels = [];
      const AButtonGroup: TFmrButtonGroupPosition = TFmrButtonGroupPosition.None; const ABeginGroup: Boolean = False);
    procedure BuildItems;
    procedure BuildBackstage;
    procedure BackstageClick(Sender: TObject);
    procedure ApplyCommandLine;
    procedure CommandClick(Sender: TObject);
    procedure TableToolsClick(Sender: TObject);
    procedure LauncherClick(Sender: TObject);
    procedure RibbonSearch(Sender: TObject; const AText: string);
    procedure TabChanged(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure SetStatus(const AText: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  RibbonBasicForm: TRibbonBasicForm;

implementation

uses
  System.IOUtils, System.Math;

const
  PathFormatPainter = 'M4,3 L17,3 L17,8 L4,8 Z M17,5 L20,5 L20,11.5 L11.5,11.5 L11.5,13.5 L10.5,13.5 L10.5,10.5 ' +
    'L19,10.5 L19,6 L17,6 Z M9.5,14 L12.5,14 L12.5,21 L9.5,21 Z';
  PathJustify = 'M3,5 L21,5 L21,6.5 L3,6.5 Z M3,9 L21,9 L21,10.5 L3,10.5 Z M3,13 L21,13 L21,14.5 L3,14.5 Z ' +
    'M3,17 L21,17 L21,18.5 L3,18.5 Z';
  PathNumbering = 'M9,5 L21,5 L21,6.5 L9,6.5 Z M9,11 L21,11 L21,12.5 L9,12.5 Z M9,17 L21,17 L21,18.5 L9,18.5 Z ' +
    'M4,3.5 L5.5,3.5 L5.5,8 L4,8 Z M3,10 L6.5,10 L6.5,12 L4.5,12 L4.5,12.5 L6.5,12.5 L6.5,14 L3,14 L3,11 L5,11 ' +
    'L5,10.8 L3,10.8 Z M3,16 L6.5,16 L6.5,20 L3,20 L3,19 L5,19 L5,18.5 L3.5,18.5 L3.5,17.5 L5,17.5 L5,17 L3,17 Z';
  PathLineSpacing = 'M10,5 L21,5 L21,6.5 L10,6.5 Z M10,11 L21,11 L21,12.5 L10,12.5 Z M10,17 L21,17 L21,18.5 L10,18.5 Z ' +
    'M5,3 L8,7 L6,7 L6,17 L8,17 L5,21 L2,17 L4,17 L4,7 L2,7 Z';
  PathShapes = 'M3,12 L11,12 L11,20 L3,20 Z M17,3 L22,12 L12,12 Z M14,15 L21,15 L21,21 L14,21 Z';
  PathTable = 'M3,4 L8,4 L8,8 L3,8 Z M9.5,4 L14.5,4 L14.5,8 L9.5,8 Z M16,4 L21,4 L21,8 L16,8 Z ' +
    'M3,10 L8,10 L8,14 L3,14 Z M9.5,10 L14.5,10 L14.5,14 L9.5,14 Z M16,10 L21,10 L21,14 L16,14 Z ' +
    'M3,16 L8,16 L8,20 L3,20 Z M9.5,16 L14.5,16 L14.5,20 L9.5,20 Z M16,16 L21,16 L21,20 L16,20 Z';
  PathChart = 'M4,14 L7,14 L7,20 L4,20 Z M10,9 L13,9 L13,20 L10,20 Z M16,4 L19,4 L19,20 L16,20 Z M2,21 L22,21 ' +
    'L22,22 L2,22 Z';
  PathMargins = 'M5,2 L19,2 L19,22 L5,22 Z M7,4 L7,20 L17,20 L17,4 Z M8,6 L16,6 L16,7 L8,7 Z M8,9 L16,9 L16,10 ' +
    'L8,10 Z M8,12 L16,12 L16,13 L8,13 Z';
  PathColumns = 'M3,4 L10.5,4 L10.5,5.5 L3,5.5 Z M13.5,4 L21,4 L21,5.5 L13.5,5.5 Z M3,8 L10.5,8 L10.5,9.5 L3,9.5 Z ' +
    'M13.5,8 L21,8 L21,9.5 L13.5,9.5 Z M3,12 L10.5,12 L10.5,13.5 L3,13.5 Z M13.5,12 L21,12 L21,13.5 L13.5,13.5 Z ' +
    'M3,16 L10.5,16 L10.5,17.5 L3,17.5 Z M13.5,16 L21,16 L21,17.5 L13.5,17.5 Z';
  PathStyle = 'M3,19 L8,5 L10,5 L15,19 L12.8,19 L11.6,15.5 L6.4,15.5 L5.2,19 Z M7.1,13.5 L10.9,13.5 L9,8 Z ' +
    'M16,13 L21,13 L21,14.5 L16,14.5 Z M16,17 L21,17 L21,18.5 L16,18.5 Z';
  PathRows = 'M3,3 L21,3 L21,9 L3,9 Z M3,11 L21,11 L21,13 L3,13 Z M3,15 L21,15 L21,21 L3,21 Z';

{ TRibbonBasicForm }

constructor TRibbonBasicForm.Create(AOwner: TComponent);
var
  Mode: string;
  I: Integer;
  S: string;
begin
  inherited CreateNew(AOwner);
  Caption := 'Document1 - FMR Ribbon';
  Width := 1180;
  Height := 640;
  Position := TFormPosition.ScreenCenter;
  Mode := 'fullnc';
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I).ToLower;
    if S.StartsWith('/frame=') then
      Mode := S.Substring(7);
  end;
  // The frame must exist before the form is shown; the ribbon moves its caption row and tab row into its host.
  if Mode <> 'none' then
  begin
    FFrame := TFmrFormFrame.Create(Self);
    if Mode = 'dwm' then
      FFrame.Mode := TFmrFrameMode.Dwm
    else if Mode = 'ncstrip' then
      FFrame.Mode := TFmrFrameMode.NCStrip
    else
      FFrame.Mode := TFmrFrameMode.FullNC;
  end;

  FManager := TFmrBarManager.Create(Self);
  FManager.Parent := Self;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := TAlignLayout.Bottom;
  FStatus.Height := 22;
  FStatus.Margins.Left := 8;
  FStatus.Text := 'Ready';

  FRibbon := TFmrRibbon.Create(Self);
  FRibbon.Parent := Self;
  FRibbon.BarManager := FManager;
  FRibbon.ShowSearchBox := True;
  FRibbon.OnSearch := RibbonSearch;
  FRibbon.OnTabChanged := TabChanged;
  if FFrame <> nil then
    FRibbon.Frame := FFrame;

  FMemo := TDemoMemo.Create(Self);
  TDemoMemo(FMemo).OnContext :=
    procedure(AScreenPoint: TPointF)
    begin
      // Right click: the context menu with the mini toolbar above it (Office).
      FMiniToolbar.Popup(AScreenPoint, True);
    end;
  FMemo.OnMouseUp := MemoMouseUp;
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.Margins.Rect := RectF(24, 12, 24, 4);
  FMemo.Lines.Text := 'FMR Ribbon for FireMonkey' + sLineBreak + sLineBreak +
    'This document area is an ordinary TMemo. The ribbon above it is one TFmrRibbon control: the caption row and ' +
    'the tab row live in the window frame (non-client area in the FullNC mode), the groups are laid out by the ' +
    'layout calculator and every button is a lightweight view painted by the theme painter.' + sLineBreak +
    sLineBreak + 'Press Alt for key tips, Ctrl+F1 to collapse the ribbon, right-click a command to add it to the ' +
    'quick access toolbar.';
  // The styles gallery and the font color gallery format the memo (live preview while hovering).
  FMemo.StyledSettings := FMemo.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size, TStyledSetting.Style,
    TStyledSetting.FontColor];
  FAppliedColor := TAlphaColors.Black;
  FMemo.TextSettings.FontColor := FAppliedColor;

  BuildItems;
  BuildAppMenu2007;
  BuildMiniToolbar;
  BuildRadialMenu;
  ApplyCommandLine;
  // Office 2007 themes get the Office 2007 application menu (the backstage view stays when /backstage is given).
  if (FBackstage = nil) and (FForceAppMenu or (FRibbon.Painter.Theme.Style.Family = TFmrThemeFamily.Office2007)) then
    FRibbon.ApplicationMenu := FAppMenu07;
  ShowStyle(0);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 900;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := FOptKeyTips or (FDumpFile <> '') or (FOpen <> '');
end;

function TRibbonBasicForm.Glyph(const AItem: TFmrBarItem; const ACode: Cardinal): TFmrBarItem;
begin
  AItem.Glyph.GlyphCode := ACode;
  Result := AItem;
end;

function TRibbonBasicForm.PathGlyph(const AItem: TFmrBarItem; const APath: string): TFmrBarItem;
begin
  AItem.Glyph.PathData := APath;
  AItem.Glyph.PathViewBox := 24;
  Result := AItem;
end;

function TRibbonBasicForm.Btn(const AName, ACaption: string; const ACode: Cardinal; const ALarge: Boolean;
  const AStyle: TFmrButtonStyle): TFmrButtonItem;
begin
  Result := TFmrButtonItem(FManager.CreateItem(TFmrButtonItem, AName));
  Result.Caption := ACaption;
  Result.ButtonStyle := AStyle;
  if ACode <> 0 then
  begin
    Result.Glyph.GlyphCode := ACode;
    if ALarge then
      Result.LargeGlyph.GlyphCode := ACode;
  end;
  Result.OnClick := CommandClick;
end;

function TRibbonBasicForm.Group(const ATab: TFmrRibbonTab; const ACaption: string): TFmrRibbonGroup;
begin
  Result := ATab.AddGroup(ACaption);
end;

procedure TRibbonBasicForm.Link(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem;
  const ALevels: TFmrViewLevels; const AButtonGroup: TFmrButtonGroupPosition; const ABeginGroup: Boolean);
var
  L: TFmrItemLink;
begin
  L := AGroup.ItemLinks.AddItem(AItem, ABeginGroup);
  L.ViewLevels := ALevels;
  L.ButtonGroup := AButtonGroup;
end;

procedure TRibbonBasicForm.BuildItems;
var
  Home, Insert, LayoutTab, View, TDesign, TLayout: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  Paste, Find, Select, Bullets, Numbering, Spacing, Bold, Italic, Underline, Strike: TFmrButtonItem;
  AL, AC, AR, AJ: TFmrButtonItem;
  Sub: TFmrButtonItem;
  FontName: TFmrFontNameItem;
  FontSize: TFmrComboItem;
  FontColor, Highlight, Shading: TFmrColorItem;
  Edit: TFmrEditItem;
  Spin, IndentL, IndentR, SpaceB, SpaceA: TFmrSpinItem;
  Track: TFmrTrackBarItem;
  Check: TFmrCheckItem;
  Save, Undo, Redo, Print: TFmrButtonItem;
  I: Integer;
  B: TFmrButtonItem;
  Item: TFmrBarItem;
  S: string;
begin
  FManager.BeginUpdate;
  FRibbon.BeginStructureUpdate;
  try
    { quick access toolbar }
    Save := Btn('btnSave', 'Save', $E74E);
    Save.ShortCut := scCtrl or Ord('S');
    Undo := Btn('btnUndo', 'Undo', $E7A7);
    Undo.ShortCut := scCtrl or Ord('Z');
    Redo := Btn('btnRedo', 'Redo', $E7A6);
    Redo.ShortCut := scCtrl or Ord('Y');
    Print := Btn('btnPrint', 'Print', $E749);
    Print.ShortCut := scCtrl or Ord('P');
    FRibbon.QuickAccessToolbar.AddItem(Save);
    FRibbon.QuickAccessToolbar.AddItem(Undo);
    FRibbon.QuickAccessToolbar.AddItem(Redo);

    { application menu (the backstage view comes later) }
    FAppMenu := TFmrPopupMenu.Create(Self);
    FAppMenu.Parent := Self;
    FAppMenu.BarManager := FManager;
    FAppMenu.ItemLinks.AddItem(Btn('btnNew', 'New', $E8A5));
    FAppMenu.ItemLinks.AddItem(Btn('btnOpen', 'Open...', $E8E5));
    FAppMenu.ItemLinks.AddItem(Save);
    FAppMenu.ItemLinks.AddItem(Btn('btnSaveAs', 'Save As...', 0));
    FAppMenu.ItemLinks.AddItem(Print, True);
    FAppMenu.ItemLinks.AddItem(Btn('btnExit', 'Exit', $E8BB), True);
    FRibbon.ApplicationMenu := FAppMenu;

    { Home }
    Home := FRibbon.AddTab('Home', 'tabHome');
    G := Group(Home, 'Clipboard');
    Paste := Btn('btnPaste', 'Paste', $E77F, True, TFmrButtonStyle.Split);
    Paste.ShortCut := scCtrl or Ord('V');
    Paste.ScreenTip.Header := 'Paste (Ctrl+V)';
    Paste.ScreenTip.Description := 'Add content from the Clipboard to your document.';
    Paste.ScreenTip.ShowShortcut := False;
    Paste.ScreenTip.ShowFooter := True;
    Sub := Btn('btnPasteKeep', 'Keep Source Formatting', $E77F);
    Sub.LargeGlyph.GlyphCode := $E77F;
    Sub.Description := 'Paste the content with the formatting of its source.';
    Paste.DropDownLinks.AddItem(Sub);
    Sub := Btn('btnPasteMerge', 'Merge Formatting', $E8D2);
    Sub.LargeGlyph.GlyphCode := $E8D2;
    Sub.Description := 'Paste and use the formatting of the surrounding text.';
    Paste.DropDownLinks.AddItem(Sub);
    Sub := Btn('btnPasteText', 'Keep Text Only', $E8E9);
    Sub.LargeGlyph.GlyphCode := $E8E9;
    Sub.Description := 'Paste the text without any formatting, pictures or tables.';
    Paste.DropDownLinks.AddItem(Sub);
    Sub := Btn('btnPasteSpecial', 'Paste Special...', 0);
    Sub.Description := 'Choose the format of the pasted content.';
    Paste.DropDownLinks.AddItem(Sub, True);
    Link(G, Paste, [TFmrViewLevel.Large]);
    B := Btn('btnCut', 'Cut', $E8C6);
    B.ShortCut := scCtrl or Ord('X');
    B.Hint := 'Remove the selection and put it on the Clipboard.';
    Link(G, B);
    B := Btn('btnCopy', 'Copy', $E8C8);
    B.ShortCut := scCtrl or Ord('C');
    B.Hint := 'Put a copy of the selection on the Clipboard.';
    Link(G, B);
    B := TFmrButtonItem(PathGlyph(Btn('btnFormatPainter', 'Format Painter'), PathFormatPainter));
    B.ButtonStyle := TFmrButtonStyle.Check;
    Link(G, B);
    G.ShowDialogLauncher := True;
    G.OnDialogLauncherClick := LauncherClick;

    G := Group(Home, 'Font');
    FontName := TFmrFontNameItem(FManager.CreateItem(TFmrFontNameItem, 'cbFontName'));
    FontName.Caption := 'Font';
    FontName.Text := 'Calibri';
    FontName.Width := 130;
    Link(G, FontName, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    FontSize := TFmrComboItem(FManager.CreateItem(TFmrComboItem, 'cbFontSize'));
    FontSize.Caption := 'Font Size';
    FontSize.Editable := True;
    for I in [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72] do
      FontSize.Items.Add(IntToStr(I));
    FontSize.Text := '11';
    FontSize.Width := 52;
    Link(G, FontSize, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
    Bold := Btn('btnBold', 'Bold', $E8DD, False, TFmrButtonStyle.Check);
    Bold.ShortCut := scCtrl or Ord('B');
    Bold.Hint := 'Make the text bold.';
    Italic := Btn('btnItalic', 'Italic', $E8DB, False, TFmrButtonStyle.Check);
    Italic.ShortCut := scCtrl or Ord('I');
    Underline := Btn('btnUnderline', 'Underline', $E8DC, False, TFmrButtonStyle.Check);
    Underline.ShortCut := scCtrl or Ord('U');
    Strike := Btn('btnStrike', 'Strikethrough', $EDE0, False, TFmrButtonStyle.Check);
    Link(G, Bold, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    Link(G, Italic, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, Underline, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, Strike, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    // Color galleries (FMR.Ribbon.ColorGallery): the arrow opens the gallery, the main part applies the last color.
    FFontColor := TFmrColorGalleryItem(FManager.CreateItem(TFmrColorGalleryItem, 'clrFont'));
    FontColor := FFontColor;
    FontColor.Caption := 'Font Color';
    FontColor.KeyTip := 'FC';
    FontColor.Glyph.GlyphCode := $E8D3;
    FontColor.Color := TAlphaColors.Red;
    FontColor.ScreenTip.Description := 'Change the color of your text.';
    FontColor.OnClick := FontColorClick;
    FFontColor.OnPreview := FontColorPreview;
    FHighlight := TFmrColorGalleryItem(FManager.CreateItem(TFmrColorGalleryItem, 'clrHighlight'));
    Highlight := FHighlight;
    Highlight.Caption := 'Text Highlight Color';
    Highlight.KeyTip := 'I';
    Highlight.Glyph.GlyphCode := $E7E6;
    Highlight.Color := TAlphaColors.Yellow;
    FHighlight.Palette := TFmrColorPalette.Highlight;
    Highlight.ShowMoreColors := False;
    Highlight.OnClick := CommandClick;
    Link(G, Highlight, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
    Link(G, FontColor, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    G.ShowDialogLauncher := True;
    G.OnDialogLauncherClick := LauncherClick;

    G := Group(Home, 'Paragraph');
    Bullets := TFmrButtonItem(Glyph(Btn('btnBullets', 'Bullets', 0, False, TFmrButtonStyle.Split), $E8FD));
    for I := 1 to 3 do
      Bullets.DropDownLinks.AddItem(Btn('btnBullet' + IntToStr(I), 'Bullet Style ' + IntToStr(I), $E8FD));
    Numbering := TFmrButtonItem(PathGlyph(Btn('btnNumbering', 'Numbering', 0, False, TFmrButtonStyle.Split),
      PathNumbering));
    Numbering.DropDownLinks.AddItem(Btn('btnNum1', '1. 2. 3.', 0));
    Numbering.DropDownLinks.AddItem(Btn('btnNum2', 'a) b) c)', 0));
    Spacing := TFmrButtonItem(PathGlyph(Btn('btnSpacing', 'Line Spacing', 0, False, TFmrButtonStyle.DropDown),
      PathLineSpacing));
    for S in ['1.0', '1.15', '1.5', '2.0', '2.5', '3.0'] do
      Spacing.DropDownLinks.AddItem(Btn('', S, 0, False, TFmrButtonStyle.Check));
    Link(G, Bullets, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    Link(G, Numbering, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    AL := Btn('btnAlignLeft', 'Align Left', $E8E4, False, TFmrButtonStyle.Check);
    AL.GroupIndex := 1;
    AL.Down := True;
    AL.ShortCut := scCtrl or Ord('L');
    AC := Btn('btnAlignCenter', 'Center', $E8E3, False, TFmrButtonStyle.Check);
    AC.GroupIndex := 1;
    AC.ShortCut := scCtrl or Ord('E');
    AR := Btn('btnAlignRight', 'Align Right', $E8E2, False, TFmrButtonStyle.Check);
    AR.GroupIndex := 1;
    AR.ShortCut := scCtrl or Ord('R');
    AJ := TFmrButtonItem(PathGlyph(Btn('btnJustify', 'Justify', 0, False, TFmrButtonStyle.Check), PathJustify));
    AJ.GroupIndex := 1;
    AJ.ShortCut := scCtrl or Ord('J');
    Link(G, AL, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    Link(G, AC, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, AR, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, AJ, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, Spacing, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
    Shading := TFmrColorItem(FManager.CreateItem(TFmrColorItem, 'clrShading'));
    Shading.Caption := 'Shading';
    Shading.Glyph.GlyphCode := $E790;
    Shading.ShowNoColor := True;
    Shading.OnClick := CommandClick;
    Link(G, Shading, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    B := Btn('btnShowMarks', 'Show/Hide', $E8C1, False, TFmrButtonStyle.Check);
    Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    G.ShowDialogLauncher := True;
    G.OnDialogLauncherClick := LauncherClick;

    G := Group(Home, 'Styles');
    G.ReductionPriority := -1;
    // In-ribbon gallery (FMR.Ribbon.Gallery) with owner-drawn text samples and live preview on the document.
    FStyles := BuildStylesGallery;
    Link(G, FStyles);
    G.ShowDialogLauncher := True;
    G.OnDialogLauncherClick := LauncherClick;

    G := Group(Home, 'Editing');
    Find := Btn('btnFind', 'Find', $E721, False, TFmrButtonStyle.Split);
    Find.ShortCut := scCtrl or Ord('F');
    Find.DropDownLinks.AddItem(Btn('btnFindAdv', 'Advanced Find...', $E721));
    Find.DropDownLinks.AddItem(Btn('btnGoTo', 'Go To...', 0));
    Link(G, Find, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
    B := Btn('btnReplace', 'Replace', $E8AB);
    B.ShortCut := scCtrl or Ord('H');
    Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
    Select := Btn('btnSelect', 'Select', $E8B3, False, TFmrButtonStyle.DropDown);
    Select.DropDownLinks.AddItem(Btn('btnSelectAll', 'Select All', $E8B3));
    Select.DropDownLinks.AddItem(Btn('btnSelectObjects', 'Select Objects', 0));
    Link(G, Select, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
    Edit := TFmrEditItem(FManager.CreateItem(TFmrEditItem, 'edGoTo'));
    Edit.Caption := 'Go to';
    Edit.TextPrompt := 'page';
    Edit.Width := 70;
    Link(G, Edit, [], TFmrButtonGroupPosition.None, True);
    Spin := TFmrSpinItem(FManager.CreateItem(TFmrSpinItem, 'spCopies'));
    Spin.Caption := 'Copies';
    Spin.Min := 1;
    Spin.Max := 99;
    Spin.Value := 1;
    Spin.Width := 70;
    Link(G, Spin);

    { Insert }
    Insert := FRibbon.AddTab('Insert', 'tabInsert');
    G := Group(Insert, 'Pages');
    // A drop-down gallery shown by a large button: group filter, owner-drawn pages, commands, resize grip.
    FCover := BuildCoverGallery;
    Link(G, FCover, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnBlankPage', 'Blank Page', $E7C3, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnPageBreak', 'Page Break', $E7C3, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    G := Group(Insert, 'Tables');
    B := TFmrButtonItem(PathGlyph(Btn('btnTable', 'Table', 0, False, TFmrButtonStyle.DropDown), PathTable));
    B.LargeGlyph.PathData := PathTable;
    B.LargeGlyph.PathViewBox := 24;
    B.DropDownLinks.AddItem(Btn('btnInsertTable', 'Insert Table...', 0));
    B.DropDownLinks.AddItem(Btn('btnDrawTable', 'Draw Table', $E70F));
    Link(G, B, [TFmrViewLevel.Large]);
    FShowTableTools := Btn('btnTableTools', 'Table Tools', 0, False, TFmrButtonStyle.Check);
    FShowTableTools.Glyph.PathData := PathTable;
    FShowTableTools.Glyph.PathViewBox := 24;
    FShowTableTools.LargeGlyph.PathData := PathTable;
    FShowTableTools.LargeGlyph.PathViewBox := 24;
    FShowTableTools.Hint := 'Show the contextual Table Tools tabs.';
    FShowTableTools.OnClick := TableToolsClick;
    Link(G, FShowTableTools, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    G := Group(Insert, 'Illustrations');
    Link(G, Btn('btnPictures', 'Pictures', $E8B9, True), [TFmrViewLevel.Large]);
    // A drop-down menu whose links contain a gallery: the gallery is shown inline, the commands below it.
    B := TFmrButtonItem(PathGlyph(Btn('btnShapes', 'Shapes', 0, False, TFmrButtonStyle.DropDown), PathShapes));
    B.KeyTip := 'SH';
    FShapesButton := B;
    FShapes := BuildShapesGallery;
    B.DropDownLinks.AddItem(FShapes);
    B.DropDownLinks.AddItem(Btn('btnDrawingCanvas', 'New Drawing Canvas', $E70F), True);
    Link(G, B);
    Link(G, Btn('btnIcons', 'Icons', $E76E));
    Link(G, PathGlyph(Btn('btnChart', 'Chart'), PathChart));
    G := Group(Insert, 'Links');
    Link(G, Btn('btnLink', 'Link', $E71B, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnBookmark', 'Bookmark', $E8A4, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnComment', 'Comment', $E90A, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    G := Group(Insert, 'Header && Footer');
    for S in ['Header', 'Footer', 'Page Number'] do
    begin
      B := Btn('', S, $E7C3, True, TFmrButtonStyle.DropDown);
      B.DropDownLinks.AddItem(Btn('', 'Blank', 0));
      B.DropDownLinks.AddItem(Btn('', 'Remove ' + S, 0));
      Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    end;
    G := Group(Insert, 'Text');
    Link(G, Btn('btnTextBox', 'Text Box', $E8D2, True), [TFmrViewLevel.Large]);
    Link(G, Btn('btnWordArt', 'WordArt', $E8D2));
    Link(G, Btn('btnDropCap', 'Drop Cap', $E8D2));
    Link(G, Btn('btnSignature', 'Signature Line', $E70F));

    { Layout }
    LayoutTab := FRibbon.AddTab('Layout', 'tabLayout');
    G := Group(LayoutTab, 'Page Setup');
    B := TFmrButtonItem(PathGlyph(Btn('btnMargins', 'Margins', 0, False, TFmrButtonStyle.DropDown), PathMargins));
    B.LargeGlyph.PathData := PathMargins;
    B.LargeGlyph.PathViewBox := 24;
    B.DropDownLinks.AddItem(Btn('', 'Normal', 0));
    B.DropDownLinks.AddItem(Btn('', 'Narrow', 0));
    B.DropDownLinks.AddItem(Btn('', 'Wide', 0));
    Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    B := Btn('btnOrientation', 'Orientation', $E7AD, True, TFmrButtonStyle.DropDown);
    B.DropDownLinks.AddItem(Btn('', 'Portrait', 0, False, TFmrButtonStyle.Check));
    B.DropDownLinks.AddItem(Btn('', 'Landscape', 0, False, TFmrButtonStyle.Check));
    Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    B := Btn('btnSize', 'Size', $E740, True, TFmrButtonStyle.DropDown);
    B.DropDownLinks.AddItem(Btn('', 'Letter', 0));
    B.DropDownLinks.AddItem(Btn('', 'A4', 0));
    Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    B := TFmrButtonItem(PathGlyph(Btn('btnColumns', 'Columns', 0, False, TFmrButtonStyle.DropDown), PathColumns));
    B.LargeGlyph.PathData := PathColumns;
    B.LargeGlyph.PathViewBox := 24;
    B.DropDownLinks.AddItem(Btn('', 'One', 0));
    B.DropDownLinks.AddItem(Btn('', 'Two', 0));
    Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    G.ShowDialogLauncher := True;
    G.OnDialogLauncherClick := LauncherClick;
    G := Group(LayoutTab, 'Paragraph');
    IndentL := TFmrSpinItem(FManager.CreateItem(TFmrSpinItem, 'spIndentLeft'));
    IndentL.Caption := 'Indent Left';
    IndentL.DecimalDigits := 1;
    IndentL.Increment := 0.1;
    IndentL.Width := 64;
    IndentR := TFmrSpinItem(FManager.CreateItem(TFmrSpinItem, 'spIndentRight'));
    IndentR.Caption := 'Indent Right';
    IndentR.DecimalDigits := 1;
    IndentR.Increment := 0.1;
    IndentR.Width := 64;
    SpaceB := TFmrSpinItem(FManager.CreateItem(TFmrSpinItem, 'spSpaceBefore'));
    SpaceB.Caption := 'Before';
    SpaceB.Width := 64;
    SpaceA := TFmrSpinItem(FManager.CreateItem(TFmrSpinItem, 'spSpaceAfter'));
    SpaceA.Caption := 'After';
    SpaceA.Value := 8;
    SpaceA.Width := 64;
    Link(G, IndentL);
    Link(G, IndentR);
    Link(G, SpaceB, [], TFmrButtonGroupPosition.None, True);
    Link(G, SpaceA);
    G.ShowDialogLauncher := True;
    G.OnDialogLauncherClick := LauncherClick;
    G := Group(LayoutTab, 'Arrange');
    Link(G, Btn('btnPosition', 'Position', $E8B9, True, TFmrButtonStyle.DropDown),
      [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnWrap', 'Wrap Text', $E8B9, True, TFmrButtonStyle.DropDown),
      [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnForward', 'Bring Forward', $E8B9));
    Link(G, Btn('btnBackward', 'Send Backward', $E8B9));
    Link(G, Btn('btnRotate', 'Rotate', $E7AD));

    { View }
    View := FRibbon.AddTab('View', 'tabView');
    G := Group(View, 'Views');
    for S in ['Read Mode', 'Print Layout', 'Web Layout'] do
    begin
      B := Btn('', S, $E7C3, True, TFmrButtonStyle.Check);
      B.GroupIndex := 3;
      if S = 'Print Layout' then
        B.Down := True;
      Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    end;
    G := Group(View, 'Show');
    for S in ['Ruler', 'Gridlines', 'Navigation Pane'] do
    begin
      Check := TFmrCheckItem(FManager.CreateItem(TFmrCheckItem, ''));
      Check.Caption := S;
      Check.Checked := S = 'Ruler';
      Check.OnClick := CommandClick;
      Link(G, Check);
    end;
    G := Group(View, 'Zoom');
    Link(G, Btn('btnZoom', 'Zoom', $E71E, True), [TFmrViewLevel.Large]);
    Link(G, Btn('btnZoom100', '100%', $E71E, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Track := TFmrTrackBarItem(FManager.CreateItem(TFmrTrackBarItem, 'tbZoom'));
    Track.Caption := 'Zoom';
    Track.Min := 10;
    Track.Max := 500;
    Track.Value := 100;
    Track.Width := 110;
    Link(G, Track, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small], TFmrButtonGroupPosition.None, True);
    G := Group(View, 'Touch');
    B := Btn('btnRadialMenu', 'Radial Menu', $E7F4, True);
    B.Hint := 'Show the radial menu at the mouse pointer.';
    B.OnClick := RadialClick;
    Link(G, B, [TFmrViewLevel.Large]);
    G := Group(View, 'Window');
    Link(G, Btn('btnNewWindow', 'New Window', $E78B, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnArrange', 'Arrange All', $E80A));
    Link(G, Btn('btnSplit', 'Split', $E80A));
    Link(G, Btn('btnSideBySide', 'View Side by Side', $E80A));

    { contextual tabs }
    FTableTools := FRibbon.AddContextGroup('Table Tools', TAlphaColor($FFD08A2E), 'ctxTable');
    TDesign := FRibbon.AddTab('Table Design', 'tabTableDesign');
    TDesign.ContextGroup := FTableTools;
    G := Group(TDesign, 'Table Style Options');
    for S in ['Header Row', 'Total Row', 'Banded Rows', 'First Column', 'Last Column', 'Banded Columns'] do
    begin
      Check := TFmrCheckItem(FManager.CreateItem(TFmrCheckItem, ''));
      Check.Caption := S;
      Check.Checked := (S = 'Header Row') or (S = 'Banded Rows') or (S = 'First Column');
      Check.OnClick := CommandClick;
      Link(G, Check);
    end;
    G := Group(TDesign, 'Table Styles');
    for I := 1 to 4 do
    begin
      B := Btn('', 'Style ' + IntToStr(I), 0, False, TFmrButtonStyle.Check);
      B.GroupIndex := 4;
      B.Glyph.PathData := PathTable;
      B.Glyph.PathViewBox := 24;
      B.LargeGlyph.PathData := PathTable;
      B.LargeGlyph.PathViewBox := 24;
      Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    end;
    G := Group(TDesign, 'Borders');
    Item := FManager.CreateItem(TFmrColorItem, 'clrTableShading');
    Item.Caption := 'Shading';
    Item.Glyph.GlyphCode := $E790;
    Item.LargeGlyph.GlyphCode := $E790;
    TFmrColorItem(Item).Color := TAlphaColor($FFDDEBF7);
    Item.OnClick := CommandClick;
    Link(G, Item, [TFmrViewLevel.Large]);
    B := Btn('btnBorders', 'Borders', $E80A, True, TFmrButtonStyle.Split);
    B.DropDownLinks.AddItem(Btn('', 'All Borders', $E80A));
    B.DropDownLinks.AddItem(Btn('', 'No Border', 0));
    Link(G, B, [TFmrViewLevel.Large]);
    TLayout := FRibbon.AddTab('Table Layout', 'tabTableLayout');
    TLayout.ContextGroup := FTableTools;
    G := Group(TLayout, 'Rows && Columns');
    for S in ['Insert Above', 'Insert Below'] do
      Link(G, PathGlyph(Btn('', S, 0, True), PathRows), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, PathGlyph(Btn('btnInsLeft', 'Insert Left'), PathColumns));
    Link(G, PathGlyph(Btn('btnInsRight', 'Insert Right'), PathColumns));
    Link(G, Btn('btnDelete', 'Delete', $E74D, False, TFmrButtonStyle.DropDown));
    G := Group(TLayout, 'Merge');
    Link(G, PathGlyph(Btn('btnMerge', 'Merge Cells'), PathTable));
    Link(G, PathGlyph(Btn('btnSplitCells', 'Split Cells'), PathTable));
    Link(G, PathGlyph(Btn('btnSplitTable', 'Split Table'), PathTable));
  finally
    FRibbon.EndStructureUpdate;
    FManager.EndUpdate;
  end;
end;

procedure TRibbonBasicForm.ApplyCommandLine;
var
  I, N: Integer;
  S, V: string;
begin
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    V := '';
    if S.Contains('=') then
    begin
      V := S.Substring(S.IndexOf('=') + 1);
      S := S.Substring(0, S.IndexOf('='));
    end;
    S := S.ToLower;
    if S = '/theme' then
      FRibbon.Theme := V
    else if (S = '/width') and TryStrToInt(V, N) then
      Width := N
    else if (S = '/height') and TryStrToInt(V, N) then
      Height := N
    else if S = '/minimized' then
      FRibbon.Minimized := True
    else if S = '/simplified' then
      FRibbon.DisplayMode := TFmrRibbonDisplayMode.Simplified
    else if S = '/qatbelow' then
      FRibbon.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon
    else if S = '/tabletools' then
    begin
      FTableTools.Visible := True;
      FShowTableTools.Down := True;
    end
    else if S = '/keytips' then
      FOptKeyTips := True
    else if S = '/dump' then
      FDumpFile := V
    else if S = '/touch' then
      FRibbon.TouchMode := True
    else if S = '/topmost' then
      FormStyle := TFormStyle.StayOnTop
    else if S = '/nosearch' then
      FRibbon.ShowSearchBox := False
    else if S = '/backstage' then
      BuildBackstage
    else if S = '/open' then
      FOpen := V.ToLower
    else if S = '/appmenu' then
      FForceAppMenu := True
    else if (S = '/tab') and TryStrToInt(V, N) and (N >= 0) and (N < FRibbon.TabCount) then
    begin
      if not FRibbon.Tabs(N).IsShown and (FRibbon.Tabs(N).ContextGroup <> nil) then
        FRibbon.Tabs(N).ContextGroup.Visible := True;
      FRibbon.ActiveTab := FRibbon.Tabs(N);
    end;
  end;
end;

procedure TRibbonBasicForm.BuildBackstage;
var
  Info: TFmrBackstageTab;
  L: TLabel;
begin
  // The backstage view of FMR.Ribbon.Backstage as the application menu: the ribbon opens it with
  // ShowApplicationMenu and hides its tab row while it covers the form.
  FBackstage := TFmrRibbonBackstageView.Create(Self);
  FBackstage.Parent := Self;
  FBackstage.BarManager := FManager;
  Info := FBackstage.AddTab('Info');
  L := TLabel.Create(Self);
  L.Parent := Info;
  L.Position.Point := PointF(32, 32);
  L.Width := 400;
  L.Text := 'Document1 - backstage view opened by the File tab';
  FBackstage.AddTab('New');
  FBackstage.AddButton('Save', BackstageClick).BeginGroup := True;
  FBackstage.AddButton('Close', BackstageClick);
  FBackstage.ActiveTab := Info;
  FBackstage.ThemeProvider := FRibbon;
  FRibbon.ApplicationMenu := FBackstage;
end;

procedure TRibbonBasicForm.BackstageClick(Sender: TObject);
begin
  SetStatus('Backstage: ' + TFmrBackstageButton(Sender).Caption);
end;

procedure TRibbonBasicForm.SetStatus(const AText: string);
begin
  FStatus.Text := AText;
end;

procedure TRibbonBasicForm.CommandClick(Sender: TObject);
var
  Item: TFmrBarItem;
  S: string;
begin
  Item := TFmrBarItem(Sender);
  S := 'Command: ' + FmrStripAccel(Item.Caption);
  if Item is TFmrButtonItem and (TFmrButtonItem(Item).ButtonStyle = TFmrButtonStyle.Check) then
    S := S + ' (down: ' + BoolToStr(TFmrButtonItem(Item).Down, True) + ')';
  if Item is TFmrCheckItem then
    S := S + ' (checked: ' + BoolToStr(TFmrCheckItem(Item).Checked, True) + ')';
  if Item is TFmrColorItem then
    S := S + ' (color: ' + IntToHex(TFmrColorItem(Item).Color, 8) + ')';
  SetStatus(S);
  if Item.Name = 'btnExit' then
    Close;
end;

procedure TRibbonBasicForm.TableToolsClick(Sender: TObject);
begin
  if FShowTableTools.Down then
    FTableTools.Activate
  else
    FTableTools.Visible := False;
  SetStatus('Table Tools: ' + BoolToStr(FTableTools.Visible, True));
end;

procedure TRibbonBasicForm.LauncherClick(Sender: TObject);
begin
  SetStatus('Dialog launcher: ' + TFmrRibbonGroup(Sender).Caption);
end;

procedure TRibbonBasicForm.RibbonSearch(Sender: TObject; const AText: string);
begin
  SetStatus('Search: ' + AText);
end;

procedure TRibbonBasicForm.TabChanged(Sender: TObject);
begin
  if FRibbon.ActiveTab <> nil then
    SetStatus('Tab: ' + FRibbon.ActiveTab.Caption);
end;

procedure TRibbonBasicForm.TimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  if FOptKeyTips then
    FRibbon.ShowKeyTipsNow;
  if FDumpFile <> '' then
    TFile.WriteAllText(FDumpFile, FRibbon.DebugDump);
  if FOpen <> '' then
    OpenPopup(FOpen);
end;

{ galleries }

type
  TDemoStyle = record
    Name: string;
    Sample: string;
    Family: string;
    Size: Single;
    Style: TFontStyles;
    Color: TAlphaColor;
  end;

const
  DemoStyles: array[0..15] of TDemoStyle = (
    (Name: 'Normal'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: []; Color: 0),
    (Name: 'No Spacing'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: []; Color: 0),
    (Name: 'Heading 1'; Sample: 'AaBbCc'; Family: 'Calibri Light'; Size: 16; Style: []; Color: $FF2F5496),
    (Name: 'Heading 2'; Sample: 'AaBbCcD'; Family: 'Calibri Light'; Size: 13; Style: []; Color: $FF2F5496),
    (Name: 'Title'; Sample: 'AaB'; Family: 'Calibri Light'; Size: 28; Style: []; Color: 0),
    (Name: 'Subtitle'; Sample: 'AaBbCcD'; Family: 'Calibri'; Size: 11; Style: []; Color: $FF5A5A5A),
    (Name: 'Subtle Emphasis'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: [TFontStyle.fsItalic];
      Color: $FF404040),
    (Name: 'Emphasis'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: [TFontStyle.fsItalic]; Color: 0),
    (Name: 'Intense Emphasis'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: [TFontStyle.fsItalic];
      Color: $FF4472C4),
    (Name: 'Strong'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: [TFontStyle.fsBold]; Color: 0),
    (Name: 'Quote'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: [TFontStyle.fsItalic]; Color: $FF404040),
    (Name: 'Intense Quote'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: [TFontStyle.fsItalic];
      Color: $FF4472C4),
    (Name: 'Subtle Reference'; Sample: 'AABBCCDD'; Family: 'Calibri'; Size: 10; Style: []; Color: $FF5A5A5A),
    (Name: 'Intense Reference'; Sample: 'AABBCCDD'; Family: 'Calibri'; Size: 10; Style: [TFontStyle.fsBold];
      Color: $FF4472C4),
    (Name: 'Book Title'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11;
      Style: [TFontStyle.fsBold, TFontStyle.fsItalic]; Color: 0),
    (Name: 'List Paragraph'; Sample: 'AaBbCcDd'; Family: 'Calibri'; Size: 11; Style: []; Color: 0));

  PathShapeLine = 'M3,20 L20,3 L21,4 L4,21 Z';
  PathShapeArrow = 'M3,20 L17,6 L13,6 L14,4 L20,4 L20,10 L18,11 L18,7 L4,21 Z';
  PathShapeRect = 'M3,5 L21,5 L21,19 L3,19 Z M5,7 L5,17 L19,17 L19,7 Z';
  PathShapeRound = 'M7,5 L17,5 Q21,5 21,9 L21,15 Q21,19 17,19 L7,19 Q3,19 3,15 L3,9 Q3,5 7,5 Z ' +
    'M7,7 Q5,7 5,9 L5,15 Q5,17 7,17 L17,17 Q19,17 19,15 L19,9 Q19,7 17,7 Z';
  PathShapeOval = 'M12,4 A8,8 0 1 1 11.99,4 Z M12,6 A6,6 0 1 0 12.01,6 Z';
  PathShapeTriangle = 'M12,3 L22,20 L2,20 Z M12,7 L5.5,18 L18.5,18 Z';
  PathShapeRight = 'M3,3 L3,21 L21,21 Z M5,8 L5,19 L16,19 Z';
  PathShapeDiamond = 'M12,2 L22,12 L12,22 L2,12 Z M12,5 L5,12 L12,19 L19,12 Z';
  PathShapePentagon = 'M12,2 L22,9.5 L18,21 L6,21 L2,9.5 Z M12,4.5 L4.4,10.2 L7.4,19 L16.6,19 L19.6,10.2 Z';
  PathShapeHexagon = 'M7,3 L17,3 L22,12 L17,21 L7,21 L2,12 Z M8,5 L4.3,12 L8,19 L16,19 L19.7,12 L16,5 Z';
  PathShapeStar = 'M12,2 L14.9,8.6 L22,9.3 L16.6,14 L18.2,21 L12,17.3 L5.8,21 L7.4,14 L2,9.3 L9.1,8.6 Z';
  PathShapeHeart = 'M12,21 L4,13 Q1,9.5 4,6 Q8,3 12,7.5 Q16,3 20,6 Q23,9.5 20,13 Z';
  PathShapeBlockRight = 'M2,8 L13,8 L13,3 L22,12 L13,21 L13,16 L2,16 Z';
  PathShapeBlockLeft = 'M22,8 L11,8 L11,3 L2,12 L11,21 L11,16 L22,16 Z';
  PathShapeBlockUp = 'M8,22 L8,11 L3,11 L12,2 L21,11 L16,11 L16,22 Z';
  PathShapeBlockDown = 'M8,2 L8,13 L3,13 L12,22 L21,13 L16,13 L16,2 Z';
  PathShapeChevron = 'M3,4 L14,4 L21,12 L14,20 L3,20 L10,12 Z';
  PathShapeCallout = 'M3,3 L21,3 L21,16 L10,16 L5,21 L6,16 L3,16 Z';

function TRibbonBasicForm.BuildStylesGallery: TFmrRibbonGalleryItem;
var
  I: Integer;
  G: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
begin
  Result := TFmrRibbonGalleryItem(FManager.CreateItem(TFmrRibbonGalleryItem, 'galStyles'));
  Result.Caption := 'Styles';
  Result.KeyTip := 'L';
  Result.LargeGlyph.PathData := PathStyle;
  Result.LargeGlyph.PathViewBox := 24;
  Result.Glyph.PathData := PathStyle;
  Result.Glyph.PathViewBox := 24;
  Result.ItemWidth := 76;
  Result.ItemHeight := 62;
  Result.MinColumns := 2;
  Result.MaxColumns := 6;
  Result.DropDownColumns := 6;
  Result.ShowGroupHeaders := False;
  Result.ScreenTip.Description := 'Choose a style for the selected paragraph. Point at a style to preview it.';
  G := Result.Groups.Add('Styles');
  for I := 0 to High(DemoStyles) do
  begin
    E := G.Items.Add(DemoStyles[I].Name);
    E.Tag := I;
  end;
  Result.SelectedIndex := 0;
  Result.OnDrawItem := StylesDrawItem;
  Result.OnHotTrack := StylesHotTrack;
  Result.OnItemClick := StylesItemClick;
  Result.DropDownLinks.AddItem(PathGlyph(Btn('btnCreateStyle', 'Create a Style'), PathStyle));
  Result.DropDownLinks.AddItem(Glyph(Btn('btnClearFormatting', 'Clear Formatting'), $E894));
  Result.DropDownLinks.AddItem(Btn('btnApplyStyles', 'Apply Styles...'));
end;

function TRibbonBasicForm.BuildCoverGallery: TFmrRibbonGalleryItem;
const
  BuiltIn: array[0..11] of string = ('Austin', 'Banded', 'Facet', 'Filigree', 'Grid', 'Integral', 'Ion (Dark)',
    'Ion (Light)', 'Motion', 'Retrospect', 'Semaphore', 'Sideline');
  Online: array[0..3] of string = ('Annual Report', 'Newsletter', 'Proposal', 'Resume');
var
  I: Integer;
  G: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
begin
  Result := TFmrRibbonGalleryItem(FManager.CreateItem(TFmrRibbonGalleryItem, 'galCover'));
  Result.Caption := 'Cover Page';
  Result.KeyTip := 'NV';
  Result.Glyph.GlyphCode := $E8A5;
  Result.LargeGlyph.GlyphCode := $E8A5;
  Result.ShowInRibbon := False;
  Result.CaptionPosition := TFmrGalleryCaptionPosition.Bottom;
  Result.ItemWidth := 104;
  Result.ItemHeight := 128;
  Result.DropDownColumns := 3;
  Result.DropDownRows := 2;
  Result.AllowFilter := True;
  Result.SelectionMode := TFmrGallerySelectionMode.None;
  Result.ScreenTip.Description := 'Add a fully formatted cover page to the document.';
  G := Result.Groups.Add('Built-in');
  for I := 0 to High(BuiltIn) do
  begin
    E := G.Items.Add(BuiltIn[I]);
    E.Tag := I;
    E.Hint := 'Insert the ' + BuiltIn[I] + ' cover page.';
  end;
  G := Result.Groups.Add('Office.com');
  for I := 0 to High(Online) do
  begin
    E := G.Items.Add(Online[I]);
    E.Tag := 100 + I;
  end;
  Result.OnDrawItem := CoverDrawItem;
  Result.OnItemClick := GalleryItemClick;
  Result.DropDownLinks.AddItem(Btn('btnMoreCovers', 'More Cover Pages from Office.com'));
  Result.DropDownLinks.AddItem(Glyph(Btn('btnRemoveCover', 'Remove Current Cover Page'), $E74D));
  Result.DropDownLinks.AddItem(Btn('btnSaveCover', 'Save Selection to Cover Page Gallery...'));
end;

function TRibbonBasicForm.BuildShapesGallery: TFmrGalleryItem;

  procedure AddShapes(const AGroup: TFmrGalleryGroup; const ANames, APaths: array of string);
  var
    I: Integer;
    E: TFmrGalleryEntry;
  begin
    for I := 0 to High(ANames) do
    begin
      E := AGroup.Items.Add(ANames[I]);
      E.Glyph.PathData := APaths[I];
      E.Glyph.PathViewBox := 24;
    end;
  end;

begin
  Result := TFmrGalleryItem(FManager.CreateItem(TFmrGalleryItem, 'galShapes'));
  Result.Caption := 'Shapes';
  Result.ShowInRibbon := False;
  Result.ItemWidth := 28;
  Result.ItemHeight := 28;
  Result.DropDownColumns := 10;
  Result.SelectionMode := TFmrGallerySelectionMode.None;
  AddShapes(Result.Groups.Add('Recently Used Shapes'), ['Line', 'Rectangle', 'Oval', 'Right Arrow'],
    [PathShapeLine, PathShapeRect, PathShapeOval, PathShapeBlockRight]);
  AddShapes(Result.Groups.Add('Lines'), ['Line', 'Arrow'], [PathShapeLine, PathShapeArrow]);
  AddShapes(Result.Groups.Add('Rectangles'), ['Rectangle', 'Rounded Rectangle'], [PathShapeRect, PathShapeRound]);
  AddShapes(Result.Groups.Add('Basic Shapes'), ['Oval', 'Isosceles Triangle', 'Right Triangle', 'Diamond',
    'Pentagon', 'Hexagon', 'Star', 'Heart', 'Callout'], [PathShapeOval, PathShapeTriangle, PathShapeRight,
    PathShapeDiamond, PathShapePentagon, PathShapeHexagon, PathShapeStar, PathShapeHeart, PathShapeCallout]);
  AddShapes(Result.Groups.Add('Block Arrows'), ['Right Arrow', 'Left Arrow', 'Up Arrow', 'Down Arrow', 'Chevron'],
    [PathShapeBlockRight, PathShapeBlockLeft, PathShapeBlockUp, PathShapeBlockDown, PathShapeChevron]);
  Result.OnItemClick := GalleryItemClick;
end;

procedure TRibbonBasicForm.StylesDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  St: TDemoStyle;
  R: TRectF;
  TextColor, SampleColor: TAlphaColor;
begin
  St := DemoStyles[EnsureRange(AEntry.Tag, 0, High(DemoStyles))];
  if TFmrGalleryDrawState.InRibbon in AState then
    TextColor := APainter.ButtonTextColor(TFmrPartState.Normal)
  else
    TextColor := APainter.Theme.Colors[TFmrToken.MenuItemText];
  SampleColor := St.Color;
  if SampleColor = 0 then
    SampleColor := TextColor
  else if APainter.Theme.Style.Dark then
    SampleColor := FmrLighten(SampleColor, 0.45);
  R := ARect;
  R.Inflate(-3, -2);
  ACanvas.Font.Family := St.Family;
  ACanvas.Font.Size := Min(St.Size + 1, 20);
  ACanvas.Font.Style := St.Style;
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := SampleColor;
  ACanvas.FillText(RectF(R.Left, R.Top, R.Right, R.Bottom - 16), St.Sample, False, 1, [], TTextAlign.Center,
    TTextAlign.Center);
  APainter.TextEx(ACanvas, RectF(R.Left, R.Bottom - 17, R.Right, R.Bottom), St.Name, TextColor, TTextAlign.Center,
    TTextAlign.Center, APainter.Metrics.FontSize - 1, False, False);
  AHandled := True;
end;

procedure TRibbonBasicForm.CoverDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
const
  Colors: array[0..5] of TAlphaColor = ($FF4472C4, $FFED7D31, $FF70AD47, $FF5B9BD5, $FFFFC000, $FF7030A0);
var
  Page, Band: TRectF;
  C: TAlphaColor;
  K: Integer;
begin
  // A miniature page: white sheet, a colored band and title lines; the caption is painted by the gallery.
  Page := RectF(0, 0, 58, 76);
  Page.Offset(Round(ARect.CenterPoint.X - 29), ARect.Top + 6);
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := TAlphaColors.White;
  ACanvas.FillRect(Page, 0, 0, [], 1);
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := $FFB0B0B0;
  ACanvas.Stroke.Thickness := 1;
  ACanvas.DrawRect(RectF(Page.Left + 0.5, Page.Top + 0.5, Page.Right - 0.5, Page.Bottom - 0.5), 0, 0, [], 1);
  K := AEntry.Tag mod 100;
  C := Colors[K mod Length(Colors)];
  case K mod 3 of
    0: Band := RectF(Page.Left + 1, Page.Top + 1, Page.Right - 1, Page.Top + 24);
    1: Band := RectF(Page.Left + 1, Page.Top + 30, Page.Right - 1, Page.Top + 46);
  else
    Band := RectF(Page.Left + 1, Page.Top + 1, Page.Left + 14, Page.Bottom - 1);
  end;
  ACanvas.Fill.Color := C;
  ACanvas.FillRect(Band, 0, 0, [], 1);
  ACanvas.Fill.Color := $FF808080;
  ACanvas.FillRect(RectF(Page.Left + 18, Page.Bottom - 22, Page.Right - 6, Page.Bottom - 19), 0, 0, [], 1);
  ACanvas.FillRect(RectF(Page.Left + 18, Page.Bottom - 15, Page.Right - 14, Page.Bottom - 13), 0, 0, [], 1);
  APainter.TextEx(ACanvas, RectF(ARect.Left + 2, Page.Bottom + 4, ARect.Right - 2, ARect.Bottom - 2), AEntry.Caption,
    APainter.Theme.Colors[TFmrToken.MenuItemText], TTextAlign.Center, TTextAlign.Leading, 0, False, True);
  AHandled := True;
end;

procedure TRibbonBasicForm.ShowStyle(const AIndex: Integer);
var
  St: TDemoStyle;
begin
  St := DemoStyles[EnsureRange(AIndex, 0, High(DemoStyles))];
  FMemo.TextSettings.Font.Family := St.Family;
  FMemo.TextSettings.Font.Size := St.Size + 3;
  FMemo.TextSettings.Font.Style := St.Style;
  if St.Color <> 0 then
    FMemo.TextSettings.FontColor := St.Color
  else
    FMemo.TextSettings.FontColor := FAppliedColor;
end;

procedure TRibbonBasicForm.StylesHotTrack(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  // Live preview: the hot style is shown on the document; nil restores the applied style.
  if AEntry <> nil then
  begin
    ShowStyle(AEntry.Tag);
    SetStatus('Preview: ' + AEntry.Caption);
  end
  else
    ShowStyle(FAppliedStyle);
end;

procedure TRibbonBasicForm.StylesItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  FAppliedStyle := AEntry.Tag;
  ShowStyle(FAppliedStyle);
  SetStatus('Style: ' + AEntry.Caption);
end;

procedure TRibbonBasicForm.GalleryItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  SetStatus(TFmrGalleryItem(Sender).Caption + ': ' + AEntry.Caption);
end;

procedure TRibbonBasicForm.FontColorPreview(Sender: TObject; const AColor: TAlphaColor; const AActive: Boolean);
begin
  if AActive and (TAlphaColorRec(AColor).A > 0) then
    FMemo.TextSettings.FontColor := AColor
  else
    ShowStyle(FAppliedStyle);
end;

procedure TRibbonBasicForm.FontColorClick(Sender: TObject);
begin
  if FFontColor.Color = TAlphaColors.Null then
    FAppliedColor := FFontColor.AutomaticColor
  else
    FAppliedColor := FFontColor.Color;
  FMemo.TextSettings.FontColor := FAppliedColor;
  SetStatus('Font color: #' + IntToHex(FAppliedColor and $FFFFFF, 6));
end;

procedure TRibbonBasicForm.DropDownOf(const AItem: TFmrBarItem; const ATab: TFmrRibbonTab);
var
  V: TFmrItemView;
begin
  // The view of the first link of AItem opens its drop-down exactly like a mouse press.
  if ATab <> nil then
    FRibbon.ActiveTab := ATab;
  FRibbon.UpdateLayout;
  if (AItem = nil) or (AItem.LinkCount = 0) or not (AItem.Links[0].ViewObject is TFmrItemView) then
    Exit;
  V := TFmrItemView(AItem.Links[0].ViewObject);
  if V.Host <> nil then
    V.Host.ElementDropDown(V, False);
end;

{ TDemoMemo }

function TDemoMemo.ShowContextMenu(const ScreenPosition: TPointF): Boolean;
begin
  Result := Assigned(FOnContext);
  if Result then
    FOnContext(ScreenPosition);
end;

{ application menu, mini toolbar, radial menu }

procedure TRibbonBasicForm.BuildAppMenu2007;
var
  SaveAs, Print, Prepare: TFmrBarItem;
  B: TFmrButtonItem;

  function Large(const AItem: TFmrBarItem; const ACode: Cardinal; const ADescription: string = ''): TFmrBarItem;
  begin
    AItem.Glyph.GlyphCode := ACode;
    AItem.LargeGlyph.GlyphCode := ACode;
    AItem.Description := ADescription;
    Result := AItem;
  end;

begin
  // Office 2007 application menu (FMR.Ribbon.AppMenu): large items, submenus in the right pane, recent documents.
  FAppMenu07 := TFmrRibbonApplicationMenu.Create(Self);
  FAppMenu07.Parent := Self;
  FAppMenu07.BarManager := FManager;
  FAppMenu07.ItemLinks.AddItem(Large(FManager.ItemByName('btnNew'), $E8A5));
  FAppMenu07.ItemLinks.AddItem(Large(FManager.ItemByName('btnOpen'), $E8E5));
  FAppMenu07.ItemLinks.AddItem(Large(FManager.ItemByName('btnSave'), $E74E));
  SaveAs := Large(Btn('btnSaveAs07', 'Save &As', 0, False, TFmrButtonStyle.Split), $E792,
    'Save a copy of the document');
  B := TFmrButtonItem(SaveAs);
  B.DropDownLinks.AddItem(Large(Btn('btnSaveDocx', 'Word Document'), $E8A5,
    'Save the document in the default file format.'));
  B.DropDownLinks.AddItem(Large(Btn('btnSaveTemplate', 'Word Template'), $E8F4,
    'Save the document as a template that can be used to format future documents.'));
  B.DropDownLinks.AddItem(Large(Btn('btnSavePdf', 'PDF or XPS'), $EA90,
    'Publish a copy of the document as a PDF or XPS file.'));
  B.DropDownLinks.AddItem(Large(Btn('btnSaveOther', 'Other Formats'), $E792,
    'Open the Save As dialog box to select from all possible file types.'));
  FAppMenu07.ItemLinks.AddItem(SaveAs, True);
  Print := Large(Btn('btnPrint07', '&Print', 0, False, TFmrButtonStyle.Split), $E749,
    'Preview and print the document');
  B := TFmrButtonItem(Print);
  B.DropDownLinks.AddItem(Large(Btn('btnPrintDialog', 'Print'), $E749,
    'Select a printer, number of copies, and other printing options before printing.'));
  B.DropDownLinks.AddItem(Large(Btn('btnQuickPrint', 'Quick Print'), $E749,
    'Send the document directly to the default printer without making changes.'));
  B.DropDownLinks.AddItem(Large(Btn('btnPrintPreview', 'Print Preview'), $E8FF,
    'Preview and make changes to pages before printing.'));
  FAppMenu07.ItemLinks.AddItem(Print);
  Prepare := Large(FManager.CreateItem(TFmrSubItem, 'subPrepare'), $E70F, 'Prepare the document for distribution');
  Prepare.Caption := 'Pr&epare';
  TFmrSubItem(Prepare).ItemLinks.AddItem(Large(Btn('btnProperties', 'Properties'), $E946,
    'View and edit document properties, such as Title, Author, and Keywords.'));
  TFmrSubItem(Prepare).ItemLinks.AddItem(Large(Btn('btnInspect', 'Inspect Document'), $E721,
    'Check the document for hidden metadata or personal information.'));
  TFmrSubItem(Prepare).ItemLinks.AddItem(Large(Btn('btnEncrypt', 'Encrypt Document'), $E72E,
    'Increase the security of the document by adding encryption.'));
  FAppMenu07.ItemLinks.AddItem(Prepare);
  FAppMenu07.ItemLinks.AddItem(Large(Btn('btnSend07', 'Sen&d'), $E724));
  FAppMenu07.ItemLinks.AddItem(Large(Btn('btnClose07', '&Close'), $E8BB), True);
  FAppMenu07.Buttons.AddItem(Glyph(Btn('btnOptions07', 'Word Opt&ions'), $E713));
  FAppMenu07.Buttons.AddItem(Glyph(Btn('btnExitWord', 'E&xit Word'), $E8BB));
  FAppMenu07.RecentDocuments.Add('Quarterly Report.docx', 'C:\Documents\Quarterly Report.docx', True);
  FAppMenu07.RecentDocuments.Add('Meeting Notes.docx', 'C:\Documents\Meeting Notes.docx');
  FAppMenu07.RecentDocuments.Add('Project Plan.docx', 'C:\Documents\Project Plan.docx', True);
  FAppMenu07.RecentDocuments.Add('Invoice 2026-10.docx', 'C:\Documents\Invoice 2026-10.docx');
  FAppMenu07.RecentDocuments.Add('Letter to Customers.docx', 'C:\Documents\Letter to Customers.docx');
  FAppMenu07.RecentDocuments.Add('Ribbon Design.docx', 'C:\Documents\Ribbon Design.docx');
  FAppMenu07.OnRecentClick := RecentClick;
  FAppMenu07.OnRecentPinChanged := RecentClick;
end;

procedure TRibbonBasicForm.BuildMiniToolbar;
var
  Grow, Shrink: TFmrButtonItem;
  B: TFmrButtonItem;
begin
  // Mini toolbar (FMR.Ribbon.MiniToolbar) with the context menu of the document; reuses the ribbon's items.
  FContextMenu := TFmrPopupMenu.Create(Self);
  FContextMenu.Parent := Self;
  FContextMenu.BarManager := FManager;
  FContextMenu.ThemeSource := FRibbon;
  FContextMenu.ItemLinks.AddItem(FManager.ItemByName('btnCut'));
  FContextMenu.ItemLinks.AddItem(FManager.ItemByName('btnCopy'));
  FContextMenu.ItemLinks.AddItem(FManager.ItemByName('btnPaste'));
  FContextMenu.ItemLinks.AddItem(Glyph(Btn('btnFontDialog', 'Font...'), $E8D2), True);
  FContextMenu.ItemLinks.AddItem(PathGlyph(Btn('btnParagraphDialog', 'Paragraph...'), PathJustify));
  FContextMenu.ItemLinks.AddItem(FManager.ItemByName('btnBullets'), True);
  FContextMenu.ItemLinks.AddItem(FManager.ItemByName('btnNumbering'));
  FContextMenu.ItemLinks.AddItem(Glyph(Btn('btnLookUp', 'Look Up'), $E721), True);
  FMiniToolbar := TFmrRibbonMiniToolbar.Create(Self);
  FMiniToolbar.Parent := Self;
  FMiniToolbar.BarManager := FManager;
  FMiniToolbar.ThemeSource := FRibbon;
  FMiniToolbar.PopupMenu := FContextMenu;
  Grow := Btn('btnGrowFont', 'Grow Font', $E8E8);
  Grow.Hint := 'Make the text a bit larger.';
  Shrink := Btn('btnShrinkFont', 'Shrink Font', $E8E7);
  Shrink.Hint := 'Make the text a bit smaller.';
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('cbFontName'));
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('cbFontSize'));
  FMiniToolbar.ItemLinks.AddItem(Grow);
  FMiniToolbar.ItemLinks.AddItem(Shrink);
  FMiniToolbar.ItemLinks.AddItem(FStyles, True);
  // A separator starts the second row.
  FMiniToolbar.ItemLinks.AddItem(FManager.CreateItem(TFmrSeparatorItem, 'sepMini'));
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('btnBold'));
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('btnItalic'));
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('btnUnderline'));
  FMiniToolbar.ItemLinks.AddItem(FHighlight);
  FMiniToolbar.ItemLinks.AddItem(FFontColor);
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('btnFormatPainter'));
  B := TFmrButtonItem(FManager.ItemByName('btnBullets'));
  FMiniToolbar.ItemLinks.AddItem(B, True);
  FMiniToolbar.ItemLinks.AddItem(FManager.ItemByName('btnNumbering'));
end;

procedure TRibbonBasicForm.BuildRadialMenu;
var
  Align, Styles: TFmrSubItem;
  I: Integer;
  S: string;
  B: TFmrButtonItem;
begin
  // Radial menu (FMR.Ribbon.RadialMenu): 8 sectors, nested rings for Align, Styles and the bullet styles.
  FRadial := TFmrRibbonRadialMenu.Create(Self);
  FRadial.Parent := Self;
  FRadial.BarManager := FManager;
  FRadial.ThemeSource := FRibbon;
  FRadial.ItemLinks.AddItem(FManager.ItemByName('btnUndo'));
  FRadial.ItemLinks.AddItem(FManager.ItemByName('btnBold'));
  FRadial.ItemLinks.AddItem(FManager.ItemByName('btnItalic'));
  FRadial.ItemLinks.AddItem(FManager.ItemByName('btnUnderline'));
  FRadial.ItemLinks.AddItem(FFontColor);
  FRadial.ItemLinks.AddItem(FManager.ItemByName('btnBullets'));
  Align := TFmrSubItem(FManager.CreateItem(TFmrSubItem, 'subRadialAlign'));
  Align.Caption := 'Align';
  Align.Glyph.GlyphCode := $E8E3;
  for S in ['btnAlignLeft', 'btnAlignCenter', 'btnAlignRight', 'btnJustify'] do
    Align.ItemLinks.AddItem(FManager.ItemByName(S));
  FRadial.ItemLinks.AddItem(Align);
  Styles := TFmrSubItem(FManager.CreateItem(TFmrSubItem, 'subRadialStyles'));
  Styles.Caption := 'Styles';
  Styles.Glyph.PathData := PathStyle;
  Styles.Glyph.PathViewBox := 24;
  for I in [0, 2, 3, 4, 5, 10] do
  begin
    B := Btn('', DemoStyles[I].Name);
    B.Glyph.PathData := PathStyle;
    B.Glyph.PathViewBox := 24;
    B.Tag := I;
    B.OnClick := StyleCommandClick;
    Styles.ItemLinks.AddItem(B);
  end;
  FRadial.ItemLinks.AddItem(Styles);
end;

procedure TRibbonBasicForm.RecentClick(Sender: TObject; const ADocument: TFmrRecentDocument);
begin
  if ADocument.Pinned then
    SetStatus('Recent document: ' + ADocument.Caption + ' (pinned)')
  else
    SetStatus('Recent document: ' + ADocument.Caption);
end;

procedure TRibbonBasicForm.RadialClick(Sender: TObject);
var
  P: TPointF;
begin
  P := Screen.MousePos;
  FRadial.Popup(P);
end;

procedure TRibbonBasicForm.StyleCommandClick(Sender: TObject);
begin
  FAppliedStyle := TFmrBarItem(Sender).Tag;
  FStyles.SelectedIndex := FAppliedStyle;
  ShowStyle(FAppliedStyle);
  SetStatus('Style: ' + DemoStyles[FAppliedStyle].Name);
end;

procedure TRibbonBasicForm.MemoMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  // Selecting text with the mouse shows the mini toolbar half transparent; it fades as the mouse goes away.
  if (Button = TMouseButton.mbLeft) and (FMemo.SelLength > 0) then
    FMiniToolbar.Popup(FMemo.LocalToScreen(PointF(X, Y)), False);
end;

procedure TRibbonBasicForm.OpenPopup(const AWhat: string);
var
  P: TPointF;
begin
  P := FMemo.LocalToScreen(PointF(FMemo.Width * 0.45, 120));
  if AWhat = 'appmenu' then
  begin
    if FRibbon.ApplicationMenu <> FAppMenu07 then
      FRibbon.ApplicationMenu := FAppMenu07;
    FAppMenu07.ShowApplicationMenu(FRibbon, FRibbon.ApplicationButtonScreenRect, False);
  end
  else if AWhat = 'minitoolbar' then
    FMiniToolbar.Popup(P, True)
  else if AWhat = 'minifade' then
    FMiniToolbar.Popup(P, False)
  else if AWhat = 'radial' then
    FRadial.Popup(P)
  else if AWhat = 'shapesmenu' then
    DropDownOf(FShapesButton, FRibbon.Tabs(1));
  if AWhat = 'stylesgallery' then
    DropDownOf(FStyles, FRibbon.Tabs(0))
  else if AWhat = 'colorgallery' then
    DropDownOf(FFontColor, FRibbon.Tabs(0))
  else if AWhat = 'highlight' then
    DropDownOf(FHighlight, FRibbon.Tabs(0))
  else if AWhat = 'cover' then
    DropDownOf(FCover, FRibbon.Tabs(1))
  else if AWhat = 'shapes' then
    DropDownOf(FShapesButton, FRibbon.Tabs(1));
end;

end.
