#ifndef _IRQ_H_
#define _IRQ_H_

#include <stdint.h>

#define IRQ_UART 0
#define IRQ_SPI  1

#define HANDLER void __attribute__((interrupt, section(".vectors"))) 

#define _ISR(irq) HANDLER isr_irq##irq
#define ISR(irq) _ISR(irq)
#define ISR_UART ISR(IRQ_UART)
#define ISR_SPI  ISR(IRQ_SPI)

static inline void global_irq_enable()
{
	// Set the global IRQ enable bit in mstatus (MIE)
	asm volatile ("csrrsi x0, mstatus, (1u << 3)");
	// Also set the master ExtIRQ enable (MEIE) in mie.
	// The per-IRQ masks in MSBs of mie are unchanged.
	const uint32_t mie_meie = 1u << 11;
	asm volatile ("csrrs x0, mie, %0" : : "r" (mie_meie));
}

static inline void global_irq_disable()
{
	// Clear mstatus.MIE
	asm volatile ("csrrci x0, mstatus, (1u << 3)");
}

static inline void external_irq_enable(int irq)
{
	uint32_t mask = 1u << (16 + irq);
	asm volatile ("csrrs x0, mie, %0" : : "r" (mask));
}

static inline void external_irq_disable(int irq)
{
	uint32_t mask = 1u << (16 + irq);
	asm volatile ("csrrs x0, mie, %0" : : "r" (mask));
}

#endif // _IRQ_H_
