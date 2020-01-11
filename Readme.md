Area Repro
==========

RISCBoy is significantly larger (in LUT4s) on ECP5 than on iCE40. This seems particularly true for the processor. To reproduce:

```
git clone --branch area_difference_repro --depth 1 https://github.com/Wren6991/RISCBoy.git riscboy
cd riscboy
. sourceme
cd synth
make -f HX8k-EVN.mk bit
make -f ECP5-EVN.mk bit
```

The two `make` command lines push identical RTL through build scripts for Lattice HX8k evaluation board and Lattice ECP5 evaluation board (*not* Versa, but the other EVN board) respectively. The RTL contains a tiny SoC with processor, 8 kiB of preloaded memory and some GPIO registers.

To confirm this works, you can replace the `make bit` target with `make prog`, and you should get a blinking LED. (Unfortunately the LEDs are inverted on the HX8k board.)

A prebuilt hex file has been included for blinky firmware, so no need for RISC-V toolchain. You will need:

- Yosys
- nextpnr-ice40
- nextpnr-ecp5

From Yosys I get these cell counts for iCE40:

```
=== riscboy_fpga ===

   Number of wires:               2947
   Number of wire bits:           8561
   Number of public wires:        2947
   Number of public wire bits:    8561
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:               3091
     SB_CARRY                      172
     SB_DFF                        162
     SB_DFFE                       269
     SB_DFFER                      196
     SB_DFFES                        4
     SB_DFFR                       101
     SB_DFFS                         9
     SB_LUT4                      2158
     SB_RAM40_4K                    20
```

And these for ECP5:

```
=== riscboy_fpga ===

   Number of wires:               5573
   Number of wire bits:           9076
   Number of public wires:        5573
   Number of public wire bits:    9076
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:               5517
     CCU2C                          92
     DP16KD                          4
     L6MUX21                       338
     LUT4                         3399
     PFUMX                         863
     TRELLIS_DPR16X4                32
     TRELLIS_FF                    789
```
