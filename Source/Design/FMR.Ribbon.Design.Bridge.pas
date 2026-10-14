{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: designer bridge and notification hub    }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.Bridge;

/// The editor windows of the design package (items editor, structure editor, image dialog, template chooser) do
/// not use IDE units: they talk to the form designer through IFmrDesignBridge and receive designer events through
/// TFmrDesignHub. The IDE implements the bridge around DesignIntf.IDesigner (FMR.Ribbon.Design.Editors); the
/// standalone preview program (tools\DesignPreview) implements it with a fake designer, so the windows can be run
/// and checked without the IDE.

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Generics.Collections, Vcl.Controls, Vcl.Forms, FMX.Types,
  FMR.Ribbon.Types, FMR.Bars, FMR.Bars.Items, FMR.Ribbon.Structure;

type
  /// <summary>What an editor window needs from the form designer.</summary>
  IFmrDesignBridge = interface
    ['{BDFEDA52-C245-437A-AD74-6683ABCB59C7}']
    /// <summary>The designed root (the form).</summary>
    function Root: TComponent;
    /// <summary>A component name not used in the root: ABaseName itself when it is free, otherwise numbered.
    /// </summary>
    function UniqueName(const ABaseName: string): string;
    /// <summary>Creates a component owned by the root with a unique name, child of AParent.</summary>
    function CreateComponent(const AClass: TComponentClass; const AParent: TFmxObject): TComponent;
    /// <summary>Tells the designer that the root changed (marks the form modified, refreshes the inspector).
    /// </summary>
    procedure Modified;
    /// <summary>Selects objects in the designer and the Object Inspector (components, collection items).</summary>
    procedure SelectObjects(const AObjects: TArray<TPersistent>);
    function SelectedObjects: TArray<TPersistent>;
    /// <summary>Creates (when missing) and shows the event handler AEventName of AInstance in the code editor.
    /// </summary>
    procedure ShowEvent(const AInstance: TPersistent; const AEventName: string);
  end;

  /// <summary>Receives designer events (registered with TFmrDesignHub).</summary>
  IFmrDesignListener = interface
    ['{1D33851D-CA22-4FF7-8663-82FEAC0662C3}']
    procedure DesignItemDeleted(const ARoot: TComponent; const AItem: TPersistent);
    procedure DesignItemInserted(const ARoot: TComponent; const AItem: TPersistent);
    procedure DesignItemsModified(const ARoot: TComponent);
    procedure DesignSelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>);
    /// <summary>The designer of ARoot closes: windows working on it must close.</summary>
    procedure DesignRootClosing(const ARoot: TComponent);
  end;

  /// <summary>Broadcasts designer events to the open editor windows.</summary>
  TFmrDesignHub = class sealed
  private
    class var FListeners: TList<IFmrDesignListener>;
    class function Snapshot: TArray<IFmrDesignListener>; static;
  public
    class destructor Destroy;
    class procedure AddListener(const AListener: IFmrDesignListener); static;
    class procedure RemoveListener(const AListener: IFmrDesignListener); static;
    class procedure ItemDeleted(const ARoot: TComponent; const AItem: TPersistent); static;
    class procedure ItemInserted(const ARoot: TComponent; const AItem: TPersistent); static;
    class procedure ItemsModified(const ARoot: TComponent); static;
    class procedure SelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>); static;
    class procedure RootClosing(const ARoot: TComponent); static;
  end;

  /// <summary>An item class offered by the editors ("New Button", "New Gallery"...).</summary>
  TFmrItemClassInfo = record
    ItemClass: TFmrBarItemClass;
    Caption: string;
    /// <summary>Base of default names and captions ('Button' → 'Button1').</summary>
    BaseName: string;
    /// <summary>Glyph of the class in the editors (Segoe Fluent Icons code point).</summary>
    Glyph: Cardinal;
  end;

  /// <summary>Drag object of bar items (items editor → structure editor, items editor → ribbon).</summary>
  TFmrItemDragObject = class(TDragControlObjectEx)
  private
    FItems: TArray<TFmrBarItem>;
  public
    constructor CreateFor(const AControl: TControl; const AItems: TArray<TFmrBarItem>);
    property Items: TArray<TFmrBarItem> read FItems;
  end;

  /// <summary>Callback that applies the IDE theme to an editor window (set by the IDE part; nil elsewhere).
  /// </summary>
  TFmrApplyThemeProc = reference to procedure(const AForm: TCustomForm);

