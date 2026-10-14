# FMR Ribbon - the ribbon control (`Source\Ribbon`)

The visual part of FMR Ribbon: `TFmrRibbon` and everything it shows (tabs, groups, item views, editors, popups,
menus, screen tips, key tips, quick access toolbar, contextual tabs, minimized and simplified modes) and its
integration with the window frame of `Source\Frame`. The data side (bar items and links, ribbon structure, layout
calculator, themes and painter, key tip assignment, strings) is core code described in `Docs\CORE.md`.

Demo: `Demos\RibbonBasic` (a document-editor style ribbon built in code, see "Demo and test scripts" at the end).

## Units

| Unit | Contents |
|---|---|
| `FMR.Ribbon` | `TFmrRibbon`; its parts `TFmrRibbonCaptionBar`, `TFmrRibbonTabBar`, `TFmrRibbonBody`, `TFmrRibbonQATBar`, `TFmrGroupPopupContent`; caption buttons `TFmrRibbonCaptionButton`; ribbon elements (`TFmrTabElement`, `TFmrAppButtonElement`, `TFmrSysButtonElement`, `TFmrCollapsedGroupElement`, `TFmrLauncherElement`); `TFmrRibbonApplicationButton`; `IFmrApplicationMenu` |
| `FMR.Ribbon.Views` | `TFmrElement` (base of everything painted and clickable), `IFmrElementHost`, `TFmrElementTracker` (hover/press/capture), item views `TFmrItemView`, `TFmrButtonView`, `TFmrSeparatorView`, view registry `FmrRegisterItemView`, helpers (`FmrStripAccel`, `FmrShortCut`, `FmrShortCutText`, `FmrSplitLargeCaption`, `FmrLatinKeyChar`) |
| `FMR.Ribbon.Editors` | `TFmrEditorView`: real FMX controls for editor items (`TEdit`, `TComboBox`, `TComboEdit`, `TSpinBox`, `TTrackBar`) and for `TFmrControlItem` (any control), two-way value sync |
| `FMR.Ribbon.Popup` | `TFmrPopupForm`, `TFmrPopupManager` (`FmrPopups`), key sink and `IFmrKeyHandler`, `IFmrPopupContext`/`TFmrPopupContext`, `IFmrPopupContent`, menus (`TFmrMenuControl`, `TFmrMenuRow`), `TFmrColorPaletteControl`, `TFmrPopupMenu` component, `TFmrCommandItem`, `TFmrTempMenu`, drop-down registry (`FmrRegisterDropDown`, `FmrCreateDropDownContent`), `IFmrThemeSource` |
| `FMR.Ribbon.ScreenTips` | `TFmrScreenTipContent`, `TFmrScreenTipController` (delay, placement, one tip at a time) |
| `FMR.Ribbon.Fonts.Win`, `FMR.Ribbon.Fonts.Linux` | Font family list for font name editors and `FMR.Ribbon.Fonts` (Windows: EnumFontFamiliesEx; Linux: fontconfig); each is empty on the other platforms |
| `FMR.Ribbon.Gallery`, `FMR.Ribbon.ColorGallery`, `FMR.Ribbon.AppMenu`, `FMR.Ribbon.MiniToolbar`, `FMR.Ribbon.RadialMenu` | In-ribbon and drop-down galleries, color gallery, application menu in the style of Office 2007, mini toolbar, radial menu - see `Docs\GALLERIES.md` |
| `FMR.Ribbon.Customize`, `FMR.Ribbon.CustomizeModel`, `FMR.Ribbon.CustomizeControls` | Run-time customization dialog ("Customize the Ribbon", "Quick Access Toolbar"), its editing session and themed controls - see `Docs\CUSTOMIZATION.md` |
| `FMR.Ribbon.BiDi`, `FMR.Ribbon.EditorStyles` | Right-to-left helpers (canvas mirroring); editor controls styled from the theme - see `Docs\CUSTOMIZATION.md` |
| `FMR.Ribbon.UIA.Win` | UI Automation provider (`FmrInstallRibbonAutomation`) - see `Docs\ACCESSIBILITY.md` |

