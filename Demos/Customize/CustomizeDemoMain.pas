unit CustomizeDemoMain;

/// Customization demo: a Word-like ribbon built in code (the same commands as Demos\RibbonBasic, with categories)
/// to exercise the customization form (FMR.Ribbon.Customize), the display options button and auto-hide, the
/// classic/simplified switch, right to left, the themed editors and the UI Automation provider.
///
/// Command line:
///   /theme=<name>  /frame=fullnc|dwm|ncstrip|none  /width=N  /height=N  /lang=ru  /tab=N
///   /open=customize|qat   open the customization form after start
///   /rtl                  RightToLeft ribbon      /formrtl   BiDiMode = bdRightToLeft on the form
///   /autohide             ShowMode = AutoHide     /showautohide  open the auto-hidden ribbon after start
///   /displayoptions       open the display options menu after start
///   /simplified           simplified ribbon       /touch     touch mode
///   /switchtheme=<name>   switch to another theme 1.5 s after start (live theme change of the editors)
///   /layout=<file>        load a layout at start (TFmrRibbon.LoadLayoutFromFile)
///   /autofile=<file>      Import/Export of the form use this file (no file dialogs)
///   /dump=<file>          TFmrRibbon.DebugDump        /dumpcust=<file>  the customization form controls
///   /savelayout=<file>    save the layout on exit     /tabletools  show the contextual tabs
///   /dropdown=<id>        invoke a ribbon element after start by its automation id (e.g. cbFontName, btnPaste)
///   /keytips              show key tips after start   /nouia      do not install the UI Automation provider

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Memo, FMX.StdCtrls, FMX.Layouts, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars, FMR.Bars.Items,
  FMR.Ribbon.Structure, FMR.Ribbon.Views, FMR.Ribbon.Popup, FMR.Ribbon, FMR.Ribbon.Strings, FMR.Frame.Types,
  FMR.Frame;

type
  TCustomizeDemoForm = class(TForm)
  private
    FFrame: TFmrFormFrame;
    FManager: TFmrBarManager;
    FRibbon: TFmrRibbon;
    FMemo: TMemo;
    FStatus: TLabel;
    FTableTools: TFmrRibbonContextGroup;
    FShowTableTools: TFmrButtonItem;
    FTimer: TTimer;
    FOpen, FDumpFile, FDumpCustFile, FSwitchTheme, FSaveLayout, FDropDown: string;
    FShowAutoHide, FDisplayOptions, FKeyTips: Boolean;
    FTicks: Integer;
    function Btn(const AName, ACaption: string; const ACode: Cardinal = 0; const ALarge: Boolean = False;
      const AStyle: TFmrButtonStyle = TFmrButtonStyle.Default): TFmrButtonItem;
    function PathGlyph(const AItem: TFmrBarItem; const APath: string): TFmrBarItem;
    procedure Link(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem; const ALevels: TFmrViewLevels = [];
      const AButtonGroup: TFmrButtonGroupPosition = TFmrButtonGroupPosition.None; const ABeginGroup: Boolean = False);
    procedure BuildItems;
    procedure AssignCategories;
    procedure ApplyCommandLine;
    procedure CommandClick(Sender: TObject);
    procedure CustomizeClick(Sender: TObject);
    procedure TableToolsClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure SetStatus(const AText: string);
    function InvokeById(const AId: string): Boolean;
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  CustomizeDemoForm: TCustomizeDemoForm;

implementation

uses
  System.IOUtils, FMR.Ribbon.Customize{$IFDEF MSWINDOWS}, FMR.Ribbon.UIA.Win{$ENDIF};

