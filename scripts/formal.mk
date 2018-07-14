# Must define:
# DOTF: .f file containing root of file list
# TOP: name of top-level module

srcs.mk: Makefile $(DOTF)
	$(SCRIPTS)/listfiles -f make $(DOTF) -o srcs.mk
-include srcs.mk

YOSYS=yosys
YOSYS_SMTBMC=$(YOSYS)-smtbmc
PREP_CMD="read_verilog -formal $(SRCS); prep -top $(TOP) -nordff; techmap -map +/adff2dff.v; write_smt2 -wires $(TOP).smt2"


BMC_ARGS=-s z3 --dump-vcd $(TOP).vcd
IND_ARGS=-i $(BMC_ARGS)

formal: clean
	$(YOSYS) -p $(PREP_CMD)
	$(YOSYS_SMTBMC) $(BMC_ARGS) $(TOP).smt2
	$(YOSYS_SMTBMC) $(IND_ARGS) $(TOP).smt2

clean::
	rm -f $(TOP).vcd $(TOP).smt2 srcs.mk