Additions to `Source\Themes\FMR.Ribbon.Painter.pas` (new methods only, existing signatures untouched): `TextEx`,
`DrawShadow`, `DrawPopupBackground`, `DrawCheckBox`, `DrawSearchGlyph`, `DrawCustomizeGlyph`, `DrawChevron`,
`DrawColorBar`, `DrawColorCell`, `DrawScreenTipSeparator`, `DrawBodyBackground`, `DrawMenuCheckBackground`.

## Architecture

### Parts

`TFmrRibbon` is one `TControl` (Align = Top) that owns four part controls (`Stored = False`, `Locked = True`, created
in the constructor, never streamed):

- **Caption bar**: quick access toolbar (above the ribbon), title, contextual tab group headers, search box,
  help button, window buttons (minimize, maximize/restore, close) when the bars live in the frame.
- **Tab bar**: application button ("File" tab or the orb of the Glass themes), tabs (contextual tabs with their color),
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
button ("...") with a menu of what does not fit. Switch with the chevron at the right end of the body
(`ShowDisplayModeButton`) or in code.

## Popups (`FMR.Ribbon.Popup`)

- `TFmrPopupForm` is a borderless FMX form with `FormStyle = Popup` (non-activating, top-most, transparent for the
  shadow and rounded corners painted by `TFmrPopupFrame`). It holds one content control; content may implement
  `IFmrPopupContent` (size, keys, shown/closed notifications, own background).
- `FmrPopups` (`TFmrPopupManager`, singleton; `FmrPopupsAssigned` after finalization) keeps the chain of open
  popups: `Show(Popup, AnchorScreenRect, Placement, ParentPopup, ByKeyboard)` (Below / Right / AtPoint / Above /
  BelowEnd,
  flipped and clamped to the work area), `Close` (closes descendants), `CloseAll`, `PopupOf(Object)`, `Top`, `IsOpen`.
  FMX closes popup forms on outside clicks and deactivation; the manager mirrors that in its chain.
- Closed windows go to a graveyard and are freed later (0.2 s and no mouse button down), because FMX may still hold
  them in its prepared-popup list while the button is pressed. A buried window hides its content (FMX still paints a
  hidden transparent window when its content is invalidated, and the content may show objects freed meanwhile); a
  window freed by its parent form leaves the graveyard (free notification).
- Contents that show bar items implement `IFmrItemDisplay` (`ShowsItem`, `ShowsLink`; menus, color palettes,
  drop-down galleries): an open popup whose item or link is destroyed is closed first (`FmrItemDestroyingHook`). Own
  popup contents that keep item references should implement it too.
- Focus: the key sink saves the focused control and gives the focus back when the popups close, also when they close
  because the window was deactivated (FMX keeps the sink as the focused control of the inactive form).
- Keyboard: popup forms never get focus. While a capturing popup chain is open or a key handler is registered
  (key tips), an invisible focusable `TFmrKeySink` takes the focus of the owner form and gives every key to the top
  popup (`PopupKeyDown`), to an editor focused inside it, then to the `IFmrKeyHandler` stack
  (`AddKeyHandler`/`RemoveKeyHandler`). The previous focus is restored afterwards; if the user clicks another control,
  popups close and handlers get `KeyboardLost`.
- Editors inside popups (a collapsed group, the minimized body, the mini toolbar): FMX's text input calls Windows
  `SetFocus` on the popup window when an editor gets the focus, which deactivates the owner form, and FMX closes every
  popup form then. `TFmrPopupForm.MouseDown` and `FmrFocusControl` (key tips) suppress that deactivation
  (`TWinWindowHandle.FDisableDeactivate`, set through RTTI); the popup window then has the keyboard itself and
  `TFmrPopupForm.KeyDown` gives the keys to the content first (Enter commits a group editor and closes the popup, Esc
  closes the popup). A focused editor leaves the text input before the popup window is destroyed (`DestroyHandle`).
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
  caption row is hidden). `TFmrFrameStateMessage` (hooked, mode, maximized, active) is handled when it arrives: the
  frame sends it after it finished attaching or detaching, and a change of `State.Hooked` or `State.Mode` rebuilds the
  caption buttons and the heights at once (no idle polling).
