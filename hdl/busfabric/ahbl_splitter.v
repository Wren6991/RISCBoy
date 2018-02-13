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
  * AHB-lite 1:N splitter
  * If this splitter is at the top of the busfabric (i.e. its master is a true master),
  * tie ahblm_hready_resp across to ahblm_hready.
  *
  * It is up to the system implementer to *ensure that the address mapped ranges
  *  are mutually exclusive*.
  */

// TODO: burst support

module ahbl_splitter #(
	parameter N_PORTS = 2,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter ADDR_MAP  = 64'h20000000_00000000,
	parameter ADDR_MASK = 64'hf0000000_f0000000
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// Master port
	input  wire                      abhlm_hready,
	output wire                      ahblm_hready_resp,
	output wire                      ahblm_hresp,
	input  wire [W_ADDR-1:0]         ahblm_haddr,
	input  wire                      ahblm_hwrite,
	input  wire [1:0]                ahblm_htrans,
	input  wire [2:0]                ahblm_hsize,
	input  wire [2:0]                ahblm_hburst,
	input  wire [3:0]                ahblm_hprot,
	input  wire                      ahblm_hmastlock,
	input  wire [W_DATA-1:0]         ahblm_hwdata,
	output wire [W_DATA-1:0]         ahblm_hrdata,

	// Slave ports
	output wire [N_PORTS-1:0]        abhls_hready,
	input  wire [N_PORTS-1:0]        ahbls_hready_resp,
	input  wire [N_PORTS-1:0]        ahbls_hresp,
	output wire [N_PORTS*W_ADDR-1:0] ahbls_haddr,
	output wire [N_PORTS-1:0]        ahbls_hwrite,
	output wire [N_PORTS*2-1:0]      ahbls_htrans,
	output wire [N_PORTS*3-1:0]      ahbls_hsize,
	output wire [N_PORTS*3-1:0]      ahbls_hburst,
	output wire [N_PORTS*4-1:0]      ahbls_hprot,
	output wire [N_PORTS-1:0]        ahbls_hmastlock,
	output wire [N_PORTS*W_DATA-1:0] ahbls_hwdata,
	input  wire [N_PORTS*W_DATA-1:0] ahbls_hrdata
);

integer i;

// Address decode

wire [N_PORTS-1:0] slave_sel_a;

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		slave_sel_a[i] = !((ahblm_haddr ^ ADDR_MAP[i * W_ADDR +: W_ADDR])
			& ADDR_MASK[i * W_ADDR +: W_ADDR]);
	end
end

// Address-phase passthrough
// Be lazy and don't blank out signals to non-selected slaves,
// except for HTRANS, which must be gated off to stop spurious transfer.

assign ahbls_haddr     = {N_PORTS{ahblm_haddr}};
assign ahbls_hwrite    = {N_PORTS{ahblm_hwrite}};
assign ahbls_hsize     = {N_PORTS{ahblm_hsize}};
assign ahbls_hburst    = {N_PORTS{ahblm_hburst}};
assign ahbls_hprot     = {N_PORTS{ahblm_hprot}};
assign ahbls_hmastlock = {N_PORTS{ahblm_hmastlock}};

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		ahbls_htrans[i * 2 +: 2] = slave_sel_a[i] ? ahblm_htrans : 2'b00;
	end
end

// AHB state machine

reg [N_PORTS-1:0] slave_sel_d;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		slave_sel_d <= {N_PORTS{1'b0}};
	end else begin
		if (ahblm_hready) begin
			slave_sel_d <= slave_sel_a;
		end
	end
end

// Data-phase passthrough

assign ahbls_hwdata = {N_PORTS{ahblm_hwdata}};
assign ahbls_hready = {N_PORTS{ahblm_hready}};

bitmap_mux #(
	.N_INPUTS(N_PORTS),
	.W_INPUT(W_DATA)
) hrdata_mux (
	.in(ahbls_hrdata),
	.sel(slave_sel_d),
	.out(ahblm_hrdata)
);

bitmap_mux #(
	.N_INPUTS(N_PORTS),
	.W_INPUT(1)
) hready_resp_mux (
	.in(ahbls_hready_resp),
	.sel(slave_sel_d),
	.out(ahblm_hready_resp)
);