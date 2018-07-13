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

// Input a bitmap. The output will have at most 1 bit set, which will
// be the least-significant set bit of the input.
// e.g. 'b011100 -> 'b000100

module onehot_priority #(
	parameter W_INPUT = 8
) (
	input wire [W_INPUT-1:0] in,
	output reg [W_INPUT-1:0] out
);

integer i;

reg accum;

always @ (*) begin
	accum = 0;
	for (i = 0; i < W_INPUT; i = i + 1) begin
		out[i] = in[i] && !accum;
		accum = accum || in[i];
	end
end

endmodule