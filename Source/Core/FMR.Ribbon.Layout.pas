{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Layout calculator of ribbon groups (pure code)       }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Layout;

/// Pure layout of the groups of one ribbon tab. No controls: the ribbon measures every link at every view level
/// (dp) and passes records; the calculator returns the level of every link, its rectangle in its group and the
/// groups that collapse into a drop-down button.
///
/// Arrangement of a group (Office rules): links flow left to right in columns. A Large link (and an in-ribbon
/// gallery) takes a full-height column; small links (SmallWithText, Small) stack in columns of up to RowCount rows.
/// A link with ButtonGroup = Member continues the row of the previous link (button groups, editors side by side);
/// on such a link BeginGroup starts a new segment of the row instead of a new column. BeginGroup on other links and
/// separator links end the column and draw a separator.
///
/// Reduction: the calculator builds a fixed sequence of steps from the fully expanded tab to the fully reduced one;
/// every step makes one group strictly narrower. For a given width the first step that fits is used, so the layout is
/// deterministic, a wider tab never gets a narrower layout and expansion is the exact reverse of reduction. Passes
/// (each pass visits groups in ascending Priority, right to left among equal priorities):
///   1. galleries lose one column at a time (round robin over the groups) down to their MinColumns;
///   2. Large -> SmallWithText, a run of up to RowCount adjacent large links per step, from the right of a group;
///   3. SmallWithText (or Large) -> Small, a run of up to RowCount links per step;
///   4. galleries become a large drop-down button;
///   5. groups collapse into their drop-down button (CanCollapse).
/// The sequence does not depend on the width; it is built once per input (Prepare) and every Calculate is a binary
/// search plus one arrangement per group.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Types, System.Math, System.Generics.Collections, FMR.Ribbon.Types;

