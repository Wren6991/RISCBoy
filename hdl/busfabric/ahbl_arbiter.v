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
 * Recommend that wiring up is scripted.
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

// Address-phase arbitration

wire [N_PORTS-1:0] mast_req_a;
wire [N_PORTS:0]   already_granted_a;
wire [N_PORTS-1:0] mast_gnt_a;

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		// HTRANS == 2'b10, 2'b11 when active
		mast_req_a[i] = ahbls_htrans[i * 2 +: 2][1];
	end
end

// Synthesis will squash this down into something nice
always @ (*) begin
	already_granted_a[0] = 1'b0;
	for (i = 0; i < N_PORTS; i = i + 1)) begin
		mast_gnt_a[i] = mast_req_a[i] && !already_granted_a[i]
		already_granted_a[i + 1] = already_granted_a[i] || mast_req_a[i];
	end
end

// Pass through address-phase signals based on grant

bitmap_mux #(
	.W_INPUT(W_ADDR),
	.N_INPUTS(N_PORTS)
) mux_haddr (
	.in(ahbls_haddr),
	.sel(mast_gnt_a),
	.out(ahblm_haddr)
);

bitmap_mux #(
	.W_INPUT(1),
	.N_INPUTS(N_PORTS)
) mux_hwrite (
	.in(ahbls_hwrite),
	.sel(mast_gnt_a),
	.out(ahblm_hwrite)
);

bitmap_mux #(
	.W_INPUT(2),
	.N_INPUTS(N_PORTS)
) mux_hwtrans (
	.in(ahbls_htrans),
	.sel(mast_gnt_a),
	.out(ahblm_htrans)
);

bitmap_mux #(
	.W_INPUT(3),
	.N_INPUTS(N_PORTS)
) mux_hsize (
	.in(ahbls_hsize),
	.sel(mast_gnt_a),
	.out(ahblm_hsize)
);

bitmap_mux #(
	.W_INPUT(3),
	.N_INPUTS(N_PORTS)
) mux_hburst (
	.in(ahbls_hburst),
	.sel(mast_gnt_a),
	.out(ahblm_hburst)
);

bitmap_mux #(
	.W_INPUT(4),
	.N_INPUTS(N_PORTS)
) mux_hprot (
	.in(ahbls_hprot),
	.sel(mast_gnt_a),
	.out(ahblm_hprot)
);

bitmap_mux #(
	.W_INPUT(1),
	.N_INPUTS(N_PORTS)
) mux_hsize (
	.in(ahbls_hmastlock),
	.sel(mast_gnt_a),
	.out(ahblm_hmastlock)
);

// AHB State Machine

// Data-phase grant bitmap
reg [N_PORTS-1:0] mast_gnt_d;

assign ahblm_hready =
	mast_gnt_d ? ahbls_hready & mast_gnt_d :
	mast_gnt_a ? ahbls_hready & mast_gnt_a : 1'b1;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mast_gnt_d <= {N_PORTS{1'b0}};
	end else begin
		if (ahblm_hready) begin
			mast_gnt_d <= mast_gnt_a;	
		end
	end
end

// Data-phase signal passthrough

assign ahbls_hrdata = {N_PORTS{ahblm_hrdata}};
assign ahbls_hready_resp = {N_PORTS{ahblm_hready_resp}};


bitmap_mux #(
	.W_INPUT(W_DATA),
	.N_INPUTS(N_PORTS)
) hwdata_mux (
	.in(ahbls_hwdata),
	.sel(mast_gnt_d),
	.out(ahbll_hwdata)
);

endmodule