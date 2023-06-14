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

`default_nettype none

module riscboy_ppu_tile_agu #(
	parameter W_ADDR = 32,
	parameter W_DATA = 16,
	parameter ADDR_MASK = 32'hffffffff,
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

	output wire [3:0]             tinfo_u,
	output wire [3:0]             tinfo_v,
	output wire [W_TILE_NUM-1:0]  tinfo_tilenum,
	output wire                   tinfo_discard,
	output wire                   tinfo_vld,
	input  wire                   tinfo_rdy
);

`include "riscboy_ppu_const.vh"

reg [W_COORD_SX-1:0]  count;
reg [W_SPANTYPE-1:0]  type;
reg [W_ADDR-1:0]      tilemap_ptr;
reg [2:0]             log_texsize;
reg                   log_tilesize;
reg                   first_of_span;

wire issue_tinfo = cgen_vld && cgen_rdy;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_done <= 1'b1;
		count <= {W_COORD_SX{1'b0}};
		type <= {W_SPANTYPE{1'b0}};
		tilemap_ptr <= {W_ADDR{1'b0}};
		log_texsize <= 3'h0;
		log_tilesize <= 1'b0;
		first_of_span <= 1'b0;
	end else if (span_start) begin
		span_done <= !(span_type == SPANTYPE_TILE || span_type == SPANTYPE_ATILE);
		count <= span_count;
		type <= span_type;
		tilemap_ptr <= span_tilemap_ptr & ADDR_MASK;
		log_texsize <= {1'b1, span_texsize[1:0]}; // only larger half of sizes available for tiled backgrounds (128 -> 1024 px)
		log_tilesize <= span_tilesize;
		first_of_span <= 1'b1;
	end else if (cgen_vld && cgen_rdy) begin
`ifdef FORMAL
		assert(!span_done);
`endif
		count <= count - 1'b1;
		first_of_span <= 1'b0;
		if (~|count)
			span_done <= 1'b1;
	end
end

// ----------------------------------------------------------------------------
// Address generation

wire [W_COORD_UV-1:0] playfield_mask = ~({{W_COORD_UV-3{1'b1}}, 3'b000} << log_texsize);
wire out_of_bounds = |{cgen_u & ~playfield_mask, cgen_v & ~playfield_mask}; // FIXME options here!

wire [W_ADDR-1:0] u_tile_index = (cgen_u & playfield_mask) >> (log_tilesize ? 4 : 3);
wire [W_ADDR-1:0] v_tile_index = (cgen_v & playfield_mask) >> (log_tilesize ? 4 : 3);
wire [W_ADDR-1:0] tile_index_in_tilemap = (u_tile_index | ({7'h0, v_tile_index} << log_texsize - log_tilesize)) & ADDR_MASK;

assign bus_addr = (tilemap_ptr + tile_index_in_tilemap) & ADDR_MASK;

wire issue_discard = out_of_bounds && 1'b0; // FIXME need an option here

// We want to know the first time a tile address is *issued* (to forward it to
// the bus) and the last time tile data is *used* (to pop it from the buffer)
wire [3:0] tile_wrap_mask = {span_tilesize, 3'h7};
wire tinfo_end;
wire first_of_tile = type == SPANTYPE_ATILE || first_of_span || ~|(cgen_u[3:0] & tile_wrap_mask);
wire last_of_tile = type == SPANTYPE_ATILE || !tinfo_buf_empty && (tinfo_end || &(tinfo_u[3:0] & tile_wrap_mask));

// ----------------------------------------------------------------------------
// Tile info buffering
//
// A very shallow queue (skid buffer) for tile numbers coming from the bus,
// and a slightly deeper queue for coordinate LSBs and out-of-bounds
// information. The second is deeper because we push to it at address issue
// time (or on out-of-bounds), and the second is not pushed to until data
// comes back from the bus.
//
// We may also push a blank record, showing that a pixel is out of bounds,
// into the tinfo queue. In this case, there will not be a corresponding entry
// in the tilenum queue.

wire consume_tinfo = tinfo_vld && tinfo_rdy;
wire consume_tilenum = consume_tinfo && last_of_tile;

wire tilenum_buf_empty;
wire tilenum_buf_full;
wire tinfo_buf_empty;
wire tinfo_buf_full;

skid_buffer #(
	.WIDTH (W_TILENUM)
) tilenum_buf (
	.clk   (clk),
	.rst_n (rst_n),
	.wdata (bus_data[W_TILENUM-1:0]),
	.wen   (bus_data_vld),
	.rdata (tinfo_tilenum),
	.ren   (consume_tilenum),
	.flush (1'b0),
	.full  (tilenum_buf_full),
	.empty (tilenum_buf_empty),
	.level (/* unused */)
);

sync_fifo #(
	.DEPTH (4),
	.WIDTH (2 * 4 + 1 + 1)
) tinfo_buf (
	.clk    (clk),
	.rst_n  (rst_n),
	.w_data ({~|count, issue_discard, cgen_v[3:0], cgen_u[3:0]}),
	.w_en   (issue_tinfo),
	.r_data ({tinfo_end, tinfo_discard, tinfo_v, tinfo_u}),
	.r_en   (consume_tinfo),
	.full   (tinfo_buf_full),
	.empty  (tinfo_buf_empty),
	.level  (/* unused */)
);

// ----------------------------------------------------------------------------
// Handshaking

// Note tilenum_buf has depth 2, so we only issue when empty, so that both the
// issued and in-flight transfer have room when they arrive. This is still
// sufficient for throughput of 1 cycle in 2, which is all that is required
// for AT tiling.

wire issue_prerequisites = !span_done && cgen_vld && !tinfo_buf_full;

assign cgen_rdy = issue_prerequisites && (bus_addr_rdy || !first_of_tile);

// For 1:1 tile mapping we don't check the tilenum buffer level, because the
// depth of the tinfo buffer is less than one tile, which guarantees there
// will never be more than 2 tile numbers in the tilenum buffer!
assign bus_addr_vld = issue_prerequisites && first_of_tile && (tilenum_buf_empty || type == SPANTYPE_TILE);
assign bus_size = 2'b00;

assign tinfo_vld = !tinfo_buf_empty && !tilenum_buf_empty;

endmodule
