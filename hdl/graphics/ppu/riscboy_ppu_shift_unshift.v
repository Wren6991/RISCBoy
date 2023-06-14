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

module riscboy_ppu_shift_unshift #(
	parameter W_DATA = 18,
	parameter MAX_SHIFT = 9
) (
	input wire clk,
	input wire rst_n,

	input wire [W_DATA-1:0] din,
	output wire [W_DATA-1:0] dout,

	input wire load,
	input wire shift,
	input wire unshift
);

reg [W_DATA+MAX_SHIFT-1:0] sreg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sreg <= {W_DATA+MAX_SHIFT{1'b0}};
	end else begin
		if (shift)
			sreg <= sreg << 1;

		if (load)
			sreg[0 +: W_DATA] <= din;
		else if (unshift)
			sreg[0 +: W_DATA] <= sreg[MAX_SHIFT +: W_DATA];
	end
end

assign dout = sreg[0 +: W_DATA];

endmodule