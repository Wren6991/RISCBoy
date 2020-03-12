#ifndef _PPU_H_
#define _PPU_H_

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#include "addressmap.h"
#include "hw/ppu_regs.h"

typedef volatile uint32_t io_rw_32;

#define N_PPU_BACKGROUNDS 2
#define N_PPU_SPRITES 8

struct ppu_hw {
	io_rw_32 csr;
	io_rw_32 dispsize;
	io_rw_32 cproc_pc;
	io_rw_32 lcd_pxfifo;
	io_rw_32 lcd_csr;
	io_rw_32 ints;
	io_rw_32 inte;
};

#define mm_ppu ((struct ppu_hw *const)PPU_BASE)

#define PPU_PIXMODE_ARGB1555 0u
#define PPU_PIXMODE_PAL8     1u
#define PPU_PIXMODE_PAL4     2u
#define PPU_PIXMODE_PAL1     3u

#define COLOUR_RED 0x7c00u
#define COLOUR_GREEN 0x3e0u
#define COLOUR_BLUE 0x1fu

// FIXME this shouldn't be here
volatile uint16_t *const PPU_PALETTE_RAM = (volatile uint16_t *const)(PPU_BASE + (1u << 11));

static inline void lcd_force_dc_cs(bool dc, bool cs)
{
	mm_ppu->lcd_csr = (mm_ppu->lcd_csr
		& ~(PPU_LCD_CSR_LCD_CS_MASK | PPU_LCD_CSR_LCD_DC_MASK))
		| (!!dc << PPU_LCD_CSR_LCD_DC_LSB)
		| (!!cs << PPU_LCD_CSR_LCD_CS_LSB);
}

static inline void lcd_set_shift_width(uint8_t width)
{
	if (width == 16)
		mm_ppu->lcd_csr |= PPU_LCD_CSR_LCD_SHIFTCNT_MASK;
	else
		mm_ppu->lcd_csr &= ~PPU_LCD_CSR_LCD_SHIFTCNT_MASK;
}

static inline void lcd_put_hword(uint16_t pixdata)
{
	while (mm_ppu->lcd_csr & PPU_LCD_CSR_PXFIFO_FULL_MASK)
		;
	mm_ppu->lcd_pxfifo = pixdata;
}

// Note the shifter always outputs MSB-first, and will simply be configured to get next data
// after shifting 8 MSBs out, so we left-justify the data
static inline void lcd_put_byte(uint8_t pixdata)
{
	while (mm_ppu->lcd_csr & PPU_LCD_CSR_PXFIFO_FULL_MASK)
		;
	mm_ppu->lcd_pxfifo = (uint16_t)pixdata << 8;
}

static inline void lcd_wait_idle()
{
	uint32_t csr;
	while (csr = mm_ppu->lcd_csr, csr & PPU_LCD_CSR_TX_BUSY_MASK || !(csr & PPU_LCD_CSR_PXFIFO_EMPTY_MASK))
		;
}

#endif // _PPU_H_
