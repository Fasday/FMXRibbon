<#
.SYNOPSIS
  Starts (or finds) a program window, optionally drives it with mouse/keyboard actions, takes a screenshot of the
  window as the user sees it (DWM-composed, with a margin for the shadow) and prints the window geometry.

.DESCRIPTION
  Geometry printed: window rect, DWM extended frame bounds, client rect in screen coordinates, the non-client
  thickness on each side and the hit-test code under every point listed in -Probe. This is what proves whether a
  caption is real non-client area (client rect starts below it) or client area.

  Actions (-Actions), separated by ';', coordinates relative to the window's top-left corner (physical pixels):
    move:X,Y        moves the cursor
    click:X,Y       left click            rclick:X,Y   right click        dclick:X,Y  double click
    down:X,Y / up:X,Y   left button down / up (drag: down, move, up)
    keys:TEXT       SendKeys syntax (e.g. keys:Hello{ENTER}, keys:%{F4})
    wait:MS         sleeps
    shot:NAME       extra screenshot <Out without .png>_NAME.png

.EXAMPLE
  .\tools\shot.ps1 -Exe bin\Win64\Debug\NCProof.exe -Out shots\ncproof.png -Probe "40,15;300,15;10,200"
  .\tools\shot.ps1 -Exe bin\Win64\Debug\NCProof.exe -Out shots\edit.png -Actions "click:420,16;keys:Hello;wait:300"
