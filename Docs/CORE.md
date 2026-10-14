# FMR Ribbon — core (non-visual) part

Everything in `Source\Core\` that is not a control: items and links, image sources, the ribbon structure, the layout
calculator, persistence of the user layout, merging, key tip logic and strings. No unit uses `Winapi`; all of it is
cross-platform. The visual ribbon (`TFmrRibbon`, painter, popups) is built on top of these contracts.

## Units

| Unit | Content |
|---|---|
| `FMR.Ribbon.Types` | Shared enums: `TFmrViewLevel(s)`, `TFmrButtonStyle`, `TFmrButtonGroupPosition`, `TFmrItemChange`, `TFmrQATPosition`, `TFmrMergeKind`, `TFmrRibbonDisplayMode`, `TFmrRibbonShowMode`, `TFmrLayoutItemKind`, `TFmrSimplifiedVisibility`, gallery enums, `TFmrKeyTipStyle`; view level helpers |
| `FMR.Bars.Images` | `TFmrImageSource` (image list index, SVG, icon-font glyph, path data) and its drawing on any FMX canvas |
| `FMR.Bars` | `TFmrBarManager`, `TFmrBarItem`, `TFmrItemLink`, `TFmrItemLinks`, `TFmrScreenTip`, `TFmrBarItemActionLink`, `IFmrBarManagerListener`, `IFmrItemLinksOwner` |
| `FMR.Bars.Items` | Button, sub item, separator, static, control, edit, combo, spin, track bar, font name, check, color, gallery (+ gallery groups/entries) |
| `FMR.Ribbon.Structure` | `IFmrRibbonStructureOwner`, `TFmrRibbonTab`, `TFmrRibbonGroup`, `TFmrRibbonContextGroup`, `TFmrRibbonQuickAccessToolbar`, `TFmrRibbonLayoutOptions`, `TFmrRibbonStructure` helpers |
| `FMR.Ribbon.Layout` | `TFmrRibbonLayoutCalculator` (classic and simplified layout), scroll helpers, tab row helper, RTL mirroring |
| `FMR.Ribbon.Persistence` | `TFmrRibbonLayoutStorage`: user layout to/from JSON |
| `FMR.Ribbon.Merge` | `TFmrRibbonMerger`: merge/unmerge of structure owners |
| `FMR.Ribbon.KeyTips` | `TFmrKeyTipAssigner` (automatic key tips), `TFmrKeyTipMatcher` (typed sequence) |
| `FMR.Ribbon.Strings` | `FmrStr`, `FmrFmt`, `FmrSetLanguage`, English and Russian tables, overrides, extra languages |

The theme engine lives in `Source\Themes\` (`FMR.Ribbon.Theme`, `FMR.Ribbon.Themes.Builtin`); the core does not
depend on it. `TFmrLayoutMetrics` is filled by the ribbon from the theme metrics.

## Objects and relations

```
Form (Owner of everything)
├── TFmrBarManager (TFmxObject, Parent = form)          Images, Categories, listeners
│   └── TFmrBarItem children (Parent = manager)         Caption, Glyph, LargeGlyph, Action, ScreenTip, ...
│         └── knows its TFmrItemLink objects (not owned)
└── TFmrRibbon (TControl, written later; implements IFmrRibbonStructureOwner)
    ├── QuickAccessToolbar: TFmrRibbonQuickAccessToolbar (persistent) → ItemLinks
    ├── TFmrRibbonContextGroup children (named; tabs reference them)
    └── TFmrRibbonTab children ──ContextGroup──► TFmrRibbonContextGroup
        └── TFmrRibbonGroup children → ItemLinks: TFmrItemLinks → TFmrItemLink.Item ──► TFmrBarItem
