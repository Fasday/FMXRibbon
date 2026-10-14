unit FmrStackTrace;

/// Stack traces for Exception.StackTrace (diagnostics of the stress runner): the raise site is captured with
/// RtlCaptureStackBackTrace and resolved with the detailed .map file next to the executable (build.ps1 passes -GD).

interface

/// "Unit.Routine (Unit.pas:123)" for a code address; the hex address when the map file has no entry.
function FmrAddressInfo(const AAddress: Pointer): string;
/// Stack of the last FreeMem that failed (the source of an EInvalidPointer, which has no stack of its own).
function FmrLastBadFree: string;
/// Address of a public symbol of the map file (e.g. a class var of an implementation-only class); nil when absent.
function FmrMapSymbol(const AName: string): Pointer;
/// Allocation tracking (main thread): every block allocated after FmrTrackStart is recorded with its stack until it
/// is freed; FmrTrackReport groups the blocks still alive by stack (the biggest groups first) and stops tracking.
procedure FmrTrackStart;
function FmrTrackReport(const ATop: Integer = 12): string;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Math, System.Generics.Collections, System.Generics.Defaults;

function RtlCaptureStackBackTrace(FramesToSkip, FramesToCapture: ULONG; BackTrace: Pointer;
  BackTraceHash: PULONG): USHORT; stdcall; external kernel32;

type
  TPublic = record
    Offset: NativeUInt;
    Name: string;
  end;

  TLine = record
    Offset: NativeUInt;
    Line: Integer;
    FileIndex: Integer;
  end;

  TStackInfo = record
    Count: Integer;
    Frames: array[0..95] of Pointer;
  end;
  PStackInfo = ^TStackInfo;

var
  GLoaded: Boolean;
  GPublics: TList<TPublic>;
  GLines: TList<TLine>;
  GFiles: TStringList;
  GCodeRva: NativeUInt = $1000;

function ParseHex(const S: string; out V: NativeUInt): Boolean;
var
  I: Integer;
  C: Char;
  D: Integer;
begin
  V := 0;
  Result := S <> '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '0'..'9': D := Ord(C) - Ord('0');
      'A'..'F': D := Ord(C) - Ord('A') + 10;
      'a'..'f': D := Ord(C) - Ord('a') + 10;
    else
      Exit(False);
    end;
    V := V * 16 + NativeUInt(D);
  end;
end;

procedure LoadMap;
var
  Lines: TStringList;
  I, J, FileIdx, P: Integer;
  S, Seg: string;
  Parts: TArray<string>;
  Pub: TPublic;
  L: TLine;
  V, Base: NativeUInt;
  InPublics: Boolean;
begin
  GLoaded := True;
  GPublics := TList<TPublic>.Create;
  GLines := TList<TLine>.Create;
  GFiles := TStringList.Create;
  if not FileExists(ChangeFileExt(ParamStr(0), '.map')) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ChangeFileExt(ParamStr(0), '.map'));
    InPublics := False;
    FileIdx := -1;
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I];
      if (I < 10) and S.Contains('.text') and S.Trim.StartsWith('0001:') then
      begin
        // " 0001:0000000140001000 00B25A04H .text CODE": start of the code segment (image base + RVA)
        Seg := S.Trim.Substring(5, S.Trim.IndexOf(' ') - 5);
        if ParseHex(Seg, V) then
        begin
          Base := V and not NativeUInt($FFFFF);
          GCodeRva := V - Base;
        end;
        Continue;
      end;
      if S.Contains('Publics by Value') then
      begin
        InPublics := True;
        Continue;
      end;
      if S.StartsWith('Line numbers for ') then
      begin
        InPublics := False;
        P := S.IndexOf('(');
        if P > 0 then
          FileIdx := GFiles.Add(S.Substring(P + 1, S.IndexOf(')') - P - 1))
        else
          FileIdx := GFiles.Add('?');
        Continue;
      end;
      if InPublics then
      begin
        S := S.Trim;
        if S.StartsWith('0001:') then
        begin
          P := S.IndexOf(' ');
          if (P > 5) and ParseHex(S.Substring(5, P - 5), V) then
          begin
            Pub.Offset := V;
            Pub.Name := S.Substring(P).Trim;
            GPublics.Add(Pub);
          end;
        end;
      end
      else if (FileIdx >= 0) and (S.Trim <> '') then
      begin
        Parts := S.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
        J := 0;
        while J + 1 < Length(Parts) do
        begin
          if Parts[J + 1].StartsWith('0001:') and ParseHex(Parts[J + 1].Substring(5), V) then
          begin
            L.Offset := V;
            L.Line := StrToIntDef(Parts[J], 0);
            L.FileIndex := FileIdx;
            GLines.Add(L);
          end;
          Inc(J, 2);
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
  GPublics.Sort(TComparer<TPublic>.Construct(
    function(const A, B: TPublic): Integer
    begin
      if A.Offset < B.Offset then Result := -1 else if A.Offset > B.Offset then Result := 1 else Result := 0;
    end));
  GLines.Sort(TComparer<TLine>.Construct(
    function(const A, B: TLine): Integer
    begin
      if A.Offset < B.Offset then Result := -1 else if A.Offset > B.Offset then Result := 1 else Result := 0;
    end));
