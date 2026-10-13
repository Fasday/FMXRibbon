{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Merging the structure of ribbons                     }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Merge;

/// Merges the tabs and groups of a source ribbon (an MDI child, a plug-in) into a target ribbon, and undoes it.
/// The source is not changed: the target gets copies of tabs and groups (Stored = False, MergedFrom = the source
/// object) whose links reference the same items. Every source tab and group is handled by its MergeKind:
///   Merge   - merged into the target object with the same Name (then the same caption); added when none;
///   Add     - always added;
///   Replace - the matching target object is hidden and the copy takes its place;
///   Remove  - the matching target object is hidden.
/// Source tabs (groups) are visited in ascending MergeOrder. A copy is inserted before the first target tab
/// (group) with a greater MergeOrder, at the end otherwise. Links of a group merged into an existing group are
/// appended to it. Unmerge deletes everything the merge created and shows what it hid. When the source is destroyed
/// while merged, it is unmerged automatically.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes, System.Generics.Collections, FMX.Types, FMR.Ribbon.Types, FMR.Bars,
  FMR.Ribbon.Structure;

type
  /// <summary>Merges structure owners into one target (normally owned by the target ribbon).</summary>
  TFmrRibbonMerger = class(TComponent)
  private type
    TAddedLink = record
      Group: TFmrRibbonGroup;
      LinkID: Integer;
    end;
    THidden = record
      Obj: TFmrRibbonStructureObject;
      WasVisible: Boolean;
    end;
    TSession = class
      Source: TFmxObject;
      Created: TList<TFmrRibbonStructureObject>;
      AddedLinks: TList<TAddedLink>;
      Hidden: TList<THidden>;
      constructor Create;
      destructor Destroy; override;
    end;
  private
    FTarget: TFmxObject;
    FSessions: TObjectList<TSession>;
    FWorking: Boolean;
    function TargetOwner: IFmrRibbonStructureOwner;
    function FindSession(const ASource: TFmxObject): TSession;
    procedure Track(const AComponent: TComponent);
    procedure Hide(const ASession: TSession; const AObject: TFmrRibbonStructureObject);
    function MapContextGroup(const ASession: TSession; const ASource: TFmrRibbonContextGroup): TFmrRibbonContextGroup;
    function FindTargetTab(const ASource: TFmrRibbonTab): TFmrRibbonTab;
    function InsertIndexForTab(const AMergeOrder: Integer): Integer;
    function InsertIndexForGroup(const ATab: TFmrRibbonTab; const AMergeOrder: Integer): Integer;
    function CopyTab(const ASession: TSession; const ASource: TFmrRibbonTab; const ATabIndex: Integer): TFmrRibbonTab;
    function CopyGroup(const ASession: TSession; const ASource: TFmrRibbonGroup; const ATab: TFmrRibbonTab;
      const AGroupIndex: Integer): TFmrRibbonGroup;
    procedure MergeGroups(const ASession: TSession; const ASource, ATarget: TFmrRibbonTab);
    procedure AppendLinks(const ASession: TSession; const ASource, ATarget: TFmrRibbonGroup);
    procedure DoUnmerge(const ASession: TSession);
    procedure Forget(const AComponent: TComponent);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>ATarget: the structure object of the target (implements IFmrRibbonStructureOwner).</summary>
    constructor Create(AOwner: TComponent; const ATarget: TFmxObject); reintroduce;
    destructor Destroy; override;
    /// <summary>Merges ASource (implements IFmrRibbonStructureOwner) into the target. False when it is already
    /// merged or is the target.</summary>
    function Merge(const ASource: TFmxObject): Boolean;
    /// <summary>Undoes the merge of ASource; False when it is not merged.</summary>
    function Unmerge(const ASource: TFmxObject): Boolean;
    procedure UnmergeAll;
    function IsMerged(const ASource: TFmxObject): Boolean;
    function MergedCount: Integer;
    property Target: TFmxObject read FTarget;
  end;

