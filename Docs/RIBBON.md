# FMR Ribbon - the ribbon control (`Source\Ribbon`)

The visual part of FMR Ribbon: `TFmrRibbon` and everything it shows (tabs, groups, item views, editors, popups,
menus, screen tips, key tips, quick access toolbar, contextual tabs, minimized and simplified modes) and its
integration with the window frame of `Source\Frame`. The data side (bar items and links, ribbon structure, layout
calculator, themes and painter, key tip assignment, strings) is core code described in `Docs\CORE.md`.

Demo: `Demos\RibbonBasic` (a Word-like ribbon built in code, see "Demo and test scripts" at the end).

## Units

| Unit | Contents |
|---|---|
| `FMR.Ribbon` | `TFmrRibbon`; its parts `TFmrRibbonCaptionBar`, `TFmrRibbonTabBar`, `TFmrRibbonBody`, `TFmrRibbonQATBar`, `TFmrGroupPopupContent`; caption buttons `TFmrRibbonCaptionButton`; ribbon elements (`TFmrTabElement`, `TFmrAppButtonElement`, `TFmrSysButtonElement`, `TFmrCollapsedGroupElement`, `TFmrLauncherElement`); `TFmrRibbonApplicationButton`; `IFmrApplicationMenu` |
| `FMR.Ribbon.Views` | `TFmrElement` (base of everything painted and clickable), `IFmrElementHost`, `TFmrElementTracker` (hover/press/capture), item views `TFmrItemView`, `TFmrButtonView`, `TFmrSeparatorView`, view registry `FmrRegisterItemView`, helpers (`FmrStripAccel`, `FmrShortCut`, `FmrShortCutText`, `FmrSplitLargeCaption`, `FmrLatinKeyChar`) |
| `FMR.Ribbon.Editors` | `TFmrEditorView`: real FMX controls for editor items (`TEdit`, `TComboBox`, `TComboEdit`, `TSpinBox`, `TTrackBar`) and for `TFmrControlItem` (any control), two-way value sync |
| `FMR.Ribbon.Popup` | `TFmrPopupForm`, `TFmrPopupManager` (`FmrPopups`), key sink and `IFmrKeyHandler`, `IFmrPopupContext`/`TFmrPopupContext`, `IFmrPopupContent`, menus (`TFmrMenuControl`, `TFmrMenuRow`), `TFmrColorPaletteControl`, `TFmrPopupMenu` component, `TFmrCommandItem`, `TFmrTempMenu`, drop-down registry (`FmrRegisterDropDown`, `FmrCreateDropDownContent`), `IFmrThemeSource` |
| `FMR.Ribbon.ScreenTips` | `TFmrScreenTipContent`, `TFmrScreenTipController` (delay, placement, one tip at a time) |
| `FMR.Ribbon.Fonts.Win` | Font family list (EnumFontFamiliesEx) for font name editors; empty on other platforms |
| `FMR.Ribbon.Gallery`, `FMR.Ribbon.ColorGallery`, `FMR.Ribbon.AppMenu`, `FMR.Ribbon.MiniToolbar`, `FMR.Ribbon.RadialMenu` | In-ribbon and drop-down galleries, color gallery, Office 2007 application menu, mini toolbar, radial menu - see `Docs\GALLERIES.md` |

Additions to `Source\Themes\FMR.Ribbon.Painter.pas` (new methods only, existing signatures untouched): `TextEx`,
`DrawShadow`, `DrawPopupBackground`, `DrawCheckBox`, `DrawSearchGlyph`, `DrawCustomizeGlyph`, `DrawChevron`,
`DrawColorBar`, `DrawColorCell`, `DrawScreenTipSeparator`, `DrawBodyBackground`, `DrawMenuCheckBackground`.

## Architecture

### Parts

`TFmrRibbon` is one `TControl` (Align = Top) that owns four part controls (`Stored = False`, `Locked = True`, created
in the constructor, never streamed):

- **Caption bar**: quick access toolbar (above the ribbon), title, contextual tab group headers, search box,
  help button, window buttons (minimize, maximize/restore, close) when the bars live in the frame.
