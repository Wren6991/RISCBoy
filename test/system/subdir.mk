TEST?=$(notdir $(PWD))

DOTF=../tb.f
SRCS=init.S $(TEST).c

INCDIRS=../include
MARCH=rv32ic
LDSCRIPT=../memmap_2nd.ld
# Disassemble all sections
DISASSEMBLE=-D

include $(SCRIPTS)/sim.mk

compile:
	make -C $(SOFTWARE)/build APPNAME=$(TEST) LDSCRIPT=$(LDSCRIPT)
	cp $(SOFTWARE)/build/$(TEST)8.hex ram_init8.hex
	$(SCRIPTS)/vhexwidth -w 16 -b 0x20000000 ram_init8.hex -o ram_init16.hex
	$(SCRIPTS)/vhexwidth -w 32 -b 0x20000000 ram_init8.hex -o ram_init32.hex

test:
	$(MAKE) sim TEST=$(TEST) > sim.log
	./test_script sim.log

clean::
	rm -f ram*.hex
	make -C $(SOFTWARE)/build APPNAME=$(TEST) clean
	rm -f sim.log