implementation

uses
  System.Math;

type
  TMergeSort = class
    class function Sort<T: TFmrRibbonStructureObject>(const AItems: TArray<T>): TArray<T>; static;
  end;

class function TMergeSort.Sort<T>(const AItems: TArray<T>): TArray<T>;
var
  I, J: Integer;
  V: T;
begin
  Result := Copy(AItems);
  for I := 1 to High(Result) do
  begin
    V := Result[I];
    J := I;
    while (J > 0) and (Result[J - 1].MergeOrder > V.MergeOrder) do
    begin
      Result[J] := Result[J - 1];
      Dec(J);
    end;
    Result[J] := V;
  end;
end;

function GroupsOf(const ATab: TFmrRibbonTab): TArray<TFmrRibbonGroup>;
var
  I: Integer;
begin
  SetLength(Result, ATab.GroupCount);
  for I := 0 to ATab.GroupCount - 1 do
    Result[I] := ATab.Groups[I];
end;

{ TFmrRibbonMerger.TSession }

constructor TFmrRibbonMerger.TSession.Create;
begin
  inherited;
  Created := TList<TFmrRibbonStructureObject>.Create;
  AddedLinks := TList<TAddedLink>.Create;
  Hidden := TList<THidden>.Create;
end;

destructor TFmrRibbonMerger.TSession.Destroy;
begin
  Created.Free;
  AddedLinks.Free;
  Hidden.Free;
  inherited;
end;

{ TFmrRibbonMerger }

constructor TFmrRibbonMerger.Create(AOwner: TComponent; const ATarget: TFmxObject);
begin
  inherited Create(AOwner);
  FTarget := ATarget;
  FSessions := TObjectList<TSession>.Create(True);
  if FTarget <> nil then
    FTarget.FreeNotification(Self);
end;

destructor TFmrRibbonMerger.Destroy;
begin
  if (FTarget <> nil) and not (csDestroying in FTarget.ComponentState) then
    UnmergeAll;
  FreeAndNil(FSessions);
  inherited;
end;

function TFmrRibbonMerger.TargetOwner: IFmrRibbonStructureOwner;
begin
  if (FTarget = nil) or not Supports(FTarget, IFmrRibbonStructureOwner, Result) then
    raise EInvalidOperation.Create('Merge target does not implement IFmrRibbonStructureOwner');
end;

procedure TFmrRibbonMerger.Track(const AComponent: TComponent);
begin
  if AComponent <> nil then
    AComponent.FreeNotification(Self);
end;

function TFmrRibbonMerger.FindSession(const ASource: TFmxObject): TSession;
var
  S: TSession;
begin
  if FSessions <> nil then
    for S in FSessions do
      if S.Source = ASource then
        Exit(S);
  Result := nil;
end;

function TFmrRibbonMerger.IsMerged(const ASource: TFmxObject): Boolean;
begin
  Result := FindSession(ASource) <> nil;
end;

function TFmrRibbonMerger.MergedCount: Integer;
begin
  Result := FSessions.Count;
end;

procedure TFmrRibbonMerger.Hide(const ASession: TSession; const AObject: TFmrRibbonStructureObject);
var
  H: THidden;
begin
  if AObject = nil then
    Exit;
  for H in ASession.Hidden do
    if H.Obj = AObject then
      Exit;
  H.Obj := AObject;
  H.WasVisible := AObject.Visible;
  ASession.Hidden.Add(H);
  Track(AObject);
  AObject.Visible := False;
end;

function TFmrRibbonMerger.MapContextGroup(const ASession: TSession;
  const ASource: TFmrRibbonContextGroup): TFmrRibbonContextGroup;
