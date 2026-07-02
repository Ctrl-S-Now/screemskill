#pragma once

// Touch-controlled Snake game rendered directly to the RGB panel.
// No LVGL: maintains its own RGB565 framebuffer and pushes full frames
// via esp_lcd_panel_draw_bitmap(). Swipe on the screen to steer the snake;
// tap after Game Over to restart.
//
// Requires (call before Snake_Game_Run):
//   I2C_Init(); EXIO_Init(); LCD_Init(); Touch_Init();
void Snake_Game_Run(void);
