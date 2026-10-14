# FMR Ribbon — design time (packages, IDE editors, templates)

This file describes the packages, how to install them in RAD Studio 13 (37.0), every design-time editor, the run-time
template builder and the contract the ribbon must implement for in-form design (phase B).

## Packages

| File | Content |
|---|---|
| `Packages\FMRRibbon.dpk` / `.dproj` | Runtime package (`{$RUNONLY}`, `{$LIBSUFFIX AUTO}` → `FMRRibbon370.bpl`): every unit of `Source\Core`, `Source\Themes`, `Source\Frame`, `Source\Extras`, `Source\Ribbon`, `Source\Templates`. Requires `rtl`, `fmx`, `Skia.Package.RTL`, `Skia.Package.FMX` (`FMR.Bars.Images` renders SVG with Skia). Windows only (Win32, Win64): `FMR.Frame.Win`, `FMR.Ribbon.Fonts.Win`, `FMR.Ribbon.UIA.Win` |
| `Packages\dclFMRRibbon.dpk` / `.dproj` | Design package (`{$DESIGNONLY}` → `dclFMRRibbon370.bpl`): `Source\Design\*`. Requires `rtl`, `vcl`, `vclimg`, `designide`, `fmx`, `FMRRibbon`. Component icons: `{$R '..\Source\Design\FMR.Ribbon.Reg.dcr'}` |
| `Packages\FMRRibbon.groupproj` | Both projects (the design package depends on the runtime package) |
| `Packages\Icons\*.png`, `FMR.Ribbon.Reg.rc` | Palette icons, 16/24/32 px PNG (`RCDATA <CLASS>16_PNG / <CLASS>_PNG / <CLASS>32_PNG`), drawn by the build script |
| `tools\build-packages.ps1` | Command-line build, icons, `.dproj` generation, optional install |

**When a unit is added** to one of the runtime folders, add it to the `contains` clause of `FMRRibbon.dpk` and run
`.\tools\build-packages.ps1 -UpdateProjects` (the `.dproj` files are generated from the `.dpk` files). The build
script refuses to build when a unit of those folders is missing from the package (it would be implicitly imported, or
missing in the IDE).

### Building

```powershell
.\tools\build-packages.ps1                         # Win32 (dcc32) + Win64 (dcc64), Release
.\tools\build-packages.ps1 -Platform Win32 -Config Debug
.\tools\build-packages.ps1 -UpdateProjects         # regenerate the .dproj files, then build
.\tools\build-packages.ps1 -Icons                  # redraw the icon PNGs and rebuild the .dcr
.\tools\build-packages.ps1 -Exclude FMR.Ribbon.X   # leave out a work-in-progress unit nothing uses
```

