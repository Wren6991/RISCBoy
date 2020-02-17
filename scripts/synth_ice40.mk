YOSYS=yosys
NEXTPNR=nextpnr-ice40
CHIPNAME?=chip
DEVICE?=hx8k
PACKAGE?=bg121

DEFINES+=FPGA FPGA_ICE40

SYNTH_OPT?=
PNR_OPT?=

SYNTH_CMD=read_verilog $(addprefix -I,$(INCDIRS)) $(addprefix -D,$(DEFINES)) $(SRCS);
ifneq (,$(TOP))
	SYNTH_CMD+=hierarchy -top $(TOP);
endif
SYNTH_CMD+=synth_ice40 $(SYNTH_OPT); write_json $(CHIPNAME).json

# Kill implicit rules
.SUFFIXES:
.IMPLICIT:

.PHONY: all romfiles synth clean program dump

all: bit

romfiles::
synth: romfiles $(CHIPNAME).json
dump: romfiles
pnr: synth $(CHIPNAME).asc
bit: pnr $(CHIPNAME).bin

SRCS=$(shell $(SCRIPTS)/listfiles --relative -f flat $(DOTF))
INCDIRS=$(shell $(SCRIPTS)/listfiles --relative -f flati $(DOTF))

dump:
	$(YOSYS) -p "$(SYNTH_CMD); write_verilog $(CHIPNAME)_synth.v"

$(CHIPNAME).json: $(SRCS)
	@echo ">>> Synth"
	@echo
	$(YOSYS) -p "$(SYNTH_CMD)" > synth.log
	tail -n 35 synth.log


$(CHIPNAME).asc: $(CHIPNAME).json $(CHIPNAME).pcf
	@echo ">>> Place and Route"
	@echo
	$(NEXTPNR) -r --placer sa --$(DEVICE) --package $(PACKAGE) --pcf $(CHIPNAME).pcf --json $(CHIPNAME).json --asc $(CHIPNAME).asc $(PNR_OPT) --quiet --log pnr.log
	@grep "Info: Max frequency for clock " pnr.log | tail -n 1

$(CHIPNAME).bin: $(CHIPNAME).asc
	@echo ">>> Generate Bitstream"
	@echo
	icepack $(CHIPNAME).asc $(CHIPNAME).bin

clean::
	rm -f $(CHIPNAME).json $(CHIPNAME).asc $(CHIPNAME).bin $(CHIPNAME)_synth.v
	rm -f synth.log pnr.log

# Code for trying n different pnr seeds and reporting results

PNR_N_TRIES := 100
PNR_TRY_LIST := $(shell seq $(PNR_N_TRIES))

pnr_sweep: $(addprefix pnr_try,$(PNR_TRY_LIST))

define make-sweep-target
pnr_try$1: synth
	@echo ">>> Starting sweep $1"
	$(NEXTPNR) --seed $1 --placer sa --$(DEVICE) --package $(PACKAGE) --pcf $(CHIPNAME).pcf --json $(CHIPNAME).json --asc pnr_try$1.asc $(PNR_OPT) --quiet --log pnr$1.log
	@grep "Info: Max frequency for clock " pnr$1.log | tail -n 1
endef

$(foreach try,$(PNR_TRY_LIST),$(eval $(call make-sweep-target,$(try))))

clean::
	rm -f pnr_try*.asc pnr*.log

