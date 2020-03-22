#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "lcd.h"
#include "gpio.h"

#include "zelda_tileset_mini_pal8.h"
#include "zelda_tileset_mini_pal8_palette.h"
#include "map_test_zelda_mini.h"

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
	lcd_init(ili9341_init_seq);

	mm_ppu->dispsize = (319 >> PPU_DISPSIZE_W_LSB) | (239 << PPU_DISPSIZE_H_LSB);

	for (int i = 0; i < ZELDA_MINI_PALETTE_SIZE; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)zelda_tileset_mini_pal8_palette)[i] | 0x8000u;

	unsigned int scroll_x = 0, scroll_y = 0, idle_count = 0;
	while (true)
	{
		uint32_t *p = cproc_prog;
		p += cproc_clip(p, 0, 319);
		p += cproc_fill(p, 16, 0, 16);
		p += cproc_tile(p, -scroll_x, -scroll_y, PPU_SIZE_1024, 0,
			PPU_FORMAT_PAL8, PPU_SIZE_16, zelda_tileset_mini_pal8, map_test_zelda_mini);
		p += cproc_sync(p);
		p += cproc_jump(p, (uintptr_t)cproc_prog);
		cproc_put_pc((uint32_t)cproc_prog);

		render_frame();

		const unsigned SPEED = 3;
		const unsigned IDLE_PERIOD = 300;
		if (gpio_in_pin(PIN_DPAD_U))
			scroll_y -= SPEED;
		if (gpio_in_pin(PIN_DPAD_D))
			scroll_y += SPEED;
		if (gpio_in_pin(PIN_DPAD_L))
			scroll_x -= SPEED;
		if (gpio_in_pin(PIN_DPAD_R))
			scroll_x += SPEED;

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
			scroll_x += SPEED;
	}
}
