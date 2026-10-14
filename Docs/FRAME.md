# The frame: FMX controls in the window's non-client area

`Source\Frame` puts caption content (title, caption buttons, the ribbon's caption row and tab row, any FMX control)
into the title bar area of a form. This file describes how it works, what each mode keeps of the Windows frame, what
was measured on Windows 11 and what is still open. The contract (types, interfaces, default hit test rules) is in
`Docs\ARCHITECTURE.md`, section "The frame".

## Units

| Unit | Contents |
|---|---|
| `FMR.Frame.Types` | Contract: `TFmrFrameMode`, `TFmrHitArea`, `IFmrFrameHitTest`, `IFmrFrameButton`, `IFmrFrameStateAware`, `TFmrFrameState`, `TFmrFrameStateMessage`. **Added**: `TFmrFrameState.DarkMode/Transparent/Hooked`, `TFmrFrameBackdrop` (None, Mica, Acrylic, Tabbed), `IFmrFrameCommands` (Minimize, ToggleMaximize, CloseForm, ShowHelp, ShowSystemMenu) |
| `FMR.Frame.Host` | `TFmrFrameHost = class(TControl, IScene)`: container of the caption content; `FmrFindFrameHost` |
| `FMR.Frame` | `TFmrFormFrame` (component, platform neutral), `TFmrFramePlatform` + `FmrFramePlatformClass` (factory filled by the platform unit) |
| `FMR.Frame.Win` | `TFmrWinFrame`: Windows implementation (subclassing, `WM_NC*`, DWM attributes, painting); `FmrHitTestName` |
| `FMR.Frame.Buttons` | `TFmrCaptionButton` (Minimize/Maximize/Close/Help, Windows 11 look), `TFmrCaptionTitle` (title that dims when inactive) |
| `FMR.Frame.Form` | `TFmrForm = class(TForm)` with a built-in `Frame` (sub-component, streamed with the form) |

`FMR.Frame` uses `FMR.Frame.Win` in its implementation section under `{$IFDEF MSWINDOWS}`, so using `FMR.Frame` (or
`FMR.Frame.Form`) is enough. All units except `FMR.Frame.Win` compile for every platform (checked with `dccosx64`:
compiles, only the link fails without the macOS SDK); without a platform class the frame does nothing and the host is
an ordinary control aligned to the top of the client area.

## How it works

### The host is the scene of its children

`TFmrFrameHost` is a child of the form. In the non-client modes it is placed **above the client area**
(`SetBounds(0, -CaptionHeight, ClientWidth, CaptionHeight)`, `Align = None`) and gives its children its own `IScene`
(`SetNewScene(Self)`), like `TCustomLayer3D` does for the 2D controls of a 3D form:

- The children's `Root` stays the form: focus, keyboard, `TEdit` caret and IME, hints, actions and the StyleBook work
  as for any control.
- Absolute coordinates stay **client coordinates of the form** (negative Y in the non-client strip). `IScene.LocalToScreen`
  / `ScreenToLocal` of the host delegate to the form's scene, so every FMX conversion (popup placement, IME candidate
  window, `ObjectAtPoint`, hints) gives the right screen position.
- `IScene.GetCanvas` is the canvas of the host's bitmap; `IScene.GetObject` returns the form (code that asks "is my
  form active/visible" or reads the form's font behavior keeps working).
- `IScene.AddUpdateRect` (every `Repaint`/`InvalidateRect` of a child, style animations, the caret flashing) does not
  go to the form (`TCustomForm.AddUpdateRect` would drop a rectangle outside its canvas anyway): the host calls
  `OnInvalidate`, the frame posts one private message (`RegisterWindowMessage('FMR.Frame.NCPaint')`, coalesced) and
  paints the strip when it arrives.
- Style changes sent for the form's scene are forwarded to the children with the host as scene (children ignore
  messages for another scene).
- In the Dwm mode (and when not hooked: design time, other platforms) the host is `Align = MostTop` in the client
  area and its children use the form's scene. Switching the mode re-scenes the children, realigns the form and gives
  the focus back to the focused control if it was in the host.

### Painting the non-client strip

`TFmrFrameHost.PaintBuffer(W, H, Scale)` renders the children into an FMX `TBitmap` (BitmapScale = form scale) with
`TOpenControl(Child).PaintInternal`; the frame maps the bitmap and copies it into a 32-bit DIB section, then `BitBlt`s
it to `GetWindowDC` at the strip rectangle (window coordinates: left = client left, top = client top − strip height,
width = client width). It happens in `WM_NCPAINT`, in the posted repaint message, on activation changes and after
`WM_SETTEXT`. A control invalidated while it is painted is painted again afterwards. Works with the stock Direct2D
canvas and with FastCanvas.

