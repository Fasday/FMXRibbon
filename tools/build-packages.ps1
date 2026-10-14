<#
.SYNOPSIS
  Command-line build of the FMR Ribbon packages: FMRRibbon (runtime) and dclFMRRibbon (design time).

.DESCRIPTION
  - Win32: both packages with dcc32 (the classic 32-bit IDE, bin\bds.exe).
  - Win64: both packages with dcc64 (the runtime package for Win64 applications; the design package for the 64-bit
    IDE, bin64\bds.exe, which loads Win64 design packages).
  - BPL:  bin\packages\<Platform>\FMRRibbon370.bpl, dclFMRRibbon370.bpl   ({$LIBSUFFIX AUTO})
  - DCP:  dcu\packages\<Platform>\FMRRibbon.dcp, dclFMRRibbon.dcp
  - DCU:  dcu\packages\<Platform>\<Package>\
  - The component icons (Source\Design\FMR.Ribbon.Reg.dcr) are generated from Packages\Icons\*.png when the .dcr
    is missing or -Icons is given; the PNGs are drawn with System.Drawing when they are missing.
  - Warnings that matter for packages (implicitly imported units, W1033) fail the build.
  - -Install registers the design package in the IDE (HKCU "Known Packages" / "Known Packages x64"); the runtime
    BPL folder must then be on the PATH of the IDE (or copy the BPLs with -CopyToBplDir).

.EXAMPLE
  .\tools\build-packages.ps1                       # Win32 + Win64, Release
  .\tools\build-packages.ps1 -Platform Win32 -Config Debug
  .\tools\build-packages.ps1 -CopyToBplDir -Install
#>
param(
  [ValidateSet('All', 'Win32', 'Win64')] [string] $Platform = 'All',
  [ValidateSet('Release', 'Debug')] [string] $Config = 'Release',
  # Rebuild the icon PNGs and the .dcr.
  [switch] $Icons,
  # Only the runtime package.
  [switch] $RuntimeOnly,
  # Copy the BPLs to the public BPL folder of the IDE (on the IDE's PATH).
  [switch] $CopyToBplDir,
  # Register dclFMRRibbon in the IDE (32-bit: Known Packages, 64-bit: Known Packages x64).
  [switch] $Install,
  # Units left out of this build (work in progress of another unit that nothing else uses), e.g.
  # -Exclude FMR.Ribbon.Customize. The packages are then compiled from temporary copies of the .dpk files.
  [string[]] $Exclude = @(),
  # Regenerate Packages\FMRRibbon.dproj and dclFMRRibbon.dproj from the contains/requires clauses of the .dpk files
  # (then build, unless -NoBuild).
  [switch] $UpdateProjects,
  [switch] $NoBuild
)

$ErrorActionPreference = 'Stop'

$Bds = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'   # Delphi 13
$BdsCommon = 'C:\Users\Public\Documents\Embarcadero\Studio\37.0'
$Root = Split-Path $PSScriptRoot -Parent
$PkgDir = Join-Path $Root 'Packages'
$DesignDir = Join-Path $Root 'Source\Design'
$Brcc = Join-Path $Bds 'bin\brcc32.exe'

$env:BDS = $Bds
$env:BDSINCLUDE = Join-Path $Bds 'include'
$env:BDSCOMMONDIR = $BdsCommon

