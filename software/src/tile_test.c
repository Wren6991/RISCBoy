#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "lcd.h"
#include "gpio.h"

#include "resource/zelda_tileset_mini_argb1555.h"
#include "resource/map_test_zelda_mini.h"

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

	*PPU_BG0_TSBASE = (uint32_t)zelda_tileset_mini_argb1555;
	*PPU_BG0_TMBASE = (uint32_t)map_test_zelda_mini;
	*PPU_BG0_CSR =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(9u << PPU_BG0_CSR_PFWIDTH_LSB) | // 1024 px wide
		(8u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 512 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(1u << PPU_BG0_CSR_FLUSH_LSB);

	unsigned int scroll_x = 0, scroll_y = 0, idle_count = 0;
	while (true)
	{
		const unsigned SPEED = 3;
		const unsigned IDLE_PERIOD = 200;
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

		*PPU_BG0_SCROLL = 
			((scroll_x << PPU_BG0_SCROLL_X_LSB) & PPU_BG0_SCROLL_X_MASK) |
			((scroll_y << PPU_BG0_SCROLL_Y_LSB) & PPU_BG0_SCROLL_Y_MASK);

		render_frame();
	}
}
