<#
.SYNOPSIS
  Builds Assets\Fonts\FmrFluentIcons.ttf and Source\Core\FMR.Ribbon.IconFont.inc from segoe-fluent-map.txt.

.DESCRIPTION
  The ribbon, its templates and the demos use code points of Segoe Fluent Icons (Windows 11) / Segoe MDL2 Assets
  (Windows 10). Those fonts must not be redistributed, so where they are missing (Linux) TFmrImageSource draws the same
  icon from "FMR Fluent Icons": a subset of FluentSystemIcons-Resizable.ttf of Microsoft's Fluent UI System Icons (MIT,
  https://github.com/microsoft/fluentui-system-icons) with only the icons named in segoe-fluent-map.txt, at their
  original code points, renamed so it never hides a full Fluent System Icons font. The .inc maps each Segoe code to
  its code point in that font.

  1. Downloads fonts/FluentSystemIcons-Resizable.ttf and .json of the pinned commit (-Commit) into dcu\IconFont.
  2. Runs make_icon_font.py (Python 3 with fontTools: pip install fonttools).

  To map another Segoe code: add a line "<code> <fluent name>" to segoe-fluent-map.txt (names: the .json, without
  "ic_fluent_" and "_20_regular"; ":filled" for the filled variant) and run this script again.

.EXAMPLE
  .\tools\IconFont\make-icon-font.ps1
  .\tools\IconFont\make-icon-font.ps1 -Check      # only checks that every name exists in the font
#>
param(
  [string] $Commit = 'a347af95478f989038cccbf085978865264c048a',
  [string] $Python = 'python',
  [switch] $Check
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Work = Join-Path $Root 'dcu\IconFont'
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$base = "https://raw.githubusercontent.com/microsoft/fluentui-system-icons/$Commit/fonts"
foreach ($f in 'FluentSystemIcons-Resizable.ttf', 'FluentSystemIcons-Resizable.json') {
  $target = Join-Path $Work "$Commit-$f"
  if (-not (Test-Path $target)) {
    Write-Host "download $f ($Commit)"
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$f" -OutFile $target -TimeoutSec 300
  }
}
$pyArgs = @(
  (Join-Path $PSScriptRoot 'make_icon_font.py'),
  (Join-Path $Work "$Commit-FluentSystemIcons-Resizable.ttf"),
  (Join-Path $Work "$Commit-FluentSystemIcons-Resizable.json"),
  $Root,
  '--source', "microsoft/fluentui-system-icons@$($Commit.Substring(0, 12)), fonts/FluentSystemIcons-Resizable.ttf"
)
if ($Check) { $pyArgs += '--check' }
& $Python @pyArgs
if ($LASTEXITCODE -ne 0) { throw "make_icon_font.py failed ($LASTEXITCODE)" }