Output: BPL in `bin\packages\<Platform>\` (`FMRRibbon370.bpl`, `dclFMRRibbon370.bpl`), DCP in `dcu\packages\<Platform>\`,
DCU in `dcu\packages\<Platform>\<Package>\`. Compiler errors, warnings and hints are printed; "implicitly imported"
warnings fail the build. In the IDE, open `Packages\FMRRibbon.groupproj` and build both projects (the `.dproj` files
use the same output folders).

### Installing in the IDE

RAD Studio 13 has a 32-bit IDE (`bin\bds.exe`) and a 64-bit IDE (`bin64\bds.exe`); each loads design packages of its
own bitness: the Win32 packages for the classic IDE, the Win64 packages for the 64-bit IDE.

1. Build: `.\tools\build-packages.ps1` (or build the group project in the IDE for Win32 and Win64).
2. The IDE must find `FMRRibbon370.bpl` when it loads the design package: copy the BPLs to the public BPL folder
   (`.\tools\build-packages.ps1 -CopyToBplDir` copies Win32 to `C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl`
   and Win64 to `...\Bpl\Win64`), or add `bin\packages\Win32` (`Win64`) to the system PATH.
3. Install: *Component > Install Packages > Add...* and choose `dclFMRRibbon370.bpl` (Win32 BPL in the 32-bit IDE,
   Win64 BPL in the 64-bit IDE), or `.\tools\build-packages.ps1 -CopyToBplDir -Install`, which registers the design
   package under `HKCU\Software\Embarcadero\BDS\37.0\Known Packages` (and `Known Packages x64`); restart the IDE.
4. Library path (*Tools > Options > Language > Delphi > Library*), per platform: either the source folders
   (`Source\Core;Source\Themes;Source\Frame;Source\Extras;Source\Ribbon;Source\Templates` — what `build.ps1` does) or
   the compiled units `dcu\packages\<Platform>\FMRRibbon` (Release DCUs of the package). Applications built with
   runtime packages use `FMRRibbon` (+ `rtl;fmx;Skia.Package.RTL;Skia.Package.FMX`).
5. Programs that draw SVG icons need `sk4d.dll` next to the exe (`build.ps1` copies it); the IDE has its own.

The palette page is **FMR Ribbon**. Checked without the IDE: both packages load with `LoadPackage` on Win32 and Win64
(`tools\DesignPreview\PackageLoadTest.dpr`: classes registered, `Register` exported, clean unload).

## Registration (`FMR.Ribbon.Reg`)

| | Classes |
|---|---|
| Palette | `TFmrRibbon`, `TFmrBarManager`, `TFmrFormFrame`, `TFmrPopupMenu`, `TFmrRibbonBackstageView`, `TFmrBackstageTab`, `TFmrBackstageButton`, `TFmrBackstageHeader`, `TFmrBackstageLabel`, `TFmrBackstageTile`, `TFmrBackstageGalleryList`, `TFmrStatusBar`, `TFmrStatusBarPanel`, `TFmrCaptionButton`, `TFmrCaptionTitle` |
| No icon (created by the editors and the Structure View, streamed) | `TFmrRibbonTab`, `TFmrRibbonGroup`, `TFmrRibbonContextGroup`, every bar item class (button, sub item, separator, static, control, edit, combo, spin, track bar, font name, check, color, gallery) |
| Class group | `GroupDescendentsWith(TFmrFormFrame, FMX.Controls.TControl)`: the frame (a plain `TComponent`) appears for FireMonkey forms only. Every other class is a `TFmxObject` and belongs to the FMX group already |
| Custom module | `RegisterCustomModule(TFmrForm, TCustomModule)`: forms that inherit `TFmrForm` show `Frame` in the Object Inspector |

## Editors

The editor windows are VCL forms built in code (the IDE is VCL). They do not use IDE units: they talk to the form
designer through `IFmrDesignBridge` and get designer events from `TFmrDesignHub` (`FMR.Ribbon.Design.Bridge`). The
IDE part (`FMR.Ribbon.Design.Editors`) implements the bridge around `IDesigner` and feeds the hub from an
`IDesignNotification`. Windows scale to the DPI of the monitor and take the IDE theme
(`IOTAIDEThemingServices.ApplyTheme`); they close when their component or the form designer goes away, and when the
design package is unloaded.

### Property editors

| Property | Editor |
|---|---|
| `Theme` of `TFmrRibbon`, `TFmrRibbonBackstageView`, `TFmrStatusBar`, `TFmrPopupMenu` | Drop-down of `TFmrTheme.ThemeNames` |
| `AccentColor` (ribbon, backstage view, status bar) | Drop-down "(theme default), Word, Excel, PowerPoint, Outlook, OneNote, Access, Fluent" with color swatches; `#AARRGGBB` / `#RRGGBB` / `$hex` typed; "..." opens the color dialog |
| Every `TFmrImageSource` (`Glyph`, `LargeGlyph`, group glyphs, screen tip images, backstage glyphs...) | Summary "(Glyph $E8C8 Copy)", "(Image 3)", "(SVG)", "(Path)", "(None)"; sub-properties; "..." opens the **image dialog** |
| `TFmrImageSource.GlyphCode` | Shown as `$E8C8 Copy`; accepts `E8C8`, `$E8C8`, `U+E8C8`, `#E8C8`; "..." opens the dialog on the icon font page |
| `TFmrImageSource.GlyphFontFamily` | Drop-down of the icon fonts installed (Segoe Fluent Icons, Segoe MDL2 Assets, Segoe UI Symbol...) |
| `TFmrImageSource.SvgSource`, `PathData` | "(N characters)"; "..." opens the dialog on the SVG / path page |
| `TFmrItemLink.Item` | Only the items of the bar manager of the link's owner (group → ribbon's manager, QAT, menus of items, status bar panels, popup menus) that can be linked there |
| `TFmrBarItem.Category` | Drop-down of the manager's categories; a new name is added to `Categories` |
| `KeyTip` (items, links, tabs, groups, context groups, application button, backstage tabs and buttons), `DialogLauncherKeyTip` | Validated: at most 3 letters/digits, upper-cased |
| `TFmrFormFrame.Mode` | Values + "..." dialog explaining Dwm / FullNC / NCStrip |

