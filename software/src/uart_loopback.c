#define CLK_SYS_MHZ 50

#include "gpio.h"
#include "tbman.h"
#include "uart.h"


const char *str = "Hello, loopback!\n";

int main()
{
	gpio_fsel(PIN_UART_TX, 1);
	gpio_fsel(PIN_UART_RX, 1);
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, 115200);
	*UART_CSR |= UART_CSR_LOOPBACK_MASK;

	char *p = str;
	while (*p)
	{
		uart_put(*p++);
		char c = uart_get();
		tbman_putc(c);
	}

	tbman_exit(0);
}