#include <stdint.h>
#include <stdbool.h>

#define CLK_SYS_MHZ 12
#include "gpio.h"
#include "lcd.h"
#include "pwm.h"
#include "tbman.h"

static uint16_t palette[256];

#define WIDTH 320
#define HEIGHT 240
#define FIXPOINT 8
#define ESCAPE (3 << FIXPOINT)

int main()
{
	gpio_fsel(PIN_LCD_PWM, 1);
	pwm_enable(false);
	pwm_invert(true);
	if (!tbman_running_in_sim())
		lcd_init(ili9341_init_seq);

	for (int i = 0; i < 256; ++i)
	{
		int j = i * 8;
		uint8_t r = 255 - j;
		uint8_t g = j < 128 ? j : 255 - j;
		uint8_t b = 0;
		palette[i] = (b >> 3) | ((g >> 2) << 5) | ((r >> 3) << 11);
	}

	// Output a test pattern and clear it, to check everything works
	if (!tbman_running_in_sim())
	{
		// st7789_start_pixels();
		// for (int y = 0; y < HEIGHT; ++y)
		// {
		// 	for (int x = 0; x < WIDTH; ++x)
		// 	{
		// 		uint16_t colour = palette[(x + y) >> 1];
		// 		lcd_put_hword(colour);
		// 	}
		// }
		st7789_start_pixels();
		for (int y = 0; y < HEIGHT; ++y)
		{
			for (int x = 0; x < WIDTH; ++x)
			{
				lcd_put_hword(0xffffu);
			}
		}
	}

	// This time it's for real
	st7789_start_pixels();
	for (int y = 0; y < HEIGHT; ++y)
	{
		for (int x = 0; x < WIDTH; ++x)
		{
			int32_t cr = (x - WIDTH / 2 - 20) * 3;
			int32_t ci = (y - HEIGHT / 2) * 3;
			int32_t zr = cr;
			int32_t zi = ci;
			int i = 0;
			for (; i < 31; ++i)
			{
				int32_t zr_tmp = (((zr * zr) - (zi * zi)) >> FIXPOINT) + cr;
				zi = 2 * ((zr * zi) >> FIXPOINT) + ci;
				zr = zr_tmp;
				if (zi * zi + zr * zr > ESCAPE * ESCAPE)
					break;
			}
			uint16_t colour = palette[i];
			lcd_put_hword(colour);
		}
	}
}
