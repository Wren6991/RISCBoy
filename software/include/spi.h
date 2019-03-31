#ifndef _SPI_H_
#define _SPI_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "addressmap.h"
#include "hw/spi_regs.h"

DECL_REG(SPI_BASE + SPI_CSR_OFFS, SPI_CSR);
DECL_REG(SPI_BASE + SPI_DIV_OFFS, SPI_DIV);
DECL_REG(SPI_BASE + SPI_FSTAT_OFFS, SPI_FSTAT);
DECL_REG(SPI_BASE + SPI_TX_OFFS, SPI_TX);
DECL_REG(SPI_BASE + SPI_RX_OFFS, SPI_RX);

static inline void spi_init(bool cpol, bool cpha)
{
	// TODO: need to drain TX FIFO etc
	*SPI_CSR = (SPI_CSR_CSAUTO_MASK | SPI_CSR_READ_EN_MASK) |
		(!!cpol << SPI_CSR_CPOL_LSB) |
		(!!cpha << SPI_CSR_CPHA_LSB);

	while (!(*SPI_FSTAT & SPI_FSTAT_RXEMPTY_MASK))
		(void)*SPI_RX;

	*SPI_FSTAT = SPI_FSTAT_TXOVER_MASK | SPI_FSTAT_RXOVER_MASK | SPI_FSTAT_RXUNDER_MASK;
}

static inline void spi_write(const uint8_t *data, size_t len)
{
	for(; len > 0; --len)
	{
		while (*SPI_FSTAT & SPI_FSTAT_TXFULL_MASK)
			;
		*SPI_TX = *data++;
	}
}

static inline void _spi_get_if_nonempty(uint8_t **rx)
{
	if (!(*SPI_FSTAT & SPI_FSTAT_RXEMPTY_MASK))
		*(*rx)++ = *SPI_RX;
}

static inline void spi_write_read(const uint8_t *tx, uint8_t *rx, size_t len)
{
	while (!(*SPI_FSTAT & SPI_FSTAT_RXEMPTY_MASK))
		(void)*SPI_RX;

	for (; len > 0; --len)
	{
		_spi_get_if_nonempty(&rx);
		while (*SPI_FSTAT & SPI_FSTAT_TXFULL_MASK)
			;
		*SPI_TX = *tx++;
	}
	while (*SPI_CSR & SPI_CSR_BUSY_MASK)
		_spi_get_if_nonempty(&rx);
	_spi_get_if_nonempty(&rx);
}

static inline void spi_wait_done()
{
	while (*SPI_CSR & SPI_CSR_BUSY_MASK)
		;
}

static inline void spi_clkdiv(int div)
{
	*SPI_DIV = div;
}

#endif // _SPI_H_