CHIPNAME=riscboy_icebreaker_dvi
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_icebreaker_dvi.f
BOOTAPP=riscboy_bootloader

DEVICE=up5k
PACKAGE=sg48
PNR_OPT=--pre-place $(CHIPNAME)_preplace.py --timing-allow-fail

include $(SCRIPTS)/synth_ice40.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) MARCH=rv32i CCFLAGS="-Os -DCLK_SYS_MHZ=14 -DFORCE_SRAM0_SIZE=131072 -DUART_BAUD=1000000"
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x20080000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f chip.pcf
	rm -f bootram_init*.hex

prog: bit
	iceprog $(CHIPNAME).bin
