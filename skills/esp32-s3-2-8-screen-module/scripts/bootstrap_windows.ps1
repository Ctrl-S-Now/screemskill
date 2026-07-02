param(
  [string]$IdfVersion = "v5.4.2"
)

$ErrorActionPreference = "Stop"

function Ensure-WingetPackage([string]$Id) {
  & winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget is required but not available on this Windows system."
}

Write-Host "[1/4] Installing Windows prerequisites"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Ensure-WingetPackage "Git.Git"
}
if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
  Ensure-WingetPackage "Python.Python.3.12"
}

Write-Host "[2/4] Installing Espressif Installation Manager CLI"
if (-not (Get-Command eim -ErrorAction SilentlyContinue)) {
  Ensure-WingetPackage "Espressif.EIM-CLI"
}

$pythonCmd = $null
if (Get-Command py -ErrorAction SilentlyContinue) {
  $pythonCmd = "py"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
  $pythonCmd = "python"
}

if (-not $pythonCmd) {
  throw "Python is still unavailable after installation."
}

Write-Host "[3/4] Installing Python-side helper packages"
& $pythonCmd -m pip install --user --upgrade pip pyyaml pyserial esptool

if (-not (Get-Command eim -ErrorAction SilentlyContinue)) {
  throw "eim was installed but is not yet available on PATH. Open a new PowerShell window and rerun this script."
}

Write-Host "[4/4] Installing ESP-IDF $IdfVersion"
& eim install -i $IdfVersion

Write-Host "Environment bootstrap complete."
