#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "display.h"
#include "gpio.h"
#include "pwm.h"

#include <stdlib.h>

uint16_t __attribute__ ((section (".noload"), aligned (4))) sprite[1024];
uint32_t __attribute__ ((section (".noload"))) cp_prog[2048];

#define N_SPRITES 100

int main()
{
	display_init();

	for (unsigned int i = 0; i < 1024; ++i)
		sprite[i] = i | 0x8000u; // alpha!

	int16_t px[N_SPRITES];
	int16_t py[N_SPRITES];
	int16_t vx[N_SPRITES];
	int16_t vy[N_SPRITES];

	for (int i = 0; i < N_SPRITES; ++i)
	{
		px[i] = -16;//rand() % (320 + 2 * 32) - 32;
		py[i] = rand() % (240 + 2 * 32) - 32;
		vx[i] = rand() % 5 + 1;
		vy[i] = 0;
	}

	while (true)
	{
		uint32_t *p = cp_prog;
		p += cproc_clip(p, 0, DISPLAY_WIDTH - 1);
		p += cproc_fill(p, 31, 0, 0);
		for (int i = 0; i < N_SPRITES; ++i)
			p += cproc_blit(p, px[i], py[i], PPU_SIZE_32, 0, PPU_FORMAT_ARGB1555, sprite);
		p += cproc_sync(p);
		p += cproc_jump(p, cp_prog);

		cproc_put_pc(cp_prog);

		display_start_frame();
		// Run update logic while PPU is rendering the frame

		for (int i = 0; i < N_SPRITES; ++i)
		{
			px[i] += vx[i];
			py[i] += vy[i];
			bool collide = false;
			if (px[i] < -32)
			{
				px[i] = -32;
				collide = true;
			}
			else if (px[i] > 352)
			{
				px[i] = 352;
				collide = true;
			}
			if (py[i] < -32)
			{
				py[i] = -32;
				collide = true;
			}
			else if (py[i] > 272)
			{
				py[i] = 272;
				collide = true;
			}
			if (collide)
			{
				vx[i] = rand() % 5 + 1;
				vy[i] = rand() % 5 + 1;
				if (rand() & 0x8000u)
					vx[i] = -vx[i];
				if (rand() & 0x8000u)
					vy[i] = -vy[i];
			}
		}

		// Now wait for rendering to complete before rebuilding blitter list
		display_wait_frame_end();
	}

}
