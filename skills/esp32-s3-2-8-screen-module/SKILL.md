---
name: esp32-s3-2-8-screen-module
description: Bring up, customize, build, flash, and troubleshoot the ESP32-S3 2.8-inch screen module repository that ships vendor ESP-IDF and Arduino samples for the 480x640 ST7701S + GT911 board. Use when the user refers to this board in exact or fuzzy ways such as ESP32-S3 2.8-inch screen module, ESP32-S3 2.8寸屏幕模组, ESP32-S3 带屏模组, 2.8寸 ESP32-S3 小屏, ESP32-S3 屏幕板, ESP32-S3 彩屏板, ESP32-S3 小屏开发板, 我买的 ESP32-S3 屏幕模组, 那块 2.8 寸小屏, 那块带触摸的小屏板, 这块 ESP32-S3 小屏, 这块带屏开发板, or similar descriptions, and Codex needs to set up the local environment, make the board work on macOS or Windows, flash firmware, configure keyboard HID or other HID-like USB behavior, or change what appears on the screen from natural-language requests without requiring hardware knowledge from the user.
---

# Esp32 S3 2.8 Inch Screen Module

Use this skill as a non-technical operator for this exact board and repository. The user should be able to describe goals in plain language such as "帮我把这块小屏点亮", "把它变成一个时钟", "帮我配好环境", or "把它做成 HID 键盘", and Codex should translate that into the right environment setup, flashing flow, and code changes without pushing hardware details back onto the user.

## Interaction Mode

- Treat loose user language as enough to trigger this skill. Do not require the user to know the exact skill name, board model wording, pin map, framework, or flashing tool.
- Lead with the user's goal, not with commands. Internally you may use `doctor.py`, bootstrap scripts, ESP-IDF, or the prebuilt first-boot image firmware, but the user-facing conversation should sound like guided product setup, not like a tool manual.
- Hide implementation detail by default. Only mention scripts, paths, frameworks, or flashing tools when they are needed to explain a blocker, ask for consent, or report progress.
- Prefer plain language such as "我先帮你检查本机环境和开发板连接状态" over tool-centric language such as "先运行 doctor.py".
- Ask as few questions as possible. Only ask when the answer changes the path in a meaningful way and cannot be discovered locally.

Read `references/interaction.md` before handling user-facing replies or deciding how much technical detail to expose.

## First Response Rules

When the user starts a task, map the request into one of these intents:

1. Environment setup
2. First boot or proof-of-life
3. Custom screen content or UI behavior
4. HID keyboard or other HID-like USB behavior
5. Troubleshooting

Then respond in this order:

1. Restate the user goal in plain language
2. Say what you will do first in plain language
3. Perform the underlying checks or actions
4. Surface only the minimum technical detail needed for the user to follow along

Good first-response examples:
- "我先帮你检查这台电脑缺哪些环境，再判断这块 2.8 寸屏幕模组能不能直接点亮。"
- "我先确认这块板子现在能不能正常进入烧录流程，然后再帮你把它改成你要的界面。"

Bad first-response patterns:
- dumping command lists before doing any work
- asking the user自己去找引脚、驱动型号、串口、框架版本
- telling the user先学会 `idf.py`、`esptool.py`、`brew`、`winget`

## Workflow Selection

### If The User Wants "Set Everything Up"

- Start with the local environment and board-connection check.
- Distinguish "not loaded in this terminal" from "not installed on disk." If a compatible ESP-IDF already exists, activate and reuse it; do not install another copy.
- If tools are genuinely missing, use the OS-specific bootstrap flow.
- Treat setup and first light as one uninterrupted task. As soon as setup succeeds and a board is connected, flash the prebuilt first-boot image immediately.
- Do not stop after reporting that the environment is ready. Setup is complete only after the prebuilt image has been flashed and the user has been asked to confirm the visible result, or after reporting a concrete hardware blocker such as no serial port.

### If The User Wants "Light It Up"

- Prefer the lowest-friction proof-of-life path first.
- Use the bundled image-test firmware when the goal is only to verify that the board, cable, screen, and flashing loop are healthy.
- Flash the prebuilt binary directly. Do not copy the editable project, run `idf.py build`, clean a build directory, or compile source for first-boot validation.
- The first-boot success screen must be the repository-root `image.png`, rendered full-screen by the panel driver without initializing LVGL. Do not use the vendor LVGL demo as the expected first-boot screen.
- If the image appears with the expected direction and colors, tell the user the basic display path is usable and offer to continue with a custom interface.

### If The User Wants "Make It Show X"

- Treat the request as a UI or feature brief, not as a coding request.
- Edit the safest existing LVGL entry points first.
- Preserve the driver stack unless the symptom is clearly hardware-level.

### If The User Wants HID Behavior

- Switch into HID caution mode before giving flash guidance.
- Explain in plain language that once the board behaves like a keyboard or other HID device, reflashing becomes more manual.
- Tell the user that each reflash requires holding `Boot`, then pressing `Reset`, to enter download mode.
- Do not imply that the standard automatic `esptool.py` flash loop still works unchanged.

## Operating Rules

- Never use source compilation as an environment or first-boot validation step. Building is reserved for a user-requested custom application that cannot be satisfied by the prebuilt first-boot firmware.
- Never copy the ESP-IDF project into the current workspace merely to verify setup or light the screen.
- Never reinstall ESP-IDF only because `idf.py` is absent from the current `PATH`. Inspect known installations and activation scripts first.
- Never ask the user to look up pins, LCD controller model, touch controller model, RGB timing, LVGL entry points, or framework-specific bootstrapping steps. This repository already contains those details.
- Never ask the user to manually compose environment-install commands when the bundled bootstrap scripts can do the work.
- Never mix path conventions casually. In Markdown and user instructions, show POSIX-style paths such as `skills/.../script.sh` for macOS and Linux, and Windows-style paths such as `.\skills\...\script.ps1` for Windows. Match the current operating system when generating commands or code.
- Never describe the skill as if the user must personally operate each tool. The default stance is that Codex does the technical work and only asks for hardware actions or approvals when needed.
- Keep vendor driver edits minimal when the task is only about what appears on screen.
- Prefer extending the existing LVGL app rather than replacing the driver stack.

## Internal Execution Resources

Use these resources as implementation details, not as the default user-facing structure:

- `references/interaction.md`: user-facing tone, question policy, and natural-language examples
- `references/workflows.md`: OS-specific setup, flashing paths, HID cautions, and troubleshooting flow
- `references/project-map.md`: board facts, edit boundaries, and runtime structure
- `scripts/doctor.py`: environment and connection inspection
- `scripts/bootstrap_mac.sh` and `scripts/bootstrap_windows.ps1`: host environment setup
- `scripts/setup_and_light.sh` and `scripts/setup_and_light.ps1`: uninterrupted setup followed by immediate first-boot flashing
- `scripts/build_idf.sh` and `scripts/build_idf.ps1`: source build, flash, and monitor
- `scripts/flash_merged_firmware.sh` and `scripts/flash_merged_firmware.ps1`: prebuilt first-boot image firmware flashing
