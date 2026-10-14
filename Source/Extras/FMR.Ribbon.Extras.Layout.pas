{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Pure layout helpers of the status bar and backstage  }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Extras.Layout;

/// Layout arithmetic of the companion controls (TFmrStatusBar, TFmrRibbonBackstageView) without any FMX
/// dependency, so it is tested by Tests\FMR.Tests.Extras: placement of status bar panels, the zoom slider
/// scale (100 % in the middle), zoom steps of the - / + buttons, keyboard navigation over selectable entries and
/// scroll clamping.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Math;

type
  /// <summary>Side of the status bar a panel is aligned to.</summary>
  TFmrStatusPanelSide = (Left, Right);

  /// <summary>Input of FmrLayoutStatusPanels for one panel.</summary>
  TFmrStatusPanelMeasure = record
    Side: TFmrStatusPanelSide;
    Visible: Boolean;
    /// <summary>Preferred width (fixed width or measured content), dp.</summary>
    Width: Single;
    /// <summary>The panel is never made narrower than this; when even that does not fit it is hidden.</summary>
    MinWidth: Single;
    /// <summary>The panel takes a share of the free space.</summary>
    Stretch: Boolean;
    class function Create(const ASide: TFmrStatusPanelSide; const AWidth: Single; const AMinWidth: Single = 0;
      const AStretch: Boolean = False; const AVisible: Boolean = True): TFmrStatusPanelMeasure; static;
  end;

  /// <summary>Result of FmrLayoutStatusPanels for one panel.</summary>
  TFmrStatusPanelSlot = record
    Left: Single;
    Width: Single;
    /// <summary>False when the panel is not shown (invisible, or no room left for it).</summary>
    Shown: Boolean;
    function Right: Single;
  end;

/// <summary>Places status bar panels between AStart and AEnd (dp). Left panels are placed from AStart in their
/// order, right panels end at AEnd (in their order, the last one is the rightmost); ASpacing separates neighbors.
/// Free space goes in equal parts to Stretch panels. When the panels do not fit: Stretch panels shrink to their
/// MinWidth, then left panels from the last one, then left panels are hidden from the last one, then right panels
/// shrink and are hidden from the first one.</summary>
function FmrLayoutStatusPanels(const APanels: array of TFmrStatusPanelMeasure; const AStart, AEnd: Single;
  const ASpacing: Single = 0): TArray<TFmrStatusPanelSlot>;

/// <summary>Position (0..1) of AZoom on the zoom slider. When AMin &lt; 100 &lt; AMax the middle of the
/// track is 100 %, the left half is linear from AMin to 100 and the right half from 100 to AMax; otherwise the whole
/// track is linear from AMin to AMax.</summary>
function FmrZoomToFraction(const AZoom, AMin, AMax: Integer): Single;
/// <summary>Inverse of FmrZoomToFraction, rounded to a whole percent and clamped to AMin..AMax.</summary>
function FmrFractionToZoom(const AFraction: Single; const AMin, AMax: Integer): Integer;
/// <summary>Zoom after a click on the - (AUp = False) or + button: the next multiple of AStep below/above AZoom,
/// clamped to AMin..AMax.</summary>
function FmrZoomStep(const AZoom, AStep, AMin, AMax: Integer; const AUp: Boolean): Integer;

/// <summary>Index of the next selectable entry after ACurrent in the direction of ADelta (+1 down, -1 up).
/// ACurrent = -1 starts before the first entry (after the last one for ADelta &lt; 0). AWrap continues at the other
/// end. Returns ACurrent when no other entry is selectable (-1 when none at all).</summary>
function FmrNextSelectable(const ASelectable: array of Boolean; const ACurrent, ADelta: Integer;
  const AWrap: Boolean): Integer;

/// <summary>First selectable entry (ALast = False) or the last one; -1 when none.</summary>
function FmrEdgeSelectable(const ASelectable: array of Boolean; const ALast: Boolean): Integer;

/// <summary>Scroll offset clamped to 0..AContent - AViewport (0 when the content fits).</summary>
function FmrClampScroll(const AOffset, AContent, AViewport: Single): Single;

/// <summary>Scroll offset that makes the range ATop..ABottom fully visible in a viewport of AViewport at
/// AOffset (the smallest change).</summary>
function FmrScrollIntoView(const AOffset, ATop, ABottom, AViewport: Single): Single;