type
  /// <summary>Sizes used by the calculator, in dp.</summary>
  TFmrLayoutMetrics = record
    /// <summary>Height of the content area of a group (where links are placed).</summary>
    ContentHeight: Single;
    /// <summary>Height of one row of small links.</summary>
    RowHeight: Single;
    RowCount: Integer;
    /// <summary>Space at the left and the right inside a group.</summary>
    GroupPaddingH: Single;
    /// <summary>Space between two groups.</summary>
    GroupSpacing: Single;
    /// <summary>Space between two columns of a group.</summary>
    ColumnSpacing: Single;
    /// <summary>Width taken by a separator between columns (line and margins).</summary>
    SeparatorWidth: Single;
    /// <summary>Space between two segments of a row (BeginGroup on a Member link).</summary>
    SegmentSpacing: Single;
    /// <summary>Width added to the caption of a group with a dialog launcher.</summary>
    DialogLauncherWidth: Single;
    MinGroupWidth: Single;
    /// <summary>A column with fewer rows than RowCount spreads them evenly over the height; otherwise they are
    /// top-aligned.</summary>
    DistributeRows: Boolean;
    { simplified (single line) layout }
    SimplifiedHeight: Single;
    SimplifiedItemSpacing: Single;
    /// <summary>Width of a separator between groups in the simplified layout.</summary>
    SimplifiedSeparatorWidth: Single;
    OverflowButtonWidth: Single;
    /// <summary>Office 365 like defaults: 3 rows of 22 dp.</summary>
    class function Default: TFmrLayoutMetrics; static;
  end;

  /// <summary>Input of one link.</summary>
  TFmrLayoutLink = record
    Kind: TFmrLayoutItemKind;
    Hidden: Boolean;
    /// <summary>Allowed levels; empty = [SmallWithText]. Ignored for galleries and separators.</summary>
    Levels: TFmrViewLevels;
    /// <summary>Width at each level. For a gallery Widths[Large] is the width of the large drop-down button the
    /// gallery becomes at the end of the reduction.</summary>
    Widths: array[TFmrViewLevel] of Single;
    BeginGroup: Boolean;
    ButtonGroup: TFmrButtonGroupPosition;
    { gallery }
    GalleryColumnWidth: Single;
    GalleryMinColumns: Integer;
    GalleryMaxColumns: Integer;
    /// <summary>Borders and scroll buttons of an in-ribbon gallery.</summary>
    GalleryExtraWidth: Single;
    { simplified layout }
    /// <summary>Width in the simplified line; 0 = Widths[Small] (Widths[SmallWithText] when Small is not
    /// allowed).</summary>
    SimplifiedWidth: Single;
    SimplifiedVisibility: TFmrSimplifiedVisibility;
    /// <summary>Free for the caller (index of the link, pointer...).</summary>
    Data: NativeInt;
    class function Button(const ALarge, ASmallWithText, ASmall: Single;
      const ALevels: TFmrViewLevels = FmrAllViewLevels): TFmrLayoutLink; static;
    class function Control(const AWithCaption, AWithoutCaption: Single): TFmrLayoutLink; static;
    class function Gallery(const AColumnWidth: Single; const AMinColumns, AMaxColumns: Integer;
      const AExtraWidth, AButtonWidth: Single): TFmrLayoutLink; static;
    class function Separator: TFmrLayoutLink; static;
    function WithBeginGroup(const AValue: Boolean = True): TFmrLayoutLink;
    function WithButtonGroup(const APosition: TFmrButtonGroupPosition): TFmrLayoutLink;
  end;

  /// <summary>Input of one group.</summary>
  TFmrLayoutGroup = record
    Hidden: Boolean;
    /// <summary>Width of the caption text; the group is at least this wide (plus paddings and launcher).</summary>
    CaptionWidth: Single;
    HasDialogLauncher: Boolean;
    /// <summary>True: the group may collapse into a drop-down button.</summary>
    CanCollapse: Boolean;
    /// <summary>Groups with a higher priority are reduced later in every pass.</summary>
    Priority: Integer;
    /// <summary>Width of the collapsed group button.</summary>
    CollapsedWidth: Single;
    Links: TArray<TFmrLayoutLink>;
    Data: NativeInt;
    class function Create(const ACaptionWidth, ACollapsedWidth: Single;
      const ALinks: array of TFmrLayoutLink): TFmrLayoutGroup; static;
  end;

  /// <summary>Place of a link in a segmented row (button group).</summary>
  TFmrLayoutSegment = (None, Single, First, Middle, Last);

  TFmrLayoutLinkResult = record
    Visible: Boolean;
    Level: TFmrViewLevel;
    /// <summary>Relative to the left edge of the group and the top of the content area.</summary>
    Bounds: TRectF;
    /// <summary>Galleries: shown columns; 0 = shown as a large drop-down button.</summary>
    GalleryColumns: Integer;
    Segment: TFmrLayoutSegment;
    /// <summary>Column of the group (0-based) and row in it (-1 for full-height links).</summary>
    Column: Integer;
    Row: Integer;
  end;

  TFmrLayoutGroupResult = record
    Visible: Boolean;
    Collapsed: Boolean;
    /// <summary>Left edge in the groups area.</summary>
    Left: Single;
    Width: Single;
    ContentWidth: Single;
    /// <summary>Width of the fully expanded group (the popup of a collapsed group).</summary>
    ExpandedWidth: Single;
    /// <summary>Links (for a collapsed group: the expanded layout shown in its popup).</summary>
    Links: TArray<TFmrLayoutLinkResult>;
    /// <summary>X of the separator lines, relative to the group.</summary>
    Separators: TArray<Single>;
    /// <summary>Reduction steps applied to the group.</summary>
    Steps: Integer;
  end;

  TFmrLayoutResult = record
    Groups: TArray<TFmrLayoutGroupResult>;
    /// <summary>Width of all visible groups with the spacing between them.</summary>
    TotalWidth: Single;
    /// <summary>False when even the fully reduced layout is wider than the available width (scroll buttons).
    /// </summary>
    Fits: Boolean;
    /// <summary>Index of the step used (0 = fully expanded).</summary>
    Step: Integer;
    StepCount: Integer;
  end;

  TFmrLinkRef = record
    Group: Integer;
    Link: Integer;
  end;

  TFmrSimplifiedLinkResult = record
    /// <summary>Shown in the line.</summary>
    Visible: Boolean;
    InOverflow: Boolean;
    /// <summary>Relative to the start of the line.</summary>
    Bounds: TRectF;
  end;

  TFmrSimplifiedGroupResult = record
    /// <summary>At least one link of the group is in the line.</summary>
    Visible: Boolean;
    Left: Single;
    Width: Single;
    Links: TArray<TFmrSimplifiedLinkResult>;
  end;

  TFmrSimplifiedLayoutResult = record
    Groups: TArray<TFmrSimplifiedGroupResult>;
    /// <summary>Links shown in the overflow ("...") menu, in ribbon order.</summary>
    Overflow: TArray<TFmrLinkRef>;
    OverflowButtonVisible: Boolean;
    OverflowButtonBounds: TRectF;
    /// <summary>X of separators between groups.</summary>
    Separators: TArray<Single>;
    TotalWidth: Single;
  end;

  /// <summary>Scroll state of a tab whose groups do not fit.</summary>
  TFmrGroupScrollInfo = record
    Offset: Single;
    MaxOffset: Single;
    CanScrollLeft: Boolean;
    CanScrollRight: Boolean;
    /// <summary>First and last group fully inside the view (-1 when none).</summary>
    FirstVisible: Integer;
    LastVisible: Integer;
  end;

  /// <summary>Layout calculator. Prepare once per input (tab, metrics, measured sizes), then Calculate on every
  /// resize.</summary>
  TFmrRibbonLayoutCalculator = class
  private type
    TGroupState = record
      Levels: TArray<TFmrViewLevel>;
      Columns: TArray<Integer>;
      Collapsed: Boolean;
      Width: Single;
      Steps: Integer;
    end;
    TStep = record
      Group: Integer;
      State: TGroupState;
      Total: Single;
    end;
    TRunKind = (LargeToSmaller, SmallTextToSmall, LargeToSmall);
  private
    FMetrics: TFmrLayoutMetrics;
    FGroups: TArray<TFmrLayoutGroup>;
    FInitial: TArray<TGroupState>;
    FSteps: TList<TStep>;
    FPrepared: Boolean;
    FCurrent: TArray<TGroupState>;
    FCurrentTotal: Single;
    procedure SetMetrics(const Value: TFmrLayoutMetrics);
    function CloneState(const S: TGroupState): TGroupState;
    function InitialState(const AGroup: Integer): TGroupState;
    function ArrangeGroup(const AGroup: Integer; const AState: TGroupState; const AFill: Boolean;
      var AResult: TFmrLayoutGroupResult): Single;
    function GroupWidth(const AGroup: Integer; const AState: TGroupState): Single;
    function GroupOrder: TArray<Integer>;
    function TotalOf(const AStates: TArray<TGroupState>): Single;
    function TryApply(const AGroup: Integer; var ANew: TGroupState): Boolean;
    procedure AddStep(const AGroup: Integer; const AState: TGroupState);
    function IsBreak(const AGroup, ALink: Integer): Boolean;
    function ReduceRun(const AGroup: Integer; const AKind: TRunKind): Boolean;
    procedure BuildSequence;
  public
    constructor Create; overload;
    constructor Create(const AMetrics: TFmrLayoutMetrics); overload;
    destructor Destroy; override;
    /// <summary>Sets the input; the reduction sequence is built on the next Calculate.</summary>
    procedure Prepare(const AGroups: TArray<TFmrLayoutGroup>);
    /// <summary>Layout of the prepared groups for AAvailableWidth.</summary>
    function Calculate(const AAvailableWidth: Single): TFmrLayoutResult;
    /// <summary>Layout of one group fully expanded (popup of a collapsed group, customization preview).</summary>
    function CalculateExpandedGroup(const AGroup: TFmrLayoutGroup): TFmrLayoutGroupResult;
    /// <summary>Single-line layout of the prepared groups (simplified ribbon).</summary>
    function CalculateSimplified(const AAvailableWidth: Single): TFmrSimplifiedLayoutResult;
    /// <summary>Total width after every step of the reduction sequence (index 0 = fully expanded).</summary>
    function StepWidths: TArray<Single>;
    /// <summary>Smallest total width reachable (fully reduced).</summary>
    function MinimumWidth: Single;
    /// <summary>Total width of the fully expanded groups.</summary>
    function ExpandedWidth: Single;
    property Metrics: TFmrLayoutMetrics read FMetrics write SetMetrics;
    /// <summary>One-shot layout.</summary>
    class function Layout(const AGroups: TArray<TFmrLayoutGroup>; const AMetrics: TFmrLayoutMetrics;
      const AAvailableWidth: Single): TFmrLayoutResult; static;
  end;