const
  PathFormatPainter = 'M4,3 L17,3 L17,8 L4,8 Z M17,5 L20,5 L20,11.5 L11.5,11.5 L11.5,13.5 L10.5,13.5 L10.5,10.5 ' +
    'L19,10.5 L19,6 L17,6 Z M9.5,14 L12.5,14 L12.5,21 L9.5,21 Z';
  PathJustify = 'M3,5 L21,5 L21,6.5 L3,6.5 Z M3,9 L21,9 L21,10.5 L3,10.5 Z M3,13 L21,13 L21,14.5 L3,14.5 Z ' +
    'M3,17 L21,17 L21,18.5 L3,18.5 Z';
  PathTable = 'M3,4 L8,4 L8,8 L3,8 Z M9.5,4 L14.5,4 L14.5,8 L9.5,8 Z M16,4 L21,4 L21,8 L16,8 Z ' +
    'M3,10 L8,10 L8,14 L3,14 Z M9.5,10 L14.5,10 L14.5,14 L9.5,14 Z M16,10 L21,10 L21,14 L16,14 Z ' +
    'M3,16 L8,16 L8,20 L3,20 Z M9.5,16 L14.5,16 L14.5,20 L9.5,20 Z M16,16 L21,16 L21,20 L16,20 Z';
  PathShapes = 'M3,12 L11,12 L11,20 L3,20 Z M17,3 L22,12 L12,12 Z M14,15 L21,15 L21,21 L14,21 Z';
  PathMargins = 'M5,2 L19,2 L19,22 L5,22 Z M7,4 L7,20 L17,20 L17,4 Z M8,6 L16,6 L16,7 L8,7 Z M8,9 L16,9 L16,10 ' +
    'L8,10 Z M8,12 L16,12 L16,13 L8,13 Z';
  PathStyle = 'M3,19 L8,5 L10,5 L15,19 L12.8,19 L11.6,15.5 L6.4,15.5 L5.2,19 Z M7.1,13.5 L10.9,13.5 L9,8 Z ' +
    'M16,13 L21,13 L21,14.5 L16,14.5 Z M16,17 L21,17 L21,18.5 L16,18.5 Z';

{ TCustomizeDemoForm }

constructor TCustomizeDemoForm.Create(AOwner: TComponent);
var
  Mode, S: string;
  I: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'Document1 - FMR Ribbon Customization';
  Width := 1180;
  Height := 680;
  Position := TFormPosition.ScreenCenter;
  Mode := 'fullnc';
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I).ToLower;
    if S.StartsWith('/frame=') then
      Mode := S.Substring(7)
    else if S = '/lang=ru' then
      FmrSetLanguage('ru')
    else if S = '/formrtl' then
      BiDiMode := TBiDiMode.bdRightToLeft;
  end;
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
  FRibbon.ShowDisplayOptionsButton := True;
  FRibbon.ShowDisplayModeButton := True;
  if FFrame <> nil then
    FRibbon.Frame := FFrame;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.Margins.Rect := RectF(24, 12, 24, 4);
  FMemo.WordWrap := True;
  FMemo.Lines.Text := 'FMR Ribbon - customization' + sLineBreak + sLineBreak +
    'Right-click the ribbon: "Customize the Ribbon...". The quick access toolbar menu: "More Commands...". ' +
    'The caption button left of Minimize: Ribbon Display Options (Auto-hide Ribbon, Show Tabs, Show Tabs and ' +
    'Commands). The chevron at the right end of the ribbon switches between the classic and the simplified ribbon.';

  BuildItems;
  AssignCategories;
  ApplyCommandLine;
  {$IFDEF MSWINDOWS}
  if not FindCmdLineSwitch('nouia') then
    FmrInstallRibbonAutomation(FRibbon);
  {$ENDIF}

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 700;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
end;

procedure TCustomizeDemoForm.DoClose(var CloseAction: TCloseAction);
begin
  if FSaveLayout <> '' then
    FRibbon.SaveLayoutToFile(FSaveLayout);
  inherited;
end;

function TCustomizeDemoForm.PathGlyph(const AItem: TFmrBarItem; const APath: string): TFmrBarItem;
begin
  AItem.Glyph.PathData := APath;
  AItem.Glyph.PathViewBox := 24;
  Result := AItem;
end;

