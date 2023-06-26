CHIPNAME=riscboy_hx8kevn
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_hx8kevn.f
TOP=riscboy_fpga
BOOTAPP=riscboy_bootloader

SYNTH_OPT=
PNR_OPT=--freq 48 --timing-allow-fail
DEVICE=hx8k
PACKAGE=ct256

include $(SCRIPTS)/synth_ice40.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) CCFLAGS=-Os
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x00100000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f bootram_init*.hex

prog: bit
	iceprog $(CHIPNAME).bin