**Coordinates while painting.** Outside painting the children's absolute coordinates are client coordinates of the
form (negative Y). For the duration of `PaintBuffer` the host overrides `GetChildrenMatrix` with a translation by minus
its own absolute origin and calls `RecalcAbsolute`/`RecalcUpdateRect`, so the children's `AbsoluteMatrix` maps to
bitmap coordinates and every `PaintInternal` sets a matrix that is right for the bitmap; afterwards the matrices are
switched back the same way. The canvas is used without `TCanvas.Offset`, so `SaveState`/`RestoreState`, clipping and
rotated/scaled children work as on a form (round 1 used `TCanvas.Offset`: FMX's `TCanvasSaveState.AssignTo` sets
`Offset` and then `SetMatrix` of the saved matrix, which already contains the offset, so everything drawn after a
`RestoreState` inside a `Paint` was shifted by the offset a second time). Details:

- Update rectangles switched during the paint are not invalidations (`AddUpdateRect` ignores them while switching);
  `GetUpdateRect` answers in the coordinates the children currently use.
- `IScene.LocalToScreen`/`ScreenToLocal` of the host add/subtract the origin while the children are relative, so
  `LocalToScreen` called from a `Paint` stays right. `LocalToAbsolute` called from a `Paint` returns bitmap
  coordinates (as for `TControl.PaintTo`).
- Switching calls `DoAbsoluteChanged` of every child twice per paint. `TStyledComboEdit`/`TStyledComboTrackBar` close
  their own `TPopup` there when `AbsoluteClipRect` is empty, which it always is for a control in the strip in client
  coordinates (checked: the `TComboEdit` of NCProof with `DropDownKind = Custom` closed its list at the first repaint;
  with the default `Native` kind it uses a picker and was not affected). So **while an FMX popup (`TPopup` in FMX's
  popup list) whose placement target is in the host is open, `PaintBuffer` keeps the matrices and uses
  `TCanvas.Offset` as before** (with its `RestoreState` shift: in NCProof the app icon loses its glyph and the rotated
  rectangle moves while the "100%" list is open). The ribbon's own popups are not FMX `TPopup`s and do not trigger
  this.
- Verified in NCProof (screenshots, the old painting re-enabled for comparison): the app icon paints its background
  inside `SaveState`/`IntersectClipRect`/`RestoreState` and its "R" glyph after it — glyph in place (old: missing, drawn
  64 dp lower, outside the strip); a rotated `TRectangle` (45°, red diamond in the caption row) is drawn in place (old:
  cut at the top edge, the offset was applied in its rotated local space); the `TComboEdit` and `TComboBox` lists stay
  open.

**What the ribbon can remove** (`Source\Ribbon\FMR.Ribbon.pas`, not edited here): the offset folding in
`TFmrRibbonPart.Paint` (the comment "The non-client host paints with TCanvas.Offset…", the `SavedOffset`/`M`
variables, the block that moves `Canvas.Offset` into `Canvas.SetMatrix` before `SaveState`, and the
`Canvas.Offset := SavedOffset` after `RestoreState`; around lines 1223–1241) and the same folding in
`TFmrTipOverlay.Paint` (around lines 1303–1323). With the new painting `Canvas.Offset` is zero, so the code is a no-op;
it is harmless to keep and it still helps in the one case above (an FMX drop-down of a control in the host open).

### Mouse, keyboard, cursor

- `WM_NCHITTEST` maps the point into the host: `TFmrFrameHost.FrameHitTest` asks the deepest control under the point
  (`ObjectAtPoint`) and its parents for `IFmrFrameHitTest`; default: the host or a control with `HitTest = False` →
  `HTCAPTION`, any other control → `HTCLIENT`; `MinButton/MaxButton/CloseButton/HelpButton` → `HTMINBUTTON`,
  `HTMAXBUTTON`, `HTCLOSE`, `HTHELP`; `SysMenu` → `HTSYSMENU`. Resize borders come from the default procedure; the top
  edge/corners are added where nothing lies above the host (Dwm mode) and in the sizing border above the strip.
- Over `HTCLIENT` Windows sends ordinary client mouse messages with **negative client Y**; FMX's `WndProc` converts them
  to form coordinates and `ObjectAtPoint` finds the host's children through the host's scene. Nothing had to be routed
  by hand: clicks, hover, drag-select in a `TEdit`, double click and mouse capture all work.
- FMX sets the form's cursor whenever the mouse is outside `ClientRect` (`TCommonCustomForm.MouseMove`): the frame sets
  the cursor of the control under the mouse again after `WM_MOUSEMOVE` and on `WM_SETCURSOR` (I-beam over the search box
  verified: `shape IBEAM` in the geometry panel).
- `HTMAXBUTTON` gives Windows 11 **Snap Layouts**. Over the caption button codes the window manager keeps the mouse
  messages: the frame drives the buttons (`IFmrFrameButton.SetFrameButtonState`) from `WM_NCMOUSEMOVE`,
  `WM_NCLBUTTONDOWN/UP` and `WM_NCMOUSELEAVE` (`TrackMouseEvent(TME_LEAVE or TME_NONCLIENT)`); the default procedure is
  not called for these buttons (it would run its own modal loop and draw a classic button). Only codes coming from the
  host are taken; the system caption buttons of the NCStrip mode stay with the default procedure.