/// <summary>Scroll state for a layout that does not fit into AViewWidth, with the offset clamped.</summary>
function FmrGroupScrollInfo(const ALayout: TFmrLayoutResult; const AViewWidth, AOffset: Single): TFmrGroupScrollInfo;
/// <summary>Offset after one click of a scroll button: the next group that is not fully visible in that direction
/// is brought fully into view.</summary>
function FmrGroupScrollStep(const ALayout: TFmrLayoutResult; const AViewWidth, AOffset: Single;
  const AForward: Boolean): Single;
/// <summary>Right-to-left: mirrors link rectangles and separators inside the group (the calculator works left to
/// right).</summary>
procedure FmrMirrorGroup(var AGroup: TFmrLayoutGroupResult);
/// <summary>Right-to-left: mirrors every group inside the total width (group Left and their content).</summary>
procedure FmrMirrorLayout(var ALayout: TFmrLayoutResult);
/// <summary>Widths of tabs in a tab row: full widths when they fit, otherwise every tab shrinks proportionally to
/// the room it has above its minimum width; AFits is False when even the minimum widths do not fit.</summary>
function FmrLayoutTabs(const AFullWidths, AMinWidths: TArray<Single>; const AAvailableWidth: Single;
  out AFits: Boolean): TArray<Single>;

implementation

const
  Eps = 0.01;

{ TFmrLayoutMetrics }

class function TFmrLayoutMetrics.Default: TFmrLayoutMetrics;
begin
  Result.ContentHeight := 66;
  Result.RowHeight := 22;
  Result.RowCount := 3;
  Result.GroupPaddingH := 4;
  Result.GroupSpacing := 0;
  Result.ColumnSpacing := 2;
  Result.SeparatorWidth := 9;
  Result.SegmentSpacing := 4;
  Result.DialogLauncherWidth := 16;
  Result.MinGroupWidth := 24;
  Result.DistributeRows := True;
  Result.SimplifiedHeight := 32;
  Result.SimplifiedItemSpacing := 2;
  Result.SimplifiedSeparatorWidth := 9;
  Result.OverflowButtonWidth := 32;
end;

{ TFmrLayoutLink }

class function TFmrLayoutLink.Button(const ALarge, ASmallWithText, ASmall: Single;
  const ALevels: TFmrViewLevels): TFmrLayoutLink;
begin
  Result := Default(TFmrLayoutLink);
  Result.Kind := TFmrLayoutItemKind.Button;
  Result.Levels := ALevels;
  Result.Widths[TFmrViewLevel.Large] := ALarge;
  Result.Widths[TFmrViewLevel.SmallWithText] := ASmallWithText;
  Result.Widths[TFmrViewLevel.Small] := ASmall;
end;

class function TFmrLayoutLink.Control(const AWithCaption, AWithoutCaption: Single): TFmrLayoutLink;
begin
  Result := Default(TFmrLayoutLink);
  Result.Kind := TFmrLayoutItemKind.Control;
  Result.Levels := FmrSmallViewLevels;
  Result.Widths[TFmrViewLevel.Large] := AWithCaption;
  Result.Widths[TFmrViewLevel.SmallWithText] := AWithCaption;
  Result.Widths[TFmrViewLevel.Small] := AWithoutCaption;
end;

class function TFmrLayoutLink.Gallery(const AColumnWidth: Single; const AMinColumns, AMaxColumns: Integer;
  const AExtraWidth, AButtonWidth: Single): TFmrLayoutLink;
begin
  Result := Default(TFmrLayoutLink);
  Result.Kind := TFmrLayoutItemKind.Gallery;
  Result.Levels := [TFmrViewLevel.Large];
  Result.GalleryColumnWidth := AColumnWidth;
  Result.GalleryMinColumns := Max(1, AMinColumns);
  Result.GalleryMaxColumns := Max(Result.GalleryMinColumns, AMaxColumns);
  Result.GalleryExtraWidth := AExtraWidth;
  Result.Widths[TFmrViewLevel.Large] := AButtonWidth;
  Result.Widths[TFmrViewLevel.SmallWithText] := AButtonWidth;
  Result.Widths[TFmrViewLevel.Small] := AButtonWidth;
end;

class function TFmrLayoutLink.Separator: TFmrLayoutLink;
begin
  Result := Default(TFmrLayoutLink);
  Result.Kind := TFmrLayoutItemKind.Separator;
end;

function TFmrLayoutLink.WithBeginGroup(const AValue: Boolean): TFmrLayoutLink;
begin
  Result := Self;
  Result.BeginGroup := AValue;
end;

function TFmrLayoutLink.WithButtonGroup(const APosition: TFmrButtonGroupPosition): TFmrLayoutLink;
begin
  Result := Self;
  Result.ButtonGroup := APosition;
end;

{ TFmrLayoutGroup }

class function TFmrLayoutGroup.Create(const ACaptionWidth, ACollapsedWidth: Single;
  const ALinks: array of TFmrLayoutLink): TFmrLayoutGroup;
var
  I: Integer;
begin
  Result := Default(TFmrLayoutGroup);
  Result.CaptionWidth := ACaptionWidth;
  Result.CollapsedWidth := ACollapsedWidth;
  Result.CanCollapse := True;
  SetLength(Result.Links, Length(ALinks));
  for I := 0 to High(ALinks) do
    Result.Links[I] := ALinks[I];
end;

{ helpers }

function EffectiveLevels(const L: TFmrLayoutLink): TFmrViewLevels; inline;
begin
  Result := L.Levels;
  if Result = [] then
    Result := [TFmrViewLevel.SmallWithText];
end;

function SimplifiedWidthOf(const L: TFmrLayoutLink): Single;
begin
  Result := L.SimplifiedWidth;
  if Result <= 0 then
  begin
    if L.Kind = TFmrLayoutItemKind.Gallery then
      Result := L.Widths[TFmrViewLevel.Large]
    else if TFmrViewLevel.Small in EffectiveLevels(L) then
      Result := L.Widths[TFmrViewLevel.Small]
    else
      Result := L.Widths[TFmrViewLevel.SmallWithText];
  end;
end;

{ TFmrRibbonLayoutCalculator }

constructor TFmrRibbonLayoutCalculator.Create;
begin
  Create(TFmrLayoutMetrics.Default);
end;

constructor TFmrRibbonLayoutCalculator.Create(const AMetrics: TFmrLayoutMetrics);
begin
  inherited Create;
  FMetrics := AMetrics;
  FSteps := TList<TStep>.Create;
end;

destructor TFmrRibbonLayoutCalculator.Destroy;
begin
  FSteps.Free;
  inherited;
end;

class function TFmrRibbonLayoutCalculator.Layout(const AGroups: TArray<TFmrLayoutGroup>;
  const AMetrics: TFmrLayoutMetrics; const AAvailableWidth: Single): TFmrLayoutResult;