var
  FmrDesignApplyTheme: TFmrApplyThemeProc;

/// <summary>Pixels per inch of the monitor under the mouse (where editor windows appear).</summary>
function FmrDesignMonitorPPI: Integer;
/// <summary>Scales a form whose controls were created at 96 dpi to the monitor PPI (fonts, controls and the size
/// of the form) and applies the IDE theme.</summary>
procedure FmrDesignFinishForm(const AForm: TCustomForm);

/// <summary>Item classes offered by the editors, in menu order.</summary>
function FmrDesignItemClasses: TArray<TFmrItemClassInfo>;
/// <summary>Info of AClass (or of its nearest registered ancestor).</summary>
function FmrDesignItemClassInfo(const AClass: TClass): TFmrItemClassInfo;
/// <summary>Creates an item in AManager through the designer: unique name, caption from the name (buttons, sub
/// items, static and check items, galleries), ACategory.</summary>
function FmrDesignNewItem(const ABridge: IFmrDesignBridge; const AManager: TFmrBarManager;
  const AClass: TFmrBarItemClass; const ACategory: string = ''): TFmrBarItem;
/// <summary>Creates a tab at the end of the tabs of ARibbon (caption 'Tab' + number).</summary>
function FmrDesignNewTab(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject;
  const AContextGroup: TFmrRibbonContextGroup = nil): TFmrRibbonTab;
function FmrDesignNewGroup(const ABridge: IFmrDesignBridge; const ATab: TFmrRibbonTab;
  const AIndex: Integer = -1): TFmrRibbonGroup;
function FmrDesignNewContextGroup(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): TFmrRibbonContextGroup;
/// <summary>The bar manager of a structure owner (nil when none).</summary>
function FmrDesignManagerOf(const ARibbon: TFmxObject): TFmrBarManager;
/// <summary>The bar manager of ARibbon; when it has none, the first bar manager of the root, or a new one, is
/// assigned to its published BarManager property.</summary>
function FmrDesignEnsureManager(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): TFmrBarManager;
/// <summary>Caption without accelerator marks ('&amp;&amp;' becomes '&amp;').</summary>
function FmrDesignStripAccel(const ACaption: string): string;
/// <summary>Name of a component, or its class name when it has no name.</summary>
function FmrDesignObjectName(const AObject: TPersistent): string;
/// <summary>Text of an item for lists: 'Caption (Name)'.</summary>
function FmrDesignItemText(const AItem: TFmrBarItem): string;
/// <summary>The ribbon (structure object) that contains AObject (a tab, group, context group, link of a group or of
/// the QAT); nil when none.</summary>
function FmrDesignRibbonOf(const AObject: TPersistent): TFmxObject;
/// <summary>True when ALink lives in AOwner's structure (group of one of its tabs, or its QAT).</summary>
function FmrDesignIsLinkOf(const ALink: TFmrItemLink; const ARibbon: TFmxObject): Boolean;

implementation

uses
  Winapi.Windows, System.TypInfo, FMR.Ribbon.Gallery, FMR.Ribbon.ColorGallery;

{ TFmrDesignHub }

class destructor TFmrDesignHub.Destroy;
begin
  FreeAndNil(FListeners);
end;

class procedure TFmrDesignHub.AddListener(const AListener: IFmrDesignListener);
begin
  if FListeners = nil then
    FListeners := TList<IFmrDesignListener>.Create;
  if not FListeners.Contains(AListener) then
    FListeners.Add(AListener);
end;

