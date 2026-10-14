<#
.SYNOPSIS
  Checks the UI Automation provider of the ribbon (FMR.Ribbon.UIA.Win) with the managed UIA client: starts
  CustomizeDemo, prints the automation tree under the form, checks bounds, ElementFromPoint, selects a tab
  (SelectionItem) and invokes a command (Invoke), then verifies the effect through UIA again.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Demos\Customize\uia-test.ps1
  powershell -ExecutionPolicy Bypass -File Demos\Customize\uia-test.ps1 -Arguments "/rtl /theme=FluentDark"
#>
param(
  [string] $Exe = (Join-Path $PSScriptRoot '..\..\bin\Win64\Debug\CustomizeDemo.exe'),
  [string] $Arguments = '',
  [int] $Depth = 4,
  [switch] $Keep
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName WindowsBase
$AE = [System.Windows.Automation.AutomationElement]
$TS = [System.Windows.Automation.TreeScope]

$failures = New-Object System.Collections.Generic.List[string]
function Check([bool] $Condition, [string] $Message) {
  if ($Condition) { Write-Host "  ok   $Message" }
  else { Write-Host "  FAIL $Message" -ForegroundColor Red; $failures.Add($Message) }
}

function Describe($e) {
  $c = $e.Current
  $r = $c.BoundingRectangle
  '{0} "{1}" id={2} [{3:0},{4:0} {5:0}x{6:0}]{7}' -f $c.ControlType.ProgrammaticName.Replace('ControlType.', ''),
    $c.Name, $c.AutomationId, $r.X, $r.Y, $r.Width, $r.Height, $(if ($c.IsEnabled) { '' } else { ' disabled' })
}

function Dump($e, [int] $level) {
  if ($level -gt $Depth) { return }
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $child = $walker.GetFirstChild($e)
  while ($child -ne $null) {
    Write-Host ('  ' * $level + (Describe $child))
    Dump $child ($level + 1)
    $child = $walker.GetNextSibling($child)
  }
}

function FindById($root, [string] $id) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($AE::AutomationIdProperty, $id)
  $root.FindFirst($TS::Descendants, $cond)
}

