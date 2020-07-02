#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

# Test that we can install the latest version at the default location.
Remove-Item "~\.wasmer" -Recurse -Force -ErrorAction SilentlyContinue
$env:WASMER_DIR = ""
$v = $null; .\install.ps1
~\.wasmer\bin\wasmer.exe --version

# Test that we can install a specific version at a custom location.
Remove-Item "~\wasmer-0.17.0" -Recurse -Force -ErrorAction SilentlyContinue
$env:WASMER_DIR = "$Home\wasmer-0.17.0"
$v = "0.17.0"; .\install.ps1
$WasmerVersion = ~\wasmer-0.17.0\bin\wasmer.exe --version
if (!($WasmerVersion -like '*0.17.0*')) {
  throw $WasmerVersion
}

# Test that the old temp file installer still works.
Remove-Item "~\wasmer-0.17.1" -Recurse -Force -ErrorAction SilentlyContinue
$env:DENO_INSTALL = "$Home\deno-1.0.1"
$v = $null; .\install.ps1 v1.0.1
$DenoVersion = ~\deno-1.0.1\bin\deno.exe --version
if (!($DenoVersion -like '*1.0.1*')) {
  throw $DenoVersion
}