function TCustomizeDemoForm.Btn(const AName, ACaption: string; const ACode: Cardinal; const ALarge: Boolean;
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

procedure TCustomizeDemoForm.Link(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem;
  const ALevels: TFmrViewLevels; const AButtonGroup: TFmrButtonGroupPosition; const ABeginGroup: Boolean);
var
  L: TFmrItemLink;
begin
  L := AGroup.ItemLinks.AddItem(AItem, ABeginGroup);
  L.ViewLevels := ALevels;
  L.ButtonGroup := AButtonGroup;
end;

procedure TCustomizeDemoForm.BuildItems;
var
  Home, Insert, LayoutTab, View, TDesign: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  Paste, Bold, Italic, Underline, Strike, AL, AC, AR, AJ, B, Sub: TFmrButtonItem;
  FontName: TFmrFontNameItem;
  FontSize, Style: TFmrComboItem;
  FontColor, Highlight: TFmrColorItem;
  Edit: TFmrEditItem;
  Spin: TFmrSpinItem;
  Track: TFmrTrackBarItem;
  Check: TFmrCheckItem;
  Save, Undo, Redo, Print: TFmrButtonItem;
  I: Integer;
  S: string;
begin
  FManager.BeginUpdate;
  FRibbon.BeginStructureUpdate;
  try
    { quick access toolbar }
    Save := Btn('btnSave', 'Save', $E74E);
    Save.ShortCut := scCtrl or Ord('S');
    Save.Category := 'File';
    Undo := Btn('btnUndo', 'Undo', $E7A7);
    Undo.ShortCut := scCtrl or Ord('Z');
    Undo.Category := 'Edit';
    Redo := Btn('btnRedo', 'Redo', $E7A6);
    Redo.ShortCut := scCtrl or Ord('Y');
    Redo.Category := 'Edit';
    Print := Btn('btnPrint', 'Print', $E749);
    Print.ShortCut := scCtrl or Ord('P');
    Print.Category := 'File';
    B := Btn('btnNew', 'New', $E8A5);
    B.Category := 'File';
    B := Btn('btnOpen', 'Open', $E8E5);
    B.Category := 'File';
    B := Btn('btnEmail', 'Email', $E715);
    B.Category := 'File';
    B := Btn('btnSpelling', 'Spelling & Grammar', $E8FD);
    B.Category := 'Review';
    B := Btn('btnCustomize', 'Customize Ribbon...', $E713);
    B.Category := 'Tools';
    B.OnClick := CustomizeClick;
    FRibbon.QuickAccessToolbar.AddItem(Save);
    FRibbon.QuickAccessToolbar.AddItem(Undo);
    FRibbon.QuickAccessToolbar.AddItem(Redo);

    { Home }
    Home := FRibbon.AddTab('Home', 'tabHome');
    G := Home.AddGroup('Clipboard');
    G.Name := 'grpClipboard';
    Paste := Btn('btnPaste', 'Paste', $E77F, True, TFmrButtonStyle.Split);
    Paste.ShortCut := scCtrl or Ord('V');
    Sub := Btn('btnPasteKeep', 'Keep Source Formatting', $E77F);
    Paste.DropDownLinks.AddItem(Sub);
    Sub := Btn('btnPasteText', 'Keep Text Only', $E8E9);
    Paste.DropDownLinks.AddItem(Sub);
    Link(G, Paste, [TFmrViewLevel.Large]);
    B := Btn('btnCut', 'Cut', $E8C6);
    B.ShortCut := scCtrl or Ord('X');
    Link(G, B);
    B := Btn('btnCopy', 'Copy', $E8C8);
    B.ShortCut := scCtrl or Ord('C');
    Link(G, B);
    B := TFmrButtonItem(PathGlyph(Btn('btnFormatPainter', 'Format Painter'), PathFormatPainter));
    B.ButtonStyle := TFmrButtonStyle.Check;
    Link(G, B);
    G.ShowDialogLauncher := True;

    G := Home.AddGroup('Font');
    G.Name := 'grpFont';
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
    Italic := Btn('btnItalic', 'Italic', $E8DB, False, TFmrButtonStyle.Check);
    Italic.ShortCut := scCtrl or Ord('I');
    Underline := Btn('btnUnderline', 'Underline', $E8DC, False, TFmrButtonStyle.Check);
    Strike := Btn('btnStrike', 'Strikethrough', $EDE0, False, TFmrButtonStyle.Check);
    Link(G, Bold, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    Link(G, Italic, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, Underline, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, Strike, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    FontColor := TFmrColorItem(FManager.CreateItem(TFmrColorItem, 'clrFont'));
    FontColor.Caption := 'Font Color';
    FontColor.Glyph.GlyphCode := $E8D3;
    FontColor.Color := TAlphaColors.Red;
    Highlight := TFmrColorItem(FManager.CreateItem(TFmrColorItem, 'clrHighlight'));
    Highlight.Caption := 'Text Highlight Color';
    Highlight.Glyph.GlyphCode := $E7E6;
    Highlight.Color := TAlphaColors.Yellow;
    Link(G, Highlight, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member, True);
    Link(G, FontColor, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    G.ShowDialogLauncher := True;

    G := Home.AddGroup('Paragraph');
    G.Name := 'grpParagraph';
    AL := Btn('btnAlignLeft', 'Align Left', $E8E4, False, TFmrButtonStyle.Check);
    AL.GroupIndex := 1;
    AL.Down := True;
    AC := Btn('btnAlignCenter', 'Center', $E8E3, False, TFmrButtonStyle.Check);
    AC.GroupIndex := 1;
    AR := Btn('btnAlignRight', 'Align Right', $E8E2, False, TFmrButtonStyle.Check);
    AR.GroupIndex := 1;
    AJ := TFmrButtonItem(PathGlyph(Btn('btnJustify', 'Justify', 0, False, TFmrButtonStyle.Check), PathJustify));
    AJ.GroupIndex := 1;
    Link(G, AL, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    Link(G, AC, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, AR, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    Link(G, AJ, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    B := Btn('btnBullets', 'Bullets', $E8FD, False, TFmrButtonStyle.Split);
    B.DropDownLinks.AddItem(Btn('btnBullet1', 'Bullet Style 1', $E8FD));
    Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Start);
    B := Btn('btnShowMarks', 'Show/Hide', $E8C1, False, TFmrButtonStyle.Check);
    Link(G, B, [TFmrViewLevel.Small], TFmrButtonGroupPosition.Member);
    G.ShowDialogLauncher := True;

    G := Home.AddGroup('Styles');
    G.Name := 'grpStyles';
    Style := TFmrComboItem(FManager.CreateItem(TFmrComboItem, 'cbStyle'));
    Style.Caption := 'Style';
    for S in ['Normal', 'No Spacing', 'Heading 1', 'Heading 2', 'Title'] do
      Style.Items.Add(S);
    Style.ItemIndex := 0;
    Style.Width := 110;
    Link(G, Style, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
    for S in ['Heading 1', 'Heading 2', 'Title'] do
    begin
      B := Btn('btnStyle' + S.Replace(' ', ''), S, 0, False, TFmrButtonStyle.Check);
      B.GroupIndex := 2;
      B.Glyph.PathData := PathStyle;
      B.Glyph.PathViewBox := 24;
      Link(G, B, [TFmrViewLevel.SmallWithText]);
    end;

    G := Home.AddGroup('Editing');
    G.Name := 'grpEditing';
    B := Btn('btnFind', 'Find', $E721, False, TFmrButtonStyle.Split);
    B.ShortCut := scCtrl or Ord('F');
    B.DropDownLinks.AddItem(Btn('btnFindAdv', 'Advanced Find...', $E721));
    Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
    B := Btn('btnReplace', 'Replace', $E8AB);
    Link(G, B, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
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
    G := Insert.AddGroup('Pages');
    G.Name := 'grpPages';
    Link(G, Btn('btnCoverPage', 'Cover Page', $E8A5, True, TFmrButtonStyle.DropDown),
      [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnBlankPage', 'Blank Page', $E7C3, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    G := Insert.AddGroup('Tables');
    G.Name := 'grpTables';
    FShowTableTools := Btn('btnTableTools', 'Table Tools', 0, False, TFmrButtonStyle.Check);
    FShowTableTools.LargeGlyph.PathData := PathTable;
    FShowTableTools.LargeGlyph.PathViewBox := 24;
    FShowTableTools.Glyph.PathData := PathTable;
    FShowTableTools.Glyph.PathViewBox := 24;
    FShowTableTools.OnClick := TableToolsClick;
    Link(G, FShowTableTools, [TFmrViewLevel.Large]);
    G := Insert.AddGroup('Illustrations');
    G.Name := 'grpIllustrations';
    Link(G, Btn('btnPictures', 'Pictures', $E8B9, True), [TFmrViewLevel.Large]);
    Link(G, PathGlyph(Btn('btnShapes', 'Shapes', 0, False, TFmrButtonStyle.DropDown), PathShapes));
    Link(G, Btn('btnIcons', 'Icons', $E76E));
    G := Insert.AddGroup('Links');
    G.Name := 'grpLinks';
    Link(G, Btn('btnLink', 'Link', $E71B, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnBookmark', 'Bookmark', $E8A4, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnComment', 'Comment', $E90A, True), [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);

    { Layout }
    LayoutTab := FRibbon.AddTab('Layout', 'tabLayout');
    G := LayoutTab.AddGroup('Page Setup');
    G.Name := 'grpPageSetup';
    B := TFmrButtonItem(PathGlyph(Btn('btnMargins', 'Margins', 0, False, TFmrButtonStyle.DropDown), PathMargins));
    B.LargeGlyph.PathData := PathMargins;
    B.LargeGlyph.PathViewBox := 24;
    Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnOrientation', 'Orientation', $E7AD, True, TFmrButtonStyle.DropDown),
      [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    Link(G, Btn('btnSize', 'Size', $E740, True, TFmrButtonStyle.DropDown), [TFmrViewLevel.Large,
      TFmrViewLevel.SmallWithText]);

    { View }
    View := FRibbon.AddTab('View', 'tabView');
    G := View.AddGroup('Show');
    G.Name := 'grpShow';
    for S in ['Ruler', 'Gridlines', 'Navigation Pane'] do
    begin
      Check := TFmrCheckItem(FManager.CreateItem(TFmrCheckItem, 'chk' + S.Replace(' ', '')));
      Check.Caption := S;
      Check.Checked := S = 'Ruler';
      Check.OnClick := CommandClick;
      Link(G, Check);
    end;
    G := View.AddGroup('Zoom');
    G.Name := 'grpZoom';
    Link(G, Btn('btnZoom', 'Zoom', $E71E, True), [TFmrViewLevel.Large]);
    Track := TFmrTrackBarItem(FManager.CreateItem(TFmrTrackBarItem, 'tbZoom'));
    Track.Caption := 'Zoom';
    Track.Min := 10;
    Track.Max := 500;
    Track.Value := 100;
    Track.Width := 110;
    Link(G, Track, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small], TFmrButtonGroupPosition.None, True);
    G := View.AddGroup('Customize');
    G.Name := 'grpCustomize';
    B := TFmrButtonItem(FManager.FindItem('btnCustomize'));
    B.LargeGlyph.GlyphCode := $E713;
    Link(G, B, [TFmrViewLevel.Large]);

    { contextual tabs }
    FTableTools := FRibbon.AddContextGroup('Table Tools', TAlphaColor($FFD08A2E), 'ctxTable');
    TDesign := FRibbon.AddTab('Table Design', 'tabTableDesign');
    TDesign.ContextGroup := FTableTools;
    G := TDesign.AddGroup('Table Styles');
    G.Name := 'grpTableStyles';
    for I := 1 to 3 do
    begin
      B := Btn('btnTableStyle' + IntToStr(I), 'Style ' + IntToStr(I), 0, False, TFmrButtonStyle.Check);
      B.GroupIndex := 4;
      B.LargeGlyph.PathData := PathTable;
      B.LargeGlyph.PathViewBox := 24;
      Link(G, B, [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText]);
    end;
  finally
    FRibbon.EndStructureUpdate;
    FManager.EndUpdate;
  end;
end;

procedure TCustomizeDemoForm.AssignCategories;
var
  T: TFmrRibbonTab;
  I, J: Integer;
  Item: TFmrBarItem;
begin
  // Every command gets the caption of the first tab that shows it as its category ("Choose commands from").
  for T in TFmrRibbonStructure.Tabs(FRibbon) do
    for I := 0 to T.GroupCount - 1 do
      for J := 0 to T.Groups[I].ItemLinks.Count - 1 do
      begin
        Item := T.Groups[I].ItemLinks[J].Item;
        if (Item <> nil) and (Item.Category = '') then
          Item.Category := T.Caption;
      end;
end;

procedure TCustomizeDemoForm.ApplyCommandLine;
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
    else if S = '/open' then
      FOpen := V.ToLower
    else if S = '/rtl' then
      FRibbon.RightToLeft := True
    else if S = '/autohide' then
      FRibbon.ShowMode := TFmrRibbonShowMode.AutoHide
    else if S = '/showautohide' then
      FShowAutoHide := True
    else if S = '/displayoptions' then
      FDisplayOptions := True
    else if S = '/simplified' then
      FRibbon.DisplayMode := TFmrRibbonDisplayMode.Simplified
    else if S = '/touch' then
      FRibbon.TouchMode := True
    else if S = '/switchtheme' then
      FSwitchTheme := V
    else if S = '/layout' then
      FRibbon.LoadLayoutFromFile(V)
    else if S = '/autofile' then
    begin
      TFmrRibbonCustomizeForm.AutoFileName := V;
      TFmrRibbonCustomizeForm.AutoConfirm := True;
    end
    else if S = '/dump' then
      FDumpFile := V
    else if S = '/dumpcust' then
      FDumpCustFile := V
    else if S = '/savelayout' then
      FSaveLayout := V
    else if S = '/dropdown' then
      FDropDown := V
    else if S = '/keytips' then
      FKeyTips := True
    else if S = '/tabletools' then
    begin
      FTableTools.Visible := True;
      FShowTableTools.Down := True;
    end
    else if (S = '/tab') and TryStrToInt(V, N) and (N >= 0) and (N < FRibbon.TabCount) then
    begin
      if not FRibbon.Tabs(N).IsShown and (FRibbon.Tabs(N).ContextGroup <> nil) then
        FRibbon.Tabs(N).ContextGroup.Visible := True;
      FRibbon.ActiveTab := FRibbon.Tabs(N);
    end;
  end;
  if FDumpCustFile <> '' then
    TFmrRibbonCustomizeForm.OnShowHook :=
      procedure(AForm: TFmrRibbonCustomizeForm)
      var
        Dump: string;
      begin
        TThread.ForceQueue(nil,
          procedure
          begin
            Dump := AForm.DebugDump;
            TFile.WriteAllText(FDumpCustFile, Dump);
          end, 600);
      end;
end;

procedure TCustomizeDemoForm.SetStatus(const AText: string);
begin
  FStatus.Text := AText;
end;

procedure TCustomizeDemoForm.CommandClick(Sender: TObject);
begin
  SetStatus('Command: ' + FmrStripAccel(TFmrBarItem(Sender).Caption));
end;

procedure TCustomizeDemoForm.CustomizeClick(Sender: TObject);
begin
  TThread.ForceQueue(nil,
    procedure
    begin
      if FRibbon.ShowCustomizationForm then
        SetStatus('Customization applied')
      else
        SetStatus('Customization cancelled');
    end);
end;

procedure TCustomizeDemoForm.TableToolsClick(Sender: TObject);
begin
  if FShowTableTools.Down then
    FTableTools.Activate
  else
    FTableTools.Visible := False;
end;

function TCustomizeDemoForm.InvokeById(const AId: string): Boolean;
var
  N: TFmrAccNode;
begin
  // The accessibility snapshot doubles as a way to "click" any ribbon element by its id.
  for N in FRibbon.AccessibilityNodes do
    if (N.Element <> nil) and SameText(N.AutomationId, AId) then
      Exit(FRibbon.AccessibilityInvoke(N.Element));
  Result := False;
end;

procedure TCustomizeDemoForm.TimerTick(Sender: TObject);
begin
  Inc(FTicks);
  if FTicks = 1 then
  begin
    if FDumpFile <> '' then
      TFile.WriteAllText(FDumpFile, FRibbon.DebugDump);
    if FShowAutoHide then
      FRibbon.ShowAutoHiddenRibbon;
    if FKeyTips then
      FRibbon.ShowKeyTipsNow;
    if FDisplayOptions then
      InvokeById('DisplayOptions');
    if (FDropDown <> '') and not InvokeById(FDropDown) then
      SetStatus('No ribbon element ' + FDropDown);
    if FOpen <> '' then
    begin
      FTimer.Enabled := False;
      if FOpen = 'qat' then
        FRibbon.ShowCustomizationForm(TFmrCustomizationPage.QuickAccessToolbar)
      else
        FRibbon.ShowCustomizationForm(TFmrCustomizationPage.Ribbon);
      FTimer.Enabled := True;
    end;
  end;
  if (FTicks = 2) and (FSwitchTheme <> '') then
    FRibbon.Theme := FSwitchTheme;
  if FTicks >= 3 then
    FTimer.Enabled := False;
end;

end.