#>
param(
  [string] $Exe,
  [string] $Arguments = '',
  [int] $ProcessId = 0,
  [string] $Out = 'shots\shot.png',
  [int] $Wait = 2500,
  [int] $Margin = 24,
  [string] $Actions = '',
  [string] $Probe = '',
  [switch] $Keep
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
if (-not ('ShotNative' -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ShotNative {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  public static IntPtr FindMain(uint pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h) && GetWindow(h, 4) == IntPtr.Zero) {
        RECT r; GetWindowRect(h, out r);
        if (r.Right - r.Left > 100 && r.Bottom - r.Top > 60) { found = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
'@
}
# Physical pixels everywhere (DPI-unaware callers would get virtualized coordinates)
[void][ShotNative]::SetProcessDpiAwarenessContext([IntPtr](-4))

$proc = $null
if ($ProcessId -ne 0) { $proc = Get-Process -Id $ProcessId }
elseif ($Exe) {
  $exePath = (Resolve-Path $Exe).Path
  $proc = if ($Arguments) { Start-Process $exePath -ArgumentList $Arguments -PassThru } else { Start-Process $exePath -PassThru }
} else { throw 'Give -Exe or -ProcessId' }

$hwnd = [IntPtr]::Zero
$deadline = (Get-Date).AddMilliseconds([Math]::Max($Wait, 500) + 15000)
while ($hwnd -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 200
  if ($proc.HasExited) { throw "Process exited with code $($proc.ExitCode)" }
  $hwnd = [ShotNative]::FindMain([uint32]$proc.Id)
}
if ($hwnd -eq [IntPtr]::Zero) { throw 'Main window not found' }
Start-Sleep -Milliseconds $Wait
[void][ShotNative]::SetForegroundWindow($hwnd)
Start-Sleep -Milliseconds 300

function Get-Geometry {
  $w = New-Object ShotNative+RECT; [void][ShotNative]::GetWindowRect($hwnd, [ref]$w)
  $f = New-Object ShotNative+RECT; [void][ShotNative]::DwmGetWindowAttribute($hwnd, 9, [ref]$f, 16)
  $c = New-Object ShotNative+RECT; [void][ShotNative]::GetClientRect($hwnd, [ref]$c)
  $p = New-Object ShotNative+POINT; [void][ShotNative]::ClientToScreen($hwnd, [ref]$p)
  [pscustomobject]@{ Window = $w; Frame = $f; Client = $c; ClientOrigin = $p }
}

$outPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
New-Item -ItemType Directory -Force -Path (Split-Path $outPath -Parent) | Out-Null

function Save-Shot([string] $path) {
  $g = Get-Geometry
  $r = $g.Window
  $x = $r.Left - $Margin; $y = $r.Top - $Margin
  $wd = ($r.Right - $r.Left) + 2 * $Margin; $ht = ($r.Bottom - $r.Top) + 2 * $Margin
  $bmp = New-Object System.Drawing.Bitmap $wd, $ht
  $gr = [System.Drawing.Graphics]::FromImage($bmp)
  $gr.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $wd, $ht))
  $gr.Dispose(); $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  Write-Host "shot -> $path"
}

function To-Screen([string] $xy) {
  $g = Get-Geometry
  $parts = $xy.Split(',')
  @(($g.Window.Left + [int]$parts[0]), ($g.Window.Top + [int]$parts[1]))
}

if ($Actions) {
  foreach ($a in $Actions.Split(';')) {
    $a = $a.Trim(); if (-not $a) { continue }
    $kind, $arg = $a.Split(':', 2)
    switch ($kind) {
      'move'   { $p = To-Screen $arg; [void][ShotNative]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 150 }
      'click'  { $p = To-Screen $arg; [void][ShotNative]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 80
                 [ShotNative]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); [ShotNative]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 200 }
      'dclick' { $p = To-Screen $arg; [void][ShotNative]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 80
                 1..2 | ForEach-Object { [ShotNative]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); [ShotNative]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 40 }
                 Start-Sleep -Milliseconds 300 }
      'rclick' { $p = To-Screen $arg; [void][ShotNative]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 80
                 [ShotNative]::mouse_event(8, 0, 0, 0, [IntPtr]::Zero); [ShotNative]::mouse_event(16, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 300 }
      'down'   { $p = To-Screen $arg; [void][ShotNative]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 80; [ShotNative]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 150 }
      'up'     { $p = To-Screen $arg; [void][ShotNative]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 80; [ShotNative]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 150 }
      'keys'   { [System.Windows.Forms.SendKeys]::SendWait($arg); Start-Sleep -Milliseconds 200 }
      'wait'   { Start-Sleep -Milliseconds ([int]$arg) }
      'shot'   { Save-Shot ($outPath -replace '\.png$', "_$arg.png") }
      default  { throw "Unknown action '$a'" }
    }
  }
}

Save-Shot $outPath

$g = Get-Geometry
$w = $g.Window; $c = $g.Client; $o = $g.ClientOrigin
$sb = New-Object System.Text.StringBuilder 256
[void][ShotNative]::GetWindowText($hwnd, $sb, 256)
Write-Host ("title        : {0}" -f $sb.ToString())
Write-Host ("dpi          : {0}" -f [ShotNative]::GetDpiForWindow($hwnd))
Write-Host ("window rect  : ({0},{1})-({2},{3})  {4}x{5}" -f $w.Left, $w.Top, $w.Right, $w.Bottom, ($w.Right - $w.Left), ($w.Bottom - $w.Top))
Write-Host ("frame bounds : ({0},{1})-({2},{3})" -f $g.Frame.Left, $g.Frame.Top, $g.Frame.Right, $g.Frame.Bottom)
Write-Host ("client rect  : origin ({0},{1}) size {2}x{3}" -f $o.X, $o.Y, $c.Right, $c.Bottom)
Write-Host ("non-client   : left {0}, top {1}, right {2}, bottom {3}" -f ($o.X - $w.Left), ($o.Y - $w.Top), ($w.Right - $o.X - $c.Right), ($w.Bottom - $o.Y - $c.Bottom))
Write-Host ("style        : 0x{0:X8}  exstyle 0x{1:X8}" -f [ShotNative]::GetWindowLong($hwnd, -16), [ShotNative]::GetWindowLong($hwnd, -20))

if ($Probe) {
  $names = @{ 0 = 'HTNOWHERE'; 1 = 'HTCLIENT'; 2 = 'HTCAPTION'; 3 = 'HTSYSMENU'; 8 = 'HTMINBUTTON'; 9 = 'HTMAXBUTTON'
    10 = 'HTLEFT'; 11 = 'HTRIGHT'; 12 = 'HTTOP'; 13 = 'HTTOPLEFT'; 14 = 'HTTOPRIGHT'; 15 = 'HTBOTTOM'; 16 = 'HTBOTTOMLEFT'
    17 = 'HTBOTTOMRIGHT'; 18 = 'HTBORDER'; 20 = 'HTCLOSE'; 21 = 'HTHELP'; -1 = 'HTTRANSPARENT' }
  foreach ($pt in $Probe.Split(';')) {
    $pt = $pt.Trim(); if (-not $pt) { continue }
    $p = To-Screen $pt
    $l = [IntPtr](($p[1] -shl 16) -bor ($p[0] -band 0xFFFF))
    $ht = [int][ShotNative]::SendMessage($hwnd, 0x84, [IntPtr]::Zero, $l)
    $n = if ($names.ContainsKey($ht)) { $names[$ht] } else { "$ht" }
    Write-Host ("hit-test ({0}) : {1}" -f $pt, $n)
  }
}

if (-not $Keep -and $Exe) {
  try { $proc.CloseMainWindow() | Out-Null; if (-not $proc.WaitForExit(3000)) { $proc.Kill() } } catch {}
}
