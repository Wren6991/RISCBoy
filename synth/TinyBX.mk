CHIPNAME=riscboy_tinybx
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_tinybx.f
BOOTAPP=blinky

SYNTH_OPT=-retime

DEVICE=lp8k
PACKAGE=cm81

include $(SCRIPTS)/synth_ice40.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) CCFLAGS=-Os
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x20080000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f chip.pcf
	rm -f bootram_init*.hex

prog: bit
	tinyprog -p $(CHIPNAME).bin