- `HTCAPTION` gives drag, Aero Snap, double click maximize/restore. Right click on the caption or the icon shows the
  system menu (`WM_NCRBUTTONUP` → `TrackPopupMenu` with the items enabled for the current state; Alt+Space works too).

### FMX popups from the non-client area

`TCustomPopupForm.CanShow`/`TimerProc` refuse to show (and close) a popup whose `PlacementTarget` does not intersect the
form's `ClientRect` (`HideWhenPlacementTargetInvisible`, default True) — true for every control in the strip. The host
sets `HideWhenPlacementTargetInvisible := False` on the `TPopup`s of its subtree, and — because pickers (the list of a
`TComboBox` is a `TPopupListPicker` attached to the combo box only inside `DropDown`) appear later — on every popup of
FMX's popup list whose placement target is in the host when a `TCustomPopupForm` handle is created
(`TAfterCreateFormHandle`, sent inside `TPopup.Popup` after the popup is registered and before the flag is copied to
the popup form).

### Hooking

The window is subclassed with `SetWindowSubclass`/`DefSubclassProc` (comctl32 loaded on demand: `Winapi.CommCtrl`'s
wrappers only work when comctl32 is already loaded, which is not the case in an FMX program; by name, or by ordinal
410/412/413 for comctl32 5.x). FMX's styled border (`Form.Border.Styling`) is switched off only when it is really
active. Layered (`Transparency = True`) forms are not hooked.

**When** (round 2: synchronous, so `Hooked` is reliable). FMX creates the form's window in
`TCommonCustomForm.InitializeNewForm`, before any component of the form exists, so the frame hooks as soon as it can:

- in its constructor (frame created in code, `TFmrForm` — whose frame is created in `InitializeNewForm` after the
  handle), or in `Loaded` (frame read from a form resource);
- synchronously in `TAfterCreateFormHandle` whenever the form's handle is (re)created (`BorderStyle`, `FormStyle`,
  `Transparency` changes) — round 1 did this only for a form that was already shown;
- `TFormBeforeShownMessage` remains as a safety net (a frame enabled while the form was loading);
- unhooked in `TBeforeDestroyFormHandle`, on `Enabled := False`, and in `WM_NCDESTROY` if the window is destroyed
  behind FMX's back.

Hooking that early exposed a round-1 bug: a strip repaint posted to the old window of a recreated handle never
arrived, the "repaint posted" flag stayed set and the strip was no longer repainted on invalidations (only on
`WM_NCPAINT`); `Attach` now clears it.

**Notification.** `TFmrFrameState` has a new field `Hooked`; `TFmrFormFrame.UpdateState` fills it from `Hooked`, and
every attach and detach sends a `TFmrFrameStateMessage` (and `OnStateChanged`): `Attach` ends with `FrameChanged`
→ `UpdateFrameState` (also when only `Hooked` changed), `Unhook` sends the state after `Detach`, `WM_NCDESTROY` sends
it after removing the subclass, and a `Hook` whose platform could not attach sends it with `Hooked = False`. Clients can
read `TFmrFrameStateMessage(M).State.Hooked` (or `Frame.Hooked`) in the handler; polling on idle is not needed. Probe
(NCProof geometry panel, `hook log`): `after CreateNew: Hooked=True; unhooked (not shown yet); hooked (not shown yet);
state messages: 9` — the window is hooked inside `CreateNew`, and `/topmost` (FormStyle change → new handle) unhooks
and re-hooks it before the form is shown.

**What the ribbon can simplify** (`FMR.Ribbon.pas`, not edited here): `TFmrRibbon.FrameStateHandler` only sets
`FFrameDirty`, and `TFmrRibbon.IdleHandler` compares `FFrame.Hooked`/`FFrame.Mode` with `FLastHooked`/`FLastMode`
(around lines 4392–4402 and 4468–4475). The handler can now use `State.Hooked`/`State.Mode` of the message directly
(the message is sent after the frame finished attaching or detaching); the idle comparison is only needed if the
ribbon wants to batch the work.

## The modes

### FullNC (default)

- **Real non-client**: caption row + tab row. `WM_NCCALCSIZE`: default calculation (sizing border on every side), then
  client top += strip height. Probe (150 %, CaptionHeight 64 dp): `non-client: left 10, top 106, right 10, bottom 10`
  = 10 px sizing border + 96 px strip.
- **Window style**: `WS_CAPTION` removed, `WS_THICKFRAME` kept (added for a `BorderStyle = Single` form, whose sizing
  codes are then turned into `HTBORDER`). DWM keeps rendering the frame: **Windows 11 shadow, rounded corners
  (`DWMWCP_ROUND`), 1 px border, dark border (`DWMWA_USE_IMMERSIVE_DARK_MODE`)**; `DWMWA_NCRENDERING_ENABLED = TRUE`.
- DWM paints the 10 px top sizing border above the strip in its caption color: the frame sets `DWMWA_CAPTION_COLOR`
  to the strip color (active/inactive), so the top looks like one piece.
