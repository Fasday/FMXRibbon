{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design time: in-form interaction (phase B)           }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Design.Interactive;

/// IDE side of the in-form design of the ribbon, written against FMR.Ribbon.DesignSupport:
///
/// - TFmrRibbonDesignController (installed as TFmrRibbonDesignHooks.Hook): a click on the ribbon in the form
///   designer selects the tab (and activates it), group, contextual group or item under the mouse (Alt+click: the
///   link itself); dragging a link, group or tab moves it (Ctrl: copies a link) with an insertion mark; double click
///   opens the OnClick handler of an item, the dialog launcher handler of a group, the structure editor on a tab.
///   It also accepts items dragged from the items editor onto the ribbon (IFmrExternalItemDrop).
/// - FmrDesignSyncSelection (called for every selection change of the designer): the ribbon shows the tab of the
///   selected tab, group, link or item and frames the selected objects. This part works without the design hooks:
///   when the ribbon does not implement IFmrRibbonDesignSupport, the tab is activated through
///   IFmrRibbonStructureOwner.SetActiveTab.
///
/// Nothing here uses IDE units: the designer is reached through IFmrDesignBridge (FmrDesignBridgeFor is set by the
/// IDE part).

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Generics.Collections, FMX.Types,
  FMX.Controls, FMR.Bars, FMR.Ribbon.Structure, FMR.Ribbon.DesignSupport, FMR.Ribbon.Design.Bridge,
  FMR.Ribbon.Design.ItemsEditor;

type
  /// <summary>Returns the designer bridge of the root that owns AComponent (nil when it is not being designed).
  /// </summary>
  TFmrBridgeFactory = reference to function(const AComponent: TComponent): IFmrDesignBridge;

  /// <summary>The design hook of the ribbon and the drop target of items dragged from the items editor.</summary>
  TFmrRibbonDesignController = class(TInterfacedObject, IFmrRibbonDesignHook, IFmrExternalItemDrop)
  private
    FPressRibbon: TControl;
    FPressPoint: TPointF;
    FDragKind: TFmrDesignDragKind;
    FDragObject: TObject;
    FDragging: Boolean;
    FTarget: TFmrDesignDropTarget;
    FFeedbackRibbon: TControl;
    procedure ResetDrag;
    procedure ClearFeedback;
    procedure SelectLater(const ABridge: IFmrDesignBridge; const AObject: TPersistent);
    procedure ApplyMove(const ARibbon: TControl; const ACopy: Boolean);
    function RibbonAtScreen(const AScreenPoint: TPoint; out ARibbon: TControl; out ALocal: TPointF): Boolean;
  public
    { IFmrRibbonDesignHook }
    function DesignMouseDown(const ARibbon: TControl; const AButton: TMouseButton; const AShift: TShiftState;
      const ALocalPoint: TPointF): Boolean;
    function DesignMouseMove(const ARibbon: TControl; const AShift: TShiftState; const ALocalPoint: TPointF): Boolean;
    function DesignMouseUp(const ARibbon: TControl; const AButton: TMouseButton; const AShift: TShiftState;
      const ALocalPoint: TPointF): Boolean;
    function DesignDblClick(const ARibbon: TControl; const ALocalPoint: TPointF): Boolean;
    procedure DesignRibbonDestroying(const ARibbon: TControl);
    { IFmrExternalItemDrop }
    function ExternalDragOver(const AScreenPoint: TPoint; const AItems: TArray<TFmrBarItem>): Boolean;
    function ExternalDrop(const AScreenPoint: TPoint; const AItems: TArray<TFmrBarItem>): Boolean;
    procedure ExternalDragCancel;
  end;

var
  /// <summary>Bridge factory (set by the IDE part of the design package).</summary>
  FmrDesignBridgeFor: TFmrBridgeFactory;

/// <summary>Installs the design hook and the external drop handler.</summary>
procedure FmrInstallDesignHooks;
/// <summary>Removes them (the design package is unloaded).</summary>
procedure FmrRemoveDesignHooks;
/// <summary>The tab of ARibbon that shows AObject (a tab, group, link, item, context group); for an item the active
/// tab when one of its links is there, otherwise the first tab with a link to it. nil when none.</summary>
function FmrDesignTabOf(const ARibbon: TFmxObject; const AObject: TPersistent): TFmrRibbonTab;
/// <summary>Shows the tab of the selection in every ribbon of ARoot and frames the selected objects.</summary>
procedure FmrDesignSyncSelection(const ARoot: TComponent; const AObjects: TArray<TPersistent>);

