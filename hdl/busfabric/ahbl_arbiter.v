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
 *   .ahbls_haddr({mast1_haddr, mast0_haddr})
 *   ...
 * Recommend that wiring up either be scripted, or done by unpaid intern.
 */

// TODO: no burst support!


module ahbl_arbiter #(
	parameter N_PORTS = 2,
	parameter W_ADDR = 32,
	parameter W_DATA = 32
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// From masters; function as slave ports
	input  wire [N_PORTS-1:0]        ahbls_hready,
	output wire [N_PORTS-1:0]        ahbls_hready_resp,
	output wire [N_PORTS-1:0]        ahbls_hresp,
	input  wire [N_PORTS*W_ADDR-1:0] ahbls_haddr,
	input  wire [N_PORTS-1:0]        ahbls_hwrite,
	input  wire [N_PORTS*2-1:0]      ahbls_htrans,
	input  wire [N_PORTS*3-1:0]      ahbls_hsize,
	input  wire [N_PORTS*3-1:0]      ahbls_hburst,
	input  wire [N_PORTS*4-1:0]      ahbls_hprot,
	input  wire [N_PORTS-1:0]        ahbls_hmastlock,
	input  wire [N_PORTS*W_DATA-1:0] ahbls_hwdata,
	output wire [N_PORTS*W_DATA-1:0] ahbls_hrdata,

	// To slave; functions as master port
	output wire                      ahblm_hready,
	input  wire                      ahblm_hready_resp,
	input  wire                      ahblm_hresp,
	output wire [W_ADDR-1:0]         ahblm_haddr,
	output wire                      ahblm_hwrite,
	output wire [1:0]                ahblm_htrans,
	output wire [2:0]                ahblm_hsize,
	output wire [2:0]                ahblm_hburst,
	output wire [3:0]                ahblm_hprot,
	output wire                      ahblm_hmastlock,
	output wire [W_DATA-1:0]         ahblm_hwdata,
	input  wire [W_DATA-1:0]         ahblm_hrdata
);

integer i;

// Why we need buffering of address-phase controls:
//
// Returning positive hready_resp to a master signifies the end of the current
// data phase *and* the current address phase for that master.
// However, suppose that master 1 is currently active in the data phase and
// address phase, but master 0 (higher priority) also has an active address phase request.
//
// At the end of the data phase, we will signal hready_resp[1]. Master 1
// will accept any read data, but will also see this as acceptance of its outstanding
// address phase request. However, the arbiter will instead take master 0's transaction
// to the data phase, which is signalled by raising hready_resp[0] concurrently.
// Master 1 will now present the address phase request for its *third* bus cycle.
//
// We will have to buffer the address-phase controls from master 1's second bus cycle, and apply
// them continually until this cycle enters its data phase. We do not raise hready_resp[1] at this point
// because, from master 1's point of view, its second address phase already ended at the end of the first data phase.
// Once the data phase is complete, we raise hready_resp[1]. Master 1 ends its third
// address phase, and the address-phase buffer is loaded with these controls if master 1
// is blocked by a higher-priority master again; otherwise they will have already been passed through
// combinatorially to the slave, so there is no need to buffer them.
// Eventually, master 1 will be idle at the end of the data phase, at which point the buffered
// request will be HTRANS_IDLE, and the live port value will be muxed instead of the buffered value.

reg [W_ADDR-1:0]         saved_haddr      [0:N_PORTS-1];
reg                      saved_hwrite     [0:N_PORTS-1];
reg [1:0]                saved_htrans     [0:N_PORTS-1];
reg [2:0]                saved_hsize      [0:N_PORTS-1];
reg [2:0]                saved_hburst     [0:N_PORTS-1];
reg [3:0]                saved_hprot      [0:N_PORTS-1];
reg                      saved_hmastlock  [0:N_PORTS-1];

// "actual" is a mux between the saved signal, if valid, else the live signal on the port
reg [N_PORTS*W_ADDR-1:0] actual_haddr;
reg [N_PORTS-1:0]        actual_hwrite;
reg [N_PORTS*2-1:0]      actual_htrans;
reg [N_PORTS*3-1:0]      actual_hsize;
reg [N_PORTS*3-1:0]      actual_hburst;
reg [N_PORTS*4-1:0]      actual_hprot;
reg [N_PORTS-1:0]        actual_hmastlock;

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		if (saved_htrans[i][1]) begin
			actual_haddr     [i * W_ADDR +: W_ADDR] = saved_haddr     [i];
			actual_hwrite    [i]                    = saved_hwrite    [i];
			actual_htrans    [i * 2 +: 2]           = saved_htrans    [i];
			actual_hsize     [i * 3 +: 3]           = saved_hsize     [i];
			actual_hburst    [i * 3 +: 3]           = saved_hburst    [i];
			actual_hprot     [i * 4 +: 4]           = saved_hprot     [i];
			actual_hmastlock [i]                    = saved_hmastlock [i];
		end else begin
			actual_haddr     [i * W_ADDR +: W_ADDR] = ahbls_haddr     [i * W_ADDR +: W_ADDR];
			actual_hwrite    [i]                    = ahbls_hwrite    [i];
			actual_htrans    [i * 2 +: 2]           = ahbls_htrans    [i * 2 +: 2];
			actual_hsize     [i * 3 +: 3]           = ahbls_hsize     [i * 3 +: 3];
			actual_hburst    [i * 3 +: 3]           = ahbls_hburst    [i * 3 +: 3];
			actual_hprot     [i * 4 +: 4]           = ahbls_hprot     [i * 4 +: 4];
			actual_hmastlock [i]                    = ahbls_hmastlock [i];
		end
	end
