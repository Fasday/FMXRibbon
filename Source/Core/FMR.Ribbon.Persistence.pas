{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Save and load of the user layout (JSON)              }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Persistence;

/// Saves what the user can customize and loads it back:
///  - options: minimized, show mode, display mode (classic/simplified);
///  - quick access toolbar: position, visibility and links (items by name);
///  - tabs and groups: order, visibility, user captions; groups may move between tabs;
///  - user-defined tabs and groups with their content (links of user-defined groups).
/// Links of groups designed in the application are not saved: a new version of the application can add commands to
/// its groups without old layouts hiding them. Tabs and groups are found by Name; unknown names (removed in a newer
/// version) and unknown item names are skipped. Tabs and groups the layout does not mention keep their position.
///
/// Format: { "format": "FMR.RibbonLayout", "version": 1, "options": {...}, "qat": {...}, "tabs": [...] }.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, FMX.Types, FMR.Ribbon.Types,
  FMR.Bars, FMR.Ribbon.Structure;

type
  EFmrLayoutError = class(Exception);

  /// <summary>Finds an item by name (default: the bar manager of the owner, then the components of its form).
  /// </summary>
  TFmrItemResolver = reference to function(const AName: string): TFmrBarItem;

  TFmrRibbonLayoutStorage = class
  public const
    FormatName = 'FMR.RibbonLayout';
    FormatVersion = 1;
  private
    class function DefaultResolver(const AOwner: IFmrRibbonStructureOwner): TFmrItemResolver; static;
    class function LinkToJSON(const ALink: TFmrItemLink): TJSONObject; static;
    class function LinksToJSON(const ALinks: TFmrItemLinks): TJSONArray; static;
    class procedure LinksFromJSON(const ALinks: TFmrItemLinks; const AArray: TJSONArray;
      const AResolver: TFmrItemResolver); static;
    class function GroupToJSON(const AGroup: TFmrRibbonGroup): TJSONObject; static;
    class function TabToJSON(const ATab: TFmrRibbonTab): TJSONObject; static;
    class procedure LoadTabs(const AOwner: IFmrRibbonStructureOwner; const AArray: TJSONArray;
      const AResolver: TFmrItemResolver); static;
  public
    /// <summary>The layout of AOwner as a new JSON object (the caller frees it).</summary>
    class function SaveToJSON(const AOwner: IFmrRibbonStructureOwner): TJSONObject; static;
    class function SaveToString(const AOwner: IFmrRibbonStructureOwner; const AIndent: Boolean = True): string; static;
    class procedure SaveToStream(const AOwner: IFmrRibbonStructureOwner; const AStream: TStream); static;
    class procedure SaveToFile(const AOwner: IFmrRibbonStructureOwner; const AFileName: string); static;
    /// <summary>Applies a layout. Raises EFmrLayoutError when the JSON is not a layout or has a newer major
    /// version.</summary>
    class procedure LoadFromJSON(const AOwner: IFmrRibbonStructureOwner; const AJSON: TJSONObject;
      const AResolver: TFmrItemResolver = nil); static;
    class procedure LoadFromString(const AOwner: IFmrRibbonStructureOwner; const AText: string;
      const AResolver: TFmrItemResolver = nil); static;
    class procedure LoadFromStream(const AOwner: IFmrRibbonStructureOwner; const AStream: TStream;
      const AResolver: TFmrItemResolver = nil); static;
    class procedure LoadFromFile(const AOwner: IFmrRibbonStructureOwner; const AFileName: string;
      const AResolver: TFmrItemResolver = nil); static;
  end;

implementation

uses
  System.TypInfo, System.IOUtils, System.Math;

const
  KFormat = 'format';
  KVersion = 'version';
  KOptions = 'options';
  KMinimized = 'minimized';
  KShowMode = 'showMode';
  KDisplayMode = 'displayMode';
  KQAT = 'qat';
  KPosition = 'position';
  KVisible = 'visible';
  KLinks = 'links';
  KTabs = 'tabs';
  KGroups = 'groups';
  KName = 'name';
  KCaption = 'caption';
  KUserCaption = 'userCaption';
  KUserDefined = 'userDefined';
  KKeyTip = 'keyTip';
  KContextGroup = 'contextGroup';
  KItem = 'item';
  KBeginGroup = 'beginGroup';
  KViewLevels = 'viewLevels';
  KButtonGroup = 'buttonGroup';
  KSimplified = 'simplified';
  KGlyphIndex = 'imageIndex';
  KGlyphCode = 'glyphCode';
  KShowDialogLauncher = 'dialogLauncher';

