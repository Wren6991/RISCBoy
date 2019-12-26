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

	*PPU_CSR = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
	while (*PPU_CSR & PPU_CSR_RUNNING_MASK)
		;
}

int main()
{
	lcd_init(ili9341_init_seq);

	*PPU_DISPSIZE = (319 >> PPU_DISPSIZE_W_LSB) | (239 << PPU_DISPSIZE_H_LSB);
	*PPU_DEFAULT_BG_COLOUR = 0x2e71; // #5e978c

	*PPU_BG0_TSBASE = (uint32_t)tileset;
	*PPU_BG0_TMBASE = (uint32_t)tilemap_foreground;
	*PPU_BG0_CSR =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(9u << PPU_BG0_CSR_PFWIDTH_LSB) | // 1024 px wide
		(7u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 256 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(1u << PPU_BG0_CSR_TRANSPARENCY_LSB) |
		(PPU_PIXMODE_ARGB1555 << PPU_BG0_CSR_PIXMODE_LSB);

	*PPU_BG1_TSBASE = (uint32_t)tileset;
	*PPU_BG1_TMBASE = (uint32_t)tilemap_background;
	*PPU_BG1_CSR =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(8u << PPU_BG0_CSR_PFWIDTH_LSB) | // 512 px wide
		(7u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 256 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(1u << PPU_BG0_CSR_TRANSPARENCY_LSB) |
		(PPU_PIXMODE_ARGB1555 << PPU_BG0_CSR_PIXMODE_LSB);

	for (int i = 0; i < PALETTE_N_COLOURS; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)tileset_palette)[i];

	while (1)
	{
		render_frame();
		*PPU_BG0_SCROLL += 2;
		*PPU_BG1_SCROLL += 1;
	}
}
