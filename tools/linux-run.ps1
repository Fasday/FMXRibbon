<#
.SYNOPSIS
  Runs a Linux64 FMR Ribbon program (built with .\build.ps1 -Platform Linux64) on a private headless Weston in WSL and
  keeps compositor screenshots and the program's own frame dumps. Moves no mouse, types nothing, opens no window on
  the desktop (Docs\LINUX.md, "Running").

.DESCRIPTION
  tools\linux-run.sh starts Weston (headless backend, pixman renderer, --debug for weston-screenshooter) with its own
  XDG_RUNTIME_DIR (/tmp/fmr-ribbon-rt.*) and socket (fmr-ribbon-<pid>), runs the program with
  FMXWAYLAND_DUMP_DIR=<Out>, takes screenshots at the given seconds (screen-1.png, ...) and stops the program
  (SIGTERM) a second after the last one. The frame dumps of each moment (one BMP per window, popups included) are
  kept in dump-<n> and converted to PNG.

  Output folder (default shots\linux\<program>): screen-<n>.png, dump-<n>\<window>-<id>.png, program.log, weston.log.

.EXAMPLE
  .\tools\linux-run.ps1 -Exe bin\Linux64\Debug\RibbonBasic -Arguments '/theme=Modern2024Dark'
  .\tools\linux-run.ps1 -Exe bin\Linux64\Debug\RibbonBasic -Arguments '/open=cover' -Shots 3,5 -Out shots\linux\cover
#>
param(
  [string] $Exe = 'bin\Linux64\Debug\RibbonBasic',
  [string[]] $Arguments = @(),
  [string] $Out = '',
  [int] $Scale = 1,
  [int] $Width = 1400,
  [int] $Height = 860,
  [int[]] $Shots = @(4),
  [int] $RunFor = 0,
  [ValidateRange(0, 3)] [int] $Log = 1,
  # FMXWAYLAND_CSD=0: no client-side decorations of FMXWayland (with RibbonBasic /waylandframe=preview).
  [switch] $CsdOff,
  # More environment variables of the program: 'NAME=value', ...
  [string[]] $Env = @(),
  [string] $Distro = 'Ubuntu-26.04'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-WslPath([string] $Path) {
  '/mnt/' + $Path.Substring(0, 1).ToLower() + $Path.Substring(2).Replace('\', '/')
}

$Root = Split-Path $PSScriptRoot -Parent
$ExePath = (Resolve-Path $Exe).Path
$name = [IO.Path]::GetFileNameWithoutExtension($ExePath)
if (-not $Out) { $Out = Join-Path $Root "shots\linux\$name" }
$Out = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path (Get-Location) $Out }))
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$envs = @("SHOTS=$($Shots -join ' ')", "FMXWAYLAND_LOG=$Log")
if ($RunFor -gt 0) { $envs += "RUN_FOR=$RunFor" }
if ($CsdOff) { $envs += 'FMXWAYLAND_CSD=0' }
$envs += $Env
$script = ConvertTo-WslPath (Join-Path $PSScriptRoot 'linux-run.sh')
# The .sh may have Windows line ends after a checkout without .gitattributes: run a copy with LF.
$text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'linux-run.sh')).Replace("`r`n", "`n")
$tmpSh = Join-Path $Out 'linux-run.sh'
[IO.File]::WriteAllText($tmpSh, $text, (New-Object Text.UTF8Encoding $false))
wsl -d $Distro -u root -- env @envs sh (ConvertTo-WslPath $tmpSh) (ConvertTo-WslPath $Out) $Scale $Width $Height `
  (ConvertTo-WslPath $ExePath) @Arguments 2>&1 | Out-Null
Remove-Item $tmpSh -Force

Add-Type -AssemblyName System.Drawing
Get-ChildItem $Out -Filter '*.bmp' -Recurse | ForEach-Object {
  # A dump written while the program was stopped may be cut: keep the BMP then.
  try {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    try { $img.Save([IO.Path]::ChangeExtension($_.FullName, '.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $img.Dispose() }
    Remove-Item $_.FullName -Force
  } catch {
    Write-Host "  (cannot read $($_.Exception.Message): $($_.TargetObject))"
  }
}
$logFile = Join-Path $Out 'program.log'
if (Test-Path $logFile) {
  Get-Content $logFile -Encoding UTF8 | Select-Object -Last 15 | ForEach-Object { Write-Host "  | $_" }
}
Get-ChildItem $Out -Filter '*.png' -Recurse | ForEach-Object { Write-Host "  $($_.FullName)" }