- Hit testing: the parts implement `IFmrFrameHitTest`; empty caption/tab row space is `Caption` (drag, double click
  maximizes, system menu), elements and the search box are `Client`, `TFmrRibbonCaptionButton`s report
  Min/Max/Close (Windows 11 snap layouts work on the maximize button).
- Caption buttons are created only when the bars are in the host and the frame paints the whole non-client area
  (FullNC, Dwm); placed from the right by hand. `IFmrFrameStateAware` gives the active/maximized state (inactive
  colors, maximized top offset added to the caption row height).
- Colors: `ApplyFrameColors` sets `Frame.CaptionColor`, `CaptionInactiveColor` and `DarkMode` from the theme. In
  colored-caption themes (BannerColorful...) and whenever the glyph color does not read on the caption color
  (contrast below 3: the dark captions of GlassBlack, ClassicBlack and BannerDarkGray, or a StyleBook override)
  the caption and tab rows use a cloned "bar theme" whose button, glyph and disabled tokens are mapped to caption
  tokens.
- `NCStrip`: Windows keeps its own caption; the caption bar is shown only when the QAT is above the ribbon and has
  items (no title, no window buttons in it); otherwise only the tab row is in the strip.
- A frame that is **not attached at run time** on a window with a border (Linux under FMXWayland's title bar without
  `IFMXWaylandWindowFrame`, a disabled frame) is treated the same way (`CaptionUnderNativeTitleBar`): the host is at
  the top of the client area under the system title bar, so no second title and no window buttons; `ShowCaption`
  keeps its streamed default. At design time the title stays (the host shows the caption content in the designer).
- Platforms that move the window themselves (`FMR.Frame.Wayland`): presses on caption space of the caption and tab
  rows go to `TFmrFrameHost.HandleFrameMouseDown` first (move, window menu, double-click maximize); on Windows it
  returns False at once (`WM_NCHITTEST` handles them before FMX sees them).
- No frame: the caption row inside the ribbon holds the QAT and the search box; it shows a title only when the form
  has no native title bar (`BorderStyle = None`) or `CaptionText` is set. `ShowCaption = False` removes the row.
