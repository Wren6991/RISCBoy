FPGABoy
=======

FPGABoy is an open-source portable games console, designed from scratch. This includes:

- A RISC-V compatible CPU
- A simple graphics pipeline (on the level of a Gameboy Advance) and display controller
- Other chip infrastructure: busfabric, memory controllers, UART, GPIO etc.
- A PCB layout in KiCad

![](doc/diagrams/system_arch.png)

The design is written in synthesisable Verilog 2001, and is intended to fit onto an iCE40-HX8k FPGA. This is the largest FPGA targetable by the open-source iCEStorm FPGA toolchain, but is still fairly austere (7680 LUT4s and flipflops), so some compromises are needed to squeeze our logic in.

More detailed information can be found in the [documentation](doc/fpgaboy_doc.pdf). Please note that, whilst development is in an early stage, this document describes the project in past or present tense, so that I don't have to rewrite it later.

Building RV32IC Toolchain
-------------------------

Follow the instructions on the [RISC-V GNU Toolchain GitHub](https://github.com/riscv/riscv-gnu-toolchain), except for the configure line:

```
./configure --prefix=/opt/riscv --with-arch=rv32ic --with-abi=ilp32
sudo mkdir /opt/riscv
sudo chown $(whoami) /opt/riscv
make -j $(nproc)
```

Simulation
----------

The simulation flow is driven by Xilinx ISIM 14.x; makefiles are found in the scripts/ folder. This has only been tested with the Linux version of ISIM.

Once ISIM is installed, you should be able to do the following:

```
. sourceme
cd test
./runtests
```

which will run all of the HDL-level tests. Software tests will require the RV32IC toolchain. You may need to adjust some of the paths in `sourceme` if ISIM is installed in a non-default location. To graphically debug a test, run its makefile directly:

```
cd system
make TEST=helloworld gui
```

PCB
---

The PCB is still a work in progress. It should be compatible with iTead's 4-layer 5x5 cm prototyping service, which currently costs $65 for 10 boards.

The schematic can be viewed [here (pdf)](board/fpgaboy.pdf)