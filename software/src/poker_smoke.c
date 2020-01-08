#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define CLK_SYS_MHZ 36
#include "ppu.h"
#include "lcd.h"
#include "tbman.h"

static uint32_t poker_program[64];

int main()
{
	if (!tbman_running_in_sim())
		lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = (319 << PPU_DISPSIZE_W_LSB) | (239 << PPU_DISPSIZE_H_LSB);


	uint32_t *iptr = poker_program;
	iptr = poker_wait(iptr, 0, -1);
	uint32_t *entry_point = iptr;
	iptr = poker_poke(iptr, offsetof(struct ppu_hw, default_bg_colour), COLOUR_RED);
	iptr = poker_wait(iptr, 120, -1);
	iptr = poker_poke(iptr, offsetof(struct ppu_hw, default_bg_colour), COLOUR_RED | COLOUR_GREEN);
	iptr = poker_wait(iptr, 0, -1);
	iptr = poker_poke(iptr, offsetof(struct ppu_hw, default_bg_colour), COLOUR_GREEN);
	iptr = poker_wait(iptr, 120, -1);
	iptr = poker_poke(iptr, offsetof(struct ppu_hw, default_bg_colour), COLOUR_GREEN | COLOUR_BLUE);
	iptr = poker_wait(iptr, 0, -1);
	iptr = poker_poke(iptr, offsetof(struct ppu_hw, default_bg_colour), COLOUR_BLUE);
	iptr = poker_wait(iptr, 120, -1);
	iptr = poker_poke(iptr, offsetof(struct ppu_hw, default_bg_colour), COLOUR_BLUE | COLOUR_RED);
	iptr = poker_jump(iptr, -1, -1, (intptr_t)poker_program);

	mm_ppu->poker_pc = (uint32_t)entry_point;
	mm_ppu->csr |= PPU_CSR_POKER_EN_MASK;

	if (tbman_running_in_sim())
	{
		lcd_force_dc_cs(1, 1);
		st7789_start_pixels();
		for (int i = 0; i < 6; ++i)
		{
			mm_ppu->csr |= PPU_CSR_HALT_HSYNC_MASK | PPU_CSR_RUN_MASK;
			while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
				;
		}
		lcd_wait_idle();
		tbman_exit(0);
	}
	else
	{
		while (true)
		{
			lcd_wait_idle();
			lcd_force_dc_cs(1, 1);
			st7789_start_pixels();

			mm_ppu->csr |= PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
			while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
				;
		}
	}

	return 0;
}

