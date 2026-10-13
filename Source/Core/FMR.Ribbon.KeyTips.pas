{*******************************************************}
{                                                       }
{  FMR Ribbon for FireMonkey                            }
{  Key tips: automatic assignment and typed matching    }
{                                                       }
{  MIT License. Copyright (c) 2026 Fasday               }
{                                                       }
{*******************************************************}

unit FMR.Ribbon.KeyTips;

/// Logic of key tips (the visual part lives in the ribbon). A scope is a set of key tips shown at the same time
/// (the tabs and the QAT; the links of the active tab; the links of a menu). TFmrKeyTipAssigner gives every entry of
/// a scope a key tip of one or two characters: explicit key tips are kept, the others come from the caption
/// (the letter after '&', the first letter, the initials of two words, the first letter with another letter of the
/// caption) and fall back to free letters. Generated tips are unique and prefix-free: no tip is the first
/// character of another, so a typed character is never ambiguous. TFmrKeyTipMatcher follows what the user types.

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Character, System.Generics.Collections, FMR.Ribbon.Types;

type
  /// <summary>One element of a scope.</summary>
  TFmrKeyTipEntry = record
    Caption: string;
    /// <summary>Key tip set by the developer (kept as is, upper-cased).</summary>
    Explicit: string;
    /// <summary>Free for the caller (index, pointer to the link...).</summary>
    Data: NativeInt;
    /// <summary>Assigned key tip.</summary>
    KeyTip: string;
    class function Create(const ACaption: string; const AExplicit: string = '';
      const AData: NativeInt = 0): TFmrKeyTipEntry; static;
  end;

  TFmrKeyTipAssigner = class
  private
    class function Normalize(const S: string): string; static;
    class function CaptionLetters(const ACaption: string): string; static;
    class function AcceleratorOf(const ACaption: string): Char; static;
    class function Words(const ACaption: string): TArray<string>; static;
    class function Conflicts(const ATip: string; const AUsed: TList<string>): Boolean; static;
  public
    /// <summary>Assigns KeyTip of every entry. Letters: from captions; Numbers: 1..9, then 09..01, then 0A..0Z
    /// (quick access toolbar style). AReserved: tips already used in the scope (e.g. by another source).</summary>
    class procedure Assign(var AEntries: TArray<TFmrKeyTipEntry>;
      const AStyle: TFmrKeyTipStyle = TFmrKeyTipStyle.Letters; const AReserved: TArray<string> = nil); static;
    /// <summary>True when no two tips are equal and no generated tip is a prefix of another.</summary>
    class function IsPrefixFree(const ATips: TArray<string>): Boolean; static;
  end;

  TFmrKeyTipMatch = (
    /// <summary>The typed text matches no key tip (the character is ignored).</summary>
    None,
    /// <summary>The typed text is the start of one or more key tips: wait for the next character.</summary>
    Partial,
    /// <summary>The typed text is a whole key tip: execute it.</summary>
    Complete);

  /// <summary>Follows the characters typed while key tips are shown.</summary>
  TFmrKeyTipMatcher = class
  private
    FTips: TArray<string>;
    FTyped: string;
    FMatchedIndex: Integer;
  public
    constructor Create(const ATips: TArray<string>);
    /// <summary>Starts again with new tips.</summary>
    procedure Reset(const ATips: TArray<string>); overload;
    /// <summary>Clears the typed text.</summary>
    procedure Reset; overload;
    /// <summary>Adds a character. An unmatched character is not kept (Typed is unchanged).</summary>
    function Press(const AChar: Char): TFmrKeyTipMatch;
    /// <summary>Removes the last typed character; False when nothing was typed (the scope should go back).
    /// </summary>
    function Backspace: Boolean;
    /// <summary>True when the tip at AIndex is still possible (shown); all are while nothing is typed.</summary>
    function IsCandidate(const AIndex: Integer): Boolean;
    function CandidateCount: Integer;
    property Typed: string read FTyped;
    /// <summary>Index of the completed tip after Press returned Complete, otherwise -1.</summary>
    property MatchedIndex: Integer read FMatchedIndex;
    property Tips: TArray<string> read FTips;
  end;

implementation

{ TFmrKeyTipEntry }

class function TFmrKeyTipEntry.Create(const ACaption, AExplicit: string; const AData: NativeInt): TFmrKeyTipEntry;
begin
  Result.Caption := ACaption;
  Result.Explicit := AExplicit;
  Result.Data := AData;
  Result.KeyTip := '';
