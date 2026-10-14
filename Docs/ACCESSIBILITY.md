# FMR Ribbon - accessibility (UI Automation)

FireMonkey has no UI Automation support. Screen readers, Windows Voice Access, UI test tools and Accessibility Insights see an FMX form as one opaque window. `FMR.Ribbon.UIA.Win` adds a server-side UIA provider for the ribbon, so its tabs, groups and commands become real automation elements.

## Use

```pascal
uses FMR.Ribbon.UIA.Win;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FmrInstallRibbonAutomation(Ribbon1);   // Windows; no-op on other platforms
end;
```

- You can call it before the form has a window; it attaches on the first idle.
- `FmrUninstallRibbonAutomation(Ribbon1)` removes the provider.
- Destroying the ribbon or the window detaches it automatically.

The unit compiles on every platform, but outside Windows both procedures do nothing.

## Design

- **Hooking the window.** The form window is subclassed with `SetWindowSubclass`. comctl32 is loaded on demand: FMX programs do not load it, and version 5 exports these functions by ordinal.
- **The root.** `WM_GETOBJECT` with `UiaRootObjectId` (-25) returns a fragment root for the window, through `UiaReturnRawElementProvider`.
  - The root names the window's HWND provider as its host (`UiaHostProviderFromHwnd`).
  - The window keeps its own name, bounds and frame properties.
  - The root adds the ribbon subtree.
- **The node source.** Elements come from `TFmrRibbon.AccessibilityNodes`, a flat snapshot (`TFmrAccNode`). Each node has:
  - role, name, `AutomationId`, help text, access key;
  - parent index, screen bounds in dp;
  - element/data objects;
  - enabled, selected and checked state;
  - value and read-only flag for editors.

  The provider caches the snapshot until `AccessibilityVersion` changes (the ribbon rebuilt or re-arranged), or for at most 250 ms.
- **Identity.**
  - A provider is identified by its ribbon element: view, tab element, system button.
  - Containers are identified by role and data: QAT, tab list, lower ribbon, groups.
  - A provider whose element has gone (for example after a tab switch) answers `UIA_E_ELEMENTNOTAVAILABLE`.
  - Runtime ids are `[UiaAppendRuntimeId, role, pointer]`.
- **Coordinates.** dp bounds are multiplied by the form's scale. `ElementProviderFromPoint` returns the smallest node containing the point.
- **Threading.** `ProviderOptions_ServerSideProvider | ProviderOptions_UseComThreading`: UIA calls the providers on the UI thread.
  - `Invoke`, `Select` and `Toggle` run the command through `TThread.ForceQueue`, so a command that opens a modal dialog or a menu never blocks the client.
  - `SetValue` is synchronous, so clients can read the new value straight back.
- **Actions.** They go through `TFmrRibbon.AccessibilityInvoke(Element)`:
  - click a button;
  - select a tab (it opens the minimized / auto-hidden body when needed);
  - open a drop-down, a collapsed group or the application menu;
  - focus an editor.

  Values go through `AccessibilitySetValue(Element, Text)`:
  - text of edits and combos (a non-editable combo accepts only one of its items);
  - numbers of spin boxes and track bars;
  - the search box.

  Both methods check that the element still exists.

## Tree

```
Window "Document1 - ..."                       (HWND provider + our fragment root, FrameworkId FMX)
  Pane "Ribbon"            id=<ribbon name>   class TFmrRibbon
    ToolBar "Quick Access Toolbar"  id=QuickAccessToolbar
      Button "Save"  id=btnSave ...           Button "Customize Quick Access Toolbar" id=QATCustomize
    Edit "Tell me what you want to do"        id=SearchBox            (Value)
    Button "Ribbon Display Options"           id=DisplayOptions
    Tab "Ribbon Tabs"                         id=TabList
      Button "File"                           id=ApplicationButton
      TabItem "Home"                          id=tabHome              (SelectionItem)
      ...                                     Button "Collapse the Ribbon" id=CollapseRibbon
    Pane "Lower Ribbon"                       id=LowerRibbon
      Group "Font"                            id=grpFont
        ComboBox "Font"                       id=cbFontName           (Value)
        ComboBox "Font Size"                  id=cbFontSize           (Value)
        Button "Bold"                         id=btnBold              (Invoke, Toggle when checked)
        SplitButton "Font Color"              id=clrFont              (Invoke)
      Group "Editing"
        Edit "Go to" id=edGoTo (Value)        Spinner "Copies" id=spCopies (Value)
      Button "Clipboard"  (collapsed group)   Button "Switch to Simplified Ribbon" id=DisplayMode
```

