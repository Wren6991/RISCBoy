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
/*
 * Strict-priority N:1 AHBL arbiter
 *
 * Lower port numbers are higher priority.
 * Use concat lists to wire masters in:
 *   .N_PORTS(2)
 *   ...
 *   .src_haddr({mast1_haddr, mast0_haddr})
 *   ...
 * Recommend that wiring up either be scripted, or done by unpaid intern.
 */

// TODO: no burst support!


module ahbl_arbiter #(
	parameter N_PORTS = 2,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter CONN_MASK = {N_PORTS{1'b1}}
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// From masters; function as slave ports
	input  wire [N_PORTS-1:0]        src_hready,
	output wire [N_PORTS-1:0]        src_hready_resp,
	output wire [N_PORTS-1:0]        src_hresp,
	input  wire [N_PORTS*W_ADDR-1:0] src_haddr,
	input  wire [N_PORTS-1:0]        src_hwrite,
	input  wire [N_PORTS*2-1:0]      src_htrans,
	input  wire [N_PORTS*3-1:0]      src_hsize,
	input  wire [N_PORTS*3-1:0]      src_hburst,
	input  wire [N_PORTS*4-1:0]      src_hprot,
	input  wire [N_PORTS-1:0]        src_hmastlock,
	input  wire [N_PORTS*W_DATA-1:0] src_hwdata,
	output wire [N_PORTS*W_DATA-1:0] src_hrdata,

	// To slave; functions as master port
	output wire                      dst_hready,
	input  wire                      dst_hready_resp,
	input  wire                      dst_hresp,
	output wire [W_ADDR-1:0]         dst_haddr,
	output wire                      dst_hwrite,
	output wire [1:0]                dst_htrans,
	output wire [2:0]                dst_hsize,
	output wire [2:0]                dst_hburst,
	output wire [3:0]                dst_hprot,
	output wire                      dst_hmastlock,
	output wire [W_DATA-1:0]         dst_hwdata,
	input  wire [W_DATA-1:0]         dst_hrdata
);

integer i;

// "actual" is a mux between the buffered signal, if valid, else the live signal on the port

reg [N_PORTS-1:0]        buf_valid;
reg [W_ADDR-1:0]         buf_haddr      [0:N_PORTS-1];
reg                      buf_hwrite     [0:N_PORTS-1];
reg [1:0]                buf_htrans     [0:N_PORTS-1];
reg [2:0]                buf_hsize      [0:N_PORTS-1];
reg [2:0]                buf_hburst     [0:N_PORTS-1];
reg [3:0]                buf_hprot      [0:N_PORTS-1];
reg                      buf_hmastlock  [0:N_PORTS-1];

reg [N_PORTS*W_ADDR-1:0] actual_haddr;
reg [N_PORTS-1:0]        actual_hwrite;
reg [N_PORTS*2-1:0]      actual_htrans;
reg [N_PORTS*3-1:0]      actual_hsize;
reg [N_PORTS*3-1:0]      actual_hburst;
reg [N_PORTS*4-1:0]      actual_hprot;
reg [N_PORTS-1:0]        actual_hmastlock;

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		if (buf_valid[i]) begin
			actual_haddr     [i * W_ADDR +: W_ADDR] = buf_haddr     [i];
			actual_hwrite    [i]                    = buf_hwrite    [i];
			actual_htrans    [i * 2 +: 2]           = buf_htrans    [i];
			actual_hsize     [i * 3 +: 3]           = buf_hsize     [i];
			actual_hburst    [i * 3 +: 3]           = buf_hburst    [i];
			actual_hprot     [i * 4 +: 4]           = buf_hprot     [i];
			actual_hmastlock [i]                    = buf_hmastlock [i];
		end else begin
			actual_haddr     [i * W_ADDR +: W_ADDR] = src_haddr     [i * W_ADDR +: W_ADDR];
			actual_hwrite    [i]                    = src_hwrite    [i];
			actual_htrans    [i * 2 +: 2]           = src_htrans    [i * 2 +: 2];
			actual_hsize     [i * 3 +: 3]           = src_hsize     [i * 3 +: 3];
			actual_hburst    [i * 3 +: 3]           = src_hburst    [i * 3 +: 3];
			actual_hprot     [i * 4 +: 4]           = src_hprot     [i * 4 +: 4];
			actual_hmastlock [i]                    = src_hmastlock [i];
		end
	end
end

// Address-phase arbitration

reg  [N_PORTS-1:0] mast_req_a;
wire [N_PORTS-1:0] mast_gnt_a;

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		// HTRANS == 2'b10, 2'b11 when active
		mast_req_a[i] = actual_htrans[i * 2 + 1] && CONN_MASK[i];
	end
end

onehot_priority #(
	.W_INPUT(N_PORTS)
) arb_priority (
	.in(mast_req_a),
	.out(mast_gnt_a)
);

