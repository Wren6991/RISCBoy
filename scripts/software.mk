SRCS ?= $(wildcard *.c) $(wildcard *.S)
APPNAME ?= test

OBJS = $(patsubst %.c,%.o,$(patsubst %.S,%.o,$(SRCS)))

CROSS_PREFIX=riscv32-unknown-elf-
CC=$(CROSS_PREFIX)gcc
LD=$(CROSS_PREFIX)gcc
OBJCOPY=$(CROSS_PREFIX)objcopy
OBJDUMP=$(CROSS_PREFIX)objdump

MARCH?=rv32ic
LDSCRIPT?=memmap.ld
override CCFLAGS+=-c -march=$(MARCH) $(addprefix -I ,$(INCDIRS))
override CCFLAGS+=-Wall -Wextra -Wno-parentheses
override LDFLAGS+=-T $(LDSCRIPT)

# Override to -D to get all sections
DISASSEMBLE?=-d

.SUFFIXES:
.SECONDARY:
.PHONY: all clean
all: compile

%.o: %.c
	$(CC) $(CCFLAGS) $< -o $@

%.o: %.S
	$(CC) $(CCFLAGS) $< -o $@

$(APPNAME).elf: $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $(APPNAME).elf

%.bin: %.elf
	$(OBJCOPY) -O binary	 $< $@

%8.hex: %.elf
	$(OBJCOPY) -O verilog $< $@

%32.hex: %8.hex
	$(SCRIPTS)/vhexwidth -w 32 $< -o $@

$(APPNAME).dis: $(APPNAME).elf
	@echo ">>>>>>>>> Memory map:" > $(APPNAME).dis
	$(OBJDUMP) -h $(APPNAME).elf >> $(APPNAME).dis
	@echo >> $(APPNAME).dis
	@echo ">>>>>>>>> Disassembly:" >> $(APPNAME).dis
	$(OBJDUMP) $(DISASSEMBLE) $(APPNAME).elf >> $(APPNAME).dis


compile:: $(APPNAME)32.hex $(APPNAME).dis

clean::
	rm -f $(APPNAME).elf $(APPNAME)32.hex $(APPNAME)8.hex $(APPNAME).dis $(APPNAME).bin $(OBJS)
