TOP ?= tb
DOTF ?= $(TOP).f
SIMNAME?=simulation

SIM_VARS = PLATFORM=lin64 LD_LIBRARY_PATH=$XILINX/lib/$PLATFORM
FUSE ?= $(SIM_VARS) fuse
SIMSCRIPT ?= $(SCRIPTS)/sim_run.tcl
GUISCRIPT ?= $(SCRIPTS)/gui_run.tcl

# Kill implicit rules
.SUFFIXES:
.IMPLICIT:

sim: build
	(cd sim; $(SIM_VARS) ./$(SIMNAME) -tclbatch $(SIMSCRIPT))

gui: build
	(cd sim; $(SIM_VARS) ./$(SIMNAME) -gui -tclbatch $(GUISCRIPT))

build:
	mkdir -p sim
	$(SCRIPTS)/listfiles --relative -f isim $(DOTF) -o sim.prj
	(cd sim; $(FUSE) -d SIM -prj ../sim.prj $(TOP) -o $(SIMNAME))

clean::
	rm -rf sim sim.prj