implementation

uses
  Winapi.Windows, System.Math, FMX.Forms, FMX.Platform.Win, FMR.Ribbon.Design.StructureEditor;

var
  GController: TFmrRibbonDesignController;
  GControllerIntf: IFmrRibbonDesignHook;

procedure FmrInstallDesignHooks;
begin
  if GController = nil then
  begin
    GController := TFmrRibbonDesignController.Create;
    GControllerIntf := GController;
  end;
  TFmrRibbonDesignHooks.Hook := GControllerIntf;
  FmrExternalItemDrop := GController;
end;

procedure FmrRemoveDesignHooks;
begin
  if (GControllerIntf <> nil) and (TFmrRibbonDesignHooks.Hook = GControllerIntf) then
    TFmrRibbonDesignHooks.Hook := nil;
  FmrExternalItemDrop := nil;
  GController := nil;
  GControllerIntf := nil;
end;

function BridgeFor(const AComponent: TComponent): IFmrDesignBridge;
begin
  if Assigned(FmrDesignBridgeFor) and (AComponent <> nil) then
    Result := FmrDesignBridgeFor(AComponent)
  else
    Result := nil;
end;

function FmrDesignTabOf(const ARibbon: TFmxObject; const AObject: TPersistent): TFmrRibbonTab;
var
  P: TPersistent;
  Item: TFmrBarItem;
  I: Integer;
  T: TFmrRibbonTab;
  Owner: IFmrRibbonStructureOwner;
  Tabs: TArray<TFmrRibbonTab>;
begin
  Result := nil;
  if (ARibbon = nil) or (AObject = nil) then
    Exit;
  if AObject is TFmrRibbonTab then
    T := TFmrRibbonTab(AObject)
  else if AObject is TFmrRibbonGroup then
    T := TFmrRibbonGroup(AObject).Tab
  else if AObject is TFmrRibbonContextGroup then
  begin
    Tabs := TFmrRibbonContextGroup(AObject).Tabs;
    if Tabs <> nil then
      T := Tabs[0]
    else
      T := nil;
  end
  else if AObject is TFmrItemLink then
  begin
    P := TFmrItemLink(AObject).LinksOwner;
    if P is TFmrRibbonGroup then
      T := TFmrRibbonGroup(P).Tab
    else
      T := nil;
  end
  else if AObject is TFmrBarItem then
  begin
    Item := TFmrBarItem(AObject);
    T := nil;
    Supports(ARibbon, IFmrRibbonStructureOwner, Owner);
    for I := 0 to Item.LinkCount - 1 do
    begin
      P := Item.Links[I].LinksOwner;
      if (P is TFmrRibbonGroup) and (TFmrRibbonGroup(P).Tab <> nil) and
        (TFmrRibbonGroup(P).Tab.Parent = ARibbon) then
      begin
        if (Owner <> nil) and (Owner.GetActiveTab = TFmrRibbonGroup(P).Tab) then
          Exit(TFmrRibbonGroup(P).Tab);
        if T = nil then
          T := TFmrRibbonGroup(P).Tab;
      end;
    end;
  end
  else
    T := nil;
  if (T <> nil) and (T.Parent = ARibbon) then
    Result := T;
end;

procedure FmrDesignSyncSelection(const ARoot: TComponent; const AObjects: TArray<TPersistent>);
var
  I: Integer;
  C: TComponent;
  Owner: IFmrRibbonStructureOwner;
  DS: IFmrRibbonDesignSupport;
  Tab: TFmrRibbonTab;
  P: TPersistent;
  Mine: TArray<TPersistent>;
begin
  if ARoot = nil then
    Exit;
  for I := 0 to ARoot.ComponentCount - 1 do
  begin
    C := ARoot.Components[I];
    if not (C is TFmxObject) or not Supports(C, IFmrRibbonStructureOwner, Owner) or
      (csDestroying in C.ComponentState) then
      Continue;
    Tab := nil;
    Mine := nil;
    for P in AObjects do
    begin
      if P = nil then
        Continue;
      if (Tab = nil) then
        Tab := FmrDesignTabOf(TFmxObject(C), P);
      if (FmrDesignRibbonOf(P) = C) or ((P is TFmrBarItem) and (FmrDesignTabOf(TFmxObject(C), P) <> nil)) then
        Mine := Mine + [P];
    end;
    try
      if Supports(C, IFmrRibbonDesignSupport, DS) then
      begin
        if (Tab <> nil) and (Owner.GetActiveTab <> Tab) then
          DS.DesignSelectTab(Tab);
        DS.DesignSetSelection(Mine);
      end
      else if (Tab <> nil) and (Owner.GetActiveTab <> Tab) then
        Owner.SetActiveTab(Tab);
    except
      // A ribbon that cannot show the selection must never break the designer.
    end;
  end;
