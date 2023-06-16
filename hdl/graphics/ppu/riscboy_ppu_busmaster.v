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
// Note there is a through path from aph_vld to aph_rdy (due to arbitration
// between requestors), so don't use rdy to generate vld :)
//
// After asserting aph_vld, the request must stay asserted and stable until
// aph_rdy goes high. It is not necessary to wait for dphase to complete
// before asserting another aphase.

`default_nettype none

module riscboy_ppu_busmaster #(
	parameter N_REQ         = 10,
	parameter W_ADDR        = 18,
	parameter W_DATA        = 16,
	parameter ADDR_MASK     = {W_ADDR{1'b1}},
	parameter MAX_IN_FLIGHT = 3
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

	// Memory access port
	output wire [W_ADDR-1:0]       mem_addr,
	output wire                    mem_addr_vld,
	input  wire                    mem_addr_rdy,
	input  wire [W_DATA-1:0]       mem_rdata,
	input  wire                    mem_rdata_vld
);
// ----------------------------------------------------------------------------
// Request arbitration

// Simple priority arbitration. No need to hold the grant stable here as this
// grant (and the associated address) is sampled when the address pipestage
// updates.

wire space_in_reqmask_fifo;
wire block_issue = !ppu_running || !space_in_reqmask_fifo;
wire [N_REQ-1:0] req_filtered = req_aph_vld & {N_REQ{!block_issue}};
wire [N_REQ-1:0] grant_aph;

onehot_priority #(
	.W_INPUT (N_REQ)
) req_priority_u (
	.in  (req_filtered),
	.out (grant_aph)
);

// ----------------------------------------------------------------------------
// Bus request generation + address pipestage

wire [W_ADDR-1:0] req_addr_muxed;

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (W_ADDR)
) addr_mux_u (
	.in  (req_aph_addr),
	.sel (grant_aph),
	.out (req_addr_muxed)
);

reg [W_ADDR-1:0] pipestage_addr;
reg [N_REQ-1:0]  pipestage_reqmask;

wire pipestage_update = mem_addr_vld ? mem_addr_rdy : |req_filtered;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pipestage_addr <= {W_ADDR{1'b0}};
		pipestage_reqmask <= {N_REQ{1'b0}};
	end else if (pipestage_update) begin
		pipestage_addr <= req_addr_muxed & ADDR_MASK;
		pipestage_reqmask <= grant_aph;
	end
end

assign mem_addr     = pipestage_addr & ADDR_MASK;
assign mem_addr_vld = |pipestage_reqmask;

assign req_aph_rdy = grant_aph & {N_REQ{pipestage_update}};


// ----------------------------------------------------------------------------
// Data phase response steering

// Need to remember which requestor is associated with each in-flight bus
// transfer, so that data can be returned to the correct requestor when the
// transfer completes.

wire [N_REQ-1:0] dph_reqmask;
localparam W_REQMASK_FIFO_LEVEL = $clog2(MAX_IN_FLIGHT + 1);
wire [W_REQMASK_FIFO_LEVEL-1:0] reqmask_fifo_level;

sync_fifo #(
	.DEPTH  (MAX_IN_FLIGHT),
	.WIDTH  (N_REQ)
) in_flight_reqmask_fifo_u (
	.clk    (clk),
	.rst_n  (rst_n),
	.wdata  (pipestage_reqmask),
	.wen    (mem_addr_vld && mem_addr_rdy),
	.rdata  (dph_reqmask),
	.ren    (mem_rdata_vld),
	.flush  (1'b0),
	.full   (/* unused */),
	.empty  (/* unused */),
	.level  (reqmask_fifo_level)
);

assign req_dph_data = {N_REQ{mem_rdata}};
assign req_dph_vld = dph_reqmask & {N_REQ{mem_rdata_vld}};

assign space_in_reqmask_fifo = (reqmask_fifo_level
	+ {{W_REQMASK_FIFO_LEVEL-1{1'b0}}, |pipestage_reqmask}
	- {{W_REQMASK_FIFO_LEVEL-1{1'b0}}, mem_rdata_vld}
	) < MAX_IN_FLIGHT;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
