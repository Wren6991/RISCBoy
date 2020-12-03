#include "spi_lcd.h"
#include "tbman.h"

int main()
{
	tbman_puts("Sup\n");

	spi_lcd_force_dc_cs(0, 1);
	spi_lcd_set_shift_width(8);
	for (int i = 0; i < 10; ++i)
	{
		spi_lcd_force_dc_cs(i & 1, 1);
		spi_lcd_force_dc_cs(i & 1, 0);
		spi_lcd_put_byte(i);
		spi_lcd_wait_idle();
		spi_lcd_force_dc_cs(i & 1, 1);
	}

	spi_lcd_force_dc_cs(1, 0);
	spi_lcd_set_shift_width(16);
	for (int i = 0; i < 50; ++i)
		spi_lcd_put_hword(0xf000 | i);

	tbman_exit(0);
}
