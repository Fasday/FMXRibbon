<#
.SYNOPSIS
  Drives the RibbonBasic demo without depending on the z-order of the desktop: mouse input is posted to the form
  window (WM_MOUSEMOVE / WM_xBUTTONDOWN / UP with client coordinates, negative in the non-client strip), keys are sent
  with keybd_event to the form made foreground, screenshots are composed from PrintWindow (capture.ps1).

.DESCRIPTION
  Actions (';'-separated), coordinates relative to the top-left corner of the window (physical pixels, like
  tools\shot.ps1):
    move:X,Y  click:X,Y  rclick:X,Y  dclick:X,Y  wait:MS  shot:NAME (Out without .png + _NAME.png)
    key:KEYS  (keys.ps1 syntax: alt, ctrl+F1, esc, H, ...)   text:TEXT (typed with WM_CHAR)

.EXAMPLE
  .\tools\drive.ps1 -Arguments "/theme=Office2007Blue" -Out shots\x.png -Actions "click:302,82;wait:500;shot:a"
#>
param(
  [string] $Exe = 'bin\Win64\Debug\RibbonBasic.exe',
  [string] $Arguments = '',
  [string] $Out = 'shots\drive.png',
  [string] $Actions = '',
  [int] $Wait = 2500,
  [switch] $Keep
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not ('RibbonDrive' -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RibbonDrive {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
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
  // The window of the process under a screen point (a popup above the form), else the form.
  public static IntPtr TargetAt(uint pid, IntPtr form, int x, int y) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (found == IntPtr.Zero && p == pid && IsWindowVisible(h) && h != form) {
        RECT r; GetWindowRect(h, out r);
        if (x >= r.Left && x < r.Right && y >= r.Top && y < r.Bottom) found = h;
      }
      return true;
    }, IntPtr.Zero);
    return found != IntPtr.Zero ? found : form;
  }
}
'@
}
[void][RibbonDrive]::SetProcessDpiAwarenessContext([IntPtr](-4))

$proc = if ($Arguments) { Start-Process (Resolve-Path $Exe).Path -ArgumentList $Arguments -PassThru } else { Start-Process (Resolve-Path $Exe).Path -PassThru }
$form = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds(15)
while ($form -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200; $form = [RibbonDrive]::FindForm([uint32]$proc.Id) }
if ($form -eq [IntPtr]::Zero) { throw 'Form not found' }
Start-Sleep -Milliseconds $Wait

function Post-Mouse([string] $xy, [uint32] $down, [uint32] $up, [int] $wparamDown, [switch] $Double) {
  $parts = $xy.Split(',')
  $w = New-Object RibbonDrive+RECT; [void][RibbonDrive]::GetWindowRect($form, [ref]$w)
  $sx = $w.Left + [int]$parts[0]; $sy = $w.Top + [int]$parts[1]
  [void][RibbonDrive]::SetCursorPos($sx, $sy)
  $target = [RibbonDrive]::TargetAt([uint32]$proc.Id, $form, $sx, $sy)
  $o = New-Object RibbonDrive+POINT; [void][RibbonDrive]::ClientToScreen($target, [ref]$o)
  $cx = $sx - $o.X; $cy = $sy - $o.Y
  $l = [IntPtr](((($cy -band 0xFFFF) -shl 16) -bor ($cx -band 0xFFFF)))
  [void][RibbonDrive]::PostMessage($target, 0x200, [IntPtr]::Zero, $l)
  Start-Sleep -Milliseconds 60
  if ($down -ne 0) {
    [void][RibbonDrive]::PostMessage($target, $down, [IntPtr]$wparamDown, $l); Start-Sleep -Milliseconds 40
    [void][RibbonDrive]::PostMessage($target, $up, [IntPtr]::Zero, $l); Start-Sleep -Milliseconds 120
    if ($Double) {
      [void][RibbonDrive]::PostMessage($target, $down + 2, [IntPtr]$wparamDown, $l); Start-Sleep -Milliseconds 40
      [void][RibbonDrive]::PostMessage($target, $up, [IntPtr]::Zero, $l); Start-Sleep -Milliseconds 120
    }
  }
}

$outPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
foreach ($a in $Actions.Split(';')) {
  $a = $a.Trim(); if (-not $a) { continue }
  $kind, $arg = $a.Split(':', 2)
  switch ($kind) {
    'move'   { Post-Mouse $arg 0 0 0; Start-Sleep -Milliseconds 100 }
    'click'  { Post-Mouse $arg 0x201 0x202 1 }
    'dclick' { Post-Mouse $arg 0x201 0x202 1 -Double }
    'rclick' { Post-Mouse $arg 0x204 0x205 2 }
    'wait'   { Start-Sleep -Milliseconds ([int]$arg) }
    'key'    { & (Join-Path $here 'keys.ps1') -ProcessId $proc.Id -Keys $arg }
    'text'   { foreach ($c in $arg.ToCharArray()) { [void][RibbonDrive]::PostMessage($form, 0x102, [IntPtr][int]$c, [IntPtr]1); Start-Sleep -Milliseconds 30 } }
    'shot'   { & (Join-Path $here 'capture.ps1') -ProcessId $proc.Id -Out ($outPath -replace '\.png$', "_$arg.png") }
    default  { throw "Unknown action '$a'" }
  }
}
& (Join-Path $here 'capture.ps1') -ProcessId $proc.Id -Out $outPath
if (-not $Keep) { try { Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue } catch {} }