var
  C: TFmrRibbonLayoutCalculator;
begin
  C := TFmrRibbonLayoutCalculator.Create(AMetrics);
  try
    C.Prepare(AGroups);
    Result := C.Calculate(AAvailableWidth);
  finally
    C.Free;
  end;
end;

procedure TFmrRibbonLayoutCalculator.SetMetrics(const Value: TFmrLayoutMetrics);
begin
  FMetrics := Value;
  FPrepared := False;
end;

procedure TFmrRibbonLayoutCalculator.Prepare(const AGroups: TArray<TFmrLayoutGroup>);
begin
  FGroups := Copy(AGroups);
  FPrepared := False;
end;

function TFmrRibbonLayoutCalculator.CloneState(const S: TGroupState): TGroupState;
begin
  Result := S;
  Result.Levels := Copy(S.Levels);
  Result.Columns := Copy(S.Columns);
end;

function TFmrRibbonLayoutCalculator.InitialState(const AGroup: Integer): TGroupState;
var
  I: Integer;
  L: TFmrLayoutLink;
begin
  Result := Default(TGroupState);
  SetLength(Result.Levels, Length(FGroups[AGroup].Links));
  SetLength(Result.Columns, Length(FGroups[AGroup].Links));
  for I := 0 to High(FGroups[AGroup].Links) do
  begin
    L := FGroups[AGroup].Links[I];
    if L.Kind = TFmrLayoutItemKind.Gallery then
    begin
      Result.Levels[I] := TFmrViewLevel.Large;
      Result.Columns[I] := Max(1, Max(L.GalleryMinColumns, L.GalleryMaxColumns));
    end
    else
      Result.Levels[I] := FmrLargestViewLevel(EffectiveLevels(L));
  end;
  Result.Width := GroupWidth(AGroup, Result);
end;

function TFmrRibbonLayoutCalculator.GroupWidth(const AGroup: Integer; const AState: TGroupState): Single;
var
  Dummy: TFmrLayoutGroupResult;
begin
  if AState.Collapsed then
    Result := FGroups[AGroup].CollapsedWidth
  else
    Result := ArrangeGroup(AGroup, AState, False, Dummy);
end;

function TFmrRibbonLayoutCalculator.ArrangeGroup(const AGroup: Integer; const AState: TGroupState;
  const AFill: Boolean; var AResult: TFmrLayoutGroupResult): Single;
var
  G: TFmrLayoutGroup;
  M: TFmrLayoutMetrics;
  RowCount: Integer;
  X: Single;
  Placed, PendingSep, LastWasRow: Boolean;
  ColumnIndex: Integer;
  Rows: TArray<TArray<Integer>>;
  RowLen: TArray<Integer>;
  RowWidth: TArray<Single>;
  RowsInColumn: Integer;
  Seps: TList<Single>;
  I: Integer;
  L: TFmrLayoutLink;
  Level: TFmrViewLevel;
  W, ContentWidth, MinWidth, GroupW, Shift: Single;
  IsContinuation: Boolean;

  procedure StartColumn;
  begin
    if Placed then
    begin
      if PendingSep then
      begin
        if AFill then
          Seps.Add(X + M.SeparatorWidth / 2);
        X := X + M.SeparatorWidth;
      end
      else
        X := X + M.ColumnSpacing;
    end;
    PendingSep := False;
  end;

  procedure SetSegments(const ARow: Integer);
  var
    K, SegStart: Integer;
    Idx: Integer;
    IsButtonGroup: Boolean;

    procedure CloseSegment(const AFirst, ALast: Integer);
    var
      J: Integer;
    begin
      if AFirst = ALast then
        AResult.Links[Rows[ARow][AFirst]].Segment := TFmrLayoutSegment.Single
      else
        for J := AFirst to ALast do
          if J = AFirst then
            AResult.Links[Rows[ARow][J]].Segment := TFmrLayoutSegment.First
          else if J = ALast then
            AResult.Links[Rows[ARow][J]].Segment := TFmrLayoutSegment.Last
          else
            AResult.Links[Rows[ARow][J]].Segment := TFmrLayoutSegment.Middle;
    end;

  begin
    IsButtonGroup := False;
    for K := 0 to RowLen[ARow] - 1 do
      if G.Links[Rows[ARow][K]].ButtonGroup <> TFmrButtonGroupPosition.None then
        IsButtonGroup := True;
    if not IsButtonGroup then
      Exit;
    SegStart := 0;
    for K := 1 to RowLen[ARow] - 1 do
    begin
      Idx := Rows[ARow][K];
      if G.Links[Idx].BeginGroup then
      begin
        CloseSegment(SegStart, K - 1);
        SegStart := K;
      end;
    end;
    CloseSegment(SegStart, RowLen[ARow] - 1);
  end;

  procedure FlushColumn;
  var
    R, K, Idx: Integer;
    ColW, Gap, Y, CX, LinkW: Single;
  begin
    if RowsInColumn = 0 then
      Exit;
    StartColumn;
    ColW := 0;
    for R := 0 to RowsInColumn - 1 do
      ColW := Max(ColW, RowWidth[R]);
    if AFill then
    begin
      if M.DistributeRows and (RowsInColumn < RowCount) then
        Gap := Max(0, (M.ContentHeight - RowsInColumn * M.RowHeight) / (RowsInColumn + 1))
      else if RowCount > 0 then
        Gap := Max(0, (M.ContentHeight - RowCount * M.RowHeight) / (RowCount + 1))
      else
        Gap := 0;
      for R := 0 to RowsInColumn - 1 do
      begin
        Y := Gap + R * (M.RowHeight + Gap);
        CX := X;
        for K := 0 to RowLen[R] - 1 do
        begin
          Idx := Rows[R][K];
          if (K > 0) and G.Links[Idx].BeginGroup then
            CX := CX + M.SegmentSpacing;
          LinkW := G.Links[Idx].Widths[AState.Levels[Idx]];
          AResult.Links[Idx].Bounds := TRectF.Create(CX, Y, CX + LinkW, Y + M.RowHeight);
          AResult.Links[Idx].Column := ColumnIndex;
          AResult.Links[Idx].Row := R;
          CX := CX + LinkW;
        end;
        SetSegments(R);
      end;
    end;
    X := X + ColW;
    Inc(ColumnIndex);
    Placed := True;
    RowsInColumn := 0;
    LastWasRow := False;
  end;

  procedure PlaceFull(const AIndex: Integer; const AWidth: Single);
  begin
    FlushColumn;
    StartColumn;
    if AFill then
    begin
      AResult.Links[AIndex].Bounds := TRectF.Create(X, 0, X + AWidth, M.ContentHeight);
      AResult.Links[AIndex].Column := ColumnIndex;
      AResult.Links[AIndex].Row := -1;
    end;
    X := X + AWidth;
    Inc(ColumnIndex);
    Placed := True;
    LastWasRow := False;
  end;

  procedure AppendToRow(const ARow, AIndex: Integer; const AWidth: Single);
  begin
    if RowLen[ARow] >= Length(Rows[ARow]) then
      SetLength(Rows[ARow], Max(4, Length(Rows[ARow]) * 2));
    if (RowLen[ARow] > 0) and G.Links[AIndex].BeginGroup then
      RowWidth[ARow] := RowWidth[ARow] + M.SegmentSpacing;
    Rows[ARow][RowLen[ARow]] := AIndex;
    Inc(RowLen[ARow]);
    RowWidth[ARow] := RowWidth[ARow] + AWidth;
  end;

