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

// Address phase signals have rdy/vld -- we assert backpressure based on
// contention and bus stall. Data phase signals are vld only -- requestor must
// accept data immediately.
//
// Note there is a through path from aph_vld to aph_rdy, so don't use rdy to
// generate vld :)
//
// After asserting aph_vld, the request must stay asserted and stable until
// aph_rdy goes high. It is not necessary to wait for dphase to complete
// before asserting another aphase.

module riscboy_ppu_busmaster #(
	parameter N_REQ = 10,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,  // must be 32 (just up here for use on ports)
	parameter ADDR_MASK = {W_ADDR{1'b1}}
) (
	input  wire                    clk,
	input  wire                    rst_n,

	input  wire                    ppu_running,


	input  wire [N_REQ-1:0]        req_aph_vld,
	output wire [N_REQ-1:0]        req_aph_rdy,
	input  wire [N_REQ*2-1:0]      req_aph_size,
	input  wire [N_REQ*W_ADDR-1:0] req_aph_addr,

	output wire [N_REQ-1:0]        req_dph_vld,
	output wire [N_REQ*W_DATA-1:0] req_dph_data,

	// AHB-lite Master port
	output wire [W_ADDR-1:0]       ahblm_haddr,
	output wire                    ahblm_hwrite,
	output wire [1:0]              ahblm_htrans,
	output wire [2:0]              ahblm_hsize,
	output wire [2:0]              ahblm_hburst,
	output wire [3:0]              ahblm_hprot,
	output wire                    ahblm_hmastlock,
	input  wire                    ahblm_hready,
	input  wire                    ahblm_hresp,
	output wire [W_DATA-1:0]       ahblm_hwdata,
	input  wire [W_DATA-1:0]       ahblm_hrdata
);

// Tie off unused bus outputs

assign ahblm_hwrite = 1'b0;
assign ahblm_hburst = 3'h0;
assign ahblm_hprot = 4'b0011; // non-cacheable non-bufferable privileged data access
assign ahblm_hmastlock = 1'b0;
assign ahblm_hwdata = {W_DATA{1'b0}};

// ----------------------------------------------------------------------------
// Request arbitration

wire [N_REQ-1:0] grant_aph_comb;
reg  [N_REQ-1:0] grant_aph_reg;
wire [N_REQ-1:0] grant_aph = |grant_aph_reg ? grant_aph_reg : grant_aph_comb;

reg  [N_REQ-1:0] grant_dph;
wire [N_REQ-1:0] req_filtered = req_aph_vld & {N_REQ{ppu_running}};

onehot_priority #(
	.W_INPUT (N_REQ)
) req_priority_u (
	.in  (req_filtered),
	.out (grant_aph_comb)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		grant_aph_reg <= {N_REQ{1'b0}};
		grant_dph <= {N_REQ{1'b0}};
	end else if (ahblm_hready) begin
		grant_aph_reg <= {N_REQ{1'b0}};
		grant_dph <= grant_aph;
	end else begin
		grant_aph_reg <= grant_aph;
	end
end

// ----------------------------------------------------------------------------
// Bus request generation

wire [W_ADDR-1:0] req_addr_muxed;
wire [1:0]        req_size_muxed;

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (W_ADDR)
) addr_mux_u (
	.in  (req_aph_addr),
	.sel (grant_aph),
	.out (req_addr_muxed)
);

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (2)
) size_mux_u (
	.in  (req_aph_size),
	.sel (grant_aph),
	.out (req_size_muxed)
);

assign ahblm_haddr = req_addr_muxed & ADDR_MASK;
assign ahblm_hsize = {1'b0, req_size_muxed};
assign ahblm_htrans = {|grant_aph, 1'b0};

assign req_aph_rdy = grant_aph & {N_REQ{ahblm_hready}};

// ----------------------------------------------------------------------------
// Data phase response steering

reg [1:0]        dph_buf_addr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dph_buf_addr <= 2'h0;
	end else if (ahblm_hready) begin
		dph_buf_addr <= ahblm_haddr[1:0];
	end
end

wire [W_DATA-1:0] hrdata_steered = {
	ahblm_hrdata[31:16],
	dph_buf_addr[1] ? ahblm_hrdata[31:24] : ahblm_hrdata[15:8],
	ahblm_hrdata[dph_buf_addr * 8 +: 8]
};

assign req_dph_vld = grant_dph & {N_REQ{ahblm_hready}};
assign req_dph_data = {N_REQ{hrdata_steered}};

endmodule
