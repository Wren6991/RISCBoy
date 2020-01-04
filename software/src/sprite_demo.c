#define CLK_SYS_MHZ 36

#include "ppu.h"
#include "lcd.h"
#include "gpio.h"

#include "tileset.h"
#include "tileset_pal.h"
#include "tilemap.h"

#include <stdlib.h>

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240
#define MAP_WIDTH  512
#define MAP_HEIGHT 256
#define N_CHARACTERS 4

typedef struct sprite {
	int16_t pos_x;
	int16_t pos_y;
	uint8_t tile;
	uint8_t tilestride;
	uint8_t ntiles;
} sprite_t;

typedef struct character {
	sprite_t spdata;
	int16_t xmin, ymin;
	int16_t xmax, ymax;
	uint8_t dir;
	uint8_t anim_frame;
} character_t;

typedef struct game_state {
	int16_t cam_x;
	int16_t cam_y;
	uint32_t frame_ctr;
	struct character chars[N_CHARACTERS];
} game_state_t;

void init(game_state_t *state)
{
	state->cam_x = 0;
	state->cam_y = 0;
	state->frame_ctr = 0;
	for (int i = 0; i < N_CHARACTERS; ++i)
	{
		state->chars[i].dir = i;//(rand() >> 16) & 0x3;
		state->chars[i].anim_frame = 0;
		state->chars[i].xmin = 24;
		state->chars[i].ymin = 10;
		state->chars[i].xmax = MAP_WIDTH - 8;
		state->chars[i].ymax = 103;
		state->chars[i].spdata.pos_x = 30 * (i + 1);//rand() & 0xff;
		state->chars[i].spdata.pos_y = 100;//rand() & 0xff;
		state->chars[i].spdata.tile = 102;
		state->chars[i].spdata.tilestride = 17;
		state->chars[i].spdata.ntiles = 2;
	}
}

static inline int clip(int x, int l, int u)
{
	return x < l ? l : x > u ? u : x;
}

void update(game_state_t *state)
{
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
	state->cam_x = clip(state->cam_x, 0, MAP_WIDTH - SCREEN_WIDTH);
	state->cam_y = clip(state->cam_y, 0, MAP_HEIGHT - SCREEN_HEIGHT);

	const int CHAR_SPEED = 2;
	for (int i = 0; i < N_CHARACTERS; ++i)
	{
		character_t *ch = &state->chars[i];
		if ((state->frame_ctr & 0x3u) == 0)
			ch->anim_frame = (ch->anim_frame + 1) & 0x3;
		if (!(rand() & 0xf00))
		{
			ch->anim_frame = 0;
			ch->dir = (rand() >> 16) & 0x3;
		}
		ch->spdata.pos_x += ch->dir == 1 ? CHAR_SPEED : ch->dir == 3 ? -CHAR_SPEED : 0;
		ch->spdata.pos_y += ch->dir == 0 ? CHAR_SPEED : ch->dir == 2 ? -CHAR_SPEED : 0;
		ch->spdata.pos_x = clip(ch->spdata.pos_x, ch->xmin, ch->xmax);
		ch->spdata.pos_y = clip(ch->spdata.pos_y, ch->ymin, ch->ymax);
	}

}

void render(const game_state_t *state)
{
	mm_ppu->bg[0].scroll = 
		((state->cam_x << PPU_BG0_SCROLL_X_LSB) & PPU_BG0_SCROLL_X_MASK) |
		((state->cam_y << PPU_BG0_SCROLL_Y_LSB) & PPU_BG0_SCROLL_Y_MASK);

	int sp = 0;
	for (int i = 0; i < N_CHARACTERS; ++i)
	{
		const character_t *ch = &state->chars[i];

		int pos_x = ch->spdata.pos_x - state->cam_x;
		int pos_y = ch->spdata.pos_y - state->cam_y;
		if (pos_x < 0 || pos_y < -16 * (ch->spdata.ntiles - 1) || pos_x > SCREEN_WIDTH + 16 || pos_y > SCREEN_HEIGHT + 16)
			continue;

		uint8_t basetile = 102 + (ch->dir << 2) + ch->anim_frame;
		for (int tile = 0; tile < ch->spdata.ntiles; ++tile)
		{
			mm_ppu->sp[sp].csr =
				(1u << PPU_SP0_CSR_EN_LSB) |
				((basetile + tile * ch->spdata.tilestride) << PPU_SP0_CSR_TILE_LSB);
			mm_ppu->sp[sp].pos =
				(((uint32_t)pos_x)	           << PPU_SP0_POS_X_LSB) |
				(((uint32_t)pos_y + 16 * tile) << PPU_SP0_POS_Y_LSB);
			++sp;
			if (sp >= N_PPU_SPRITES)
				break;
		}
		if (sp >= N_PPU_SPRITES)
			break;
	}
	// Deactivate remaining hardware sprites
	while (sp < N_PPU_SPRITES)
		mm_ppu->sp[sp++].csr = 0;

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

	mm_ppu->dispsize = ((SCREEN_WIDTH - 1) >> PPU_DISPSIZE_W_LSB) | ((SCREEN_HEIGHT - 1) << PPU_DISPSIZE_H_LSB);
	mm_ppu->default_bg_colour = 0x7c1fu;

	mm_ppu->bg[0].tsbase = (uint32_t)tileset;
	mm_ppu->bg[0].tmbase = (uint32_t)tilemap;
	mm_ppu->bg[0].csr =
		(1u << PPU_BG0_CSR_EN_LSB) |
		(5u << PPU_BG0_CSR_PFWIDTH_LSB) | // 1024 px wide
		(4u << PPU_BG0_CSR_PFHEIGHT_LSB) | // 512 px high
		(1u << PPU_BG0_CSR_TILESIZE_LSB) | // 16x16 pixel tiles
		(PPU_PIXMODE_PAL8 << PPU_BG0_CSR_PIXMODE_LSB);

	for (int i = 0; i < TILESET_PALETTE_SIZE; ++i)
		PPU_PALETTE_RAM[i] = ((const uint16_t *)tileset_bin_pal)[i];

	mm_ppu->sp_csr =
		(PPU_PIXMODE_PAL8 << PPU_SP_CSR_PIXMODE_LSB) |
		(1u << PPU_SP_CSR_TILESIZE_LSB);
	mm_ppu->sp_tsbase = (uint32_t)tileset;


	static game_state_t gstate;
	init(&gstate);

	while (true)
	{
		update(&gstate);
		render(&gstate);
	}
}
