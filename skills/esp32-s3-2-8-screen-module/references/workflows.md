# Workflows

## Decision Rules

- Need the fastest confidence check that the board is alive:
  - flash the bundled first-boot image firmware
- Need to validate environment setup:
  - do not build source; immediately flash the bundled first-boot image after setup
- Need a custom UI or device behavior:
  - use the ESP-IDF source project
- Need Arduino specifically:
  - treat `Arduino/` as a secondary path and prefer ESP-IDF unless the user explicitly asks otherwise

## Path Rules

- In Markdown and human-facing instructions, always show macOS and Linux paths with forward slashes, for example:
  - `./skills/esp32-s3-2-8-screen-module/scripts/bootstrap_mac.sh`
- Show Windows paths with backslashes, for example:
  - `.\skills\esp32-s3-2-8-screen-module\scripts\bootstrap_windows.ps1`
- When generating code, shell commands, PowerShell commands, or config snippets, match the target OS. Do not casually reuse POSIX separators in Windows PowerShell examples, and do not write Windows-style backslashes into macOS shell commands.
- If a command or code sample must be cross-platform, explicitly provide one version for macOS or Linux and one version for Windows.

## Environment Check

Run:

```bash
python3 skills/esp32-s3-2-8-screen-module/scripts/doctor.py --json
```

Or on Windows:

```powershell
python .\skills\esp32-s3-2-8-screen-module\scripts\doctor.py --json
```

What to look for:
- `repo_root` resolved
- `idf_installations` and `usable_idf_export` before treating ESP-IDF as missing
- `idf.py` on `PATH` means loaded now; a valid activation script means installed but not loaded
- `esptool.py` or `python -m esptool` available for first-boot image firmware flashing
- Python helper modules present: `yaml`, `serial`, `esptool`
- at least one likely serial port

If the skill is installed outside this repository, pass `--repo-root <path>` to `doctor.py`, and set `ESP32_S3_TOUCH_LCD_REPO` before using the shell or PowerShell wrappers.

Do not install ESP-IDF when `idf.py` is merely absent from `PATH` but `usable_idf_export` is present. Activate that installation instead.

## ESP-IDF Version Choice

Prefer ESP-IDF `v5.4.x` for this repository.

Reasoning:
- The vendor project declares `idf: ">=4.4"` and carries older-style driver usage.
- Espressif's current official installation flow defaults to ESP-IDF `v6.0+`, but this repository has not been verified against `v6.x` in the current workspace.
- If installation tooling asks for a version, choose `v5.4.2` or another `v5.4.x` release first. Move to `v6.x` only if you are prepared to fix compatibility regressions.

## macOS Bring-Up

Environment setup followed immediately by first light:

```bash
./skills/esp32-s3-2-8-screen-module/scripts/setup_and_light.sh /dev/cu.usbmodemXXXX
```

First-boot image firmware:

```bash
./skills/esp32-s3-2-8-screen-module/scripts/flash_merged_firmware.sh /dev/cu.usbmodemXXXX
```

Source build only:

```bash
./skills/esp32-s3-2-8-screen-module/scripts/build_idf.sh build
```

Build and flash:

```bash
./skills/esp32-s3-2-8-screen-module/scripts/build_idf.sh flash /dev/cu.usbmodemXXXX
```

Build, flash, monitor:

```bash
./skills/esp32-s3-2-8-screen-module/scripts/build_idf.sh full /dev/cu.usbmodemXXXX
```

## Windows Bring-Up

Environment setup followed immediately by first light:

```powershell
.\skills\esp32-s3-2-8-screen-module\scripts\setup_and_light.ps1 COM5
```

## First-Boot No-Build Rule

For environment setup, connection checks, and first light:

- use `Firmware/ESP32-S3-2.8-Image-Test.bin`
- flash it at offset `0x0`
- do not copy the editable project
- do not run `idf.py build`
- do not delete or repair a `build/` directory
- do not wait for another user message after setup succeeds

Source build begins only after the user requests a custom application or behavior.

First-boot image firmware:

```powershell
.\skills\esp32-s3-2-8-screen-module\scripts\flash_merged_firmware.ps1 COM5
```

Source build only:

```powershell
.\skills\esp32-s3-2-8-screen-module\scripts\build_idf.ps1 build
```

Build and flash:

