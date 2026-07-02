# On-Screen Apps: Rendering, Touch, and Timing

Guidance for building custom interactive screen content (games, dashboards,
status displays) on this board. These are field-tested lessons — follow them to
avoid re-discovering the same bugs.

## Render Directly, Skip LVGL For Full-Frame UIs

For anything that repaints the whole screen every frame (games, animated
gauges), **do not use LVGL**. Its object tree and scheduler are overhead you do
not need. Instead:

1. Allocate one RGB565 framebuffer in PSRAM:
   `heap_caps_malloc(SCR_W * SCR_H * 2, MALLOC_CAP_SPIRAM)`
   (480x640x2 = 600 KB — must be PSRAM, not internal RAM).
2. Draw into it with your own primitives.
3. Push the whole frame with
   `esp_lcd_panel_draw_bitmap(panel_handle, 0, 0, SCR_W, SCR_H, fb)`.

Keep LVGL only for control-heavy UIs (buttons, lists, forms).

Bring up just what you need before the loop:
`I2C_Init(); EXIO_Init(); LCD_Init(); Touch_Init();` — no `LVGL_Init()`.

## Screen vs Touch Axes Are Swapped — Calibrate Explicitly

The panel is **480 wide x 640 tall**, but the GT911 touch config uses
`x_max = V_RES (640)`, `y_max = H_RES (480)` — i.e. **touch axes are swapped
relative to the display**. When reading raw touch, map:

```
screen_x = touch_y;   // touch native Y -> screen X
screen_y = touch_x;   // touch native X -> screen Y
```

### Direction calibration is a required step, not an afterthought

Depending on how the panel is physically mounted, swipe directions can come out
rotated or mirrored. **After first flashing an interactive app, ask the user to
test all four directions** and correct with a single transform. The mapping is
one of a small set:

- **Axis swap** (`sdx = dy, sdy = dx`) — fixes the common "horizontal swipe
  moves vertically" case. *(This is the one we hit on this board.)*
- **90° rotation** (`sdx = dy, sdy = -dx` or `sdx = -dy, sdy = dx`).
- **Single-axis flip** (negate one of `dx`/`dy`) — fixes "up and down are
  reversed but left/right are fine".

To diagnose: collect the user's four observed (swipe → result) pairs and solve
for the transform, then verify all four before shipping. Do not guess a single
axis flip when the report describes a rotation.

## Touch Polling Cadence — The vTaskDelay(0) Trap

**Never poll touch on a sub-tick delay.** FreeRTOS default tick is 10 ms, so
`pdMS_TO_TICKS(8)` rounds to **0 ticks**; `vTaskDelay(0)` does not yield the
CPU. A poll loop with `vTaskDelay(0)`:

- busy-spins, burning the whole per-step interval instantly (game runs far too
  fast), and
- starves the touch driver / watchdog tasks, so **touch appears completely
  dead**.

Both symptoms at once ("touch stopped responding *and* it got faster") are the
signature of this bug.

**Rule:** poll on a **fixed 10 ms cadence** (one real tick) decoupled from game
speed:

```c
const int poll_ms = 10;               // == 1 tick; actually yields
int elapsed = 0;
while (elapsed < step_ms) {
    poll_touch();
    vTaskDelay(pdMS_TO_TICKS(poll_ms));
    elapsed += poll_ms;
}
game_step();
```

## Swipe Threshold

A swipe threshold of ~14 px feels responsive without misfiring. 30 px feels
sluggish. If the user says "not sensitive enough," lower toward 10 px; if
"too twitchy / double-turns," raise toward 18–20 px and consider limiting to
one direction change per game step.

## Speed Tuning

Express game speed as a per-step delay that shrinks with score, with a floor:

```c
int step_ms = base_ms - score * accel;
if (step_ms < min_ms) step_ms = min_ms;
```

Sensible starting points on this board: `base_ms ≈ 260`, `min_ms ≈ 140`,
`accel ≈ 4`. Slower `base_ms` if the user wants a calmer start.

## Build Gotchas On This Repo

- The toolchain is strict: `-Werror` includes `misleading-indentation`. Do not
  put two statements guarded-looking on one line
  (`if (a) x; if (b) y;`) — split them.
- Local clang/clangd will flag `-mlongcalls`, `../hal.h not found`, etc. These
  are **false positives** from the wrong toolchain; trust the `idf.py build`
  result, not the editor squiggles.
- Register new source files in `main/CMakeLists.txt` (both `SRCS` and, for a new
  folder, `INCLUDE_DIRS`).
