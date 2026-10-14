<#
.SYNOPSIS
  Command-line build of an FMR Ribbon program (demo, test runner) for Win64 (dcc64), Win32 (dcc32) or Linux64
  (dcclinux64 with FMXWayland).

.DESCRIPTION
  - Output exe/map:  bin\<Platform>\<Config>\
  - DCU:             dcu\<Platform>\<Config>\<ProjectName>\
  - Compiles res\WinApp.rc (PerMonitorV2 manifest) to dcu\WinApp.res; a .dpr includes it with {$R WinApp.res}
    (Windows only: {$IFDEF MSWINDOWS}).
  - Every folder under Source\ is on the search path (Source\Design only for Windows); -SearchPath adds more (e.g.
    FastCanvas, DUnitX).
  - Always a full build (-B), so changed switches never mix with stale DCUs.

  Linux64 (Docs\LINUX.md): the program runs on FMXWayland (-FmxWayland, default f:\Projects\FMXWayland or
  $env:FMXWAYLAND_DIR), a native Wayland backend of FMX that replaces Embarcadero's libfmux:
  1. FMXWayland's tools\gen-fmux-api.ps1 generates FMUX.Api.pas into dcu\Linux64\gen (from the local Delphi; never
     committed). That folder, FMXWayland\src and FMXWayland\src\Protocols come FIRST on the unit path, so the compiler
     uses the generated FMUX.Api instead of the precompiled one.
  2. The Linux platform SDK (-Sdk, default D:\LinuxSDK\ubuntu-22.04, made by FMXWayland's tools\make-linux-sdk.ps1)
     is passed to dcclinux64's linker (--syslibroot, --libpath), as FMXWayland's tools\build.ps1 does.
  3. Delphi 13 ships no Linux64 FMX.Filter.res (FMX.Filter links it): the Win64 one (resources are platform
     independent) is copied to dcu\Linux64\res-fix, which is on the resource path.
  4. libsk4d.so (Skia) and the bundled icon font (Assets\Fonts) are copied next to the program.
  The program must use the Skia canvas (GlobalUseSkia := True in the .dpr, unit FMX.Skia).

.EXAMPLE
  .\build.ps1 -Project Demos\NCProof\NCProof.dpr
  .\build.ps1 -Project Tests\FmrRibbonTests.dpr -Config Debug -Console
  .\build.ps1 -Project Demos\RibbonBasic\RibbonBasic.dpr -Platform Linux64
#>
param(
  [Parameter(Mandatory = $true)] [string] $Project,
  [ValidateSet('Release', 'Debug')] [string] $Config = 'Debug',
  [ValidateSet('Win64', 'Win32', 'Linux64')] [string] $Platform = 'Win64',
  [string[]] $SearchPath = @(),
  [string[]] $Define = @(),
  # Console application (test runners): the .dpr says {$APPTYPE CONSOLE}; nothing else changes.
  [switch] $Console,
  # Linux64: FMXWayland's folder (src, src\Protocols, tools\gen-fmux-api.ps1, tools\delphi-env.ps1).
  [string] $FmxWayland = $(if ($env:FMXWAYLAND_DIR) { $env:FMXWAYLAND_DIR } else { 'f:\Projects\FMXWayland' }),
  # Linux64: the Linux platform SDK to link against (glibc of the SDK = the oldest glibc the program runs with).
  [string] $Sdk = $(if ($env:FMR_LINUX_SDK) { $env:FMR_LINUX_SDK } else { 'D:\LinuxSDK\ubuntu-22.04' })
)

$ErrorActionPreference = 'Stop'

$Bds = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'   # Delphi 13
$Root = $PSScriptRoot
$Linux = $Platform -eq 'Linux64'
$DccName = switch ($Platform) { 'Win32' { 'dcc32' } 'Linux64' { 'dcclinux64' } default { 'dcc64' } }
$Dcc = Join-Path $Bds "bin\$DccName.exe"
$Brcc = Join-Path $Bds 'bin\brcc32.exe'

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
$paths = @()
$libPaths = @()
if ($Linux) {
  if (-not (Test-Path (Join-Path $FmxWayland 'src\FMXWayland.Fmux.pas'))) {
    throw "No FMXWayland at '$FmxWayland' (pass -FmxWayland <folder> or set FMXWAYLAND_DIR; see Docs\LINUX.md)"
  }
  $FmxWayland = (Resolve-Path $FmxWayland).Path
  if (-not (Test-Path (Join-Path $Sdk 'usr\lib\x86_64-linux-gnu\libc.so.6'))) {
    throw "No Linux SDK at '$Sdk' (FMXWayland's tools\make-linux-sdk.ps1 makes one; -Sdk or FMR_LINUX_SDK; see Docs\LINUX.md)"
  }
  $Sdk = (Resolve-Path $Sdk).Path
  $gccDir = Get-ChildItem (Join-Path $Sdk 'usr\lib\gcc\x86_64-linux-gnu') -Directory |
    Sort-Object { [int]($_.Name -replace '\D.*', '') } | Select-Object -Last 1
  if (-not $gccDir) { throw "No usr\lib\gcc\x86_64-linux-gnu\<version> in $Sdk" }
  # Where this Delphi keeps FMX for Linux (product or GetIt package) and the FMUX.Api.pas that matches its units.
  . (Join-Path $FmxWayland 'tools\delphi-env.ps1')
  $DelphiEnv = Get-DelphiEnv $Bds
  $env:BDSCOMMONDIR = $DelphiEnv.CommonDir
  # dcclinux64 runs its linker (ld.lld.exe) from the PATH.
  $env:PATH = "$Bds\bin;$Bds\bin64;$env:PATH"
  $Fmx = Find-FmxLinux $DelphiEnv $Config
  $GenDir = Join-Path $Root 'dcu\Linux64\gen'
  & (Join-Path $FmxWayland 'tools\gen-fmux-api.ps1') -Bds $Bds -Out (Join-Path $GenDir 'FMUX.Api.pas') `
    -Source $Fmx.Source -Config $Config | Out-Host
  $paths += $GenDir, (Join-Path $FmxWayland 'src'), (Join-Path $FmxWayland 'src\Protocols')
}
$paths += $ResDir
$paths += Get-ChildItem (Join-Path $Root 'Source') -Directory -Recurse |
  Where-Object { -not ($Linux -and $_.Name -eq 'Design') } | ForEach-Object { $_.FullName }
$paths += Join-Path $Root 'Source'
$paths += Split-Path $ProjectPath -Parent
$paths += $SearchPath | ForEach-Object { (Resolve-Path $_).Path }
if ($Linux) {
  $delphiLib = Join-Path $Bds "lib\linux64\$($Config.ToLower())"
  # The precompiled FMX for Linux units first when they come from a GetIt package.
  if ($Fmx.DcuDir -ne $delphiLib) { $paths += $Fmx.DcuDir }
  $paths += $delphiLib
  # Delphi 13 has no Linux64 FMX.Filter.res; resources are platform independent: the Win64 one on the resource path.
  if (-not (Test-Path (Join-Path $delphiLib 'FMX.Filter.res'))) {
    $resFix = Join-Path $Root 'dcu\Linux64\res-fix'
    New-Item -ItemType Directory -Force -Path $resFix | Out-Null
    Copy-Item (Join-Path $Bds "lib\win64\$($Config.ToLower())\FMX.Filter.res") $resFix -Force
    $paths += $resFix
  }
  $libPaths = @($Fmx.DcuDir, $delphiLib, (Join-Path $Sdk 'usr\lib\x86_64-linux-gnu'), $gccDir.FullName)
}
$pathArg = ($paths -join ';')

$flags = @(
  '-B', '-Q',
  # Sources are UTF-8 (with or without BOM); without this, files without a BOM are read in the ANSI code page.
  '--codepage:65001'
)
if ($Linux) {
  $flags += '-NSSystem;Xml;Data;Datasnap;Web;Soap;FMX;Posix;Linuxapi',
    "--syslibroot:$Sdk", "--libpath:$($libPaths -join ';')"
} else {
  $flags += '-NSSystem;Winapi;FMX;System.Win;Data;Xml;Vcl'
}
$flags += "-E$OutDir", "-NU$DcuDir", "-U$pathArg", "-I$pathArg", "-R$pathArg", '-GD'
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
if ($Linux) {
  Write-Host "$DccName $Name [$Config], FMXWayland $FmxWayland, SDK $Sdk"
  $out = & $Dcc @flags $ProjectPath 2>&1
  $code = $LASTEXITCODE
  $out | Where-Object { "$_" -notmatch '^(Linker command line:|Embarcadero|Copyright)' } | ForEach-Object { Write-Host "$_" }
  if ($code -ne 0) { throw "$DccName failed ($code)" }
} else {
  Write-Host "$DccName $Name [$Config]"
  & $Dcc @flags $ProjectPath
  if ($LASTEXITCODE -ne 0) { throw "$DccName failed ($LASTEXITCODE)" }
}

# 4. Runtime dependencies: Skia (SVG icons; the canvas on Linux) for programs that use it
$Sk4dName = if ($Linux) { 'libsk4d.so' } else { 'sk4d.dll' }
$Sk4d = Join-Path $Bds "Redist\$($Platform.ToLower())\$Sk4dName"
if (Test-Path $Sk4d) {
  # Another program of the output folder may be running and hold the DLL: an existing copy is fine.
  try { Copy-Item $Sk4d $OutDir -Force -ErrorAction Stop }
  catch { if (-not (Test-Path (Join-Path $OutDir $Sk4dName))) { throw } }
}
if ($Linux) {
  # The icon font that replaces Segoe Fluent Icons on Linux (FMR.Ribbon.IconFont; also found next to the program).
  $fonts = Join-Path $Root 'Assets\Fonts'
  if (Test-Path $fonts) {
    $fontOut = Join-Path $OutDir 'fonts'
    New-Item -ItemType Directory -Force -Path $fontOut | Out-Null
    Get-ChildItem $fonts -Filter '*.ttf' | Copy-Item -Destination $fontOut -Force
  }
  Write-Host "OK -> $(Join-Path $OutDir $Name)"
} else {
  Write-Host "OK -> $(Join-Path $OutDir "$Name.exe")"
}
