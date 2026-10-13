unit FMR.Tests.Fakes;

/// Test doubles: a ribbon stand-in that implements IFmrRibbonStructureOwner and records what it is told, a links
/// owner that records link notifications, and a root component for streaming tests.

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, FMX.Types, FMR.Ribbon.Types, FMR.Bars,
  FMR.Bars.Items, FMR.Ribbon.Structure;

type
  TFakeRibbon = class(TFmxObject, IFmrRibbonStructureOwner)
  private
    FBarManager: TFmrBarManager;
    FQAT: TFmrRibbonQuickAccessToolbar;
    FActiveTab: TFmrRibbonTab;
    FOptions: TFmrRibbonLayoutOptions;
    FUpdateCount: Integer;
    procedure SetBarManager(const Value: TFmrBarManager);
    procedure SetQAT(const Value: TFmrRibbonQuickAccessToolbar);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
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
    StructureChangedCount: Integer;
    ObjectChangedCount: Integer;
    LastChange: TFmrItemChange;
    LinksChangedCount: Integer;
    LinkItemChangedCount: Integer;
    LinkRemovingCount: Integer;
    UpdateBatches: Integer;
    Removed: TList<TObject>;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ResetCounters;
    property Options: TFmrRibbonLayoutOptions read FOptions write FOptions;
    property ActiveTab: TFmrRibbonTab read FActiveTab write SetActiveTab;
  published
    property BarManager: TFmrBarManager read FBarManager write SetBarManager;
    property QuickAccessToolbar: TFmrRibbonQuickAccessToolbar read FQAT write SetQAT;
  end;

  TFakeLinksOwner = class(TInterfacedPersistent, IFmrItemLinksOwner)
  public
    Links: TFmrItemLinks;
    LinksChangedCount: Integer;
    ItemChangedCount: Integer;
    LastChange: TFmrItemChange;
    RemovingCount: Integer;
    procedure LinksChanged(const ALinks: TFmrItemLinks);
    procedure LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
    procedure LinkRemoving(const ALink: TFmrItemLink);
    constructor Create;
    destructor Destroy; override;
  end;

  TFakeListener = class(TInterfacedObject, IFmrBarManagerListener)
  public
    Log: TList<TFmrManagerChange>;
    LastItem: TFmrBarItem;
    procedure BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
      const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
    function Count(const AChange: TFmrManagerChange): Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  /// <summary>Root of streamed test structures (plays the form).</summary>
  TFmrTestRoot = class(TFmxObject)
  end;

  /// <summary>A designed test structure: root -> manager -> items, root -> ribbon -> tabs -> groups.</summary>
  TTestStructure = class
  public
    Root: TFmrTestRoot;
    Manager: TFmrBarManager;
    Ribbon: TFakeRibbon;
    Paste, Cut, Copy, Bold, Italic, Underline, Find, Zoom, Save, Undo, Redo: TFmrButtonItem;
    Styles: TFmrGalleryItem;
    FontName: TFmrFontNameItem;
    TabHome, TabInsert, TabView, TabPicture: TFmrRibbonTab;
    GrpClipboard, GrpFont, GrpStyles, GrpTables, GrpZoom, GrpArrange: TFmrRibbonGroup;
    CtxPicture: TFmrRibbonContextGroup;
    constructor Create;
    destructor Destroy; override;
    function NewButton(const AName, ACaption: string): TFmrButtonItem;
    function NewTab(const AName, ACaption: string): TFmrRibbonTab;
    function NewGroup(const ATab: TFmrRibbonTab; const AName, ACaption: string): TFmrRibbonGroup;
  end;

/// <summary>Text dump of tabs/groups/links of an owner: "Home[Clipboard(btnPaste,btnCut)]..." (hidden objects
/// marked with '-').</summary>
function DumpStructure(const AOwner: TFmxObject): string;

implementation

{ TFakeRibbon }

constructor TFakeRibbon.Create(AOwner: TComponent);
begin
  inherited;
  FQAT := TFmrRibbonQuickAccessToolbar.Create(Self);
  FOptions := TFmrRibbonLayoutOptions.Default;
  Removed := TList<TObject>.Create;
end;

destructor TFakeRibbon.Destroy;
begin
  FreeAndNil(FQAT);
  inherited;
  FreeAndNil(Removed);
end;

procedure TFakeRibbon.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FBarManager) then
    FBarManager := nil;
end;

procedure TFakeRibbon.ResetCounters;
begin
  StructureChangedCount := 0;
  ObjectChangedCount := 0;
  LinksChangedCount := 0;
  LinkItemChangedCount := 0;
  LinkRemovingCount := 0;
  UpdateBatches := 0;
  Removed.Clear;
end;