end;

{ TFmrKeyTipAssigner }

class function TFmrKeyTipAssigner.Normalize(const S: string): string;
begin
  Result := S.Trim.ToUpper;
end;

class function TFmrKeyTipAssigner.AcceleratorOf(const ACaption: string): Char;
var
  I: Integer;
begin
  I := 1;
  while I < Length(ACaption) do
  begin
    if ACaption[I] = '&' then
    begin
      if ACaption[I + 1] = '&' then
        Inc(I)
      else if ACaption[I + 1].IsLetterOrDigit then
        Exit(ACaption[I + 1].ToUpper);
    end;
    Inc(I);
  end;
  Result := #0;
end;

class function TFmrKeyTipAssigner.CaptionLetters(const ACaption: string): string;
var
  C: Char;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for C in ACaption do
      if C.IsLetterOrDigit then
        SB.Append(C.ToUpper);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TFmrKeyTipAssigner.Words(const ACaption: string): TArray<string>;
var
  W: string;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    for W in ACaption.Split([' ', '-', '_', '/', '\', '.', ',', '&', '(', ')'], TStringSplitOptions.ExcludeEmpty) do
      if CaptionLetters(W) <> '' then
        L.Add(CaptionLetters(W));
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

class function TFmrKeyTipAssigner.Conflicts(const ATip: string; const AUsed: TList<string>): Boolean;
var
  U: string;
begin
  for U in AUsed do
    if U.StartsWith(ATip) or ATip.StartsWith(U) then
      Exit(True);
  Result := False;
end;

class function TFmrKeyTipAssigner.IsPrefixFree(const ATips: TArray<string>): Boolean;
var
  I, J: Integer;
begin
  for I := 0 to High(ATips) do
    for J := 0 to High(ATips) do
      if (I <> J) and (ATips[I] <> '') and (ATips[J] <> '') and ATips[J].StartsWith(ATips[I]) then
        Exit(False);
  Result := True;
end;

class procedure TFmrKeyTipAssigner.Assign(var AEntries: TArray<TFmrKeyTipEntry>; const AStyle: TFmrKeyTipStyle;
  const AReserved: TArray<string>);
const
  Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  Digits = '123456789';
var
  Used: TList<string>;
  Pending: TList<Integer>;
  I, N: Integer;
  S: string;

  function TryTake(const AIndex: Integer; const ATip: string): Boolean;
  begin
    Result := (ATip <> '') and not Conflicts(ATip, Used);
    if Result then
    begin
      AEntries[AIndex].KeyTip := ATip;
      Used.Add(ATip);
    end;
  end;

  // Single characters still free, in caption order, then the alphabet.
  function FreeSingles(const ACaption: string): TArray<string>;
  var
    C: Char;
    L: TList<string>;
  begin
    L := TList<string>.Create;
    try
      for C in CaptionLetters(ACaption) + Alphabet + Digits do
        if not L.Contains(C) then
          L.Add(C);
      Result := L.ToArray;
    finally
      L.Free;
    end;
  end;

  function NumberTip(const ANumber: Integer): string;
  begin
    if ANumber < 9 then
      Result := Digits[ANumber + 1]
    else if ANumber < 18 then
      Result := '0' + Digits[9 - (ANumber - 9)]
    else if ANumber - 18 < Length(Alphabet) then
      Result := '0' + Alphabet[ANumber - 18 + 1]
    else
      Result := '';
  end;

var
  W: TArray<string>;
  Letters, Tip: string;
  C: Char;
  J, K: Integer;
  Done: Boolean;
begin
  Used := TList<string>.Create;
  Pending := TList<Integer>.Create;
  try
    for S in AReserved do
      if Normalize(S) <> '' then
        Used.Add(Normalize(S));
    // Explicit tips first: kept even when they conflict with each other.
    for I := 0 to High(AEntries) do
    begin
      AEntries[I].KeyTip := Normalize(AEntries[I].Explicit);
      if AEntries[I].KeyTip <> '' then
        Used.Add(AEntries[I].KeyTip)
      else
        Pending.Add(I);
    end;

    if AStyle = TFmrKeyTipStyle.Numbers then
    begin
      N := 0;
      for I in Pending do
        repeat
          Tip := NumberTip(N);
          Inc(N);
          if Tip = '' then
            Break;
        until TryTake(I, Tip);
      Exit;
    end;

    // Pass 1a: the letter after '&' (explicit accelerator), first entry wins.
    for I in Pending.ToArray do
    begin
      C := AcceleratorOf(AEntries[I].Caption);
      if (C <> #0) and TryTake(I, C) then
        Pending.Remove(I);
    end;

    // Pass 1b: the first letter when no other pending caption starts with it. Entries sharing a first letter all
    // get two characters starting with it (HO for Home, HE for Help), which keeps the scope prefix-free.
    for I in Pending.ToArray do
    begin
      Letters := CaptionLetters(AEntries[I].Caption);
      if Letters = '' then
        Continue;
      Tip := Letters[1];
      Done := False;
      for K in Pending do
        if (K <> I) and CaptionLetters(AEntries[K].Caption).StartsWith(Tip) then
        begin
          Done := True;
          Break;
        end;
      if not Done and TryTake(I, Tip) then
        Pending.Remove(I);
    end;

    // Pass 2: two characters from the caption: initials of the first two words, then first letter + another one.
    for I in Pending.ToArray do
    begin
      Letters := CaptionLetters(AEntries[I].Caption);
      if Letters = '' then
        Continue;
      W := Words(AEntries[I].Caption);
      Done := False;
      if Length(W) >= 2 then
        Done := TryTake(I, W[0][1] + W[1][1]);
      J := 2;
      while not Done and (J <= Length(Letters)) do
      begin
        Done := TryTake(I, Letters[1] + Letters[J]);
        Inc(J);
      end;
      if Done then
        Pending.Remove(I);
    end;

    // Pass 3: any free single character, then any free pair.
    for I in Pending.ToArray do
    begin
      Done := False;
      for Tip in FreeSingles(AEntries[I].Caption) do
        if TryTake(I, Tip) then
        begin
          Done := True;
          Break;
        end;
      if not Done then
        for C in Alphabet + Digits do
        begin
          for K := 1 to Length(Alphabet + Digits) do
            if TryTake(I, C + (Alphabet + Digits)[K]) then
            begin
              Done := True;
              Break;
            end;
          if Done then
            Break;
        end;
    end;
  finally
    Pending.Free;
    Used.Free;
  end;
end;

{ TFmrKeyTipMatcher }

constructor TFmrKeyTipMatcher.Create(const ATips: TArray<string>);
begin
  inherited Create;
  Reset(ATips);
end;

procedure TFmrKeyTipMatcher.Reset(const ATips: TArray<string>);
var
  I: Integer;
begin
  SetLength(FTips, Length(ATips));
  for I := 0 to High(ATips) do
    FTips[I] := ATips[I].Trim.ToUpper;
  Reset;
end;

procedure TFmrKeyTipMatcher.Reset;
begin
  FTyped := '';
  FMatchedIndex := -1;
end;

function TFmrKeyTipMatcher.Press(const AChar: Char): TFmrKeyTipMatch;
var
  Candidate: string;
  I, Exact, Partial: Integer;
begin
  FMatchedIndex := -1;
  Candidate := FTyped + AChar.ToUpper;
  Exact := -1;
  Partial := 0;
  for I := 0 to High(FTips) do
    if FTips[I] <> '' then
    begin
      if FTips[I] = Candidate then
      begin
        if Exact < 0 then
          Exact := I;
      end
      else if FTips[I].StartsWith(Candidate) then
        Inc(Partial);
    end;
  // An exact match wins over longer tips with the same start (only possible with conflicting explicit tips).
  if Exact >= 0 then
  begin
    FTyped := Candidate;
    FMatchedIndex := Exact;
    Result := TFmrKeyTipMatch.Complete;
  end
  else if Partial > 0 then
  begin
    FTyped := Candidate;
    Result := TFmrKeyTipMatch.Partial;
  end
  else
    Result := TFmrKeyTipMatch.None;
end;

function TFmrKeyTipMatcher.Backspace: Boolean;
begin
  FMatchedIndex := -1;
  Result := FTyped <> '';
  if Result then
    FTyped := FTyped.Substring(0, FTyped.Length - 1);
end;

function TFmrKeyTipMatcher.IsCandidate(const AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex <= High(FTips)) and (FTips[AIndex] <> '') and FTips[AIndex].StartsWith(FTyped);
end;

function TFmrKeyTipMatcher.CandidateCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FTips) do
    if IsCandidate(I) then
      Inc(Result);
end;

end.
