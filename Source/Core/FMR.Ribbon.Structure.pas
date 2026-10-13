{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Ribbon structure: tabs, groups, context groups, QAT  }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Structure;

/// The ribbon control has children TFmrRibbonTab and TFmrRibbonContextGroup; tabs have children TFmrRibbonGroup
/// whose ItemLinks reference bar items. The quick access toolbar is a persistent of the ribbon. These classes do not
/// know the ribbon control: they talk to the object that implements IFmrRibbonStructureOwner (the Parent of a tab or
/// a context group), so they can be tested and streamed with any TFmxObject that implements it.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, FMX.Types,
  FMR.Ribbon.Types, FMR.Bars.Images, FMR.Bars;

type
  TFmrRibbonTab = class;
  TFmrRibbonGroup = class;
  TFmrRibbonContextGroup = class;
  TFmrRibbonQuickAccessToolbar = class;

  /// <summary>Options of the ribbon that belong to the user layout (saved with FMR.Ribbon.Persistence).</summary>
  TFmrRibbonLayoutOptions = record
    /// <summary>Only the tab row is shown (Ctrl+F1).</summary>
    Minimized: Boolean;
    ShowMode: TFmrRibbonShowMode;
    DisplayMode: TFmrRibbonDisplayMode;
    class function Default: TFmrRibbonLayoutOptions; static;
  end;

  /// <summary>Implemented by the ribbon (and by test doubles). Tabs and context groups are its children; the
  /// structure objects report every change to it. Calls are not made while the structure object or the owner is
  /// loading or destroying.</summary>
  IFmrRibbonStructureOwner = interface
    ['{A4DB8FCD-FB5B-47C0-AB4B-2A39E2F085CA}']
    /// <summary>The object whose children are the tabs and context groups (normally the ribbon itself).</summary>
    function GetStructureObject: TFmxObject;
    /// <summary>Bar manager used to resolve item names (persistence, customization); may be nil.</summary>
    function GetBarManager: TFmrBarManager;
    function GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
    function GetActiveTab: TFmrRibbonTab;
    procedure SetActiveTab(const ATab: TFmrRibbonTab);
    function GetLayoutOptions: TFmrRibbonLayoutOptions;
    procedure SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
    /// <summary>Brackets a batch of structure changes (loading a layout, merging): the owner may postpone its
    /// updates until the outermost EndStructureUpdate. Calls nest.</summary>
    procedure BeginStructureUpdate;
    procedure EndStructureUpdate;
    /// <summary>Tabs, groups or context groups were added, removed, moved or shown/hidden. Treat it as
    /// "invalidate": objects being destroyed (csDestroying) may still be children.</summary>
    procedure StructureChanged(const ASender: TObject);
    /// <summary>A property of a tab, group, context group or the quick access toolbar changed (caption, key tip,
    /// color, glyph...).</summary>
    procedure StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
    /// <summary>A tab, group or context group leaves the structure or is destroyed: drop references to it.</summary>
    procedure StructureObjectRemoving(const AObject: TObject);
    /// <summary>The links of a group or of the quick access toolbar changed (AOwner: the group or the QAT).
    /// </summary>
    procedure LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  end;

  /// <summary>Base of tabs, groups and context groups.</summary>
  TFmrRibbonStructureObject = class(TFmxObject)
  private
    FCaption: string;
    FUserCaption: string;
    FKeyTip: string;
    FVisible: Boolean;
    FMergeOrder: Integer;
    FMergeKind: TFmrMergeKind;
    FIsUserDefined: Boolean;
    FMergedFrom: TFmrRibbonStructureObject;
    procedure SetMergedFrom(const Value: TFmrRibbonStructureObject);
    procedure SetCaption(const Value: string);
    procedure SetUserCaption(const Value: string);
    procedure SetKeyTip(const Value: string);
    procedure SetVisible(const Value: Boolean);
  protected
    /// <summary>The structure owner (ribbon) or nil; nil while it is loading or destroying.</summary>
    function ReadyOwner(out AOwner: IFmrRibbonStructureOwner; const AIgnoreOwnState: Boolean = False): Boolean;
    function FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean; virtual; abstract;
    /// <summary>Tells the owner that this object goes away (called from destructors).</summary>
    procedure NotifyRemoving;
    procedure NotifyChanged(const AChange: TFmrItemChange = TFmrItemChange.Layout);
    procedure NotifyStructure;
    procedure VisibleChanged; virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    /// <summary>UserCaption when set (renamed by the user), otherwise Caption.</summary>
    function DisplayCaption: string;
    /// <summary>The structure owner (ribbon) or nil.</summary>
    function StructureOwner: IFmrRibbonStructureOwner;
    /// <summary>Source object this one was copied from by merging (nil when not merged or when the source is
    /// destroyed).</summary>
    property MergedFrom: TFmrRibbonStructureObject read FMergedFrom write SetMergedFrom;
  published
    property Caption: string read FCaption write SetCaption;
    /// <summary>Created by the user through customization (persisted with its content).</summary>
    property IsUserDefined: Boolean read FIsUserDefined write FIsUserDefined default False;
    /// <summary>Explicit key tip; empty = generated.</summary>
    property KeyTip: string read FKeyTip write SetKeyTip;
    property MergeKind: TFmrMergeKind read FMergeKind write FMergeKind default TFmrMergeKind.Merge;
    /// <summary>Position when merged into another ribbon: inserted before the first target object with a greater
    /// MergeOrder.</summary>
    property MergeOrder: Integer read FMergeOrder write FMergeOrder default 0;
    /// <summary>Caption given by the user (customization); empty = Caption.</summary>
    property UserCaption: string read FUserCaption write SetUserCaption;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  /// <summary>Colored set of contextual tabs ("Picture Tools"), shown only while the context applies.</summary>
  TFmrRibbonContextGroup = class(TFmrRibbonStructureObject)
  private
    FColor: TAlphaColor;
    procedure SetColor(const Value: TAlphaColor);
  protected
    function FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean; override;
    procedure ParentChanged; override;
    procedure VisibleChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Tabs of the owner that belong to this context group.</summary>
    function Tabs: TArray<TFmrRibbonTab>;
    /// <summary>Shows the context group and makes its first visible tab active.</summary>
    procedure Activate;
  published
    property Color: TAlphaColor read FColor write SetColor default TAlphaColors.Null;
    property Visible default False;
  end;

  /// <summary>A ribbon tab; its children are groups.</summary>
  TFmrRibbonTab = class(TFmrRibbonStructureObject)
  private
    FContextGroup: TFmrRibbonContextGroup;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
    procedure SetContextGroup(const Value: TFmrRibbonContextGroup);
    function GetGroupCount: Integer;
    function GetGroup(const AIndex: Integer): TFmrRibbonGroup;
    function GetTabIndex: Integer;
    procedure SetTabIndex(const Value: Integer);
  protected
    function FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ParentChanged; override;
    procedure ChangeChildren; override;
    procedure ChangeOrder; override;
  public
    destructor Destroy; override;
    /// <summary>Creates a group as the last child (owned by the owner of the tab).</summary>
    function AddGroup(const ACaption: string = ''): TFmrRibbonGroup;
    function IndexOfGroup(const AGroup: TFmrRibbonGroup): Integer;
    function FindGroup(const ANameOrCaption: string): TFmrRibbonGroup;
    /// <summary>Visible, and its context group (if any) is visible.</summary>
    function IsShown: Boolean;
    property GroupCount: Integer read GetGroupCount;
    property Groups[const AIndex: Integer]: TFmrRibbonGroup read GetGroup;
    /// <summary>Index among the tabs of the owner (not the child index).</summary>
    property TabIndex: Integer read GetTabIndex write SetTabIndex;
    property Active: Boolean read GetActive write SetActive;
  published
    property ContextGroup: TFmrRibbonContextGroup read FContextGroup write SetContextGroup;
  end;

  /// <summary>A group of a tab: links to items, a caption and an optional dialog launcher.</summary>
  TFmrRibbonGroup = class(TFmrRibbonStructureObject, IFmrItemLinksOwner)
  private
    FItemLinks: TFmrItemLinks;
    FGlyph: TFmrImageSource;
    FCanCollapse: Boolean;
    FReductionPriority: Integer;
    FShowDialogLauncher: Boolean;
    FDialogLauncherKeyTip: string;
    FShowCaption: Boolean;
    FOnDialogLauncherClick: TNotifyEvent;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetGlyph(const Value: TFmrImageSource);
    procedure SetCanCollapse(const Value: Boolean);
    procedure SetReductionPriority(const Value: Integer);
    procedure SetShowDialogLauncher(const Value: Boolean);
    procedure SetDialogLauncherKeyTip(const Value: string);
    procedure SetShowCaption(const Value: Boolean);
    procedure GlyphChanged(Sender: TObject);
    function GetTab: TFmrRibbonTab;
    function GetGroupIndex: Integer;
    procedure SetGroupIndex(const Value: Integer);
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    function FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean; override;
    procedure ParentChanged; override;
    procedure ChangeOrder; override;
    procedure DoDialogLauncherClick; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Called by the ribbon when the dialog launcher is clicked.</summary>
    procedure DialogLauncherClick;
    property Tab: TFmrRibbonTab read GetTab;
    /// <summary>Index among the groups of the tab.</summary>
    property GroupIndex: Integer read GetGroupIndex write SetGroupIndex;
  published
    property CanCollapse: Boolean read FCanCollapse write SetCanCollapse default True;
    property DialogLauncherKeyTip: string read FDialogLauncherKeyTip write SetDialogLauncherKeyTip;
    /// <summary>Image of the collapsed group button and of the group in the quick access toolbar.</summary>
    property Glyph: TFmrImageSource read FGlyph write SetGlyph;
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    /// <summary>Groups with a higher value keep their size longer when the ribbon gets narrow.</summary>
    property ReductionPriority: Integer read FReductionPriority write SetReductionPriority default 0;
    property ShowCaption: Boolean read FShowCaption write SetShowCaption default True;
    property ShowDialogLauncher: Boolean read FShowDialogLauncher write SetShowDialogLauncher default False;
    property OnDialogLauncherClick: TNotifyEvent read FOnDialogLauncherClick write FOnDialogLauncherClick;
  end;

  /// <summary>Quick access toolbar data of a ribbon.</summary>
  TFmrRibbonQuickAccessToolbar = class(TInterfacedPersistent, IFmrItemLinksOwner)
  private
    [Weak] FOwner: TComponent;
    FItemLinks: TFmrItemLinks;
    FPosition: TFmrQATPosition;
    FVisible: Boolean;
    FShowCustomizeButton: Boolean;
    FDestroying: Boolean;
    procedure SetItemLinks(const Value: TFmrItemLinks);
    procedure SetPosition(const Value: TFmrQATPosition);
    procedure SetVisible(const Value: Boolean);
    procedure SetShowCustomizeButton(const Value: Boolean);
    function ReadyOwner(out AOwner: IFmrRibbonStructureOwner): Boolean;
    procedure Changed;
    { IFmrItemLinksOwner }
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  protected
    function GetOwner: TPersistent; override;
  public
    /// <summary>AOwner: the ribbon (implements IFmrRibbonStructureOwner).</summary>
    constructor Create(const AOwner: TComponent);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    /// <summary>Adds a link to AItem unless the toolbar already has one; returns the link.</summary>
    function AddItem(const AItem: TFmrBarItem): TFmrItemLink;
    procedure RemoveItem(const AItem: TFmrBarItem);
    function ContainsItem(const AItem: TFmrBarItem): Boolean;
    property Owner: TComponent read FOwner;
  published
    property ItemLinks: TFmrItemLinks read FItemLinks write SetItemLinks;
    property Position: TFmrQATPosition read FPosition write SetPosition default TFmrQATPosition.AboveRibbon;
    property ShowCustomizeButton: Boolean read FShowCustomizeButton write SetShowCustomizeButton default True;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  /// <summary>Helpers over the structure of an owner (designer drag and drop, customization, merging).</summary>
  TFmrRibbonStructure = class
  public
    class function TabCount(const AOwner: TFmxObject): Integer; static;
    class function Tabs(const AOwner: TFmxObject): TArray<TFmrRibbonTab>; static;
    class function Tab(const AOwner: TFmxObject; const AIndex: Integer): TFmrRibbonTab; static;
    class function ContextGroups(const AOwner: TFmxObject): TArray<TFmrRibbonContextGroup>; static;
    /// <summary>Every group of every tab, in order.</summary>
    class function AllGroups(const AOwner: TFmxObject): TArray<TFmrRibbonGroup>; static;
    /// <summary>Tab whose Name (preferred) or caption matches (case-insensitive).</summary>
    class function FindTab(const AOwner: TFmxObject; const ANameOrCaption: string): TFmrRibbonTab; static;
    class function FindGroup(const AOwner: TFmxObject; const AName: string): TFmrRibbonGroup; static;
    class function FindContextGroup(const AOwner: TFmxObject; const ANameOrCaption: string)
      : TFmrRibbonContextGroup; static;
    /// <summary>Creates a tab (owned by the owner's Owner, like the designer does) inserted at ATabIndex among the
    /// tabs (-1 = last).</summary>
    class function CreateTab(const AOwner: TFmxObject; const ACaption: string;
      const ATabIndex: Integer = -1): TFmrRibbonTab; static;
    class function CreateGroup(const ATab: TFmrRibbonTab; const ACaption: string;
      const AGroupIndex: Integer = -1): TFmrRibbonGroup; static;
    class function CreateContextGroup(const AOwner: TFmxObject; const ACaption: string;
      const AColor: TAlphaColor): TFmrRibbonContextGroup; static;
    /// <summary>Moves a tab to ANewIndex among the tabs of its owner.</summary>
    class procedure MoveTab(const ATab: TFmrRibbonTab; const ANewIndex: Integer); static;
    /// <summary>Moves a group into ATarget (may be its own tab) at AIndex among the groups (-1 = last).</summary>
    class procedure MoveGroup(const AGroup: TFmrRibbonGroup; const ATarget: TFmrRibbonTab;
      const AIndex: Integer = -1); static;
    /// <summary>Moves a link into ATarget (may be its own collection) at AIndex (-1 = last).</summary>
    class procedure MoveLink(const ALink: TFmrItemLink; const ATarget: TFmrItemLinks;
      const AIndex: Integer = -1); static;
    /// <summary>Copies a link (item and every link property) into ATarget.</summary>
    class function CopyLink(const ALink: TFmrItemLink; const ATarget: TFmrItemLinks;
      const AIndex: Integer = -1): TFmrItemLink; static;
    /// <summary>Child index of the owner that corresponds to a tab index (insertion position).</summary>
    class function TabIndexToChildIndex(const AOwner: TFmxObject; const ATabIndex: Integer): Integer; static;
  end;