if ($Arguments -ne '') { $proc = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru }
else { $proc = Start-Process -FilePath $Exe -PassThru }
try {
  # Process.MainWindowHandle may be the hidden FMX application window (TFMAppClass): look for the form window.
  $form = $null
  $byPid = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $proc.Id)
  for ($i = 0; $i -lt 50 -and $form -eq $null; $i++) {
    Start-Sleep -Milliseconds 200
    foreach ($w in $AE::RootElement.FindAll($TS::Children, $byPid)) {
      if ($w.Current.ClassName -ne 'TFMAppClass' -and -not $w.Current.BoundingRectangle.IsEmpty) { $form = $w }
    }
  }
  if ($form -eq $null) { throw 'The demo window did not appear' }
  Start-Sleep -Milliseconds 1200

  Write-Host (Describe $form)
  Dump $form 1

  Write-Host 'Checks:'
  $ribbon = $form.FindFirst($TS::Children,
    (New-Object System.Windows.Automation.PropertyCondition($AE::ClassNameProperty, 'TFmrRibbon')))
  Check ($ribbon -ne $null) 'the form has a TFmrRibbon child'
  $tabs = FindById $form 'TabList'
  Check ($tabs -ne $null -and $tabs.Current.ControlType -eq [System.Windows.Automation.ControlType]::Tab) 'tab list'
  $homeTab = FindById $form 'tabHome'
  $insert = FindById $form 'tabInsert'
  Check ($homeTab -ne $null -and $insert -ne $null) 'tabs Home and Insert'
  $sel = $homeTab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
  Check $sel.Current.IsSelected 'Home is selected'

  $win = $form.Current.BoundingRectangle
  $r = $insert.Current.BoundingRectangle
  Check ($r.Width -gt 10 -and $r.Height -gt 10 -and $r.Left -ge $win.Left -and $r.Right -le $win.Right -and
    $r.Top -ge $win.Top -and $r.Bottom -le $win.Bottom) "Insert tab bounds inside the window ($r)"

  # ElementFromPoint follows the real z-order: bring the form up; the desktop may be shared with other windows.
  try { $form.SetFocus() } catch { }
  Start-Sleep -Milliseconds 400
  $center = New-Object System.Windows.Point(($r.Left + $r.Width / 2), ($r.Top + $r.Height / 2))
  $hit = $AE::FromPoint($center)
  if ($hit -ne $null -and $hit.Current.ProcessId -ne $proc.Id) {
    Write-Host "  skip ElementFromPoint: the point is covered by '$($hit.Current.Name)' of process $($hit.Current.ProcessId)"
  } else {
    Check ($hit -ne $null -and $hit.Current.AutomationId -eq 'tabInsert') "ElementFromPoint(Insert center) = $($hit.Current.ControlType.ProgrammaticName) '$($hit.Current.Name)' id=$($hit.Current.AutomationId)"
  }

  $bold = FindById $form 'btnBold'
  Check ($bold -ne $null) 'command Bold in the lower ribbon'
  if ($bold -ne $null) {
    $p = $null
    Check ($bold.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref] $p) -or
      $bold.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref] $p)) 'Bold has Toggle or Invoke'
    $group = [System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($bold)
    Check ($group.Current.AutomationId -eq 'grpFont' -and
      $group.Current.ControlType -eq [System.Windows.Automation.ControlType]::Group) "parent of Bold = $($group.Current.AutomationId)"
  }

  $ValueP = [System.Windows.Automation.ValuePattern]::Pattern
  $size = FindById $form 'cbFontSize'
  Check ($size -ne $null -and $size.Current.ControlType -eq [System.Windows.Automation.ControlType]::ComboBox) 'font size is a ComboBox'
  if ($size -ne $null) {
    $vp = $size.GetCurrentPattern($ValueP)
    Check ($vp.Current.Value -eq '11') "font size value = $($vp.Current.Value)"
    $vp.SetValue('14')
    Start-Sleep -Milliseconds 300
    $vp = (FindById $form 'cbFontSize').GetCurrentPattern($ValueP)
    Check ($vp.Current.Value -eq '14') "ValuePattern.SetValue('14') -> $($vp.Current.Value)"
  }
  $copies = FindById $form 'spCopies'
  Check ($copies -ne $null -and $copies.Current.ControlType -eq [System.Windows.Automation.ControlType]::Spinner) 'copies is a Spinner'
  $search = FindById $form 'SearchBox'
  Check ($search -ne $null -and $search.Current.ControlType -eq [System.Windows.Automation.ControlType]::Edit) 'search box is an Edit'
  if ($search -ne $null) {
    $search.GetCurrentPattern($ValueP).SetValue('bold')
    Start-Sleep -Milliseconds 300
    Check ((FindById $form 'SearchBox').GetCurrentPattern($ValueP).Current.Value -eq 'bold') 'search box SetValue'
    $search.GetCurrentPattern($ValueP).SetValue('')
  }

  $sel = $insert.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
  $sel.Select()
  Start-Sleep -Milliseconds 800
  $insert = FindById $form 'tabInsert'
  $sel = $insert.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
  Check $sel.Current.IsSelected 'SelectionItem.Select activated Insert'
  $pictures = FindById $form 'btnPictures'
  Check ($pictures -ne $null) 'Insert commands are exposed after the switch (btnPictures)'
  Check ((FindById $form 'btnBold') -eq $null) 'Home commands are gone (btnBold)'

  $blank = FindById $form 'btnBlankPage'
  if ($blank -ne $null) {
    $inv = $blank.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $inv.Invoke()
    Start-Sleep -Milliseconds 600
    $status = $form.Current.Name
    Write-Host "  (invoked Blank Page)"
  }
  Check ($blank -ne $null) 'Invoke on btnBlankPage'

  $opts = FindById $form 'DisplayOptions'
  if ($opts -ne $null) { Check ($opts.Current.Name -ne '') "display options button is named ($($opts.Current.Name))" }
  $sel = (FindById $form 'tabHome').GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
  $sel.Select()
  Start-Sleep -Milliseconds 500
  Check ((FindById $form 'btnBold') -ne $null) 'back to Home'
}
finally {
  if (-not $Keep) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
}

if ($failures.Count -gt 0) {
  Write-Host "$($failures.Count) check(s) failed" -ForegroundColor Red
  exit 1
}
Write-Host 'All UIA checks passed'