```

- Every object is created with `Create(AOwner)` only and owned by the form, exactly like the designer creates
  components; parent/child relations use `Parent` (FMX children), so FMX streams them and the Structure View shows
  manager → items and ribbon → tabs → groups.
- References between objects are streamed by name and protected with `FreeNotification`: `TFmrItemLink.Item`
  (protected by the item's link registry), `TFmrRibbonTab.ContextGroup`, `TFmrControlItem.Control`,
  `TFmrBarItem.Action`, `MergedFrom` of merged copies.
- `TFmrItemLinks` (an owned collection) holds links for groups, the QAT, sub menus (`TFmrSubItem.ItemLinks`),
  drop-downs (`TFmrButtonItem.DropDownLinks`, `TFmrGalleryItem.DropDownLinks`); the same class will hold the links of
  the mini toolbar, radial menu and status bar.
- An item cannot be linked into its own collections (`EFmrBarError`); indirect cycles do not loop (re-entrant
  change notifications are ignored), but menus must guard against showing them recursively.

### Notifications

```
item property set ─► TFmrBarItem.Changed(kind) ─► every link ─► its TFmrItemLinks ─► owner.LinkItemChanged(link, kind)
                                               └► TFmrBarManager ─► listeners.BarManagerChanged(ItemChanged, item, kind)