implementation

uses
  System.Math;

{ TFmrRibbonLayoutOptions }

class function TFmrRibbonLayoutOptions.Default: TFmrRibbonLayoutOptions;
begin
  Result.Minimized := False;
  Result.ShowMode := TFmrRibbonShowMode.TabsAndCommands;
  Result.DisplayMode := TFmrRibbonDisplayMode.Classic;
end;

function IsBusy(const AComponent: TComponent): Boolean; inline;
begin
  Result := (AComponent <> nil) and ([csLoading, csDestroying] * AComponent.ComponentState <> []);
end;

function OwnerOf(const AObject: TFmxObject; out AOwner: IFmrRibbonStructureOwner): Boolean;
begin
  Result := (AObject <> nil) and Supports(AObject, IFmrRibbonStructureOwner, AOwner);
end;

{ TFmrRibbonStructureObject }

constructor TFmrRibbonStructureObject.Create(AOwner: TComponent);
begin
  inherited;
  FVisible := True;
end;

function TFmrRibbonStructureObject.DisplayCaption: string;
begin
  if FUserCaption <> '' then
    Result := FUserCaption
  else
    Result := FCaption;
end;

function TFmrRibbonStructureObject.ReadyOwner(out AOwner: IFmrRibbonStructureOwner;
  const AIgnoreOwnState: Boolean): Boolean;
