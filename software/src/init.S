#include "addressmap.h"

#define COLLAPSE_WEAK_HANDLERS

.section .vectors

.macro VEC name:req
.align 2
j \name
.endm

// ----------------------------------------------------------------------------
// Vector table
.vector_table:

// Exceptions

	VEC handle_instr_misalign
	VEC handle_instr_fault
	VEC handle_instr_illegal
	VEC handle_breakpoint
	VEC handle_load_misalign
	VEC handle_load_fault
	VEC handle_store_misalign
	VEC handle_store_fault
	VEC .halt
	VEC .halt
	VEC .halt
	VEC handle_ecall
	VEC .halt
	VEC .halt
	VEC .halt
	VEC .halt

// Standard interrupts
// Note: global EIRQ does not fire. Instead we have 16 separate vectors

	VEC .halt
	VEC .halt
	VEC .halt
	VEC isr_machine_softirq
	VEC .halt
	VEC .halt
	VEC .halt
	VEC isr_machine_timer
	VEC .halt
	VEC .halt
	VEC .halt
	VEC .halt
	VEC .halt
	VEC .halt
	VEC .halt
	VEC .halt

// External interrupts

	VEC isr_irq0
	VEC isr_irq1
	VEC isr_irq2
	VEC isr_irq3
	VEC isr_irq4
	VEC isr_irq5
	VEC isr_irq6
	VEC isr_irq7
	VEC isr_irq8
	VEC isr_irq9
	VEC isr_irq10
	VEC isr_irq11
	VEC isr_irq12
	VEC isr_irq13
	VEC isr_irq14
	VEC isr_irq15


// ----------------------------------------------------------------------------
// Reset handler

.reset_handler:
	li sp, SRAM1_BASE + SRAM1_SIZE
	la t0, .vector_table
	csrw mtvec, t0
	jal _start
	j .halt


// ----------------------------------------------------------------------------
// Weak handler/ISR symbols
//
// If COLLAPSE_WEAK_HANDLERS is set, these all point to a single halt loop.
// Otherwise there is a halt loop per handler, which can ease debugging.
// To install your own handler, simply create a handler with one of these names,
// and link it.

.macro weak_handler name:req
.global \name
.type \name,%function
.weak \name
\name:
#ifndef COLLAPSE_WEAK_HANDLERS
1:
	j 1b
#endif
.endm

.global .halt
.type .halt,%function
#ifdef COLLAPSE_WEAK_HANDLERS
.halt:
#endif
weak_handler handle_instr_misalign
weak_handler handle_instr_fault
weak_handler handle_instr_illegal
weak_handler handle_breakpoint
weak_handler handle_load_misalign
weak_handler handle_load_fault
weak_handler handle_store_misalign
weak_handler handle_store_fault
weak_handler handle_ecall
weak_handler isr_machine_softirq
weak_handler isr_machine_timer
weak_handler isr_irq0
weak_handler isr_irq1
weak_handler isr_irq2
weak_handler isr_irq3
weak_handler isr_irq4
weak_handler isr_irq5
weak_handler isr_irq6
weak_handler isr_irq7
weak_handler isr_irq8
weak_handler isr_irq9
weak_handler isr_irq10
weak_handler isr_irq11
weak_handler isr_irq12
weak_handler isr_irq13
weak_handler isr_irq14
weak_handler isr_irq15

#ifndef COLLAPSE_WEAK_HANDLERS
.halt:
#endif
	j .halt