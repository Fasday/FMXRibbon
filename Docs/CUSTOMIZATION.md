# FMR Ribbon - run-time customization, display options, right to left, themed editors

This covers the user-facing additions to `TFmrRibbon`:

- the **customization form** ("Customize the Ribbon" and "Quick Access Toolbar" pages),
- the **Ribbon Display Options** button and real **auto-hide**,
- the classic/simplified **switch** and its overflow menu,
- full **right-to-left** mirroring,
- **themed editors** (edit, combo, spin, track bar in dark themes),
- a check of **touch mode**.

UI Automation has its own document: `Docs\ACCESSIBILITY.md`. The demo is `Demos\Customize`.

## Units

| Unit | Contents |
|---|---|
| `FMR.Ribbon.CustomizeModel` | `TFmrRibbonCustomization`: the editing session behind the form (no UI, unit-tested). `TFmrCustomizationShadow`: owner of the shadow structure. `TFmrCommandSource`: entries of "Choose commands from". |
| `FMR.Ribbon.Customize` | `TFmrRibbonCustomizeForm` (the dialog) and `TFmrRenameForm` (display name + symbol). Both are built in code. |
| `FMR.Ribbon.CustomizeControls` | Small controls for the dialog, painted with the ribbon painter: `TFmrCustButton`, `TFmrCustCheck`, `TFmrCustList` (list/tree with check boxes and expanders), `TFmrCustNav`, `TFmrCustSymbolGrid`, `FmrCustLabel`. |
| `FMR.Ribbon.BiDi` | `IFmrMirroredHost`, `FmrMirrorRect`/`FmrMirrorX`/`FmrMirrorCanvas`, `FmrDrawImage` (images stay unmirrored on a mirrored canvas). |
| `FMR.Ribbon.EditorStyles` | `TFmrRibbonEdit`, `TFmrRibbonComboEdit`, `TFmrRibbonComboBox`, `TFmrRibbonSpinBox`, `TFmrRibbonTrackBar`: FMX editors whose styles are built from theme tokens. `FmrThemeEditor`. |
| `FMR.Ribbon.UIA.Win` | UI Automation provider (see `Docs\ACCESSIBILITY.md`). |

Small additions to existing units:

- **`FMR.Ribbon`**: see "API" below.
- **`FMR.Ribbon.Popup`**:
  - RTL menus.
  - `TFmrPopupPlacement.BelowEnd`.
  - Icons drawn with `FmrDrawImage`.
- **`FMR.Ribbon.Views`** and **`FMR.Ribbon.Editors`**:
  - Unmirrored icons.
  - Themed editor classes.
  - Mirrored editor bounds.
- **`FMR.Ribbon.Painter`**:
  - New methods: `DrawDisplayOptionsGlyph`, `DrawSwitchChevron`, `DrawCaptionStyleButton`, `IsMirrored`.
  - `Text`/`TextEx` draw unmirrored text on a mirrored canvas.
- **`FMR.Ribbon.Strings`**: new strings in English and Russian:
  - `Cust*` (form texts).
  - `RibbonAutoHideDesc`, `RibbonShowTabsDesc`, `RibbonShowTabsAndCommandsDesc`.
  - `RibbonShowRibbon`, `RibbonSwitchToSimplified`, `RibbonSwitchToClassic`.
  - `Acc*`.
- **`FMR.Ribbon.Persistence`**: glyph codes of user-defined groups are saved (`"glyphCode"`).

## API (`TFmrRibbon`)

| Member | Meaning |
|---|---|
| `ShowCustomizationForm(APage = Ribbon): Boolean` | Opens the dialog modally on the given page (`TFmrCustomizationPage.Ribbon` or `QuickAccessToolbar`). Returns True when the user pressed OK. |
| `DefaultLayout: string` | Layout JSON of the ribbon as designed. "Reset" returns to it. It is captured automatically, before the first `LoadLayoutFrom*`, at `Loaded`, or on the first idle. Set it yourself if the ribbon is built later than that. |
| `ResetLayout` | Loads `DefaultLayout`. |
| `ShowDisplayOptionsButton` (published) | The "Ribbon Display Options" caption button. |
| `ShowDisplayModeButton` (published) | The chevron at the right end of the body: classic/simplified switch. |
| `ShowAutoHiddenRibbon`, `AutoHiddenRibbonShown` | Opens/queries the auto-hide overlay (`ShowMode = AutoHide`). |
| `EffectiveRightToLeft` | True when `RightToLeft` is set or the form's `BiDiMode` is `bdRightToLeft`. |
| `AccessibilityNodes`, `AccessibilityInvoke`, `AccessibilitySetValue`, `AccessibilityVersion` | Snapshot and actions for accessibility clients (`Docs\ACCESSIBILITY.md`). |