var
  O: TObject;
begin
  Result := False;
  AOwner := nil;
  if not AIgnoreOwnState and IsBusy(Self) then
    Exit;
  if not FindOwner(AOwner) then
    Exit;
  O := AOwner.GetStructureObject;
  if (O is TComponent) and IsBusy(TComponent(O)) then
  begin
    AOwner := nil;
    Exit;
  end;
  Result := True;
end;

function TFmrRibbonStructureObject.StructureOwner: IFmrRibbonStructureOwner;
begin
  if not FindOwner(Result) then
    Result := nil;
end;

procedure TFmrRibbonStructureObject.NotifyChanged(const AChange: TFmrItemChange);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.StructureObjectChanged(Self, AChange);
end;

procedure TFmrRibbonStructureObject.NotifyStructure;
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.StructureChanged(Self);
end;

procedure TFmrRibbonStructureObject.VisibleChanged;
begin
  NotifyStructure;
end;

procedure TFmrRibbonStructureObject.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FMergedFrom) then
    FMergedFrom := nil;
end;

procedure TFmrRibbonStructureObject.SetMergedFrom(const Value: TFmrRibbonStructureObject);
begin
  if FMergedFrom <> Value then
  begin
    if FMergedFrom <> nil then
      FMergedFrom.RemoveFreeNotification(Self);
    FMergedFrom := Value;
    if FMergedFrom <> nil then
      FMergedFrom.FreeNotification(Self);
  end;
