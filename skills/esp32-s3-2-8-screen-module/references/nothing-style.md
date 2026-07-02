# Nothing-Style Visual Reference

An original, dependency-free design language for on-screen UIs on this board,
inspired by the *feel* of Nothing OS. It intentionally uses **no proprietary
assets** (the Ndot typeface is a Nothing trademark and most GitHub copies ship
with no license — do not bundle or redistribute it). Everything here is drawn
by the firmware itself.

If a user legitimately owns a dot-matrix font they are licensed to use, they
may swap it in; the default is the self-drawn bitmap font described below.

## Core Principles

1. **Pure black canvas.** Background is `0x0000`. No gradients, no panels.
2. **Monochrome + one accent.** Body/text in white and grays; a single
   **signature red** (`0xF800`) as the only chromatic accent, used sparingly
   (status dot, key value, one highlight per screen).
3. **Dot-matrix texture.** A faint grid of single dim pixels (`~0x1082`) at the
   center of each cell gives the quiet, technical "engineered" surface.
4. **Corner brackets, not boxes.** Frame content with four small L-shaped
   corner marks instead of full rectangles — a HUD/instrument motif.
5. **Generous negative space.** Left-aligned labels, big numerals, lots of
   emptiness. Never crowd.
6. **Restraint over decoration.** If an element is not information, remove it.

## Palette (RGB565)

| Role              | Value    | Notes                          |
|-------------------|----------|--------------------------------|
| Background        | `0x0000` | pure black                     |
| Dot-matrix grid   | `0x1082` | barely-there texture           |
| Primary / head    | `0xFFFF` | pure white                     |
| Secondary body    | `0xF79E` | near-white, slightly softer    |
| Dim / labels      | `0x630C` | gray, for secondary text/frame |
| Accent (the red)  | `0xF800` | Nothing signature red          |

Use the accent for **at most one thing per screen**. Overusing red kills it.

## Typography

- Default to a **self-drawn 5x7 bitmap font**, scaled up in integer steps
  (`sc = 2..7`). This reads as dot-matrix-adjacent without any font files.
- Big headline numerals (score, time, temperature) at `sc = 5..7`.
- Labels/hints at `sc = 2` in the dim gray.
- Keep everything on an implicit grid; align to cell centers where possible.

## Layout Recipe (480x640 portrait)

- **Uniform safe-area padding.** Reserve a consistent margin (≈20 px) from the
  physical screen edge on all four sides. Nothing — HUD, frame, content — may
  touch the bezel. Define one `PAD` constant and derive a usable area
  (`AREA_X/Y/W/H`) from it; anchor everything to that inset area, not to raw
  screen coordinates. This breathing room is core to the style; crowded edges
  read as cheap.
- **Top HUD band** (~56 px, inside the padding): small red status dot at left, a
  short uppercase label next to it, the primary value right-aligned. A 1 px dim
  divider under the band.
- **Content area** framed by four corner brackets (arm ~26 px, thickness 2 px,
  dim gray).
- **Full-screen states** (game over, alerts): big red dot, stacked headline,
  dim label above a large accent value, a dim one-line hint near the bottom.

## Drawing Primitives To Provide

Any UI following this style should implement, straight into an RGB565
framebuffer pushed via `esp_lcd_panel_draw_bitmap`:

- `fb_fill(color)` — fast 32-bit clear.
- `fb_rect(x,y,w,h,color)` — clipped rectangle.
- `fb_circle(cx,cy,r,color)` — filled circle (for dots and rounded corners).
- `fb_round_rect(x,y,s,rad,color)` — soft square for game/board tiles.
- `draw_dot_grid()` — the faint texture.
- `draw_corner_brackets()` — the four L marks.
- A bitmap-font text renderer (`draw_text`, `draw_text_centered`).

See the Snake reference implementation in `references/examples/` for concrete,
compile-tested code that realizes all of the above on this exact panel.

## Anti-Patterns

- Full bordered boxes, drop shadows, gradients, multiple bright colors.
- Red used for large fills or more than one element per screen.
- Centered body paragraphs (this style is left-aligned and sparse).
- Bundling the Ndot font or any unlicensed typeface.
