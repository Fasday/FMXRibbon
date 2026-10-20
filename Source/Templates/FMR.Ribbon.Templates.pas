{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Ribbon templates                                     }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Templates;

/// Builds complete ribbon structures (tabs, groups, items and links, quick access toolbar, a contextual
/// tab group) into a ribbon and its bar manager. Used by the design package ("Apply template...") and usable at run
/// time. The builder only needs the structure object (TFmrRibbon or any IFmrRibbonStructureOwner) and a
/// TFmrBarManager; components are owned by the owner of the ribbon (the form), exactly like the designer creates
/// them, and named through a name function (the IDE passes Designer.UniqueName). Icons are glyphs of the Segoe Fluent
/// Icons / Segoe MDL2 Assets font (TFmrImageSource.GlyphCode), so no image files are needed.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections, FMX.Types, FMR.Ribbon.Types,
  FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure;

type
  /// <summary>Built-in templates.</summary>
  TFmrRibbonTemplate = (
    /// <summary>Home (Clipboard, Font, Editing) and View (Zoom, Show).</summary>
    Simple,
    /// <summary>Document editor: Home, Insert, Layout, View and a "Table Tools" contextual tab group.</summary>
    Document,
    /// <summary>Spreadsheet: Home, Insert, Formulas, Data, View.</summary>
    Spreadsheet);

  /// <summary>Returns a component name for a base name ('btnPaste' → 'btnPaste' or 'btnPaste1'). The IDE passes a
  /// function built on Designer.UniqueName.</summary>
  TFmrTemplateNameFunc = reference to function(const ABaseName: string): string;

  /// <summary>Size of a button created by the builder.</summary>
  TFmrTemplateButtonSize = (
    /// <summary>Large glyph and caption (reduces to small with text and small).</summary>
    Large,
    /// <summary>Small glyph with caption (reduces to small).</summary>
    Small,
    /// <summary>Small glyph only.</summary>
    IconOnly);

  /// <summary>Place of an icon-only link in a row of button groups (TFmrItemLink.ButtonGroup).</summary>
  TFmrTemplateRowPos = (
    /// <summary>Starts a new row (ButtonGroup = Start).</summary>
    NewRow,
    /// <summary>Continues the row after a gap (ButtonGroup = Member, BeginGroup).</summary>
    NewSegment,
    /// <summary>Continues the segment of the previous link (ButtonGroup = Member).</summary>
    Next);

  /// <summary>Builds ribbon structures. Create it for a ribbon and a bar manager, call Build (or the building
  /// blocks), read Created for the new components.</summary>
  TFmrRibbonTemplateBuilder = class
  private
    FStructure: TFmxObject;
    FManager: TFmrBarManager;
    FNamer: TFmrTemplateNameFunc;
    FCreated: TList<TComponent>;
    FCategory: string;
    FFirstTab: TFmrRibbonTab;
    function NewName(const ABaseName: string): string;
    procedure Track(const AComponent: TComponent);
    function NewItem(const AClass: TFmrBarItemClass; const ABaseName, ACaption: string): TFmrBarItem;
    procedure AddCategory(const ACategory: string);
    procedure BuildSimple;
    procedure BuildDocument;
    procedure BuildSpreadsheet;
    procedure AddClipboardGroup(const ATab: TFmrRibbonTab; const AFull: Boolean);
    procedure AddStandardQAT;
  public
    /// <summary>AStructureObject: the ribbon (its children are the tabs). AManager: the bar manager of the items
    /// (nil = the manager of the structure owner). ANamer: nil = unique names among the components of the owner.
    /// </summary>
    constructor Create(const AStructureObject: TFmxObject; const AManager: TFmrBarManager = nil;
      const ANamer: TFmrTemplateNameFunc = nil);
    destructor Destroy; override;
    /// <summary>Builds a template. Existing tabs are kept (the new tabs are appended); call ClearStructure first to
    /// replace them.</summary>
    procedure Build(const ATemplate: TFmrRibbonTemplate);
    /// <summary>Deletes the tabs, the contextual tab groups and the links of the quick access toolbar of the ribbon
    /// (items of the bar manager are kept).</summary>
    procedure ClearStructure;
    { building blocks }
    /// <summary>New tab (appended); sets the category of the items created after it to ACaption.</summary>
    function AddTab(const AName, ACaption: string; const AKeyTip: string = '';
      const AContextGroup: TFmrRibbonContextGroup = nil): TFmrRibbonTab;
    function AddContextGroup(const AName, ACaption: string; const AColor: TAlphaColor): TFmrRibbonContextGroup;
    function AddGroup(const ATab: TFmrRibbonTab; const AName, ACaption: string;
      const ALauncher: Boolean = False): TFmrRibbonGroup;
    /// <summary>Button with a glyph of the icon font; linked into AGroup when it is not nil.</summary>
    function AddButton(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AGlyph: Cardinal;
      const ASize: TFmrTemplateButtonSize = TFmrTemplateButtonSize.Small;
      const AStyle: TFmrButtonStyle = TFmrButtonStyle.Default; const ABeginGroup: Boolean = False): TFmrButtonItem;
    /// <summary>Icon-only button placed in a row of button groups.</summary>
    function AddGroupButton(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AGlyph: Cardinal;
      const APos: TFmrTemplateRowPos; const AStyle: TFmrButtonStyle = TFmrButtonStyle.Default): TFmrButtonItem;
    function AddCheck(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
      const AChecked: Boolean = False): TFmrCheckItem;
    /// <summary>Color button (split); icon-only colors are placed in a row of button groups at APos.</summary>
    function AddColor(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AGlyph: Cardinal;
      const AColor: TAlphaColor; const ASize: TFmrTemplateButtonSize = TFmrTemplateButtonSize.IconOnly;
      const APos: TFmrTemplateRowPos = TFmrTemplateRowPos.NewRow): TFmrColorItem;
    function AddCombo(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AItems: array of string;
      const AText: string; const AWidth: Single; const AEditable: Boolean = True;
      const AShowCaption: Boolean = False): TFmrComboItem;
    function AddFontName(const AGroup: TFmrRibbonGroup; const AName, AText: string;
      const AWidth: Single): TFmrFontNameItem;
    function AddSpin(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AValue, AMin, AMax,
      AIncrement: Double; const ADigits: Integer; const AWidth: Single): TFmrSpinItem;
    function AddGallery(const AGroup: TFmrRibbonGroup; const AName, ACaption: string; const AGlyph: Cardinal;
      const AEntries: array of string; const AEntryGlyph: Cardinal): TFmrGalleryItem;
    /// <summary>Menu entry (a button item linked into the drop-down links of AParent).</summary>
    function AddMenuItem(const AParent: TFmrButtonItem; const AName, ACaption: string; const AGlyph: Cardinal = 0;
      const ABeginGroup: Boolean = False): TFmrButtonItem;
    /// <summary>Links an existing item into AGroup.</summary>
    function AddLink(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem; const ALevels: TFmrViewLevels = [];
      const ABeginGroup: Boolean = False): TFmrItemLink;
    /// <summary>Links AItem into the quick access toolbar (no duplicates).</summary>
    procedure AddToQAT(const AItem: TFmrBarItem);
    class function TemplateCaption(const ATemplate: TFmrRibbonTemplate): string; static;
    class function TemplateDescription(const ATemplate: TFmrRibbonTemplate): string; static;
    /// <summary>Default name function: ABaseName when no component of AOwner has it, otherwise ABaseName1, 2...
    /// </summary>
    class function DefaultNamer(const AOwner: TComponent): TFmrTemplateNameFunc; static;
    property StructureObject: TFmxObject read FStructure;
    property Manager: TFmrBarManager read FManager;
    /// <summary>Category given to the items created next (AddTab sets it to the tab caption).</summary>
    property Category: string read FCategory write FCategory;
    /// <summary>Components created so far (tabs, groups, context groups, items), in creation order.</summary>
    property Created: TList<TComponent> read FCreated;
    /// <summary>First tab created by Build (to make it active).</summary>
    property FirstTab: TFmrRibbonTab read FFirstTab;
  end;

  EFmrTemplateError = class(Exception);

