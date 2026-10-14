<#
.SYNOPSIS
  Screenshot of all visible windows of a process (main form and its popups) composed from PrintWindow
  (PW_RENDERFULLCONTENT), so windows of other programs that cover the form do not spoil the picture.

.EXAMPLE
  .\tools\capture.ps1 -ProcessId 1234 -Out shots\x.png
#>
param(
  [Parameter(Mandatory = $true)] [int] $ProcessId,
  [Parameter(Mandatory = $true)] [string] $Out,
  [int] $Margin = 16
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('RibbonCapture' -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
public static class RibbonCapture {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  public static List<IntPtr> Windows(uint pid) {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        if (r.Right - r.Left > 4 && r.Bottom - r.Top > 4) list.Add(h);
      }
      return true;
    }, IntPtr.Zero);
    return list; // top-most first
  }
  public static Bitmap Shot(IntPtr h, out RECT r) {
    GetWindowRect(h, out r);
    var bmp = new Bitmap(Math.Max(1, r.Right - r.Left), Math.Max(1, r.Bottom - r.Top),
      System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(bmp)) {
      IntPtr hdc = g.GetHdc();
      PrintWindow(h, hdc, 2);
      g.ReleaseHdc(hdc);
    }
    return bmp;
  }
}
'@
}
[void][RibbonCapture]::SetProcessDpiAwarenessContext([IntPtr](-4))

$wins = [RibbonCapture]::Windows([uint32]$ProcessId)
if ($wins.Count -eq 0) { throw 'No visible window' }
# The largest window is the form; popups are drawn over it in z-order.
$shots = @()
foreach ($h in $wins) {
  $r = New-Object RibbonCapture+RECT
  $bmp = [RibbonCapture]::Shot($h, [ref]$r)
  $shots += [pscustomobject]@{ Bmp = $bmp; R = $r; Area = ($r.Right - $r.Left) * ($r.Bottom - $r.Top) }
}
$main = ($shots | Sort-Object Area -Descending)[0]
$L = $main.R.Left; $T = $main.R.Top; $Rt = $main.R.Right; $B = $main.R.Bottom
foreach ($s in $shots) { $L = [Math]::Min($L, $s.R.Left); $T = [Math]::Min($T, $s.R.Top); $Rt = [Math]::Max($Rt, $s.R.Right); $B = [Math]::Max($B, $s.R.Bottom) }
$L -= $Margin; $T -= $Margin; $Rt += $Margin; $B += $Margin
$canvas = New-Object System.Drawing.Bitmap ($Rt - $L), ($B - $T)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::FromArgb(255, 96, 96, 96))
[array]::Reverse($shots)
foreach ($s in $shots) { $g.DrawImage($s.Bmp, $s.R.Left - $L, $s.R.Top - $T) }
$g.Dispose()
if ([IO.Path]::IsPathRooted($Out)) { $outPath = $Out } else { $outPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
New-Item -ItemType Directory -Force -Path (Split-Path $outPath -Parent) | Out-Null
$canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose(); foreach ($s in $shots) { $s.Bmp.Dispose() }
Write-Host "capture -> $outPath (windows: $($wins.Count), origin $($main.R.Left - $L),$($main.R.Top - $T))"
