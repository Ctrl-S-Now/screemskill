param(
  [string]$RepoUrl = $env:ESP32_SCREEN_SKILL_REPO_URL
)

$ErrorActionPreference = "Stop"
$skillName = "esp32-s3-2-8-screen-module"
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$installRoot = Join-Path $codexHome "esp32-s3-screen-skill"
$skillTarget = Join-Path (Join-Path $codexHome "skills") $skillName

if ($RepoUrl) {
  if (Test-Path (Join-Path $installRoot ".git")) {
    & git -C $installRoot pull --ff-only
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $installRoot -Parent) | Out-Null
    & git clone $RepoUrl $installRoot
  }
  $repoRoot = $installRoot
} else {
  if (-not $PSScriptRoot) {
    throw "Set ESP32_SCREEN_SKILL_REPO_URL when running this installer from the internet."
  }
  $repoRoot = $PSScriptRoot
}

$source = Join-Path (Join-Path $repoRoot "skills") $skillName
if (-not (Test-Path (Join-Path $source "SKILL.md"))) {
  throw "Skill source not found: $source"
}

New-Item -ItemType Directory -Force -Path (Join-Path $codexHome "skills") | Out-Null
if (Test-Path $skillTarget) {
  throw "Install target already exists: $skillTarget"
}

New-Item -ItemType Junction -Path $skillTarget -Target $source | Out-Null
Write-Host "Installed $skillName at $skillTarget"
Write-Host "Restart Codex to load the skill."

