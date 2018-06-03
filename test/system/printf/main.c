#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>

#define PERI_BASE (0x4 << 28)
#define TBMAN_BASE (PERI_BASE + 0xf000)

#define REG(addr, name) volatile uint32_t * (name) = (volatile uint32_t*)(addr)

REG(TBMAN_BASE, TBMAN_PRINT);
REG(TBMAN_BASE + 0x4, TBMAN_EXIT);

void tbman_exit(uint32_t stat)
{
	*TBMAN_EXIT = stat;
}

void tbman_puts(const char *s)
{
	while (*s)
		*TBMAN_PRINT = *s++;
}

void tbman_printf(const char *fmt, ...)
{
	char buf[128];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buf, 128, fmt, args);
	tbman_puts(buf);
	va_end(args);
}

int main()
{
	tbman_puts("Starting\n");
	tbman_printf("Abc\n");
	//tbman_printf("Printing int: %d\n", 1234);
	//tbman_printf("Printing float: %f\n", 3.142f);
	tbman_exit(0);
}