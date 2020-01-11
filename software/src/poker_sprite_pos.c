#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "lcd.h"
#include "tbman.h"
#include "gpio.h"
#include "pwm.h"

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

uint16_t __attribute__ ((section (".noload"), aligned (512))) sprite[256];
uint32_t __attribute__ ((section (".noload"))) poker_prog[256];

static inline void render_scanline()
{
	mm_ppu->csr |= PPU_CSR_HALT_HSYNC_MASK | PPU_CSR_RUN_MASK;
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

static inline void render_frame()
{
	mm_ppu->csr &= ~PPU_CSR_HALT_HSYNC_MASK;
	mm_ppu->csr |= PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

int main()
{
	if (!tbman_running_in_sim())
		lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = ((SCREEN_WIDTH - 1) << PPU_DISPSIZE_W_LSB) | ((SCREEN_HEIGHT - 1) << PPU_DISPSIZE_H_LSB);
	mm_ppu->default_bg_colour = COLOUR_BLUE;//(COLOUR_BLUE >> 1) & COLOUR_BLUE | (COLOUR_GREEN >> 1) & COLOUR_GREEN | (COLOUR_RED >> 1) & COLOUR_RED;

	if (tbman_running_in_sim())
		for (unsigned int i = 0; i < 256; ++i)
			sprite[i] = i | 0x8000u; // alpha!
	else
		// Nicer pattern to look at
		for (unsigned int i = 0; i < 256; ++i)
			sprite[i] =  (i << 1) & COLOUR_BLUE | (i << 2) & COLOUR_GREEN | COLOUR_RED | 0x8000u;

	mm_ppu->sp_csr =
		(PPU_PIXMODE_ARGB1555 << PPU_SP_CSR_PIXMODE_LSB) |
		(1u << PPU_SP_CSR_TILESIZE_LSB);
	mm_ppu->sp_tsbase = (uint32_t)sprite;
	mm_ppu->sp[0] = 0;

	while (true)
	{
		lcd_wait_idle();
		lcd_force_dc_cs(1, 1);
		st7789_start_pixels();
		
		// Horizontal stretch program
		uint32_t *iptr = poker_prog;
		for (unsigned i = 0; i < 16; ++i)
		{
			iptr = poker_wait(iptr, 2 * i + 1, -1);
			iptr = poker_poke(iptr, offsetof(struct ppu_hw, sp[0]), (16u << PPU_SP0_Y_LSB) | (16u + i + 1u));
		}
		iptr = poker_wait(iptr, 0, -1);
		uint32_t *entry_point = iptr;
		iptr = poker_poke(iptr, offsetof(struct ppu_hw, sp[0]), (16u << PPU_SP0_Y_LSB) | 16u);
		iptr = poker_bceq(iptr, -1, -1, (intptr_t)poker_prog);

		mm_ppu->poker_pc = (intptr_t)entry_point;
		mm_ppu->csr |= PPU_CSR_POKER_EN_MASK;
		for (int i = 0; i < 16; ++i)
			render_scanline();
		mm_ppu->csr &= ~PPU_CSR_POKER_EN_MASK;

		// Vertical shear program
		iptr = poker_prog;
		for (unsigned int i = 0; i < 16; ++i)
		{
			iptr = poker_wait(iptr, 32 + i + 1, -1);
			iptr = poker_poke(iptr, offsetof(struct ppu_hw, sp[0]), ((32u + i + 1) << PPU_SP0_Y_LSB) | 48u);
		}
		iptr = poker_wait(iptr, 0, -1);
		entry_point = iptr;
		iptr = poker_poke(iptr, offsetof(struct ppu_hw, sp[0]), (32u << PPU_SP0_Y_LSB) | 48u);
		iptr = poker_jump(iptr, (intptr_t)poker_prog);

		mm_ppu->poker_pc = (intptr_t)entry_point;
		mm_ppu->csr |= PPU_CSR_POKER_EN_MASK;
		for (int i = 0; i < 32; ++i)
			render_scanline();
		mm_ppu->csr &= ~PPU_CSR_POKER_EN_MASK;

		if (tbman_running_in_sim())
		{
			lcd_wait_idle();
			tbman_exit(0);
		}
		else
		{
			mm_ppu->sp[0] = (SCREEN_WIDTH / 2 + 4) | ((SCREEN_HEIGHT / 2 + 4) << PPU_SP0_Y_LSB);
			render_frame();		
		}
	}

}
