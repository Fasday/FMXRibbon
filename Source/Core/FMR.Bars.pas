{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Bar manager, items and item links                    }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Bars;

/// Items + links model. TFmrBarManager is a non-visual TFmxObject whose children are the items (TFmrBarItem), so
/// the Structure View shows manager -> items and FMX streams them. Items are lightweight objects, not controls.
/// Ribbon groups, the quick access toolbar, menus and the mini toolbar hold TFmrItemLink objects (collection items)
/// that reference items; one item can have any number of links. An item notifies its links when it changes, every
/// link notifies the owner of its collection (IFmrItemLinksOwner); destroying an item deletes its links.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, System.Actions,
  System.ImageList, FMX.Types, FMX.ActnList, FMX.ImgList, FMR.Ribbon.Types, FMR.Bars.Images;

type
  EFmrBarError = class(Exception);

  TFmrBarManager = class;
  TFmrBarItem = class;
  TFmrItemLink = class;
  TFmrItemLinks = class;

  TFmrBarItemClass = class of TFmrBarItem;

  /// <summary>What happened in a bar manager.</summary>
  TFmrManagerChange = (
    ItemAdded,
    ItemRemoved,
    /// <summary>An item changed; AItemChange tells what.</summary>
    ItemChanged,
    /// <summary>The order of the items changed.</summary>
    Reordered,
    ImagesChanged,
    CategoriesChanged,
    /// <summary>EndUpdate or Loaded after changes made while updating: refresh everything.</summary>
    Updated,
    /// <summary>The manager is being destroyed: drop every reference to it and its items.</summary>
    Destroying);

  /// <summary>Subscriber of a bar manager (the ribbon, a customization form). Register with AddListener; remove
  /// yourself with RemoveListener before you are destroyed.</summary>
  IFmrBarManagerListener = interface
    ['{73686DD3-B788-4174-A10F-CBE6FA98AA7B}']
    procedure BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
      const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
  end;

  /// <summary>Implemented by the owner of a TFmrItemLinks collection (ribbon group, quick access toolbar, sub item,
  /// gallery). Calls are not made while the owner is loading or destroying.</summary>
  IFmrItemLinksOwner = interface
    ['{BD6084AB-A95A-44C0-8AE7-92067460535B}']
    /// <summary>Links were added, removed, moved or a link property changed.</summary>
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    /// <summary>The item of ALink changed.</summary>
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    /// <summary>ALink leaves the collection (destroyed or moved to another one): release what was created for it
    /// (ALink.ViewObject).</summary>
    procedure LinkRemoving(const ALink: TFmrItemLink);
  end;

  /// <summary>Rich tooltip of an item: bold header, description, optional image and footer.</summary>
  TFmrScreenTip = class(TPersistent)
  private
    [Weak] FOwner: TPersistent;
    FHeader: string;
    FDescription: string;
    FFooter: string;
    FImage: TFmrImageSource;
    FFooterImage: TFmrImageSource;
    FShowShortcut: Boolean;
    FShowFooter: Boolean;
    FWidth: Single;
    FOnChange: TNotifyEvent;
    procedure SetHeader(const Value: string);
    procedure SetDescription(const Value: string);
    procedure SetFooter(const Value: string);
    procedure SetImage(const Value: TFmrImageSource);
    procedure SetFooterImage(const Value: TFmrImageSource);
    procedure SetShowShortcut(const Value: Boolean);
    procedure SetShowFooter(const Value: Boolean);
    procedure SetWidth(const Value: Single);
    procedure ImageChanged(Sender: TObject);
    function IsWidthStored: Boolean;
  protected
    function GetOwner: TPersistent; override;
    procedure Changed;
  public
    constructor Create(const AOwner: TPersistent);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    /// <summary>True when no header, description and footer are set (the ribbon then shows the item caption and
    /// hint).</summary>
    function IsEmpty: Boolean;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property Header: string read FHeader write SetHeader;
    property Description: string read FDescription write SetDescription;
    /// <summary>Footer text; when empty and ShowFooter is set the ribbon shows "Press F1 for more help".</summary>
    property Footer: string read FFooter write SetFooter;
    property Image: TFmrImageSource read FImage write SetImage;
    property FooterImage: TFmrImageSource read FFooterImage write SetFooterImage;
    /// <summary>Appends the shortcut of the item to the header ("Copy (Ctrl+C)").</summary>
    property ShowShortcut: Boolean read FShowShortcut write SetShowShortcut default True;
    property ShowFooter: Boolean read FShowFooter write SetShowFooter default False;
    /// <summary>Width of the tip in dp; 0 = automatic.</summary>
    property Width: Single read FWidth write SetWidth stored IsWidthStored;
  end;

  /// <summary>Action link of bar items: Caption, Enabled, Visible, Hint, ShortCut, ImageIndex, Checked and
  /// GroupIndex follow a TAction; Click executes the action when the item has no OnClick handler.</summary>
  TFmrBarItemActionLink = class(FMX.ActnList.TActionLink)
  private
    function GetClient: TFmrBarItem;
  protected
    procedure AssignClient(AClient: TObject); override;
    function IsCaptionLinked: Boolean; override;
    function IsCheckedLinked: Boolean; override;
    function IsEnabledLinked: Boolean; override;
    function IsGroupIndexLinked: Boolean; override;
    function IsHintLinked: Boolean; override;
    function IsImageIndexLinked: Boolean; override;
    function IsShortCutLinked: Boolean; override;
    function IsVisibleLinked: Boolean; override;
    function IsOnExecuteLinked: Boolean; override;
    procedure SetCaption(const Value: string); override;
    procedure SetChecked(Value: Boolean); override;
    procedure SetEnabled(Value: Boolean); override;
    procedure SetGroupIndex(Value: Integer); override;
    procedure SetHint(const Value: string); override;
    procedure SetImageIndex(Value: Integer); override;
    procedure SetShortCut(Value: TShortCut); override;
    procedure SetVisible(Value: Boolean); override;
  public
    property Client: TFmrBarItem read GetClient;
  end;

  /// <summary>Base class of every item of a bar manager. Items are children of the manager (Parent) and are owned
  /// by the form like other components.</summary>
  TFmrBarItem = class(TFmxObject)
  private
    [Weak] FManager: TFmrBarManager;
    FCaption: string;
    FDescription: string;
    FHint: string;
    FKeyTip: string;
    FCategory: string;
    FKeywords: string;
    FEnabled: Boolean;
    FVisible: Boolean;
    FGlyph: TFmrImageSource;
    FLargeGlyph: TFmrImageSource;
    FShortCut: TShortCut;
    FScreenTip: TFmrScreenTip;
    FOnClick: TNotifyEvent;
    FLinks: TList<TFmrItemLink>;
    FChanging: Boolean;
    procedure SetCaption(const Value: string);
    procedure SetDescription(const Value: string);
    procedure SetHint(const Value: string);
    procedure SetKeyTip(const Value: string);
    procedure SetCategory(const Value: string);
    procedure SetEnabled(const Value: Boolean);
    procedure SetVisible(const Value: Boolean);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetLargeGlyph(const Value: TFmrImageSource);
    procedure SetShortCut(const Value: TShortCut);
    procedure SetScreenTip(const Value: TFmrScreenTip);
    function GetImageIndex: TImageIndex;
    procedure SetImageIndex(const Value: TImageIndex);
    function GetLinkCount: Integer;
    function GetLink(const AIndex: Integer): TFmrItemLink;
    function GetBarAction: TBasicAction;
    procedure SetBarAction(const Value: TBasicAction);
    procedure GlyphChanged(Sender: TObject);
    procedure ScreenTipChanged(Sender: TObject);
    function IsCaptionStored: Boolean;
    function IsEnabledStored: Boolean;
    function IsHintStored: Boolean;
    function IsShortCutStored: Boolean;
    function IsVisibleStored: Boolean;
    procedure AttachManager;
    procedure DetachManager;
  protected
    procedure ParentChanged; override;
    procedure Loaded; override;
    function GetActionLinkClass: TActionLinkClass; override;
    procedure ActionChange(Sender: TBasicAction; CheckDefaults: Boolean); override;
    /// <summary>Checked state shared with actions (Down of buttons, Checked of check items).</summary>
    function GetIsChecked: Boolean; virtual;
    procedure SetIsChecked(const Value: Boolean); virtual;
    function SupportsChecked: Boolean; virtual;
    function GetGroupIndexValue: Integer; virtual;
    procedure SetGroupIndexValue(const Value: Integer); virtual;
    /// <summary>Runs OnClick or, without a handler, the action.</summary>
    procedure DoClick; virtual;
    /// <summary>Notifies the links and the manager. Ignored while loading or destroying; re-entrant calls (an item
    /// whose links reach itself) are ignored.</summary>
    procedure Changed(const AChange: TFmrItemChange = TFmrItemChange.Layout); virtual;
    procedure AddLink(const ALink: TFmrItemLink);
    procedure RemoveLink(const ALink: TFmrItemLink);
    /// <summary>Called for links collections owned by this item (sub menus, drop-down content).</summary>
    procedure OwnedLinksChanged; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Executes the item (OnClick, or the action) when it is enabled.</summary>
    procedure Click; virtual;
    /// <summary>Asks the action (if any) to update the item (OnUpdate of the action).</summary>
    procedure UpdateFromAction;
    /// <summary>Levels a link uses when its ViewLevels is empty: all three when LargeGlyph is set, otherwise small
    /// with text and small (only small with text when there is no glyph).</summary>
    function DefaultViewLevels: TFmrViewLevels; virtual;
    /// <summary>How the layout calculator treats links of this item.</summary>
    function LayoutKind: TFmrLayoutItemKind; virtual;
    /// <summary>True when the item can be linked from ALinks (an item cannot be linked into its own collections).
    /// </summary>
    function CanLinkInto(const ALinks: TFmrItemLinks): Boolean; virtual;
    property Manager: TFmrBarManager read FManager;
    property LinkCount: Integer read GetLinkCount;
    property Links[const AIndex: Integer]: TFmrItemLink read GetLink;
    property IsChecked: Boolean read GetIsChecked write SetIsChecked;
  published
    property Action: TBasicAction read GetBarAction write SetBarAction;
    property Caption: string read FCaption write SetCaption stored IsCaptionStored;
    /// <summary>Category name (see TFmrBarManager.Categories); used by customization and command search.</summary>
    property Category: string read FCategory write SetCategory;
    /// <summary>Longer text shown in menus with descriptions and in command search.</summary>
    property Description: string read FDescription write SetDescription;
    property Enabled: Boolean read FEnabled write SetEnabled stored IsEnabledStored default True;
    /// <summary>Small (16 dp) image; also used for large views when LargeGlyph is empty.</summary>
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    /// <summary>Large (32 dp) image.</summary>
    property LargeGlyph: TFmrImageSource read FLargeGlyph write SetLargeGlyph;
    /// <summary>Shortcut to Glyph.ImageIndex (streamed by Glyph).</summary>
    property ImageIndex: TImageIndex read GetImageIndex write SetImageIndex stored False default -1;
    property Hint: string read FHint write SetHint stored IsHintStored;
    /// <summary>Extra words found by the command search ("print, printer, paper").</summary>
    property Keywords: string read FKeywords write FKeywords;
    /// <summary>Explicit key tip; empty = generated from the caption.</summary>
    property KeyTip: string read FKeyTip write SetKeyTip;
    property ScreenTip: TFmrScreenTip read FScreenTip write SetScreenTip;
    property ShortCut: TShortCut read FShortCut write SetShortCut stored IsShortCutStored default 0;
    property Visible: Boolean read FVisible write SetVisible stored IsVisibleStored default True;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  /// <summary>A reference to an item placed in a group, the quick access toolbar, a menu or the mini toolbar.
  /// </summary>
  TFmrItemLink = class(TCollectionItem)
  private
    FItem: TFmrBarItem;
    FBeginGroup: Boolean;
    FViewLevels: TFmrViewLevels;
    FButtonGroup: TFmrButtonGroupPosition;
    FVisible: Boolean;
    FUserCaption: string;
    FKeyTip: string;
    FSimplifiedVisibility: TFmrSimplifiedVisibility;
    FTag: NativeInt;
    FData: TObject;
    FViewObject: TObject;
    procedure SetItem(const Value: TFmrBarItem);
    procedure SetBeginGroup(const Value: Boolean);
    procedure SetViewLevels(const Value: TFmrViewLevels);
    procedure SetButtonGroup(const Value: TFmrButtonGroupPosition);
    procedure SetVisible(const Value: Boolean);
    procedure SetUserCaption(const Value: string);
    procedure SetKeyTip(const Value: string);
    procedure SetSimplifiedVisibility(const Value: TFmrSimplifiedVisibility);
    function GetLinks: TFmrItemLinks;
  protected
    function GetDisplayName: string; override;
    procedure ItemChanged(const AChange: TFmrItemChange);
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    /// <summary>UserCaption when set, otherwise the caption of the item.</summary>
    function Caption: string;
    /// <summary>KeyTip of the link when set, otherwise the key tip of the item.</summary>
    function EffectiveKeyTip: string;
    /// <summary>ViewLevels when not empty, otherwise the default levels of the item.</summary>
    function EffectiveViewLevels: TFmrViewLevels;
    /// <summary>Visible, has an item and the item is visible.</summary>
    function IsVisible: Boolean;
    /// <summary>Owner of the links collection (group, quick access toolbar, sub item...).</summary>
    function LinksOwner: TPersistent;
    /// <summary>Moves the link to another collection (or another position of the same one); -1 appends.</summary>
    procedure MoveTo(const ALinks: TFmrItemLinks; const AIndex: Integer = -1);
    property Links: TFmrItemLinks read GetLinks;
    /// <summary>Free for the application; not streamed, not owned.</summary>
    property Data: TObject read FData write FData;
    /// <summary>Reserved for the ribbon (control or view info created for this link); not streamed, not owned.
    /// The links owner is told with LinkRemoving when the link goes away.</summary>
    property ViewObject: TObject read FViewObject write FViewObject;
  published
    property Item: TFmrBarItem read FItem write SetItem;
    /// <summary>A separator is shown before this link.</summary>
    property BeginGroup: Boolean read FBeginGroup write SetBeginGroup default False;
    property ButtonGroup: TFmrButtonGroupPosition read FButtonGroup write SetButtonGroup
      default TFmrButtonGroupPosition.None;
    property KeyTip: string read FKeyTip write SetKeyTip;
    property SimplifiedVisibility: TFmrSimplifiedVisibility read FSimplifiedVisibility
      write SetSimplifiedVisibility default TFmrSimplifiedVisibility.Auto;
    property Tag: NativeInt read FTag write FTag default 0;
    /// <summary>Caption shown instead of the caption of the item (renamed by customization).</summary>
    property UserCaption: string read FUserCaption write SetUserCaption;
    /// <summary>Levels allowed in ribbon groups (largest first); empty = DefaultViewLevels of the item.</summary>
    property ViewLevels: TFmrViewLevels read FViewLevels write SetViewLevels default [];
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  /// <summary>Ordered links. The owner (AOwner of the constructor) is told about changes through
  /// IFmrItemLinksOwner when it implements it.</summary>
  TFmrItemLinks = class(TOwnedCollection)
  private
    function GetLink(const AIndex: Integer): TFmrItemLink;
    procedure SetLink(const AIndex: Integer; const Value: TFmrItemLink);
    function OwnerReady(out AOwner: IFmrItemLinksOwner): Boolean;
  protected
    procedure Update(Item: TCollectionItem); override;
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification); override;
    procedure DoLinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
  public
    constructor Create(const AOwner: TPersistent); reintroduce; virtual;
    function Add: TFmrItemLink;
    function Insert(const AIndex: Integer): TFmrItemLink;
    /// <summary>Appends a link to AItem.</summary>
    function AddItem(const AItem: TFmrBarItem; const ABeginGroup: Boolean = False): TFmrItemLink;
    function InsertItem(const AIndex: Integer; const AItem: TFmrBarItem): TFmrItemLink;
    /// <summary>Index of the first link to AItem, -1 when none.</summary>
    function IndexOfItem(const AItem: TFmrBarItem): Integer;
    function FindByItem(const AItem: TFmrBarItem): TFmrItemLink;
    function ContainsItem(const AItem: TFmrBarItem): Boolean;
    /// <summary>Deletes every link to AItem.</summary>
    procedure RemoveItem(const AItem: TFmrBarItem);
    /// <summary>Number of links whose IsVisible is True.</summary>
    function VisibleCount: Integer;
    property Items[const AIndex: Integer]: TFmrItemLink read GetLink write SetLink; default;
  end;

  /// <summary>Non-visual holder of the items of a form. Drop it on the form; its children are the items.</summary>
  TFmrBarManager = class(TFmxObject)
  private
    FImageLink: TImageLink;
    FCategories: TStrings;
    FListeners: TList<IFmrBarManagerListener>;
    FItems: TList<TFmrBarItem>;
    FItemsValid: Boolean;
    FUpdateCount: Integer;
    FPendingUpdate: Boolean;
    FDestroying: Boolean;
    function GetImages: TCustomImageList;
    procedure SetImages(const Value: TCustomImageList);
    procedure SetCategories(const Value: TStrings);
    function GetItemCount: Integer;
    function GetItem(const AIndex: Integer): TFmrBarItem;
    procedure ImagesChanged(Sender: TObject);
    procedure CategoriesChanged(Sender: TObject);
    procedure ValidateItems;
  protected
    procedure Notify(const AChange: TFmrManagerChange; const AItem: TFmrBarItem;
      const AItemChange: TFmrItemChange = TFmrItemChange.Layout); virtual;
    procedure ItemAdded(const AItem: TFmrBarItem); virtual;
    procedure ItemRemoved(const AItem: TFmrBarItem); virtual;
    procedure ItemChanged(const AItem: TFmrBarItem; const AChange: TFmrItemChange); virtual;
    procedure ChangeChildren; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    function IsUpdating: Boolean;
    procedure AddListener(const AListener: IFmrBarManagerListener);
    procedure RemoveListener(const AListener: IFmrBarManagerListener);
    /// <summary>Creates an item as a child of the manager, owned by the owner of the manager (the form), like the
    /// designer does.</summary>
    function CreateItem(const AClass: TFmrBarItemClass; const AName: string = ''): TFmrBarItem;
    /// <summary>Item with the given name (case-insensitive) or nil.</summary>
    function FindItem(const AName: string): TFmrBarItem;
    /// <summary>Item with the given name; raises EFmrBarError when there is none.</summary>
    function ItemByName(const AName: string): TFmrBarItem;
    function IndexOfItem(const AItem: TFmrBarItem): Integer;
    function ItemsInCategory(const ACategory: string): TArray<TFmrBarItem>;
    /// <summary>Command search ("Tell me"): visible items whose caption, description, hint, keywords or category
    /// contain every word of AText (case-insensitive, '&amp;' ignored). Captions starting with the text come
    /// first, then captions containing it, then the other matches; ties keep the item order. AMaxCount 0 = all.
    /// </summary>
    function SearchItems(const AText: string; const AMaxCount: Integer = 0): TArray<TFmrBarItem>;
    /// <summary>A name not used by another component of the owner: ABase1, ABase2...</summary>
    function UniqueItemName(const ABase: string): string;
    property ItemCount: Integer read GetItemCount;
    property Items[const AIndex: Integer]: TFmrBarItem read GetItem;
  published
    property Categories: TStrings read FCategories write SetCategories;
    property Images: TCustomImageList read GetImages write SetImages;
  end;

  TFmrItemDestroyingHook = procedure(const AItem: TFmrBarItem);
  TFmrLinkDestroyingHook = procedure(const ALink: TFmrItemLink);