end;

function FmrAddressInfo(const AAddress: Pointer): string;
var
  Off: NativeUInt;
  Lo, Hi, Mid, Found: Integer;
begin
  if not GLoaded then
    LoadMap;
  Result := Format('$%p', [AAddress]);
  if NativeUInt(AAddress) < HInstance + GCodeRva then
    Exit;
  Off := NativeUInt(AAddress) - HInstance - GCodeRva;
  Lo := 0;
  Hi := GPublics.Count - 1;
  Found := -1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if GPublics[Mid].Offset <= Off then
    begin
      Found := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
  if Found >= 0 then
    Result := GPublics[Found].Name;
  Lo := 0;
  Hi := GLines.Count - 1;
  Found := -1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if GLines[Mid].Offset <= Off then
    begin
      Found := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
  if Found >= 0 then
    Result := Result + Format(' (%s:%d)', [GFiles[GLines[Found].FileIndex], GLines[Found].Line]);
end;

function FmrMapSymbol(const AName: string): Pointer;
var
  Lines: TStringList;
  I, Seg, Seg2: Integer;
  S, T: string;
  Starts: array[1..9] of NativeUInt;
  V, Off: NativeUInt;
begin
  Result := nil;
  if not FileExists(ChangeFileExt(ParamStr(0), '.map')) then
    Exit;
  FillChar(Starts, SizeOf(Starts), 0);
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ChangeFileExt(ParamStr(0), '.map'));
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I].Trim;
      if (I < 12) and (Length(S) > 6) and (S[5] = ':') and CharInSet(S[1], ['0'..'9']) then
      begin
        Seg := StrToIntDef(S.Substring(0, 4), 0);
        T := S.Substring(5, S.IndexOf(' ') - 5);
        if (Seg in [1..9]) and ParseHex(T, V) then
          Starts[Seg] := V;
        Continue;
      end;
      if S.EndsWith(' ' + AName) and (Length(S) > 14) and (S[5] = ':') then
      begin
        Seg := StrToIntDef(S.Substring(0, 4), 0);
        T := S.Substring(5, S.IndexOf(' ') - 5);
        if (Seg in [1..9]) and ParseHex(T, Off) then
        begin
          // the segment table gives image base + RVA; the lowest start (.tls) is the image base
          V := High(NativeUInt);
          for Seg2 := Low(Starts) to High(Starts) do
            if (Starts[Seg2] <> 0) and (Starts[Seg2] < V) then
              V := Starts[Seg2];
          Exit(Pointer(HInstance + (Starts[Seg] - V) + Off));
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function GetStackInfo(P: PExceptionRecord): Pointer;
var
  Info: PStackInfo;
{$IFDEF CPUX86}
  Cur, Top: PNativeUInt;
  Lo, Hi: NativeUInt;
  Tib: PNativeUInt;
{$ENDIF}
begin
  New(Info);
  {$IFDEF CPUX86}
  // Win32 code has no stack frames: the faulting address, then every value on the stack that points into the code
  // (a "raw" trace, noisy but enough to find the caller chain).
  Info.Count := 0;
  if P <> nil then
  begin
    Info.Frames[0] := Pointer(NativeUInt(P.ExceptionAddress) + 1);
    Info.Count := 1;
  end;
  if not GLoaded then
    LoadMap;
  Lo := HInstance + GCodeRva;
  if GPublics.Count > 0 then
    Hi := Lo + GPublics.Last.Offset + $10000
  else
    Hi := Lo + $1000000;
  asm
    mov Cur, esp
    mov eax, dword ptr fs:[4]
    mov Tib, eax
  end;
  Top := Tib;
  while (NativeUInt(Cur) < NativeUInt(Top)) and (Info.Count < Length(Info.Frames)) do
  begin
    if (Cur^ > Lo) and (Cur^ < Hi) then
    begin
      Info.Frames[Info.Count] := Pointer(Cur^);
      Inc(Info.Count);
    end;
    Inc(Cur);
  end;
  {$ELSE}
  Info.Count := RtlCaptureStackBackTrace(1, Length(Info.Frames), @Info.Frames[0], nil);
  {$ENDIF}
  Result := Info;
