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

// Inference/injection wrapper for PPU palette RAM
// Intent is for this to map to a single iCE40 BRAM (256x16 1R 1W).
//
// Assumed that (!!!) rdata will remain constant over clock edges where ren is
// low.

module riscboy_palette_ram #(
	parameter W_DATA = 16,
	parameter W_ADDR = 8,
	parameter DEPTH = 1 << W_ADDR // let this default
) (
	input wire              clk,

	input wire [W_ADDR-1:0] waddr,
	input wire [W_DATA-1:0] wdata,
	input wire              wen,

	input wire [W_ADDR-1:0] raddr,
	output reg [W_DATA-1:0] rdata,
	input wire              ren
);

reg [W_DATA-1:0] mem [0:DEPTH-1];

always @ (posedge clk) begin
	if (ren)
		rdata <= mem[raddr];
	if (wen)
		mem[waddr] <= wdata;
end

endmodule
