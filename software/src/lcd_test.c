#include <stdint.h>
#include <stdbool.h>

#define CLK_SYS_MHZ 12
#include "gpio.h"
#include "spi_lcd.h"
#include "pwm.h"

int main()
{
	pwm_enable(false);
	pwm_invert(true);
	spi_lcd_init(st7789_init_seq);

	uint8_t buf[2];

	spi_lcd_start_pixels();
	for (int y = 0; y < 240; ++y)
	{
		for (int x = 0; x < 240; ++x)
		{
			uint32_t colour = x & 0x1f | ((y & 0x1f) << 11) | (((x + y) >> 3) << 5);
			buf[0] = colour >> 8;
			buf[1] = colour & 0xff;
			spi_lcd_write(buf, 2);
		}
	}
}
