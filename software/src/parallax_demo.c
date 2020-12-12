#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "display.h"
#include "gpio.h"

#include "tileset.h"
#include "tileset_palette.h"
#include "tilemap_background.h"
#include "tilemap_foreground.h"

uint32_t ppu_prog[64];

int main()
{
	display_init();

	unsigned scroll_fg = 0;
	unsigned scroll_bg = 0;
	while (1)
	{
		uint32_t *p = ppu_prog;
		p += cproc_clip(p, 0, 319);
		p += cproc_fill(p, 13, 18, 17); // #5e978c
		p += cproc_tile(p, -scroll_bg, 0,
			PPU_SIZE_512,
			0, PPU_FORMAT_ARGB1555,
			PPU_SIZE_16,
			tileset,
			tilemap_background
		);
		p += cproc_tile(p, -scroll_fg, 0,
			PPU_SIZE_1024,
			0, PPU_FORMAT_ARGB1555,
			PPU_SIZE_16,
			tileset,
			tilemap_foreground
		);
		p += cproc_sync(p);
		p += cproc_jump(p, ppu_prog);
		cproc_put_pc(ppu_prog);

		display_start_frame();
		display_wait_frame_end();
		scroll_fg += 2;
		scroll_bg += 1;
	}
}