**Image dialog** (`FMR.Ribbon.Design.ImageDialog`, modal): kind, fixed color, recolor; pages *Image list* (grid of the
images of the bar manager's `Images`), *Icon font* (font family, glyph grid of every glyph of the font's private use
area — 2030 glyphs for Segoe Fluent Icons — with code points, search by name or code, code edit), *SVG* (paste or load
a file), *Path* (path data, view box); preview at 16/24/32/48 dp on a light and a dark background, drawn by
`TFmrImageSource.Draw` itself on an FMX bitmap canvas, so it shows exactly what the ribbon paints. Glyph names: a table
of ~260 well-known names (`FmrGlyphNames`), checked on rendered sheets (`tools\DesignPreview\glyphsheet.ps1`).

### Component editors (context menu of the component in the form designer and the Structure View)

| Component | Verbs (double click) |
|---|---|
| `TFmrBarManager` | **Items Editor...** (double click), New Button, New Item ▸ (every item class) |
| `TFmrRibbon` | **Structure Editor...** (double click), Items Editor..., Add Tab, Add Contextual Tab Group, Apply Template..., Theme ▸ (every theme, current one checked), Previous Tab, Next Tab, Create Bar Manager (when it has none) |
| `TFmrRibbonTab` | Add Group, Show This Tab (double click), Move Left, Move Right, Structure Editor... |
| `TFmrRibbonGroup` | New Button, New Item ▸, Add Links to Existing Items..., Move Left, Move Right, Structure Editor...; double click shows its tab |
| `TFmrRibbonContextGroup` | Add Tab, Show the First Tab |
| Bar items | Edit OnClick (double click, `TDefaultEditor`), Add to Quick Access Toolbar, Items Editor... |
| `TFmrRibbonBackstageView` | Add Tab, Add Button, Previous Tab, Next Tab, Theme ▸ |
| `TFmrStatusBar` | Add Text Panel, Add Container Panel, Add Item Links Panel, Add View Buttons, Add Zoom Slider, Theme ▸ |

New components are created with `IDesigner.CreateChild` (owner = the form, unique name, parent set). Selection editors
add `FMR.Ribbon.Types`, `FMR.Bars`, `FMR.Ribbon.Structure` / `FMR.Bars.Items` to the uses clause for the parameter types
of event handlers.

### Items editor (`FMR.Ribbon.Design.ItemsEditor`, non-modal, one per bar manager)