# ---------------------------------------------------------------------------------------------------------------
# Component icons: 16/24/32 px PNG (RCDATA <CLASS>16_PNG, <CLASS>_PNG, <CLASS>32_PNG), see "New in 10.2.2:
# Component icons". Drawn with a glyph of the Segoe icon font on a colored rounded square.
# ---------------------------------------------------------------------------------------------------------------
$IconSpecs = @(
  @{ Class = 'TFmrRibbon';              Glyph = 0xE80F; Color = '#2B579A'; Shape = 'ribbon' },
  @{ Class = 'TFmrBarManager';          Glyph = 0xE8FD; Color = '#3D78B2'; Shape = 'plain' },
  @{ Class = 'TFmrFormFrame';           Glyph = 0xE737; Color = '#4D9F7D'; Shape = 'plain' },
  @{ Class = 'TFmrRibbonBackstageView'; Glyph = 0xE8A5; Color = '#B7472A'; Shape = 'backstage' },
  @{ Class = 'TFmrStatusBar';           Glyph = 0xE9E9; Color = '#787878'; Shape = 'statusbar' },
  @{ Class = 'TFmrPopupMenu';           Glyph = 0xE700; Color = '#8A529F'; Shape = 'plain' },
  @{ Class = 'TFmrBackstageTab';        Glyph = 0xE7C4; Color = '#B7472A'; Shape = 'plain' },
  @{ Class = 'TFmrBackstageButton';     Glyph = 0xE815; Color = '#B7472A'; Shape = 'plain' },
  @{ Class = 'TFmrStatusBarPanel';      Glyph = 0xE75B; Color = '#787878'; Shape = 'plain' },
  @{ Class = 'TFmrBackstageHeader';     Glyph = 0xE8D2; Color = '#B7472A'; Shape = 'plain' },
  @{ Class = 'TFmrBackstageLabel';      Glyph = 0xE8E9; Color = '#B7472A'; Shape = 'plain' },
  @{ Class = 'TFmrBackstageTile';       Glyph = 0xE8A9; Color = '#B7472A'; Shape = 'plain' },
  @{ Class = 'TFmrBackstageGalleryList';Glyph = 0xE8FD; Color = '#B7472A'; Shape = 'plain' },
  @{ Class = 'TFmrCaptionButton';       Glyph = 0xE8BB; Color = '#4D9F7D'; Shape = 'plain' },
  @{ Class = 'TFmrCaptionTitle';        Glyph = 0xE8D2; Color = '#4D9F7D'; Shape = 'plain' }
)

function New-FmrIconPng([hashtable] $Spec, [int] $Size, [string] $Path) {
  Add-Type -AssemblyName System.Drawing
  $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)
    $color = [System.Drawing.ColorTranslator]::FromHtml($Spec.Color)
    $m = [Math]::Max(1, [int]($Size / 16))
    $r = [Math]::Max(2, [int]($Size / 6))
    $rect = New-Object System.Drawing.RectangleF($m, $m, ($Size - 2 * $m), ($Size - 2 * $m))
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $gp.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $gp.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $gp.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $gp.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $gp.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush($color)
    $g.FillPath($brush, $gp)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $light = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 255, 255, 255))
    switch ($Spec.Shape) {
      'ribbon' {
        # Window with a tab row and a body: a band at the top, three "buttons" below.
        $g.FillRectangle($light, $rect.X + $m, $rect.Y + $Size * 0.22, $rect.Width - 2 * $m, $Size * 0.10)
        $bw = ($rect.Width - 4 * $m) / 3
        for ($i = 0; $i -lt 3; $i++) {
          $g.FillRectangle($white, $rect.X + $m + $i * ($bw + $m), $rect.Y + $Size * 0.40, $bw - $m, $Size * 0.36)
        }
        $g.FillRectangle($white, $rect.X + $m * 2, $rect.Y + $Size * 0.10, $Size * 0.22, $Size * 0.10)
      }
      'backstage' {
        $g.FillRectangle($light, $rect.X + $m, $rect.Y + $m, $rect.Width * 0.32, $rect.Height - 2 * $m)
        for ($i = 0; $i -lt 3; $i++) {
          $g.FillRectangle($white, $rect.X + $m * 2, $rect.Y + $Size * (0.22 + 0.18 * $i), $rect.Width * 0.22, [Math]::Max(1, $Size * 0.07))
        }
        $g.FillRectangle($white, $rect.X + $rect.Width * 0.45, $rect.Y + $Size * 0.22, $rect.Width * 0.42, $Size * 0.48)
      }
      'statusbar' {
        $g.FillRectangle($light, $rect.X + $m, $rect.Y + $rect.Height * 0.62, $rect.Width - 2 * $m, $rect.Height * 0.26)
        $g.FillRectangle($white, $rect.X + $m * 2, $rect.Y + $rect.Height * 0.68, $rect.Width * 0.30, $rect.Height * 0.12)
        $g.FillRectangle($white, $rect.X + $rect.Width * 0.62, $rect.Y + $rect.Height * 0.72, $rect.Width * 0.28, [Math]::Max(1, $Size * 0.05))
      }
      default {
        $fontName = 'Segoe Fluent Icons'
        $font = New-Object System.Drawing.Font($fontName, [single]($Size * 0.52), [System.Drawing.GraphicsUnit]::Pixel)
        if ($font.Name -ne $fontName) {
          $font.Dispose()
          $font = New-Object System.Drawing.Font('Segoe MDL2 Assets', [single]($Size * 0.52), [System.Drawing.GraphicsUnit]::Pixel)
        }
        $fmt = New-Object System.Drawing.StringFormat
        $fmt.Alignment = [System.Drawing.StringAlignment]::Center
        $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
        $text = [char]::ConvertFromUtf32([int]$Spec.Glyph)
        $g.DrawString($text, $font, $white, $rect, $fmt)
        $font.Dispose()
      }
    }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $g.Dispose()
    $bmp.Dispose()
  }
}

