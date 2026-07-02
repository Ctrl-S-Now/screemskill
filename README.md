# ESP32-S3 2.8-inch Screen Module Skill

This repository lets a non-technical user control an ESP32-S3 2.8-inch screen module through natural-language requests in Codex.

Users can say things such as:

- "帮我把这块 2.8 寸小屏点亮"
- "把这张照片显示上去"
- "做一个可以触摸的时钟"
- "把它做成三个快捷键"

The Skill handles environment checks, source changes, builds, flashing, and startup-log verification. It supports macOS and Windows and does not require the user to understand pins, display timing, ESP-IDF commands, or serial-port tooling.

## Install On macOS

```bash
curl -fsSL https://raw.githubusercontent.com/Ctrl-S-Now/screemskill/main/install.sh | bash -s -- https://github.com/Ctrl-S-Now/screemskill.git
```

## Install On Windows

Run this in PowerShell:

```powershell
$env:ESP32_SCREEN_SKILL_REPO_URL="https://github.com/Ctrl-S-Now/screemskill.git"; irm https://raw.githubusercontent.com/Ctrl-S-Now/screemskill/main/install.ps1 | iex
```

Restart Codex after installation. The user can then start a new session and describe what they want the board to do without naming the Skill exactly.

## First Hardware Check

The first hardware check flashes the bundled `Firmware/ESP32-S3-2.8-Image-Test.bin`. A successful board displays `image.png` full-screen using the RGB panel driver without initializing LVGL.

LVGL is used later when a requested product needs interactive pages, controls, animation, or touch behavior.

## HID Reflashing

If the board is configured as a keyboard, mouse, macro pad, or another HID-like USB device, automatic reflashing is no longer assumed. For each reflash:

1. Hold `Boot`.
2. Press `Reset`.
3. Release the buttons to enter download mode.

The normal automatic `esptool.py` reset flow should not be presented as unchanged in HID mode.

## Repository Layout

- `skills/esp32-s3-2-8-screen-module/`: Codex Skill
- `ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/`: editable ESP-IDF project
- `Firmware/ESP32-S3-2.8-Image-Test.bin`: prebuilt first-boot firmware
- `image.png`: first-boot validation image
- `install.sh`: macOS installer
- `install.ps1`: Windows installer

Vendor source files remain subject to their original notices and licenses.
