CHIPNAME=riscboy_hx8kevn
DOTF=$(HDL)/riscboy_fpga/riscboy_fpga_ecp5evn_mini.f
TOP=riscboy_fpga
BOOTAPP=blinky

SYNTH_OPT=-retime

DEVICE=hx8k
PACKAGE=ct256

include $(SCRIPTS)/synth_ice40.mk

prog: bit
	iceprog $(CHIPNAME).bin
