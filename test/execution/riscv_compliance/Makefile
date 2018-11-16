# You should override this via command line
TEST=I-ADD-01

ARCH=rv32i
ARCH_DIR=riscv-compliance/riscv-test-suite/$(ARCH)
SRC_DIR=$(ARCH_DIR)/src
REF_DIR=$(ARCH_DIR)/references

# The architecture passed to the compiler/assembler
# (some tests depend on the size/alignment of instructions so must be RV32I instead)
MARCH=rv32ic

# Check out the relevant files, and a standard sub makefile, into their own directory.
# Then call into this makefile, to build the simulator and assemble/run the test code.
# It's disgusting but keeps sim tools from imploding when you try to start multiple tests concurrently.

.PHONY: all make_dir compile sim test clean
all: sim

mkdir:
	mkdir -p $(TEST)
	cp -f $(SRC_DIR)/$(TEST).S $(TEST)/$(TEST).S
	cp -f $(REF_DIR)/$(TEST).reference_output $(TEST)/$(TEST).ref
	cp -f subdir_makefile $(TEST)/Makefile

compile: mkdir
	$(MAKE) -C $(TEST) TEST=$(TEST) MARCH=$(MARCH) compile

sim: compile
	$(MAKE) -C $(TEST) TEST=$(TEST) sim

gui: compile
	$(MAKE) -C $(TEST) TEST=$(TEST) gui

test: compile
	$(MAKE) -C $(TEST) TEST=$(TEST) test

clean:
	rm -rf $(TEST)
