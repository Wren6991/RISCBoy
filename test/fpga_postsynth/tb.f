file ../riscboy_fpga/tb.v
file riscboy_synth.v

# Need to pull in the sim lib for iCE40 primitives
# Get the path with  $(yosys-config --datdir/ice40/cells_sim.v)
file /usr/local/share/yosys/ice40/cells_sim.v