begin
  G := FGroups[AGroup];
  M := FMetrics;
  RowCount := Max(1, M.RowCount);
  X := 0;
  Placed := False;
  PendingSep := False;
  LastWasRow := False;
  ColumnIndex := 0;
  RowsInColumn := 0;
  SetLength(Rows, RowCount);
  SetLength(RowLen, RowCount);
  SetLength(RowWidth, RowCount);
  Seps := nil;
  if AFill then
  begin
    Seps := TList<Single>.Create;
    SetLength(AResult.Links, Length(G.Links));
    for I := 0 to High(G.Links) do
      AResult.Links[I] := Default(TFmrLayoutLinkResult);
  end;
  try
    for I := 0 to High(G.Links) do
    begin
      L := G.Links[I];
      if L.Hidden then
        Continue;
      if L.Kind = TFmrLayoutItemKind.Separator then
      begin
        FlushColumn;
        if Placed then
          PendingSep := True;
        LastWasRow := False;
        Continue;
      end;
      IsContinuation := (L.ButtonGroup = TFmrButtonGroupPosition.Member) and LastWasRow and (RowsInColumn > 0);
      if L.BeginGroup and not IsContinuation then
      begin
        FlushColumn;
        if Placed then
          PendingSep := True;
      end;
      Level := AState.Levels[I];
      if AFill then
      begin
        AResult.Links[I].Visible := True;
        AResult.Links[I].Level := Level;
      end;
      if L.Kind = TFmrLayoutItemKind.Gallery then
      begin
        if AFill then
          AResult.Links[I].GalleryColumns := AState.Columns[I];
        if AState.Columns[I] > 0 then
          W := AState.Columns[I] * L.GalleryColumnWidth + L.GalleryExtraWidth
        else
          W := L.Widths[TFmrViewLevel.Large];
        PlaceFull(I, W);
      end
      else if Level = TFmrViewLevel.Large then
        PlaceFull(I, L.Widths[TFmrViewLevel.Large])
      else
      begin
        W := L.Widths[Level];
        if IsContinuation then
          AppendToRow(RowsInColumn - 1, I, W)
        else
        begin
          if RowsInColumn >= RowCount then
            FlushColumn;
          RowLen[RowsInColumn] := 0;
          RowWidth[RowsInColumn] := 0;
          Inc(RowsInColumn);
          AppendToRow(RowsInColumn - 1, I, W);
        end;
        LastWasRow := True;
      end;
    end;
    FlushColumn;
    ContentWidth := X;
    MinWidth := G.CaptionWidth + 2 * M.GroupPaddingH;
    if G.HasDialogLauncher then
      MinWidth := MinWidth + M.DialogLauncherWidth;
    GroupW := Max(Max(ContentWidth + 2 * M.GroupPaddingH, MinWidth), M.MinGroupWidth);
    if AFill then
    begin
      Shift := M.GroupPaddingH + (GroupW - 2 * M.GroupPaddingH - ContentWidth) / 2;
      for I := 0 to High(AResult.Links) do
        if AResult.Links[I].Visible then
          AResult.Links[I].Bounds.Offset(Shift, 0);
      SetLength(AResult.Separators, Seps.Count);
      for I := 0 to Seps.Count - 1 do
        AResult.Separators[I] := Seps[I] + Shift;
      AResult.ContentWidth := ContentWidth;
      AResult.Width := GroupW;
    end;
    Result := GroupW;
  finally
    Seps.Free;
  end;
end;

function TFmrRibbonLayoutCalculator.TotalOf(const AStates: TArray<TGroupState>): Single;
var
  I, N: Integer;
begin
  Result := 0;
  N := 0;
  for I := 0 to High(FGroups) do
    if not FGroups[I].Hidden then
    begin
      Result := Result + AStates[I].Width;
      Inc(N);
    end;
  if N > 1 then
    Result := Result + (N - 1) * FMetrics.GroupSpacing;
end;

function TFmrRibbonLayoutCalculator.GroupOrder: TArray<Integer>;
var
  L: TList<Integer>;
  I: Integer;
begin
  L := TList<Integer>.Create;
  try
    for I := High(FGroups) downto 0 do
      if not FGroups[I].Hidden then
        L.Add(I);
    // Stable insertion sort by priority keeps the right-to-left order among equal priorities.
    for I := 1 to L.Count - 1 do
    begin
      var J := I;
      var V := L[I];
      while (J > 0) and (FGroups[L[J - 1]].Priority > FGroups[V].Priority) do
      begin
        L[J] := L[J - 1];
        Dec(J);
      end;
      L[J] := V;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

procedure TFmrRibbonLayoutCalculator.AddStep(const AGroup: Integer; const AState: TGroupState);
var
  S: TStep;
begin
  FCurrentTotal := FCurrentTotal - FCurrent[AGroup].Width + AState.Width;
  FCurrent[AGroup] := AState;
  S.Group := AGroup;
  S.State := CloneState(AState);
  S.Total := FCurrentTotal;
  FSteps.Add(S);
end;

function TFmrRibbonLayoutCalculator.TryApply(const AGroup: Integer; var ANew: TGroupState): Boolean;
begin
  ANew.Width := GroupWidth(AGroup, ANew);
  Result := ANew.Width < FCurrent[AGroup].Width - Eps;
  if Result then
  begin
    ANew.Steps := FCurrent[AGroup].Steps + 1;
    AddStep(AGroup, ANew);
  end;
