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

// 
// Behavioural model for asynchronous SRAM.
// Intended to be compatible with GS74116AGP SRAM,
// for use in full-system simulations with this external SRAM.
// 


// Truth table from datasheet
//
// -----+------+------+------+------+---------+---------
// CE_n | OE_n | WE_n | LB_n | UB_n | DQ[7:0] | DQ[15:8]
// -----+------+------+------+------+---------+---------
//   1  |  X   |  X   |  X   |  X   | Hi-Z    | Hi-Z
// -----+------+------+------+------+---------+---------
//   0  |  0   |  1   |  0   |  0   | Read    | Read
//   0  |  0   |  1   |  1   |  0   | Hi-Z    | Read
//   0  |  0   |  1   |  0   |  1   | Read    | Hi-Z
// -----+------+------+------+------+---------+---------
//   0  |  X   |  0   |  0   |  0   | Write   | Write
//   0  |  X   |  0   |  1   |  0   | Hi-Z    | Write
//   0  |  X   |  0   |  0   |  1   | Write   | Hi-Z
// -----+------+------+------+------+---------+---------
//   0  |  1   |  1   |  X   |  X   | Hi-Z    | Hi-Z
//   0  |  X   |  X   |  1   |  1   | Hi-Z    | Hi-Z

module sram_async #(
	parameter WIDTH = 16,
	parameter DEPTH = 1 << 18,
	localparam W_ADDR = $clog2(DEPTH)
) (
	input wire [W_ADDR-1:0] addr,
	inout reg [WIDTH-1:0] dq,

	input wire ce_n,
	input wire we_n,
	input wire oe_n,
	input wire ub_n,
	input wire lb_n
);

reg [WIDTH-1:0] mem [0:DEPTH-1];

// This is very much not synthesisable
always @ (*) begin
	if (!ce_n) begin
		if (!we_n) begin
			dq = {WIDTH{1'bz}};
			mem[addr] =
			 {ub_n ? mem[addr][WIDTH/2 +: WIDTH/2] : dq[WIDTH/2 +: WIDTH/2],
			  lb_n ? mem[addr][0       +: WIDTH/2] : dq[0       +: WIDTH/2]};
		end else if (!oe_n) begin
			dq =
			 {ub_n ? {(WIDTH/2){1'bz}} : mem[addr][WIDTH/2 +: WIDTH/2],
			  lb_n ? {(WIDTH/2){1'bz}} : mem[addr][0       +: WIDTH/2]};
		end else begin
			dq = {WIDTH{1'bz}};
		end
	end else begin
		dq = {WIDTH{1'bz}};
	end
end

endmodule