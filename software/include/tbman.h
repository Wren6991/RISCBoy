#ifndef _TBMAN_H_
#define _TBMAN_H_

#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>

#include "addressmap.h"
#include "hw/tbman_regs.h"

#error "Don't use this header (old tbman)"

DECL_REG(TBMAN_BASE + TBMAN_PRINT_OFFS, TBMAN_PRINT);
DECL_REG(TBMAN_BASE + TBMAN_PUTINT_OFFS, TBMAN_PUTINT);
DECL_REG(TBMAN_BASE + TBMAN_EXIT_OFFS, TBMAN_EXIT);
DECL_REG(TBMAN_BASE + TBMAN_DEFINES_OFFS, TBMAN_DEFINES);
DECL_REG(TBMAN_BASE + TBMAN_STUB_OFFS, TBMAN_STUB);
DECL_REG(TBMAN_BASE + TBMAN_IRQ_FORCE_OFFS, TBMAN_IRQ_FORCE);

static inline void tbman_exit(uint32_t stat)
{
	*TBMAN_EXIT = stat;
}

static inline void tbman_putc(char c)
{
	*TBMAN_PRINT = c;
}

static inline void tbman_puts(const char *s)
{
	while (*s)
		*TBMAN_PRINT = *s++;
}

static inline void tbman_putint(uint32_t i)
{
	*TBMAN_PUTINT = i;
}

static inline void tbman_printf(const char *fmt, ...)
{
	char buf[128];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buf, 128, fmt, args);
	tbman_puts(buf);
	va_end(args);
}

static inline bool tbman_running_in_sim()
{
	return !!(*TBMAN_DEFINES & TBMAN_DEFINES_SIM_MASK);
}

static inline bool tbman_running_in_fpga()
{
	return !!(*TBMAN_DEFINES & TBMAN_DEFINES_FPGA_MASK);
}

#endif //_TBMAN_H_