end;

procedure TFmrRibbonStructureObject.NotifyRemoving;
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O, True) then
  begin
    O.StructureObjectRemoving(Self);
    O.StructureChanged(Self);
  end;
end;

procedure TFmrRibbonStructureObject.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    NotifyChanged(TFmrItemChange.Layout);
  end;
end;

procedure TFmrRibbonStructureObject.SetKeyTip(const Value: string);
begin
  if FKeyTip <> Value then
  begin
    FKeyTip := Value;
    NotifyChanged(TFmrItemChange.Paint);
  end;
end;

procedure TFmrRibbonStructureObject.SetUserCaption(const Value: string);
begin
  if FUserCaption <> Value then
  begin
    FUserCaption := Value;
    NotifyChanged(TFmrItemChange.Layout);
  end;
end;

procedure TFmrRibbonStructureObject.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    VisibleChanged;
  end;
end;

{ TFmrRibbonContextGroup }

constructor TFmrRibbonContextGroup.Create(AOwner: TComponent);
begin
  inherited;
  FColor := TAlphaColors.Null;
  Visible := False;
end;

destructor TFmrRibbonContextGroup.Destroy;
begin
  NotifyRemoving;
  inherited;
end;

function TFmrRibbonContextGroup.FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean;
begin
  Result := OwnerOf(Parent, AOwner);
end;

procedure TFmrRibbonContextGroup.ParentChanged;
begin
  inherited;
  NotifyStructure;
end;

procedure TFmrRibbonContextGroup.VisibleChanged;
var
  O: IFmrRibbonStructureOwner;
  Active: TFmrRibbonTab;
begin
  if not FVisible and ReadyOwner(O) then
  begin
    Active := O.GetActiveTab;
    if (Active <> nil) and (Active.ContextGroup = Self) then
      O.SetActiveTab(nil);
  end;
  inherited;
end;

