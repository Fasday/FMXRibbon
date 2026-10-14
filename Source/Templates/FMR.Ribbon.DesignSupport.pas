{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Design-time contract between ribbon and IDE package  }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.DesignSupport;

/// Contract between the ribbon control (run-time package FMRRibbon) and the design-time package (dclFMRRibbon).
/// Nothing here uses IDE units, so the ribbon can implement it without depending on the design package.
///
/// - TFmrRibbon implements IFmrRibbonDesignSupport: hit testing of its lightweight elements, bounds of structure
///   objects, drop targets and design feedback (insertion mark, selection frames). All coordinates are local
///   coordinates of the ribbon control: at design time the caption row and the tab row always stay inside the
///   ribbon (the frame is not hooked).
/// - The design package installs one IFmrRibbonDesignHook (TFmrRibbonDesignHooks.Hook) while it is loaded. At design
///   time the ribbon forwards its mouse events to the hook instead of running commands; the hook selects objects in
///   the IDE, switches tabs and drags links, groups and tabs.
///
/// The FMX form designer sends mouse events to a control at design time only when the control is
/// design-interactive (TControl.FDesignInteractive = True, as TTabItem and TFmrRibbonBackstageView do) and is the
/// control under the mouse; the ribbon's parts must therefore not catch the mouse at design time (Locked = True or
/// HitTest = False on the parts), see Docs\DESIGNTIME.md.

interface

{$SCOPEDENUMS ON}

uses
  System.Classes, System.Types, System.UITypes, FMX.Types, FMX.Controls, FMR.Bars, FMR.Ribbon.Structure;

