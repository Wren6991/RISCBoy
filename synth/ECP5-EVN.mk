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

SYNTH_OPT=-retime

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk


clean::
	rm -f prog.log

prog: bit
	openocd -f $(TRELLIS)/misc/openocd/ecp5-evn.cfg -c "transport select jtag; init; svf $(CHIPNAME).svf; exit" 2>&1 | tee prog.log | tail