function Update-FmrIcons {
  $iconDir = Join-Path $PkgDir 'Icons'
  New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
  $rc = New-Object System.Text.StringBuilder
  [void]$rc.AppendLine('/* Component icons of dclFMRRibbon (generated by tools\build-packages.ps1) */')
  foreach ($spec in $IconSpecs) {
    foreach ($size in 16, 24, 32) {
      $suffix = if ($size -eq 24) { '' } else { "$size" }
      $file = Join-Path $iconDir ("{0}{1}.png" -f $spec.Class, $suffix)
      if ($Icons -or -not (Test-Path $file)) { New-FmrIconPng $spec $size $file }
      [void]$rc.AppendLine(('{0}{1}_PNG RCDATA "{2}"' -f $spec.Class.ToUpper(), $suffix, (Split-Path $file -Leaf)))
    }
  }
  $rcFile = Join-Path $iconDir 'FMR.Ribbon.Reg.rc'
  [IO.File]::WriteAllText($rcFile, $rc.ToString(), [Text.Encoding]::ASCII)
  $dcr = Join-Path $DesignDir 'FMR.Ribbon.Reg.dcr'
  # File names in the .rc are relative to the icon folder (no machine-specific paths in the repository)
  Push-Location $iconDir
  try { & $Brcc -fo"$dcr" "$rcFile" | Out-Null } finally { Pop-Location }
  if ($LASTEXITCODE -ne 0) { throw "brcc32 failed for the icons ($LASTEXITCODE)" }
  Write-Host "icons -> $dcr"
}

