# FMR Ribbon - galleries, application menu, mini toolbar, radial menu

Popup features of the ribbon built on its extension points (`FmrRegisterItemView`, `FmrRegisterDropDown`,
`IFmrApplicationMenu`, `FmrPopups` / `TFmrPopupForm`, `IFmrThemeSource`). Everything lives in new units of
`Source\Ribbon`; existing units got only small hooks (see "Changes in existing units"). Demo: `Demos\RibbonBasic`.

| Unit | Contents |
|---|---|
| `FMR.Ribbon.Gallery` | `TFmrGalleryView` (in-ribbon gallery), `TFmrGalleryPopupContent` (drop-down gallery, menus with inline galleries), `TFmrGalleryGrid`, `TFmrRibbonGalleryItem` (owner drawing, resize mode), `FmrGalleryItemSize`, `FmrDrawGalleryEntry` |
| `FMR.Ribbon.ColorGallery` | `TFmrColorGalleryItem`, `TFmrColorGalleryControl` (drop-down of every `TFmrColorItem`), `FmrShowColorDialog` ("More Colors"), recent colors, `FmrThemeColor` |
| `FMR.Ribbon.AppMenu` | `TFmrRibbonApplicationMenu` (Office 2007 application menu, `IFmrApplicationMenu`), `TFmrRecentDocuments` |
| `FMR.Ribbon.MiniToolbar` | `TFmrRibbonMiniToolbar` (floating formatting toolbar, fades with the mouse distance, optional context menu) |
| `FMR.Ribbon.RadialMenu` | `TFmrRibbonRadialMenu` (OneNote style radial menu with nested rings) |

The initialization sections register the views and drop-down factories; they replace the gallery placeholder menu
and the old color palette of `FMR.Ribbon.Popup`. `FMR.Ribbon` uses `FMR.Ribbon.Gallery` and `FMR.Ribbon.ColorGallery`
(implementation section), so galleries work in every application with a ribbon; the other three units are used by the
applications that create their components.

## Galleries (`FMR.Ribbon.Gallery`)

### Data

The data model is `TFmrGalleryItem` of the core (`Docs\CORE.md`): groups of entries (caption, glyph, hint,
description, enabled, visible), `MinColumns`/`MaxColumns`, `DropDownColumns`/`DropDownRows`, `ItemWidth`/
`ItemHeight`, `CaptionPosition` (None, Bottom, Right), `ShowInRibbon`, `AllowFilter`, `ShowGroupHeaders`,
`SelectionMode`, `SelectedEntry`, `DropDownLinks`, `OnItemClick`, `OnHotTrack`.

`TFmrRibbonGalleryItem = class(TFmrGalleryItem)` adds:

| Property | Meaning |
|---|---|
| `OnDrawItem(Sender, Canvas, Entry, Rect, State, Painter, var Handled)` | Owner drawing of an entry. The hot/selected background is painted first; set `Handled` to skip the default glyph and caption. `State`: `Hot`, `Selected`, `Pressed`, `Disabled`, `InRibbon`; `Painter` gives theme colors (`ButtonTextColor`, `Theme.Colors[MenuItemText]`...) |
| `DropDownResize` | `None`, `Vertical`, `Both` (default) - the grip at the bottom of the drop-down |
| `DropDownMinWidth` | Minimum width of the drop-down (dp) |

Cell size (`FmrGalleryItemSize`): `ItemWidth`/`ItemHeight` when set; otherwise from the caption position: None = a
large glyph cell (44 dp), Bottom = glyph above the caption, Right = small glyph + caption (large glyph + bold caption +
description when entries have descriptions). In the ribbon the cell height is limited to the content height of the
group.

### In-ribbon gallery (`TFmrGalleryView`)

Registered with `FmrRegisterItemView(TFmrGalleryItem, TFmrGalleryView)`.

- In a classic group it feeds the layout calculator with `TFmrLayoutLink.Gallery(cell width, MinColumns,
  MaxColumns, frame + strip width, large button width)`. The calculator removes one column per reduction step down to
  `MinColumns` and finally turns the gallery into a large drop-down button (then the view paints like
  `TFmrButtonView`). The view finds the column count from the width it is placed with.
- Rows: as many as fit the content height, vertically centered; the entries of all groups flow without headers.
- Strip at the right (`DrawGalleryScroll`): scroll up / scroll down one row (disabled at the ends), the drop-down
  button. The drop-down button opens on mouse down (`OpensOnPress`); the popup opens over the gallery at its top-left
  corner and is at least as wide as the gallery (more columns), like Office.