end

// Address-phase arbitration

reg [N_PORTS-1:0] mast_req_a;
reg [N_PORTS:0]   already_granted_a;	// temp for priority mux
reg [N_PORTS-1:0] mast_gnt_a;

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		// HTRANS == 2'b10, 2'b11 when active
		// Uses buffered requests if valid
		mast_req_a[i] = actual_htrans[i * 2 + 1];
	end
end

always @ (*) begin
	already_granted_a[0] = 1'b0;
	for (i = 0; i < N_PORTS; i = i + 1) begin
		mast_gnt_a[i] = mast_req_a[i] && !already_granted_a[i];
		already_granted_a[i + 1] = already_granted_a[i] || mast_req_a[i];
	end
end

// Pass through address-phase signals based on grant

bitmap_mux #(
	.W_INPUT(W_ADDR),
	.N_INPUTS(N_PORTS)
) mux_haddr (
	.in(actual_haddr),
	.sel(mast_gnt_a),
	.out(ahblm_haddr)
);

bitmap_mux #(
	.W_INPUT(1),
	.N_INPUTS(N_PORTS)
) mux_hwrite (
	.in(actual_hwrite),
	.sel(mast_gnt_a),
	.out(ahblm_hwrite)
);

bitmap_mux #(
	.W_INPUT(2),
	.N_INPUTS(N_PORTS)
) mux_hwtrans (
	.in(actual_htrans),
	.sel(mast_gnt_a),
	.out(ahblm_htrans)
);

bitmap_mux #(
	.W_INPUT(3),
	.N_INPUTS(N_PORTS)
) mux_hsize (
	.in(actual_hsize),
	.sel(mast_gnt_a),
	.out(ahblm_hsize)
);

bitmap_mux #(
	.W_INPUT(3),
	.N_INPUTS(N_PORTS)
) mux_hburst (
	.in(actual_hburst),
	.sel(mast_gnt_a),
	.out(ahblm_hburst)
);

bitmap_mux #(
	.W_INPUT(4),
	.N_INPUTS(N_PORTS)
) mux_hprot (
	.in(actual_hprot),
	.sel(mast_gnt_a),
	.out(ahblm_hprot)
);

bitmap_mux #(
	.W_INPUT(1),
	.N_INPUTS(N_PORTS)
) mux_hmastlock (
	.in(actual_hmastlock),
	.sel(mast_gnt_a),
	.out(ahblm_hmastlock)
);

// AHB State Machine

reg [N_PORTS-1:0] mast_req_d;
reg [N_PORTS-1:0] mast_gnt_d;

assign ahblm_hready =
	mast_gnt_d ? |(ahbls_hready & mast_gnt_d) :
	mast_gnt_a ? |(ahbls_hready & mast_gnt_a) : 1'b1;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mast_gnt_d <= {N_PORTS{1'b0}};
		mast_req_d <= {N_PORTS{1'b0}};
		for (i = 0; i < N_PORTS; i = i + 1) begin
			{saved_haddr[i], saved_hwrite[i], saved_htrans[i], saved_hsize[i],
				saved_hburst[i], saved_hprot[i], saved_hmastlock[i]} <= {(W_ADDR + 14){1'b0}};
		end
	end else begin
		if (ahblm_hready) begin
			mast_gnt_d <= mast_gnt_a;
			mast_req_d <= mast_req_a;
		end
		for (i = 0; i < N_PORTS; i = i + 1) begin
			if (ahbls_hready_resp[i] && !(mast_req_a[i] && mast_gnt_a[i])) begin
				saved_haddr     [i] <= ahbls_haddr     [i * W_ADDR +: W_ADDR];
				saved_hwrite    [i] <= ahbls_hwrite    [i];
				saved_htrans    [i] <= ahbls_htrans    [i * 2 +: 2];
				saved_hsize     [i] <= ahbls_hsize     [i * 3 +: 3];
				saved_hburst    [i] <= ahbls_hburst    [i * 3 +: 3];
				saved_hprot     [i] <= ahbls_hprot     [i * 4 +: 4];
				saved_hmastlock [i] <= ahbls_hmastlock [i];
			end
		end
	end
end

// Data-phase signal passthrough

assign ahbls_hrdata = {N_PORTS{ahblm_hrdata}};

wire [N_PORTS-1:0] resp_mask = mast_gnt_a || mast_gnt_d ? mast_gnt_a | mast_gnt_d : {N_PORTS{1'b1}};
assign ahbls_hready_resp = {N_PORTS{ahblm_hready_resp}} & resp_mask;
assign ahbls_hresp = {N_PORTS{ahblm_hresp}} & resp_mask;

bitmap_mux #(
	.W_INPUT(W_DATA),
	.N_INPUTS(N_PORTS)
) hwdata_mux (
	.in(ahbls_hwdata),
	.sel(mast_gnt_d),
	.out(ahblm_hwdata)
);

endmodule