# ---------------------------------------------------------------------------------------------------------------
# Compilation
# ---------------------------------------------------------------------------------------------------------------
function Invoke-FmrPackage([string] $Dpk, [string] $Plat, [string[]] $ExtraUnitPath) {
  $dccName = if ($Plat -eq 'Win32') { 'dcc32' } else { 'dcc64' }
  $dcc = Join-Path $Bds "bin\$dccName.exe"
  $name = [IO.Path]::GetFileNameWithoutExtension($Dpk)
  $bplDir = Join-Path $Root "bin\packages\$Plat"
  $dcpDir = Join-Path $Root "dcu\packages\$Plat"
  $dcuDir = Join-Path $dcpDir $name
  New-Item -ItemType Directory -Force -Path $bplDir, $dcpDir, $dcuDir | Out-Null
  $lib = Join-Path $Bds ("lib\{0}\release" -f $Plat.ToLower())
  $unitPath = @($dcpDir, $lib) + $ExtraUnitPath
  $pathArg = ($unitPath -join ';')
  if ($Exclude.Count -gt 0) {
    # Temporary copy without the excluded units; relative paths made absolute.
    $tmpDir = Join-Path $Root 'dcu\packages\tmp'
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $lines = Get-Content $Dpk | Where-Object { $l = $_; -not ($Exclude | Where-Object { $l -match ('^\s*' + [regex]::Escape($_) + '\s+in\s') }) }
    $text = ($lines -join "`r`n") -replace "'\.\.\\", ("'" + $Root + '\')
    # The last unit of the contains clause ends with ';' - repair a trailing ',' left by a removed last unit.
    $text = $text -replace ",(\s*)end\.", ';$1end.'
    $Dpk = Join-Path $tmpDir (Split-Path $Dpk -Leaf)
    [IO.File]::WriteAllText($Dpk, $text, [Text.UTF8Encoding]::new($false))
    Write-Host "  (excluded: $($Exclude -join ', '))"
  }
  $flags = @(
    '-B', '-Q',
    '--codepage:65001',
    '-NSSystem;Winapi;FMX;System.Win;Data;Xml;Vcl;Vcl.Imaging;Vcl.Shell',
    "-LE$bplDir", "-LN$dcpDir", "-NU$dcuDir",
    "-U$pathArg", "-I$pathArg", "-R$pathArg"
  )
  if ($Config -eq 'Release') {
    $flags += '-$O+', '-$D-', '-$L-', '-$C-', '-DRELEASE'
  } else {
    $flags += '-$O-', '-$D+', '-$L+', '-$C+', '-DDEBUG'
  }
  Write-Host "$dccName $name [$Plat $Config]"
  Push-Location $PkgDir
  try {
    $out = & $dcc @flags $Dpk 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
  } finally { Pop-Location }
  $errors = @($out | Where-Object { $_ -match '\b(Error|Fatal)\b' })
  $warnings = @($out | Where-Object { $_ -match '\bWarning\b' })
  $hints = @($out | Where-Object { $_ -match '\bHint\b' })
  $implicit = @($out | Where-Object { $_ -match 'W1033|implicitly imported' })
  $errors + $warnings + $hints | ForEach-Object { Write-Host "  $_" }
  if ($code -ne 0 -or $errors.Count -gt 0) { throw "$dccName $name failed ($code)" }
  if ($implicit.Count -gt 0) { throw "$name has implicitly imported units: list them in the package or require their package" }
  $bpl = Get-ChildItem $bplDir -Filter "$name*.bpl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  Write-Host ("  OK -> {0} ({1} warnings, {2} hints)" -f $bpl.FullName, $warnings.Count, $hints.Count)
  return $bpl.FullName
}

# ---------------------------------------------------------------------------------------------------------------
# .dproj files (MSBuild projects of the IDE) generated from the .dpk files
# ---------------------------------------------------------------------------------------------------------------
function Write-FmrDproj([string] $Name, [string] $Guid, [string] $Description, [bool] $Design) {
  $dpkText = Get-Content (Join-Path $PkgDir "$Name.dpk") -Raw
  $requires = [regex]::Match($dpkText, '(?s)\brequires\b(.*?);').Groups[1].Value -split ',' |
    ForEach-Object { ($_ -replace '//.*', '').Trim() } | Where-Object { $_ }
  $units = [regex]::Matches($dpkText, "(?m)^\s*([\w\.]+)\s+in\s+'([^']+)'") | ForEach-Object { $_.Groups[2].Value }
  $refs = New-Object System.Text.StringBuilder
  foreach ($r in $requires) { [void]$refs.AppendLine("        <DCCReference Include=""$r.dcp""/>") }
  foreach ($u in $units) { [void]$refs.AppendLine("        <DCCReference Include=""$u""/>") }
  $kind = if ($Design) { '<DesignOnlyPackage>true</DesignOnlyPackage>' } else { '<RuntimeOnlyPackage>true</RuntimeOnlyPackage>' }
  $xml = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <!-- Generated by tools\build-packages.ps1 -UpdateProjects from $Name.dpk. -->
    <PropertyGroup>
        <ProjectGuid>{$Guid}</ProjectGuid>
        <MainSource>$Name.dpk</MainSource>
        <ProjectVersion>20.3</ProjectVersion>
        <FrameworkType>None</FrameworkType>
        <Base>True</Base>
        <Config Condition="'`$(Config)'==''">Release</Config>
        <Platform Condition="'`$(Platform)'==''">Win32</Platform>
        <TargetedPlatforms>3</TargetedPlatforms>
        <AppType>Package</AppType>
        <ProjectName Condition="'`$(ProjectName)'==''">$Name</ProjectName>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Config)'=='Base' or '`$(Base)'!=''">
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('`$(Platform)'=='Win32' and '`$(Base)'=='true') or '`$(Base_Win32)'!=''">
        <Base_Win32>true</Base_Win32>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('`$(Platform)'=='Win64' and '`$(Base)'=='true') or '`$(Base_Win64)'!=''">
        <Base_Win64>true</Base_Win64>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Config)'=='Debug' or '`$(Cfg_1)'!=''">
        <Cfg_1>true</Cfg_1>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Config)'=='Release' or '`$(Cfg_2)'!=''">
        <Cfg_2>true</Cfg_2>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Base)'!=''">
        $kind
        <SanitizedProjectName>$Name</SanitizedProjectName>
        <DllSuffix>`$(Auto)</DllSuffix>
        <GenPackage>true</GenPackage>
        <GenDll>true</GenDll>
        <DCC_Description>$Description</DCC_Description>
        <DCC_ImplicitBuild>false</DCC_ImplicitBuild>
        <DCC_CodePage>65001</DCC_CodePage>
        <DCC_Namespace>System;Winapi;FMX;System.Win;Data;Xml;Vcl;Vcl.Imaging;`$(DCC_Namespace)</DCC_Namespace>
        <DCC_BplOutput>..\bin\packages\`$(Platform)</DCC_BplOutput>
        <DCC_DcpOutput>..\dcu\packages\`$(Platform)</DCC_DcpOutput>
        <DCC_DcuOutput>..\dcu\packages\`$(Platform)\$Name</DCC_DcuOutput>
        <DCC_UnitSearchPath>..\dcu\packages\`$(Platform);`$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
        <VerInfo_IncludeVerInfo>false</VerInfo_IncludeVerInfo>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Cfg_1)'!=''">
        <DCC_Define>DEBUG;`$(DCC_Define)</DCC_Define>
        <DCC_Optimize>false</DCC_Optimize>
        <DCC_GenerateStackFrames>true</DCC_GenerateStackFrames>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Cfg_2)'!=''">
        <DCC_Define>RELEASE;`$(DCC_Define)</DCC_Define>
        <DCC_LocalDebugSymbols>false</DCC_LocalDebugSymbols>
        <DCC_DebugInformation>0</DCC_DebugInformation>
    </PropertyGroup>
    <ItemGroup>
        <DelphiCompile Include="`$(MainSource)">
            <MainSource>MainSource</MainSource>
        </DelphiCompile>
