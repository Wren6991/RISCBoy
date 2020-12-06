.PHONY: clean tb all

all: tb

dut.cpp:
	yosys -p "read_verilog -I $(HDL)/graphics/ppu2 $(shell listfiles $(HDL)/graphics/ppu2/riscboy_ppu.f); prep -flatten -top riscboy_ppu; async2sync; write_cxxrtl dut.cpp" 2>&1 > cxxrtl.log

clean::
	rm -f dut.cpp cxxrtl.log

tb: dut.cpp
	clang++ -O3 -std=c++14 -I $(shell yosys-config --datdir)/include -I $(SOFTWARE)/include tb.cpp -o tb