end;

function TFmrRibbonLayoutCalculator.IsBreak(const AGroup, ALink: Integer): Boolean;
var
  L: TFmrLayoutLink;
begin
  L := FGroups[AGroup].Links[ALink];
  Result := (L.Kind in [TFmrLayoutItemKind.Separator, TFmrLayoutItemKind.Gallery]) or
    (L.BeginGroup and (L.ButtonGroup <> TFmrButtonGroupPosition.Member));
end;

function TFmrRibbonLayoutCalculator.ReduceRun(const AGroup: Integer; const AKind: TRunKind): Boolean;
var
  G: TFmrLayoutGroup;
  Cur: TGroupState;
  RunEnd, RunStart, I, Taken, RowCount: Integer;
  New: TGroupState;
  Next: TFmrViewLevel;

  function Eligible(const AIndex: Integer): Boolean;
  var
    L: TFmrLayoutLink;
    Lv: TFmrViewLevels;
  begin
    L := G.Links[AIndex];
    Result := False;
    if L.Hidden or not (L.Kind in [TFmrLayoutItemKind.Button, TFmrLayoutItemKind.Control]) then
      Exit;
    Lv := EffectiveLevels(L);
    case AKind of
      TRunKind.LargeToSmaller:
        Result := (Cur.Levels[AIndex] = TFmrViewLevel.Large) and FmrNextSmallerViewLevel(Lv, TFmrViewLevel.Large, Next);
      TRunKind.SmallTextToSmall:
        Result := (Cur.Levels[AIndex] = TFmrViewLevel.SmallWithText) and (TFmrViewLevel.Small in Lv);
      TRunKind.LargeToSmall:
        Result := (Cur.Levels[AIndex] = TFmrViewLevel.Large) and (TFmrViewLevel.Small in Lv);
    end;
  end;

  function TargetLevel(const AIndex: Integer): TFmrViewLevel;
  begin
    if AKind = TRunKind.LargeToSmaller then
      FmrNextSmallerViewLevel(EffectiveLevels(G.Links[AIndex]), TFmrViewLevel.Large, Result)
    else
      Result := TFmrViewLevel.Small;
  end;

begin
  Result := False;
  G := FGroups[AGroup];
  Cur := FCurrent[AGroup];
  if Cur.Collapsed then
    Exit;
  RowCount := Max(1, FMetrics.RowCount);
  RunEnd := High(G.Links);
  // Candidates from right to left: the rightmost RowCount eligible links of every run.
  while RunEnd >= 0 do
  begin
    if not Eligible(RunEnd) then
    begin
      Dec(RunEnd);
      Continue;
    end;
    RunStart := RunEnd;
    Taken := 1;
    I := RunEnd - 1;
    while (I >= 0) and (Taken < RowCount) and not IsBreak(AGroup, I + 1) do
    begin
      if G.Links[I].Hidden then
      begin
        Dec(I);
        Continue;
      end;
      if not Eligible(I) then
        Break;
      RunStart := I;
      Inc(Taken);
      Dec(I);
    end;
    New := CloneState(Cur);
    for I := RunStart to RunEnd do
      if not G.Links[I].Hidden and Eligible(I) then
        New.Levels[I] := TargetLevel(I);
    if TryApply(AGroup, New) then
      Exit(True);
    RunEnd := RunStart - 1;
  end;
end;

procedure TFmrRibbonLayoutCalculator.BuildSequence;
var
  Order: TArray<Integer>;
  G, I: Integer;
  Any: Boolean;
  New: TGroupState;
  Stuck: TArray<TArray<Boolean>>;
  Initial: TStep;
begin
  FSteps.Clear;
  SetLength(FInitial, Length(FGroups));
  for G := 0 to High(FGroups) do
    FInitial[G] := InitialState(G);
  SetLength(FCurrent, Length(FGroups));
  for G := 0 to High(FGroups) do
    FCurrent[G] := CloneState(FInitial[G]);
  FCurrentTotal := TotalOf(FCurrent);
  Initial.Group := -1;
  Initial.Total := FCurrentTotal;
  FSteps.Add(Initial);
  Order := GroupOrder;

  // 1. galleries lose columns, one column per group per round
  SetLength(Stuck, Length(FGroups));
  for G := 0 to High(FGroups) do
    SetLength(Stuck[G], Length(FGroups[G].Links));
  repeat
    Any := False;
    for G in Order do
      for I := High(FGroups[G].Links) downto 0 do
        if (FGroups[G].Links[I].Kind = TFmrLayoutItemKind.Gallery) and not FGroups[G].Links[I].Hidden and
          not Stuck[G][I] and (FCurrent[G].Columns[I] > FGroups[G].Links[I].GalleryMinColumns) then
        begin
          New := CloneState(FCurrent[G]);
          Dec(New.Columns[I]);
          if TryApply(G, New) then
          begin
            Any := True;
            Break;
          end
          else
            Stuck[G][I] := True;
        end;
  until not Any;

  // 2. Large -> SmallWithText (or Small when SmallWithText is not allowed)
  for G in Order do
    while ReduceRun(G, TRunKind.LargeToSmaller) do;

  // 3. -> Small
  for G in Order do
    while ReduceRun(G, TRunKind.SmallTextToSmall) or ReduceRun(G, TRunKind.LargeToSmall) do;

  // 4. galleries become drop-down buttons
  for G in Order do
    for I := High(FGroups[G].Links) downto 0 do
      if (FGroups[G].Links[I].Kind = TFmrLayoutItemKind.Gallery) and not FGroups[G].Links[I].Hidden and
        (FCurrent[G].Columns[I] > 0) then
      begin
        New := CloneState(FCurrent[G]);
        New.Columns[I] := 0;
        TryApply(G, New);
      end;

  // 5. collapse groups
  for G in Order do
    if FGroups[G].CanCollapse and not FCurrent[G].Collapsed then
    begin
      New := CloneState(FCurrent[G]);
      New.Collapsed := True;
      TryApply(G, New);
    end;

  FPrepared := True;
end;

function TFmrRibbonLayoutCalculator.Calculate(const AAvailableWidth: Single): TFmrLayoutResult;
var
  Lo, Hi, Mid, StepIndex, G, I: Integer;
  States: TArray<TGroupState>;
  X: Single;
  N: Integer;
  Expanded: TFmrLayoutGroupResult;
