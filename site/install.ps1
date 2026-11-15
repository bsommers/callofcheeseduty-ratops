<#
.SYNOPSIS
  KASEKRIEG: RAT OPS installer for Windows (x64).
.DESCRIPTION
  Downloads the latest GitHub Release setup zip, verifies its SHA-256 against the
  release's SHA256SUMS, extracts it and runs the bundled per-user installer
  (no admin needed). Use -AllUsers (elevated) to install to Program Files.
.EXAMPLE
  irm https://bsommers.github.io/callofcheeseduty-ratops/install.ps1 | iex
.EXAMPLE
  & ([scriptblock]::Create((irm https://bsommers.github.io/callofcheeseduty-ratops/install.ps1))) -DryRun
#>
[CmdletBinding()]
param(
  [switch]$AllUsers,
  [switch]$DryRun,
  [switch]$Uninstall,
  [string]$BaseUrl = "https://github.com/bsommers/callofcheeseduty-ratops/releases/latest/download"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is much faster without the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($Uninstall) {
  $dirs = @((Join-Path $env:LOCALAPPDATA "Programs\KasekriegRatOps"), (Join-Path $env:ProgramFiles "KasekriegRatOps"))
  foreach ($d in $dirs) {
    $u = Join-Path $d "uninstall.ps1"
    if (Test-Path $u) {
      if ($DryRun) { Write-Host "[dry-run] would run $u" } else { & powershell -NoProfile -ExecutionPolicy Bypass -File $u }
      return
    }
  }
  Write-Host "Nothing to uninstall (or use Apps & Features)."; return
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("ratops-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  Write-Host "Fetching checksum list from $BaseUrl/SHA256SUMS"
  $raw = (Invoke-WebRequest -UseBasicParsing "$BaseUrl/SHA256SUMS").Content
  if ($raw -is [byte[]]) { $raw = [Text.Encoding]::UTF8.GetString($raw) }   # served as octet-stream
  $sums = $raw -split "`r?`n"
  $line = $sums | Where-Object { $_ -match 'windows-x64-setup\.zip\s*$' } | Select-Object -First 1
  if (-not $line) { throw "No Windows asset listed in SHA256SUMS (has a GitHub Release been published?)" }
  $parts = $line.Trim() -split '\s+', 2
  $want = $parts[0].ToLowerInvariant()
  $file = $parts[1].TrimStart('*')
  if ($file -match '[\\/]|\.\.') { throw "Suspicious file name in SHA256SUMS: $file" }
  Write-Host "Asset:    $file"
  Write-Host "Expected: $want"
  Write-Host "Download: $BaseUrl/$file (about 190 MB)"
  if ($DryRun) { Write-Host "[dry-run] would download, verify, extract and run install.ps1 (AllUsers=$AllUsers). Nothing changed."; return }

  $zip = Join-Path $work $file
  Invoke-WebRequest -UseBasicParsing "$BaseUrl/$file" -OutFile $zip
  $got = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
  if ($got -ne $want) { throw "Checksum mismatch (expected $want, got $got). Nothing installed." }
  Write-Host "Checksum OK."

  Expand-Archive -Path $zip -DestinationPath $work -Force
  $installer = Get-ChildItem -Path $work -Recurse -Filter install.ps1 | Select-Object -First 1
  if (-not $installer) { throw "install.ps1 not found inside the zip" }
  $extra = @(); if ($AllUsers) { $extra += "-AllUsers" }
  & powershell -NoProfile -ExecutionPolicy Bypass -File $installer.FullName @extra
  if ($LASTEXITCODE -ne 0) { throw "Bundled installer failed (exit $LASTEXITCODE)" }
  Write-Host "Done. Launch KASEKRIEG RAT OPS from the Start Menu."
  Write-Host "SmartScreen may warn on first run because the build is unsigned: More info > Run anyway."
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