- **Canvas offset**: the host paints the non-client strip with relative matrices (`Docs\FRAME.md`), so the parts
  normally paint with `Canvas.Offset` = 0. Only while an FMX drop-down of a control in the host is open (a themed
  combo in the QAT) the host falls back to `TCanvas.Offset`, which `TCanvasSaveState` would apply a second time after
  every `RestoreState`: for that case the parts and `TFmrTipOverlay` fold a non-zero offset into the matrix while they
  paint (`TFmrCanvasOffsetGuard`; a no-op otherwise). The old unconditional workaround is gone.

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
  other tips at `KeyTipAnchor` of the element, clamped inside the part. When the body is hidden (minimized ribbon,
  Show Tabs) the tab tips are painted by an overlay control on the form right below the tab row (`TFmrTabTipOverlay`),
  so they do not cover the tab captions.
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
- **Right to left** (`RightToLeft` or the form's `BiDiMode`): everything is mirrored - parts and popups flip
  their canvas and mouse coordinates (logical geometry stays left to right); text and icons are drawn unmirrored;
  editors, the search box and caption buttons get mirrored bounds (`Docs\CUSTOMIZATION.md`).
- **Display options and auto-hide** (`ShowDisplayOptionsButton`, `ShowMode = AutoHide`): a caption
  button with Auto-hide Ribbon / Show Tabs / Show Tabs and Commands; auto-hide keeps only the caption row and shows
  tabs and commands in an overlay popup (`ShowAutoHiddenRibbon`).
- **Customization form** (`ShowCustomizationForm`, QAT "More Commands...", ribbon menu "Customize the Ribbon..."),
  `DefaultLayout`/`ResetLayout`; **themed editors**; **UI Automation** (`AccessibilityNodes`,
  `FMR.Ribbon.UIA.Win`, `Docs\ACCESSIBILITY.md`).
- **Persistence and merging**: `SaveLayoutTo*`/`LoadLayoutFrom*`, `Merge`/`Unmerge`/`UnmergeAll` wrap the core
  structure services and re-lay out the ribbon.
- **Design time**: the ribbon is design-interactive and implements `IFmrRibbonDesignSupport` (hit tests, bounds, drop
  targets, insertion mark and dashed selection frames painted in `AfterPaint` of the parts, `DesignSelectTab` that
  also shows a tab of a hidden contextual group); it passes the mouse to the design package's hook; parts are locked
  and not streamed; no events run at design time; `TFmrControlItem` controls stay where the form has them. Full
  description: `Docs\DESIGNTIME.md`, "Phase B". `ActiveTab` is published and settable, `TabAtScreenPoint` is kept.
- **Diagnostics**: `DebugDump` (parts, elements and bounds as text; the demo writes it with `/dump=`).

## Modern 2024: caption row and tab row extras, focus effect

- **Caption row and tab row toolbars** (like the tab area toolbars of other ribbons): `CaptionToolbar` (links at the
  right end of the caption row, left of the window buttons: the account picture) and `TabAreaToolbar` (links at the
  right end of the tab row: Comments, Share), both `TFmrRibbonItemBar` (`ItemLinks`, `Visible`; `AddItem`). Their
  views are toolbar views (`TFmrViewPlace.Toolbar`) hosted by the caption bar and the tab bar: glyph only, or glyph
  and caption when the link's `ViewLevels` contain `SmallWithText`; they take key tips at the top level and are
  `Client` for the frame hit test.
- **`ApplicationIcon`** (`TFmrImageSource`, an SVG keeps its colors): 16 dp icon at the left end of the caption row,
  the window menu on a click (`SysMenu` hit test).
- **Items for them** (`FMR.Bars.Items`, painted by `TFmrButtonView`): `TFmrCheckItem.CheckStyle = ToggleSwitch`
  (caption then a toggle switch: an "AutoSave" switch), `TFmrButtonItem.Primary` (filled with the accent in
  every state: "Share"; a split primary button is one shape), `TFmrAvatarItem` (initials in a colored circle,
  `Initials`, `Color`; a drop-down button for the account menu). New painter methods: `DrawToggleSwitch`,
  `DrawPrimaryButton`, `DrawAvatar`, `TabCaptionWidth`.
- **Layout of the Modern 2024 themes** (style switches and metrics in `Docs\STYLES.md`): the title follows the quick
  access toolbar (`LeadingTitle`), the search box is centered with its own size, the window buttons are 48 dp wide,
  tabs are as wide as their bold caption, the collapse button is a chevron in the bottom right corner of the card
  (a pin in the body of a collapsed ribbon), two-row groups keep their rows at the top (`MaxRowGap`), an in-ribbon
  gallery is one row of cells at the top of its group, the area around the card and the caption are transparent
  over Mica (or `CaptionBackdropFill`).
- **Focus effect.** The ribbon follows the active state of its window: the frame state (`TFmrFrameStateMessage`,
  `IFmrFrameStateAware`) when the bars are in a hooked frame, `TFormActivateMessage`/`TFormDeactivateMessage`
  otherwise; it stays active while one of its popups is open (an editor of a popup may deactivate the window for a
  moment; FMX closes the popups when another window is activated, and the next idle check makes the caption
  inactive). The transition takes about 170 ms (`AnimateActivation`, `ActiveLevel`): the base bar theme is blended
  into the tab row theme (caption and tab row fills, `TabTextInactive`) and the caption row theme (title, quick access
  toolbar, caption toolbar, search box and window buttons fade to `CaptionTextInactive`, `SearchBoxFillInactive`).
  The caption row has its own painter for that. `ShowInactiveState = False` keeps the active look. Checked on
  screenshots of the showcase application (now Demos\Notes), Light and Dark Gray, active and inactive windows.

## Galleries, application menu, mini toolbar, radial menu

Built on the extension points above, in their own units (full description: `Docs\GALLERIES.md`):

- `FMR.Ribbon.Gallery`: `TFmrGalleryView` (`FmrRegisterItemView` for `TFmrGalleryItem`: in-ribbon gallery with the
  layout's column reduction, row scrolling (also with the mouse wheel: `TFmrElement.MouseWheel`, the parts ask the hot
  element before switching tabs), drop-down button, hot tracking, live preview, selection, one key tip) and
  `TFmrGalleryPopupContent` (`FmrRegisterDropDown`: drop-down gallery with filter band, group headers, wheel/scroll
  bar, keyboard, commands below, resize grip; also menus whose links contain galleries). `TFmrRibbonGalleryItem` adds
  `OnDrawItem` and `DropDownResize`.
