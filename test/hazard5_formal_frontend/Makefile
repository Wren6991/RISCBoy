TOP=tb
DOTF=tb.f
DEFINES=HAZARD5_FORMAL_REGRESSION HAZARD5_FRONTEND_ASSERTIONS

include $(SCRIPTS)/formal.mk

NEWLOG = $(shell [ induct.log -nt bmc.log ] && echo induct.log || echo bmc.log)

disasm:
	grep "Value for anyconst in tb.dut (hazard5_formal_regression.vh:35)" $(NEWLOG) | sed 's/^.*:/.hword/' > disasm.s
	riscv32-unknown-elf-gcc -c disasm.s -o disasm.o
	riscv32-unknown-elf-objdump -d  disasm.o

clean::
	rm -f disasm.s disasm.o