How users open the form:

- **QAT menu, "More Commands..."**: opens the Quick Access Toolbar page. If `OnCustomizeQuickAccessToolbar` is assigned, that handler runs instead.
- **QAT right-click, "Customize Quick Access Toolbar..."**: same behavior as "More Commands...".
- **Ribbon context menu, "Customize the Ribbon..."**: opens the ribbon page.

These menu entries call `QueueCustomizationForm`. The modal form runs from the message loop after the menu has closed (`TThread.ForceQueue`).

## The dialog

The dialog is a modal FMX form owned by the ribbon's form. On Windows:

- the owner is set with `GWLP_HWNDPARENT`, so it stays above the main window when popup menus open;
- it gets a dark title bar (DWM attribute 20) in dark themes.

Everything is painted with the ribbon's painter and theme, so the dialog follows the theme. Light and dark themes were checked on screenshots.

**Ribbon page**

- **"Choose commands from"**: All Commands, Commands Not in the Ribbon, one entry per tab (in ribbon order), one entry per item `Category`.
  - A search box filters the list.
  - Only named, visible items with a caption are listed (no separators or static items), because layouts store items by name.
- **"Customize the Ribbon"**:
  - Tree of tabs, groups and links, filtered by All Tabs, Main Tabs or Tool Tabs (contextual).
  - The check box of a tab or group is its visibility.
  - Contextual tabs show their group name: "Table Design (Table Tools)".
- **Buttons**:
  - Add >> / << Remove.
  - Up / Down.
  - New Tab, New Group, Rename... (display name; custom groups also get a symbol from a grid).
  - Reset (selected tab / all customizations).
  - Import/Export (JSON layout files).
  - The button row wraps when translated captions are longer (checked in Russian).

**Quick Access Toolbar page**

- The same command chooser.
- The toolbar's command list, with Add/Remove, Up/Down and `<Separator>`.
- "Show Quick Access Toolbar below the Ribbon".
- Reset and Import/Export.

**Rules**, enforced by the model:

- Commands can be added only to user-defined (custom) groups. The hint below the tree says so.
- Commands of designed groups cannot be removed or reordered.
- Designed tabs and groups are hidden (unchecked), never deleted.
- A custom tab can be removed only when it holds only custom groups.
- Groups move inside their tab, and into the neighbouring tab at either end.
- Renaming a designed object sets its `UserCaption`. An empty name, or the designed caption, clears it.

## The model (`FMR.Ribbon.CustomizeModel`)

`TFmrRibbonCustomization.Create(Ribbon, DefaultLayout)` copies the structure into a shadow owner (`TFmrCustomizationShadow`, an `IFmrRibbonStructureOwner`):

- real `TFmrRibbonTab`, `TFmrRibbonGroup` and `TFmrRibbonContextGroup` objects with the same names, owned by a private root component;
- a shadow quick access toolbar linking the same items.

The form edits only the shadow, using the helpers of `FMR.Ribbon.Structure`. So:

- **Cancel** frees the session, and the ribbon is never touched.
- **Import, Export and Reset All** are the JSON persistence of `FMR.Ribbon.Persistence` applied to the shadow (same format as `SaveLayoutToFile`). Unknown files raise `EFmrLayoutError`, shown as a themed message.
- **Apply (OK)** transfers the shadow in one structure update:
  - creates the new user-defined tabs and groups (with their glyph code);
  - copies order, visibility and user captions of every tab and group;
  - frees removed user-defined objects;
  - replaces the links of user-defined groups and of the QAT where they differ.

Applying an unchanged session changes nothing (tested).

The model works with any `IFmrRibbonStructureOwner`, so it can drive customization without the form:

