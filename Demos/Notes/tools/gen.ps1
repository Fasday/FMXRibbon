<#
.SYNOPSIS
  Regenerates Demos\Notes\NotesMain.fmx: builds tools\GenForm (with NOTES_GEN, so the form unit does not
  need its .fmx), runs it, then builds the demo.

.EXAMPLE
  .\Demos\Notes\tools\gen.ps1
  .\Demos\Notes\tools\gen.ps1 -Platform Win32
#>
param(
  [ValidateSet('Win64', 'Win32')] [string] $Platform = 'Win64',
  [switch] $NoDemo
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Push-Location $Root
try {
  & .\build.ps1 -Project Demos\Notes\tools\GenForm.dpr -Platform $Platform -Define NOTES_GEN -SearchPath Demos\Notes
  $exe = Join-Path $Root "bin\$Platform\Debug\GenForm.exe"
  $fmx = Join-Path $Root 'Demos\Notes\NotesMain.fmx'
  $p = Start-Process $exe -ArgumentList "`"$fmx`"" -PassThru
  if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'GenForm did not finish' }
  if ($p.ExitCode -ne 0) { throw "GenForm failed ($($p.ExitCode)): $(Get-Content ([IO.Path]::ChangeExtension($exe, '.err')) -ErrorAction SilentlyContinue)" }
  Write-Host "written: $fmx ($((Get-Item $fmx).Length) bytes)"
  if (-not $NoDemo) { & .\build.ps1 -Project Demos\Notes\Notes.dpr -Platform $Platform }
} finally {
  Pop-Location
}
