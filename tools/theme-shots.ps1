<#
.SYNOPSIS
  Captures the RibbonBasic demo in several themes and saves the ribbon part of each window to Docs\images\themes\
  (used by the README).

.EXAMPLE
  .\tools\theme-shots.ps1
  .\tools\theme-shots.ps1 -Themes Office365Black,FluentLight -Height 340
#>
param(
  [string[]] $Themes = @('Office365Colorful', 'Office365White', 'Office365Black', 'Office2016Colorful',
    'Office2013White', 'Office2010Blue', 'Office2007Blue', 'Office2007Black', 'FluentLight', 'FluentDark'),
  [string] $Exe = 'bin\Win64\Debug\RibbonBasic.exe',
  [string] $Frame = 'fullnc',
  # Height of the saved part in physical pixels (caption + tabs + ribbon body + a strip of the document)
  [int] $Height = 330,
  [string] $OutDir = 'Docs\images\themes'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  New-Item -ItemType Directory -Force -Path $OutDir, 'shots' | Out-Null
  foreach ($t in $Themes) {
    $raw = "shots\theme_raw_$t`_$([guid]::NewGuid().ToString('N').Substring(0, 6)).png"
    & (Join-Path $PSScriptRoot 'drive.ps1') -Exe $Exe -Arguments "/theme=$t /frame=$Frame /height=480" -Out $raw -Wait 3000 | Out-Null
    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $raw).Path)
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
    } finally { $src.Dispose() }
  }
} finally { Pop-Location }