/// <summary>Builds ATemplate into ARibbon (a TFmrRibbon or any structure owner). AManager nil: the bar manager of
/// the ribbon. AReplace deletes the existing tabs first. Returns the first new tab.</summary>
function FmrApplyRibbonTemplate(const ARibbon: TFmxObject; const ATemplate: TFmrRibbonTemplate;
  const AManager: TFmrBarManager = nil; const AReplace: Boolean = False;
  const ANamer: TFmrTemplateNameFunc = nil): TFmrRibbonTab;

const
  /// <summary>Glyph code points of the Segoe Fluent Icons / Segoe MDL2 Assets fonts used by the templates (checked
  /// on a rendered sheet, tools\DesignPreview\glyphsheet.ps1).</summary>
  FmrGlyphPaste = $E77F;
  FmrGlyphCut = $E8C6;
  FmrGlyphCopy = $E8C8;
  FmrGlyphFormatPainter = $E771;
  FmrGlyphUndo = $E7A7;
  FmrGlyphRedo = $E7A6;
  FmrGlyphSave = $E74E;
  FmrGlyphSaveAs = $E792;
  FmrGlyphOpen = $E8E5;
  FmrGlyphPrint = $E749;
  FmrGlyphBold = $E8DD;
  FmrGlyphItalic = $E8DB;
  FmrGlyphUnderline = $E8DC;
  FmrGlyphStrikethrough = $EDE0;
  FmrGlyphFontIncrease = $E8E8;
  FmrGlyphFontDecrease = $E8E7;
  FmrGlyphChangeCase = $E8E9;
  FmrGlyphClearFormatting = $ED60;
  FmrGlyphHighlight = $E7E6;
  FmrGlyphFontColor = $E8D3;
  FmrGlyphFont = $E8D2;
  FmrGlyphBullets = $E8FD;
  FmrGlyphNumbering = $F168;
  FmrGlyphMultilevel = $EA40;
  FmrGlyphIndentDecrease = $EA52;
  FmrGlyphIndentIncrease = $E8B5;
  FmrGlyphSort = $E8CB;
  FmrGlyphParagraphMark = $E9AA;
  FmrGlyphAlignLeft = $E8E4;
  FmrGlyphAlignCenter = $E8E3;
  FmrGlyphAlignRight = $E8E2;
  FmrGlyphJustify = $E700;
  FmrGlyphLineSpacing = $ECE7;
  FmrGlyphShading = $EB42;
  FmrGlyphBorders = $E739;
  FmrGlyphFind = $E721;
  FmrGlyphReplace = $E8AB;
  FmrGlyphSelect = $E8B3;
  FmrGlyphCoverPage = $E8A5;
  FmrGlyphBlankPage = $ED0E;
  FmrGlyphPageBreak = $E751;
  FmrGlyphTable = $E80A;
  FmrGlyphPictures = $EB9F;
  FmrGlyphShapes = $EB91;
  FmrGlyphIcons = $E76E;
  FmrGlyphDiagram = $EABB;
  FmrGlyphChart = $E9D2;
  FmrGlyphColumnChart = $F404;
  FmrGlyphLineChart = $EAFC;
  FmrGlyphPieChart = $EB05;
  FmrGlyphScreenshot = $E924;
  FmrGlyphLink = $E71B;
  FmrGlyphBookmark = $E7C1;
  FmrGlyphCrossReference = $E8A7;
  FmrGlyphComment = $E90A;
  FmrGlyphHeader = $ED6E;
  FmrGlyphFooter = $E75B;
  FmrGlyphPageNumber = $F146;
  FmrGlyphTextBox = $E75A;
  FmrGlyphTextEffects = $EF60;
  FmrGlyphDropCap = $E97E;
  FmrGlyphEquation = $E94B;
  FmrGlyphSymbol = $E8C1;
  FmrGlyphMargins = $E799;
  FmrGlyphOrientation = $E8B4;
  FmrGlyphSize = $E9A6;
  FmrGlyphColumns = $EE4D;
  FmrGlyphLineNumbers = $F168;
  FmrGlyphHyphenation = $E738;
  FmrGlyphPosition = $ED6F;
  FmrGlyphWrapText = $E8A1;
  FmrGlyphBringForward = $EE40;
  FmrGlyphSendBackward = $EE50;
  FmrGlyphRotate = $E7AD;
  FmrGlyphReadMode = $E736;
  FmrGlyphPrintLayout = $E7C3;
  FmrGlyphWebLayout = $E774;
  FmrGlyphZoom = $E71E;
  FmrGlyphZoomIn = $E8A3;
  FmrGlyphZoomOut = $E71F;
  FmrGlyphPercent = $E94C;
  FmrGlyphOnePage = $E7C3;
  FmrGlyphMultiplePages = $E89A;
  FmrGlyphPageWidth = $E740;
  FmrGlyphNewWindow = $E78B;
  FmrGlyphArrangeAll = $E8A9;
  FmrGlyphSplit = $EE4E;
  FmrGlyphSwitchWindows = $E7C4;
  FmrGlyphAutoSum = $E8EF;
  FmrGlyphFill = $E74B;
  FmrGlyphClear = $EA99;
  FmrGlyphFilter = $E71C;
  FmrGlyphInsertCells = $EFDA;
  FmrGlyphDelete = $E74D;
  FmrGlyphFormat = $E713;
  FmrGlyphMerge = $EA3C;
  FmrGlyphWrapLine = $E751;
  FmrGlyphCurrency = $E8C7;
  FmrGlyphComma = $F111;
  FmrGlyphIncreaseDecimal = $E948;
  FmrGlyphDecreaseDecimal = $E949;
  FmrGlyphConditional = $E9D5;
  FmrGlyphCellStyles = $E771;
  FmrGlyphFunction = $E943;
  FmrGlyphRecent = $E81C;
  FmrGlyphFinancial = $E8C7;
  FmrGlyphLogical = $E8FB;
  FmrGlyphDateTime = $EC92;
  FmrGlyphNameManager = $E8EC;
  FmrGlyphEdit = $E70F;
  FmrGlyphCalculate = $E8EF;
  FmrGlyphGetData = $EE94;
  FmrGlyphRefresh = $E72C;
  FmrGlyphSortUp = $E74A;
  FmrGlyphSortDown = $E74B;
  FmrGlyphTextToColumns = $EE4D;
  FmrGlyphRemoveDuplicates = $E8E6;
  FmrGlyphValidation = $E73E;
  FmrGlyphFreezePanes = $ED6F;
  FmrGlyphZoomSelection = $E8B3;
  FmrGlyphPivotTable = $E8A9;
  FmrGlyphSpelling = $E8FB;
  FmrGlyphHelp = $E897;
  FmrGlyphNew = $E8A5;

implementation

const
  scCtrlKey = $4000; // System.Classes.scCtrl

function CtrlKey(const AChar: Char): TShortCut;
begin
  Result := TShortCut(scCtrlKey or Ord(AChar));
end;

function FmrApplyRibbonTemplate(const ARibbon: TFmxObject; const ATemplate: TFmrRibbonTemplate;
  const AManager: TFmrBarManager; const AReplace: Boolean; const ANamer: TFmrTemplateNameFunc): TFmrRibbonTab;
var
  B: TFmrRibbonTemplateBuilder;
begin
  B := TFmrRibbonTemplateBuilder.Create(ARibbon, AManager, ANamer);
  try
    if AReplace then
      B.ClearStructure;
    B.Build(ATemplate);
    Result := B.FirstTab;
  finally
    B.Free;
  end;
end;

{ TFmrRibbonTemplateBuilder }

constructor TFmrRibbonTemplateBuilder.Create(const AStructureObject: TFmxObject; const AManager: TFmrBarManager;
  const ANamer: TFmrTemplateNameFunc);
var
  O: IFmrRibbonStructureOwner;
begin
  inherited Create;
  if AStructureObject = nil then
    raise EFmrTemplateError.Create('The ribbon of a template must not be nil');
  FStructure := AStructureObject;
  FManager := AManager;
  if (FManager = nil) and Supports(FStructure, IFmrRibbonStructureOwner, O) then
    FManager := O.GetBarManager;
  if FManager = nil then
    raise EFmrTemplateError.Create('The ribbon has no bar manager: assign BarManager first');
  FNamer := ANamer;
  if not Assigned(FNamer) then
    FNamer := DefaultNamer(FStructure.Owner);
  FCreated := TList<TComponent>.Create;
