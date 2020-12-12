#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "display.h"
#include "gpio.h"
#include "affine_transform.h"
#include "tbman.h"

#include "track_tiles.h"
#include "track1.h"

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

ppu_instr_t cproc_prog0[2048];
ppu_instr_t cproc_prog1[2048];

int main() {
	display_init();

	mm_ppu->dispsize = (SCREEN_WIDTH - 1 >> PPU_DISPSIZE_W_LSB) | (SCREEN_HEIGHT - 1 << PPU_DISPSIZE_H_LSB);

	int32_t camx = 0;
	int32_t camy = 0;
	uint8_t camtheta = 0;

	unsigned int idle_count = 0;
	int next_prog_buf = 0;
	while (true) {
		next_prog_buf = !next_prog_buf;
		ppu_instr_t *p = next_prog_buf ? cproc_prog1 : cproc_prog0;
		ppu_instr_t *entry_point = p;

		const unsigned int sky_height = 100;
		ppu_instr_t *sky_loop_top = p;
		p += cproc_clip(p, 0, SCREEN_WIDTH - 1);
		p += cproc_fill(p, 10, 20, 30);
		p += cproc_sync(p);
		p += cproc_branch(p, sky_loop_top, PPU_CPROC_BRANCH_YLT, sky_height - 1);

		// Remainder is tiled
		for (unsigned int sy = sky_height; sy < SCREEN_HEIGHT; ++sy) {
			// p += cproc_clip(p, 0, SCREEN_WIDTH - 1);
			affine_transform_t at;
			affine_identity(at);
			affine_translate(at, -camx, -camy);
			const float cam_height = 100;
			const float focal_plane_dist = 100;
			float scanline_cam_y = sy - sky_height + 1;
			float scale_factor = scanline_cam_y / 

			// Note we are moving the tiling window down along with the raster beam, so
			// that the raster beam offset is not applied to our affine transform
			// (start of scanline is always considered (0, 0))
			p += cproc_atile(p, 0, sy, PPU_SIZE_1024, 0, PPU_FORMAT_ARGB1555, PPU_SIZE_16,
				at, track_tiles, track1);
			p += cproc_sync(p);
		}

		// Flip the program buffer once the current frame has finished rendering, we
		// can loop round and start generating the next program whilst the next
		// frame is rendering.
		display_wait_frame_end();
		cproc_put_pc(entry_point);
		display_start_frame();


		const unsigned SPEED = 3;
		const unsigned IDLE_PERIOD = 300;
		if (gpio_in_pin(PIN_DPAD_U))
			camy += SPEED;
		if (gpio_in_pin(PIN_DPAD_D))
			camy -= SPEED;
		if (gpio_in_pin(PIN_DPAD_L))
			camx -= SPEED;
		if (gpio_in_pin(PIN_DPAD_R))
			camx += SPEED;

		if (!(gpio_in() & ((1u << PIN_DPAD_U) | (1u << PIN_DPAD_D) | (1u << PIN_DPAD_L) | (1u << PIN_DPAD_R)))) {
			if (idle_count < IDLE_PERIOD)
				++idle_count;
		}
		else {
			idle_count = 0;
		}
		// if (idle_count >= IDLE_PERIOD)
		// 	++camx;

		if (gpio_in() & (1u << PIN_BTN_A)) {
			++camtheta;
		}
	}
}