begin
  if ASource = nil then
    Exit(nil);
  Result := nil;
  if ASource.Name <> '' then
    Result := TFmrRibbonStructure.FindContextGroup(FTarget, ASource.Name);
  if Result = nil then
    for var C in TFmrRibbonStructure.ContextGroups(FTarget) do
      if SameText(C.Caption, ASource.Caption) then
        Exit(C);
  if Result = nil then
  begin
    Result := TFmrRibbonStructure.CreateContextGroup(FTarget, ASource.Caption, ASource.Color);
    Result.Stored := False;
    Result.KeyTip := ASource.KeyTip;
    Result.MergedFrom := ASource;
    Result.Visible := ASource.Visible;
    ASession.Created.Add(Result);
    Track(Result);
  end;
end;

function TFmrRibbonMerger.FindTargetTab(const ASource: TFmrRibbonTab): TFmrRibbonTab;
var
  T: TFmrRibbonTab;
begin
  if ASource.Name <> '' then
    for T in TFmrRibbonStructure.Tabs(FTarget) do
      if SameText(T.Name, ASource.Name) then
        Exit(T);
  for T in TFmrRibbonStructure.Tabs(FTarget) do
    if (ASource.Caption <> '') and SameText(T.Caption, ASource.Caption) then
      Exit(T);
  Result := nil;
end;

function TFmrRibbonMerger.InsertIndexForTab(const AMergeOrder: Integer): Integer;
var
  A: TArray<TFmrRibbonTab>;
  I: Integer;
begin
  A := TFmrRibbonStructure.Tabs(FTarget);
  for I := 0 to High(A) do
    if A[I].MergeOrder > AMergeOrder then
      Exit(I);
  Result := -1;
end;

