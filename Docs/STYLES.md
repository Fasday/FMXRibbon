# Themes and StyleBook tokens

The ribbon paints every part with canvas primitives (no style objects per control) using a **theme**: a table of
tokens (colors and fills), metrics (sizes in dp) and switches that select the drawing variant (tab shape,
application button, group frame).

## Built-in themes

| Name (`TFmrRibbon.Theme`) | Look |
|---|---|
| `Office365Colorful`, `Office365White`, `Office365DarkGray`, `Office365Black` | Office 365 / 2019+: flat, floating body card, underlined active tab |
| `Office2016Colorful`, `Office2016White`, `Office2016DarkGray` | Office 2016: accent caption (Colorful), boxed tabs |
| `Office2013White`, `Office2013LightGray`, `Office2013DarkGray` | Office 2013: capital tab captions, colored File tab, tinted highlights |
| `Office2010Blue`, `Office2010Silver`, `Office2010Black` | Office 2010: gradients, framed groups, colored File tab |
| `Office2007Blue`, `Office2007Silver`, `Office2007Black` | Office 2007: glass gradients, application orb |
| `FluentLight`, `FluentDark` | Windows 11 (WinUI 3): Mica-friendly caption, rounded corners |
| `Office2024Light`, `Office2024DarkGray`, `Office2024Dark` | Microsoft 365 / Office 2024 (the 2023/2024 visual refresh, measured on Word "White", "Dark Gray" and "Black"): caption row 48 dp, tab row 30 dp, bold active tab with a thin rounded line, a 100 dp body card 8 dp from the window edges, chevron arrows, the title after the quick access toolbar, a centered search box, the collapse chevron in the card, a transparent caption over Mica |