- Hot tracking of entries (pressed look while the button is down), selection (`SelectedEntry` is kept visible:
  the gallery scrolls to it when the selection changes), click = `ClickEntry` (selects with `SelectionMode =
  Single`, fires `OnItemClick`).
- Live preview: `TFmrGalleryItem.HotTrack(Entry)` while the mouse is over an entry, `HotTrack(nil)` when it leaves
  the entries (and before a click applies the entry, so the click is not undone by the revert).
- Screen tips: entries show a tip (caption + hint/description) when they have a hint or their caption is not painted
  (`CaptionPosition = None`); the frame and the strip show the item's screen tip ("More" for the drop-down button).
- Key tips: the gallery as a whole has one key tip (badge at the drop-down button); it opens the drop-down by
  keyboard (the selected entry gets the focus).
- In simplified mode and in the quick access toolbar the gallery is a drop-down button.

### Drop-down gallery (`TFmrGalleryPopupContent`)

`FmrRegisterDropDown(TFmrGalleryItem, ...)` - opened by the strip button, by a gallery reduced to a button, by a
`ShowInRibbon = False` gallery (a large button with an arrow), from the quick access toolbar or by key tips.

Sections from top to bottom:

1. **Filter band** (`AllowFilter` and at least two visible groups with captions): the current filter ("All" or a
   group name) with an arrow; a click opens a list (All + group names, the current one checked); the popup keeps its
   size.
2. **Gallery**: group headers (`ShowGroupHeaders`, `DrawGalleryGroupHeader`), every group on new rows, cells in
   `DropDownColumns` (0 = `MaxColumns`) columns; height: `DropDownRows` rows, else up to 60 % of the work area. A thin
   scroll bar (drag the thumb, click the track to page) and the mouse wheel (one row per notch) scroll it.
3. **Commands**: `DropDownLinks` in a `TFmrMenuControl` (glyphs, check marks, submenus, key tips, accelerators)
   separated by a line ("Create a Style", "Clear Formatting"...).
4. **Resize grip** (`DropDownResize`): dots in the corner (both directions: more/fewer columns and rows) or in the
   middle (vertical only). The size stays within the work area; at least one row and one column.

Mouse: hot tracking + live preview + entry tips, press/release on the same entry = click (the popups close first,
then the item's `OnItemClick`). Keyboard: arrows move the focus in the grid (Up/Down keep the column), Home/End,
PgUp/PgDn (a page of rows), Enter/Space click, Tab and Down from the last row move into the commands, Up from the
first command goes back to the grid, Esc closes; letters go to the commands (accelerators, key tips). The focused
entry is previewed too.

### Menus with inline galleries

Registered for `TFmrButtonItem` and `TFmrSubItem`: when the links of a drop-down (`DropDownLinks`,
`TFmrSubItem.ItemLinks`) contain a visible `TFmrGalleryItem`, the drop-down is a `TFmrGalleryPopupContent` in menu
mode: every gallery link is an inline gallery section (group headers, all rows, or `DropDownRows` with a scroll bar),
the runs of other links are menu sections. Without gallery links the factory returns nil and the ordinary menu is
shown. Demo: Insert > Shapes (shapes gallery + "New Drawing Canvas").

## Color gallery (`FMR.Ribbon.ColorGallery`)

`FmrRegisterDropDown(TFmrColorItem, ...)`: every color item (split by default: the main part applies the last color,
the arrow opens the gallery; the glyph shows the color bar) gets:

- "Automatic" (`ShowAutomatic`; `Color := TAlphaColors.Null`, painted with `AutomaticColor`);
- Theme Colors: the 10 Office theme colors and 5 rows of tints/shades (lighter 80/60/40 %, darker 25/50 %; light
  colors get only shades, very dark colors only tints) - `FmrThemeColor(Col, Row)`;
- Standard Colors (10), Recent Colors (colors picked with "More Colors...", shared by all items, newest first);
- "No Color" (`ShowNoColor`; `Color := FmrNoColor` = `$00FFFFFF`, transparent but not Null), "More Colors..."
  (`ShowMoreColors`).

Every cell has a screen tip with its name ("Blue, Accent 1, Lighter 40%"), the current color is selected, keyboard:
arrows (geometric), Home/End, Enter, Esc.

`TFmrColorGalleryItem = class(TFmrColorItem)`: `Palette` (`Office` or `Highlight`: the 15 highlight colors of Word in
5 columns with "Stop Highlighting"), `ShowRecentColors`, `OnPreview(Sender, Color, Active)` (live preview: Active =
False restores), `OnMoreColors(Sender, var Color, var Handled)` (replace the dialog).

`FmrShowColorDialog(Initial, Title, OnDone)`: a modal FMX form with a `TColorPanel` (hue/saturation square), a hex
edit (`#RRGGBB`), new/current preview (click "current" to go back) and OK/Cancel; it uses the default FMX style.

## Application menu (`FMR.Ribbon.AppMenu`)

```pascal
AppMenu := TFmrRibbonApplicationMenu.Create(Self);
AppMenu.BarManager := BarManager1;
AppMenu.ItemLinks.AddItem(ItemNew);           // left column: large rows
AppMenu.ItemLinks.AddItem(ItemSaveAs, True);  // split button with DropDownLinks: submenu in the right pane
AppMenu.Buttons.AddItem(ItemOptions);         // bottom right
AppMenu.RecentDocuments.Add('Report.docx', 'C:\Docs\Report.docx', True {pinned});
AppMenu.OnRecentClick := RecentClick;
Ribbon1.ApplicationMenu := AppMenu;           // IFmrApplicationMenu
```

- With the Office 2007 themes (orb) the menu body starts at the middle of the orb and the content paints the orb
  pressed at the exact screen position of the ribbon's orb, so the orb seems to lie on the menu (the upper half of
  the popup is transparent; a click on the orb closes the menu). Other themes open the same menu below the "File"
  tab (the backstage view of `Source\Extras` remains the usual choice there).
