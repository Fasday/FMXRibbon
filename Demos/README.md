# FMR Ribbon demos

All demos are FireMonkey programs for Windows (Win64 and Win32). Build them from the repository root with
`build.ps1`, which puts every folder of `Source\` on the search path and writes the executable to
`bin\<Platform>\<Config>\`:

```powershell
.\build.ps1 -Project Demos\WordLike\WordLike.dpr                 # Win64 Debug
.\build.ps1 -Project Demos\WordLike\WordLike.dpr -Platform Win32
.\build.ps1 -Project Demos\Showcase\Showcase.dpr -Config Release
```

Debug builds set `ReportMemoryLeaksOnShutdown`: closing a demo that leaked shows the RTL leak report.

**FastCanvas** (optional GPU canvas, `f:\Projects\FmxFastCanvas_GitHub`, see its README): the demos that support it
call `InstallFastCanvas` before `Application.Initialize` when they are built with the `FMR_FASTCANVAS` define:

```powershell
.\build.ps1 -Project Demos\WordLike\WordLike.dpr -Define FMR_FASTCANVAS `
  -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src
```

(WordLike, Showcase and NCProof support it; the About page of WordLike and the Canvas page of the Showcase show the
canvas class in use.)

Screenshots for documentation are taken with `tools\drive.ps1` (posted mouse messages, keys, `PrintWindow`
capture, independent of other windows on the desktop), for example
`.\tools\drive.ps1 -Exe bin\Win64\Debug\Showcase.exe -Arguments "/page=1 /theme=Office365Black" -Out shots\x.png`.

