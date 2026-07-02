param(
  [string]$IdfVersion = "v5.4.2"
)

$ErrorActionPreference = "Stop"

function Ensure-WingetPackage([string]$Id) {
  & winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements
}

function Find-ExistingIdfExport {
  $candidates = @()
  if ($env:IDF_PATH) {
    $candidates += (Join-Path $env:IDF_PATH "export.ps1")
  }
  $candidates += (Join-Path $HOME "esp\esp-idf\export.ps1")
  $candidates += (Join-Path $HOME "espidf\esp-idf\export.ps1")

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  foreach ($root in @((Join-Path $HOME "esp"), (Join-Path $HOME "espidf"))) {
    if (Test-Path $root) {
      $match = Get-ChildItem -Path $root -Filter "export.ps1" -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "[\\/]esp-idf[\\/]export\.ps1$" } |
        Sort-Object FullName |
        Select-Object -First 1
      if ($match) {
        return $match.FullName
      }
    }
  }
  return $null
}

function Ensure-PythonHelpers([string]$PythonCommand) {
  $packages = @{
    "yaml" = "pyyaml"
    "serial" = "pyserial"
    "esptool" = "esptool"
  }
  $missing = @()
  foreach ($module in $packages.Keys) {
    & $PythonCommand -c "import $module" 2>$null
    if ($LASTEXITCODE -ne 0) {
      $missing += $packages[$module]
    }
  }
  if ($missing.Count -gt 0) {
    Write-Host "Installing missing Python helpers: $($missing -join ', ')"
    & $PythonCommand -m pip install --user @missing
  } else {
    Write-Host "Python helpers already available; skipping installation."
  }
}

function Resolve-PythonCommand {
  if (Get-Command py -ErrorAction SilentlyContinue) {
    return "py"
  }
  if (Get-Command python -ErrorAction SilentlyContinue) {
    return "python"
  }
  return $null
}

$existingIdfExport = Find-ExistingIdfExport
if ($existingIdfExport) {
  Write-Host "Reusing existing ESP-IDF: $existingIdfExport"
  . $existingIdfExport | Out-Null
  & idf.py --version
  $pythonCmd = Resolve-PythonCommand
  if (-not $pythonCmd) {
    throw "Python is unavailable even though ESP-IDF is installed."
  }
  Ensure-PythonHelpers $pythonCmd
  Write-Host "Environment bootstrap complete; no ESP-IDF installation was performed."
  exit 0
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

$pythonCmd = Resolve-PythonCommand

if (-not $pythonCmd) {
  throw "Python is still unavailable after installation."
}

Write-Host "[3/4] Installing missing Python-side helper packages"
Ensure-PythonHelpers $pythonCmd

if (-not (Get-Command eim -ErrorAction SilentlyContinue)) {
  throw "eim was installed but is not yet available on PATH. Open a new PowerShell window and rerun this script."
}

Write-Host "[4/4] Installing ESP-IDF $IdfVersion"
& eim install -i $IdfVersion

Write-Host "Environment bootstrap complete."
