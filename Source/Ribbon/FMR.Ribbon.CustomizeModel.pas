{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Customization session (model of the customize form)  }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.CustomizeModel;

/// The data side of "Customize the Ribbon" / "Quick Access Toolbar" (no UI, testable with any
/// IFmrRibbonStructureOwner). A session copies the structure of the ribbon into a shadow owner: real TFmrRibbonTab,
/// TFmrRibbonGroup and TFmrRibbonContextGroup objects with the same names, owned by a private root component, and
/// a shadow quick access toolbar. The form edits the shadow with the structure helpers of FMR.Ribbon.Structure;
/// import, export and "reset all" are the JSON persistence of FMR.Ribbon.Persistence applied to the shadow. Cancel
/// simply frees the session; Apply (OK) transfers the shadow to the ribbon: new user-defined tabs and groups are
/// created, the order, visibility and user captions of every tab and group are copied, user-defined objects that
/// were removed are freed, the links of user-defined groups and of the quick access toolbar are replaced when they
/// differ.
///
/// Rules: commands can be added only to user-defined (custom) groups; commands of designed groups cannot be
/// removed or reordered; designed tabs and groups are hidden (unchecked), not deleted; a custom tab can be removed
/// when it contains only custom groups.

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON, FMX.Types, FMR.Ribbon.Types,
  FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure, FMR.Ribbon.Persistence, FMR.Ribbon.Strings;

type
  /// <summary>Kind of the source of the "Choose commands from" list.</summary>
  TFmrCommandSourceKind = (AllCommands, NotInRibbon, Tab, Category);

  /// <summary>One entry of "Choose commands from".</summary>
  TFmrCommandSource = record
    Kind: TFmrCommandSourceKind;
    /// <summary>Kind = Tab: a tab of the session (shadow tab).</summary>
    Tab: TFmrRibbonTab;
    /// <summary>Kind = Category: the category of the bar manager.</summary>
    Category: string;
    /// <summary>Text shown in the list of sources.</summary>
    Caption: string;
    class function Create(const AKind: TFmrCommandSourceKind; const ACaption: string;
      const ATab: TFmrRibbonTab = nil; const ACategory: string = ''): TFmrCommandSource; static;
  end;

  /// <summary>Owner of the shadow structure of a session (tabs and context groups are its children).</summary>
  TFmrCustomizationShadow = class(TFmxObject, IFmrRibbonStructureOwner)
  private
    FBarManager: TFmrBarManager;
    FQAT: TFmrRibbonQuickAccessToolbar;
    FActiveTab: TFmrRibbonTab;
    FOptions: TFmrRibbonLayoutOptions;
    FUpdateCount: Integer;
    FOnRemoving: TProc<TObject>;
  protected
    { IFmrRibbonStructureOwner }
    function GetStructureObject: TFmxObject;
    function GetBarManager: TFmrBarManager;
    function GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
    function GetActiveTab: TFmrRibbonTab;
    procedure SetActiveTab(const ATab: TFmrRibbonTab);
    function GetLayoutOptions: TFmrRibbonLayoutOptions;
    procedure SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
    procedure BeginStructureUpdate;
    procedure EndStructureUpdate;
    procedure StructureChanged(const ASender: TObject);
    procedure StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
    procedure StructureObjectRemoving(const AObject: TObject);
    procedure LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property QuickAccessToolbar: TFmrRibbonQuickAccessToolbar read FQAT;
  end;

  /// <summary>Editing session of the customization form. Objects passed to the edit methods are objects of the
  /// session: shadow tabs, shadow groups and links of shadow groups (or of the shadow quick access toolbar).
  /// </summary>
  TFmrRibbonCustomization = class
  private
    FTarget: IFmrRibbonStructureOwner;
    FRoot: TComponent;
    FShadow: TFmrCustomizationShadow;
    FOriginals: TDictionary<TFmrRibbonStructureObject, TFmrRibbonStructureObject>;
    FDefaultLayout: string;
    FModified: Boolean;
    procedure BuildShadow;
    procedure ShadowRemoving(AObject: TObject);
    function TargetObject: TFmxObject;
    function UniqueName(const ABase: string): string;
    function IsNameFree(const AName: string): Boolean;
    function GroupOfLink(const ALink: TFmrItemLink): TFmrRibbonGroup;
    function TabOf(const AObject: TObject): TFmrRibbonTab;
    function DefaultJSON: TJSONObject;
    procedure Changed;
    function GetQATBelow: Boolean;
    procedure SetQATBelow(const Value: Boolean);
    function GetQATVisible: Boolean;
    procedure SetQATVisible(const Value: Boolean);
  public
    /// <summary>ADefaultLayout: the layout JSON of the ribbon as designed (TFmrRibbon.DefaultLayout), used by the
    /// reset commands; empty = reset removes user-defined content and shows every designed tab and group.</summary>
    constructor Create(const ATarget: IFmrRibbonStructureOwner; const ADefaultLayout: string = '');
    destructor Destroy; override;

    { the shadow structure }
    function Tabs: TArray<TFmrRibbonTab>;
    function Groups(const ATab: TFmrRibbonTab): TArray<TFmrRibbonGroup>;
    function QuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
    /// <summary>The ribbon object a shadow tab or group was copied from (nil for objects created in the session).
    /// </summary>
    function OriginalOf(const AObject: TFmrRibbonStructureObject): TFmrRibbonStructureObject;
    /// <summary>The shadow copy of a tab or group of the ribbon (nil when none).</summary>
    function ShadowOf(const AOriginal: TFmrRibbonStructureObject): TFmrRibbonStructureObject;
    /// <summary>Tab of a contextual tab group ("Tool Tabs").</summary>
    class function IsToolTab(const ATab: TFmrRibbonTab): Boolean; static;
    /// <summary>Caption of a tab, group or link as shown in the tree.</summary>
    function CaptionOf(const AObject: TObject): string;

    { commands }
    /// <summary>Items that can be put into custom groups and the quick access toolbar: named, visible, with a
    /// caption, not separators or labels (items are stored by name in a layout).</summary>
    class function IsCustomizableItem(const AItem: TFmrBarItem): Boolean; static;
    /// <summary>All commands, commands not in the ribbon, one entry per tab and one per category.</summary>
    function CommandSources: TArray<TFmrCommandSource>;
    /// <summary>Commands of a source whose caption contains AFilter (case-insensitive); sorted by caption except
    /// for tabs (ribbon order).</summary>
    function Commands(const ASource: TFmrCommandSource; const AFilter: string = ''): TArray<TFmrBarItem>;
    /// <summary>True when the item is linked in a group of the session.</summary>
    function IsInRibbon(const AItem: TFmrBarItem): Boolean;

    { editing the ribbon tree }
    /// <summary>ATarget: a custom group or a link of a custom group (the command is inserted after it).</summary>
    function CanAddCommand(const AItem: TFmrBarItem; const ATarget: TObject): Boolean;
    function AddCommand(const AItem: TFmrBarItem; const ATarget: TObject): TFmrItemLink;
    function CanRemove(const AObject: TObject): Boolean;
    procedure Remove(const AObject: TObject);
    /// <summary>Tabs move among the tabs, groups among the groups of their tab and into the neighbouring tab at
    /// the ends, links of custom groups inside their group.</summary>
    function CanMove(const AObject: TObject; const ADelta: Integer): Boolean;
    procedure Move(const AObject: TObject; const ADelta: Integer);
    /// <summary>A custom tab with one custom group after the tab of AAfter (at the end when nil); returns the
    /// group.</summary>
    function NewTab(const AAfter: TObject): TFmrRibbonGroup;
    /// <summary>A custom group in the tab of AWhere, after the group of AWhere (or last).</summary>
    function NewGroup(const AWhere: TObject): TFmrRibbonGroup;
    function CanRename(const AObject: TObject): Boolean;
    /// <summary>Designed objects get a UserCaption (empty or equal to the designed caption clears it); custom
    /// objects get a new Caption; links of custom groups a UserCaption.</summary>
    procedure Rename(const AObject: TObject; const ACaption: string);
    procedure SetGroupGlyph(const AGroup: TFmrRibbonGroup; const AGlyphCode: Cardinal);
    function IsVisible(const AObject: TObject): Boolean;
    procedure SetVisible(const AObject: TObject; const AVisible: Boolean);
    function CanResetTab(const ATab: TFmrRibbonTab): Boolean;
    /// <summary>Restores a designed tab: visible, no user caption, its designed groups in their designed order,
    /// no custom groups.</summary>
    procedure ResetTab(const ATab: TFmrRibbonTab);
    /// <summary>The default layout for everything (tabs, groups, quick access toolbar).</summary>
    procedure ResetAll;
    procedure ResetQAT;

    { quick access toolbar }
    function CanAddToQAT(const AItem: TFmrBarItem): Boolean;
    function AddToQAT(const AItem: TFmrBarItem; const AIndex: Integer = -1): TFmrItemLink;
    procedure RemoveFromQAT(const AIndex: Integer);
    function CanMoveInQAT(const AIndex, ADelta: Integer): Boolean;
    procedure MoveInQAT(const AIndex, ADelta: Integer);
    /// <summary>A separator before the link (BeginGroup).</summary>
    procedure SetQATSeparator(const AIndex: Integer; const AValue: Boolean);
    property QATBelow: Boolean read GetQATBelow write SetQATBelow;
    property QATVisible: Boolean read GetQATVisible write SetQATVisible;

    { files }
    function SaveToString: string;
    /// <summary>Imports a layout into the session; raises EFmrLayoutError for files that are not layouts.</summary>
    procedure LoadFromString(const AText: string);
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);

    /// <summary>Transfers the session to the ribbon (one structure update).</summary>
    procedure Apply;
    property Modified: Boolean read FModified;
    property DefaultLayout: string read FDefaultLayout write FDefaultLayout;
    property Shadow: TFmrCustomizationShadow read FShadow;
  end;