end;

{ TFmrRibbonDesignController }

procedure TFmrRibbonDesignController.ResetDrag;
begin
  FPressRibbon := nil;
  FDragKind := TFmrDesignDragKind.None;
  FDragObject := nil;
  FDragging := False;
  FTarget := TFmrDesignDropTarget.Empty;
end;

procedure TFmrRibbonDesignController.ClearFeedback;
var
  DS: IFmrRibbonDesignSupport;
begin
  if (FFeedbackRibbon <> nil) and Supports(FFeedbackRibbon, IFmrRibbonDesignSupport, DS) then
    DS.DesignShowDropTarget(TFmrDesignDropTarget.Empty);
  FFeedbackRibbon := nil;
end;

procedure TFmrRibbonDesignController.SelectLater(const ABridge: IFmrDesignBridge; const AObject: TPersistent);
var
  Bridge: IFmrDesignBridge;
  Obj: TPersistent;
  Comp: TComponent;
  Notifier: TComponent;
begin
  if (ABridge = nil) or (AObject = nil) then
    Exit;
  Bridge := ABridge;
  Obj := AObject;
  // The designer processes the click after the control: select once it is done. A component going away in
  // between is detected with the component of the object (the object itself or the owner of a link).
  if Obj is TComponent then
    Comp := TComponent(Obj)
  else if (Obj is TFmrItemLink) and (TFmrItemLink(Obj).Item <> nil) then
    Comp := TFmrItemLink(Obj).Item
  else
    Comp := nil;
  Notifier := Comp;
  TThread.ForceQueue(nil,
    procedure
    begin
      if (Notifier <> nil) and (csDestroying in Notifier.ComponentState) then
        Exit;
      Bridge.SelectObjects([Obj]);
    end);
end;

function TFmrRibbonDesignController.DesignMouseDown(const ARibbon: TControl; const AButton: TMouseButton;
  const AShift: TShiftState; const ALocalPoint: TPointF): Boolean;
var
  DS: IFmrRibbonDesignSupport;
  Hit: TFmrDesignHit;
  Bridge: IFmrDesignBridge;
  Sel: TPersistent;
begin
  Result := False;
  ResetDrag;
  ClearFeedback;
  if not Supports(ARibbon, IFmrRibbonDesignSupport, DS) then
    Exit;
  Bridge := BridgeFor(ARibbon);
  if Bridge = nil then
    Exit;
  Hit := DS.DesignHitTest(ALocalPoint);
  case Hit.Kind of
    TFmrDesignHitKind.None:
      Exit;
    TFmrDesignHitKind.Tab:
      begin
        DS.DesignSelectTab(Hit.Tab);
        Sel := Hit.Tab;
        FDragKind := TFmrDesignDragKind.Tab;
        FDragObject := Hit.Tab;
      end;
    TFmrDesignHitKind.ContextGroup:
      Sel := Hit.ContextGroup;
    TFmrDesignHitKind.Group, TFmrDesignHitKind.GroupLauncher, TFmrDesignHitKind.CollapsedGroup:
      begin
        Sel := Hit.Group;
        FDragKind := TFmrDesignDragKind.Group;
        FDragObject := Hit.Group;
      end;
    TFmrDesignHitKind.Link, TFmrDesignHitKind.QATLink:
      begin
        if (ssAlt in AShift) or (Hit.Item = nil) then
          Sel := Hit.Link
        else
          Sel := Hit.Item;
        FDragKind := TFmrDesignDragKind.Link;
        FDragObject := Hit.Link;
      end;
  else
    Sel := ARibbon;
  end;
  if AButton = TMouseButton.mbLeft then
  begin
    FPressRibbon := ARibbon;
    FPressPoint := ALocalPoint;
  end
  else
  begin
    ResetDrag;
    // Right button: the designer's context menu should show the verbs of the object under the mouse.
    Bridge.SelectObjects([Sel]);
  end;
  SelectLater(Bridge, Sel);
  Result := True;
end;

