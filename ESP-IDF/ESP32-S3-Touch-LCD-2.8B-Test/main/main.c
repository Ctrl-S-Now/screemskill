#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "TCA9554PWR.h"
#include "PCF85063.h"
#include "QMI8658.h"
#include "ST7701S.h"
#include "GT911.h"
#include "SD_MMC.h"
#include "LVGL_Driver.h"
#include "LVGL_Example.h"
#include "Screen_Image.h"
#include "Wireless.h"
#include "BAT_Driver.h"
#include "Proof_Image.h"

#define FIRST_BOOT_IMAGE_TEST 1

void Driver_Loop(void *parameter)
{
    while(1)
    {
        QMI8658_Loop();
        RTC_Loop();
        BAT_Get_Volts();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
    vTaskDelete(NULL);
}
void Driver_Init(void)
{
    Flash_Searching();
    BAT_Init();
    I2C_Init();
    PCF85063_Init();
    QMI8658_Init();
    EXIO_Init();                    // Example Initialize EXIO
    xTaskCreatePinnedToCore(
        Driver_Loop, 
        "Other Driver task",
        4096, 
        NULL, 
        3, 
        NULL, 
        0);
}
void app_main(void)
{
#if FIRST_BOOT_IMAGE_TEST
    I2C_Init();
    EXIO_Init();
    LCD_Init();
    Proof_Image_Show();

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
#else
    Wireless_Init();
    Driver_Init();
    LCD_Init();
    Touch_Init();
    SD_Init();
    LVGL_Init();
/********************* Full-screen image *********************/
    Screen_Image_Show();

    // lv_demo_widgets();
    // lv_demo_keypad_encoder();
    // lv_demo_benchmark();
    // lv_demo_stress();
    // lv_demo_music();

    while (1) {
        // raise the task priority of LVGL and/or reduce the handler period can improve the performance
        vTaskDelay(pdMS_TO_TICKS(10));
        // The task running lv_timer_handler should have lower priority than that running `lv_tick_inc`
        lv_timer_handler();
    }
#endif
}