- **Tab bar**: application button ("File" tab or the Office 2007 orb), tabs (contextual tabs with their color),
  tab scroll buttons, collapse/pin button, display options.
- **Body**: the groups of the active tab (classic or simplified), group scroll buttons.
- **QAT bar**: the quick access toolbar when it is below the ribbon (or above it with no caption row).

With a frame (`TFmrFormFrame` found on the owner form or set in `Frame`), the caption bar and the tab bar are
parented to `Frame.Host` (Align = Top) and the ribbon sets `Frame.CaptionHeight` to their total height; the ribbon
control itself holds only the body and the QAT bar. Without a frame (other platforms, a ribbon in a panel) all four
parts are children of the ribbon and `UpdateHeights` places them with `SetBounds`.

Parts are `TFmrRibbonPart = class(TControl, IFmrElementHost)`: a list of elements, a `TFmrElementTracker` for the
mouse, painting through the theme painter, and a `TFmrTipOverlay` child (created while key tips are shown) that paints
the key tip badges above the editor controls.

### Elements and views

Nothing in the ribbon is a styled control per button. Every painted, clickable thing is a `TFmrElement` (plain
object: bounds in host coordinates, hot/pressed part, focused flag, key tip, screen tip, `Execute`,
`OpensOnPress`). Item views are elements bound to an item link (`TFmrItemView`, `Item`, `Link`, `ViewPlace`,
`Level`). Hundreds of items cost a few objects each, and only the active tab has views.

- `TFmrElementTracker` routes mouse moves/downs/ups of a host to its elements (hot part, press, capture, drop-down
  on press, double click), starts and cancels screen tips.
- `TFmrButtonView` paints every button kind: large/small/small with text, split (main and arrow parts), drop-down,
  check, radio, button groups (`ButtonGroup` position), color items with a color bar, gallery placeholder.
- `TFmrSeparatorView`: separators in simplified mode and toolbars.
- `TFmrEditorView` (`FMR.Ribbon.Editors`): creates the FMX control of an editor item once and moves it with the
  view; the caption and glyph are painted by the view, the control is a child of the host control. Values flow both
  ways (item -> control on item change, control -> item on change/enter). The control is hidden, not destroyed, when
  its tab is not active.
- Registry: `FmrRegisterItemView(TItemClass, TViewClass)`; `FmrItemViewClass` walks up the item class chain.
  Registered: `TFmrBarItem -> TFmrButtonView`, `TFmrSeparatorItem -> TFmrSeparatorView`,
  `TFmrCustomEditItem`/`TFmrControlItem -> TFmrEditorView`.

`TFmrViewPlace`: `Group` (classic body, levels Large / SmallWithText / Small decided by `FMR.Ribbon.Layout`),
`Toolbar` (QAT, glyph only), `Simplified` (single line).

### Lazy pipeline

Changes only set flags: `InvalidateStructure` (tabs/groups/links changed: rebuild views), `InvalidateLayout`
(sizes changed: run the layout calculator), `InvalidateArrange` (place elements). `EnsureAll` brings everything up
to date; it runs on idle (`TIdleMessage`), before painting and before mouse handling, so batches of changes cost one
pass (`BeginStructureUpdate`/`EndStructureUpdate` bracket code that builds a ribbon). If arranging happens during a
paint (the non-client host drops invalidations made while painting), `FNeedRepaint` repaints the parts on the next
idle. `UpdateLayout` forces a pass.

Group collapse follows the core layout (`FMR.Ribbon.Layout`): views shrink level by level, then groups collapse into
a `TFmrCollapsedGroupElement` (large button with the group glyph/caption); when even that does not fit, the group
area scrolls with scroll buttons.

### Minimized ribbon and group popups

- `Minimized` (Ctrl+F1, double click on a tab, collapse button, QAT menu) and `ShowMode = TabsOnly` hide the body.
  Clicking a tab shows the body in a popup below the tab row (`ShowMinimizedPopup`): the body control is moved into a
  `TFmrPopupForm` and taken back with `ReleaseContent` when the popup closes. `AutoHide` behaves like `TabsOnly`.
