#include "Snake_Game.h"

#include <string.h>
#include <stdlib.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_random.h"
#include "esp_log.h"
#include "esp_heap_caps.h"

#include "ST7701S.h"                 // panel_handle, EXAMPLE_LCD_H_RES/V_RES, Set_Backlight
#include "esp_lcd_touch.h"           // esp_lcd_touch_read_data / get_coordinates
#include "GT911.h"                   // tp (touch handle)

static const char *TAG = "SNAKE";

// ---- Screen geometry ---------------------------------------------------
// Panel is 480 wide (H_RES) x 640 tall (V_RES), RGB565.
#define SCR_W   EXAMPLE_LCD_H_RES    // 480
#define SCR_H   EXAMPLE_LCD_V_RES    // 640

// ---- Safe-area padding -------------------------------------------------
// Uniform margin from the physical screen edge. All content (HUD, frame,
// playfield) lives inside this inset — nothing touches the bezel.
#define PAD       20
#define AREA_X    PAD                        // left edge of usable area
#define AREA_Y    PAD                        // top edge of usable area
#define AREA_W    (SCR_W - 2 * PAD)          // usable width
#define AREA_H    (SCR_H - 2 * PAD)          // usable height

// ---- HUD band (top strip reserved for score / title) -------------------
#define HUD_H     56                         // height of the HUD, inside the pad
#define BOARD_TOP (AREA_Y + HUD_H)           // playfield starts below the HUD

// ---- Playfield grid ----------------------------------------------------
#define CELL      22                 // pixel size of one grid cell
#define GRID_W    (AREA_W / CELL)                       // columns inside the pad
#define GRID_H    ((AREA_H - HUD_H) / CELL)             // rows below the HUD
#define BOARD_PX_W (GRID_W * CELL)
#define BOARD_PX_H (GRID_H * CELL)
// Center the grid within the padded content region.
#define OFF_X     (AREA_X + (AREA_W - BOARD_PX_W) / 2)
#define OFF_Y     (BOARD_TOP + (AREA_H - HUD_H - BOARD_PX_H) / 2)

#define MAX_LEN   (GRID_W * GRID_H)

// ---- Colors (RGB565) — Nothing-inspired monochrome + red accent --------
#define C_BG       0x0000            // pure black
#define C_DOT      0x1082            // faint dot-matrix background grid
#define C_SNAKE    0xF79E            // near-white body
#define C_HEAD     0xFFFF            // pure white head
#define C_FOOD     0xF800            // Nothing signature red
#define C_TEXT     0xFFFF            // white
#define C_DIM      0x630C            // dim gray (secondary text)
#define C_ACCENT   0xF800            // red accent

// ---- Framebuffer -------------------------------------------------------
// SCR_W * SCR_H * 2 bytes = 480*640*2 = 600 KB. Lives in PSRAM.
static uint16_t *fb = NULL;

// ---- Game state --------------------------------------------------------
typedef struct { int8_t x, y; } Pt;

static Pt   snake[MAX_LEN];
static int  snake_len;
static int  dir_x, dir_y;           // current direction
static int  next_dx, next_dy;       // queued direction from touch
static Pt   food;
static int  score;
static bool alive;

// ---- Touch swipe tracking ---------------------------------------------
static bool  touching = false;
static int   start_x, start_y;      // in screen pixel coords
static int   last_x, last_y;
#define SWIPE_MIN 14                 // px before a swipe registers

// ------------------------------------------------------------------------
// Framebuffer primitives
// ------------------------------------------------------------------------
static void fb_fill(uint16_t c)
{
    // Fast fill using 32-bit writes.
    uint32_t v = ((uint32_t)c << 16) | c;
    uint32_t *p = (uint32_t *)fb;
    int n = (SCR_W * SCR_H) / 2;
    for (int i = 0; i < n; i++) p[i] = v;
}

static void fb_rect(int x, int y, int w, int h, uint16_t c)
{
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > SCR_W) w = SCR_W - x;
    if (y + h > SCR_H) h = SCR_H - y;
    if (w <= 0 || h <= 0) return;
    for (int row = 0; row < h; row++) {
        uint16_t *line = &fb[(y + row) * SCR_W + x];
        for (int col = 0; col < w; col++) line[col] = c;
    }
}

