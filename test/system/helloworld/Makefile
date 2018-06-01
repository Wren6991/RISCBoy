SRCS=$(HDL)/proc $(HDL)/busfabric $(HDL)/mem/ahb_sync_sram.v $(HDL)/mem/sram_sync.v $(HDL)/tbman $(HDL)/fpgaboy_core ../tb.v


include $(SCRIPTS)/sim.mk

test:
	$(MAKE) compile
	$(MAKE) sim > sim.log
	./test_script sim.log

compile:
	$(MAKE) -f $(SCRIPTS)/software.mk APPNAME=ram_init compile

clean::
	$(MAKE) -f $(SCRIPTS)/software.mk APPNAME=ram_init clean
	rm -f sim.log