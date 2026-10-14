<#
.SYNOPSIS
  Captures the RibbonBasic demo in several themes and saves the ribbon part of each window to Docs\images\themes\
  (used by the README).

.DESCRIPTION
  The window is placed mostly outside the visible desktop (/pos), so the captures hardly cover other windows; a
  strip of it stays visible and on top (/topmost), because an occluded window is not painted by the Direct2D
  canvas. A capture whose window came out unpainted (white) is taken again.

.EXAMPLE
  .\tools\theme-shots.ps1
  .\tools\theme-shots.ps1 -Themes Office2024Dark,FluentLight -Height 340
#>
param(
  [string[]] $Themes = @('Office2024Light', 'Office2024DarkGray', 'Office2024Dark', 'Office365Colorful',
    'Office365White', 'Office365Black', 'Office2016Colorful', 'Office2013White', 'Office2010Blue', 'Office2007Blue',
    'Office2007Black', 'FluentLight', 'FluentDark'),
  [string] $Exe = 'bin\Win64\Debug\RibbonBasic.exe',
  [string] $Frame = 'fullnc',
  # Height of the saved part in physical pixels (caption + tabs + ribbon body + a strip of the document)
  [int] $Height = 330,
  [string] $OutDir = 'Docs\images\themes',
  # Window position (dp): mostly to the right of the primary monitor; '' = where the demo puts it
  [string] $Pos = '2540,0'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  New-Item -ItemType Directory -Force -Path $OutDir, 'shots' | Out-Null
  foreach ($t in $Themes) {
    $demoArgs = "/theme=$t /frame=$Frame /height=480 /activelook /topmost"
    if ($Pos) { $demoArgs += " /pos=$Pos" }
    $raws = @()
    for ($try = 1; $try -le 4; $try++) {
      $raw = "shots\theme_raw_$t`_$([guid]::NewGuid().ToString('N').Substring(0, 6)).png"
      $raws += $raw
      & (Join-Path $PSScriptRoot 'drive.ps1') -Exe $Exe -Arguments $demoArgs -Out $raw -Wait 3000 -NoCursor | Out-Null
      $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $raw).Path)
      # unpainted: the off-screen part of the window is plain white (no text, no glyphs)
      # (the caption and tab rows of FullNC are painted separately: check them on their own)
      $inked = 0; $strip = 0
      for ($py = 20; $py -lt [Math]::Min(220, $src.Height); $py += 3) {
        for ($px = 60; $px -lt $src.Width - 40; $px += 5) {
          $c = $src.GetPixel($px, $py)
          if (-not ($c.R -eq 255 -and $c.G -eq 255 -and $c.B -eq 255)) { if ($py -lt 85) { $strip++ } else { $inked++ } }
        }
      }
      if (($inked -gt 200 -and $strip -gt 40) -or $try -eq 4) { break }
      $src.Dispose()
    }
    try {
      # drive.ps1 puts the window at (16,16) on a gray background; keep the window only, top part
      $x = 16; $y = 16
      $w = $src.Width - 2 * $x
      $h = [Math]::Min($Height, $src.Height - $y)
      $dst = New-Object System.Drawing.Bitmap $w, $h
      $g = [System.Drawing.Graphics]::FromImage($dst)
      $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle $x, $y, $w, $h),
        [System.Drawing.GraphicsUnit]::Pixel)
      $g.Dispose()
      $out = Join-Path $OutDir "$t.png"
      $dst.Save([IO.Path]::GetFullPath($out), [System.Drawing.Imaging.ImageFormat]::Png)
      $dst.Dispose()
      Write-Host "$t -> $out"
    } finally { $src.Dispose(); Remove-Item $raws -ErrorAction SilentlyContinue }
  }
} finally { Pop-Location }