/// <summary>Text of a caption without accelerator marks.</summary>
function FmrCustStripAmp(const ACaption: string): string;

implementation

uses
  System.Math, System.IOUtils, System.Generics.Defaults;

function FmrCustStripAmp(const ACaption: string): string;
var
  I: Integer;
begin
  if not ACaption.Contains('&') then
    Exit(ACaption);
  Result := '';
  I := 1;
  while I <= Length(ACaption) do
  begin
    if ACaption[I] = '&' then
    begin
      if (I < Length(ACaption)) and (ACaption[I + 1] = '&') then
      begin
        Result := Result + '&';
        Inc(I);
      end;
    end
    else
      Result := Result + ACaption[I];
    Inc(I);
  end;
end;

function JArray(const AObj: TJSONObject; const AKey: string): TJSONArray;
var
  V: TJSONValue;
begin
  Result := nil;
  if AObj = nil then
    Exit;
  V := AObj.GetValue(AKey);
  if V is TJSONArray then
    Result := TJSONArray(V);
end;

function SameLinks(const A, B: TFmrItemLinks): Boolean;
var
  I: Integer;
  X, Y: TFmrItemLink;
begin
  if A.Count <> B.Count then
    Exit(False);
  for I := 0 to A.Count - 1 do
  begin
    X := A[I];
    Y := B[I];
    if (X.Item <> Y.Item) or (X.BeginGroup <> Y.BeginGroup) or (X.Visible <> Y.Visible) or
      (X.ViewLevels <> Y.ViewLevels) or (X.ButtonGroup <> Y.ButtonGroup) or (X.UserCaption <> Y.UserCaption) or
      (X.KeyTip <> Y.KeyTip) or (X.SimplifiedVisibility <> Y.SimplifiedVisibility) then
      Exit(False);
  end;
  Result := True;
end;

{ TFmrCommandSource }

class function TFmrCommandSource.Create(const AKind: TFmrCommandSourceKind; const ACaption: string;
  const ATab: TFmrRibbonTab; const ACategory: string): TFmrCommandSource;
begin
  Result.Kind := AKind;
  Result.Caption := ACaption;
  Result.Tab := ATab;
  Result.Category := ACategory;
end;

{ TFmrCustomizationShadow }

constructor TFmrCustomizationShadow.Create(AOwner: TComponent);
begin
  inherited;
  FQAT := TFmrRibbonQuickAccessToolbar.Create(Self);
  FOptions := TFmrRibbonLayoutOptions.Default;
end;

destructor TFmrCustomizationShadow.Destroy;
begin
  FOnRemoving := nil;
  FreeAndNil(FQAT);
  inherited;
end;

function TFmrCustomizationShadow.GetStructureObject: TFmxObject;
begin
  Result := Self;
end;

function TFmrCustomizationShadow.GetBarManager: TFmrBarManager;
begin
  Result := FBarManager;
end;

function TFmrCustomizationShadow.GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
begin
  Result := FQAT;
end;

function TFmrCustomizationShadow.GetActiveTab: TFmrRibbonTab;
begin
  Result := FActiveTab;
