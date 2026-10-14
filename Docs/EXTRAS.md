# FMR Ribbon — companion controls: backstage view and status bar

`Source\Extras\` holds the controls that live next to the ribbon: the **backstage view** ("File"
view) and the **status bar**. Both work on their own (own `Theme` / `AccentColor`) and with the ribbon
(`ThemeProvider` = the `TFmrRibbon`, or any object implementing `IFmrThemeProvider`). Demo: `Demos\Extras\ExtrasDemo.dpr`.

## Units

| Unit | Content |
|---|---|
| `FMR.Ribbon.Extras.Layout` | Pure logic, no FMX: status bar panel placement (`FmrLayoutStatusPanels`), zoom scale (`FmrZoomToFraction` / `FmrFractionToZoom`, 100 % in the middle), zoom steps (`FmrZoomStep`), keyboard navigation over selectable entries (`FmrNextSelectable`, `FmrEdgeSelectable`), scroll clamping. Tested by `Tests\FMR.Tests.Extras` (12 tests) |
| `FMR.Ribbon.ThemeLink` | `TFmrThemeLink`: the theme of a companion control — explicit provider, else the nearest parent that is a provider, else an own theme built from `ThemeName` + `AccentColor` with the form's StyleBook tokens applied. Listens to `TFmrThemeChangedMessage` and `TStyleChangedMessage` |
| `FMR.Ribbon.StatusBar` | `TFmrStatusBar`, `TFmrStatusBarPanel` |
| `FMR.Ribbon.Backstage` | `TFmrRibbonBackstageView`, `TFmrBackstageTab`, `TFmrBackstageButton`, `TFmrBackstageViewMessage` |
| `FMR.Ribbon.Backstage.Controls` | Themed content helpers: `TFmrBackstageLabel`, `TFmrBackstageHeader`, `TFmrBackstageTile`, `TFmrBackstageGalleryList` (+ `TFmrBackstageGalleryItem(s)`) |

All classes are registered for streaming with `RegisterFmxClasses` in the initialization sections. Nothing was added to
`FMR.Ribbon.Painter`: the controls paint with its existing primitives (`Fill`, `Frame`, `Line`, `TextEx`,
`DrawStatusBar`, `DrawKeyTip`, `DrawAppButton`…) and theme tokens.

## Theme sources

| Situation | Theme used |
|---|---|
| `ThemeProvider` set (the `TFmrRibbon`) | `IFmrThemeProvider.GetFmrTheme` of the provider; repainted on its `TFmrThemeChangedMessage` |
| No provider, placed inside a provider (panels in a status bar, helpers in a backstage view) | the parent's theme |
| Standalone | `TFmrTheme.CreateTheme(Theme, AccentColor)` + `ApplyStyleOverrides` of the form's StyleBook |

`TFmrStatusBar` and `TFmrRibbonBackstageView` implement `IFmrThemeProvider` themselves (for their children) and send
`TFmrThemeChangedMessage(Self)` when their theme changes. The method returning the `TFmrTheme` object is
`CurrentTheme` (the published `Theme` property is the name of the standalone theme).

Contract for a provider (the ribbon): assign the new theme first, then send `TFmrThemeChangedMessage(Self)`, then
free the old theme (`TDemoThemeProvider.SetTheme` in the demo does exactly this).

## Backstage view

```
TFmrRibbonBackstageView (TControl; hidden at run time until Show, Align = Contents when shown)
├── TFmrBackstageTab  "Info"      (TControl container: drop any FMX controls into it)
├── TFmrBackstageTab  "New"
├── TFmrBackstageTab  "Open"
├── TFmrBackstageButton "Save"    (TFmxObject: a command)        BeginGroup
├── TFmrBackstageTab  "Save As"
├── TFmrBackstageTab  "Print"
├── TFmrBackstageButton "Close"                                   BeginGroup
├── TFmrBackstageTab  "Account"                                   NavAlign = Bottom
└── TFmrBackstageButton "Options"                                 NavAlign = Bottom, KeepOpen
```

**Decision — children, not collections.** Tabs and buttons are children of the view, in navigation order (child
order). Tabs must be real containers so the designer can drop controls into them; making buttons children too gives
one ordered list (Save between Open and Save As) that FMX streams with no extra code, the Structure
View shows and drag & drop reorders. `TFmrBackstageButton` is a `TFmxObject` (like the bar items of a bar manager),
not a control, so it does not clutter the designer surface.

### `TFmrRibbonBackstageView`

| Property / event | Meaning |
|---|---|
| `ActiveTab` | Visible tab (only the active tab is visible; `TFmrBackstageTab.Visible` is managed and not stored) |
| `NavigationWidth` | dp, 0 = automatic (fits the captions; at least 132–172 dp depending on the theme family; at most half the view) |
| `ShowBackButton` | Back arrow at the top of the pane (round in the Flat and Banner themes, flat in Modern, Modern 2024, Soft and Classic); closes the view |
| `Caption` | Optional title next to the back button |
| `NavGlyphs` | `Auto` (glyphs for the Modern, Modern 2024 and Soft themes), `Show`, `Hide` |
| `Animation` | `Slide` (default: fade in + content slides 48 dp from the left, 220 ms ease-out), `Fade`, `None` |
| `KeepCaptionVisible` | In the frame's Dwm mode (caption host in the client area) the view starts below the caption host |
| `ThemeProvider`, `Theme`, `AccentColor` | See "Theme sources" |
| `BarManager` | Images (`TFmrBarManager.Images`) for glyphs with an `ImageIndex`, and for helper controls inside the tabs |
| `Align` | Design time only (at run time it is always `Contents`) |
| `OnShow`, `OnHide` | After the view was shown / hidden (also broadcast as `TFmrBackstageViewMessage`) |
| `OnTabChanging(Sender, NewTab, var Allow)`, `OnTabChanged` | Tab switch by mouse, keyboard or code |
| `OnButtonClick(Sender, Button)` | After a navigation button ran |
| Methods | `Show(AByKeyboard = False)`, `Hide`, `Toggle`, `ClickButton`, `AddTab`, `AddButton`, `InvalidateNavigation`, `ItemRect`, `NavigationPaneWidth`, `CurrentTheme`, `Painter`; `IsOpen`, `KeyTipsVisible`, `Tabs[]`, `Buttons[]` |
| Ribbon protocol | `ShowApplicationMenu(ARibbon, AAnchor, AByKeyboard)`, `IsApplicationMenuOpen`, `CloseApplicationMenu` (see "Connecting to the ribbon") |

`TFmrBackstageTab`: `Caption`, `Glyph` (`TFmrImageSource`), `BeginGroup` (separator above), `KeyTip`, `NavAlign`
(`Top`/`Bottom`), `TabVisible`, `Enabled`, `Hint`, `Padding` (default 40, 24, 40, 20), `Activate`.

`TFmrBackstageButton`: `Caption`, `Glyph`, `BeginGroup`, `Enabled`, `Visible`, `Hint`, `KeyTip`, `NavAlign`,
`KeepOpen` (clicking does not close the view), `Item` (optional `TFmrBarItem`: caption/glyph when empty, runs when
`OnClick` is not assigned), `OnClick`. A click closes the view first, then runs the command (a dialog opened by
the command shows over the document).

### Behavior

- **Show**: remembers the focused control, sets `Align = Contents`, `BringToFront`, makes the view visible (animated),
  focuses the navigation pane, fires `OnShow` and `TFmrBackstageViewMessage(View, True)`. The view covers its parent
  completely (the status bar too).
- **Hide**: Esc (from anywhere in the view: the form passes dialog keys to unfocused controls), the back button,
  a navigation button (unless `KeepOpen`), or code. Gives the focus back, fires `OnHide` and the message.
- **Keyboard** (navigation pane focused): Up/Down (skip disabled items, wrap; moving over a tab shows it),
  Home/End, Enter/Space (tab: focus its first control; button: run it), Right (focus the content).
  **Key tips**: `Show(True)` (or Alt while the pane is focused) shows key tips over the item glyphs (left of the text
  without glyphs); they are generated with `TFmrKeyTipAssigner` from the captions or taken from `KeyTip`, typed with
  `TFmrKeyTipMatcher` (partial matches hide the others, Backspace, Esc clears the typed text).
- **Mouse**: hover/pressed/selected highlights, tooltips (`Hint` of items, "Back" for the back button).
- **Painting** (tokens): `BackstageFill` (content), `BackstageNavFill` (pane; the accent in the Flat and Banner themes
  and ModernColorful), `BackstageNavText`, `BackstageNavHotFill`, `BackstageNavSelectedFill`, `BackstageNavSelectedText`,
  `BackstageNavSeparator` (group lines; the pane border in Classic, Modern and Soft), `TabActiveIndicator` (accent bar of the
  selected item in ModernWhite/DarkGray/Black, Modern 2024 and Soft), `KeyTip*`. Metrics per family: Glass/Classic (compact
  items, rounded highlights), Flat/Banner (40 dp items, larger font, round back button, flat full-width highlight), Modern/Soft
  (rounded inset highlight, glyphs, accent bar).

### Helper controls (`FMR.Ribbon.Backstage.Controls`)

All take the theme of the view they are in (and the images of its `BarManager`).

| Control | Use |
|---|---|
| `TFmrBackstageLabel` | `Text`, `TextStyle` (`Header`, `Title`, `Subtitle` (bold), `Normal`, `Secondary` = `BackstageText` color), `WordWrap`, `AutoSize` (height follows the wrapped text), `Bold`, `HorzAlign`/`VertAlign`. Header/Title use Segoe UI Light when the theme font is Segoe UI |
| `TFmrBackstageHeader` | `TFmrBackstageLabel` with `TextStyle = Header`, `Align = Top`, bottom margin 8 — the "Info" / "Open" page title |
| `TFmrBackstageTile` | Big button: `Caption`, `Description`, `Glyph`, `GlyphSize`, `Layout` (`Vertical`: glyph above caption — Protect Document, Print; `Horizontal`: glyph left of caption + description — Save As locations), `ShowFrame`, `Selected`, `OnClick`; focusable (Enter/Space) |
| `TFmrBackstageGalleryList` | Recent files: `Items` (collection: `Caption`, `Description` (path), `Glyph` (empty = document glyph in the accent color), `Header` (group caption "Today"), `Hint`, `Tag`, `Data`), `ItemIndex`, `ItemHeight`, hot tracking, selection, Up/Down/Home/End/Enter, wheel scrolling with a thin scroll indicator, `OnItemClick`, `OnChange` |

### The frame and the tab row

While the backstage is open the title bar stays visible and the ribbon's tab row is hidden. With
`TFmrFormFrame` in `FullNC`/`NCStrip` the caption row and the tab row are in the non-client host, so the view (in the
client area) never covers them; the ribbon must hide its tab row and shrink `Frame.CaptionHeight` while the view is
open, and restore both when it closes. `ExtrasDemo /frame` does exactly that in `BackstageShow` / `BackstageHide`
(checked on screenshots: title bar stays, tab row gone, non-client top 109 px → 58 px at 150 %, restored on Esc).
In the `Dwm` mode the host is a `MostTop` control of the client area; the view starts below it
(`KeepCaptionVisible`, default True), so the title bar stays visible there too (checked: `/frame=dwm`).

Hooks for the ribbon: `OnShow` / `OnHide` of the view, or (better, no event handler taken from the user) the
broadcast `TFmrBackstageViewMessage` (`View`, `IsOpen`).

### Designing it in the IDE

(The design-time package is not part of this work; see "What the coordinator must do".)

- Drop a `TFmrRibbonBackstageView` on the form. At design time it is an ordinary control (default 640 × 400; set
  `Align = Client` while designing if you like — at run time it is always hidden until `Show` and then covers the
  form). To get it out of the way in the designer set `Visible = False`: `Visible` is ignored at run time.
- Add tabs: drop `TFmrBackstageTab` on the view; a dropped tab becomes the active tab at once. Click a navigation
  item in the designer to show its tab (the view is design-interactive and selects the tab), or set `ActiveTab`.
- Drop any controls into the active tab (controls dropped on the view itself are moved into the active tab).
- Add commands: `TFmrBackstageButton` is non-visual; put it on the view (or drag it onto the view in the Structure
  View). The order of children is the navigation order (reorder in the Structure View).
- Content: `TFmrBackstageHeader` at the top of each tab, labels/tiles/gallery lists or any FMX controls.

## Status bar

```
TFmrStatusBar (TControl, Align = Bottom, Height = theme StatusBarHeight)
├── TFmrStatusBarPanel  Kind=Text        "Page 1 of 3"   OnClick, Hint
├── TFmrStatusBarPanel  Kind=Text        "245 words"
├── TFmrStatusBarPanel  Kind=Text        "English (United States)"  Glyph
├── TFmrStatusBarPanel  Kind=Container   PanelWidth=96   └── TProgressBar (any child controls)
├── TFmrStatusBarPanel  Kind=ItemLinks   Side=Right      ItemLinks → bar manager items (Focus, Comments)
├── TFmrStatusBarPanel  Kind=ViewButtons Side=Right      Read / Print / Web
└── TFmrStatusBarPanel  Kind=ZoomSlider  Side=Right      − ─────┼───── + 100%
```

**Decision — panels are child controls** (`TFmrStatusBarPanel = class(TControl)`, not a plain `TFmxObject`): a
`Container` panel must host controls, and as controls all panels get mouse events, hints (`Hint`/`ShowHint` of FMX),
design-time selection and reordering for free. The status bar sets their bounds.

### `TFmrStatusBar`

`AutoHeight` (default True: `StatusBarHeight` of the theme), `PanelSpacing`, `BarManager` (images of item links),
`ShowSizeGrip` (dots at the right end; dragging resizes the form through FMX's `ISizeGrip`; not needed for windows
with a sizing border), `ThemeProvider` / `Theme` / `AccentColor`, `OnLinkClick(Sender, Panel, Link, var Handled)`;
`AddPanel(Kind, Text, Side)`, `Panels[]`, `PanelCount`, `UpdatePanels`, `CurrentTheme`, `Painter`.
Paints `DrawStatusBar` (`StatusBarFill` + `StatusBarSeparator` line at the top).

### `TFmrStatusBarPanel`

| Property | Meaning |
|---|---|
| `Kind` | `Text`, `Container`, `ItemLinks`, `ZoomSlider`, `ViewButtons` |
| `Side` | `Left` (placed from the left in child order) / `Right` (ends at the right edge, in child order) |
| `Text`, `Glyph`, `Alignment` | Text panels (glyph before the text) |
| `PanelWidth` (0 = fit content; Container: 100), `MinWidth`, `Stretch` (shares the free width) | Placement. When the bar is too narrow: stretch panels shrink to `MinWidth`, then left panels from the last one, then left panels are hidden from the last one, then right panels shrink/hide from the first one |
| `Bevel` | `Auto` (separator lines for the Glass and Classic themes, none for flat themes), `None`, `Separator`, `Frame` |
| `ItemLinks` | `TFmrItemLinks` (the panel is the `IFmrItemLinksOwner`): small buttons painted by the panel (glyph, caption when the link's `ViewLevels = [SmallWithText]`, static items or no glyph), checked state from `Item.IsChecked`, `BeginGroup`/separator items; a click runs `Item.Click` unless `OnLinkClick` handles it; hint = item hint or caption |
| `Zoom`, `ZoomMin` (10), `ZoomMax` (500), `ZoomStep` (10), `SliderWidth` (100), `ShowZoomPercent` | Zoom slider: − / + go to the previous/next multiple of `ZoomStep`; click on the track jumps, drag the thumb; the 100 % tick is in the middle (left half 10…100, right half 100…500) and snaps within 4 dp |
| `OnZoomChange`, `OnZoomClick` | Zoom changed / the percentage was clicked (for example to open a zoom dialog) |
| `ActiveView`, `Views`, `OnViewChange` | View buttons (Read Mode: open book, Print Layout: page, Web Layout: globe), checked look for the active one |
| `Hint`, `ShowHint` (default True), `OnClick` (Text: hot tracked only when assigned), `Enabled`, `Visible`, `Padding` | Standard |

Per-part tooltips: "Zoom Out", "Zoom In", "Zoom", "Zoom level", "Read Mode", "Print Layout", "Web Layout", link hints
(resourcestrings in the unit). Tokens: `StatusBarFill`, `StatusBarText`, `StatusBarSeparator`,
`StatusBarItemHotFill` (hover; pressed/checked are blends of it with the text color).

### Designing it in the IDE

Drop a `TFmrStatusBar` (it aligns to the bottom); drop `TFmrStatusBarPanel`s on it and set `Kind`/`Side`; for
`Container` panels drop controls into the panel; for `ItemLinks` panels set the status bar's `BarManager` and edit
`ItemLinks` (collection editor, `Item` = a bar item).

## Connecting to the ribbon (what the coordinator must do)

1. **Theme**: set `ThemeProvider := Ribbon1` on the status bar and the backstage view (or leave it nil for the view:
   `ShowApplicationMenu` adopts the ribbon). `TFmrRibbon` must send `TFmrThemeChangedMessage(Self)` after it
   replaced its theme (see the provider contract above).
2. **Application menu**: `TFmrRibbon.ApplicationMenu := BackstageView1`. `FMR.Ribbon` declares `IFmrApplicationMenu`
   with `ARibbon: TFmrRibbon`; `FMR.Ribbon.Backstage` cannot use `FMR.Ribbon` (it is a companion unit and must not
   depend on the ribbon). The view already has the three methods with `ARibbon: TFmxObject`
   (`ShowApplicationMenu`, `IsApplicationMenuOpen`, `CloseApplicationMenu`). Either
   - move `IFmrApplicationMenu` into a shared unit (e.g. `FMR.Ribbon.Types` or `FMR.Ribbon.Theme`) with
     `const ARibbon: TFmxObject`, and add it to the class declaration of `TFmrRibbonBackstageView` (one line), or
   - in the ribbon: `if FApplicationMenu is TFmrRibbonBackstageView then TFmrRibbonBackstageView(FApplicationMenu).ShowApplicationMenu(Self, Anchor, ByKeyboard)`.
3. **Tab row**: subscribe to `TFmrBackstageViewMessage`; when `Msg.View = ApplicationMenu`: on `IsOpen` hide the tab
   row (and the QAT below the ribbon) and set `Frame.CaptionHeight` to the caption row height; on close restore
   them. Without a frame (ribbon rows inside the ribbon) nothing is needed: the view covers the whole client area.
4. **Key tips**: while the view is open the ribbon should not process Alt/key tips itself (the view handles Alt
   when its pane is focused). Opening by keyboard (Alt, F) → `ShowApplicationMenu(..., AByKeyboard = True)`, which
   shows the view's key tips immediately.
5. **Design package**: register `TFmrRibbonBackstageView`, `TFmrStatusBar` and the helper controls
   (`TFmrBackstageHeader`, `TFmrBackstageLabel`, `TFmrBackstageTile`, `TFmrBackstageGalleryList`) on the palette;
   `TFmrBackstageTab`, `TFmrBackstageButton`, `TFmrStatusBarPanel` too (or with `RegisterNoIcon` plus component
   editor verbs "Add Tab", "Add Button", "Add Panel" that call `AddTab`/`AddButton`/`AddPanel`).
6. **Packages**: add `Source\Extras\*.pas` to `FMRRibbon.dpk`.

## Bug fix outside `Source\Extras`

`Source\Frame\FMR.Frame.Win.pas`, `TFmrWinFrame.ApplyWindowStyle`: the decision to remove `WS_CAPTION` (FullNC, Dwm
with a backdrop) required `WS_CAPTION` to be present in the current style. After the first `FrameChanged` removed
it, every later `FrameChanged` (a `CaptionHeight`, color or dark mode change at run time) computed "not wanted" and
called `RestoreWindowStyle`: the window got its system caption back (style `0x16CF0000`, non-client top 48 px,
system title bar over the strip). Found when the demo shrank `CaptionHeight` on backstage open. Fix: the mode alone
decides; the current style only guards the removal. Checked: `/frame` + `CaptionHeight` 66 → 32 dp keeps style
`0x160F0000`, non-client top 109 → 58 px; mode switches still restore the caption (`WantRemoved` False with
`FCaptionStyleRemoved`).

## Demo (`Demos\Extras\ExtrasDemo.dpr`)

Form built in code: a top bar with a "File" button (painted with `TFmrRibbonPainter.DrawAppButton`/`DrawTab`) and a
theme combo box, a page preview that follows the zoom and view buttons, a status bar (Page 1 of 3, word count,
language with a glyph, a progress bar in a container panel, Focus/Comments item links, view buttons, zoom slider)
and the backstage view: Info (header, document title/path, three vertical tiles with descriptions, properties
column), New (template cards made of `TFlowLayout`/`TRectangle`/`TText`), Open (location tiles + recent files
gallery with group headers), Save (button), Save As (location tiles, `TEdit`, `TComboBox`, `TButton`), Print (print
tile, copies `TSpinBox`, printer combo, settings, `TImage` preview), Close (button), Account (bottom; theme combo),
Options (bottom button, `KeepOpen`). Themes come from `TDemoThemeProvider` (a stand-in for `TFmrRibbon`).

Command line: `/theme=<name>` `/accent=RRGGBB` `/backstage` (open at start) `/tab=N` (0-based) `/keytips` (open as
by keyboard) `/noanim` `/standalone` (no provider: each control's own `Theme`) `/frame[=fullnc|dwm|ncstrip]`
(caption row + tab row in a `TFmrFormFrame`; the tab row is hidden while the backstage is open) `/keeprow` (with
`/frame`: do not hide the tab row).

## Verification

Builds: `.\build.ps1 -Project Demos\Extras\ExtrasDemo.dpr` (Win64) and `-Platform Win32`: no warnings, no hints.
Tests: `.\build.ps1 -Project Tests\FmrRibbonTests.dpr`, `bin\Win64\Debug\FmrRibbonTests.exe`: 132 tests (120 + 12
new), all passing, no leaks.

Screenshots checked (Windows 11, 150 %; `shots\` is not committed):

| Shot | What was checked |
|---|---|
| `backstage_365.png` (`/backstage /theme=ModernWhite`) | gray pane, glyphs, accent bar on Info, flat back arrow, group separators, Account/Options at the bottom, Info page layout (header, title, path, tiles, properties column) |
| `backstage_2016.png` (`BannerColorful /tab=2`) | accent pane, round back button, full-width darker selection, Open page: location tiles (Recent selected), recent files with group headers and document glyphs, hover |
| `backstage_2010.png` (`ClassicBlue /tab=4`) | gradient pane, blue gradient selection, compact items, Print page with tile, `TSpinBox`, combo, settings, `TImage` preview |
| `backstage_softdark.png` (`SoftDark /tab=1`) | dark pane, subtle selection + accent bar, New page template cards |
| `backstage_keys_*.png` (`ModernColorful`) | Down ×2 → Open shown with focus rectangle; Down ×2 more → Save skipped as a tab (focus only), Save As shown; Esc → view closed, "backstage hidden" |
| `backstage_keytips*.png` (`/keytips`) | key tips I N OP SA SV P C A OT over the glyphs; typing O leaves OP and OT |
| `win32_enter*.png` (Win32, `FlatWhite`) | Down ×3 → focus on Save; Enter → view closed, "Page 1 of 3 - saved"; click on the Focus link → checked, "Focus True" |
| `extras_main.png`, `statusbar_2010_crop.png`, `statusbar_365black_crop.png` | status bar in light, Classic (separators) and dark themes |
| `statusbar_drag*.png` (`BannerColorful`) | thumb dragged → 364 %, page zoomed; click on Read Mode → checked button, sepia page |
| `statusbar_hint_*_crop.png` | hover + hint on "245 words", "Zoom In" hint on +, two clicks on + → 120 %, "Read Mode" hint |
| `frame_fullnc.png`, `frame_fullnc_backstage.png` (`/frame BannerColorful`) | caption row + tab row in the non-client area (HTCAPTION in gaps, HTCLIENT on File); backstage open: title bar kept, tab row hidden, non-client top 58 px |
| `frame_dwm*.png` (`/frame=dwm`) | caption host visible above the open view; Esc restores the tab row |

## Known issues / limits

- Tabs and buttons of the view and the panels of the status bar store `Position`/`Size` in the .fmx although the
  container places them (harmless noise).
- Selecting a tab in the Structure View does not show it in the designer (FMX has no selection notification for
  controls); click its navigation item or set `ActiveTab`.
- Alt toggling the key tips (navigation pane focused) is implemented but could not be verified automatically (the
  test windows of another program took the focus during the run); `Show(True)` / `/keytips` is verified. Alt from a
  control inside a tab goes to that control.
- The slide animation moves the active tab with `SetBounds` (fine for normal content; heavy tabs may stutter).
- Fixed: the hint of the hot entry ("Back") stayed on the screen when the view was closed with Esc (`Hide` now hides
  the application hint; checked on a screenshot).
- No RTL mirroring, no touch-mode sizes yet.
- The Glass themes go with the application menu rather than a backstage; the view still works and uses their tokens.
- Screenshots were sometimes covered by another program's test windows running on the same desktop
  (`FastCanvasStress`); those runs were repeated.
