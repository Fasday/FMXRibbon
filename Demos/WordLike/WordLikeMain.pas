{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  FMR Write: a Word-like showcase application          }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit WordLikeMain;

/// The main form of FMR Write. Everything visible is streamed from WordLikeMain.fmx, exactly like a form designed
/// in the IDE: the bar manager with its items, the ribbon with tabs, groups, links, the contextual "Selection
/// Tools" group and the quick access toolbar, the window frame, the backstage view with its tabs and content, the
/// status bar, the document page, the find panel, the mini toolbar and the context menu. The .fmx is written by
/// tools\GenForm (it builds the form in code with WordLikeBuild.pas and saves it with WriteComponent +
/// ObjectBinaryToText); this unit only declares the published fields and the event handlers the .fmx refers to.
///
/// Command line (for screenshots):
///   /theme=<name> /accent=RRGGBB /lang=ru /frame=fullnc|dwm|ncstrip /backdrop=mica|acrylic /zoom=N /tab=N
///   /backstage[=N] (open the backstage view on tab N) /select (select a paragraph: contextual tabs)
///   /find=<text> /simplified /touch /qatbelow /open=styles|themes|accent|table|shapes|symbols|fontcolor|
///   minitoolbar|context|customize|keytips /fresh (ignore saved settings and layout) /nosave
///   /docdir=<folder> (folder of Save As) /width=N /height=N /dumpfmx=<file> (the loaded form written back to text)
///   /dump=<file> (TFmrRibbon.DebugDump)

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections, System.Messaging,
  System.Math, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo, FMX.Memo.Types,
  FMX.StdCtrls, FMX.Edit, FMX.ListBox, FMX.Layouts, FMX.Objects, FMX.Effects, FMX.SpinBox, FMX.EditBox,
  FMX.ImgList, FMX.Controls.Presentation, FMX.ScrollBox, FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Theme, FMR.Ribbon.Painter, FMR.Ribbon, FMR.Ribbon.Gallery,
  FMR.Ribbon.ColorGallery, FMR.Ribbon.MiniToolbar, FMR.Ribbon.Popup, FMR.Ribbon.Backstage,
  FMR.Ribbon.Backstage.Controls, FMR.Ribbon.StatusBar, FMR.Frame.Types, FMR.Frame;

