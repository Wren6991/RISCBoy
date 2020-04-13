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

// PPU command processor control

static inline void cproc_put_pc(uint32_t pc)
{
	mm_ppu->cproc_pc = pc;
}

#define PPU_CPROC_SYNC  (0x0u << 28)
#define PPU_CPROC_CLIP  (0x1u << 28)
#define PPU_CPROC_FILL  (0x2u << 28)
#define PPU_CPROC_BLIT  (0x4u << 28)
#define PPU_CPROC_TILE  (0x5u << 28)
#define PPU_CPROC_ABLIT (0x6u << 28)
#define PPU_CPROC_ATILE (0x7u << 28)
#define PPU_CPROC_POKE  (0xeu << 28)
#define PPU_CPROC_JUMP  (0xfu << 28)

#define PPU_CPROC_BRANCH_ALWAYS 0x0

#define PPU_FORMAT_ARGB1555 0
#define PPU_FORMAT_PAL8 1
#define PPU_FORMAT_PAL4 2
#define PPU_FORMAT_PAL1

#define PPU_SIZE_8    0
#define PPU_SIZE_16   1
#define PPU_SIZE_32   2
#define PPU_SIZE_64   3
#define PPU_SIZE_128  4
#define PPU_SIZE_256  5
#define PPU_SIZE_512  6
#define PPU_SIZE_1024 7

#define PPU_ABLIT_FULLSIZE 0
#define PPU_ABLIT_HALFSIZE 1
static inline size_t cproc_sync(uint32_t *prog)
{
	*prog++ = PPU_CPROC_SYNC;
	return 1;
}

static inline size_t cproc_clip(uint32_t *prog, uint16_t x_start, uint16_t x_end)
{
	*prog++ = PPU_CPROC_CLIP | (x_start & 0x3ffu) | ((x_end & 0x3ffu) << 10);
	return 1;
}

static inline size_t cproc_fill(uint32_t *prog, uint8_t r, uint8_t g, uint8_t b)
{
	*prog++ = PPU_CPROC_FILL | ((r & 0x1fu) << 10) | ((g & 0x1fu) << 5) | (b & 0x1fu);
	return 1;
}

static inline size_t cproc_branch(uint32_t *prog, uint32_t target, uint32_t condition, uint16_t compval)
{
	*prog++ = PPU_CPROC_JUMP | ((condition & 0xfu) << 24) | (compval & 0x3ffu);
	*prog++ = target & 0xfffffffcu;
	return 2;
}

static inline size_t cproc_jump(uint32_t *prog, uintptr_t target)
{
	return cproc_branch(prog, target, PPU_CPROC_BRANCH_ALWAYS, 0);
}

static inline size_t cproc_blit(uint32_t *prog, uint16_t x, uint16_t y, uint8_t size, uint8_t poff, uint8_t fmt, const void *img)
{
	*prog++ = PPU_CPROC_BLIT | (x & 0x3ffu) | ((y & 0x3ffu) << 10) | ((size & 0x7u) << 25) | ((poff & 0x7u) << 22);
	*prog++ = ((uint32_t)img & 0xfffffffcu) | (fmt & 0x3u);
	return 2;
}

static inline size_t cproc_ablit(uint32_t *prog, uint16_t x, uint16_t y, uint8_t size, uint8_t poff,
	uint8_t fmt, uint8_t halfsize, const int32_t *aparam, const void *img)
{
	*prog++ = PPU_CPROC_ABLIT | (x & 0x3ffu) | ((y & 0x3ffu) << 10) | ((size & 0x7u) << 25) | ((poff & 0x7u) << 22) | (!!halfsize << 21);
	*prog++ = (((uint32_t)aparam[2] >> 10) & 0x0000ffffu) | (((uint32_t)aparam[5] << 6) & 0xffff0000u);
	*prog++ = (((uint32_t)aparam[0] >> 8 ) & 0x0000ffffu) | (((uint32_t)aparam[1] << 8) & 0xffff0000u);
	*prog++ = (((uint32_t)aparam[3] >> 8 ) & 0x0000ffffu) | (((uint32_t)aparam[4] << 8) & 0xffff0000u);
	*prog++ = ((uint32_t)img & 0xfffffffcu) | (fmt & 0x3u);
	return 5;
}

static inline size_t cproc_tile(uint32_t *prog, uint16_t x, uint16_t y, uint8_t pfsize, uint8_t poff,
	uint8_t fmt, uint8_t tilesize, const void *tileset, const void *tilemap)
{
	*prog++ = PPU_CPROC_TILE | (x & 0x3ffu) | ((y & 0x3ffu) << 10) | ((tilesize & 0x1u) << 25) | ((poff & 0x7u) << 22);
	*prog++ = ((uint32_t)tilemap & 0xfffffffcu) | (pfsize & 0x3u);
	*prog++ = ((uint32_t)tileset & 0xfffffffcu) | (fmt & 0x3u);
	return 3;
}

static inline size_t cproc_atile(uint32_t *prog, uint16_t x, uint16_t y, uint8_t pfsize, uint8_t poff,
	uint8_t fmt, uint8_t tilesize, const int32_t *aparam, const void *tileset, const void *tilemap)
{
	*prog++ = PPU_CPROC_ATILE | (x & 0x3ffu) | ((y & 0x3ffu) << 10) | ((tilesize & 0x1u) << 25) | ((poff & 0x7u) << 22);
	*prog++ = (((uint32_t)aparam[2] >> 10) & 0x0000ffffu) | (((uint32_t)aparam[5] << 6) & 0xffff0000u);
	*prog++ = (((uint32_t)aparam[0] >> 8 ) & 0x0000ffffu) | (((uint32_t)aparam[1] << 8) & 0xffff0000u);
	*prog++ = (((uint32_t)aparam[3] >> 8 ) & 0x0000ffffu) | (((uint32_t)aparam[4] << 8) & 0xffff0000u);
	*prog++ = ((uint32_t)tilemap & 0xfffffffcu) | (pfsize & 0x3u);
	*prog++ = ((uint32_t)tileset & 0xfffffffcu) | (fmt & 0x3u);
	return 6;
}
#endif // _PPU_H_
