#!/usr/bin/env pwsh
# Copyright 2018 the Wasmer authors. All rights reserved. MIT license.
# TODO(everyone): Keep this script simple and easily auditable.

$ErrorActionPreference = 'Stop'

if ($v) {
  $Version = "${v}" # "v${v}"
}
if ($args.Length -eq 1) {
  $Version = $args.Get(0)
}

$WasmerInstall = $env:WASMER_DIR
$WasmerDir = if ($WasmerInstall) {
  "$WasmerInstall"
} else {
  "$Home\.wasmer"
}

$WasmerInstaller = "$Home\temp-wasmer-installer.exe"
$WasmerBinDir = "$WasmerDir\bin"
$WapmArchive = "$Home\wapm-archive.tar.gz"
$WapmArchiveInflated = "$Home\wapm-archive.tar"
$Target = 'windows'

$allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
  Write-Output "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run the Wasmer Installer."
  Write-Output "For example, to set the execution policy to 'RemoteSigned' please run :"
  Write-Output "'Set-ExecutionPolicy RemoteSigned -scope CurrentUser'"
  break
}

# GitHub requires TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$WasmerInstallerUri = if (!$Version) {
  Write-Host "Fetching latest Wasmer release..."
  $Response = Invoke-RestMethod -Uri 'https://api.github.com/repos/wasmerio/wasmer/releases/latest' -UseBasicParsing
  ( 
    $Response.assets | 
    Where-Object { $_.name -eq "wasmer-${Target}.exe" } | 
    Select-Object -First 1 
  ).browser_download_url
} else {
  "https://github.com/wasmerio/wasmer/releases/download/${Version}/wasmer-${Target}.exe"
}

if (!(Test-Path $WasmerDir)) {
  New-Item $WasmerDir -ItemType Directory | Out-Null
}

if (Test-Path $WasmerInstaller) {
  Remove-Item $WasmerInstaller
}

Write-Host "Downloading Wasmer..."

Invoke-WebRequest $WasmerInstallerUri -OutFile $WasmerInstaller -UseBasicParsing

Write-Output "Installing Wasmer..."

Start-Process $WasmerInstaller -Wait -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$WasmerDir`" /SP-"
Remove-Item $WasmerInstaller

Write-Output "Adding Wasmer to ENV:Path $WasmerBinDir..."

$User = [EnvironmentVariableTarget]::User
$Path = [Environment]::GetEnvironmentVariable('Path', $User)
if (!(";$Path;".ToLower() -like "*;$WasmerBinDir;*".ToLower())) {
  Write-Output "Adding Wasmer bin directory ($WasmerBinDir) to Environment path..."
  [Environment]::SetEnvironmentVariable('Path', "$Path;$WasmerBinDir", $User)
  $Env:Path += ";$WasmerBinDir"
}

Write-Host "Wasmer installed" -ForegroundColor Green

$WapmUri = if ($true) {
  Write-Host "Fetching latest WAPM release..."
  $Response = Invoke-RestMethod -Uri 'https://api.github.com/repos/wasmerio/wapm-cli/releases/latest' -UseBasicParsing
  (
  $Response.assets |
          Where-Object { $_.name -eq "wapm-cli-${Target}-amd64.tar.gz" } |
          Select-Object -First 1
  ).browser_download_url
}

Write-Host "Downloading WAPM..."

Invoke-WebRequest $WapmUri -OutFile $WapmArchive -UseBasicParsing

$Installed7Zip = if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
  Write-Host "Installing 7Zip script for tar extraction"
  Install-Package -Scope CurrentUser -Force 7Zip4PowerShell > $null
  $true
} else {
  $false
}

Write-Output "Inflating $WapmArchive..."
Expand-7Zip $WapmArchive $Home
Remove-Item $WapmArchive
Write-Output "Extracting $WapmArchiveInflated to $WasmerBinDir..."
# 7zip doesn't support inflating and extracting in the same step
Expand-7Zip $WapmArchiveInflated "$WasmerBinDir\.."
Remove-Item $WapmArchiveInflated
Write-Host "Wapm installed" -ForegroundColor Green

Write-Host "Finished" -ForegroundColor Green

Write-Output "Run '$WasmerBinDir\wasmer --help' to get started"
