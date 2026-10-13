<#
.SYNOPSIS
  Command-line build of an FMR Ribbon program (demo, test runner) for Win64 (dcc64) or Win32 (dcc32).

.DESCRIPTION
  - Output exe/map:  bin\<Platform>\<Config>\
  - DCU:             dcu\<Platform>\<Config>\<ProjectName>\
  - Compiles res\WinApp.rc (PerMonitorV2 manifest) to dcu\WinApp.res; a .dpr includes it with {$R WinApp.res}.
  - Every folder under Source\ is on the search path; -SearchPath adds more (e.g. FastCanvas, DUnitX).
  - Always a full build (-B), so changed switches never mix with stale DCUs.

.EXAMPLE
  .\build.ps1 -Project Demos\NCProof\NCProof.dpr
  .\build.ps1 -Project Tests\FmrRibbonTests.dpr -Config Debug -Console
#>
param(
  [Parameter(Mandatory = $true)] [string] $Project,
  [ValidateSet('Release', 'Debug')] [string] $Config = 'Debug',
  [ValidateSet('Win64', 'Win32')] [string] $Platform = 'Win64',
  [string[]] $SearchPath = @(),
  [string[]] $Define = @(),
  # Console application (test runners): the .dpr says {$APPTYPE CONSOLE}; nothing else changes.
  [switch] $Console
)

$ErrorActionPreference = 'Stop'

$Bds = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'   # Delphi 13
$DccName = if ($Platform -eq 'Win32') { 'dcc32' } else { 'dcc64' }
$Dcc = Join-Path $Bds "bin\$DccName.exe"
$Brcc = Join-Path $Bds 'bin\brcc32.exe'
$Root = $PSScriptRoot

$ProjectPath = (Resolve-Path $Project).Path
$Name = [IO.Path]::GetFileNameWithoutExtension($ProjectPath)
$OutDir = Join-Path $Root "bin\$Platform\$Config"
$DcuDir = Join-Path $Root "dcu\$Platform\$Config\$Name"
$ResDir = Join-Path $Root 'dcu'
New-Item -ItemType Directory -Force -Path $OutDir, $DcuDir | Out-Null

$env:BDS = $Bds
$env:BDSINCLUDE = Join-Path $Bds 'include'
$env:BDSCOMMONDIR = 'C:\Users\Public\Documents\Embarcadero\Studio\37.0'

# 1. Shared resources (manifest)
Push-Location (Join-Path $Root 'res')
try {
  & $Brcc -fo"$(Join-Path $ResDir 'WinApp.res')" 'WinApp.rc' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "brcc32 failed ($LASTEXITCODE)" }
} finally { Pop-Location }

# 2. Search path: dcu\ (WinApp.res), every folder of Source\, the project's folder, extra folders
$paths = @($ResDir)
$paths += Get-ChildItem (Join-Path $Root 'Source') -Directory -Recurse | ForEach-Object { $_.FullName }
$paths += Join-Path $Root 'Source'
$paths += Split-Path $ProjectPath -Parent
$paths += $SearchPath | ForEach-Object { (Resolve-Path $_).Path }
$pathArg = ($paths -join ';')

$flags = @(
  '-B', '-Q',
  # Sources are UTF-8 (with or without BOM); without this, files without a BOM are read in the ANSI code page.
  '--codepage:65001',
  '-NSSystem;Winapi;FMX;System.Win;Data;Xml;Vcl',
  "-E$OutDir", "-NU$DcuDir",
  "-U$pathArg", "-I$pathArg", "-R$pathArg",
  '-GD'
)
$defines = @($Define)
if ($Config -eq 'Release') {
  $flags += '-$O+', '-$C-', '-$D+', '-$L+'
  $defines += 'RELEASE'
} else {
  $flags += '-$O-', '-$C+', '-$D+', '-$L+', '-V'
  $defines += 'DEBUG'
}
if ($defines.Count -gt 0) { $flags += '-D' + ($defines -join ';') }

# 3. Compile
Write-Host "$DccName $Name [$Config]"
& $Dcc @flags $ProjectPath
if ($LASTEXITCODE -ne 0) { throw "$DccName failed ($LASTEXITCODE)" }

# 4. Runtime dependencies: Skia (SVG icons) for programs that use it
$Sk4d = Join-Path $Bds "Redist\$($Platform.ToLower())\sk4d.dll"
if (Test-Path $Sk4d) { Copy-Item $Sk4d $OutDir -Force }

Write-Host "OK -> $(Join-Path $OutDir "$Name.exe")"
