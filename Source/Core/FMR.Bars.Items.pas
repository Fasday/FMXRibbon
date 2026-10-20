{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Concrete bar items                                   }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Bars.Items;

/// Concrete items. Button-like items (button, sub item, static, check, color) are painted by the ribbon; editor
/// items (edit, combo, spin, track bar, font name) only hold data: the ribbon creates an FMX control for every link
/// and keeps it in sync (TFmrItemChange.Value). TFmrGalleryItem is the data model of in-ribbon and drop-down
/// galleries.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, FMX.Types, FMX.Controls, FMR.Ribbon.Types,
  FMR.Bars.Images, FMR.Bars;

type
  /// <summary>Command button: plain, check (toggle, radio with GroupIndex), drop-down or split.</summary>
  TFmrButtonItem = class(TFmrBarItem, IFmrItemLinksOwner)
  private
    FButtonStyle: TFmrButtonStyle;
    FDown: Boolean;
    FGroupIndex: Integer;
    FAllowAllUp: Boolean;
    FPrimary: Boolean;
    FDropDownLinks: TFmrItemLinks;
    FOnDropDown: TNotifyEvent;
    procedure SetPrimary(const Value: Boolean);
    procedure SetButtonStyle(const Value: TFmrButtonStyle);
    procedure SetDown(const Value: Boolean);
    procedure SetGroupIndex(const Value: Integer);
    procedure SetAllowAllUp(const Value: Boolean);
    procedure SetDropDownLinks(const Value: TFmrItemLinks);
    function IsDropDownLinksStored: Boolean;
    procedure UncheckGroup;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    function GetIsChecked: Boolean; override;
    procedure SetIsChecked(const Value: Boolean); override;
    function SupportsChecked: Boolean; override;
    function GetGroupIndexValue: Integer; override;
    procedure SetGroupIndexValue(const Value: Integer); override;
    procedure DoClick; override;
    procedure DoDropDown; virtual;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Called by the ribbon before it shows the drop-down (OnDropDown fills DropDownLinks lazily).
    /// </summary>
    procedure DropDown;
    /// <summary>True when the button has a drop-down part (DropDown or Split style).</summary>
    function HasDropDown: Boolean;
  published
    property AllowAllUp: Boolean read FAllowAllUp write SetAllowAllUp default False;
    property ButtonStyle: TFmrButtonStyle read FButtonStyle write SetButtonStyle default TFmrButtonStyle.Default;
    property Down: Boolean read FDown write SetDown default False;
    /// <summary>Content of the drop-down menu (links to other items, a gallery item...).</summary>
    property DropDownLinks: TFmrItemLinks read FDropDownLinks write SetDropDownLinks stored IsDropDownLinksStored;
    /// <summary>Buttons with the same GroupIndex (not 0) in one manager are exclusive (radio).</summary>
    property GroupIndex: Integer read FGroupIndex write SetGroupIndex default 0;
    /// <summary>Filled with the accent color in every state, like a "Share" button (PrimaryButton*
    /// tokens).</summary>
    property Primary: Boolean read FPrimary write SetPrimary default False;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
  end;

  /// <summary>Account picture of the caption row: the initials of a user in a colored circle; a click opens the
  /// DropDownLinks (account menu) or runs OnClick.</summary>
  TFmrAvatarItem = class(TFmrButtonItem)
  private
    FInitials: string;
    FColor: TAlphaColor;
    procedure SetInitials(const Value: string);
    procedure SetColor(const Value: TAlphaColor);
  published
    /// <summary>Text in the circle (one or two letters).</summary>
    property Initials: string read FInitials write SetInitials;
    /// <summary>Color of the circle; Null = the accent color of the theme.</summary>
    property Color: TAlphaColor read FColor write SetColor default TAlphaColors.Null;
  end;

  /// <summary>Sub menu: clicking it shows ItemLinks.</summary>
  TFmrSubItem = class(TFmrBarItem, IFmrItemLinksOwner)
  private
    FItemLinks: TFmrItemLinks;
    FOnPopup: TNotifyEvent;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    procedure DoClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Called by the ribbon before the sub menu is shown (OnPopup).</summary>
    procedure Popup;
  published
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
  end;

  /// <summary>Separator line; in menus a non-empty Caption makes it a header.</summary>
  TFmrSeparatorItem = class(TFmrBarItem)
  public
    function DefaultViewLevels: TFmrViewLevels; override;
    function LayoutKind: TFmrLayoutItemKind; override;
  end;

  /// <summary>Text label (optionally with a glyph).</summary>
  TFmrStaticItem = class(TFmrBarItem)
  private
    FAlignment: TTextAlign;
    FWidth: Single;
    procedure SetAlignment(const Value: TTextAlign);
    procedure SetWidth(const Value: Single);
    function IsWidthStored: Boolean;
  published
    property Alignment: TTextAlign read FAlignment write SetAlignment default TTextAlign.Leading;
    /// <summary>Fixed width in dp; 0 = fit the caption.</summary>
    property Width: Single read FWidth write SetWidth stored IsWidthStored;
  end;

  /// <summary>Hosts an existing FMX control. A control has one parent, so it is shown by one link at a time.
  /// </summary>
  TFmrControlItem = class(TFmrBarItem)
  private
    FControl: TControl;
    FWidth: Single;
    procedure SetControl(const Value: TControl);
    procedure SetWidth(const Value: Single);
    function IsWidthStored: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    function DefaultViewLevels: TFmrViewLevels; override;
    function LayoutKind: TFmrLayoutItemKind; override;
  published
    property Control: TControl read FControl write SetControl;
    /// <summary>Width in dp; 0 = the width of the control.</summary>
    property Width: Single read FWidth write SetWidth stored IsWidthStored;
  end;

  /// <summary>Base of editor items: the ribbon creates a control per link (caption label + editor at
  /// SmallWithText, the editor only at Small).</summary>
  TFmrCustomEditItem = class(TFmrBarItem)
  public const
    DefaultEditWidth = 100;
  private
    FWidth: Single;
    FReadOnly: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetWidth(const Value: Single);
    procedure SetReadOnly(const Value: Boolean);
    function IsWidthStored: Boolean;
  protected
    /// <summary>Notifies Value change and fires OnChange.</summary>
    procedure DoChange; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    function DefaultViewLevels: TFmrViewLevels; override;
    function LayoutKind: TFmrLayoutItemKind; override;
  published
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    /// <summary>Width of the editor in dp (without the caption).</summary>
    property Width: Single read FWidth write SetWidth stored IsWidthStored;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  /// <summary>Single-line text editor.</summary>
  TFmrEditItem = class(TFmrCustomEditItem)
  private
    FText: string;
    FTextPrompt: string;
    FMaxLength: Integer;
    procedure SetText(const Value: string);
    procedure SetTextPrompt(const Value: string);
    procedure SetMaxLength(const Value: Integer);
  published
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    property Text: string read FText write SetText;
    property TextPrompt: string read FTextPrompt write SetTextPrompt;
  end;

  /// <summary>Combo box (drop-down list) or combo edit (Editable).</summary>
  TFmrComboItem = class(TFmrCustomEditItem)
  private
    FItems: TStrings;
    FItemIndex: Integer;
    FDropDownCount: Integer;
    FEditable: Boolean;
    FText: string;
    procedure SetItems(const Value: TStrings);
    procedure SetItemIndex(const Value: Integer);
    procedure SetDropDownCount(const Value: Integer);
    procedure SetEditable(const Value: Boolean);
    function GetText: string;
    procedure SetText(const Value: string);
    function IsTextStored: Boolean;
    procedure ItemsChanged(Sender: TObject);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property DropDownCount: Integer read FDropDownCount write SetDropDownCount default 8;
    property Editable: Boolean read FEditable write SetEditable default False;
    property Items: TStrings read FItems write SetItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;
    /// <summary>Selected text; free text when Editable.</summary>
    property Text: string read GetText write SetText stored IsTextStored;
  end;

  /// <summary>Numeric editor with up/down buttons.</summary>
  TFmrSpinItem = class(TFmrCustomEditItem)
  private
    FValue: Double;
    FMin: Double;
    FMax: Double;
    FIncrement: Double;
    FDecimalDigits: Integer;
    procedure SetValue(const AValue: Double);
    procedure SetMin(const AValue: Double);
    procedure SetMax(const AValue: Double);
    procedure SetIncrement(const AValue: Double);
    procedure SetDecimalDigits(const AValue: Integer);
    function IsValueStored: Boolean;
    function IsMinStored: Boolean;
    function IsMaxStored: Boolean;
    function IsIncrementStored: Boolean;
    function Clamp(const AValue: Double): Double;
  public
    constructor Create(AOwner: TComponent); override;
    procedure StepUp;
    procedure StepDown;
  published
    property DecimalDigits: Integer read FDecimalDigits write SetDecimalDigits default 0;
    property Increment: Double read FIncrement write SetIncrement stored IsIncrementStored;
    /// <summary>Upper limit; no limits when Max is not greater than Min.</summary>
    property Max: Double read FMax write SetMax stored IsMaxStored;
    property Min: Double read FMin write SetMin stored IsMinStored;
    property Value: Double read FValue write SetValue stored IsValueStored;
  end;

  /// <summary>Track bar (zoom slider and the like).</summary>
  TFmrTrackBarItem = class(TFmrCustomEditItem)
  private
    FValue: Single;
    FMin: Single;
    FMax: Single;
    procedure SetValue(const AValue: Single);
    procedure SetMin(const AValue: Single);
    procedure SetMax(const AValue: Single);
    function IsValueStored: Boolean;
    function IsMinStored: Boolean;
    function IsMaxStored: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Max: Single read FMax write SetMax stored IsMaxStored;
    property Min: Single read FMin write SetMin stored IsMinStored;
    property Value: Single read FValue write SetValue stored IsValueStored;
  end;

  /// <summary>Combo with the font families of the system. Items are filled by RefreshFonts through
  /// FontListProvider (set by the platform part of the ribbon).</summary>
  TFmrFontNameItem = class(TFmrComboItem)
  private class var
    FFontListProvider: TProc<TStrings>;
  private
    FShowFontPreview: Boolean;
    procedure SetShowFontPreview(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    /// <summary>Refills Items with the font families (sorted, unique).</summary>
    procedure RefreshFonts;
    /// <summary>Fills a list with the font families of the system.</summary>
    class property FontListProvider: TProc<TStrings> read FFontListProvider write FFontListProvider;
  published
    property Editable default True;
    /// <summary>The drop-down shows every family in its own face.</summary>
    property ShowFontPreview: Boolean read FShowFontPreview write SetShowFontPreview default True;
  end;

  /// <summary>Look of a check item in the ribbon and its toolbars.</summary>
  TFmrCheckStyle = (
    /// <summary>A check box (a radio button with a GroupIndex) before the caption.</summary>
    CheckBox,
    /// <summary>The caption followed by a toggle switch (an "AutoSave" switch).</summary>
    ToggleSwitch);

  /// <summary>Check box item painted by the ribbon; exclusive (radio) with a GroupIndex other than 0.</summary>
  TFmrCheckItem = class(TFmrBarItem)
  private
    FChecked: Boolean;
    FGroupIndex: Integer;
    FCheckStyle: TFmrCheckStyle;
    FOnChange: TNotifyEvent;
    procedure SetChecked(const Value: Boolean);
    procedure SetGroupIndex(const Value: Integer);
    procedure SetCheckStyle(const Value: TFmrCheckStyle);
  protected
    function GetIsChecked: Boolean; override;
    procedure SetIsChecked(const Value: Boolean); override;
    function SupportsChecked: Boolean; override;
    function GetGroupIndexValue: Integer; override;
    procedure SetGroupIndexValue(const Value: Integer); override;
    procedure DoClick; override;
  public
    function DefaultViewLevels: TFmrViewLevels; override;
  published
    property Checked: Boolean read FChecked write SetChecked default False;
    property CheckStyle: TFmrCheckStyle read FCheckStyle write SetCheckStyle default TFmrCheckStyle.CheckBox;
    property GroupIndex: Integer read FGroupIndex write SetGroupIndex default 0;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  /// <summary>Color picker button (split by default): the main part applies Color, the arrow opens the palette.
  /// </summary>
  TFmrColorItem = class(TFmrButtonItem)
  private
    FColor: TAlphaColor;
    FAutomaticColor: TAlphaColor;
    FShowAutomatic: Boolean;
    FShowNoColor: Boolean;
    FShowMoreColors: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetColor(const Value: TAlphaColor);
    procedure SetAutomaticColor(const Value: TAlphaColor);
    procedure SetShowAutomatic(const Value: Boolean);
    procedure SetShowNoColor(const Value: Boolean);
    procedure SetShowMoreColors(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
  published
    property AutomaticColor: TAlphaColor read FAutomaticColor write SetAutomaticColor default TAlphaColors.Black;
    property ButtonStyle default TFmrButtonStyle.Split;
    property Color: TAlphaColor read FColor write SetColor default TAlphaColors.Null;
    property ShowAutomatic: Boolean read FShowAutomatic write SetShowAutomatic default True;
    property ShowMoreColors: Boolean read FShowMoreColors write SetShowMoreColors default True;
    property ShowNoColor: Boolean read FShowNoColor write SetShowNoColor default False;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TFmrGalleryItem = class;
  TFmrGalleryGroup = class;

  /// <summary>One entry of a gallery.</summary>
  TFmrGalleryEntry = class(TCollectionItem)
  private
    FCaption: string;
    FDescription: string;
    FHint: string;
    FGlyph: TFmrImageSource;
    FEnabled: Boolean;
    FVisible: Boolean;
    FTag: NativeInt;
    FData: TObject;
    procedure SetCaption(const Value: string);
    procedure SetDescription(const Value: string);
    procedure SetHint(const Value: string);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetEnabled(const Value: Boolean);
    procedure SetVisible(const Value: Boolean);
    procedure GlyphChanged(Sender: TObject);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function Group: TFmrGalleryGroup;
    function Gallery: TFmrGalleryItem;
    property Data: TObject read FData write FData;
  published
    property Caption: string read FCaption write SetCaption;
    property Description: string read FDescription write SetDescription;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    property Hint: string read FHint write SetHint;
    property Tag: NativeInt read FTag write FTag default 0;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  TFmrGalleryEntries = class(TOwnedCollection)
  private
    function GetEntry(const AIndex: Integer): TFmrGalleryEntry;
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(const AOwner: TFmrGalleryGroup);
    function Add: TFmrGalleryEntry; overload;
    function Add(const ACaption: string; const AImageIndex: Integer = -1): TFmrGalleryEntry; overload;
    property Items[const AIndex: Integer]: TFmrGalleryEntry read GetEntry; default;
  end;

  /// <summary>Group of gallery entries with an optional header.</summary>
  TFmrGalleryGroup = class(TCollectionItem)
  private
    FCaption: string;
    FVisible: Boolean;
    FItems: TFmrGalleryEntries;
    procedure SetCaption(const Value: string);
    procedure SetVisible(const Value: Boolean);
    procedure SetItems(const Value: TFmrGalleryEntries);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function Gallery: TFmrGalleryItem;
  published
    property Caption: string read FCaption write SetCaption;
    property Items: TFmrGalleryEntries read FItems write SetItems;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  TFmrGalleryGroups = class(TOwnedCollection)
  private
    function GetGroup(const AIndex: Integer): TFmrGalleryGroup;
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(const AOwner: TFmrGalleryItem);
    function Add: TFmrGalleryGroup; overload;
    function Add(const ACaption: string): TFmrGalleryGroup; overload;
    property Items[const AIndex: Integer]: TFmrGalleryGroup read GetGroup; default;
  end;

  TFmrGalleryEntryEvent = procedure(Sender: TObject; const AEntry: TFmrGalleryEntry) of object;

  /// <summary>Gallery data: groups of entries shown in the ribbon (columns reduced when space is short, between
  /// MinColumns and MaxColumns) and in a drop-down with optional commands below (DropDownLinks).</summary>
  TFmrGalleryItem = class(TFmrBarItem, IFmrItemLinksOwner)
  private
    FGroups: TFmrGalleryGroups;
    FDropDownLinks: TFmrItemLinks;
    FMinColumns: Integer;
    FMaxColumns: Integer;
    FDropDownColumns: Integer;
    FDropDownRows: Integer;
    FItemWidth: Single;
    FItemHeight: Single;
    FShowInRibbon: Boolean;
    FAllowFilter: Boolean;
    FShowGroupHeaders: Boolean;
    FSelectionMode: TFmrGallerySelectionMode;
    FSelectedEntry: TFmrGalleryEntry;
    FLoadedSelectedIndex: Integer;
    FCaptionPosition: TFmrGalleryCaptionPosition;
    FOnItemClick: TFmrGalleryEntryEvent;
    FOnHotTrack: TFmrGalleryEntryEvent;
    procedure SetGroups(const Value: TFmrGalleryGroups);
    procedure SetDropDownLinks(const Value: TFmrItemLinks);
    procedure SetMinColumns(const Value: Integer);
    procedure SetMaxColumns(const Value: Integer);
    procedure SetDropDownColumns(const Value: Integer);
    procedure SetDropDownRows(const Value: Integer);
    procedure SetItemWidth(const Value: Single);
    procedure SetItemHeight(const Value: Single);
    procedure SetShowInRibbon(const Value: Boolean);
    procedure SetAllowFilter(const Value: Boolean);
    procedure SetShowGroupHeaders(const Value: Boolean);
    procedure SetSelectionMode(const Value: TFmrGallerySelectionMode);
    function GetSelectedIndex: Integer;
    procedure SetSelectedIndex(const Value: Integer);
    procedure SetCaptionPosition(const Value: TFmrGalleryCaptionPosition);
    function GetEntryCount: Integer;
    function GetEntry(const AIndex: Integer): TFmrGalleryEntry;
    function GetSelectedEntry: TFmrGalleryEntry;
    procedure SetSelectedEntry(const Value: TFmrGalleryEntry);
    function IsDropDownLinksStored: Boolean;
    function IsItemWidthStored: Boolean;
    function IsItemHeightStored: Boolean;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    procedure GroupsChanged; virtual;
    procedure EntryDestroying(const AEntry: TFmrGalleryEntry);
    procedure DoItemClick(const AEntry: TFmrGalleryEntry); virtual;
    procedure DoHotTrack(const AEntry: TFmrGalleryEntry); virtual;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DefaultViewLevels: TFmrViewLevels; override;
    function LayoutKind: TFmrLayoutItemKind; override;
    /// <summary>Called by the ribbon when an entry is clicked: selects it (SelectionMode Single) and fires
    /// OnItemClick.</summary>
    procedure ClickEntry(const AEntry: TFmrGalleryEntry);
    /// <summary>Called by the ribbon when the mouse enters an entry (live preview) and with nil when it leaves the
    /// gallery (revert the preview).</summary>
    procedure HotTrack(const AEntry: TFmrGalleryEntry);
    /// <summary>Flat index of AEntry over all groups, -1 when it does not belong to this gallery.</summary>
    function IndexOfEntry(const AEntry: TFmrGalleryEntry): Integer;
    /// <summary>Entries of all groups in order.</summary>
    property EntryCount: Integer read GetEntryCount;
    property Entries[const AIndex: Integer]: TFmrGalleryEntry read GetEntry;
    property SelectedEntry: TFmrGalleryEntry read GetSelectedEntry write SetSelectedEntry;
  published
    property AllowFilter: Boolean read FAllowFilter write SetAllowFilter default False;
    property CaptionPosition: TFmrGalleryCaptionPosition read FCaptionPosition write SetCaptionPosition
      default TFmrGalleryCaptionPosition.None;
    /// <summary>Columns of the drop-down; 0 = MaxColumns.</summary>
    property DropDownColumns: Integer read FDropDownColumns write SetDropDownColumns default 0;
    property DropDownLinks: TFmrItemLinks read FDropDownLinks write SetDropDownLinks stored IsDropDownLinksStored;
    /// <summary>Visible rows of the drop-down before it scrolls; 0 = automatic.</summary>
    property DropDownRows: Integer read FDropDownRows write SetDropDownRows default 0;
    property Groups: TFmrGalleryGroups read FGroups write SetGroups;
    /// <summary>Size of an entry in dp; 0 = from the theme and the images.</summary>
    property ItemHeight: Single read FItemHeight write SetItemHeight stored IsItemHeightStored;
    property ItemWidth: Single read FItemWidth write SetItemWidth stored IsItemWidthStored;
    /// <summary>Most columns shown in the ribbon.</summary>
    property MaxColumns: Integer read FMaxColumns write SetMaxColumns default 6;
    /// <summary>Fewest columns shown in the ribbon before the gallery becomes a large drop-down button.</summary>
    property MinColumns: Integer read FMinColumns write SetMinColumns default 2;
    /// <summary>Flat index of the selected entry; -1 = none. The selection follows its entry when entries are
    /// added, moved or deleted.</summary>
    property SelectedIndex: Integer read GetSelectedIndex write SetSelectedIndex default -1;
    property SelectionMode: TFmrGallerySelectionMode read FSelectionMode write SetSelectionMode
      default TFmrGallerySelectionMode.Single;
    property ShowGroupHeaders: Boolean read FShowGroupHeaders write SetShowGroupHeaders default True;
    /// <summary>In-ribbon gallery; False = a drop-down button only.</summary>
    property ShowInRibbon: Boolean read FShowInRibbon write SetShowInRibbon default True;
    property OnHotTrack: TFmrGalleryEntryEvent read FOnHotTrack write FOnHotTrack;
    property OnItemClick: TFmrGalleryEntryEvent read FOnItemClick write FOnItemClick;
  end;

implementation

uses
  System.Math, System.Actions;

{ TFmrButtonItem }

constructor TFmrButtonItem.Create(AOwner: TComponent);
begin
  inherited;
  FDropDownLinks := TFmrItemLinks.Create(Self);
end;

destructor TFmrButtonItem.Destroy;
begin
  FreeAndNil(FDropDownLinks);
  inherited;
end;

procedure TFmrButtonItem.Loaded;
begin
  inherited;
  if FDown and (FGroupIndex <> 0) then
    UncheckGroup;
end;

procedure TFmrButtonItem.DoClick;
var
  ActionChecks: Boolean;
begin
  if FButtonStyle = TFmrButtonStyle.DropDown then
  begin
    DropDown;
    Exit;
  end;
  if FButtonStyle = TFmrButtonStyle.Check then
  begin
    ActionChecks := (Action is TContainedAction) and TContainedAction(Action).AutoCheck;
    if not ActionChecks and ((FGroupIndex = 0) or not FDown or FAllowAllUp) then
      Down := not FDown;
  end;
  inherited;
end;

procedure TFmrButtonItem.DoDropDown;
begin
  if Assigned(FOnDropDown) then
    FOnDropDown(Self);
end;

procedure TFmrButtonItem.DropDown;
begin
  if Enabled then
    DoDropDown;
end;

function TFmrButtonItem.HasDropDown: Boolean;
begin
  Result := FButtonStyle in [TFmrButtonStyle.DropDown, TFmrButtonStyle.Split];
end;

function TFmrButtonItem.GetIsChecked: Boolean;
begin
  Result := FDown;
end;

procedure TFmrButtonItem.SetIsChecked(const Value: Boolean);
begin
  Down := Value;
end;

function TFmrButtonItem.SupportsChecked: Boolean;
begin
  Result := True;
end;

function TFmrButtonItem.GetGroupIndexValue: Integer;
begin
  Result := FGroupIndex;
end;

procedure TFmrButtonItem.SetGroupIndexValue(const Value: Integer);
begin
  GroupIndex := Value;
end;

function TFmrButtonItem.IsDropDownLinksStored: Boolean;
begin
  Result := FDropDownLinks.Count > 0;
end;

procedure TFmrButtonItem.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  OwnedLinksChanged;
end;

procedure TFmrButtonItem.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

procedure TFmrButtonItem.LinksChanged(const ALinks: TFmrItemLinks);
begin
  OwnedLinksChanged;
end;

procedure TFmrButtonItem.SetAllowAllUp(const Value: Boolean);
begin
  FAllowAllUp := Value;
end;

procedure TFmrButtonItem.SetPrimary(const Value: Boolean);
begin
  if FPrimary <> Value then
  begin
    FPrimary := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrButtonItem.SetButtonStyle(const Value: TFmrButtonStyle);
begin
  if FButtonStyle <> Value then
  begin
    FButtonStyle := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrButtonItem.UncheckGroup;
var
  I: Integer;
  Other: TFmrBarItem;
begin
  if (Manager = nil) or (FGroupIndex = 0) then
    Exit;
  for I := 0 to Manager.ItemCount - 1 do
  begin
    Other := Manager.Items[I];
    if (Other <> Self) and (Other is TFmrButtonItem) and (TFmrButtonItem(Other).FGroupIndex = FGroupIndex) then
      TFmrButtonItem(Other).Down := False;
  end;
end;

procedure TFmrButtonItem.SetDown(const Value: Boolean);
begin
  if FDown <> Value then
  begin
    FDown := Value;
    if FDown and not (csLoading in ComponentState) then
      UncheckGroup;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrButtonItem.SetDropDownLinks(const Value: TFmrItemLinks);
begin
  FDropDownLinks.Assign(Value);
end;

procedure TFmrButtonItem.SetGroupIndex(const Value: Integer);
begin
  if FGroupIndex <> Value then
  begin
    FGroupIndex := Value;
    if FDown and not (csLoading in ComponentState) then
      UncheckGroup;
  end;
end;

{ TFmrAvatarItem }

procedure TFmrAvatarItem.SetInitials(const Value: string);
begin
  if FInitials <> Value then
  begin
    FInitials := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrAvatarItem.SetColor(const Value: TAlphaColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

{ TFmrSubItem }

constructor TFmrSubItem.Create(AOwner: TComponent);
begin
  inherited;
  FItemLinks := TFmrItemLinks.Create(Self);
end;

destructor TFmrSubItem.Destroy;
begin
  FreeAndNil(FItemLinks);
  inherited;
end;

procedure TFmrSubItem.DoClick;
begin
  Popup;
end;

procedure TFmrSubItem.Popup;
begin
  if Assigned(FOnPopup) then
    FOnPopup(Self);
end;

procedure TFmrSubItem.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  OwnedLinksChanged;
end;

procedure TFmrSubItem.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

procedure TFmrSubItem.LinksChanged(const ALinks: TFmrItemLinks);
begin
  OwnedLinksChanged;
end;

procedure TFmrSubItem.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

{ TFmrSeparatorItem }

function TFmrSeparatorItem.DefaultViewLevels: TFmrViewLevels;
begin
  Result := [];
end;

function TFmrSeparatorItem.LayoutKind: TFmrLayoutItemKind;
begin
  Result := TFmrLayoutItemKind.Separator;
end;

{ TFmrStaticItem }

function TFmrStaticItem.IsWidthStored: Boolean;
begin
  Result := FWidth <> 0;
end;

procedure TFmrStaticItem.SetAlignment(const Value: TTextAlign);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrStaticItem.SetWidth(const Value: Single);
begin
  if FWidth <> Value then
  begin
    FWidth := System.Math.Max(0, Value);
    Changed(TFmrItemChange.Layout);
  end;
end;

{ TFmrControlItem }

function TFmrControlItem.DefaultViewLevels: TFmrViewLevels;
begin
  if Caption <> '' then
    Result := FmrSmallViewLevels
  else
    Result := [TFmrViewLevel.Small];
end;

function TFmrControlItem.IsWidthStored: Boolean;
begin
  Result := FWidth <> 0;
end;

function TFmrControlItem.LayoutKind: TFmrLayoutItemKind;
begin
  Result := TFmrLayoutItemKind.Control;
end;

procedure TFmrControlItem.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FControl) then
  begin
    FControl := nil;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrControlItem.SetControl(const Value: TControl);
begin
  if FControl <> Value then
  begin
    if FControl <> nil then
      FControl.RemoveFreeNotification(Self);
    FControl := Value;
    if FControl <> nil then
      FControl.FreeNotification(Self);
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrControlItem.SetWidth(const Value: Single);
begin
  if FWidth <> Value then
  begin
    FWidth := System.Math.Max(0, Value);
    Changed(TFmrItemChange.Layout);
  end;
end;

{ TFmrCustomEditItem }

constructor TFmrCustomEditItem.Create(AOwner: TComponent);
begin
  inherited;
  FWidth := DefaultEditWidth;
end;

function TFmrCustomEditItem.DefaultViewLevels: TFmrViewLevels;
begin
  if Caption <> '' then
    Result := FmrSmallViewLevels
  else
    Result := [TFmrViewLevel.Small];
end;

procedure TFmrCustomEditItem.DoChange;
begin
  Changed(TFmrItemChange.Value);
  if Assigned(FOnChange) and not (csLoading in ComponentState) then
    FOnChange(Self);
end;

function TFmrCustomEditItem.IsWidthStored: Boolean;
begin
  Result := FWidth <> DefaultEditWidth;
end;

function TFmrCustomEditItem.LayoutKind: TFmrLayoutItemKind;
begin
  Result := TFmrLayoutItemKind.Control;
end;

procedure TFmrCustomEditItem.SetReadOnly(const Value: Boolean);
begin
  if FReadOnly <> Value then
  begin
    FReadOnly := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrCustomEditItem.SetWidth(const Value: Single);
begin
  if FWidth <> Value then
  begin
    FWidth := System.Math.Max(0, Value);
    Changed(TFmrItemChange.Layout);
  end;
end;

{ TFmrEditItem }

procedure TFmrEditItem.SetMaxLength(const Value: Integer);
begin
  if FMaxLength <> Value then
  begin
    FMaxLength := System.Math.Max(0, Value);
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrEditItem.SetText(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    DoChange;
  end;
end;

procedure TFmrEditItem.SetTextPrompt(const Value: string);
begin
  if FTextPrompt <> Value then
  begin
    FTextPrompt := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

{ TFmrComboItem }

constructor TFmrComboItem.Create(AOwner: TComponent);
begin
  inherited;
  FItemIndex := -1;
  FDropDownCount := 8;
  FItems := TStringList.Create;
  TStringList(FItems).OnChange := ItemsChanged;
end;

destructor TFmrComboItem.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TFmrComboItem.Loaded;
begin
  inherited;
  if (FItemIndex < 0) and (FText <> '') then
    FItemIndex := FItems.IndexOf(FText);
end;

function TFmrComboItem.GetText: string;
begin
  if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then
    Result := FItems[FItemIndex]
  else
    Result := FText;
end;

function TFmrComboItem.IsTextStored: Boolean;
begin
  Result := (FItemIndex < 0) and (FText <> '');
end;

procedure TFmrComboItem.ItemsChanged(Sender: TObject);
begin
  if FItemIndex >= FItems.Count then
    FItemIndex := -1;
  Changed(TFmrItemChange.Value);
end;

procedure TFmrComboItem.SetDropDownCount(const Value: Integer);
begin
  FDropDownCount := System.Math.Max(1, Value);
end;

procedure TFmrComboItem.SetEditable(const Value: Boolean);
begin
  if FEditable <> Value then
  begin
    FEditable := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrComboItem.SetItemIndex(const Value: Integer);
var
  V: Integer;
begin
  V := Value;
  if not (csLoading in ComponentState) and ((V < -1) or (V >= FItems.Count)) then
    V := -1;
  if FItemIndex <> V then
  begin
    FItemIndex := V;
    if (V >= 0) and (V < FItems.Count) then
      FText := FItems[V];
    DoChange;
  end;
end;

procedure TFmrComboItem.SetItems(const Value: TStrings);
begin
  FItems.Assign(Value);
end;

procedure TFmrComboItem.SetText(const Value: string);
var
  NewIndex: Integer;
begin
  if (FText = Value) and (GetText = Value) then
    Exit;
  FText := Value;
  if csLoading in ComponentState then
    Exit;
  NewIndex := FItems.IndexOf(Value);
  FItemIndex := NewIndex;
  DoChange;
end;

{ TFmrSpinItem }

constructor TFmrSpinItem.Create(AOwner: TComponent);
begin
  inherited;
  FIncrement := 1;
  FMax := 100;
  Width := 60;
end;

function TFmrSpinItem.Clamp(const AValue: Double): Double;
begin
  Result := AValue;
  if FMax > FMin then
    Result := EnsureRange(Result, FMin, FMax);
end;

function TFmrSpinItem.IsIncrementStored: Boolean;
begin
  Result := FIncrement <> 1;
end;

function TFmrSpinItem.IsMaxStored: Boolean;
begin
  Result := FMax <> 100;
end;

function TFmrSpinItem.IsMinStored: Boolean;
begin
  Result := FMin <> 0;
end;

function TFmrSpinItem.IsValueStored: Boolean;
begin
  Result := FValue <> 0;
end;

procedure TFmrSpinItem.SetDecimalDigits(const AValue: Integer);
begin
  if FDecimalDigits <> AValue then
  begin
    FDecimalDigits := EnsureRange(AValue, 0, 15);
    Changed(TFmrItemChange.Value);
  end;
end;

procedure TFmrSpinItem.SetIncrement(const AValue: Double);
begin
  FIncrement := AValue;
end;

procedure TFmrSpinItem.SetMax(const AValue: Double);
begin
  if FMax <> AValue then
  begin
    FMax := AValue;
    if not (csLoading in ComponentState) then
      Value := FValue;
  end;
end;

procedure TFmrSpinItem.SetMin(const AValue: Double);
begin
  if FMin <> AValue then
  begin
    FMin := AValue;
    if not (csLoading in ComponentState) then
      Value := FValue;
  end;
end;

procedure TFmrSpinItem.SetValue(const AValue: Double);
var
  V: Double;
begin
  if csLoading in ComponentState then
    V := AValue
  else
    V := Clamp(AValue);
  if FValue <> V then
  begin
    FValue := V;
    DoChange;
  end;
end;

procedure TFmrSpinItem.StepDown;
begin
  Value := FValue - FIncrement;
end;

procedure TFmrSpinItem.StepUp;
begin
  Value := FValue + FIncrement;
end;

{ TFmrTrackBarItem }

constructor TFmrTrackBarItem.Create(AOwner: TComponent);
begin
  inherited;
  FMax := 100;
end;

function TFmrTrackBarItem.IsMaxStored: Boolean;
begin
  Result := FMax <> 100;
end;

function TFmrTrackBarItem.IsMinStored: Boolean;
begin
  Result := FMin <> 0;
end;

function TFmrTrackBarItem.IsValueStored: Boolean;
begin
  Result := FValue <> 0;
end;

procedure TFmrTrackBarItem.SetMax(const AValue: Single);
begin
  if FMax <> AValue then
  begin
    FMax := AValue;
    if not (csLoading in ComponentState) then
      Value := FValue;
  end;
end;

procedure TFmrTrackBarItem.SetMin(const AValue: Single);
begin
  if FMin <> AValue then
  begin
    FMin := AValue;
    if not (csLoading in ComponentState) then
      Value := FValue;
  end;
end;

procedure TFmrTrackBarItem.SetValue(const AValue: Single);
var
  V: Single;
begin
  V := AValue;
  if not (csLoading in ComponentState) and (FMax > FMin) then
    V := EnsureRange(V, FMin, FMax);
  if FValue <> V then
  begin
    FValue := V;
    DoChange;
  end;
end;

{ TFmrFontNameItem }

constructor TFmrFontNameItem.Create(AOwner: TComponent);
begin
  inherited;
  Editable := True;
  FShowFontPreview := True;
  Width := 140;
end;

procedure TFmrFontNameItem.RefreshFonts;
var
  L: TStringList;
  Current: string;
begin
  if not Assigned(FFontListProvider) then
    Exit;
  Current := Text;
  L := TStringList.Create;
  try
    L.Sorted := True;
    L.Duplicates := dupIgnore;
    L.CaseSensitive := False;
    FFontListProvider(L);
    Items.Assign(L);
  finally
    L.Free;
  end;
  if Current <> '' then
    Text := Current;
end;

procedure TFmrFontNameItem.SetShowFontPreview(const Value: Boolean);
begin
  if FShowFontPreview <> Value then
  begin
    FShowFontPreview := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

{ TFmrCheckItem }

function TFmrCheckItem.DefaultViewLevels: TFmrViewLevels;
begin
  Result := [TFmrViewLevel.SmallWithText];
end;

procedure TFmrCheckItem.DoClick;
var
  ActionChecks: Boolean;
begin
  ActionChecks := (Action is TContainedAction) and TContainedAction(Action).AutoCheck;
  if not ActionChecks and ((FGroupIndex = 0) or not FChecked) then
    Checked := not FChecked;
  inherited;
end;

function TFmrCheckItem.GetGroupIndexValue: Integer;
begin
  Result := FGroupIndex;
end;

function TFmrCheckItem.GetIsChecked: Boolean;
begin
  Result := FChecked;
end;

procedure TFmrCheckItem.SetChecked(const Value: Boolean);
var
  I: Integer;
  Other: TFmrBarItem;
begin
  if FChecked = Value then
    Exit;
  FChecked := Value;
  if FChecked and (FGroupIndex <> 0) and (Manager <> nil) and not (csLoading in ComponentState) then
    for I := 0 to Manager.ItemCount - 1 do
    begin
      Other := Manager.Items[I];
      if (Other <> Self) and (Other is TFmrCheckItem) and (TFmrCheckItem(Other).FGroupIndex = FGroupIndex) then
        TFmrCheckItem(Other).Checked := False;
    end;
  Changed(TFmrItemChange.Value);
  if Assigned(FOnChange) and not (csLoading in ComponentState) then
    FOnChange(Self);
end;

procedure TFmrCheckItem.SetGroupIndex(const Value: Integer);
begin
  FGroupIndex := Value;
end;

procedure TFmrCheckItem.SetCheckStyle(const Value: TFmrCheckStyle);
begin
  if FCheckStyle <> Value then
  begin
    FCheckStyle := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrCheckItem.SetGroupIndexValue(const Value: Integer);
begin
  GroupIndex := Value;
end;

procedure TFmrCheckItem.SetIsChecked(const Value: Boolean);
begin
  Checked := Value;
end;

function TFmrCheckItem.SupportsChecked: Boolean;
begin
  Result := True;
end;

{ TFmrColorItem }

constructor TFmrColorItem.Create(AOwner: TComponent);
begin
  inherited;
  ButtonStyle := TFmrButtonStyle.Split;
  FColor := TAlphaColors.Null;
  FAutomaticColor := TAlphaColors.Black;
  FShowAutomatic := True;
  FShowMoreColors := True;
end;

procedure TFmrColorItem.SetAutomaticColor(const Value: TAlphaColor);
begin
  if FAutomaticColor <> Value then
  begin
    FAutomaticColor := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrColorItem.SetColor(const Value: TAlphaColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    Changed(TFmrItemChange.Value);
    if Assigned(FOnChange) and not (csLoading in ComponentState) then
      FOnChange(Self);
  end;
end;

procedure TFmrColorItem.SetShowAutomatic(const Value: Boolean);
begin
  FShowAutomatic := Value;
end;

procedure TFmrColorItem.SetShowMoreColors(const Value: Boolean);
begin
  FShowMoreColors := Value;
end;

procedure TFmrColorItem.SetShowNoColor(const Value: Boolean);
begin
  FShowNoColor := Value;
end;

{ TFmrGalleryEntry }

constructor TFmrGalleryEntry.Create(Collection: TCollection);
begin
  FEnabled := True;
  FVisible := True;
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
  inherited;
end;

destructor TFmrGalleryEntry.Destroy;
var
  G: TFmrGalleryItem;
begin
  G := Gallery;
  if G <> nil then
    G.EntryDestroying(Self);
  inherited;
  FreeAndNil(FGlyph);
end;

procedure TFmrGalleryEntry.Assign(Source: TPersistent);
var
  S: TFmrGalleryEntry;
begin
  if Source is TFmrGalleryEntry then
  begin
    S := TFmrGalleryEntry(Source);
    FCaption := S.FCaption;
    FDescription := S.FDescription;
    FHint := S.FHint;
    FEnabled := S.FEnabled;
    FVisible := S.FVisible;
    FTag := S.FTag;
    FData := S.FData;
    FGlyph.Assign(S.FGlyph);
    Changed(False);
  end
  else
    inherited;
end;

function TFmrGalleryEntry.Gallery: TFmrGalleryItem;
var
  G: TFmrGalleryGroup;
begin
  G := Group;
  if G <> nil then
    Result := G.Gallery
  else
    Result := nil;
end;

function TFmrGalleryEntry.GetDisplayName: string;
begin
  if FCaption <> '' then
    Result := FCaption
  else
    Result := inherited GetDisplayName;
end;

procedure TFmrGalleryEntry.GlyphChanged(Sender: TObject);
begin
  Changed(False);
end;

function TFmrGalleryEntry.Group: TFmrGalleryGroup;
begin
  if (Collection <> nil) and (TFmrGalleryEntries(Collection).Owner is TFmrGalleryGroup) then
    Result := TFmrGalleryGroup(TFmrGalleryEntries(Collection).Owner)
  else
    Result := nil;
end;

procedure TFmrGalleryEntry.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed(False);
  end;
end;

procedure TFmrGalleryEntry.SetDescription(const Value: string);
begin
  if FDescription <> Value then
  begin
    FDescription := Value;
    Changed(False);
  end;
end;

procedure TFmrGalleryEntry.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    Changed(False);
  end;
end;

procedure TFmrGalleryEntry.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrGalleryEntry.SetHint(const Value: string);
begin
  FHint := Value;
end;

procedure TFmrGalleryEntry.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed(False);
  end;
end;

{ TFmrGalleryEntries }

constructor TFmrGalleryEntries.Create(const AOwner: TFmrGalleryGroup);
begin
  inherited Create(AOwner, TFmrGalleryEntry);
end;

function TFmrGalleryEntries.Add: TFmrGalleryEntry;
begin
  Result := TFmrGalleryEntry(inherited Add);
end;

function TFmrGalleryEntries.Add(const ACaption: string; const AImageIndex: Integer): TFmrGalleryEntry;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.FCaption := ACaption;
    Result.FGlyph.ImageIndex := AImageIndex;
  finally
    EndUpdate;
  end;
end;

function TFmrGalleryEntries.GetEntry(const AIndex: Integer): TFmrGalleryEntry;
begin
  Result := TFmrGalleryEntry(inherited Items[AIndex]);
end;

procedure TFmrGalleryEntries.Update(Item: TCollectionItem);
var
  G: TFmrGalleryItem;
begin
  inherited;
  if Owner is TFmrGalleryGroup then
  begin
    G := TFmrGalleryGroup(Owner).Gallery;
    if G <> nil then
      G.GroupsChanged;
  end;
end;

{ TFmrGalleryGroup }

constructor TFmrGalleryGroup.Create(Collection: TCollection);
begin
  FVisible := True;
  FItems := TFmrGalleryEntries.Create(Self);
  inherited;
end;

destructor TFmrGalleryGroup.Destroy;
begin
  inherited;
  FreeAndNil(FItems);
end;

procedure TFmrGalleryGroup.Assign(Source: TPersistent);
begin
  if Source is TFmrGalleryGroup then
  begin
    FCaption := TFmrGalleryGroup(Source).FCaption;
    FVisible := TFmrGalleryGroup(Source).FVisible;
    FItems.Assign(TFmrGalleryGroup(Source).FItems);
    Changed(False);
  end
  else
    inherited;
end;

function TFmrGalleryGroup.Gallery: TFmrGalleryItem;
begin
  if (Collection <> nil) and (TFmrGalleryGroups(Collection).Owner is TFmrGalleryItem) then
    Result := TFmrGalleryItem(TFmrGalleryGroups(Collection).Owner)
  else
    Result := nil;
end;

function TFmrGalleryGroup.GetDisplayName: string;
begin
  if FCaption <> '' then
    Result := FCaption
  else
    Result := inherited GetDisplayName;
end;

procedure TFmrGalleryGroup.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed(False);
  end;
end;

procedure TFmrGalleryGroup.SetItems(const Value: TFmrGalleryEntries);
begin
  FItems.Assign(Value);
end;

procedure TFmrGalleryGroup.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed(False);
  end;
end;

{ TFmrGalleryGroups }

constructor TFmrGalleryGroups.Create(const AOwner: TFmrGalleryItem);
begin
  inherited Create(AOwner, TFmrGalleryGroup);
end;

function TFmrGalleryGroups.Add: TFmrGalleryGroup;
begin
  Result := TFmrGalleryGroup(inherited Add);
end;

function TFmrGalleryGroups.Add(const ACaption: string): TFmrGalleryGroup;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.FCaption := ACaption;
  finally
    EndUpdate;
  end;
end;

function TFmrGalleryGroups.GetGroup(const AIndex: Integer): TFmrGalleryGroup;
begin
  Result := TFmrGalleryGroup(inherited Items[AIndex]);
end;

procedure TFmrGalleryGroups.Update(Item: TCollectionItem);
begin
  inherited;
  if Owner is TFmrGalleryItem then
    TFmrGalleryItem(Owner).GroupsChanged;
end;

{ TFmrGalleryItem }

constructor TFmrGalleryItem.Create(AOwner: TComponent);
begin
  inherited;
  FGroups := TFmrGalleryGroups.Create(Self);
  FDropDownLinks := TFmrItemLinks.Create(Self);
  FMinColumns := 2;
  FMaxColumns := 6;
  FShowInRibbon := True;
  FShowGroupHeaders := True;
  FSelectionMode := TFmrGallerySelectionMode.Single;
  FLoadedSelectedIndex := -1;
end;

procedure TFmrGalleryItem.Loaded;
begin
  inherited;
  if (FLoadedSelectedIndex >= 0) and (FLoadedSelectedIndex < EntryCount) then
    FSelectedEntry := GetEntry(FLoadedSelectedIndex);
  FLoadedSelectedIndex := -1;
end;

procedure TFmrGalleryItem.EntryDestroying(const AEntry: TFmrGalleryEntry);
begin
  if FSelectedEntry = AEntry then
  begin
    FSelectedEntry := nil;
    Changed(TFmrItemChange.Value);
  end;
end;

destructor TFmrGalleryItem.Destroy;
begin
  FreeAndNil(FDropDownLinks);
  FreeAndNil(FGroups);
  inherited;
end;

function TFmrGalleryItem.DefaultViewLevels: TFmrViewLevels;
begin
  if FShowInRibbon then
    Result := [TFmrViewLevel.Large]
  else
    Result := inherited DefaultViewLevels;
end;

function TFmrGalleryItem.LayoutKind: TFmrLayoutItemKind;
begin
  if FShowInRibbon then
    Result := TFmrLayoutItemKind.Gallery
  else
    Result := TFmrLayoutItemKind.Button;
end;

procedure TFmrGalleryItem.GroupsChanged;
begin
  if (FGroups = nil) or (csDestroying in ComponentState) then
    Exit;
  if (FSelectedEntry <> nil) and (IndexOfEntry(FSelectedEntry) < 0) then
    FSelectedEntry := nil;
  // Entries can be added, removed, reordered or hidden; captions and glyphs can also change the measured size.
  Changed(TFmrItemChange.Layout);
end;

procedure TFmrGalleryItem.ClickEntry(const AEntry: TFmrGalleryEntry);
begin
  if (AEntry = nil) or not AEntry.Enabled or not Enabled then
    Exit;
  if FSelectionMode = TFmrGallerySelectionMode.Single then
    SelectedEntry := AEntry;
  DoItemClick(AEntry);
end;

procedure TFmrGalleryItem.DoItemClick(const AEntry: TFmrGalleryEntry);
begin
  if Assigned(FOnItemClick) then
    FOnItemClick(Self, AEntry);
end;

procedure TFmrGalleryItem.DoHotTrack(const AEntry: TFmrGalleryEntry);
begin
  if Assigned(FOnHotTrack) then
    FOnHotTrack(Self, AEntry);
end;

procedure TFmrGalleryItem.HotTrack(const AEntry: TFmrGalleryEntry);
begin
  DoHotTrack(AEntry);
end;

function TFmrGalleryItem.GetEntryCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FGroups.Count - 1 do
    Inc(Result, FGroups[I].Items.Count);
end;

function TFmrGalleryItem.GetEntry(const AIndex: Integer): TFmrGalleryEntry;
var
  I, N: Integer;
begin
  N := AIndex;
  if N >= 0 then
    for I := 0 to FGroups.Count - 1 do
    begin
      if N < FGroups[I].Items.Count then
        Exit(FGroups[I].Items[N]);
      Dec(N, FGroups[I].Items.Count);
    end;
  raise EListError.CreateFmt('Gallery entry index out of bounds (%d)', [AIndex]);
end;

function TFmrGalleryItem.IndexOfEntry(const AEntry: TFmrGalleryEntry): Integer;
var
  I, Base: Integer;
begin
  Base := 0;
  if AEntry <> nil then
    for I := 0 to FGroups.Count - 1 do
    begin
      if AEntry.Collection = FGroups[I].Items then
        Exit(Base + AEntry.Index);
      Inc(Base, FGroups[I].Items.Count);
    end;
  Result := -1;
end;

function TFmrGalleryItem.GetSelectedEntry: TFmrGalleryEntry;
begin
  Result := FSelectedEntry;
end;

procedure TFmrGalleryItem.SetSelectedEntry(const Value: TFmrGalleryEntry);
var
  V: TFmrGalleryEntry;
begin
  V := Value;
  if (V <> nil) and (IndexOfEntry(V) < 0) then
    V := nil;
  if FSelectedEntry <> V then
  begin
    FSelectedEntry := V;
    Changed(TFmrItemChange.Value);
  end;
end;

function TFmrGalleryItem.GetSelectedIndex: Integer;
begin
  if csLoading in ComponentState then
    Result := FLoadedSelectedIndex
  else
    Result := IndexOfEntry(FSelectedEntry);
end;

function TFmrGalleryItem.IsDropDownLinksStored: Boolean;
begin
  Result := FDropDownLinks.Count > 0;
end;

function TFmrGalleryItem.IsItemHeightStored: Boolean;
begin
  Result := FItemHeight <> 0;
end;

function TFmrGalleryItem.IsItemWidthStored: Boolean;
begin
  Result := FItemWidth <> 0;
end;

procedure TFmrGalleryItem.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  OwnedLinksChanged;
end;

procedure TFmrGalleryItem.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

procedure TFmrGalleryItem.LinksChanged(const ALinks: TFmrItemLinks);
begin
  OwnedLinksChanged;
end;

procedure TFmrGalleryItem.SetAllowFilter(const Value: Boolean);
begin
  if FAllowFilter <> Value then
  begin
    FAllowFilter := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrGalleryItem.SetCaptionPosition(const Value: TFmrGalleryCaptionPosition);
begin
  if FCaptionPosition <> Value then
  begin
    FCaptionPosition := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrGalleryItem.SetDropDownColumns(const Value: Integer);
begin
  FDropDownColumns := System.Math.Max(0, Value);
end;

procedure TFmrGalleryItem.SetDropDownLinks(const Value: TFmrItemLinks);
begin
  FDropDownLinks.Assign(Value);
end;

procedure TFmrGalleryItem.SetDropDownRows(const Value: Integer);
begin
  FDropDownRows := System.Math.Max(0, Value);
end;

procedure TFmrGalleryItem.SetGroups(const Value: TFmrGalleryGroups);
begin
  FGroups.Assign(Value);
end;

procedure TFmrGalleryItem.SetItemHeight(const Value: Single);
begin
  if FItemHeight <> Value then
  begin
    FItemHeight := System.Math.Max(0, Value);
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrGalleryItem.SetItemWidth(const Value: Single);
begin
  if FItemWidth <> Value then
  begin
    FItemWidth := System.Math.Max(0, Value);
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrGalleryItem.SetMaxColumns(const Value: Integer);
begin
  if FMaxColumns <> Value then
  begin
    FMaxColumns := System.Math.Max(1, Value);
    if not (csLoading in ComponentState) and (FMinColumns > FMaxColumns) then
      FMinColumns := FMaxColumns;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrGalleryItem.SetMinColumns(const Value: Integer);
begin
  if FMinColumns <> Value then
  begin
    FMinColumns := System.Math.Max(1, Value);
    if not (csLoading in ComponentState) and (FMaxColumns < FMinColumns) then
      FMaxColumns := FMinColumns;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrGalleryItem.SetSelectedIndex(const Value: Integer);
begin
  if csLoading in ComponentState then
    FLoadedSelectedIndex := Value
  else if (Value >= 0) and (Value < EntryCount) then
    SetSelectedEntry(GetEntry(Value))
  else
    SetSelectedEntry(nil);
end;

procedure TFmrGalleryItem.SetSelectionMode(const Value: TFmrGallerySelectionMode);
begin
  if FSelectionMode <> Value then
  begin
    FSelectionMode := Value;
    if Value = TFmrGallerySelectionMode.None then
      SelectedIndex := -1;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrGalleryItem.SetShowGroupHeaders(const Value: Boolean);
begin
  if FShowGroupHeaders <> Value then
  begin
    FShowGroupHeaders := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrGalleryItem.SetShowInRibbon(const Value: Boolean);
begin
  if FShowInRibbon <> Value then
  begin
    FShowInRibbon := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

initialization
  RegisterFmxClasses([TFmrButtonItem, TFmrSubItem, TFmrSeparatorItem, TFmrStaticItem, TFmrControlItem,
    TFmrEditItem, TFmrComboItem, TFmrSpinItem, TFmrTrackBarItem, TFmrFontNameItem, TFmrCheckItem, TFmrColorItem,
    TFmrGalleryItem, TFmrAvatarItem]);
  RegisterClasses([TFmrItemLinks, TFmrItemLink, TFmrGalleryGroups, TFmrGalleryGroup, TFmrGalleryEntries,
    TFmrGalleryEntry]);

end.