procedure TFakeRibbon.SetBarManager(const Value: TFmrBarManager);
begin
  if FBarManager <> Value then
  begin
    if FBarManager <> nil then
      FBarManager.RemoveFreeNotification(Self);
    FBarManager := Value;
    if FBarManager <> nil then
      FBarManager.FreeNotification(Self);
  end;
end;

procedure TFakeRibbon.SetQAT(const Value: TFmrRibbonQuickAccessToolbar);
begin
  FQAT.Assign(Value);
end;

function TFakeRibbon.GetStructureObject: TFmxObject;
begin
  Result := Self;
end;

function TFakeRibbon.GetBarManager: TFmrBarManager;
begin
  Result := FBarManager;
end;

function TFakeRibbon.GetQuickAccessToolbar: TFmrRibbonQuickAccessToolbar;
begin
  Result := FQAT;
end;

function TFakeRibbon.GetActiveTab: TFmrRibbonTab;
begin
  Result := FActiveTab;
end;

procedure TFakeRibbon.SetActiveTab(const ATab: TFmrRibbonTab);
begin
  FActiveTab := ATab;
end;

function TFakeRibbon.GetLayoutOptions: TFmrRibbonLayoutOptions;
begin
  Result := FOptions;
end;

procedure TFakeRibbon.SetLayoutOptions(const AOptions: TFmrRibbonLayoutOptions);
begin
  FOptions := AOptions;
end;

procedure TFakeRibbon.BeginStructureUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TFakeRibbon.EndStructureUpdate;
begin
  Dec(FUpdateCount);
  if FUpdateCount = 0 then
    Inc(UpdateBatches);
end;

procedure TFakeRibbon.StructureChanged(const ASender: TObject);
begin
  Inc(StructureChangedCount);
end;

procedure TFakeRibbon.StructureObjectChanged(const ASender: TObject; const AChange: TFmrItemChange);
begin
  Inc(ObjectChangedCount);
  LastChange := AChange;
end;

procedure TFakeRibbon.StructureObjectRemoving(const AObject: TObject);
begin
  if AObject = FActiveTab then
    FActiveTab := nil;
  Removed.Add(AObject);
end;

procedure TFakeRibbon.LinksChanged(const AOwner: TPersistent; const ALinks: TFmrItemLinks);
begin
  Inc(LinksChangedCount);
end;

procedure TFakeRibbon.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  Inc(LinkItemChangedCount);
  LastChange := AChange;
end;

procedure TFakeRibbon.LinkRemoving(const ALink: TFmrItemLink);
begin
  Inc(LinkRemovingCount);
end;

{ TFakeLinksOwner }

constructor TFakeLinksOwner.Create;
begin
  inherited;
  Links := TFmrItemLinks.Create(Self);
end;

destructor TFakeLinksOwner.Destroy;
begin
  FreeAndNil(Links);
  inherited;
end;

procedure TFakeLinksOwner.LinkItemChanged(const ALink: TFmrItemLink; const AChange: TFmrItemChange);
begin
  Inc(ItemChangedCount);
  LastChange := AChange;
end;

procedure TFakeLinksOwner.LinkRemoving(const ALink: TFmrItemLink);
begin
  Inc(RemovingCount);
end;

procedure TFakeLinksOwner.LinksChanged(const ALinks: TFmrItemLinks);
begin
  Inc(LinksChangedCount);
end;

{ TFakeListener }

constructor TFakeListener.Create;
begin
  inherited;
  Log := TList<TFmrManagerChange>.Create;
end;

destructor TFakeListener.Destroy;
begin
  Log.Free;
  inherited;
end;

procedure TFakeListener.BarManagerChanged(const AManager: TFmrBarManager; const AChange: TFmrManagerChange;
  const AItem: TFmrBarItem; const AItemChange: TFmrItemChange);
begin
  Log.Add(AChange);
  LastItem := AItem;
end;

function TFakeListener.Count(const AChange: TFmrManagerChange): Integer;
var
  C: TFmrManagerChange;
begin
  Result := 0;
  for C in Log do
    if C = AChange then
      Inc(Result);
end;

{ TTestStructure }