- `FMR.Ribbon.ColorGallery`: drop-down of every `TFmrColorItem` (theme colors with tints/shades, standard and recent
  colors, Automatic, No Color, "More Colors..." dialog), `TFmrColorGalleryItem` (highlight palette, live preview).
- `FMR.Ribbon.AppMenu`: `TFmrRibbonApplicationMenu` - the application menu in the style of Office 2007 (`IFmrApplicationMenu`).
- `FMR.Ribbon.MiniToolbar`: `TFmrRibbonMiniToolbar` - fading floating toolbar, optionally with a context menu.
- `FMR.Ribbon.RadialMenu`: `TFmrRibbonRadialMenu` - round menu with nested rings.
- Menu rows show screen tips (`FmrMenuHotRowHook` in `FMR.Ribbon.Popup`, handler in `FMR.Ribbon.ScreenTips`).
- Hooks added for them: `TFmrElement.SetHotPart`/`MouseMoveAt` (`FMR.Ribbon.Views`); menu commands now run from the
  message loop (`TThread.ForceQueue`), so a command that shows a modal dialog no longer runs inside the mouse handler
  of a popup the popup manager frees meanwhile.

## Status

### Done (checked on screenshots, see `shots\rb_*.png`)

Themes Modern White/Black, Banner Colorful, Flat White, Classic Blue/Silver, Glass Blue (orb), Soft Dark; frames
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

- Galleries, the color gallery ("More Colors...", live preview), the application menu, the mini toolbar,
  the radial menu and menu screen tips are done (`Docs\GALLERIES.md`, its own list of known issues).
- Auto-hide, themed editors, full right to left, the customization form and UI Automation are done
  (`Docs\CUSTOMIZATION.md`, `Docs\ACCESSIBILITY.md`, their own lists of known issues).
