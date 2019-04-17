SRC_DIR=../src
SRCS=$(SRC_DIR)/init.S $(SRC_DIR)/$(APPNAME).c
INCDIRS=../include
LDSCRIPT=../memmap_boot.ld

MARCH=rv32ic
# Disassemble all sections
DISASSEMBLE=-D

include $(SCRIPTS)/software.mk
