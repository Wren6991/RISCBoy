#ifndef _LCD_H_
#define _LCD_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "delay.h"
#include "gpio.h"

// Each record consists of:
// - A payload size (including the command byte)
// - An post-delay in units of 5 ms. 0 means no delay.
// - The command payload, including the initial command byte
// A payload size of 0 terminates the list.

static const uint8_t ili9341_init_seq[] = {
	1, 1, 0x01,
	2, 0, 0xc0, 0x23,  // PWCTRL1, VRH = 4.6V
	2, 0, 0xc1, 0x10,  // PWCTRL2, minimum step-up factor (BT)
	0
};

static const uint8_t st7789_init_seq[] = {
	1, 30,  0x01,                         // Software reset
	1, 100, 0x11,                         // Exit sleep mode
	2, 2,   0x3a, 0x55,                   // Set colour mode to 16 bit
	2, 0,   0x36, 0x00,                   // Set MADCTL: row then column, refresh is bottom to top ????
	5, 0,   0x2a, 0x00, 0x00, 0x00, 0xf0, // CASET: column addresses from 0 to 240 (f0)
	5, 0,   0x2b, 0x00, 0x00, 0x00, 0xf0, // RASET: row addresses from 0 to 240 (f0)
	1, 2,   0x21,                         // Inversion on, then 10 ms delay (supposedly a hack?)
	1, 2,   0x13,                         // Normal display on, then 10 ms delay
	1, 100, 0x29,                         // Main screen turn on, then wait 500 ms
	0                                     // Terminate list
};

static inline void _lcd_put(uint8_t x)
{
	uint32_t pinval = *GPIO_OUT;
	const uint32_t sdo_mask = 1ul << PIN_LCD_SDO;
	const uint32_t scl_mask = 1ul << PIN_LCD_SCL;
	for (int i = 0; i < 8; ++i)
	{
		pinval = pinval & ~(sdo_mask | scl_mask) | ((x >> 7) << PIN_LCD_SDO);
		*GPIO_OUT = pinval;
		pinval |= scl_mask;
		x <<= 1;
		*GPIO_OUT = pinval;
	}
	*GPIO_OUT = pinval & ~scl_mask;
}

static inline void lcd_write(const uint8_t *data, size_t count)
{
	gpio_out_pin(PIN_LCD_CS, 0);
	for (size_t i = 0; i < count; ++i)
		_lcd_put(data[i]);
	gpio_out_pin(PIN_LCD_CS, 1);
}

static inline void lcd_write_cmd(const uint8_t *cmd, size_t count)
{
	gpio_out_pin(PIN_LCD_DC, 0);
	gpio_out_pin(PIN_LCD_CS, 0);
	_lcd_put(*cmd++);
	if (count >= 2)
	{
		gpio_out_pin(PIN_LCD_DC, 1);
		for (int i = 0; i < count - 1; ++i)
			_lcd_put(*cmd++);
	}
	gpio_out_pin(PIN_LCD_CS, 1);
}

static inline void lcd_init(const uint8_t *init_seq)
{
	*GPIO_OUT = *GPIO_OUT
		& ~(
		(1ul << PIN_LCD_SCL) |
		(1ul << PIN_LCD_SDO) |
		(1ul << PIN_LCD_DC) |
		(1ul << PIN_LCD_RST))
		| (1ul << PIN_LCD_CS);
	*GPIO_DIR |= 
		(1ul << PIN_LCD_SCL) |
		(1ul << PIN_LCD_SDO) |
		(1ul << PIN_LCD_CS) |
		(1ul << PIN_LCD_DC) |
		(1ul << PIN_LCD_RST);

	*GPIO_FSEL0 &= ~(
		GPIO_FSEL_MASK_PIN(PIN_LCD_SCL) |
		GPIO_FSEL_MASK_PIN(PIN_LCD_SDO) |
		GPIO_FSEL_MASK_PIN(PIN_LCD_CS) |
		GPIO_FSEL_MASK_PIN(PIN_LCD_DC) |
		GPIO_FSEL_MASK_PIN(PIN_LCD_RST)
	);

	delay_ms(5);
	gpio_out_pin(PIN_LCD_RST, 1);
	delay_ms(150);

	const uint8_t *cmd = init_seq;

	while (*cmd)
	{
		lcd_write_cmd(cmd + 2, *cmd);
		delay_ms(*(cmd + 1) * 5);
		cmd += *cmd + 2;
	}
}

static inline void st7789_start_pixels()
{
	uint8_t cmd = 0x2c;
	lcd_write_cmd(&cmd, 1);
	gpio_out_pin(PIN_LCD_DC, 1);
}

#endif