#include <math.h>

#include "pico/stdlib.h"
#include "hardware/interp.h"

#include "raspberry_256x256_rgb565.h"

#define PIN_DB0 21
// #define PIN_LED 16
#define PIN_RST 26
#define PIN_CS 25
#define PIN_RS 24
#define PIN_WR 23
#define PIN_RD 22

#define N_DATA_PINS 16

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240
#define IMAGE_SIZE 256
#define LOG_IMAGE_SIZE 8


static inline void gpio_out_init(uint pin, bool val) {
	gpio_init(pin);
	gpio_put(pin, val);
	gpio_set_dir(pin, GPIO_OUT);
}

static inline uint16_t rev16(uint16_t x) {
	x = (x & 0xff00u) >> 8 | (x & 0x00ffu) << 8;
	x = (x & 0xf0f0u) >> 4 | (x & 0x0f0fu) << 4;
	x = (x & 0xccccu) >> 2 | (x & 0x3333u) << 2;
	x = (x & 0xaaaau) >> 1 | (x & 0x5555u) << 1;
	return x;
}

static inline void set_db(uint16_t data) {
	gpio_put_masked(
		~(~0u << N_DATA_PINS) << (PIN_DB0 - (N_DATA_PINS - 1)),
		(uint32_t)rev16(data) << (PIN_DB0 - (N_DATA_PINS - 1))
	);
}

// yes again with this shit
#define _delay() asm volatile ("nop \n nop \n nop")

static inline void put_cmd(uint16_t cmd) {
	_delay();
	set_db(cmd);
	gpio_put(PIN_RS, 0);
	_delay();
	gpio_put(PIN_CS, 0);
	_delay();
	gpio_put(PIN_WR, 0);
	_delay();
	gpio_put(PIN_WR, 1);
	_delay();
	gpio_put(PIN_CS, 1);
	_delay();
	gpio_put(PIN_RS, 1);
}

static inline void put_data(uint16_t data) {
	_delay();
	set_db(data);
	_delay();
	gpio_put(PIN_CS, 0);
	_delay();
	gpio_put(PIN_WR, 0);
	_delay();
	gpio_put(PIN_WR, 1);
	_delay();
	gpio_put(PIN_CS, 1);
	_delay();
}