implementation

{ TFmrStatusPanelMeasure }

class function TFmrStatusPanelMeasure.Create(const ASide: TFmrStatusPanelSide; const AWidth, AMinWidth: Single;
  const AStretch, AVisible: Boolean): TFmrStatusPanelMeasure;
begin
  Result.Side := ASide;
  Result.Width := AWidth;
  Result.MinWidth := AMinWidth;
  Result.Stretch := AStretch;
  Result.Visible := AVisible;
end;

{ TFmrStatusPanelSlot }

function TFmrStatusPanelSlot.Right: Single;
begin
  Result := Left + Width;
end;

function FmrLayoutStatusPanels(const APanels: array of TFmrStatusPanelMeasure; const AStart, AEnd: Single;
  const ASpacing: Single): TArray<TFmrStatusPanelSlot>;
var
  N, I, ShownCount, StretchCount: Integer;
  W: TArray<Single>;
  Avail, Total, Over, Free, Cut, X, RightTotal, LeftEnd: Single;

  function MinOf(const AIndex: Integer): Single;
  begin
    Result := Max(0, APanels[AIndex].MinWidth);
  end;

  procedure ShrinkTo(const AIndex: Integer);
  begin
    if (Over <= 0) or not Result[AIndex].Shown then
      Exit;
    Cut := Min(Over, W[AIndex] - Min(W[AIndex], MinOf(AIndex)));
    if Cut > 0 then
    begin
      W[AIndex] := W[AIndex] - Cut;
      Over := Over - Cut;
    end;
  end;

  procedure HidePanel(const AIndex: Integer);
  begin
    if (Over <= 0) or not Result[AIndex].Shown then
      Exit;
    Result[AIndex].Shown := False;
    if ShownCount > 1 then
      Over := Over - W[AIndex] - ASpacing
    else
      Over := Over - W[AIndex];
    Dec(ShownCount);
    W[AIndex] := 0;
  end;

begin
  N := Length(APanels);
  SetLength(Result, N);
  SetLength(W, N);
  Avail := Max(0, AEnd - AStart);
  ShownCount := 0;
  StretchCount := 0;
  Total := 0;
  for I := 0 to N - 1 do
  begin
    Result[I].Left := AStart;
    Result[I].Width := 0;
    Result[I].Shown := APanels[I].Visible;
    if not Result[I].Shown then
      Continue;
    W[I] := Max(0, Max(APanels[I].Width, APanels[I].MinWidth));
    Total := Total + W[I];
    Inc(ShownCount);
    if APanels[I].Stretch then
      Inc(StretchCount);
  end;
  if ShownCount > 1 then
    Total := Total + (ShownCount - 1) * ASpacing;

  if Total <= Avail then
  begin
    Free := Avail - Total;
    if (StretchCount > 0) and (Free > 0) then
      for I := 0 to N - 1 do
        if Result[I].Shown and APanels[I].Stretch then
          W[I] := W[I] + Free / StretchCount;
  end
  else
  begin
    Over := Total - Avail;
    // 1. stretch panels, 2. left panels from the last one: down to their minimum width
    for I := N - 1 downto 0 do
      if APanels[I].Stretch then
        ShrinkTo(I);
    for I := N - 1 downto 0 do
      if APanels[I].Side = TFmrStatusPanelSide.Left then
        ShrinkTo(I);
    // 3. hide left panels from the last one
    for I := N - 1 downto 0 do
      if APanels[I].Side = TFmrStatusPanelSide.Left then
        HidePanel(I);
    // 4. right panels from the first one: shrink, then hide
    for I := 0 to N - 1 do
      if APanels[I].Side = TFmrStatusPanelSide.Right then
        ShrinkTo(I);
    for I := 0 to N - 1 do
      if APanels[I].Side = TFmrStatusPanelSide.Right then
        HidePanel(I);
  end;

  // place the left group
  X := AStart;
  LeftEnd := AStart;
  for I := 0 to N - 1 do
    if Result[I].Shown and (APanels[I].Side = TFmrStatusPanelSide.Left) then
    begin
      Result[I].Left := X;
      Result[I].Width := W[I];
      LeftEnd := X + W[I];
      X := LeftEnd + ASpacing;
    end;
  // place the right group so that it ends at AEnd (never over the left group)
  RightTotal := 0;
  ShownCount := 0;
  for I := 0 to N - 1 do
    if Result[I].Shown and (APanels[I].Side = TFmrStatusPanelSide.Right) then
    begin
      if ShownCount > 0 then
        RightTotal := RightTotal + ASpacing;
      RightTotal := RightTotal + W[I];
      Inc(ShownCount);
    end;
  X := AEnd - RightTotal;
  if (LeftEnd > AStart) and (X < LeftEnd + ASpacing) then
    X := LeftEnd + ASpacing;
  X := Max(X, AStart);
  for I := 0 to N - 1 do
    if Result[I].Shown and (APanels[I].Side = TFmrStatusPanelSide.Right) then
    begin
      Result[I].Left := X;
      Result[I].Width := W[I];
      X := X + W[I] + ASpacing;
    end;