$($refs.ToString().TrimEnd())
        <BuildConfiguration Include="Base">
            <Key>Base</Key>
        </BuildConfiguration>
        <BuildConfiguration Include="Debug">
            <Key>Cfg_1</Key>
            <CfgParent>Base</CfgParent>
        </BuildConfiguration>
        <BuildConfiguration Include="Release">
            <Key>Cfg_2</Key>
            <CfgParent>Base</CfgParent>
        </BuildConfiguration>
    </ItemGroup>
    <ProjectExtensions>
        <Borland.Personality>Delphi.Personality.12</Borland.Personality>
        <Borland.ProjectType>Package</Borland.ProjectType>
        <BorlandProject>
            <Delphi.Personality>
                <Source>
                    <Source Name="MainSource">$Name.dpk</Source>
                </Source>
            </Delphi.Personality>
            <Platforms>
                <Platform value="Win32">True</Platform>
                <Platform value="Win64">True</Platform>
            </Platforms>
        </BorlandProject>
        <ProjectFileVersion>12</ProjectFileVersion>
    </ProjectExtensions>
    <Import Condition="Exists('`$(BDS)\Bin\CodeGear.Delphi.Targets')" Project="`$(BDS)\Bin\CodeGear.Delphi.Targets"/>
    <Import Condition="Exists('`$(APPDATA)\Embarcadero\`$(BDSAPPDATABASEDIR)\`$(PRODUCTVERSION)\UserTools.proj')" Project="`$(APPDATA)\Embarcadero\`$(BDSAPPDATABASEDIR)\`$(PRODUCTVERSION)\UserTools.proj"/>
