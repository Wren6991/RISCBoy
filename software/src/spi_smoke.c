#include "delay.h"
#include "gpio.h"
#include "spi.h"
#include "tbman.h"

// Not self-checking.
// Just squirt some data out the SPI so it can be visually checked in waveform viewer.

const uint8_t data[] = {
	0x0,
	0x1,
	0xa5,
	0x5a
};

int main()
{
	*GPIO_FSEL0 |=
		GPIO_FSEL_MASK_PIN(PIN_FLASH_CS)   |
		GPIO_FSEL_MASK_PIN(PIN_FLASH_SCLK) |
		GPIO_FSEL_MASK_PIN(PIN_FLASH_MOSI);

	gpio_dir_pin(PIN_FLASH_MISO, 1); // avoid Z, else get Xs in the FIFO, which we try to drain.

	for (int div = 1; div <= 5; div += 4)
	{
		spi_clkdiv(div);
		for (int cpol_cpha = 0; cpol_cpha < 4; ++cpol_cpha)
		{
			spi_init(cpol_cpha >> 1, cpol_cpha & 0x1);
			spi_write(data, sizeof(data) / sizeof(*data));
			spi_wait_done();
			delay_us(10);
		}
		delay_us(100);
	}


	tbman_exit(0);
}
