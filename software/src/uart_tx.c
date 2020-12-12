#include "tbman.h"
#include "gpio.h"
#include "uart.h"

#define CLK_FREQ_MHZ 100

int main()
{
	// Float stuff should all be compile-time. 115200 baud.
	uart_init();
	uart_clkdiv_baud(CLK_FREQ_MHZ, 115200);

	tbman_puts("Hello, tbman!\n");
	uart_puts("Hello, UART!\n");

	// Need to wait for completion, else we will terminate the simulation
	// while characters still in FIFO.
	uart_wait_done();
	tbman_exit(0);
}
