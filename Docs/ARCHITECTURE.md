# FMR Ribbon — architecture and decisions

This file is the contract between the parts of the library. Read it before changing code; when a decision changes,
change it here first.

## Decisions

| Topic | Decision |
|---|---|
| Name | FMR Ribbon. Units `FMR.*`, classes `TFmr*`, interfaces `IFmr*` |
| Delphi | 13 (RAD Studio 37.0) and newer; Win64 first, Win32 must compile |
| Platforms | Core (bars, ribbon, layout, themes, popups) on every FMX platform; frame/NC integration Windows only (`*.Win.pas`, `{$IFDEF MSWINDOWS}`); on other platforms the ribbon shows its caption row inside itself |
| License | MIT |
| Model | DevExpress-style **Items + Links**: items live in a bar manager, groups/QAT/menus hold links to them |
| Items | Lightweight: items and links are not controls; the ribbon lays them out and paints them. Editor/control items (`TEdit`, `TComboBox`, any `TControl`) are real FMX controls placed by the ribbon |
| Themes | Vector painting in code + **color/brush/font tokens** read from a StyleBook (`TColorObject`, `TBrushObject`, `TFontObject`). Built-in themes are embedded `.style` resources: Office 365/2019 (Colorful, White, Dark Gray, Black), Office 2016 (colored captions), Office 2013, Office 2010 (Blue, Silver, Black), Office 2007 (Blue, Silver, Black), Windows 11 Fluent (Light, Dark). The app's StyleBook can override any token |
| Icons | `TFmrImageSource`: FMX `TImageList` index, SVG (Skia), glyph from an icon font (Segoe Fluent Icons…), `TPathData` |
| Frame | `TFmrFormFrame` component (drop on any form) and the optional ancestor `TFmrForm`; modes `Dwm`, `FullNC` (**default**), `NCStrip`. In `FullNC` the caption row **and the tab row** are in the real non-client area |
| Strings | All UI strings in `FMR.Ribbon.Strings` (English) with a Russian table; `FmrSetLanguage('ru')` |
| Tests | DUnitX (`Tests\`), logic only (layout, items/links, merge, persistence, key tips) |
| Demos | `Demos\NCProof` (the three frame modes, geometry panel), `Demos\WordLike` (showcase application), `Demos\Showcase` (one page per feature, theme and canvas switch) |

## Source layout

```
Source\Frame\     FMR.Frame.Types        shared enums/interfaces of the frame (contract, see below)
                  FMR.Frame.Host         TFmrFrameHost: container of the caption content (TControl + IScene)
                  FMR.Frame              TFmrFormFrame: platform-neutral component
                  FMR.Frame.Win          Windows implementation (subclassing, WM_NC*, DWM, region, shadow)
                  FMR.Frame.Buttons      TFmrCaptionButton (min/max/close/help), title label helpers
                  FMR.Frame.Form         TFmrForm = TForm with a built-in frame
Source\Core\      FMR.Bars               TFmrBarManager, TFmrBarItem, TFmrItemLink(s), categories
                  FMR.Bars.Items         concrete items (button, sub item, separator, static, control, editors…)
                  FMR.Bars.Images        TFmrImageSource and drawing of icons
                  FMR.Ribbon.Types       enums/records shared by the ribbon
                  FMR.Ribbon.Structure   TFmrRibbonTab, TFmrRibbonGroup, TFmrRibbonContextGroup, QAT data
                  FMR.Ribbon.Layout      pure layout calculator (groups, view levels, collapse order)
                  FMR.Ribbon             TFmrRibbon control
                  FMR.Ribbon.Painter     painting of ribbon parts from theme tokens
                  FMR.Ribbon.Theme       theme tokens, built-in themes, accent colors
                  FMR.Ribbon.Popup       popup windows (menus, galleries, group popups) — cross-platform FMX forms
                  FMR.Ribbon.KeyTips     key tips
                  FMR.Ribbon.ScreenTips  rich tooltips
                  FMR.Ribbon.Gallery     gallery items
                  FMR.Ribbon.Backstage   backstage view
                  FMR.Ribbon.AppMenu     application menu
                  FMR.Ribbon.Strings     localization
Source\Design\    design-time only (package dclFMRRibbon): registration, editors, designer window
Source\Themes\    *.style theme files (embedded with a .rc)
Packages\         FMRRibbon.dpk (runtime), dclFMRRibbon.dpk (design time)
Tests\            FmrRibbonTests.dpr (DUnitX console runner) + test units
Demos\            NCProof, WordLike, Showcase
tools\            shot.ps1 (screenshot + window geometry + hit-test probe)
```

## Building and checking

- `.\build.ps1 -Project <dpr>` builds Win64 Debug into `bin\Win64\Debug` (every folder of `Source` is on the search
  path). `-Platform Win32`, `-Config Release`, `-SearchPath` for extra folders.
- `.\tools\shot.ps1 -Exe bin\Win64\Debug\X.exe -Out shots\x.png -Probe "40,15;..." -Actions "click:..;keys:.."`
  starts the program, drives it, saves a screenshot of the window (as composed by DWM) and prints the window rect,
  the client rect in screen coordinates, the non-client thickness on each side and the hit-test code under probe
  points. Look at the PNG (the Read tool shows images) to check what was drawn.
- Tests: `.\build.ps1 -Project Tests\FmrRibbonTests.dpr` then run `bin\Win64\Debug\FmrRibbonTests.exe`.

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
drop-down button. Reduction order follows Office: right to left, large → small-with-text → small, then collapse;
groups can give a priority. Tested with DUnitX.

## Themes and painting

- A theme is a set of named tokens: `fmr.tab.text`, `fmr.tab.active.fill`, `fmr.group.caption.text`,
  `fmr.button.hot.fill`, … (full list in `Docs\STYLES.md`). Tokens are `TColorObject`, `TBrushObject` (gradients for
  2007/2010) or `TFontObject` resources of a StyleBook. Lookup order: the form's StyleBook, then the built-in theme
  selected with `TFmrRibbon.Theme`, then defaults in code.
- `TFmrRibbonPainter` paints every part (caption, tabs, group frames, buttons in every state, galleries,
  separators, scroll buttons, key tips, screen tips, backstage) with canvas primitives and these tokens; metrics
  (heights, paddings) are part of the theme too.

## Status

See `Docs\STATUS.md` for what is done, what is in progress and what is planned.
