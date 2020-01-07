CHIPNAME=riscboy_ecp5evn
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_ecp5evn.f
BOOTAPP=riscboy_bootloader

SYNTH_OPT=-retime

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) CCFLAGS=-Os
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x20080000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f bootram_init*.hex

prog: bit
	iceprog $(CHIPNAME).bin
