// Controller for an external 16-bit async SRAM (when combined with async_sram_phy.v)
// with multiple upstream ports:
//
// - 32-bit AHB port, read/write capable, for use by processor
// - 16-bit simple read-only port, for use by PPU
//
// The SRAM + PHY combination behaves similarly to a synchronous SRAM with a
// read latency of 2, and with the write data expected on the cycle following
// the address. Subject to these constraints, a new address can be issued to
// the SRAM every single cycle, and this is critical to PPU performance.
//
// Goals:
//
// - PPU requesting on every cycle will result in the PPU accessing SRAM on
//   every cycle
//
// - Active PPU requests will block AHB accesses from reaching SRAM
//
// - *Absolute minimum* of muxing on the AHB address path as this is likely to
//   end up as the critical path of the final system
//
// - AHB writes take 1 cycle for 8/16-bit and 2 cycles for 32-bit accesses
//
// - Try to get full SRAM throughput for overlapping 32-bit AHB reads, to keep
//   instruction fetch fast -- a bit tricky because of the 2-cycle SRAM
//   latency, but doable if we look ahead at the next AHB address phase
//   whilst it is still stalled.

`default_nettype none

module riscboy_sram_ctrl #(
	parameter W_HDATA     = 32,
	parameter W_HADDR     = 32,
	parameter W_SRAM_ADDR = 18,
	parameter W_SRAM_DATA = W_HDATA / 2 // Do not modify
) (
	// Globals
	input wire                      clk,
	input wire                      rst_n,

	// AHB lite interface
	input  wire [W_HADDR-1:0]       ahbls_haddr,
	input  wire [1:0]               ahbls_htrans,
	input  wire [2:0]               ahbls_hburst,
	input  wire [3:0]               ahbls_hprot,
	input  wire                     ahbls_hmastlock,
	input  wire                     ahbls_hwrite,
	input  wire [2:0]               ahbls_hsize,
	input  wire                     ahbls_hready,
	output wire                     ahbls_hready_resp,
	output wire                     ahbls_hresp,
	input  wire [W_HDATA-1:0]       ahbls_hwdata,
	output wire [W_HDATA-1:0]       ahbls_hrdata,

	// PPU pixel data DMA interface
	input  wire [W_SRAM_ADDR-1:0]   dma_addr,
	input  wire                     dma_addr_vld,
	output wire                     dma_addr_rdy,
	output wire [W_SRAM_DATA-1:0]   dma_rdata,
	output wire                     dma_rdata_vld,

	output wire [W_SRAM_ADDR-1:0]   sram_addr,
	output wire [W_SRAM_DATA-1:0]   sram_dq_out,
	output wire [W_SRAM_DATA-1:0]   sram_dq_oe,
	input  wire [W_SRAM_DATA-1:0]   sram_dq_in,
	output wire                     sram_ce_n,
	output wire                     sram_we_n,
	output wire                     sram_oe_n,
	output wire [W_SRAM_DATA/8-1:0] sram_byte_n
);

// ----------------------------------------------------------------------------
// SRAM pipeline status

// There are 3 SRAM pipeline phases:
//
// - Address phase: addresses are registered into SRAM PHY pads at the end of
//   this cycle
//
// - Write phase: write data is valid at the beginning of this cycle, and
//   registered into SRAM PHY pads on the negedge in the middle of this
//   cycle
//
// - Read phase: read data is registered out of the SRAM PHY at the beginning
//   of this cycle and registered back at its upstream bus destination by the
//   end of this cycle.

localparam W_OP = 3;
localparam OP_NONE  = 3'b000;
localparam OP_AHB_W = 3'b001;
localparam OP_AHB_R = 3'b010;
localparam OP_DMA_R = 3'b100;

wire [W_OP-1:0] sram_aph_op;
reg  [W_OP-1:0] sram_wph_op;
reg  [W_OP-1:0] sram_rph_op;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sram_wph_op <= OP_NONE;
		sram_rph_op <= OP_NONE;
	end else begin
		sram_wph_op <= sram_aph_op;
		sram_rph_op <= sram_wph_op;
	end
end

// ----------------------------------------------------------------------------
// AHB interface

// Sample AHB address phase attributes into data phase:

wire [W_SRAM_ADDR-1:0] ahb_ram_addr_aph = ahbls_haddr[$clog2(W_SRAM_DATA / 8) +: W_SRAM_ADDR];
wire                   ahb_read_aph     = ahbls_htrans[1] && !ahbls_hwrite;
wire                   ahb_write_aph    = ahbls_htrans[1] && ahbls_hwrite;
// TODO only valid for 16-bit SRAM:
wire                   ahb_2beat_aph    = ahbls_hsize[1];

wire                   issue_ahb_first_beat_early;

reg  [W_SRAM_ADDR-1:0] ahb_ram_addr_dph;
reg                    ahb_addr_align_dph;
reg                    ahb_read_dph;
reg                    ahb_write_dph;
reg                    ahb_valid_dph;
reg                    ahb_2beat_dph;
reg [2:0]              ahb_size_dph;
reg [1:0]              ahb_issue_ctr_dph;
reg                    ahb_first_beat_was_early;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ahb_ram_addr_dph <= {W_SRAM_ADDR{1'b0}};
		ahb_addr_align_dph <= 1'b0;
		ahb_read_dph <= 1'b0;
		ahb_write_dph <= 1'b0;
		ahb_valid_dph <= 1'b0;
		ahb_2beat_dph <= 1'b0;
		ahb_size_dph <= 3'h0;
		ahb_issue_ctr_dph <= 2'h0;
		ahb_first_beat_was_early <= 1'b0;
	end else if (ahbls_hready) begin
		ahb_ram_addr_dph <= ahb_ram_addr_aph | {{W_SRAM_ADDR-1{1'b0}},
			ahb_first_beat_was_early || |(sram_aph_op & (OP_AHB_W | OP_AHB_R))
		};
		ahb_addr_align_dph <= ahbls_haddr[0];
		ahb_read_dph <= ahb_read_aph;
		ahb_write_dph <= ahb_write_aph;
		ahb_valid_dph <= ahb_read_aph || ahb_write_aph;
		ahb_2beat_dph <= ahb_2beat_aph;
		ahb_size_dph <= ahbls_hsize;
		ahb_issue_ctr_dph <= {1'b0, ahb_first_beat_was_early} + {1'b0, |(sram_aph_op & (OP_AHB_R | OP_AHB_W))};
		ahb_first_beat_was_early <= 1'b0;
	end else begin
		// Be careful not to count transfers issued in anticipation of
		// the *next* dphase as part of the current one:
		ahb_issue_ctr_dph <= ahb_issue_ctr_dph +
			{1'b0, |(sram_aph_op & (OP_AHB_R | OP_AHB_W)) && !issue_ahb_first_beat_early};
		if (ahb_2beat_dph) begin
			ahb_ram_addr_dph[0] <= ahb_issue_ctr_dph[0] || |(sram_aph_op & (OP_AHB_R | OP_AHB_W));
		end
		ahb_first_beat_was_early <= ahb_first_beat_was_early || issue_ahb_first_beat_early;
	end
end

// Generate AHB response:

reg [W_SRAM_DATA-1:0] ahb_rdata_buf;
reg                   ahb_final_sram_beat_dph;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ahb_rdata_buf <= {W_SRAM_DATA{1'b0}};
		ahb_final_sram_beat_dph <= 1'b0;
	end else begin
		if (|(sram_rph_op & OP_AHB_R)) begin
			ahb_rdata_buf <= sram_dq_in;
		end
		if (ahbls_hready) begin
			ahb_final_sram_beat_dph <= !ahb_2beat_aph;
		end else begin
			ahb_final_sram_beat_dph <= ahb_final_sram_beat_dph || (
				ahb_read_dph ? |(sram_rph_op & OP_AHB_R) : |(sram_wph_op & OP_AHB_W)
			);
		end
	end
end

assign ahbls_hresp = 1'b0;
assign ahbls_hrdata = {sram_dq_in, ahb_2beat_dph ? ahb_rdata_buf : sram_dq_in};
assign ahbls_hready_resp =
	ahb_read_dph  ? |(sram_rph_op & OP_AHB_R) && ahb_final_sram_beat_dph :
	ahb_write_dph ? |(sram_wph_op & OP_AHB_W) && ahb_final_sram_beat_dph : 1'b1;

// ----------------------------------------------------------------------------
// SRAM control signals

// The address issued to SRAM in SRAM address phase is from one of 3 sources:
//
// - DMA address bus (always used when dma_addr_vld is asserted)
//
// - AHB address bus, during AHB address phase
//
// - AHB data-phase address, sampled at end of AHB address phase, used for
//   second beat of 2-beat accesses, and for first beat of access deferred
//   from address phase to data phase due to contention with the DMA port

wire dph_last_beat_issued = ahb_2beat_dph ? ahb_issue_ctr_dph[1] : ahb_issue_ctr_dph[0];

wire sram_from_ahb_read_dph       = ahb_read_dph  && !dph_last_beat_issued;
wire sram_from_ahb_write_dph      = ahb_write_dph && !dph_last_beat_issued;
wire sram_from_ahb_read_aph       = ahb_read_aph  && ahbls_hready && !(ahb_first_beat_was_early && !ahb_2beat_aph);
wire sram_from_ahb_write_aph      = ahb_write_aph && ahbls_hready;
wire sram_from_ahb_read_aph_early = ahb_read_aph  && !ahbls_hready_resp;

// Note the toggling is only required for non-early read aphase, as only reads
// are ever done early, but it's harmless to use the same address term
// everywhere (and saves a little logic)
wire [W_SRAM_ADDR-1:0] ahb_addr_aph_toggled = ahb_ram_addr_aph | {{W_SRAM_ADDR-1{1'b0}}, ahb_first_beat_was_early};

assign {issue_ahb_first_beat_early, sram_aph_op, sram_addr} =
	dma_addr_vld                 ? {1'b0, OP_DMA_R, dma_addr            } :
	sram_from_ahb_read_dph       ? {1'b0, OP_AHB_R, ahb_ram_addr_dph    } :
	sram_from_ahb_write_dph      ? {1'b0, OP_AHB_W, ahb_ram_addr_dph    } :
	sram_from_ahb_read_aph       ? {1'b0, OP_AHB_R, ahb_addr_aph_toggled} :
	sram_from_ahb_write_aph      ? {1'b0, OP_AHB_W, ahb_addr_aph_toggled} :
	sram_from_ahb_read_aph_early ? {1'b1, OP_AHB_R, ahb_addr_aph_toggled} :
	                               {1'b0, OP_NONE,  {W_SRAM_ADDR{1'bx}}};

// Generate control signals accordingly
assign sram_ce_n = ~|sram_aph_op;
assign sram_oe_n = ~|(sram_aph_op & (OP_AHB_R | OP_DMA_R));
assign sram_we_n = ~|(sram_aph_op & OP_AHB_W);

// TODO only valid for 16-bit:
assign sram_byte_n = ~(
	dma_addr_vld                           ? 2'b11                                       :
	ahb_valid_dph && !dph_last_beat_issued ? {|ahb_size_dph, 1'b1} << ahb_addr_align_dph :
	                                         {|ahbls_hsize,  1'b1} << ahbls_haddr[0]
);

reg write_addr_hword_sel;
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		write_addr_hword_sel <= 1'b0;
	end else if (|(sram_aph_op & OP_AHB_W)) begin
		write_addr_hword_sel <= sram_addr[0];
	end
end

assign sram_dq_oe = {W_SRAM_DATA{!sram_we_n}};
assign sram_dq_out = ahbls_hwdata[write_addr_hword_sel * W_SRAM_DATA +: W_SRAM_DATA];

// ----------------------------------------------------------------------------
// DMA port handshaking

assign dma_addr_rdy = 1'b1;
assign dma_rdata_vld = |(sram_rph_op & OP_DMA_R);
assign dma_rdata = sram_dq_in;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
