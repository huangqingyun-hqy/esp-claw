/*
 * gamebox_s3 board glue for esp_board_manager.
 * Provides lcd_panel_factory_entry_t required by dev_display_lcd (SPI sub-device).
 * The 2.0inch HS20S010B module is a standard ST7789 240x320 panel, so the
 * built-in esp_lcd ST7789 driver is sufficient (no vendor init sequence needed).
 */
#include <string.h>
#include "esp_log.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_vendor.h"

static const char *TAG = "GAMEBOX_S3_SETUP";

esp_err_t lcd_panel_factory_entry_t(esp_lcd_panel_io_handle_t io,
                                    const esp_lcd_panel_dev_config_t *panel_dev_config,
                                    esp_lcd_panel_handle_t *ret_panel)
{
    esp_err_t ret = esp_lcd_new_panel_st7789(io, panel_dev_config, ret_panel);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to create ST7789 panel: %s", esp_err_to_name(ret));
        return ret;
    }
    ESP_LOGI(TAG, "ST7789 panel created (240x320 SPI)");
    return ESP_OK;
}
