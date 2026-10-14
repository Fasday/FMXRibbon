{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  UI Automation provider of the ribbon (Windows)       }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.UIA.Win;

/// FMX has no UI Automation support: screen readers and test tools see an FMX form as one opaque window. This unit
/// gives the ribbon a server-side UIA provider (see Docs\ACCESSIBILITY.md):
///  - the form window is subclassed (SetWindowSubclass, comctl32 loaded on demand like FMR.Frame.Win); WM_GETOBJECT
///    with UiaRootObjectId returns a fragment root for the window (hosted by the HWND provider, so the window keeps
///    its name and frame properties);
///  - the root has one child "Ribbon" (Pane) whose children follow TFmrRibbon.AccessibilityNodes: the quick access
///    toolbar (ToolBar), the tab row (Tab with TabItem children, SelectionItem pattern), the lower ribbon (Pane) with
///    its groups (Group) and commands (Button, SplitButton, CheckBox, Edit; Invoke, Toggle);
///  - elements are identified by their ribbon element (or role and data for containers); a snapshot of the nodes is
///    taken on demand and cached until the ribbon rearranges; providers of elements that went away answer
///    UIA_E_ELEMENTNOTAVAILABLE;
///  - ProviderOptions_UseComThreading: UIA calls the providers on the UI thread (the thread that created them);
///    Invoke runs the command asynchronously (TThread.ForceQueue), so modal dialogs opened by a command do not block
///    the client.
/// On other platforms the unit compiles to the two no-op procedures.

interface

uses
  FMR.Ribbon;

/// <summary>Exposes the ribbon to UI Automation clients through the window of its form. Call after the form has a
/// window (e.g. in OnShow or later; earlier calls are retried on the first idle). Windows only.</summary>
procedure FmrInstallRibbonAutomation(const ARibbon: TFmrRibbon);
procedure FmrUninstallRibbonAutomation(const ARibbon: TFmrRibbon);

implementation

{$IFDEF MSWINDOWS}
uses
  System.SysUtils, System.Classes, System.Types, System.Variants, System.Generics.Collections, System.Messaging,
  Winapi.Windows, Winapi.Messages, Winapi.ActiveX, Winapi.UIAutomation, FMX.Types, FMX.Forms,
  FMX.Platform.Win, System.Math, FMR.Ribbon.Strings;