// AHB State Machine

reg [N_PORTS-1:0] mast_gnt_d;
assign dst_hready = mast_gnt_d ? |(src_hready & mast_gnt_d) : 1'b1;

wire [N_PORTS-1:0] mast_aphase_ends = mast_req_a & src_hready;
wire [N_PORTS-1:0] buf_wen = mast_aphase_ends & ~(mast_gnt_a & {N_PORTS{dst_hready}});

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mast_gnt_d <= {N_PORTS{1'b0}};
		for (i = 0; i < N_PORTS; i = i + 1) begin
			buf_valid[i]     <= 1'b0;
			buf_htrans[i]    <= 2'h0;
			buf_haddr[i]     <= {W_ADDR{1'b0}};
			buf_hwrite[i]    <= 1'b0;
			buf_hsize[i]     <= 3'h0;
			buf_hburst[i]    <= 3'h0;
			buf_hprot[i]     <= 3'h0;
			buf_hmastlock[i] <= 1'b0;
		end
	end else begin
		if (dst_hready) begin
			mast_gnt_d <= mast_gnt_a;
			buf_valid <= buf_valid & ~mast_gnt_a;
		end
		for (i = 0; i < N_PORTS; i = i + 1) begin
			if (buf_wen[i]) begin
				buf_valid    [i] <= 1'b1;
				buf_htrans   [i] <= src_htrans   [i * 2 +: 2];
				buf_haddr    [i] <= src_haddr    [i * W_ADDR +: W_ADDR];
				buf_hwrite   [i] <= src_hwrite   [i];
				buf_hsize    [i] <= src_hsize    [i * 3 +: 3];
				buf_hburst   [i] <= src_hburst   [i * 3 +: 3];
				buf_hprot    [i] <= src_hprot    [i * 4 +: 4];
				buf_hmastlock[i] <= src_hmastlock[i];
			end
		end
	end
end

// Data-phase signal passthrough

// Master being in dphase with arbiter is separate (looser) condition than arbiter
// being in (that master's) dphase with slave (which is indicated by mast_gnt_d)
wire [N_PORTS-1:0] mast_in_dphase = buf_valid | mast_gnt_d;

// There are two reasons to report ready:
// - the master is currently not in data phase with the arbiter (IDLE)
// - the master is in data phase with both arbiter and slave, and slave is ready
assign src_hready_resp = ~mast_in_dphase | (mast_gnt_d & {N_PORTS{dst_hready_resp}});
assign src_hresp = mast_gnt_d & {N_PORTS{dst_hresp}};
assign src_hrdata = {N_PORTS{dst_hrdata}};

onehot_mux #(
	.W_INPUT(W_DATA),
	.N_INPUTS(N_PORTS)
) hwdata_mux (
	.in(src_hwdata),
	.sel(mast_gnt_d),
	.out(dst_hwdata)
);

// Pass through address-phase signals based on grant

onehot_mux #(
	.W_INPUT(W_ADDR),
	.N_INPUTS(N_PORTS)
) mux_haddr (
	.in(actual_haddr),
	.sel(mast_gnt_a),
	.out(dst_haddr)
);

onehot_mux #(
	.W_INPUT(1),
	.N_INPUTS(N_PORTS)
) mux_hwrite (
	.in(actual_hwrite),
	.sel(mast_gnt_a),
	.out(dst_hwrite)
);

onehot_mux #(
	.W_INPUT(2),
	.N_INPUTS(N_PORTS)
) mux_hwtrans (
	.in(actual_htrans),
	.sel(mast_gnt_a),
	.out(dst_htrans)
);

onehot_mux #(
	.W_INPUT(3),
	.N_INPUTS(N_PORTS)
) mux_hsize (
	.in(actual_hsize),
	.sel(mast_gnt_a),
	.out(dst_hsize)
);

onehot_mux #(
	.W_INPUT(3),
	.N_INPUTS(N_PORTS)
) mux_hburst (
	.in(actual_hburst),
	.sel(mast_gnt_a),
	.out(dst_hburst)
);

onehot_mux #(
	.W_INPUT(4),
	.N_INPUTS(N_PORTS)
) mux_hprot (
	.in(actual_hprot),
	.sel(mast_gnt_a),
	.out(dst_hprot)
);

onehot_mux #(
	.W_INPUT(1),
	.N_INPUTS(N_PORTS)
) mux_hmastlock (
	.in(actual_hmastlock),
	.sel(mast_gnt_a),
	.out(dst_hmastlock)
);

endmodule
