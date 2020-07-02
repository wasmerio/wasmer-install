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
$WasmerExe = "$WasmerDir\bin\wasmer.exe"
$Target = 'windows'

# GitHub requires TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$WasmerInstallerUri = if (!$Version) {
  Write-Host "Fetching lastest release..."
  $Response = Invoke-WebRequest 'https://github.com/wasmerio/wasmer/releases' -UseBasicParsing
  if ($PSVersionTable.PSEdition -eq 'Core') {
    $Response.Links |
      Where-Object { $_.href -like "/wasmerio/wasmer/releases/download/*/wasmer-${Target}.exe" } |
      ForEach-Object { 'https://github.com' + $_.href } |
      Select-Object -First 1
  } else {
    $HTMLFile = New-Object -Com HTMLFile
    if ($HTMLFile.IHTMLDocument2_write) {
      $HTMLFile.IHTMLDocument2_write($Response.Content)
    } else {
      $ResponseBytes = [Text.Encoding]::Unicode.GetBytes($Response.Content)
      $HTMLFile.write($ResponseBytes)
    }
    $HTMLFile.getElementsByTagName('a') |
      Where-Object { $_.href -like "about:/wasmerio/wasmer/releases/download/*/wasmer-${Target}.exe" } |
      ForEach-Object { $_.href -replace 'about:', 'https://github.com' } |
      Select-Object -First 1
  }
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
Write-Output "Run '$WasmerBinDir\wasmer --help' to get started"