procedure TFmrRibbonContextGroup.SetColor(const Value: TAlphaColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    NotifyChanged(TFmrItemChange.Paint);
  end;
end;

function TFmrRibbonContextGroup.Tabs: TArray<TFmrRibbonTab>;
var
  T: TFmrRibbonTab;
  L: TList<TFmrRibbonTab>;
begin
  L := TList<TFmrRibbonTab>.Create;
  try
    if Parent <> nil then
      for T in TFmrRibbonStructure.Tabs(Parent) do
        if T.ContextGroup = Self then
          L.Add(T);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

procedure TFmrRibbonContextGroup.Activate;
var
  T: TFmrRibbonTab;
begin
  Visible := True;
  for T in Tabs do
    if T.Visible then
    begin
      T.Active := True;
      Break;
    end;
end;

{ TFmrRibbonTab }

destructor TFmrRibbonTab.Destroy;
begin
  ContextGroup := nil;
  NotifyRemoving;
  inherited;
end;

function TFmrRibbonTab.FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean;
begin
  Result := OwnerOf(Parent, AOwner);
end;

procedure TFmrRibbonTab.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FContextGroup) then
  begin
    FContextGroup := nil;
    NotifyStructure;
  end;
end;

procedure TFmrRibbonTab.ParentChanged;
begin
  inherited;
  NotifyStructure;
end;

procedure TFmrRibbonTab.ChangeChildren;
begin
  inherited;
  NotifyStructure;
end;

procedure TFmrRibbonTab.ChangeOrder;
begin
  inherited;
  NotifyStructure;
end;

function TFmrRibbonTab.AddGroup(const ACaption: string): TFmrRibbonGroup;
begin
  Result := TFmrRibbonStructure.CreateGroup(Self, ACaption);
end;

function TFmrRibbonTab.GetActive: Boolean;
var
  O: IFmrRibbonStructureOwner;
begin
  Result := FindOwner(O) and (O.GetActiveTab = Self);
end;

procedure TFmrRibbonTab.SetActive(const Value: Boolean);
var
  O: IFmrRibbonStructureOwner;
begin
  if FindOwner(O) then
  begin
    if Value then
      O.SetActiveTab(Self)
    else if O.GetActiveTab = Self then
      O.SetActiveTab(nil);
  end;
end;

procedure TFmrRibbonTab.SetContextGroup(const Value: TFmrRibbonContextGroup);
begin
  if FContextGroup <> Value then
  begin
    if FContextGroup <> nil then
      FContextGroup.RemoveFreeNotification(Self);
    FContextGroup := Value;
    if FContextGroup <> nil then
      FContextGroup.FreeNotification(Self);
    NotifyStructure;
  end;
end;

function TFmrRibbonTab.GetGroupCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ChildrenCount - 1 do
    if (Children[I] is TFmrRibbonGroup) and not (csDestroying in Children[I].ComponentState) then
      Inc(Result);
end;

function TFmrRibbonTab.GetGroup(const AIndex: Integer): TFmrRibbonGroup;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to ChildrenCount - 1 do
    if (Children[I] is TFmrRibbonGroup) and not (csDestroying in Children[I].ComponentState) then
    begin
      if N = AIndex then
        Exit(TFmrRibbonGroup(Children[I]));
      Inc(N);
    end;
  raise EListError.CreateFmt('Group index out of bounds (%d)', [AIndex]);
end;

function TFmrRibbonTab.IndexOfGroup(const AGroup: TFmrRibbonGroup): Integer;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to ChildrenCount - 1 do
    if (Children[I] is TFmrRibbonGroup) and not (csDestroying in Children[I].ComponentState) then
    begin
      if Children[I] = AGroup then
        Exit(N);
      Inc(N);
    end;
  Result := -1;
end;

function TFmrRibbonTab.FindGroup(const ANameOrCaption: string): TFmrRibbonGroup;
var
  I: Integer;
begin
  for I := 0 to GroupCount - 1 do
    if SameText(Groups[I].Name, ANameOrCaption) then
      Exit(Groups[I]);
  for I := 0 to GroupCount - 1 do
    if SameText(Groups[I].Caption, ANameOrCaption) then
      Exit(Groups[I]);
  Result := nil;
end;

function TFmrRibbonTab.GetTabIndex: Integer;
begin
  if Parent = nil then
    Exit(-1);
  Result := TArray.IndexOf<TFmrRibbonTab>(TFmrRibbonStructure.Tabs(Parent), Self);
end;

procedure TFmrRibbonTab.SetTabIndex(const Value: Integer);
begin
  TFmrRibbonStructure.MoveTab(Self, Value);
end;

function TFmrRibbonTab.IsShown: Boolean;
begin
  Result := Visible and ((FContextGroup = nil) or FContextGroup.Visible);
end;

{ TFmrRibbonGroup }

constructor TFmrRibbonGroup.Create(AOwner: TComponent);
begin
  inherited;
  FCanCollapse := True;
  FShowCaption := True;
  FItemLinks := TFmrItemLinks.Create(Self);
  FGlyph := TFmrImageSource.Create(Self);
  FGlyph.OnChange := GlyphChanged;
end;

destructor TFmrRibbonGroup.Destroy;
begin
  NotifyRemoving;
  FreeAndNil(FItemLinks);
  FreeAndNil(FGlyph);
  inherited;
end;