var
  /// <summary>Called first in the destructor of every bar item, also of items without a manager (FMR.Ribbon.Popup
  /// closes the open popups that show the item).</summary>
  FmrItemDestroyingHook: TFmrItemDestroyingHook = nil;
  /// <summary>Called first in the destructor of every item link.</summary>
  FmrLinkDestroyingHook: TFmrLinkDestroyingHook = nil;

implementation

resourcestring
  SFmrActionClientClass = 'Class %s cannot be a client of a bar item action link';
  SFmrCannotLinkIntoItself = 'Item %s cannot be linked into its own links';
  SFmrItemNotFound = 'Bar item "%s" not found';

{ TFmrScreenTip }

constructor TFmrScreenTip.Create(const AOwner: TPersistent);
begin
  inherited Create;
  FOwner := AOwner;
  FShowShortcut := True;
  FImage := TFmrImageSource.Create(Self);
  FImage.OnChange := ImageChanged;
  FFooterImage := TFmrImageSource.Create(Self);
  FFooterImage.OnChange := ImageChanged;
end;

destructor TFmrScreenTip.Destroy;
begin
  FImage.Free;
  FFooterImage.Free;
  inherited;
end;

function TFmrScreenTip.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

procedure TFmrScreenTip.Assign(Source: TPersistent);
var
  S: TFmrScreenTip;