end;

{ zoom }

function FmrZoomToFraction(const AZoom, AMin, AMax: Integer): Single;
var
  Z: Integer;
begin
  if AMax <= AMin then
    Exit(0);
  Z := EnsureRange(AZoom, AMin, AMax);
  if (AMin < 100) and (AMax > 100) then
  begin
    if Z <= 100 then
      Result := 0.5 * (Z - AMin) / (100 - AMin)
    else
      Result := 0.5 + 0.5 * (Z - 100) / (AMax - 100);
  end
  else
    Result := (Z - AMin) / (AMax - AMin);
end;

function FmrFractionToZoom(const AFraction: Single; const AMin, AMax: Integer): Integer;
var
  F: Single;
begin
  if AMax <= AMin then
    Exit(AMin);
  F := EnsureRange(AFraction, 0, 1);
  if (AMin < 100) and (AMax > 100) then
  begin
    if F <= 0.5 then
      Result := Round(AMin + (100 - AMin) * F / 0.5)
    else
      Result := Round(100 + (AMax - 100) * (F - 0.5) / 0.5);
  end
  else
    Result := Round(AMin + (AMax - AMin) * F);
  Result := EnsureRange(Result, AMin, AMax);
end;

function FmrZoomStep(const AZoom, AStep, AMin, AMax: Integer; const AUp: Boolean): Integer;
var
  S: Integer;
begin
  S := Max(1, AStep);
  if AUp then
    Result := (AZoom div S + 1) * S
  else if AZoom mod S = 0 then
    Result := AZoom - S
  else
    Result := (AZoom div S) * S;
  Result := EnsureRange(Result, AMin, Max(AMin, AMax));
end;

{ navigation }

function FmrNextSelectable(const ASelectable: array of Boolean; const ACurrent, ADelta: Integer;
  const AWrap: Boolean): Integer;
var
  N, I, Step, Steps: Integer;
begin
  N := Length(ASelectable);
  Result := ACurrent;
  if N = 0 then
    Exit(-1);
  if ADelta < 0 then
    Step := -1
  else
    Step := 1;
  if (ACurrent < 0) or (ACurrent >= N) then
  begin
    if Step > 0 then
      I := -1
    else
      I := N;
  end
  else
    I := ACurrent;
  for Steps := 1 to N do
  begin
    I := I + Step;
    if (I < 0) or (I >= N) then
    begin
      if not AWrap then
        Break;
      if I < 0 then
        I := N - 1
      else
        I := 0;
    end;
    if I = ACurrent then
      Break;
    if ASelectable[I] then
      Exit(I);
  end;
  if (ACurrent >= 0) and (ACurrent < N) and ASelectable[ACurrent] then
    Result := ACurrent
  else if (ACurrent < 0) or (ACurrent >= N) then
    Result := -1;
end;

function FmrEdgeSelectable(const ASelectable: array of Boolean; const ALast: Boolean): Integer;
begin
  if ALast then
    Result := FmrNextSelectable(ASelectable, -1, -1, False)
  else
    Result := FmrNextSelectable(ASelectable, -1, 1, False);
end;

{ scrolling }

function FmrClampScroll(const AOffset, AContent, AViewport: Single): Single;
begin
  Result := EnsureRange(AOffset, 0, Max(0, AContent - AViewport));
end;

function FmrScrollIntoView(const AOffset, ATop, ABottom, AViewport: Single): Single;
begin
  Result := AOffset;
  if ATop < Result then
    Result := ATop
  else if ABottom > Result + AViewport then
    Result := ABottom - AViewport;
  Result := Max(0, Result);
end;

end.
