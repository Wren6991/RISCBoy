include $(SCRIPTS)/sim.mk

SYNTHDIR = $(PROJ_ROOT)/synth

.PHONY: synth
synth:
	$(MAKE) -C $(SYNTHDIR) dump
	cp $(SYNTHDIR)/riscboy_synth.v .

.PHONY: test
test: sim

clean::
	rm -f riscboy_synth.v
	$(MAKE) -C $(SYNTHDIR) clean