function TFmrRibbonGroup.FindOwner(out AOwner: IFmrRibbonStructureOwner): Boolean;
begin
  Result := (Parent <> nil) and OwnerOf(Parent.Parent, AOwner);
end;

function TFmrRibbonGroup.GetTab: TFmrRibbonTab;
begin
  if Parent is TFmrRibbonTab then
    Result := TFmrRibbonTab(Parent)
  else
    Result := nil;
end;

function TFmrRibbonGroup.GetGroupIndex: Integer;
begin
  if Tab <> nil then
    Result := Tab.IndexOfGroup(Self)
  else
    Result := -1;
end;

procedure TFmrRibbonGroup.SetGroupIndex(const Value: Integer);
begin
  if Tab <> nil then
    TFmrRibbonStructure.MoveGroup(Self, Tab, Value);
end;

procedure TFmrRibbonGroup.ParentChanged;
begin
  inherited;
  NotifyStructure;
end;

procedure TFmrRibbonGroup.ChangeOrder;
begin
  inherited;
  NotifyStructure;
end;

procedure TFmrRibbonGroup.DialogLauncherClick;
begin
  DoDialogLauncherClick;
end;

procedure TFmrRibbonGroup.DoDialogLauncherClick;
begin
  if Assigned(FOnDialogLauncherClick) then
    FOnDialogLauncherClick(Self);
end;

procedure TFmrRibbonGroup.GlyphChanged(Sender: TObject);
begin
  NotifyChanged(TFmrItemChange.Paint);
end;

procedure TFmrRibbonGroup.LinksChanged(const ALinks: TFmrItemLinks);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.LinksChanged(Self, ALinks);
end;

procedure TFmrRibbonGroup.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.LinkItemChanged(ALink, AChange);
end;

procedure TFmrRibbonGroup.LinkRemoving(const ALink: TFmrItemLink);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.LinkRemoving(ALink);
end;

procedure TFmrRibbonGroup.SetCanCollapse(const Value: Boolean);
begin
  if FCanCollapse <> Value then
  begin
    FCanCollapse := Value;
    NotifyChanged(TFmrItemChange.Layout);
  end;
end;

procedure TFmrRibbonGroup.SetDialogLauncherKeyTip(const Value: string);
begin
  if FDialogLauncherKeyTip <> Value then
  begin
    FDialogLauncherKeyTip := Value;
    NotifyChanged(TFmrItemChange.Paint);
  end;
end;

procedure TFmrRibbonGroup.SetGlyph(const Value: TFmrImageSource);
begin
  FGlyph.Assign(Value);
end;

procedure TFmrRibbonGroup.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrRibbonGroup.SetReductionPriority(const Value: Integer);
begin
  if FReductionPriority <> Value then
  begin
    FReductionPriority := Value;
    NotifyChanged(TFmrItemChange.Layout);
  end;
end;

procedure TFmrRibbonGroup.SetShowCaption(const Value: Boolean);
begin
  if FShowCaption <> Value then
  begin
    FShowCaption := Value;
    NotifyChanged(TFmrItemChange.Layout);
  end;
end;

procedure TFmrRibbonGroup.SetShowDialogLauncher(const Value: Boolean);
begin
  if FShowDialogLauncher <> Value then
  begin
    FShowDialogLauncher := Value;
    NotifyChanged(TFmrItemChange.Layout);
  end;
end;

{ TFmrRibbonQuickAccessToolbar }

constructor TFmrRibbonQuickAccessToolbar.Create(const AOwner: TComponent);
begin
  inherited Create;
  FOwner := AOwner;
  FVisible := True;
  FShowCustomizeButton := True;
  FItemLinks := TFmrItemLinks.Create(Self);
end;

destructor TFmrRibbonQuickAccessToolbar.Destroy;
begin
  FDestroying := True;
  FreeAndNil(FItemLinks);
  inherited;
end;

function TFmrRibbonQuickAccessToolbar.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

procedure TFmrRibbonQuickAccessToolbar.Assign(Source: TPersistent);
var
  S: TFmrRibbonQuickAccessToolbar;
begin
  if Source is TFmrRibbonQuickAccessToolbar then
  begin
    S := TFmrRibbonQuickAccessToolbar(Source);
    FPosition := S.FPosition;
    FVisible := S.FVisible;
    FShowCustomizeButton := S.FShowCustomizeButton;
    FItemLinks.Assign(S.FItemLinks);
    Changed;
  end
  else
    inherited;
end;

function TFmrRibbonQuickAccessToolbar.ReadyOwner(out AOwner: IFmrRibbonStructureOwner): Boolean;
begin
  Result := not FDestroying and (FOwner <> nil) and not IsBusy(FOwner) and
    Supports(FOwner, IFmrRibbonStructureOwner, AOwner);
end;

procedure TFmrRibbonQuickAccessToolbar.Changed;
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.StructureObjectChanged(Self, TFmrItemChange.Layout);
end;