begin
  if Source is TFmrScreenTip then
  begin
    S := TFmrScreenTip(Source);
    FHeader := S.FHeader;
    FDescription := S.FDescription;
    FFooter := S.FFooter;
    FShowShortcut := S.FShowShortcut;
    FShowFooter := S.FShowFooter;
    FWidth := S.FWidth;
    FImage.Assign(S.FImage);
    FFooterImage.Assign(S.FFooterImage);
    Changed;
  end
  else
    inherited;
end;

procedure TFmrScreenTip.Changed;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TFmrScreenTip.ImageChanged(Sender: TObject);
begin
  Changed;
end;

function TFmrScreenTip.IsEmpty: Boolean;
begin
  Result := (FHeader = '') and (FDescription = '') and (FFooter = '');
end;

function TFmrScreenTip.IsWidthStored: Boolean;
begin
  Result := FWidth <> 0;
end;

procedure TFmrScreenTip.SetDescription(const Value: string);
begin
  if FDescription <> Value then
  begin
    FDescription := Value;
    Changed;
  end;
end;

procedure TFmrScreenTip.SetFooter(const Value: string);
begin
  if FFooter <> Value then
  begin
    FFooter := Value;
    Changed;
  end;
end;

procedure TFmrScreenTip.SetFooterImage(const Value: TFmrImageSource);
begin
  FFooterImage.Assign(Value);
