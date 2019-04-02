#define CLK_SYS_MHZ 24

#include "delay.h"
#include "gpio.h"

int main()
{
	gpio_fsel(PIN_LED, 0);
	gpio_dir_pin(PIN_LED, 1);
	while (true)
	{
		for (int i = 0; i < 6; ++i)
		{
			delay_ms(100);
			*GPIO_OUT ^= (1ul << PIN_LED);
		}
		for (int i = 0; i < 3; ++i)
		{
			delay_ms(300);
			*GPIO_OUT ^= (1ul << PIN_LED);
		}
	}
}