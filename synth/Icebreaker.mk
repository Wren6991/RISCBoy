CHIPNAME=riscboy_icebreaker
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_icebreaker.f
BOOTAPP=riscboy_bootloader

DEVICE=up5k
PACKAGE=sg48

include $(SCRIPTS)/synth_ice40.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) MARCH=rv32i CCFLAGS="-Os -DCLK_SYS_MHZ=12 -DFORCE_SRAM0_SIZE=131072 -DUART_BAUD=1000000"
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x00100000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f chip.pcf
	rm -f bootram_init*.hex

prog: bit
	iceprog $(CHIPNAME).bin
