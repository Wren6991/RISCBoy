#include "irq.h"
#include "tbman.h"
#include <stdbool.h>

HANDLER handle_load_misalign()
{
	uint32_t mepc;
	asm volatile ("csrrw %0, mepc, x0" : "=r" (mepc));

	uint32_t instr_lsbs = *(volatile uint16_t *)mepc;
	uint32_t instr_msbs = *(volatile uint16_t *)(mepc + 2);
	bool instr_is_32bit = !(~instr_lsbs & 0x3);
	tbman_puts("Handling misaligned load\n");
	tbman_putint(instr_lsbs | (instr_is_32bit ? instr_msbs << 16 : 0u));

	mepc += instr_is_32bit ? 4 : 2;
	asm volatile ("csrrw x0, mepc, %0" : : "r" (mepc));
}

HANDLER handle_store_misalign()
{
	uint32_t mepc;
	asm volatile ("csrrw %0, mepc, x0" : "=r" (mepc));

	uint32_t instr_lsbs = *(volatile uint16_t *)mepc;
	uint32_t instr_msbs = *(volatile uint16_t *)(mepc + 2);
	bool instr_is_32bit = !(~instr_lsbs & 0x3);
	tbman_puts("Handling misaligned store\n");
	tbman_putint(instr_lsbs | (instr_is_32bit ? instr_msbs << 16 : 0u));

	mepc += instr_is_32bit ? 4 : 2;
	asm volatile ("csrrw x0, mepc, %0" : : "r" (mepc));
}

int main()
{
	// The faulting instructions do not need a clobber list, as exception
	// hardware squashes the result!
	tbman_puts("Misaligned word load:\n");
	asm volatile ("lw a0, 2(x0)");
	tbman_puts("Misaligned halfword load:\n");
	asm volatile ("lh a0, 1(x0)");
	tbman_puts("Misaligned word store:\n");
	asm volatile ("sw a0, 2(x0)");
	tbman_puts("Misaligned halfword store:\n");
	asm volatile ("sh a0, 1(x0)");
	tbman_exit(0);
}