- Without `WS_CAPTION` Windows maximizes a window over the whole monitor (taskbar covered): `WM_GETMINMAXINFO` puts it
  into the work area, beyond it by the frame thickness (measured: window `(-10,-10)-(3850,2098)`, frame bounds
  `(0,0)-(3840,2088)` = work area, client from y = 96). The frame thickness is taken from `AdjustWindowRectExForDpi`
  for the current style (it differs by 1 px with and without `WS_CAPTION`; `SM_CXSIZEFRAME + SM_CXPADDEDBORDER` gave
  12 instead of 10 at 150 %).
- Kept: Snap Layouts, Aero Snap/drag, double click maximize, system menu, taskbar minimize/restore. Lost: the
  maximize/restore **animations**, which Windows plays only for windows with `WS_CAPTION` (measured, see "Animations"
  below; `FmrWinFullNCStrategy := CaptionDuringAnimation` gets them back).
- `WM_NCPAINT`: only the strip is painted; the default procedure is not called (not needed without `WS_CAPTION`, DWM
  rendering stays on).

### NCStrip

- The system title bar stays (drawn by DWM: title, icon, system buttons, Snap Layouts of the system maximize button);
  below it a **real non-client strip** of `CaptionHeight`: `WM_NCCALCSIZE` default + strip height. Probe:
  `non-client: left 11, top 141` = 45 px system caption + 96 px strip.
- `WM_NCPAINT` is passed to the default procedure **unchanged**, then the strip is painted (see the experiments: any
  other way switches the DWM frame off). `WM_NCACTIVATE` goes to the default procedure (the system caption shows the
  active state).
- The demo hides its own caption buttons in this mode.

### Dwm

- No top non-client area (`non-client: top 0`); the host is an ordinary `MostTop` control painted by FMX in the client
  area; maximized: client top = window top + frame thickness. Top edge resizing is done by the hit test (top 10 px of
  the host → `HTTOP`/corners).
- Without a backdrop `WS_CAPTION` is kept (animations stay) and the frame is not extended into the client area (DWM
  draws no caption buttons there).
- With `Backdrop` (Mica, Acrylic, Tabbed; `DWMWA_SYSTEMBACKDROP_TYPE`, Windows 11 22H2+): the frame is extended over
  the whole window (`DwmExtendFrameIntoClientArea(-1)`), the form's fill is made transparent (Solid, alpha 0: FMX then
  skips the style background; restored when the backdrop is switched off) and the host is transparent; everything FMX
  leaves transparent shows the material. With `WS_CAPTION` DWM draws its own caption buttons over the extended frame
  (seen: doubled glyphs, `DwmDefWindowProc` answered `HTCLOSE` at its own button), so in this case `WS_CAPTION` is
  removed as in FullNC.
- `DwmDefWindowProc` is called first in `WM_NCHITTEST` in this mode.

## Experiments on Windows 11 (25H2, build 26200, 3840 × 2160 at 150 %)

| Experiment | Result |
|---|---|
| FullNC keeping `WS_CAPTION`, top non-client = strip, `WM_NCPAINT` passed to the default procedure | **DWM draws its own caption (icon, title, min/max/close, 45 px) over the top of the strip**: the caption row is hidden, the tab row shows below it. Kept as `FmrWinFullNCStrategy := KeepCaptionStyle` (demo: `/strategy=keepcaption`) for comparison |
| Same, `WM_NCPAINT` handled without calling the default procedure (or calling it with a region that excludes the strip) | `DWMWA_NCRENDERING_ENABLED` becomes **FALSE**: Windows falls back to the "basic" frame (classic caption buttons, no shadow, square corners) — measured for NCStrip and KeepCaptionStyle; passing the original region keeps it TRUE |
| FullNC without `WS_CAPTION` (`WS_THICKFRAME` only), strip below the default top border, no default `WM_NCPAINT` | **Works**: DWM renders border, shadow and rounded corners, our GDI painting of the strip is visible (like a menu bar area), `DWMWA_NCRENDERING_ENABLED = TRUE` |
| Dwm + Mica with `WS_CAPTION` and the frame extended over the window | DWM draws its caption buttons on top of FMX's |
| Region + own shadow windows (`FMR.Frame.Shadow.Win`) | **Not needed** on Windows 11: the DWM frame is kept in every mode, so the fallback was not written |

DWM NC rendering per mode (attribute read by the demo): `/noframe` 1, FullNC 1, NCStrip 1, Dwm 1, KeepCaptionStyle 1
(after the `WM_NCPAINT` fix; NCStrip and KeepCaptionStyle were 0 before it).

### Round 2: can `WS_CAPTION` stay while the strip is real non-client?

Question: keep `WS_CAPTION | WS_THICKFRAME` (as Chromium and Windows Terminal do, for the system animations) but let
`WM_NCCALCSIZE` reserve the top sizing border + our strip as non-client, without DWM painting its caption over it.
(Chromium/Terminal make the caption area *client* area and remove only the caption height; FullNC must keep the strip
non-client, so this is a different situation.) All variants are selectable with `FmrWinFullNCStrategy` (demo
`/strategy=…`); with `WS_CAPTION` the geometry is now window top + top sizing border + strip, the same as without it
(probe: `non-client: left 11, top 107` = 11 px border + 96 px strip; style `0x16CF0000`).