end;

procedure TFmrScreenTip.SetHeader(const Value: string);
begin
  if FHeader <> Value then
  begin
    FHeader := Value;
    Changed;
  end;
end;

procedure TFmrScreenTip.SetImage(const Value: TFmrImageSource);
begin
  FImage.Assign(Value);
end;

procedure TFmrScreenTip.SetShowFooter(const Value: Boolean);
begin
  if FShowFooter <> Value then
  begin
    FShowFooter := Value;
    Changed;
  end;
end;

procedure TFmrScreenTip.SetShowShortcut(const Value: Boolean);
begin
  if FShowShortcut <> Value then
  begin
    FShowShortcut := Value;
    Changed;
  end;
end;

procedure TFmrScreenTip.SetWidth(const Value: Single);
begin
  if FWidth <> Value then
  begin
    FWidth := Value;
    Changed;
  end;
end;

{ TFmrBarItemActionLink }

procedure TFmrBarItemActionLink.AssignClient(AClient: TObject);
begin
  if not (AClient is TFmrBarItem) then
    raise EActionError.CreateFmt(SFmrActionClientClass, [AClient.ClassName]);
  inherited;
end;

function TFmrBarItemActionLink.GetClient: TFmrBarItem;
begin
  Result := TFmrBarItem(inherited Client);
end;

function TFmrBarItemActionLink.IsCaptionLinked: Boolean;
begin
  Result := (Action is TContainedAction) and (Client.Caption = TContainedAction(Action).Caption);
end;

function TFmrBarItemActionLink.IsCheckedLinked: Boolean;
begin
  Result := (Action is TContainedAction) and Client.SupportsChecked and
    (Client.GetIsChecked = TContainedAction(Action).Checked);
end;

function TFmrBarItemActionLink.IsEnabledLinked: Boolean;
begin
  Result := (Action is TContainedAction) and (Client.Enabled = TContainedAction(Action).Enabled);
end;

function TFmrBarItemActionLink.IsGroupIndexLinked: Boolean;
begin
  Result := (Action is TContainedAction) and Client.SupportsChecked and
    (Client.GetGroupIndexValue = TContainedAction(Action).GroupIndex);
end;

function TFmrBarItemActionLink.IsHintLinked: Boolean;
begin
  Result := (Action is TContainedAction) and (Client.Hint = TContainedAction(Action).Hint);
end;

function TFmrBarItemActionLink.IsImageIndexLinked: Boolean;
begin
  Result := (Action is TContainedAction) and
    ((Client.ImageIndex = TContainedAction(Action).ImageIndex) or (Client.ImageIndex < 0));
end;

function TFmrBarItemActionLink.IsOnExecuteLinked: Boolean;
begin
  Result := False;
end;

function TFmrBarItemActionLink.IsShortCutLinked: Boolean;
begin
  Result := (Action is TContainedAction) and (Client.ShortCut = TContainedAction(Action).ShortCut);
end;

function TFmrBarItemActionLink.IsVisibleLinked: Boolean;
begin
  Result := (Action is TContainedAction) and (Client.Visible = TContainedAction(Action).Visible);
end;

procedure TFmrBarItemActionLink.SetCaption(const Value: string);
begin
  if IsCaptionLinked then
    Client.Caption := Value;
end;

procedure TFmrBarItemActionLink.SetChecked(Value: Boolean);
begin
  if IsCheckedLinked then
    Client.SetIsChecked(Value);
end;

procedure TFmrBarItemActionLink.SetEnabled(Value: Boolean);
begin
  if IsEnabledLinked then
    Client.Enabled := Value;
end;

procedure TFmrBarItemActionLink.SetGroupIndex(Value: Integer);
begin
  if IsGroupIndexLinked then
    Client.SetGroupIndexValue(Value);
end;

procedure TFmrBarItemActionLink.SetHint(const Value: string);
begin
  if IsHintLinked then
    Client.Hint := Value;
end;

procedure TFmrBarItemActionLink.SetImageIndex(Value: Integer);
begin
  if IsImageIndexLinked then
    Client.ImageIndex := Value;
end;

procedure TFmrBarItemActionLink.SetShortCut(Value: TShortCut);
begin
  if IsShortCutLinked then
    Client.ShortCut := Value;
end;

procedure TFmrBarItemActionLink.SetVisible(Value: Boolean);
begin
  if IsVisibleLinked then
    Client.Visible := Value;
end;

{ TFmrBarItem }

