TEST?=$(shell basename $(PWD))

DOTF=../tb.f
SRCS=init.S $(TEST).c
APPNAME=ram_init

INCDIRS=../include
MARCH=rv32ic
# Disassemble all sections
DISASSEMBLE=-D

include $(SCRIPTS)/sim.mk
include $(SCRIPTS)/software.mk

test:
	$(MAKE) sim TEST=$(TEST) > sim.log
	./test_script sim.log

clean::
	rm -f sim.log