- Font preview in the font combo.
- Alt+letter pressed together (without releasing Alt) does not jump to a tab; press and release Alt, then the letter.
- No animations (popups, minimized body, backstage slide is the backstage's own) apart from the focus effect of the
  caption row.
- While an editor of a popup has the keyboard, Windows activated the popup window; the ribbon keeps its active look
  while its popups are open, the DWM border of the window still shows the inactive state.

### Design time and follow-up fixes (phase B)

- In-form design (`Docs\DESIGNTIME.md`, "Phase B"): checked with `DesignPreview.exe /realtest` against a real ribbon
  in a simulated designer (45 checks, Win64 and Win32) and on screenshots (`shots\design\real_*.png`).
- Canvas offset workaround reduced to the drop-down fallback case; frame state handled from the message.
- Checked again on screenshots (`shots\b3\`): RibbonBasic in FullNC, Dwm, NCStrip and without frame with key tips
  (Alt, H) and the Paste menu (P, A); minimized ribbon key tips below the tab row (FullNC and no frame) and the Home
  popup with its tips; wheel over the in-ribbon styles gallery scrolls one row (tab unchanged), elsewhere it switches
  tabs; drop-down gallery entry tip right of the drop-down; dark themed font list scroll bar; themed "More Colors"
  dialog (SoftDark, dark title bar); typing into the mini toolbar's font size (28 + Enter applied, toolbar kept);
  typing into the editor of a collapsed group popup; the backstage "Back" hint gone after Esc.
- Closing the form with a group popup open (with a focused editor), the mini toolbar with a focused editor, the
  minimized ribbon with key tips, the color gallery, the backstage: no error, no leak report (`tools\closecheck.ps1`).
  Two exit bugs found and fixed: the key sink could be freed twice (the form freed it, then the queued release), and a
  focused editor in a popup raised "AFormHandle cannot be nil" when the popup was destroyed after its window.

### Notes for the next agents

- New item kinds: write a `TFmrItemView` descendant and `FmrRegisterItemView`; for a popup, a `TControl` content
  implementing `IFmrPopupContent` and `FmrRegisterDropDown` (replace the gallery placeholder this way).
- Application menu / backstage: implement `IFmrApplicationMenu` or the RTTI methods above; the ribbon passes the
  application button rectangle (`ApplicationButtonScreenRect`) and `AByKeyboard`.
- Popups from other code: `TFmrPopupForm.CreatePopup(Context, Content)` + `FmrPopups.Show`; menus in code with
  `TFmrTempMenu`.
- Frame: `Frame.CaptionHeight` is owned by the ribbon while it is attached; the canvas offset guard above only acts
  while an FMX drop-down of a host control is open.
- Design time: new parts or child controls of the ribbon must be `Locked`/`Stored = False` and must not take the
  mouse at design time (`TFmrRibbonPart.ObjectAtPoint`); new events must not run with `csDesigning`.

## Demo and test scripts (`Demos\RibbonBasic`)

`RibbonBasic.exe` switches: `/theme=<name> /frame=fullnc|dwm|ncstrip|none /minimized /simplified /width=N
/height=N /qatbelow /tabletools /keytips /touch /nosearch /tab=N /topmost /dump=<file> /backstage /appmenu
/open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial` (see
`Docs\GALLERIES.md`). Debug builds report memory leaks on exit.

The desktop may be shared with other windows, so the scripts do not rely on the screen:

- `drive.ps1`: starts the demo, posts mouse messages to the form or to the popup under the point
  (`move:`, `click:`, `rclick:`, `dclick:` with window-relative physical coordinates, `wheel:X,Y,NOTCHES`), sends
  keys (`key:` via `keys.ps1`), types (`text:` with WM_CHAR), captures (`shot:NAME`), then a final capture. Start with
  `key:shift` so the form is the foreground window: FMX closes popups when the form is deactivated.
- `keys.ps1`: when `SetForegroundWindow` is refused (another process owns the foreground) it attaches to the
  foreground thread's input first.
- `closecheck.ps1`: runs `drive.ps1`, closes the form with WM_CLOSE and reports a process that does not end (an error
  or the leak report of a Debug build; screenshot `*_hang.png`).
- `capture.ps1`: composes `PrintWindow` images of all windows of the process (popups included; the transparent
  shadow area of popups comes out black). PNG origin is the window at (16, 16).
- `keys.ps1`: `keybd_event` key strokes to the form made foreground (`alt`, `ctrl+F1`, `esc`, letters...).

Example: `.\tools\drive.ps1 -Arguments "/theme=ModernWhite /frame=fullnc" -Out shots\x.png
-Actions "key:alt;wait:500;key:H;wait:500;shot:home"`.

Screenshots without disturbing somebody who works at the desktop: `drive.ps1 -NoCursor` (posted mouse messages, the
real cursor stays) and the demo switches `/pos=X,Y` (RibbonBasic, Notes, Extras: the window mostly outside the visible
desktop, PrintWindow still renders it), `/topmost` (an occluded window is not painted by the Direct2D canvas: the
visible strip of it must stay on top) and `/activelook` (`ShowInactiveState = False`: a window started in the
background keeps the active caption). `drive.ps1 ... -Actions "post:0x86,1,0"` posts `WM_NCACTIVATE` (Dwm mode: the
active look; in FullNC Windows corrects it to inactive). `tools\sidebyside.ps1` puts the same region of two
screenshots one above the other (before/after comparisons of a change).