end;

destructor TFmrRibbonTemplateBuilder.Destroy;
begin
  FCreated.Free;
  inherited;
end;

class function TFmrRibbonTemplateBuilder.DefaultNamer(const AOwner: TComponent): TFmrTemplateNameFunc;
begin
  Result :=
    function(const ABaseName: string): string
    var
      N: Integer;
    begin
      Result := ABaseName;
      if AOwner = nil then
        Exit;
      N := 0;
      while AOwner.FindComponent(Result) <> nil do
      begin
        Inc(N);
        Result := ABaseName + IntToStr(N);
      end;
    end;
end;

function TFmrRibbonTemplateBuilder.NewName(const ABaseName: string): string;
begin
  Result := FNamer(ABaseName);
end;

procedure TFmrRibbonTemplateBuilder.Track(const AComponent: TComponent);
begin
  FCreated.Add(AComponent);
end;

procedure TFmrRibbonTemplateBuilder.AddCategory(const ACategory: string);
begin
  if (ACategory <> '') and (FManager.Categories.IndexOf(ACategory) < 0) then
    FManager.Categories.Add(ACategory);
end;

function TFmrRibbonTemplateBuilder.NewItem(const AClass: TFmrBarItemClass; const ABaseName,
  ACaption: string): TFmrBarItem;
begin
  Result := FManager.CreateItem(AClass, NewName(ABaseName));
  Track(Result);
  Result.Caption := ACaption;
  if FCategory <> '' then
    Result.Category := FCategory;
end;

function TFmrRibbonTemplateBuilder.AddTab(const AName, ACaption, AKeyTip: string;
  const AContextGroup: TFmrRibbonContextGroup): TFmrRibbonTab;
begin
  Result := TFmrRibbonStructure.CreateTab(FStructure, ACaption);
  Result.Name := NewName(AName);
  Track(Result);
  Result.KeyTip := AKeyTip;
  Result.ContextGroup := AContextGroup;
  FCategory := ACaption;
  AddCategory(ACaption);
  if FFirstTab = nil then
    FFirstTab := Result;
end;

function TFmrRibbonTemplateBuilder.AddContextGroup(const AName, ACaption: string;
  const AColor: TAlphaColor): TFmrRibbonContextGroup;
begin
  Result := TFmrRibbonStructure.CreateContextGroup(FStructure, ACaption, AColor);
  Result.Name := NewName(AName);
  Track(Result);
end;

function TFmrRibbonTemplateBuilder.AddGroup(const ATab: TFmrRibbonTab; const AName, ACaption: string;
  const ALauncher: Boolean): TFmrRibbonGroup;
begin
  Result := TFmrRibbonStructure.CreateGroup(ATab, ACaption);
  Result.Name := NewName(AName);
  Track(Result);
  Result.ShowDialogLauncher := ALauncher;
end;

function TFmrRibbonTemplateBuilder.AddLink(const AGroup: TFmrRibbonGroup; const AItem: TFmrBarItem;
  const ALevels: TFmrViewLevels; const ABeginGroup: Boolean): TFmrItemLink;
begin
  Result := AGroup.ItemLinks.AddItem(AItem, ABeginGroup);
  Result.ViewLevels := ALevels;
end;

function TFmrRibbonTemplateBuilder.AddButton(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AGlyph: Cardinal; const ASize: TFmrTemplateButtonSize; const AStyle: TFmrButtonStyle;
  const ABeginGroup: Boolean): TFmrButtonItem;
var
  L: TFmrItemLink;
begin
  Result := TFmrButtonItem(NewItem(TFmrButtonItem, AName, ACaption));
  Result.ButtonStyle := AStyle;
  if AGlyph <> 0 then
    Result.Glyph.GlyphCode := AGlyph;
  if AGroup <> nil then
  begin
    L := AddLink(AGroup, Result, [], ABeginGroup);
    if ASize = TFmrTemplateButtonSize.IconOnly then
      L.ViewLevels := [TFmrViewLevel.Small]
    else if ASize = TFmrTemplateButtonSize.Large then
      L.ViewLevels := FmrAllViewLevels
    else if not Result.Glyph.IsEmpty then
      L.ViewLevels := FmrSmallViewLevels;
  end;
end;

procedure PlaceInRow(const ALink: TFmrItemLink; const APos: TFmrTemplateRowPos);
begin
  case APos of
    TFmrTemplateRowPos.NewRow:
      ALink.ButtonGroup := TFmrButtonGroupPosition.Start;
    TFmrTemplateRowPos.NewSegment:
      begin
        ALink.ButtonGroup := TFmrButtonGroupPosition.Member;
        ALink.BeginGroup := True;
      end;
    TFmrTemplateRowPos.Next:
      ALink.ButtonGroup := TFmrButtonGroupPosition.Member;
  end;
end;

function TFmrRibbonTemplateBuilder.AddGroupButton(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AGlyph: Cardinal; const APos: TFmrTemplateRowPos; const AStyle: TFmrButtonStyle): TFmrButtonItem;
begin
  Result := AddButton(nil, AName, ACaption, AGlyph, TFmrTemplateButtonSize.IconOnly, AStyle);
  PlaceInRow(AddLink(AGroup, Result, [TFmrViewLevel.Small]), APos);
end;

function TFmrRibbonTemplateBuilder.AddCheck(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AChecked: Boolean): TFmrCheckItem;
begin
  Result := TFmrCheckItem(NewItem(TFmrCheckItem, AName, ACaption));
  Result.Checked := AChecked;
  if AGroup <> nil then
    AddLink(AGroup, Result);
end;

function TFmrRibbonTemplateBuilder.AddColor(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AGlyph: Cardinal; const AColor: TAlphaColor; const ASize: TFmrTemplateButtonSize;
  const APos: TFmrTemplateRowPos): TFmrColorItem;
var
  L: TFmrItemLink;
begin
  Result := TFmrColorItem(NewItem(TFmrColorItem, AName, ACaption));
  Result.Color := AColor;
  Result.Glyph.GlyphCode := AGlyph;
  if AGroup <> nil then
  begin
    L := AddLink(AGroup, Result);
    if ASize = TFmrTemplateButtonSize.IconOnly then
    begin
      L.ViewLevels := [TFmrViewLevel.Small];
      PlaceInRow(L, APos);
    end
    else if ASize = TFmrTemplateButtonSize.Large then
      L.ViewLevels := FmrAllViewLevels
    else if not Result.Glyph.IsEmpty then
      L.ViewLevels := FmrSmallViewLevels;
  end;
end;

function TFmrRibbonTemplateBuilder.AddCombo(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AItems: array of string; const AText: string; const AWidth: Single; const AEditable,
  AShowCaption: Boolean): TFmrComboItem;
var
  S: string;
begin
  Result := TFmrComboItem(NewItem(TFmrComboItem, AName, ACaption));
  Result.Editable := AEditable;
  for S in AItems do
    Result.Items.Add(S);
  Result.Text := AText;
  Result.Width := AWidth;
  if AGroup <> nil then
  begin
    if AShowCaption then
      AddLink(AGroup, Result, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small])
    else
      AddLink(AGroup, Result, [TFmrViewLevel.Small]);
  end;
end;

function TFmrRibbonTemplateBuilder.AddFontName(const AGroup: TFmrRibbonGroup; const AName, AText: string;
  const AWidth: Single): TFmrFontNameItem;
var
  L: TFmrItemLink;
begin
  Result := TFmrFontNameItem(NewItem(TFmrFontNameItem, AName, 'Font'));
  Result.Text := AText;
  Result.Width := AWidth;
  Result.Hint := 'Font';
  if AGroup <> nil then
  begin
    L := AddLink(AGroup, Result, [TFmrViewLevel.Small]);
    L.ButtonGroup := TFmrButtonGroupPosition.Start;
  end;
end;