end;

procedure TFmrCustomizationShadow.SetActiveTab(const ATab: TFmrRibbonTab);
begin
  FActiveTab := ATab;
end;

function TFmrCustomizationShadow.GetLayoutOptions: TFmrRibbonLayoutOptions;
begin
  Result := FOptions;
end;

procedure TFmrCustomizationShadow.SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
begin
  FOptions := AOptions;
end;

procedure TFmrCustomizationShadow.BeginStructureUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TFmrCustomizationShadow.EndStructureUpdate;
begin
  if FUpdateCount > 0 then
    Dec(FUpdateCount);
end;

procedure TFmrCustomizationShadow.StructureChanged(const ASender: TObject);
begin
end;

procedure TFmrCustomizationShadow.StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
begin
end;

procedure TFmrCustomizationShadow.StructureObjectRemoving(const AObject: TObject);
begin
  if AObject = FActiveTab then
    FActiveTab := nil;
  if Assigned(FOnRemoving) then
    FOnRemoving(AObject);
end;

procedure TFmrCustomizationShadow.LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
begin
end;

procedure TFmrCustomizationShadow.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
end;

procedure TFmrCustomizationShadow.LinkRemoving(const ALink: TFmrItemLink);
begin
end;

{ TFmrRibbonCustomization }

constructor TFmrRibbonCustomization.Create(const ATarget: IFmrRibbonStructureOwner; const ADefaultLayout: string);
begin
  inherited Create;
  FTarget := ATarget;
  FDefaultLayout := ADefaultLayout;
  FOriginals := TDictionary<TFmrRibbonStructureObject, TFmrRibbonStructureObject>.Create;
  FRoot := TComponent.Create(nil);
  FShadow := TFmrCustomizationShadow.Create(FRoot);
  FShadow.FBarManager := FTarget.GetBarManager;
  FShadow.FOnRemoving := ShadowRemoving;
  BuildShadow;
end;

destructor TFmrRibbonCustomization.Destroy;
begin
  if FShadow <> nil then
    FShadow.FOnRemoving := nil;
  FreeAndNil(FShadow);
  FreeAndNil(FRoot);
  FreeAndNil(FOriginals);
  FTarget := nil;
  inherited;
end;

function TFmrRibbonCustomization.TargetObject: TFmxObject;
begin
  Result := FTarget.GetStructureObject;
end;

procedure TFmrRibbonCustomization.Changed;
begin
  FModified := True;
end;

procedure TFmrRibbonCustomization.ShadowRemoving(AObject: TObject);
begin
  if (FOriginals <> nil) and (AObject is TFmrRibbonStructureObject) then
    FOriginals.Remove(TFmrRibbonStructureObject(AObject));
end;

function TFmrRibbonCustomization.IsNameFree(const AName: string): Boolean;
var
  FormRoot: TComponent;
begin
  Result := IsValidIdent(AName) and (FRoot.FindComponent(AName) = nil);
  if Result then
  begin
    FormRoot := TargetObject.Owner;
    if (FormRoot <> nil) and (FormRoot.FindComponent(AName) <> nil) then
      Result := False;
  end;
end;

function TFmrRibbonCustomization.UniqueName(const ABase: string): string;
var
  N: Integer;
begin
  N := 1;
  repeat
    Result := ABase + IntToStr(N);
    Inc(N);
  until IsNameFree(Result);
end;

procedure TFmrRibbonCustomization.BuildShadow;
var
  Ctx, SC: TFmrRibbonContextGroup;
  CtxMap: TDictionary<TFmrRibbonContextGroup, TFmrRibbonContextGroup>;
  T, ST: TFmrRibbonTab;
  G, SG: TFmrRibbonGroup;
  I: Integer;
  Q: TFmrRibbonQuickAccessToolbar;

  procedure CopyName(const ASource, ADest: TComponent);
  begin
    if (ASource.Name <> '') and IsValidIdent(ASource.Name) and (FRoot.FindComponent(ASource.Name) = nil) then
      ADest.Name := ASource.Name;
  end;

  procedure CopyBase(const ASource, ADest: TFmrRibbonStructureObject);
  begin
    CopyName(ASource, ADest);
    ADest.Caption := ASource.Caption;
    ADest.UserCaption := ASource.UserCaption;
    ADest.KeyTip := ASource.KeyTip;
    ADest.Visible := ASource.Visible;
    ADest.IsUserDefined := ASource.IsUserDefined;
    ADest.MergeKind := ASource.MergeKind;
    ADest.MergeOrder := ASource.MergeOrder;
  end;

begin
  CtxMap := TDictionary<TFmrRibbonContextGroup, TFmrRibbonContextGroup>.Create;
  try
    for Ctx in TFmrRibbonStructure.ContextGroups(TargetObject) do
    begin
      SC := TFmrRibbonContextGroup.Create(FRoot);
      CopyBase(Ctx, SC);
      SC.Color := Ctx.Color;
      FShadow.AddObject(SC);
      CtxMap.Add(Ctx, SC);
      FOriginals.Add(SC, Ctx);
    end;
    for T in TFmrRibbonStructure.Tabs(TargetObject) do
    begin
      ST := TFmrRibbonTab.Create(FRoot);
      CopyBase(T, ST);
      if (T.ContextGroup <> nil) and CtxMap.TryGetValue(T.ContextGroup, SC) then
        ST.ContextGroup := SC;
      FShadow.AddObject(ST);
      FOriginals.Add(ST, T);
      for I := 0 to T.GroupCount - 1 do
      begin
        G := T.Groups[I];
        SG := TFmrRibbonGroup.Create(FRoot);
        CopyBase(G, SG);
        SG.Glyph := G.Glyph;
        SG.ShowDialogLauncher := G.ShowDialogLauncher;
        SG.ShowCaption := G.ShowCaption;
        SG.ItemLinks := G.ItemLinks;
        ST.AddObject(SG);
        FOriginals.Add(SG, G);
      end;
    end;
  finally
    CtxMap.Free;
  end;
  Q := FTarget.GetQuickAccessToolbar;
  if Q <> nil then
    FShadow.FQAT.Assign(Q);
  FShadow.FOptions := FTarget.GetLayoutOptions;
end;

function TFmrRibbonCustomization.Tabs: TArray<TFmrRibbonTab>;
begin
  Result := TFmrRibbonStructure.Tabs(FShadow);
end;

function TFmrRibbonCustomization.Groups(const ATab: TFmrRibbonTab): TArray<TFmrRibbonGroup>;
var
  I: Integer;