// Filled circle centered at (cx,cy) with radius r.
static void fb_circle(int cx, int cy, int r, uint16_t c)
{
    int r2 = r * r;
    for (int dy = -r; dy <= r; dy++) {
        int yy = cy + dy;
        if (yy < 0 || yy >= SCR_H) continue;
        int span2 = r2 - dy * dy;
        if (span2 < 0) continue;
        // integer sqrt
        int dx = 0; while ((dx + 1) * (dx + 1) <= span2) dx++;
        int x0 = cx - dx, w = 2 * dx + 1;
        if (x0 < 0) { w += x0; x0 = 0; }
        if (x0 + w > SCR_W) w = SCR_W - x0;
        if (w <= 0) continue;
        uint16_t *line = &fb[yy * SCR_W + x0];
        for (int i = 0; i < w; i++) line[i] = c;
    }
}

// Rounded square block for the snake body (soft Nothing-style pill look).
static void fb_round_rect(int x, int y, int s, int rad, uint16_t c)
{
    // Center cross bars.
    fb_rect(x + rad, y, s - 2 * rad, s, c);
    fb_rect(x, y + rad, rad, s - 2 * rad, c);
    fb_rect(x + s - rad, y + rad, rad, s - 2 * rad, c);
    // Rounded corners via quarter circles.
    fb_circle(x + rad, y + rad, rad, c);
    fb_circle(x + s - rad - 1, y + rad, rad, c);
    fb_circle(x + rad, y + s - rad - 1, rad, c);
    fb_circle(x + s - rad - 1, y + s - rad - 1, rad, c);
}

// Snake body cell: rounded white block with a small inset.
static void draw_body_cell(int gx, int gy, uint16_t c)
{
    int px = OFF_X + gx * CELL + 2;
    int py = OFF_Y + gy * CELL + 2;
    int s = CELL - 4;
    fb_round_rect(px, py, s, 5, c);
}

// Food: a clean red dot (Nothing accent).
static void draw_food_dot(int gx, int gy)
{
    int cx = OFF_X + gx * CELL + CELL / 2;
    int cy = OFF_Y + gy * CELL + CELL / 2;
    fb_circle(cx, cy, CELL / 2 - 3, C_FOOD);
}

static void fb_push(void)
{
    esp_lcd_panel_draw_bitmap(panel_handle, 0, 0, SCR_W, SCR_H, fb);
}

// ------------------------------------------------------------------------
// Minimal 5x7 bitmap font for the few glyphs we need (digits + words).
// Rendered scaled up. Each glyph is 5 columns x 7 rows, LSB = top row.
// ------------------------------------------------------------------------
static const uint8_t font5x7[][5] = {
    {0x00,0x00,0x00,0x00,0x00}, // ' ' (space) idx 0
    {0x7F,0x08,0x08,0x08,0x7F}, // 'H' 1
    {0x00,0x41,0x7F,0x41,0x00}, // 'I' 2
    // digits 0-9 start at idx 3
    {0x3E,0x51,0x49,0x45,0x3E}, // 0
    {0x00,0x42,0x7F,0x40,0x00}, // 1
    {0x42,0x61,0x51,0x49,0x46}, // 2
    {0x21,0x41,0x45,0x4B,0x31}, // 3
    {0x18,0x14,0x12,0x7F,0x10}, // 4
    {0x27,0x45,0x45,0x45,0x39}, // 5
    {0x3C,0x4A,0x49,0x49,0x30}, // 6
    {0x01,0x71,0x09,0x05,0x03}, // 7
    {0x36,0x49,0x49,0x49,0x36}, // 8
    {0x06,0x49,0x49,0x29,0x1E}, // 9
    // letters we use for words
    {0x7F,0x49,0x49,0x49,0x41}, // 'E' 13
    {0x7F,0x02,0x0C,0x02,0x7F}, // 'M' 14
    {0x3E,0x41,0x41,0x41,0x22}, // 'C' 15
    {0x7F,0x40,0x40,0x40,0x40}, // 'L' 16
    {0x46,0x49,0x49,0x49,0x31}, // 'S' 17
    {0x7F,0x09,0x19,0x29,0x46}, // 'R' 18
    {0x3E,0x41,0x41,0x41,0x3E}, // 'O' 19
    {0x7F,0x09,0x09,0x09,0x01}, // 'F' 20
    {0x3E,0x41,0x51,0x21,0x5E}, // 'Q' -> reused? keep for 'G'
    {0x3E,0x41,0x49,0x49,0x7A}, // 'G' 22
    {0x7C,0x12,0x11,0x12,0x7C}, // 'A' 23
    {0x7F,0x08,0x14,0x22,0x41}, // 'K' 24
    {0x7F,0x40,0x40,0x40,0x40}, // duplicate 'L' safeguard
    {0x01,0x01,0x7F,0x01,0x01}, // 'T' 26
    {0x3F,0x40,0x38,0x40,0x3F}, // 'W' 27
    {0x7F,0x41,0x41,0x22,0x1C}, // 'D' 28
    {0x7F,0x04,0x08,0x10,0x7F}, // 'N' 29
    {0x3F,0x40,0x40,0x40,0x3F}, // 'U' 30
    {0x03,0x04,0x78,0x04,0x03}, // 'Y' 31
    {0x63,0x14,0x08,0x14,0x63}, // 'X' 32
    {0x30,0x40,0x40,0x40,0x3F}, // 'J'? unused
    {0x7F,0x09,0x09,0x09,0x06}, // 'P' 34
    {0x1C,0x22,0x41,0x22,0x1C}, // 'O' round -> reuse
};

