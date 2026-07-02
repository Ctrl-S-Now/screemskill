#include "Proof_Image.h"
#include "ST7701S.h"

#include "../LVGL_UI/proof_image_data.inc"

void Proof_Image_Show(void)
{
    ESP_ERROR_CHECK(esp_lcd_panel_draw_bitmap(
        panel_handle,
        0,
        0,
        EXAMPLE_LCD_H_RES,
        EXAMPLE_LCD_V_RES,
        proof_image_map));
}
