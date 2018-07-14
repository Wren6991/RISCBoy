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

int main()
{
	// volatile to avoid constant folding
	volatile float a = 2.25f;
	volatile float b = 12.f;
	volatile float c = a * b / 1.3f;
	tbman_exit((uint32_t)c);
}