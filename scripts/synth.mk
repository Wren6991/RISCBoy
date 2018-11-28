YOSYS=yosys
ARACHNE=arachne-pnr
CHIPNAME?=chip
DEVICE?=1k
TIME_DEVICE?=hx$(DEVICE)
PACKAGE?=tq144

DEFINES+=FPGA TRISTATE_ICE40

SYNTH_CMD=read_verilog $(addprefix -D,$(DEFINES)) $(SRCS); 
ifneq (,$(TOP))
	SYNTH_CMD+=hierarchy -top $(TOP); 
endif
SYNTH_CMD+=synth_ice40 -blif $(CHIPNAME).blif

# Kill implicit rules
.SUFFIXES:
.IMPLICIT:

.PHONY: all synth clean program

all: synth

srcs.mk: Makefile $(DOTF)
	$(SCRIPTS)/listfiles --relative -f make -o srcs.mk $(DOTF)

-include srcs.mk

$(CHIPNAME).blif: $(SRCS)
	$(YOSYS) -p "$(SYNTH_CMD)"

$(CHIPNAME).asc: $(CHIPNAME).blif $(CHIPNAME).pcf
	$(ARACHNE) -d $(DEVICE) -P $(PACKAGE) -p $(CHIPNAME).pcf -o $(CHIPNAME).asc $(CHIPNAME).blif

$(CHIPNAME).bin: $(CHIPNAME).asc
	icepack $(CHIPNAME).asc $(CHIPNAME).bin

synth: $(CHIPNAME).bin
	icetime -tmd $(TIME_DEVICE) $(CHIPNAME).asc

prog: $(CHIPNAME).bin
	iceprog $(CHIPNAME).bin

clean::
	rm -f $(CHIPNAME).blif $(CHIPNAME).asc $(CHIPNAME).bin
	rm -f srcs.mk