int main() {
#if 0
	// Blinky test pattern
	const uint first = 6;
	const uint last = 27;
	for (int i = first; i <= last; ++i) {
		gpio_out_init(i, 0);
	}
	while (true) {
		gpio_put_all(-1u);
		busy_wait_us_32(100);
		for (int i = first; i < last; ++i) {
			gpio_put_all(1u << i);
			busy_wait_us_32(100);
		}
		gpio_put_all(0);
		busy_wait_us_32(100 * 1000);
	}

#else
	for (int i = PIN_DB0; i > PIN_DB0 - N_DATA_PINS; --i)
		gpio_out_init(i, 0);
	// gpio_out_init(PIN_LED, 1);
	gpio_out_init(PIN_RST, 1);
	gpio_out_init(PIN_CS,  1);
	gpio_out_init(PIN_RS,  1);
	gpio_out_init(PIN_WR,  1);
	gpio_out_init(PIN_RD,  1);

	// hw_set_bits(&padsbank0_hw->io[PIN_LED], PADS_BANK0_GPIO0_DRIVE_BITS);

	// The NOAC starts by sending this many zero data elements, then a 0x8000u.
	// No idea if it's important
	for (int i = 0; i < 1135208; ++i)
		put_data(0);
	busy_wait_us_32(22);
	put_data(0x8000u);
	busy_wait_us_32(22);

	// Then we have all this bollocks -- no idea what it is, seems to be some
	// kind of reset sequence given how long the following delay is.
	put_cmd(0x0u);
	put_data(0x1u);
	put_cmd(0x1u);
	put_data(0x0u);
	put_cmd(0x2u);
	put_data(0x700u);
	put_cmd(0x3u);
	put_data(0x1038u);
	put_cmd(0x4u);
	put_data(0x0u);
	put_cmd(0x8u);
	put_data(0x202u);
	put_cmd(0x9u);
	put_data(0x0u);
	put_cmd(0xau);
	put_data(0x0u);
	put_cmd(0xcu);
	put_data(0x0u);
	put_cmd(0xdu);
	put_data(0x0u);
	put_cmd(0xfu);
	put_data(0x0u);
	put_cmd(0x10u);
	put_data(0x0u);
	put_cmd(0x11u);
	put_data(0x7u);
	put_cmd(0x12u);
	put_data(0x0u);
	put_cmd(0x13u);
	put_data(0x0u);
	busy_wait_us_32(200 * 1000);

	// Then this... again haven't a clue
	put_cmd(0x10u);
	put_data(0x17b0u);
	put_cmd(0x11u);
	put_data(0x37u);
	busy_wait_us_32(15 * 1000);

	// I'm going to drop the running commentary now as it's not adding very much
	put_cmd(0x12u);
	put_data(0x13cu);
	put_cmd(0x13u);
	put_data(0x145au);
	put_cmd(0x29u);
	put_data(0xeu);
	put_cmd(0x20u);
	put_data(0x0u);
	put_cmd(0x21u);
	put_data(0x0u);
	put_cmd(0x30u);
	put_data(0x0u);
	put_cmd(0x31u);
	put_data(0x505u);
	put_cmd(0x32u);
	put_data(0x4u);
	put_cmd(0x35u);
	put_data(0x6u);
	put_cmd(0x36u);
	put_data(0x707u);
	put_cmd(0x37u);
	put_data(0x105u);
	put_cmd(0x38u);
	put_data(0x2u);
	put_cmd(0x39u);
	put_data(0x707u);
	put_cmd(0x3cu);
	put_data(0x704u);
	put_cmd(0x3du);
	put_data(0x807u);
	put_cmd(0x50u);
	put_data(0x0u);
	put_cmd(0x51u);
	put_data(0xefu);
	put_cmd(0x52u);
	put_data(0x0u);
	put_cmd(0x53u);
	put_data(0x13fu);
	put_cmd(0x60u);
	put_data(0x2700u);
	put_cmd(0x61u);
	put_data(0x1u);
	put_cmd(0x6au);
	put_data(0x0u);
	put_cmd(0x80u);
	put_data(0x0u);
	put_cmd(0x81u);
	put_data(0x0u);
	put_cmd(0x82u);
	put_data(0x0u);
	put_cmd(0x83u);
	put_data(0x0u);
	put_cmd(0x84u);
	put_data(0x0u);
	put_cmd(0x85u);
	put_data(0x0u);
	put_cmd(0x90u);
	put_data(0x10u);
	put_cmd(0x92u);
	put_data(0x0u);
	put_cmd(0x93u);
	put_data(0x3u);
	put_cmd(0x95u);
	put_data(0x110u);
	put_cmd(0x97u);
	put_data(0x0u);
	put_cmd(0x98u);
	put_data(0x0u);
	put_cmd(0x7u);
	put_data(0x173u);
	put_cmd(0x22u);
	busy_wait_us_32(50 * 1000);

	// After 50 ms we can now start sending pixel data.

	// Rip off from the SDK example (I mean I did write it so I guess it's ok)

#define UNIT_LSB 16
	interp_config lane0_cfg = interp_default_config();
	interp_config_set_shift(&lane0_cfg, UNIT_LSB - 1); // -1 because 2 bytes per pixel
	interp_config_set_mask(&lane0_cfg, 1, 1 + (LOG_IMAGE_SIZE - 1));
	interp_config_set_add_raw(&lane0_cfg, true); // Add full accumulator to base with each POP
	interp_config lane1_cfg = interp_default_config();
	interp_config_set_shift(&lane1_cfg, UNIT_LSB - (1 + LOG_IMAGE_SIZE));
	interp_config_set_mask(&lane1_cfg, 1 + LOG_IMAGE_SIZE, 1 + (2 * LOG_IMAGE_SIZE - 1));
	interp_config_set_add_raw(&lane1_cfg, true);

	interp_set_config(interp0, 0, &lane0_cfg);
	interp_set_config(interp0, 1, &lane1_cfg);
	interp0->base[2] = (uint32_t) raspberry_256x256;

	float theta = 0.f;
	float theta_max = 2.f * (float) M_PI;
	while (1) {
		theta += 0.02f;
		if (theta > theta_max)
			theta -= theta_max;
		int32_t rotate[4] = {
				cosf(theta) * (1 << UNIT_LSB), -sinf(theta) * (1 << UNIT_LSB),
				sinf(theta) * (1 << UNIT_LSB), cosf(theta) * (1 << UNIT_LSB)
		};
		interp0->base[0] = rotate[0];
		interp0->base[1] = rotate[2];
		for (int y = 0; y < SCREEN_HEIGHT; ++y) {
			interp0->accum[0] = rotate[1] * y;
			interp0->accum[1] = rotate[3] * y;
			for (int x = 0; x < SCREEN_WIDTH; ++x) {
				put_data(*(uint16_t *)(interp0->pop[2]));
			}
		}
	}
#endif
}