begin
  Result := nil;
  if ATab = nil then
    Exit;
  SetLength(Result, ATab.GroupCount);
  for I := 0 to ATab.GroupCount - 1 do
    Result[I] := ATab.Groups[I];
end;

function TFmrRibbonCustomization.QuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
begin
  Result := FShadow.FQAT;
end;

function TFmrRibbonCustomization.OriginalOf(const AObject: TFmrRibbonStructureObject): TFmrRibbonStructureObject;
begin
  if (AObject = nil) or not FOriginals.TryGetValue(AObject, Result) then
    Result := nil;
end;

function TFmrRibbonCustomization.ShadowOf(const AOriginal: TFmrRibbonStructureObject): TFmrRibbonStructureObject;
var
  P: TPair<TFmrRibbonStructureObject, TFmrRibbonStructureObject>;
begin
  for P in FOriginals do
    if P.Value = AOriginal then
      Exit(P.Key);
  Result := nil;
end;

class function TFmrRibbonCustomization.IsToolTab(const ATab: TFmrRibbonTab): Boolean;
begin
  Result := (ATab <> nil) and (ATab.ContextGroup <> nil);
end;

function TFmrRibbonCustomization.CaptionOf(const AObject: TObject): string;
begin
  if AObject is TFmrRibbonStructureObject then
    Result := FmrCustStripAmp(TFmrRibbonStructureObject(AObject).DisplayCaption)
  else if AObject is TFmrItemLink then
    Result := FmrCustStripAmp(TFmrItemLink(AObject).Caption)
  else if AObject is TFmrBarItem then
    Result := FmrCustStripAmp(TFmrBarItem(AObject).Caption)
  else
    Result := '';
end;

function TFmrRibbonCustomization.GroupOfLink(const ALink: TFmrItemLink): TFmrRibbonGroup;
begin
  if (ALink <> nil) and (ALink.LinksOwner is TFmrRibbonGroup) then
    Result := TFmrRibbonGroup(ALink.LinksOwner)
  else
    Result := nil;
end;

function TFmrRibbonCustomization.TabOf(const AObject: TObject): TFmrRibbonTab;
begin
  Result := nil;
  if AObject is TFmrRibbonTab then
    Result := TFmrRibbonTab(AObject)
  else if AObject is TFmrRibbonGroup then
    Result := TFmrRibbonGroup(AObject).Tab
  else if AObject is TFmrItemLink then
  begin
    if GroupOfLink(TFmrItemLink(AObject)) <> nil then
      Result := GroupOfLink(TFmrItemLink(AObject)).Tab;
  end;
end;

{ commands }

class function TFmrRibbonCustomization.IsCustomizableItem(const AItem: TFmrBarItem): Boolean;
begin
  Result := (AItem <> nil) and (AItem.Name <> '') and AItem.Visible and (FmrCustStripAmp(AItem.Caption).Trim <> '') and
    not (AItem is TFmrSeparatorItem) and not (AItem is TFmrStaticItem) and
    not (csDestroying in AItem.ComponentState);
end;

function TFmrRibbonCustomization.IsInRibbon(const AItem: TFmrBarItem): Boolean;
var
  T: TFmrRibbonTab;
  I: Integer;
begin
  for T in Tabs do
    for I := 0 to T.GroupCount - 1 do
      if T.Groups[I].ItemLinks.ContainsItem(AItem) then
        Exit(True);
  Result := False;
end;

function TFmrRibbonCustomization.CommandSources: TArray<TFmrCommandSource>;
var
  T: TFmrRibbonTab;
  Cats: TStringList;
  Manager: TFmrBarManager;
  I: Integer;
  S, Caption: string;
begin
  Result := [TFmrCommandSource.Create(TFmrCommandSourceKind.AllCommands, FmrStr(TFmrStringId.CustAllCommands)),
    TFmrCommandSource.Create(TFmrCommandSourceKind.NotInRibbon, FmrStr(TFmrStringId.CustCommandsNotInRibbon))];
  for T in Tabs do
  begin
    Caption := FmrCustStripAmp(T.DisplayCaption);
    if T.ContextGroup <> nil then
      Caption := Caption + ' (' + FmrCustStripAmp(T.ContextGroup.DisplayCaption) + ')';
    Result := Result + [TFmrCommandSource.Create(TFmrCommandSourceKind.Tab, Caption, T)];
  end;
  Manager := FTarget.GetBarManager;
  if Manager = nil then
    Exit;
  Cats := TStringList.Create;
  try
    Cats.Sorted := True;
    Cats.Duplicates := dupIgnore;
    Cats.CaseSensitive := False;
    for S in Manager.Categories do
      if S.Trim <> '' then
        Cats.Add(S.Trim);
    for I := 0 to Manager.ItemCount - 1 do
      if IsCustomizableItem(Manager.Items[I]) and (Manager.Items[I].Category.Trim <> '') then
        Cats.Add(Manager.Items[I].Category.Trim);
    for S in Cats do
      Result := Result + [TFmrCommandSource.Create(TFmrCommandSourceKind.Category, S, nil, S)];
  finally
    Cats.Free;
  end;
end;

function TFmrRibbonCustomization.Commands(const ASource: TFmrCommandSource;
  const AFilter: string): TArray<TFmrBarItem>;
var
  L: TList<TFmrBarItem>;
  Manager: TFmrBarManager;
  I, J: Integer;
  Item: TFmrBarItem;
  Needle: string;
  G: TFmrRibbonGroup;

  function Matches(const AItem: TFmrBarItem): Boolean;
  begin
    Result := (Needle = '') or FmrCustStripAmp(AItem.Caption).ToLower.Contains(Needle);
  end;

begin
  Result := nil;
  Needle := AFilter.Trim.ToLower;
  L := TList<TFmrBarItem>.Create;
  try
    Manager := FTarget.GetBarManager;
    case ASource.Kind of
      TFmrCommandSourceKind.Tab:
        if ASource.Tab <> nil then
          for I := 0 to ASource.Tab.GroupCount - 1 do
          begin
            G := ASource.Tab.Groups[I];
            for J := 0 to G.ItemLinks.Count - 1 do
            begin
              Item := G.ItemLinks[J].Item;
              if IsCustomizableItem(Item) and not L.Contains(Item) and Matches(Item) then
                L.Add(Item);
            end;
          end;
    else
      if Manager <> nil then
        for I := 0 to Manager.ItemCount - 1 do
        begin
          Item := Manager.Items[I];
          if not IsCustomizableItem(Item) or not Matches(Item) then
            Continue;
          case ASource.Kind of
            TFmrCommandSourceKind.NotInRibbon:
              if IsInRibbon(Item) then
                Continue;
            TFmrCommandSourceKind.Category:
              if not SameText(Item.Category.Trim, ASource.Category) then
                Continue;
          end;
          L.Add(Item);
        end;
      L.Sort(TComparer<TFmrBarItem>.Construct(
        function(const A, B: TFmrBarItem): Integer
        begin
          Result := CompareText(FmrCustStripAmp(A.Caption), FmrCustStripAmp(B.Caption));
          if Result = 0 then
            Result := CompareText(A.Name, B.Name);
        end));
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

