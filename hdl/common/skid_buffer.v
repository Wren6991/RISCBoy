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

// A pipestage register with buffered handshake
// Similar to a DEPTH=2 FIFO, but no mux on the output side.

module skid_buffer #(
	parameter WIDTH = 8
) (
	input  wire             clk,
	input  wire             rst_n,

	input  wire [WIDTH-1:0] wdata,
	input  wire             wen,
	output reg  [WIDTH-1:0] rdata,
	input  wire             ren,

	input  wire             flush,

	output reg              full,
	output reg              empty,
	output wire [1:0]       level
);

// Flags

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		empty <= 1'b1;
		full <= 1'b0;
	end else if (flush) begin
		empty <= 1'b1;
		full <= 1'b0;
	end else begin
		full  <= (full  || wen && !ren && !empty) && !(ren && !wen);
		empty <= (empty || ren && !wen && !full ) && !(wen && !ren);
`ifdef FORMAL
		assert(!(full && empty));
		assert(!(wen && full));
		assert(!(ren && empty));
`endif
	end
end

assign level = {full, !(full || empty)};

// Datapath

reg [WIDTH-1:0] skidbuf;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		rdata <= {WIDTH{1'b0}};
		skidbuf <= {WIDTH{1'b0}};
	end else begin
		if (wen && (ren || empty))
			rdata <= wdata;
		else if (wen)
			skidbuf <= wdata;

		if (ren && full)
			rdata <= skidbuf;
	end
end

endmodule