| Role (`TFmrAccRole`) | Control type | Patterns |
|---|---|---|
| QuickAccessToolbar | ToolBar | - |
| TabList | Tab | - |
| Tab | TabItem | SelectionItem (Select = activate) |
| ApplicationButton, SystemButton, CollapsedGroup, DropDownButton | Button | Invoke |
| Button | Button | Invoke; Toggle when checked |
| SplitButton | SplitButton | Invoke (main part) |
| CheckBox | CheckBox | Toggle |
| Editor | Edit | Value |
| ComboBox / Spinner / Slider | ComboBox / Spinner / Slider | Value |
| LowerRibbon | Pane | - |
| Group | Group | - |

Properties:

- **Name**: the caption without `&`. Glyph-only system buttons use their screen tip header ("Collapse the Ribbon", "Ribbon Display Options", "More Options"...).
- **AutomationId**: the item, tab or group `Name`. Built-in parts use fixed ids: `QATCustomize`, `DisplayOptions`, `CollapseRibbon`, `SimplifiedOverflow`, `DisplayMode`, `ApplicationButton`, `<group>.Launcher`.
- **HelpText**: the screen tip description.
- **AccessKey**: the key tip.
- **ClassName**: the element's class.
- **FrameworkId**: `FMX`.
- **IsEnabled**.
- **IsKeyboardFocusable** / **HasKeyboardFocus**: always False (see limitations).

In simplified mode, groups have no box. Their bounds are the union of their commands. In RTL, bounds are the mirrored screen rectangles.

## Using the snapshot without UIA

`AccessibilityNodes`, `AccessibilityInvoke` and `AccessibilitySetValue` are plain public methods, so other code can use them too. For example, the Customize demo's `/dropdown=<id>` "clicks" any element by its automation id:

```pascal
for N in Ribbon1.AccessibilityNodes do
  if SameText(N.AutomationId, 'btnPaste') then
    Ribbon1.AccessibilityInvoke(N.Element);
```

## Verification

`Demos\Customize\uia-test.ps1` (Windows PowerShell 5.1, managed `System.Windows.Automation` client):

1. Starts `CustomizeDemo.exe` and finds the form window. Note that `Process.MainWindowHandle` can be FMX's hidden `TFMAppClass` window.
2. Prints the tree.
3. Checks:
   - the ribbon pane, tab list, tabs, selection state;
   - tab bounds inside the window;
   - `ElementFromPoint` on a tab;
   - the parent group of Bold;
   - patterns;
   - font size ComboBox value "11", then `SetValue("14")` read back;
   - the Spinner, the search box value;
   - `SelectionItem.Select` on Insert, after which Insert commands appear and Home commands are gone;
   - `Invoke` on a command;
   - the display options button name;
   - back to Home.

```
powershell -ExecutionPolicy Bypass -File Demos\Customize\uia-test.ps1
powershell -ExecutionPolicy Bypass -File Demos\Customize\uia-test.ps1 -Depth 5 -Arguments "/simplified /rtl"
```

All checks pass, both in the default layout and with `/simplified /rtl`.

## Limitations / not implemented

- **No focus tracking and no UIA events.** None of `FocusChanged`, `StructureChanged`, `PropertyChanged`, `Invoked` is raised.
  - Clients that poll (test tools, Inspect, Accessibility Insights) work.
  - Narrator and NVDA can read and invoke the elements by navigation, but do not announce key tip or keyboard navigation inside the ribbon.
  - Neither screen reader was tested; only the managed UIA client was.
- **Not exposed**: popups (menus, galleries, group popups, the auto-hide overlay), the backstage view and the customization dialog.
- **Patterns**:
  - Drop-downs offer `Invoke` (opens them), not `ExpandCollapse`.
  - Spin boxes and track bars offer `Value` (text), not `RangeValue`.
- **One scale.** Bounds use the form's scale and assume the logical screen origin is the physical one. Mixed-DPI multi-monitor setups may show offset rectangles.
- **Windows only.** No NSAccessibility on macOS.
