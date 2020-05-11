#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "lcd.h"
#include "tbman.h"
#include "affine_transform.h"
#include "ulx3s_bin.h"
#include "ulx3s_bin_pal.h"

#include <stdlib.h>

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

uint32_t __attribute__ ((section (".noload"))) cp_prog[2048];

static inline void render_frame()
{
	mm_ppu->csr = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
	mm_dvi_lcd->csr = 1; // Make sure DVI is running
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

#define N_SPRITES 1

int main()
{
	mm_ppu->dispsize = ((SCREEN_WIDTH - 1) << PPU_DISPSIZE_W_LSB) | ((SCREEN_HEIGHT - 1) << PPU_DISPSIZE_H_LSB);

	int16_t px[N_SPRITES];
	int16_t py[N_SPRITES];
	int16_t pt[N_SPRITES];
	int16_t vx[N_SPRITES];
	int16_t vy[N_SPRITES];
	uint8_t vt[N_SPRITES];

	for (int i = 0; i < N_SPRITES; ++i)
	{
		px[i] = rand() % 320;
		py[i] = rand() % 240;
		pt[i] = rand() % 256;
		vx[i] = rand() % 5 + 1;
		vy[i] = rand() % 5 + 1;
		vt[i] = rand() % 7 - 3;
	}

	for (int i = 0; i < 256; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)ulx3s_bin_pal)[i] | 0x8000u;

	while (true)
	{
		int32_t base[6], trans[6];
		affine_identity(base);
		affine_translate(base, -128, -128);

		uint32_t *p = cp_prog;
		p += cproc_clip(p, 0, 319);
		p += cproc_fill(p, 31, 31, 31);
		for (int i = 0; i < N_SPRITES; ++i)
		{
			affine_copy(trans, base);
			affine_rotate(trans, pt[i]);
			affine_translate(trans, px[i], py[i]);
			p += cproc_ablit(p, 0, 0, PPU_SIZE_512, 0, PPU_FORMAT_PAL8, PPU_ABLIT_HALFSIZE, trans, ulx3s_bin);
		}
		p += cproc_sync(p);
		p += cproc_jump(p, (uint32_t)cp_prog);

		cproc_put_pc((uint32_t)cp_prog);

		render_frame();

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
				vt[i] = rand() % 7 - 3;
			}
			pt[i] += vt[i];
		}

	}

	return 0;
}
