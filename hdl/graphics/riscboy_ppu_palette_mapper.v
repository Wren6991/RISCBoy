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

module riscboy_ppu_palette_mapper #(
	parameter W_PIXDATA = 15,
	parameter W_PALETTE_IDX = 8
) (
	input wire                     clk,
	input wire                     rst_n,

	input wire                     in_vld,
	input wire                     in_rdy,
	input wire [W_PIXDATA-1:0]     in_data,
	input wire                     in_paletted,

	input wire [W_PALETTE_IDX-1:0] pram_waddr,
	input wire [W_PIXDATA-1:0]     pram_wdata,
	input wire                     pram_wen,

	output wire                    out_vld,
	output wire                    out_rdy,
	output wire [W_PIXDATA-1:0]    out_data
);

// PRAM read port is synchronous. We need a register to hold non-paletted
// pixels to match the delay (could do without, but would expose some nasty
// races)

reg [W_PIXDATA-1:0] sidestep_data;
reg                 sidestep_vld;
reg                 pram_out_vld;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sidestep_data <= {W_PIXDATA{1'b0}};
		sidestep_vld <= 1'b0;
		pram_out_vld <= 1'b0;
	end else begin
		if (out_rdy) begin
			sidestep_vld <= 1'b0;
			pram_out_vld <= 1'b0;
		end
		if (in_vld && in_rdy) begin
			if (in_paletted) begin
				pram_out_vld <= 1'b1;
			end else begin
				sidestep_data <= in_data;
				sidestep_vld <= 1'b1;
			end
		end
	end
end

wire [W_PIXDATA-1:0] pram_rdata;

// Note that we want to stick the pixel data onto the PRAM address port
// immediately: if it is left hanging around, somebody might come and rewrite
// the PRAM in the meantime, since raster counter is incremented when the
// blender completes a pixel.

assign in_rdy = !(out_vld && !out_rdy);

riscboy_palette_ram #(
	.W_DATA (W_PIXDATA),
	.W_ADDR (W_PALETTE_IDX)
) pram_u (
	.clk   (clk),
	.waddr (pram_waddr),
	.wdata (pram_wdata),
	.wen   (pram_wen),

	.raddr (in_data[0 +: W_PALETTE_IDX]),
	.rdata (pram_rdata),
	.ren   (in_vld && in_rdy && in_paletted)
);

assign out_vld = sidestep_vld || pram_out_vld;
assign out_data = sidestep_vld ? sidestep_data : pram_rdata;

endmodule
