#include <stdint.h>

#define PERI_BASE (0x4 << 28)
#define TBMAN_BASE (PERI_BASE + 0xf000)

#define REG(addr, name) volatile uint32_t * (name) = (volatile uint32_t*)(addr)

REG(TBMAN_BASE, TBMAN_PRINT);
REG(TBMAN_BASE + 0x4, TBMAN_EXIT);

void tbman_puts(const char *s)
{
	while (*s)
		*TBMAN_PRINT = *s++;
}

void tbman_exit(uint32_t stat)
{
	*TBMAN_EXIT = stat;
}

int main()
{
	tbman_puts("Hello, world!\n");
	tbman_exit(123);
}