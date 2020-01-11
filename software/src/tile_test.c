#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "lcd.h"
#include "gpio.h"

#include "zelda_tileset_mini_pal8.h"
#include "zelda_tileset_mini_pal8_palette.h"
#include "map_test_zelda_mini.h"

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
	mm_ppu->default_bg_colour = 0x7c1fu;

	mm_ppu->bg[0].tsbase = (uint32_t)zelda_tileset_mini_pal8;
	mm_ppu->bg[0].tmbase = (uint32_t)map_test_zelda_mini;
	mm_ppu->bg[0].csr =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(6u << PPU_BG0_CSR_PFWIDTH_LSB) | // 1024 px wide
		(5u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 512 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(PPU_PIXMODE_PAL8 << PPU_BG0_CSR_PIXMODE_LSB);

	for (int i = 0; i < ZELDA_MINI_PALETTE_SIZE; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)zelda_tileset_mini_pal8_palette)[i];

	mm_ppu->sp_csr =
		(PPU_PIXMODE_PAL8 << PPU_SP_CSR_PIXMODE_LSB) |
		(1u << PPU_SP_CSR_TILESIZE_LSB);
	mm_ppu->sp_tsbase = (uint32_t)zelda_tileset_mini_pal8;

	int16_t sprite_xpos[N_PPU_SPRITES];
	int16_t sprite_ypos[N_PPU_SPRITES];
	bool sprite_xdir[N_PPU_SPRITES];

	for (unsigned i = 0; i < N_PPU_SPRITES; ++i)
	{
		sprite_xpos[i] = 25u * (1 + i);
		sprite_ypos[i] = 25u * (1 + i);
		sprite_xdir[i] = true;

		mm_ppu->sp[i] =
			(38u << PPU_SP0_TILE_LSB) |
			(((uint32_t)sprite_xpos[i])	<< PPU_SP0_X_LSB) |
			(((uint32_t)sprite_ypos[i])	<< PPU_SP0_Y_LSB);
	}

	unsigned int scroll_x = 0, scroll_y = 0, idle_count = 0;
	while (true)
	{
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
		// if (idle_count >= IDLE_PERIOD)
		// 	scroll_x += SPEED;

		mm_ppu->bg[0].scroll = 
			((scroll_x << PPU_BG0_SCROLL_X_LSB) & PPU_BG0_SCROLL_X_MASK) |
			((scroll_y << PPU_BG0_SCROLL_Y_LSB) & PPU_BG0_SCROLL_Y_MASK);

		if (!gpio_in_pin(PIN_BTN_A))
		{
			for (unsigned i = 0; i < N_PPU_SPRITES; ++i)
			{
				const int16_t x_max = 336;
				const int16_t x_min = 0;
				const int16_t speed = 1;
				sprite_xpos[i] += sprite_xdir[i] ? speed : -speed;
				if (sprite_xpos[i] > x_max)
				{
					sprite_xpos[i] = x_max;
					sprite_xdir[i] = !sprite_xdir[i];
				}
				if (sprite_xpos[i] < x_min)
				{
					sprite_xpos[i] = x_min;
					sprite_xdir[i] = !sprite_xdir[i];
				}
				mm_ppu->sp[i] =
					(38u << PPU_SP0_TILE_LSB) |
					(((uint32_t)sprite_xpos[i])	<< PPU_SP0_X_LSB) |
					(((uint32_t)sprite_ypos[i])	<< PPU_SP0_Y_LSB);
			}
		}
		render_frame();
	}
}
