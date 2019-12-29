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
  * tie src_hready_resp across to src_hready.
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
	parameter ADDR_MASK = 64'hf0000000_f0000000,
	parameter CONN_MASK = {N_PORTS{1'b1}}
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// From master; functions as slave port
	input  wire                      src_hready,
	output wire                      src_hready_resp,
	output wire                      src_hresp,
	input  wire [W_ADDR-1:0]         src_haddr,
	input  wire                      src_hwrite,
	input  wire [1:0]                src_htrans,
	input  wire [2:0]                src_hsize,
	input  wire [2:0]                src_hburst,
	input  wire [3:0]                src_hprot,
	input  wire                      src_hmastlock,
	input  wire [W_DATA-1:0]         src_hwdata,
	output wire [W_DATA-1:0]         src_hrdata,

	// To slaves; function as master ports
	output wire [N_PORTS-1:0]        dst_hready,
	input  wire [N_PORTS-1:0]        dst_hready_resp,
	input  wire [N_PORTS-1:0]        dst_hresp,
	output wire [N_PORTS*W_ADDR-1:0] dst_haddr,
	output wire [N_PORTS-1:0]        dst_hwrite,
	output reg  [N_PORTS*2-1:0]      dst_htrans,
	output wire [N_PORTS*3-1:0]      dst_hsize,
	output wire [N_PORTS*3-1:0]      dst_hburst,
	output wire [N_PORTS*4-1:0]      dst_hprot,
	output wire [N_PORTS-1:0]        dst_hmastlock,
	output wire [N_PORTS*W_DATA-1:0] dst_hwdata,
	input  wire [N_PORTS*W_DATA-1:0] dst_hrdata
);

localparam HTRANS_IDLE = 2'b00;

integer i;

// Address decode

reg [N_PORTS-1:0] slave_sel_a_nomask;
reg [N_PORTS-1:0] slave_sel_a;
reg decode_err_a;

always @ (*) begin
	if (src_htrans == HTRANS_IDLE) begin
		slave_sel_a_nomask = {N_PORTS{1'b0}};
		slave_sel_a = {N_PORTS{1'b0}};
		decode_err_a = 1'b0;
	end else begin
		for (i = 0; i < N_PORTS; i = i + 1) begin
			slave_sel_a_nomask[i] = !((src_haddr ^ ADDR_MAP[i * W_ADDR +: W_ADDR])
				& ADDR_MASK[i * W_ADDR +: W_ADDR]);
		end
		slave_sel_a = slave_sel_a_nomask & CONN_MASK;
		decode_err_a = !slave_sel_a_nomask;
	end
end

// Address-phase passthrough
// Be lazy and don't blank out signals to non-selected slaves,
// except for HTRANS, which must be gated off to stop spurious transfer.
// Costs transitions, but saves gates.

assign dst_haddr     = {N_PORTS{src_haddr}};
assign dst_hwrite    = {N_PORTS{src_hwrite}};
assign dst_hsize     = {N_PORTS{src_hsize}};
assign dst_hburst    = {N_PORTS{src_hburst}};
assign dst_hprot     = {N_PORTS{src_hprot}};
assign dst_hmastlock = {N_PORTS{src_hmastlock}};

always @ (*) begin
	for (i = 0; i < N_PORTS; i = i + 1) begin
		dst_htrans[i * 2 +: 2] = slave_sel_a[i] ? src_htrans : HTRANS_IDLE;
	end 
end

// AHB state machine

reg [N_PORTS-1:0] slave_sel_d;
reg decode_err_d;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		slave_sel_d <= {N_PORTS{1'b0}};
		decode_err_d <= 1'b0;
	end else begin
		if (src_hready) begin
			slave_sel_d <= slave_sel_a;
			decode_err_d <= decode_err_a;
		end
	end
end

// Data-phase passthrough

assign dst_hwdata = {N_PORTS{src_hwdata}};
assign dst_hready = {N_PORTS{src_hready}};

onehot_mux #(
	.N_INPUTS(N_PORTS),
	.W_INPUT(W_DATA)
) hrdata_mux (
	.in(dst_hrdata),
	.sel(slave_sel_d),
	.out(src_hrdata)
);

// We want to avoid any combinatorial paths from htrans->hready
// both for timing closure reasons, and to avoid loops with poorly
// behaved masters.
// One rule to avoid this is to *only use data-phase state for muxing*

assign src_hready_resp = !slave_sel_d || |(slave_sel_d & dst_hready_resp);
assign src_hresp = decode_err_d || |(slave_sel_d & dst_hresp);

endmodule