// Map a char to a glyph index in font5x7. Returns 0 (space) if unknown.
static int glyph_index(char ch)
{
    switch (ch) {
        case ' ': return 0;
        case 'H': return 1;
        case 'I': return 2;
        case '0': return 3; case '1': return 4; case '2': return 5;
        case '3': return 6; case '4': return 7; case '5': return 8;
        case '6': return 9; case '7': return 10; case '8': return 11;
        case '9': return 12;
        case 'E': return 13; case 'M': return 14; case 'C': return 15;
        case 'L': return 16; case 'S': return 17; case 'R': return 18;
        case 'O': return 19; case 'F': return 20; case 'G': return 22;
        case 'A': return 23; case 'K': return 24; case 'T': return 26;
        case 'W': return 27; case 'D': return 28; case 'N': return 29;
        case 'U': return 30; case 'Y': return 31; case 'X': return 32;
        case 'P': return 34;
        default:  return 0;
    }
}

// Draw a single char at pixel (x,y), each font pixel scaled to sc x sc.
static void draw_char(int x, int y, char ch, int sc, uint16_t c)
{
    int gi = glyph_index(ch);
    const uint8_t *g = font5x7[gi];
    for (int col = 0; col < 5; col++) {
        uint8_t bits = g[col];
        for (int row = 0; row < 7; row++) {
            if (bits & (1 << row)) {
                fb_rect(x + col * sc, y + row * sc, sc, sc, c);
            }
        }
    }
}

// Draw a string; returns total pixel width used.
static int draw_text(int x, int y, const char *s, int sc, uint16_t c)
{
    int cx = x;
    for (const char *p = s; *p; p++) {
        draw_char(cx, y, *p, sc, c);
        cx += (5 + 1) * sc;         // 1 column spacing
    }
    return cx - x;
}

static int text_width(const char *s, int sc)
{
    return (int)strlen(s) * (5 + 1) * sc;
}

static void draw_text_centered(int y, const char *s, int sc, uint16_t c)
{
    int w = text_width(s, sc);
    draw_text((SCR_W - w) / 2, y, s, sc, c);
}

// ------------------------------------------------------------------------
// Game logic
// ------------------------------------------------------------------------
static void place_food(void)
{
    // Pick a free cell.
    for (;;) {
        int fx = esp_random() % GRID_W;
        int fy = esp_random() % GRID_H;
        bool on_snake = false;
        for (int i = 0; i < snake_len; i++) {
            if (snake[i].x == fx && snake[i].y == fy) { on_snake = true; break; }
        }
        if (!on_snake) { food.x = fx; food.y = fy; return; }
    }
}

static void game_reset(void)
{
    snake_len = 3;
    int cx = GRID_W / 2, cy = GRID_H / 2;
    snake[0] = (Pt){cx,     cy};
    snake[1] = (Pt){cx - 1, cy};
    snake[2] = (Pt){cx - 2, cy};
    dir_x = 1; dir_y = 0;
    next_dx = 1; next_dy = 0;
    score = 0;
    alive = true;
    place_food();
}

// Advance one step. Returns false if the snake died this step.
static bool game_step(void)
{
    // Apply queued turn (ignore reversals).
    if (!(next_dx == -dir_x && next_dy == -dir_y)) {
        dir_x = next_dx; dir_y = next_dy;
    }

    Pt head = snake[0];
    head.x += dir_x;
    head.y += dir_y;

    // Walls wrap around: exit one side, re-enter the opposite side.
    if (head.x < 0)         head.x = GRID_W - 1;
    else if (head.x >= GRID_W) head.x = 0;
    if (head.y < 0)         head.y = GRID_H - 1;
    else if (head.y >= GRID_H) head.y = 0;

    // Self collision (skip the tail cell, which will move away — unless growing).
    for (int i = 0; i < snake_len - 1; i++) {
        if (snake[i].x == head.x && snake[i].y == head.y) return false;
    }

    bool grew = (head.x == food.x && head.y == food.y);
    int new_len = grew ? snake_len + 1 : snake_len;
    if (new_len > MAX_LEN) new_len = MAX_LEN;

    // Shift body.
    for (int i = new_len - 1; i > 0; i--) snake[i] = snake[i - 1];
    snake[0] = head;
    snake_len = new_len;

    if (grew) {
        score++;
        place_food();
    }
    return true;
}