constructor TFmrBarItem.Create(AOwner: TComponent);
begin
  inherited;
  FEnabled := True;
  FVisible := True;
  FLinks := TList<TFmrItemLink>.Create;
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
  FLargeGlyph := TFmrImageSource.Create(Self);
  FLargeGlyph.OnChange := GlyphChanged;
  FScreenTip := TFmrScreenTip.Create(Self);
  FScreenTip.OnChange := ScreenTipChanged;
end;

destructor TFmrBarItem.Destroy;
begin
  if Assigned(FmrItemDestroyingHook) then
    FmrItemDestroyingHook(Self);
  while FLinks.Count > 0 do
    FLinks.Last.Free;
  DetachManager;
  FreeAndNil(FLinks);
  FreeAndNil(FGlyph);
  FreeAndNil(FLargeGlyph);
  FreeAndNil(FScreenTip);
  inherited;
end;

procedure TFmrBarItem.AttachManager;
var
  NewManager: TFmrBarManager;
begin
  if Parent is TFmrBarManager then
    NewManager := TFmrBarManager(Parent)
  else
    NewManager := nil;
  if NewManager = FManager then
    Exit;
  DetachManager;
  FManager := NewManager;
  if FManager <> nil then
  begin
    FManager.ItemAdded(Self);
    if (FCategory <> '') and not (csLoading in ComponentState) and (FManager.Categories.IndexOf(FCategory) < 0) then
      FManager.Categories.Add(FCategory);
  end;
end;

procedure TFmrBarItem.DetachManager;
var
  Old: TFmrBarManager;
begin
  Old := FManager;
  FManager := nil;
  if Old <> nil then
    Old.ItemRemoved(Self);
end;

procedure TFmrBarItem.ParentChanged;
begin
  inherited;
  if FLinks <> nil then
    AttachManager;
end;

procedure TFmrBarItem.Loaded;
begin
  inherited;
  if (FManager <> nil) and (FCategory <> '') and (FManager.Categories.IndexOf(FCategory) < 0) then
    FManager.Categories.Add(FCategory);
end;

function TFmrBarItem.GetActionLinkClass: TActionLinkClass;
begin
  Result := TFmrBarItemActionLink;
end;

function TFmrBarItem.GetBarAction: TBasicAction;
begin
  Result := inherited Action;
end;

procedure TFmrBarItem.SetBarAction(const Value: TBasicAction);
begin
  inherited Action := Value;
end;

procedure TFmrBarItem.ActionChange(Sender: TBasicAction; CheckDefaults: Boolean);
var
  A: TContainedAction;
begin
  inherited;
  if not (Sender is TContainedAction) then
    Exit;
  A := TContainedAction(Sender);
  if not CheckDefaults or (Caption = '') then
    Caption := A.Caption;
  if not CheckDefaults or Enabled then
    Enabled := A.Enabled;
  if not CheckDefaults or (Hint = '') then
    Hint := A.Hint;
  if not CheckDefaults or Visible then
    Visible := A.Visible;
  if not CheckDefaults or (ShortCut = 0) then
    ShortCut := A.ShortCut;
  if (not CheckDefaults or (ImageIndex < 0)) and (A.ImageIndex >= 0) then
    ImageIndex := A.ImageIndex;
  if SupportsChecked then
  begin
    if not CheckDefaults or not GetIsChecked then
      SetIsChecked(A.Checked);
    if not CheckDefaults or (GetGroupIndexValue = 0) then
      SetGroupIndexValue(A.GroupIndex);
  end;
end;

function TFmrBarItem.GetIsChecked: Boolean;
begin
  Result := False;
end;

procedure TFmrBarItem.SetIsChecked(const Value: Boolean);
begin
end;

function TFmrBarItem.SupportsChecked: Boolean;
begin
  Result := False;
end;

function TFmrBarItem.GetGroupIndexValue: Integer;
begin
  Result := 0;
end;

procedure TFmrBarItem.SetGroupIndexValue(const Value: Integer);
begin
end;

procedure TFmrBarItem.Click;
begin
  if FEnabled then
    DoClick;
end;

procedure TFmrBarItem.DoClick;
begin
  if Assigned(FOnClick) then
    FOnClick(Self)
  else if (ActionLink <> nil) and not (csDesigning in ComponentState) then
    ActionLink.Execute(Self);
end;

procedure TFmrBarItem.UpdateFromAction;
begin
  InitiateAction;
end;

procedure TFmrBarItem.Changed(const AChange: TFmrItemChange);
var
  Snapshot: TArray<TFmrItemLink>;
  L: TFmrItemLink;
