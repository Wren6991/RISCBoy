#define CLK_SYS_MHZ 12

#include "ppu.h"
#include "display.h"
#include "tb_cxxrtl_io.h"
#include "uart.h"
#include "affine_transform.h"
#include "testframe.bin.h"
#include "testframe.bin.pal.h"

#include <string.h>

#define SCREEN_WIDTH 320u
#define SCREEN_HEIGHT 240u

// Each video frame is a 128x128 4bpp image, and an accompanying 16 colour
// palette (each colour ARGB1555). This is a squashed version of the original
// 4:3 aspect ratio, which is itself cropped from a 1080p source. We need to
// stretch this image to 320x240 to restore it to the correct aspect ratio.
//
// Two parts to this:
//
// - Use halfsize flag so that we can rasterise a 256x256 region with a
//   stretched version of our 128x128 texture
// - Tile the screen with multiple of these 256x256 regions (two total) to
//   cover the full 320x240 

// 16 colour palette (each ARGB1555), 128x128 4bpp texture
#define PAL_SIZE_BYTES (16 * 2)
#define TEX_SIZE_BYTES (128 * 128 / 2)
#define BUF_SIZE_BYTES (PAL_SIZE_BYTES + TEX_SIZE_BYTES)

uint8_t __attribute__((section (".noload"), aligned(4))) texbuf0[BUF_SIZE_BYTES];
uint8_t __attribute__((section (".noload"), aligned(4))) texbuf1[BUF_SIZE_BYTES];
uint32_t __attribute__ ((section (".noload"))) cp_prog[64];

void *bufs[] = {texbuf0, texbuf1};

void render_start()
{
	mm_ppu->csr = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
}

void render_wait()
{
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

void __time_critical update_buf(uint8_t *buf)
{
	for (int i = 0; i < BUF_SIZE_BYTES; ++i)
		buf[i] = uart_get();
}


int main()
{
	display_init();

	const affine_transform_t ta = {
		(int32_t)(AF_ONE * 128.f / 320.f), 0, 0,
		0, (int32_t)(AF_ONE * 128.f / 240.f), 0
	};
	affine_transform_t tb;
	affine_copy(tb, ta);
	affine_translate(tb, -256, 0);

	for (int i = 0; i < BUF_SIZE_BYTES / 2; ++i)
		((uint16_t *)texbuf0)[i] = 0x8000u;
	// memcpy(texbuf0, testframe_bin_pal, PAL_SIZE_BYTES);
	// memcpy(texbuf0 + PAL_SIZE_BYTES, testframe_bin, BUF_SIZE_BYTES);

	int current_buf = 0;

	while (true)
	{
		uint32_t *p = cp_prog;
		p += cproc_clip(p, 0, SCREEN_WIDTH - 1);
		p += cproc_fill(p, 0, 0, 0);
		p += cproc_ablit(p, 0, 0, PPU_SIZE_256, 0, PPU_FORMAT_PAL4, PPU_ABLIT_HALFSIZE, ta, bufs[current_buf] + PAL_SIZE_BYTES);
		p += cproc_ablit(p, 256, 0, PPU_SIZE_256, 0, PPU_FORMAT_PAL4, PPU_ABLIT_HALFSIZE, tb, bufs[current_buf] + PAL_SIZE_BYTES);
		p += cproc_sync(p);
		p += cproc_jump(p, (uint32_t)cp_prog);
		cproc_put_pc((uint32_t)cp_prog);

		for (int i = 0; i < 16; ++i)
			PPU_PALETTE_RAM[i] = ((uint16_t *)bufs[current_buf])[i] | 0x8000u; // alpha!

		display_start_frame();
		current_buf = !current_buf;
		update_buf(bufs[current_buf]);
		display_wait_frame_end();
	}

	return 0;
}
