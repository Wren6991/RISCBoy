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

// This is based on Style #2 from Cummings' paper:
// Simulation and Synthesis Techniques for Asynchronous FIFO Design (SNUG 2002)

module async_fifo #(
	parameter W_DATA = 16,
	parameter W_ADDR = 3,
	parameter SYNC_STAGES = 2,
	parameter USE_MEM = 0
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
	output  reg [W_DATA-1:0] rdata,
	input  wire              rpop,
	output wire              rfull,
	output wire              rempty,
	output wire [W_ADDR:0]   rlevel
);

// ----------------------------------------------------------------------------
// Flags and controls (flags are mildly pessimistic)

// Pointers are 1 bit oversized to distinguish empty from full state.
wire [W_ADDR:0] wptr_w;     // |
wire [W_ADDR:0] wptr_gry_w; // | progression
wire [W_ADDR:0] wptr_gry_r; // V
wire [W_ADDR:0] wptr_r;

wire [W_ADDR:0] rptr_r;
wire [W_ADDR:0] rptr_gry_r;
wire [W_ADDR:0] rptr_gry_w;
wire [W_ADDR:0] rptr_w;

wire [W_ADDR:0] rptr_r_next;

// rptr_w and wptr_r are expensive (Gray-decoded), so avoid them for full/empty calculations
// For full, due to symmetries in Gray code, we check that 2 MSBs differ and all others are equal
assign wempty = wptr_gry_w == rptr_gry_w;
assign wfull  = wptr_gry_w == (rptr_gry_w ^ {2'b11, {W_ADDR-1{1'b0}}});
assign wlevel = wptr_w - rptr_w;

assign rempty = rptr_gry_r == wptr_gry_r;
assign rfull  = rptr_gry_r == (wptr_gry_r ^ {2'b11, {W_ADDR-1{1'b0}}});
assign rlevel = wptr_r - rptr_r;

wire push_actual = wpush && !wfull;
wire pop_actual = rpop && !rempty;

//synthesis translate_off
always @ (posedge wclk)
	if (wpush && wfull)
		$display($time, ": WARNING %m: push on full");
always @ (posedge rclk)
	if (rpop && rempty)
		$display($time, ": WARNING %m: pop on empty");
//synthesis translate_on

// ----------------------------------------------------------------------------
// Pointer counters and synchronisation

gray_counter #(
	.W_CTR (W_ADDR + 1)
) gray_counter_w (
	.clk            (wclk),
	.rst_n          (wrst_n),
	.en             (push_actual),
	.clr            (1'b0),
	.count_bin      (wptr_w),
	.count_bin_next (/* unused */),
	.count_gry      (wptr_gry_w)
);

gray_counter #(
	.W_CTR (W_ADDR + 1)
) gray_counter_r (
	.clk            (rclk),
	.rst_n          (rrst_n),
	.en             (pop_actual),
	.clr            (1'b0),
	.count_bin      (rptr_r),
	.count_bin_next (rptr_r_next),
	.count_gry      (rptr_gry_r)
);

sync_1bit #(
	.N_STAGES (SYNC_STAGES + 1)
) sync_wptr [W_ADDR:0] (
	.clk   (rclk),
	.rst_n (rrst_n),
	.i     (wptr_gry_w),
	.o     (wptr_gry_r)
);

sync_1bit #(
	.N_STAGES (SYNC_STAGES)
) sync_rptr [W_ADDR:0] (
	.clk   (wclk),
	.rst_n (wrst_n),
	.i     (rptr_gry_r),
	.o     (rptr_gry_w)
);

gray_decode #(
	.N (W_ADDR + 1)
) decode_wptr (
	.i (wptr_gry_r),
	.o (wptr_r)
);

gray_decode #(
	.N (W_ADDR + 1)
) decode_rptr (
	.i (rptr_gry_w),
	.o (rptr_w)
);

// ----------------------------------------------------------------------------
// Memory and read/write ports

localparam MEM_DEPTH = 1 << W_ADDR;
reg [W_DATA-1:0] mem [0:MEM_DEPTH-1];

wire [W_ADDR-1:0] memptr_w = wptr_w[W_ADDR-1:0];
wire [W_ADDR-1:0] memptr_r = pop_actual ? rptr_r_next[W_ADDR-1:0] : rptr_r[W_ADDR-1:0];

always @ (posedge wclk)
	if (push_actual)
		mem[memptr_w] <= wdata;

always @ (posedge rclk)
	rdata <= mem[memptr_r];

endmodule
