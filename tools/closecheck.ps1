<#
.SYNOPSIS
  Drives a demo with tools\drive.ps1 (-Keep), then closes its main form with WM_CLOSE and waits for the process to
  end. Debug builds report memory leaks in a message box on exit: a process that does not end in time is reported
  (and a screenshot of its windows is taken) - the leak report is visible there.

.EXAMPLE
  .\tools\closecheck.ps1 -Arguments "/open=minitoolbar" -Actions "key:shift;wait:2500;click:1000,380;text:28;key:enter"
#>
param(
  [string] $Exe = 'bin\Win64\Debug\RibbonBasic.exe',
  [string] $Arguments = '',
  [string] $Actions = '',
  [string] $Out = 'shots\closecheck.png',
  [int] $Timeout = 10000
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$name = [IO.Path]::GetFileNameWithoutExtension($Exe)
& (Join-Path $here 'drive.ps1') -Exe $Exe -Arguments $Arguments -Actions $Actions -Out $Out -Keep | Out-Null
$proc = Get-Process $name -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $proc) { Write-Host "closecheck: process ended already"; exit 0 }
$form = [RibbonDrive]::FindForm([uint32]$proc.Id)
[void][RibbonDrive]::PostMessage($form, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
if ($proc.WaitForExit($Timeout)) {
  Write-Host "closecheck: exited (code $($proc.ExitCode))"
  exit 0
}
& (Join-Path $here 'capture.ps1') -ProcessId $proc.Id -Out ($Out -replace '\.png$', '_hang.png')
Write-Host "closecheck: still running after $Timeout ms (leak report or hang) - see the _hang screenshot"
Stop-Process -Id $proc.Id
exit 1
