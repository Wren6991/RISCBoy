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

// One half of the affine coordinate generator
// op_a should be a_xu or a_xv, and op_b should be a_yu or a_yv
//
// Where
//   A = [ a_xu  a_yu ]
//       [ a_xv  a_yv ]
// and
//   u = A(s - s0) + b
//
// This is because only op_a supports unshifting after the multiply step, so
// that it can be repeatedly added as raster x advances.

`default_nettype none

module riscboy_ppu_phase_accum #(
	parameter W_COORD_INT = 10,
	parameter W_COORD_FRAC = 8,
	parameter W_COORD_FULL = W_COORD_INT + W_COORD_FRAC // Do not modify
) (
	input wire                    clk,
	input wire                    rst_n,

	input wire [W_COORD_FULL-1:0] op_a_wdata,   // a_xu or a_xv
	input wire                    op_a_load,
	input wire                    op_a_unshift,

	input wire [W_COORD_FULL-1:0] op_b_wdata,   // a_yu or a_yv
	input wire                    op_b_load,    
	                                            
	input wire                    op_shift,     

	input wire [W_COORD_FULL-1:0] accum_wdata,
	input wire                    accum_load,
	input wire                    accum_hold,
	input wire                    accum_add_a,
	input wire                    accum_add_b,
	input wire                    accum_incr,
	output reg [W_COORD_FULL-1:0] accum
);

wire [W_COORD_FULL-1:0] op_a;
wire [W_COORD_FULL-1:0] op_b;

riscboy_ppu_shift_unshift #(
	.W_DATA    (W_COORD_FULL),
	.MAX_SHIFT (W_COORD_INT - 1)
) op_a_shifter (
	.clk     (clk),
	.rst_n   (rst_n),
	.din     (op_a_wdata),
	.dout    (op_a),
	.load    (op_a_load),
	.shift   (op_shift),
	.unshift (op_a_unshift)
);

riscboy_ppu_shift_unshift #(
	.W_DATA    (W_COORD_FULL),
	.MAX_SHIFT (0)
) op_b_shifter (
	.clk     (clk),
	.rst_n   (rst_n),
	.din     (op_b_wdata),
	.dout    (op_b),
	.load    (op_b_load),
	.shift   (op_shift),
	.unshift (1'b0)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		accum <= {W_COORD_FULL{1'b0}};
	end else if (accum_load) begin
		accum <= accum_wdata;
	end else if (!accum_hold) begin
		// Note I have tried standard carry save tricks etc but I can't beat what
		// Yosys does here with two + symbols
		accum <= accum
			+ (op_a & {W_COORD_FULL{accum_add_a}} | {{W_COORD_FULL-1{1'b0}}, accum_incr} << W_COORD_FRAC)
			+ (op_b & {W_COORD_FULL{accum_add_b}});
	end
end

`ifdef FORMAL

always @ (posedge clk) if (rst_n) begin
	assert(!(accum_incr && accum_add_a)); // since this uses the same adder input
	if (accum_load)
		assert(!(accum_incr || accum_add_a || accum_add_b));
end

`endif

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
