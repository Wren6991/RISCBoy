/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2019 Luke Wren                                       *
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

module riscboy_ppu_background #(
	parameter W_COORD = 9,
	parameter W_OUTDATA = 15,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	// Driven parameters:
	parameter W_SHIFTCTR = $clog2(W_DATA),
	parameter W_SHAMT = $clog2(W_SHIFTCTR + 1),
	parameter W_LOG_COORD = $clog2(W_COORD),
	parameter BUS_SIZE_MAX = $clog2(W_DATA) - 3
) (
	input  wire                   clk,
	input  wire                   rst_n,

	input  wire                   en,
	input  wire                   flush,

	input  wire [W_COORD-1:0]     beam_x,
	input  wire [W_COORD-1:0]     beam_y,

	output wire                   bus_vld,
	output wire [W_ADDR-1:0]      bus_addr,
	output wire [1:0]             bus_size,
	input  wire                   bus_rdy,
	input  wire [W_DATA-1:0]      bus_data,

	// Config signals -- source tbd
	input  wire [W_COORD-1:0]     cfg_scroll_x,
	input  wire [W_COORD-1:0]     cfg_scroll_y,
	input  wire [W_LOG_COORD-1:0] cfg_log_w,
	input  wire [W_LOG_COORD-1:0] cfg_log_h,
	input  wire [W_ADDR-1:0]      cfg_tileset_base,
	input  wire [W_ADDR-1:0]      cfg_tilemap_base,
	input  wire                   cfg_tile_size,
	input  wire [2:0]             cfg_pixel_mode,
	input  wire                   cfg_transparency,

	output wire                   out_vld,
	input  wire                   out_rdy,
	output wire                   out_alpha,
	output wire [W_OUTDATA-1:0]   out_pixdata
);

