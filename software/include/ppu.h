#ifndef _PPU_H_
#define _PPU_H_

#include <stdbool.h>
#include <stdint.h>

#include "addressmap.h"
#include "hw/ppu_regs.h"

DECL_REG(PPU_BASE + PPU_CSR_OFFS, PPU_CSR);
DECL_REG(PPU_BASE + PPU_DISPSIZE_OFFS, PPU_DISPSIZE);
DECL_REG(PPU_BASE + PPU_DEFAULT_BG_COLOUR_OFFS, PPU_DEFAULT_BG_COLOUR);
DECL_REG(PPU_BASE + PPU_BEAM_OFFS, PPU_BEAM);
DECL_REG(PPU_BASE + PPU_BG0_CSR_OFFS, PPU_BG0_CSR);
DECL_REG(PPU_BASE + PPU_BG0_SCROLL_OFFS, PPU_BG0_SCROLL);
DECL_REG(PPU_BASE + PPU_BG0_TSBASE_OFFS, PPU_BG0_TSBASE);
DECL_REG(PPU_BASE + PPU_BG0_TMBASE_OFFS, PPU_BG0_TMBASE);
DECL_REG(PPU_BASE + PPU_LCD_PXFIFO_OFFS, PPU_LCD_PXFIFO);
DECL_REG(PPU_BASE + PPU_LCD_CSR_OFFS, PPU_LCD_CSR);

static inline void lcd_force_dc_cs(bool dc, bool cs)
{
	*PPU_LCD_CSR = (*PPU_LCD_CSR
		& ~(PPU_LCD_CSR_LCD_CS_MASK | PPU_LCD_CSR_LCD_DC_MASK))
		| (!!dc << PPU_LCD_CSR_LCD_DC_LSB)
		| (!!cs << PPU_LCD_CSR_LCD_CS_LSB);
}

static inline void lcd_set_shift_width(uint8_t width)
{
	*PPU_LCD_CSR = *PPU_LCD_CSR
		& ~PPU_LCD_CSR_LCD_SHIFTCNT_MASK
		| ((width << PPU_LCD_CSR_LCD_SHIFTCNT_LSB) & PPU_LCD_CSR_LCD_SHIFTCNT_MASK);
}

static inline void lcd_put_hword(uint16_t pixdata)
{
	while (*PPU_LCD_CSR & PPU_LCD_CSR_PXFIFO_FULL_MASK)
		;
	*PPU_LCD_PXFIFO = pixdata;
}

// Note the shifter always outputs MSB-first, and will simply be configured to get next data
// after shifting 8 MSBs out, so we left-justify the data
static inline void lcd_put_byte(uint8_t pixdata)
{
	while (*PPU_LCD_CSR & PPU_LCD_CSR_PXFIFO_FULL_MASK)
		;
	*PPU_LCD_PXFIFO = (uint16_t)pixdata << 8;
}

static inline void lcd_wait_idle()
{
	uint32_t csr;
	while (csr = *PPU_LCD_CSR, csr & PPU_LCD_CSR_TX_BUSY_MASK || !(csr & PPU_LCD_CSR_PXFIFO_EMPTY_MASK))
		;
}

#endif // _PPU_H_
