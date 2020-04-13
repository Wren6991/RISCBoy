#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "lcd.h"
#include "gpio.h"
#include "affine_transform.h"
#include "tbman.h"

#include "zelda_tileset_mini_pal8.h"
#include "zelda_tileset_mini_pal8_palette.h"
#include "map_test_zelda_mini.h"

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

uint32_t __attribute__ ((section (".noload"))) cproc_prog[256];

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
	if (!tbman_running_in_sim())
		lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = (SCREEN_WIDTH - 1 >> PPU_DISPSIZE_W_LSB) | (SCREEN_HEIGHT - 1 << PPU_DISPSIZE_H_LSB);

	for (int i = 0; i < ZELDA_MINI_PALETTE_SIZE; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)zelda_tileset_mini_pal8_palette)[i] | 0x8000u;

	affine_transform_t cam_trans;
	affine_identity(cam_trans);

	unsigned int idle_count = 0;
	while (true)
	{
		uint32_t *p = cproc_prog;
		p += cproc_clip(p, 0, SCREEN_WIDTH - 1);
		p += cproc_fill(p, 16, 0, 16);
		p += cproc_atile(p, 0, 0, PPU_SIZE_1024, 0, PPU_FORMAT_PAL8, PPU_SIZE_16,
			cam_trans, zelda_tileset_mini_pal8, map_test_zelda_mini);
		p += cproc_sync(p);
		p += cproc_jump(p, (uintptr_t)cproc_prog);
		cproc_put_pc((uint32_t)cproc_prog);

		render_frame();

		const unsigned SPEED = 3;
		const unsigned IDLE_PERIOD = 300;
		if (gpio_in_pin(PIN_DPAD_U))
			affine_translate(cam_trans, 0, SPEED);
		if (gpio_in_pin(PIN_DPAD_D))
			affine_translate(cam_trans, 0, -SPEED);
		if (gpio_in_pin(PIN_DPAD_L))
			affine_translate(cam_trans, SPEED, 0);
		if (gpio_in_pin(PIN_DPAD_R))
			affine_translate(cam_trans, -SPEED, 0);

		if (!(gpio_in() & ((1u << PIN_DPAD_U) | (1u << PIN_DPAD_D) | (1u << PIN_DPAD_L) | (1u << PIN_DPAD_R))))
		{
			if (idle_count < IDLE_PERIOD)
				++idle_count;
		}
		else
		{
			idle_count = 0;
		}
		if (idle_count >= IDLE_PERIOD)
			affine_translate(cam_trans, -SPEED, 0);

		if (gpio_in() & (1u << PIN_BTN_A))
		{
			affine_translate(cam_trans, -(SCREEN_WIDTH / 2), -(SCREEN_HEIGHT / 2));
			affine_rotate(cam_trans, SPEED);
			affine_translate(cam_trans, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2);
		}
	}
}