```pascal
var
  C: TFmrRibbonCustomization;
  G: TFmrRibbonGroup;
begin
  C := TFmrRibbonCustomization.Create(Ribbon1, Ribbon1.DefaultLayout);
  try
    G := C.NewTab(C.Tabs[0]);                      // a custom tab after Home, with one custom group
    C.Rename(G, 'Favorites');
    C.AddCommand(BarManager1.FindItem('btnBold'), G);
    C.AddToQAT(BarManager1.FindItem('btnPrint'));
    C.Apply;
  finally
    C.Free;
  end;
end;
```

## Display options and auto-hide

**The display options button** (`ShowDisplayOptionsButton`) sits left of Minimize in the caption row. It opens a large-row menu (glyph, bold caption, description), right-aligned to the button:

| Entry | Effect |
|---|---|
| Auto-hide Ribbon | `ShowMode := AutoHide` |
| Show Tabs | `ShowMode := TabsOnly` |
| Show Tabs and Commands | `ShowMode := TabsAndCommands` and `Minimized := False` |

The current mode is checked. Without a frame, the button sits at the right end of the caption row inside the ribbon.

**`ShowMode = AutoHide`**:

- Only the caption row stays: QAT, title, search, display options, plus a "..." button (`AutoHideShow`, "Show Ribbon").
- Clicking the "..." button or the empty caption row opens an overlay popup below the caption row. The tab bar and the body are moved into it.
- The overlay closes on an outside click, Esc, or after a command. The bars then return to the frame host or the ribbon.
- Key tips (Alt) open the overlay first.

Checked with ModernWhite, BannerColorful (colored caption), SoftDark and `/frame=none`.

## Classic/simplified switch

`ShowDisplayModeButton` adds a chevron at the bottom-right of the body:

- "Switch to Simplified Ribbon" (chevron up) in classic mode;
- "Switch to Classic Ribbon" (chevron down) in simplified mode, centred vertically.

The simplified overflow button ("...") opens a menu with the same row style as other menus: glyph gutter, caption, submenus for drop-downs. Editors (combos, edits) are not repeated in the overflow menu.

## Right to left

`RightToLeft := True`, or `BiDiMode = bdRightToLeft` on the form, mirrors everything. It works like `WS_EX_LAYOUTRTL`:

- **Parts keep left-to-right geometry.** The caption bar, tab bar, body, QAT bar, group popups and menus keep their logical left-to-right element geometry. They flip the canvas horizontally while painting (`FmrMirrorCanvas`) and flip mouse coordinates before hit testing. Layout code, key tips and keyboard navigation are therefore unchanged.
- **Text** reads correctly. `TFmrRibbonPainter.Text`/`TextEx` detect a mirrored canvas (`IsMirrored`, `m11 < 0`), draw the string unmirrored inside its rectangle, and swap leading and trailing alignment.
- **Icons** are drawn unmirrored (`FmrDrawImage`, like `NOMIRRORBITMAP`), so "B" and "I" glyphs read correctly. Painted chevrons, arrows and launchers are mirrored.
- **Real controls** get mirrored bounds: editors, the search box and caption buttons. Window buttons move to the left.
- **Popups** of a right-to-left ribbon:
  - their context implements `IFmrMirroredHost`;
  - drop-downs align their right edge with the anchor;
  - submenus open to the left;
  - Left/Right keys are swapped in menus.

## Themed editors

The editor controls of `TFmrEditorView` are created from `FMR.Ribbon.EditorStyles`. `FmrThemeEditor` gives each control the colors of the theme, and the control overrides `GetStyleObject` to return a style tree built in code. Theme tokens used:

- `EditFill`, `EditBorder`, `EditBorderHot`, `EditText`;
- `ButtonArrow`, menu fill/text, accent.

A theme change gives the control the `StyleLookup` of the new color scheme (one name per scheme; the tree built in `GetStyleObject` is tagged with it), so FMX loads the new style, and the old tree is freed. FMX recycles style trees into a global style cache (reparenting, out of view) and takes one back only by its tag: with names per control or per theme change the cache grew with every theme switch (about 6 MB per 50 switches in the Document template) until the application ended. A combo also frees the tree of its list box before the list box style changes (`TCustomListBox.ApplyStyle` adds two clones of `selection` to a recycled tree every time it is used again). Live switching was checked (ModernWhite to SoftDark; `tools\Stress`: no heap growth over 50 switches).

