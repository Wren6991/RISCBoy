DOTF=$(HDL)/hazard5/hazard5.f

KICAD_NET=$(PROJ_ROOT)/board/fpgaboy.net

chip.pcf:
	$(SCRIPTS)/extract_ref_nets $(PROJ_ROOT)/board/fpgaboy.net U1

include $(SCRIPTS)/synth.mk
