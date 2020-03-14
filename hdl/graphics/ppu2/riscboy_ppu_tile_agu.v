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

module riscboy_ppu_tile_address_gen #(
	parameter W_ADDR = 32,
	parameter W_DATA = 16,
	parameter W_COORD_UV = 10,
	parameter W_COORD_SX = 9,
	parameter W_SPAN_TYPE = 3,
	parameter W_TILE_NUM = 8
) (
	input  wire                   clk,
	input  wire                   rst_n,

	output wire                   bus_addr_vld,
	input  wire                   bus_addr_rdy,
	output wire [1:0]             bus_size,
	output wire [W_ADDR-1:0]      bus_addr,
	input  wire                   bus_data_vld,
	input  wire [W_DATA-1:0]      bus_data,

	input  wire                   span_start,
	input  wire [W_COORD_SX-1:0]  span_count,
	input  wire [W_SPAN_TYPE-1:0] span_type,
	input  wire [W_ADDR-1:0]      span_tilemap_ptr,
	input  wire [2:0]             span_texsize,
	input  wire                   span_tilesize,
	output reg                    span_done,

	input  wire [W_COORD_UV-1:0]  cgen_u,
	input  wire [W_COORD_UV-1:0]  cgen_v,
	input  wire                   cgen_vld,
	output wire                   cgen_rdy,

	output wire [W_TILE_NUM-1:0]  tilenum,
	output wire                   tilenum_vld,
	input  wire                   tilenum_rdy
);

`include "riscboy_ppu_const.vh"

wire                  tbuf_full;
wire                  tbuf_empty;
wire [1:0]            tbuf_level;
wire                  tbuf_push;

reg [W_COORD_SX-1:0]  count;
reg [W_SPANTYPE-1:0]  type;
reg [W_ADDR-1:0]      tilemap_ptr;
reg [2:0]             log_texsize;
reg                   log_tilesize;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_done <= 1'b1;
		count <= {W_COORD_SX{1'b0}};
		type <= {W_SPANTYPE{1'b0}};
		tilemap_ptr <= {W_ADDR{1'b0}};
		log_texsize <= 3'h0;
		log_tilesize <= 1'b0;
	end else if (span_start) begin
		span_done <= span_type == SPANTYPE_FILL;
		count <= span_count;
		type <= span_type;
		tilemap_ptr <= span_tilemap_ptr;
		log_texsize <= span_texsize;
		log_tilesize <= span_tilesize;
	end else if (cgen_vld && cgen_rdy) begin
		count <= count - 1'b1;
		if (~|count)
			span_done <= 1'b1;
	end
end

assign cgen_rdy = !span_done && (
	(type == SPANTYPE_TILE || type == SPANTYPE_ATILE) && bus_addr_vld && bus_addr_rdy ||
	(type == SPANTYPE_BLIT || type == SPANTYPE_ABLIT) && !tbuf_full
); // FIXME SHOULD NOT USE TBUF TO PACE BLIT IN NON-TILE MODES

skid_buffer #(
	.WIDTH(W_TILENUM)
) tilenum_buffer (
	.clk   (clk),
	.rst_n (rst_n),

	.wdata (bus_data[W_TILENUM-1:0]),
	.wen   (bus_data_vld),
	.rdata (tilenum),
	.ren   (tilenum_vld && tilenum_rdy),
	.flush (1'b0),
	.full  (tbuf_full),
	.empty (tbuf_empty),
	.level (tbuf_level)
);

assign tilenum_vld = !tbuf_empty;

endmodule