FMX creates some objects itself: list items, the combo popup, spin buttons and track bar thumbs. Their styles are registered in the FMX resource pool, one set per color scheme.

Combos use `DropDownKind = Custom`, so the list is a themed `TListBox` that scrolls to the current text. The font name combo works the same way.

## Touch mode

`TouchMode` (the demo's `/touch`) was checked on screenshots:

- larger buttons;
- larger caption and display options buttons;
- the switch chevron.

No changes were needed. The customization dialog does not change size in touch mode.

## Demo (`Demos\Customize`)

`CustomizeDemo.exe` is a document-editor style ribbon built in code. Every command has a category; a contextual "Table Tools" tab is included. Switches:

| Switch | Effect |
|---|---|
| `/theme=<name>` | Theme. Checked: ModernWhite, ClassicBlue, SoftDark, ModernBlack, BannerColorful. |
| `/frame=fullnc\|dwm\|ncstrip\|none` | Frame mode. |
| `/open=customize\|qat` | Opens the form on a page after start. |
| `/rtl` | `RightToLeft`. |
| `/formrtl` | Form `BiDiMode`. |
| `/autohide` | `ShowMode = AutoHide`. |
| `/showautohide` | Opens the overlay after start. |
| `/displayoptions` | Opens the display options menu after start. |
| `/simplified` | Simplified ribbon. |
| `/touch` | Touch mode. |
| `/lang=ru` | Russian strings. |
| `/switchtheme=<name>` | Live theme change after 1.5 s. |
| `/layout=<file>` | Loads a layout at start. |
| `/savelayout=<file>` | Saves the layout on exit. |
| `/autofile=<file>` | Import/Export use this file without dialogs; confirmations are answered Yes. |
| `/dump=<file>` | `DebugDump` of the ribbon. |
| `/dumpcust=<file>` | Control rectangles of the dialog. |
| `/dropdown=<automation id>` | Invokes a ribbon element (e.g. `cbFontName`, `btnPaste`). |
| `/tabletools`, `/tab=N`, `/keytips` | Show the contextual tab, select a tab, show key tips. |
| `/nouia` | Do not install the UI Automation provider. |

For scripted runs, the dialog offers class variables `TFmrRibbonCustomizeForm.OnShowHook`, `AutoFileName` and `AutoConfirm`, plus `DebugDump`.

Screenshots of the checks are in `shots\cust\`:

| Shots | Shows |
|---|---|
| `c02`/`c40` | Form in English |
| `c39` | Form in Russian |
| `c04`, `c11` | Bold added to a new tab and group, then applied |
| `c12`, `c13` | Export/import, reset all |
| `c14`, `c15` | QAT page in SoftDark |
| `c16`, `c33`, `c34` | Display options menu |
| `c45`, `c46` | Auto-hide overlay |
| `c18`, `c25` | Switch and overflow |
| `c26`, `c35` | RTL |
| `c29`–`c31` | Themed editors |
| `c32` | Touch |

## Tests

`Tests\FMR.Tests.Customize.pas` (14 tests) covers the session:

- the shadow mirrors the ribbon;
- Cancel leaves the ribbon untouched;
- commands go only into custom groups;
- new tabs and groups are applied;
- hide, rename and move;
- moves into the neighbouring tab;
- removing custom objects;
- reordering and renaming custom links;
- export/import round trip;
- reset all / reset tab;
- QAT editing;
- command sources;
- applying twice changes nothing.

## Known limitations

- Designed tabs and groups without a `Name` cannot be stored in a layout. They are not reset or re-ordered by name, as with all layout persistence. Give designed tabs and groups names.
- **Right to left**:
  - The FMX editors' inner layout stays left to right (text alignment, the combo arrow side).
  - The customization dialog itself is not mirrored.
  - Icons are never mirrored. Direction-dependent icons (undo/redo arrows) keep their left-to-right look.
- Fixed: the scroll bars of themed drop-down lists have a themed style too (track in the list color, a rounded thumb
  in the item text color at 32 %/55 % hot, no arrow buttons; pooled per color scheme like the other styles).
- Black or odd dialog borders and shadows in `shots\` come from `PrintWindow` captures, not from the windows.
- `/showautohide` may lose the overlay when the window is activated right after start. Clicking "..." always works.
