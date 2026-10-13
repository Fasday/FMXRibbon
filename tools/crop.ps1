# Crops a region of a PNG and scales it up (nearest neighbour) to inspect pixels of a screenshot.
# .\Demos\NCProof\crop.ps1 -In shots\a.png -Out shots\a_crop.png -X 0 -Y 0 -Width 200 -Height 100 -Zoom 4
param([string] $In, [string] $Out, [int] $X, [int] $Y, [int] $Width, [int] $Height, [int] $Zoom = 4)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $In).Path)
try {
  $dst = New-Object System.Drawing.Bitmap ($Width * $Zoom), ($Height * $Zoom)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, ($Width * $Zoom), ($Height * $Zoom)),
    (New-Object System.Drawing.Rectangle $X, $Y, $Width, $Height), [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $dst.Save([IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)), [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()
} finally { $src.Dispose() }