Categories on the left ("(All items)", every category of `Categories` and of the items, "(No category)"; add, rename —
items follow —, delete), items on the right (caption, name, type, number of links; the item's own glyph). *New Button*
(the arrow: every item class; the new item gets the selected category), *Delete* (Del), *Up* / *Down* (Ctrl+Up/Down,
reorders the manager's children), Ins = new button. Selecting rows selects the items in the Object Inspector (and the
selection of the designer selects the rows); double click opens `OnClick`. Items can be dragged onto a category (sets
it), into the structure editor (creates links) and — with the ribbon's design hooks — onto the ribbon in the form
(`TFmrItemDragObject` / `IFmrExternalItemDrop`).

### Structure editor (`FMR.Ribbon.Design.StructureEditor`, non-modal, one per ribbon)

Works for any `IFmrRibbonStructureOwner` (the ribbon, or a test double). Tree:

```
Ribbon1
├── Quick Access Toolbar → links
├── Home (tab) → Clipboard (group) → Paste (link) → Keep Text Only, Paste Special... (menu links of the item)
├── ...
└── Table Tools (contextual tab group) → Table Design (tab) → ...
```

- Toolbar: Tab, Context (contextual group + its first tab), Group (after the selected group of the target tab),
  Item ▾ (new item of any class, linked after the selected link / at the end of the selected group, menu or QAT; the
  category is the tab caption), Link (links to existing items, picker with filter), QAT (adds the selected links' items
  to the quick access toolbar), Delete (Del), Up / Down (Ctrl+Up/Down), Expand / Collapse, Template...; theme combo.
- Drag and drop inside the tree: links between groups, the QAT and menus (Ctrl copies), groups between tabs, tabs (onto
  a context group: the tab joins it; onto the ribbon: leaves it); items dragged from the items editor become links.
- F2 renames (caption of tabs/groups/context groups; the item caption for links). Context menu with the same commands.
- **Selection decision**: tabs, groups, context groups are selected in the Object Inspector; **a link selects its item**
  (as in DevExpress: caption, glyph, events are at hand); the link's own properties are in the panel at the bottom
  (Begin group, Visible, Key tip, Default sizes / Large / Small + text / Small, button group) and "Link in Inspector"
  selects the `TFmrItemLink` itself. The designer's selection selects the matching node (for an item: its first link).
- Refresh: designer notifications (item deleted/inserted, items modified) schedule a refresh (30 ms timer); when only
  captions/images changed the nodes are updated in place, otherwise the tree is rebuilt keeping expansion and
  selection. Pointers of a tree that may be stale are compared, never dereferenced.

### Templates

`Source\Templates\FMR.Ribbon.Templates.pas` (run time, in the runtime package): `TFmrRibbonTemplateBuilder` builds
complete Office-like structures into any structure owner and its bar manager; `FmrApplyRibbonTemplate(Ribbon,
Template, Manager = nil, Replace = False, Namer = nil)`.

| Template | Content |
|---|---|
| `Simple` | Home (Clipboard, Font, Editing), View (Zoom, Show) |
| `Word` | Home (Clipboard with Paste split menu, Font with font name/size editors and button-group rows, Paragraph, Styles gallery with drop-down commands, Editing), Insert (Pages, Tables, Illustrations, Links, Comments, Header & Footer, Text, Symbols), Layout (Page Setup with menus, Paragraph with spin editors, Arrange), View (Views as radio buttons, Show check boxes, Zoom, Window), contextual group "Table Tools" (Table Design, Table Layout) |
| `Excel` | Home (Clipboard, Font, Alignment, Number, Styles, Cells, Editing), Insert (Tables, Illustrations, Charts, Text), Formulas, Data, View |

All templates fill the QAT with Save, Undo, Redo (shortcuts Ctrl+S/Z/Y), set key tips of the tabs and common
commands, categories per tab, and use glyphs of the Segoe Fluent Icons / MDL2 font (`FmrGlyph*` constants), so no
image files are needed. Large buttons get `LargeGlyph` (all three view levels), small ones `Glyph` only, icon-only
buttons `ViewLevels = [Small]` in button-group rows (`TFmrTemplateRowPos`: new row, new segment, next).
Components are owned by the ribbon's owner and named through the name function: `DefaultNamer` (free name, else
numbered) at run time, `Designer.UniqueName` at design time. The building blocks (`AddTab`, `AddGroup`, `AddButton`,
`AddGroupButton`, `AddCheck`, `AddColor`, `AddCombo`, `AddFontName`, `AddSpin`, `AddGallery`, `AddMenuItem`,
`AddLink`, `AddToQAT`, `ClearStructure`) are public for application code.