type
  TSubclassProc = function(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM; uIdSubclass: UINT_PTR;
    dwRefData: DWORD_PTR): LRESULT; stdcall;
  TSetWindowSubclass = function(hWnd: HWND; pfnSubclass: TSubclassProc; uIdSubclass: UINT_PTR;
    dwRefData: DWORD_PTR): BOOL; stdcall;
  TRemoveWindowSubclass = function(hWnd: HWND; pfnSubclass: TSubclassProc; uIdSubclass: UINT_PTR): BOOL; stdcall;
  TDefSubclassProc = function(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

const
  SubclassId = $464D5255; // 'FMRU'
  E_ELEMENTNOTENABLED = HRESULT($80040200);
  E_ELEMENTNOTAVAILABLE = HRESULT($80040201);
  E_INVALIDOPERATION = HRESULT($80131509);
  RoleRibbon = -1;
  RoleRoot = -2;
  RoleElement = 1000;
  EditorRoles = [TFmrAccRole.Editor, TFmrAccRole.ComboBox, TFmrAccRole.Spinner, TFmrAccRole.Slider];

var
  ComCtl: HMODULE = 0;
  _SetWindowSubclass: TSetWindowSubclass = nil;
  _RemoveWindowSubclass: TRemoveWindowSubclass = nil;
  _DefSubclassProc: TDefSubclassProc = nil;

function LoadSubclassApi: Boolean;

  function GetProc(const AName: string; const AOrdinal: Word): Pointer;
  begin
    Result := GetProcAddress(ComCtl, PChar(AName));
    if Result = nil then
      Result := GetProcAddress(ComCtl, PChar(NativeUInt(AOrdinal)));
  end;

begin
  // comctl32 is not loaded in an FMX program and version 5 exports these functions by ordinal only.
  if not Assigned(_DefSubclassProc) then
  begin
    if ComCtl = 0 then
      ComCtl := LoadLibrary('comctl32.dll');
    if ComCtl <> 0 then
    begin
      @_SetWindowSubclass := GetProc('SetWindowSubclass', 410);
      @_RemoveWindowSubclass := GetProc('RemoveWindowSubclass', 412);
      @_DefSubclassProc := GetProc('DefSubclassProc', 413);
    end;
  end;
  Result := Assigned(_SetWindowSubclass) and Assigned(_RemoveWindowSubclass) and Assigned(_DefSubclassProc);
end;

type
  /// Key of a node: the element for elements; role (and data) for containers.
  TNodeKey = record
    Role: Integer;
    Ptr: Pointer;
    class function Make(const ARole: Integer; const APtr: Pointer): TNodeKey; static;
    function SameAs(const AOther: TNodeKey): Boolean;
  end;

  TUiaHook = class;

  /// Shared by the providers of one ribbon; outlives the hook while clients hold providers.
  TUiaContext = class(TInterfacedObject)
  private
    FRibbon: TFmrRibbon;
    FWnd: HWND;
    FNodes: TArray<TFmrAccNode>;
    FVersion: Integer;
    FTick: Cardinal;
    FRoot: IRawElementProviderSimple;
  public
    function Alive: Boolean;
    function Nodes: TArray<TFmrAccNode>;
    function KeyOf(const ANode: TFmrAccNode): TNodeKey;
    function Find(const AKey: TNodeKey; out AIndex: Integer): Boolean;
    function Scale: Single;
    function Provider(const AKey: TNodeKey): IRawElementProviderSimple;
  end;

  TUiaElement = class(TInterfacedObject, IRawElementProviderSimple, IRawElementProviderFragment, IInvokeProvider,
    ISelectionItemProvider, IToggleProvider, IValueProvider)
  private
    FContext: TUiaContext;
    FContextRef: IInterface;
    FKey: TNodeKey;
    function Node(out ANode: TFmrAccNode; out AIndex: Integer): Boolean;
    function Navigable(const ADirection: NavigateDirection): TNodeKey;
  protected
    { IRawElementProviderSimple }
    function get_ProviderOptions(out pRetVal: ProviderOptions): HRESULT; stdcall;
    function GetPatternProvider(patternId: UIA_PATTERN_ID; out pRetVal: IUnknown): HRESULT; stdcall;
    function GetPropertyValue(propertyId: UIA_PROPERTY_ID; out pRetVal: OleVariant): HRESULT; stdcall;
    function get_HostRawElementProvider(out pRetVal: IRawElementProviderSimple): HRESULT; virtual; stdcall;
    { IRawElementProviderFragment }
    function Navigate(direction: NavigateDirection; out pRetVal: IRawElementProviderFragment): HRESULT; stdcall;
    function GetRuntimeId(out pRetVal: SAFEARRAY): HRESULT; stdcall;
    function get_BoundingRectangle(out pRetVal: UiaRect): HRESULT; stdcall;
    function GetEmbeddedFragmentRoots(out pRetVal: SAFEARRAY): HRESULT; stdcall;
    function SetFocus: HRESULT; stdcall;
    function get_FragmentRoot(out pRetVal: IRawElementProviderFragmentRoot): HRESULT; stdcall;
    { IInvokeProvider }
    function Invoke: HRESULT; stdcall;
    { ISelectionItemProvider }
    function Select: HRESULT; stdcall;
    function AddToSelection: HRESULT; stdcall;
    function RemoveFromSelection: HRESULT; stdcall;
    function get_IsSelected(out pRetVal: BOOL): HRESULT; stdcall;
    function get_SelectionContainer(out pRetVal: IRawElementProviderSimple): HRESULT; stdcall;
    { IToggleProvider }
    function Toggle: HRESULT; stdcall;
    function get_ToggleState(out pRetVal: ToggleState): HRESULT; stdcall;
    { IValueProvider }
    function SetValue(val: PChar): HRESULT; stdcall;
    function get_Value(out pRetVal: PChar): HRESULT; stdcall;
    function get_IsReadOnly(out pRetVal: BOOL): HRESULT; stdcall;
  public
    constructor Create(const AContext: TUiaContext; const AKey: TNodeKey);
  end;

  TUiaRoot = class(TUiaElement, IRawElementProviderFragmentRoot)
  protected
    function get_HostRawElementProvider(out pRetVal: IRawElementProviderSimple): HRESULT; override; stdcall;
    { IRawElementProviderFragmentRoot }
    function ElementProviderFromPoint(x: Double; y: Double; out pRetVal: IRawElementProviderFragment): HRESULT;
      stdcall;
    function GetFocus(out pRetVal: IRawElementProviderFragment): HRESULT; stdcall;
  end;

  /// Subclasses the form window and answers WM_GETOBJECT.
  TUiaHook = class(TComponent)
  private
    FRibbon: TFmrRibbon;
    FContext: TUiaContext;
    FContextRef: IInterface;
    FWnd: HWND;
    FIdleId: TMessageSubscriptionId;
    procedure TryAttach;
    procedure Detach;
    procedure IdleHandler(const Sender: TObject; const M: System.Messaging.TMessage);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor CreateFor(const ARibbon: TFmrRibbon);
    destructor Destroy; override;
  end;

var
  GHooks: TObjectList<TUiaHook>;

{ TNodeKey }

class function TNodeKey.Make(const ARole: Integer; const APtr: Pointer): TNodeKey;
begin
  Result.Role := ARole;
  Result.Ptr := APtr;
end;

function TNodeKey.SameAs(const AOther: TNodeKey): Boolean;
begin
  Result := (Role = AOther.Role) and (Ptr = AOther.Ptr);
end;

{ TUiaContext }

function TUiaContext.Alive: Boolean;
begin
  Result := (FRibbon <> nil) and (FWnd <> 0) and IsWindow(FWnd);
end;

function TUiaContext.Nodes: TArray<TFmrAccNode>;
var
  Now: Cardinal;
begin
  if not Alive then
    Exit(nil);
  Now := GetTickCount;
  if (FNodes = nil) or (FVersion <> FRibbon.AccessibilityVersion) or (Now - FTick > 250) then
  begin
    FNodes := FRibbon.AccessibilityNodes;
    FVersion := FRibbon.AccessibilityVersion;
    FTick := Now;
  end;
  Result := FNodes;
end;

function TUiaContext.KeyOf(const ANode: TFmrAccNode): TNodeKey;
begin
  // Container roles start at 1: (0, nil) means "no node".
  if ANode.Element <> nil then
    Result := TNodeKey.Make(RoleElement, ANode.Element)
  else if ANode.Role = TFmrAccRole.Group then
    Result := TNodeKey.Make(Ord(ANode.Role) + 1, ANode.Data)
  else
    Result := TNodeKey.Make(Ord(ANode.Role) + 1, nil);
end;

function TUiaContext.Find(const AKey: TNodeKey; out AIndex: Integer): Boolean;
var
  A: TArray<TFmrAccNode>;
  I: Integer;
begin
  A := Nodes;
  for I := 0 to High(A) do
    if KeyOf(A[I]).SameAs(AKey) then
    begin
      AIndex := I;
      Exit(True);
    end;
  AIndex := -1;
  Result := False;
end;

function TUiaContext.Scale: Single;
var
  F: TCommonCustomForm;
begin
  Result := 1;
  if FRibbon = nil then
    Exit;
  if (FRibbon.Root <> nil) and (FRibbon.Root.GetObject is TCommonCustomForm) then
  begin
    F := TCommonCustomForm(FRibbon.Root.GetObject);
    if F.Handle <> nil then
      Result := F.Handle.Scale;
  end;
  if Result <= 0 then
    Result := 1;
end;

function TUiaContext.Provider(const AKey: TNodeKey): IRawElementProviderSimple;
begin
  if AKey.Role = RoleRoot then
    Result := FRoot
  else
    Result := TUiaElement.Create(Self, AKey);
end;

{ TUiaElement }

constructor TUiaElement.Create(const AContext: TUiaContext; const AKey: TNodeKey);
begin
  inherited Create;
  FContext := AContext;
  FContextRef := AContext;
  FKey := AKey;
end;

function TUiaElement.Node(out ANode: TFmrAccNode; out AIndex: Integer): Boolean;
begin
  Result := FContext.Find(FKey, AIndex);
  if Result then
    ANode := FContext.Nodes[AIndex]
  else
    ANode := Default(TFmrAccNode);
end;

function TUiaElement.get_ProviderOptions(out pRetVal: ProviderOptions): HRESULT;
begin
  pRetVal := ProviderOptions_ServerSideProvider or ProviderOptions_UseComThreading;
  Result := S_OK;
end;

function TUiaElement.get_HostRawElementProvider(out pRetVal: IRawElementProviderSimple): HRESULT;
begin
  pRetVal := nil;
  Result := S_OK;
end;

function TUiaElement.GetPatternProvider(patternId: UIA_PATTERN_ID; out pRetVal: IUnknown): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  pRetVal := nil;
  Result := S_OK;
  if (FKey.Role < 0) or not Node(N, I) then
    Exit;
  case patternId of
    UIA_InvokePatternId:
      if N.Role in [TFmrAccRole.Button, TFmrAccRole.SplitButton, TFmrAccRole.DropDownButton,
        TFmrAccRole.ApplicationButton, TFmrAccRole.CollapsedGroup, TFmrAccRole.SystemButton] then
        pRetVal := IInvokeProvider(Self);
    UIA_SelectionItemPatternId:
      if N.Role = TFmrAccRole.Tab then
        pRetVal := ISelectionItemProvider(Self);
    UIA_TogglePatternId:
      if (N.Role = TFmrAccRole.CheckBox) or ((N.Role = TFmrAccRole.Button) and N.Checked) then
        pRetVal := IToggleProvider(Self);
    UIA_ValuePatternId:
      if N.Role in EditorRoles then
        pRetVal := IValueProvider(Self);
  end;
end;

function ControlTypeOf(const ARole: TFmrAccRole): Integer;
begin
  case ARole of
    TFmrAccRole.QuickAccessToolbar: Result := UIA_ToolBarControlTypeId;
    TFmrAccRole.TabList: Result := UIA_TabControlTypeId;
    TFmrAccRole.Tab: Result := UIA_TabItemControlTypeId;
    TFmrAccRole.LowerRibbon: Result := UIA_PaneControlTypeId;
    TFmrAccRole.Group: Result := UIA_GroupControlTypeId;
    TFmrAccRole.SplitButton: Result := UIA_SplitButtonControlTypeId;
    TFmrAccRole.CheckBox: Result := UIA_CheckBoxControlTypeId;
    TFmrAccRole.Editor: Result := UIA_EditControlTypeId;
    TFmrAccRole.ComboBox: Result := UIA_ComboBoxControlTypeId;
    TFmrAccRole.Spinner: Result := UIA_SpinnerControlTypeId;
    TFmrAccRole.Slider: Result := UIA_SliderControlTypeId;
  else
    Result := UIA_ButtonControlTypeId;
  end;
end;

function TUiaElement.GetPropertyValue(propertyId: UIA_PROPERTY_ID; out pRetVal: OleVariant): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  pRetVal := Unassigned;
  Result := S_OK;
  if not FContext.Alive then
    Exit(E_ELEMENTNOTAVAILABLE);
  if FKey.Role = RoleRoot then
  begin
    if propertyId = UIA_FrameworkIdPropertyId then
      pRetVal := 'FMX';
    Exit;
  end;
  if FKey.Role = RoleRibbon then
  begin
    case propertyId of
      UIA_ControlTypePropertyId: pRetVal := UIA_PaneControlTypeId;
      UIA_NamePropertyId: pRetVal := FmrStr(TFmrStringId.AccRibbon);
      UIA_AutomationIdPropertyId: pRetVal := FContext.FRibbon.Name;
      UIA_ClassNamePropertyId: pRetVal := FContext.FRibbon.ClassName;
      UIA_FrameworkIdPropertyId: pRetVal := 'FMX';
      UIA_IsEnabledPropertyId: pRetVal := True;
      UIA_IsControlElementPropertyId, UIA_IsContentElementPropertyId: pRetVal := True;
      UIA_IsKeyboardFocusablePropertyId, UIA_HasKeyboardFocusPropertyId: pRetVal := False;
    end;
    Exit;
  end;
  if not Node(N, I) then
    Exit(E_ELEMENTNOTAVAILABLE);
  case propertyId of
    UIA_ControlTypePropertyId: pRetVal := ControlTypeOf(N.Role);
    UIA_NamePropertyId: pRetVal := N.Name;
    UIA_HelpTextPropertyId:
      if N.HelpText <> '' then
        pRetVal := N.HelpText;
    UIA_AccessKeyPropertyId:
      if N.AccessKey <> '' then
        pRetVal := N.AccessKey;
    UIA_AutomationIdPropertyId:
      if N.AutomationId <> '' then
        pRetVal := N.AutomationId
      else
        pRetVal := N.Name;
    UIA_ClassNamePropertyId:
      if N.Element <> nil then
        pRetVal := N.Element.ClassName
      else if N.Data <> nil then
        pRetVal := N.Data.ClassName;
    UIA_FrameworkIdPropertyId: pRetVal := 'FMX';
    UIA_IsEnabledPropertyId: pRetVal := N.Enabled;
    UIA_IsControlElementPropertyId, UIA_IsContentElementPropertyId: pRetVal := True;
    UIA_IsKeyboardFocusablePropertyId, UIA_HasKeyboardFocusPropertyId: pRetVal := False;
  end;
end;

function TUiaElement.Navigable(const ADirection: NavigateDirection): TNodeKey;
var
  A: TArray<TFmrAccNode>;
  Index, Parent, I: Integer;
  N: TFmrAccNode;
  Found: Boolean;
begin
  Result := TNodeKey.Make(0, nil);
  A := FContext.Nodes;
  if FKey.Role = RoleRoot then
  begin
    if (ADirection in [NavigateDirection_FirstChild, NavigateDirection_LastChild]) then
      Result := TNodeKey.Make(RoleRibbon, nil);
    Exit;
  end;
  if FKey.Role = RoleRibbon then
  begin
    case ADirection of
      NavigateDirection_Parent:
        Result := TNodeKey.Make(RoleRoot, nil);
      NavigateDirection_FirstChild:
        for I := 0 to High(A) do
          if A[I].Parent = -1 then
            Exit(FContext.KeyOf(A[I]));
      NavigateDirection_LastChild:
        for I := High(A) downto 0 do
          if A[I].Parent = -1 then
            Exit(FContext.KeyOf(A[I]));
    end;
    Exit;
  end;
  if not Node(N, Index) then
    Exit;
  Parent := N.Parent;
  case ADirection of
    NavigateDirection_Parent:
      if Parent < 0 then
        Result := TNodeKey.Make(RoleRibbon, nil)
      else
        Result := FContext.KeyOf(A[Parent]);
    NavigateDirection_NextSibling:
      for I := Index + 1 to High(A) do
        if A[I].Parent = Parent then
          Exit(FContext.KeyOf(A[I]));
    NavigateDirection_PreviousSibling:
      for I := Index - 1 downto 0 do
        if A[I].Parent = Parent then
          Exit(FContext.KeyOf(A[I]));
    NavigateDirection_FirstChild:
      for I := Index + 1 to High(A) do
        if A[I].Parent = Index then
          Exit(FContext.KeyOf(A[I]));
    NavigateDirection_LastChild:
      begin
        Found := False;
        for I := High(A) downto Index + 1 do
          if A[I].Parent = Index then
          begin
            Result := FContext.KeyOf(A[I]);
            Found := True;
            Break;
          end;
        if not Found then
          Result := TNodeKey.Make(0, nil);
      end;
  end;
end;

function TUiaElement.Navigate(direction: NavigateDirection; out pRetVal: IRawElementProviderFragment): HRESULT;
var
  K: TNodeKey;
begin
  pRetVal := nil;
  Result := S_OK;
  if not FContext.Alive then
    Exit;
  K := Navigable(direction);
  if (K.Role = 0) and (K.Ptr = nil) then
    Exit;
  pRetVal := FContext.Provider(K) as IRawElementProviderFragment;
end;

function TUiaElement.GetRuntimeId(out pRetVal: SAFEARRAY): HRESULT;
var
  SA: PSafeArray;
  Ids: array[0..2] of Integer;
  I: Integer;
begin
  if FKey.Role = RoleRoot then
  begin
    // The root takes the runtime id of its host window.
    PPointer(@pRetVal)^ := nil;
    Exit(S_OK);
  end;
  Ids[0] := UiaAppendRuntimeId;
  Ids[1] := FKey.Role;
  Ids[2] := Integer(NativeUInt(FKey.Ptr) and $7FFFFFFF);
  SA := SafeArrayCreateVector(VT_I4, 0, 3);
  for I := 0 to 2 do
    SafeArrayPutElement(SA, I, Ids[I]);
  PPointer(@pRetVal)^ := SA;
  Result := S_OK;
end;

function TUiaElement.get_BoundingRectangle(out pRetVal: UiaRect): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
  R: TRectF;
  S: Single;
  WR: TRect;
begin
  pRetVal := Default(UiaRect);
  Result := S_OK;
  if not FContext.Alive then
    Exit;
  if FKey.Role = RoleRoot then
    Exit;
  if FKey.Role = RoleRibbon then
  begin
    R := TRectF.Empty;
    for N in FContext.Nodes do
      if (N.Parent = -1) and not N.Bounds.IsEmpty then
        if R.IsEmpty then
          R := N.Bounds
        else
          R := TRectF.Union(R, N.Bounds);
    if R.IsEmpty and GetWindowRect(FContext.FWnd, WR) then
    begin
      pRetVal.left := WR.Left;
      pRetVal.top := WR.Top;
      pRetVal.width := WR.Width;
      pRetVal.height := 1;
      Exit;
    end;
  end
  else
  begin
    if not Node(N, I) then
      Exit(E_ELEMENTNOTAVAILABLE);
    R := N.Bounds;
  end;
  S := FContext.Scale;
  pRetVal.left := R.Left * S;
  pRetVal.top := R.Top * S;
  pRetVal.width := R.Width * S;
  pRetVal.height := R.Height * S;
end;

function TUiaElement.GetEmbeddedFragmentRoots(out pRetVal: SAFEARRAY): HRESULT;
begin
  PPointer(@pRetVal)^ := nil;
  Result := S_OK;
end;

function TUiaElement.SetFocus: HRESULT;
begin
  Result := S_OK;
end;

function TUiaElement.get_FragmentRoot(out pRetVal: IRawElementProviderFragmentRoot): HRESULT;
begin
  if FContext.FRoot <> nil then
    pRetVal := FContext.FRoot as IRawElementProviderFragmentRoot
  else
    pRetVal := nil;
  Result := S_OK;
end;

function TUiaElement.Invoke: HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
  Element: TObject;
  Context: IInterface;
  Ctx: TUiaContext;
begin
  if not Node(N, I) or (N.Element = nil) then
    Exit(E_ELEMENTNOTAVAILABLE);
  if not N.Enabled then
    Exit(E_ELEMENTNOTENABLED);
  Element := N.Element;
  Ctx := FContext;
  Context := FContextRef;
  // Asynchronous: a command may open a modal form or a menu; the client must not wait for it.
  TThread.ForceQueue(nil,
    procedure
    begin
      if Ctx.Alive then
        Ctx.FRibbon.AccessibilityInvoke(Element);
      // Context keeps the shared object alive until the call ran.
      if Context = nil then
        Exit;
    end);
  Result := S_OK;
end;

function TUiaElement.Select: HRESULT;
begin
  Result := Invoke;
end;

function TUiaElement.AddToSelection: HRESULT;
begin
  Result := Invoke;
end;

function TUiaElement.RemoveFromSelection: HRESULT;
begin
  Result := E_INVALIDOPERATION;
end;

function TUiaElement.get_IsSelected(out pRetVal: BOOL): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  pRetVal := Node(N, I) and N.Selected;
  Result := S_OK;
end;

function TUiaElement.get_SelectionContainer(out pRetVal: IRawElementProviderSimple): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  pRetVal := nil;
  if Node(N, I) and (N.Parent >= 0) then
    pRetVal := FContext.Provider(FContext.KeyOf(FContext.Nodes[N.Parent]));
  Result := S_OK;
end;

function TUiaElement.Toggle: HRESULT;
begin
  Result := Invoke;
end;

function TUiaElement.get_ToggleState(out pRetVal: ToggleState): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  if Node(N, I) and N.Checked then
    pRetVal := ToggleState_On
  else
    pRetVal := ToggleState_Off;
  Result := S_OK;
end;

function TUiaElement.SetValue(val: PChar): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  if not FContext.Alive or not Node(N, I) then
    Exit(E_ELEMENTNOTAVAILABLE);
  if not N.Enabled then
    Exit(E_ELEMENTNOTENABLED);
  // Synchronous: setting a value does not open anything, and clients read it back right away.
  if not FContext.FRibbon.AccessibilitySetValue(N.Element, string(val)) then
    Exit(E_INVALIDOPERATION);
  FContext.FNodes := nil;
  Result := S_OK;
end;

function TUiaElement.get_Value(out pRetVal: PChar): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  pRetVal := nil;
  if not Node(N, I) then
    Exit(E_ELEMENTNOTAVAILABLE);
  // A BSTR: the client frees it.
  pRetVal := PChar(SysAllocString(PChar(N.Value)));
  Result := S_OK;
end;

function TUiaElement.get_IsReadOnly(out pRetVal: BOOL): HRESULT;
var
  N: TFmrAccNode;
  I: Integer;
begin
  pRetVal := not Node(N, I) or N.ReadOnly or not N.Enabled;
  Result := S_OK;
end;

{ TUiaRoot }

function TUiaRoot.get_HostRawElementProvider(out pRetVal: IRawElementProviderSimple): HRESULT;
begin
  pRetVal := nil;
  if FContext.Alive then
    Result := UiaHostProviderFromHwnd(FContext.FWnd, pRetVal)
  else
    Result := S_OK;
end;

function TUiaRoot.ElementProviderFromPoint(x, y: Double; out pRetVal: IRawElementProviderFragment): HRESULT;
var
  A: TArray<TFmrAccNode>;
  P: TPointF;
  S, Best: Single;
  I, Found: Integer;
begin
  pRetVal := nil;
  Result := S_OK;
  if not FContext.Alive then
    Exit;
  S := FContext.Scale;
  P := PointF(x / S, y / S);
  A := FContext.Nodes;
  Found := -1;
  Best := MaxSingle;
  // The smallest node under the point (commands before their groups and containers).
  for I := 0 to High(A) do
    if A[I].Bounds.Contains(P) and (A[I].Bounds.Width * A[I].Bounds.Height < Best) then
    begin
      Best := A[I].Bounds.Width * A[I].Bounds.Height;
      Found := I;
    end;
  if Found >= 0 then
    pRetVal := FContext.Provider(FContext.KeyOf(A[Found])) as IRawElementProviderFragment;
end;

function TUiaRoot.GetFocus(out pRetVal: IRawElementProviderFragment): HRESULT;
begin
  pRetVal := nil;
  Result := S_OK;
end;

{ subclass procedure }

function UiaSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Hook: TUiaHook;
begin
  Hook := TUiaHook(dwRefData);
  if (uMsg = WM_GETOBJECT) and (Integer(lParam) = -25) and (Hook <> nil) and (Hook.FContext <> nil) and
    (Hook.FContext.FRoot <> nil) then
    Exit(UiaReturnRawElementProvider(hWnd, wParam, lParam, Hook.FContext.FRoot));
  if uMsg = WM_NCDESTROY then
  begin
    if Hook <> nil then
    begin
      UiaReturnRawElementProvider(hWnd, 0, 0, nil);
      Hook.FWnd := 0;
      if Hook.FContext <> nil then
        Hook.FContext.FWnd := 0;
    end;
    _RemoveWindowSubclass(hWnd, UiaSubclassProc, SubclassId);
  end;
  Result := _DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;

{ TUiaHook }

constructor TUiaHook.CreateFor(const ARibbon: TFmrRibbon);
begin
  inherited Create(nil);
  FRibbon := ARibbon;
  FRibbon.FreeNotification(Self);
  FContext := TUiaContext.Create;
  FContextRef := FContext;
  FContext.FRibbon := ARibbon;
  FContext.FRoot := TUiaRoot.Create(FContext, TNodeKey.Make(RoleRoot, nil));
  TryAttach;
  if FWnd = 0 then
    FIdleId := TMessageManager.DefaultManager.SubscribeToMessage(TIdleMessage, IdleHandler);
end;

destructor TUiaHook.Destroy;
begin
  if FIdleId <> 0 then
    TMessageManager.DefaultManager.Unsubscribe(TIdleMessage, FIdleId);
  Detach;
  if FRibbon <> nil then
    FRibbon.RemoveFreeNotification(Self);
  if FContext <> nil then
  begin
    FContext.FRibbon := nil;
    FContext.FWnd := 0;
    // Break the cycle root -> context -> root; clients may still hold providers (they answer "not available").
    FContext.FRoot := nil;
  end;
  FContextRef := nil;
  inherited;
end;

procedure TUiaHook.TryAttach;
var
  Form: TCommonCustomForm;
  Wnd: HWND;
begin
  if (FWnd <> 0) or (FRibbon = nil) or not LoadSubclassApi then
    Exit;
  if (FRibbon.Root = nil) or not (FRibbon.Root.GetObject is TCommonCustomForm) then
    Exit;
  Form := TCommonCustomForm(FRibbon.Root.GetObject);
  if not Form.IsHandleAllocated then
    Exit;
  Wnd := FormToHWND(Form);
  if (Wnd = 0) or not _SetWindowSubclass(Wnd, UiaSubclassProc, SubclassId, DWORD_PTR(Self)) then
    Exit;
  FWnd := Wnd;
  FContext.FWnd := Wnd;
end;

procedure TUiaHook.Detach;
begin
  if FWnd <> 0 then
  begin
    if IsWindow(FWnd) then
    begin
      UiaReturnRawElementProvider(FWnd, 0, 0, nil);
      _RemoveWindowSubclass(FWnd, UiaSubclassProc, SubclassId);
    end;
    FWnd := 0;
  end;
  if FContext <> nil then
    FContext.FWnd := 0;
end;

procedure TUiaHook.IdleHandler(const Sender: TObject; const M: System.Messaging.TMessage);
begin
  TryAttach;
  if (FWnd <> 0) and (FIdleId <> 0) then
  begin
    TMessageManager.DefaultManager.Unsubscribe(TIdleMessage, FIdleId);
    FIdleId := 0;
  end;
end;

procedure TUiaHook.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FRibbon) then
  begin
    Detach;
    FRibbon := nil;
    // The hook stays in the list (freed at finalization or by FmrUninstallRibbonAutomation); it is inert now.
    if FContext <> nil then
      FContext.FRibbon := nil;
  end;
end;

procedure FmrInstallRibbonAutomation(const ARibbon: TFmrRibbon);
var
  H: TUiaHook;
begin
  if ARibbon = nil then
    Exit;
  for H in GHooks do
    if H.FRibbon = ARibbon then
      Exit;
  GHooks.Add(TUiaHook.CreateFor(ARibbon));
end;

procedure FmrUninstallRibbonAutomation(const ARibbon: TFmrRibbon);
var
  I: Integer;
begin
  for I := GHooks.Count - 1 downto 0 do
    if GHooks[I].FRibbon = ARibbon then
      GHooks.Delete(I);
end;

initialization
  GHooks := TObjectList<TUiaHook>.Create(True);

finalization
  FreeAndNil(GHooks);

{$ELSE}

procedure FmrInstallRibbonAutomation(const ARibbon: TFmrRibbon);
begin
end;

procedure FmrUninstallRibbonAutomation(const ARibbon: TFmrRibbon);
begin
end;

{$ENDIF}

end.