begin
  if not FPrepared then
    BuildSequence;
  // Totals are strictly decreasing: binary search of the first step that fits.
  Lo := 0;
  Hi := FSteps.Count - 1;
  StepIndex := -1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if FSteps[Mid].Total <= AAvailableWidth + Eps then
    begin
      StepIndex := Mid;
      Hi := Mid - 1;
    end
    else
      Lo := Mid + 1;
  end;
  Result := Default(TFmrLayoutResult);
  Result.StepCount := FSteps.Count;
  Result.Fits := StepIndex >= 0;
  if StepIndex < 0 then
    StepIndex := FSteps.Count - 1;
  Result.Step := StepIndex;
  SetLength(States, Length(FGroups));
  for G := 0 to High(FGroups) do
    States[G] := FInitial[G];
  for I := 1 to StepIndex do
    States[FSteps[I].Group] := FSteps[I].State;

  SetLength(Result.Groups, Length(FGroups));
  X := 0;
  N := 0;
  for G := 0 to High(FGroups) do
  begin
    Result.Groups[G] := Default(TFmrLayoutGroupResult);
    if FGroups[G].Hidden then
      Continue;
    if N > 0 then
      X := X + FMetrics.GroupSpacing;
    Inc(N);
    Expanded := Default(TFmrLayoutGroupResult);
    ArrangeGroup(G, FInitial[G], True, Expanded);
    if States[G].Collapsed then
    begin
      Result.Groups[G] := Expanded;
      Result.Groups[G].Collapsed := True;
      Result.Groups[G].Width := FGroups[G].CollapsedWidth;
    end
    else
      ArrangeGroup(G, States[G], True, Result.Groups[G]);
    Result.Groups[G].Visible := True;
    Result.Groups[G].ExpandedWidth := Expanded.Width;
    Result.Groups[G].Steps := States[G].Steps;
    Result.Groups[G].Left := X;
    X := X + Result.Groups[G].Width;
  end;
  Result.TotalWidth := X;
end;

function TFmrRibbonLayoutCalculator.CalculateExpandedGroup(const AGroup: TFmrLayoutGroup): TFmrLayoutGroupResult;
var
  Saved: TArray<TFmrLayoutGroup>;
  SavedPrepared: Boolean;
begin
  Saved := FGroups;
  SavedPrepared := FPrepared;
  try
    FGroups := [AGroup];
    Result := Default(TFmrLayoutGroupResult);
    ArrangeGroup(0, InitialState(0), True, Result);
    Result.Visible := True;
    Result.ExpandedWidth := Result.Width;
  finally
    FGroups := Saved;
    FPrepared := SavedPrepared;
  end;
end;

function TFmrRibbonLayoutCalculator.StepWidths: TArray<Single>;
var
  I: Integer;
begin
  if not FPrepared then
    BuildSequence;
  SetLength(Result, FSteps.Count);
  for I := 0 to FSteps.Count - 1 do
    Result[I] := FSteps[I].Total;
end;

function TFmrRibbonLayoutCalculator.MinimumWidth: Single;
begin
  if not FPrepared then
    BuildSequence;
  Result := FSteps.Last.Total;
end;

function TFmrRibbonLayoutCalculator.ExpandedWidth: Single;
begin
  if not FPrepared then
    BuildSequence;
  Result := FSteps.First.Total;
end;

function TFmrRibbonLayoutCalculator.CalculateSimplified(const AAvailableWidth: Single): TFmrSimplifiedLayoutResult;
type
  TEntry = record
    Group, Link: Integer;
    Width: Single;
    Visibility: TFmrSimplifiedVisibility;
    Shown: Boolean;
  end;
var
  Entries: TList<TEntry>;
  E: TEntry;
  G, I, K: Integer;
  L: TFmrLayoutLink;
  M: TFmrLayoutMetrics;
  Overflow: TList<TFmrLinkRef>;
  Ref: TFmrLinkRef;
  Limit, X: Single;
  HasForced: Boolean;

  function LineWidth: Single;
  var
    J, LastGroup: Integer;
  begin
    Result := 0;
    LastGroup := -1;
    for J := 0 to Entries.Count - 1 do
      if Entries[J].Shown then
      begin
        if LastGroup >= 0 then
        begin
          if Entries[J].Group <> LastGroup then
            Result := Result + M.SimplifiedSeparatorWidth
          else
            Result := Result + M.SimplifiedItemSpacing;
        end;
        Result := Result + Entries[J].Width;
        LastGroup := Entries[J].Group;
      end;
  end;

  function RemoveLast(const AVisibility: TFmrSimplifiedVisibility): Boolean;
  var
    J: Integer;
    T: TEntry;
  begin
    for J := Entries.Count - 1 downto 0 do
      if Entries[J].Shown and (Entries[J].Visibility = AVisibility) then
      begin
        T := Entries[J];
        T.Shown := False;
        Entries[J] := T;
        Exit(True);
      end;
    Result := False;
  end;

begin
  M := FMetrics;
  Result := Default(TFmrSimplifiedLayoutResult);
  SetLength(Result.Groups, Length(FGroups));
  Entries := TList<TEntry>.Create;
  Overflow := TList<TFmrLinkRef>.Create;
  try
    HasForced := False;
    for G := 0 to High(FGroups) do
    begin
      SetLength(Result.Groups[G].Links, Length(FGroups[G].Links));
      if FGroups[G].Hidden then
        Continue;
      for I := 0 to High(FGroups[G].Links) do
      begin
        L := FGroups[G].Links[I];
        if L.Hidden or (L.Kind = TFmrLayoutItemKind.Separator) or
          (L.SimplifiedVisibility = TFmrSimplifiedVisibility.Never) then
          Continue;
        E.Group := G;
        E.Link := I;
        E.Width := SimplifiedWidthOf(L);
        E.Visibility := L.SimplifiedVisibility;
        E.Shown := L.SimplifiedVisibility <> TFmrSimplifiedVisibility.Overflow;
        if not E.Shown then
          HasForced := True;
        Entries.Add(E);
      end;
    end;

    if HasForced or (LineWidth > AAvailableWidth + Eps) then
    begin
      Limit := AAvailableWidth - M.OverflowButtonWidth - M.SimplifiedItemSpacing;
      while (LineWidth > Limit + Eps) and RemoveLast(TFmrSimplifiedVisibility.Auto) do;
      while (LineWidth > Limit + Eps) and RemoveLast(TFmrSimplifiedVisibility.Always) do;
    end;

    X := 0;
    K := -1;
    for I := 0 to Entries.Count - 1 do
    begin
      E := Entries[I];
      if E.Shown then
      begin
        if K >= 0 then
        begin
          if E.Group <> K then
          begin
            Result.Separators := Result.Separators + [X + M.SimplifiedSeparatorWidth / 2];
            X := X + M.SimplifiedSeparatorWidth;
          end
          else
            X := X + M.SimplifiedItemSpacing;
        end;
        if not Result.Groups[E.Group].Visible then
        begin
          Result.Groups[E.Group].Visible := True;
          Result.Groups[E.Group].Left := X;
        end;
        Result.Groups[E.Group].Links[E.Link].Visible := True;
        Result.Groups[E.Group].Links[E.Link].Bounds := TRectF.Create(X, 0, X + E.Width, M.SimplifiedHeight);
        X := X + E.Width;
        Result.Groups[E.Group].Width := X - Result.Groups[E.Group].Left;
        K := E.Group;
      end
      else
      begin
        Result.Groups[E.Group].Links[E.Link].InOverflow := True;
        Ref.Group := E.Group;
        Ref.Link := E.Link;
        Overflow.Add(Ref);
      end;
    end;
    Result.Overflow := Overflow.ToArray;
    Result.OverflowButtonVisible := Overflow.Count > 0;
    if Result.OverflowButtonVisible then
    begin
      if X > 0 then
        X := X + M.SimplifiedItemSpacing;
      Result.OverflowButtonBounds := TRectF.Create(X, 0, X + M.OverflowButtonWidth, M.SimplifiedHeight);
      X := X + M.OverflowButtonWidth;
    end;
    Result.TotalWidth := X;
  finally
    Overflow.Free;
    Entries.Free;
  end;