// Faint dot-matrix backdrop: one dim dot at the center of every grid cell.
// This is the signature Nothing texture — quiet, precise, technical.
static void draw_dot_grid(void)
{
    for (int gy = 0; gy < GRID_H; gy++) {
        for (int gx = 0; gx < GRID_W; gx++) {
            int cx = OFF_X + gx * CELL + CELL / 2;
            int cy = OFF_Y + gy * CELL + CELL / 2;
            fb[cy * SCR_W + cx] = C_DOT;
        }
    }
}

// A thin corner-bracket frame (only the four L-shaped corners, not a full box)
// — a common Nothing/technical-HUD motif.
static void draw_corner_brackets(void)
{
    const int L = 26, T = 2;                 // arm length, thickness
    const int gap = 6;                       // breathing room around the board
    int x0 = OFF_X - gap,               y0 = OFF_Y - gap;
    int x1 = OFF_X + BOARD_PX_W - 1 + gap, y1 = OFF_Y + BOARD_PX_H - 1 + gap;
    // top-left
    fb_rect(x0, y0, L, T, C_DIM);          fb_rect(x0, y0, T, L, C_DIM);
    // top-right
    fb_rect(x1 - L, y0, L, T, C_DIM);      fb_rect(x1 - T, y0, T, L, C_DIM);
    // bottom-left
    fb_rect(x0, y1 - T, L, T, C_DIM);      fb_rect(x0, y1 - L, T, L, C_DIM);
    // bottom-right
    fb_rect(x1 - L, y1 - T, L, T, C_DIM);  fb_rect(x1 - T, y1 - L, T, L, C_DIM);
}

static void render_play(void)
{
    fb_fill(C_BG);
    draw_dot_grid();

    // --- Top HUD: minimal, left-aligned label + score, red status dot -----
    // Everything anchored inside the padded safe area.
    int hud_mid = AREA_Y + 14;               // vertical center-ish of the label
    fb_circle(AREA_X + 6, hud_mid + 1, 5, C_ACCENT);   // signature red dot
    draw_text(AREA_X + 20, hud_mid - 6, "SNAKE", 2, C_TEXT);
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", score);
    int w = text_width(buf, 3);
    draw_text(AREA_X + AREA_W - w, AREA_Y + 8, buf, 3, C_TEXT);
    // thin divider under the HUD, spanning the padded width
    fb_rect(AREA_X, BOARD_TOP - 12, AREA_W, 1, C_DIM);

    draw_corner_brackets();

    // Food — red accent dot.
    draw_food_dot(food.x, food.y);

    // Snake — rounded white blocks; head pure white, body slightly softer.
    for (int i = snake_len - 1; i >= 0; i--) {
        draw_body_cell(snake[i].x, snake[i].y, i == 0 ? C_HEAD : C_SNAKE);
    }

    fb_push();
}

static void render_gameover(void)
{
    fb_fill(C_BG);
    draw_dot_grid();

    int midy = SCR_H / 2;

    // Big red status dot, then stacked dot-matrix headline.
    fb_circle(SCR_W / 2, midy - 170, 8, C_ACCENT);

    draw_text_centered(midy - 130, "GAME", 7, C_TEXT);
    draw_text_centered(midy - 50,  "OVER", 7, C_TEXT);

    // Score block: dim label above, big number below.
    draw_text_centered(midy + 60, "SCORE", 2, C_DIM);
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", score);
    draw_text_centered(midy + 90, buf, 5, C_ACCENT);

    // Prompt.
    draw_text_centered(midy + 200, "TAP TO RESTART", 2, C_DIM);

    fb_push();
}

