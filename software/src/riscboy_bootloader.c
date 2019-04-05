#define CLK_SYS_MHZ 36

#include "delay.h"
#include "gpio.h"
#include "spi.h"
#include "uart.h"

#define UART_BAUD (500 * 1000)
#define SPI_CLK_MHZ 6
#define HOST_TIMEOUT_MS 1000

const char *splash =
"\n"
"  ___ ___ ___  ___ ___\n"
" | _ \\_ _/ __|/ __| _ ) ___ _  _\n"
" |   /| |\\__ \\ (__| _ \\/ _ \\ || |\n"
" |_|_\\___|___/\\___|___/\\___/\\_, |\n"
"                            |__/\n\n";

// Serial bootloader for RISCBoy.
// Allows host machine to read/write SPI flash via UART.
// If no host is detected, after some timeout, a 2nd-stage
// program will be loaded from SPI flash and executed.

// We have 8k to play with (internal SRAM w/ preload), but
// it would be nice to put something on the screen and make some
// noise too :) so code should be reasonably efficient, and
// compiled with -Os.

// The host has commands for efficiently transferring
// a page-sized buffer back and forth. It can also
// ask us to calculate a checksum of our copy, and send it,
// to ensure that our copy matches what it sent/received.

// The SET_ADDR command sets the address of the next flash access
// (in bytes), which we echo back. The address is auto-incremented
// by one page after each read/program, and one sector after each erase.

// A separate set of commands is used for reading from the SPI flash into
// the page buffer, writing to flash from the buffer, or erasing
// flash sectors.

// If the host detects a checksum error, it can simply retransmit or
// request retransmission.

// If the host detects a sequencing/protocol error (e.g. ACK timeout after
// programming command), the reset sequence is:
// - send NOP * (PAGESIZE + 1)
// - wait 20 ms
// - flush host RX buffer
// - send NOP
// - wait for ACK
// - if no ACK after 20 ms, repeat

#define BLOCKSIZE 65536
#define SECTORSIZE 4096
#define PAGESIZE 256
#define ADDRSIZE 3
#define BOOT_2ND_MAGIC 0x123456

#define NOP          '\n'

#define WRITE_BUF    'w'
#define READ_BUF     'r'
#define GET_CHECKSUM 'c'

#define SET_ADDR     'a'

#define WRITE_FLASH  'W' // No effect if addr isn't page-aligned
#define READ_FLASH   'R'
#define ERASE_SECTOR 'E' // No effect if addr isn't sector-aligned
#define ERASE_BLOCK  'B' // No effect if addr isn't block-aligned

#define BOOT_2ND     '2' // No effect if addr isn't magic 0x123456
                         // (since this is a destructive thing to do if
                         // the device is partially programmed!)

#define ACK          ':' // a toggle-y sequence

uint8_t cmdbuf[1 + ADDRSIZE + PAGESIZE];
uint8_t *pagebuf = cmdbuf + 1 + ADDRSIZE;

void run_2nd_stage();
void run_flash_shell();

int main()
{
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	spi_init(false, false);
	spi_clkdiv(CLK_SYS_MHZ / (2 * SPI_CLK_MHZ));

	gpio_fsel(PIN_LED, 0);
	gpio_dir_pin(PIN_LED, 1);

	gpio_fsel(PIN_UART_TX, 1);
	gpio_fsel(PIN_UART_RX, 1);
	gpio_fsel(PIN_FLASH_CS, 1);
	gpio_fsel(PIN_FLASH_SCLK, 1);
	gpio_fsel(PIN_FLASH_MOSI, 1);
	gpio_fsel(PIN_FLASH_MISO, 1);

	uart_puts(splash);
	gpio_out_pin(PIN_LED, 1);

	int nop_count = 0;
	int t;
	for (t = 0; t < HOST_TIMEOUT_MS; ++t)
	{
		while (!uart_rx_empty())
			if (uart_get() == NOP)
				++nop_count;
		if (nop_count > 10)
			break;
		delay_us(1000);
	}

	gpio_out_pin(PIN_LED, 0);
	if (t >= HOST_TIMEOUT_MS)
		run_2nd_stage();

	uart_put(ACK);

	run_flash_shell();
}

