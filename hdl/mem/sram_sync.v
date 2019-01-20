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
	parameter PRELOAD_FILE = "NONE",
	parameter ADDR_WIDTH = $clog2(DEPTH) // Let this default
) (
	input wire                                     clk,
	input wire [(BYTE_ENABLE ? WIDTH / 8 : 1)-1:0] wen,
	input wire [ADDR_WIDTH-1:0]                    addr,
	input wire [WIDTH-1:0]                         wdata,
	output reg [WIDTH-1:0]                         rdata
);

genvar i;

reg [WIDTH-1:0] mem [0:DEPTH-1];

generate
if (PRELOAD_FILE != "NONE") begin: preload
	initial $readmemh(PRELOAD_FILE, mem);
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
endgenerate

endmodule