end;

function GetStackString(Info: Pointer): string;
var
  I: Integer;
  SB: TStringBuilder;
  S: string;
begin
  Result := '';
  if Info = nil then
    Exit;
  SB := TStringBuilder.Create;
  try
    for I := 0 to PStackInfo(Info).Count - 1 do
    begin
      S := FmrAddressInfo(Pointer(NativeUInt(PStackInfo(Info).Frames[I]) - 1));
      // the RTL's own raise machinery says nothing
      if S.StartsWith('System.@') or S.StartsWith('System.SysUtils.') and S.Contains('StackInfo') then
        Continue;
      SB.Append('      at ').Append(S).AppendLine;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure CleanUpStackInfo(Info: Pointer);
begin
  Dispose(PStackInfo(Info));
end;

var
  GOldMM: TMemoryManagerEx;
  GBadFree: TStackInfo;
  GBadFreeSet: Boolean;

const
  TrackSlots = 1 shl 18;
  TrackFrames = 30;

type
  TTrackEntry = record
    P: Pointer;
    Size: NativeInt;
    Frames: array[0..TrackFrames - 1] of Pointer;
  end;
  TTrackTable = array[0..TrackSlots - 1] of TTrackEntry;
  PTrackTable = ^TTrackTable;

var
  GTrack: PTrackTable;
  GTracking: Boolean;
  GInTrack: Boolean;

const
  Tombstone = Pointer(1);

procedure TrackAdd(const P: Pointer; const ASize: NativeInt);
var
  I, N: NativeUInt;
begin
  if (P = nil) or GInTrack or (GetCurrentThreadId <> MainThreadID) then
    Exit;
  GInTrack := True;
  try
    I := (NativeUInt(P) shr 4) and (TrackSlots - 1);
    for N := 1 to TrackSlots do
    begin
      if (GTrack[I].P = nil) or (GTrack[I].P = Tombstone) then
      begin
        GTrack[I].P := P;
        GTrack[I].Size := ASize;
        FillChar(GTrack[I].Frames, SizeOf(GTrack[I].Frames), 0);
        RtlCaptureStackBackTrace(2, TrackFrames, @GTrack[I].Frames[0], nil);
        Exit;
      end;
      I := (I + 1) and (TrackSlots - 1);
    end;
  finally
    GInTrack := False;
  end;
end;

procedure TrackRemove(const P: Pointer);
var
  I, N: NativeUInt;
begin
  if (P = nil) or GInTrack or (GetCurrentThreadId <> MainThreadID) then
    Exit;
  I := (NativeUInt(P) shr 4) and (TrackSlots - 1);
  for N := 1 to TrackSlots do
  begin
    if GTrack[I].P = nil then
      Exit;
    if GTrack[I].P = P then
    begin
      GTrack[I].P := Tombstone;
      Exit;
    end;
    I := (I + 1) and (TrackSlots - 1);
  end;
end;

function TrackedGetMem(Size: NativeInt): Pointer;
begin
  Result := GOldMM.GetMem(Size);
  if GTracking then
    TrackAdd(Result, Size);
end;

function TrackedAllocMem(Size: NativeInt): Pointer;
begin
  Result := GOldMM.AllocMem(Size);
  if GTracking then
    TrackAdd(Result, Size);
end;

