param(
  [ValidateSet("build", "flash", "monitor", "full")]
  [string]$Action = "build",
  [string]$Port = ""
)

$ErrorActionPreference = "Stop"

function Test-RepoRoot([string]$PathValue) {
  if (-not $PathValue) {
    return $false
  }
  return (Test-Path (Join-Path $PathValue "ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/main.c"))
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

function Ensure-Idf {
  $idf = Get-Command idf.py -ErrorAction SilentlyContinue
  if ($idf) {
    return
  }

  $exportScript = Join-Path $HOME "esp/esp-idf/export.ps1"
  if (Test-Path $exportScript) {
    . $exportScript | Out-Null
  }

  $idf = Get-Command idf.py -ErrorAction SilentlyContinue
  if (-not $idf) {
    throw "idf.py is not available. Open an ESP-IDF-enabled terminal or install ESP-IDF first."
  }
}

$repoRoot = Resolve-RepoRoot
$projectDir = Join-Path $repoRoot "ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test"

Ensure-Idf

Push-Location $projectDir
try {
  switch ($Action) {
    "build" {
      & idf.py -DIDF_TARGET=esp32s3 build
    }
    "flash" {
      if (-not $Port) {
        throw "Port is required for flash."
      }
      & idf.py -DIDF_TARGET=esp32s3 -p $Port build flash
    }
    "monitor" {
      if (-not $Port) {
        throw "Port is required for monitor."
      }
      & idf.py -DIDF_TARGET=esp32s3 -p $Port monitor
    }
    "full" {
      if (-not $Port) {
        throw "Port is required for full."
      }
      & idf.py -DIDF_TARGET=esp32s3 -p $Port build flash monitor
    }
  }
} finally {
  Pop-Location
}
