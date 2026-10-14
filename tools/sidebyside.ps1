<#
.SYNOPSIS
  Puts the same region of two screenshots one above the other (reference on top), zoomed, to compare them.

.EXAMPLE
  .\tools\sidebyside.ps1 -Ref shots\before.png -Ours shots\x.png -X 0 -Y 0 -Width 700 -Height 200 `
    -DX 15 -DY 8 -Out shots\cmp\caption.png
  DX/DY: where the reference point (X, Y) is in Ours, relative to (X, Y) (different window origins).
#>
param(
  [Parameter(Mandatory = $true)] [string] $Ref,
  [Parameter(Mandatory = $true)] [string] $Ours,
  [int] $X, [int] $Y, [int] $Width, [int] $Height,
  [int] $DX = 0, [int] $DY = 0,
  [int] $Zoom = 2,
  [Parameter(Mandatory = $true)] [string] $Out
)
Add-Type -AssemblyName System.Drawing
$a = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Ref).Path)
$b = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Ours).Path)
try {
  $gap = 6
  $dst = New-Object System.Drawing.Bitmap ($Width * $Zoom), (2 * $Height * $Zoom + $gap)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255))
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.DrawImage($a, (New-Object System.Drawing.Rectangle 0, 0, ($Width * $Zoom), ($Height * $Zoom)),
    (New-Object System.Drawing.Rectangle $X, $Y, $Width, $Height), [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawImage($b, (New-Object System.Drawing.Rectangle 0, ($Height * $Zoom + $gap), ($Width * $Zoom), ($Height * $Zoom)),
    (New-Object System.Drawing.Rectangle ($X + $DX), ($Y + $DY), $Width, $Height), [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  if ([IO.Path]::IsPathRooted($Out)) { $o = $Out } else { $o = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
  $dst.Save($o, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()
} finally { $a.Dispose(); $b.Dispose() }