type
  /// <summary>Kind of the ribbon element under a point at design time.</summary>
  TFmrDesignHitKind = (
    /// <summary>Outside the ribbon.</summary>
    None,
    /// <summary>A part of the ribbon that has no structure object (empty tab row, caption, empty body).</summary>
    Ribbon,
    ApplicationButton,
    Tab,
    /// <summary>Header of a contextual tab group in the caption row.</summary>
    ContextGroup,
    /// <summary>A group of the active tab (frame, caption, free space between links).</summary>
    Group,
    /// <summary>The dialog launcher of a group.</summary>
    GroupLauncher,
    /// <summary>The drop-down button of a collapsed group.</summary>
    CollapsedGroup,
    /// <summary>A link of a group.</summary>
    Link,
    /// <summary>A link of the quick access toolbar.</summary>
    QATLink,
    /// <summary>The quick access toolbar outside its links.</summary>
    QAT);

  /// <summary>Result of IFmrRibbonDesignSupport.DesignHitTest.</summary>
  TFmrDesignHit = record
    Kind: TFmrDesignHitKind;
    /// <summary>Tab of the element (the active tab for groups and links of groups).</summary>
    Tab: TFmrRibbonTab;
    Group: TFmrRibbonGroup;
    ContextGroup: TFmrRibbonContextGroup;
    /// <summary>Link under the point (Link, QATLink).</summary>
    Link: TFmrItemLink;
    /// <summary>Bounds of the element in local coordinates of the ribbon.</summary>
    Bounds: TRectF;
    class function Empty: TFmrDesignHit; static;
    /// <summary>Item of Link (nil when no link).</summary>
    function Item: TFmrBarItem;
  end;

  /// <summary>What is being dragged on the ribbon.</summary>
  TFmrDesignDragKind = (
    None,
    /// <summary>A link (moved between groups or into the QAT) or an item (a new link is created).</summary>
    Link,
    /// <summary>A group (moved inside its tab or into another tab).</summary>
    Group,
    /// <summary>A tab (reordered in the tab row).</summary>
    Tab);

  /// <summary>Where a dragged object lands; returned by IFmrRibbonDesignSupport.DesignDropTarget.</summary>
  TFmrDesignDropTarget = record
    Kind: TFmrDesignDragKind;
    /// <summary>Link: the collection the link goes into (a group's or the QAT's ItemLinks).</summary>
    Links: TFmrItemLinks;
    /// <summary>Group: the tab the group goes into.</summary>
    Tab: TFmrRibbonTab;
    /// <summary>Insertion index: links before which the link goes (Links.Count = append); groups among the groups
    /// of Tab; tabs among the tabs (TFmrRibbonStructure.MoveTab).</summary>
    Index: Integer;
    /// <summary>Insertion mark (a thin vertical bar) in local coordinates of the ribbon; empty when nothing is
    /// painted.</summary>
    Mark: TRectF;
    class function Empty: TFmrDesignDropTarget; static;
    function IsValid: Boolean;
  end;

  /// <summary>Implemented by TFmrRibbon for the design package. Points and rectangles are in local coordinates of
  /// the ribbon control. Every method brings the layout up to date first (the ribbon normally lays out on idle).
  /// </summary>
  IFmrRibbonDesignSupport = interface
    ['{0D21AB53-4BD9-421C-B29B-FB924957A1E5}']
    /// <summary>The element under ALocalPoint.</summary>
    function DesignHitTest(const ALocalPoint: TPointF): TFmrDesignHit;
    /// <summary>Bounds of a shown tab, context group header, group (of the active tab), link of a shown group or
    /// of the QAT, or of the first link to an item; an empty rectangle when the object is not shown.</summary>
    function DesignObjectBounds(const AObject: TPersistent): TRectF;
    /// <summary>Where an object of AKind dropped at ALocalPoint goes: links into the group under the point (or the
    /// QAT), before the link whose center is right of the point; groups into the active tab (or the tab under the
    /// point in the tab row); tabs into the tab row. Kind = None when the point accepts nothing.</summary>
    function DesignDropTarget(const ALocalPoint: TPointF; const AKind: TFmrDesignDragKind): TFmrDesignDropTarget;
    /// <summary>Shows the insertion mark of ATarget (TFmrDesignDropTarget.Empty hides it).</summary>
    procedure DesignShowDropTarget(const ATarget: TFmrDesignDropTarget);
    /// <summary>Objects selected in the IDE (tabs, groups, links' items, context groups): the ribbon frames the
    /// shown ones with a dashed rectangle. Empty array: no frames.</summary>
    procedure DesignSetSelection(const AObjects: TArray<TPersistent>);
    /// <summary>Makes ATab the active tab at design time (no events, no popups) and repaints.</summary>
    procedure DesignSelectTab(const ATab: TFmrRibbonTab);
  end;

  /// <summary>Implemented by the design package. TFmrRibbon calls it from MouseDown/MouseMove/MouseUp/DblClick
  /// while csDesigning is set and TFmrRibbonDesignHooks.Hook is assigned; True means handled (the ribbon does
  /// nothing else). ARibbon is the TFmrRibbon (typed TControl so that this unit does not use FMR.Ribbon).</summary>
  IFmrRibbonDesignHook = interface
    ['{FDA28767-D47A-406B-A0E1-BA3BA6202369}']
    function DesignMouseDown(const ARibbon: TControl; const AButton: TMouseButton; const AShift: TShiftState;
      const ALocalPoint: TPointF): Boolean;
    function DesignMouseMove(const ARibbon: TControl; const AShift: TShiftState; const ALocalPoint: TPointF): Boolean;
    function DesignMouseUp(const ARibbon: TControl; const AButton: TMouseButton; const AShift: TShiftState;
      const ALocalPoint: TPointF): Boolean;
    function DesignDblClick(const ARibbon: TControl; const ALocalPoint: TPointF): Boolean;
    /// <summary>The ribbon is destroyed: forget it.</summary>
    procedure DesignRibbonDestroying(const ARibbon: TControl);
  end;

  /// <summary>Holder of the design hook. Set by the design package when it is loaded and cleared when it is
  /// unloaded (the run-time package stays loaded in the IDE).</summary>
  TFmrRibbonDesignHooks = class sealed
  private
    class var FHook: IFmrRibbonDesignHook;
  public
    /// <summary>The hook when AObject is being designed and a hook is installed, otherwise nil.</summary>
    class function HookFor(const AObject: TComponent): IFmrRibbonDesignHook; static;
    class property Hook: IFmrRibbonDesignHook read FHook write FHook;
  end;

implementation

{ TFmrDesignHit }

class function TFmrDesignHit.Empty: TFmrDesignHit;
begin
  Result := Default(TFmrDesignHit);
  Result.Kind := TFmrDesignHitKind.None;
  Result.Bounds := TRectF.Empty;
end;

function TFmrDesignHit.Item: TFmrBarItem;
begin
  if Link <> nil then
    Result := Link.Item
  else
    Result := nil;
end;

{ TFmrDesignDropTarget }

class function TFmrDesignDropTarget.Empty: TFmrDesignDropTarget;
begin
  Result := Default(TFmrDesignDropTarget);
  Result.Kind := TFmrDesignDragKind.None;
  Result.Index := -1;
  Result.Mark := TRectF.Empty;
end;

function TFmrDesignDropTarget.IsValid: Boolean;
begin
  case Kind of
    TFmrDesignDragKind.Link:
      Result := Links <> nil;
    TFmrDesignDragKind.Group:
      Result := Tab <> nil;
    TFmrDesignDragKind.Tab:
      Result := Index >= 0;
  else
    Result := False;
  end;
end;

{ TFmrRibbonDesignHooks }

class function TFmrRibbonDesignHooks.HookFor(const AObject: TComponent): IFmrRibbonDesignHook;
begin
  if (AObject <> nil) and (csDesigning in AObject.ComponentState) and
    not (csDestroying in AObject.ComponentState) then
    Result := FHook
  else
    Result := nil;
end;

end.
