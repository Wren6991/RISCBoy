#include "gpio.h"
#include "tbman.h"

const uint32_t test_vec[] = {
	0x12345678,
	0x23456789,
	0x3456789a,
	0x456789ab
};

int main()
{
	tbman_puts("GPIO test");
	gpio_out(0);
	gpio_dir(~0ul);
	tbman_putint(gpio_in());
	for (int i = 0; i < sizeof(test_vec) / sizeof(*test_vec); ++i)
	{
		gpio_out(test_vec[i]);
		tbman_putint(gpio_in());
	}
	tbman_exit(0);
}
