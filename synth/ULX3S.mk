CHIPNAME=riscboy_ulx3s
TOP=riscboy_fpga
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_ulx3s.f
BOOTAPP=riscboy_bootloader

SYNTH_OPT=-abc9

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) CCFLAGS="-Os -DFORCE_SRAM0_SIZE=131072 -DCLK_SYS_MHZ=50 -DSTAGE2_OFFS=0x90000"
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x00100000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f bootram_init*.hex

prog: bit
	ujprog $(CHIPNAME).bit

flash: bit
	ujprog -j flash $(CHIPNAME).bit