`include "riscboy_ppu_const.vh"

// ----------------------------------------------------------------------------
// Coordinate handling

// Pixel's location in the background coordinate system
reg [W_COORD-1:0] u;
reg [W_COORD-1:0] v;

wire [W_COORD-1:0] w_mask = ~({{W_COORD{1'b1}}, 1'b0} << cfg_log_w);
wire [W_COORD-1:0] h_mask = ~({{W_COORD{1'b1}}, 1'b0} << cfg_log_h);

wire [W_COORD-1:0] u_flushval = (beam_x + cfg_scroll_x) & w_mask;
wire [W_COORD-1:0] v_flushval = (beam_y + cfg_scroll_y) & h_mask;

always @ (posedge clk) begin
	if (!rst_n) begin
		u <= {W_COORD{1'b0}};
		v <= {W_COORD{1'b0}};
	end else if (flush) begin
		u <= u_flushval;
		v <= v_flushval;
	end else if (out_vld && out_rdy) begin
		u <= (u + 1'b1) & w_mask;
	end
end

wire [2:0] pixel_log_size = MODE_LOG_PIXSIZE(cfg_pixel_mode);

wire [4:0] pixel_size_bits = 5'h1 << pixel_log_size;
wire [2:0] tile_log_size = cfg_tile_size ? 3'h4 : 3'h3;

// ----------------------------------------------------------------------------
// Pixel shifting and output logic

reg  [W_SHIFTCTR-1:0] shift_ctr;
wire [W_SHIFTCTR-1:0] shift_ctr_next;
wire                  shift_ctr_carryout;
wire [W_SHIFTCTR-1:0] shift_increment;
assign {shift_ctr_carryout, shift_ctr_next} = shift_ctr + shift_increment;

wire pixel_load_rdy;

// Seek: rapid log-time shift through the bus data when getting back into
// steady state after flush.
reg                   shift_empty;
reg                   shift_seeking;
wire [W_SHIFTCTR-1:0] shift_seek_target = u[W_SHIFTCTR-1:0] << pixel_log_size;

wire [W_SHAMT-1:0]    shamt;
wire                  shift_en = (shift_seeking && !shift_empty) || (out_vld && out_rdy);

// To seek, we shift by the highest bit-weight first, to maintain the
// invariant that total shift count is aligned on a boundary of next shift
// amount
wire [W_SHIFTCTR-1:0] seek_shamt;
wire seek_end = (shift_ctr | seek_shamt) == shift_seek_target;

onehot_priority #(
	.W_INPUT(W_SHIFTCTR),
	.HIGHEST_WINS (1)
) seek_order_u (
	.in  (shift_ctr ^ shift_seek_target),
	.out (seek_shamt)
);

assign shift_increment = shift_seeking ? seek_shamt : pixel_size_bits;

onehot_encoder #(
	.W_INPUT(W_SHIFTCTR)
) shamt_encoder (
	.in  (shift_ctr_next & ~shift_ctr),
	.out (shamt)
);

riscboy_ppu_pixel_gearbox #(
	.W_DATA(W_DATA),
	.W_PIX_MIN(1),
	.W_PIX_MAX(W_OUTDATA + 1)
) gearbox_u (
	.clk     (clk),
	.rst_n   (rst_n),
	.din     (bus_data),
	.din_vld (pixel_load_rdy),
	.shamt   ((shamt + {{W_SHAMT-1{1'b0}}, 1'b1}) & {W_SHAMT{shift_en}}),
	.dout    (out_pixdata)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		shift_ctr <= {W_SHIFTCTR{1'b0}};
		shift_seeking <= 1'b0;
		shift_empty <= 1'b1;
	end else if (flush) begin
		shift_ctr <= {W_SHIFTCTR{1'b0}};
		shift_seeking <= |{u_flushval[W_SHIFTCTR-1:0] << pixel_log_size};
		shift_empty <= 1'b1;
	end else if (!shift_empty) begin
		shift_empty <= shift_en && shift_ctr_carryout;
		if (shift_en) begin
			shift_seeking <= shift_seeking && !seek_end;
			shift_ctr <= shift_ctr_next;
		end
	end else begin
		shift_empty <= !pixel_load_rdy;
	end
end

// When not enabled, continuously output transparency so that we don't hold up the blender
assign out_vld = !en || !(shift_empty || shift_seeking || flush);
wire out_paletted = MODE_IS_PALETTED(cfg_pixel_mode);
assign out_alpha = en; // FIXME

// ----------------------------------------------------------------------------
// Tile bookkeeping

reg tile_empty;
reg [W_TILENUM-1:0] tile;
reg [LOG_W_TILE_MAX-1:0] tile_pixctr;

wire tile_load_rdy;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tile_empty <= 1'b1;
		tile <= {W_TILENUM{1'b0}};
		tile_pixctr <= {LOG_W_TILE_MAX{1'b0}};
	end else if (flush) begin
		tile_empty <= 1'b1;
		tile_pixctr <= u_flushval[LOG_W_TILE_MAX-1:0] & {cfg_tile_size, {LOG_W_TILE_MAX-1{1'b1}}};
	end else if (tile_empty) begin
		if (tile_load_rdy) begin
			tile <= bus_data[W_TILENUM-1:0];
			tile_empty <= 1'b0;
		end
	end else if (out_vld && out_rdy) begin
		tile_pixctr <= tile_pixctr + 1'b1;
		if (tile_pixctr == {cfg_tile_size, {LOG_W_TILE_MAX-1{1'b1}}}) begin
			tile_empty <= 1'b1;
			tile_pixctr <= {LOG_W_TILE_MAX{1'b0}};
		end
	end
end

// ----------------------------------------------------------------------------
// Address generation

// Safe to ignore cases where tileset is less than one tile wide...
wire [W_LOG_COORD-1:0] log_playfield_width_tiles = cfg_log_w + 1'b1 - tile_log_size;


wire [W_ADDR-1:0] idx_of_tile_in_tilemap = (u >> tile_log_size) | ({{W_ADDR-W_COORD{1'b0}}, v >> tile_log_size} << log_playfield_width_tiles);

wire [W_ADDR-1:0] tile_addr = cfg_tilemap_base | idx_of_tile_in_tilemap;

wire [W_ADDR-1:0] idx_of_pixel_in_tileset = cfg_tile_size ?
	{{W_ADDR-W_TILENUM-8{1'b0}}, tile, v[3:0], u[3:0]} :
	{{W_ADDR-W_TILENUM-6{1'b0}}, tile, v[2:0], u[2:0]};

wire [W_ADDR-1:0] pixel_addr = (cfg_tileset_base | ((idx_of_pixel_in_tileset << pixel_log_size) >> 3)) & ({W_ADDR{1'b1}} << BUS_SIZE_MAX);

// Tile accesses take priority. Assumption is (FIXME: assert this!) that the
// pixel shifter runs out of data more often than the tile register, and the
// final pixel runout on a tile is coincident with the runout of the tile itself.
// This means the new tile will be fetched first, and then the first pixel fetch
// will be made based on that tile.

reg bus_dphase_dirty;

assign bus_addr = tile_empty ? tile_addr : pixel_addr;
assign bus_size = tile_empty ? 2'b00 : BUS_SIZE_MAX;
assign bus_vld = ((tile_empty || shift_empty) && en) || bus_dphase_dirty;

assign pixel_load_rdy = bus_rdy && !bus_dphase_dirty && !tile_empty;
assign tile_load_rdy = bus_rdy && !bus_dphase_dirty && tile_empty;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		bus_dphase_dirty <= 1'b0;
	end else begin
		bus_dphase_dirty <= (bus_dphase_dirty || (bus_vld && flush)) && !bus_rdy;
	end
end

endmodule
