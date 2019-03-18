#include "gpio.h"

#define LED_PIN 0
#define LED_MASK (1ul << LED_PIN)

#define DELAY_COUNT 100000

int main()
{
	gpio_fsel(LED_PIN, 0);
	gpio_dir_pin(LED_PIN, 1);
	while (true)
	{
		for (volatile int i = 0; i < DELAY_COUNT; ++i)
			;
		*GPIO_OUT ^= LED_MASK;
	}
}