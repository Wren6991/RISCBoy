#include "tbman.h"
#include "gpio.h"
#include "uart.h"

#define CLK_FREQ_MHZ 50

int main()
{
	// Connect UART out to pad
	gpio_fsel(15, 1);

	// Float stuff should all be compile-time. 115200 baud.
	uart_init();
	uart_clkdiv((uint32_t)(CLK_FREQ_MHZ * 1e6 * (256.0 / 8.0) / 115200.0));

	tbman_puts("Hello, tbman!\n");
	uart_puts("Hello, UART!\n");

	// Need to wait for completion, else we will terminate the simulation
	// while characters still in FIFO.
	uart_wait_done();
	tbman_exit(0);
}