param(
  [Parameter(Mandatory = $true)]
  [string]$Port,
  [string]$Baud = "921600"
)

$ErrorActionPreference = "Stop"

function Test-RepoRoot([string]$PathValue) {
  if (-not $PathValue) {
    return $false
  }
  return (Test-Path (Join-Path $PathValue "Firmware/ESP32-S3-2.8-Image-Test.bin"))
}

function Resolve-RepoRoot {
  $candidates = @()
  if ($env:ESP32_S3_TOUCH_LCD_REPO) {
    $candidates += $env:ESP32_S3_TOUCH_LCD_REPO
  }
  $candidates += (Join-Path (Join-Path $HOME ".codex") "esp32-s3-screen-skill")
  $candidates += $PSScriptRoot
  $candidates += (Get-Location).Path

  foreach ($candidate in $candidates) {
    $current = [System.IO.Path]::GetFullPath($candidate)
    while ($true) {
      if (Test-RepoRoot $current) {
        return $current
      }
      $parent = Split-Path $current -Parent
      if (-not $parent -or $parent -eq $current) {
        break
      }
      $current = $parent
    }
  }

  throw "Unable to locate the repository root. Set ESP32_S3_TOUCH_LCD_REPO or run from inside the repo."
}

$repoRoot = Resolve-RepoRoot
$firmware = Join-Path $repoRoot "Firmware/ESP32-S3-2.8-Image-Test.bin"

$hasEsptoolCommand = Get-Command esptool.py -ErrorAction SilentlyContinue
if (-not $hasEsptoolCommand) {
  $pythonProbe = if (Get-Command py -ErrorAction SilentlyContinue) { "py" } elseif (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { $null }
  if ($pythonProbe) {
    & $pythonProbe -c "import esptool" 2>$null
  }
  if (-not $pythonProbe -or $LASTEXITCODE -ne 0) {
    foreach ($root in @((Join-Path $HOME "esp"), (Join-Path $HOME "espidf"))) {
      if (Test-Path $root) {
        $export = Get-ChildItem -Path $root -Filter "export.ps1" -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -match "[\\/]esp-idf[\\/]export\.ps1$" } |
          Sort-Object FullName |
          Select-Object -First 1
        if ($export) {
          . $export.FullName | Out-Null
          break
        }
      }
    }
  }
}

$esptool = Get-Command esptool.py -ErrorAction SilentlyContinue
if ($esptool) {
  & esptool.py --chip esp32s3 --port $Port --baud $Baud write_flash 0x0 $firmware
  exit $LASTEXITCODE
}

$py = Get-Command py -ErrorAction SilentlyContinue
if ($py) {
  & py -c "import esptool" 2>$null
  if ($LASTEXITCODE -eq 0) {
    & py -m esptool --chip esp32s3 --port $Port --baud $Baud write_flash 0x0 $firmware
    exit $LASTEXITCODE
  }
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
  & python -c "import esptool" 2>$null
  if ($LASTEXITCODE -eq 0) {
    & python -m esptool --chip esp32s3 --port $Port --baud $Baud write_flash 0x0 $firmware
    exit $LASTEXITCODE
  }
}

throw "esptool.py or python is required to flash the first-boot image firmware."
