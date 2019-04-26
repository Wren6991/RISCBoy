# Must define:
# DOTF: .f file containing root of file list
# TOP: name of top-level module

srcs.mk: Makefile $(DOTF)
	$(SCRIPTS)/listfiles -f make $(DOTF) -o srcs.mk
-include srcs.mk

YOSYS=yosys
YOSYS_SMTBMC=$(YOSYS)-smtbmc

DEPTH=20

DEFINES?=

PREP_CMD =read_verilog -formal
PREP_CMD+=$(addprefix -I,$(INCDIRS))
PREP_CMD+=$(addprefix -D,$(DEFINES) )
PREP_CMD+= $(SRCS);
PREP_CMD+=prep -top $(TOP) -nordff; techmap -map +/adff2dff.v; write_smt2 -wires $(TOP).smt2

BMC_ARGS=-s z3 --dump-vcd $(TOP).vcd -t $(DEPTH)
IND_ARGS=-i $(BMC_ARGS)

.PHONY: prove prep bmc induct clean

prove: bmc induct

prep:
	$(YOSYS) -p "$(PREP_CMD)"

bmc: prep
	$(YOSYS_SMTBMC) $(BMC_ARGS) $(TOP).smt2

induct: prep
	$(YOSYS_SMTBMC) $(IND_ARGS) $(TOP).smt2

clean::
	rm -f $(TOP).vcd $(TOP).smt2 srcs.mk
