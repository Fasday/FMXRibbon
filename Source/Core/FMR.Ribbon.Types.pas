{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Enumerations and helpers shared by the ribbon units  }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.Types;

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils;

type
  /// <summary>How a link is shown inside a ribbon group.</summary>
  TFmrViewLevel = (
    /// <summary>Large glyph with the caption below it; the item takes the full content height.</summary>
    Large,
    /// <summary>Small glyph with the caption to the right; one row of a three-row column.</summary>
    SmallWithText,
    /// <summary>Small glyph only (editors: the control without its caption label).</summary>
    Small);

  TFmrViewLevels = set of TFmrViewLevel;

  /// <summary>Behavior of a button item.</summary>
  TFmrButtonStyle = (
    /// <summary>Plain command button.</summary>
    Default,
    /// <summary>Toggle button: every click flips Down (radio behavior with GroupIndex).</summary>
    Check,
    /// <summary>The whole button opens the drop-down (DropDownLinks / OnDropDown).</summary>
    DropDown,
    /// <summary>Split button: the main part executes the command, the arrow part opens the drop-down.</summary>
    Split);

  /// <summary>Membership of a link in a button group (a row of small buttons drawn as one segmented control).
  /// Start begins a new button group; Member continues the group of the previous link.</summary>
  TFmrButtonGroupPosition = (None, Start, Member);

  /// <summary>What changed in an item; decides how much of the ribbon must be updated.</summary>
  TFmrItemChange = (
    /// <summary>Size or presence changed (caption, glyph presence, visibility, style, width): re-layout.</summary>
    Layout,
    /// <summary>Only the look changed (enabled, down, glyph content, color): repaint.</summary>
    Paint,
    /// <summary>The value of an editor item changed (text, item index, number): sync its controls.</summary>
    Value);

  /// <summary>Where the quick access toolbar is shown.</summary>
  TFmrQATPosition = (AboveRibbon, BelowRibbon);

  /// <summary>What merging does with a tab or a group of the merged (source) ribbon.</summary>
  TFmrMergeKind = (
    /// <summary>Merge into the target tab/group with the same name or caption; add when there is none.</summary>
    Merge,
    /// <summary>Always add as a new tab/group.</summary>
    Add,
    /// <summary>Hide the matching target tab/group and add this one in its place.</summary>
    Replace,
    /// <summary>Hide the matching target tab/group; this one is not added.</summary>
    Remove);

  /// <summary>Classic (three rows, group captions) or simplified (single line) ribbon.</summary>
  TFmrRibbonDisplayMode = (Classic, Simplified);

  /// <summary>"Ribbon display options" of the caption row.</summary>
  TFmrRibbonShowMode = (
    /// <summary>Tabs and the commands of the active tab are always shown.</summary>
    TabsAndCommands,
    /// <summary>Only the tab row is shown; clicking a tab shows its commands over the document (minimized).</summary>
    TabsOnly,
    /// <summary>Full screen: the ribbon is hidden until the top edge of the window is clicked.</summary>
    AutoHide);

  /// <summary>Kind of a link for the layout calculator.</summary>
  TFmrLayoutItemKind = (
    /// <summary>A button-like item painted by the ribbon (button, sub item, static, check, color).</summary>
    Button,
    /// <summary>An item shown with a real FMX control (editors, combo boxes, any TControl).</summary>
    Control,
    /// <summary>An in-ribbon gallery whose column count is reduced when space is short.</summary>
    Gallery,
    /// <summary>A vertical separator line between columns.</summary>
    Separator);

  /// <summary>Place of a link in the simplified (single line) ribbon.</summary>
  TFmrSimplifiedVisibility = (
    /// <summary>In the line while it fits, then in the overflow ("…") menu.</summary>
    Auto,
    /// <summary>Kept in the line as long as possible (moved to the overflow menu last).</summary>
    Always,
    /// <summary>Always in the overflow menu.</summary>
    Overflow,
    /// <summary>Not shown in the simplified ribbon.</summary>
    Never);

  /// <summary>Where gallery entries show their caption.</summary>
  TFmrGalleryCaptionPosition = (None, Bottom, Right);

  /// <summary>Selection behavior of a gallery.</summary>
  TFmrGallerySelectionMode = (None, Single);

  /// <summary>Kind of key tips generated for a scope: letters from captions or numbers (quick access toolbar).
  /// </summary>
  TFmrKeyTipStyle = (Letters, Numbers);

const
  FmrAllViewLevels = [TFmrViewLevel.Large, TFmrViewLevel.SmallWithText, TFmrViewLevel.Small];
  FmrSmallViewLevels = [TFmrViewLevel.SmallWithText, TFmrViewLevel.Small];

/// <summary>The largest level of ALevels (Large before SmallWithText before Small); SmallWithText for an empty set.
/// </summary>
function FmrLargestViewLevel(const ALevels: TFmrViewLevels): TFmrViewLevel;
/// <summary>The largest level of ALevels smaller than ALevel; returns False when there is none.</summary>
function FmrNextSmallerViewLevel(const ALevels: TFmrViewLevels; const ALevel: TFmrViewLevel;
  out ANext: TFmrViewLevel): Boolean;
/// <summary>'Large,SmallWithText' style text of a set (used by the JSON persistence).</summary>
function FmrViewLevelsToString(const ALevels: TFmrViewLevels): string;
function FmrStringToViewLevels(const AText: string): TFmrViewLevels;

implementation

uses
  System.TypInfo;

function FmrLargestViewLevel(const ALevels: TFmrViewLevels): TFmrViewLevel;
var
  L: TFmrViewLevel;
begin
  for L := Low(TFmrViewLevel) to High(TFmrViewLevel) do
    if L in ALevels then
      Exit(L);
  Result := TFmrViewLevel.SmallWithText;
end;

function FmrNextSmallerViewLevel(const ALevels: TFmrViewLevels; const ALevel: TFmrViewLevel;
  out ANext: TFmrViewLevel): Boolean;
var
  L: TFmrViewLevel;
begin
  for L := Succ(Low(TFmrViewLevel)) to High(TFmrViewLevel) do
    if (L > ALevel) and (L in ALevels) then
    begin
      ANext := L;
      Exit(True);
    end;
  ANext := ALevel;
  Result := False;
end;

function FmrViewLevelsToString(const ALevels: TFmrViewLevels): string;
var
  L: TFmrViewLevel;
begin
  Result := '';
  for L := Low(TFmrViewLevel) to High(TFmrViewLevel) do
    if L in ALevels then
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + GetEnumName(TypeInfo(TFmrViewLevel), Ord(L));
    end;
end;

function FmrStringToViewLevels(const AText: string): TFmrViewLevels;
var
  S: string;
  V: Integer;
begin
  Result := [];
  for S in AText.Split([',', ' ', ';'], TStringSplitOptions.ExcludeEmpty) do
  begin
    V := GetEnumValue(TypeInfo(TFmrViewLevel), S.Trim);
    if (V >= Ord(Low(TFmrViewLevel))) and (V <= Ord(High(TFmrViewLevel))) then
      Include(Result, TFmrViewLevel(V));
  end;
end;

end.
