/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2020 Luke Wren                                       *
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

// Inference/injection wrapper for one-write one-read synchronous memory, nontransparent

module sram_sync_1r1w #(
	parameter WIDTH = 16,
	parameter DEPTH = 1 << 8,
	parameter W_ADDR = $clog2(DEPTH) // let this default
) (
	input wire              clk,

	input wire [W_ADDR-1:0] waddr,
	input wire [WIDTH-1:0]  wdata,
	input wire              wen,

	input wire [W_ADDR-1:0] raddr,
	output reg [WIDTH-1:0]  rdata,
	input wire              ren
);

reg [WIDTH-1:0] mem [0:DEPTH-1];

always @ (posedge clk) begin
	if (ren)
		rdata <= mem[raddr];
	if (wen)
		mem[waddr] <= wdata;
end

endmodule