| Demo | What it shows |
|---|---|
| [WordLike](#wordlike--fmr-write) | "FMR Write": a complete Word-like application whose main form is a real `.fmx` form |
| [Showcase](#showcase--feature-gallery) | One page per feature with explanations and live controls |
| [RibbonBasic](#ribbonbasic) | A Word-like ribbon built in code: galleries, application menu, mini toolbar, radial menu |
| [Extras](#extras) | Backstage view and status bar on their own (with a stand-in theme provider) |
| [NCProof](#ncproof) | The window frame: FMX controls in the real non-client area, the three frame modes |
| [Customize](#customize) | Customization form, display options, auto-hide, simplified switch, right to left, UI Automation |

## WordLike — FMR Write

`Demos\WordLike\WordLike.dpr`. A text editor that looks and behaves like Word, written the way an application is
written in the IDE: **the main form is streamed from `WordLikeMain.fmx`** — the window frame (`TFmrFormFrame`,
FullNC), the bar manager with about 140 items, the ribbon with its tabs, groups, links, the "Selection Tools"
contextual group and the quick access toolbar, the backstage view with its tabs and content, the status bar with
its panels, an image list, the document page, the find pane, the mini toolbar, the context menu, a timer and the
file dialogs. The unit (`WordLikeMain.pas`) only declares the published fields and the event handlers that the
`.fmx` refers to.

What to try:

- **Home**: Paste (split button: Keep Source Formatting / Keep Text Only), Cut, Copy; font name and size editors,
  Grow/Shrink, Change Case menu, Bold/Italic/Underline/Strikethrough toggles, the font color gallery (live preview),
  Clear Formatting; bullets, numbering, indent, sort, alignment (radio buttons); the owner-drawn **Styles gallery**
  with live preview; Find / Replace (the find pane: next, previous, replace, replace all, result count).
- **Insert**: blank page, page break, a drop-down gallery of quick tables (owner drawn, inserts a text grid), the
  Shapes menu with an inline gallery, text box, date & time, signature line, comment, link, the in-ribbon Symbols
  gallery.
- **Layout**: margins, orientation and page size (menus with radio items), watermark, page color (color gallery),
  page borders, indent spin editors — the page follows.
- **View**: read mode / print layout / web layout (synced with the view buttons of the status bar), status bar,
  word wrap and find pane check boxes, zoom (menu, 100 %, in, out, page width; the status bar slider is bound to it:
  zoom scales the page and the font), the **Themes gallery** listing every registered theme with a preview swatch
  (a click switches the whole window live), the accent gallery, simplified ribbon, touch mode, language
  (English / Русский), Customize Ribbon (`TFmrRibbon.ShowCustomizationForm`), Reset Ribbon.
- **Selection Tools** (contextual group, two tabs "Text" and "Lines"): shown while the document has a selection;
  change case, cut/copy/delete, quotes, sort, reverse and trim lines, lists, a selection counter.
- **File** (backstage view): Info (properties, protect = read-only, check for issues = remove double spaces,
  version history = undo), New (template tiles with images from the `TImageList`), Open (recent files and samples,
  Browse), Save, Save As (folder, name, format), Print (simulated: copies, printer list, page preview), Close, About
  (canvas class), Options (theme, accent, frame mode FullNC/Dwm/NCStrip, Mica/Acrylic backdrop, language, touch,
  simplified, QAT below, search box, screen tips — all applied live).
- Quick access toolbar (Save, Undo, Redo, customize menu), Undo/Redo history (also Ctrl+Z / Ctrl+Y), the search box
  ("Tell me": commands; Enter searches the document), key tips everywhere (Alt), the mini toolbar after a mouse
  selection and on right click (with the context menu), status bar: page, words, characters, language (click to
  switch), messages, view buttons, zoom slider.
- **Persistence**: on close the ribbon layout is saved to `%APPDATA%\FMRWrite\layout.json` (customized tabs, QAT,
  minimized/simplified state) and theme, accent, frame, language, zoom and recent files to `settings.ini`; both are
  loaded at start. Reset Ribbon returns to the designed layout.
- **Language**: `FmrSetLanguage` switches the library strings; the captions of the demo's own components are
  translated from `WordLikeLang.pas` (English texts are captured from the `.fmx` at start).

Command line: `/theme=<name> /accent=RRGGBB /lang=ru /frame=fullnc|dwm|ncstrip /backdrop=mica|acrylic /zoom=N
/tab=N /backstage[=N] /select /find=<text> /simplified /touch /qatbelow
/open=styles|themes|accent|table|shapes|symbols|fontcolor|minitoolbar|context|customize|keytips /keytips /fresh`
(ignore saved settings) `/nosave /settingsdir=<folder> /docdir=<folder> /width=N /height=N /dumpfmx=<file>` (writes
the form, as loaded, back to text) `/dump=<file>` (`TFmrRibbon.DebugDump`).

### The `.fmx` and its generator

`WordLikeMain.fmx` was not written by hand: `tools\GenForm.dpr` creates the real form class with `CreateNew` (so no
resource is read), builds every component in code (`tools\WordLikeBuild.pas`: owned by the form, named, events
pointing to published methods) and saves it with `TStream.WriteComponent` + `ObjectBinaryToText`, exactly what the
IDE does when it saves a designed form. To change the form, edit `WordLikeBuild.pas` (or open the `.fmx` in the IDE
with the packages installed) and regenerate:

```powershell
.\Demos\WordLike\tools\gen.ps1            # builds GenForm (-Define WORDLIKE_GEN), writes the .fmx, builds the demo
bin\Win64\Debug\GenForm.exe <file.fmx> /show /fresh /nosave   # also shows the generated form, for comparison
```

`WordLike.exe /dumpfmx=<file>` writes the loaded form back to text: compared with `WordLikeMain.fmx` only the client
size and the positions that depend on it differ (the frame attaches in `Loaded` and takes the caption strip from the
client area), so every property of the library survives streaming.

## Showcase — feature gallery

`Demos\Showcase\Showcase.dpr`, built in code. The main ribbon (Word template from `FmrApplyRibbonTemplate` plus a
"Showcase" tab with a themes gallery, page navigation and popups) is in the window frame; the navigation list on the
left (a themed `TFmrBackstageGalleryList`) selects a page; every page explains one feature and has live controls
(themed `TFmrBackstageTile` buttons):

| # | Page | Live controls |
|---|---|---|
| 0 | Overview | links to every page |
| 1 | Themes and accents | all 18 built-in themes, 8 accent colors |
| 2 | Window frame | FullNC / Dwm / NCStrip, backdrop None / Mica / Acrylic / Tabbed (Dwm, Windows 11) |
| 3 | Adaptive layout | a slider sets the width of a second ribbon in a panel (reduction steps); Simple / Word / Excel templates |
| 4 | Galleries | open the styles, themes, color, highlight galleries and the Shapes menu |
| 5 | Menus and popups | split button menu, context menu (`TFmrPopupMenu`), drop-down menu, command search |
| 6 | Key tips | show key tips, on/off |
| 7 | Screen tips | show the tip of Paste, on/off |
| 8 | Contextual tabs | show / activate / hide Table Tools, add a "Picture Tools" group in code |
| 9 | Quick Access Toolbar | above / below, add / remove commands, visibility, customize button |
| 10 | Display modes | minimized, tabs and commands / tabs only / auto-hide, classic / simplified, touch, buttons |
| 11 | Right to left | `RightToLeft` on/off |
| 12 | Mini toolbar | with the context menu, fading |
| 13 | Radial menu | nested ring (Align) |
| 14 | Application menu or backstage | backstage view, Office 2007 application menu, popup menu; Office 2007 Blue (orb) |
| 15 | Status bar | a second status bar with every panel kind |
| 16 | Merging | a "document" ribbon merged into / unmerged from the main ribbon (`Merge` / `Unmerge`) |
| 17 | Persistence | layout JSON in a memo: save, load, hide a tab, reset |
| 18 | Customization | `ShowCustomizationForm` (ribbon / quick access toolbar pages) |
| 19 | Localization | English / Русский (`FmrSetLanguage`) |
| 20 | Canvas | canvas class in use, `FMR_FASTCANVAS`, how to build with FastCanvas |
| 21 | Performance | creates a tab with 50 groups x 10 commands and measures creation, layout, paint and tab switch |

Command line: `/page=N /theme=<name> /accent=RRGGBB /frame=fullnc|dwm|ncstrip /lang=ru /width=N /height=N` and
`/auto` (runs the demo action of the page about a second after start: opens the gallery, the menu, the radial menu,
merges, measures...), for screenshots.

## RibbonBasic

`Demos\RibbonBasic\RibbonBasic.dpr`: a Word-like ribbon built in code — tabs Home, Insert, Layout, View, the "Table
Tools" contextual group, every button kind, editors, color items, dialog launchers, the quick access toolbar and the
search box; the in-ribbon styles gallery, Cover Page (drop-down gallery with filter and grip), Shapes (menu with an
inline gallery), font color / highlight galleries, the Office 2007 application menu, the mini toolbar (selection,
right click) and the radial menu. Switches: `/theme= /frame=fullnc|dwm|ncstrip|none /minimized /simplified /width=
/height= /qatbelow /tabletools /keytips /touch /nosearch /tab=N /backstage /appmenu
/open=stylesgallery|colorgallery|highlight|cover|shapes|appmenu|minitoolbar|minifade|radial /dump=<file>` (see
`Docs\RIBBON.md` and `Docs\GALLERIES.md`).

## Extras

`Demos\Extras\ExtrasDemo.dpr`: the backstage view (Info, New, Open, Save As, Print, Account, Options) and the status
bar (text, container, item links, view buttons, zoom slider) without a ribbon: a stand-in theme provider plays its
part. Switches: `/theme= /accent=RRGGBB /backstage /tab=N /keytips /standalone /noanim /frame[=fullnc|dwm|ncstrip]
/keeprow` (see `Docs\EXTRAS.md`).

## NCProof

`Demos\NCProof\NCProof.dpr`: the proof of the window frame — buttons, a `TEdit`, combo boxes and a fake tab row in
the real non-client area, a geometry panel (window/client rectangles, hit test under the cursor, DPI, focus, IME
positions). Switches: `/mode=dwm|fullnc|ncstrip /dark /backdrop=mica|acrylic|tabbed /notabs /maximized /pos=X,Y
/topmost /fixed /noframe /strategy=keepcaption|allowncpaint|nodwmframe|animcaption /animtest /simdpi`; FastCanvas
with `-Define FMR_FASTCANVAS` (see `Docs\FRAME.md`).

## Customize

`Demos\Customize\CustomizeDemo.dpr`: the customization form (`FMR.Ribbon.Customize`: "Customize the Ribbon" and
"Quick Access Toolbar" pages, import/export), the Ribbon Display Options caption button, auto-hide, the
classic/simplified switch, right to left, the themed editors and the UI Automation provider (`uia-test.ps1`).
Switches: `/theme= /frame= /lang=ru /tab=N /open=customize|qat /rtl /formrtl /autohide /showautohide
/displayoptions /simplified /touch /switchtheme= /layout=<file> /autofile=<file> /savelayout=<file> /tabletools
/dropdown=<id> /keytips /nouia /dump= /dumpcust=` (see the header of `CustomizeDemoMain.pas`).