type
  /// <summary>The document memo (interposer: the .fmx stores a plain TMemo). A right click shows the mini toolbar
  /// with the context menu of the ribbon instead of the FMX context menu.</summary>
  TMemo = class(FMX.Memo.TMemo)
  private
    FOnContextPopup: TProc<TPointF>;
  public
    function ShowContextMenu(const ScreenPosition: TPointF): Boolean; override;
    property OnContextPopup: TProc<TPointF> read FOnContextPopup write FOnContextPopup;
  end;

  TDocState = record
    Text: string;
    SelStart: Integer;
    SelLength: Integer;
  end;

  TDocFont = record
    Family: string;
    Size: Single;
    Style: TFontStyles;
    Color: TAlphaColor;
  end;

  TViewMode = (Read, Print, Web);

  TWordLikeForm = class(TForm)
    Frame1: TFmrFormFrame;
    ImageList1: TImageList;
    BarManager1: TFmrBarManager;
    Ribbon1: TFmrRibbon;
    BackstageView1: TFmrRibbonBackstageView;
    StatusBar1: TFmrStatusBar;
    MiniToolbar1: TFmrRibbonMiniToolbar;
    ContextMenu1: TFmrPopupMenu;
    SelectionTimer: TTimer;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    { document }
    DocArea: TRectangle;
    Page: TRectangle;
    PageShadow: TShadowEffect;
    Memo: TMemo;
    Watermark: TText;
    FindPanel: TRectangle;
    edFind: TEdit;
    edReplace: TEdit;
    lblFind: TLabel;
    lblReplace: TLabel;
    lblFindResult: TLabel;
    { ribbon }
    ctxSelection: TFmrRibbonContextGroup;
    tabHome: TFmrRibbonTab;
    tabSelection: TFmrRibbonTab;
    btnSave: TFmrButtonItem;
    btnUndo: TFmrButtonItem;
    btnRedo: TFmrButtonItem;
    btnBold: TFmrButtonItem;
    btnItalic: TFmrButtonItem;
    btnUnderline: TFmrButtonItem;
    btnStrike: TFmrButtonItem;
    cbFontName: TFmrFontNameItem;
    cbFontSize: TFmrComboItem;
    clrFontColor: TFmrColorGalleryItem;
    btnAlignLeft: TFmrButtonItem;
    btnAlignCenter: TFmrButtonItem;
    btnAlignRight: TFmrButtonItem;
    btnJustify: TFmrButtonItem;
    galStyles: TFmrRibbonGalleryItem;
    galTable: TFmrRibbonGalleryItem;
    galShapes: TFmrGalleryItem;
    galSymbols: TFmrRibbonGalleryItem;
    galThemes: TFmrRibbonGalleryItem;
    galAccent: TFmrRibbonGalleryItem;
    btnShapes: TFmrButtonItem;
    btnReadMode: TFmrButtonItem;
    btnPrintLayout: TFmrButtonItem;
    btnWebLayout: TFmrButtonItem;
    chkStatusBar: TFmrCheckItem;
    chkWordWrap: TFmrCheckItem;
    chkFindPane: TFmrCheckItem;
    chkSimplified: TFmrCheckItem;
    chkTouch: TFmrCheckItem;
    btnLangEn: TFmrButtonItem;
    btnLangRu: TFmrButtonItem;
    clrPageColor: TFmrColorItem;
    btnPageBorders: TFmrButtonItem;
    spIndentLeft: TFmrSpinItem;
    spIndentRight: TFmrSpinItem;
    stSelInfo: TFmrStaticItem;
    { backstage }
    bsInfo: TFmrBackstageTab;
    bsNew: TFmrBackstageTab;
    bsOpen: TFmrBackstageTab;
    bsSaveAs: TFmrBackstageTab;
    bsPrint: TFmrBackstageTab;
    bsOptions: TFmrBackstageTab;
    bsAbout: TFmrBackstageTab;
    lblInfoTitle: TFmrBackstageLabel;
    lblInfoPath: TFmrBackstageLabel;
    lblInfoWords: TFmrBackstageLabel;
    lblInfoChars: TFmrBackstageLabel;
    lblInfoLines: TFmrBackstageLabel;
    lblInfoPages: TFmrBackstageLabel;
    lblInfoProtect: TFmrBackstageLabel;
    lblInfoIssues: TFmrBackstageLabel;
    lblInfoHistory: TFmrBackstageLabel;
    tileProtect: TFmrBackstageTile;
    lstRecent: TFmrBackstageGalleryList;
    lblSaveFolder: TFmrBackstageLabel;
    edSaveName: TEdit;
    cbSaveFormat: TComboBox;
    spCopies: TSpinBox;
    cbPrinter: TComboBox;
    imgPreview: TImage;
    lblPrintInfo: TFmrBackstageLabel;
    lblAboutTitle: TFmrBackstageLabel;
    cbOptTheme: TComboBox;
    cbOptAccent: TComboBox;
    cbOptFrame: TComboBox;
    cbOptBackdrop: TComboBox;
    cbOptLanguage: TComboBox;
    chkOptSimplified: TCheckBox;
    chkOptTouch: TCheckBox;
    chkOptQATBelow: TCheckBox;
    chkOptSearch: TCheckBox;
    chkOptScreenTips: TCheckBox;
    { status bar }
    spPage: TFmrStatusBarPanel;
    spWords: TFmrStatusBarPanel;
    spChars: TFmrStatusBarPanel;
    spLanguage: TFmrStatusBarPanel;
    spMessage: TFmrStatusBarPanel;
    spView: TFmrStatusBarPanel;
    spZoom: TFmrStatusBarPanel;
    { form }
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    { file }
    procedure NewClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure PrintClick(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    { Home }
    procedure PasteClick(Sender: TObject);
    procedure PasteTextClick(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure ClipboardLauncherClick(Sender: TObject);
    procedure FontLauncherClick(Sender: TObject);
    procedure FontNameChange(Sender: TObject);
    procedure FontSizeChange(Sender: TObject);
    procedure GrowFontClick(Sender: TObject);
    procedure ShrinkFontClick(Sender: TObject);
    procedure FontStyleClick(Sender: TObject);
    procedure ChangeCaseClick(Sender: TObject);
    procedure FontColorClick(Sender: TObject);
    procedure FontColorPreview(Sender: TObject; const AColor: TAlphaColor; const AActive: Boolean);
    procedure ClearFormattingClick(Sender: TObject);
    procedure BulletsClick(Sender: TObject);
    procedure NumberingClick(Sender: TObject);
    procedure IndentClick(Sender: TObject);
    procedure SortClick(Sender: TObject);
    procedure AlignClick(Sender: TObject);
    procedure StylesDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure StylesHotTrack(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure StylesItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure FindClick(Sender: TObject);
    procedure ReplaceClick(Sender: TObject);
    procedure SelectAllClick(Sender: TObject);
    { find panel }
    procedure FindNextClick(Sender: TObject);
    procedure FindPrevClick(Sender: TObject);
    procedure ReplaceOneClick(Sender: TObject);
    procedure ReplaceAllClick(Sender: TObject);
    procedure FindCloseClick(Sender: TObject);
    procedure FindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    { Insert }
    procedure InsertTextClick(Sender: TObject);
    procedure InsertTableClick(Sender: TObject);
    procedure TableDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure TableItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure ShapesItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure SymbolDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure SymbolItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    { Layout }
    procedure MarginsClick(Sender: TObject);
    procedure OrientationClick(Sender: TObject);
    procedure PageSizeClick(Sender: TObject);
    procedure WatermarkClick(Sender: TObject);
    procedure PageColorClick(Sender: TObject);
    procedure PageBordersClick(Sender: TObject);
    procedure IndentSpinChange(Sender: TObject);
    { View }
    procedure ViewModeClick(Sender: TObject);
    procedure ShowCheckClick(Sender: TObject);
    procedure ZoomClick(Sender: TObject);
    procedure ThemeDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure ThemeItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure AccentDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
      const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
      var AHandled: Boolean);
    procedure AccentItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
    procedure RibbonOptionClick(Sender: TObject);
    procedure LanguageClick(Sender: TObject);
    procedure CustomizeClick(Sender: TObject);
    procedure ResetRibbonClick(Sender: TObject);
    { Selection Tools }
    procedure DeleteSelClick(Sender: TObject);
    procedure QuoteClick(Sender: TObject);
    procedure TrimClick(Sender: TObject);
    procedure ReverseLinesClick(Sender: TObject);
    { ribbon }
    procedure RibbonSearch(Sender: TObject; const AText: string);
    procedure RibbonDisplayModeChanged(Sender: TObject);
    { backstage }
    procedure BackstageShow(Sender: TObject);
    procedure BackstageTabChanged(Sender: TObject);
    procedure TemplateTileClick(Sender: TObject);
    procedure RecentItemClick(Sender: TObject; const AItem: TFmrBackstageGalleryItem);
    procedure BrowseOpenClick(Sender: TObject);
    procedure BrowseSaveClick(Sender: TObject);
    procedure SaveAsGoClick(Sender: TObject);
    procedure PrintTileClick(Sender: TObject);
    procedure ProtectTileClick(Sender: TObject);
    procedure InspectTileClick(Sender: TObject);
    procedure HistoryTileClick(Sender: TObject);
    procedure CloseDocClick(Sender: TObject);
    procedure OptComboChange(Sender: TObject);
    procedure OptCheckChange(Sender: TObject);
    { status bar }
    procedure StatusViewChange(Sender: TObject);
    procedure StatusZoomChange(Sender: TObject);
    procedure StatusZoomClick(Sender: TObject);
    procedure StatusLanguageClick(Sender: TObject);
    procedure StatusWordsClick(Sender: TObject);
    { document }
    procedure MemoChangeTracking(Sender: TObject);
    procedure MemoKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure MemoMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure MemoApplyStyleLookup(Sender: TObject);
    procedure SelectionTimerTimer(Sender: TObject);
    procedure DocAreaResize(Sender: TObject);
  private
    FFont: TDocFont;
    FAlign: TTextAlign;
    FZoom: Integer;
    FAppliedStyle: Integer;
    FUndo: TList<TDocState>;
    FRedo: TList<TDocState>;
    FLastState: TDocState;
    FTypingTick: Cardinal;
    FProgrammatic: Boolean;
    FFileName: string;
    FDocName: string;
    FDocCounter: Integer;
    FModified: Boolean;
    FUpdatingUI: Boolean;
    FTextVersion: Integer;
    FShownVersion: Integer;
    FLastSelKey: string;
    FThemes: TObjectDictionary<string, TFmrTheme>;
    FThemeNames: TArray<string>;
    FAccent: TAlphaColor;
    FEnglish: TDictionary<string, string>;
    FLanguage: string;
    FViewMode: TViewMode;
    FPageSize: TSizeF;
    FLandscape: Boolean;
    FMarginIndex: Integer;
    FPageColor: TAlphaColor;
    FProtected: Boolean;
    FRecent: TStringList;
    FSettingsDir: string;
    FDocDir: string;
    FFresh: Boolean;
    FNoSave: Boolean;
    FThemeMsgId: TMessageSubscriptionId;
    FStartActions: TStringList;
    { state and formatting }
    function CurrentState: TDocState;
    procedure RestoreState(const AState: TDocState);
    procedure ChangeText(const AText: string; const ASelStart, ASelLength: Integer);
    procedure ReplaceSelection(const AText: string; const ASelectInserted: Boolean = False);
    procedure InsertAtCaret(const AText: string; const AOwnLine: Boolean);
    procedure TransformSelection(const AFunc: TFunc<string, string>; const AWholeLines: Boolean);
    procedure SelectedLineRange(out AStart, AEnd: Integer);
    procedure ResetHistory;
    procedure MarkModified;
    procedure ApplyFormat;
    procedure PreviewFont(const AFont: TDocFont);
    procedure UpdateFormatUI;
    procedure ApplyStyle(const AIndex: Integer);
    procedure SetZoom(const AValue: Integer);
    procedure SetViewMode(const AMode: TViewMode);
    procedure LayoutPage;
    procedure UpdateStatus;
    procedure UpdateSelectionInfo;
    procedure UpdateUndoUI;
    procedure UpdateCaption;
    procedure SetMessage(const AText: string);
    { find }
    procedure ShowFindPanel(const AReplace: Boolean);
    function FindText(const AForward: Boolean; const AQuiet: Boolean = False): Boolean;
    { documents }
    procedure NewDocument(const ATemplate: Integer);
    procedure OpenFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    procedure AddRecent(const AFileName: string);
    procedure FillRecent;
    procedure UpdateInfoPage;
    procedure UpdatePrintPreview;
    procedure FillPrinters;
    function DocumentFolder: string;
    { themes, language, options }
    procedure FillThemeGallery;
    procedure FillOptionCombos;
    procedure ApplyTheme(const AName: string; const AAccent: TAlphaColor);
    procedure ThemeChangedHandler(const Sender: TObject; const M: TMessage);
    procedure ApplyThemeColors;
    procedure SyncOptions;
    procedure SetLanguage(const ACode: string);
    procedure CaptureEnglish;
    procedure ApplyLanguage;
    procedure SetComponentText(const AComponent: TComponent; const AText: string; const ADescription: Boolean);
    function L(const AEnglish, ARussian: string): string;
    function ThemeFor(const AName: string): TFmrTheme;
    procedure SetFrameMode(const AIndex: Integer);
    { settings }
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ParseCommandLine;
    procedure RunStartActions;
    procedure ShowCustomization;
    procedure OpenDropDown(const AItem: TFmrBarItem; const ATab: TFmrRibbonTab);
    procedure DumpForm(const AFileName: string);
  end;

var
  WordLikeForm: TWordLikeForm;

implementation

{$IFNDEF WORDLIKE_GEN}
{$R *.fmx}
{$ENDIF}

uses
  System.IOUtils, System.IniFiles, System.StrUtils, System.Character, FMX.Platform, FMX.Printer,
  FMR.Ribbon.Views, FMR.Ribbon.Strings, WordLikeData, WordLikeLang;

const
  PointToDp = 96 / 72;
  PageSizes: array [0..2] of TSizeF = ((cx: 816; cy: 1056), (cx: 794; cy: 1123), (cx: 559; cy: 794));
  MarginSizes: array [0..3] of TRectF = ((Left: 96; Top: 96; Right: 96; Bottom: 96),
    (Left: 48; Top: 48; Right: 48; Bottom: 48), (Left: 72; Top: 96; Right: 72; Bottom: 96),
    (Left: 192; Top: 96; Right: 192; Bottom: 96));
  WatermarkTexts: array [0..3] of string = ('', 'DRAFT', 'CONFIDENTIAL', 'SAMPLE');
  FrameModes: array [0..2] of TFmrFrameMode = (TFmrFrameMode.FullNC, TFmrFrameMode.Dwm, TFmrFrameMode.NCStrip);
  Backdrops: array [0..3] of TFmrFrameBackdrop = (TFmrFrameBackdrop.None, TFmrFrameBackdrop.Mica,
    TFmrFrameBackdrop.Acrylic, TFmrFrameBackdrop.Tabbed);

{ TMemo }

function TMemo.ShowContextMenu(const ScreenPosition: TPointF): Boolean;
begin
  Result := Assigned(FOnContextPopup);
  if Result then
    FOnContextPopup(ScreenPosition);
end;

{ helpers }

function WordCount(const S: string): Integer;
var
  I: Integer;
  InWord: Boolean;
begin
  Result := 0;
  InWord := False;
  for I := 1 to Length(S) do
    if S[I].IsWhiteSpace then
      InWord := False
    else if not InWord then
    begin
      InWord := True;
      Inc(Result);
    end;
end;

function TitleCase(const S: string): string;
var
  I: Integer;
  Start: Boolean;
begin
  Result := S.ToLower;
  Start := True;
  for I := 1 to Length(Result) do
  begin
    if Start and Result[I].IsLetter then
      Result[I] := Result[I].ToUpper;
    Start := not Result[I].IsLetterOrDigit and (Result[I] <> '''');
  end;
end;

function SentenceCase(const S: string): string;
var
  I: Integer;
  Start: Boolean;
begin
  Result := S.ToLower;
  Start := True;
  for I := 1 to Length(Result) do
  begin
    if Start and Result[I].IsLetter then
    begin
      Result[I] := Result[I].ToUpper;
      Start := False;
    end
    else if CharInSet(Result[I], ['.', '!', '?', #10]) then
      Start := True;
  end;
end;

function ToggleCase(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I].IsUpper then
      Result[I] := Result[I].ToLower
    else
      Result[I] := Result[I].ToUpper;
end;

function BuildTable(const ACols, ARows: Integer): string;
const
  CellWidth = 6;
var
  R: Integer;

  // Box drawing characters only: a font has them all with the same width, so the grid stays aligned in the
  // proportional font of the document (the empty cells hold dashed lines).
  function Border(const ALeft, AMiddle, ARight: Char): string;
  var
    C: Integer;
  begin
    Result := ALeft;
    for C := 1 to ACols do
    begin
      Result := Result + StringOfChar('─', CellWidth);
      if C < ACols then
        Result := Result + AMiddle
      else
        Result := Result + ARight;
    end;
  end;

  function Row(const AFill: Char): string;
  var
    C: Integer;
  begin
    Result := '│';
    for C := 1 to ACols do
      Result := Result + StringOfChar(AFill, CellWidth) + '│';
  end;

begin
  Result := Border('┌', '┬', '┐');
  for R := 1 to ARows do
  begin
    if R = 1 then
      Result := Result + sLineBreak + Row('┅')
    else
      Result := Result + sLineBreak + Row('┄');
    if R < ARows then
      Result := Result + sLineBreak + Border('├', '┼', '┤');
  end;
  Result := Result + sLineBreak + Border('└', '┴', '┘');
end;

procedure FillRoundRect(const ACanvas: TCanvas; const ARect: TRectF; const AColor: TAlphaColor;
  const ARadius: Single = 0);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AColor;
  ACanvas.FillRect(ARect, ARadius, ARadius, AllCorners, 1);
end;

{ TWordLikeForm: form }

procedure TWordLikeForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  FUndo := TList<TDocState>.Create;
  FRedo := TList<TDocState>.Create;
  FThemes := TObjectDictionary<string, TFmrTheme>.Create([doOwnsValues]);
  FEnglish := TDictionary<string, string>.Create;
  FRecent := TStringList.Create;
  FStartActions := TStringList.Create;
  FLanguage := 'en';
  FZoom := 100;
  FAppliedStyle := 0;
  FMarginIndex := 0;
  FViewMode := TViewMode.Print;
  FPageSize := PageSizes[1];
  FPageColor := TAlphaColors.White;
  FDocName := 'Document1';
  FSettingsDir := TPath.Combine(TPath.GetHomePath, 'FMRWrite');
  FDocDir := TPath.Combine(TPath.GetDocumentsPath, 'FMR Write');
  ParseCommandLine;
  if FStartActions.Values['dumpfmx'] <> '' then
    DumpForm(FStartActions.Values['dumpfmx']);

  FThemeMsgId := TMessageManager.DefaultManager.SubscribeToMessage(TFmrThemeChangedMessage, ThemeChangedHandler);
  Memo.OnContextPopup :=
    procedure(AScreenPoint: TPointF)
    begin
      MiniToolbar1.Popup(AScreenPoint, True);
    end;
  // which canvas paints the window: Direct2D by default, TFastCanvas when built with FMR_FASTCANVAS
  lblAboutTitle.Text := Format('FMR Write  -  %s, %d-bit', [TCanvasManager.DefaultCanvas.ClassName,
    SizeOf(Pointer) * 8]);
  CaptureEnglish;
  FillThemeGallery;
  FillOptionCombos;
  FillRecent;
  FFont.Family := Memo.TextSettings.Font.Family;
  FFont.Size := Round(Memo.TextSettings.Font.Size / PointToDp);
  FFont.Style := Memo.TextSettings.Font.Style;
  FFont.Color := Memo.TextSettings.FontColor;
  FAlign := TTextAlign.Leading;
  FAccent := Ribbon1.AccentColor;

  if not FFresh then
  begin
    LoadSettings;
    // The ribbon captured its designed layout at Loaded (DefaultLayout): Reset Ribbon goes back to it.
    if TFile.Exists(TPath.Combine(FSettingsDir, 'layout.json')) then
      try
        Ribbon1.LoadLayoutFromFile(TPath.Combine(FSettingsDir, 'layout.json'));
      except
        on E: Exception do
          SetMessage('Layout not loaded: ' + E.Message);
      end;
  end;

  // command line overrides
  if FStartActions.Values['theme'] <> '' then
    ApplyTheme(FStartActions.Values['theme'], FAccent);
  if FStartActions.Values['accent'] <> '' then
    ApplyTheme(Ribbon1.Theme, TAlphaColor($FF000000 or Cardinal(StrToIntDef('$' + FStartActions.Values['accent'],
      0))));
  if FStartActions.Values['lang'] <> '' then
    SetLanguage(FStartActions.Values['lang']);
  if FStartActions.Values['frame'] <> '' then
    SetFrameMode(IndexText(FStartActions.Values['frame'], ['fullnc', 'dwm', 'ncstrip']));
  I := IndexText(FStartActions.Values['backdrop'], ['none', 'mica', 'acrylic', 'tabbed']);
  if I > 0 then
  begin
    SetFrameMode(1);
    Frame1.Backdrop := Backdrops[I];
  end;
  if FStartActions.IndexOf('simplified') >= 0 then
    Ribbon1.DisplayMode := TFmrRibbonDisplayMode.Simplified;
  if FStartActions.IndexOf('touch') >= 0 then
    Ribbon1.TouchMode := True;
  if FStartActions.IndexOf('qatbelow') >= 0 then
    Ribbon1.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon;
  if FStartActions.Values['zoom'] <> '' then
    FZoom := EnsureRange(StrToIntDef(FStartActions.Values['zoom'], 100), 10, 500);
  if FStartActions.Values['width'] <> '' then
    Width := StrToIntDef(FStartActions.Values['width'], Width);
  if FStartActions.Values['height'] <> '' then
    Height := StrToIntDef(FStartActions.Values['height'], Height);
  if FStartActions.Values['tab'] <> '' then
  begin
    I := StrToIntDef(FStartActions.Values['tab'], 0);
    if (I >= 0) and (I < Ribbon1.TabCount) and Ribbon1.Tabs(I).IsShown then
      Ribbon1.ActiveTab := Ribbon1.Tabs(I);
  end;

  ApplyThemeColors;
  SyncOptions;
  ApplyFormat;
  UpdateFormatUI;
  spZoom.Zoom := FZoom;
  LayoutPage;
  ResetHistory;
  UpdateCaption;
  UpdateStatus;
  SetMessage(L('Ready', 'Готово'));
  if FStartActions.Count > 0 then
    TThread.ForceQueue(nil, RunStartActions, 900);
end;

procedure TWordLikeForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FNoSave then
    Exit;
  try
    ForceDirectories(FSettingsDir);
    Ribbon1.SaveLayoutToFile(TPath.Combine(FSettingsDir, 'layout.json'));
    SaveSettings;
  except
    // settings are a convenience: never block closing
  end;
end;

procedure TWordLikeForm.FormDestroy(Sender: TObject);
begin
  TMessageManager.DefaultManager.Unsubscribe(TFmrThemeChangedMessage, FThemeMsgId);
  FStartActions.Free;
  FRecent.Free;
  FEnglish.Free;
  FThemes.Free;
  FRedo.Free;
  FUndo.Free;
end;

procedure TWordLikeForm.ParseCommandLine;
var
  I: Integer;
  S, N, V: string;
begin
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if not (S.StartsWith('/') or S.StartsWith('-')) then
      Continue;
    S := S.Substring(1);
    if S.Contains('=') then
    begin
      N := S.Substring(0, S.IndexOf('=')).ToLower;
      V := S.Substring(S.IndexOf('=') + 1);
    end
    else
    begin
      N := S.ToLower;
      V := '';
    end;
    if N = 'fresh' then
      FFresh := True
    else if N = 'nosave' then
      FNoSave := True
    else if N = 'docdir' then
      FDocDir := V
    else if N = 'settingsdir' then
      FSettingsDir := V
    else if V = '' then
      FStartActions.Add(N)
    else
      FStartActions.Values[N] := V;
  end;
end;

procedure TWordLikeForm.RunStartActions;
var
  Open: string;
  I: Integer;
begin
  if FStartActions.Values['dump'] <> '' then
    TFile.WriteAllText(FStartActions.Values['dump'], Ribbon1.DebugDump);
  if FStartActions.Values['find'] <> '' then
  begin
    ShowFindPanel(False);
    edFind.Text := FStartActions.Values['find'];
    FindText(True);
  end;
  if FStartActions.IndexOf('select') >= 0 then
  begin
    I := Memo.Text.IndexOf('FMR Write');
    Memo.SetFocus;
    Memo.SelStart := Max(0, I);
    Memo.SelLength := 33;
    SelectionTimerTimer(nil);
  end;
  if (FStartActions.IndexOf('backstage') >= 0) or (FStartActions.Values['backstage'] <> '') then
  begin
    I := StrToIntDef(FStartActions.Values['backstage'], 0);
    if (I >= 0) and (I < BackstageView1.TabCount) then
      BackstageView1.ActiveTab := BackstageView1.Tabs[I];
    BackstageView1.Animation := TFmrBackstageAnimation.None;
    BackstageView1.ShowApplicationMenu(Ribbon1, Ribbon1.ApplicationButtonScreenRect, False);
  end;
  Open := FStartActions.Values['open'].ToLower;
  if FStartActions.IndexOf('keytips') >= 0 then
    Open := 'keytips';
  if Open = 'styles' then
    OpenDropDown(galStyles, tabHome)
  else if Open = 'fontcolor' then
    OpenDropDown(clrFontColor, tabHome)
  else if Open = 'table' then
    OpenDropDown(galTable, nil)
  else if Open = 'shapes' then
    OpenDropDown(btnShapes, nil)
  else if Open = 'symbols' then
    OpenDropDown(galSymbols, nil)
  else if Open = 'themes' then
    OpenDropDown(galThemes, nil)
  else if Open = 'accent' then
    OpenDropDown(galAccent, nil)
  else if Open = 'context' then
    MiniToolbar1.Popup(Memo.LocalToScreen(PointF(Memo.Width * 0.4, 140)), True)
  else if Open = 'minitoolbar' then
    MiniToolbar1.Popup(Memo.LocalToScreen(PointF(Memo.Width * 0.4, 140)), True)
  else if Open = 'customize' then
    CustomizeClick(nil)
  else if Open = 'keytips' then
    Ribbon1.ShowKeyTipsNow;
end;

procedure TWordLikeForm.OpenDropDown(const AItem: TFmrBarItem; const ATab: TFmrRibbonTab);
var
  I: Integer;
  Tab: TFmrRibbonTab;
  V: TFmrItemView;
begin
  // The view of the first visible link opens its drop-down exactly like a mouse press.
  Tab := ATab;
  if Tab = nil then
    for I := 0 to AItem.LinkCount - 1 do
      if AItem.Links[I].LinksOwner is TFmrRibbonGroup then
      begin
        Tab := TFmrRibbonGroup(AItem.Links[I].LinksOwner).Tab;
        Break;
      end;
  if Tab <> nil then
    Ribbon1.ActiveTab := Tab;
  Ribbon1.UpdateLayout;
  for I := 0 to AItem.LinkCount - 1 do
    if AItem.Links[I].ViewObject is TFmrItemView then
    begin
      V := TFmrItemView(AItem.Links[I].ViewObject);
      if V.Host <> nil then
      begin
        V.Host.ElementDropDown(V, False);
        Exit;
      end;
    end;
end;

procedure TWordLikeForm.DumpForm(const AFileName: string);
var
  Bin: TMemoryStream;
  Txt: TStringStream;
begin
  // Writes the form as it was loaded from the .fmx (before FormCreate changed anything): comparing this file with
  // WordLikeMain.fmx shows properties that do not survive streaming.
  Bin := TMemoryStream.Create;
  Txt := TStringStream.Create('', TEncoding.UTF8);
  try
    Bin.WriteComponent(Self);
    Bin.Position := 0;
    ObjectBinaryToText(Bin, Txt);
    TFile.WriteAllText(AFileName, Txt.DataString, TEncoding.UTF8);
  finally
    Txt.Free;
    Bin.Free;
  end;
end;

{ TWordLikeForm: document state, undo/redo }

function TWordLikeForm.CurrentState: TDocState;
begin
  Result.Text := Memo.Text;
  Result.SelStart := Memo.SelStart;
  Result.SelLength := Memo.SelLength;
end;

procedure TWordLikeForm.RestoreState(const AState: TDocState);
begin
  FProgrammatic := True;
  try
    Memo.Text := AState.Text;
    Memo.SelStart := Min(AState.SelStart, Length(AState.Text));
    Memo.SelLength := AState.SelLength;
  finally
    FProgrammatic := False;
  end;
  Inc(FTextVersion);
end;

procedure TWordLikeForm.ChangeText(const AText: string; const ASelStart, ASelLength: Integer);
begin
  // Every change made by a command is one undo step.
  FUndo.Add(CurrentState);
  FRedo.Clear;
  FProgrammatic := True;
  try
    Memo.Text := AText;
    Memo.SelStart := EnsureRange(ASelStart, 0, Length(AText));
    Memo.SelLength := Max(0, ASelLength);
  finally
    FProgrammatic := False;
  end;
  FLastState := CurrentState;
  FTypingTick := 0;
  Inc(FTextVersion);
  MarkModified;
  UpdateUndoUI;
end;

procedure TWordLikeForm.ReplaceSelection(const AText: string; const ASelectInserted: Boolean);
var
  S: string;
  P, N: Integer;
begin
  S := Memo.Text;
  P := Memo.SelStart;
  N := Memo.SelLength;
  if ASelectInserted then
    ChangeText(Copy(S, 1, P) + AText + Copy(S, P + N + 1, MaxInt), P, Length(AText))
  else
    ChangeText(Copy(S, 1, P) + AText + Copy(S, P + N + 1, MaxInt), P + Length(AText), 0);
end;

procedure TWordLikeForm.InsertAtCaret(const AText: string; const AOwnLine: Boolean);
var
  S, Ins: string;
  P, N: Integer;
begin
  S := Memo.Text;
  P := Memo.SelStart;
  N := Memo.SelLength;
  Ins := AText;
  if AOwnLine then
  begin
    if (P > 0) and (S[P] <> #10) then
      Ins := sLineBreak + Ins;
    if (P + N < Length(S)) and (S[P + N + 1] <> #13) then
      Ins := Ins + sLineBreak;
  end;
  ChangeText(Copy(S, 1, P) + Ins + Copy(S, P + N + 1, MaxInt), P + Length(Ins), 0);
  if Memo.CanFocus then
    Memo.SetFocus;
end;

procedure TWordLikeForm.SelectedLineRange(out AStart, AEnd: Integer);
var
  S: string;
begin
  // [AStart, AEnd) in 0-based text positions: the whole lines touched by the selection (without the last break).
  S := Memo.Text;
  AStart := Memo.SelStart;
  AEnd := Memo.SelStart + Memo.SelLength;
  if (AEnd > AStart) and (AEnd <= Length(S)) and (S[AEnd] = #10) then
    Dec(AEnd);
  while (AStart > 0) and (S[AStart] <> #10) do
    Dec(AStart);
  while (AEnd < Length(S)) and not CharInSet(S[AEnd + 1], [#13, #10]) do
    Inc(AEnd);
end;

procedure TWordLikeForm.TransformSelection(const AFunc: TFunc<string, string>; const AWholeLines: Boolean);
var
  S, Sel, NewText: string;
  A, B: Integer;
begin
  if Memo.ReadOnly then
  begin
    SetMessage(L('The document is read-only.', 'Документ доступен только для чтения.'));
    Exit;
  end;
  if AWholeLines then
    SelectedLineRange(A, B)
  else
  begin
    if Memo.SelLength = 0 then
      Memo.SelectWord;
    A := Memo.SelStart;
    B := A + Memo.SelLength;
  end;
  S := Memo.Text;
  Sel := Copy(S, A + 1, B - A);
  NewText := AFunc(Sel);
  if NewText <> Sel then
    ChangeText(Copy(S, 1, A) + NewText + Copy(S, B + 1, MaxInt), A, Length(NewText));
end;

procedure TWordLikeForm.ResetHistory;
begin
  FUndo.Clear;
  FRedo.Clear;
  FLastState := CurrentState;
  FTypingTick := 0;
  FModified := False;
  Inc(FTextVersion);
  UpdateUndoUI;
end;

procedure TWordLikeForm.MarkModified;
begin
  FModified := True;
end;

procedure TWordLikeForm.UndoClick(Sender: TObject);
var
  S: TDocState;
begin
  if FUndo.Count = 0 then
    Exit;
  FRedo.Add(CurrentState);
  S := FUndo.Last;
  FUndo.Delete(FUndo.Count - 1);
  RestoreState(S);
  FLastState := S;
  FTypingTick := 0;
  UpdateUndoUI;
  SetMessage(L('Undo', 'Отменено'));
end;

procedure TWordLikeForm.RedoClick(Sender: TObject);
var
  S: TDocState;
begin
  if FRedo.Count = 0 then
    Exit;
  FUndo.Add(CurrentState);
  S := FRedo.Last;
  FRedo.Delete(FRedo.Count - 1);
  RestoreState(S);
  FLastState := S;
  FTypingTick := 0;
  UpdateUndoUI;
  SetMessage(L('Redo', 'Возвращено'));
end;

procedure TWordLikeForm.UpdateUndoUI;
begin
  if btnUndo.Enabled <> (FUndo.Count > 0) then
    btnUndo.Enabled := FUndo.Count > 0;
  if btnRedo.Enabled <> (FRedo.Count > 0) then
    btnRedo.Enabled := FRedo.Count > 0;
end;

procedure TWordLikeForm.MemoChangeTracking(Sender: TObject);
var
  Now: Cardinal;
begin
  if FProgrammatic or (FUndo = nil) then
    Exit;
  // Typing: a pause of more than a second starts a new undo step.
  Now := TThread.GetTickCount;
  if (FTypingTick = 0) or (Now - FTypingTick > 1000) then
  begin
    FUndo.Add(FLastState);
    FRedo.Clear;
  end;
  FTypingTick := Now;
  FLastState := CurrentState;
  Inc(FTextVersion);
  MarkModified;
  UpdateUndoUI;
end;

procedure TWordLikeForm.MemoKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  // The memo has its own single-level undo; Ctrl+Z / Ctrl+Y use the document history instead.
  if (ssCtrl in Shift) and not (ssAlt in Shift) then
    if Key = vkZ then
    begin
      UndoClick(nil);
      Key := 0;
    end
    else if Key = vkY then
    begin
      RedoClick(nil);
      Key := 0;
    end;
end;

procedure TWordLikeForm.MemoMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  // Selecting text with the mouse shows the mini toolbar half transparent; it fades as the mouse goes away.
  if (Button = TMouseButton.mbLeft) and (Memo.SelLength > 0) then
    MiniToolbar1.Popup(Memo.LocalToScreen(PointF(X, Y)), False);
end;

procedure TWordLikeForm.MemoApplyStyleLookup(Sender: TObject);

  procedure HideBackground(const AObject: TFmxObject);
  var
    Child: TFmxObject;
  begin
    if AObject.Children = nil then
      Exit;
    for Child in AObject.Children do
    begin
      if SameText(Child.StyleName, 'background') and (Child is TControl) then
        TControl(Child).Opacity := 0
      else
        HideBackground(Child);
    end;
  end;

begin
  if FUndo = nil then
    Exit;
  // The memo is the text area of a white page: its own frame and background are not wanted.
  HideBackground(Memo);
end;

{ TWordLikeForm: formatting }

procedure TWordLikeForm.ApplyFormat;
begin
  PreviewFont(FFont);
end;

procedure TWordLikeForm.PreviewFont(const AFont: TDocFont);
begin
  Memo.TextSettings.BeginUpdate;
  try
    Memo.TextSettings.Font.Family := AFont.Family;
    Memo.TextSettings.Font.Size := Max(4, AFont.Size * PointToDp * FZoom / 100);
    Memo.TextSettings.Font.Style := AFont.Style;
    if (AFont.Color = TAlphaColors.Null) or (AFont.Color = 0) then
      Memo.TextSettings.FontColor := TAlphaColors.Black
    else
      Memo.TextSettings.FontColor := AFont.Color;
    Memo.TextSettings.HorzAlign := FAlign;
  finally
    Memo.TextSettings.EndUpdate;
  end;
end;

procedure TWordLikeForm.UpdateFormatUI;
begin
  FUpdatingUI := True;
  try
    cbFontName.Text := FFont.Family;
    cbFontSize.Text := FormatFloat('0.#', FFont.Size);
    btnBold.Down := TFontStyle.fsBold in FFont.Style;
    btnItalic.Down := TFontStyle.fsItalic in FFont.Style;
    btnUnderline.Down := TFontStyle.fsUnderline in FFont.Style;
    btnStrike.Down := TFontStyle.fsStrikeOut in FFont.Style;
    case FAlign of
      TTextAlign.Center: btnAlignCenter.Down := True;
      TTextAlign.Trailing: btnAlignRight.Down := True;
    else
      if not btnJustify.Down then
        btnAlignLeft.Down := True;
    end;
    if galStyles.SelectedIndex <> FAppliedStyle then
      galStyles.SelectedIndex := FAppliedStyle;
  finally
    FUpdatingUI := False;
  end;
end;

function StyleFont(const AIndex: Integer): TDocFont;
var
  St: TWriteStyle;
begin
  St := WriteStyles[EnsureRange(AIndex, 0, High(WriteStyles))];
  Result.Family := St.Family;
  Result.Size := St.Size;
  Result.Style := St.Style;
  if St.Color = 0 then
    Result.Color := TAlphaColors.Black
  else
    Result.Color := St.Color;
end;

procedure TWordLikeForm.ApplyStyle(const AIndex: Integer);
begin
  FAppliedStyle := EnsureRange(AIndex, 0, High(WriteStyles));
  FFont := StyleFont(FAppliedStyle);
  ApplyFormat;
  UpdateFormatUI;
end;

procedure TWordLikeForm.FontNameChange(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if FUpdatingUI or (Trim(cbFontName.Text) = '') then
    Exit;
  FFont.Family := Trim(cbFontName.Text);
  ApplyFormat;
  SetMessage(L('Font: ', 'Шрифт: ') + FFont.Family);
end;

procedure TWordLikeForm.FontSizeChange(Sender: TObject);
var
  V: Single;
begin
  if FUndo = nil then
    Exit;
  if FUpdatingUI then
    Exit;
  if TryStrToFloat(cbFontSize.Text.Replace(',', FormatSettings.DecimalSeparator).Replace('.',
    FormatSettings.DecimalSeparator), V) and (V >= 1) and (V <= 400) then
  begin
    FFont.Size := V;
    ApplyFormat;
  end
  else
    UpdateFormatUI;
end;

procedure TWordLikeForm.GrowFontClick(Sender: TObject);
const
  Sizes: array [0..15] of Single = (8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 60, 72, 96);
var
  I: Integer;
begin
  for I := 0 to High(Sizes) do
    if Sizes[I] > FFont.Size then
    begin
      FFont.Size := Sizes[I];
      Break;
    end;
  ApplyFormat;
  UpdateFormatUI;
end;

procedure TWordLikeForm.ShrinkFontClick(Sender: TObject);
const
  Sizes: array [0..15] of Single = (96, 72, 60, 48, 36, 28, 24, 20, 18, 16, 14, 12, 11, 10, 9, 8);
var
  I: Integer;
begin
  for I := 0 to High(Sizes) do
    if Sizes[I] < FFont.Size then
    begin
      FFont.Size := Sizes[I];
      Break;
    end;
  ApplyFormat;
  UpdateFormatUI;
end;

procedure TWordLikeForm.FontStyleClick(Sender: TObject);
var
  B: TFmrButtonItem;
  St: TFontStyle;
begin
  if FUpdatingUI then
    Exit;
  B := TFmrButtonItem(Sender);
  if B = btnBold then
    St := TFontStyle.fsBold
  else if B = btnItalic then
    St := TFontStyle.fsItalic
  else if B = btnUnderline then
    St := TFontStyle.fsUnderline
  else
    St := TFontStyle.fsStrikeOut;
  if B.Down then
    Include(FFont.Style, St)
  else
    Exclude(FFont.Style, St);
  ApplyFormat;
end;

procedure TWordLikeForm.FontColorClick(Sender: TObject);
begin
  if clrFontColor.Color = TAlphaColors.Null then
    FFont.Color := TAlphaColors.Black
  else
    FFont.Color := clrFontColor.Color;
  ApplyFormat;
  SetMessage(L('Font color: #', 'Цвет текста: #') + IntToHex(FFont.Color and $FFFFFF, 6));
end;

procedure TWordLikeForm.FontColorPreview(Sender: TObject; const AColor: TAlphaColor; const AActive: Boolean);
var
  F: TDocFont;
begin
  if AActive and (TAlphaColorRec(AColor).A > 0) then
  begin
    F := FFont;
    F.Color := AColor;
    PreviewFont(F);
  end
  else
    ApplyFormat;
end;

procedure TWordLikeForm.ClearFormattingClick(Sender: TObject);
begin
  FAlign := TTextAlign.Leading;
  btnAlignLeft.Down := True;
  ApplyStyle(0);
  SetMessage(L('Formatting cleared', 'Форматирование очищено'));
end;

procedure TWordLikeForm.FontLauncherClick(Sender: TObject);
var
  S: string;
begin
  S := Format('%s, %s pt', [FFont.Family, FormatFloat('0.#', FFont.Size)]);
  if TFontStyle.fsBold in FFont.Style then
    S := S + L(', bold', ', полужирный');
  if TFontStyle.fsItalic in FFont.Style then
    S := S + L(', italic', ', курсив');
  if TFontStyle.fsUnderline in FFont.Style then
    S := S + L(', underline', ', подчёркнутый');
  SetMessage(L('Font: ', 'Шрифт: ') + S + ', #' + IntToHex(FFont.Color and $FFFFFF, 6));
end;

procedure TWordLikeForm.ChangeCaseClick(Sender: TObject);
var
  Mode: Integer;
begin
  Mode := TComponent(Sender).Tag;
  TransformSelection(
    function(S: string): string
    begin
      case Mode of
        0: Result := SentenceCase(S);
        1: Result := S.ToLower;
        2: Result := S.ToUpper;
        3: Result := TitleCase(S);
      else
        Result := ToggleCase(S);
      end;
    end, False);
end;

procedure TWordLikeForm.AlignClick(Sender: TObject);
begin
  case TComponent(Sender).Tag of
    1: FAlign := TTextAlign.Center;
    2: FAlign := TTextAlign.Trailing;
  else
    FAlign := TTextAlign.Leading;
  end;
  ApplyFormat;
  if TComponent(Sender).Tag = 3 then
    SetMessage(L('TMemo has no justified text: shown aligned left', 'TMemo не умеет выравнивать по ширине: ' +
      'текст выровнен влево'));
end;

function MapLines(const S: string; const AFunc: TFunc<Integer, string, string>): string;
var
  Lines: TArray<string>;
  I: Integer;
begin
  Lines := S.Replace(#13#10, #10).Split([#10]);
  for I := 0 to High(Lines) do
    Lines[I] := AFunc(I, Lines[I]);
  Result := string.Join(sLineBreak, Lines);
end;

function AllLines(const S: string; const ATest: TFunc<string, Boolean>): Boolean;
var
  Line: string;
begin
  Result := True;
  for Line in S.Replace(#13#10, #10).Split([#10]) do
    if (Trim(Line) <> '') and not ATest(Line) then
      Exit(False);
end;

function IsNumbered(const ALine: string): Boolean;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(ALine)) and ALine[I].IsDigit do
    Inc(I);
  Result := (I > 1) and (I < Length(ALine)) and (ALine[I] = '.') and (ALine[I + 1] = ' ');
end;

procedure TWordLikeForm.BulletsClick(Sender: TObject);
begin
  TransformSelection(
    function(S: string): string
    var
      Remove: Boolean;
    begin
      Remove := AllLines(S,
        function(Line: string): Boolean
        begin
          Result := Line.StartsWith('• ');
        end);
      Result := MapLines(S,
        function(Index: Integer; Line: string): string
        begin
          if Remove then
            Result := Line.Substring(2)
          else if Trim(Line) = '' then
            Result := Line
          else
            Result := '• ' + Line;
        end);
    end, True);
end;

procedure TWordLikeForm.NumberingClick(Sender: TObject);
begin
  TransformSelection(
    function(S: string): string
    var
      Remove: Boolean;
      N: Integer;
    begin
      Remove := AllLines(S,
        function(Line: string): Boolean
        begin
          Result := IsNumbered(Line);
        end);
      N := 0;
      Result := MapLines(S,
        function(Index: Integer; Line: string): string
        begin
          if Remove then
            Result := Line.Substring(Line.IndexOf('. ') + 2)
          else if Trim(Line) = '' then
            Result := Line
          else
          begin
            Inc(N);
            Result := IntToStr(N) + '. ' + Line;
          end;
        end);
    end, True);
end;

procedure TWordLikeForm.IndentClick(Sender: TObject);
var
  Increase: Boolean;
begin
  Increase := TComponent(Sender).Tag > 0;
  TransformSelection(
    function(S: string): string
    begin
      Result := MapLines(S,
        function(Index: Integer; Line: string): string
        var
          K: Integer;
        begin
          if Increase then
            Result := '    ' + Line
          else
          begin
            K := 0;
            while (K < 4) and (K < Length(Line)) and (Line[K + 1] = ' ') do
              Inc(K);
            Result := Line.Substring(K);
          end;
        end);
    end, True);
end;

procedure TWordLikeForm.SortClick(Sender: TObject);
begin
  if Memo.SelLength = 0 then
    Memo.SelectAll;
  TransformSelection(
    function(S: string): string
    var
      Lines: TStringList;
    begin
      Lines := TStringList.Create;
      try
        Lines.Text := S;
        Lines.Sort;
        Result := string.Join(sLineBreak, Lines.ToStringArray);
      finally
        Lines.Free;
      end;
    end, True);
  SetMessage(L('Lines sorted', 'Строки отсортированы'));
end;

procedure TWordLikeForm.StylesDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  St: TWriteStyle;
  R: TRectF;
  TextColor, SampleColor: TAlphaColor;
begin
  St := WriteStyles[EnsureRange(AEntry.Tag, 0, High(WriteStyles))];
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
  ACanvas.Font.Size := Min(St.Size + 2, 20);
  ACanvas.Font.Style := St.Style;
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := SampleColor;
  ACanvas.FillText(RectF(R.Left, R.Top, R.Right, R.Bottom - 16), St.Sample, False, 1, [], TTextAlign.Center,
    TTextAlign.Center);
  APainter.TextEx(ACanvas, RectF(R.Left, R.Bottom - 17, R.Right, R.Bottom), AEntry.Caption, TextColor,
    TTextAlign.Center, TTextAlign.Center, APainter.Metrics.FontSize - 1, False, False);
  AHandled := True;
end;

procedure TWordLikeForm.StylesHotTrack(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  // Live preview: the style under the mouse is shown on the document; nil restores the applied format.
  if AEntry <> nil then
    PreviewFont(StyleFont(AEntry.Tag))
  else
    ApplyFormat;
end;

procedure TWordLikeForm.StylesItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  ApplyStyle(AEntry.Tag);
  SetMessage(L('Style: ', 'Стиль: ') + AEntry.Caption);
end;

{ TWordLikeForm: clipboard and editing }

procedure TWordLikeForm.PasteClick(Sender: TObject);
var
  Before: TDocState;
begin
  Before := CurrentState;
  FProgrammatic := True;
  try
    Memo.PasteFromClipboard;
  finally
    FProgrammatic := False;
  end;
  if Memo.Text <> Before.Text then
  begin
    FUndo.Add(Before);
    FRedo.Clear;
    FLastState := CurrentState;
    Inc(FTextVersion);
    MarkModified;
    UpdateUndoUI;
  end;
end;

procedure TWordLikeForm.PasteTextClick(Sender: TObject);
var
  Svc: IFMXClipboardService;
  S: string;
begin
  // Keep Text Only: the clipboard text with the line breaks normalized and the spaces trimmed.
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    Exit;
  S := Svc.GetClipboard.ToString;
  S := MapLines(S,
    function(Index: Integer; Line: string): string
    begin
      Result := Trim(Line);
    end);
  if S <> '' then
    ReplaceSelection(S);
end;

procedure TWordLikeForm.CutClick(Sender: TObject);
begin
  if Memo.SelLength = 0 then
    Exit;
  Memo.CopyToClipboard;
  ReplaceSelection('');
  SetMessage(L('Cut to the clipboard', 'Вырезано в буфер обмена'));
end;

procedure TWordLikeForm.CopyClick(Sender: TObject);
begin
  if Memo.SelLength = 0 then
    Exit;
  Memo.CopyToClipboard;
  SetMessage(Format(L('%d characters copied', 'Скопировано символов: %d'), [Memo.SelLength]));
end;

procedure TWordLikeForm.ClipboardLauncherClick(Sender: TObject);
var
  Svc: IFMXClipboardService;
  S: string;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    S := Svc.GetClipboard.ToString;
  if S = '' then
    SetMessage(L('The clipboard is empty', 'Буфер обмена пуст'))
  else
    SetMessage(Format(L('Clipboard: %d characters, "%s"', 'Буфер обмена: символов %d, "%s"'),
      [Length(S), Copy(S.Replace(sLineBreak, ' '), 1, 40)]));
end;

procedure TWordLikeForm.SelectAllClick(Sender: TObject);
begin
  Memo.SetFocus;
  Memo.SelectAll;
end;

procedure TWordLikeForm.DeleteSelClick(Sender: TObject);
begin
  if Memo.SelLength > 0 then
    ReplaceSelection('');
end;

procedure TWordLikeForm.QuoteClick(Sender: TObject);
begin
  if Memo.SelLength > 0 then
    ReplaceSelection('“' + Memo.SelText + '”', True);
end;

procedure TWordLikeForm.TrimClick(Sender: TObject);
begin
  TransformSelection(
    function(S: string): string
    begin
      Result := MapLines(S,
        function(Index: Integer; Line: string): string
        begin
          Result := Trim(Line);
          while Result.Contains('  ') do
            Result := Result.Replace('  ', ' ');
        end);
    end, True);
end;

procedure TWordLikeForm.ReverseLinesClick(Sender: TObject);
begin
  TransformSelection(
    function(S: string): string
    var
      Lines: TArray<string>;
      I: Integer;
    begin
      Lines := S.Replace(#13#10, #10).Split([#10]);
      Result := '';
      for I := High(Lines) downto 0 do
      begin
        if I < High(Lines) then
          Result := Result + sLineBreak;
        Result := Result + Lines[I];
      end;
    end, True);
end;

{ TWordLikeForm: find and replace }

procedure TWordLikeForm.ShowFindPanel(const AReplace: Boolean);
begin
  FindPanel.Visible := True;
  chkFindPane.Checked := True;
  LayoutPage;
  if (edFind.Text = '') and (Memo.SelLength > 0) and (Memo.SelLength < 60) then
    edFind.Text := Memo.SelText;
  if AReplace and (edFind.Text <> '') then
    edReplace.SetFocus
  else
    edFind.SetFocus;
end;

function TWordLikeForm.FindText(const AForward, AQuiet: Boolean): Boolean;
var
  S, What: string;
  P, From, Count, Index, Q: Integer;
begin
  What := edFind.Text;
  Result := False;
  if What = '' then
    Exit;
  S := Memo.Text.ToUpper;
  What := What.ToUpper;
  if AForward then
  begin
    From := Memo.SelStart + Memo.SelLength;
    P := S.IndexOf(What, Min(From, Length(S)));
    if P < 0 then
      P := S.IndexOf(What);
  end
  else
  begin
    From := Memo.SelStart - 1;
    if From >= 0 then
      P := S.LastIndexOf(What, From)
    else
      P := -1;
    if P < 0 then
      P := S.LastIndexOf(What);
  end;
  Count := 0;
  Index := 0;
  Q := S.IndexOf(What);
  while Q >= 0 do
  begin
    Inc(Count);
    if Q = P then
      Index := Count;
    Q := S.IndexOf(What, Q + Length(What));
  end;
  Result := P >= 0;
  if Result then
  begin
    Memo.SelStart := P;
    Memo.SelLength := Length(What);
    lblFindResult.Text := Format(L('Result %d of %d', 'Результат %d из %d'), [Index, Count]);
  end
  else if not AQuiet then
    lblFindResult.Text := L('No results', 'Ничего не найдено');
end;

procedure TWordLikeForm.FindClick(Sender: TObject);
begin
  ShowFindPanel(False);
end;

procedure TWordLikeForm.ReplaceClick(Sender: TObject);
begin
  ShowFindPanel(True);
end;

procedure TWordLikeForm.FindNextClick(Sender: TObject);
begin
  FindText(True);
end;

procedure TWordLikeForm.FindPrevClick(Sender: TObject);
begin
  FindText(False);
end;

procedure TWordLikeForm.ReplaceOneClick(Sender: TObject);
begin
  if (edFind.Text <> '') and SameText(Memo.SelText, edFind.Text) then
    ReplaceSelection(edReplace.Text);
  FindText(True);
end;

procedure TWordLikeForm.ReplaceAllClick(Sender: TObject);
var
  S, U, What: string;
  Count, P: Integer;
begin
  What := edFind.Text;
  if What = '' then
    Exit;
  S := Memo.Text;
  U := S.ToUpper;
  Count := 0;
  P := U.IndexOf(What.ToUpper);
  while P >= 0 do
  begin
    Inc(Count);
    P := U.IndexOf(What.ToUpper, P + Length(What));
  end;
  if Count > 0 then
    ChangeText(StringReplace(S, What, edReplace.Text, [rfReplaceAll, rfIgnoreCase]), 0, 0);
  lblFindResult.Text := Format(L('%d replaced', 'Заменено: %d'), [Count]);
end;

procedure TWordLikeForm.FindCloseClick(Sender: TObject);
begin
  FindPanel.Visible := False;
  chkFindPane.Checked := False;
  LayoutPage;
  Memo.SetFocus;
end;

procedure TWordLikeForm.FindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    if Sender = edReplace then
      ReplaceOneClick(nil)
    else
      FindText(not (ssShift in Shift));
    Key := 0;
  end
  else if Key = vkEscape then
  begin
    FindCloseClick(nil);
    Key := 0;
  end;
end;

procedure TWordLikeForm.RibbonSearch(Sender: TObject; const AText: string);
begin
  // Enter in the "Tell me" box without choosing a command searches the document.
  ShowFindPanel(False);
  edFind.Text := AText;
  if not FindText(True) then
    SetMessage(Format(L('"%s" was not found', '"%s" не найдено'), [AText]));
end;

{ TWordLikeForm: Insert }

procedure TWordLikeForm.InsertTextClick(Sender: TObject);
begin
  if Memo.ReadOnly then
    Exit;
  case TComponent(Sender).Tag of
    0: InsertAtCaret('───────────────── ' + L('Page Break', 'Разрыв страницы') + ' ─────────────────', True);
    1: InsertAtCaret(sLineBreak + sLineBreak + sLineBreak + sLineBreak + sLineBreak, True);
    2: InsertAtCaret(FormatDateTime('dddd, d mmmm yyyy, hh:nn', Now), False);
    3: InsertAtCaret('______________________________' + sLineBreak + L('Signature', 'Подпись'), True);
    4: InsertAtCaret('┃ ' + L('Text box: type your text here', 'Надпись: введите текст'), True);
    5: InsertAtCaret('https://github.com/', False);
    6: InsertAtCaret('[' + L('Comment', 'Примечание') + ': ]', False);
    7: InsertAtCaret(StringOfChar('─', 48), True);
  end;
end;

procedure TWordLikeForm.InsertTableClick(Sender: TObject);
begin
  if not Memo.ReadOnly then
    InsertAtCaret(BuildTable(3, 3), True);
end;

procedure TWordLikeForm.TableDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  Size: TPoint;
  Grid: TRectF;
  CW, CH: Single;
  C, R: Integer;
  TextColor, LineColor: TAlphaColor;
begin
  Size := WriteTables[EnsureRange(AEntry.Tag, 0, High(WriteTables))];
  TextColor := APainter.Theme.Colors[TFmrToken.MenuItemText];
  LineColor := APainter.Theme.Colors[TFmrToken.Accent];
  Grid := RectF(ARect.Left + 10, ARect.Top + 8, ARect.Right - 10, ARect.Bottom - 22);
  CW := Grid.Width / Size.X;
  CH := Grid.Height / Size.Y;
  for R := 0 to Size.Y - 1 do
    for C := 0 to Size.X - 1 do
    begin
      if R = 0 then
        FillRoundRect(ACanvas, RectF(Grid.Left + C * CW, Grid.Top, Grid.Left + (C + 1) * CW, Grid.Top + CH),
          FmrWithAlpha(LineColor, 0.35));
      ACanvas.Stroke.Kind := TBrushKind.Solid;
      ACanvas.Stroke.Color := LineColor;
      ACanvas.Stroke.Thickness := 1;
      ACanvas.DrawRect(RectF(Grid.Left + C * CW, Grid.Top + R * CH, Grid.Left + (C + 1) * CW,
        Grid.Top + (R + 1) * CH), 0, 0, [], 1);
    end;
  APainter.TextEx(ACanvas, RectF(ARect.Left, ARect.Bottom - 20, ARect.Right, ARect.Bottom - 2),
    Format('%d × %d', [Size.X, Size.Y]), TextColor, TTextAlign.Center, TTextAlign.Center, 0, False, False);
  AHandled := True;
end;

procedure TWordLikeForm.TableItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
var
  Size: TPoint;
begin
  Size := WriteTables[EnsureRange(AEntry.Tag, 0, High(WriteTables))];
  if not Memo.ReadOnly then
    InsertAtCaret(BuildTable(Size.X, Size.Y), True);
  SetMessage(Format(L('Table %d × %d inserted', 'Вставлена таблица %d × %d'), [Size.X, Size.Y]));
end;

procedure TWordLikeForm.ShapesItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  if not Memo.ReadOnly then
    InsertAtCaret(WriteShapes[EnsureRange(AEntry.Tag, 0, High(WriteShapes))].Text, False);
end;

procedure TWordLikeForm.SymbolDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  C: TAlphaColor;
begin
  if TFmrGalleryDrawState.InRibbon in AState then
    C := APainter.ButtonTextColor(TFmrPartState.Normal)
  else
    C := APainter.Theme.Colors[TFmrToken.MenuItemText];
  ACanvas.Font.Family := 'Segoe UI';
  ACanvas.Font.Size := 16;
  ACanvas.Font.Style := [];
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := C;
  ACanvas.FillText(ARect, WriteSymbols[EnsureRange(AEntry.Tag, 0, High(WriteSymbols))], False, 1, [],
    TTextAlign.Center, TTextAlign.Center);
  AHandled := True;
end;

procedure TWordLikeForm.SymbolItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  if not Memo.ReadOnly then
    InsertAtCaret(WriteSymbols[EnsureRange(AEntry.Tag, 0, High(WriteSymbols))], False);
end;

{ TWordLikeForm: Layout }

procedure TWordLikeForm.MarginsClick(Sender: TObject);
begin
  FMarginIndex := EnsureRange(TComponent(Sender).Tag, 0, High(MarginSizes));
  LayoutPage;
end;

procedure TWordLikeForm.OrientationClick(Sender: TObject);
begin
  FLandscape := TComponent(Sender).Tag = 1;
  LayoutPage;
end;

procedure TWordLikeForm.PageSizeClick(Sender: TObject);
begin
  FPageSize := PageSizes[EnsureRange(TComponent(Sender).Tag, 0, High(PageSizes))];
  LayoutPage;
end;

procedure TWordLikeForm.WatermarkClick(Sender: TObject);
var
  I: Integer;
begin
  I := EnsureRange(TComponent(Sender).Tag, 0, High(WatermarkTexts));
  Watermark.Text := WatermarkTexts[I];
  Watermark.Visible := I > 0;
  LayoutPage;
end;

procedure TWordLikeForm.PageColorClick(Sender: TObject);
begin
  if (clrPageColor.Color = TAlphaColors.Null) or (TAlphaColorRec(clrPageColor.Color).A = 0) then
    FPageColor := TAlphaColors.White
  else
    FPageColor := clrPageColor.Color;
  LayoutPage;
end;

procedure TWordLikeForm.PageBordersClick(Sender: TObject);
begin
  LayoutPage;
end;

procedure TWordLikeForm.IndentSpinChange(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  LayoutPage;
end;

procedure TWordLikeForm.LayoutPage;
var
  Z, W, H, X, Y, AreaW, AreaH, Top, K: Single;
  S: TSizeF;
  M: TRectF;
begin
  if FUndo = nil then
    Exit;
  if (DocArea = nil) or (Page = nil) or (Memo = nil) then
    Exit;
  Z := FZoom / 100;
  AreaW := DocArea.Width;
  AreaH := DocArea.Height;
  Top := 0;
  if FindPanel.Visible then
    Top := FindPanel.Height;
  M := MarginSizes[FMarginIndex];
  M.Left := M.Left + spIndentLeft.Value;
  M.Right := M.Right + spIndentRight.Value;
  if FViewMode = TViewMode.Web then
  begin
    Page.SetBounds(0, Top, AreaW, Max(40, AreaH - Top));
    Page.Fill.Color := FPageColor;
    Page.Stroke.Kind := TBrushKind.None;
    PageShadow.Enabled := False;
    Memo.Margins.Rect := RectF(24 + spIndentLeft.Value * Z, 16, 24 + spIndentRight.Value * Z, 4);
  end
  else
  begin
    S := FPageSize;
    if FLandscape then
      S := TSizeF.Create(S.cy, S.cx);
    W := S.cx * Z;
    K := 1;
    if W > AreaW - 32 then
    begin
      K := Max(0.2, (AreaW - 32) / W);
      W := AreaW - 32;
    end;
    X := Round((AreaW - W) / 2);
    Y := Top + 20;
    // a whole sheet when it fits (small zoom), otherwise the page runs below the bottom edge (the memo scrolls)
    H := S.cy * Z * K;
    if H > AreaH - Y - 20 then
      H := Max(60, AreaH - Y + 12);
    Page.SetBounds(X, Y, W, H);
    if FViewMode = TViewMode.Read then
      Page.Fill.Color := $FFF8F1E3
    else
      Page.Fill.Color := FPageColor;
    Page.Stroke.Kind := TBrushKind.Solid;
    if btnPageBorders.Down then
    begin
      Page.Stroke.Thickness := 3;
      Page.Stroke.Color := Ribbon1.Painter.Theme.Colors[TFmrToken.Accent];
    end
    else
    begin
      Page.Stroke.Thickness := 1;
      Page.Stroke.Color := $FFD4D4D4;
    end;
    PageShadow.Enabled := True;
    Memo.Margins.Rect := RectF(M.Left * Z * K, M.Top * Z, M.Right * Z * K, 4);
  end;
  Watermark.TextSettings.Font.Size := 88 * Z;
  Watermark.Width := Page.Width;
  Watermark.Height := 160 * Z;
  Watermark.Position.Point := PointF(0, Max(0, (Min(Page.Height, AreaH) - Watermark.Height) / 2));
end;

{ TWordLikeForm: View }

procedure TWordLikeForm.SetZoom(const AValue: Integer);
begin
  FZoom := EnsureRange(AValue, 10, 500);
  ApplyFormat;
  LayoutPage;
  if spZoom.Zoom <> FZoom then
    spZoom.Zoom := FZoom;
end;

procedure TWordLikeForm.ZoomClick(Sender: TObject);
var
  W: Single;
begin
  case TComponent(Sender).Tag of
    1: SetZoom((FZoom div 10 + 1) * 10);
    2: SetZoom(((FZoom + 9) div 10 - 1) * 10);
    3:
      begin
        W := FPageSize.cx;
        if FLandscape then
          W := FPageSize.cy;
        SetZoom(Trunc((DocArea.Width - 40) / W * 100));
      end;
  else
    SetZoom(TComponent(Sender).Tag);
  end;
  SetMessage(Format(L('Zoom %d%%', 'Масштаб %d%%'), [FZoom]));
end;

procedure TWordLikeForm.SetViewMode(const AMode: TViewMode);
begin
  FViewMode := AMode;
  FUpdatingUI := True;
  try
    case AMode of
      TViewMode.Read: btnReadMode.Down := True;
      TViewMode.Web: btnWebLayout.Down := True;
    else
      btnPrintLayout.Down := True;
    end;
    if Ord(spView.ActiveView) <> Ord(AMode) then
      spView.ActiveView := TFmrStatusView(Ord(AMode));
  finally
    FUpdatingUI := False;
  end;
  Memo.ReadOnly := FProtected or (AMode = TViewMode.Read);
  LayoutPage;
end;

procedure TWordLikeForm.ViewModeClick(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if not FUpdatingUI then
    SetViewMode(TViewMode(EnsureRange(TComponent(Sender).Tag, 0, 2)));
end;

procedure TWordLikeForm.StatusViewChange(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if not FUpdatingUI then
    SetViewMode(TViewMode(Ord(spView.ActiveView)));
end;

procedure TWordLikeForm.StatusZoomChange(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if spZoom.Zoom <> FZoom then
    SetZoom(spZoom.Zoom);
end;

procedure TWordLikeForm.StatusZoomClick(Sender: TObject);
begin
  SetZoom(100);
end;

procedure TWordLikeForm.ShowCheckClick(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if Sender = chkStatusBar then
    StatusBar1.Visible := chkStatusBar.Checked
  else if Sender = chkWordWrap then
    Memo.WordWrap := chkWordWrap.Checked
  else if Sender = chkFindPane then
  begin
    if chkFindPane.Checked then
      ShowFindPanel(False)
    else
      FindCloseClick(nil);
  end;
end;

function TWordLikeForm.ThemeFor(const AName: string): TFmrTheme;
begin
  if not FThemes.TryGetValue(AName, Result) then
  begin
    Result := TFmrTheme.CreateTheme(AName);
    FThemes.Add(AName, Result);
  end;
end;

procedure TWordLikeForm.FillThemeGallery;
const
  FamilyNames: array [TFmrThemeFamily] of string = ('Office 2007', 'Office 2010', 'Office 2013', 'Office 2016',
    'Office 365', 'Windows 11');
  FamilyOrder: array [0..5] of TFmrThemeFamily = (TFmrThemeFamily.Office365, TFmrThemeFamily.Fluent,
    TFmrThemeFamily.Office2016, TFmrThemeFamily.Office2013, TFmrThemeFamily.Office2010, TFmrThemeFamily.Office2007);
var
  Family: TFmrThemeFamily;
  G: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
  I: Integer;
begin
  // Every theme registered with TFmrTheme.RegisterTheme, grouped by family; a theme registered by the
  // application would appear here too.
  FThemeNames := TFmrTheme.ThemeNames;
  galThemes.Groups.BeginUpdate;
  try
    galThemes.Groups.Clear;
    for Family in FamilyOrder do
    begin
      G := nil;
      for I := 0 to High(FThemeNames) do
        if ThemeFor(FThemeNames[I]).Style.Family = Family then
        begin
          if G = nil then
            G := galThemes.Groups.Add(FamilyNames[Family]);
          E := G.Items.Add(TFmrTheme.ThemeDisplayName(FThemeNames[I]));
          E.Hint := FThemeNames[I];
          E.Tag := I;
        end;
    end;
  finally
    galThemes.Groups.EndUpdate;
  end;
end;

procedure TWordLikeForm.ThemeDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  T: TFmrTheme;
  Box, R: TRectF;
  Caption: string;
  TextColor: TAlphaColor;
  CapH, TabH: Single;
begin
  // A miniature ribbon in the colors of the theme: caption, tab row with the active tab, body with commands.
  T := ThemeFor(FThemeNames[EnsureRange(AEntry.Tag, 0, High(FThemeNames))]);
  Box := RectF(ARect.Left + 4, ARect.Top + 3, ARect.Right - 4, ARect.Bottom - 17);
  CapH := Round(Box.Height * 0.28);
  TabH := Round(Box.Height * 0.22);
  R := RectF(Box.Left, Box.Top, Box.Right, Box.Top + CapH);
  T.Fills[TFmrToken.CaptionFill].ApplyTo(ACanvas.Fill);
  ACanvas.FillRect(R, 0, 0, [], 1);
  R := RectF(Box.Left, R.Bottom, Box.Right, R.Bottom + TabH);
  T.Fills[TFmrToken.TabRowFill].ApplyTo(ACanvas.Fill);
  ACanvas.FillRect(R, 0, 0, [], 1);
  if T.Fills[TFmrToken.TabActiveFill].IsVisible then
  begin
    T.Fills[TFmrToken.TabActiveFill].ApplyTo(ACanvas.Fill);
    ACanvas.FillRect(RectF(Box.Left + 14, R.Top + 2, Box.Left + 34, R.Bottom), 0, 0, [], 1);
  end;
  FillRoundRect(ACanvas, RectF(Box.Left + 16, R.Bottom - 2, Box.Left + 32, R.Bottom),
    T.Colors[TFmrToken.TabActiveIndicator]);
  FillRoundRect(ACanvas, RectF(Box.Left + 3, R.Top + 3, Box.Left + 11, R.Bottom - 3),
    T.Colors[TFmrToken.Accent]);
  R := RectF(Box.Left, R.Bottom, Box.Right, Box.Bottom);
  T.Fills[TFmrToken.BodyFill].ApplyTo(ACanvas.Fill);
  ACanvas.FillRect(R, 0, 0, [], 1);
  FillRoundRect(ACanvas, RectF(R.Left + 5, R.Top + 4, R.Left + 13, R.Bottom - 4), T.Colors[TFmrToken.GlyphTint], 1);
  FillRoundRect(ACanvas, RectF(R.Left + 17, R.Top + 4, R.Right - 8, R.Top + 7), T.Colors[TFmrToken.GlyphTint], 1);
  FillRoundRect(ACanvas, RectF(R.Left + 17, R.Top + 10, R.Right - 16, R.Top + 13), T.Colors[TFmrToken.GlyphTint],
    1);
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := FmrWithAlpha(APainter.Theme.Colors[TFmrToken.ButtonText], 0.25);
  ACanvas.Stroke.Thickness := 1;
  ACanvas.DrawRect(RectF(Box.Left + 0.5, Box.Top + 0.5, Box.Right - 0.5, Box.Bottom - 0.5), 0, 0, [], 1);
  Caption := AEntry.Caption.Replace('Office ', '').Replace('Windows 11 ', 'Win11 ');
  if TFmrGalleryDrawState.InRibbon in AState then
    TextColor := APainter.ButtonTextColor(TFmrPartState.Normal)
  else
    TextColor := APainter.Theme.Colors[TFmrToken.MenuItemText];
  APainter.TextEx(ACanvas, RectF(ARect.Left + 1, ARect.Bottom - 17, ARect.Right - 1, ARect.Bottom - 1), Caption,
    TextColor, TTextAlign.Center, TTextAlign.Center, APainter.Metrics.FontSize - 1.5, False, False);
  AHandled := True;
end;

procedure TWordLikeForm.ThemeItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  ApplyTheme(AEntry.Hint, FAccent);
  SetMessage(L('Theme: ', 'Тема: ') + AEntry.Caption);
end;

procedure TWordLikeForm.AccentDrawItem(Sender: TObject; const ACanvas: TCanvas; const AEntry: TFmrGalleryEntry;
  const ARect: TRectF; const AState: TFmrGalleryDrawStates; const APainter: TFmrRibbonPainter;
  var AHandled: Boolean);
var
  C: TAlphaColor;
  Dot: TRectF;
begin
  C := WriteAccents[EnsureRange(AEntry.Tag, 0, High(WriteAccents))].Color;
  if C = 0 then
    C := TFmrTheme.DefaultAccent(Ribbon1.Theme);
  Dot := RectF(ARect.Left + 8, ARect.CenterPoint.Y - 8, ARect.Left + 24, ARect.CenterPoint.Y + 8);
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := C;
  ACanvas.FillEllipse(Dot, 1);
  APainter.TextEx(ACanvas, RectF(Dot.Right + 8, ARect.Top, ARect.Right - 4, ARect.Bottom), AEntry.Caption,
    APainter.Theme.Colors[TFmrToken.MenuItemText], TTextAlign.Leading, TTextAlign.Center, 0, False, False);
  AHandled := True;
end;

procedure TWordLikeForm.AccentItemClick(Sender: TObject; const AEntry: TFmrGalleryEntry);
begin
  ApplyTheme(Ribbon1.Theme, WriteAccents[EnsureRange(AEntry.Tag, 0, High(WriteAccents))].Color);
  SetMessage(L('Accent: ', 'Акцент: ') + AEntry.Caption);
end;

procedure TWordLikeForm.ApplyTheme(const AName: string; const AAccent: TAlphaColor);
begin
  if not TFmrTheme.ThemeExists(AName) then
    Exit;
  FAccent := AAccent;
  Ribbon1.BeginStructureUpdate;
  try
    Ribbon1.AccentColor := AAccent;
    Ribbon1.Theme := AName;
  finally
    Ribbon1.EndStructureUpdate;
  end;
  ApplyThemeColors;
  SyncOptions;
end;

procedure TWordLikeForm.ThemeChangedHandler(const Sender: TObject; const M: TMessage);
begin
  if (M is TFmrThemeChangedMessage) and (TFmrThemeChangedMessage(M).Provider = Ribbon1) and (FUndo <> nil) then
    ApplyThemeColors;
end;

procedure TWordLikeForm.ApplyThemeColors;
var
  T: TFmrTheme;
  Dark: Boolean;
  TextColor: TAlphaColor;
  C: TComponent;
begin
  T := Ribbon1.Painter.Theme;
  if T = nil then
    Exit;
  Dark := T.Style.Dark or (FmrLuminance(T.Colors[TFmrToken.BodyFill]) < 0.3);
  if Dark then
    DocArea.Fill.Color := FmrDarken(T.Colors[TFmrToken.BodyFill], 0.35)
  else if T.Style.Family in [TFmrThemeFamily.Office2007, TFmrThemeFamily.Office2010] then
    DocArea.Fill.Color := FmrBlend(T.Colors[TFmrToken.BodyFill], $FFB0B0B0, 0.35)
  else
    DocArea.Fill.Color := $FFE6E6E6;
  FindPanel.Fill.Color := T.Colors[TFmrToken.StatusBarFill];
  FindPanel.Stroke.Color := T.Colors[TFmrToken.StatusBarSeparator];
  TextColor := T.Colors[TFmrToken.StatusBarText];
  lblFind.TextSettings.FontColor := TextColor;
  lblReplace.TextSettings.FontColor := TextColor;
  lblFindResult.TextSettings.FontColor := TextColor;
  // stock check boxes in the backstage view take the text color of the theme
  for C in Self do
    if (C is TCheckBox) and (TCheckBox(C).Parent <> nil) then
      TCheckBox(C).TextSettings.FontColor := T.Colors[TFmrToken.BackstageHeaderText];
  LayoutPage;
end;

procedure TWordLikeForm.FillOptionCombos;
var
  I: Integer;
begin
  cbOptTheme.BeginUpdate;
  try
    cbOptTheme.Items.Clear;
    for I := 0 to High(FThemeNames) do
      cbOptTheme.Items.Add(TFmrTheme.ThemeDisplayName(FThemeNames[I]));
  finally
    cbOptTheme.EndUpdate;
  end;
  cbOptAccent.Items.Clear;
  for I := 0 to High(WriteAccents) do
    cbOptAccent.Items.Add(L(WriteAccents[I].Name, WriteAccents[I].NameRu));
  cbOptFrame.Items.Clear;
  cbOptFrame.Items.Add(L('FullNC - caption and tabs in the non-client area',
    'FullNC - заголовок и вкладки в неклиентской области'));
  cbOptFrame.Items.Add(L('Dwm - caption in the client area (Mica/Acrylic)',
    'Dwm - заголовок в клиентской области (Mica/Acrylic)'));
  cbOptFrame.Items.Add(L('NCStrip - system title bar, tabs below it',
    'NCStrip - системный заголовок, вкладки под ним'));
  cbOptBackdrop.Items.Clear;
  cbOptBackdrop.Items.Add(L('None', 'Нет'));
  cbOptBackdrop.Items.Add('Mica');
  cbOptBackdrop.Items.Add('Acrylic');
  cbOptBackdrop.Items.Add('Mica Alt (Tabbed)');
  cbOptLanguage.Items.Clear;
  cbOptLanguage.Items.Add('English');
  cbOptLanguage.Items.Add('Русский');
  I := Max(0, cbSaveFormat.ItemIndex);
  cbSaveFormat.Items.Clear;
  cbSaveFormat.Items.Add(L('Plain Text (*.txt)', 'Обычный текст (*.txt)'));
  cbSaveFormat.Items.Add('Markdown (*.md)');
  cbSaveFormat.ItemIndex := I;
end;

procedure TWordLikeForm.SyncOptions;
var
  I: Integer;
  E: TFmrGalleryEntry;
begin
  if FUpdatingUI then
    Exit;
  FUpdatingUI := True;
  try
    cbOptTheme.ItemIndex := IndexText(Ribbon1.Theme, FThemeNames);
    cbOptAccent.ItemIndex := 0;
    for I := 1 to High(WriteAccents) do
      if WriteAccents[I].Color = FAccent then
        cbOptAccent.ItemIndex := I;
    for I := 0 to High(FrameModes) do
      if FrameModes[I] = Frame1.Mode then
        cbOptFrame.ItemIndex := I;
    for I := 0 to High(Backdrops) do
      if Backdrops[I] = Frame1.Backdrop then
        cbOptBackdrop.ItemIndex := I;
    cbOptLanguage.ItemIndex := IfThen(FLanguage = 'ru', 1, 0);
    chkOptSimplified.IsChecked := Ribbon1.DisplayMode = TFmrRibbonDisplayMode.Simplified;
    chkOptTouch.IsChecked := Ribbon1.TouchMode;
    chkOptQATBelow.IsChecked := Ribbon1.QuickAccessToolbar.Position = TFmrQATPosition.BelowRibbon;
    chkOptSearch.IsChecked := Ribbon1.ShowSearchBox;
    chkOptScreenTips.IsChecked := Ribbon1.ShowScreenTips;
    chkSimplified.Checked := Ribbon1.DisplayMode = TFmrRibbonDisplayMode.Simplified;
    chkTouch.Checked := Ribbon1.TouchMode;
    if FLanguage = 'ru' then
      btnLangRu.Down := True
    else
      btnLangEn.Down := True;
    for I := 0 to galThemes.EntryCount - 1 do
    begin
      E := galThemes.Entries[I];
      if SameText(E.Hint, Ribbon1.Theme) then
      begin
        if galThemes.SelectedEntry <> E then
          galThemes.SelectedEntry := E;
        Break;
      end;
    end;
    galAccent.SelectedIndex := cbOptAccent.ItemIndex;
  finally
    FUpdatingUI := False;
  end;
end;

procedure TWordLikeForm.SetFrameMode(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > High(FrameModes)) then
    Exit;
  if FrameModes[AIndex] <> TFmrFrameMode.Dwm then
    Frame1.Backdrop := TFmrFrameBackdrop.None;
  Frame1.Mode := FrameModes[AIndex];
end;

procedure TWordLikeForm.OptComboChange(Sender: TObject);
var
  I: Integer;
begin
  if FUndo = nil then
    Exit;
  if FUpdatingUI then
    Exit;
  I := TComboBox(Sender).ItemIndex;
  if I < 0 then
    Exit;
  if Sender = cbOptTheme then
    ApplyTheme(FThemeNames[I], FAccent)
  else if Sender = cbOptAccent then
    ApplyTheme(Ribbon1.Theme, WriteAccents[I].Color)
  else if Sender = cbOptFrame then
    SetFrameMode(I)
  else if Sender = cbOptBackdrop then
  begin
    if I > 0 then
      SetFrameMode(1);
    Frame1.Backdrop := Backdrops[I];
  end
  else if Sender = cbOptLanguage then
    SetLanguage(IfThen(I = 1, 'ru', 'en'));
  SyncOptions;
end;

procedure TWordLikeForm.OptCheckChange(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if FUpdatingUI then
    Exit;
  if Sender = chkOptSimplified then
  begin
    if chkOptSimplified.IsChecked then
      Ribbon1.DisplayMode := TFmrRibbonDisplayMode.Simplified
    else
      Ribbon1.DisplayMode := TFmrRibbonDisplayMode.Classic;
  end
  else if Sender = chkOptTouch then
    Ribbon1.TouchMode := chkOptTouch.IsChecked
  else if Sender = chkOptQATBelow then
  begin
    if chkOptQATBelow.IsChecked then
      Ribbon1.QuickAccessToolbar.Position := TFmrQATPosition.BelowRibbon
    else
      Ribbon1.QuickAccessToolbar.Position := TFmrQATPosition.AboveRibbon;
  end
  else if Sender = chkOptSearch then
    Ribbon1.ShowSearchBox := chkOptSearch.IsChecked
  else if Sender = chkOptScreenTips then
    Ribbon1.ShowScreenTips := chkOptScreenTips.IsChecked;
  SyncOptions;
end;

procedure TWordLikeForm.RibbonOptionClick(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if FUpdatingUI then
    Exit;
  if Sender = chkSimplified then
  begin
    if chkSimplified.Checked then
      Ribbon1.DisplayMode := TFmrRibbonDisplayMode.Simplified
    else
      Ribbon1.DisplayMode := TFmrRibbonDisplayMode.Classic;
  end
  else if Sender = chkTouch then
    Ribbon1.TouchMode := chkTouch.Checked;
  SyncOptions;
end;

procedure TWordLikeForm.RibbonDisplayModeChanged(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  SyncOptions;
end;

procedure TWordLikeForm.LanguageClick(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if FUpdatingUI then
    Exit;
  SetLanguage(IfThen(TComponent(Sender).Tag = 1, 'ru', 'en'));
end;

procedure TWordLikeForm.StatusLanguageClick(Sender: TObject);
begin
  SetLanguage(IfThen(FLanguage = 'ru', 'en', 'ru'));
end;

procedure TWordLikeForm.CustomizeClick(Sender: TObject);
begin
  // Queued: the form is modal and must not run inside the mouse handler of a ribbon element.
  TThread.ForceQueue(nil, ShowCustomization);
end;

procedure TWordLikeForm.ShowCustomization;
begin
  if Ribbon1.ShowCustomizationForm then
    SetMessage(L('Ribbon customization applied', 'Настройка ленты применена'))
  else
    SetMessage(L('Ribbon customization cancelled', 'Настройка ленты отменена'));
end;

procedure TWordLikeForm.ResetRibbonClick(Sender: TObject);
begin
  Ribbon1.ResetLayout;
  SyncOptions;
  SetMessage(L('The ribbon was reset to its designed layout', 'Лента возвращена к исходному виду'));
end;

{ TWordLikeForm: language }

function TWordLikeForm.L(const AEnglish, ARussian: string): string;
begin
  if FLanguage = 'ru' then
    Result := ARussian
  else
    Result := AEnglish;
end;

procedure TWordLikeForm.CaptureEnglish;
var
  C: TComponent;

  procedure Put(const AKey, AText: string);
  begin
    if AText <> '' then
      FEnglish.AddOrSetValue(AKey, AText);
  end;

begin
  // The designed (English) texts, so switching back from Russian restores them.
  for C in Self do
  begin
    if C.Name = '' then
      Continue;
    if C is TFmrBarItem then
    begin
      Put(C.Name, TFmrBarItem(C).Caption);
      Put(C.Name + '#d', TFmrBarItem(C).ScreenTip.Description);
    end
    else if C is TFmrRibbonStructureObject then
      Put(C.Name, TFmrRibbonStructureObject(C).Caption)
    else if C is TFmrBackstageTab then
      Put(C.Name, TFmrBackstageTab(C).Caption)
    else if C is TFmrBackstageButton then
      Put(C.Name, TFmrBackstageButton(C).Caption)
    else if C is TFmrBackstageTile then
    begin
      Put(C.Name, TFmrBackstageTile(C).Caption);
      Put(C.Name + '#d', TFmrBackstageTile(C).Description);
    end
    else if C is TFmrBackstageLabel then
      Put(C.Name, TFmrBackstageLabel(C).Text)
    else if C is TFmrStatusBarPanel then
      Put(C.Name, TFmrStatusBarPanel(C).Text)
    else if C is TCheckBox then
      Put(C.Name, TCheckBox(C).Text)
    else if C is TButton then
      Put(C.Name, TButton(C).Text)
    else if C is TLabel then
      Put(C.Name, TLabel(C).Text)
    else if C is TEdit then
      Put(C.Name, TEdit(C).TextPrompt);
  end;
end;

procedure TWordLikeForm.SetComponentText(const AComponent: TComponent; const AText: string;
  const ADescription: Boolean);
begin
  if AComponent is TFmrBarItem then
  begin
    if ADescription then
      TFmrBarItem(AComponent).ScreenTip.Description := AText
    else
      TFmrBarItem(AComponent).Caption := AText;
  end
  else if AComponent is TFmrRibbonStructureObject then
    TFmrRibbonStructureObject(AComponent).Caption := AText
  else if AComponent is TFmrBackstageTab then
    TFmrBackstageTab(AComponent).Caption := AText
  else if AComponent is TFmrBackstageButton then
    TFmrBackstageButton(AComponent).Caption := AText
  else if AComponent is TFmrBackstageTile then
  begin
    if ADescription then
      TFmrBackstageTile(AComponent).Description := AText
    else
      TFmrBackstageTile(AComponent).Caption := AText;
  end
  else if AComponent is TFmrBackstageLabel then
    TFmrBackstageLabel(AComponent).Text := AText
  else if AComponent is TFmrStatusBarPanel then
    TFmrStatusBarPanel(AComponent).Text := AText
  else if AComponent is TCheckBox then
    TCheckBox(AComponent).Text := AText
  else if AComponent is TButton then
    TButton(AComponent).Text := AText
  else if AComponent is TLabel then
    TLabel(AComponent).Text := AText
  else if AComponent is TEdit then
    TEdit(AComponent).TextPrompt := AText;
end;

procedure TWordLikeForm.ApplyLanguage;
var
  Pair: TPair<string, string>;
  Key, Text: string;
  Desc: Boolean;
  C: TComponent;
  I: Integer;
  Ru: Boolean;
begin
  Ru := FLanguage = 'ru';
  BarManager1.BeginUpdate;
  Ribbon1.BeginStructureUpdate;
  try
    for Pair in FEnglish do
    begin
      Key := Pair.Key;
      Desc := Key.EndsWith('#d');
      if Desc then
        C := FindComponent(Key.Substring(0, Key.Length - 2))
      else
        C := FindComponent(Key);
      if C = nil then
        Continue;
      if not (Ru and WriteRussianText(Key, Text)) then
        Text := Pair.Value;
      SetComponentText(C, Text, Desc);
    end;
    for I := 0 to galStyles.EntryCount - 1 do
      if Ru then
        galStyles.Entries[I].Caption := WriteStyles[galStyles.Entries[I].Tag].NameRu
      else
        galStyles.Entries[I].Caption := WriteStyles[galStyles.Entries[I].Tag].Name;
    for I := 0 to galAccent.EntryCount - 1 do
      if Ru then
        galAccent.Entries[I].Caption := WriteAccents[galAccent.Entries[I].Tag].NameRu
      else
        galAccent.Entries[I].Caption := WriteAccents[galAccent.Entries[I].Tag].Name;
    for I := 0 to High(WriteTemplates) do
    begin
      C := FindComponent('tileTemplate' + IntToStr(I));
      if C is TFmrBackstageTile then
        if Ru then
          TFmrBackstageTile(C).Caption := WriteTemplates[I].NameRu
        else
          TFmrBackstageTile(C).Caption := WriteTemplates[I].Name;
    end;
  finally
    Ribbon1.EndStructureUpdate;
    BarManager1.EndUpdate;
  end;
  spLanguage.Text := L('English (United States)', 'Русский (Россия)');
  FillRecent;
  FUpdatingUI := True;
  try
    FillOptionCombos;
  finally
    FUpdatingUI := False;
  end;
end;

procedure TWordLikeForm.SetLanguage(const ACode: string);
begin
  FmrSetLanguage(ACode);
  if ACode.StartsWith('ru', True) then
    FLanguage := 'ru'
  else
    FLanguage := 'en';
  ApplyLanguage;
  UpdateCaption;
  UpdateStatus;
  SyncOptions;
end;

{ TWordLikeForm: status bar, selection }

procedure TWordLikeForm.SetMessage(const AText: string);
begin
  spMessage.Text := AText;
end;

procedure TWordLikeForm.UpdateCaption;
begin
  Caption := FDocName + ' - FMR Write';
end;

procedure TWordLikeForm.UpdateStatus;
var
  S: string;
  Lines, Pages, Line: Integer;
begin
  S := Memo.Text;
  Lines := Max(1, Memo.Lines.Count);
  Pages := Max(1, (Lines + 39) div 40);
  Line := Memo.CaretPosition.Line;
  spPage.Text := Format(L('Page %d of %d', 'Страница %d из %d'), [Min(Pages, Line div 40 + 1), Pages]);
  spWords.Text := Format(L('%d words', 'Слов: %d'), [WordCount(S)]);
  spChars.Text := Format(L('%d characters', 'Знаков: %d'), [Length(S.Replace(sLineBreak, ''))]);
  FShownVersion := FTextVersion;
end;

procedure TWordLikeForm.UpdateSelectionInfo;
var
  Sel: string;
begin
  Sel := Memo.SelText;
  stSelInfo.Caption := Format(L('%d words, %d characters', 'Слов: %d, знаков: %d'), [WordCount(Sel),
    Length(Sel.Replace(sLineBreak, ''))]);
end;

procedure TWordLikeForm.SelectionTimerTimer(Sender: TObject);
var
  HasSelection: Boolean;
  Key: string;
begin
  if FUndo = nil then
    Exit;
  if BackstageView1.IsOpen then
    Exit;
  // Contextual tabs follow the selection of the document (Office shows Picture Tools the same way).
  HasSelection := Memo.SelLength > 0;
  if ctxSelection.Visible <> HasSelection then
    ctxSelection.Visible := HasSelection;
  Key := Format('%d:%d:%d', [Memo.SelStart, Memo.SelLength, FTextVersion]);
  if HasSelection and (Key <> FLastSelKey) then
    UpdateSelectionInfo;
  if (Key <> FLastSelKey) or (FShownVersion <> FTextVersion) then
    UpdateStatus;
  FLastSelKey := Key;
end;

procedure TWordLikeForm.StatusWordsClick(Sender: TObject);
var
  S: string;
begin
  S := Memo.Text;
  SetMessage(Format(L('%d words, %d characters, %d lines', 'Слов: %d, знаков: %d, строк: %d'), [WordCount(S),
    Length(S.Replace(sLineBreak, '')), Memo.Lines.Count]));
end;

procedure TWordLikeForm.DocAreaResize(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  LayoutPage;
end;

{ TWordLikeForm: documents }

function TWordLikeForm.DocumentFolder: string;
begin
  Result := FDocDir;
end;

procedure TWordLikeForm.NewDocument(const ATemplate: Integer);
var
  T: Integer;
begin
  T := EnsureRange(ATemplate, 0, High(WriteTemplates));
  Inc(FDocCounter);
  FProgrammatic := True;
  try
    Memo.Text := WriteTemplates[T].Text;
    Memo.SelStart := 0;
  finally
    FProgrammatic := False;
  end;
  FFileName := '';
  if T = 0 then
    FDocName := L('Document', 'Документ') + IntToStr(FDocCounter)
  else
    FDocName := WriteTemplates[T].Name;
  FProtected := False;
  tileProtect.Selected := False;
  Memo.ReadOnly := FViewMode = TViewMode.Read;
  ApplyStyle(0);
  ResetHistory;
  UpdateCaption;
  SetMessage(L('New document: ', 'Новый документ: ') + WriteTemplates[T].Name);
end;

procedure TWordLikeForm.OpenFile(const AFileName: string);
begin
  try
    FProgrammatic := True;
    try
      Memo.Text := TFile.ReadAllText(AFileName);
      Memo.SelStart := 0;
    finally
      FProgrammatic := False;
    end;
    FFileName := AFileName;
    FDocName := TPath.GetFileNameWithoutExtension(AFileName);
    ResetHistory;
    AddRecent(AFileName);
    UpdateCaption;
    SetMessage(L('Opened ', 'Открыт файл ') + AFileName);
  except
    on E: Exception do
      SetMessage(E.Message);
  end;
end;

procedure TWordLikeForm.SaveToFile(const AFileName: string);
begin
  try
    ForceDirectories(TPath.GetDirectoryName(AFileName));
    TFile.WriteAllText(AFileName, Memo.Text, TEncoding.UTF8);
    FFileName := AFileName;
    FDocName := TPath.GetFileNameWithoutExtension(AFileName);
    FModified := False;
    AddRecent(AFileName);
    UpdateCaption;
    SetMessage(L('Saved to ', 'Сохранено: ') + AFileName);
  except
    on E: Exception do
      SetMessage(E.Message);
  end;
end;

procedure TWordLikeForm.AddRecent(const AFileName: string);
var
  I: Integer;
begin
  I := FRecent.IndexOf(AFileName);
  if I >= 0 then
    FRecent.Delete(I);
  FRecent.Insert(0, AFileName);
  while FRecent.Count > 10 do
    FRecent.Delete(FRecent.Count - 1);
  FillRecent;
end;

procedure TWordLikeForm.FillRecent;
var
  I: Integer;
begin
  lstRecent.Items.BeginUpdate;
  try
    lstRecent.Items.Clear;
    if FRecent.Count > 0 then
    begin
      lstRecent.Items.AddHeader(L('Recent documents', 'Последние документы'));
      for I := 0 to FRecent.Count - 1 do
        lstRecent.Items.AddItem(TPath.GetFileName(FRecent[I]), TPath.GetDirectoryName(FRecent[I])).Tag := I;
    end;
    lstRecent.Items.AddHeader(L('Samples', 'Примеры'));
    for I := 1 to High(WriteTemplates) do
      lstRecent.Items.AddItem(IfThen(FLanguage = 'ru', WriteTemplates[I].NameRu, WriteTemplates[I].Name),
        WriteTemplates[I].Description).Tag := 1000 + I;
  finally
    lstRecent.Items.EndUpdate;
  end;
end;

procedure TWordLikeForm.NewClick(Sender: TObject);
begin
  NewDocument(0);
end;

procedure TWordLikeForm.OpenClick(Sender: TObject);
begin
  BackstageView1.ActiveTab := bsOpen;
  BackstageView1.ShowApplicationMenu(Ribbon1, Ribbon1.ApplicationButtonScreenRect, False);
end;

procedure TWordLikeForm.SaveClick(Sender: TObject);
begin
  if FFileName <> '' then
    SaveToFile(FFileName)
  else
  begin
    BackstageView1.ActiveTab := bsSaveAs;
    if not BackstageView1.IsOpen then
      BackstageView1.ShowApplicationMenu(Ribbon1, Ribbon1.ApplicationButtonScreenRect, False);
  end;
end;

procedure TWordLikeForm.PrintClick(Sender: TObject);
begin
  BackstageView1.ActiveTab := bsPrint;
  BackstageView1.ShowApplicationMenu(Ribbon1, Ribbon1.ApplicationButtonScreenRect, False);
end;

procedure TWordLikeForm.CloseDocClick(Sender: TObject);
begin
  NewDocument(0);
end;

procedure TWordLikeForm.TemplateTileClick(Sender: TObject);
begin
  BackstageView1.Hide;
  NewDocument(TComponent(Sender).Tag);
end;

procedure TWordLikeForm.RecentItemClick(Sender: TObject; const AItem: TFmrBackstageGalleryItem);
var
  Tag: Integer;
begin
  Tag := AItem.Tag;
  BackstageView1.Hide;
  if Tag >= 1000 then
    NewDocument(Tag - 1000)
  else if (Tag >= 0) and (Tag < FRecent.Count) then
    OpenFile(FRecent[Tag]);
end;

procedure TWordLikeForm.BrowseOpenClick(Sender: TObject);
begin
  OpenDialog1.InitialDir := DocumentFolder;
  if OpenDialog1.Execute then
  begin
    BackstageView1.Hide;
    OpenFile(OpenDialog1.FileName);
  end;
end;

procedure TWordLikeForm.BrowseSaveClick(Sender: TObject);
begin
  SaveDialog1.InitialDir := DocumentFolder;
  SaveDialog1.FileName := edSaveName.Text;
  if SaveDialog1.Execute then
  begin
    BackstageView1.Hide;
    SaveToFile(SaveDialog1.FileName);
  end;
end;

procedure TWordLikeForm.SaveAsGoClick(Sender: TObject);
var
  Name: string;
  C: Char;
begin
  Name := Trim(edSaveName.Text);
  for C in TPath.GetInvalidFileNameChars do
    Name := Name.Replace(C, '_');
  if Name = '' then
    Name := FDocName;
  if cbSaveFormat.ItemIndex = 1 then
    Name := Name + '.md'
  else
    Name := Name + '.txt';
  BackstageView1.Hide;
  SaveToFile(TPath.Combine(DocumentFolder, Name));
end;

procedure TWordLikeForm.BackstageShow(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  BackstageTabChanged(nil);
end;

procedure TWordLikeForm.BackstageTabChanged(Sender: TObject);
begin
  if FUndo = nil then
    Exit;
  if BackstageView1.ActiveTab = bsInfo then
    UpdateInfoPage
  else if BackstageView1.ActiveTab = bsSaveAs then
  begin
    lblSaveFolder.Text := DocumentFolder;
    if edSaveName.Text = '' then
      edSaveName.Text := FDocName;
  end
  else if BackstageView1.ActiveTab = bsPrint then
  begin
    FillPrinters;
    UpdatePrintPreview;
  end
  else if BackstageView1.ActiveTab = bsOptions then
    SyncOptions;
end;

function IssueCount(const S: string): Integer;
var
  P: Integer;
  Line: string;
begin
  Result := 0;
  P := S.IndexOf('  ');
  while P >= 0 do
  begin
    Inc(Result);
    P := S.IndexOf('  ', P + 2);
  end;
  for Line in S.Replace(#13#10, #10).Split([#10]) do
    if (Line <> '') and (Line <> TrimRight(Line)) then
      Inc(Result);
end;

procedure TWordLikeForm.UpdateInfoPage;
var
  S: string;
  N: Integer;
begin
  S := Memo.Text;
  lblInfoTitle.Text := FDocName;
  if FFileName <> '' then
    lblInfoPath.Text := FFileName
  else
    lblInfoPath.Text := L('This document has not been saved yet', 'Документ ещё не сохранён');
  lblInfoWords.Text := Format(L('Words: %d', 'Слов: %d'), [WordCount(S)]);
  lblInfoChars.Text := Format(L('Characters: %d', 'Знаков: %d'), [Length(S.Replace(sLineBreak, ''))]);
  lblInfoLines.Text := Format(L('Lines: %d', 'Строк: %d'), [Memo.Lines.Count]);
  lblInfoPages.Text := Format(L('Pages: %d', 'Страниц: %d'), [Max(1, (Memo.Lines.Count + 39) div 40)]);
  if FProtected then
    lblInfoProtect.Text := L('This document is read-only. Click again to allow editing.',
      'Документ доступен только для чтения. Нажмите ещё раз, чтобы разрешить правку.')
  else
    lblInfoProtect.Text := L('Anyone can edit this document. Click to make it read-only.',
      'Документ можно изменять. Нажмите, чтобы запретить правку.');
  N := IssueCount(S);
  if N = 0 then
    lblInfoIssues.Text := L('No double spaces or trailing spaces were found.',
      'Двойных пробелов и пробелов в конце строк нет.')
  else
    lblInfoIssues.Text := Format(L('%d double or trailing spaces. Click to remove them.',
      'Лишних пробелов: %d. Нажмите, чтобы удалить их.'), [N]);
  lblInfoHistory.Text := Format(L('%d changes can be undone. Click to restore the previous version.',
    'Можно отменить изменений: %d. Нажмите, чтобы вернуть предыдущую версию.'), [FUndo.Count]);
end;

procedure TWordLikeForm.ProtectTileClick(Sender: TObject);
begin
  FProtected := not FProtected;
  tileProtect.Selected := FProtected;
  Memo.ReadOnly := FProtected or (FViewMode = TViewMode.Read);
  UpdateInfoPage;
end;

procedure TWordLikeForm.InspectTileClick(Sender: TObject);
var
  S, T: string;
begin
  S := Memo.Text;
  T := MapLines(S,
    function(Index: Integer; Line: string): string
    begin
      Result := TrimRight(Line);
      while Result.Contains('  ') do
        Result := Result.Replace('  ', ' ');
    end);
  if T <> S then
    ChangeText(T, 0, 0);
  UpdateInfoPage;
end;

procedure TWordLikeForm.HistoryTileClick(Sender: TObject);
begin
  UndoClick(nil);
  UpdateInfoPage;
end;

procedure TWordLikeForm.FillPrinters;
var
  I: Integer;
begin
  if cbPrinter.Count > 0 then
    Exit;
  try
    for I := 0 to Printer.Count - 1 do
    begin
      cbPrinter.Items.Add(Printer.Printers[I].Title);
      if Printer.Printers[I] = Printer.ActivePrinter then
        cbPrinter.ItemIndex := I;
    end;
  except
    cbPrinter.Items.Clear;
  end;
  if cbPrinter.Count = 0 then
    cbPrinter.Items.Add('Microsoft Print to PDF');
  if cbPrinter.ItemIndex < 0 then
    cbPrinter.ItemIndex := 0;
end;

procedure TWordLikeForm.UpdatePrintPreview;
var
  B: TBitmap;
  S: TSizeF;
  K: Single;
  W, H: Integer;
  M, R: TRectF;
begin
  S := FPageSize;
  if FLandscape then
    S := TSizeF.Create(S.cy, S.cx);
  K := 1400 / Max(S.cx, S.cy);
  W := Round(S.cx * K);
  H := Round(S.cy * K);
  B := TBitmap.Create(W, H);
  try
    if B.Canvas.BeginScene then
    try
      B.Canvas.Clear(FPageColor);
      B.Canvas.Stroke.Kind := TBrushKind.Solid;
      B.Canvas.Stroke.Color := $FFB8B8B8;
      B.Canvas.Stroke.Thickness := 1;
      B.Canvas.DrawRect(RectF(0.5, 0.5, W - 0.5, H - 0.5), 0, 0, [], 1);
      M := MarginSizes[FMarginIndex];
      R := RectF(M.Left * K, M.Top * K, W - M.Right * K, H - M.Bottom * K);
      if Watermark.Visible then
      begin
        B.Canvas.Font.Family := 'Segoe UI';
        B.Canvas.Font.Size := 60 * K;
        B.Canvas.Font.Style := [TFontStyle.fsBold];
        B.Canvas.Fill.Color := $22000000;
        B.Canvas.FillText(RectF(0, 0, W, H), Watermark.Text, False, 1, [], TTextAlign.Center, TTextAlign.Center);
      end;
      B.Canvas.Font.Family := FFont.Family;
      B.Canvas.Font.Size := FFont.Size * PointToDp * K;
      B.Canvas.Font.Style := FFont.Style;
      B.Canvas.Fill.Kind := TBrushKind.Solid;
      B.Canvas.Fill.Color := FFont.Color;
      B.Canvas.IntersectClipRect(R);
      B.Canvas.FillText(R, Memo.Text, True, 1, [], FAlign, TTextAlign.Leading);
    finally
      B.Canvas.EndScene;
    end;
    imgPreview.Bitmap.Assign(B);
  finally
    B.Free;
  end;
  lblPrintInfo.Text := Format(L('%d page(s), %s', 'Страниц: %d, %s'), [Max(1, (Memo.Lines.Count + 39) div 40),
    IfThen(FLandscape, L('landscape', 'альбомная'), L('portrait', 'книжная'))]);
end;

procedure TWordLikeForm.PrintTileClick(Sender: TObject);
begin
  // Printing is simulated: the demo must not send pages to a real printer.
  BackstageView1.Hide;
  SetMessage(Format(L('%d copies sent to "%s" (simulated)', 'Отправлено копий: %d на "%s" (имитация)'),
    [Round(spCopies.Value), cbPrinter.Text]));
end;

{ TWordLikeForm: settings }

procedure TWordLikeForm.LoadSettings;
var
  Ini: TMemIniFile;
  I: Integer;
  S: string;
begin
  if not TFile.Exists(TPath.Combine(FSettingsDir, 'settings.ini')) then
    Exit;
  Ini := TMemIniFile.Create(TPath.Combine(FSettingsDir, 'settings.ini'), TEncoding.UTF8);
  try
    FAccent := TAlphaColor(StrToInt64Def('$' + Ini.ReadString('Window', 'Accent', '0'), 0));
    S := Ini.ReadString('Window', 'Theme', Ribbon1.Theme);
    if TFmrTheme.ThemeExists(S) then
      ApplyTheme(S, FAccent);
    SetLanguage(Ini.ReadString('Window', 'Language', 'en'));
    SetFrameMode(Ini.ReadInteger('Window', 'Frame', 0));
    I := Ini.ReadInteger('Window', 'Backdrop', 0);
    if (I > 0) and (I <= High(Backdrops)) and (Frame1.Mode = TFmrFrameMode.Dwm) then
      Frame1.Backdrop := Backdrops[I];
    FZoom := EnsureRange(Ini.ReadInteger('Window', 'Zoom', 100), 10, 500);
    FRecent.Clear;
    for I := 0 to 9 do
    begin
      S := Ini.ReadString('Recent', 'File' + IntToStr(I), '');
      if (S <> '') and TFile.Exists(S) then
        FRecent.Add(S);
    end;
    FillRecent;
  finally
    Ini.Free;
  end;
end;

procedure TWordLikeForm.SaveSettings;
var
  Ini: TMemIniFile;
  I: Integer;
begin
  Ini := TMemIniFile.Create(TPath.Combine(FSettingsDir, 'settings.ini'), TEncoding.UTF8);
  try
    Ini.WriteString('Window', 'Theme', Ribbon1.Theme);
    Ini.WriteString('Window', 'Accent', IntToHex(FAccent, 8));
    Ini.WriteString('Window', 'Language', FLanguage);
    Ini.WriteInteger('Window', 'Frame', Max(0, cbOptFrame.ItemIndex));
    Ini.WriteInteger('Window', 'Backdrop', Max(0, cbOptBackdrop.ItemIndex));
    Ini.WriteInteger('Window', 'Zoom', FZoom);
    Ini.EraseSection('Recent');
    for I := 0 to FRecent.Count - 1 do
      Ini.WriteString('Recent', 'File' + IntToStr(I), FRecent[I]);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