function EnumToStr(const AInfo: Pointer; const AValue: Integer): string;
begin
  Result := GetEnumName(AInfo, AValue);
end;

function StrToEnum(const AInfo: Pointer; const AText: string; const ADefault: Integer): Integer;
begin
  Result := GetEnumValue(AInfo, AText);
  if (Result < GetTypeData(AInfo).MinValue) or (Result > GetTypeData(AInfo).MaxValue) then
    Result := ADefault;
end;

function GetStr(const AObj: TJSONObject; const AKey: string; const ADefault: string = ''): string;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AKey);
  if V is TJSONString then
    Result := TJSONString(V).Value
  else
    Result := ADefault;
end;

function GetBool(const AObj: TJSONObject; const AKey: string; const ADefault: Boolean): Boolean;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AKey);
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean
  else
    Result := ADefault;
end;

function GetInt(const AObj: TJSONObject; const AKey: string; const ADefault: Integer): Integer;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AKey);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt
  else
    Result := ADefault;
end;

function GetArray(const AObj: TJSONObject; const AKey: string): TJSONArray;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AKey);
  if V is TJSONArray then
    Result := TJSONArray(V)
  else
    Result := nil;
end;

function GetObj(const AObj: TJSONObject; const AKey: string): TJSONObject;
var
  V: TJSONValue;
begin
  V := AObj.GetValue(AKey);
  if V is TJSONObject then
    Result := TJSONObject(V)
  else
    Result := nil;
end;

type
  TOrder = class
  public
    /// Reorders ACurrent so that the mentioned objects (in AMentioned order) fill the slots not used by the
    /// others, which keep their index. Calls AMove(Object, NewIndex) from the first slot to the last.
    class procedure Apply<T: class>(const ACurrent: TArray<T>; const AMentioned: TList<T>;
      const AMove: TProc<T, Integer>); static;
  end;

class procedure TOrder.Apply<T>(const ACurrent: TArray<T>; const AMentioned: TList<T>;
  const AMove: TProc<T, Integer>);
var
  Res: TArray<T>;
  I, K: Integer;
begin
  SetLength(Res, Length(ACurrent));
  for I := 0 to High(ACurrent) do
    if AMentioned.Contains(ACurrent[I]) then
      Res[I] := nil
    else
      Res[I] := ACurrent[I];
  K := 0;
  for I := 0 to High(Res) do
    if Res[I] = nil then
    begin
      while (K < AMentioned.Count) and not TArray.Contains<T>(ACurrent, AMentioned[K]) do
        Inc(K);
      if K < AMentioned.Count then
      begin
        Res[I] := AMentioned[K];
        Inc(K);
      end;
    end;
  for I := 0 to High(Res) do
    if Res[I] <> nil then
      AMove(Res[I], I);
end;

{ TFmrRibbonLayoutStorage }

class function TFmrRibbonLayoutStorage.DefaultResolver(const AOwner: IFmrRibbonStructureOwner): TFmrItemResolver;
var
  Manager: TFmrBarManager;
  Root: TComponent;
begin
  Manager := AOwner.GetBarManager;
  Root := AOwner.GetStructureObject.Owner;
  Result :=
    function(const AName: string): TFmrBarItem
    var
      C: TComponent;
    begin
      Result := nil;
      if AName = '' then
        Exit;
      if Manager <> nil then
        Result := Manager.FindItem(AName);
      if (Result = nil) and (Root <> nil) then
      begin
        C := Root.FindComponent(AName);
        if C is TFmrBarItem then
          Result := TFmrBarItem(C);
      end;
    end;
end;

class function TFmrRibbonLayoutStorage.LinkToJSON(const ALink: TFmrItemLink): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair(KItem, ALink.Item.Name);
  if ALink.BeginGroup then
    Result.AddPair(KBeginGroup, TJSONBool.Create(True));
  if not ALink.Visible then
    Result.AddPair(KVisible, TJSONBool.Create(False));
  if ALink.ViewLevels <> [] then
    Result.AddPair(KViewLevels, FmrViewLevelsToString(ALink.ViewLevels));
  if ALink.ButtonGroup <> TFmrButtonGroupPosition.None then
    Result.AddPair(KButtonGroup, EnumToStr(TypeInfo(TFmrButtonGroupPosition), Ord(ALink.ButtonGroup)));
  if ALink.SimplifiedVisibility <> TFmrSimplifiedVisibility.Auto then
    Result.AddPair(KSimplified, EnumToStr(TypeInfo(TFmrSimplifiedVisibility), Ord(ALink.SimplifiedVisibility)));
  if ALink.UserCaption <> '' then
    Result.AddPair(KUserCaption, ALink.UserCaption);
  if ALink.KeyTip <> '' then
    Result.AddPair(KKeyTip, ALink.KeyTip);
