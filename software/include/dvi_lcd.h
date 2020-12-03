#ifndef _DVI_LCD_H
#define _DVI_LCD_H

#include <stdbool.h>

#include "addressmap.h"
#include "hw/ppu_dispctrl_dvi_regs.h"

struct dvi_lcd_hw {
	io_rw_32 csr;
};

#define mm_dvi_lcd ((struct dvi_lcd_hw *const)DISP_BASE)

static inline void dvi_lcd_enable(bool en) {
	mm_dvi_lcd->csr = mm_dvi_lcd->csr & ~DISPCTRL_DVI_CSR_EN_MASK | (!!en << DISPCTRL_DVI_CSR_EN_LSB);
}

#endif
