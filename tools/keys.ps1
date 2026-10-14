<#
.SYNOPSIS
  Sends key strokes to the main form of a process with keybd_event (FMX ignores some SendKeys combinations).
  Used with tools\shot.ps1 -Keep / -ProcessId to drive the RibbonBasic demo.

.EXAMPLE
  .\tools\keys.ps1 -ProcessId 1234 -Keys "ctrl+F1"
  .\tools\keys.ps1 -ProcessId 1234 -Keys "alt;H;wait:300;esc"
  Items (';'-separated): alt (press and release Alt), F1..F12, esc, enter, tab, left, right, up, down, back, space,
  letters and digits, combinations with ctrl+, shift+, alt+ (e.g. ctrl+B), wait:MS.
#>
param(
  [Parameter(Mandatory = $true)] [int] $ProcessId,
  [Parameter(Mandatory = $true)] [string] $Keys
)

$ErrorActionPreference = 'Stop'
if (-not ('RibbonKeys2' -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RibbonKeys2 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  // SetForegroundWindow is refused while another process owns the foreground: attach to its input first.
  public static bool ForceForeground(IntPtr h) {
    uint dummy;
    IntPtr fg = GetForegroundWindow();
    uint fgThread = GetWindowThreadProcessId(fg, out dummy);
    uint me = GetCurrentThreadId();
    uint target = GetWindowThreadProcessId(h, out dummy);
    AttachThreadInput(me, fgThread, true);
    AttachThreadInput(target, fgThread, true);
    BringWindowToTop(h);
    SetForegroundWindow(h);
    AttachThreadInput(target, fgThread, false);
    AttachThreadInput(me, fgThread, false);
    return GetForegroundWindow() == h;
  }
  public static IntPtr FindForm(uint pid) {
    IntPtr best = IntPtr.Zero; long bestArea = 0;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        long a = (long)(r.Right - r.Left) * (r.Bottom - r.Top);
        if (a > bestArea) { bestArea = a; best = h; }
      }
      return true;
    }, IntPtr.Zero);
    return best;
  }
}
'@
}

$form = [RibbonKeys2]::FindForm([uint32]$ProcessId)
if (($form -ne [IntPtr]::Zero) -and ([RibbonKeys2]::GetForegroundWindow() -ne $form)) {
  [void][RibbonKeys2]::SetForegroundWindow($form)
  Start-Sleep -Milliseconds 150
  if ([RibbonKeys2]::GetForegroundWindow() -ne $form) { [void][RibbonKeys2]::ForceForeground($form); Start-Sleep -Milliseconds 150 }
  if ([RibbonKeys2]::GetForegroundWindow() -ne $form) { Write-Warning "keys.ps1: the form is not the foreground window ($Keys)" }
}

$named = @{ 'esc' = 0x1B; 'enter' = 0x0D; 'tab' = 0x09; 'left' = 0x25; 'up' = 0x26; 'right' = 0x27; 'down' = 0x28;
  'back' = 0x08; 'space' = 0x20; 'alt' = 0x12; 'ctrl' = 0x11; 'shift' = 0x10 }

function Get-Vk([string] $name) {
  $n = $name.ToLower()
  if ($named.ContainsKey($n)) { return [byte]$named[$n] }
  if ($n -match '^f(\d+)$') { return [byte](0x6F + [int]$Matches[1]) }
  return [byte][char]$name.ToUpper()
}

function Tap([byte] $vk) {
  [RibbonKeys2]::keybd_event($vk, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 30
  [RibbonKeys2]::keybd_event($vk, 0, 2, [IntPtr]::Zero); Start-Sleep -Milliseconds 60
}

foreach ($item in $Keys.Split(';')) {
  $item = $item.Trim(); if (-not $item) { continue }
  if ($item -match '^wait:(\d+)$') { Start-Sleep -Milliseconds ([int]$Matches[1]); continue }
  $parts = $item.Split('+')
  $mods = @(); for ($i = 0; $i -lt $parts.Length - 1; $i++) { $mods += Get-Vk $parts[$i] }
  $key = Get-Vk $parts[-1]
  foreach ($m in $mods) { [RibbonKeys2]::keybd_event($m, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 30 }
  Tap $key
  for ($i = $mods.Length - 1; $i -ge 0; $i--) { [RibbonKeys2]::keybd_event($mods[$i], 0, 2, [IntPtr]::Zero); Start-Sleep -Milliseconds 30 }
  Start-Sleep -Milliseconds 120
}
