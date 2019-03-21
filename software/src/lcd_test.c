#include "gpio.h"
#include "delay.h"

#include <stdint.h>
#include <stddef.h>

#define CLK_SYS_MHZ 12

#define PIN_LCD_SCL 1
#define PIN_LCD_SDO 2
#define PIN_LCD_CS  3
#define PIN_LCD_DC  4

static inline void _lcd_put(uint8_t x)
{
	for (int i = 0; i < 8; ++i)
	{
		gpio_out_pin(PIN_LCD_SDO, x >> 7);
		x <<= 1;
		gpio_out_pin(PIN_LCD_SCL, 1);
		gpio_out_pin(PIN_LCD_SCL, 0);
	}
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

// Totally incomplete for now
static const uint8_t lcd_init_seq[] = {
	2, 0xc0, 0x23,  // PWCTRL1, VRH = 4.6V
	2, 0xc1, 0x10,  // PWCTRL2, minimum step-up factor (BT)
	0
};

void lcd_init()
{
	*GPIO_OUT = *GPIO_OUT
		& ~(
		(1ul << PIN_LCD_SCL) |
		(1ul << PIN_LCD_SDO) |
		(1ul << PIN_LCD_CS))
		| (1ul << PIN_LCD_CS);
	*GPIO_DIR |= 
		(1ul << PIN_LCD_SCL) |
		(1ul << PIN_LCD_SDO) |
		(1ul << PIN_LCD_CS) |
		(1ul << PIN_LCD_CS);

	gpio_fsel(PIN_LCD_SCL, 0);
	gpio_fsel(PIN_LCD_SDO, 0);
	gpio_fsel(PIN_LCD_CS, 0);
	gpio_fsel(PIN_LCD_DC, 0);

	// Software reset
	lcd_write_byte(0x01);
	delay_ms(5);

	const uint8_t *cmd = lcd_init_seq;

	while (*cmd)
	{
		lcd_write(cmd + 1, *cmd);
		cmd += *cmd + 1;
	}
}

int main()
{
	while (true)
	{
		delay_ms(100);
		lcd_init();
	}
}