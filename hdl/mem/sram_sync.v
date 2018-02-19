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
// read/write, and optional per-byte write enable (implemented as multiple RAMs).

module sram_sync #(
	parameter WIDTH = 4,
	parameter DEPTH = 1 << 10,
	// ADDR_WIDTH should be a localparam, but Xilinx ISIM errors on the clog2 call in this case.
	// Instead, it now gives a warning that the param is implicitly a localparam. Wonderful
	parameter ADDR_WIDTH = $clog2(DEPTH),
	parameter BYTE_ENABLE = 0
) (
	input wire                                     clk,
	input wire [(BYTE_ENABLE ? WIDTH / 8 : 1)-1:0] wen,
	input wire [ADDR_WIDTH-1:0]                    addr,
	input wire [WIDTH-1:0]                         wdata,
	output reg [WIDTH-1:0]                         rdata
);

genvar i;

generate if (BYTE_ENABLE) begin: has_byte_enable
	for (i = 0; i < WIDTH / 8; i = i + 1) begin: byte_mem

		reg [7:0] mem [0:DEPTH-1];
		always @ (posedge clk) begin
			if (wen[i])
				mem[addr] <= wdata[8 * i +: 8];
			rdata[8 * i +: 8] <= mem[addr];
		end
	end
end else begin: no_byte_enable
	reg [WIDTH-1:0] mem [0:DEPTH-1];

	always @ (posedge clk) begin
		if (wen)
			mem[addr] <= wdata;
		rdata <= mem[addr];
	end
end
endgenerate

endmodule