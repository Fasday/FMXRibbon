<#
.SYNOPSIS
  Adds a UTF-8 BOM to every Delphi source (.pas, .dpr, .dpk, .inc, .fmx) that contains non-ASCII characters and has
  none, so the IDE and dcc (without --codepage) read it as UTF-8 instead of the ANSI code page.
#>
$Root = Split-Path $PSScriptRoot -Parent
$bom = [byte[]](0xEF, 0xBB, 0xBF)
Get-ChildItem $Root -Recurse -File -Include *.pas, *.dpr, *.dpk, *.inc, *.fmx |
  Where-Object { $_.FullName -notmatch '\\(bin|dcu|__history|__recovery)\\' } |
  ForEach-Object {
    $bytes = [IO.File]::ReadAllBytes($_.FullName)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if (-not $hasBom -and ($bytes | Where-Object { $_ -ge 0x80 } | Select-Object -First 1)) {
      [IO.File]::WriteAllBytes($_.FullName, $bom + $bytes)
      Write-Host "BOM added: $($_.FullName.Substring($Root.Length + 1))"
    }
  }
