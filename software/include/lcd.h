#ifndef _LCD_H_
#define _LCD_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "delay.h"
#include "ppu.h"

// Each record consists of:
// - A payload size (including the command byte)
// - A post-delay in units of 5 ms. 0 means no delay.
// - The command payload, including the initial command byte
// A payload size of 0 terminates the list.

static const uint8_t ili9341_init_seq[] = {
	1,  30, 0x01,                   // Software reset, 150 ms delay
	2,  24, 0xc1, 0x11,             // PWCTRL2, step up control (BT) = 1, -> VGL = -VCI * 3,  120 ms delay
	3,  0,  0xc5, 0x34, 0x3d,       // VMCTRL1, VCOMH = 4.0 V, VCOML = -0.975 V
	2,  0,  0xc7, 0xc0,             // VMCTRL2, override NVM-stored VCOM offset, and set our own offset of 0 points
	2,  0,  0x36, 0xe8,             // MADCTL, set MX+MY+MV (swap X/Y and flip both axes), set colour order to BGR
	2,  0,  0x3a, 0x55,             // COLMOD, 16 bpp pixel format for both RGB and MCU interfaces
	3,  0,  0xb1, 0x00, 0x18,       // FRMCTR1 frame rate control for normal display mode, no oscillator prescale, 79 Hz refresh
	4,  0,  0xb6, 0x08, 0x82, 0x27, // DFUNCTR: interval scan in non-display area (PTG). Crystal type normally white (REV). Set non-display scan interval (from PTG) to every 5th frame (ISC). Number of lines = 320 (NL). Do not configure external fosc divider (PCDIV).
	2,  0,  0x26, 0x01,             // GAMSET = 0x01, the only defined value for gamma curve selection
	16, 0,  0xe0, 0x0f, 0x31, 0x2b, // PGAMCTRL, positive gamma control, essentially magic as far as I'm concerned
	        0x0c, 0x0e, 0x08, 0x4e,
	        0xf1, 0x37, 0x07, 0x10,
	        0x03, 0x0e, 0x09, 0x00,
	16, 0,  0xe1, 0x00, 0x0e, 0x14, // NGAMCTRL, also magic moon runes
	        0x03, 0x11, 0x07, 0x31,
	        0xc1, 0x48, 0x08, 0x0f,
	        0x0c, 0x31, 0x36, 0x0f,
	1,  30, 0x11,                   // SLPOUT, exit sleep mode and wait 150 ms
	1,  30, 0x29,                   // DISPON, turn display on and wait 150 ms
	0                               // Terminate list
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

static inline void lcd_write_cmd(const uint8_t *cmd, size_t count)
{
	lcd_wait_idle();
	lcd_set_shift_width(8);
	lcd_force_dc_cs(0, 0);
	lcd_put_byte(*cmd++);
	if (count >= 2)
	{
		lcd_force_dc_cs(1, 0);
		for (size_t i = 0; i < count - 1; ++i)
			lcd_put_byte(*cmd++);
	}
	lcd_wait_idle();
	lcd_force_dc_cs(1, 1);
	lcd_set_shift_width(16);
}

static inline void lcd_init(const uint8_t *init_seq)
{

	// PIN_LCD_RST low
	// delay_ms(5);
	// gpio_out_pin(PIN_LCD_RST, 1);
	// delay_ms(150);

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
	lcd_force_dc_cs(1, 0);
}

#endif