link added/removed/moved/property ─► owner.LinksChanged(links); a link leaving a collection ─► owner.LinkRemoving(link)
group/QAT (IFmrItemLinksOwner) ─► IFmrRibbonStructureOwner.LinksChanged / LinkItemChanged / LinkRemoving
tab/group/context group added, removed, moved, shown/hidden ─► owner.StructureChanged(sender)
caption, key tip, color, glyph, launcher... ─► owner.StructureObjectChanged(sender, kind)
tab/group/context group destroyed ─► owner.StructureObjectRemoving(obj) + StructureChanged(obj)
```

- `TFmrItemChange`: `Layout` (size may change: re-measure and re-layout), `Paint` (repaint), `Value` (editor value:
  sync the control created for the link).
- Nothing is reported while the sender or the owner is loading or destroying. After `Loaded` the ribbon must rebuild
  everything.
- `TFmrBarManager.BeginUpdate/EndUpdate` turns all changes into one `Updated` notification;
  `IFmrRibbonStructureOwner.BeginStructureUpdate/EndStructureUpdate` brackets layout loading and merging (the owner
  should postpone its re-layout to the outermost `EndStructureUpdate`).
- `FmrItemDestroyingHook` / `FmrLinkDestroyingHook` (global procedure variables) are called first in the destructor of
  every item and link, also without a manager and inside `BeginUpdate`: `FMR.Ribbon.Popup` closes the open popups
  that show them (menus keep raw references to their rows' items and links).

### Actions

`TFmrBarItem` publishes `Action` (FMX `TFmxObject` already implements `IActionClient`); `TFmrBarItemActionLink`
makes Caption (`TAction.Text`), Enabled, Visible, Hint, ShortCut, ImageIndex (→ `Glyph.ImageIndex`), Checked
(→ `Down` / `Checked`) and GroupIndex follow the action; linked properties are not stored in the .fmx. `Click` runs
`OnClick` when assigned, otherwise executes the action; disabled items do not click. `UpdateFromAction` calls the
action's `OnUpdate` (the ribbon should call it for visible items on idle, like FMX does for controls).

### Items

| Item | Notes |
|---|---|
| `TFmrButtonItem` | `ButtonStyle` Default/Check/DropDown/Split, `Down`, `GroupIndex` (radio within the manager), `AllowAllUp`, `DropDownLinks`, `OnDropDown` (fill the menu lazily) |
| `TFmrSubItem` | `ItemLinks` = sub menu, `OnPopup` |
| `TFmrSeparatorItem` | layout kind `Separator`; in menus a caption makes it a header |
| `TFmrStaticItem` | label, `Alignment`, `Width` |
| `TFmrControlItem` | hosts an existing `TControl` (one parent → one link shows it at a time) |
| `TFmrEditItem`, `TFmrComboItem`, `TFmrSpinItem`, `TFmrTrackBarItem`, `TFmrFontNameItem` | data only; the ribbon creates an FMX control per link and syncs on `TFmrItemChange.Value`; editor changes made by the user must be written back to the item (which notifies the other links) |
| `TFmrCheckItem` | painted check box, radio with `GroupIndex` |
| `TFmrColorItem` | split button with `Color`, automatic/no color/more colors options |
| `TFmrGalleryItem` | `Groups` → `Items` (entries with caption, glyph, hint, description), `MinColumns`/`MaxColumns` (in-ribbon), `DropDownColumns/Rows`, `ItemWidth/Height`, `ShowInRibbon`, `AllowFilter`, `SelectedIndex`/`SelectedEntry` (follows its entry), `ClickEntry` → `OnItemClick`, `HotTrack(entry or nil)` → `OnHotTrack` (live preview; nil = revert) |

`DefaultViewLevels` of an item (used when a link's `ViewLevels` is empty): all three with a `LargeGlyph`, small
with text and small with a `Glyph`, small with text only without glyphs; editors: small with text (with a caption)
and small. `LayoutKind` tells the ribbon how to feed the layout calculator.

`TFmrBarManager.SearchItems(text)` implements the data side of command search ("Tell me"): every word must occur in
caption, description, hint, `Keywords` or category; captions starting with the text come first.

### Images (`TFmrImageSource`)

`Kind = Auto` picks SVG, then glyph, then path, then image list index. `Draw(Canvas, Rect, Opacity, Tint, Images)`
centers the image keeping the aspect ratio and works with any canvas:

- image list: `TCustomImageList.Draw`; with `Recolor` a single-color copy (`FmrRecolorBitmap`) is cached;
- SVG: rendered by `TFmrImageSource.SvgRenderer` (Skia by default: `TSkSVGDOM` into a `TBitmap` via `SkiaDraw`),
  cached per pixel size and tint (6 entries per source); `Recolor` tints with an `SrcIn` color filter;
- glyph: `FillText` with `GlyphFontFamily` (default `Segoe Fluent Icons` on Windows 11, `Segoe MDL2 Assets` on
  Windows 10; set `DefaultGlyphFontFamily` elsewhere), code points above $FFFF supported;
- path: `FillPath` of `PathData` fitted to the rect (or drawn in a 0..`PathViewBox` square like an SVG viewBox).

`Color` fixes the color of glyphs/paths (and recolored images); otherwise the painter's `Tint` is used (black when
Null). Define `FMR_NO_SKIA` to build without Skia (then assign `SvgRenderer` yourself). Programs drawing SVG need
`sk4d.dll` next to the exe (`build.ps1` copies it).

## Ribbon structure

`IFmrRibbonStructureOwner` is implemented by the ribbon; tabs and context groups find it on their `Parent`, groups
on `Parent.Parent`, the QAT on its owner component. Methods: `GetStructureObject`, `GetBarManager`,
`GetQuickAccessToolbar`, `Get/SetActiveTab`, `Get/SetLayoutOptions`, `Begin/EndStructureUpdate` and the
notifications listed above. `Tests\FMR.Tests.Fakes.pas` (`TFakeRibbon`) is a complete minimal implementation.

- `TFmrRibbonStructureObject` (base of tab, group, context group): `Caption`, `UserCaption` (renamed by the user;
  `DisplayCaption` = UserCaption or Caption), `KeyTip`, `Visible`, `MergeKind`, `MergeOrder`, `IsUserDefined`,
  `MergedFrom`.
- `TFmrRibbonTab`: `ContextGroup`, `Groups[]`/`GroupCount`, `TabIndex` (among tabs, settable), `Active`
  (through the owner), `IsShown` (visible and its context group visible), `AddGroup`, `FindGroup`.
- `TFmrRibbonGroup`: `ItemLinks`, `Glyph` (collapsed button, QAT), `CanCollapse`, `ReductionPriority`,
  `ShowCaption`, `ShowDialogLauncher`, `DialogLauncherKeyTip`, `OnDialogLauncherClick` (`DialogLauncherClick`).
- `TFmrRibbonContextGroup`: `Caption`, `Color`, `Visible` (default False), `Tabs`, `Activate`. Hiding it while its
  tab is active calls `SetActiveTab(nil)`: the ribbon then picks another tab.
- `TFmrRibbonQuickAccessToolbar`: `ItemLinks`, `Position`, `Visible`, `ShowCustomizeButton`, `AddItem` (no
  duplicates), `RemoveItem`, `ContainsItem`.
- `TFmrRibbonStructure`: `Tabs`, `Tab`, `TabCount`, `ContextGroups`, `AllGroups`, `FindTab`/`FindGroup`/
  `FindContextGroup`, `CreateTab`/`CreateGroup`/`CreateContextGroup` (owned by the form, like the designer),
  `MoveTab`, `MoveGroup` (also between tabs), `MoveLink`, `CopyLink`, `TabIndexToChildIndex`. Tab indexes count
  only tabs (the ribbon may have other children).

## Layout algorithm (`FMR.Ribbon.Layout`)

Input per group (`TFmrLayoutGroup`): caption width, dialog launcher, `CanCollapse`, `Priority`, collapsed button
width, links. Input per link (`TFmrLayoutLink`): kind (button, control, gallery, separator), allowed levels, width at
every level (measured by the painter), `BeginGroup`, `ButtonGroup`, gallery column width/min/max/extra width,
simplified width/visibility, `Hidden`, free `Data`. Sizes are dp; `TFmrLayoutMetrics` holds content height, row
height/count (3), paddings, spacings, separator width, launcher width.

**Arrangement of one group.** Links flow left to right in columns. A Large link or a gallery takes a full-height
column. Small links (SmallWithText/Small) stack in a column of up to `RowCount` rows; a column with fewer rows spreads
them evenly (`DistributeRows`). A link with `ButtonGroup = Member` continues the row of the previous link (button
groups, editors side by side); on such a link `BeginGroup` starts a new segment of the row (gap
`SegmentSpacing`) instead of a new column. `BeginGroup` on any other link and separator links end the column and
draw a separator (never at the start or the end). Group width = max(content + 2 × padding, caption + 2 × padding
(+ launcher), `MinGroupWidth`); narrower content is centered. Results: level, rectangle (relative to the group and the
content top), column/row, segment position (`First/Middle/Last/Single` for button groups), gallery columns,
separator positions.

**Reduction.** A fixed sequence of steps is built from the fully expanded tab; every step makes one group strictly
narrower (a step that would not reduce the group width is skipped). Passes, each visiting the groups in ascending
`Priority` and right to left among equal priorities:

1. galleries lose one column per step (round robin over groups) down to `MinColumns`;
2. Large → SmallWithText (or Small when SmallWithText is not allowed): per step the rightmost run of up to
   `RowCount` adjacent large links (a run ends at separators, `BeginGroup`, galleries) — a group is reduced as far as
   possible before the next group to the left;
3. SmallWithText → Small, and Large → Small for links whose step 2 was not beneficial, same way;
4. galleries become a large drop-down button (`GalleryColumns = 0`, width `Widths[Large]`);
5. groups collapse into their drop-down button (`CanCollapse`, only when the button is narrower).

`Calculate(width)` binary-searches the first step whose total width fits (`Fits = False` and the fully reduced state
when none does: show scroll buttons). Because the sequence does not depend on the width, the result is deterministic,
a wider tab never gets a narrower layout and expansion is the exact reverse of reduction. `Prepare` once per input
(tab switch, item change, theme change), then `Calculate` on every resize costs O(log steps + links).
A collapsed group's result keeps the expanded layout of its links for the popup (`ExpandedWidth`).

**Simplified layout** (`CalculateSimplified`): one line of all visible links (`SimplifiedWidth`, default the Small
width), item spacing inside groups, separators between groups. `Never` links are skipped, `Overflow` links always go
to the "…" menu; when the line is too wide `Auto` links leave from the right, then `Always` links. The overflow list
keeps ribbon order; the overflow button rectangle is returned.

**Helpers.** `FmrGroupScrollInfo` (clamped offset, can scroll left/right, first/last fully visible group) and
`FmrGroupScrollStep` (next offset for a scroll button click) for tabs that do not fit; `FmrLayoutTabs` (tab widths
shrink proportionally between full and minimum width); `FmrMirrorLayout`/`FmrMirrorGroup` for right-to-left
(mirrors rectangles, separators and segment ends); `CalculateExpandedGroup`, `StepWidths`, `MinimumWidth`,
`ExpandedWidth`.

Mapping for the ribbon author: one `TFmrLayoutLink` per link (`Hidden := not Link.IsVisible`,
`Levels := Link.EffectiveViewLevels`, kind from `Item.LayoutKind`, widths from the painter), one `TFmrLayoutGroup`
per group (`Hidden := not Group.Visible`, `Priority := ReductionPriority`), and keep the link index in `Data`.

## Persistence (`FMR.Ribbon.Persistence`)

`TFmrRibbonLayoutStorage.SaveToJSON/SaveToString/SaveToStream/SaveToFile` and the matching `LoadFrom…` (optional
`TFmrItemResolver`; default: bar manager of the owner, then components of the form).

```json
{ "format": "FMR.RibbonLayout", "version": 1,
  "options": { "minimized": false, "showMode": "TabsAndCommands", "displayMode": "Classic" },
  "qat": { "position": "BelowRibbon", "visible": true, "links": [ { "item": "btnSave" }, { "item": "btnRedo", "beginGroup": true } ] },
  "tabs": [ { "name": "tabInsert", "visible": true, "groups": [ { "name": "grpTables", "visible": true } ] },
            { "name": "tabCustom1", "visible": true, "userDefined": true, "caption": "My Tab", "keyTip": "Y",
              "groups": [ { "name": "grpCustom1", "visible": true, "userDefined": true, "caption": "My Group",
                            "links": [ { "item": "btnBold", "viewLevels": "Large" } ] } ] } ] }
