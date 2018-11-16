SRCS ?= $(wildcard *.c) $(wildcard *.S)
APPNAME ?= test

OBJS = $(patsubst %.c,%.o,$(patsubst %.S,%.o,$(SRCS)))

CROSS_PREFIX=riscv32-unknown-elf-
CC=$(CROSS_PREFIX)gcc
LD=$(CROSS_PREFIX)gcc
OBJCOPY=$(CROSS_PREFIX)objcopy
OBJDUMP=$(CROSS_PREFIX)objdump

MARCH?=rv32ic
LDSCRIPT?=$(SCRIPTS)/memmap.ld
CCFLAGS?=-c -march=$(MARCH) $(addprefix -I ,$(INCDIRS))
LDFLAGS+=-T $(LDSCRIPT)

# Override to -D to get all sections
DISASSEMBLE ?= -d

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
	@echo ">>>>>>>>> Memory map:" > $(APPNAME).dis
	$(OBJDUMP) -h $(APPNAME).elf >> $(APPNAME).dis
	@echo >> $(APPNAME).dis
	@echo ">>>>>>>>> Disassembly:" >> $(APPNAME).dis
	$(OBJDUMP) $(DISASSEMBLE) $(APPNAME).elf >> $(APPNAME).dis


compile:: $(APPNAME).hex $(APPNAME).dis

clean::
	rm -f $(APPNAME).elf $(APPNAME).hex $(APPNAME).dis $(OBJS)