
#define CLK_SYS_MHZ 12

#include "delay.h"
#include "gpio.h"
#include "spi.h"
#include "uart.h"

const char *splash =
"\n"
"  ___ ___ ___  ___ ___\n"
" | _ \\_ _/ __|/ __| _ ) ___ _  _\n"
" |   /| |\\__ \\ (__| _ \\/ _ \\ || |\n"
" |_|_\\___|___/\\___|___/\\___/\\_, |\n"
"                            |__/\n\n"
"SPI flash shell\n\n";

const char *help =
"Commands:\n"
"i: read id register\n"
"r: read 64B page\n"
"w: program 64B page\n"
"e: erase sector\n"
"L/l: LED on/off\n"
"h: show this help\n"
"\n";


static uint8_t getbyte()
{
	uint8_t b = 0;
	int i = 0;
	while (i < 2)
	{
		uint8_t c = uart_get();
		bool ignore = false;
		if (c >= 'a' && c <= 'f')
			b |= 0xa + c - 'a';
		else if (c >= 'A' && c <= 'F')
			b |= 0xA + c - 'A';
		else if (c >= '0' && c <= '9')
			b |= c - '0';
		else
			ignore = true;
		if (!ignore)
		{
			uart_put(c);
			++i;
			if (i < 2)
				b <<= 4;
		}
	}
	return b;
}

static inline void flash_set_write_enable()
{
	uint8_t cmd = 0x06;
	spi_write(&cmd, 1);
	spi_wait_done();
}

static inline void flash_wait_done()
{
	uint8_t txbuf[2] = {0x05, 0x00};
	uint8_t rxbuf[2];
	while (true)
	{
		delay_us(50);
		spi_write_read(txbuf, rxbuf, 2);
		if (!(rxbuf[1] & 0x1))
			break;
	}
}

int main()
{
	// Oh no hope nobody overruns our buffer :o
	const size_t BUFSIZE = 80;
	uint8_t txbuf[BUFSIZE];
	uint8_t rxbuf[BUFSIZE];

	gpio_fsel(PIN_UART_TX, 1);
	gpio_fsel(PIN_UART_RX, 1);
	gpio_fsel(PIN_FLASH_CS, 1);
	gpio_fsel(PIN_FLASH_SCLK, 1);
	gpio_fsel(PIN_FLASH_MOSI, 1);
	gpio_fsel(PIN_FLASH_MISO, 1);

	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, 115200);
	spi_init(false, false);
	spi_clkdiv(CLK_SYS_MHZ / 2); // 1 MHz

	// Blinkity blink motherfucker
	// I tied the LED to the reset pin on the TinyFPGA.
	// Why?
	// One reason:
	// ¯\_(ツ)_/¯

	gpio_fsel(PIN_LED, 0);
	gpio_dir_pin(PIN_LED, true);
	for (int i = 0; i < 6; ++i)
	{
		*GPIO_OUT ^= (1ul << PIN_LED);
		delay_ms(100);
	}

	uart_puts(splash);
	uart_puts(help);

	while (true)
	{
		uart_puts("> ");
		for (int i = 0; i < BUFSIZE; ++i)
		{
			txbuf[i] = 0;
			rxbuf[i] = 0;
		}
		char c;
		do
		{
			c = uart_get();
			if (c != ' ')
			{
				uart_put(c);
				uart_puts("\n");
			}
		} while (c == ' ');

		switch (c)
		{
			case 'i': {
				txbuf[0] = 0x90; // JEDEC ID read
				spi_write_read(txbuf, rxbuf, 6);
				uart_puts("ID: ");
				uart_putbyte(rxbuf[4]);
				uart_putbyte(rxbuf[5]);
				uart_puts("\n");
				break;
			}
			case 'r': {
				txbuf[0] = 0x03; // cont read command
				uart_puts(": ");
				for (int i = 0; i < 3; ++i)
					txbuf[i + 1] = getbyte();
				uart_puts("\n");
				spi_write_read(txbuf, rxbuf, 64 + 4);
				for (int i = 0; i < 64; ++i)
				{
					uart_putbyte(rxbuf[i + 4]);
					if ((i & 0x7) == 0x7)
						uart_puts("\n");
				}
				break;
			}
			case 'w': {
				txbuf[0] = 0x02;
				uart_puts(": ");
				for (int i = 0; i < 3; ++i)
					txbuf[i + 1] = getbyte();
				for (int i = 0; i < 64; ++i)
				{
					if (!(i & 0x7))
						uart_puts("\n: ");
					txbuf[i + 4] = getbyte();
				}
				uart_puts("\nprog...\n");
				flash_set_write_enable();
				spi_write(txbuf, 68);
				spi_wait_done();
				flash_wait_done();
				uart_puts("done\n");
				break;
			}
			case 'e': {
				txbuf[0] = 0x20;
				uart_puts(": ");
				for (int i = 0; i < 3; ++i)
					txbuf[i + 1] = getbyte();
				uart_puts("\nerasing...\n");
				flash_set_write_enable();
				spi_write(txbuf, 4);
				spi_wait_done(); // CS must go high after sector erase cmd
				flash_wait_done();
				uart_puts("done\n");
				break;
			}
			case 'L':
				gpio_out_pin(PIN_LED, 1);
				break;
			case 'l':
				gpio_out_pin(PIN_LED, 0);
				break;
			case '\r':
			case '\n':
				break;
			default:
				uart_puts(help);
				break;
		}
	}
	return 0;
}