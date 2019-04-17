#define CLK_SYS_MHZ 36

#include "delay.h"
#include "gpio.h"
#include "uart.h"

int main()
{
	uart_wait_done();
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, 500000);
	gpio_fsel(PIN_UART_TX, 1);

	uart_puts("Hello, world! From 2nd stage code\n");
	uart_puts("Commence LED blinking\n");

	gpio_fsel(PIN_LED, 0);
	gpio_dir_pin(PIN_LED, 1);

	while (true)
	{
		uart_puts("blink\n");
		gpio_out_pin(PIN_LED, 1);
		delay_ms(500);
		uart_puts("blonk\n");
		gpio_out_pin(PIN_LED, 0);
		delay_ms(500);
	}
}
