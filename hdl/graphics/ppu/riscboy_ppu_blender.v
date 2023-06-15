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

// For now we are just doing 1 bit alpha blending, so no need to read from
// the scanline buffer -- just gate the writes based on alpha.
//
// Input data may be paletted. We perform the lookup here, and use the alpha
// bit from the palette RAM to determine whether a paletted pixel is
// transparent.
//
// Handshake is vld-only. We can not put backpressure on pixel data from
// upstream (else the bus handling on the pixel data side would be much more
// complex) and, as a result, we can not tolerate backpressure from the scan
// buffer. We assume exclusive access.

`default_nettype none

module riscboy_ppu_blender #(
	parameter W_PIXDATA = 16,
	parameter W_COORD_SX = 9,
	parameter W_PALETTE_IDX = 8
) (
	input  wire                     clk,
	input  wire                     rst_n,

	input  wire                     in_vld,
	input  wire [W_PIXDATA-1:0]     in_data,
	input  wire                     in_paletted,
	input  wire                     in_blank, // output a blank pixel (for non-alpha-related reasons e.g. outside of transformed sprite bounds)

	input  wire [W_PALETTE_IDX-1:0] pram_waddr,
	input  wire [W_PIXDATA-1:0]     pram_wdata,
	input  wire                     pram_wen,

	output wire  [W_COORD_SX-1:0]   scanbuf_waddr,
	output wire  [W_PIXDATA-2:0]    scanbuf_wdata,
	output wire                     scanbuf_wen,

	input wire                      span_start,
	input wire  [W_COORD_SX-1:0]    span_x0,
	input wire  [W_COORD_SX-1:0]    span_count,
	output reg                      span_done
);

wire [W_PIXDATA-1:0] pmap_out_data;
wire                 pmap_out_vld;


riscboy_ppu_palette_mapper #(
	.W_PIXDATA(W_PIXDATA),
	.W_PALETTE_IDX(W_PALETTE_IDX)
) palette_mapper (
	.clk         (clk),
	.rst_n       (rst_n),
	.in_vld      (in_vld),
	.in_data     (in_data),
	.in_paletted (in_paletted),
	.pram_waddr  (pram_waddr),
	.pram_wdata  (pram_wdata),
	.pram_wen    (pram_wen),
	.out_vld     (pmap_out_vld),
	.out_data    (pmap_out_data)
);

reg [W_COORD_SX-1:0] x_coord;
reg [W_COORD_SX-1:0] x_remaining;
reg out_blank;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_done <= 1'b1;
		x_coord <= {W_COORD_SX{1'b0}};
		x_remaining <= {W_COORD_SX{1'b0}};
	end else if (span_start) begin
		span_done <= 1'b0;
		x_coord <= span_x0;
		x_remaining <= span_count;
	end else if (pmap_out_vld) begin
		x_coord <= x_coord + 1'b1;
		x_remaining <= x_remaining - 1'b1;
		// Note span_count is 1 below actual count, i.e. if initialised to 1, we draw 2 pixels
		if (~|x_remaining) begin
			span_done <= 1'b1;
		end
`ifdef FORMAL
		assert(!span_done);
`endif
	end
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		out_blank <= 1'b0;
	end else begin
		out_blank <= in_vld && in_blank;
	end
end
assign scanbuf_waddr = x_coord;
assign scanbuf_wdata = pmap_out_data;
assign scanbuf_wen = pmap_out_vld && pmap_out_data[W_PIXDATA-1] // "Alpha blending" :)
	&& !out_blank;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