{ editing }

function TFmrRibbonCustomization.CanAddCommand(const AItem: TFmrBarItem; const ATarget: TObject): Boolean;
var
  G: TFmrRibbonGroup;
begin
  if ATarget is TFmrRibbonGroup then
    G := TFmrRibbonGroup(ATarget)
  else if ATarget is TFmrItemLink then
    G := GroupOfLink(TFmrItemLink(ATarget))
  else
    G := nil;
  Result := IsCustomizableItem(AItem) and (G <> nil) and G.IsUserDefined and (G.Owner = FRoot) and
    not G.ItemLinks.ContainsItem(AItem) and AItem.CanLinkInto(G.ItemLinks);
end;

function TFmrRibbonCustomization.AddCommand(const AItem: TFmrBarItem; const ATarget: TObject): TFmrItemLink;
var
  G: TFmrRibbonGroup;
  Index: Integer;
begin
  if not CanAddCommand(AItem, ATarget) then
    Exit(nil);
  Index := -1;
  if ATarget is TFmrItemLink then
  begin
    G := GroupOfLink(TFmrItemLink(ATarget));
    Index := TFmrItemLink(ATarget).Index + 1;
  end
  else
    G := TFmrRibbonGroup(ATarget);
  if (Index >= 0) and (Index < G.ItemLinks.Count) then
    Result := G.ItemLinks.InsertItem(Index, AItem)
  else
    Result := G.ItemLinks.AddItem(AItem);
  Changed;
end;

function TFmrRibbonCustomization.CanRemove(const AObject: TObject): Boolean;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  I: Integer;
begin
  Result := False;
  if AObject is TFmrItemLink then
  begin
    G := GroupOfLink(TFmrItemLink(AObject));
    Result := (G <> nil) and G.IsUserDefined;
  end
  else if AObject is TFmrRibbonGroup then
    Result := TFmrRibbonGroup(AObject).IsUserDefined
  else if AObject is TFmrRibbonTab then
  begin
    T := TFmrRibbonTab(AObject);
    if not T.IsUserDefined then
      Exit;
    for I := 0 to T.GroupCount - 1 do
      if not T.Groups[I].IsUserDefined then
        Exit;
    Result := True;
  end;
end;

procedure TFmrRibbonCustomization.Remove(const AObject: TObject);
begin
  if not CanRemove(AObject) then
    Exit;
  AObject.Free;
  Changed;
end;

function TFmrRibbonCustomization.CanMove(const AObject: TObject; const ADelta: Integer): Boolean;
var
  A: TArray<TFmrRibbonTab>;
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  L: TFmrItemLink;
  I: Integer;
begin
  Result := False;
  if ADelta = 0 then
    Exit;
  if AObject is TFmrRibbonTab then
  begin
    I := TFmrRibbonTab(AObject).TabIndex + ADelta;
    Result := (I >= 0) and (I < Length(Tabs));
  end
  else if AObject is TFmrRibbonGroup then
  begin
    G := TFmrRibbonGroup(AObject);
    T := G.Tab;
    if T = nil then
      Exit;
    I := G.GroupIndex + ADelta;
    if (I >= 0) and (I < T.GroupCount) then
      Exit(True);
    A := Tabs;
    I := T.TabIndex + Sign(ADelta);
    Result := (I >= 0) and (I <= High(A));
  end
  else if AObject is TFmrItemLink then
  begin
    L := TFmrItemLink(AObject);
    G := GroupOfLink(L);
    I := L.Index + ADelta;
    Result := (G <> nil) and G.IsUserDefined and (I >= 0) and (I < G.ItemLinks.Count);
  end;
end;

procedure TFmrRibbonCustomization.Move(const AObject: TObject; const ADelta: Integer);
var
  A: TArray<TFmrRibbonTab>;
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  L: TFmrItemLink;
  I: Integer;
begin
  if not CanMove(AObject, ADelta) then
    Exit;
  if AObject is TFmrRibbonTab then
    TFmrRibbonStructure.MoveTab(TFmrRibbonTab(AObject), TFmrRibbonTab(AObject).TabIndex + ADelta)
  else if AObject is TFmrRibbonGroup then
  begin
    G := TFmrRibbonGroup(AObject);
    T := G.Tab;
    I := G.GroupIndex + ADelta;
    if (I >= 0) and (I < T.GroupCount) then
      TFmrRibbonStructure.MoveGroup(G, T, I)
    else
    begin
      A := Tabs;
      T := A[T.TabIndex + Sign(ADelta)];
      if ADelta < 0 then
        TFmrRibbonStructure.MoveGroup(G, T, -1)
      else
        TFmrRibbonStructure.MoveGroup(G, T, 0);
    end;
  end
  else if AObject is TFmrItemLink then
  begin
    L := TFmrItemLink(AObject);
    L.Index := L.Index + ADelta;
  end;
  Changed;
end;

function TFmrRibbonCustomization.NewGroup(const AWhere: TObject): TFmrRibbonGroup;
var
  T: TFmrRibbonTab;
  Index: Integer;
begin
  T := TabOf(AWhere);
  if T = nil then
  begin
    if Length(Tabs) = 0 then
      Exit(NewTab(nil));
    T := Tabs[High(Tabs)];
  end;
  Index := -1;
  if AWhere is TFmrRibbonGroup then
    Index := TFmrRibbonGroup(AWhere).GroupIndex + 1
  else if (AWhere is TFmrItemLink) and (GroupOfLink(TFmrItemLink(AWhere)) <> nil) then
    Index := GroupOfLink(TFmrItemLink(AWhere)).GroupIndex + 1;
  Result := TFmrRibbonStructure.CreateGroup(T, FmrStr(TFmrStringId.CustNewGroup), Index);
  Result.IsUserDefined := True;
  Result.Name := UniqueName('grpCustom');
  Changed;