function TFmrRibbonTemplateBuilder.AddSpin(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AValue, AMin, AMax, AIncrement: Double; const ADigits: Integer; const AWidth: Single): TFmrSpinItem;
begin
  Result := TFmrSpinItem(NewItem(TFmrSpinItem, AName, ACaption));
  Result.Min := AMin;
  Result.Max := AMax;
  Result.Increment := AIncrement;
  Result.DecimalDigits := ADigits;
  Result.Value := AValue;
  Result.Width := AWidth;
  if AGroup <> nil then
    AddLink(AGroup, Result, [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small]);
end;

function TFmrRibbonTemplateBuilder.AddGallery(const AGroup: TFmrRibbonGroup; const AName, ACaption: string;
  const AGlyph: Cardinal; const AEntries: array of string; const AEntryGlyph: Cardinal): TFmrGalleryItem;
var
  G: TFmrGalleryGroup;
  E: TFmrGalleryEntry;
  S: string;
begin
  Result := TFmrGalleryItem(NewItem(TFmrGalleryItem, AName, ACaption));
  Result.Glyph.GlyphCode := AGlyph;
  Result.CaptionPosition := TFmrGalleryCaptionPosition.Bottom;
  Result.MinColumns := 2;
  Result.MaxColumns := 5;
  G := Result.Groups.Add(ACaption);
  for S in AEntries do
  begin
    E := G.Items.Add(S);
    if AEntryGlyph <> 0 then
      E.Glyph.GlyphCode := AEntryGlyph;
  end;
  if AGroup <> nil then
    AddLink(AGroup, Result);
end;

function TFmrRibbonTemplateBuilder.AddMenuItem(const AParent: TFmrButtonItem; const AName, ACaption: string;
  const AGlyph: Cardinal; const ABeginGroup: Boolean): TFmrButtonItem;
begin
  Result := AddButton(nil, AName, ACaption, AGlyph);
  AParent.DropDownLinks.AddItem(Result, ABeginGroup);
end;

procedure TFmrRibbonTemplateBuilder.AddToQAT(const AItem: TFmrBarItem);
var
  O: IFmrRibbonStructureOwner;
begin
  if (AItem <> nil) and Supports(FStructure, IFmrRibbonStructureOwner, O) and (O.GetQuickAccessToolbar <> nil) then
    O.GetQuickAccessToolbar.AddItem(AItem);
end;

procedure TFmrRibbonTemplateBuilder.ClearStructure;
var
  O: IFmrRibbonStructureOwner;
  T: TFmrRibbonTab;
  C: TFmrRibbonContextGroup;
begin
  if Supports(FStructure, IFmrRibbonStructureOwner, O) then
    O.BeginStructureUpdate;
  try
    for T in TFmrRibbonStructure.Tabs(FStructure) do
      T.Free;
    for C in TFmrRibbonStructure.ContextGroups(FStructure) do
      C.Free;
    if (O <> nil) and (O.GetQuickAccessToolbar <> nil) then
      O.GetQuickAccessToolbar.ItemLinks.Clear;
  finally
    if O <> nil then
      O.EndStructureUpdate;
  end;
end;

procedure TFmrRibbonTemplateBuilder.Build(const ATemplate: TFmrRibbonTemplate);
var
  O: IFmrRibbonStructureOwner;
begin
  if Supports(FStructure, IFmrRibbonStructureOwner, O) then
    O.BeginStructureUpdate;
  FManager.BeginUpdate;
  try
    case ATemplate of
      TFmrRibbonTemplate.Simple:
        BuildSimple;
      TFmrRibbonTemplate.Document:
        BuildDocument;
      TFmrRibbonTemplate.Spreadsheet:
        BuildSpreadsheet;
    end;
  finally
    FManager.EndUpdate;
    if O <> nil then
    begin
      O.EndStructureUpdate;
      if (FFirstTab <> nil) and (O.GetActiveTab = nil) then
        O.SetActiveTab(FFirstTab);
    end;
  end;
end;

class function TFmrRibbonTemplateBuilder.TemplateCaption(const ATemplate: TFmrRibbonTemplate): string;
begin
  case ATemplate of
    TFmrRibbonTemplate.Simple:
      Result := 'Simple';
    TFmrRibbonTemplate.Document:
      Result := 'Document';
    TFmrRibbonTemplate.Spreadsheet:
      Result := 'Spreadsheet';
  else
    Result := '';
  end;
end;

class function TFmrRibbonTemplateBuilder.TemplateDescription(const ATemplate: TFmrRibbonTemplate): string;
begin
  case ATemplate of
    TFmrRibbonTemplate.Simple:
      Result := 'Home (Clipboard, Font, Editing) and View (Zoom, Show); Save, Undo and Redo in the quick access ' +
        'toolbar.';
    TFmrRibbonTemplate.Document:
      Result := 'Home (Clipboard, Font, Paragraph, Styles, Editing), Insert (Pages, Tables, Illustrations, Links, ' +
        'Comments, Header & Footer, Text, Symbols), Layout (Page Setup, Paragraph, Arrange), View (Views, Show, ' +
        'Zoom, Window) and the "Table Tools" contextual tabs.';
    TFmrRibbonTemplate.Spreadsheet:
      Result := 'Home (Clipboard, Font, Alignment, Number, Styles, Cells, Editing), Insert (Tables, ' +
        'Illustrations, Charts, Text), Formulas (Function Library, Defined Names, Calculation), Data (Get Data, ' +
        'Sort & Filter, Data Tools) and View (Workbook Views, Show, Zoom, Window).';
  else
    Result := '';
  end;
end;

procedure TFmrRibbonTemplateBuilder.AddStandardQAT;
var
  SaveCat: string;
  Save, Undo, Redo: TFmrButtonItem;
begin
  SaveCat := FCategory;
  FCategory := 'Quick Access';
  AddCategory(FCategory);
  Save := AddButton(nil, 'btnSave', 'Save', FmrGlyphSave);
  Save.ShortCut := CtrlKey('S');
  Save.Hint := 'Save (Ctrl+S)';
  Undo := AddButton(nil, 'btnUndo', 'Undo', FmrGlyphUndo);
  Undo.ShortCut := CtrlKey('Z');
  Undo.Hint := 'Undo (Ctrl+Z)';
  Redo := AddButton(nil, 'btnRedo', 'Redo', FmrGlyphRedo);
  Redo.ShortCut := CtrlKey('Y');
  Redo.Hint := 'Redo (Ctrl+Y)';
  AddToQAT(Save);
  AddToQAT(Undo);
  AddToQAT(Redo);
  FCategory := SaveCat;
end;

procedure TFmrRibbonTemplateBuilder.AddClipboardGroup(const ATab: TFmrRibbonTab; const AFull: Boolean);
var
  G: TFmrRibbonGroup;
  Paste, B: TFmrButtonItem;
begin
  G := AddGroup(ATab, 'grpClipboard', 'Clipboard', AFull);
  Paste := AddButton(G, 'btnPaste', 'Paste', FmrGlyphPaste, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.Split);
  Paste.ShortCut := CtrlKey('V');
  Paste.KeyTip := 'V';
  Paste.ScreenTip.Header := 'Paste';
  Paste.ScreenTip.Description := 'Add content from the Clipboard.';
  AddMenuItem(Paste, 'btnPasteKeepText', 'Keep Text Only', FmrGlyphFont);
  AddMenuItem(Paste, 'btnPasteSpecial', 'Paste Special...', FmrGlyphPaste, True);
  B := AddButton(G, 'btnCut', 'Cut', FmrGlyphCut);
  B.ShortCut := CtrlKey('X');
  B.KeyTip := 'X';
  B := AddButton(G, 'btnCopy', 'Copy', FmrGlyphCopy);
  B.ShortCut := CtrlKey('C');
  B.KeyTip := 'C';
  if AFull then
  begin
    B := AddButton(G, 'btnFormatPainter', 'Format Painter', FmrGlyphFormatPainter);
    B.ButtonStyle := TFmrButtonStyle.Check;
    B.KeyTip := 'FP';
  end;
end;

procedure TFmrRibbonTemplateBuilder.BuildSimple;
var
  Home, View: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B: TFmrButtonItem;
