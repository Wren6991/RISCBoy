INCDIRS+=$(PWD)
INCDIRS+=$(SOFTWARE)/include
LDSCRIPT=$(SOFTWARE)/memmap_2nd.ld
BUILD_DIR=$(SOFTWARE)/build

MARCH=rv32ic

.PHONY: all
all:
	make -C $(BUILD_DIR) APPNAME=$(APPNAME) SRCS="$(SRCS)" INCDIRS="$(INCDIRS)" LDSCRIPT=$(LDSCRIPT) $(APPNAME).bin
	$(SCRIPTS)/mkflashexec $(BUILD_DIR)/$(APPNAME).bin $(APPNAME)_flash.bin

clean:
	make -C $(BUILD_DIR) APPNAME=$(APPNAME) SRCS="$(SRCS)" clean
	rm -f $(APPNAME)_flash.bin

prog: all
	uartprog -s 0x22000 -wr $(APPNAME)_flash.bin