end;

function TFmrRibbonCustomization.NewTab(const AAfter: TObject): TFmrRibbonGroup;
var
  T, After: TFmrRibbonTab;
  Index: Integer;
begin
  After := TabOf(AAfter);
  if After <> nil then
    Index := After.TabIndex + 1
  else
    Index := -1;
  if Index >= Length(Tabs) then
    Index := -1;
  T := TFmrRibbonStructure.CreateTab(FShadow, FmrStr(TFmrStringId.CustNewTab), Index);
  T.IsUserDefined := True;
  T.Name := UniqueName('tabCustom');
  Result := TFmrRibbonStructure.CreateGroup(T, FmrStr(TFmrStringId.CustNewGroup));
  Result.IsUserDefined := True;
  Result.Name := UniqueName('grpCustom');
  Changed;
end;

function TFmrRibbonCustomization.CanRename(const AObject: TObject): Boolean;
var
  G: TFmrRibbonGroup;
begin
  if (AObject is TFmrRibbonTab) or (AObject is TFmrRibbonGroup) then
    Result := True
  else if AObject is TFmrItemLink then
  begin
    G := GroupOfLink(TFmrItemLink(AObject));
    Result := (G <> nil) and G.IsUserDefined;
  end
  else
    Result := False;
end;

procedure TFmrRibbonCustomization.Rename(const AObject: TObject; const ACaption: string);
var
  S: TFmrRibbonStructureObject;
  L: TFmrItemLink;
  Caption: string;
begin
  if not CanRename(AObject) then
    Exit;
  Caption := ACaption.Trim;
  if AObject is TFmrRibbonStructureObject then
  begin
    S := TFmrRibbonStructureObject(AObject);
    if S.IsUserDefined then
    begin
      if Caption <> '' then
        S.Caption := Caption;
      S.UserCaption := '';
    end
    else if (Caption = '') or (Caption = S.Caption) or (Caption = FmrCustStripAmp(S.Caption)) then
      S.UserCaption := ''
    else
      S.UserCaption := Caption;
  end
  else if AObject is TFmrItemLink then
  begin
    L := TFmrItemLink(AObject);
    if (Caption = '') or (L.Item = nil) or (Caption = L.Item.Caption) or (Caption = FmrCustStripAmp(L.Item.Caption)) then
      L.UserCaption := ''
    else
      L.UserCaption := Caption;
  end;
  Changed;
end;

procedure TFmrRibbonCustomization.SetGroupGlyph(const AGroup: TFmrRibbonGroup; const AGlyphCode: Cardinal);
begin
  if (AGroup = nil) or not AGroup.IsUserDefined then
    Exit;
  AGroup.Glyph.GlyphCode := AGlyphCode;
  Changed;
end;

function TFmrRibbonCustomization.IsVisible(const AObject: TObject): Boolean;
begin
  if AObject is TFmrRibbonStructureObject then
    Result := TFmrRibbonStructureObject(AObject).Visible
  else if AObject is TFmrItemLink then
    Result := TFmrItemLink(AObject).Visible
  else
    Result := True;
end;

procedure TFmrRibbonCustomization.SetVisible(const AObject: TObject; const AVisible: Boolean);
begin
  if (AObject is TFmrRibbonTab) or (AObject is TFmrRibbonGroup) then
  begin
    TFmrRibbonStructureObject(AObject).Visible := AVisible;
    Changed;
  end;
end;

function TFmrRibbonCustomization.DefaultJSON: TJSONObject;
var
  V: TJSONValue;
begin
  Result := nil;
  if FDefaultLayout = '' then
    Exit;
  V := TJSONObject.ParseJSONValue(FDefaultLayout);
  if V is TJSONObject then
    Result := TJSONObject(V)
  else
    V.Free;
end;

function TFmrRibbonCustomization.CanResetTab(const ATab: TFmrRibbonTab): Boolean;
begin
  Result := (ATab <> nil) and not ATab.IsUserDefined;
end;

procedure TFmrRibbonCustomization.ResetTab(const ATab: TFmrRibbonTab);
var
  J: TJSONObject;
  JTabs, Groups: TJSONArray;
  GV: TJSONValue;
  Entry, GroupEntry: TJSONObject;
  I, K: Integer;
  G: TFmrRibbonGroup;
  Home: TFmrRibbonTab;
  Mentioned: TList<TFmrRibbonGroup>;
  Name: string;

  function FindEntry(const ATabName: string): TJSONObject;
  var
    X: TJSONValue;
  begin
    Result := nil;
    if (JTabs = nil) or (ATabName = '') then
      Exit;
    for X in JTabs do
      if (X is TJSONObject) and SameText(TJSONObject(X).GetValue<string>('name', ''), ATabName) and
        not TJSONObject(X).GetValue<Boolean>('userDefined', False) then
        Exit(TJSONObject(X));
  end;

  function DefaultTabOf(const AGroupName: string): TFmrRibbonTab;
  var
    X, Y: TJSONValue;
    Gs: TJSONArray;
  begin
    Result := nil;
    if (JTabs = nil) or (AGroupName = '') then
      Exit;
    for X in JTabs do
      if X is TJSONObject then
      begin
        Gs := JArray(TJSONObject(X), 'groups');
        if Gs <> nil then
          for Y in Gs do
            if (Y is TJSONObject) and SameText(TJSONObject(Y).GetValue<string>('name', ''), AGroupName) then
              Exit(TFmrRibbonStructure.FindTab(FShadow, TJSONObject(X).GetValue<string>('name', '')));
      end;
  end;

