# Stub makefile for the "tyre-kicking" testcases 
# e.g. fibonacci; simple litmus tests which are easy to debug.

include $(SCRIPTS)/sim.mk

ram_init32.hex: $(ASM_SRC)
	riscv32-unknown-elf-gcc -c -march=rv32ic $(ASM_SRC) -o $(ASM_SRC).elf
	riscv32-unknown-elf-objcopy -O verilog $(ASM_SRC).elf ram_init8.hex
	$(SCRIPTS)/vhexwidth -w 32 ram_init8.hex -o ram_init32.hex


test: ram_init32.hex
	$(MAKE) sim > sim.log
	./test_script sim.log

clean::
	rm -f $(ASM_SRC).elf ram_init8.hex ram_init32.hex sim.log