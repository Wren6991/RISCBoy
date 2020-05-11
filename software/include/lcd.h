#ifndef _LCD_H_
#define _LCD_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "addressmap.h"
#include "hw/ppu_dispctrl_spi_regs.h"
#include "hw/ppu_dispctrl_dvi_regs.h"
#include "delay.h"
#include "ppu.h"

// Display controllers have a constant, read-only field in a fixed location,
// so software can determine which type of display interface is present in
// the current hardware build

typedef enum {
	DISPCTRL_TYPE_SPI = 0,
	DISPCTRL_TYPE_DVI = 1
} dispctrl_type_t;

static inline dispctrl_type_t get_dispctrl_type()
{
	return *(io_rw_32 *const)DISP_BASE >> 28;
}

// SPI hardware definitions

struct spi_lcd_hw {
	io_rw_32 csr;
	io_rw_32 dispsize;
	io_rw_32 pxfifo;
};

#define mm_spi_lcd ((struct spi_lcd_hw *const)DISP_BASE)

static inline void lcd_force_dc_cs(bool dc, bool cs)
{
	mm_spi_lcd->csr = (mm_spi_lcd->csr
		& ~(DISPCTRL_SPI_CSR_LCD_CS_MASK | DISPCTRL_SPI_CSR_LCD_DC_MASK))
		| (!!dc << DISPCTRL_SPI_CSR_LCD_DC_LSB)
		| (!!cs << DISPCTRL_SPI_CSR_LCD_CS_LSB);
}

static inline void lcd_set_shift_width(uint8_t width)
{
	if (width == 16)
		mm_spi_lcd->csr |= DISPCTRL_SPI_CSR_LCD_SHIFTCNT_MASK;
	else
		mm_spi_lcd->csr &= ~DISPCTRL_SPI_CSR_LCD_SHIFTCNT_MASK;
}

static inline void lcd_put_hword(uint16_t pixdata)
{
	while (mm_spi_lcd->csr & DISPCTRL_SPI_CSR_PXFIFO_FULL_MASK)
		;
	mm_spi_lcd->pxfifo = pixdata;
}

// Note the shifter always outputs MSB-first, and will simply be configured to get next data
// after shifting 8 MSBs out, so we left-justify the data
static inline void lcd_put_byte(uint8_t pixdata)
{
	while (mm_spi_lcd->csr & DISPCTRL_SPI_CSR_PXFIFO_FULL_MASK)
		;
	mm_spi_lcd->pxfifo = (uint16_t)pixdata << 8;
}

static inline void lcd_wait_idle()
{
	uint32_t csr;
	do {
		csr = mm_spi_lcd->csr;
	} while (csr & DISPCTRL_SPI_CSR_TX_BUSY_MASK || !(csr & DISPCTRL_SPI_CSR_PXFIFO_EMPTY_MASK));
}

static inline void lcd_set_disp_width(unsigned int width)
{
	mm_spi_lcd->dispsize = width - 1;
}

// Init sequences. Each record consists of:
// - A payload size (including the command byte)
// - A post-delay in units of 5 ms. 0 means no delay.
// - The command payload, including the initial command byte
// A payload size of 0 terminates the list.

static const uint8_t ili9341_init_seq[] = {
	2,  0,  0x36, 0xe8,             // For some reason the display likes to see a MADCTL *before* sw reset after a power cycle. I have no idea why

	1,  30, 0x01,                   // Software reset, 150 ms delay
	2,  24, 0xc1, 0x11,             // PWCTRL2, step up control (BT) = 1, -> VGL = -VCI * 3,  120 ms delay
	3,  0,  0xc5, 0x34, 0x3d,       // VMCTRL1, VCOMH = 4.0 V, VCOML = -0.975 V
	2,  0,  0xc7, 0xc0,             // VMCTRL2, override NVM-stored VCOM offset, and set our own offset of 0 points
	2,  0,  0x36, 0xe8,             // MADCTL, set MX+MY+MV (swap X/Y and flip both axes), set colour order to BGR
	2,  0,  0x3a, 0x55,             // COLMOD, 16 bpp pixel format for both RGB and MCU interfaces
	3,  0,  0xb1, 0x00, 0x18,       // FRMCTR1 frame rate control for normal display mode, no oscillator prescale, 79 Hz refresh
	4,  0,  0xb6, 0x08, 0x82, 0x27, // DFUNCTR: interval scan in non-display area (PTG). Crystal type normally white (REV). Set non-display scan interval (from PTG) to every 5th frame (ISC). Number of lines = 320 (NL). Do not configure external fosc divider (PCDIV).
	2,  0,  0x26, 0x01,             // GAMSET = 0x01, the only defined value for gamma curve selection
	16, 0,  0xe0, 0x0f, 0x31, 0x2b, // PGAMCTRL, positive gamma control, essentially magic as far as I'm concerned
	        0x0c, 0x0e, 0x08, 0x4e,
	        0xf1, 0x37, 0x07, 0x10,
	        0x03, 0x0e, 0x09, 0x00,
	16, 0,  0xe1, 0x00, 0x0e, 0x14, // NGAMCTRL, also magic moon runes
	        0x03, 0x11, 0x07, 0x31,
	        0xc1, 0x48, 0x08, 0x0f,
	        0x0c, 0x31, 0x36, 0x0f,
	1,  30, 0x11,                   // SLPOUT, exit sleep mode and wait 150 ms
	1,  30, 0x29,                   // DISPON, turn display on and wait 150 ms
	0                               // Terminate list
};

static const uint8_t st7789_init_seq[] = {
	1, 30,  0x01,                         // Software reset
	1, 100, 0x11,                         // Exit sleep mode
	2, 2,   0x3a, 0x55,                   // Set colour mode to 16 bit
	2, 0,   0x36, 0x00,                   // Set MADCTL: row then column, refresh is bottom to top ????
	5, 0,   0x2a, 0x00, 0x00, 0x00, 0xf0, // CASET: column addresses from 0 to 240 (f0)
	5, 0,   0x2b, 0x00, 0x00, 0x00, 0xf0, // RASET: row addresses from 0 to 240 (f0)
	1, 2,   0x21,                         // Inversion on, then 10 ms delay (supposedly a hack?)
	1, 2,   0x13,                         // Normal display on, then 10 ms delay
	1, 100, 0x29,                         // Main screen turn on, then wait 500 ms
	0                                     // Terminate list
};

static inline void lcd_write_cmd(const uint8_t *cmd, size_t count)
{
	lcd_wait_idle();
	lcd_set_shift_width(8);
	lcd_force_dc_cs(0, 0);
	lcd_put_byte(*cmd++);
	if (count >= 2)
	{
		lcd_force_dc_cs(1, 0);
		for (size_t i = 0; i < count - 1; ++i)
			lcd_put_byte(*cmd++);
	}
	lcd_wait_idle();
	lcd_force_dc_cs(1, 1);
	lcd_set_shift_width(16);
}

static inline void lcd_init(const uint8_t *init_seq)
{
	const uint8_t *cmd = init_seq;
	while (*cmd)
	{
		lcd_write_cmd(cmd + 2, *cmd);
		delay_ms(*(cmd + 1) * 5);
		cmd += *cmd + 2;
	}
}

static inline void st7789_start_pixels()
{
	uint8_t cmd = 0x2c;
	lcd_write_cmd(&cmd, 1);
	lcd_force_dc_cs(1, 0);
}

// DVI hardware definitions

struct dvi_lcd_hw {
	io_rw_32 csr;
};

#define mm_dvi_lcd ((struct dvi_lcd_hw *const)DISP_BASE)

#endif
