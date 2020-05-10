#include "lcd.h"
#include "tbman.h"

int main()
{
	tbman_puts("Sup\n");

	lcd_force_dc_cs(0, 1);
	lcd_set_shift_width(8);
	for (int i = 0; i < 10; ++i)
	{
		lcd_force_dc_cs(i & 1, 1);
		lcd_force_dc_cs(i & 1, 0);
		lcd_put_byte(i);
		lcd_wait_idle();
		lcd_force_dc_cs(i & 1, 1);
	}

	lcd_force_dc_cs(1, 0);
	lcd_set_shift_width(16);
	for (int i = 0; i < 50; ++i)
		lcd_put_hword(0xf000 | i);

	tbman_exit(0);
}
