#ifndef _TB_CXXRTL_IO_H
#define _TB_CXXRTL_IO_H

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

// ----------------------------------------------------------------------------
// Testbench IO hardware layout

#include "addressmap.h"

typedef struct {
	volatile uint32_t print_char;
	volatile uint32_t print_u32;
	volatile uint32_t exit;
	volatile uint32_t running_in_sim;
} io_hw_t;

#define mm_io ((io_hw_t *const)TBMAN_BASE)

// ----------------------------------------------------------------------------
// Testbench IO convenience functions

static inline void tb_putc(char c) {
	mm_io->print_char = (uint32_t)c;
}

static inline void tb_puts(const char *s) {
	while (*s)
		mm_io->print_char = *s++;
}

static inline void tb_put_u32(uint32_t x) {
	mm_io->print_u32 = x;
}

static inline void tb_exit(uint32_t ret) {
	mm_io->exit = ret;
}

static inline bool tb_running_in_sim() {
	return !!mm_io->running_in_sim;
}

#ifndef PRINTF_BUF_SIZE
#define PRINTF_BUF_SIZE 256
#endif

static inline void tb_printf(const char *fmt, ...) {
	char buf[PRINTF_BUF_SIZE];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buf, PRINTF_BUF_SIZE, fmt, args);
	tb_puts(buf);
	va_end(args);
}

#define tb_assert(cond, ...) if (!(cond)) {tb_printf(__VA_ARGS__); tb_exit(-1);}

#endif
