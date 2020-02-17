YOSYS=yosys
NEXTPNR=nextpnr-ecp5
TRELLIS?=/usr/share/trellis

CHIPNAME?=chip
DEVICE?=um5g-85k
PACKAGE?=CABGA381

DEFINES+=FPGA FPGA_ECP5

SYNTH_OPT?=
PNR_OPT?=

SYNTH_CMD=read_verilog $(addprefix -I,$(INCDIRS)) $(addprefix -D,$(DEFINES)) $(SRCS);
ifneq (,$(TOP))
	SYNTH_CMD+=hierarchy -top $(TOP);
endif
SYNTH_CMD+=synth_ecp5 $(SYNTH_OPT) -json $(CHIPNAME).json

# Kill implicit rules
.SUFFIXES:
.IMPLICIT:

.PHONY: all romfiles synth clean program dump

all: bit

romfiles::
synth: romfiles $(CHIPNAME).json
dump: romfiles
pnr: synth $(CHIPNAME).config
bit: pnr $(CHIPNAME).bin $(CHIPNAME).svf

SRCS=$(shell $(SCRIPTS)/listfiles --relative -f flat $(DOTF))
INCDIRS=$(shell $(SCRIPTS)/listfiles --relative -f flati $(DOTF))

dump:
	$(YOSYS) -p "$(SYNTH_CMD); write_verilog $(CHIPNAME)_synth.v"

$(CHIPNAME).json: $(SRCS)
	@echo ">>> Synth"
	@echo
	$(YOSYS) -p "$(SYNTH_CMD)" > synth.log
	tail -n 35 synth.log


$(CHIPNAME).config: $(CHIPNAME).json $(CHIPNAME).lpf
	@echo ">>> Place and Route"
	@echo
	$(NEXTPNR) -r --placer sa --$(DEVICE) --package $(PACKAGE) --lpf $(CHIPNAME).lpf --json $(CHIPNAME).json --textcfg $@ $(PNR_OPT) --quiet --log pnr.log
	@grep "Info: Max frequency for clock " pnr.log | tail -n 1

$(CHIPNAME).bin: $(CHIPNAME).config
	@echo ">>> Generate Bitstream"
	@echo
	ecppack --svf $(CHIPNAME).svf $< $@

$(CHIPNAME).svf: $(CHIPNAME).bin

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
	$(NEXTPNR) --seed $1 --placer sa --$(DEVICE) --package $(PACKAGE) --lpf $(CHIPNAME).lpf --json $(CHIPNAME).json --textcfg pnr_try$1.config $(PNR_OPT) --quiet --log pnr$1.log
	@grep "Info: Max frequency for clock " pnr$1.log | tail -n 1
endef

$(foreach try,$(PNR_TRY_LIST),$(eval $(call make-sweep-target,$(try))))

clean::
	rm -f pnr_try*.asc pnr*.log