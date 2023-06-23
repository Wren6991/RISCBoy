TOP    := riscboy_sram_ctrl
DOTF   := $(HDL)/sram_ctrl/riscboy_sram_ctrl.f
TBEXEC := tb

.PHONY: clean all

all: $(TBEXEC)

SYNTH_CMD += read_verilog $(addprefix -I,$(shell listfiles -f flati $(DOTF))) $(shell listfiles $(DOTF));
SYNTH_CMD += chparam -set W_HADDR 6 $(TOP);
SYNTH_CMD += chparam -set W_SRAM_ADDR 5 $(TOP);
SYNTH_CMD += hierarchy -top $(TOP);
SYNTH_CMD += write_cxxrtl build/dut.cpp

build/dut.cpp: $(shell listfiles $(DOTF)) $(wildcard *.vh)
	mkdir -p build
	yosys -p '$(SYNTH_CMD)' 2>&1 > build/cxxrtl.log

clean::
	rm -rf build $(TBEXEC)

$(TBEXEC): build/dut.cpp tb.cpp
	clang++ -O3 -std=c++14 -I $(shell yosys-config --datdir)/include -I build tb.cpp -o $(TBEXEC)

test: $(TBEXEC)
	./tb