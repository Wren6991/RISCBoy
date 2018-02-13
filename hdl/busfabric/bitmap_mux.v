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

// A multiplexer, where the input is a bitmap of which channel is selected,
// rather than an index.
// Should be faster than a mux if this bitmap is already known, but the index is not
// (e.g. in an address decoder)

module bitmap_mux #(
	parameter N_INPUTS = 2,
	parameter W_INPUT = 32
) (
	input wire  [N_INPUTS*W_INPUT-1:0] in,
	input wire  [N_INPUTS-1:0]         sel,
	output wire [W_INPUT-1:0]          out
);


// This produces an  n * m  2:1 AND array
// and n  m:1 OR gates.
// OR gates are actually produced in the form of a max-imbalance tree,
// but synthesis can be trusted to flatten this down.

integer i, j;

wire [W_INPUT-1:0] masked_data [N_INPUTS-1:0];
wire [W_INPUT-1:0] mux_accum   [N_INPUTS:0];


always @ (*) begin
	mux_accum[0] = {W_INPUT{1'b0}};
	for (i = 0; i < W_INPUT; i = i + 1) begin
		for (j = 0; j < N_INPUTS; j = j + 1) begin
			masked_data[j][i] = in[j * W_INPUT + i] & sel[j];
			mux_accum[j+1][i] = mux_accum[j][i] | masked_data[j][i];
		end
	end
end

assign out = mux_accum[N_INPUTS];

endmodule