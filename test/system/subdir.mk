TEST?=$(shell basename $(PWD))

DOTF=../tb.f
SRCS=init.S $(TEST).c

INCDIRS=../include
MARCH=rv32ic
# Disassemble all sections
DISASSEMBLE=-D

include $(SCRIPTS)/sim.mk

compile:
	make -C $(SOFTWARE)/build APPNAME=$(TEST)
	cp $(SOFTWARE)/build/$(TEST).hex ram_init8.hex
	$(SCRIPTS)/vhexwidth -w 32 ram_init8.hex -o ram_init32.hex

test:
	$(MAKE) sim TEST=$(TEST) > sim.log
	./test_script sim.log

clean::
	rm ram*.hex
	make -C $(SOFTWARE)/build APPNAME=$(TEST) clean
	rm -f sim.log