function TFmrRibbonDesignController.DesignMouseMove(const ARibbon: TControl; const AShift: TShiftState;
  const ALocalPoint: TPointF): Boolean;
var
  DS: IFmrRibbonDesignSupport;
begin
  Result := False;
  if (FPressRibbon <> ARibbon) or (FDragObject = nil) or not (ssLeft in AShift) then
    Exit;
  if not Supports(ARibbon, IFmrRibbonDesignSupport, DS) then
    Exit;
  if not FDragging and (FPressPoint.Distance(ALocalPoint) < 5) then
    Exit(True);
  FDragging := True;
  FTarget := DS.DesignDropTarget(ALocalPoint, FDragKind);
  DS.DesignShowDropTarget(FTarget);
  FFeedbackRibbon := ARibbon;
  Result := True;
end;

procedure TFmrRibbonDesignController.ApplyMove(const ARibbon: TControl; const ACopy: Boolean);
var
  Link: TFmrItemLink;
  Group: TFmrRibbonGroup;
  Tab: TFmrRibbonTab;
  Index: Integer;
begin
  Index := FTarget.Index;
  case FDragKind of
    TFmrDesignDragKind.Link:
      begin
        Link := TFmrItemLink(FDragObject);
        if (Link.Item <> nil) and not Link.Item.CanLinkInto(FTarget.Links) then
          Exit;
        if ACopy then
          TFmrRibbonStructure.CopyLink(Link, FTarget.Links, Index)
        else
        begin
          if (Link.Collection = FTarget.Links) and (Link.Index < Index) then
            Dec(Index);
          if Index >= FTarget.Links.Count then
            Index := -1;
          TFmrRibbonStructure.MoveLink(Link, FTarget.Links, Index);
        end;
      end;
    TFmrDesignDragKind.Group:
      begin
        Group := TFmrRibbonGroup(FDragObject);
        if (Group.Tab = FTarget.Tab) and (Index > Group.GroupIndex) then
          Dec(Index);
        TFmrRibbonStructure.MoveGroup(Group, FTarget.Tab, Index);
      end;
    TFmrDesignDragKind.Tab:
      begin
        Tab := TFmrRibbonTab(FDragObject);
        if Index > Tab.TabIndex then
          Dec(Index);
        TFmrRibbonStructure.MoveTab(Tab, Index);
      end;
  end;
end;

function TFmrRibbonDesignController.DesignMouseUp(const ARibbon: TControl; const AButton: TMouseButton;
  const AShift: TShiftState; const ALocalPoint: TPointF): Boolean;
var
  Bridge: IFmrDesignBridge;
begin
  try
    if FDragging and (FPressRibbon = ARibbon) then
    begin
      ClearFeedback;
      if FTarget.IsValid and (FTarget.Kind = FDragKind) then
      begin
        ApplyMove(ARibbon, ssCtrl in AShift);
        Bridge := BridgeFor(ARibbon);
        if Bridge <> nil then
          Bridge.Modified;
      end;
      Result := True;
    end
    else
      Result := FPressRibbon = ARibbon;
  finally
    ResetDrag;
  end;
end;

function TFmrRibbonDesignController.DesignDblClick(const ARibbon: TControl; const ALocalPoint: TPointF): Boolean;
var
  DS: IFmrRibbonDesignSupport;
  Hit: TFmrDesignHit;
  Bridge: IFmrDesignBridge;
  Editor: TFmrStructureEditorForm;
begin
  Result := False;
  ResetDrag;
  if not Supports(ARibbon, IFmrRibbonDesignSupport, DS) then
    Exit;
  Bridge := BridgeFor(ARibbon);
  if Bridge = nil then
    Exit;
  Hit := DS.DesignHitTest(ALocalPoint);
  case Hit.Kind of
    TFmrDesignHitKind.Link, TFmrDesignHitKind.QATLink:
      if Hit.Item <> nil then
      begin
        Bridge.ShowEvent(Hit.Item, 'OnClick');
        Result := True;
      end;
    TFmrDesignHitKind.GroupLauncher:
      begin
        Bridge.ShowEvent(Hit.Group, 'OnDialogLauncherClick');
        Result := True;
      end;
    TFmrDesignHitKind.Tab, TFmrDesignHitKind.Group, TFmrDesignHitKind.ContextGroup, TFmrDesignHitKind.Ribbon:
      begin
        Editor := FmrShowStructureEditor(Bridge, ARibbon);
        Result := Editor <> nil;
      end;
  end;
