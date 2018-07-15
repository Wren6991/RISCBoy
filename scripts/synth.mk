CHIPNAME?=chip
DEVICE?=1k
TIME_DEVICE?=hx$(DEVICE)
SYNTH_CMD="read_verilog -DFPGA $(SRCS); synth_ice40 -blif $(CHIPNAME).blif"

YOSYS=yosys
ARACHNE=arachne-pnr


# Kill implicit rules
.SUFFIXES:
.IMPLICIT:

.PHONY: all synth clean program

all: synth

srcs.mk: Makefile $(DOTF)
	$(SCRIPTS)/listfiles -f make -o srcs.mk $(DOTF)

-include srcs.mk

$(CHIPNAME).blif: $(SRCS)
	$(YOSYS) -p $(SYNTH_CMD)

$(CHIPNAME).asc: $(CHIPNAME).blif $(CHIPNAME).pcf
	$(ARACHNE) -d $(DEVICE) -p $(CHIPNAME).pcf -o $(CHIPNAME).asc $(CHIPNAME).blif

$(CHIPNAME).bin: $(CHIPNAME).asc
	icepack $(CHIPNAME).asc $(CHIPNAME).bin

synth: $(CHIPNAME).bin
	icetime -tmd $(TIME_DEVICE) $(CHIPNAME).asc

prog: $(CHIPNAME).bin
	iceprog $(CHIPNAME).bin

clean::
	rm -f $(CHIPNAME).blif $(CHIPNAME).asc $(CHIPNAME).bin
	rm -f srcs.mk