end;

class function TFmrRibbonLayoutStorage.LinksToJSON(const ALinks: TFmrItemLinks): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to ALinks.Count - 1 do
    if (ALinks[I].Item <> nil) and (ALinks[I].Item.Name <> '') then
      Result.AddElement(LinkToJSON(ALinks[I]));
end;

class procedure TFmrRibbonLayoutStorage.LinksFromJSON(const ALinks: TFmrItemLinks; const AArray: TJSONArray;
  const AResolver: TFmrItemResolver);
var
  V: TJSONValue;
  O: TJSONObject;
  Item: TFmrBarItem;
  L: TFmrItemLink;
begin
  ALinks.BeginUpdate;
  try
    ALinks.Clear;
    if AArray = nil then
      Exit;
    for V in AArray do
    begin
      if not (V is TJSONObject) then
        Continue;
      O := TJSONObject(V);
      Item := AResolver(GetStr(O, KItem));
      if (Item = nil) or not Item.CanLinkInto(ALinks) then
        Continue;
      L := ALinks.Add;
      L.Item := Item;
      L.BeginGroup := GetBool(O, KBeginGroup, False);
      L.Visible := GetBool(O, KVisible, True);
      L.ViewLevels := FmrStringToViewLevels(GetStr(O, KViewLevels));
      L.ButtonGroup := TFmrButtonGroupPosition(StrToEnum(TypeInfo(TFmrButtonGroupPosition), GetStr(O, KButtonGroup),
        Ord(TFmrButtonGroupPosition.None)));
      L.SimplifiedVisibility := TFmrSimplifiedVisibility(StrToEnum(TypeInfo(TFmrSimplifiedVisibility),
        GetStr(O, KSimplified), Ord(TFmrSimplifiedVisibility.Auto)));
      L.UserCaption := GetStr(O, KUserCaption);
      L.KeyTip := GetStr(O, KKeyTip);
    end;
  finally
    ALinks.EndUpdate;
  end;
end;

class function TFmrRibbonLayoutStorage.GroupToJSON(const AGroup: TFmrRibbonGroup): TJSONObject;
begin
  Result := TJSONObject.Create;
  if AGroup.Name <> '' then
    Result.AddPair(KName, AGroup.Name);
  Result.AddPair(KVisible, TJSONBool.Create(AGroup.Visible));
  if AGroup.UserCaption <> '' then
    Result.AddPair(KUserCaption, AGroup.UserCaption);
  if AGroup.IsUserDefined then
  begin
    Result.AddPair(KUserDefined, TJSONBool.Create(True));
    Result.AddPair(KCaption, AGroup.Caption);
    if AGroup.KeyTip <> '' then
      Result.AddPair(KKeyTip, AGroup.KeyTip);
    if AGroup.Glyph.ImageIndex >= 0 then
      Result.AddPair(KGlyphIndex, TJSONNumber.Create(AGroup.Glyph.ImageIndex));
    if AGroup.Glyph.GlyphCode <> 0 then
      Result.AddPair(KGlyphCode, TJSONNumber.Create(Int64(AGroup.Glyph.GlyphCode)));
    if AGroup.ShowDialogLauncher then
      Result.AddPair(KShowDialogLauncher, TJSONBool.Create(True));
    Result.AddPair(KLinks, LinksToJSON(AGroup.ItemLinks));
  end;
end;

class function TFmrRibbonLayoutStorage.TabToJSON(const ATab: TFmrRibbonTab): TJSONObject;
var
  Groups: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  if ATab.Name <> '' then
    Result.AddPair(KName, ATab.Name);
  Result.AddPair(KVisible, TJSONBool.Create(ATab.Visible));
  if ATab.UserCaption <> '' then
    Result.AddPair(KUserCaption, ATab.UserCaption);
  if ATab.IsUserDefined then
  begin
    Result.AddPair(KUserDefined, TJSONBool.Create(True));
    Result.AddPair(KCaption, ATab.Caption);
    if ATab.KeyTip <> '' then
      Result.AddPair(KKeyTip, ATab.KeyTip);
    if (ATab.ContextGroup <> nil) and (ATab.ContextGroup.Name <> '') then
      Result.AddPair(KContextGroup, ATab.ContextGroup.Name);
  end;
  Groups := TJSONArray.Create;
  Result.AddPair(KGroups, Groups);
  for I := 0 to ATab.GroupCount - 1 do
    // A designed group without a name cannot be found again; a user-defined one is recreated.
    if (ATab.Groups[I].Name <> '') or ATab.Groups[I].IsUserDefined then
      Groups.AddElement(GroupToJSON(ATab.Groups[I]));