| Variant | Result |
|---|---|
| `KeepCaptionStyle` (`/strategy=keepcaption`): `WS_CAPTION`, top border kept, strip below it | DWM still draws its caption bar (icon, title "FMR NCProof", min/max/close) over the top ~45 px of the strip; only the tab row is visible. Keeping the top border changes nothing: DWM paints its caption into whatever top non-client area a captioned window has |
| `KeepCaptionAllowNCPaint` (`/strategy=allowncpaint`): + `DWMWA_ALLOW_NCPAINT = TRUE` | Our strip is **visible**, no DWM caption, rounded corners kept, maximize/restore **animated**. But the whole non-client area becomes GDI-visible: the normally invisible ~10 px resize borders are painted by the default `WM_NCPAINT` and show as a thick white frame around the window. Not usable without painting the whole frame ourselves (and the shadow would then start outside that band) |
| `KeepCaptionNoDwmFrame` (`/strategy=nodwmframe`): + `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED` | Strip visible, animations kept, but the frame is the classic "basic" one painted by the default procedure: light blue 8 px border, square corners, **no shadow** (frame bounds = window rect). Would need the shadow-window fallback |
| `WM_NCACTIVATE` without the default procedure, `DwmExtendFrameIntoClientArea` margins | Not tried separately: the FullNC frame already answers `WM_NCACTIVATE` with `lParam = -1` (no default caption repaint) and the caption is still drawn by DWM in `KeepCaptionStyle`; the margins only extend the DWM frame into the *client* area, the opposite of what is needed |
| `CaptionDuringAnimation` (`/strategy=animcaption`): FullNC without `WS_CAPTION`, but `WM_SYSCOMMAND` `SC_MINIMIZE/SC_MAXIMIZE/SC_RESTORE` runs with `WS_CAPTION` put back for the duration of the default processing | **Works**: maximize and restore are animated, the animation frames show our strip (DWM cross-fades snapshots; no DWM caption seen), the final state is the normal FullNC one. Geometry is kept the no-caption one during the command (`AdjustClientRect`, `FrameThickness`); the system maximizes a captioned window with its own 11 px frame (window `(-11,-11)`), so a maximized client rectangle is clamped to the monitor work area (client `(0,96) 3840×1992`, same as the default). Restore lands 1 px off the original position once (no accumulation over cycles). Commands that do not go through `WM_SYSCOMMAND` (Win+Up/Down, `ShowWindow` from code, `WindowState :=`) are not animated |

**Recommendation**: keep `NoCaptionStyle` as the default; `CaptionDuringAnimation` is a working opt-in
(`FmrWinFullNCStrategy := TFmrWinFullNCStrategy.CaptionDuringAnimation` before the form is created) and a candidate for
the default after testing on Windows 10 and with several monitors. A real-NC strip with `WS_CAPTION` permanently kept
is not possible without losing the DWM frame look (AllowNCPaint, NoDwmFrame) or being covered (KeepCaption).

### Animations (measured)

NCProof `/animtest` paints the client area magenta; a script posts `WM_SYSCOMMAND` and counts magenta pixels on the
screen every ~65 ms (`CopyFromScreen`). Numbers: magenta samples per frame (window ≈ 47 000, maximized ≈ 209 000).

| Window | Maximize | Restore (from maximized) |
|---|---|---|
| `/noframe` (FMX window with system caption) | 45 694 → 59 163 → 167 668 → 205 633 (animated) | 205 631 → 199 107 → 74 470 → 46 104 (animated) |
| FullNC `NoCaptionStyle` (default) | 47 067 → 209 531 (jump) | 209 526 → 47 574 (jump) |
| `KeepCaptionStyle` / `AllowNCPaint` / `NoDwmFrame` | animated (61 293 → 153 042 → 209 541 …) | — |
| FullNC `CaptionDuringAnimation` | 47 293 → 60 242 → 172 422 → 210 199 (animated) | 151 123 → 150 249 → 185 527 → 48 605 (animated) |

Minimize could not be compared: FMX minimizes its main form through `TPlatformWin.MinimizeApp`, which switches the
system animation off (`SPI_SETANIMATION`) while it minimizes the application window, so no minimize animation was seen
for the plain FMX window either.

## IME

