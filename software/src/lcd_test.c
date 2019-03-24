#include <stdint.h>
#include <stddef.h>

#define CLK_SYS_MHZ 12
#include "delay.h"
#include "gpio.h"
#include "pwm.h"

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

static inline void lcd_write_byte(uint8_t x)
{
	gpio_out_pin(PIN_LCD_CS, 0);
	_lcd_put(x);
	gpio_out_pin(PIN_LCD_CS, 1);
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

// Each record consists of:
// - A payload size (including the command byte)
// - An post-delay in units of 5 ms. 0 is valid.
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

void st7789_set_window(int x0, int x1, int y0, int y1)
{
	uint8_t buf[5];
	buf[0] = 0x2a;
	buf[1] = x0 >> 8;
	buf[2] = x0 & 0xff;
	buf[3] = x1 >> 8;
	buf[4] = x1 & 0xff;
	lcd_write_cmd(buf, 5);
	buf[0] = 0x2b;
	buf[1] = y0 >> 8;
	buf[2] = y0 & 0xff;
	buf[3] = y1 >> 8;
	buf[4] = y1 & 0xff;
	lcd_write_cmd(buf, 5);
	buf[0] = 0x2c; // RAMWR
	lcd_write_cmd(buf, 1); // RAMWR
	gpio_out_pin(PIN_LCD_DC, 1);
}

void lcd_init()
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

	const uint8_t *cmd = st7789_init_seq;

	while (*cmd)
	{
		lcd_write_cmd(cmd + 2, *cmd);
		delay_ms(*(cmd + 1) * 5);
		cmd += *cmd + 2;
	}
}

int main()
{
	gpio_fsel(PIN_LCD_PWM, 1);
	// pwm_div(1);
	// pwm_enable(true);
	// pwm_val(0x80);
	pwm_enable(false);
	pwm_invert(true);
	lcd_init();

	
	uint8_t buf[2];

	st7789_set_window(0, 240, 0, 240);
	for (int y = 0; y < 240; ++y)
	{
		for (int x = 0; x < 240; ++x)
		{
			uint32_t colour = x & 0x1f | ((y & 0x1f) << 11) | (((x + y) >> 3) << 5);
			buf[0] = colour >> 8;
			buf[1] = colour & 0xff;
			lcd_write(buf, 2);
		}
	}
}