```powershell
.\skills\esp32-s3-2-8-screen-module\scripts\build_idf.ps1 flash COM5
```

Build, flash, monitor:

```powershell
.\skills\esp32-s3-2-8-screen-module\scripts\build_idf.ps1 full COM5
```

## HID Device Warning

Apply this warning whenever the user asks for keyboard HID, mouse HID, keypad HID, macro pad behavior, joystick HID, or any firmware that makes the board emulate a HID device.

What to tell the user:
- Once the board is flashed as a HID device, normal reflashing becomes manual.
- Each reflash requires entering download mode by hand:
  - hold `Boot`
  - press `Reset`
  - release into flashing mode
- In this HID configuration, do not assume `esptool.py` can continue to flash the board directly with the usual automatic reset behavior.

Operational rule:
- Before giving flash steps for HID firmware, explicitly warn about the manual Boot/Reset sequence.
- After HID-related changes, do not describe the workflow as "one-click flash" or imply that the standard serial flashing loop still works unchanged.

## Typical Natural-Language Requests

> Rendering choice: full-screen / animated / game-like → direct framebuffer app
> (no LVGL); control-heavy → LVGL. Apply the house Nothing-style by default.
> See `references/onscreen-apps.md` and `references/nothing-style.md`.

"Make a game" (snake, etc.):
- New `main/<Game>/` app rendering to a PSRAM framebuffer; no LVGL
- Start from the template in `references/examples/snake/`
- Calibrate touch direction with the user; poll at a fixed 10 ms cadence

"Show a digital clock" / "status display":
- Direct framebuffer app if it's full-screen/animated; else extend `LVGL_Example.c`
- Use the existing `RTC_Loop()` data path
- For LVGL: add a timer or label refresh

"Make a custom dashboard":
- Rework the existing `Onboard_create()` layout in `LVGL_Example.c`
- Keep `main.c` boot flow unchanged

"Add a touch button":
- Add an LVGL button and `lv_obj_add_event_cb(...)` in `LVGL_Example.c`
- Only inspect `LVGL_Driver.c` if touch events do not arrive

"Dim or animate the backlight":
- Call `Set_Backlight()` from UI logic
- Edit `ST7701S.c` only if PWM behavior itself is wrong

## Troubleshooting

Blank screen:
- Flash the first-boot image firmware first to separate hardware issues from source edits
- The expected screen is the repository-root `image.png`, rotated and fitted to 480x640 by the direct panel path without LVGL initialization
- If the image firmware works but a custom build does not, compare only UI-level edits before touching the driver
- Inspect `EXAMPLE_LCD_BK_LIGHT_ON_LEVEL` and RGB timing only when there is evidence of panel-level failure

Touch not responding:
- Verify the screen itself renders first
- **In a direct-framebuffer app, first suspect the poll loop:** a sub-tick
  `vTaskDelay` (e.g. `pdMS_TO_TICKS(8)` -> 0 ticks) busy-spins and starves the
  touch task, killing touch *and* speeding the app up. Use a fixed 10 ms poll.
  See `references/onscreen-apps.md`.
- Then inspect `LVGL_Driver.c` and `GT911.c`

Touch works but swipe directions are wrong (rotated / mirrored):
- Expected: screen and touch axes are swapped on this board (`screen_x=touch_y`,
  `screen_y=touch_x`). Mounting orientation can further rotate/mirror.
- Ask the user for all four observed (swipe -> result) pairs, solve for the
  transform (axis swap / 90° rotation / single-axis flip), verify all four, then
  ship. Recipe in `references/onscreen-apps.md`. Do not guess a single flip when
  the report describes a rotation.

Build fails with memory or PSRAM-related errors:
- Preserve `sdkconfig.defaults` and `sdkconfig.defaults.esp32s3`
- Avoid changing flash size or PSRAM mode unless the hardware is known to differ from the vendor sample

Board no longer flashes after switching to HID behavior:
- Check whether the firmware now enumerates as a HID device instead of the usual serial interface
- Tell the user to hold `Boot`, then press `Reset`, to force download mode before reflashing
- Do not promise that `esptool.py` can still flash it directly without the manual button sequence

No serial port appears:
- Reconnect the cable
- Try another cable
- Re-run `doctor.py`
- Stop and report that hardware connection is blocking flash verification if no port is visible