FMX positions the IME windows itself (`TImmManager.UpdateIMEWindowPosition`, called on `WM_IME_STARTCOMPOSITION`,
`WM_IME_COMPOSITION`, `IMN_OPENCANDIDATE` and on caret moves while composing): `ImmSetCandidateWindow` with
`CFS_POINT` = `TextInput.GetTargetClausePointF` (a `LocalToAbsolute` point = client coordinates of the form) and
`CFS_EXCLUDE` = `Form.ScreenToClient(Focused.LocalToScreen(selection rect))`, both in client pixels. For a `TEdit` in
the strip both are client points with negative Y, which the IME converts with `ClientToScreen` — the right place. The
composition string is drawn inline by the edit (FMX hides the IME's composition window), i.e. into the strip bitmap.

Checked: the NCProof geometry panel computes both values exactly like FMX for the focused control and converts them
to screen pixels. Search box focused in FullNC (150 %): `IME clause pt (3186,70)`, `IME exclude (3186,67)-(3187,91)`
(the caret line), search box `(3126,61)-(3486,97)` — inside the edit, on the caret. No fix was needed. Not done: a
real composition. The Microsoft Japanese IME is installed but not in the user's input languages; activating its
profile for the process (`ITfInputProcessorProfileMgr.ActivateProfile(TF_IPPMF_FORPROCESS)`) returned `S_OK` but the
keystrokes stayed in the user's layout, and activating it with `TF_IPPMF_ENABLEPROFILE` changes the user's input
settings (`HKCU\Software\Microsoft\CTF\TIP\…`). That was reverted and the activation code was removed from the demo.
`LocalToAbsolute` returns bitmap coordinates during `PaintBuffer` (see "Coordinates while painting"); FMX's IME code
does not run while the strip is painted.

## Per-monitor DPI changes

Code path of `WM_DPICHANGED` (reviewed and simulated; one monitor only):

1. The subclass passes the message on first: FMX's `TWinWindowHandle.WMDpiChanged` sets the new scale
   (`Form.Handle.Scale`), applies the **suggested rectangle** (`WndBounds := ScaledRect^` → `SetWindowPos`), recreates
   the canvas and sends `TScaleChangedMessage`. The `WM_NCCALCSIZE`/`WM_SIZE` caused by the new bounds already see the
   new scale: the strip height is `CaptionHeight` (dp) × new scale, the sizing border comes from
   `AdjustWindowRectExForDpi(…, GetDpiForWindow)` (the window's DPI is already the new one when the message arrives),
   and `WM_SIZE` places the host with the new client width.
2. Then `FrameChanged`: style, DWM attributes (caption color, corners), `SWP_FRAMECHANGED` (non-client recalculated
   once more), `UpdateLayout`, repaint; `PaintBuffer` resizes the bitmap and sets `BitmapScale` to the new scale.

Simulation: NCProof's button "Simulate WM_DPICHANGED (120 dpi)" (`/simdpi` presses it after start) sends
`WM_DPICHANGED` with 120 dpi and the window rectangle scaled by 120/144, as Windows does when a window moves to a
125 % monitor; pressing it again goes back to 144 dpi. Result at 120 dpi: `dpi / scale: 144 / 1,25` (the window's real
DPI stays 144, FMX uses 1.25), window `1475×951` (the suggested size), `non-client top 90` = 10 px border + 64 dp × 1.25,
host `1164 × 64 dp`, everything drawn at the smaller scale, hit tests right (`HTSYSMENU`, `HTCAPTION`, `HTCLIENT` at
the expected points). Back at 144 dpi: `top 106`, scale 1.50, window `1769×1141`. In the simulation the sizing border
stays 10 px because `GetDpiForWindow` still returns 144; on a real 120 dpi monitor it is 8 px.

## Design time

`TFmrFormFrame` at design time (`csDesigning`) never hooks the window (`CanHook`), creates the host as an ordinary
`MostTop` control of the form with the height `CaptionHeight`, `Locked = True` (the designer does not move or resize
it; it is owned by the frame, not by the form, so the designer does not select it) and `Stored = False` (not written
to the form file). So the host already is the design-time representation of the caption area: whatever is put into it
is shown at the top of the form designer, where the Dwm mode puts it at run time. The ribbon moves its caption row and
tab row into `Frame.Host` whenever it has a frame (`TFmrRibbon.PlaceBars`), also at design time, so a ribbon on a form
with a frame shows both rows at the top of the designer (inside the host) and its body below; without a frame the
rows stay inside the ribbon (its fallback) — `TFmrFormFrame` does not change that. `Hooked` is False at design time
and no `TFmrFrameStateMessage` is sent.

Checked with a simulation (a test program, not in the repository, that creates the frame and the ribbon with an owner
in `csDesigning` state, as the IDE does): `frame designing=True hooked=False`, host `(0,0 884×62)` on the form with the
ribbon's `TFmrRibbonCaptionBar (0,0 884×32)` and `TFmrRibbonTabBar (0,32 884×30)`, ribbon body at `y = 62`; the
screenshot shows the system caption of the (unhooked) window, then the ribbon's caption row (QAT, title, no window
buttons), tab row and body. The same program at run time: `hooked=True`, host `(0,-62 886×62)` in the non-client
area, ribbon at `y = 0`.

Limits: the host's children are not designable (they are not owned by the form, and the host is not streamed); making
caption content designable would need streaming the host's children through the frame (e.g. a `TFmrFrameHost`
published as a sub-component with `GetChildren`/`SetChildOrder`), which conflicts with the ribbon creating its rows
itself. Proposal: keep the host non-designable; designers of caption content (the ribbon's design-time editor) work on
their own components, which the host only displays.

## Windows 10 notes (from documentation and experience, not tested here)

- `DWMWA_USE_IMMERSIVE_DARK_MODE` is attribute 20 from build 18985 and 19 before (1809–1909): the frame tries 20,
  then 19.
- `DWMWA_WINDOW_CORNER_PREFERENCE`, `DWMWA_CAPTION_COLOR` and `DWMWA_SYSTEMBACKDROP_TYPE` do not exist (the calls fail
  and are ignored): square corners, no Mica/Acrylic, and the color of the top sizing border above the FullNC strip
  cannot be set — Windows 10 draws the top border of a `WS_THICKFRAME` window in its own frame color (to be checked on
  a Windows 10 machine). If it looks wrong, a Windows 10 path can put the strip directly at the top of the window and
  treat its top pixels as `HTTOP` (as the Dwm mode does).
- `DWMWA_SYSTEMBACKDROP_TYPE` needs Windows 11 22H2 (22621); 21H2 has only the undocumented Mica attribute 1029.
- Snap Layouts do not exist; `HTMAXBUTTON` just behaves as the maximize button.
- Windows 10 does not draw the top border of a window whose top non-client area is removed (Dwm mode): a 1 px line
  would have to be painted by the application.

## Test results (NCProof, Win64, Windows 11, 150 %)

Run with `.\tools\shot.ps1` (see "Tools" below); window at `/pos=1300,30`, coordinates relative to the
window (physical pixels).

```
### FullNC (default)
window rect  : (1950,45)-(3721,1184)  1771x1139
frame bounds : (1958,45)-(3713,1176)
client rect  : origin (1960,151) size 1751x1023
non-client   : left 10, top 106, right 10, bottom 10
style        : 0x160F0000  exstyle 0x00000108
hit-test (40,34) : HTSYSMENU        app icon (IFmrFrameHitTest -> SysMenu)
hit-test (95,34) : HTCLIENT         QAT button (TSpeedButton)
hit-test (330,34) : HTCLIENT        TComboBox
hit-test (800,34) : HTCAPTION       title (TLabel, HitTest = False)
hit-test (1350,34) : HTCLIENT       TEdit "Search..."
hit-test (1590,34) : HTMINBUTTON
hit-test (1657,34) : HTMAXBUTTON
hit-test (1725,34) : HTCLOSE
hit-test (60,80) : HTCLIENT         tab "File" (tab row: tab -> Client)
hit-test (1200,80) : HTCAPTION      gap of the tab row (-> Caption)
hit-test (885,3) : HTTOP
hit-test (3,3) : HTTOPLEFT
hit-test (5,500) : HTLEFT
hit-test (885,1135) : HTBOTTOM
hit-test (800,400) : HTCLIENT       client area

### NCStrip
client rect  : origin (1961,186) size 1749x987
non-client   : left 11, top 141, right 11, bottom 11
style        : 0x16CF0000
hit-test (200,20) : HTCAPTION       system title bar
hit-test (1700,20) : HTMAXBUTTON    system maximize button
hit-test (40,70) : HTSYSMENU        app icon in the strip
hit-test (800,70) : HTCAPTION       title in the strip
hit-test (60,115) : HTCLIENT        tab in the strip
hit-test (885,3) : HTTOP

### Dwm
client rect  : origin (1961,45) size 1749x1128
non-client   : left 11, top 0, right 11, bottom 11
style        : 0x16CF0000
hit-test (40,24) : HTSYSMENU   hit-test (800,24) : HTCAPTION   hit-test (1350,24) : HTCLIENT
hit-test (1590,24) : HTMINBUTTON   hit-test (1657,24) : HTMAXBUTTON   hit-test (1725,24) : HTCLOSE
hit-test (60,70) : HTCLIENT   hit-test (1200,70) : HTCAPTION   hit-test (885,3) : HTTOP   hit-test (3,3) : HTTOPLEFT

### Dwm + Mica
non-client   : left 10, top 0, right 10, bottom 10
style        : 0x160F0000   (WS_CAPTION removed)
hit-test (800,24) : HTCAPTION   hit-test (1725,24) : HTCLOSE   hit-test (885,3) : HTTOP
```

Checked on screenshots (`shots\`, not committed):

| What | Evidence |
|---|---|
| Caption row and tab row painted in the non-client area, no garbage, Windows 11 corners and shadow | FullNC screenshot; frame bounds inset only on the sides and the bottom |
| Hover of a QAT `TSpeedButton` in the non-client area | hot background visible |
| Typing in the non-client `TEdit` | `search text: "Hello NC"`, `focus in NC: YES - inside the non-client host`, caret visible |
| Selection and clipboard | Ctrl+A selection painted in the strip; Ctrl+C put "Hello NC" on the clipboard (`Get-Clipboard`); Ctrl+V into the client `TEdit` pasted it |
| `TComboBox` in the non-client area | the list opens right below the combo box; clicking "Notes.txt" selected it |
| Hint of a non-client control | "Save" hint below the QAT button |
| Caption buttons | close hot = red `#C42B1C` with white glyph; maximize hot + **Windows 11 Snap Layouts flyout**; restore glyph when maximized; dimmed glyphs when inactive |
| Maximize by double click on the caption, restore by double click | window `(-10,-10)-(3850,2098)` (work area), then back to `(1949,45)-(3721,1184)` |
| Maximize, minimize with the FMX caption buttons | `WS_MAXIMIZE` / `WS_MINIMIZE` in the style; strip repainted after `ShowWindow(SW_RESTORE)` |
| System menu | right click on the caption (at the cursor) and click on the app icon |
| Mode switch at run time FullNC → NCStrip → Dwm → FullNC | each mode correct, client controls realigned, no stale gap |
| CaptionHeight 64 → 32 at run time | `non-client top 58` |
| Light/dark | dark strip, white glyphs, dark DWM border, top border in the strip color |
| Resize by the right edge | window 1304 px wide, strip re-laid out |
| `BorderStyle = Single` (`/fixed`) | DWM frame kept, edges answer `HTBORDER` |
| Win32 build; FastCanvas build (`TFastCanvas`, FullNC and Dwm + Mica) | same results |

## Limitations and open issues

- **While an FMX drop-down of a strip control is open** (`TComboEdit`, `TComboTrackBar`, a `TPopup`), the strip is
  painted with `TCanvas.Offset` (see "Coordinates while painting"): during that time rotated/scaled children and
  drawing after `RestoreState` inside a `Paint` are shifted as in round 1.
- **Design time**: the host shows caption content at the top of the form designer but its children are not designable
  (see "Design time").
- **IME**: candidate/exclude positions verified by computation, no real composition (see "IME").
- **DPI change between monitors**: simulated with `WM_DPICHANGED` on one monitor (see "Per-monitor DPI changes").
- **Auto-hide taskbar**: a maximized window leaves 2 px at the taskbar's edge (`ABM_GETAUTOHIDEBAREX`) — not tested.
- **Windows 10**: not tested (see the notes above).
- Maximize/restore animations are missing in FullNC with the default strategy and in Dwm with a backdrop (no
  `WS_CAPTION`); `CaptionDuringAnimation` restores them for FullNC (opt-in).
- Controls in the strip must have `HitTest = False` (or implement `IFmrFrameHitTest`) where the window should be
  dragged: a background control with `HitTest = True` makes its whole area `HTCLIENT` (contract rule).
- After minimize/restore at 150 % FMX may change the window height by 1 px (`TWinWindowHandle.WMWindowPosChanging`
  rounds the size with the border size of the iconic window); it happens without the frame too (`/noframe`).
- `TFmrFrameHost` sets `HideWhenPlacementTargetInvisible := False` on popups of its controls and does not restore it.
- The strip is repainted completely on every invalidation (it is small; partial repaint with clip rectangles is
  possible later).

## Tools and how to run

- Build: `.\build.ps1 -Project Demos\NCProof\NCProof.dpr` (`-Platform Win32`). FastCanvas:
  `.\build.ps1 -Project Demos\NCProof\NCProof.dpr -Define FMR_FASTCANVAS -SearchPath f:\Projects\FmxFastCanvas_GitHub\src\Canvas,f:\Projects\FmxFastCanvas_GitHub\third_party\delphidx12\src`.
- Command line of NCProof: `/mode=dwm|fullnc|ncstrip`, `/dark`, `/backdrop=mica|acrylic|tabbed`, `/notabs`,
  `/maximized`, `/pos=X,Y` (dp), `/topmost`, `/fixed` (BorderStyle Single), `/noframe` (frame disabled),
  `/strategy=keepcaption|allowncpaint|nodwmframe|animcaption` (FullNC strategies, read before the form is created),
  `/animtest` (magenta client area for the animation measurements), `/simdpi` (simulated `WM_DPICHANGED` 1.5 s after
  the start).
- Round 2 additions to the demo: a `TComboEdit` ("100%") and a rotated `TRectangle` in the caption row, the app icon
  painted with `SaveState`/`RestoreState`, the "Simulate WM_DPICHANGED" button, and the geometry lines `IME clause pt`,
  `IME exclude`, `IME candidate` (what FMX last passed to `ImmSetCandidateWindow`, only set while composing) and
  `hook log` (Hooked after `CreateNew`, every hook/unhook from `OnStateChanged`, number of `TFmrFrameStateMessage`s).
- The geometry panel shows mode, canvas class, window/client rectangles, non-client thickness, DPI, FMX client size,
  style, `DWMWA_NCRENDERING_ENABLED`, cursor position and shape, the hit-test code under the cursor, host bounds and
  scene, the focused control and whether it is in the non-client host, the search text, the selected tab and the last
  action (exceptions are shown there too).
- `tools\shot.ps1` (merged from the demo's copy): (1) `FindMain` also accepts windows owned
  by the FMX application window (`TFMAppClass`): FMX main forms are owned by it, so `tools\shot.ps1` reports "Main
  window not found" for every FMX program. (2) Action `ctrl:K` (Ctrl+K with `keybd_event`): `SendKeys` `^a`/`^c` do not
  reach FMX (also in a client-area `TEdit`).
- `tools\crop.ps1`: crops and zooms a screenshot region to inspect pixels.
