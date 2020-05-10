CHIPNAME=riscboy
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga.f
KICAD_NET=$(PROJ_ROOT)/board/fpgaboy.net

DEVICE=hx8k
PACKAGE=bg121

include $(SCRIPTS)/synth_ice40.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=blinky
	cp $(SOFTWARE)/build/blinky8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x20080000 -o bootram_init32.hex

# Regenerate pin constraints from the most recent schematics
riscboy.pcf:
	$(SCRIPTS)/extract_ref_nets $(PROJ_ROOT)/board/fpgaboy.net U1 --filter fpga_cfg -o riscboy.pcf

clean::
	make -C $(SOFTWARE)/build APPNAME=blinky clean
	rm -f chip.pcf
	rm -f bootram_init*.hex