Every theme is built from an accent color (`TFmrRibbon.AccentColor`; 0 = the theme's default, Word blue): Colorful
captions, active tab indicators, File tab, selection in galleries. Constants: `FmrAccentWord`, `FmrAccentExcel`
(#107C41), `FmrAccentPowerPoint` (#C43E1C), `FmrAccentOutlook`, `FmrAccentOneNote`, `FmrAccentAccess`,
`FmrAccentFluent`, `FmrAccentWord2024` (#185ABD, the default of the Office 2024 themes).

The Office 2024 themes take the accent as the brand color of the application (the older Word, Excel and PowerPoint
accents give the 2024 ones): in Light the "Share" button is the accent and the active tab line the accent x 0.9 (Word
#185ABD / #1651AA, Excel #107C41 / #0F703B); in Dark and Dark Gray both are light shades of a brand ramp,
`FmrAccentShade(Accent, Level)` (OKLCH lightness 0.66 / 0.74 / 0.83: Word #598FEC, #82ABF1, #AEC6F0).

Switches of `TFmrThemeStyle` added for Office 2024 (other themes keep them off): `ChevronArrows` (stroked chevrons
instead of filled triangles, also in the themed editors), `BoldActiveTab` (tabs as wide as their bold caption),
`LeadingTitle` (the title follows the quick access toolbar), `CollapseInBody` (the collapse chevron in the bottom
right corner of the card). Metrics: `TabFontSize`, `TabIndicatorHeight`/`TabIndicatorOffset`, `CaptionButtonWidth`,
`SearchBoxWidth`/`SearchBoxHeight`, `MaxRowGap` (rows of a column with fewer rows are top-aligned with this gap:
Word's two-row Font and Paragraph groups), `StatusBarFontSize`, `GroupSeparatorInsetTop`/`Bottom`.

Tokens added with Office 2024 (every theme defines them): `TabTextInactive` (tabs of an inactive window),
`CaptionBackdropFill` (painted over a Mica/Acrylic backdrop instead of the caption color; none = the material shows
through), `SearchBoxFillInactive`, `PrimaryButton*` (accent filled buttons, `TFmrButtonItem.Primary`),
`ToggleSwitch*` (`TFmrCheckItem.CheckStyle = ToggleSwitch`).

**Focus effect.** When the window loses the focus the caption row fades (about 170 ms,
`TFmrRibbon.AnimateActivation`) to its inactive look: `CaptionFillInactive`, `CaptionTextInactive` for the title, the
quick access toolbar, the caption toolbar, the search box text and the window buttons, `SearchBoxFillInactive`, and
`TabTextInactive` for the tabs. Office 2024 dims only the caption row content (like Word: #BDBDBD in White, #9E9E9E
in Dark Gray); its tabs, tab line and body do not change. `TFmrRibbon.ShowInactiveState = False` keeps the active
look.

`tools\ThemeSheet` renders a sheet of parts of every theme into `shots\themes\*.png` (`/tokens <file>` writes the
token table below).

## Overriding tokens with a StyleBook

Put resources into the form's StyleBook whose **StyleName** is the token's style name:

- `TColorObject` — a solid color;
- `TBrushObject` — a solid color or a gradient (the gradient is applied top to bottom);
- `TFontObject` named `fmr_font` — the font family and size of the ribbon.

The ribbon reads them when the style changes (`TFmrTheme.ApplyStyleOverrides`); tokens that are not in the
StyleBook keep the values of the selected built-in theme. `TFmrTheme.ExportToStyle` writes all tokens of a theme
into a style, a starting point for a custom StyleBook.

## Tokens
| Token (StyleName) | Office 365 White | Office 365 Black | Office 2024 Light | Office 2024 Dark |
|---|---|---|---|---|
| `fmr_caption_fill` | #FFF3F3F3 | #FF1F1F1F | #FFF0F0F0 | #FF1F1F1F |
| `fmr_caption_fill_inactive` | #FFF3F3F3 | #FF1F1F1F | #FFF0F0F0 | #FF1F1F1F |
| `fmr_caption_backdrop_fill` | none | none | none | none |
| `fmr_caption_text` | #FF1F1F1F | #FFF5F5F5 | #FF242424 | #FFFFFFFF |
| `fmr_caption_text_inactive` | #FF8A8A8A | #FF9A9A9A | #FFBDBDBD | #FF969696 |
| `fmr_caption_button_glyph` | #FF1F1F1F | #FFF5F5F5 | #FF242424 | #FFFFFFFF |
| `fmr_caption_button_hot_fill` | #FFE0E0E0 | #FF3A3A3A | #0F000000 | #14FFFFFF |
| `fmr_caption_button_pressed_fill` | #FFCCCCCC | #FF4C4C4C | #1A000000 | #0CFFFFFF |
| `fmr_close_button_hot_fill` | #FFC42B1C | #FFC42B1C | #FFC42B1C | #FFC42B1C |
| `fmr_close_button_pressed_fill` | #FFC74F43 | #FFC74F43 | #FFC74F43 | #FFC74F43 |
| `fmr_close_button_hot_glyph` | #FFFFFFFF | #FFFFFFFF | #FFFFFFFF | #FFFFFFFF |
| `fmr_frame_border` | #FFBDBDBD | #FF5A5A5A | #FFC8C8C8 | #FF5A5A5A |
| `fmr_frame_border_inactive` | #FFD6D6D6 | #FF464646 | #FFD6D6D6 | #FF464646 |
| `fmr_app_button_fill` | none | none | none | none |
| `fmr_app_button_hot_fill` | #FFE0E0E0 | #FF3A3A3A | #0F000000 | #14FFFFFF |
| `fmr_app_button_pressed_fill` | #FFCCCCCC | #FF4C4C4C | #1A000000 | #0CFFFFFF |
| `fmr_app_button_text` | #FF424242 | #FFD6D6D6 | #FF242424 | #FFFFFFFF |
| `fmr_app_button_border` | none | none | none | none |
| `fmr_tab_row_fill` | #FFF3F3F3 | #FF1F1F1F | #FFF0F0F0 | #FF1F1F1F |
| `fmr_tab_text` | #FF424242 | #FFD6D6D6 | #FF242424 | #FFFFFFFF |
| `fmr_tab_text_hot` | #FF1F1F1F | #FFFFFFFF | #FF242424 | #FFFFFFFF |
| `fmr_tab_text_active` | #FF2B579A | #FF8AA3C7 | #FF242424 | #FFFFFFFF |
| `fmr_tab_text_disabled` | #FFA6A6A6 | #FF808080 | #FFBDBDBD | #FF5C5C5C |
| `fmr_tab_text_inactive` | #FF424242 | #FFD6D6D6 | #FF242424 | #FFFFFFFF |
| `fmr_tab_hot_fill` | #FFE0E0E0 | #FF3A3A3A | #0F000000 | #14FFFFFF |
| `fmr_tab_active_fill` | none | none | none | none |
| `fmr_tab_active_border` | none | none | none | none |
| `fmr_tab_active_indicator` | #FF2B579A | #FF8AA3C7 | #FF1651AA | #FF80ACF1 |
| `fmr_tab_separator` | none | none | none | none |
| `fmr_body_fill` | #FFFFFFFF | #FF292929 | #FFFFFFFF | #FF292929 |
| `fmr_body_border` | #FFE1E1E1 | #FF3A3A3A | #FFDCDEE1 | #40000000 |
| `fmr_body_shadow` | #14000000 | #40000000 | #24000000 | #60000000 |
| `fmr_group_fill` | none | none | none | none |
| `fmr_group_hot_fill` | none | none | none | none |
| `fmr_group_border` | none | none | none | none |
| `fmr_group_caption_fill` | none | none | none | none |
| `fmr_group_caption_text` | #FF616161 | #FFC2C2C2 | #FF242424 | #FFFFFFFF |
| `fmr_group_separator` | #FFE1E1E1 | #FF3A3A3A | #FFD1D1D1 | #FF666666 |
| `fmr_group_launcher_glyph` | #FF616161 | #FFC2C2C2 | #FF242424 | #FFFFFFFF |
| `fmr_group_collapsed_fill` | none | none | none | none |
| `fmr_group_collapsed_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_button_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_button_text_disabled` | #FFA6A6A6 | #FF808080 | #FFBDBDBD | #FF5C5C5C |
| `fmr_button_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_button_hot_border` | none | none | none | none |
| `fmr_button_pressed_fill` | #FFD6D6D6 | #FF4A4A4A | #FFE0E0E0 | #FF474747 |
| `fmr_button_pressed_border` | none | none | none | none |
| `fmr_button_checked_fill` | #FFDEDEDE | #FF444444 | #FFEBEBEB | #FF383838 |
| `fmr_button_checked_border` | #FFC8C8C8 | #FF606060 | #FF616161 | #FFADADAD |
| `fmr_button_checked_hot_fill` | #FFD0D0D0 | #FF4A4A4A | #FFE0E0E0 | #FF424242 |
| `fmr_button_split_line` | #FFC8C8C8 | #FF606060 | #FFD1D1D1 | #FF666666 |
| `fmr_button_arrow` | #FF616161 | #FFC2C2C2 | #FF3B3B3B | #FFD4D4D4 |
| `fmr_glyph_tint` | #FF262626 | #FFF0F0F0 | #FF3B3B3B | #FFD4D4D4 |
| `fmr_glyph_tint_disabled` | #FFA6A6A6 | #FF808080 | #FFBDBDBD | #FF5C5C5C |
| `fmr_button_group_fill` | none | none | none | none |
| `fmr_button_group_border` | none | none | none | none |
| `fmr_edit_fill` | #FFFFFFFF | #FF232323 | #FFFFFFFF | #FF292929 |
| `fmr_edit_border` | #FFC8C8C8 | #FF585858 | #FF8A8A8A | #FF757575 |
| `fmr_edit_border_hot` | #FF8A8A8A | #FF7F7F7F | #FF616161 | #FF9E9E9E |
| `fmr_edit_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_edit_prompt_text` | #FF616161 | #FFC2C2C2 | #FF616161 | #FFC8C8C8 |
| `fmr_gallery_fill` | #FFFFFFFF | #FF232323 | #FFFFFFFF | #FF292929 |
| `fmr_gallery_border` | #FFE1E1E1 | #FF3A3A3A | #FFD1D1D1 | #FF666666 |
| `fmr_gallery_item_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_gallery_item_hot_border` | #FFC8C8C8 | #FF606060 | #FF616161 | #FFADADAD |
| `fmr_gallery_item_selected_fill` | #2E2B579A | #2E8AA3C7 | #FFEBEBEB | #FF383838 |
| `fmr_gallery_item_selected_border` | #FF2B579A | #FF8AA3C7 | #FF616161 | #FFADADAD |
| `fmr_gallery_scroll_fill` | #FFFFFFFF | #FF292929 | #FFFFFFFF | #FF292929 |
| `fmr_gallery_scroll_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_gallery_scroll_glyph` | #FF616161 | #FFC2C2C2 | #FF3B3B3B | #FFD4D4D4 |
| `fmr_gallery_group_header_fill` | #FFF8F8F8 | #FF232323 | #FFF6F6F6 | #FF333333 |
| `fmr_gallery_group_header_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_menu_fill` | #FFFFFFFF | #FF282828 | #FFFFFFFF | #FF2B2B2B |
| `fmr_menu_border` | #FFD6D6D6 | #FF3A3A3A | #FFE0E0E0 | #FF454545 |
| `fmr_menu_gutter_fill` | none | none | none | none |
| `fmr_menu_item_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_menu_item_text_disabled` | #FFA6A6A6 | #FF808080 | #FFBDBDBD | #FF5C5C5C |
| `fmr_menu_item_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_menu_item_hot_border` | none | none | none | none |
| `fmr_menu_separator` | #FFE1E1E1 | #FF3A3A3A | #FFD1D1D1 | #FF666666 |
| `fmr_menu_shortcut_text` | #FF616161 | #FFC2C2C2 | #FF616161 | #FFC8C8C8 |
| `fmr_menu_header_fill` | #FFF7F7F7 | #FF222222 | #FFF6F6F6 | #FF333333 |
| `fmr_menu_header_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_popup_shadow` | #38000000 | #66000000 | #30000000 | #66000000 |
| `fmr_qat_below_fill` | #FFFFFFFF | #FF292929 | #FFFFFFFF | #FF292929 |
| `fmr_qat_border` | #FFE1E1E1 | #FF3A3A3A | #FFD1D1D1 | #FF666666 |
| `fmr_scroll_button_fill` | #FFFFFFFF | #FF292929 | #FFFFFFFF | #FF292929 |
| `fmr_scroll_button_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_scroll_button_glyph` | #FF616161 | #FFC2C2C2 | #FF3B3B3B | #FFD4D4D4 |
| `fmr_key_tip_fill` | #FFFFFFFF | #FF2B2B2B | #FFFFFFFF | #FF2B2B2B |
| `fmr_key_tip_border` | #FF616161 | #FFC2C2C2 | #FF8A8A8A | #FFADADAD |
| `fmr_key_tip_text` | #FF262626 | #FFFFFFFF | #FF242424 | #FFFFFFFF |
| `fmr_screen_tip_fill` | #FFFFFFFF | #FF282828 | #FFFFFFFF | #FF2B2B2B |
| `fmr_screen_tip_border` | #FFD6D6D6 | #FF3A3A3A | #FFE0E0E0 | #FF454545 |
| `fmr_screen_tip_title_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_screen_tip_text` | #FF616161 | #FFC2C2C2 | #FF616161 | #FFC8C8C8 |
| `fmr_screen_tip_separator` | #FFE1E1E1 | #FF3A3A3A | #FFD1D1D1 | #FF666666 |
| `fmr_backstage_fill` | #FFFFFFFF | #FF292929 | #FFFFFFFF | #FF292929 |
| `fmr_backstage_nav_fill` | #FFF3F3F3 | #FF1F1F1F | #FFF0F0F0 | #FF1F1F1F |
| `fmr_backstage_nav_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_backstage_nav_hot_fill` | #FFE0E0E0 | #FF3A3A3A | #0F000000 | #14FFFFFF |
| `fmr_backstage_nav_selected_fill` | #FFCCCCCC | #FF4C4C4C | #1A000000 | #0CFFFFFF |
| `fmr_backstage_nav_selected_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_backstage_nav_separator` | #FFE1E1E1 | #FF3A3A3A | #FFD1D1D1 | #FF666666 |
| `fmr_backstage_header_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_backstage_text` | #FF616161 | #FFC2C2C2 | #FF616161 | #FFC8C8C8 |
| `fmr_status_bar_fill` | #FFF3F3F3 | #FF1F1F1F | #FFF5F5F5 | #FF141414 |
| `fmr_status_bar_text` | #FF616161 | #FFC2C2C2 | #FF242424 | #FFFFFFFF |
| `fmr_status_bar_separator` | #FFE1E1E1 | #FF3A3A3A | #FFFFFFFF | #FF3B3A39 |
| `fmr_status_bar_item_hot_fill` | #FFE0E0E0 | #FF3A3A3A | #FFE0E0E0 | #FF242424 |
| `fmr_search_box_fill` | #FFFFFFFF | #FF232323 | #FFFAFAFA | #FF1C1C1C |
| `fmr_search_box_hot_fill` | #FFFFFFFF | #FF232323 | #FFFAFAFA | #FF1C1C1C |
| `fmr_search_box_fill_inactive` | #FFFFFFFF | #FF232323 | #FFF0F0F0 | #FF1C1C1C |
| `fmr_search_box_border` | #FFC8C8C8 | #FF585858 | #FFD6D6D6 | #40000000 |
| `fmr_search_box_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_search_box_prompt` | #FF616161 | #FFC2C2C2 | #FF616161 | #FFADADAD |
| `fmr_mini_toolbar_fill` | #FFFFFFFF | #FF282828 | #FFFFFFFF | #FF2B2B2B |
| `fmr_mini_toolbar_border` | #FFD6D6D6 | #FF3A3A3A | #FFE0E0E0 | #FF454545 |
| `fmr_radial_fill` | #FFFFFFFF | #FF282828 | #FFFFFFFF | #FF2B2B2B |
| `fmr_radial_border` | #FF2B579A | #FF8AA3C7 | #FF185ABD | #FF80ACF1 |
| `fmr_radial_sector_hot_fill` | #FFEBEBEB | #FF3D3D3D | #FFF0F0F0 | #FF3D3D3D |
| `fmr_radial_text` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
| `fmr_primary_button_fill` | #FF2B579A | #FF2B579A | #FF185ABD | #FF5690EB |
| `fmr_primary_button_hot_fill` | #FF4068A4 | #FF4068A4 | #FF2F6BC4 | #FF4D82D3 |
| `fmr_primary_button_pressed_fill` | #FF254A83 | #FF254A83 | #FF467BCA | #FF4573BC |
| `fmr_primary_button_text` | #FFFFFFFF | #FFFFFFFF | #FFFFFFFF | #FF000000 |
| `fmr_toggle_switch_fill` | #FF2B579A | #FF8AA3C7 | #FF1651AA | #FF80ACF1 |
| `fmr_toggle_switch_border` | #FF616161 | #FFC2C2C2 | #FF242424 | #FFFFFFFF |
| `fmr_toggle_switch_thumb` | #FF616161 | #FFC2C2C2 | #FF242424 | #FFFFFFFF |
| `fmr_toggle_switch_thumb_on` | #FFFFFFFF | #FF1F1F1F | #FFFFFFFF | #FF1F1F1F |
| `fmr_accent` | #FF2B579A | #FF2B579A | #FF185ABD | #FF185ABD |
| `fmr_focus_border` | #FF262626 | #FFF0F0F0 | #FF242424 | #FFFFFFFF |
