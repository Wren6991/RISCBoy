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

wire                  tbuf_full;
wire                  tbuf_empty;
wire [1:0]            tbuf_level;
wire                  tbuf_push;

reg [W_COORD_SX-1:0]  count;
reg [W_SPANTYPE-1:0]  type;
reg [W_ADDR-1:0]      tilemap_ptr;
reg [2:0]             log_texsize;
reg                   log_tilesize;

wire issue_tinfo = cgen_vld && cgen_rdy;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_done <= 1'b1;
		count <= {W_COORD_SX{1'b0}};
		type <= {W_SPANTYPE{1'b0}};
		tilemap_ptr <= {W_ADDR{1'b0}};
		log_texsize <= 3'h0;
		log_tilesize <= 1'b0;
	end else if (span_start) begin
		span_done <= !(span_type == SPANTYPE_TILE || span_type == SPANTYPE_ATILE);
		count <= span_count;
		type <= span_type;
		tilemap_ptr <= span_tilemap_ptr & ADDR_MASK;
		log_texsize <= {1'b1, span_texsize[1:0]}; // only larger half of sizes available for tiled backgrounds (128 -> 1024 px)
		log_tilesize <= span_tilesize;
	end else if (cgen_vld && cgen_rdy) begin
`ifdef FORMAL
		assert(!span_done);
`endif
		count <= count - 1'b1;
		if (~|count)
			span_done <= 1'b1;
	end
end

// ----------------------------------------------------------------------------
// Address generation

wire playfield_mask = ~({{W_COORD_UV-3{1'b1}}, 3'b000} << log_texsize);
wire out_of_bounds = |{cgen_u & ~playfield_mask, cgen_v & ~playfield_mask}; // FIXME options here!

wire [W_ADDR-1:0] u_tile_index = (cgen_u & playfield_mask) >> (log_tilesize ? 4 : 3);
wire [W_ADDR-1:0] v_tile_index = (cgen_v & playfield_mask) >> (log_tilesize ? 4 : 3);
wire [W_ADDR-1:0] tile_index_in_tilemap = (u_tile_index | ({7'h0, v_tile_index} << log_texsize - log_tilesize)) & ADDR_MASK;

assign bus_addr = (tilemap_ptr + tile_index_in_tilemap) & ADDR_MASK;

wire issue_discard = out_of_bounds && 0; // FIXME need an option here

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
wire consume_tilenum = consume_tinfo && !tinfo_discard;


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
	.WIDTH (2 * 4 + 1)
) tinfo_buf (
	.clk    (clk),
	.rst_n  (rst_n),
	.w_data ({out_of_bounds, cgen_v[3:0], cgen_u[3:0]}),
	.w_en   (issue_tinfo),
	.r_data ({tinfo_discard, tinfo_v, tinfo_u}),
	.r_en   (consume_tinfo),
	.full   (tinfo_buf_full),
	.empty  (tinfo_buf_empty),
	.level  (/* unused */)
);

// ----------------------------------------------------------------------------
// Handshaking

wire issue_prerequisites = !span_done && cgen_vld && !(tilenum_buf_full || tinfo_buf_full);

assign cgen_rdy = issue_prerequisites && (bus_addr_rdy || issue_discard);

assign bus_addr_vld = issue_prerequisites && !issue_discard;
assign bus_size = 2'b00;

assign tinfo_vld = !tinfo_buf_empty && (tinfo_discard || !tilenum_buf_empty);

endmodule
