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

// Asynchronous FIFO

// wclk and rclk are two free-running clocks with arbitrary relationship.
// Full/empty signals, and levels, are approximate, but conservative.
// They are calculated with a sync'd version of the other clock domain's
// pointer; W may see more data than is actually there (but never less)
// and R may see less data (but never more), as pointers only move forward.

// There are two async resets; ideally these should be the same reset, but with
// rising edges synchronised to each clock domain.

module async_fifo #(
	parameter W_DATA = 1,
	parameter W_ADDR = 1,
	parameter SYNC_STAGES = 1
) (
	input  wire              wrst_n,
	input  wire              wclk,
	input  wire [W_DATA-1:0] wdata,
	input  wire              wpush,
	output wire              wfull,
	output wire              wempty,
	output wire [W_ADDR:0]   wlevel,

	input  wire              rrst_n,
	input  wire              rclk,
	input  wire [W_DATA-1:0] rdata,
	input  wire              rpop,
	output wire              rfull,
	output wire              rempty,
	output wire [W_ADDR:0]   rlevel,
);

localparam MEM_DEPTH = 1 << W_ADDR;
reg [W_DATA-1:0] mem [0:MEM_DEPTH-1];

// Pointers are 1 bit oversized to distinguish empty from full state.
reg [W_ADDR:0] wptr;
reg [W_ADDR:0] rptr;
wire [W_ADDR:0] wptr_sync;
wire [W_ADDR:0] rptr_sync;

// Flags and control synchronisation

assign wempty = wptr == rptr_sync;
assign wfull = wptr == (rptr_sync ^ MEM_DEPTH);
assign wlevel = wptr - rptr_sync;

assign rempty = rptr == wptr_sync;
assign rfull = rptr == (wptr_sync ^ MEM_DEPTH);
assign rlevel = wptr_sync - rptr;

nbit_sync #(
	.W_DATA(W_ADDR + 1),
	.SYNC_STAGES(SYNC_STAGES)
) sync_ptr_w2r (
	.wrst_n (wrst_n),
	.wclk   (wclk),
	.wdata  (wptr),

	.rrst_n (rrst_n),
	.rclk   (rclk),
	.rdata  (wptr_sync)
);

nbit_sync #(
	.W_DATA(W_ADDR + 1),
	.SYNC_STAGES(SYNC_STAGES)
) sync_ptr_r2w (
	.wrst_n (rrst_n),
	.wclk   (rclk),
	.wdata  (rptr),

	.rrst_n (wrst_n),
	.rclk   (wclk),
	.rdata  (rptr_sync)
);

// Read/write state machines

always @ (posedge wclk or negedge wrst_n) begin
	if (!wrst_n) begin
		wptr <= {W_ADDR+1{1'b0}};
	end else begin
		if (wpush) begin
			wptr <= wptr + 1'b1;
			mem[wptr[W_ADDR-1:0]] <= wdata;
		end
	end
end

always @ (posedge rclk or negedge rrst_n) begin
	if (!rrst_n) begin
		rptr <= {W_ADDR+1{1'b0}};
	end else begin
		if (rpop) begin
			rptr <= rptr + 1'b1;
		end
	end
end

assign rdata = mem[rptr[W_ADDR-1:0]];

endmodule