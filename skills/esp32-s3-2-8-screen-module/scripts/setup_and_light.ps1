param(
  [Parameter(Mandatory = $true)]
  [string]$Port
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "bootstrap_windows.ps1")
& (Join-Path $PSScriptRoot "flash_merged_firmware.ps1") -Port $Port

Write-Host "Setup and first-boot flash completed. Confirm that the expected image is visible."
