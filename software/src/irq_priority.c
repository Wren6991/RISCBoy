#include "irq.h"
#include "tbman.h"
#include <stdbool.h>

// Raise all 16 IRQs simultaneously.
// Check that all of the handlers run, in the correct priority order (lowest first)

#define N_IRQS 16

volatile int irq_order[N_IRQS];
volatile int n_irqs_received;

#define ACK_IRQ(irq) ISR(irq)() {*TBMAN_IRQ_FORCE &= ~(1ul << irq);\
	irq_order[n_irqs_received] = irq; ++n_irqs_received;}

ACK_IRQ(0);
ACK_IRQ(1);
ACK_IRQ(2);
ACK_IRQ(3);
ACK_IRQ(4);
ACK_IRQ(5);
ACK_IRQ(6);
ACK_IRQ(7);
ACK_IRQ(8);
ACK_IRQ(9);
ACK_IRQ(10);
ACK_IRQ(11);
ACK_IRQ(12);
ACK_IRQ(13);
ACK_IRQ(14);
ACK_IRQ(15);

int main()
{
	for (int i = 0; i < N_IRQS; ++i)
		external_irq_enable(i);
	global_irq_enable();

	n_irqs_received = 0;
	for (int i = 0; i < N_IRQS; ++ i)
		irq_order[i] = N_IRQS;

	tbman_puts("Raising all IRQs\n");
	*TBMAN_IRQ_FORCE = ~0u;

	while (n_irqs_received < N_IRQS)
		;

	tbman_puts("IRQs received. Checking order\n");
	bool failed = false;
	for (int i = 0; i < N_IRQS; ++i)
	{
		tbman_putint(irq_order[i]);
		failed |= irq_order[i] != i;
	}

	tbman_exit(failed);
}