```

- Saved: options, QAT (position, visibility, links), order/visibility/`UserCaption` of tabs and groups (groups may
  move between tabs), user-defined tabs and groups with caption, key tip, context group, glyph index, launcher and
  links. Link properties saved: item name, `BeginGroup`, `Visible`, `ViewLevels`, `ButtonGroup`,
  `SimplifiedVisibility`, `UserCaption`, `KeyTip`; defaults are omitted.
- Not saved: links of designed groups (a new application version can add commands to its groups without old
  layouts hiding them), designed captions (localization keeps working).
- Loading deletes the current user-defined tabs/groups and recreates them (loading twice changes nothing); designed
  groups inside a deleted user tab are kept and placed again. Tabs/groups are matched by `Name`; unknown tabs,
  groups, items and enum values are skipped. Objects the layout does not mention keep their index; the mentioned
  ones fill the other slots in the saved order. Unknown format or a newer version raises `EFmrLayoutError`.
- Round trip is lossless: save → load into a fresh form → save gives the same JSON (tested).
- "Reset customization": save the layout once at startup (before loading the user's file) and load that snapshot.

## Merging (`FMR.Ribbon.Merge`)

`TFmrRibbonMerger.Create(Owner, TargetStructureObject)`; `Merge(Source)`, `Unmerge(Source)`, `UnmergeAll`,
`IsMerged`, `MergedCount`. The source is never changed: the target gets copies (`Stored = False`, `MergedFrom` =
source object) whose links reference the same items. Per source tab/group (`MergeKind`): `Merge` — into the target
object with the same Name, else the same caption, else added; `Add`; `Replace` — the target object is hidden, the
copy takes its place; `Remove` — the target object is hidden. Source objects are processed in ascending `MergeOrder`;
copies are inserted before the first target object with a greater `MergeOrder`. Links of a group merged into an
existing group are appended. Context groups are mapped by name/caption or copied. Unmerge deletes everything the
merge created (appended links by collection ID), and restores the visibility it changed. A destroyed source is
unmerged automatically; several sources can be merged and unmerged independently. The QAT is not merged.

## Key tips (`FMR.Ribbon.KeyTips`)

`TFmrKeyTipAssigner.Assign(entries, style, reserved)` for one scope (the tabs + QAT + application button; the
links of a tab; a menu): explicit tips are kept (upper-cased); then the letter after `&`; then the first letter when
no other pending caption starts with it; captions sharing a first letter get two letters (initials of two words,
then first letter + another letter: Home → HO, Help → HE); then any free letter/pair. Generated tips are unique and
prefix-free (no tip is the start of another), so a typed character is never ambiguous. Style `Numbers` gives
1…9, 09…01, 0A…0Z (QAT). `TFmrKeyTipMatcher`: `Press(char)` → None / Partial / Complete (`MatchedIndex`),
`IsCandidate` (hide non-matching tips), `Backspace` (False = go back to the parent scope), `Reset`.

## Strings (`FMR.Ribbon.Strings`)

`FmrStr(TFmrStringId.X)`, `FmrFmt`, `FmrSetLanguage('en' | 'ru' | 'ru-RU' | registered code)` (unknown → English,
returns False), `FmrLanguage`, `FmrSystemLanguage`, `FmrRegisterLanguage(code, table)` (empty entries fall back to
English), `FmrSetString` overrides (all languages), `FmrResetStrings`. A `TFmrLanguageChangedMessage` is sent through
`TMessageManager.DefaultManager` on every change. Ids cover the QAT menu, ribbon menu/display options, search,
screen tips ("Press F1 for more help."), application menu/backstage, customization form, common buttons, galleries,
color/font items and caption buttons.

## Building and running the tests

DUnitX ships precompiled with Delphi 13 in `lib\win64\release` / `lib\win32\release`, which are on the default
`dcc64.cfg`/`dcc32.cfg` library path, so no extra search path is needed:

```powershell
cd f:\Projects\FMXRibbon
.\build.ps1 -Project Tests\FmrRibbonTests.dpr            # Win64 Debug
.\bin\Win64\Debug\FmrRibbonTests.exe                      # exit code = failed + errored tests
.\build.ps1 -Project Tests\FmrRibbonTests.dpr -Platform Win32
.\bin\Win32\Debug\FmrRibbonTests.exe
```

(If a Delphi installation lacks the DUnitX DCUs, add `-SearchPath "C:\Program Files (x86)\Embarcadero\Studio\37.0\source\DunitX"`.)
The runner reports memory leaks on shutdown. Test units: `FMR.Tests.Bars` (items, links, notifications, cascades,
actions, editors, gallery, images incl. real drawing of path and SVG, search), `FMR.Tests.Structure` (owner
notifications, move helpers, streaming round trip with `WriteComponent`/`ReadComponent`/`ObjectBinaryToText`,
defaults not stored, clone), `FMR.Tests.Layout` (arrangement, reduction order, priorities, galleries, collapse,
monotonic width, determinism, simplified overflow, scrolling, tabs, RTL), `FMR.Tests.Persistence`,
`FMR.Tests.Merge`, `FMR.Tests.KeyTips` (+ strings). Current result: 120 tests, all passing on Win64 and Win32
(Debug), Win64 Release builds clean.

## Decisions

- Context groups are named `TFmxObject` children of the ribbon (owner decision), not a collection as the first
  draft of `ARCHITECTURE.md` said; tabs reference them by name.
- QAT position/visibility live in `TFmrRibbonQuickAccessToolbar`; `TFmrRibbonLayoutOptions` holds only Minimized,
  ShowMode and DisplayMode.
- Items are owned by the manager's owner (the form) and parented to the manager (`CreateItem` does that), like the
  designer will.
- One image list (`TFmrBarManager.Images`) for small and large glyphs: FMX image lists are multi-resolution and
  `LargeGlyph.ImageIndex` can point anywhere.
- `TFmrItemLink.ViewObject` is reserved for the ribbon (control/view info per link); release it in `LinkRemoving`
  and when a group is removed (`StructureObjectRemoving`; links of a destroyed group are deleted silently).
- `UserCaption` on tabs, groups and links is the customization rename; designed captions are never overwritten.
- A layout step is applied only when it makes the group narrower; collapsing is skipped when the collapsed button is
  not narrower than the reduced group.
- Key tips: entries sharing a first letter all get two letters (clean prefix-free rule) instead of "first one wins".
- `TFmrButtonItem.GroupIndex` radio groups are per manager.
- Gallery selection is stored as an entry reference (streamed as `SelectedIndex`), so it follows its entry.

## Open issues / for the visual ribbon author

- Implement `IFmrRibbonStructureOwner` on `TFmrRibbon` (see `TFakeRibbon`), own a `TFmrRibbonQuickAccessToolbar`
  (`Create(Self)`) as a published property, and a `TFmrRibbonMerger` if merging is exposed.
- Treat `StructureChanged` as "invalidate" (objects with `csDestroying` may still be children; the helpers skip
  them). Rebuild everything after `Loaded` and at the outermost `EndStructureUpdate`.
- Register as `IFmrBarManagerListener` of the manager (`ImagesChanged`, `Updated`, `Destroying`), remove yourself
  before destruction.
- `TFmrFontNameItem.FontListProvider` must be set by a platform unit (e.g. a `*.Win.pas` with
  `EnumFontFamiliesEx`): neither FMX nor Skia exposes font family enumeration.
- Editor items are data only; the controls per link (edit, combo, spin box, track bar, color picker) and their
  two-way sync are the ribbon's job.
- Command search, gallery filtering (`AllowFilter`), mini toolbar/radial menu/status bar link collections, UIA and
  touch mode need only the existing data; their UI is not written.
- The persistence stores only the image index of user-defined group glyphs (not SVG/glyph/path sources).
- `ARCHITECTURE.md` still describes context groups as a collection; it should be updated by the coordinator.