function TFmrRibbonMerger.InsertIndexForGroup(const ATab: TFmrRibbonTab; const AMergeOrder: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to ATab.GroupCount - 1 do
    if ATab.Groups[I].MergeOrder > AMergeOrder then
      Exit(I);
  Result := -1;
end;

function TFmrRibbonMerger.CopyTab(const ASession: TSession; const ASource: TFmrRibbonTab;
  const ATabIndex: Integer): TFmrRibbonTab;
var
  G: TFmrRibbonGroup;
begin
  Result := TFmrRibbonStructure.CreateTab(FTarget, ASource.Caption, ATabIndex);
  Result.Stored := False;
  Result.UserCaption := ASource.UserCaption;
  Result.KeyTip := ASource.KeyTip;
  Result.MergeOrder := ASource.MergeOrder;
  Result.MergedFrom := ASource;
  Result.ContextGroup := MapContextGroup(ASession, ASource.ContextGroup);
  Result.Visible := ASource.Visible;
  ASession.Created.Add(Result);
  Track(Result);
  for G in GroupsOf(ASource) do
    CopyGroup(ASession, G, Result, -1);
end;

function TFmrRibbonMerger.CopyGroup(const ASession: TSession; const ASource: TFmrRibbonGroup;
  const ATab: TFmrRibbonTab; const AGroupIndex: Integer): TFmrRibbonGroup;
var
  I: Integer;
begin
  Result := TFmrRibbonStructure.CreateGroup(ATab, ASource.Caption, AGroupIndex);
  Result.Stored := False;
  Result.UserCaption := ASource.UserCaption;
  Result.KeyTip := ASource.KeyTip;
  Result.MergeOrder := ASource.MergeOrder;
  Result.MergedFrom := ASource;
  Result.Glyph := ASource.Glyph;
  Result.CanCollapse := ASource.CanCollapse;
  Result.ReductionPriority := ASource.ReductionPriority;
  Result.ShowCaption := ASource.ShowCaption;
  Result.ShowDialogLauncher := ASource.ShowDialogLauncher;
  Result.DialogLauncherKeyTip := ASource.DialogLauncherKeyTip;
  Result.OnDialogLauncherClick := ASource.OnDialogLauncherClick;
  Result.Visible := ASource.Visible;
  Result.ItemLinks.BeginUpdate;
  try
    for I := 0 to ASource.ItemLinks.Count - 1 do
      TFmrRibbonStructure.CopyLink(ASource.ItemLinks[I], Result.ItemLinks);
  finally
    Result.ItemLinks.EndUpdate;
  end;
  if not ASession.Created.Contains(ATab) then
  begin
    // A group added to a tab this session did not create is removed by itself on unmerge.
    ASession.Created.Add(Result);
    Track(Result);
  end;
end;

procedure TFmrRibbonMerger.AppendLinks(const ASession: TSession; const ASource, ATarget: TFmrRibbonGroup);
var
  I: Integer;
  L: TFmrItemLink;
  A: TAddedLink;
begin
  Track(ATarget);
  ATarget.ItemLinks.BeginUpdate;
  try
    for I := 0 to ASource.ItemLinks.Count - 1 do
    begin
      L := TFmrRibbonStructure.CopyLink(ASource.ItemLinks[I], ATarget.ItemLinks);
      A.Group := ATarget;
      A.LinkID := L.ID;
      ASession.AddedLinks.Add(A);
    end;
  finally
    ATarget.ItemLinks.EndUpdate;
  end;
end;

procedure TFmrRibbonMerger.MergeGroups(const ASession: TSession; const ASource, ATarget: TFmrRibbonTab);
var
  SG, TG: TFmrRibbonGroup;
  Index: Integer;
begin
  for SG in TMergeSort.Sort<TFmrRibbonGroup>(GroupsOf(ASource)) do
  begin
    TG := nil;
    if SG.Name <> '' then
      for var G in GroupsOf(ATarget) do
        if SameText(G.Name, SG.Name) then
        begin
          TG := G;
          Break;
        end;
    if (TG = nil) and (SG.Caption <> '') then
      for var G in GroupsOf(ATarget) do
        if SameText(G.Caption, SG.Caption) then
        begin
          TG := G;
          Break;
        end;
    case SG.MergeKind of
      TFmrMergeKind.Merge:
        if TG <> nil then
          AppendLinks(ASession, SG, TG)
        else
          CopyGroup(ASession, SG, ATarget, InsertIndexForGroup(ATarget, SG.MergeOrder));
      TFmrMergeKind.Add:
        CopyGroup(ASession, SG, ATarget, InsertIndexForGroup(ATarget, SG.MergeOrder));
      TFmrMergeKind.Replace:
        begin
          if TG <> nil then
          begin
            Index := ATarget.IndexOfGroup(TG) + 1;
            Hide(ASession, TG);
            if Index >= ATarget.GroupCount then
              Index := -1;
          end
          else
            Index := InsertIndexForGroup(ATarget, SG.MergeOrder);
          CopyGroup(ASession, SG, ATarget, Index);
        end;
      TFmrMergeKind.Remove:
        Hide(ASession, TG);
    end;
  end;
end;

function TFmrRibbonMerger.Merge(const ASource: TFmxObject): Boolean;
var
  Owner: IFmrRibbonStructureOwner;
  Session: TSession;
  ST, TT: TFmrRibbonTab;
  Index: Integer;
begin
  Result := False;
  if (ASource = nil) or (ASource = FTarget) or IsMerged(ASource) then
    Exit;
  if not Supports(ASource, IFmrRibbonStructureOwner) then
    raise EInvalidOperation.Create('Merge source does not implement IFmrRibbonStructureOwner');
  Owner := TargetOwner;
  Session := TSession.Create;
  Session.Source := ASource;
  FSessions.Add(Session);
  ASource.FreeNotification(Self);
  FWorking := True;
  Owner.BeginStructureUpdate;
  try
    for ST in TMergeSort.Sort<TFmrRibbonTab>(TFmrRibbonStructure.Tabs(ASource)) do
    begin
      TT := FindTargetTab(ST);
      case ST.MergeKind of
        TFmrMergeKind.Merge:
          if TT <> nil then
            MergeGroups(Session, ST, TT)
          else
            CopyTab(Session, ST, InsertIndexForTab(ST.MergeOrder));
        TFmrMergeKind.Add:
          CopyTab(Session, ST, InsertIndexForTab(ST.MergeOrder));
        TFmrMergeKind.Replace:
          begin
            if TT <> nil then
            begin
              Index := TT.TabIndex + 1;
              Hide(Session, TT);
              if Index >= TFmrRibbonStructure.TabCount(FTarget) then
                Index := -1;
            end
            else
              Index := InsertIndexForTab(ST.MergeOrder);
            CopyTab(Session, ST, Index);
          end;
        TFmrMergeKind.Remove:
          Hide(Session, TT);
      end;
    end;
  finally
    Owner.EndStructureUpdate;
    FWorking := False;
  end;
  Result := True;
end;

procedure TFmrRibbonMerger.DoUnmerge(const ASession: TSession);
var
  Owner: IFmrRibbonStructureOwner;
  I: Integer;
  A: TAddedLink;
  Item: TCollectionItem;
  H: THidden;
  Obj: TFmrRibbonStructureObject;
begin
  Owner := TargetOwner;
  FWorking := True;
  Owner.BeginStructureUpdate;
  try
    for I := ASession.AddedLinks.Count - 1 downto 0 do
    begin
      A := ASession.AddedLinks[I];
      if A.Group <> nil then
      begin
        Item := A.Group.ItemLinks.FindItemID(A.LinkID);
        Item.Free;
      end;
    end;
    ASession.AddedLinks.Clear;
    for I := ASession.Created.Count - 1 downto 0 do
    begin
      Obj := ASession.Created[I];
      ASession.Created.Delete(I);
      if Obj <> nil then
      begin
        Obj.RemoveFreeNotification(Self);
        Obj.Free;
      end;
    end;
    for I := ASession.Hidden.Count - 1 downto 0 do
    begin
      H := ASession.Hidden[I];
      if H.Obj <> nil then
        H.Obj.Visible := H.WasVisible;
    end;
    ASession.Hidden.Clear;
  finally
    Owner.EndStructureUpdate;
    FWorking := False;
  end;
end;

function TFmrRibbonMerger.Unmerge(const ASource: TFmxObject): Boolean;
var
  Session: TSession;
begin
  Session := FindSession(ASource);
  Result := Session <> nil;
  if not Result then
    Exit;
  DoUnmerge(Session);
  if not (csDestroying in ASource.ComponentState) then
    ASource.RemoveFreeNotification(Self);
  FSessions.Remove(Session);
end;

procedure TFmrRibbonMerger.UnmergeAll;
begin
  while (FSessions <> nil) and (FSessions.Count > 0) do
    Unmerge(FSessions.Last.Source);
end;

procedure TFmrRibbonMerger.Forget(const AComponent: TComponent);
var
  S: TSession;
  I: Integer;
  A: TAddedLink;
  H: THidden;
begin
  for S in FSessions do
  begin
    for I := S.Created.Count - 1 downto 0 do
      if S.Created[I] = AComponent then
        S.Created.Delete(I);
    for I := S.AddedLinks.Count - 1 downto 0 do
      if S.AddedLinks[I].Group = AComponent then
      begin
        A := S.AddedLinks[I];
        A.Group := nil;
        S.AddedLinks[I] := A;
      end;
    for I := S.Hidden.Count - 1 downto 0 do
      if S.Hidden[I].Obj = AComponent then
      begin
        H := S.Hidden[I];
        H.Obj := nil;
        S.Hidden[I] := H;
      end;
  end;
end;

procedure TFmrRibbonMerger.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation <> opRemove) or (FSessions = nil) then
    Exit;
  if AComponent = FTarget then
  begin
    // The target and everything created in it go away together.
    FTarget := nil;
    FSessions.Clear;
    Exit;
  end;
  if (FindSession(TFmxObject(AComponent)) <> nil) and not FWorking then
  begin
    // The source is destroyed while merged: its items are going away as well.
    Unmerge(TFmxObject(AComponent));
    Exit;
  end;
  Forget(AComponent);
end;

end.
