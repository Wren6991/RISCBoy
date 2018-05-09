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

The simulation flow is driven by Xilinx ISIM 14.x; makefiles are found in the scripts/ folder. This has only been tested with the Linux version of ISIM. The ISIM installer failed due to permissions on my Ubuntu 17.04 installation, and I had to manually create the directory /opt/Xilinx and chmod/chown it.

Once ISIM is installed, you should be able to do the following:

```
cd fpgaboy
. sourceme
cd test
./runtests
```

which will run all of the HDL-level tests. You may need to adjust some of the paths in `sourceme` if ISIM is installed in a non-default location. To debug a test graphically, run its makefile directly:

```
cd ahbl_arbiter
make gui
```