begin
  if not CanResetTab(ATab) then
    Exit;
  J := DefaultJSON;
  Mentioned := TList<TFmrRibbonGroup>.Create;
  try
    JTabs := nil;
    if J <> nil then
      JTabs := JArray(J, 'tabs');
    Entry := FindEntry(ATab.Name);
    // Custom groups of the tab go away.
    for I := ATab.GroupCount - 1 downto 0 do
      if ATab.Groups[I].IsUserDefined then
        ATab.Groups[I].Free;
    if Entry <> nil then
    begin
      ATab.Visible := Entry.GetValue<Boolean>('visible', True);
      ATab.UserCaption := Entry.GetValue<string>('userCaption', '');
      Groups := JArray(Entry, 'groups');
      K := 0;
      if Groups <> nil then
        for GV in Groups do
        begin
          if not (GV is TJSONObject) then
            Continue;
          GroupEntry := TJSONObject(GV);
          if GroupEntry.GetValue<Boolean>('userDefined', False) then
            Continue;
          G := TFmrRibbonStructure.FindGroup(FShadow, GroupEntry.GetValue<string>('name', ''));
          if (G = nil) or Mentioned.Contains(G) then
            Continue;
          TFmrRibbonStructure.MoveGroup(G, ATab, K);
          G.Visible := GroupEntry.GetValue<Boolean>('visible', True);
          G.UserCaption := GroupEntry.GetValue<string>('userCaption', '');
          Mentioned.Add(G);
          Inc(K);
        end;
    end
    else
    begin
      ATab.Visible := True;
      ATab.UserCaption := '';
    end;
    // Designed groups that belong elsewhere go back to their default tab; unnamed ones stay.
    for I := ATab.GroupCount - 1 downto 0 do
    begin
      G := ATab.Groups[I];
      if Mentioned.Contains(G) then
        Continue;
      Name := G.Name;
      Home := DefaultTabOf(Name);
      if (Home <> nil) and (Home <> ATab) then
        TFmrRibbonStructure.MoveGroup(G, Home)
      else
      begin
        G.Visible := True;
        G.UserCaption := '';
      end;
    end;
  finally
    Mentioned.Free;
    J.Free;
  end;
  Changed;
end;

procedure TFmrRibbonCustomization.ResetAll;
var
  T: TFmrRibbonTab;
  I: Integer;
  G: TFmrRibbonGroup;
begin
  if FDefaultLayout <> '' then
  begin
    TFmrRibbonLayoutStorage.LoadFromString(FShadow, FDefaultLayout);
    // Objects without a name are not in a layout: they only lose their user caption.
    for T in Tabs do
    begin
      if (T.Name = '') and not T.IsUserDefined then
        T.UserCaption := '';
      for I := 0 to T.GroupCount - 1 do
        if (T.Groups[I].Name = '') and not T.Groups[I].IsUserDefined then
        begin
          T.Groups[I].UserCaption := '';
          T.Groups[I].Visible := True;
        end;
    end;
  end
  else
  begin
    for T in Tabs do
    begin
      for I := T.GroupCount - 1 downto 0 do
      begin
        G := T.Groups[I];
        if G.IsUserDefined then
          G.Free
        else
        begin
          G.Visible := True;
          G.UserCaption := '';
        end;
      end;
      if T.IsUserDefined then
      begin
        // Designed groups moved into a custom tab go to the first designed tab.
        for I := T.GroupCount - 1 downto 0 do
          for var D in Tabs do
            if not D.IsUserDefined then
            begin
              TFmrRibbonStructure.MoveGroup(T.Groups[I], D);
              Break;
            end;
        T.Free;
      end
      else
      begin
        T.Visible := True;
        T.UserCaption := '';
      end;
    end;
  end;
  Changed;
end;

procedure TFmrRibbonCustomization.ResetQAT;
var
  J, Mini: TJSONObject;
  Q: TJSONValue;
begin
  J := DefaultJSON;
  try
    if J = nil then
      Exit;
    Q := J.GetValue('qat');
    if not (Q is TJSONObject) then
      Exit;
    Mini := TJSONObject.Create;
    try
      Mini.AddPair('format', TFmrRibbonLayoutStorage.FormatName);
      Mini.AddPair('version', TJSONNumber.Create(TFmrRibbonLayoutStorage.FormatVersion));
      Mini.AddPair('qat', TJSONObject(Q.Clone));
      TFmrRibbonLayoutStorage.LoadFromJSON(FShadow, Mini);
    finally
      Mini.Free;
    end;
  finally
    J.Free;
  end;
  Changed;
end;

{ quick access toolbar }

function TFmrRibbonCustomization.CanAddToQAT(const AItem: TFmrBarItem): Boolean;
begin
  Result := IsCustomizableItem(AItem) and not FShadow.FQAT.ContainsItem(AItem);
end;

function TFmrRibbonCustomization.AddToQAT(const AItem: TFmrBarItem; const AIndex: Integer): TFmrItemLink;
var
  Links: TFmrItemLinks;
begin
  Result := nil;
  if not IsCustomizableItem(AItem) then
    Exit;
  Links := FShadow.FQAT.ItemLinks;
  Result := Links.FindByItem(AItem);
  if Result <> nil then
  begin
    Result.Visible := True;
    Exit;
  end;
  if (AIndex >= 0) and (AIndex < Links.Count) then
    Result := Links.InsertItem(AIndex, AItem)
  else
    Result := Links.AddItem(AItem);
  Changed;
end;

procedure TFmrRibbonCustomization.RemoveFromQAT(const AIndex: Integer);
var
  Links: TFmrItemLinks;
begin
  Links := FShadow.FQAT.ItemLinks;
  if (AIndex >= 0) and (AIndex < Links.Count) then
  begin
    Links.Delete(AIndex);
    Changed;
  end;
end;

function TFmrRibbonCustomization.CanMoveInQAT(const AIndex, ADelta: Integer): Boolean;
var
  N: Integer;
begin
  N := FShadow.FQAT.ItemLinks.Count;
  Result := (ADelta <> 0) and (AIndex >= 0) and (AIndex < N) and (AIndex + ADelta >= 0) and (AIndex + ADelta < N);
end;

procedure TFmrRibbonCustomization.MoveInQAT(const AIndex, ADelta: Integer);
begin
  if not CanMoveInQAT(AIndex, ADelta) then
    Exit;
  FShadow.FQAT.ItemLinks[AIndex].Index := AIndex + ADelta;
  Changed;
end;

procedure TFmrRibbonCustomization.SetQATSeparator(const AIndex: Integer; const AValue: Boolean);
var
  Links: TFmrItemLinks;
begin
  Links := FShadow.FQAT.ItemLinks;
  if (AIndex >= 0) and (AIndex < Links.Count) and (Links[AIndex].BeginGroup <> AValue) then
  begin
    Links[AIndex].BeginGroup := AValue;
    Changed;
  end;
end;

function TFmrRibbonCustomization.GetQATBelow: Boolean;
begin
  Result := FShadow.FQAT.Position = TFmrQATPosition.BelowRibbon;
end;

procedure TFmrRibbonCustomization.SetQATBelow(const Value: Boolean);
begin
  if Value then
    FShadow.FQAT.Position := TFmrQATPosition.BelowRibbon
  else
    FShadow.FQAT.Position := TFmrQATPosition.AboveRibbon;
  Changed;
end;

