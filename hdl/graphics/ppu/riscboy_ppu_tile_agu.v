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
	parameter W_ADDR      = 18,
	parameter W_DATA      = 16,
	parameter ADDR_MASK   = {W_ADDR{1'b1}},
	parameter W_COORD_UV  = 10,
	parameter W_COORD_SX  = 9,
	parameter W_SPAN_TYPE = 3,
	parameter W_TILE_NUM  = 8
) (
	input  wire                   clk,
	input  wire                   rst_n,

	output wire                   bus_addr_vld,
	input  wire                   bus_addr_rdy,
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
reg                   type_is_atile;
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
		type_is_atile <= 1'b0;
		tilemap_ptr <= {W_ADDR{1'b0}};
		log_texsize <= 3'h0;
		log_tilesize <= 1'b0;
		first_of_span <= 1'b0;
	end else if (span_start) begin
		span_done <= !(span_type == SPANTYPE_TILE || span_type == SPANTYPE_ATILE);
		count <= span_count;
		type <= span_type;
		type_is_atile <= span_type == SPANTYPE_ATILE;
		tilemap_ptr <= span_tilemap_ptr & ADDR_MASK;
		log_texsize <= {1'b1, span_texsize[1:0]}; // only larger half of sizes available for tiled backgrounds (128 -> 1024 px)
		log_tilesize <= span_tilesize;
		first_of_span <= 1'b1;
	end else if (cgen_vld && cgen_rdy) begin
`ifdef FORMAL
		assert(!span_done);
`endif
		count <= count - 1'b1;
		first_of_span <= type_is_atile;
		if (~|count) begin
			span_done <= 1'b1;
		end
	end
end

// ----------------------------------------------------------------------------
// Address generation

wire [W_COORD_UV-1:0] playfield_mask = ~({{W_COORD_UV-3{1'b1}}, 3'b000} << log_texsize);
wire out_of_bounds = |{cgen_u & ~playfield_mask, cgen_v & ~playfield_mask}; // FIXME options here!

wire [W_ADDR:0] u_tile_index = (cgen_u & playfield_mask) >> (log_tilesize ? 4 : 3);
wire [W_ADDR:0] v_tile_index = (cgen_v & playfield_mask) >> (log_tilesize ? 4 : 3);
wire [W_ADDR:0] tile_index_in_tilemap = (u_tile_index | ({7'h0, v_tile_index} << log_texsize - log_tilesize)) & ADDR_MASK;

wire [W_ADDR:0] bus_addr_byte = ({tilemap_ptr, 1'b0} + tile_index_in_tilemap) & {ADDR_MASK, 1'b1};
assign bus_addr = bus_addr_byte[W_ADDR:1];

wire issue_discard = out_of_bounds && 1'b0; // FIXME need an option here

// We want to know the first time a tile address is *issued* (to forward it to
// the bus) and the last time tile data is *used* (to pop it from the buffer)
wire [3:0] tile_wrap_mask = {span_tilesize, 3'h7};
wire tinfo_end;
wire first_of_tile = first_of_span || ~|(cgen_u[3:0] & tile_wrap_mask);
wire last_of_tile = type_is_atile || !tinfo_buf_empty && (tinfo_end || &(tinfo_u[3:0] & tile_wrap_mask));

// ----------------------------------------------------------------------------
// Tile info buffering
//
// A shallow FIFO for tile numbers coming from the bus, and a slightly deeper
// queue for coordinate LSBs and out-of-bounds information. The second is
// deeper because we push to it at address issue time (or on out-of-bounds),
// and the second is not pushed to until data comes back from the bus.
//
// We may also push a blank record, showing that a pixel is out of bounds,
// into the tinfo queue. In this case, there will not be a corresponding entry
// in the tilenum queue.

wire consume_tinfo = tinfo_vld && tinfo_rdy;
wire consume_tilenum = consume_tinfo && last_of_tile;

localparam TILENUM_BUF_DEPTH = 5;
localparam W_TILENUM_BUF_LEVEL = 3;
localparam TINFO_BUF_DEPTH = 2 * TILENUM_BUF_DEPTH;

wire                           tilenum_buf_empty;
wire                           tilenum_buf_full;
wire [W_TILENUM_BUF_LEVEL-1:0] tilenum_buf_level;
wire                           tinfo_buf_empty;
wire                           tinfo_buf_full;

// 1-bit wide FIFO to hold the byte address LSB of in-flight bus accesses, so
// that the correct byte can be picked from the data bus. This FIFO does not
// overflow because its level is always equal to the number of in-flight
// transfers, which is never greater than the depth of `tilenum_buf`, which
// has the same depth as this FIFO.

wire [W_TILENUM_BUF_LEVEL-1:0] tilenum_fetches_in_flight;
wire                           rdata_byte_align;

sync_fifo #(
	.DEPTH (TILENUM_BUF_DEPTH),
	.WIDTH (1)
) in_flight_byte_align_buf (
	.clk (clk),
	.rst_n (rst_n),
	.wdata (bus_addr_byte[0]),
	.wen   (bus_addr_vld && bus_addr_rdy),
	.rdata (rdata_byte_align),
	.ren   (bus_data_vld),
	.flush (1'b0),
	.empty (/* unused */),
	.full  (/* unused */),
	.level (tilenum_fetches_in_flight)
);

sync_fifo #(
	.DEPTH (TILENUM_BUF_DEPTH),
	.WIDTH (W_TILENUM)
) tilenum_buf (
	.clk   (clk),
	.rst_n (rst_n),
	.wdata (bus_data[rdata_byte_align * W_TILENUM +: W_TILENUM]),
	.wen   (bus_data_vld),
	.rdata (tinfo_tilenum),
	.ren   (consume_tilenum),
	.flush (1'b0),
	.full  (tilenum_buf_full),
	.empty (tilenum_buf_empty),
	.level (tilenum_buf_level)
);

sync_fifo #(
	.DEPTH (TINFO_BUF_DEPTH),
	.WIDTH (2 * 4 + 1 + 1)
) tinfo_buf (
	.clk    (clk),
	.rst_n  (rst_n),
	.wdata  ({~|count, issue_discard, cgen_v[3:0], cgen_u[3:0]}),
	.wen    (issue_tinfo),
	.rdata  ({tinfo_end, tinfo_discard, tinfo_v, tinfo_u}),
	.ren    (consume_tinfo),
	.flush  (1'b0),
	.full   (tinfo_buf_full),
	.empty  (tinfo_buf_empty),
	.level  (/* unused */)
);

// ----------------------------------------------------------------------------
// Handshaking

wire tilenum_space_for_fetch = tilenum_fetches_in_flight + tilenum_buf_level < TILENUM_BUF_DEPTH;

wire issue_prerequisites = !span_done && cgen_vld && tilenum_space_for_fetch && !tinfo_buf_full;

assign cgen_rdy = issue_prerequisites && (bus_addr_rdy || !first_of_tile);

assign bus_addr_vld = issue_prerequisites && first_of_tile;

assign tinfo_vld = !tinfo_buf_empty && !tilenum_buf_empty;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