- Left column: `ItemLinks` as large rows (32 dp glyph, caption, submenu arrow; split rows have a separate arrow part;
  `BeginGroup`/separators draw lines).
- Right pane (`ShowExtraPane`, `ExtraPaneWidth`): "Recent Documents" (`ExtraPaneCaption`) with numbered rows and pin
  buttons (`Pinned`, `OnRecentPinChanged`; the pin of a row is shown when it is pinned or hot), `OnRecentClick`.
  Hovering a left row with a submenu (`TFmrSubItem.ItemLinks` or `TFmrButtonItem.DropDownLinks`) for 350 ms (or a click
  on it / its arrow, or Right) shows the submenu in the pane: a header (the item's `Description`, else its caption)
  and large rows with bold captions and wrapped descriptions. Hovering a row without submenu shows the recent list
  again. The pane height is the largest of all its contents, so the menu never resizes.
- Bottom band: `Buttons` right-aligned, framed.
- Keyboard: Up/Down, Right (submenu or recent list), Left (back), Tab (buttons), Enter, Esc, accelerators (`&`
  letter or first letter), digits open recent documents. Opened by keyboard (Alt, F) it shows key tips (letters for
  the rows and buttons, 1-9 for recent documents).
- Events: `OnPopup`, `OnCloseUp`; `IsApplicationMenuOpen`, `CloseApplicationMenu`, `Content`.

## Mini toolbar (`FMR.Ribbon.MiniToolbar`)

`TFmrRibbonMiniToolbar` (`ItemLinks`, `BarManager`, `ThemeSource` = the ribbon or `Theme`, `PopupMenu`,
`FadeDistance` = 120 dp, `OnPopup`, `OnCloseUp`):

- Items are shown with the ribbon's views in the toolbar place: glyph buttons, check buttons, split/drop-down
  buttons, color items with their color bar, galleries as drop-down buttons, and editor items with real controls
  (font name and size combos). A `TFmrSeparatorItem` link starts a new row, `BeginGroup` leaves a gap.
- `Popup(ScreenPoint)`: above the point, 55 % opaque; a 40 ms timer measures the distance of the mouse from the toolbar:
  opaque within 6 dp, fading out with the distance, closed beyond `FadeDistance`.
- `Popup(ScreenPoint, True)` with `PopupMenu`: the context menu at the point and the toolbar above it, opaque while the
  menu is open; using the toolbar closes the menu and keeps the toolbar; choosing a menu command closes both (FMX popup
  rules); when the menu closes otherwise the toolbar fades with the distance.
- Drop-downs of its buttons (color gallery, bullets...) are child popups of the toolbar window, so the toolbar stays
  while they are used. Buttons show screen tips.

## Radial menu (`FMR.Ribbon.RadialMenu`)

`TFmrRibbonRadialMenu` (`ItemLinks`, `BarManager`, `ThemeSource`/`Theme`, `Glyph` of the center, `Diameter` = 260 dp,
`Animation`, `OnPopup`, `OnCloseUp`), `Popup(ScreenPoint)` centers it at the point.

- Up to 8 sectors clockwise from the top (visible links, separators skipped), glyph and caption in each, checked
  items tinted with the accent, disabled items faded, the hot sector filled with `RadialSectorHotFill`.
- Items with sub items (`TFmrSubItem`, buttons with `DropDownLinks`) show an arrow in the outer ring; the arrow, a
  sub item or a whole drop-down button opens a nested ring (a split button runs its command, its arrow opens the
  ring). The center button closes the menu at the top level and goes back in nested rings (back arrow).
- Keyboard: arrows rotate the focus, Enter/Space run or open, Backspace goes back, Esc goes back / closes.
- Painted with `DrawRadialBackground`/`DrawRadialSector` and the Radial* tokens on a transparent round window (own
  soft shadow); opening and ring changes scale in over 170 ms (ease-out).

## Menu screen tips

Rows of every `TFmrMenuControl` (ribbon menus, `TFmrPopupMenu`, the commands of drop-down galleries) show the screen
tip of their item (`ScreenTip` header/description/footer or `Hint`) to the right of the menu, aligned with the row,
after the usual delay; quick switch between rows. Implemented by `FmrMenuHotRowHook` (`FMR.Ribbon.Popup`), installed
by `FMR.Ribbon.ScreenTips`. Large rows with descriptions (Office 2007 style) exist in `TFmrMenuControl`
(`TFmrMenuItemStyle.Large`/`Auto`) and in the application menu.

## Painter additions (`FMR.Ribbon.Painter`)

`DrawResizeGrip`, `DrawThinScrollBar`, `DrawGalleryFilterBand`, `DrawPinGlyph`, `DrawAppMenuFrame`, `DrawMiniToolbar`,
`DrawRadialBackground`, `DrawRadialSector` (new methods only).

## Changes in existing units

- `FMR.Ribbon.Views`: `TFmrElement.SetHotPart` (virtual writer of `HotPart`) and `TFmrElement.MouseMoveAt(P)`
  (called by `TFmrElementTracker` after mouse moves and presses), so elements with inner parts track them and learn
  that the mouse left. `TFmrElementTracker.SetHot` no longer clears `HotPart` when only the part of the same element
  changes.
- `FMR.Ribbon.Popup`: `TFmrMenuHotRowHook` / `FmrMenuHotRowHook`, called by `TFmrMenuControl` when its hot row changes,
  when it closes and when it is freed.
- `FMR.Ribbon.ScreenTips`: the menu screen tip handler (initialization section).
- `FMR.Ribbon.Popup`, `TFmrMenuControl.ExecuteRow`: the command runs from the message loop (`TThread.ForceQueue`)
  after the popups closed. Before, a command that showed a modal dialog ran inside the mouse handler of the menu while
  the popup manager freed the closed menu (graveyard timer) - an access violation after the dialog closed (found with
  "More Colors..."). The new popups do the same (gallery clicks, color picks, application menu commands, radial menu).
- `FMR.Ribbon`: uses `FMR.Ribbon.Gallery` and `FMR.Ribbon.ColorGallery` (one line in the implementation uses).

## Known issues

- The mini toolbar window is outside the popup chain (so menus of the ribbon never close it): typing into its combo
  boxes is not routed to them (popup windows never get the keyboard focus); their lists work with the mouse.
- Fading of the mini toolbar paints it into a bitmap drawn with the opacity (the painter itself draws opaque); the
  radial menu animation scales the disc and fades only the glyphs and texts.
- Entry screen tips are placed below the cell (they cover the next row while shown); the mouse wheel over an
  in-ribbon gallery switches tabs (ribbon behavior) instead of scrolling rows.
- The "More Colors" dialog is a modal FMX form with the default FMX style (not themed).
- The application menu has the Office 2007 look only; with Office 2010+ themes the backstage view is the better choice
  (the menu still works, below the "File" tab).
- No right-to-left mirroring in the new popups; no touch-mode sizes.
- Automated checks: other programs on the shared desktop took the foreground every few seconds (FMX closes popups
  when the form is deactivated), so screenshots were taken with retries (see Verification).

## Verification

Builds: `.\build.ps1 -Project Demos\RibbonBasic\RibbonBasic.dpr` (Win64) and `-Platform Win32` without warnings or
hints; `Demos\Extras` and `Demos\Customize` still build; tests `Tests\FmrRibbonTests.dpr`: 156/156 passed, no leaks.
The demo exits without a memory leak report after: styles gallery (hover, click), color gallery and "More Colors",
mini toolbar with context menu (Bold), application menu (submenu, command), radial menu (nested ring, back), fading
mini toolbar.

Screenshots (`shots\gal\`, Windows 11 at 150 %):

| Shot | Checked |
|---|---|
| `g01_home`, `s02_w1000`, `s03_w760`, `w02_grouppopup` | in-ribbon styles gallery at 6 / 2 columns, reduced to a large button, in a collapsed group popup |
| `s01_scroll07` | row scrolling (scroll down), hot gallery frame and entry in Office 2007 |
| `g13_dd_hover`, `g13_dd_menuhover`, `t01_styles_dark` | drop-down over the in-ribbon gallery, hover + live preview on the memo + entry tip, command hover, FluentDark |
| `g16_resize_smaller`, `g16_resize` | resize grip: fewer columns/rows with scroll bar, larger |
| `g14_cover`, `g15_filter_listhot`, `g15_filter`, `g19_dbg`, `t02_cover_dark` | gallery from a large button: filter band, filter list, filtered to "Built-in", group header, owner-drawn pages, 365 / 2007 / FluentDark |
| `h01_shapes_dark`, `t03_shapes_07`, `t04_shapes_365`, `h04_shapes_resized` | menu with an inline gallery (group headers) and a command; the top gallery is resizable |
| `k01_keys_nav`, `k01_final_crop` | Alt, H, L opens the gallery by keyboard (selected entry focused), Right, Right, Down moves the focus with preview, Enter applies it (gallery scrolls to the selection) |
| `c01_color`, `t05_color_07`, `t06_color_dark`, `c02_more`, `c04_recent`, `h02_highlight07` | color gallery with tints/shades, color tip, live preview, "More Colors" dialog, recent colors, highlight palette |
| `a06_dbg`, `a07_pin_crop`, `a08_365`, `a09_fluentdark`, `x02_appkeys` | Office 2007 application menu: orb over the menu, Save As submenu in the pane, pinned recent documents, other themes, key tips |
| `m01_mini365`, `m02_bold_hot`, `m02_bold`, `m05_*_crop`, `m06_mini07` | mini toolbar + context menu, button tip, Bold keeps the toolbar and closes the menu, fading with distance, Office 2007 |
| `r01_radial`, `r02_hot_crop`, `r02_nested_crop`, `leak3_b` | radial menu, hot sector (2007), nested Align ring with back button, FluentDark |
| `x03_menutip` | screen tip of a context menu row |

## For the coordinator (design package)

Register for the IDE: components `TFmrRibbonApplicationMenu`, `TFmrRibbonMiniToolbar`, `TFmrRibbonRadialMenu`
(palette); bar item classes `TFmrRibbonGalleryItem` and `TFmrColorGalleryItem` (item editor of the bar manager);
collections `TFmrRecentDocuments`/`TFmrRecentDocument` are registered with `RegisterClasses`. Add the units
`FMR.Ribbon.Gallery`, `FMR.Ribbon.ColorGallery`, `FMR.Ribbon.AppMenu`, `FMR.Ribbon.MiniToolbar`,
`FMR.Ribbon.RadialMenu` to `FMRRibbon.dpk`.

## Demo (`Demos\RibbonBasic`)

- Home > Styles: in-ribbon styles gallery (`TFmrRibbonGalleryItem`, owner-drawn "AaBbCcDd" samples in the style's
  font and color, 16 styles, 2..6 columns, live preview on the document memo, commands "Create a Style", "Clear
  Formatting", "Apply Styles...").
- Home > Font: Font Color (`TFmrColorGalleryItem`, live preview on the memo, the split part applies the last color)
  and Text Highlight Color (highlight palette).
- Insert > Pages > Cover Page: drop-down gallery from a large button (`ShowInRibbon = False`), group filter
  (Built-in / Office.com), owner-drawn pages with captions, 3 x 2 rows, resize grip, commands.
- Insert > Illustrations > Shapes: menu with an inline shapes gallery (5 groups with headers) and a command.
- File: the Office 2007 application menu with the Office 2007 themes (or `/appmenu`); `/backstage` keeps the backstage
  view; other themes keep the `TFmrPopupMenu`.
- Right click on the document: context menu + mini toolbar; selecting text with the mouse: the fading mini toolbar.
- View > Touch > Radial Menu: the radial menu at the mouse (Undo, Bold, Italic, Underline, Font Color, Bullets
  (nested bullet styles), Align (nested), Styles (nested)).
- Switches: `/open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial` opens the
  popup about a second after start (for screenshots), `/appmenu`.
