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

module cache_ro_full_assoc #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter N_ENTRIES = 8
) (
	input wire clk,
	input wire rst_n,

	// read valid lookup is combinatorial,
	// read data is presented on the next clock edge.
	// (timing is intended to fit nicely into ReVive pipeline)
	input wire  [W_ADDR-1:0] raddr,
	output wire              rvalid,
	output reg  [W_DATA-1:0] rdata,
	
	input wire  [W_ADDR-1:0] waddr,
	input wire  [W_DATA-1:0] wdata,
	input wire               wen
);

parameter W_SETADDR = $clog2(N_ENTRIES);
parameter W_TAG = W_ADDR - $clog2(W_DATA / 8);


reg [W_TAG-1:0]     tags     [0:N_ENTRIES-1];
reg [N_ENTRIES-1:0] valid;
reg [W_DATA-1:0]    data_mem [0:N_ENTRIES-1];

integer i;

// ==============================
// Pseudorandom eviction selector
// ==============================

reg [15:0] eviction_lfsr;
wire [W_SETADDR-1:0] next_evict = eviction_lfsr[W_SETADDR-1:0];

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		eviction_lfsr <= 16'h0;
	end else begin
		eviction_lfsr <= {eviction_lfsr[14:0], eviction_lfsr[15] ^ eviction_lfsr[13] ^ eviction_lfsr[12] ^ eviction_lfsr[3]};
	end
end

// =====================================
// Parallel tag lookup + one-hot encoder
// =====================================

reg  [N_ENTRIES-1:0] check_match;
reg  [W_SETADDR-1:0] encode_accum [0:N_ENTRIES];
wire [W_SETADDR-1:0] match_addr = encode_accum[N_ENTRIES];

assign rvalid = |(check_match & valid);

always @ (*) begin
	for (i = 0; i < N_ENTRIES; i = i + 1) begin
		check_match[i] = raddr[W_ADDR-1 -: W_TAG] == tags[i];
	end
end

// This style of encoder will FAIL if a tag appears more than once in the array.
// It's the cache owner's responsibility to not write tags which are already valid.
// However, it is a 2-layer sum of product network, which is nice :)
always @ (*) begin
	for (i = 0; i < N_ENTRIES; i = i + 1) begin
		encode_accum[i + 1] = encode_accum[i] | (check_match[i] ? i : 0);
	end
end

// ============================
// Clocked read/write processes
// ============================

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		rdata <= {W_DATA{1'b0}};
	end else begin
		rdata <= data_mem[match_addr];
	end
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		valid <= {N_ENTRIES{1'b0}};
	end else begin
		if (wen) begin
			tags[next_evict] <= waddr[W_ADDR-1 -: W_TAG];
			valid[next_evict] <= 1'b0;
			data_mem[next_evict] <= wdata;
		end
	end
end

endmodule