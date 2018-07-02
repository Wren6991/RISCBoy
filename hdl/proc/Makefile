MODNAME=revive_cpu
SRCS=revive_cpu.v revive_instr_decompress.v revive_alu.v regfile_1w2r.v shift_rla.v

YOSYS=yosys
YOSYS_SMTBMC=$(YOSYS)-smtbmc

PREP_CMD="read_verilog -formal $(SRCS); prep -top $(MODNAME) -nordff; techmap -map +/adff2dff.v; write_smt2 -wires $(MODNAME).smt2"

BMC_ARGS=-s z3 --dump-vcd $(MODNAME).vcd
IND_ARGS=-i $(BMC_ARGS)

formal: clean
	$(YOSYS) -p $(PREP_CMD)
	$(YOSYS_SMTBMC) $(BMC_ARGS) $(MODNAME).smt2
	$(YOSYS_SMTBMC) $(IND_ARGS) $(MODNAME).smt2
clean:
	rm -f $(MODNAME).vcd $(MODNAME).smt2
