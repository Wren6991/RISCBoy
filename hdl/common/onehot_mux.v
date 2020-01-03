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

// Multiplex based on a bitmap selector, rather than an index selector.
// Generates a fast and->or mux structure rather than a tree of dmuxes.
// The selector must be one-hot, else the result is meaningless.

module onehot_mux #(
	parameter N_INPUTS = 2,
	parameter W_INPUT = 32
) (
	input wire  [N_INPUTS*W_INPUT-1:0] in,
	input wire  [N_INPUTS-1:0]         sel,
	output wire [W_INPUT-1:0]          out
);

integer i;

reg [W_INPUT-1:0] mux_accum;

always @ (*) begin
	mux_accum = {W_INPUT{1'b0}};
	for (i = 0; i < N_INPUTS; i = i + 1) begin
		mux_accum = mux_accum | (in[i * W_INPUT +: W_INPUT] & {W_INPUT{sel[i]}});
	end
end

assign out = mux_accum;

endmodule