// ------------------------------------------------------------------------
// Touch: convert native touch coords to screen pixels and detect swipes.
// ------------------------------------------------------------------------
// Touch config uses x_max=V_RES(640), y_max=H_RES(480): the touch native
// axes are swapped relative to the display. Map: screen_x = touch_y,
// screen_y = touch_x.
static bool read_touch(int *sx, int *sy)
{
    uint16_t tx[1] = {0}, ty[1] = {0};
    uint8_t cnt = 0;
    esp_lcd_touch_read_data(tp);
    bool pressed = esp_lcd_touch_get_coordinates(tp, tx, ty, NULL, &cnt, 1);
    if (pressed && cnt > 0) {
        *sx = ty[0];    // touch-y -> screen-x
        *sy = tx[0];    // touch-x -> screen-y
        if (*sx < 0) *sx = 0;
        if (*sx >= SCR_W) *sx = SCR_W - 1;
        if (*sy < 0) *sy = 0;
        if (*sy >= SCR_H) *sy = SCR_H - 1;
        return true;
    }
    return false;
}

// Poll touch and update next direction (during play) or return "tap released"
// (used to restart after game over). Called frequently between steps.
// Returns true if a tap was completed this call (press then release short move).
static bool poll_touch_play(void)
{
    int x, y;
    bool now = read_touch(&x, &y);

    if (now && !touching) {
        touching = true;
        start_x = last_x = x;
        start_y = last_y = y;
    } else if (now && touching) {
        int dx = x - start_x;
        int dy = y - start_y;
        int adx = abs(dx), ady = abs(dy);
        if (adx >= SWIPE_MIN || ady >= SWIPE_MIN) {
            // The touch axes are swapped relative to the game grid, so a raw
            // swipe maps to the wrong snake direction. Observed raw->wanted:
            //   left->up, up->left, down->right, right->down.
            // That is exactly a swap of the swipe axes: (sdx,sdy) = (dy, dx).
            int gdx = dy;      // horizontal snake move comes from vertical swipe
            int gdy = dx;      // vertical snake move comes from horizontal swipe
            int agx = abs(gdx), agy = abs(gdy);
            if (agx > agy) {
                next_dx = (gdx > 0) ? 1 : -1; next_dy = 0;
            } else {
                next_dy = (gdy > 0) ? 1 : -1; next_dx = 0;
            }
            // Reset origin so a continued drag can trigger another turn.
            start_x = x; start_y = y;
        }
        last_x = x; last_y = y;
    } else if (!now && touching) {
        touching = false;
    }
    return false;
}

// For the game-over screen: return true once a full tap (press+release) happens.
static bool poll_touch_tap(void)
{
    int x, y;
    bool now = read_touch(&x, &y);
    if (now && !touching) {
        touching = true;
    } else if (!now && touching) {
        touching = false;
        return true;    // released -> counts as a tap
    }
    return false;
}

// ------------------------------------------------------------------------
// Main loop
// ------------------------------------------------------------------------
void Snake_Game_Run(void)
{
    fb = heap_caps_malloc(SCR_W * SCR_H * sizeof(uint16_t), MALLOC_CAP_SPIRAM);
    if (!fb) {
        // Fall back to internal RAM attempt (will likely fail at this size);
        // log and bail so the failure is visible on the serial monitor.
        ESP_LOGE(TAG, "Failed to allocate %d KB framebuffer in PSRAM",
                 (int)(SCR_W * SCR_H * sizeof(uint16_t) / 1024));
        return;
    }
    ESP_LOGI(TAG, "Snake started: grid %dx%d, cell %dpx", GRID_W, GRID_H, CELL);

    Set_Backlight(80);

    // Step timing: start slower, speed up slightly as score grows.
    const int base_ms = 260;
    const int min_ms  = 140;

    for (;;) {                       // one iteration = one full game
        game_reset();
        render_play();

        // Small settle so an in-progress touch from the menu is released.
        touching = false;

        while (alive) {
            int step_ms = base_ms - score * 4;
            if (step_ms < min_ms) step_ms = min_ms;

            // Poll touch on a fixed cadence (independent of the game speed)
            // so swipes register with low latency. 10ms == one FreeRTOS tick,
            // which actually yields the CPU (pdMS_TO_TICKS of <10ms rounds to
            // 0 ticks -> a busy-spin that starves the touch task).
            const int poll_ms = 10;
            int elapsed = 0;
            while (elapsed < step_ms) {
                poll_touch_play();
                vTaskDelay(pdMS_TO_TICKS(poll_ms));
                elapsed += poll_ms;
            }

            if (!game_step()) {
                alive = false;
                break;
            }
            render_play();
        }

        render_gameover();

        // Wait for a tap to restart. Require a fresh press: clear touch state.
        touching = false;
        // Ignore taps for a moment so the death swipe doesn't instantly restart.
        vTaskDelay(pdMS_TO_TICKS(400));
        touching = false;
        while (!poll_touch_tap()) {
            vTaskDelay(pdMS_TO_TICKS(20));
        }
    }
}
