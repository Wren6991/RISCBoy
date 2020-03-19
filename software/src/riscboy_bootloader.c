#ifndef CLK_SYS_MHZ
#define CLK_SYS_MHZ 36
#endif

#include "delay.h"
#include "gpio.h"
#include "spi.h"
#include "tbman.h"
#include "uart.h"

#ifndef UART_BAUD
#define UART_BAUD (3 * 1000 * 1000)
#endif

#define SPI_CLK_MHZ 6
#define HOST_TIMEOUT_MS 100

#ifndef STAGE2_OFFS
#define STAGE2_OFFS 0x30000
#endif

#ifdef FORCE_SRAM0_SIZE
#undef SRAM0_SIZE
#define SRAM0_SIZE FORCE_SRAM0_SIZE
#endif

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

#define LOAD_MEM     'l' // These two are basically a hack while my flash is dead
#define EXEC_MEM     'x' // but they give a nice fast build-program-run cycle

#define TEST_MEM     'm'

#define ACK          ':' // a toggle-y sequence

const char *stage2_magic = "RISCBoy";
#define xstr(s) str(s)
#define str(s) #s

uint8_t cmdbuf[1 + ADDRSIZE + PAGESIZE];
uint8_t *pagebuf = cmdbuf + 1 + ADDRSIZE;

int test_mem();
void run_2nd_stage();
void run_flash_shell();

int main()
{
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);

	gpio_fsel(PIN_LED, 0);
	gpio_dir_pin(PIN_LED, 1);

	gpio_fsel(PIN_UART_TX, 1);
	gpio_fsel(PIN_UART_RX, 1);
	gpio_fsel(PIN_UART_CTS, 1);
	gpio_fsel(PIN_UART_RTS, 1);
	gpio_fsel(PIN_FLASH_CS, 1);
	gpio_fsel(PIN_FLASH_SCLK, 1);
	gpio_fsel(PIN_FLASH_MOSI, 1);
	gpio_fsel(PIN_FLASH_MISO, 1);

	uart_puts(splash);
	if (*TBMAN_STUB & TBMAN_STUB_SPI_MASK)
	{
		uart_puts("SPI hardware not present. Skipping flash load.");
		test_mem();
		run_flash_shell();
	}
	spi_init(false, false);
	spi_clkdiv(CLK_SYS_MHZ / (2 * SPI_CLK_MHZ));

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

	if (t < HOST_TIMEOUT_MS)
	{
		uart_put(ACK);
		run_flash_shell();
	}
	if (test_mem())
	{
		uart_puts("Memtest failed. Falling back to flash shell.\n");
		run_flash_shell();
	}
	run_2nd_stage();
}

void run_2nd_stage()
{
	uart_puts("Checking for stage 2: flash " xstr(STAGE2_OFFS) "\n");
	uint8_t cmdbuf[16];
	cmdbuf[0] = 0x03;
	cmdbuf[1] = 0xff & (STAGE2_OFFS >> 16);
	cmdbuf[2] = 0xff & (STAGE2_OFFS >> 8);
	cmdbuf[3] = 0xff & (STAGE2_OFFS >> 0);
	spi_write_read(cmdbuf, cmdbuf, 16);
	bool mismatch = false;
	const char *expect = stage2_magic, *actual = (char *)&cmdbuf[4];
	while (*expect)
	{
		if (*expect++ != *actual++)
		{
			mismatch = true;
			break;
		}
	}
	if (mismatch)
	{
		uart_puts("Stage 2 not found. Falling back to flash shell.\n");
		run_flash_shell();
	}
	uint32_t size = cmdbuf[12] | (cmdbuf[13] << 8) | (cmdbuf[14] << 16) | (cmdbuf[15] << 24);
	uart_puts("Found stage 2 (");
	uart_putint(size);
	uart_puts(" bytes)\n");

	cmdbuf[0] = 0x03;
	cmdbuf[1] = 0xff & ((STAGE2_OFFS + 12) >> 16);
	cmdbuf[2] = 0xff & ((STAGE2_OFFS + 12) >> 8);
	cmdbuf[3] = 0xff & ((STAGE2_OFFS + 12) >> 0);

	// Force CS low; we need to clear FIFO then continue reading!
	*SPI_CSR &= ~(SPI_CSR_CSAUTO_MASK | SPI_CSR_CS_MASK);

	uint8_t *mem = (uint8_t *)SRAM0_BASE;
	// Jump to reset handler, which is after vector table (TODO handle variable table sizes)
	void (*stage2)(void) = (void(*)(void))(SRAM0_BASE + 0xc0);

	spi_write_read(cmdbuf, cmdbuf, 4);
	spi_write_read(mem, mem, size);

	uart_puts("Dump before jump:\n");
	for (int i = 0; i < 10; ++i)
	{
		uart_putint(((volatile uint32_t *)mem)[i]);
		uart_puts("\n");
	}

	stage2();
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
	for (size_t i = 0; i < len; ++i)
		sum = (sum + (sum << 3) + 1) ^ (data[i] + (data[i] << 5) + (data[i] << 9));
	return sum;
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
			case LOAD_MEM:
			{
				// Password on top nibble to avoid some nasty accidents
				if (addr >> 20 != 0xb)
					break;
				addr &= SRAM0_SIZE - 1;
				uint32_t len = 0;
				for (int i = 0; i < 3; ++i)
					len = (len << 8) | uart_get();
				if (addr + len > SRAM0_SIZE)
					break;
				uint8_t *p = (uint8_t *)(SRAM0_BASE + addr);
				uart_put(ACK);
				while (len--)
					*p++ = uart_get();
				uart_put(ACK);
				break;
			}
			case EXEC_MEM:
			{
				if (addr >> 20 != 0xb)
					break;
				uart_put(ACK);
				// Scary but true
				((void (*)())(SRAM0_BASE + (addr & SRAM0_SIZE - 1)))();
				break;
			}
			case TEST_MEM:
				uart_put(ACK);
				test_mem();
				uart_puts("::::");
				break;
			default:
				break;
		}
	}
}

