<#
.SYNOPSIS
  Renders a sheet of icon-font glyphs (code point + name) into a PNG, to check the code points used by the ribbon
  templates and the glyph names of the image source dialog.

.EXAMPLE
  .\tools\DesignPreview\glyphsheet.ps1 -Codes "E77F:Paste,E8C6:Cut" -Out shots\glyphs.png
  .\tools\DesignPreview\glyphsheet.ps1 -File tools\DesignPreview\glyphs.txt -Out shots\glyphs.png
#>
param(
  [string] $Codes = '',
  [string] $File = '',
  # A range of code points ("E900-E9FF"): compact cells with the code only.
  [string] $Range = '',
  [string] $Out = 'shots\glyphs.png',
  [string] $Font = 'Segoe Fluent Icons',
  [int] $Columns = 8
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$entries = @()
$lines = @()
if ($File) { $lines += Get-Content $File }
if ($Codes) { $lines += $Codes -split ',' }
foreach ($l in $lines) {
  $l = $l.Trim()
  if (-not $l -or $l.StartsWith('#')) { continue }
  $p = $l -split '[:=\s]', 2
  $entries += [pscustomobject]@{ Code = [Convert]::ToInt32($p[0], 16); Name = if ($p.Count -gt 1) { $p[1].Trim() } else { '' } }
}

$cellW = 150; $cellH = 70
if ($Range) {
  $r = $Range -split '-'
  $from = [Convert]::ToInt32($r[0], 16); $to = [Convert]::ToInt32($r[1], 16)
  for ($c = $from; $c -le $to; $c++) { $entries += [pscustomobject]@{ Code = $c; Name = '' } }
  $Columns = 16; $cellW = 64; $cellH = 56
}
$rows = [Math]::Ceiling($entries.Count / $Columns)
$bmp = New-Object System.Drawing.Bitmap(($cellW * $Columns), ($cellH * $rows))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$glyphFont = New-Object System.Drawing.Font($Font, 26, [System.Drawing.GraphicsUnit]::Pixel)
$textFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.GraphicsUnit]::Pixel)
$black = [System.Drawing.Brushes]::Black
$gray = [System.Drawing.Brushes]::DimGray
$pen = [System.Drawing.Pens]::Gainsboro
for ($i = 0; $i -lt $entries.Count; $i++) {
  $x = ($i % $Columns) * $cellW
  $y = [Math]::Floor($i / $Columns) * $cellH
  $g.DrawRectangle($pen, $x, $y, $cellW - 1, $cellH - 1)
  $e = $entries[$i]
  if ($Range) {
    $g.DrawString([char]::ConvertFromUtf32($e.Code), $glyphFont, $black, ($x + 16), ($y + 4))
    $g.DrawString(('{0:X4}' -f $e.Code), $textFont, $gray, ($x + 14), ($y + 38))
  } else {
    $g.DrawString([char]::ConvertFromUtf32($e.Code), $glyphFont, $black, ($x + 6), ($y + 8))
    $g.DrawString(('{0:X4}' -f $e.Code), $textFont, $gray, ($x + 48), ($y + 10))
    $g.DrawString($e.Name, $textFont, $black, ($x + 48), ($y + 30))
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $Out -Parent) | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "font: $($glyphFont.Name) -> $Out ($($entries.Count) glyphs)"
