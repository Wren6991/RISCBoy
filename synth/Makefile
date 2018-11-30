DOTF=$(HDL)/riscboy_fpga/riscboy_fpga.f
KICAD_NET=$(PROJ_ROOT)/board/fpgaboy.net

DEVICE=hx8k
PACKAGE=bg121

include $(SCRIPTS)/synth_ice40.mk

chip.pcf:
	$(SCRIPTS)/extract_ref_nets $(PROJ_ROOT)/board/fpgaboy.net U1 --filter fpga_cfg

clean::
	rm -f chip.pcf
