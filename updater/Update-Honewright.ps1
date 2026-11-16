# Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
# SPDX-License-Identifier: GPL-3.0-only

# Honewright updater for WoW Forever (Windows).
# Double-click "Update Honewright.bat" next to this file.
#
# What it does:
#   1. Finds your World of Warcraft\_forever_\Interface\AddOns folder
#      (remembers it after the first run; asks you if it can't find it).
#   2. Checks GitHub for the newest Honewright release. "Update Honewright
#      (testing).bat" takes the newest test build instead (pre-releases
#      that haven't gone to CurseForge yet), for trying changes early.
#   3. If it's newer than what you have, backs up your current copy
#      (next to this script, in "backup") and installs the new one.
# Your settings are stored by WoW in WTF\...\SavedVariables, not in the
# addon folder, so updating never touches them.

param(
  [switch]$Force,    # reinstall even if you're up to date
  [switch]$Testing   # newest build including test builds (pre-releases)
)

$ErrorActionPreference = 'Stop'
$Repo = 'Zudryx/Honewright'   # GitHub owner/name
$ConfigPath = Join-Path $PSScriptRoot 'honewright-updater.json'
$Headers = @{ 'User-Agent' = 'Honewright-Updater'; 'Accept' = 'application/vnd.github+json' }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Find-AddOnsFolder {
  # 1) remembered from last time
  foreach ($path in @($ConfigPath)) {
    if (-not (Test-Path $path)) { continue }
    try {
      $cfg = Get-Content $path -Raw | ConvertFrom-Json
      if ($cfg.AddOns -and (Test-Path $cfg.AddOns)) { return $cfg.AddOns }
    } catch {}
  }

  # 2) Battle.net's install location + common places
  $roots = New-Object System.Collections.Generic.List[string]
  foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                     'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft')) {
    try {
      $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
      if ($p) {
        $p = $p.TrimEnd('\')
        $roots.Add($p)
        $roots.Add((Split-Path $p -Parent))   # InstallPath usually points at ...\_retail_
      }
    } catch {}
  }
  foreach ($drive in @('C', 'D', 'E', 'F')) {
    foreach ($sub in @('Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft',
                       'World of Warcraft', 'Games\World of Warcraft', 'Battle.net\World of Warcraft')) {
      $roots.Add("${drive}:\$sub")
    }
  }
  foreach ($root in ($roots | Select-Object -Unique)) {
    foreach ($flavor in @('_forever_', 'forever')) {
      $game = Join-Path $root $flavor
      if (Test-Path $game) {
        $addons = Join-Path $game 'Interface\AddOns'
        New-Item -ItemType Directory -Force -Path $addons | Out-Null
        return $addons
      }
    }
  }

  # 3) ask
  Write-Host "Couldn't find WoW Forever automatically. Please pick your World of Warcraft\_forever_ folder."
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = 'Select your World of Warcraft\_forever_ folder'
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'No folder selected.' }
  $picked = $dialog.SelectedPath
  if ((Split-Path $picked -Leaf) -ieq 'AddOns') { return $picked }
  if ((Split-Path $picked -Leaf) -ieq 'Interface') { $addons = Join-Path $picked 'AddOns' }
  else { $addons = Join-Path $picked 'Interface\AddOns' }
  New-Item -ItemType Directory -Force -Path $addons | Out-Null
  return $addons
}

function Get-InstalledVersion($addons) {
  $toc = Join-Path $addons 'Honewright\Honewright.toc'
  if (-not (Test-Path $toc)) { return $null }
  $m = Select-String -Path $toc -Pattern '^## Version:\s*([\d\.]+)' | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value }
  return $null
}

function Test-Newer($latest, $installed) {
  if (-not $installed) { return $true }
  try { return ([version]$latest) -gt ([version]$installed) } catch { return $latest -ne $installed }
}

try {
  Write-Host ''
  Write-Host '  Honewright updater' -ForegroundColor Cyan
  Write-Host '  ------------------'

  $addons = Find-AddOnsFolder
  $lastTag = $null
  try { if (Test-Path $ConfigPath) { $lastTag = (Get-Content $ConfigPath -Raw | ConvertFrom-Json).InstalledTag } } catch {}
  @{ AddOns = $addons; InstalledTag = $lastTag } | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
  Write-Host "  AddOns folder: $addons"

  $installed = Get-InstalledVersion $addons
  if ($Testing) {
    # newest release of any kind: test builds are pre-releases
    $all = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases?per_page=20" -Headers $Headers
    $release = $all | Where-Object { -not $_.draft } | Select-Object -First 1
    if (-not $release) { throw 'No Honewright releases found.' }
  } else {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $Headers
  }
  $latest = $release.tag_name.TrimStart('v')
  $shown = if ($installed) { $installed } else { 'not installed' }
  $label = if ($Testing) { 'Newest (test builds included)' } else { 'Latest' }
  Write-Host "  Installed: $shown    ${label}: $latest"

  $upToDate = if ($Testing) { $lastTag -eq $release.tag_name } else { -not (Test-Newer $latest $installed) }
  if (-not $Force -and $upToDate) {
    Write-Host ''
    Write-Host '  You already have the latest Honewright.' -ForegroundColor Green
    return
  }

  $asset = $release.assets | Where-Object { $_.name -like 'Honewright-*.zip' } | Select-Object -First 1   # the addon, not HonewrightUpdater.zip
  if (-not $asset) { throw "Release $latest has no Honewright zip attached." }

  $tmp = Join-Path $env:TEMP ('honewright-update-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp $asset.name
  Write-Host "  Downloading $($asset.name) ..."
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers $Headers -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $new = Join-Path $tmp 'Honewright'
  if (-not (Test-Path (Join-Path $new 'Honewright.toc'))) { throw 'The download looks wrong (no Honewright.toc inside).' }

  $dest = Join-Path $addons 'Honewright'
  $backup = $null
  if (Test-Path $dest) {
    # keep a copy outside the AddOns folder so WoW doesn't try to load it
    $backupRoot = Join-Path $PSScriptRoot 'backup'
    $label = if ($installed) { $installed } else { 'unknown' }
    $backup = Join-Path $backupRoot ("Honewright-$label-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    Copy-Item -Path $dest -Destination $backup -Recurse
    Remove-Item -Path $dest -Recurse -Force
    Write-Host "  Old version backed up to: $backup"
  }
  try {
    Copy-Item -Path $new -Destination $dest -Recurse
  } catch {
    # put the old version back so the addon keeps working
    if ($backup -and (Test-Path $backup)) {
      if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue }
      Copy-Item -Path $backup -Destination $dest -Recurse
      Write-Host '  Install failed - your previous version was restored.' -ForegroundColor Yellow
    }
    throw
  }
  Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue

  @{ AddOns = $addons; InstalledTag = $release.tag_name } | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8

  Write-Host ''
  Write-Host "  Honewright $latest installed." -ForegroundColor Green
  if ($release.prerelease) {
    Write-Host '  This is a test build. "Update Honewright.bat" goes back to the normal releases.' -ForegroundColor Yellow
  }
  Write-Host '  If WoW is running, type /reload in game.'
  if ($release.body) {
    Write-Host ''
    Write-Host '  What changed:' -ForegroundColor Cyan
    $release.body -split "`n" | ForEach-Object { Write-Host "    $_" }
  }
}
catch {
  Write-Host ''
  Write-Host "  Update failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host '  If WoW is open, close the game or the AddOns window and try again.'
  exit 1
}