constructor TTestStructure.Create;
begin
  inherited;
  Root := TFmrTestRoot.Create(nil);
  Root.Name := 'Root';
  Manager := TFmrBarManager.Create(Root);
  Manager.Name := 'BarManager';
  Manager.Parent := Root;
  Ribbon := TFakeRibbon.Create(Root);
  Ribbon.Name := 'Ribbon';
  Ribbon.Parent := Root;
  Ribbon.BarManager := Manager;

  Paste := NewButton('btnPaste', 'Paste');
  Cut := NewButton('btnCut', 'Cut');
  Copy := NewButton('btnCopy', 'Copy');
  Bold := NewButton('btnBold', 'Bold');
  Italic := NewButton('btnItalic', 'Italic');
  Underline := NewButton('btnUnderline', 'Underline');
  Find := NewButton('btnFind', 'Find');
  Zoom := NewButton('btnZoom', 'Zoom');
  Save := NewButton('btnSave', 'Save');
  Undo := NewButton('btnUndo', 'Undo');
  Redo := NewButton('btnRedo', 'Redo');
  Styles := TFmrGalleryItem(Manager.CreateItem(TFmrGalleryItem, 'galStyles'));
  Styles.Caption := 'Styles';
  FontName := TFmrFontNameItem(Manager.CreateItem(TFmrFontNameItem, 'cbFontName'));
  FontName.Caption := 'Font';

  CtxPicture := TFmrRibbonContextGroup.Create(Root);
  CtxPicture.Name := 'ctxPicture';
  CtxPicture.Caption := 'Picture Tools';
  CtxPicture.Parent := Ribbon;

  TabHome := NewTab('tabHome', 'Home');
  TabInsert := NewTab('tabInsert', 'Insert');
  TabView := NewTab('tabView', 'View');
  TabPicture := NewTab('tabPicture', 'Format');
  TabPicture.ContextGroup := CtxPicture;

  GrpClipboard := NewGroup(TabHome, 'grpClipboard', 'Clipboard');
  GrpClipboard.ItemLinks.AddItem(Paste).ViewLevels := [TFmrViewLevel.Large];
  GrpClipboard.ItemLinks.AddItem(Cut);
  GrpClipboard.ItemLinks.AddItem(Copy);
  GrpFont := NewGroup(TabHome, 'grpFont', 'Font');
  GrpFont.ItemLinks.AddItem(FontName);
  GrpFont.ItemLinks.AddItem(Bold).ButtonGroup := TFmrButtonGroupPosition.Start;
  GrpFont.ItemLinks.AddItem(Italic).ButtonGroup := TFmrButtonGroupPosition.Member;
  GrpFont.ItemLinks.AddItem(Underline).ButtonGroup := TFmrButtonGroupPosition.Member;
  GrpStyles := NewGroup(TabHome, 'grpStyles', 'Styles');
  GrpStyles.ItemLinks.AddItem(Styles);
  GrpStyles.ItemLinks.AddItem(Find, True);
  GrpTables := NewGroup(TabInsert, 'grpTables', 'Tables');
  GrpTables.ItemLinks.AddItem(Paste);
  GrpZoom := NewGroup(TabView, 'grpZoom', 'Zoom');
  GrpZoom.ItemLinks.AddItem(Zoom);
  GrpArrange := NewGroup(TabPicture, 'grpArrange', 'Arrange');
  GrpArrange.ItemLinks.AddItem(Copy);

  Ribbon.QuickAccessToolbar.ItemLinks.AddItem(Save);
  Ribbon.QuickAccessToolbar.ItemLinks.AddItem(Undo);
  Ribbon.ResetCounters;
end;

destructor TTestStructure.Destroy;
begin
  Root.Free;
  inherited;
end;

function TTestStructure.NewButton(const AName, ACaption: string): TFmrButtonItem;
begin
  Result := TFmrButtonItem(Manager.CreateItem(TFmrButtonItem, AName));
  Result.Caption := ACaption;
end;

function TTestStructure.NewGroup(const ATab: TFmrRibbonTab; const AName, ACaption: string): TFmrRibbonGroup;
begin
  Result := TFmrRibbonGroup.Create(Root);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Parent := ATab;
end;

function TTestStructure.NewTab(const AName, ACaption: string): TFmrRibbonTab;
begin
  Result := TFmrRibbonTab.Create(Root);
  Result.Name := AName;
  Result.Caption := ACaption;
  Result.Parent := Ribbon;
end;

function DumpStructure(const AOwner: TFmxObject): string;
var
  T: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  I, J: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for T in TFmrRibbonStructure.Tabs(AOwner) do
    begin
      if not T.Visible then
        SB.Append('-');
      SB.Append(T.DisplayCaption).Append('[');
      for I := 0 to T.GroupCount - 1 do
      begin
        G := T.Groups[I];
        if I > 0 then
          SB.Append(',');
        if not G.Visible then
          SB.Append('-');
        SB.Append(G.DisplayCaption).Append('(');
        for J := 0 to G.ItemLinks.Count - 1 do
        begin
          if J > 0 then
            SB.Append(',');
          if G.ItemLinks[J].Item <> nil then
            SB.Append(G.ItemLinks[J].Item.Name);
        end;
        SB.Append(')');
      end;
      SB.Append(']');
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

initialization
  RegisterFmxClasses([TFmrTestRoot, TFakeRibbon]);

end.
