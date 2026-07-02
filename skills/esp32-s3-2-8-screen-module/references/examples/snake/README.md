# Snake — Reference On-Screen App

A compile-tested, real-hardware-verified example that demonstrates the
skill's recommended approach for interactive full-screen content on this board:

- **No LVGL** — draws into a PSRAM RGB565 framebuffer and pushes full frames via
  `esp_lcd_panel_draw_bitmap`.
- **Nothing-style visuals** — pure black, dot-matrix texture, monochrome snake
  with rounded white tiles, single red accent (food + status dots), corner-
  bracket HUD, self-drawn 5x7 bitmap font, and a uniform `PAD` safe-area margin
  so nothing touches the bezel. See `references/nothing-style.md`.
- **Correct touch handling** — swipe steering with the screen/touch axis swap
  applied, 10 ms fixed poll cadence, ~14 px swipe threshold. See
  `references/onscreen-apps.md`.
- **Wraparound walls, self-collision death** as the game rule.

## How it's wired

- Files live in `main/Snake_Game/` in the project.
- Registered in `main/CMakeLists.txt` under `SRCS` and `INCLUDE_DIRS`.
- Entered from `main/main.c` via a `SNAKE_GAME` branch that inits only
  `I2C_Init(); EXIO_Init(); LCD_Init(); Touch_Init();` then calls
  `Snake_Game_Run()`.

## Reuse

Treat this as a template. To build a different full-screen app (clock,
dashboard, meter), keep the framebuffer + primitives + touch scaffolding and
replace the game logic and `render_*` functions. Re-run the four-direction
touch calibration on the target device — mounting orientation can differ.