end;

class function TFmrRibbonLayoutStorage.SaveToJSON(const AOwner: IFmrRibbonStructureOwner): TJSONObject;
var
  Options: TFmrRibbonLayoutOptions;
  O, Q: TJSONObject;
  Tabs: TJSONArray;
  QAT: TFmrRibbonQuickAccessToolbar;
  T: TFmrRibbonTab;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair(KFormat, FormatName);
    Result.AddPair(KVersion, TJSONNumber.Create(FormatVersion));

    Options := AOwner.GetLayoutOptions;
    O := TJSONObject.Create;
    Result.AddPair(KOptions, O);
    O.AddPair(KMinimized, TJSONBool.Create(Options.Minimized));
    O.AddPair(KShowMode, EnumToStr(TypeInfo(TFmrRibbonShowMode), Ord(Options.ShowMode)));
    O.AddPair(KDisplayMode, EnumToStr(TypeInfo(TFmrRibbonDisplayMode), Ord(Options.DisplayMode)));

    QAT := AOwner.GetQuickAccessToolbar;
    if QAT <> nil then
    begin
      Q := TJSONObject.Create;
      Result.AddPair(KQAT, Q);
      Q.AddPair(KPosition, EnumToStr(TypeInfo(TFmrQATPosition), Ord(QAT.Position)));
      Q.AddPair(KVisible, TJSONBool.Create(QAT.Visible));
      Q.AddPair(KLinks, LinksToJSON(QAT.ItemLinks));
    end;

    Tabs := TJSONArray.Create;
    Result.AddPair(KTabs, Tabs);
    for T in TFmrRibbonStructure.Tabs(AOwner.GetStructureObject) do
      if (T.Name <> '') or T.IsUserDefined then
        Tabs.AddElement(TabToJSON(T));
  except
    Result.Free;
    raise;
  end;
end;

class function TFmrRibbonLayoutStorage.SaveToString(const AOwner: IFmrRibbonStructureOwner;
  const AIndent: Boolean): string;
var
  J: TJSONObject;
begin
  J := SaveToJSON(AOwner);
  try
    if AIndent then
      Result := J.Format(2)
    else
      Result := J.ToJSON;
  finally
    J.Free;
  end;
end;

class procedure TFmrRibbonLayoutStorage.SaveToStream(const AOwner: IFmrRibbonStructureOwner; const AStream: TStream);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(SaveToString(AOwner));
  if Length(Bytes) > 0 then
    AStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

class procedure TFmrRibbonLayoutStorage.SaveToFile(const AOwner: IFmrRibbonStructureOwner; const AFileName: string);
begin
  TFile.WriteAllText(AFileName, SaveToString(AOwner), TEncoding.UTF8);
end;

class procedure TFmrRibbonLayoutStorage.LoadFromString(const AOwner: IFmrRibbonStructureOwner; const AText: string;
  const AResolver: TFmrItemResolver);
var
  V: TJSONValue;
begin
  V := TJSONObject.ParseJSONValue(AText);
  try
    if not (V is TJSONObject) then
      raise EFmrLayoutError.Create('Ribbon layout: invalid JSON');
    LoadFromJSON(AOwner, TJSONObject(V), AResolver);
  finally
    V.Free;
  end;
end;

class procedure TFmrRibbonLayoutStorage.LoadFromStream(const AOwner: IFmrRibbonStructureOwner; const AStream: TStream;
  const AResolver: TFmrItemResolver);
var
  Bytes: TBytes;
  Size: Int64;
  Offset: Integer;
  Encoding: TEncoding;
begin
  Size := AStream.Size - AStream.Position;
  SetLength(Bytes, Size);
  if Size > 0 then
    AStream.ReadBuffer(Bytes[0], Size);
  Encoding := nil;
  Offset := TEncoding.GetBufferEncoding(Bytes, Encoding, TEncoding.UTF8);
  LoadFromString(AOwner, TEncoding.UTF8.GetString(Bytes, Offset, Length(Bytes) - Offset), AResolver);
