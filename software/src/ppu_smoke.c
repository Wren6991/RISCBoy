#define CLK_SYS_MHZ 36

#include "display.h"
#include "display.h"
#include "tb_cxxrtl_io.h"
#include "gpio.h"
#include "pwm.h"

// Don't put the tile assets in .bss, so that we don't have to sit and watch
// them be cleared in the simulator. We're about to fully initialise them anyway.
uint16_t __attribute__ ((section (".noload"), aligned (4))) tileset[65536];
uint8_t  __attribute__ ((section (".noload"), aligned (4))) tilemap[256];
uint32_t __attribute__ ((section (".noload"))) cproc_prog[256];

int main() {
	display_init();

	for (int i = 0; i < 256; ++i)
		tilemap[i] = i;
	for (unsigned int tile = 0; tile < 16 * 16; ++tile)
	{
		for (unsigned int x = 0; x < 16; ++x)
		{
			for (unsigned int y = 0; y < 16; ++y)
			{
				unsigned int i = x + (tile % 16) * 16 + 256 * (y + (tile / 16) * 16);
				tileset[tile * 256 + y * 16 + x] =
					0x8000u | // alpha!
					(i & COLOUR_BLUE) |
					((i >> 3) & COLOUR_GREEN) |
					((i >> 1) & COLOUR_RED);
			}
		}
	}

	unsigned int scroll_x = 0;
	unsigned int scroll_y = 0;
	unsigned int frame_ctr = 0;
	while (true) {
		uint32_t *p = cproc_prog;
		p += cproc_clip(p, 0, 319);
		p += cproc_fill(p, 16, 0, 16);
		p += cproc_tile(p, -scroll_x, -scroll_y, PPU_SIZE_256, 0, PPU_FORMAT_ARGB1555, PPU_SIZE_16, tileset, tilemap);
		p += cproc_sync(p);
		p += cproc_jump(p, (uintptr_t)cproc_prog);
		cproc_put_pc((uint32_t)cproc_prog);

		display_start_frame();
		display_wait_frame_end();

		++frame_ctr;
		unsigned int dir0 = (frame_ctr >> 6) & 0x7u;
		unsigned int dir90 = (dir0 + 2) & 0x7u;
		if ((dir0 & 3u) != 3)
			if (dir0 & 4u)
				--scroll_x;
			else
				++scroll_x;
		if ((dir90 & 3u) != 3)
			if (dir90 & 4u)
				--scroll_y;
			else
				++scroll_y;
	}

	tb_exit(0);
}