class procedure TFmrDesignHub.RemoveListener(const AListener: IFmrDesignListener);
begin
  if FListeners <> nil then
    FListeners.Remove(AListener);
end;

class function TFmrDesignHub.Snapshot: TArray<IFmrDesignListener>;
begin
  if FListeners = nil then
    Result := nil
  else
    Result := FListeners.ToArray;
end;

class procedure TFmrDesignHub.ItemDeleted(const ARoot: TComponent; const AItem: TPersistent);
var
  L: IFmrDesignListener;
begin
  for L in Snapshot do
    if FListeners.Contains(L) then
      L.DesignItemDeleted(ARoot, AItem);
end;

class procedure TFmrDesignHub.ItemInserted(const ARoot: TComponent; const AItem: TPersistent);
var
  L: IFmrDesignListener;
begin
  for L in Snapshot do
    if FListeners.Contains(L) then
      L.DesignItemInserted(ARoot, AItem);
end;

class procedure TFmrDesignHub.ItemsModified(const ARoot: TComponent);
var
  L: IFmrDesignListener;
begin
  for L in Snapshot do
    if FListeners.Contains(L) then
      L.DesignItemsModified(ARoot);
end;

class procedure TFmrDesignHub.SelectionChanged(const ARoot: TComponent; const AObjects: TArray<TPersistent>);
var
  L: IFmrDesignListener;
begin
  for L in Snapshot do
    if FListeners.Contains(L) then
      L.DesignSelectionChanged(ARoot, AObjects);
end;

class procedure TFmrDesignHub.RootClosing(const ARoot: TComponent);
var
  L: IFmrDesignListener;
begin
  for L in Snapshot do
    if FListeners.Contains(L) then
      L.DesignRootClosing(ARoot);
end;

function FmrDesignMonitorPPI: Integer;
var
  M: TMonitor;
begin
  M := Screen.MonitorFromPoint(Mouse.CursorPos);
  if M <> nil then
    Result := M.PixelsPerInch
  else
    Result := Screen.PixelsPerInch;
  if Result <= 0 then
    Result := 96;
end;

procedure FmrDesignFinishForm(const AForm: TCustomForm);
var
  PPI, W, H: Integer;
begin
  PPI := FmrDesignMonitorPPI;
  if PPI <> 96 then
  begin
    W := AForm.ClientWidth;
    H := AForm.ClientHeight;
    AForm.ScaleForPPI(PPI);
    // Forms made with CreateNew do not always scale their own size.
    if AForm.ClientWidth = W then
      AForm.ClientWidth := MulDiv(W, PPI, 96);
    if AForm.ClientHeight = H then
      AForm.ClientHeight := MulDiv(H, PPI, 96);
  end;
  if Assigned(FmrDesignApplyTheme) then
    FmrDesignApplyTheme(AForm);
end;

{ TFmrItemDragObject }

constructor TFmrItemDragObject.CreateFor(const AControl: TControl; const AItems: TArray<TFmrBarItem>);
begin
  inherited Create(AControl);
  FItems := AItems;
end;

{ item classes }

function Info(const AClass: TFmrBarItemClass; const ACaption, ABaseName: string;
  const AGlyph: Cardinal): TFmrItemClassInfo;
begin
  Result.ItemClass := AClass;
  Result.Caption := ACaption;
  Result.BaseName := ABaseName;
  Result.Glyph := AGlyph;
end;

