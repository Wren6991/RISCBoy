/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2023 Luke Wren                                       *
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

// Adapt PPU's RAM bus to an AHB-Lite port, so it can be dropped into AHB-Lite
// systems. Currently this supports only a 32-bit AHB data bus.

`default_nettype none

module riscboy_ppu_ahbl_adapter #(
	parameter W_MEM_ADDR    = 18,
	parameter W_MEM_DATA    = 16,
	parameter W_HADDR       = 32,
	parameter DST_ADDR_BASE = {W_HADDR{1'b0}},
	parameter W_HDATA       = 2 * W_MEM_DATA // Do not modify
) (
	input  wire                  clk,
	input  wire                  rst_n,

	output wire [W_MEM_ADDR-1:0] ppu_addr,
	output wire                  ppu_addr_vld,
	input  wire                  ppu_addr_rdy,
	input  wire [W_MEM_DATA-1:0] ppu_rdata,
	input  wire                  ppu_rdata_vld,

	output wire [W_HADDR-1:0]    ahblm_haddr,
	output wire                  ahblm_hwrite,
	output wire [1:0]            ahblm_htrans,
	output wire [2:0]            ahblm_hsize,
	output wire [2:0]            ahblm_hburst,
	output wire [3:0]            ahblm_hprot,
	output wire                  ahblm_hmastlock,
	input  wire                  ahblm_hready,
	input  wire                  ahblm_hresp,
	output wire [W_HDATA-1:0]    ahblm_hwdata,
	input  wire [W_HDATA-1:0]    ahblm_hrdata
);

localparam ADDR_BYTE_SHIFT = $clog2(W_HDATA / W_MEM_DATA);

assign ahblm_htrans = {ppu_addr_vld, 1'b0};
assign ahblm_hsize = $clog2(W_MEM_DATA / 8);
assign ppu_addr_rdy = ppu_addr_vld && ahblm_hready;

assign ahblm_haddr = DST_ADDR_BASE + {
	{W_HADDR - W_MEM_ADDR - ADDR_BYTE_SHIFT{1'b0}},
	ppu_addr,
	{ADDR_BYTE_SHIFT{1'b0}}
};

// Stop pretending to be generic over all possible sizes at this point --
// we're assuming the downstream bus is double the width of the upstream
reg dph_valid;
reg dph_align;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dph_valid <= 1'b0;
		dph_align <= 1'b0;
	end else if (ahblm_hready) begin
		dph_valid <= ahblm_htrans[1];
		dph_align <= ppu_addr[0];
	end
end

assign ppu_rdata = ahblm_hrdata[dph_align * W_MEM_DATA +: W_MEM_DATA];
assign ppu_rdata_vld = dph_valid && ahblm_hready;

// Assign unused outputs to safe values
assign ahblm_hwrite    = 1'b0;
assign ahblm_hburst    = 3'h0;
assign ahblm_hprot     = 4'h1;
assign ahblm_hmastlock = 1'b0;
assign ahblm_hwdata    = {W_HDATA{1'b0}};

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
