INCDIRS+=$(PWD)
INCDIRS+=$(SOFTWARE)/include
LDSCRIPT=$(SOFTWARE)/memmap_2nd.ld
BUILD_DIR=$(SOFTWARE)/build

MARCH?=rv32ic

.PHONY: all
all:
	make -C $(BUILD_DIR) APPNAME=$(APPNAME) SRCS="$(SRCS)" INCDIRS="$(INCDIRS)" LDSCRIPT=$(LDSCRIPT) $(APPNAME).bin $(APPNAME).dis
	cp -f $(BUILD_DIR)/$(APPNAME).bin $(APPNAME).bin
	$(SCRIPTS)/mkflashexec $(BUILD_DIR)/$(APPNAME).bin $(APPNAME)_flash.bin

clean:
	make -C $(BUILD_DIR) APPNAME=$(APPNAME) SRCS="$(SRCS)" clean
	rm -f $(APPNAME)_flash.bin $(APPNAME).bin

prog: all
	uartprog -s 0x30000 -wr $(APPNAME)_flash.bin

exec: all
	uartprog -x $(APPNAME).bin
