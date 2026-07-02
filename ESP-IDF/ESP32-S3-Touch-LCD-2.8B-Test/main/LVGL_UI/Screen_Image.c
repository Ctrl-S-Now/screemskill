#include "lvgl.h"
#include "Screen_Image.h"

#include "screen_image_data.inc"

static const lv_img_dsc_t screen_image = {
    .header.always_zero = 0,
    .header.w = 480,
    .header.h = 640,
    .data_size = sizeof(screen_image_map),
    .header.cf = LV_IMG_CF_TRUE_COLOR,
    .data = screen_image_map,
};

void Screen_Image_Show(void)
{
    lv_obj_t *image = lv_img_create(lv_scr_act());
    lv_img_set_src(image, &screen_image);
    lv_obj_center(image);
}