end;

{ scrolling }

function FmrGroupScrollInfo(const ALayout: TFmrLayoutResult; const AViewWidth, AOffset: Single): TFmrGroupScrollInfo;
var
  I: Integer;
  G: TFmrLayoutGroupResult;
begin
  Result := Default(TFmrGroupScrollInfo);
  Result.MaxOffset := Max(0, ALayout.TotalWidth - AViewWidth);
  Result.Offset := EnsureRange(AOffset, 0, Result.MaxOffset);
  Result.CanScrollLeft := Result.Offset > Eps;
  Result.CanScrollRight := Result.Offset < Result.MaxOffset - Eps;
  Result.FirstVisible := -1;
  Result.LastVisible := -1;
  for I := 0 to High(ALayout.Groups) do
  begin
    G := ALayout.Groups[I];
    if not G.Visible then
      Continue;
    if (G.Left >= Result.Offset - Eps) and (G.Left + G.Width <= Result.Offset + AViewWidth + Eps) then
    begin
      if Result.FirstVisible < 0 then
        Result.FirstVisible := I;
      Result.LastVisible := I;
    end;
  end;
end;

function FmrGroupScrollStep(const ALayout: TFmrLayoutResult; const AViewWidth, AOffset: Single;
  const AForward: Boolean): Single;
var
  Info: TFmrGroupScrollInfo;
  I: Integer;
  G: TFmrLayoutGroupResult;
begin
  Info := FmrGroupScrollInfo(ALayout, AViewWidth, AOffset);
  Result := Info.Offset;
  if AForward then
  begin
    for I := 0 to High(ALayout.Groups) do
    begin
      G := ALayout.Groups[I];
      if G.Visible and (G.Left + G.Width > Info.Offset + AViewWidth + Eps) then
      begin
        Result := G.Left + G.Width - AViewWidth;
        Break;
      end;
    end;
  end
  else
  begin
    for I := High(ALayout.Groups) downto 0 do
    begin
      G := ALayout.Groups[I];
      if G.Visible and (G.Left < Info.Offset - Eps) then
      begin
        Result := G.Left;
        Break;
      end;
    end;
  end;
  Result := EnsureRange(Result, 0, Info.MaxOffset);
end;

procedure FmrMirrorGroup(var AGroup: TFmrLayoutGroupResult);
var
  I: Integer;
  W: Single;
  R: TRectF;
begin
  if AGroup.Collapsed then
    W := AGroup.ExpandedWidth
  else
    W := AGroup.Width;
  for I := 0 to High(AGroup.Links) do
    if AGroup.Links[I].Visible then
    begin
      R := AGroup.Links[I].Bounds;
      AGroup.Links[I].Bounds := TRectF.Create(W - R.Right, R.Top, W - R.Left, R.Bottom);
      case AGroup.Links[I].Segment of
        TFmrLayoutSegment.First: AGroup.Links[I].Segment := TFmrLayoutSegment.Last;
        TFmrLayoutSegment.Last: AGroup.Links[I].Segment := TFmrLayoutSegment.First;
      end;
    end;
  for I := 0 to High(AGroup.Separators) do
    AGroup.Separators[I] := W - AGroup.Separators[I];
end;

procedure FmrMirrorLayout(var ALayout: TFmrLayoutResult);
var
  I: Integer;
begin
  for I := 0 to High(ALayout.Groups) do
    if ALayout.Groups[I].Visible then
    begin
      ALayout.Groups[I].Left := ALayout.TotalWidth - ALayout.Groups[I].Left - ALayout.Groups[I].Width;
      FmrMirrorGroup(ALayout.Groups[I]);
    end;
end;

function FmrLayoutTabs(const AFullWidths, AMinWidths: TArray<Single>; const AAvailableWidth: Single;
  out AFits: Boolean): TArray<Single>;
var
  I: Integer;
  SumFull, SumMin, Ratio: Single;
begin
  SetLength(Result, Length(AFullWidths));
  SumFull := 0;
  SumMin := 0;
  for I := 0 to High(AFullWidths) do
  begin
    SumFull := SumFull + AFullWidths[I];
    if I <= High(AMinWidths) then
      SumMin := SumMin + Min(AMinWidths[I], AFullWidths[I])
    else
      SumMin := SumMin + AFullWidths[I];
  end;
  AFits := SumMin <= AAvailableWidth + Eps;
  if SumFull <= AAvailableWidth + Eps then
    Ratio := 1
  else if not AFits or (SumFull - SumMin <= Eps) then
    Ratio := 0
  else
    Ratio := (AAvailableWidth - SumMin) / (SumFull - SumMin);
  for I := 0 to High(AFullWidths) do
  begin
    var MinW: Single;
    if I <= High(AMinWidths) then
      MinW := Min(AMinWidths[I], AFullWidths[I])
    else
      MinW := AFullWidths[I];
    Result[I] := MinW + (AFullWidths[I] - MinW) * Ratio;
  end;
end;

end.