function TrackedReallocMem(P: Pointer; Size: NativeInt): Pointer;
begin
  if GTracking then
    TrackRemove(P);
  Result := GOldMM.ReallocMem(P, Size);
  if GTracking then
    TrackAdd(Result, Size);
end;

function CheckedFreeMem(P: Pointer): Integer;
begin
  if GTracking then
    TrackRemove(P);
  Result := GOldMM.FreeMem(P);
  if Result <> 0 then
  begin
    GBadFree.Count := RtlCaptureStackBackTrace(1, Length(GBadFree.Frames), @GBadFree.Frames[0], nil);
    GBadFreeSet := True;
  end;
end;

procedure FmrTrackStart;
begin
  if GTrack = nil then
    GTrack := VirtualAlloc(nil, SizeOf(TTrackTable), MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE)
  else
    FillChar(GTrack^, SizeOf(TTrackTable), 0);
  GTracking := GTrack <> nil;
end;

function FmrTrackReport(const ATop: Integer): string;
type
  TGroup = record
    First: Integer;
    Count: Integer;
    Bytes: NativeInt;
  end;
var
  Groups: TList<TGroup>;
  I, J, K: Integer;
  G: TGroup;
  Found: Boolean;
  S, Line: string;
  Total: NativeInt;
begin
  GTracking := False;
  Result := '';
  if GTrack = nil then
    Exit;
  Groups := TList<TGroup>.Create;
  try
    Total := 0;
    for I := 0 to TrackSlots - 1 do
      if (GTrack[I].P <> nil) and (GTrack[I].P <> Tombstone) then
      begin
        Inc(Total, GTrack[I].Size);
        Found := False;
        for J := 0 to Groups.Count - 1 do
          if CompareMem(@GTrack[Groups[J].First].Frames[0], @GTrack[I].Frames[0], SizeOf(GTrack[I].Frames)) then
          begin
            G := Groups[J];
            Inc(G.Count);
            Inc(G.Bytes, GTrack[I].Size);
            Groups[J] := G;
            Found := True;
            Break;
          end;
        if not Found and (Groups.Count < 4000) then
        begin
          G.First := I;
          G.Count := 1;
          G.Bytes := GTrack[I].Size;
          Groups.Add(G);
        end;
      end;
    Groups.Sort(TComparer<TGroup>.Construct(
      function(const A, B: TGroup): Integer
      begin
        Result := B.Bytes - A.Bytes;
      end));
    Result := Format('alive: %d bytes in %d stacks', [Total, Groups.Count]);
    for J := 0 to Min(ATop, Groups.Count) - 1 do
    begin
      S := '';
      for K := 0 to TrackFrames - 1 do
        if GTrack[Groups[J].First].Frames[K] <> nil then
        begin
          Line := FmrAddressInfo(Pointer(NativeUInt(GTrack[Groups[J].First].Frames[K]) - 1));
          if Line.StartsWith('System.@') or Line.StartsWith('FmrStackTrace.') or Line.StartsWith('System.TObject.') then
            Continue;
          S := S + sLineBreak + '        ' + Line;
        end;
      Result := Result + sLineBreak + Format('    %d blocks, %d bytes:', [Groups[J].Count, Groups[J].Bytes]) + S;
    end;
  finally
    Groups.Free;
  end;
end;

function FmrLastBadFree: string;
begin
  if GBadFreeSet then
    Result := GetStackString(@GBadFree)
  else
    Result := '';
  GBadFreeSet := False;
end;

procedure InstallFreeCheck;
var
  M: TMemoryManagerEx;
begin
  GetMemoryManager(GOldMM);
  M := GOldMM;
  M.FreeMem := CheckedFreeMem;
  M.GetMem := TrackedGetMem;
  M.AllocMem := TrackedAllocMem;
  M.ReallocMem := TrackedReallocMem;
  SetMemoryManager(M);
end;

initialization
  InstallFreeCheck;
  Exception.GetExceptionStackInfoProc := GetStackInfo;
  Exception.GetStackInfoStringProc := GetStackString;
  Exception.CleanUpStackInfoProc := CleanUpStackInfo;

finalization
  Exception.GetExceptionStackInfoProc := nil;
  Exception.GetStackInfoStringProc := nil;
  Exception.CleanUpStackInfoProc := nil;
  GPublics.Free;
  GLines.Free;
  GFiles.Free;

end.
