#include "gpio.h"
#include "uart.h"

#define PIN_UART_TX 15
#define PIN_LED 0
#define CLK_SYS_MHZ 12
#define DELAY 1000000

void bad_delay(volatile int x)
{
	while (x--)
		;
}

int main()
{
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, 115200);
	gpio_fsel(PIN_UART_TX, 1);

	gpio_fsel(PIN_LED, 0);
	gpio_dir_pin(PIN_LED, 1);

	while (true)
	{
		gpio_out_pin(PIN_LED, 1);
		bad_delay(DELAY);
		gpio_out_pin(PIN_LED, 0);
		uart_puts("Hello, world!\n");
		bad_delay(DELAY);
	}
}