function TFmrRibbonQuickAccessToolbar.AddItem(const AItem: TFmrBarItem): TFmrItemLink;
begin
  Result := FItemLinks.FindByItem(AItem);
  if (Result = nil) and (AItem <> nil) then
    Result := FItemLinks.AddItem(AItem);
end;

function TFmrRibbonQuickAccessToolbar.ContainsItem(const AItem: TFmrBarItem): Boolean;
begin
  Result := FItemLinks.ContainsItem(AItem);
end;

procedure TFmrRibbonQuickAccessToolbar.RemoveItem(const AItem: TFmrBarItem);
begin
  FItemLinks.RemoveItem(AItem);
end;

procedure TFmrRibbonQuickAccessToolbar.LinksChanged(const ALinks: TFmrItemLinks);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.LinksChanged(Self, ALinks);
end;

procedure TFmrRibbonQuickAccessToolbar.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.LinkItemChanged(ALink, AChange);
end;

procedure TFmrRibbonQuickAccessToolbar.LinkRemoving(const ALink: TFmrItemLink);
var
  O: IFmrRibbonStructureOwner;
begin
  if ReadyOwner(O) then
    O.LinkRemoving(ALink);
end;

procedure TFmrRibbonQuickAccessToolbar.SetItemLinks(const Value: TFmrItemLinks);
begin
  FItemLinks.Assign(Value);
end;

procedure TFmrRibbonQuickAccessToolbar.SetPosition(const Value: TFmrQATPosition);
begin
  if FPosition <> Value then
  begin
    FPosition := Value;
    Changed;
  end;
end;

procedure TFmrRibbonQuickAccessToolbar.SetShowCustomizeButton(const Value: Boolean);
begin
  if FShowCustomizeButton <> Value then
  begin
    FShowCustomizeButton := Value;
    Changed;
  end;
end;

procedure TFmrRibbonQuickAccessToolbar.SetVisible(const Value: Boolean);
begin
  if FVisible <> Value then
  begin
    FVisible := Value;
    Changed;
  end;
end;

{ TFmrRibbonStructure }

class function TFmrRibbonStructure.Tabs(const AOwner: TFmxObject): TArray<TFmrRibbonTab>;
var
  I, N: Integer;
begin
  Result := nil;
  if AOwner = nil then
    Exit;
  SetLength(Result, AOwner.ChildrenCount);
  N := 0;
  for I := 0 to AOwner.ChildrenCount - 1 do
    if (AOwner.Children[I] is TFmrRibbonTab) and not (csDestroying in AOwner.Children[I].ComponentState) then
    begin
      Result[N] := TFmrRibbonTab(AOwner.Children[I]);
      Inc(N);
    end;
  SetLength(Result, N);
end;

class function TFmrRibbonStructure.TabCount(const AOwner: TFmxObject): Integer;
begin
  Result := Length(Tabs(AOwner));
end;

class function TFmrRibbonStructure.Tab(const AOwner: TFmxObject; const AIndex: Integer): TFmrRibbonTab;
var
  A: TArray<TFmrRibbonTab>;
begin
  A := Tabs(AOwner);
  if (AIndex >= 0) and (AIndex < Length(A)) then
    Result := A[AIndex]
  else
    Result := nil;
end;

class function TFmrRibbonStructure.ContextGroups(const AOwner: TFmxObject): TArray<TFmrRibbonContextGroup>;
var
  I: Integer;
begin
  Result := nil;
  if AOwner <> nil then
    for I := 0 to AOwner.ChildrenCount - 1 do
      if (AOwner.Children[I] is TFmrRibbonContextGroup) and
        not (csDestroying in AOwner.Children[I].ComponentState) then
        Result := Result + [TFmrRibbonContextGroup(AOwner.Children[I])];
end;

class function TFmrRibbonStructure.AllGroups(const AOwner: TFmxObject): TArray<TFmrRibbonGroup>;
var
  T: TFmrRibbonTab;
  I: Integer;
begin
  Result := nil;
  for T in Tabs(AOwner) do
    for I := 0 to T.GroupCount - 1 do
      Result := Result + [T.Groups[I]];
end;

class function TFmrRibbonStructure.FindTab(const AOwner: TFmxObject; const ANameOrCaption: string): TFmrRibbonTab;
var
  T: TFmrRibbonTab;
begin
  if ANameOrCaption = '' then
    Exit(nil);
  for T in Tabs(AOwner) do
    if SameText(T.Name, ANameOrCaption) then
      Exit(T);
  for T in Tabs(AOwner) do
    if SameText(T.Caption, ANameOrCaption) then
      Exit(T);
  Result := nil;
end;

class function TFmrRibbonStructure.FindGroup(const AOwner: TFmxObject; const AName: string): TFmrRibbonGroup;
var
  G: TFmrRibbonGroup;
begin
  if AName <> '' then
    for G in AllGroups(AOwner) do
      if SameText(G.Name, AName) then
        Exit(G);
  Result := nil;
end;

class function TFmrRibbonStructure.FindContextGroup(const AOwner: TFmxObject;
  const ANameOrCaption: string): TFmrRibbonContextGroup;
var
  C: TFmrRibbonContextGroup;
