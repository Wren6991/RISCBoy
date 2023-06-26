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

`default_nettype none

 module riscboy_ppu_pixel_agu #(
	parameter W_COORD_SX = 9,
	parameter W_COORD_UV = 10,
	parameter W_SPAN_TYPE = 3,
	parameter W_ADDR = 18,
	parameter ADDR_MASK = {W_ADDR{1'b1}}
 ) (
	input  wire                   clk,
	input  wire                   rst_n,

	// Address phase only. Data phase is handled at the unpacker.
	output wire                   bus_addr_vld,
	input  wire                   bus_addr_rdy,
	output wire [W_ADDR-1:0]      bus_addr,
	input  wire                   bus_data_vld,

	input  wire                   span_start,
	input  wire [W_COORD_SX-1:0]  span_count,
	input  wire [W_SPAN_TYPE-1:0] span_type,
	input  wire [1:0]             span_pixmode,
	input  wire [W_ADDR-1:0]      span_texture_ptr,
	input  wire [2:0]             span_texsize,
	input  wire                   span_tilesize,
	input  wire                   span_ablit_halfsize,
	output reg                    span_done,

	// Direct cgen access for BLIT/ABLIT spans
	input  wire [W_COORD_UV-1:0]  cgen_u,
	input  wire [W_COORD_UV-1:0]  cgen_v,
	input  wire                   cgen_vld,
	output wire                   cgen_rdy,

	// Indirect cgen information for TILE/ATILE spans
	input  wire [3:0]             tinfo_u,
	input  wire [3:0]             tinfo_v,
	input  wire [7:0]             tinfo_tilenum,
	input  wire                   tinfo_discard,
	input  wire                   tinfo_vld,
	output wire                   tinfo_rdy,

	// Pass pixel metadata to the unpacker. Unpacker will generally pop when bus
	// data arrives, but will pop immediately if "discard" is set, as this
	// indicates there is no data coming.
	output wire [3:0]             pinfo_u,
	output wire                   pinfo_discard,
	output wire                   pinfo_vld,
	input  wire                   pinfo_rdy
);

`include "riscboy_ppu_const.vh"

reg [W_COORD_SX-1:0] count;
reg [W_SPANTYPE-1:0] type;
reg                  type_is_blit;
reg [1:0]            pixmode;
reg [W_ADDR-1:0]     texture_ptr;
reg [2:0]            texsize;
reg                  tilesize;
reg [W_COORD_UV-1:0] ordinate_mask;

wire                 issue_pixel;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_done <= 1'b1;
		count <= {W_COORD_SX{1'b0}};
		type <= {W_SPANTYPE{1'b0}};
		type_is_blit <= 1'b0;
		pixmode <= 2'h0;
		texture_ptr <= {W_ADDR{1'b0}};
		texsize <= 3'h0;
		tilesize <= 1'b0;
		ordinate_mask <= {W_COORD_UV{1'b0}};
	end else if (span_start) begin
		span_done <= span_type == SPANTYPE_FILL;
		count <= span_count;
		type <= span_type;
		type_is_blit <= span_type == SPANTYPE_BLIT || span_type == SPANTYPE_ABLIT;
		pixmode <= span_pixmode;
		texture_ptr <= span_texture_ptr;
		texsize <= span_texsize - (span_ablit_halfsize && span_type == SPANTYPE_ABLIT);
		tilesize <= span_tilesize;
		ordinate_mask <= ~({{W_COORD_UV-3{1'b1}}, 3'b000} <<
			(span_texsize - (span_ablit_halfsize && span_type == SPANTYPE_ABLIT)));
	end else if (issue_pixel) begin
		count <= count - 1'b1;
		if (~|count) begin
			span_done <= 1'b1;
		end
	end
end

// ----------------------------------------------------------------------------
// Address generation

wire pinfo_room_for_issue; // TODO delete?
wire pinfo_fifo_full;

wire [W_ADDR:0] blit_pixel_offs_in_texture = (cgen_u & ordinate_mask) |
	({{W_COORD_UV-3{1'b0}}, cgen_v & ordinate_mask, 3'b000} << texsize);

wire [W_ADDR:0] tile_pixel_offset_in_tilemap = tilesize ?
	{{W_ADDR-15{1'b0}}, tinfo_tilenum, tinfo_v, tinfo_u} :
	{{W_ADDR-13{1'b0}}, tinfo_tilenum, tinfo_v[2:0], tinfo_u[2:0]};

wire [W_ADDR:0] pixel_addr_offs = ({type_is_blit ? blit_pixel_offs_in_texture : tile_pixel_offset_in_tilemap, 1'b0}
	>> 3'h4 - MODE_LOG_PIXSIZE(pixmode)) & ADDR_MASK;

wire blit_out_of_bounds = |{cgen_u & ~ordinate_mask, cgen_v & ~ordinate_mask};

// Always halfword-sized, halfword-aligned
assign bus_addr = (({texture_ptr, 1'b0} + pixel_addr_offs) >> 1) & ADDR_MASK;
assign bus_addr_vld = type_is_blit ?
	!(span_done || pinfo_fifo_full || blit_out_of_bounds || !cgen_vld) :
	!(span_done || pinfo_fifo_full || tinfo_discard || !tinfo_vld);

assign issue_pixel = !span_done && (
	bus_addr_vld && bus_addr_rdy ||
	type_is_blit && cgen_vld && blit_out_of_bounds && !pinfo_fifo_full ||
	!type_is_blit && tinfo_vld && tinfo_discard && !pinfo_fifo_full
);

assign cgen_rdy = issue_pixel && type_is_blit;
assign tinfo_rdy = issue_pixel && !type_is_blit;

// ----------------------------------------------------------------------------
// Metadata

localparam PINFO_FIFO_DEPTH = 5;
localparam W_PINFO_FIFO_LEVEL = 3;

wire                          pinfo_fifo_empty;
wire [W_PINFO_FIFO_LEVEL-1:0] pinfo_fifo_level;

wire [4:0] pinfo_fifo_wdata = type_is_blit ?
	{blit_out_of_bounds, cgen_u[3:0]} :
	{tinfo_discard, tinfo_u};

sync_fifo #(
	.DEPTH (PINFO_FIFO_DEPTH),
	.WIDTH (5)
) pinfo_fifo (
	.clk    (clk),
	.rst_n  (rst_n),

	.wdata  (pinfo_fifo_wdata),
	.wen    (issue_pixel),
	.rdata  ({pinfo_discard, pinfo_u}),
	.ren    (pinfo_vld && pinfo_rdy),
	.flush  (1'b0),
	.full   (pinfo_fifo_full),
	.empty  (pinfo_fifo_empty),
	.level  (pinfo_fifo_level)
);

assign pinfo_vld = !pinfo_fifo_empty;

reg [W_PINFO_FIFO_LEVEL-1:0] fetches_in_flight;
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		fetches_in_flight <= {W_PINFO_FIFO_LEVEL{1'b0}};
	end else begin
		fetches_in_flight <= fetches_in_flight
			+ {{W_PINFO_FIFO_LEVEL-1{1'b0}}, bus_addr_vld && bus_addr_rdy}
			- {{W_PINFO_FIFO_LEVEL-1{1'b0}}, bus_data_vld                };
	end
end

assign pinfo_room_for_issue = pinfo_fifo_level + fetches_in_flight < PINFO_FIFO_DEPTH;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