void run_2nd_stage()
{
	uart_puts("Loading 2nd stage... kinda\n");
	while (true)
	{
		delay_ms(500);
		gpio_out_pin(PIN_LED, 1);
		delay_ms(500);
		gpio_out_pin(PIN_LED, 0);
	}
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

// TODO: use something better
uint16_t checksum(uint8_t *data, size_t len)
{
	uint16_t sum = 0xffff;
	for (int i = 0; i < len; ++i)
		sum = (sum + (sum << 3) + 1) ^ (data[i] + (data[i] << 5) + (data[i] << 9));
}

static inline void set_cmd_addr(uint32_t addr)
{
	cmdbuf[1] = (addr >> 16) & 0xff;
	cmdbuf[2] = (addr >> 8 ) & 0xff;
	cmdbuf[3] = (addr >> 0 ) & 0xff;
}

void run_flash_shell()
{
	uint32_t addr = 123; // Deliberately non-aligned. W/E are NOPs until this is initialised

	while (true)
	{
		char c = uart_get();
		switch (c)
		{
			case NOP:
				uart_put(ACK);
				break;
			case WRITE_BUF: {
				uint8_t *p = pagebuf;
				for (int i = 0; i < PAGESIZE; ++i)
					*p++ = uart_get();
				uart_put(ACK);
				break;
			}
			case READ_BUF:
			{
				uint8_t *p = pagebuf;
				for (int i = 0; i < PAGESIZE; ++i)
					uart_put(*p++);
				// No ACK; data is enough.
				break;
			}
			case GET_CHECKSUM:
			{
				uint16_t sum = checksum(pagebuf, PAGESIZE);
				uart_put(sum >> 8);
				uart_put(sum);
				// No ACK
				break;
			}
			case SET_ADDR:
			{
				addr = 0;
				for (int i = 0; i < 3; ++i)
				{
					uint8_t c = uart_get();
					uart_put(c);
					addr = (addr << 8) | c;
				}
				uart_put(ACK);
				break;
			}
			case WRITE_FLASH:
			{
				gpio_out_pin(PIN_LED, 1);
				if (!(addr & (PAGESIZE - 1)))
				{
					flash_set_write_enable();
					cmdbuf[0] = 0x02;
					set_cmd_addr(addr);
					spi_write(cmdbuf, PAGESIZE + 4);
					spi_wait_done();
					flash_wait_done();
					addr += PAGESIZE;
				}
				uart_put(ACK);
				gpio_out_pin(PIN_LED, 0);
				break;
			}
			case READ_FLASH:
			{
				gpio_out_pin(PIN_LED, 1);
				cmdbuf[0] = 0x03;
				set_cmd_addr(addr);
				spi_write_read(cmdbuf, cmdbuf, PAGESIZE + 4);
				spi_wait_done();
				addr += PAGESIZE;
				uart_put(ACK);
				gpio_out_pin(PIN_LED, 0);
				break;
			}
			case ERASE_SECTOR:
			{
				gpio_out_pin(PIN_LED, 1);
				if (!(addr & (SECTORSIZE - 1)))
				{
					flash_set_write_enable();
					cmdbuf[0] = 0x20;
					set_cmd_addr(addr);
					spi_write(cmdbuf, 4);
					spi_wait_done();
					flash_wait_done();
					addr += SECTORSIZE;
				}
				uart_put(ACK);
				gpio_out_pin(PIN_LED, 0);
				break;
			}
			case ERASE_BLOCK:
			{
				gpio_out_pin(PIN_LED, 1);
				if (!(addr & (BLOCKSIZE - 1)))
				{
					flash_set_write_enable();
					cmdbuf[0] = 0xd8;
					set_cmd_addr(addr);
					spi_write(cmdbuf, 4);
					spi_wait_done();
					flash_wait_done();
					addr += BLOCKSIZE;
				}
				uart_put(ACK);
				gpio_out_pin(PIN_LED, 0);
				break;
			}
			case BOOT_2ND:
				uart_put(ACK);
				if (addr == BOOT_2ND_MAGIC)
					run_2nd_stage();
				break;
			default:
				break;
		}
	}
}

