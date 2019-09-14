#include <stdint.h>
#include <stdbool.h>

#define CLK_SYS_MHZ 12
#include "gpio.h"
#include "lcd.h"
#include "pwm.h"

static uint16_t palette[256];

#define WIDTH 240
#define HEIGHT 240
#define FIXPOINT 8
#define ESCAPE (3 << FIXPOINT)

int main()
{
	gpio_fsel(PIN_LCD_PWM, 1);
	pwm_enable(false);
	pwm_invert(true);
	lcd_init(st7789_init_seq);

	for (int i = 0; i < 256; ++i)
	{
		uint8_t r = 255 - i;
		uint8_t g = i < 128 ? 128 : 255 - i;
		uint8_t b = 0;
		palette[i] = (b >> 3) | ((g >> 2) << 5) | ((r >> 3) << 11);
	}

	// Output a test pattern and clear it, to check everything works
	st7789_start_pixels();
	for (int y = 0; y < HEIGHT; ++y)
	{
		for (int x = 0; x < WIDTH; ++x)
		{
			uint16_t colour = palette[(x + y) >> 1];
			lcd_put_hword(colour);
		}
	}
	st7789_start_pixels();
	for (int y = 0; y < HEIGHT; ++y)
	{
		for (int x = 0; x < WIDTH; ++x)
		{
			lcd_put_hword(0xffffu);
		}
	}

	// This time it's for real
	st7789_start_pixels();
	for (int y = 0; y < HEIGHT; ++y)
	{
		for (int x = 0; x < WIDTH; ++x)
		{
			int32_t cr = (x - WIDTH / 2 - 10) * 3;
			int32_t ci = (y - HEIGHT / 2) * 3;
			int32_t zr = cr;
			int32_t zi = ci;
			int i = 0;
			for (; i < 255; ++i)
			{
				int32_t zr_tmp = (((zr * zr) - (zi * zi)) >> FIXPOINT) + cr;
				zi = 2 * ((zr * zi) >> FIXPOINT) + ci;
				zr = zr_tmp;
				if (zi < -ESCAPE || zi > ESCAPE || zr < -ESCAPE || zr > ESCAPE)
					break;
			}
			uint16_t colour = palette[i];
			lcd_put_hword(colour);
		}
	}
}
