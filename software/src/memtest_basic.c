#include "addressmap.h"
#include "tbman.h"

#include <stdint.h>

volatile uint32_t *mem = (volatile uint32_t *)SRAM0_BASE;

const int TESTSIZE_BYTES = 1024;
const uint32_t RAND_SEED = 12345;

// Don't have room for libc stuff
uint32_t rand_state;

static inline uint32_t randu()
{
	rand_state = rand_state * 1103515245 + 12345;
	return rand_state;
}

int main()
{
	tbman_puts("Byte write random\n");
	rand_state = RAND_SEED;
	for (int i = 0; i < TESTSIZE_BYTES; ++i)
		((volatile uint8_t*)mem)[i] = randu();
	tbman_puts("Readback\n");
	rand_state = RAND_SEED;
	for (int i = 0; i < TESTSIZE_BYTES; ++i)
	{
		uint8_t actual = ((volatile uint8_t*)mem)[i];
		uint8_t expected = randu();
		if (actual != expected)
		{
			tbman_puts("Mismatch at addr\n");
			tbman_putint((uint32_t)&((uint8_t*)mem)[i]);
			tbman_puts("expected\n");
			tbman_putint(expected);
			tbman_puts("actual\n");
			tbman_putint(actual);
			tbman_exit(-1);
		}
	}

	tbman_puts("Halfword write random\n");
	rand_state = RAND_SEED;
	for (int i = 0; i < TESTSIZE_BYTES / sizeof(uint16_t); ++i)
		((volatile uint16_t*)mem)[i] = randu();
	tbman_puts("Readback\n");
	rand_state = RAND_SEED;
	for (int i = 0; i < TESTSIZE_BYTES / sizeof(uint16_t); ++i)
	{
		uint16_t actual = ((volatile uint16_t*)mem)[i];
		uint16_t expected = randu();
		if (actual != expected)
		{
			tbman_puts("Mismatch at addr\n");
			tbman_putint((uint32_t)&((uint16_t*)mem)[i]);
			tbman_puts("expected\n");
			tbman_putint(expected);
			tbman_puts("actual\n");
			tbman_putint(actual);
			tbman_exit(-1);
		}
	}
	
	tbman_puts("Word write random\n");
	rand_state = RAND_SEED;
	for (int i = 0; i < TESTSIZE_BYTES / sizeof(uint32_t); ++i)
		((volatile uint32_t*)mem)[i] = randu();
	tbman_puts("Readback\n");
	rand_state = RAND_SEED;
	for (int i = 0; i < TESTSIZE_BYTES / sizeof(uint32_t); ++i)
	{
		uint32_t actual = ((volatile uint32_t*)mem)[i];
		uint32_t expected = randu();
		if (actual != expected)
		{
			tbman_puts("Mismatch at addr\n");
			tbman_putint((uint32_t)&((uint32_t*)mem)[i]);
			tbman_puts("expected\n");
			tbman_putint(expected);
			tbman_puts("actual\n");
			tbman_putint(actual);
			tbman_exit(-1);
		}
	}
	
	tbman_exit(0);
}