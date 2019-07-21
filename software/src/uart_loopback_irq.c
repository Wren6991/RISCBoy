#define CLK_SYS_MHZ 50

#include "irq.h"
#include "tbman.h"
#include "uart.h"
#include <stdbool.h>

const char *test_str = "Hello, interrupt! 0123456789.";
// Using volatile flags to communicate between handler and thread mode. Like an animal.
volatile char rxbuf[64];
volatile bool rx_done;


ISR_UART()
{
	volatile static char * rxptr = rxbuf;
	while (!uart_rx_empty())
		*rxptr++ = (char)uart_get();
	if (*(rxptr - 1) == '.')
	{
		*rxptr++ = 0;
		rx_done = true;
	}
}

// Don't have room for stdlib in this environment
bool bad_strcmp(const char *s, const char *t)
{
	while (*s || *t)
	{
		if (*s++ != *t++)
			return true;
	}
	return false;
}

int main()
{
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, 115200);
	// Enable interrupt on RX not empty, and enable hard loopback mode
	*UART_CSR |= UART_CSR_RXIE_MASK | UART_CSR_LOOPBACK_MASK;

	global_irq_enable();
	external_irq_enable(IRQ_UART);

	tbman_puts("Starting TX\n");
	uart_puts(test_str); 
	while (!rx_done)
		;
	tbman_puts("RX complete\n");

	tbman_exit(bad_strcmp(test_str, (const char*)rxbuf));
}