#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

/* 流水燈順序：LED0 → LED2 → LED3 → LED1 */
#define BLINK_DELAY_MS 200

static const struct gpio_dt_spec leds[] = {
    GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios),
    GPIO_DT_SPEC_GET(DT_ALIAS(led1), gpios),
    GPIO_DT_SPEC_GET(DT_ALIAS(led2), gpios),
    GPIO_DT_SPEC_GET(DT_ALIAS(led3), gpios),
};

static const int sequence[] = {0, 2, 3, 1};

int main(void)
{
    /* 初始化所有 LED GPIO */
    for (int i = 0; i < ARRAY_SIZE(leds); i++) {
        if (!gpio_is_ready_dt(&leds[i])) {
            return -ENODEV;
        }
        gpio_pin_configure_dt(&leds[i], GPIO_OUTPUT_INACTIVE);
    }

    /* 流水燈主迴圈 */
    while (1) {
        for (int s = 0; s < ARRAY_SIZE(sequence); s++) {
            int idx = sequence[s];

            /* 全滅後點亮當前 LED */
            for (int i = 0; i < ARRAY_SIZE(leds); i++) {
                gpio_pin_set_dt(&leds[i], 0);
            }
            gpio_pin_set_dt(&leds[idx], 1);
            k_msleep(BLINK_DELAY_MS);
        }
    }

    return 0;
}