uint32_t rand_state = 0xf00fa55a;
static inline uint32_t randu()
{
	// Cheesy implementation of the LCG used in glibc.
	// Faster than software multiply routine.
	// FIXME just use a multiply once we have ISA support
	rand_state =
		(rand_state <<  0) +
		(rand_state <<  2) +
		(rand_state <<  3) +
		(rand_state <<  5) +
		(rand_state <<  6) +
		(rand_state <<  9) +
		(rand_state << 10) +
		(rand_state << 11) +
		(rand_state << 14) +
		(rand_state << 17) +
		(rand_state << 18) +
		(rand_state << 22) +
		(rand_state << 23) +
		(rand_state << 24) +
		(rand_state << 30) +
		12345;
	return rand_state;
}

int test_mem()
{
	volatile uint8_t *mem8 = (volatile uint8_t*)SRAM0_BASE;
	volatile uint32_t *mem32 = (volatile uint32_t*)SRAM0_BASE;
	const size_t size = SRAM0_SIZE;

	int fail_count = 0;
	uint32_t rand_state_saved;

	uart_puts("\nTesting 0x");
	uart_putint((uint32_t)&mem8[0]);
	uart_puts(" to 0x");
	uart_putint((uint32_t)&mem8[size]);
	uart_puts("\n");

	// Byte memtest takes a second or two on every boot. It is worth running
	// to verify timing/connection of byte strobes, but needn't run every time.
#ifdef MEMTEST_BYTES
	uart_puts("Zero bytes...\n");

	for (size_t i = 0; i < size; ++i)
		mem8[i] = 0;

	for (size_t i = 0; i < size; ++i)
	{
		if (mem8[i])
		{
			uart_puts("FAIL @");
			uart_putint((uint32_t)&mem8[i]);
			uart_puts("\n");
			++fail_count;
		}
		if (fail_count > 20)
		{
			uart_puts("Too many failures.\n");
			break;
		}
	}
	if (fail_count)
		return -1;
	else
		uart_puts("OK.\n");

	uart_puts("Random bytes...\n");
	rand_state_saved = rand_state;
	for (size_t i = 0; i < size; ++i)
		mem8[i] = randu() >> 20;

	fail_count = 0;
	rand_state = rand_state_saved;

	for (size_t i = 0; i < size; ++i)
	{
		uint8_t expect = randu() >> 20;
		uint8_t actual = mem8[i];
		if (expect != actual)
		{
			++fail_count;
			uart_puts("FAIL @");
			uart_putint((uint32_t)&mem8[i]);
			uart_puts(": expected ");
			uart_putbyte(expect);
			uart_puts(", got ");
			uart_putbyte(actual);
			uart_puts("\n");
		}
		if (fail_count > 20)
		{
			uart_puts("Too many failures.\n");
			break;
		}
	}

	if (fail_count)
		return -1;
	else
		uart_puts("OK.\n");
#endif

	uart_puts("Zero words...\n");
	for (size_t i = 0; i < size / 4; ++i)
		mem32[i] = 0;

	fail_count = 0;
	for (size_t i = 0; i < size / 4; ++i)
	{
		uint32_t actual = mem32[i];
		if (actual)
		{
			uart_puts("FAIL @");
			uart_putint((uint32_t)&mem32[i]);
			uart_puts(": got ");
			uart_putint(actual);
			uart_puts("\n");
			++fail_count;
		}
		if (fail_count > 20)
		{
			uart_puts("Too many failures.\n");
			break;
		}
	}

	if (fail_count)
		return -1;
	else
		uart_puts("OK.\n");

	uart_puts("Random words...\n");
	rand_state_saved = rand_state;
	for (size_t i = 0; i < size / 4; ++i)
		mem32[i] = randu();

	fail_count = 0;
	rand_state = rand_state_saved;

	for (size_t i = 0; i < size / 4; ++i)
	{
		uint32_t expect = randu();
		uint32_t actual = mem32[i];
		if (expect != actual)
		{
			++fail_count;
			uart_puts("FAIL @");
			uart_putint((uint32_t)&mem32[i]);
			uart_puts(": expected ");
			uart_putint(expect);
			uart_puts(", got ");
			uart_putint(actual);
			uart_puts("\n");
		}
		if (fail_count > 20)
		{
			uart_puts("Too many failures.\n");
			break;
		}
	}

	if (fail_count)
		return -1;
	else
		uart_puts("OK.\n");
	return 0;
}
