#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "lcd.h"
#include "tbman.h"
#include "gpio.h"
#include "pwm.h"

uint16_t __attribute__ ((aligned (32768))) tileset[16384];
uint8_t __attribute__ ((aligned (256))) tilemap[256];

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
	if (!tbman_running_in_sim())
		lcd_init(st7789_init_seq);

	*PPU_DISPSIZE = (239 << PPU_DISPSIZE_W_LSB) | (239 << PPU_DISPSIZE_H_LSB);
	*PPU_DEFAULT_BG_COLOUR = 0x7c01fu; // magenta

	for (int i = 0; i < 256; ++i)
		tilemap[i] = i;
	for (int i = 0; i < 16384; ++i)
		tileset[i] = i;

	*PPU_BG0_TMBASE = (uint32_t)tilemap;
	*PPU_BG0_TSBASE = (uint32_t)tileset;
	*PPU_BG0_CSR =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(7u << PPU_BG0_CSR_PFWIDTH_LSB) | // 256 px wide
		(7u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 256 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(1u << PPU_BG0_CSR_FLUSH_LSB);

	unsigned int scroll_x;
	while (true)
	{
		render_frame();
		*PPU_BG0_SCROLL = (++scroll_x) & PPU_BG0_SCROLL_X_MASK;
	}

	tbman_exit(0);
}
