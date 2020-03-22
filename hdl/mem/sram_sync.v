/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2018 Luke Wren                                       *
 *                                                                    *
 * Everyone is permitted to copy and distribute verbatim or modified  *
 * copies of this license document and accompanying software, and     *
 * changing either is allowed.                                        *
 *                                                                    *
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION  *
 *                                                                    *
 * 0. You just DO WHAT THE FUCK YOU WANT TO.                          *
 * 1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.             *
 *                                                                    *
 *********************************************************************/

// Generate a (hopefully inference-compatible) memory with synchronous
// read/write, and optional per-byte write enable

module sram_sync #(
	parameter WIDTH = 32,
	parameter DEPTH = 1 << 11,
	parameter BYTE_ENABLE = 0,
	parameter PRELOAD_FILE = "",
	parameter ADDR_WIDTH = $clog2(DEPTH) // Let this default
) (
	input wire                                     clk,
	input wire [(BYTE_ENABLE ? WIDTH / 8 : 1)-1:0] wen,
	input wire [ADDR_WIDTH-1:0]                    addr,
	input wire [WIDTH-1:0]                         wdata,
	output reg [WIDTH-1:0]                         rdata
);

`ifdef FPGA_ICE40
localparam FPGA_ICE40_DEFINED = 1;
`else
localparam FPGA_ICE40_DEFINED = 0;
`endif

`ifdef SIM
localparam SIM_DEFINED = 1;
`else
localparam SIM_DEFINED = 0;
`endif

generate
if (FPGA_ICE40_DEFINED && WIDTH == 32 && DEPTH == 1 << 15) begin: up5k_spram
// Special case: use all SPRAMs on UP5k

wire [31:0] rdata0;
wire [31:0] rdata1;

SB_SPRAM256KA ram00 (
	.ADDRESS    (addr[13:0]),
	.DATAIN     (wdata[15:0]),
	.MASKWREN   ({wen[1], wen[1], wen[0], wen[0]}),
	.WREN       (wen[1] || wen[0]),
	.CHIPSELECT (!addr[14]),
	.CLOCK      (clk),
	.STANDBY    (1'b0),
	.SLEEP      (1'b0),
	.POWEROFF   (1'b1),
	.DATAOUT    (rdata0[15:0])
);

SB_SPRAM256KA ram01 (
	.ADDRESS    (addr[13:0]),
	.DATAIN     (wdata[31:16]),
	.MASKWREN   ({wen[3], wen[3], wen[2], wen[2]}),
	.WREN       (wen[3] || wen[2]),
	.CHIPSELECT (!addr[14]),
	.CLOCK      (clk),
	.STANDBY    (1'b0),
	.SLEEP      (1'b0),
	.POWEROFF   (1'b1),
	.DATAOUT    (rdata0[31:16])
);

SB_SPRAM256KA ram10 (
	.ADDRESS    (addr[13:0]),
	.DATAIN     (wdata[15:0]),
	.MASKWREN   ({wen[1], wen[1], wen[0], wen[0]}),
	.WREN       (wen[1] || wen[0]),
	.CHIPSELECT (addr[14]),
	.CLOCK      (clk),
	.STANDBY    (1'b0),
	.SLEEP      (1'b0),
	.POWEROFF   (1'b1),
	.DATAOUT    (rdata1[15:0])
);

SB_SPRAM256KA ram11 (
	.ADDRESS    (addr[13:0]),
	.DATAIN     (wdata[31:16]),
	.MASKWREN   ({wen[3], wen[3], wen[2], wen[2]}),
	.WREN       (wen[3] || wen[2]),
	.CHIPSELECT (addr[14]),
	.CLOCK      (clk),
	.STANDBY    (1'b0),
	.SLEEP      (1'b0),
	.POWEROFF   (1'b1),
	.DATAOUT    (rdata1[31:16])
);

reg chipselect_prev;
always @ (posedge clk)
	chipselect_prev <= addr[14];

always @ (*) rdata = chipselect_prev ? rdata1 : rdata0;

end else begin: behav_mem
// Behavioural model, but Yosys does a great job of this on ECP5 and iCE40.

genvar i;

reg [WIDTH-1:0] mem [0:DEPTH-1];

if (PRELOAD_FILE != "" || SIM_DEFINED) begin: preload
	initial begin: preload_initial
		`ifdef SIM
			integer n;
			for (n = 0; n < DEPTH; n = n + 1)
				mem[n] = {WIDTH{1'b0}};
		`endif
		if (PRELOAD_FILE != "")
			$readmemh(PRELOAD_FILE, mem);
	end
end


if (BYTE_ENABLE) begin: has_byte_enable
	for (i = 0; i < WIDTH / 8; i = i + 1) begin: byte_mem
		always @ (posedge clk) begin
			if (wen[i])
				mem[addr][8 * i +: 8] <= wdata[8 * i +: 8];
			rdata[8 * i +: 8] <= mem[addr][8 * i +: 8];
		end
	end
end else begin: no_byte_enable
	always @ (posedge clk) begin
		if (wen)
			mem[addr] <= wdata;
		rdata <= mem[addr];
	end
end

end
endgenerate

endmodule
