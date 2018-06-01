SRCS ?= $(wildcard *.c) $(wildcard *.S)
APPNAME ?= test

OBJS = $(patsubst %.c,%.o,$(patsubst %.S,%.o,$(SRCS)))

CROSS_PREFIX=riscv32-unknown-elf-
CC=$(CROSS_PREFIX)gcc
LD=$(CROSS_PREFIX)gcc
OBJCOPY=$(CROSS_PREFIX)objcopy
OBJDUMP=$(CROSS_PREFIX)objdump

LDSCRIPT=$(SCRIPTS)/memmap.ld
CCFLAGS=-c -march=rv32ic -O -nostartfiles
LDFLAGS=-T $(LDSCRIPT)

.SUFFIXES:
.PHONY: all clean
all: compile

%.o: %.c
	$(CC) $(CCFLAGS) $< -o $@

%.o: %.S
	$(CC) $(CCFLAGS) $< -o $@

$(APPNAME).elf: $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $(APPNAME).elf

$(APPNAME).hex: $(APPNAME).elf
	$(OBJCOPY) -O verilog $(APPNAME).elf $(APPNAME).hex

$(APPNAME).dis: $(APPNAME).elf
	$(OBJDUMP) -d $(APPNAME).elf > $(APPNAME).dis

compile: $(APPNAME).hex $(APPNAME).dis

clean::
	rm -f $(APPNAME).elf $(APPNAME).hex $(APPNAME).dis $(OBJS)