function FmrDesignItemClasses: TArray<TFmrItemClassInfo>;
begin
  Result := [
    Info(TFmrButtonItem, 'Button', 'Button', $E815),
    Info(TFmrSubItem, 'Sub Item (menu)', 'SubItem', $E700),
    Info(TFmrSeparatorItem, 'Separator', 'Separator', $E738),
    Info(TFmrStaticItem, 'Static Text', 'Static', $E8D2),
    Info(TFmrCheckItem, 'Check Box', 'Check', $E739),
    Info(TFmrColorItem, 'Color Picker', 'Color', $E790),
    Info(TFmrColorGalleryItem, 'Color Gallery (palettes, preview)', 'ColorGallery', $E790),
    Info(TFmrGalleryItem, 'Gallery', 'Gallery', $E8A9),
    Info(TFmrRibbonGalleryItem, 'Gallery (owner drawn)', 'Gallery', $E8A9),
    Info(TFmrEditItem, 'Edit Box', 'Edit', $E70F),
    Info(TFmrComboItem, 'Combo Box', 'Combo', $E70D),
    Info(TFmrSpinItem, 'Spin Edit', 'Spin', $ECE7),
    Info(TFmrTrackBarItem, 'Track Bar', 'TrackBar', $E9E9),
    Info(TFmrFontNameItem, 'Font Name', 'FontName', $E8D2),
    Info(TFmrAvatarItem, 'Account Picture (initials)', 'Avatar', $E77B),
    Info(TFmrControlItem, 'Control Container', 'Control', $E737)];
end;

function FmrDesignItemClassInfo(const AClass: TClass): TFmrItemClassInfo;
var
  I: TFmrItemClassInfo;
  Best: Integer;
  Depth: Integer;
  C: TClass;
begin
  Result := Info(TFmrBarItem, 'Item', 'Item', $E8B7);
  Best := MaxInt;
  for I in FmrDesignItemClasses do
    if AClass.InheritsFrom(I.ItemClass) then
    begin
      Depth := 0;
      C := AClass;
      while (C <> nil) and (C <> I.ItemClass) do
      begin
        Inc(Depth);
        C := C.ClassParent;
      end;
      if Depth < Best then
      begin
        Best := Depth;
        Result := I;
      end;
    end;
end;

function FmrDesignManagerOf(const ARibbon: TFmxObject): TFmrBarManager;
var
  O: IFmrRibbonStructureOwner;
begin
  if (ARibbon <> nil) and Supports(ARibbon, IFmrRibbonStructureOwner, O) then
    Result := O.GetBarManager
  else
    Result := nil;
end;

function FmrDesignEnsureManager(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): TFmrBarManager;
var
  I: Integer;
  Root: TComponent;
begin
  Result := FmrDesignManagerOf(ARibbon);
  if Result <> nil then
    Exit;
  Root := ABridge.Root;
  for I := 0 to Root.ComponentCount - 1 do
    if Root.Components[I] is TFmrBarManager then
    begin
      Result := TFmrBarManager(Root.Components[I]);
      Break;
    end;
  if Result = nil then
  begin
    if Root is TFmxObject then
      Result := TFmrBarManager(ABridge.CreateComponent(TFmrBarManager, TFmxObject(Root)))
    else
      Result := TFmrBarManager(ABridge.CreateComponent(TFmrBarManager, nil));
  end;
  if IsPublishedProp(ARibbon, 'BarManager') then
    SetObjectProp(ARibbon, 'BarManager', Result);
  ABridge.Modified;
end;

function NextCaption(const ARoot: TComponent; const ABase: string; const AClass: TClass): string;
var
  N, I: Integer;
  Used: TList<string>;
  S: string;
begin
  Used := TList<string>.Create;
  try
    if ARoot <> nil then
      for I := 0 to ARoot.ComponentCount - 1 do
        if ARoot.Components[I] is AClass then
        begin
          if ARoot.Components[I] is TFmrBarItem then
            S := TFmrBarItem(ARoot.Components[I]).Caption
          else if ARoot.Components[I] is TFmrRibbonStructureObject then
            S := TFmrRibbonStructureObject(ARoot.Components[I]).Caption
          else
            S := '';
          Used.Add(S);
        end;
    N := 1;
    repeat
      Result := ABase + ' ' + IntToStr(N);
      Inc(N);
    until not Used.Contains(Result);
  finally
    Used.Free;
  end;
end;

function FmrDesignNewItem(const ABridge: IFmrDesignBridge; const AManager: TFmrBarManager;
  const AClass: TFmrBarItemClass; const ACategory: string): TFmrBarItem;
