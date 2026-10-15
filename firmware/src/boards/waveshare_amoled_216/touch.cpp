#include "../../hal/touch_hal.h"
#include "../../hal/imu_hal.h"
#include "board.h"
#include <Arduino.h>
#include <Wire.h>
#include <TouchDrvCSTXXX.hpp>

static TouchDrvCST92xx touch;

static volatile bool     touch_data_ready = false;
static volatile bool     touch_pressed = false;
static volatile uint16_t touch_x = 0;
static volatile uint16_t touch_y = 0;

static void IRAM_ATTR touch_isr(void) {
    touch_data_ready = true;
}

void touch_hal_init(void) {
    touch.setPins(TP_RST, TP_INT);
    if (!touch.begin(Wire, CST9220_ADDR, IIC_SDA, IIC_SCL)) {
        Serial.println("Touch init failed");
        return;
    }
    touch.setMaxCoordinates(LCD_WIDTH, LCD_HEIGHT);
    // The panel's own frame at rotation 0, measured with swipes on hardware.
    touch.setMirrorXY(false, true);
    pinMode(TP_INT, INPUT_PULLUP);
    attachInterrupt(TP_INT, touch_isr, FALLING);
    Serial.println("Touch init OK");
}

void touch_hal_read(uint16_t* x, uint16_t* y, bool* pressed) {
    if (touch_data_ready) {
        touch_data_ready = false;
        int16_t tx[5], ty[5];
        uint8_t n = touch.getPoint(tx, ty, touch.getSupportTouchPoint());
        if (n > 0) {
            touch_pressed = true;
            touch_x = (uint16_t)tx[0];
            touch_y = (uint16_t)ty[0];
        } else {
            touch_pressed = false;
        }
    }
    // The panel is turned in software (display.cpp), so LVGL always draws at
    // 0°. Undo the same turn here or a swipe reads as the wrong direction.
    const uint16_t m = LCD_WIDTH - 1;
    const uint16_t px = touch_x < m ? touch_x : m, py = touch_y < m ? touch_y : m;
    switch (imu_hal_rotation_quadrant()) {
    case 1:  *x = py;     *y = m - px; break;
    case 2:  *x = m - px; *y = m - py; break;
    case 3:  *x = m - py; *y = px;     break;
    default: *x = px;     *y = py;     break;
    }
    *pressed = touch_pressed;
}
