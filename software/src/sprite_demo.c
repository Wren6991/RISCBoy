#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "display.h"
#include "gpio.h"

#include <stdlib.h>

#include "tileset.h"
#include "tileset_pal.h"
#include "tilemap.h"

#define MAP_WIDTH  512
#define MAP_HEIGHT 256
#define N_CHARACTERS 100
#define CPROC_LIST_SIZE 2048

typedef struct {
	int16_t pos_x;
	int16_t pos_y;
	uint8_t tile;
	uint8_t tilestride;
	uint8_t ntiles;
} sprite_t;

typedef struct {
	sprite_t spdata;
	int16_t xmin, ymin;
	int16_t xmax, ymax;
	uint8_t dir;
	uint8_t anim_frame;
} character_t;

typedef struct {
	int16_t cam_x;
	int16_t cam_y;
	uint32_t frame_ctr;
	character_t chars[N_CHARACTERS];
} game_state_t;

typedef struct {
	// Double-buffered command list so we can build the next frame's list during
	// the current frame
	int prog_buf_next;
	uint32_t ppu_prog0[CPROC_LIST_SIZE];
	uint32_t ppu_prog1[CPROC_LIST_SIZE];
} render_state_t;

void game_init(game_state_t *state) {
	state->cam_x = 0;
	state->cam_y = 0;
	state->frame_ctr = 0;
	for (int i = 0; i < N_CHARACTERS; ++i) {
		state->chars[i].dir = (rand() >> 16) & 0x3;
		state->chars[i].anim_frame = 0;
		state->chars[i].xmin = 8;
		state->chars[i].ymin = -6;
		state->chars[i].xmax = MAP_WIDTH - 24;
		state->chars[i].ymax = 128+87;
		state->chars[i].spdata.pos_x = rand() & 0xff;
		state->chars[i].spdata.pos_y = rand() & 0xff;
		state->chars[i].spdata.tile = 102;
		state->chars[i].spdata.tilestride = 17;
		state->chars[i].spdata.ntiles = 2;
	}
}

void render_init(render_state_t *state) {
	state->prog_buf_next = 0;
}

static inline int clip(int x, int l, int u) {
	return x < l ? l : x > u ? u : x;
}

void update(game_state_t *state) {
	state->frame_ctr++;

	const int CAMERA_SPEED = 3;
	if (gpio_in_pin(PIN_DPAD_U))
		state->cam_y -= CAMERA_SPEED;
	if (gpio_in_pin(PIN_DPAD_D))
		state->cam_y += CAMERA_SPEED;
	if (gpio_in_pin(PIN_DPAD_L))
		state->cam_x -= CAMERA_SPEED;
	if (gpio_in_pin(PIN_DPAD_R))
		state->cam_x += CAMERA_SPEED;
	state->cam_x = clip(state->cam_x, 0, MAP_WIDTH - DISPLAY_WIDTH);
	state->cam_y = clip(state->cam_y, 0, MAP_HEIGHT - DISPLAY_HEIGHT);

	// Pause when A held, so I can see the pixels
	if (gpio_in_pin(PIN_BTN_A))
		return;

	const int CHAR_SPEED = 2;
	for (int i = 0; i < N_CHARACTERS; ++i) {
		character_t *ch = &state->chars[i];
		if ((state->frame_ctr & 0x3u) == 0)
			ch->anim_frame = (ch->anim_frame + 1) & 0x3;
		if (!(rand() & 0xf00)) {
			ch->anim_frame = 0;
			ch->dir = (rand() >> 16) & 0x3;
		}
		ch->spdata.pos_x += ch->dir == 1 ? CHAR_SPEED : ch->dir == 3 ? -CHAR_SPEED : 0;
		ch->spdata.pos_y += ch->dir == 0 ? CHAR_SPEED : ch->dir == 2 ? -CHAR_SPEED : 0;
		ch->spdata.pos_x = clip(ch->spdata.pos_x, ch->xmin, ch->xmax);
		ch->spdata.pos_y = clip(ch->spdata.pos_y, ch->ymin, ch->ymax);
	}

}

void render(const game_state_t *gstate, render_state_t *rstate) {
	// Generate a PPU program into whichever program buffer is not currently being executed
	rstate->prog_buf_next = !rstate->prog_buf_next;
	uint32_t *prog_base = rstate->prog_buf_next ? rstate->ppu_prog1 : rstate->ppu_prog0;
	uint32_t *p = prog_base;

	// Render to the full scanline width
	p += cproc_clip(p, 0, DISPLAY_WIDTH - 1);

	// One background layer -> one TILE instruction
	p += cproc_tile(p, -gstate->cam_x, -gstate->cam_y,
		PPU_SIZE_512,    // Playfield size
		0,               // Palette offset
		PPU_FORMAT_PAL8, // Tileset pixel format
		PPU_SIZE_16,     // Tile size
		tileset,
		tilemap
	);

	// Generate a BLIT list for the animated sprites
	for (int i = 0; i < N_CHARACTERS; ++i) {
		const character_t *ch = &gstate->chars[i];
		int pos_x = ch->spdata.pos_x - gstate->cam_x;
		int pos_y = ch->spdata.pos_y - gstate->cam_y;
		uint8_t basetile = 102 + (ch->dir << 2) + ch->anim_frame;
		for (int tile = 0; tile < ch->spdata.ntiles; ++tile) {
			p += cproc_blit(p,
				pos_x,
				pos_y + 16 * tile,
				PPU_SIZE_16,
				0,
				PPU_FORMAT_PAL8,
				tileset + 16 * 16 * (basetile + tile * ch->spdata.tilestride)
			);
		}
	}

	// After finishing a scanline, present the buffer and loop to start
	p += cproc_sync(p);
	p += cproc_jump(p, prog_base);

	display_wait_frame_end();
	cproc_put_pc(prog_base);
	display_start_frame();
}

int main()
{
	display_init();

	for (int i = 0; i < 256; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)tileset_bin_pal)[i];

	static game_state_t gstate;
	static render_state_t rstate;
	game_init(&gstate);
	render_init(&rstate);

	while (true) 	{
		update(&gstate);
		render(&gstate, &rstate);
	}
}