end;

class procedure TFmrRibbonLayoutStorage.LoadFromFile(const AOwner: IFmrRibbonStructureOwner; const AFileName: string;
  const AResolver: TFmrItemResolver);
begin
  LoadFromString(AOwner, TFile.ReadAllText(AFileName, TEncoding.UTF8), AResolver);
end;

class procedure TFmrRibbonLayoutStorage.LoadFromJSON(const AOwner: IFmrRibbonStructureOwner; const AJSON: TJSONObject;
  const AResolver: TFmrItemResolver);
var
  Resolver: TFmrItemResolver;
  O, Q: TJSONObject;
  Options: TFmrRibbonLayoutOptions;
  QAT: TFmrRibbonQuickAccessToolbar;
begin
  if (AJSON = nil) or (GetStr(AJSON, KFormat) <> FormatName) then
    raise EFmrLayoutError.Create('Ribbon layout: unknown format');
  if GetInt(AJSON, KVersion, 0) > FormatVersion then
    raise EFmrLayoutError.CreateFmt('Ribbon layout: version %d is not supported', [GetInt(AJSON, KVersion, 0)]);
  Resolver := AResolver;
  if not Assigned(Resolver) then
    Resolver := DefaultResolver(AOwner);

  AOwner.BeginStructureUpdate;
  try
    O := GetObj(AJSON, KOptions);
    if O <> nil then
    begin
      Options := AOwner.GetLayoutOptions;
      Options.Minimized := GetBool(O, KMinimized, Options.Minimized);
      Options.ShowMode := TFmrRibbonShowMode(StrToEnum(TypeInfo(TFmrRibbonShowMode), GetStr(O, KShowMode),
        Ord(Options.ShowMode)));
      Options.DisplayMode := TFmrRibbonDisplayMode(StrToEnum(TypeInfo(TFmrRibbonDisplayMode), GetStr(O, KDisplayMode),
        Ord(Options.DisplayMode)));
      AOwner.SetLayoutOptions(Options);
    end;

    Q := GetObj(AJSON, KQAT);
    QAT := AOwner.GetQuickAccessToolbar;
    if (Q <> nil) and (QAT <> nil) then
    begin
      QAT.Position := TFmrQATPosition(StrToEnum(TypeInfo(TFmrQATPosition), GetStr(Q, KPosition), Ord(QAT.Position)));
      QAT.Visible := GetBool(Q, KVisible, QAT.Visible);
      if GetArray(Q, KLinks) <> nil then
        LinksFromJSON(QAT.ItemLinks, GetArray(Q, KLinks), Resolver);
    end;

    if GetArray(AJSON, KTabs) <> nil then
      LoadTabs(AOwner, GetArray(AJSON, KTabs), Resolver);
  finally
    AOwner.EndStructureUpdate;
  end;
end;

class procedure TFmrRibbonLayoutStorage.LoadTabs(const AOwner: IFmrRibbonStructureOwner; const AArray: TJSONArray;
  const AResolver: TFmrItemResolver);
var
  S: TFmxObject;
  Root: TComponent;
  T, Fallback: TFmrRibbonTab;
  G: TFmrRibbonGroup;
  Orphans: TList<TFmrRibbonGroup>;
  TabOrder: TList<TFmrRibbonTab>;
  GroupOrder: TList<TFmrRibbonGroup>;
  TabValue, GroupValue: TJSONValue;
  TabJ, GroupJ: TJSONObject;
  Groups: TJSONArray;
  I: Integer;
  Name: string;

  procedure SetNameIfFree(const AComponent: TComponent; const AName: string);
  begin
    if (AName <> '') and IsValidIdent(AName) and ((Root = nil) or (Root.FindComponent(AName) = nil)) then
      AComponent.Name := AName;
  end;

  function GroupsOf(const ATab: TFmrRibbonTab): TArray<TFmrRibbonGroup>;
  var
    K: Integer;
  begin
    SetLength(Result, ATab.GroupCount);
    for K := 0 to ATab.GroupCount - 1 do
      Result[K] := ATab.Groups[K];
  end;