function TFmrRibbonCustomization.GetQATVisible: Boolean;
begin
  Result := FShadow.FQAT.Visible;
end;

procedure TFmrRibbonCustomization.SetQATVisible(const Value: Boolean);
begin
  FShadow.FQAT.Visible := Value;
  Changed;
end;

{ files }

function TFmrRibbonCustomization.SaveToString: string;
begin
  Result := TFmrRibbonLayoutStorage.SaveToString(FShadow);
end;

procedure TFmrRibbonCustomization.LoadFromString(const AText: string);
begin
  TFmrRibbonLayoutStorage.LoadFromString(FShadow, AText);
  Changed;
end;

procedure TFmrRibbonCustomization.SaveToFile(const AFileName: string);
begin
  TFile.WriteAllText(AFileName, SaveToString, TEncoding.UTF8);
end;

procedure TFmrRibbonCustomization.LoadFromFile(const AFileName: string);
begin
  LoadFromString(TFile.ReadAllText(AFileName, TEncoding.UTF8));
end;

{ apply }

procedure TFmrRibbonCustomization.Apply;
var
  Target: TFmxObject;
  FormRoot: TComponent;
  ShTabs: TArray<TFmrRibbonTab>;
  ST, OT: TFmrRibbonTab;
  SG, OG: TFmrRibbonGroup;
  O: TFmrRibbonStructureObject;
  Kept: TList<TObject>;
  I, J: Integer;
  OQ: TFmrRibbonQuickAccessToolbar;
  T: TFmrRibbonTab;

  procedure NameNew(const AObject: TComponent; const AName, ABase: string);
  var
    N: Integer;
    S: string;
  begin
    if (AName <> '') and IsValidIdent(AName) and ((FormRoot = nil) or (FormRoot.FindComponent(AName) = nil)) then
      AObject.Name := AName
    else if FormRoot <> nil then
    begin
      N := 1;
      repeat
        S := ABase + IntToStr(N);
        Inc(N);
      until FormRoot.FindComponent(S) = nil;
      AObject.Name := S;
    end;
  end;

  function OriginalContext(const AShadow: TFmrRibbonContextGroup): TFmrRibbonContextGroup;
  begin
    O := OriginalOf(AShadow);
    if O is TFmrRibbonContextGroup then
      Result := TFmrRibbonContextGroup(O)
    else
      Result := nil;
  end;

begin
  Target := TargetObject;
  FormRoot := Target.Owner;
  ShTabs := Tabs;
  Kept := TList<TObject>.Create;
  FTarget.BeginStructureUpdate;
  try
    // 1. An original for every shadow tab and group.
    for ST in ShTabs do
    begin
      O := OriginalOf(ST);
      if (O is TFmrRibbonTab) and (O.Parent = Target) then
        OT := TFmrRibbonTab(O)
      else
      begin
        OT := TFmrRibbonStructure.CreateTab(Target, ST.Caption);
        OT.IsUserDefined := True;
        NameNew(OT, ST.Name, 'tabCustom');
        FOriginals.AddOrSetValue(ST, OT);
      end;
      Kept.Add(OT);
      if OT.IsUserDefined then
      begin
        OT.Caption := ST.Caption;
        OT.KeyTip := ST.KeyTip;
        OT.ContextGroup := OriginalContext(ST.ContextGroup);
      end;
      OT.UserCaption := ST.UserCaption;
      OT.Visible := ST.Visible;
      for I := 0 to ST.GroupCount - 1 do
      begin
        SG := ST.Groups[I];
        O := OriginalOf(SG);
        if (O is TFmrRibbonGroup) and not (csDestroying in O.ComponentState) then
          OG := TFmrRibbonGroup(O)
        else
        begin
          OG := TFmrRibbonStructure.CreateGroup(OT, SG.Caption);
          OG.IsUserDefined := True;
          NameNew(OG, SG.Name, 'grpCustom');
          FOriginals.AddOrSetValue(SG, OG);
        end;
        Kept.Add(OG);
      end;
    end;

    // 2. Groups into their tabs, in order, with their properties.
    for ST in ShTabs do
    begin
      OT := TFmrRibbonTab(OriginalOf(ST));
      for I := 0 to ST.GroupCount - 1 do
      begin
        SG := ST.Groups[I];
        OG := TFmrRibbonGroup(OriginalOf(SG));
        TFmrRibbonStructure.MoveGroup(OG, OT, I);
        OG.Visible := SG.Visible;
        OG.UserCaption := SG.UserCaption;
        if OG.IsUserDefined then
        begin
          OG.Caption := SG.Caption;
          OG.KeyTip := SG.KeyTip;
          if not OG.Glyph.SameAs(SG.Glyph) then
            OG.Glyph := SG.Glyph;
          OG.ShowDialogLauncher := SG.ShowDialogLauncher;
          if not SameLinks(OG.ItemLinks, SG.ItemLinks) then
            OG.ItemLinks := SG.ItemLinks;
        end;
      end;
    end;

    // 3. User-defined groups and tabs that the session removed.
    for T in TFmrRibbonStructure.Tabs(Target) do
      for J := T.GroupCount - 1 downto 0 do
        if T.Groups[J].IsUserDefined and not Kept.Contains(T.Groups[J]) then
          T.Groups[J].Free;
    for T in TFmrRibbonStructure.Tabs(Target) do
      if T.IsUserDefined and not Kept.Contains(T) then
      begin
        // Designed groups cannot be lost: anything left goes to the first kept tab.
        for J := T.GroupCount - 1 downto 0 do
          if (Kept.Count > 0) and (Kept[0] is TFmrRibbonTab) then
            TFmrRibbonStructure.MoveGroup(T.Groups[J], TFmrRibbonTab(Kept[0]));
        T.Free;
      end;

    // 4. Tab order.
    for I := 0 to High(ShTabs) do
      TFmrRibbonStructure.MoveTab(TFmrRibbonTab(OriginalOf(ShTabs[I])), I);

    // 5. Quick access toolbar and options.
    OQ := FTarget.GetQuickAccessToolbar;
    if OQ <> nil then
    begin
      if not SameLinks(OQ.ItemLinks, FShadow.FQAT.ItemLinks) then
        OQ.ItemLinks := FShadow.FQAT.ItemLinks;
      OQ.Position := FShadow.FQAT.Position;
      OQ.Visible := FShadow.FQAT.Visible;
    end;
    FTarget.SetLayoutOptions(FShadow.FOptions);
  finally
    FTarget.EndStructureUpdate;
    Kept.Free;
  end;
  FModified := False;
end;

end.
