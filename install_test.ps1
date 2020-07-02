#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

# Test that we can install the latest version at the default location.
Remove-Item "~\.wasmer" -Recurse -Force -ErrorAction SilentlyContinue
$env:WASMER_DIR = ""
$v = $null; .\install.ps1
~\.wasmer\bin\wasmer.exe --version

# Test that we can install a specific version at a custom location.
Remove-Item "~\wasmer-0.17.1" -Recurse -Force -ErrorAction SilentlyContinue
$env:WASMER_DIR = "$Home\wasmer-0.17.1"
$v = "0.17.1"; .\install.ps1
$WasmerVersion = ~\wasmer-0.17.1\bin\wasmer.exe --version
if (!($WasmerVersion -like '*0.17.1*')) {
  throw $WasmerVersion
}
