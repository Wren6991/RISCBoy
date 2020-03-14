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

// Synchronous FIFO
//
// No first-word-fallthrough.
// All outputs are registered, apart from read data, which is
// combinationally decoded from internal register-based memory.
// Depth must be power of 2, != 1

module sync_fifo #(
	parameter DEPTH = 2,
	parameter WIDTH = 32,
	parameter W_ADDR = $clog2(DEPTH)	// SHOULD BE LOCALPARAM but this triggers bug in xilinx tools with clog2
) (
	input  wire clk,
	input  wire rst_n,

	input  wire [WIDTH-1:0] w_data,
	input  wire             w_en,
	output wire [WIDTH-1:0] r_data,
	input  wire             r_en,

	output  reg             full,
	output  reg             empty,
	output  reg [W_ADDR:0]  level
);

reg [WIDTH-1:0] mem[0:DEPTH-1];

reg [W_ADDR-1:0] w_ptr;
reg [W_ADDR-1:0] r_ptr;
assign r_data = mem[r_ptr];

wire push = w_en && !full;
wire pop = r_en && !empty;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		full <= 1'b0;
		empty <= 1'b1;
		level <= {(W_ADDR+1){1'b0}};
		w_ptr <= {W_ADDR{1'b0}};
		r_ptr <= {W_ADDR{1'b0}};
	end else begin
		w_ptr <= w_ptr + push;
		r_ptr <= r_ptr + pop;
		if (push) begin
			mem[w_ptr] <= w_data;
			if (!pop) begin
				level <= level + 1'b1;
				empty <= 1'b0;
				full <= level == DEPTH - 1;
			end
		end else if (pop) begin
			level <= level - 1'b1;
			full <= 1'b0;
			empty <= level == 1;
		end
	end
end

//synthesis translate_off
always @ (posedge clk)
	if (w_en && full)
		$display($time, ": WARNING %m: push on full");
always @ (posedge clk)
	if (r_en && empty)
		$display($time, ": WARNING %m: pop on empty");
//synthesis translate_on


`ifdef FORMAL_CHECK_FIFO
initial assume(!rst_n);
always @ (posedge clk) begin
	assume(!(w_en && full && !r_en));
	assume(!(r_en && empty));
	assume(rst_n);

	assert((full) ~^ (level == DEPTH));
	assert((empty) ~^ (level == 0));
	assert(level <= DEPTH);
	assert((w_ptr == r_ptr) ~^ (full || empty));

	assert($past(r_en) || (r_data == $past(r_data) || $past(empty)));
	assert($past(r_en) || level >= $past(level));
	assert($past(w_en) || level <= $past(level));
	assert(!($past(empty) && $past(w_en) && r_data != $past(w_data)));
	assert(!($past(r_en) && r_ptr == $past(r_ptr)));
	assert(!($past(w_en) && w_ptr == $past(w_ptr)));
end
`endif

endmodule