begin
  if ANameOrCaption = '' then
    Exit(nil);
  for C in ContextGroups(AOwner) do
    if SameText(C.Name, ANameOrCaption) then
      Exit(C);
  for C in ContextGroups(AOwner) do
    if SameText(C.Caption, ANameOrCaption) then
      Exit(C);
  Result := nil;
end;

class function TFmrRibbonStructure.TabIndexToChildIndex(const AOwner: TFmxObject; const ATabIndex: Integer): Integer;
var
  A: TArray<TFmrRibbonTab>;
begin
  A := Tabs(AOwner);
  if (ATabIndex < 0) or (ATabIndex >= Length(A)) then
  begin
    if Length(A) = 0 then
      Result := AOwner.ChildrenCount
    else
      Result := A[High(A)].Index + 1;
  end
  else
    Result := A[ATabIndex].Index;
end;

class function TFmrRibbonStructure.CreateTab(const AOwner: TFmxObject; const ACaption: string;
  const ATabIndex: Integer): TFmrRibbonTab;
var
  ChildIndex: Integer;
begin
  Result := TFmrRibbonTab.Create(AOwner.Owner);
  try
    Result.Caption := ACaption;
    ChildIndex := TabIndexToChildIndex(AOwner, ATabIndex);
    if ChildIndex >= AOwner.ChildrenCount then
      AOwner.AddObject(Result)
    else
      AOwner.InsertObject(ChildIndex, Result);
  except
    Result.Free;
    raise;
  end;
end;

class function TFmrRibbonStructure.CreateGroup(const ATab: TFmrRibbonTab; const ACaption: string;
  const AGroupIndex: Integer): TFmrRibbonGroup;
begin
  Result := TFmrRibbonGroup.Create(ATab.Owner);
  try
    Result.Caption := ACaption;
    if (AGroupIndex < 0) or (AGroupIndex >= ATab.GroupCount) then
      ATab.AddObject(Result)
    else
      ATab.InsertObject(ATab.Groups[AGroupIndex].Index, Result);
  except
    Result.Free;
    raise;
  end;
end;

class function TFmrRibbonStructure.CreateContextGroup(const AOwner: TFmxObject; const ACaption: string;
  const AColor: TAlphaColor): TFmrRibbonContextGroup;
begin
  Result := TFmrRibbonContextGroup.Create(AOwner.Owner);
  try
    Result.Caption := ACaption;
    Result.Color := AColor;
    AOwner.AddObject(Result);
  except
    Result.Free;
    raise;
  end;
end;

class procedure TFmrRibbonStructure.MoveTab(const ATab: TFmrRibbonTab; const ANewIndex: Integer);
var
  A: TArray<TFmrRibbonTab>;
  Target: Integer;
begin
  if (ATab = nil) or (ATab.Parent = nil) then
    Exit;
  A := Tabs(ATab.Parent);
  Target := EnsureRange(ANewIndex, 0, High(A));
  if A[Target] = ATab then
    Exit;
  ATab.Index := A[Target].Index;
end;

class procedure TFmrRibbonStructure.MoveGroup(const AGroup: TFmrRibbonGroup; const ATarget: TFmrRibbonTab;
  const AIndex: Integer);
var
  Count: Integer;
begin
  if (AGroup = nil) or (ATarget = nil) then
    Exit;
  if AGroup.Parent <> ATarget then
  begin
    Count := ATarget.GroupCount;
    if (AIndex < 0) or (AIndex >= Count) then
      ATarget.AddObject(AGroup)
    else
      ATarget.InsertObject(ATarget.Groups[AIndex].Index, AGroup);
  end
  else
  begin
    Count := ATarget.GroupCount;
    if (AIndex < 0) or (AIndex >= Count) then
      AGroup.Index := ATarget.Groups[Count - 1].Index
    else if ATarget.Groups[AIndex] <> AGroup then
      AGroup.Index := ATarget.Groups[AIndex].Index;
  end;
end;

class procedure TFmrRibbonStructure.MoveLink(const ALink: TFmrItemLink; const ATarget: TFmrItemLinks;
  const AIndex: Integer);
begin
  if (ALink <> nil) and (ATarget <> nil) then
  begin
    ALink.MoveTo(ATarget, AIndex);
    if (AIndex < 0) and (ALink.Index <> ATarget.Count - 1) then
      ALink.Index := ATarget.Count - 1;
  end;
end;

class function TFmrRibbonStructure.CopyLink(const ALink: TFmrItemLink; const ATarget: TFmrItemLinks;
  const AIndex: Integer): TFmrItemLink;
begin
  ATarget.BeginUpdate;
  try
    if (AIndex < 0) or (AIndex >= ATarget.Count) then
      Result := ATarget.Add
    else
      Result := ATarget.Insert(AIndex);
    Result.Assign(ALink);
  finally
    ATarget.EndUpdate;
  end;
end;

initialization
  RegisterFmxClasses([TFmrRibbonTab, TFmrRibbonGroup, TFmrRibbonContextGroup]);

end.
