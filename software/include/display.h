#ifndef _DISPLAY_H
#define _DISPLAY_H

#include "spi_lcd.h"
#include "dvi_lcd.h"
#include "ppu.h"
#include "tb_cxxrtl_io.h"

// Header file for doing common things to SPI/DVI display controllers, without
// having to be aware of which of the two you have

#ifndef SPI_LCD_INIT_SEQ
#define SPI_LCD_INIT_SEQ ili9341_init_seq
#endif

#ifndef DISPLAY_WIDTH
#define DISPLAY_WIDTH 320
#endif

#ifndef DISPLAY_HEIGHT
#define DISPLAY_HEIGHT 240
#endif

// Display controllers have a constant, read-only field in a fixed location,
// so software can determine which type of display interface is present in
// the current hardware build

typedef enum {
	DISPCTRL_TYPE_SPI = 0,
	DISPCTRL_TYPE_DVI = 1
} dispctrl_type_t;

static inline dispctrl_type_t get_dispctrl_type() {
	return (*(io_rw_32 *const)DISP_BASE) >> 28;
}

static inline void display_init() {
	mm_ppu->dispsize =
		((DISPLAY_WIDTH  - 1) << PPU_DISPSIZE_W_LSB) |
		((DISPLAY_HEIGHT - 1) << PPU_DISPSIZE_H_LSB);
	dispctrl_type_t disptype = get_dispctrl_type();
	if (disptype == DISPCTRL_TYPE_SPI) {
		// This takes a looooooooooooooong time in sim
		if (!tb_running_in_sim())
			spi_lcd_init(SPI_LCD_INIT_SEQ);
		spi_lcd_set_disp_width(DISPLAY_WIDTH);
	}
	else if (disptype == DISPCTRL_TYPE_DVI) {
		// Nothing to do here -- we won't start it until the first frame starts
		// rendering, to avoid bottoming out
	}
}

static inline void display_wait_frame_end() {
	while (mm_ppu->csr & PPU_CSR_RUNNING_MASK)
		;
}

static inline void display_start_frame() {
	dispctrl_type_t disptype = get_dispctrl_type();
	if (disptype == DISPCTRL_TYPE_SPI) {
		spi_lcd_wait_idle();
		spi_lcd_force_dc_cs(1, 1);
		spi_lcd_start_pixels();
	}
	else if (disptype == DISPCTRL_TYPE_DVI) {
		// Just make sure it's running. Always begins at top of vblank when enable
		// goes 0->1, so there is enough time to get the first scanline ready
		dvi_lcd_enable(true);
	}
	mm_ppu->csr = PPU_CSR_HALT_VSYNC_MASK | PPU_CSR_RUN_MASK;
}

#endif