- A collapsed group opens a `TFmrGroupPopupContent` popup that **borrows** the views of the group (`SetHost`), so
  editors keep their controls and values; they are returned on close (`ReturnViews`). The content is removed from
  the ribbon's ownership while the popup window owns it.

### Simplified mode

`DisplayMode = Simplified`: one line of small/with-text views per group, separated by separators, an overflow
button ("...") with a menu of what does not fit. Switch from the display options menu or in code.

## Popups (`FMR.Ribbon.Popup`)

- `TFmrPopupForm` is a borderless FMX form with `FormStyle = Popup` (non-activating, top-most, transparent for the
  shadow and rounded corners painted by `TFmrPopupFrame`). It holds one content control; content may implement
  `IFmrPopupContent` (size, keys, shown/closed notifications, own background).
- `FmrPopups` (`TFmrPopupManager`, singleton; `FmrPopupsAssigned` after finalization) keeps the chain of open
  popups: `Show(Popup, AnchorScreenRect, Placement, ParentPopup, ByKeyboard)` (Below / Right / AtPoint / Above,
  flipped and clamped to the work area), `Close` (closes descendants), `CloseAll`, `PopupOf(Object)`, `Top`, `IsOpen`.
  FMX closes popup forms on outside clicks and deactivation; the manager mirrors that in its chain.
- Closed windows go to a graveyard and are freed later (0.2 s and no mouse button down), because FMX may still hold
  them in its prepared-popup list while the button is pressed.
- Keyboard: popup forms never get focus. While a capturing popup chain is open or a key handler is registered
  (key tips), an invisible focusable `TFmrKeySink` takes the focus of the owner form and gives every key to the top
  popup (`PopupKeyDown`), to an editor focused inside it, then to the `IFmrKeyHandler` stack
  (`AddKeyHandler`/`RemoveKeyHandler`). The previous focus is restored afterwards; if the user clicks another control,
  popups close and handlers get `KeyboardLost`.