begin
  if FChanging or (FLinks = nil) or ([csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  FChanging := True;
  try
    Snapshot := FLinks.ToArray;
    for L in Snapshot do
      if FLinks.Contains(L) then
        L.ItemChanged(AChange);
    if FManager <> nil then
      FManager.ItemChanged(Self, AChange);
  finally
    FChanging := False;
  end;
end;

procedure TFmrBarItem.OwnedLinksChanged;
begin
  Changed(TFmrItemChange.Paint);
end;

procedure TFmrBarItem.AddLink(const ALink: TFmrItemLink);
begin
  if (FLinks <> nil) and not FLinks.Contains(ALink) then
    FLinks.Add(ALink);
end;

procedure TFmrBarItem.RemoveLink(const ALink: TFmrItemLink);
begin
  if FLinks <> nil then
    FLinks.Remove(ALink);
end;

function TFmrBarItem.CanLinkInto(const ALinks: TFmrItemLinks): Boolean;
begin
  Result := (ALinks = nil) or (ALinks.Owner <> Self);
end;

function TFmrBarItem.DefaultViewLevels: TFmrViewLevels;
begin
  if not FLargeGlyph.IsEmpty then
    Result := FmrAllViewLevels
  else if FGlyph.IsEmpty then
    Result := [TFmrViewLevel.SmallWithText]
  else
    Result := FmrSmallViewLevels;
end;

function TFmrBarItem.LayoutKind: TFmrLayoutItemKind;
begin
  Result := TFmrLayoutItemKind.Button;
end;

function TFmrBarItem.GetLinkCount: Integer;
begin
  Result := FLinks.Count;
end;

function TFmrBarItem.GetLink(const AIndex: Integer): TFmrItemLink;
begin
  Result := FLinks[AIndex];
end;

procedure TFmrBarItem.GlyphChanged(Sender: TObject);
begin
  Changed(TFmrItemChange.Layout);
end;

procedure TFmrBarItem.ScreenTipChanged(Sender: TObject);
begin
  Changed(TFmrItemChange.Paint);
end;

function TFmrBarItem.GetImageIndex: TImageIndex;
begin
  Result := FGlyph.ImageIndex;
end;

procedure TFmrBarItem.SetImageIndex(const Value: TImageIndex);
begin
  FGlyph.ImageIndex := Value;
end;

function TFmrBarItem.IsCaptionStored: Boolean;
begin
  Result := (ActionLink = nil) or not TFmrBarItemActionLink(ActionLink).IsCaptionLinked;
end;

function TFmrBarItem.IsEnabledStored: Boolean;
begin
  Result := (ActionLink = nil) or not TFmrBarItemActionLink(ActionLink).IsEnabledLinked;
end;

function TFmrBarItem.IsHintStored: Boolean;
begin
  Result := (ActionLink = nil) or not TFmrBarItemActionLink(ActionLink).IsHintLinked;
end;

function TFmrBarItem.IsShortCutStored: Boolean;
begin
  Result := (ActionLink = nil) or not TFmrBarItemActionLink(ActionLink).IsShortCutLinked;
end;

function TFmrBarItem.IsVisibleStored: Boolean;
begin
  Result := (ActionLink = nil) or not TFmrBarItemActionLink(ActionLink).IsVisibleLinked;
end;

procedure TFmrBarItem.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

procedure TFmrBarItem.SetCategory(const Value: string);
begin
  if FCategory <> Value then
  begin
    FCategory := Value;
    if (FManager <> nil) and (Value <> '') and not (csLoading in ComponentState) and
      (FManager.Categories.IndexOf(Value) < 0) then
      FManager.Categories.Add(Value);
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrBarItem.SetDescription(const Value: string);
begin
  if FDescription <> Value then
  begin
    FDescription := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrBarItem.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrBarItem.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrBarItem.SetLargeGlyph(const Value: TFmrImageSource);
begin
  FLargeGlyph.Assign(Value);
end;

procedure TFmrBarItem.SetHint(const Value: string);
begin
  if FHint <> Value then
  begin
    FHint := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrBarItem.SetKeyTip(const Value: string);
begin
  if FKeyTip <> Value then
  begin
    FKeyTip := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrBarItem.SetScreenTip(const Value: TFmrScreenTip);
begin
  FScreenTip.Assign(Value);
end;

procedure TFmrBarItem.SetShortCut(const Value: TShortCut);
begin
  if FShortCut <> Value then
  begin
    FShortCut := Value;
    Changed(TFmrItemChange.Paint);
  end;
end;

procedure TFmrBarItem.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed(TFmrItemChange.Layout);
  end;
end;

{ TFmrItemLink }

constructor TFmrItemLink.Create(Collection: TCollection);
begin
  FVisible := True;
  inherited;
end;

destructor TFmrItemLink.Destroy;
begin
  if Assigned(FmrLinkDestroyingHook) then
    FmrLinkDestroyingHook(Self);
  // Leave the collection first so its owner is told (LinkRemoving) while Item is still assigned.
  Collection := nil;
  if FItem <> nil then
    FItem.RemoveLink(Self);
  FItem := nil;
  inherited;
end;

procedure TFmrItemLink.Assign(Source: TPersistent);
var
  S: TFmrItemLink;
begin
  if Source is TFmrItemLink then
  begin
    S := TFmrItemLink(Source);
    FBeginGroup := S.FBeginGroup;
    FViewLevels := S.FViewLevels;
    FButtonGroup := S.FButtonGroup;
    FVisible := S.FVisible;
    FUserCaption := S.FUserCaption;
    FKeyTip := S.FKeyTip;
    FSimplifiedVisibility := S.FSimplifiedVisibility;
    FTag := S.FTag;
    FData := S.FData;
    Item := S.FItem;
    Changed(False);
  end
  else
    inherited;
end;

function TFmrItemLink.GetDisplayName: string;
begin
  if FItem = nil then
    Result := inherited GetDisplayName
  else if FItem.Name <> '' then
    Result := FItem.Name
  else
    Result := FItem.Caption;
end;

function TFmrItemLink.GetLinks: TFmrItemLinks;
begin
  Result := TFmrItemLinks(Collection);
end;

function TFmrItemLink.LinksOwner: TPersistent;
begin
  if Collection <> nil then
    Result := TFmrItemLinks(Collection).Owner
  else
    Result := nil;
end;

procedure TFmrItemLink.ItemChanged(const AChange: TFmrItemChange);
begin
  if Collection <> nil then
    TFmrItemLinks(Collection).DoLinkItemChanged(Self, AChange);
end;

function TFmrItemLink.Caption: string;
begin
  if FUserCaption <> '' then
    Result := FUserCaption
  else if FItem <> nil then
    Result := FItem.Caption
  else
    Result := '';
end;

function TFmrItemLink.EffectiveKeyTip: string;
begin
  if FKeyTip <> '' then
    Result := FKeyTip
  else if FItem <> nil then
    Result := FItem.KeyTip
  else
    Result := '';
end;

function TFmrItemLink.EffectiveViewLevels: TFmrViewLevels;
begin
  if FViewLevels <> [] then
    Result := FViewLevels
  else if FItem <> nil then
    Result := FItem.DefaultViewLevels
  else
    Result := [TFmrViewLevel.SmallWithText];
end;

function TFmrItemLink.IsVisible: Boolean;
begin
  Result := FVisible and (FItem <> nil) and FItem.Visible;
end;

procedure TFmrItemLink.MoveTo(const ALinks: TFmrItemLinks; const AIndex: Integer);
begin
  if ALinks = nil then
    Exit;
  if (FItem <> nil) and not FItem.CanLinkInto(ALinks) then
    raise EFmrBarError.CreateFmt(SFmrCannotLinkIntoItself, [FItem.Name]);
  if Collection <> ALinks then
    Collection := ALinks;
  if (AIndex >= 0) and (AIndex < ALinks.Count) then
    Index := AIndex;
end;

procedure TFmrItemLink.SetItem(const Value: TFmrBarItem);
begin
  if FItem = Value then
    Exit;
  if (Value <> nil) and not Value.CanLinkInto(Links) then
    raise EFmrBarError.CreateFmt(SFmrCannotLinkIntoItself, [Value.Name]);
  if FItem <> nil then
    FItem.RemoveLink(Self);
  FItem := Value;
  if FItem <> nil then
    FItem.AddLink(Self);
  Changed(False);
end;

procedure TFmrItemLink.SetBeginGroup(const Value: Boolean);
begin
  if FBeginGroup <> Value then
  begin
    FBeginGroup := Value;
    Changed(False);
  end;
end;

procedure TFmrItemLink.SetButtonGroup(const Value: TFmrButtonGroupPosition);
begin
  if FButtonGroup <> Value then
  begin
    FButtonGroup := Value;
    Changed(False);
  end;
end;

procedure TFmrItemLink.SetKeyTip(const Value: string);
begin
  if FKeyTip <> Value then
  begin
    FKeyTip := Value;
    Changed(False);
  end;
end;

procedure TFmrItemLink.SetSimplifiedVisibility(const Value: TFmrSimplifiedVisibility);
begin
  if FSimplifiedVisibility <> Value then
  begin
    FSimplifiedVisibility := Value;
    Changed(False);
  end;
end;

procedure TFmrItemLink.SetUserCaption(const Value: string);
begin
  if FUserCaption <> Value then
  begin
    FUserCaption := Value;
    Changed(False);
  end;
end;

procedure TFmrItemLink.SetViewLevels(const Value: TFmrViewLevels);
begin
  if FViewLevels <> Value then
  begin
    FViewLevels := Value;
    Changed(False);
  end;
end;

procedure TFmrItemLink.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed(False);
  end;
end;

{ TFmrItemLinks }

constructor TFmrItemLinks.Create(const AOwner: TPersistent);
begin
  inherited Create(AOwner, TFmrItemLink);
end;

function TFmrItemLinks.OwnerReady(out AOwner: IFmrItemLinksOwner): Boolean;
var
  O: TPersistent;
begin
  O := Owner;
  if (O is TComponent) and ([csLoading, csDestroying] * TComponent(O).ComponentState <> []) then
    Exit(False);
  Result := (O <> nil) and Supports(O, IFmrItemLinksOwner, AOwner);
end;

function TFmrItemLinks.Add: TFmrItemLink;
begin
  Result := TFmrItemLink(inherited Add);
end;

function TFmrItemLinks.Insert(const AIndex: Integer): TFmrItemLink;
begin
  Result := TFmrItemLink(inherited Insert(AIndex));
end;

function TFmrItemLinks.AddItem(const AItem: TFmrBarItem; const ABeginGroup: Boolean): TFmrItemLink;
begin
  if (AItem <> nil) and not AItem.CanLinkInto(Self) then
    raise EFmrBarError.CreateFmt(SFmrCannotLinkIntoItself, [AItem.Name]);
  BeginUpdate;
  try
    Result := Add;
    Result.FBeginGroup := ABeginGroup;
    Result.Item := AItem;
  finally
    EndUpdate;
  end;
end;

function TFmrItemLinks.InsertItem(const AIndex: Integer; const AItem: TFmrBarItem): TFmrItemLink;
begin
  if (AItem <> nil) and not AItem.CanLinkInto(Self) then
    raise EFmrBarError.CreateFmt(SFmrCannotLinkIntoItself, [AItem.Name]);
  BeginUpdate;
  try
    Result := Insert(AIndex);
    Result.Item := AItem;
  finally
    EndUpdate;
  end;
end;

function TFmrItemLinks.IndexOfItem(const AItem: TFmrBarItem): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Item = AItem then
      Exit(I);
  Result := -1;
end;

function TFmrItemLinks.FindByItem(const AItem: TFmrBarItem): TFmrItemLink;
var
  I: Integer;
begin
  I := IndexOfItem(AItem);
  if I >= 0 then
    Result := Items[I]
  else
    Result := nil;
end;

function TFmrItemLinks.ContainsItem(const AItem: TFmrBarItem): Boolean;
begin
  Result := IndexOfItem(AItem) >= 0;
end;

procedure TFmrItemLinks.RemoveItem(const AItem: TFmrBarItem);
var
  I: Integer;
begin
  BeginUpdate;
  try
    for I := Count - 1 downto 0 do
      if Items[I].Item = AItem then
        Delete(I);
  finally
    EndUpdate;
  end;
end;

function TFmrItemLinks.VisibleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Items[I].IsVisible then
      Inc(Result);
end;

function TFmrItemLinks.GetLink(const AIndex: Integer): TFmrItemLink;
begin
  Result := TFmrItemLink(inherited Items[AIndex]);
end;

procedure TFmrItemLinks.SetLink(const AIndex: Integer; const Value: TFmrItemLink);
begin
  inherited Items[AIndex] := Value;
end;

procedure TFmrItemLinks.Notify(Item: TCollectionItem; Action: TCollectionNotification);
var
  O: IFmrItemLinksOwner;
begin
  inherited;
  if (Action = TCollectionNotification.cnExtracting) and OwnerReady(O) then
    O.LinkRemoving(TFmrItemLink(Item));
end;

procedure TFmrItemLinks.Update(Item: TCollectionItem);
var
  O: IFmrItemLinksOwner;
begin
  inherited;
  if OwnerReady(O) then
    O.LinksChanged(Self);
end;

procedure TFmrItemLinks.DoLinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
var
  O: IFmrItemLinksOwner;
begin
  if (UpdateCount = 0) and OwnerReady(O) then
    O.LinkItemChanged(ALink, AChange);
end;

{ TFmrBarManager }

constructor TFmrBarManager.Create(AOwner: TComponent);
begin
  inherited;
  FCategories := TStringList.Create;
  TStringList(FCategories).OnChange := CategoriesChanged;
  FListeners := TList<IFmrBarManagerListener>.Create;
  FItems := TList<TFmrBarItem>.Create;
  FImageLink := TImageLink.Create;
  FImageLink.OnChange := ImagesChanged;
end;

destructor TFmrBarManager.Destroy;
var
  I: Integer;
begin
  FDestroying := True;
  Notify(TFmrManagerChange.Destroying, nil);
  FListeners.Clear;
  ValidateItems;
  for I := 0 to FItems.Count - 1 do
    FItems[I].FManager := nil;
  FItems.Clear;
  FreeAndNil(FImageLink);
  inherited;
  FreeAndNil(FItems);
  FreeAndNil(FListeners);
  FreeAndNil(FCategories);
end;

procedure TFmrBarManager.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TFmrBarManager.EndUpdate;
begin
  if FUpdateCount > 0 then
  begin
    Dec(FUpdateCount);
    if (FUpdateCount = 0) and FPendingUpdate then
    begin
      FPendingUpdate := False;
      Notify(TFmrManagerChange.Updated, nil);
    end;
  end;
end;

function TFmrBarManager.IsUpdating: Boolean;
begin
  Result := FUpdateCount > 0;
end;

procedure TFmrBarManager.AddListener(const AListener: IFmrBarManagerListener);
begin
  if (AListener <> nil) and (FListeners <> nil) and not FListeners.Contains(AListener) then
    FListeners.Add(AListener);
end;

procedure TFmrBarManager.RemoveListener(const AListener: IFmrBarManagerListener);
begin
  if FListeners <> nil then
    FListeners.Remove(AListener);
end;

procedure TFmrBarManager.Notify(const AChange: TFmrManagerChange; const AItem: TFmrBarItem;
  const AItemChange: TFmrItemChange);
var
  Snapshot: TArray<IFmrBarManagerListener>;
  L: IFmrBarManagerListener;
begin
  if (FListeners = nil) or (FListeners.Count = 0) then
    Exit;
  if (AChange <> TFmrManagerChange.Destroying) and (FDestroying or (csLoading in ComponentState)) then
    Exit;
  if (FUpdateCount > 0) and (AChange <> TFmrManagerChange.Destroying) then
  begin
    FPendingUpdate := True;
    Exit;
  end;
  Snapshot := FListeners.ToArray;
  for L in Snapshot do
    if FListeners.Contains(L) then
      L.BarManagerChanged(Self, AChange, AItem, AItemChange);
end;

procedure TFmrBarManager.ItemAdded(const AItem: TFmrBarItem);
begin
  FItemsValid := False;
  Notify(TFmrManagerChange.ItemAdded, AItem);
end;

procedure TFmrBarManager.ItemRemoved(const AItem: TFmrBarItem);
begin
  FItemsValid := False;
  if FItems <> nil then
    FItems.Remove(AItem);
  Notify(TFmrManagerChange.ItemRemoved, AItem);
end;

procedure TFmrBarManager.ItemChanged(const AItem: TFmrBarItem; const AChange: TFmrItemChange);
begin
  Notify(TFmrManagerChange.ItemChanged, AItem, AChange);
end;

procedure TFmrBarManager.ChangeChildren;
begin
  inherited;
  if FItems <> nil then
  begin
    FItemsValid := False;
    Notify(TFmrManagerChange.Reordered, nil);
  end;
end;

procedure TFmrBarManager.Loaded;
begin
  inherited;
  FItemsValid := False;
  Notify(TFmrManagerChange.Updated, nil);
end;

procedure TFmrBarManager.ValidateItems;
var
  I: Integer;
begin
  if FItemsValid or (FItems = nil) then
    Exit;
  FItems.Clear;
  for I := 0 to ChildrenCount - 1 do
    if (Children[I] is TFmrBarItem) and not (csDestroying in Children[I].ComponentState) then
      FItems.Add(TFmrBarItem(Children[I]));
  FItemsValid := True;
end;

function TFmrBarManager.GetItemCount: Integer;
begin
  ValidateItems;
  Result := FItems.Count;
end;

function TFmrBarManager.GetItem(const AIndex: Integer): TFmrBarItem;
begin
  ValidateItems;
  Result := FItems[AIndex];
end;

function TFmrBarManager.IndexOfItem(const AItem: TFmrBarItem): Integer;
begin
  ValidateItems;
  Result := FItems.IndexOf(AItem);
end;

function TFmrBarManager.CreateItem(const AClass: TFmrBarItemClass; const AName: string): TFmrBarItem;
var
  LOwner: TComponent;
begin
  LOwner := Owner;
  if LOwner = nil then
    LOwner := Self;
  Result := AClass.Create(LOwner);
  try
    if AName <> '' then
      Result.Name := AName;
    Result.Parent := Self;
  except
    Result.Free;
    raise;
  end;
end;

function TFmrBarManager.FindItem(const AName: string): TFmrBarItem;
var
  I: Integer;
begin
  if AName <> '' then
  begin
    ValidateItems;
    for I := 0 to FItems.Count - 1 do
      if SameText(FItems[I].Name, AName) then
        Exit(FItems[I]);
  end;
  Result := nil;
end;

function TFmrBarManager.ItemByName(const AName: string): TFmrBarItem;
begin
  Result := FindItem(AName);
  if Result = nil then
    raise EFmrBarError.CreateFmt(SFmrItemNotFound, [AName]);
end;

function TFmrBarManager.ItemsInCategory(const ACategory: string): TArray<TFmrBarItem>;
var
  L: TList<TFmrBarItem>;
  I: Integer;
begin
  ValidateItems;
  L := TList<TFmrBarItem>.Create;
  try
    for I := 0 to FItems.Count - 1 do
      if SameText(FItems[I].Category, ACategory) then
        L.Add(FItems[I]);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function TFmrBarManager.SearchItems(const AText: string; const AMaxCount: Integer): TArray<TFmrBarItem>;
var
  Needle, Caption, Haystack: string;
  Words: TArray<string>;
  Buckets: array[0..2] of TList<TFmrBarItem>;
  I, B: Integer;
  Item: TFmrBarItem;
  All: Boolean;
  W: string;
  L: TList<TFmrBarItem>;
begin
  Result := nil;
  Needle := AText.Replace('&', '').Trim.ToLower;
  if Needle = '' then
    Exit;
  Words := Needle.Split([' '], TStringSplitOptions.ExcludeEmpty);
  ValidateItems;
  for B := 0 to 2 do
    Buckets[B] := TList<TFmrBarItem>.Create;
  L := TList<TFmrBarItem>.Create;
  try
    for I := 0 to FItems.Count - 1 do
    begin
      Item := FItems[I];
      if not Item.Visible then
        Continue;
      Caption := Item.Caption.Replace('&', '').ToLower;
      Haystack := Caption + #1 + Item.Description.ToLower + #1 + Item.Hint.ToLower + #1 + Item.Keywords.ToLower +
        #1 + Item.Category.ToLower;
      All := True;
      for W in Words do
        if not Haystack.Contains(W) then
        begin
          All := False;
          Break;
        end;
      if not All then
        Continue;
      if Caption.StartsWith(Needle) then
        Buckets[0].Add(Item)
      else if Caption.Contains(Needle) then
        Buckets[1].Add(Item)
      else
        Buckets[2].Add(Item);
    end;
    for B := 0 to 2 do
      L.AddRange(Buckets[B]);
    if (AMaxCount > 0) and (L.Count > AMaxCount) then
      L.Count := AMaxCount;
    Result := L.ToArray;
  finally
    L.Free;
    for B := 0 to 2 do
      Buckets[B].Free;
  end;
end;

function TFmrBarManager.UniqueItemName(const ABase: string): string;
var
  N: Integer;
  Scope: TComponent;
begin
  Scope := Owner;
  if Scope = nil then
    Scope := Self;
  N := 1;
  repeat
    Result := ABase + IntToStr(N);
    Inc(N);
  until (Scope.FindComponent(Result) = nil) and (FindItem(Result) = nil);
end;

function TFmrBarManager.GetImages: TCustomImageList;
begin
  if FImageLink <> nil then
    Result := TCustomImageList(FImageLink.Images)
  else
    Result := nil;
end;

procedure TFmrBarManager.SetImages(const Value: TCustomImageList);
begin
  if FImageLink.Images <> Value then
  begin
    FImageLink.Images := Value;
    ImagesChanged(nil);
  end;
end;

procedure TFmrBarManager.ImagesChanged(Sender: TObject);
begin
  if not FDestroying then
    Notify(TFmrManagerChange.ImagesChanged, nil, TFmrItemChange.Paint);
end;

procedure TFmrBarManager.CategoriesChanged(Sender: TObject);
begin
  Notify(TFmrManagerChange.CategoriesChanged, nil, TFmrItemChange.Paint);
end;

procedure TFmrBarManager.SetCategories(const Value: TStrings);
begin
  FCategories.Assign(Value);
end;

initialization
  RegisterFmxClasses([TFmrBarManager, TFmrBarItem]);

end.
