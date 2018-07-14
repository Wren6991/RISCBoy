DOTF=../tb.f

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