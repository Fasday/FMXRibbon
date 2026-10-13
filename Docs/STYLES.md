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

Every theme is built from an accent color (`TFmrRibbon.AccentColor`; 0 = the theme's default, Word blue): Colorful
captions, active tab indicators, File tab, selection in galleries. Constants: `FmrAccentWord`, `FmrAccentExcel`,
`FmrAccentPowerPoint`, `FmrAccentOutlook`, `FmrAccentOneNote`, `FmrAccentAccess`, `FmrAccentFluent`.

`tools\ThemeSheet` renders a sheet of parts of every theme into `shots\themes\*.png`.

## Overriding tokens with a StyleBook

Put resources into the form's StyleBook whose **StyleName** is the token's style name:

- `TColorObject` — a solid color;
- `TBrushObject` — a solid color or a gradient (the gradient is applied top to bottom);
- `TFontObject` named `fmr_font` — the font family and size of the ribbon.

The ribbon reads them when the style changes (`TFmrTheme.ApplyStyleOverrides`); tokens that are not in the
StyleBook keep the values of the selected built-in theme. `TFmrTheme.ExportToStyle` writes all tokens of a theme
into a style, a starting point for a custom StyleBook.

## Tokens
| Token (StyleName) | Office 365 White | Office 365 Black |
|---|---|---|
| `fmr_caption_fill` | #FFF3F3F3 | #FF1F1F1F |
| `fmr_caption_fill_inactive` | #FFF3F3F3 | #FF1F1F1F |
| `fmr_caption_text` | #FF1F1F1F | #FFF5F5F5 |
| `fmr_caption_text_inactive` | #FF8A8A8A | #FF9A9A9A |
| `fmr_caption_button_glyph` | #FF1F1F1F | #FFF5F5F5 |
| `fmr_caption_button_hot_fill` | #FFE0E0E0 | #FF3A3A3A |
| `fmr_caption_button_pressed_fill` | #FFCCCCCC | #FF4C4C4C |
| `fmr_close_button_hot_fill` | #FFC42B1C | #FFC42B1C |
| `fmr_close_button_pressed_fill` | #FFC74F43 | #FFC74F43 |
| `fmr_close_button_hot_glyph` | #FFFFFFFF | #FFFFFFFF |
| `fmr_frame_border` | #FFBDBDBD | #FF5A5A5A |
| `fmr_frame_border_inactive` | #FFD6D6D6 | #FF464646 |
| `fmr_app_button_fill` | none | none |
| `fmr_app_button_hot_fill` | #FFE0E0E0 | #FF3A3A3A |
| `fmr_app_button_pressed_fill` | #FFCCCCCC | #FF4C4C4C |
| `fmr_app_button_text` | #FF424242 | #FFD6D6D6 |
| `fmr_app_button_border` | none | none |
| `fmr_tab_row_fill` | #FFF3F3F3 | #FF1F1F1F |
| `fmr_tab_text` | #FF424242 | #FFD6D6D6 |
| `fmr_tab_text_hot` | #FF1F1F1F | #FFFFFFFF |
| `fmr_tab_text_active` | #FF2B579A | #FF8AA3C7 |
| `fmr_tab_text_disabled` | #FFA6A6A6 | #FF808080 |
| `fmr_tab_hot_fill` | #FFE0E0E0 | #FF3A3A3A |
| `fmr_tab_active_fill` | none | none |
| `fmr_tab_active_border` | none | none |
| `fmr_tab_active_indicator` | #FF2B579A | #FF8AA3C7 |
| `fmr_tab_separator` | none | none |
| `fmr_body_fill` | #FFFFFFFF | #FF292929 |
| `fmr_body_border` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_body_shadow` | #14000000 | #40000000 |
| `fmr_group_fill` | none | none |
| `fmr_group_hot_fill` | none | none |
| `fmr_group_border` | none | none |
| `fmr_group_caption_fill` | none | none |
| `fmr_group_caption_text` | #FF616161 | #FFC2C2C2 |
| `fmr_group_separator` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_group_launcher_glyph` | #FF616161 | #FFC2C2C2 |
| `fmr_group_collapsed_fill` | none | none |
| `fmr_group_collapsed_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_button_text` | #FF262626 | #FFF0F0F0 |
| `fmr_button_text_disabled` | #FFA6A6A6 | #FF808080 |
| `fmr_button_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_button_hot_border` | none | none |
| `fmr_button_pressed_fill` | #FFD6D6D6 | #FF4A4A4A |
| `fmr_button_pressed_border` | none | none |
| `fmr_button_checked_fill` | #FFDEDEDE | #FF444444 |
| `fmr_button_checked_border` | #FFC8C8C8 | #FF606060 |
| `fmr_button_checked_hot_fill` | #FFD0D0D0 | #FF4A4A4A |
| `fmr_button_split_line` | #FFC8C8C8 | #FF606060 |
| `fmr_button_arrow` | #FF616161 | #FFC2C2C2 |
| `fmr_glyph_tint` | #FF262626 | #FFF0F0F0 |
| `fmr_glyph_tint_disabled` | #FFA6A6A6 | #FF808080 |
| `fmr_button_group_fill` | none | none |
| `fmr_button_group_border` | none | none |
| `fmr_edit_fill` | #FFFFFFFF | #FF232323 |
| `fmr_edit_border` | #FFC8C8C8 | #FF585858 |
| `fmr_edit_border_hot` | #FF8A8A8A | #FF7F7F7F |
| `fmr_edit_text` | #FF262626 | #FFF0F0F0 |
| `fmr_edit_prompt_text` | #FF616161 | #FFC2C2C2 |
| `fmr_gallery_fill` | #FFFFFFFF | #FF232323 |
| `fmr_gallery_border` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_gallery_item_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_gallery_item_hot_border` | #FFC8C8C8 | #FF606060 |
| `fmr_gallery_item_selected_fill` | #2E2B579A | #2E8AA3C7 |
| `fmr_gallery_item_selected_border` | #FF2B579A | #FF8AA3C7 |
| `fmr_gallery_scroll_fill` | #FFFFFFFF | #FF292929 |
| `fmr_gallery_scroll_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_gallery_scroll_glyph` | #FF616161 | #FFC2C2C2 |
| `fmr_gallery_group_header_fill` | #FFF8F8F8 | #FF232323 |
| `fmr_gallery_group_header_text` | #FF262626 | #FFF0F0F0 |
| `fmr_menu_fill` | #FFFFFFFF | #FF282828 |
| `fmr_menu_border` | #FFD6D6D6 | #FF3A3A3A |
| `fmr_menu_gutter_fill` | none | none |
| `fmr_menu_item_text` | #FF262626 | #FFF0F0F0 |
| `fmr_menu_item_text_disabled` | #FFA6A6A6 | #FF808080 |
| `fmr_menu_item_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_menu_item_hot_border` | none | none |
| `fmr_menu_separator` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_menu_shortcut_text` | #FF616161 | #FFC2C2C2 |
| `fmr_menu_header_fill` | #FFF7F7F7 | #FF222222 |
| `fmr_menu_header_text` | #FF262626 | #FFF0F0F0 |
| `fmr_popup_shadow` | #38000000 | #66000000 |
| `fmr_qat_below_fill` | #FFFFFFFF | #FF292929 |
| `fmr_qat_border` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_scroll_button_fill` | #FFFFFFFF | #FF292929 |
| `fmr_scroll_button_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_scroll_button_glyph` | #FF616161 | #FFC2C2C2 |
| `fmr_key_tip_fill` | #FFFFFFFF | #FF2B2B2B |
| `fmr_key_tip_border` | #FF616161 | #FFC2C2C2 |
| `fmr_key_tip_text` | #FF262626 | #FFFFFFFF |
| `fmr_screen_tip_fill` | #FFFFFFFF | #FF282828 |
| `fmr_screen_tip_border` | #FFD6D6D6 | #FF3A3A3A |
| `fmr_screen_tip_title_text` | #FF262626 | #FFF0F0F0 |
| `fmr_screen_tip_text` | #FF616161 | #FFC2C2C2 |
| `fmr_screen_tip_separator` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_backstage_fill` | #FFFFFFFF | #FF292929 |
| `fmr_backstage_nav_fill` | #FFF3F3F3 | #FF1F1F1F |
| `fmr_backstage_nav_text` | #FF262626 | #FFF0F0F0 |
| `fmr_backstage_nav_hot_fill` | #FFE0E0E0 | #FF3A3A3A |
| `fmr_backstage_nav_selected_fill` | #FFCCCCCC | #FF4C4C4C |
| `fmr_backstage_nav_selected_text` | #FF262626 | #FFF0F0F0 |
| `fmr_backstage_nav_separator` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_backstage_header_text` | #FF262626 | #FFF0F0F0 |
| `fmr_backstage_text` | #FF616161 | #FFC2C2C2 |
| `fmr_status_bar_fill` | #FFF3F3F3 | #FF1F1F1F |
| `fmr_status_bar_text` | #FF616161 | #FFC2C2C2 |
| `fmr_status_bar_separator` | #FFE1E1E1 | #FF3A3A3A |
| `fmr_status_bar_item_hot_fill` | #FFE0E0E0 | #FF3A3A3A |
| `fmr_search_box_fill` | #FFFFFFFF | #FF232323 |
| `fmr_search_box_hot_fill` | #FFFFFFFF | #FF232323 |
| `fmr_search_box_border` | #FFC8C8C8 | #FF585858 |
| `fmr_search_box_text` | #FF262626 | #FFF0F0F0 |
| `fmr_search_box_prompt` | #FF616161 | #FFC2C2C2 |
| `fmr_mini_toolbar_fill` | #FFFFFFFF | #FF282828 |
| `fmr_mini_toolbar_border` | #FFD6D6D6 | #FF3A3A3A |
| `fmr_radial_fill` | #FFFFFFFF | #FF282828 |
| `fmr_radial_border` | #FF2B579A | #FF8AA3C7 |
| `fmr_radial_sector_hot_fill` | #FFEBEBEB | #FF3D3D3D |
| `fmr_radial_text` | #FF262626 | #FFF0F0F0 |
| `fmr_accent` | #FF2B579A | #FF2B579A |
| `fmr_focus_border` | #FF262626 | #FFF0F0F0 |

