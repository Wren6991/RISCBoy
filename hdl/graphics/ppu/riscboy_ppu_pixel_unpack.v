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

// Pick + mask individual pixels from bus data, or generate constant colour
// spans, and pass them on for blending and palette mapping.

module riscboy_ppu_pixel_unpack #(
	parameter W_COORD_SX = 9,
	parameter W_SPAN_TYPE = 3,
	parameter W_DATA = 16 // do not modify
) (
	input wire                   clk,
	input wire                   rst_n,

	// Pixel data
	input wire [W_DATA-1:0]      in_data,
	input wire                   in_vld,

	// Pixel metadata
	input wire [3:0]             pinfo_u,
	input wire                   pinfo_discard,
	input wire                   pinfo_vld,
	output wire                  pinfo_rdy,

	input wire                   span_start,
	input wire [W_COORD_SX-1:0]  span_x0,
	input wire [W_COORD_SX-1:0]  span_count,
	input wire [W_SPAN_TYPE-1:0] span_type,
	input wire [1:0]             span_pixmode,
	input wire [2:0]             span_paloffs,
	input wire [14:0]            span_fill_colour,
	output reg                   span_done,

	output reg                   out_vld,
	output reg                   out_blank, // A blank pixel for non-alpha-related reasons
	output reg [W_DATA-1:0]      out_data,
	output reg                   out_paletted
);

`include "riscboy_ppu_const.vh"

reg [W_COORD_SX-1:0] x_coord;
reg [W_COORD_SX-1:0] x_remaining;
reg [W_SPANTYPE-1:0] type;
reg [1:0]            pixmode;
reg [2:0]            paloffs;
reg [14:0]           fill_colour;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_done <= 1'b1;
		x_coord <= {W_COORD_SX{1'b0}};
		x_remaining <= {W_COORD_SX{1'b0}};
		type <= SPANTYPE_FILL;
		pixmode <= PIXMODE_ARGB1555;
		paloffs <= 3'h0;
		fill_colour <= 15'h0;
	end else if (span_start) begin
		span_done <= 1'b0;
		x_coord <= span_x0;
		x_remaining <= span_count;
		type <= span_type;
		pixmode <= span_pixmode;
		paloffs <= span_paloffs;
		fill_colour <= span_fill_colour;
	end else if (!span_done) begin
		if (out_vld) begin
			x_remaining <= x_remaining - 1'b1;
			x_coord <= x_coord + 1'b1;
			if (~|x_remaining)
				span_done <= 1'b1;
		end
`ifdef FORMAL
		if (in_vld)
			assert(pinfo_vld);
`endif
	end
end

wire [7:0] paloffs_shifted = {paloffs, 5'h0};

always @ (*) begin
	out_vld = !span_done && (type == SPANTYPE_FILL || in_vld || (pinfo_vld && pinfo_discard));
	out_blank = pinfo_discard && type != SPANTYPE_FILL;
	out_data = 16'h0;
	if (type == SPANTYPE_FILL) begin
		out_data = {1'b1, fill_colour};
	end else case (pixmode)
		PIXMODE_ARGB1555: out_data      = in_data;
		PIXMODE_PAL8:     out_data[7:0] = in_data[8 * pinfo_u[0] +: 8]           + paloffs_shifted;
		PIXMODE_PAL4:     out_data[7:0] = {4'h0, in_data[4 * pinfo_u[1:0] +: 4]} + paloffs_shifted;
		PIXMODE_PAL1:     out_data[7:0] = {7'h0, in_data[pinfo_u[3:0]]}          + paloffs_shifted;
	endcase
	out_paletted = MODE_IS_PALETTED(pixmode);
end

assign pinfo_rdy = (pinfo_vld && pinfo_discard) || in_vld;

endmodule
