<#
.SYNOPSIS
  Regenerates Demos\WordLike\WordLikeMain.fmx: builds tools\GenForm (with WORDLIKE_GEN, so the form unit does not
  need its .fmx), runs it, then builds the demo.

.EXAMPLE
  .\Demos\WordLike\tools\gen.ps1
  .\Demos\WordLike\tools\gen.ps1 -Platform Win32
#>
param(
  [ValidateSet('Win64', 'Win32')] [string] $Platform = 'Win64',
  [switch] $NoDemo
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Push-Location $Root
try {
  & .\build.ps1 -Project Demos\WordLike\tools\GenForm.dpr -Platform $Platform -Define WORDLIKE_GEN -SearchPath Demos\WordLike
  $exe = Join-Path $Root "bin\$Platform\Debug\GenForm.exe"
  $fmx = Join-Path $Root 'Demos\WordLike\WordLikeMain.fmx'
  $p = Start-Process $exe -ArgumentList "`"$fmx`"" -PassThru
  if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'GenForm did not finish' }
  if ($p.ExitCode -ne 0) { throw "GenForm failed ($($p.ExitCode)): $(Get-Content ([IO.Path]::ChangeExtension($exe, '.err')) -ErrorAction SilentlyContinue)" }
  Write-Host "written: $fmx ($((Get-Item $fmx).Length) bytes)"
  if (-not $NoDemo) { & .\build.ps1 -Project Demos\WordLike\WordLike.dpr -Platform $Platform }
} finally {
  Pop-Location
}