- `IFmrPopupContext` (`TFmrPopupContext`; the ribbon's own context) gives the painter, images, owner form, key tip
  state and two callbacks: `ItemExecuting` (hide key tips, clear the search box) and `ItemContextPopup` (right click:
  "Add to Quick Access Toolbar").
- `TFmrMenuControl`: rows from item links (glyph gutter, caption, shortcut text, check/radio marks, submenu arrows,
  split rows, separators, headers, large rows with descriptions in `Large`/`Auto` style), hover submenus after a
  delay, keyboard navigation, accelerators (the `&` letter or the first letter), key tips, scrolling when taller
  than the screen.
- `TFmrColorPaletteControl`: automatic color, theme colors with tints/shades, standard colors, no color.
- Drop-down registry: `FmrRegisterDropDown(TItemClass, Factory)`; `FmrCreateDropDownContent` uses a factory or a
  menu of the item's links (`DropDownLinks`, `TFmrSubItem.ItemLinks`). Registered: `TFmrColorItem` (palette),
  `TFmrGalleryItem` (placeholder menu until the gallery is implemented).
- `TFmrPopupMenu` (component): context menus/application menus with `ItemLinks`, painted with the theme of a ribbon
  (`ThemeSource`, any `IFmrThemeSource`) or its own `Theme`. `Popup(X, Y)`, `PopupBelow(Rect)`.
- `TFmrTempMenu` + `TFmrCommandItem`: menus built in code with anonymous methods (QAT menu, context menu, search
  results), freed with the popup (`TFmrMenuControl.OwnedObject`).

## Frame integration (`Source\Frame`)

- The ribbon finds the frame (`Frame` property or the `TFmrFormFrame` of the owner form), moves the caption bar and
  the tab bar into `Frame.Host` and keeps `Frame.CaptionHeight` = caption row + tab row (tab row only when the
  caption row is hidden). `TFmrFrameStateMessage` (hooked, mode, maximized, active) is handled on idle: caption
  buttons, heights and colors are refreshed after the frame finished attaching.
- Hit testing: the parts implement `IFmrFrameHitTest`; empty caption/tab row space is `Caption` (drag, double click
  maximizes, system menu), elements and the search box are `Client`, `TFmrRibbonCaptionButton`s report
  Min/Max/Close (Windows 11 snap layouts work on the maximize button).
- Caption buttons are created only when the bars are in the host and the frame paints the whole non-client area
  (FullNC, Dwm); placed from the right by hand. `IFmrFrameStateAware` gives the active/maximized state (inactive
  colors, maximized top offset added to the caption row height).
- Colors: `ApplyFrameColors` sets `Frame.CaptionColor`, `CaptionInactiveColor` and `DarkMode` from the theme. In
  colored-caption themes (Office 2016 Colorful...) the caption and tab rows use a cloned "bar theme" whose button and
  glyph tokens are mapped to caption tokens.
- `NCStrip`: Windows keeps its own caption; the caption bar is shown only when the QAT is above the ribbon and has
  items (no title, no window buttons in it); otherwise only the tab row is in the strip.
- No frame: the caption row inside the ribbon holds the QAT and the search box; it shows a title only when the form
  has no native title bar (`BorderStyle = None`) or `CaptionText` is set. `ShowCaption = False` removes the row.
- **Workaround (frame bug)**: the host paints its children with `TCanvas.Offset`; `TCanvasSaveState.Assign`
  re-applies the offset to the saved matrix, so every `SaveState`/`RestoreState` pair shifts what is painted next by
  the offset again. The parts and `TFmrTipOverlay` fold the offset into the matrix while painting and restore
  `Canvas.Offset` afterwards. Remove when `TFmrFrameHost.PaintBuffer` no longer uses `Offset`.

## Key tips and keyboard

- Alt or F10 pressed and released alone (`DialogKey` arms, FMX's `TStartMenuLoopMessage` enters) shows the **Top**
  level: application button and tabs (letters), QAT items and the customize button (numbers 1..9, 09, 08...).
  Typing a tip runs it: a tab goes to the **Tab** level (its views, launchers, collapsed groups, scroll buttons),
  a collapsed group opens its popup at the **GroupPopup** level, a drop-down opens with key tips on its rows, an
  editor gets the focus, a button runs and key tips end. Esc/Backspace go back one level, Alt/F10 leave.
- Tips come from `TFmrKeyTipAssigner` (core): explicit `KeyTip` of items/tabs first, then generated from captions,
  prefix-free. `TFmrKeyTipMatcher` filters badges while typing (two-letter tips).
- Letters are matched layout-independently: when the typed character matches nothing, the Latin letter of the
  physical key (`FmrLatinKeyChar`, `VkKeyScanW` on Windows) is tried, so key tips work with a Cyrillic layout.
  The same fallback applies to menu accelerators.
- Arrow keys, Tab and Enter move a keyboard focus over the tips of the current level (focused element is painted hot).
- Badges: tab tips hang below the tab row (top of the body), QAT tips below the caption row (top of the tab row),
  other tips at `KeyTipAnchor` of the element, clamped inside the part.
- Shortcuts: `DialogKey` runs the bar item whose `ShortCut` matches (Ctrl/Alt combinations and F-keys). While an
  editor of the ribbon has the focus, editing keys (Ctrl+A/C/V/X/Z/Y, Ctrl+arrows...) stay with the editor.
  Ctrl+F1 toggles `Minimized`.

## Other features

- **Screen tips** (`TFmrScreenTipController`): header (with shortcut), description, optional image and footer
  ("Press F1 for more help"), disabled note; 600 ms initial delay, quick switch between neighbours, shown below the
  element; outside the popup chain so they never close menus.
- **Search box** (`ShowSearchBox`, `SearchText`, `OnSearch`): a borderless `TEdit` in the caption row; typing shows a
  non-capturing results popup with `TFmrBarManager.SearchItems`; Up/Down/Enter/Esc are routed to it; running a
  result clears the box; Enter without a selection fires `OnSearch`.
- **Quick access toolbar** (`QuickAccessToolbar`): above/below, customize menu (items, show below/above, collapse
  the ribbon, `OnCustomizeQuickAccessToolbar` for "More Commands"), right-click "Add to/Remove from Quick Access
  Toolbar" on any view or menu row.
- **Contextual tabs**: `TFmrRibbonContextGroup` (`Visible`, `Activate`), colored headers in the caption row
  (`ShowTabGroups`), colored tabs; the title and the search box avoid the headers.
- **Application menu** (`ApplicationMenu`): a `TFmrPopupMenu` (shown below the application button), an object
  implementing `IFmrApplicationMenu`, or an object with public `ShowApplicationMenu(TFmxObject, TRectF, Boolean)` and
  `IsApplicationMenuOpen` methods called through RTTI - this is how `TFmrRibbonBackstageView` (`Source\Extras`,
  which must not use `FMR.Ribbon`) plugs in. While such a control is open over the form, the ribbon hides its tab row
  in the frame (frame keeps only the caption row) and ignores Alt; it restores everything when the view closes
  (polled on idle). `OnApplicationButtonClick` replaces all of this.
- **Themes**: `Theme` (name) and `AccentColor`; the ribbon implements `IFmrThemeProvider` (`GetFmrTheme`) and sends
  `TFmrThemeChangedMessage(Self)` after every theme rebuild (`FMR.Ribbon.ThemeLink` consumers: status bar,
  backstage). It also implements `IFmrThemeSource` for popup menus.
- **Touch mode** (`TouchMode`): larger metrics from the theme.
- **Right to left** (`RightToLeft`): groups are mirrored; captions and menus are not.
- **Persistence and merging**: `SaveLayoutTo*`/`LoadLayoutFrom*`, `Merge`/`Unmerge`/`UnmergeAll` wrap the core
  structure services and re-lay out the ribbon.
- **Design-time hooks**: `ActiveTab` is published and settable, `TabAtScreenPoint` lets a design package switch tabs
  on click, parts are not streamed.
- **Diagnostics**: `DebugDump` (parts, elements and bounds as text; the demo writes it with `/dump=`).

## Galleries, application menu, mini toolbar, radial menu

Built on the extension points above, in their own units (full description: `Docs\GALLERIES.md`):

- `FMR.Ribbon.Gallery`: `TFmrGalleryView` (`FmrRegisterItemView` for `TFmrGalleryItem`: in-ribbon gallery with the
  layout's column reduction, row scrolling, drop-down button, hot tracking, live preview, selection, one key tip) and
  `TFmrGalleryPopupContent` (`FmrRegisterDropDown`: drop-down gallery with filter band, group headers, wheel/scroll
  bar, keyboard, commands below, resize grip; also menus whose links contain galleries). `TFmrRibbonGalleryItem` adds
  `OnDrawItem` and `DropDownResize`.
- `FMR.Ribbon.ColorGallery`: drop-down of every `TFmrColorItem` (theme colors with tints/shades, standard and recent
  colors, Automatic, No Color, "More Colors..." dialog), `TFmrColorGalleryItem` (highlight palette, live preview).
- `FMR.Ribbon.AppMenu`: `TFmrRibbonApplicationMenu` - the Office 2007 application menu (`IFmrApplicationMenu`).
- `FMR.Ribbon.MiniToolbar`: `TFmrRibbonMiniToolbar` - fading floating toolbar, optionally with a context menu.
- `FMR.Ribbon.RadialMenu`: `TFmrRibbonRadialMenu` - round menu with nested rings.
- Menu rows show screen tips (`FmrMenuHotRowHook` in `FMR.Ribbon.Popup`, handler in `FMR.Ribbon.ScreenTips`).
- Hooks added for them: `TFmrElement.SetHotPart`/`MouseMoveAt` (`FMR.Ribbon.Views`); menu commands now run from the
  message loop (`TThread.ForceQueue`), so a command that shows a modal dialog no longer runs inside the mouse handler
  of a popup the popup manager frees meanwhile.

## Status

### Done (checked on screenshots, see `shots\rb_*.png`)

Themes Office 365 White/Black, 2016 Colorful, 2013 White, 2010 Blue/Silver, 2007 Blue (orb), Fluent Dark; frames
FullNC, Dwm, NCStrip, none; widths 1180/800/700/560/450 (levels, collapsed groups, scrolling); hover and pressed
states; screen tips; Paste split menu with large rows; font color palette; collapsed group popup with a borrowed
`TEdit` accepting typing; minimized ribbon (Ctrl+F1) and its tab popup; key tips Top -> Home -> Paste menu
(P, A) -> Esc back, collapsed group by key tips (S, Y) -> Heading 1 (H, 1), editor focus by key tip (G) with typing,
minimized key tips; contextual tabs toggled from Insert -> Table Tools; typing into the font name combo and Enter;
command search ("bo", "ital") with Down/Enter; QAT customize menu; right-click "Add to Quick Access Toolbar"; QAT
below; simplified mode with overflow; touch mode; File menu (`TFmrPopupMenu`) and the backstage view as application
menu (`/backstage`, tab row hidden while open). Win64 and Win32 build without warnings; tests 132/132 on both;
the demo closes without memory leaks after popups, key tips, group popups and minimized mode.

### Not done / known limitations

- Galleries, the color gallery ("More Colors...", live preview), the Office 2007 application menu, the mini toolbar,
  the radial menu and menu screen tips are done (`Docs\GALLERIES.md`, its own list of known issues).
- `ShowMode = AutoHide` behaves like `TabsOnly` (no hiding of the whole ribbon on the caption).
- Font preview in the font combo.
- Editor controls use the default FMX style (white in dark themes).
- Right to left mirrors the groups only.
- Alt+letter pressed together (without releasing Alt) does not jump to a tab; press and release Alt, then the letter.
- In minimized mode the tab key tips are drawn inside the tab row (over the captions), not below it.
- No animations (popups, minimized body, backstage slide is the backstage's own).
- Design-time package (designer, component editors) is not part of this work.

### Notes for the next agents

- New item kinds: write a `TFmrItemView` descendant and `FmrRegisterItemView`; for a popup, a `TControl` content
  implementing `IFmrPopupContent` and `FmrRegisterDropDown` (replace the gallery placeholder this way).
- Application menu / backstage: implement `IFmrApplicationMenu` or the RTTI methods above; the ribbon passes the
  application button rectangle (`ApplicationButtonScreenRect`) and `AByKeyboard`.
- Popups from other code: `TFmrPopupForm.CreatePopup(Context, Content)` + `FmrPopups.Show`; menus in code with
  `TFmrTempMenu`.
- Frame: see the `TCanvas.Offset` workaround above; `Frame.CaptionHeight` is owned by the ribbon while it is attached.

## Demo and test scripts (`Demos\RibbonBasic`)

`RibbonBasic.exe` switches: `/theme=<name> /frame=fullnc|dwm|ncstrip|none /minimized /simplified /width=N
/height=N /qatbelow /tabletools /keytips /touch /nosearch /tab=N /topmost /dump=<file> /backstage /appmenu
/open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial` (see
`Docs\GALLERIES.md`). Debug builds report memory leaks on exit.

The desktop may be shared with other windows, so the scripts do not rely on the screen:

- `drive.ps1`: starts the demo, posts mouse messages to the form or to the popup under the point
  (`move:`, `click:`, `rclick:`, `dclick:` with window-relative physical coordinates), sends keys (`key:` via
  `keys.ps1`), types (`text:` with WM_CHAR), captures (`shot:NAME`), then a final capture.
- `capture.ps1`: composes `PrintWindow` images of all windows of the process (popups included; the transparent
  shadow area of popups comes out black). PNG origin is the window at (16, 16).
- `keys.ps1`: `keybd_event` key strokes to the form made foreground (`alt`, `ctrl+F1`, `esc`, letters...).

Example: `.\tools\drive.ps1 -Arguments "/theme=Office365White /frame=fullnc" -Out shots\x.png
-Actions "key:alt;wait:500;key:H;wait:500;shot:home"`.