Design time: "Apply Template..." (ribbon verb, structure editor) shows a chooser (template, description, "replace the
existing tabs and the QAT"); a bar manager is assigned/created when the ribbon has none.

Tests: `Tests\FMR.Tests.Templates` (10 tests on the fake ribbon: structure of the three templates, glyphs and
categories, QAT, unique names on a second application, replacement, name function, missing manager, streaming round
trip).

### Selection sync (works without any ribbon change)

`FmrDesignSyncSelection` runs on every selection change of the designer: each ribbon of the form shows the tab of the
selected tab, group, link, item (the active tab when one of its links is there, else the first tab with a link) or
contextual group. With `IFmrRibbonDesignSupport` it calls `DesignSelectTab` and `DesignSetSelection`, otherwise
`IFmrRibbonStructureOwner.SetActiveTab`. So selecting a tab or group in the Structure View, the Object Inspector, the
structure editor or the items editor already shows it in the form designer.

## Phase B: in-form design — contract for `TFmrRibbon`

### How FMX passes clicks to a control at design time

The FMX form designer gives mouse events to a control when it is **design-interactive**: `TControl` has the protected
field `FDesignInteractive` (read by `IControl.DesignInteractive`); `TTabItem` sets it in its constructor and its
`MouseDown` switches the tab and calls `TCommonCustomForm(Owner).Designer.SelectComponent(Self)` (`FMX.TabControl`,
`TTabItem.MouseDown`). `FMX.Forms.IDesignerHook` (the form's `Designer`) has `SelectComponent`, `IsSelected`,
`DesignerModified`, `UniqueName` and `Decorate` (painting over the finished form), and it can be queried for
`IDesigner`. At design time `TControl.CheckHitTest` returns True for every visible, not `Locked` control, so the
deepest control under the mouse is found; a `Locked` control is skipped. `TFmrRibbonBackstageView` already uses the
mechanism. Which control receives the events when a design-interactive control has children could not be checked
without the IDE, hence the "belt and braces" in step 3.

### The interfaces (`Source\Templates\FMR.Ribbon.DesignSupport.pas`, runtime package, no IDE units)

```pascal
TFmrDesignHitKind = (None, Ribbon, ApplicationButton, Tab, ContextGroup, Group, GroupLauncher, CollapsedGroup,
  Link, QATLink, QAT);
TFmrDesignHit = record
  Kind: TFmrDesignHitKind; Tab: TFmrRibbonTab; Group: TFmrRibbonGroup; ContextGroup: TFmrRibbonContextGroup;
  Link: TFmrItemLink; Bounds: TRectF;            // ribbon-local
  class function Empty: TFmrDesignHit; static; function Item: TFmrBarItem;
end;
TFmrDesignDragKind = (None, Link, Group, Tab);
TFmrDesignDropTarget = record
  Kind: TFmrDesignDragKind;
  Links: TFmrItemLinks;   // Link: target collection (group or QAT ItemLinks)
  Tab: TFmrRibbonTab;     // Group: target tab
  Index: Integer;         // insertion index (links / groups of Tab / tabs); Links.Count = append
  Mark: TRectF;           // insertion bar, ribbon-local; empty = nothing to paint
  class function Empty: TFmrDesignDropTarget; static; function IsValid: Boolean;
end;

/// implemented by TFmrRibbon
IFmrRibbonDesignSupport = interface ['{0D21AB53-4BD9-421C-B29B-FB924957A1E5}']
  function DesignHitTest(const ALocalPoint: TPointF): TFmrDesignHit;
  function DesignObjectBounds(const AObject: TPersistent): TRectF;
  function DesignDropTarget(const ALocalPoint: TPointF; const AKind: TFmrDesignDragKind): TFmrDesignDropTarget;
  procedure DesignShowDropTarget(const ATarget: TFmrDesignDropTarget);
  procedure DesignSetSelection(const AObjects: TArray<TPersistent>);
  procedure DesignSelectTab(const ATab: TFmrRibbonTab);
end;

/// implemented by the design package (TFmrRibbonDesignController), installed in TFmrRibbonDesignHooks.Hook
IFmrRibbonDesignHook = interface ['{FDA28767-D47A-406B-A0E1-BA3BA6202369}']
  function DesignMouseDown(const ARibbon: TControl; const AButton: TMouseButton; const AShift: TShiftState;
    const ALocalPoint: TPointF): Boolean;
  function DesignMouseMove(const ARibbon: TControl; const AShift: TShiftState; const ALocalPoint: TPointF): Boolean;
  function DesignMouseUp(const ARibbon: TControl; const AButton: TMouseButton; const AShift: TShiftState;
    const ALocalPoint: TPointF): Boolean;
  function DesignDblClick(const ARibbon: TControl; const ALocalPoint: TPointF): Boolean;
  procedure DesignRibbonDestroying(const ARibbon: TControl);
end;
TFmrRibbonDesignHooks.HookFor(Component): IFmrRibbonDesignHook   // nil unless csDesigning and a hook installed
```

All points and rectangles are local coordinates of the `TFmrRibbon` control (at design time the caption row and the
tab row stay inside the ribbon: the frame is not hooked). Every method brings the layout up to date first
(`EnsureAll`).

### What `TFmrRibbon` must do

1. `uses FMR.Ribbon.DesignSupport`; add `IFmrRibbonDesignSupport` to the class declaration.
2. Constructor (`csDesigning` is already set after `inherited Create` when the owner is designed or loaded by the
   designer): `FDesignInteractive := True`; at design time `AutoCapture := True` (move/up events during a drag) and
   every part (`FCaptionBar`, `FTabBar`, `FBody`, `FQATBar`, caption buttons, the search edit) `Locked := True`, so the
   designer's hit test stops at the ribbon (the TTabItem pattern: its content is `Locked`). The ribbon has
   `HitTest = False` at run time; at design time `CheckHitTest` ignores that.
3. Override `MouseDown`, `MouseMove`, `MouseUp`, `DblClick` (DblClick: `MouseDown` with `ssDouble` in FMX — call
   `DesignDblClick` there): when `TFmrRibbonDesignHooks.HookFor(Self)` is assigned, pass the event with the local point
   and stop when it returns True. Without a hook keep the current behavior (`TabAtScreenPoint` → `SetActiveTab`).
   Belt and braces: `TFmrRibbonPart.MouseDown/Move/Up` at design time convert the point
   (`FRibbon.AbsoluteToLocal(LocalToAbsolute(P))`) and call the same ribbon methods, in case the designer gives the
   events to the deepest control after all.
4. `BeforeDestruction`: `if Hook <> nil then Hook.DesignRibbonDestroying(Self)`.
5. `DesignHitTest`: caption bar (context group headers → `ContextGroup`, QAT views → `QATLink`, rest of the QAT
   area → `QAT`), tab bar (`TFmrTabElement` → `Tab`, `TFmrAppButtonElement` → `ApplicationButton`), body
   (`TFmrCollapsedGroupElement` → `CollapsedGroup`, `TFmrLauncherElement` → `GroupLauncher`, `TFmrItemView` →
   `Link` with `Group` = the link's owner and `Tab` = the active tab, inside `FGroupBoxes[i].Rect` but on no element →
   `Group`), QAT bar below the ribbon, otherwise `Ribbon`. `Bounds` in ribbon coordinates. The parts' protected
   `FindElement` already does the element lookup.
6. `DesignObjectBounds`: tab element, context header, group box, item view of a link (its `ViewObject`) or the first
   shown view of an item; empty when not shown.
7. `DesignDropTarget`:
   - `Link`: group box under the point (or the QAT): the link views of that group in link order; the index of the first
     view whose center is right of the point (in a column of small buttons: below the point); `Mark` = 2 dp bar at the
     left edge of that view (right edge of the last view when appending), the height of the view (content height for
     large buttons). Over a collapsed group: append to it.
   - `Group`: in the tab row the tab under the point (append, `Index = -1`, mark under the tab); in the body the active
     tab, index of the first group box whose center is right of the point, mark in the gap between the group boxes.
   - `Tab`: index of the first tab whose center is right of the point; mark at its left edge (row height).
   - `None` everywhere else.
8. `DesignShowDropTarget` / `DesignSetSelection`: store and repaint; paint in `AfterPaint` (after the children): the
   insertion bar in the theme accent color (2 dp + small triangles at both ends), a dashed frame around every shown
   selected object (`DesignObjectBounds`).
9. `DesignSelectTab`: activate the tab without `OnTabChanging`/`OnTabChanged`, without popups; at design time show a
   tab of a hidden contextual group while it is selected (otherwise its groups cannot be designed).
10. Keep `TabAtScreenPoint` (used by the fallback).
11. Needed already now: `DoTabChanged` (and every other event) must not run at design time
    (`if csDesigning in ComponentState then Exit`). `SetActiveTab` calls `DoTabChanged` also at design time, and the
    selection sync (and "Show This Tab", "Next Tab"...) activates tabs in the designer, where event properties hold the
    designer's method references, not code.

### IDE side (already written, `FMR.Ribbon.Design.Interactive`)

`TFmrRibbonDesignController`, installed by `Register`: left click selects the object under the mouse — tab (and
activates it), contextual group, group (also launcher / collapsed group), the **item** of a link (Alt+click: the link
itself), the ribbon elsewhere; the selection is posted (`TThread.ForceQueue`) so it happens after the designer's own
processing of the click; the right button also selects at once, so the designer's context menu shows the verbs of the
object (Add Group, New Item ▸, Move Left...). Dragging a link, group or tab more than 5 dp shows the insertion mark;
releasing moves it (`TFmrRibbonStructure.MoveLink/MoveGroup/MoveTab`, index corrected inside the same collection; Ctrl
copies a link) and marks the form modified. Double click: item → `OnClick` handler, launcher →
`OnDialogLauncherClick`, tab/group/ribbon → structure editor. Items dragged from the items editor over the form are
tracked through `TDragObject.GetDragCursor` (screen point → FMX form under it via `FormToHWND`/`WindowFromPoint` →
ribbon → `DesignDropTarget`), the mark is shown, and the drop inserts links (`ExternalDrop`).

Checked in `tools\DesignPreview` (`/selftest`) with a fake ribbon implementing `IFmrRibbonDesignSupport`: link into
another group, inside its group, Ctrl copy, group and tab moves, mark hidden after the drop, a click without moving
does nothing, double click opens `OnClick`, the selection sync. What remains for phase B is the ribbon side above and
a check in the IDE (in particular which control receives the events, the order of the designer's own selection and
ours, and the external drop position in a zoomed/scrolled designer view).

## Preview program (`tools\DesignPreview`)

`DesignPreview.dpr` (VCL) runs the editor windows without the IDE: a fake designer (`TPreviewBridge`: unique names,
creation, selection, "show event" logged, designer events sent to the hub), a fake ribbon (`TPreviewRibbon`) filled with
a template.

```powershell
.\build.ps1 -Project tools\DesignPreview\DesignPreview.dpr
bin\Win64\Debug\DesignPreview.exe /structure /expand /select=btnPaste /shot=shots\design\structure.png
bin\Win64\Debug\DesignPreview.exe /items /shot=shots\design\items.png
bin\Win64\Debug\DesignPreview.exe /image /glyph=E8C8 /shot=shots\design\image.png
bin\Win64\Debug\DesignPreview.exe /templates /shot=shots\design\templates.png
bin\Win64\Debug\DesignPreview.exe /template=excel /structure      # template: word (default), excel, simple, none
bin\Win64\Debug\DesignPreview.exe /selftest=shots\design\selftest.txt   # exit code = failures
```

`TemplateDemo.dpr` (FMX) shows a real `TFmrRibbon` built by a template
(`/template=word|excel|simple /tab=N /theme=NAME /context`); checked on screenshots: Word Home and Insert tabs
(Office365White), Excel Home (Office2016Colorful). Captions containing `&` use `&&` (the ribbon treats `&` as an
accelerator mark).

`/selftest` also drives the structure editor (Ins adds a button to the selected group with the tab's category, Del
deletes a link / a tab with its groups, an item freed behind the editor's back refreshes the tree, the designer's
selection selects the node). `glyphsheet.ps1` renders glyph code points with names (`-File glyphs.txt`) or whole
ranges (`-Range E700-E7FF`). `PackageLoadTest.dpr` loads both packages with `LoadPackage`.

## Decisions

- Editor windows are VCL forms built in code (no `.dfm`), independent of IDE units through `IFmrDesignBridge` /
  `TFmrDesignHub`, so they run in the preview program; only `FMR.Ribbon.Design.Editors` and `FMR.Ribbon.Reg` use
  `DesignIntf`/`DesignEditors`/`VCLEditors`/`ToolsAPI`.
- The design-hook contract and the template builder are runtime code in the new folder `Source\Templates` (I may not
  touch `Source\Core`; the coordinator may move `FMR.Ribbon.DesignSupport` to `Source\Core` — only the `.dpk` path
  changes).
- A link node selects its item (DevExpress-like); link properties in the structure editor's bottom panel.
- `{$LIBSUFFIX AUTO}`: BPLs are named `...370.bpl`, DCPs keep the plain name; both IDEs (32/64-bit) are served by the
  Win32/Win64 builds.
- Component icons are PNG resources drawn by the build script (glyph of the icon font or a small sketch on a colored
  rounded square); `.dcr` regenerated with `-Icons`.
- Template glyph code points were chosen by looking at rendered sheets of Segoe Fluent Icons; where the font has no
  exact Office icon (Shapes, Header, Subscript...) a close glyph is used; Subscript/Superscript are left out.

## Open issues

- Nothing was run inside the IDE (not possible here): registration, editors and the notifier are compiled for Win32 and
  Win64 and the packages load with `LoadPackage`, the windows are checked in the preview program.
- Phase B needs the ribbon side (steps 1–10 above); step 11 (no `OnTabChanged` at design time) is needed for the
  editors as they are.
- `IDesigner.CreateChild` with a non-control parent (the bar manager, a tab) is what FMX's own menu editor does for
  `TMainMenu`; to be confirmed in the IDE for tabs/groups.
- The 64-bit IDE registry key `Known Packages x64` is used by `-Install`; install through the IDE menu when in doubt.
- Selecting a contextual group's tab whose group is hidden (`Visible = False`) activates it only once the ribbon shows
  hidden contextual tabs at design time (step 9).
- The template icons are approximations (one icon font); Office has its own icons.
