DOTF=$(HDL)/riscboy_fpga/riscboy_fpga.f
KICAD_NET=$(PROJ_ROOT)/board/fpgaboy.net

DEVICE=8k

chip.pcf:
	$(SCRIPTS)/extract_ref_nets $(PROJ_ROOT)/board/fpgaboy.net U1 --filter fpga_cfg

clean::
	rm -f chip.pcf

include $(SCRIPTS)/synth.mk
