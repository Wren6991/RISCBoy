#ifndef _PPU_H_
#define _PPU_H_

#include <stdbool.h>
#include <stdint.h>

#include "addressmap.h"
#include "hw/ppu_regs.h"

typedef volatile uint32_t io_rw_32;

#define N_PPU_BACKGROUNDS 2
#define N_PPU_SPRITES 8

struct ppu_hw {
	io_rw_32 csr;
	io_rw_32 dispsize;
	io_rw_32 default_bg_colour;
	io_rw_32 beam;
	io_rw_32 poker_pc;
	io_rw_32 poker_scratch;
	struct ppu_bg_hw {
		io_rw_32 csr;
		io_rw_32 scroll;
		io_rw_32 tsbase;
		io_rw_32 tmbase;
	} bg[N_PPU_BACKGROUNDS];
	io_rw_32 sp_csr;
	io_rw_32 sp_tsbase;
	struct ppu_sp_hw {
		io_rw_32 csr;
		io_rw_32 pos;
	} sp[N_PPU_SPRITES];
	io_rw_32 pxfifo;
	io_rw_32 lcd_csr;
};

#define mm_ppu ((struct ppu_hw *const)PPU_BASE)

// TODO get rid of old-style definitions:
DECL_REG(PPU_BASE + PPU_CSR_OFFS, PPU_CSR);
DECL_REG(PPU_BASE + PPU_DISPSIZE_OFFS	, PPU_DISPSIZE);
DECL_REG(PPU_BASE + PPU_DEFAULT_BG_COLOUR_OFFS, PPU_DEFAULT_BG_COLOUR);
DECL_REG(PPU_BASE + PPU_BEAM_OFFS, PPU_BEAM);

DECL_REG(PPU_BASE + PPU_BG0_CSR_OFFS, PPU_BG0_CSR);
DECL_REG(PPU_BASE + PPU_BG0_SCROLL_OFFS, PPU_BG0_SCROLL);
DECL_REG(PPU_BASE + PPU_BG0_TSBASE_OFFS, PPU_BG0_TSBASE);
DECL_REG(PPU_BASE + PPU_BG0_TMBASE_OFFS, PPU_BG0_TMBASE);
DECL_REG(PPU_BASE + PPU_BG1_CSR_OFFS, PPU_BG1_CSR);
DECL_REG(PPU_BASE + PPU_BG1_SCROLL_OFFS, PPU_BG1_SCROLL);
DECL_REG(PPU_BASE + PPU_BG1_TSBASE_OFFS, PPU_BG1_TSBASE);
DECL_REG(PPU_BASE + PPU_BG1_TMBASE_OFFS, PPU_BG1_TMBASE);

DECL_REG(PPU_BASE + PPU_SP_CSR_OFFS, PPU_SP_CSR);
DECL_REG(PPU_BASE + PPU_SP_TSBASE_OFFS, PPU_SP_TMBASE);
DECL_REG(PPU_BASE + PPU_SP0_CSR_OFFS, PPU_SP0_CSR);
DECL_REG(PPU_BASE + PPU_SP0_POS_OFFS, PPU_SP0_POS);

DECL_REG(PPU_BASE + PPU_LCD_PXFIFO_OFFS, PPU_LCD_PXFIFO);
DECL_REG(PPU_BASE + PPU_LCD_CSR_OFFS, PPU_LCD_CSR);

#define PPU_PIXMODE_ARGB1555 0u
#define PPU_PIXMODE_ARGB1232 2u
#define PPU_PIXMODE_PAL8     4u
#define PPU_PIXMODE_PAL4     5u
#define PPU_PIXMODE_PAL2     6u
#define PPU_PIXMODE_PAL1     7u

#define COLOUR_RED 0x7c00u
#define COLOUR_GREEN 0x3e0u
#define COLOUR_BLUE 0x1fu

// FIXME this shouldn't be here
volatile uint16_t *const PPU_PALETTE_RAM = (volatile uint16_t *const)(PPU_BASE + (1u << 11));

static inline void lcd_force_dc_cs(bool dc, bool cs)
{
	*PPU_LCD_CSR = (*PPU_LCD_CSR
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

#define POKER_INSTR_WAIT (0x00u << 24)
#define POKER_INSTR_JUMP (0x01u << 24)
#define POKER_INSTR_POKE (0x02u << 24)

static inline uint32_t* poker_wait(uint32_t *iptr, uint32_t x_match, uint32_t y_match)
{
	*iptr++ = POKER_INSTR_WAIT | ((x_match & 0xfffu) << 12) | (y_match & 0xfffu);
	return iptr;
}

static inline uint32_t* poker_jump(uint32_t *iptr, uint32_t x_match, uint32_t y_match, intptr_t target)
{
	*iptr++ = POKER_INSTR_JUMP | ((x_match & 0xfffu) << 12) | (y_match & 0xfffu);
	*iptr++ = target;
	return iptr;
}

static inline uint32_t* poker_poke(uint32_t *iptr, intptr_t addr, uint32_t data)
{
	*iptr++ = POKER_INSTR_POKE | (addr & 0xfffu);
	*iptr++ = data;
	return iptr;
}

#endif // _PPU_H_
