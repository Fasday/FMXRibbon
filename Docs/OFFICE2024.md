# Office 2024 reference measurements

Colors measured on the real Word, Excel and PowerPoint 2024 (Microsoft 365, Windows 11, 96 DPI) in the White, Dark Gray and Black Office themes, active and inactive windows. The themes Office2024Light, Office2024DarkGray and Office2024Dark and the focus effect are built from these numbers. (File names refer to captures kept outside the repository.)

## Word 2024 White

Captured after the dark ones (the owner switched Word to White): `word_light_active.png` (window active) and
`word_light_inactive.png` (window inactive), 2576x1408, 96 DPI, same window size and layout as the dark captures.
Unlike the dark pair, these two DO differ, so they show the focus effect.

Sampled (active → inactive):

| Part | Active | Inactive |
|---|---|---|
| caption + tab row background | #EBEEF2 (Mica tint) | #F0F0F0 (solid) |
| title text, "AutoSave" text, toggle, QAT glyphs (Save is purple #922E9B), caption button glyphs, search text | #242424 (search text #616161) | all #BDBDBD |
| search box fill | #FAFAFA | #F0F0F0 (border stays) |
| tab text (all tabs, active bold) | #242424 | #242424 (unchanged) |
| active tab underline | #1651AA | #1651AA (unchanged) |
| document background | #EDEFF4 (Mica tint) | #F0F0F0 |
| ribbon body card | #FFFFFF, edge #DCDEE1, bottom shadow #CBCDD1 | same (edge #DFDFDF / #CECECE) |
| group caption text | #242424 | same |
| group separator | #D1D1D1 | same |
| disabled text | #BDBDBD | same |
| account avatar | #A4262C circle, white initials | same |
| "Share" button | #185ABD fill, white text/glyph | same |

So in Word 2024 the focus effect dims only the caption row content (title, QAT, AutoSave, search, caption buttons)
to #BDBDBD and turns the Mica-tinted backgrounds into flat #F0F0F0; tabs and the ribbon body do not change.

## Word 2024 "Dark Gray" Office theme

`word_darkgray_active.png` / `word_darkgray_inactive.png` (same window). A third variant worth a theme of its own
(`Office2024DarkGray`): dark gray caption, LIGHT GRAY ribbon body with dark text.

| Part | Active | Inactive |
|---|---|---|
| caption + tab row background | #55575B (Mica tint) | #525252 |
| title, AutoSave, QAT glyphs, caption button glyphs | #FFFFFF | #9E9E9E |
| search box fill / text | #BDBDBD / #424242 | #858585 / dimmer |
| tab text | #FFFFFF | #FFFFFF (unchanged) |
| active tab underline | #AEC6F0 | unchanged |
| ribbon body card | #BDBDBD, edge #464748, bottom shadow #323334 | same |
| button and group caption text | #242424 | same |
| group separator, disabled text | #858585 | same |
| document background | #58595B (Mica tint) | #525252 |
| "Share" button | #82ABF1 fill, #242424 text | same |

Note on the Black theme captures (`word_active.png` / `word_inactive.png`): both were taken while the window looked
active, so they do not show the inactive state; by analogy with White and Dark Gray, the inactive caption content
dims to a gray (about #9E9E9E) and the Mica tint turns into a flat color.

## Accents per application (White theme, `<app>_white_active.png`)

| App | "Share" button fill | Active tab underline | Note |
|---|---|---|---|
| Word | #185ABD | #1651AA | underline = fill x 0.9 |
| Excel | #107C41 | #0F703B | underline = fill x 0.9 |
| PowerPoint | #C43E1C | #B13719 | underline = fill x 0.9 |
| Access | — | — | Access still has the older Office look (red "File" tab, no 2024 refresh) |

Dark Gray (Word only so far): fill #82ABF1 (dark text), underline #AEC6F0 — lighter brand shades, not a plain mix
with white (different factor per channel), i.e. Office takes them from a brand color ramp. The QAT Save glyph is
purple #922E9B in every app (Fluent icon color, not the accent). Excel's window was not maximized (1920x1023).
NOTE: the earlier Word Dark Gray full captures were overwritten by White ones; the Dark Gray numbers above and the
crops `wdg_left2.png` / `wdgi_left2.png` remain.

## Accents per application (Dark Gray theme, `<app>_darkgray_active.png`, recaptured)

| App | "Share" fill (text #242424) | Active tab underline |
|---|---|---|
| Word | #82ABF1 | #AEC6F0 |
| Excel | #60BD82 | #A0D8B9 |
| PowerPoint | (window was minimized — not captured) | |

Word Dark Gray full captures were retaken (`word_darkgray_active.png` / `_inactive.png`): title #FFFFFF active →
#9E9E9E inactive; caption #56585B (Mica) → #525252.

## Black theme (`<app>_black_active.png` / `_inactive.png`, all apps, real inactive state this time)

| Part | Active | Inactive |
|---|---|---|
| caption + tab row background | #1D222A (Mica tint) | #0A0A0A (flat) |
| title, QAT glyphs, caption button glyphs | #FFFFFF | #5C5C5C |
| search box fill / text | #1F1F1F / #ADADAD | #141414 / #5C5C5C |
| tab text | #FFFFFF | #FFFFFF (unchanged) |
| ribbon body card | #292929 | same |
| document background | #21262E (Mica tint) | #0A0A0A |

Accents in Black ("Share" text is black #000000):

| App | Share fill | Underline |
|---|---|---|
| Word | #598FEC | #82ABF1 |
| Excel | #37A660 | #60BD82 |
| PowerPoint | #D67540 | #E1966D |

## The brand ramp (all themes together)

| Step | Word | Excel | PowerPoint | Used for |
|---|---|---|---|---|
| -1 | #1651AA | #0F703B | #B13719 | White: underline |
| 0 (brand) | #185ABD | #107C41 | #C43E1C | White: Share fill |
| +1 | #598FEC | #37A660 | #D67540 | Black: Share fill |
| +2 | #82ABF1 | #60BD82 | #E1966D | Black: underline; Dark Gray: Share fill |
| +3 | #AEC6F0 | #A0D8B9 | (n/a) | Dark Gray: underline |

So the themes take fixed steps of one ramp of lighter shades of the brand color.