begin
  S := AOwner.GetStructureObject;
  Root := S.Owner;
  Orphans := TList<TFmrRibbonGroup>.Create;
  TabOrder := TList<TFmrRibbonTab>.Create;
  GroupOrder := TList<TFmrRibbonGroup>.Create;
  try
    // 1. User-defined content is recreated from the layout. Designed groups inside user-defined tabs are kept.
    for T in TFmrRibbonStructure.Tabs(S) do
    begin
      for I := T.GroupCount - 1 downto 0 do
      begin
        G := T.Groups[I];
        if G.IsUserDefined then
          G.Free
        else if T.IsUserDefined then
        begin
          G.Parent := nil;
          Orphans.Add(G);
        end;
      end;
      if T.IsUserDefined then
        T.Free;
    end;

    // 2. Tabs and their groups in the order of the layout.
    for TabValue in AArray do
    begin
      if not (TabValue is TJSONObject) then
        Continue;
      TabJ := TJSONObject(TabValue);
      Name := GetStr(TabJ, KName);
      if GetBool(TabJ, KUserDefined, False) then
      begin
        T := TFmrRibbonStructure.CreateTab(S, GetStr(TabJ, KCaption));
        T.IsUserDefined := True;
        SetNameIfFree(T, Name);
        T.KeyTip := GetStr(TabJ, KKeyTip);
        T.ContextGroup := TFmrRibbonStructure.FindContextGroup(S, GetStr(TabJ, KContextGroup));
      end
      else
      begin
        T := nil;
        if Name <> '' then
          for var Candidate in TFmrRibbonStructure.Tabs(S) do
            if SameText(Candidate.Name, Name) then
            begin
              T := Candidate;
              Break;
            end;
        if T = nil then
          Continue;
      end;
      if TabOrder.Contains(T) then
        Continue;
      TabOrder.Add(T);
      T.Visible := GetBool(TabJ, KVisible, T.Visible);
      T.UserCaption := GetStr(TabJ, KUserCaption);

      GroupOrder.Clear;
      Groups := GetArray(TabJ, KGroups);
      if Groups <> nil then
        for GroupValue in Groups do
        begin
          if not (GroupValue is TJSONObject) then
            Continue;
          GroupJ := TJSONObject(GroupValue);
          Name := GetStr(GroupJ, KName);
          if GetBool(GroupJ, KUserDefined, False) then
          begin
            G := TFmrRibbonStructure.CreateGroup(T, GetStr(GroupJ, KCaption));
            G.IsUserDefined := True;
            SetNameIfFree(G, Name);
            G.KeyTip := GetStr(GroupJ, KKeyTip);
            G.Glyph.ImageIndex := GetInt(GroupJ, KGlyphIndex, -1);
            G.Glyph.GlyphCode := Cardinal(Max(0, GetInt(GroupJ, KGlyphCode, 0)));
            G.ShowDialogLauncher := GetBool(GroupJ, KShowDialogLauncher, False);
            LinksFromJSON(G.ItemLinks, GetArray(GroupJ, KLinks), AResolver);
          end
          else
          begin
            G := TFmrRibbonStructure.FindGroup(S, Name);
            if G = nil then
              for var Orphan in Orphans do
                if SameText(Orphan.Name, Name) then
                begin
                  G := Orphan;
                  Break;
                end;
            if G = nil then
              Continue;
            Orphans.Remove(G);
            if G.Parent <> T then
              TFmrRibbonStructure.MoveGroup(G, T);
          end;
          if GroupOrder.Contains(G) then
            Continue;
          GroupOrder.Add(G);
          G.Visible := GetBool(GroupJ, KVisible, G.Visible);
          G.UserCaption := GetStr(GroupJ, KUserCaption);
        end;

      TOrder.Apply<TFmrRibbonGroup>(GroupsOf(T), GroupOrder,
        procedure(AGroup: TFmrRibbonGroup; AIndex: Integer)
        begin
          TFmrRibbonStructure.MoveGroup(AGroup, AGroup.Tab, AIndex);
        end);
    end;

    // 3. Designed groups that lived in a removed user-defined tab and are not in the layout.
    if Orphans.Count > 0 then
    begin
      Fallback := nil;
      for T in TFmrRibbonStructure.Tabs(S) do
        if not T.IsUserDefined then
        begin
          Fallback := T;
          Break;
        end;
      for G in Orphans do
        if Fallback <> nil then
          TFmrRibbonStructure.MoveGroup(G, Fallback);
    end;

    TOrder.Apply<TFmrRibbonTab>(TFmrRibbonStructure.Tabs(S), TabOrder,
      procedure(ATab: TFmrRibbonTab; AIndex: Integer)
      begin
        TFmrRibbonStructure.MoveTab(ATab, AIndex);
      end);
  finally
    GroupOrder.Free;
    TabOrder.Free;
    Orphans.Free;
  end;
end;

end.
