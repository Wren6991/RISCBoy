#include "tb_cxxrtl_io.h"

volatile int flag;

void __attribute__((interrupt)) handle_ecall()
{
	tb_puts("Handling ECALL\n");
	flag = 0;

	// mepc contains the address of ecall itself; increment before return
	uint32_t mepc_val;
	asm volatile ("csrrc %0, mepc, x0" : "=r" (mepc_val));
	mepc_val += 4;
	asm volatile ("csrrw x0, mepc, %0" : : "r" (mepc_val));
}

int main()
{
	// Fail by default
	flag = 1;
	// Should clear flag:
	tb_puts("Raising ECALL\n");
	asm volatile("ecall");
	// Return flag to testbench environment
	tb_exit(flag);
}

