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
// Simulation model for GS74116AGP SRAM (and similar)
// It might also be synthesisable, but I really don't recommend it
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
//
// Read timing: assert address, CE, OE and byte enables, and wait for 10 ns
// Write timing: assert address, CE, byte enables, data. Wait 3 ns. 
//  Assert WE. Wait 7 ns.
// Data sampled by SRAM on rising edge (deassertion; active low!)

module sram_async #(
	parameter W_DATA = 16,            // Must be power of 2, >= 8
	parameter DEPTH = 1 << 18,        // == 0.5 MiB for 16 bit interface
	parameter W_ADDR = $clog2(DEPTH), // Let this default
	parameter W_BYTES = W_DATA / 8    // Let this default
) (
	input wire [W_ADDR-1:0] addr,
	inout wire [W_DATA-1:0] dq,

	input wire ce_n,
	input wire oe_n,
	input wire we_n,
	input wire [W_BYTES-1:0] ben_n
);

reg [W_DATA-1:0] dq_r;
assign dq = dq_r;

reg [7:0] byte_mem [0:DEPTH-1] [0:W_BYTES-1];

always @ (*) begin: readport
	integer i;
	for (i = 0; i < W_BYTES; i = i + 1) begin
		dq_r[i * 8 +: 8] = !ce_n && !oe_n && we_n && !ben_n[i] ?
			byte_mem[addr][i] : 8'hz;
	end 	
end

always @ (posedge we_n) begin: writeport
	integer i;
	for (i = 0; i < W_BYTES; i = i + 1) begin
		if (!ce_n && !ben_n[i])
			byte_mem[addr][i] <= dq[i * 8 +: 8];
	end
end

endmodule