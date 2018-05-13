SRCS=$(HDL)/proc/revive_cpu.v $(HDL)/proc/revive_alu.v $(HDL)/proc/revive_instr_decompress.v $(HDL)/proc/regfile_1w2r.v $(HDL)/mem/ahb_sync_sram.v $(HDL)/mem/sram_sync.v ../tb.v
ASM_SRC=loadstore.S

include $(SCRIPTS)/sim.mk


ram_init.hex: $(ASM_SRC)
	riscv32-unknown-elf-gcc -c -march=rv32ic $(ASM_SRC) -o $(ASM_SRC).elf
	riscv32-unknown-elf-objcopy -O verilog $(ASM_SRC).elf ram_init.hex

test: ram_init.hex
	$(MAKE) sim > sim.log
	./test_script sim.log

clean::
	rm -f $(ASM_SRC).elf ram_init.hex sim.log