</Project>
"@
  [IO.File]::WriteAllText((Join-Path $PkgDir "$Name.dproj"), $xml, [Text.UTF8Encoding]::new($false))
  Write-Host "project -> Packages\$Name.dproj ($($units.Count) units)"
}

if ($UpdateProjects) {
  Write-FmrDproj 'FMRRibbon' '01D72EAD-8126-4E73-8419-2C76D9AC0079' 'FMR Ribbon for FireMonkey' $false
  Write-FmrDproj 'dclFMRRibbon' 'B83F5DC6-D7DC-42F9-AAB7-113F75731910' 'FMR Ribbon for FireMonkey - design time' $true
  if ($NoBuild) { return }
}

# Every unit of the run-time folders must be in FMRRibbon.dpk (and every design unit in dclFMRRibbon.dpk):
# otherwise it would be implicitly imported or missing in the IDE.
function Test-FmrPackageUnits([string] $Dpk, [string[]] $Folders) {
  $text = Get-Content (Join-Path $PkgDir $Dpk) -Raw
  $missing = @()
  foreach ($folder in $Folders) {
    Get-ChildItem (Join-Path $Root "Source\$folder") -Filter '*.pas' -ErrorAction SilentlyContinue | ForEach-Object {
      $unit = [IO.Path]::GetFileNameWithoutExtension($_.Name)
      if ($Exclude -contains $unit) { return }
      if ($text -notmatch ('(?m)^\s*' + [regex]::Escape($unit) + '\s+in\s')) { $missing += "$folder\$($_.Name)" }
    }
  }
  if ($missing.Count -gt 0) {
    throw "$Dpk does not contain: $($missing -join ', ') (add them to the contains clause and the .dproj)"
  }
}
Test-FmrPackageUnits 'FMRRibbon.dpk' @('Core', 'Themes', 'Frame', 'Extras', 'Ribbon', 'Templates')
if (-not $RuntimeOnly) { Test-FmrPackageUnits 'dclFMRRibbon.dpk' @('Design') }

$platforms = if ($Platform -eq 'All') { @('Win32', 'Win64') } else { @($Platform) }
if (-not $RuntimeOnly) {
  if ($Icons -or -not (Test-Path (Join-Path $DesignDir 'FMR.Ribbon.Reg.dcr'))) { Update-FmrIcons }
}

$built = @{}
foreach ($plat in $platforms) {
  $built["$plat.runtime"] = Invoke-FmrPackage (Join-Path $PkgDir 'FMRRibbon.dpk') $plat @()
  if (-not $RuntimeOnly) {
    $built["$plat.design"] = Invoke-FmrPackage (Join-Path $PkgDir 'dclFMRRibbon.dpk') $plat @($DesignDir)
  }
}

if ($CopyToBplDir) {
  foreach ($plat in $platforms) {
    $target = if ($plat -eq 'Win32') { Join-Path $BdsCommon 'Bpl' } else { Join-Path $BdsCommon 'Bpl\Win64' }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Get-ChildItem (Join-Path $Root "bin\packages\$plat") -Filter '*.bpl' | Copy-Item -Destination $target -Force
    Write-Host "copied $plat BPLs -> $target"
  }
}

if ($Install -and -not $RuntimeOnly) {
  foreach ($plat in $platforms) {
    $key = if ($plat -eq 'Win32') { 'Known Packages' } else { 'Known Packages x64' }
    $regPath = "HKCU:\Software\Embarcadero\BDS\37.0\$key"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    $bpl = $built["$plat.design"]
    if ($CopyToBplDir) {
      $target = if ($plat -eq 'Win32') { Join-Path $BdsCommon 'Bpl' } else { Join-Path $BdsCommon 'Bpl\Win64' }
      $bpl = Join-Path $target (Split-Path $bpl -Leaf)
    }
    New-ItemProperty -Path $regPath -Name $bpl -Value 'FMR Ribbon for FireMonkey - design time' -PropertyType String -Force | Out-Null
    Write-Host "registered $bpl in '$key'"
  }
}
