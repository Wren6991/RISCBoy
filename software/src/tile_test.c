#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "display.h"
#include "gpio.h"
#include "affine_transform.h"
#include "tb_cxxrtl_io.h"

#include "zelda_tileset_mini_pal8.h"
#include "zelda_tileset_mini_pal8_palette.h"
#include "map_test_zelda_mini.h"

uint32_t __attribute__ ((section (".noload"))) cproc_prog[1024];

uint8_t map_doubled[WIDTH_MAP_TEST_ZELDA_MINI * HEIGHT_MAP_TEST_ZELDA_MINI * 2];

int main()
{
	display_init();

	for (int i = 0; i < ZELDA_MINI_PALETTE_SIZE; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)zelda_tileset_mini_pal8_palette)[i] | 0x8000u;

	affine_transform_t cam_trans;
	affine_identity(cam_trans);

	// PPU2 only supports square maps -- to get rectangular wrapping, double up the map vertically
	const int n_tiles = WIDTH_MAP_TEST_ZELDA_MINI * HEIGHT_MAP_TEST_ZELDA_MINI;
	for (int i = 0; i < n_tiles; ++i) {
		map_doubled[i] = map_test_zelda_mini[i];
		map_doubled[i + n_tiles] = map_test_zelda_mini[i];
	}

	unsigned int idle_count = 0;
	while (true)
	{
		uint32_t *p = cproc_prog;
		// Every scanline, render a span of the affine-tiled background
		uint32_t *scanline_func = p;
		p += cproc_clip(p, 0, DISPLAY_WIDTH - 1);
		p += cproc_atile(p, 0, 0, PPU_SIZE_1024, 0, PPU_FORMAT_PAL8, PPU_SIZE_16,
			cam_trans, zelda_tileset_mini_pal8, map_doubled);
		p += cproc_ret(p);

		uint32_t *entry_point = p;
		for (unsigned int y = 0; y < DISPLAY_HEIGHT; ++y) {
			p += cproc_call(p, scanline_func);
			// Each scanline, draw a different solid red span, forming a triangle
			if (y > 100) {
				p += cproc_clip(p, y, DISPLAY_WIDTH - 1 - y);
				p += cproc_fill(p, 31, 0, 0);
			}
			p += cproc_sync(p);
		}

		cproc_put_pc(entry_point);

		display_start_frame();
		display_wait_frame_end();

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
			affine_translate(cam_trans, -(DISPLAY_WIDTH / 2), -(DISPLAY_HEIGHT / 2));
			affine_rotate(cam_trans, SPEED);
			affine_translate(cam_trans, DISPLAY_WIDTH / 2, DISPLAY_HEIGHT / 2);
		}
	}
}
