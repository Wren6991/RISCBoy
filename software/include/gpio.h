#ifndef _GPIO_H_
#define _GPIO_H_

#include <stdint.h>
#include <stdbool.h>

#include "addressmap.h"
#include "hw/gpio_regs.h"

DECL_REG(GPIO_BASE + GPIO_OUT_OFFS, GPIO_OUT);
DECL_REG(GPIO_BASE + GPIO_DIR_OFFS, GPIO_DIR);
DECL_REG(GPIO_BASE + GPIO_IN_OFFS, GPIO_IN);

#define N_GPIOS 11

#define PIN_LED         0

#define PIN_DPAD_U      1
#define PIN_DPAD_D      2
#define PIN_DPAD_L      3
#define PIN_DPAD_R      4
#define PIN_BTN_A       5
#define PIN_BTN_B       6
#define PIN_BTN_X       7
#define PIN_BTN_Y       8
#define PIN_BTN_START   9
#define PIN_BTN_SELECT  10


static inline void gpio_out(uint32_t val)
{
	*GPIO_OUT = val;
}

static inline void gpio_out_pin(int pin, bool val)
{
	*GPIO_OUT = *GPIO_OUT & ~(1ul << pin) | ((int)val << pin);
}

static inline void gpio_dir(uint32_t val)
{
	*GPIO_DIR = val;
}

static inline void gpio_dir_pin(int pin, bool val)
{
	*GPIO_DIR = *GPIO_DIR & ~(1ul << pin) | ((int)val << pin);
}

static inline uint32_t gpio_in()
{
	return *GPIO_IN;
}

static inline bool gpio_in_pin(int pin)
{
	return !!(*GPIO_IN & (1ul << pin));
}

#endif // _GPIO_H_
