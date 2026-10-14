# FMR Ribbon — architecture and decisions

This file is the contract between the parts of the library. Read it before changing code; when a decision changes,
change it here first.

## Decisions

| Topic | Decision |
|---|---|
| Name | FMR Ribbon. Units `FMR.*`, classes `TFmr*`, interfaces `IFmr*` |
| Delphi | 13 (RAD Studio 37.0) and newer; Win64 first, Win32 must compile; Linux64 (FMXWayland) must compile and run |
| Platforms | Core (bars, ribbon, layout, themes, popups) on every FMX platform; frame/NC integration Windows only (`*.Win.pas`, `{$IFDEF MSWINDOWS}`); Linux: `FMR.Frame.Wayland` attaches when the platform offers `IFMXWaylandWindowFrame` (`Docs\LINUX.md`), otherwise (and on other platforms) the frame host is an ordinary control and the ribbon leaves the title to the system title bar. Platform units compile to nothing elsewhere, so one unit list serves every platform |
| License | MIT |
| Model | **Items + Links**: items live in a bar manager, groups/QAT/menus hold links to them |
| Items | Lightweight: items and links are not controls; the ribbon lays them out and paints them. Editor/control items (`TEdit`, `TComboBox`, any `TControl`) are real FMX controls placed by the ribbon |
| Themes | Vector painting in code + **color/brush/font tokens** read from a StyleBook (`TColorObject`, `TBrushObject`, `TFontObject`). Built-in themes are built in code (`FMR.Ribbon.Themes.Builtin`), families `Modern` (Colorful, White, Dark Gray, Black; in the style of Microsoft 365, 2019–2023), `Modern2024` (Light, Dark Gray, Dark; Microsoft 365, 2024), `Banner` (Office 2016 style, colored captions), `Flat` (Office 2013 style), `Classic` (Office 2010 style: Blue, Silver, Black), `Glass` (Office 2007 style: Blue, Silver, Black), `Soft` (Windows 11 style: Light, Dark). The app's StyleBook can override any token |
| Icons | `TFmrImageSource`: FMX `TImageList` index, SVG (Skia), glyph from an icon font (Segoe Fluent Icons…), `TPathData`. Segoe codes are drawn from "FMR Icons" (`Assets\Fonts\FmrIcons.ttf`, a subset of Microsoft's Fluent UI System Icons, MIT) where the Segoe font is missing (`FMR.Ribbon.IconFont.inc`, `tools\IconFont`) |
| Fonts | `FMR.Ribbon.Fonts`: installed families (platform listers `FMR.Ribbon.Fonts.Win`/`.Linux`), `FmrResolveFontFamily` (first installed of a list), `FmrUIFontFamily` (theme font: Segoe UI on Windows, Noto Sans/Cantarell/… elsewhere), private fonts for the Skia canvas |
| Frame | `TFmrFormFrame` component (drop on any form) and the optional ancestor `TFmrForm`; modes `Dwm`, `FullNC` (**default**), `NCStrip`. In `FullNC` the caption row **and the tab row** are in the real non-client area |
| Strings | All UI strings in `FMR.Ribbon.Strings` (English) with a Russian table; `FmrSetLanguage('ru')` |
| Tests | DUnitX (`Tests\`), logic only (layout, items/links, merge, persistence, key tips) |
| Demos | `Demos\NCProof` (the three frame modes, geometry panel), `Demos\Notes` (FMR Notes, a notes editor streamed from an `.fmx`), `Demos\Showcase` (one page per feature, theme and canvas switch) |

## Source layout

```
Source\Frame\      FMR.Frame.Types, FMR.Frame.Host, FMR.Frame, FMR.Frame.Win, FMR.Frame.Wayland, FMR.Frame.Buttons,
                   FMR.Frame.Form
                   window frame and non-client host (Docs\FRAME.md; Linux: Docs\LINUX.md)
Source\Core\       FMR.Bars, FMR.Bars.Items, FMR.Bars.Images, FMR.Ribbon.Types, FMR.Ribbon.Structure,
                   FMR.Ribbon.Layout, FMR.Ribbon.Persistence, FMR.Ribbon.Merge, FMR.Ribbon.KeyTips, FMR.Ribbon.Strings,
                   FMR.Ribbon.Fonts (+ FMR.Ribbon.IconFont.inc, generated)
                   non-visual model and pure logic (Docs\CORE.md)
Source\Themes\     FMR.Ribbon.Theme, FMR.Ribbon.Themes.Builtin, FMR.Ribbon.Painter (Docs\STYLES.md)
Source\Ribbon\     FMR.Ribbon (TFmrRibbon), Views, Popup, Editors, EditorStyles, ScreenTips, Gallery, ColorGallery,
                   AppMenu, MiniToolbar, RadialMenu, Customize*, BiDi, Fonts.Win, Fonts.Linux, UIA.Win
                   (Docs\RIBBON.md, GALLERIES.md, CUSTOMIZATION.md, ACCESSIBILITY.md)
Source\Extras\     FMR.Ribbon.Backstage(.Controls), FMR.Ribbon.StatusBar, FMR.Ribbon.ThemeLink (Docs\EXTRAS.md)
Source\Templates\  FMR.Ribbon.Templates (run-time templates), FMR.Ribbon.DesignSupport (design-hook interfaces)
Source\Design\     design-time only (dclFMRRibbon): registration, editors, editor windows (Docs\DESIGNTIME.md)
Packages\          FMRRibbon.dpk (runtime; Win32, Win64, Linux64), dclFMRRibbon.dpk (design), FMRRibbon.groupproj
Assets\Fonts\      FmrIcons.ttf ("FMR Icons": Fluent UI System Icons subset, THIRD_PARTY_NOTICES.md)
Tests\             FmrRibbonTests.dpr (DUnitX console runner) + test units
Demos\             NCProof, RibbonBasic, Notes, Showcase, Extras, Customize (Demos\README.md)
tools\             build-packages.ps1, shot.ps1 / drive.ps1 / capture.ps1 / keys.ps1 (run, drive and capture
                   programs), closecheck.ps1, ThemeSheet, DesignPreview, Stress (stress and destroy paths of the
                   real ribbon), fix-encoding.ps1, linux-run.ps1/.sh (Linux programs on a headless Weston),
                   IconFont (make-icon-font.ps1, segoe-icon-map.txt)
```

## Building and checking

- `.\build.ps1 -Project <dpr>` builds Win64 Debug into `bin\Win64\Debug` (every folder of `Source` is on the search
  path). `-Platform Win32`, `-Config Release`, `-SearchPath` for extra folders. `-Platform Linux64` builds with
  FMXWayland (`-FmxWayland`, `-Sdk`; `Docs\LINUX.md`); `.\tools\linux-run.ps1` runs the result on a headless Weston
  in WSL and keeps screenshots.
- `.\tools\shot.ps1 -Exe bin\Win64\Debug\X.exe -Out shots\x.png -Probe "40,15;..." -Actions "click:..;keys:.."`
  starts the program, drives it, saves a screenshot of the window (as composed by DWM) and prints the window rect,
  the client rect in screen coordinates, the non-client thickness on each side and the hit-test code under probe
  points. Look at the PNG (the Read tool shows images) to check what was drawn.
- Tests: `.\build.ps1 -Project Tests\FmrRibbonTests.dpr` then run `bin\Win64\Debug\FmrRibbonTests.exe`.
- Stress: `.\build.ps1 -Project tools\Stress\FmrStress.dpr`, `bin\Win64\Debug\FmrStress.exe /log=<file>
  [/only=<scenario,...>] [/repeat=N]`: loops and destroy paths on real windows, GDI/USER/heap growth checks, stack
  traces of exceptions from the map file (`-GD`); a Debug build also reports leaks on exit.

## The frame (`Source\Frame`)

Full description, Windows behavior per mode, test results and limitations: `Docs\FRAME.md`. Later additions to
the contract: `TFmrFrameBackdrop` (None, Mica, Acrylic, Tabbed; Dwm mode), `IFmrFrameCommands` (min/max/close/system menu
for caption controls), `TFmrFrameState.DarkMode` / `Transparent`

### Contract (`FMR.Frame.Types`, fixed)

- `TFmrFrameMode = (Dwm, FullNC, NCStrip)`.
- `TFmrHitArea = (Default, Client, Caption, SysMenu, MinButton, MaxButton, CloseButton, HelpButton, Nowhere)`.
- `IFmrFrameHitTest.FrameHitTest(LocalPoint): TFmrHitArea` — implemented by controls in the host that decide per
  point (tab row: tab → Client, gap → Caption). The frame asks the deepest control under the cursor
  (`ObjectAtPoint`), then its parents up to the host; first non-Default answer wins. Default rules when nobody
  answers: the host itself or a control with `HitTest = False` → Caption; any other control → Client.
- `IFmrFrameButton` — caption buttons whose hot/pressed state the frame drives (the window manager keeps mouse
  messages over HTMINBUTTON/HTMAXBUTTON/HTCLOSE).
- `IFmrFrameStateAware.FrameStateChanged(State)` + `TFmrFrameStateMessage` — active/maximized/minimized/mode.

### `TFmrFrameHost` (`FMR.Frame.Host`)

A `TControl` placed on the form by the frame, container of the caption content (`Align = Top` children). It
implements `IScene` for its children, as `TCustomLayer3D` does for the 2D controls of a 3D form: the children's
`Root` stays the form, so focus, keyboard, IME, hints, actions and the StyleBook work unchanged; only painting and
invalidation go through the host:

- Dwm mode: the host is an ordinary control at the top of the client area, its children use the form's scene.
- FullNC / NCStrip: the host gives its children its own scene; `AddUpdateRect` marks the non-client area dirty and
  invalidates it (`RedrawWindow(RDW_FRAME…)`); in `WM_NCPAINT` the children are painted into a bitmap that is copied
  to the window DC. Mouse: over interactive controls `WM_NCHITTEST` returns `HTCLIENT`, Windows then sends ordinary
  client mouse messages with negative client coordinates, the form routes them to `ObjectAtPoint`, which finds the
  host's children through the host's `ScreenToLocal`.

### `TFmrFormFrame` (`FMR.Frame`)

Non-visual component dropped on a form (or owned by `TFmrForm`):

```pascal
property Mode: TFmrFrameMode default TFmrFrameMode.FullNC;
property CaptionHeight: Single;          // dp, height of the caption content (host)
property Host: TFmrFrameHost;            // read-only, created by the frame
property State: TFmrFrameState;          // read-only
procedure Minimize; procedure ToggleMaximize; procedure CloseForm;
procedure ShowSystemMenu(const AScreenPoint: TPointF);
```

At design time (`csDesigning`) nothing is hooked: the host is shown at the top of the client area, so the caption
content can be designed. The ribbon finds the frame of its form (or gets it through its `Frame` property), moves its
caption row and tab row into `Frame.Host` and sets `Frame.CaptionHeight`. Without a frame (other platforms, a ribbon
inside a panel) the ribbon keeps both rows inside itself.

## Bars: items and links (`Source\Core\FMR.Bars*`)

- `TFmrBarManager = class(TFmxObject)` — non-visual, dropped on the form. Its **children are the items**
  (`TFmrBarItem = class(TFmxObject)`), so the Structure View shows manager → items and FMX streams them without
  extra code. `Images: TCustomImageList`, `Categories: TStrings`, item lookup, `BeginUpdate/EndUpdate`.
- `TFmrBarItem` — Caption, Description, Hint, Enabled, Visible, `Glyph`/`LargeGlyph: TFmrImageSource`,
  ImageIndex, Action (FMX actions through `TFmxObject`'s `IActionClient`), ShortCut, KeyTip, ScreenTip, Category,
  OnClick. Items know their links and notify them on every change.
- `TFmrItemLink = class(TCollectionItem)` — Item, BeginGroup, ViewLevels (`Large`, `SmallWithText`, `Small`),
  ButtonGroup position, Visible, UserCaption, KeyTip override. `TFmrItemLinks = class(TOwnedCollection)` notifies its
  owner (`IFmrItemLinksOwner`).
- One item can have links in several groups, the QAT, menus and the mini toolbar at once.

## Ribbon structure (`FMR.Ribbon.Structure`)

- `TFmrRibbon = class(TControl)` → children `TFmrRibbonTab = class(TFmxObject)` → children
  `TFmrRibbonGroup = class(TFmxObject)` with `ItemLinks: TFmrItemLinks`. Context tab groups:
  `TFmrRibbonContextGroup` (named children of the ribbon; tabs reference them by name), QAT: `TFmrRibbonQuickAccessToolbar` (persistent with links).
- The structure classes talk to the ribbon through `IFmrRibbonStructureOwner` (structure changed, tab/group
  changed), so they are testable without the control.

## Layout (`FMR.Ribbon.Layout`)

Pure code with no controls: input is a list of groups with, per link, the size at each view level (measured by the
painter); output is the chosen level of every link, positions inside the groups and which groups collapse into a
drop-down button. Reduction order: right to left, large → small-with-text → small, then collapse;
groups can give a priority. Tested with DUnitX.

## Themes and painting

- A theme is a set of named tokens: `fmr.tab.text`, `fmr.tab.active.fill`, `fmr.group.caption.text`,
  `fmr.button.hot.fill`, … (full list in `Docs\STYLES.md`). Tokens are `TColorObject`, `TBrushObject` (gradients for
  the Glass and Classic themes) or `TFontObject` resources of a StyleBook. Lookup order: the form's StyleBook, then the built-in theme
  selected with `TFmrRibbon.Theme`, then defaults in code.
- `TFmrRibbonPainter` paints every part (caption, tabs, group frames, buttons in every state, galleries,
  separators, scroll buttons, key tips, screen tips, backstage) with canvas primitives and these tokens; metrics
  (heights, paddings) are part of the theme too.

## Status

See `Docs\STATUS.md` for what is done, what is in progress and what is planned.
