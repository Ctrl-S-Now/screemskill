# Project Map

## Board Summary

- MCU family: ESP32-S3
- Display controller: ST7701S
- Touch controller: GT911
- Resolution: 480x640
- IO expander: TCA9554 at `0x20`
- RTC: PCF85063 at `0x51`
- IMU: QMI8658 at `0x6A` or `0x6B` in the vendor code path
- SD card, battery sensing, buzzer, Wi-Fi scan UI are already wired into the sample

Treat these values as fixed board facts. Do not ask the user to provide them.

## Non-Technical User Guardrails

- The user should not need to reason about file path separators. When documenting or generating commands, keep macOS and Linux examples in POSIX form and Windows examples in PowerShell form.
- HID-related firmware is a special case. If the board is turned into a keyboard HID or any other HID-like USB device, reflashing usually stops being automatic and requires a manual Boot/Reset sequence to enter download mode.

## Fixed Hardware Map

Source of truth:
- `ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/LCD_Driver/ST7701S.h`
- `ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/Touch_Driver/GT911.h`
- `ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/EXIO/TCA9554PWR.h`

Important values already encoded in the project:
- Backlight GPIO: `6`
- RGB sync GPIOs: `HSYNC=38`, `VSYNC=39`, `DE=40`, `PCLK=41`
- RGB data GPIOs: `5, 45, 48, 47, 21, 14, 13, 12, 11, 10, 9, 46, 3, 8, 18, 17`
- I2C master GPIOs: `SDA=15`, `SCL=7`
- Touch interrupt GPIO: `16`
- Touch reset GPIO: `-1`
- Panel pixel clock: `30 MHz`
- Flash expectation: `16 MB`
- PSRAM expectation: octal PSRAM enabled

## Preferred Project Path

Use `ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test` as the canonical editable project.

Key files:
- `main/main.c`: selects the direct first-boot image path or the product UI path
- `main/LVGL_UI/LVGL_Example.c`: primary UI and most feature work
- `main/LVGL_UI/LVGL_Example.h`: declarations for UI-level helpers
- `main/LVGL_Driver/LVGL_Driver.c`: LVGL display flush and touch input bridge
- `main/LCD_Driver/ST7701S.c`: panel init and backlight PWM
- `main/Touch_Driver/GT911.c`: touch driver behavior
- `main/EXIO/TCA9554PWR.c`: IO expander helpers
- `sdkconfig.defaults` and `sdkconfig.defaults.esp32s3`: flash/PSRAM defaults
- `image.png`: source image for the first-boot screen
- `Firmware/ESP32-S3-2.8-Image-Test.bin`: prebuilt first-boot image firmware, flash at `0x0`

## First-Boot Runtime Sequence

The first-boot image test deliberately does not initialize LVGL:

1. `I2C_Init()`
2. `EXIO_Init()`
3. `LCD_Init()`
4. `Proof_Image_Show()` writes the converted `image.png` directly through the RGB panel driver

The expected result is a full-screen 480x640 image with correct direction and colors.

## Product UI Runtime Sequence

The sample startup order in `main/main.c` is:

1. `Wireless_Init()`
2. `Driver_Init()` for flash, battery, I2C, RTC, IMU, EXIO
3. `LCD_Init()`
4. `Touch_Init()`
5. `SD_Init()`
6. `LVGL_Init()`
7. `Lvgl_Example1()`

For most product ideas, keep this sequence intact.

## Safe Edit Zones

Edit here first:
- New pages, text, indicators, animations, timers, touch callbacks: `LVGL_Example.c`
- Demo selection or replacing the default screen: `main.c`
- LVGL refresh cadence or touch handoff details: `LVGL_Driver.c`

Edit only when symptoms point there:
- Blank screen, panel reset, color/order, backlight PWM: `ST7701S.*`
- Touch coordinates or touch not responding: `GT911.*`
- IO expander-driven reset or chip select behavior: `TCA9554PWR.*`
- PSRAM or flash capacity mismatches: `sdkconfig.defaults*`

## Expected First-Boot Behavior

If the board boots successfully, the screen should show the repository-root `image.png`. Do not use the vendor LVGL widget panel as the first hardware-validation screen.
