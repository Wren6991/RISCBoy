#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "lcd.h"
#include "gpio.h"

#include "tileset.h"
#include "tileset_palette.h"
#include "tilemap_background.h"
#include "tilemap_foreground.h"

void render_frame()
{
	lcd_wait_idle();
	lcd_force_dc_cs(1, 1);
	st7789_start_pixels();

	mm_ppu->csr = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

int main()
{
	lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = (319 >> PPU_DISPSIZE_W_LSB) | (239 << PPU_DISPSIZE_H_LSB);
	mm_ppu->default_bg_colour = 0x2e71; // #5e978c

	mm_ppu->bg[0].tsbase = (uint32_t)tileset;
	mm_ppu->bg[0].tmbase = (uint32_t)tilemap_background;
	mm_ppu->bg[0].csr =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(8u << PPU_BG0_CSR_PFWIDTH_LSB) | // 512 px wide
		(7u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 256 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(1u << PPU_BG0_CSR_TRANSPARENCY_LSB) |
		(PPU_PIXMODE_ARGB1555 << PPU_BG0_CSR_PIXMODE_LSB);

	mm_ppu->bg[1].tsbase = (uint32_t)tileset;
	mm_ppu->bg[1].tmbase = (uint32_t)tilemap_foreground;
	mm_ppu->bg[1].csr =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(9u << PPU_BG0_CSR_PFWIDTH_LSB) | // 1024 px wide
		(7u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 256 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(1u << PPU_BG0_CSR_TRANSPARENCY_LSB) |
		(PPU_PIXMODE_ARGB1555 << PPU_BG0_CSR_PIXMODE_LSB);

	for (int i = 0; i < PALETTE_N_COLOURS; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)tileset_palette)[i];

	unsigned scroll_fg = 0;
	unsigned scroll_bg = 0;
	while (1)
	{
		render_frame();
		scroll_fg += 2;
		scroll_bg += 1;
		mm_ppu->bg[0].scroll = scroll_bg;
		mm_ppu->bg[1].scroll = scroll_fg;
	}
}
