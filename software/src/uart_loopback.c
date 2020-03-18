#define CLK_SYS_MHZ 50

#include "gpio.h"
#include "tbman.h"
#include "uart.h"
#include "delay.h"

#define FIFO_DEPTH 4

const char *str = "Hello, loopback!\n";

int main()
{
	gpio_fsel(PIN_UART_TX, 1);
	gpio_fsel(PIN_UART_RX, 1);
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, 115200);
	*UART_CSR |= UART_CSR_LOOPBACK_MASK;

	// First test is checked externally,
	// based on observing UART/TBMAN output.

	const char *s = str;
	while (*s)
	{
		uart_put(*s++);
		char c = uart_get();
		tbman_putc(c);
	}

	// Second test is checked internally, and reported on.

	bool failed = false;
	tbman_puts("Aggressive loopback:\n");

	uart_clkdiv_baud(CLK_SYS_MHZ, 1000 * 1000);

	const int test_len = 128;
	uint8_t txbuf[test_len];
	uint8_t rxbuf[test_len];

	uint8_t *p = rxbuf;

	for (int i = 0; i < test_len; ++i)
		txbuf[i] = i;

	for (int i = 0; i < test_len; ++i)
	{
		uart_put(txbuf[i]);
		if (!uart_rx_empty())
			*p++ = uart_get();
	}
	while (*UART_CSR & UART_CSR_BUSY_MASK)
		if (!uart_rx_empty())
			*p++ = uart_get();
	while (!uart_rx_empty())
		*p++ = uart_get();


	if (p != rxbuf + test_len)
	{
		failed = true;
		tbman_puts("Length mismatch\n");
	}


	if (!failed)
	{
		int accum = 0;
		for (int i = 0; i < test_len; ++i)
		{
			accum += rxbuf[i];
			if (txbuf[i] != rxbuf[i])
			{
				failed = true;
				tbman_puts("Data mismatch @:\n");
				tbman_putint(i);
			}
		}
		tbman_puts("RX sum:\n");
		tbman_putint(accum);
	}

	// Finally a quick smoke test for RTS/CTS (which are also patched together by LOOPBACK)

	uart_enable_cts(true);

	tbman_puts("RTS/CTS smoke test:\n");
	for (int i = 0; i < 2 * FIFO_DEPTH - 1; ++i)
		uart_put(~i);

	delay_ms(1);

	for (int i = 0; i < 2 * FIFO_DEPTH - 1; ++i)
	{
		if (uart_get() != (~i & 0xff))
		{
			puts("Data mismatch\n");
			failed = true;
		}
	}
	if (!failed)
		tbman_puts("OK.\n");

	tbman_exit(failed);
}
