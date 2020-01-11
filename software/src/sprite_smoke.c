#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "lcd.h"
#include "tbman.h"
#include "gpio.h"
#include "pwm.h"

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

uint16_t __attribute__ ((section (".noload"), aligned (512))) sprite[256];

static inline void render_scanline()
{
	mm_ppu->csr = PPU_CSR_HALT_HSYNC_MASK | PPU_CSR_RUN_MASK;
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

static inline void render_frame()
{
	mm_ppu->csr = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}
int main()
{
	if (!tbman_running_in_sim())
		lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = ((SCREEN_WIDTH - 1) << PPU_DISPSIZE_W_LSB) | ((SCREEN_HEIGHT - 1) << PPU_DISPSIZE_H_LSB);
	mm_ppu->default_bg_colour = 0u;

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
		for (unsigned i = 0; i < 16; ++i)
		{
			mm_ppu->sp[0] = i | (16 << PPU_SP0_Y_LSB);
			render_scanline();
		}
		for (unsigned i = 0; i <= 16; ++i)
		{
			mm_ppu->sp[0] = (SCREEN_WIDTH + i) | ((i + 32) << PPU_SP0_Y_LSB);
			render_scanline();
		}
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
