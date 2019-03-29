#include <stdint.h>

#include "delay.h"
#include "gpio.h"
#include "spi.h"
#include "tbman.h"

// Use SPI's internal loopback setting to perform quick sanity check
// for various CPOL, CPHA and baud rate

#define BUFSIZE 4
static const uint8_t tx[BUFSIZE] = {
	0,
	1,
	0xa5,
	0x5a
};

int main()
{
	uint8_t rx[BUFSIZE];

	*GPIO_FSEL0 |=
		GPIO_FSEL_MASK_PIN(PIN_FLASH_CS)   |
		GPIO_FSEL_MASK_PIN(PIN_FLASH_SCLK) |
		GPIO_FSEL_MASK_PIN(PIN_FLASH_MOSI);

	gpio_dir_pin(PIN_FLASH_MISO, 1); // avoid Z, else get Xs in the FIFO, which we try to drain.

	for (int div = 1; div <= 10; div += 9)
	{
		spi_clkdiv(div);
		for (int cpol_cpha = 0; cpol_cpha < 4; ++cpol_cpha)
		{
			for (int i = 0; i < BUFSIZE; ++i)
				rx[i] = 0xff;
			spi_init(cpol_cpha >> 1, cpol_cpha & 0x1);
			*SPI_CSR |= SPI_CSR_LOOPBACK_MASK;
			spi_write_read(tx, rx, BUFSIZE);
			for (int i = 0; i < BUFSIZE; ++i)
				if (tx[i] != rx[i])
					tbman_exit(-1);
		}
		delay_us(100);
	}

	tbman_puts("All tests passed\n");
	tbman_exit(0);
}
