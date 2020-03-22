#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "lcd.h"
#include "tbman.h"
#include "gpio.h"
#include "pwm.h"

#include <stdlib.h>

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

uint16_t __attribute__ ((section (".noload"), aligned (4))) sprite[1024];
uint32_t __attribute__ ((section (".noload"))) cp_prog[2048];

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

#define N_SPRITES 200

int main()
{
	if (!tbman_running_in_sim())
		lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = ((SCREEN_WIDTH - 1) << PPU_DISPSIZE_W_LSB) | ((SCREEN_HEIGHT - 1) << PPU_DISPSIZE_H_LSB);

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
		p += cproc_clip(p, 0, 319);
		p += cproc_fill(p, 31, 0, 0);
		for (int i = 0; i < N_SPRITES; ++i)
			p += cproc_blit(p, px[i], py[i], PPU_SIZE_32, 0, PPU_FORMAT_ARGB1555, sprite);
		p += cproc_sync(p);
		p += cproc_jump(p, (uint32_t)cp_prog);

		cproc_put_pc((uint32_t)cp_prog);

		lcd_wait_idle();
		lcd_force_dc_cs(1, 1);
		st7789_start_pixels();

		mm_ppu->csr = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;

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
		while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
			;
	}

}
