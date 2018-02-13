CHIPNAME?=chip
DEVICE?=1k
TIME_DEVICE?=hx$(DEVICE)
SYNTH_CMD="synth_ice40 -blif $(CHIPNAME).blif"

YOSYS=yosys
ARACHNE=arachne-pnr


# Kill implicit rules
.SUFFIXES:
.IMPLICIT:

.PHONY: all synth clean program

all: synth

$(CHIPNAME).blif: $(SRCS)
	$(YOSYS) -p $(SYNTH_CMD) $(SRCS)

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