var
  I: TFmrItemClassInfo;
begin
  Result := TFmrBarItem(ABridge.CreateComponent(AClass, AManager));
  I := FmrDesignItemClassInfo(AClass);
  if not (Result is TFmrSeparatorItem) and not (Result is TFmrControlItem) then
    Result.Caption := NextCaption(ABridge.Root, I.BaseName, AClass);
  if ACategory <> '' then
    Result.Category := ACategory;
end;

function FmrDesignNewTab(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject;
  const AContextGroup: TFmrRibbonContextGroup): TFmrRibbonTab;
begin
  // Appended as the last child: tab indexes count only tabs, other children of the ribbon do not matter.
  Result := TFmrRibbonTab(ABridge.CreateComponent(TFmrRibbonTab, ARibbon));
  Result.Caption := NextCaption(ABridge.Root, 'Tab', TFmrRibbonTab);
  Result.ContextGroup := AContextGroup;
end;

function FmrDesignNewGroup(const ABridge: IFmrDesignBridge; const ATab: TFmrRibbonTab;
  const AIndex: Integer): TFmrRibbonGroup;
begin
  Result := TFmrRibbonGroup(ABridge.CreateComponent(TFmrRibbonGroup, ATab));
  Result.Caption := NextCaption(ABridge.Root, 'Group', TFmrRibbonGroup);
  if (AIndex >= 0) and (AIndex < ATab.GroupCount - 1) then
    TFmrRibbonStructure.MoveGroup(Result, ATab, AIndex);
end;

function FmrDesignNewContextGroup(const ABridge: IFmrDesignBridge; const ARibbon: TFmxObject): TFmrRibbonContextGroup;
begin
  Result := TFmrRibbonContextGroup(ABridge.CreateComponent(TFmrRibbonContextGroup, ARibbon));
  Result.Caption := NextCaption(ABridge.Root, 'Context', TFmrRibbonContextGroup);
  Result.Color := $FF2B579A;
end;

function FmrDesignStripAccel(const ACaption: string): string;
var
  I: Integer;
begin
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

function FmrDesignObjectName(const AObject: TPersistent): string;
begin
  if AObject = nil then
    Result := ''
  else if (AObject is TComponent) and (TComponent(AObject).Name <> '') then
    Result := TComponent(AObject).Name
  else if AObject is TCollectionItem then
    Result := TCollectionItem(AObject).DisplayName
  else
    Result := AObject.ClassName;
end;

function FmrDesignItemText(const AItem: TFmrBarItem): string;
begin
  if AItem = nil then
    Exit('(no item)');
  if AItem.Caption = '' then
    Result := AItem.Name
  else
    Result := FmrDesignStripAccel(AItem.Caption) + '  (' + AItem.Name + ')';
end;

function FmrDesignRibbonOf(const AObject: TPersistent): TFmxObject;
var
  P: TPersistent;
  O: IFmrRibbonStructureOwner;
begin
  Result := nil;
  if AObject is TFmrItemLink then
  begin
    P := TFmrItemLink(AObject).LinksOwner;
    if P is TFmrRibbonGroup then
      Exit(FmrDesignRibbonOf(P));
    if (P is TFmrRibbonQuickAccessToolbar) and (TFmrRibbonQuickAccessToolbar(P).Owner is TFmxObject) then
      Exit(TFmxObject(TFmrRibbonQuickAccessToolbar(P).Owner));
    Exit;
  end;
  if AObject is TFmrRibbonStructureObject then
  begin
    O := TFmrRibbonStructureObject(AObject).StructureOwner;
    if O <> nil then
      Result := O.GetStructureObject;
  end;
end;

function FmrDesignIsLinkOf(const ALink: TFmrItemLink; const ARibbon: TFmxObject): Boolean;
begin
  Result := (ALink <> nil) and (FmrDesignRibbonOf(ALink) = ARibbon);
end;

end.