end;

procedure TFmrRibbonDesignController.DesignRibbonDestroying(const ARibbon: TControl);
begin
  if FPressRibbon = ARibbon then
    ResetDrag;
  if FFeedbackRibbon = ARibbon then
    FFeedbackRibbon := nil;
end;

function TFmrRibbonDesignController.RibbonAtScreen(const AScreenPoint: TPoint; out ARibbon: TControl;
  out ALocal: TPointF): Boolean;
var
  I, J: Integer;
  Form: TCommonCustomForm;
  Wnd, Under: HWND;
  C: TComponent;
  Scale: Single;
  P: TPointF;
  Sp: TPoint;
begin
  Result := False;
  ARibbon := nil;
  Under := WindowFromPoint(AScreenPoint);
  for I := 0 to Screen.FormCount - 1 do
  begin
    Form := Screen.Forms[I];
    if (Form.Handle = nil) or not (csDesigning in Form.ComponentState) then
      Continue;
    Wnd := FormToHWND(Form);
    if (Wnd = 0) or ((Under <> Wnd) and not IsChild(Wnd, Under)) then
      Continue;
    Sp := AScreenPoint;
    Winapi.Windows.ScreenToClient(Wnd, Sp);
    Scale := Form.Handle.Scale;
    if Scale <= 0 then
      Scale := 1;
    P := PointF(Sp.X / Scale, Sp.Y / Scale);
    for J := 0 to Form.ComponentCount - 1 do
    begin
      C := Form.Components[J];
      if (C is TControl) and Supports(C, IFmrRibbonDesignSupport) and TControl(C).Visible and
        TControl(C).AbsoluteRect.Contains(P) then
      begin
        ARibbon := TControl(C);
        ALocal := ARibbon.AbsoluteToLocal(P);
        Exit(True);
      end;
    end;
  end;
end;

function TFmrRibbonDesignController.ExternalDragOver(const AScreenPoint: TPoint;
  const AItems: TArray<TFmrBarItem>): Boolean;
var
  Ribbon: TControl;
  Local: TPointF;
  DS: IFmrRibbonDesignSupport;
  Target: TFmrDesignDropTarget;
begin
  Result := False;
  try
    if not RibbonAtScreen(AScreenPoint, Ribbon, Local) or not Supports(Ribbon, IFmrRibbonDesignSupport, DS) then
    begin
      ClearFeedback;
      Exit;
    end;
    if (FFeedbackRibbon <> nil) and (FFeedbackRibbon <> Ribbon) then
      ClearFeedback;
    Target := DS.DesignDropTarget(Local, TFmrDesignDragKind.Link);
    DS.DesignShowDropTarget(Target);
    FFeedbackRibbon := Ribbon;
    Result := Target.IsValid;
  except
    Result := False;
  end;
end;

function TFmrRibbonDesignController.ExternalDrop(const AScreenPoint: TPoint;
  const AItems: TArray<TFmrBarItem>): Boolean;
var
  Ribbon: TControl;
  Local: TPointF;
  DS: IFmrRibbonDesignSupport;
  Target: TFmrDesignDropTarget;
  Item: TFmrBarItem;
  Index: Integer;
  Bridge: IFmrDesignBridge;
  Manager: TFmrBarManager;
begin
  Result := False;
  ClearFeedback;
  if not RibbonAtScreen(AScreenPoint, Ribbon, Local) or not Supports(Ribbon, IFmrRibbonDesignSupport, DS) then
    Exit;
  Target := DS.DesignDropTarget(Local, TFmrDesignDragKind.Link);
  DS.DesignShowDropTarget(TFmrDesignDropTarget.Empty);
  if not Target.IsValid or (Target.Kind <> TFmrDesignDragKind.Link) then
    Exit;
  Manager := FmrDesignManagerOf(Ribbon);
  Index := Target.Index;
  for Item in AItems do
    if (Item.Manager = Manager) and Item.CanLinkInto(Target.Links) then
    begin
      Target.Links.InsertItem(EnsureRange(Index, 0, Target.Links.Count), Item);
      Inc(Index);
      Result := True;
    end;
  if Result then
  begin
    Bridge := BridgeFor(Ribbon);
    if Bridge <> nil then
      Bridge.Modified;
  end;
end;

procedure TFmrRibbonDesignController.ExternalDragCancel;
begin
  ClearFeedback;
end;

initialization

finalization
  FmrRemoveDesignHooks;

end.