begin
  Home := AddTab('tabHome', 'Home', 'H');
  AddClipboardGroup(Home, False);

  G := AddGroup(Home, 'grpFont', 'Font');
  B := AddGroupButton(G, 'btnBold', 'Bold', FmrGlyphBold, TFmrTemplateRowPos.NewRow, TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('B');
  B := AddGroupButton(G, 'btnItalic', 'Italic', FmrGlyphItalic, TFmrTemplateRowPos.Next, TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('I');
  B := AddGroupButton(G, 'btnUnderline', 'Underline', FmrGlyphUnderline, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('U');
  AddColor(G, 'clrFontColor', 'Font Color', FmrGlyphFontColor, TAlphaColors.Red, TFmrTemplateButtonSize.IconOnly,
    TFmrTemplateRowPos.NewRow);

  G := AddGroup(Home, 'grpEditing', 'Editing');
  B := AddButton(G, 'btnFind', 'Find', FmrGlyphFind);
  B.ShortCut := CtrlKey('F');
  B := AddButton(G, 'btnReplace', 'Replace', FmrGlyphReplace);
  B.ShortCut := CtrlKey('H');
  B := AddButton(G, 'btnSelectAll', 'Select All', FmrGlyphSelect);
  B.ShortCut := CtrlKey('A');

  View := AddTab('tabView', 'View', 'W');
  G := AddGroup(View, 'grpZoom', 'Zoom');
  AddButton(G, 'btnZoom', 'Zoom', FmrGlyphZoom, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnZoomIn', 'Zoom In', FmrGlyphZoomIn);
  AddButton(G, 'btnZoomOut', 'Zoom Out', FmrGlyphZoomOut);
  AddButton(G, 'btnZoom100', '100%', FmrGlyphPercent);
  G := AddGroup(View, 'grpShow', 'Show');
  AddCheck(G, 'chkRuler', 'Ruler');
  AddCheck(G, 'chkStatusBar', 'Status Bar', True);

  AddStandardQAT;
end;

procedure TFmrRibbonTemplateBuilder.BuildDocument;
const
  FontSizes: array[0..15] of string = ('8', '9', '10', '10.5', '11', '12', '14', '16', '18', '20', '24', '28', '36',
    '48', '72', '96');
var
  Home, Insert, Layout, View, TabDesign, TabTableLayout: TFmrRibbonTab;
  Ctx: TFmrRibbonContextGroup;
  G: TFmrRibbonGroup;
  B, Menu: TFmrButtonItem;
  Gal: TFmrGalleryItem;
begin
  { Home }
  Home := AddTab('tabHome', 'Home', 'H');
  AddClipboardGroup(Home, True);

  G := AddGroup(Home, 'grpFont', 'Font', True);
  AddFontName(G, 'cmbFontName', 'Calibri', 120);
  AddCombo(G, 'cmbFontSize', 'Font Size', FontSizes, '11', 54).Hint := 'Font Size';
  G.ItemLinks[G.ItemLinks.Count - 1].ButtonGroup := TFmrButtonGroupPosition.Member;
  AddGroupButton(G, 'btnGrowFont', 'Increase Font Size', FmrGlyphFontIncrease, TFmrTemplateRowPos.NewSegment);
  AddGroupButton(G, 'btnShrinkFont', 'Decrease Font Size', FmrGlyphFontDecrease, TFmrTemplateRowPos.Next);
  AddGroupButton(G, 'btnChangeCase', 'Change Case', FmrGlyphChangeCase, TFmrTemplateRowPos.NewSegment,
    TFmrButtonStyle.DropDown);
  AddGroupButton(G, 'btnClearFormatting', 'Clear All Formatting', FmrGlyphClearFormatting,
    TFmrTemplateRowPos.NewSegment);
  B := AddGroupButton(G, 'btnBold', 'Bold', FmrGlyphBold, TFmrTemplateRowPos.NewRow, TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('B');
  B.KeyTip := '1';
  B := AddGroupButton(G, 'btnItalic', 'Italic', FmrGlyphItalic, TFmrTemplateRowPos.Next, TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('I');
  B.KeyTip := '2';
  B := AddGroupButton(G, 'btnUnderline', 'Underline', FmrGlyphUnderline, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Split);
  B.ShortCut := CtrlKey('U');
  B.KeyTip := '3';
  AddMenuItem(B, 'btnUnderlineDouble', 'Double Underline');
  AddMenuItem(B, 'btnUnderlineDotted', 'Dotted Underline');
  AddGroupButton(G, 'btnStrikethrough', 'Strikethrough', FmrGlyphStrikethrough, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check);
  AddColor(G, 'clrHighlight', 'Text Highlight Color', FmrGlyphHighlight, TAlphaColors.Yellow,
    TFmrTemplateButtonSize.IconOnly, TFmrTemplateRowPos.NewSegment);
  AddColor(G, 'clrFontColor', 'Font Color', FmrGlyphFontColor, TAlphaColors.Red, TFmrTemplateButtonSize.IconOnly,
    TFmrTemplateRowPos.Next);

  G := AddGroup(Home, 'grpParagraph', 'Paragraph', True);
  AddGroupButton(G, 'btnBullets', 'Bullets', FmrGlyphBullets, TFmrTemplateRowPos.NewRow, TFmrButtonStyle.Split);
  AddGroupButton(G, 'btnNumbering', 'Numbering', FmrGlyphNumbering, TFmrTemplateRowPos.Next, TFmrButtonStyle.Split);
  AddGroupButton(G, 'btnMultilevelList', 'Multilevel List', FmrGlyphMultilevel, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.DropDown);
  AddGroupButton(G, 'btnDecreaseIndent', 'Decrease Indent', FmrGlyphIndentDecrease, TFmrTemplateRowPos.NewSegment);
  AddGroupButton(G, 'btnIncreaseIndent', 'Increase Indent', FmrGlyphIndentIncrease, TFmrTemplateRowPos.Next);
  AddGroupButton(G, 'btnSort', 'Sort', FmrGlyphSort, TFmrTemplateRowPos.NewSegment);
  AddGroupButton(G, 'btnShowMarks', 'Show/Hide Paragraph Marks', FmrGlyphParagraphMark,
    TFmrTemplateRowPos.NewSegment, TFmrButtonStyle.Check);
  B := AddGroupButton(G, 'btnAlignLeft', 'Align Left', FmrGlyphAlignLeft, TFmrTemplateRowPos.NewRow,
    TFmrButtonStyle.Check);
  B.GroupIndex := 1;
  B.Down := True;
  AddGroupButton(G, 'btnAlignCenter', 'Center', FmrGlyphAlignCenter, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check).GroupIndex := 1;
  AddGroupButton(G, 'btnAlignRight', 'Align Right', FmrGlyphAlignRight, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check).GroupIndex := 1;
  AddGroupButton(G, 'btnJustify', 'Justify', FmrGlyphJustify, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check).GroupIndex := 1;
  AddGroupButton(G, 'btnLineSpacing', 'Line and Paragraph Spacing', FmrGlyphLineSpacing,
    TFmrTemplateRowPos.NewSegment, TFmrButtonStyle.DropDown);
  AddColor(G, 'clrShading', 'Shading', FmrGlyphShading, TAlphaColors.Null, TFmrTemplateButtonSize.IconOnly,
    TFmrTemplateRowPos.NewSegment);
  AddGroupButton(G, 'btnBorders', 'Borders', FmrGlyphBorders, TFmrTemplateRowPos.Next, TFmrButtonStyle.Split);

  G := AddGroup(Home, 'grpStyles', 'Styles', True);
  Gal := AddGallery(G, 'galStyles', 'Styles', FmrGlyphFont, ['Normal', 'No Spacing', 'Heading 1', 'Heading 2',
    'Title', 'Subtitle', 'Subtle Emphasis', 'Emphasis', 'Intense Emphasis', 'Strong', 'Quote', 'Intense Quote'],
    FmrGlyphFont);
  Gal.SelectedIndex := 0;
  Gal.DropDownLinks.AddItem(AddButton(nil, 'btnCreateStyle', 'Create a Style', FmrGlyphEdit));
  Gal.DropDownLinks.AddItem(AddButton(nil, 'btnClearStyle', 'Clear Formatting', FmrGlyphClearFormatting));
  Gal.DropDownLinks.AddItem(AddButton(nil, 'btnApplyStyles', 'Apply Styles...', FmrGlyphFont));

  G := AddGroup(Home, 'grpEditing', 'Editing');
  B := AddButton(G, 'btnFind', 'Find', FmrGlyphFind, TFmrTemplateButtonSize.Small, TFmrButtonStyle.Split);
  B.ShortCut := CtrlKey('F');
  B.KeyTip := 'FD';
  AddMenuItem(B, 'btnAdvancedFind', 'Advanced Find...', FmrGlyphFind);
  AddMenuItem(B, 'btnGoTo', 'Go To...', 0);
  B := AddButton(G, 'btnReplace', 'Replace', FmrGlyphReplace);
  B.ShortCut := CtrlKey('H');
  Menu := AddButton(G, 'btnSelect', 'Select', FmrGlyphSelect, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  AddMenuItem(Menu, 'btnSelectAll', 'Select All', FmrGlyphSelect).ShortCut := CtrlKey('A');
  AddMenuItem(Menu, 'btnSelectObjects', 'Select Objects', 0);
  AddMenuItem(Menu, 'btnSelectionPane', 'Selection Pane...', 0, True);

  { Insert }
  Insert := AddTab('tabInsert', 'Insert', 'N');
  G := AddGroup(Insert, 'grpPages', 'Pages');
  AddButton(G, 'btnCoverPage', 'Cover Page', FmrGlyphCoverPage, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  AddButton(G, 'btnBlankPage', 'Blank Page', FmrGlyphBlankPage);
  AddButton(G, 'btnPageBreak', 'Page Break', FmrGlyphPageBreak);
  G := AddGroup(Insert, 'grpTables', 'Tables');
  Menu := AddButton(G, 'btnTable', 'Table', FmrGlyphTable, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddMenuItem(Menu, 'btnInsertTable', 'Insert Table...', FmrGlyphTable);
  AddMenuItem(Menu, 'btnDrawTable', 'Draw Table', FmrGlyphEdit);
  AddMenuItem(Menu, 'btnQuickTables', 'Quick Tables', 0, True);
  G := AddGroup(Insert, 'grpIllustrations', 'Illustrations');
  AddButton(G, 'btnPictures', 'Pictures', FmrGlyphPictures, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnShapes', 'Shapes', FmrGlyphShapes, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnIcons', 'Icons', FmrGlyphIcons, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnDiagram', 'Diagram', FmrGlyphDiagram);
  AddButton(G, 'btnChart', 'Chart', FmrGlyphChart);
  AddButton(G, 'btnScreenshot', 'Screenshot', FmrGlyphScreenshot, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  G := AddGroup(Insert, 'grpLinks', 'Links');
  AddButton(G, 'btnLink', 'Link', FmrGlyphLink, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Split).ShortCut :=
    CtrlKey('K');
  AddButton(G, 'btnBookmark', 'Bookmark', FmrGlyphBookmark);
  AddButton(G, 'btnCrossReference', 'Cross-reference', FmrGlyphCrossReference);
  G := AddGroup(Insert, 'grpComments', 'Comments');
  AddButton(G, 'btnNewComment', 'Comment', FmrGlyphComment, TFmrTemplateButtonSize.Large);
  G := AddGroup(Insert, 'grpHeaderFooter', 'Header && Footer');
  AddButton(G, 'btnHeader', 'Header', FmrGlyphHeader, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnFooter', 'Footer', FmrGlyphFooter, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnPageNumber', 'Page Number', FmrGlyphPageNumber, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  G := AddGroup(Insert, 'grpText', 'Text');
  AddButton(G, 'btnTextBox', 'Text Box', FmrGlyphTextBox, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnTextEffects', 'Text Effects', FmrGlyphTextEffects, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnDropCap', 'Drop Cap', FmrGlyphDropCap, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  G := AddGroup(Insert, 'grpSymbols', 'Symbols');
  AddButton(G, 'btnEquation', 'Equation', FmrGlyphEquation, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Split);
  AddButton(G, 'btnSymbol', 'Symbol', FmrGlyphSymbol, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);

  { Layout }
  Layout := AddTab('tabLayout', 'Layout', 'P');
  G := AddGroup(Layout, 'grpPageSetup', 'Page Setup', True);
  Menu := AddButton(G, 'btnMargins', 'Margins', FmrGlyphMargins, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  AddMenuItem(Menu, 'btnMarginsNormal', 'Normal');
  AddMenuItem(Menu, 'btnMarginsNarrow', 'Narrow');
  AddMenuItem(Menu, 'btnMarginsWide', 'Wide');
  AddMenuItem(Menu, 'btnMarginsCustom', 'Custom Margins...', 0, True);
  Menu := AddButton(G, 'btnOrientation', 'Orientation', FmrGlyphOrientation, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  B := AddMenuItem(Menu, 'btnPortrait', 'Portrait');
  B.ButtonStyle := TFmrButtonStyle.Check;
  B.GroupIndex := 2;
  B.Down := True;
  B := AddMenuItem(Menu, 'btnLandscape', 'Landscape');
  B.ButtonStyle := TFmrButtonStyle.Check;
  B.GroupIndex := 2;
  AddButton(G, 'btnPageSize', 'Size', FmrGlyphSize, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnColumns', 'Columns', FmrGlyphColumns, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnBreaks', 'Breaks', FmrGlyphPageBreak, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnLineNumbers', 'Line Numbers', FmrGlyphLineNumbers, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  AddButton(G, 'btnHyphenation', 'Hyphenation', FmrGlyphHyphenation, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  G := AddGroup(Layout, 'grpLayoutParagraph', 'Paragraph', True);
  AddSpin(G, 'spnIndentLeft', 'Left:', 0, 0, 22, 0.1, 1, 64);
  AddSpin(G, 'spnIndentRight', 'Right:', 0, 0, 22, 0.1, 1, 64);
  AddSpin(G, 'spnSpacingBefore', 'Before:', 0, 0, 1584, 6, 0, 64);
  AddSpin(G, 'spnSpacingAfter', 'After:', 8, 0, 1584, 6, 0, 64);
  G.ItemLinks[2].BeginGroup := True;
  G := AddGroup(Layout, 'grpArrange', 'Arrange');
  AddButton(G, 'btnPosition', 'Position', FmrGlyphPosition, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnWrapText', 'Wrap Text', FmrGlyphWrapText, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnBringForward', 'Bring Forward', FmrGlyphBringForward, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.Split);
  AddButton(G, 'btnSendBackward', 'Send Backward', FmrGlyphSendBackward, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.Split);
  AddButton(G, 'btnRotate', 'Rotate', FmrGlyphRotate, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);

  { View }
  View := AddTab('tabView', 'View', 'W');
  G := AddGroup(View, 'grpViews', 'Views');
  B := AddButton(G, 'btnReadMode', 'Read Mode', FmrGlyphReadMode, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.Check);
  B.GroupIndex := 3;
  B := AddButton(G, 'btnPrintLayout', 'Print Layout', FmrGlyphPrintLayout, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.Check);
  B.GroupIndex := 3;
  B.Down := True;
  B := AddButton(G, 'btnWebLayout', 'Web Layout', FmrGlyphWebLayout, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.Check);
  B.GroupIndex := 3;
  G := AddGroup(View, 'grpShow', 'Show');
  AddCheck(G, 'chkRuler', 'Ruler');
  AddCheck(G, 'chkGridlines', 'Gridlines');
  AddCheck(G, 'chkNavigationPane', 'Navigation Pane');
  G := AddGroup(View, 'grpZoom', 'Zoom');
  AddButton(G, 'btnZoom', 'Zoom', FmrGlyphZoom, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnZoom100', '100%', FmrGlyphPercent, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnOnePage', 'One Page', FmrGlyphOnePage);
  AddButton(G, 'btnMultiplePages', 'Multiple Pages', FmrGlyphMultiplePages);
  AddButton(G, 'btnPageWidth', 'Page Width', FmrGlyphPageWidth);
  G := AddGroup(View, 'grpWindow', 'Window');
  AddButton(G, 'btnNewWindow', 'New Window', FmrGlyphNewWindow, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnArrangeAll', 'Arrange All', FmrGlyphArrangeAll);
  AddButton(G, 'btnSplit', 'Split', FmrGlyphSplit);
  AddButton(G, 'btnSwitchWindows', 'Switch Windows', FmrGlyphSwitchWindows, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);

  { Table Tools (contextual) }
  Ctx := AddContextGroup('ctxTableTools', 'Table Tools', TAlphaColor($FF2B579A));
  TabDesign := AddTab('tabTableDesign', 'Table Design', 'JT', Ctx);
  G := AddGroup(TabDesign, 'grpTableStyleOptions', 'Table Style Options');
  AddCheck(G, 'chkHeaderRow', 'Header Row', True);
  AddCheck(G, 'chkTotalRow', 'Total Row');
  AddCheck(G, 'chkBandedRows', 'Banded Rows', True);
  G := AddGroup(TabDesign, 'grpTableBorders', 'Borders', True);
  AddButton(G, 'btnTableBorders', 'Borders', FmrGlyphBorders, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Split);
  AddColor(G, 'clrTableShading', 'Shading', FmrGlyphShading, TAlphaColors.Null, TFmrTemplateButtonSize.Large);
  TabTableLayout := AddTab('tabTableLayout', 'Table Layout', 'JL', Ctx);
  G := AddGroup(TabTableLayout, 'grpRowsColumns', 'Rows && Columns', True);
  AddButton(G, 'btnDeleteCells', 'Delete', FmrGlyphDelete, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnInsertAbove', 'Insert Above', FmrGlyphSortUp, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnInsertBelow', 'Insert Below', FmrGlyphSortDown);
  AddButton(G, 'btnInsertLeft', 'Insert Left', FmrGlyphIndentDecrease);
  AddButton(G, 'btnInsertRight', 'Insert Right', FmrGlyphIndentIncrease);
  G := AddGroup(TabTableLayout, 'grpMerge', 'Merge');
  AddButton(G, 'btnMergeCells', 'Merge Cells', FmrGlyphMerge);
  AddButton(G, 'btnSplitCells', 'Split Cells', FmrGlyphColumns);
  AddButton(G, 'btnSplitTable', 'Split Table', FmrGlyphSplit);

  AddStandardQAT;
end;

procedure TFmrRibbonTemplateBuilder.BuildSpreadsheet;
const
  FontSizes: array[0..12] of string = ('8', '9', '10', '11', '12', '14', '16', '18', '20', '24', '28', '36', '48');
var
  Home, Insert, Formulas, Data, View: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  B, Menu: TFmrButtonItem;
begin
  { Home }
  Home := AddTab('tabHome', 'Home', 'H');
  AddClipboardGroup(Home, True);

  G := AddGroup(Home, 'grpFont', 'Font', True);
  AddFontName(G, 'cmbFontName', 'Calibri', 120);
  AddCombo(G, 'cmbFontSize', 'Font Size', FontSizes, '11', 54).Hint := 'Font Size';
  G.ItemLinks[G.ItemLinks.Count - 1].ButtonGroup := TFmrButtonGroupPosition.Member;
  AddGroupButton(G, 'btnGrowFont', 'Increase Font Size', FmrGlyphFontIncrease, TFmrTemplateRowPos.NewSegment);
  AddGroupButton(G, 'btnShrinkFont', 'Decrease Font Size', FmrGlyphFontDecrease, TFmrTemplateRowPos.Next);
  B := AddGroupButton(G, 'btnBold', 'Bold', FmrGlyphBold, TFmrTemplateRowPos.NewRow, TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('B');
  B.KeyTip := '1';
  B := AddGroupButton(G, 'btnItalic', 'Italic', FmrGlyphItalic, TFmrTemplateRowPos.Next, TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('I');
  B.KeyTip := '2';
  B := AddGroupButton(G, 'btnUnderline', 'Underline', FmrGlyphUnderline, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check);
  B.ShortCut := CtrlKey('U');
  B.KeyTip := '3';
  AddGroupButton(G, 'btnBorders', 'Borders', FmrGlyphBorders, TFmrTemplateRowPos.NewSegment, TFmrButtonStyle.Split);
  AddColor(G, 'clrFillColor', 'Fill Color', FmrGlyphShading, TAlphaColors.Yellow, TFmrTemplateButtonSize.IconOnly,
    TFmrTemplateRowPos.NewSegment);
  AddColor(G, 'clrFontColor', 'Font Color', FmrGlyphFontColor, TAlphaColors.Red, TFmrTemplateButtonSize.IconOnly,
    TFmrTemplateRowPos.Next);

  G := AddGroup(Home, 'grpAlignment', 'Alignment', True);
  B := AddGroupButton(G, 'btnAlignLeft', 'Align Left', FmrGlyphAlignLeft, TFmrTemplateRowPos.NewRow,
    TFmrButtonStyle.Check);
  B.GroupIndex := 1;
  AddGroupButton(G, 'btnAlignCenter', 'Center', FmrGlyphAlignCenter, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check).GroupIndex := 1;
  AddGroupButton(G, 'btnAlignRight', 'Align Right', FmrGlyphAlignRight, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.Check).GroupIndex := 1;
  AddGroupButton(G, 'btnTextOrientation', 'Orientation', FmrGlyphOrientation, TFmrTemplateRowPos.NewSegment,
    TFmrButtonStyle.DropDown);
  AddGroupButton(G, 'btnDecreaseIndent', 'Decrease Indent', FmrGlyphIndentDecrease, TFmrTemplateRowPos.NewRow);
  AddGroupButton(G, 'btnIncreaseIndent', 'Increase Indent', FmrGlyphIndentIncrease, TFmrTemplateRowPos.Next);
  AddButton(G, 'btnWrapText', 'Wrap Text', FmrGlyphWrapLine, TFmrTemplateButtonSize.Small, TFmrButtonStyle.Check,
    True);
  Menu := AddButton(G, 'btnMergeCenter', 'Merge && Center', FmrGlyphMerge, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.Split);
  AddMenuItem(Menu, 'btnMergeAcross', 'Merge Across');
  AddMenuItem(Menu, 'btnMergeCellsMenu', 'Merge Cells');
  AddMenuItem(Menu, 'btnUnmergeCells', 'Unmerge Cells');

  G := AddGroup(Home, 'grpNumber', 'Number', True);
  AddCombo(G, 'cmbNumberFormat', 'Number Format', ['General', 'Number', 'Currency', 'Accounting', 'Short Date',
    'Long Date', 'Time', 'Percentage', 'Fraction', 'Scientific', 'Text'], 'General', 110, False);
  AddGroupButton(G, 'btnCurrency', 'Accounting Number Format', FmrGlyphCurrency, TFmrTemplateRowPos.NewRow,
    TFmrButtonStyle.Split);
  AddGroupButton(G, 'btnPercent', 'Percent Style', FmrGlyphPercent, TFmrTemplateRowPos.Next);
  AddGroupButton(G, 'btnComma', 'Comma Style', FmrGlyphComma, TFmrTemplateRowPos.Next);
  AddGroupButton(G, 'btnIncreaseDecimal', 'Increase Decimal', FmrGlyphIncreaseDecimal, TFmrTemplateRowPos.NewSegment);
  AddGroupButton(G, 'btnDecreaseDecimal', 'Decrease Decimal', FmrGlyphDecreaseDecimal, TFmrTemplateRowPos.Next);

  G := AddGroup(Home, 'grpStyles', 'Styles');
  AddButton(G, 'btnConditionalFormatting', 'Conditional Formatting', FmrGlyphConditional,
    TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnFormatAsTable', 'Format as Table', FmrGlyphTable, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  AddButton(G, 'btnCellStyles', 'Cell Styles', FmrGlyphCellStyles, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);

  G := AddGroup(Home, 'grpCells', 'Cells');
  AddButton(G, 'btnInsertCells', 'Insert', FmrGlyphInsertCells, TFmrTemplateButtonSize.Small, TFmrButtonStyle.Split);
  AddButton(G, 'btnDeleteCells', 'Delete', FmrGlyphDelete, TFmrTemplateButtonSize.Small, TFmrButtonStyle.Split);
  AddButton(G, 'btnFormatCells', 'Format', FmrGlyphFormat, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);

  G := AddGroup(Home, 'grpEditing', 'Editing');
  AddButton(G, 'btnAutoSum', 'Sum', FmrGlyphAutoSum, TFmrTemplateButtonSize.Small, TFmrButtonStyle.Split);
  AddButton(G, 'btnFill', 'Fill', FmrGlyphFill, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnClear', 'Clear', FmrGlyphClear, TFmrTemplateButtonSize.Small, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnSortFilter', 'Sort && Filter', FmrGlyphSort, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  B := AddButton(G, 'btnFindSelect', 'Find && Select', FmrGlyphFind, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  AddMenuItem(B, 'btnFind', 'Find...', FmrGlyphFind).ShortCut := CtrlKey('F');
  AddMenuItem(B, 'btnReplace', 'Replace...', FmrGlyphReplace).ShortCut := CtrlKey('H');
  AddMenuItem(B, 'btnGoTo', 'Go To...', 0).ShortCut := CtrlKey('G');

  { Insert }
  Insert := AddTab('tabInsert', 'Insert', 'N');
  G := AddGroup(Insert, 'grpTables', 'Tables');
  AddButton(G, 'btnPivotTable', 'Pivot Table', FmrGlyphPivotTable, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Split);
  AddButton(G, 'btnTable', 'Table', FmrGlyphTable, TFmrTemplateButtonSize.Large).ShortCut := CtrlKey('T');
  G := AddGroup(Insert, 'grpIllustrations', 'Illustrations');
  AddButton(G, 'btnPictures', 'Pictures', FmrGlyphPictures, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnShapes', 'Shapes', FmrGlyphShapes);
  AddButton(G, 'btnIcons', 'Icons', FmrGlyphIcons);
  AddButton(G, 'btnDiagram', 'Diagram', FmrGlyphDiagram);
  G := AddGroup(Insert, 'grpCharts', 'Charts', True);
  AddButton(G, 'btnRecommendedCharts', 'Recommended Charts', FmrGlyphChart, TFmrTemplateButtonSize.Large);
  AddGroupButton(G, 'btnColumnChart', 'Column Chart', FmrGlyphColumnChart, TFmrTemplateRowPos.NewRow,
    TFmrButtonStyle.DropDown);
  AddGroupButton(G, 'btnLineChart', 'Line Chart', FmrGlyphLineChart, TFmrTemplateRowPos.Next,
    TFmrButtonStyle.DropDown);
  AddGroupButton(G, 'btnPieChart', 'Pie Chart', FmrGlyphPieChart, TFmrTemplateRowPos.Next, TFmrButtonStyle.DropDown);
  G := AddGroup(Insert, 'grpText', 'Text');
  AddButton(G, 'btnTextBox', 'Text Box', FmrGlyphTextBox, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnHeaderFooter', 'Header && Footer', FmrGlyphHeader, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnSymbol', 'Symbol', FmrGlyphSymbol, TFmrTemplateButtonSize.Large);

  { Formulas }
  Formulas := AddTab('tabFormulas', 'Formulas', 'M');
  G := AddGroup(Formulas, 'grpFunctionLibrary', 'Function Library');
  AddButton(G, 'btnInsertFunction', 'Insert Function', FmrGlyphFunction, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnFormulaAutoSum', 'Sum', FmrGlyphAutoSum, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Split);
  AddButton(G, 'btnRecentlyUsed', 'Recently Used', FmrGlyphRecent, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  AddButton(G, 'btnFinancial', 'Financial', FmrGlyphFinancial, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnLogical', 'Logical', FmrGlyphLogical, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnTextFunctions', 'Text', FmrGlyphFont, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnDateTime', 'Date && Time', FmrGlyphDateTime, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  G := AddGroup(Formulas, 'grpDefinedNames', 'Defined Names');
  AddButton(G, 'btnNameManager', 'Name Manager', FmrGlyphNameManager, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnDefineName', 'Define Name', FmrGlyphEdit, TFmrTemplateButtonSize.Small, TFmrButtonStyle.Split);
  AddButton(G, 'btnUseInFormula', 'Use in Formula', FmrGlyphFunction, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);
  G := AddGroup(Formulas, 'grpCalculation', 'Calculation');
  AddButton(G, 'btnCalculationOptions', 'Calculation Options', FmrGlyphFormat, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  AddButton(G, 'btnCalculateNow', 'Calculate Now', FmrGlyphCalculate);
  AddButton(G, 'btnCalculateSheet', 'Calculate Sheet', FmrGlyphPrintLayout);

  { Data }
  Data := AddTab('tabData', 'Data', 'A');
  G := AddGroup(Data, 'grpGetData', 'Get && Transform Data');
  AddButton(G, 'btnGetData', 'Get Data', FmrGlyphGetData, TFmrTemplateButtonSize.Large, TFmrButtonStyle.DropDown);
  AddButton(G, 'btnRefreshAll', 'Refresh All', FmrGlyphRefresh, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Split);
  G := AddGroup(Data, 'grpSortFilter', 'Sort && Filter');
  AddButton(G, 'btnSortAZ', 'Sort A to Z', FmrGlyphSortUp, TFmrTemplateButtonSize.IconOnly);
  AddButton(G, 'btnSortZA', 'Sort Z to A', FmrGlyphSortDown, TFmrTemplateButtonSize.IconOnly);
  AddButton(G, 'btnSort', 'Sort', FmrGlyphSort, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnFilter', 'Filter', FmrGlyphFilter, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Check);
  AddButton(G, 'btnClearFilter', 'Clear', FmrGlyphClear);
  G := AddGroup(Data, 'grpDataTools', 'Data Tools');
  AddButton(G, 'btnTextToColumns', 'Text to Columns', FmrGlyphTextToColumns, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnRemoveDuplicates', 'Remove Duplicates', FmrGlyphRemoveDuplicates);
  AddButton(G, 'btnDataValidation', 'Data Validation', FmrGlyphValidation, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.Split);

  { View }
  View := AddTab('tabView', 'View', 'W');
  G := AddGroup(View, 'grpWorkbookViews', 'Workbook Views');
  B := AddButton(G, 'btnNormalView', 'Normal', FmrGlyphTable, TFmrTemplateButtonSize.Large, TFmrButtonStyle.Check);
  B.GroupIndex := 3;
  B.Down := True;
  B := AddButton(G, 'btnPageBreakPreview', 'Page Break Preview', FmrGlyphWrapText, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.Check);
  B.GroupIndex := 3;
  B := AddButton(G, 'btnPageLayoutView', 'Page Layout', FmrGlyphPrintLayout, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.Check);
  B.GroupIndex := 3;
  G := AddGroup(View, 'grpShow', 'Show');
  AddCheck(G, 'chkRuler', 'Ruler', True);
  AddCheck(G, 'chkGridlines', 'Gridlines', True);
  AddCheck(G, 'chkFormulaBar', 'Formula Bar', True);
  AddCheck(G, 'chkHeadings', 'Headings', True);
  G := AddGroup(View, 'grpZoom', 'Zoom');
  AddButton(G, 'btnZoom', 'Zoom', FmrGlyphZoom, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnZoom100', '100%', FmrGlyphPercent, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnZoomToSelection', 'Zoom to Selection', FmrGlyphZoomSelection, TFmrTemplateButtonSize.Large);
  G := AddGroup(View, 'grpWindow', 'Window');
  AddButton(G, 'btnNewWindow', 'New Window', FmrGlyphNewWindow, TFmrTemplateButtonSize.Large);
  AddButton(G, 'btnFreezePanes', 'Freeze Panes', FmrGlyphFreezePanes, TFmrTemplateButtonSize.Large,
    TFmrButtonStyle.DropDown);
  AddButton(G, 'btnSplit', 'Split', FmrGlyphSplit);
  AddButton(G, 'btnSwitchWindows', 'Switch Windows', FmrGlyphSwitchWindows, TFmrTemplateButtonSize.Small,
    TFmrButtonStyle.DropDown);

  AddStandardQAT;
end;

end.
