CHIPNAME=riscboy_ecp5evn
TOP=riscboy_fpga
BUILD=mini
ifeq ($(BUILD),full)
    DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_ecp5evn.f
   	BOOTAPP=riscboy_bootloader
else
    DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_ecp5evn_mini.f
    BOOTAPP=blinky
endif

SYNTH_OPT=-abc9

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) CCFLAGS="-Os -DFORCE_SRAM0_SIZE=262144"
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x20080000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f bootram_init*.hex
	rm -f prog.log

prog: bit
	openocd -f $(TRELLIS)/misc/openocd/ecp5-evn.cfg -c "transport select jtag; init; svf $(CHIPNAME).svf; exit" 2>&1 | tee prog.log | tail
