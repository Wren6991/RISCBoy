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
	parameter W_COORD = 12,
	parameter W_OUTDATA = 15,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	// Driven parameters:
	parameter W_SHIFTCTR = $clog2(W_DATA),
	parameter W_SHAMT = $clog2(W_SHIFTCTR + 1),
	parameter W_LOG_COORD = $clog2(W_COORD),
	parameter W_LOG_LOG_COORD = $clog2(W_LOG_COORD), // trust me
	parameter BUS_SIZE_MAX = $clog2(W_DATA) - 3
) (
	input  wire                        clk,
	input  wire                        rst_n,

	input  wire                        en,
	input  wire                        flush,

	input  wire [W_COORD-1:0]          beam_x,
	input  wire [W_COORD-1:0]          beam_y,

	// Once vld asserted, can not be deasserted until rdy is seen.
	// If addr+size is held constant, rdy indicates data is present on data bus.
	// If addr+size are not held constant (e.g. due to flush) the data response
	// is undefined, and should be discarded. However vld must still be held
	// high until rdy is seen.
	output wire                        bus_vld,
	output wire [W_ADDR-1:0]           bus_addr,
	output wire [1:0]                  bus_size,
	input  wire                        bus_rdy,
	input  wire [W_DATA-1:0]           bus_data,

	// Config signals -- source tbd
	input  wire [W_COORD-1:0]          cfg_scroll_x,
	input  wire [W_COORD-1:0]          cfg_scroll_y,
	input  wire [W_LOG_COORD-1:0]      cfg_log_w,
	input  wire [W_LOG_COORD-1:0]      cfg_log_h,
	input  wire [W_ADDR-1:0]           cfg_tileset_base,
	input  wire [W_ADDR-1:0]           cfg_tilemap_base,
	input  wire [W_LOG_LOG_COORD-1:0]  cfg_loglog_tileset_width,
	input  wire [W_LOG_LOG_COORD-1:0]  cfg_loglog_tilemap_width,
	input  wire                        cfg_tile_size,
	input  wire [2:0]                  cfg_pixel_mode,
	input  wire                        cfg_transparency,

	output wire                        out_vld,
	input  wire                        out_rdy,
	output wire                        out_alpha,
	output wire [W_OUTDATA-1:0]        out_pixdata,
	output wire                        out_paletted
);

`include "riscboy_ppu_const.vh"

// ----------------------------------------------------------------------------
// Coordinate handling

// Pixel's location in the background coordinate system
reg [W_COORD-1:0] u;
reg [W_COORD-1:0] v;

wire [W_COORD-1:0] w_mask = ~({{W_COORD{1'b1}}, 1'b0} << cfg_log_w}};
wire [W_COORD-1:0] h_mask = ~({{W_COORD{1'b1}}, 1'b0} << cfg_log_h}};

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

wire [2:0] pixel_log_size = MODE_LOG_PIXSIZE(pixel_mode);

wire [4:0] pixel_size_bits = 5'h1 << pixel_log_size;
wire [4:0] tile_size_pixels = 5'h8 << log_tile_size;

// ----------------------------------------------------------------------------
// Pixel shifting and output logic

reg  [W_SHIFTCTR-1:0] shift_ctr;
wire [W_SHIFTCTR-1:0] shift_ctr_next
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
wire                  shift_en;
wire                  shift_load;
wire [W_OUTDATA-1:0]  shift_dout;

// To seek, we shift by the highest bit-weight first, to maintain the
// invariant that total shift count is aligned on a boundary of next shift
// amount
wire [W_SHAMT-1:0] seek_shamt;
wire seek_end = (shift_ctr | seek_shamt) == shift_seek_target;

onehot_priority #(
	.W_INPUT(W_SHAMT),
	.HIGHEST_WINS (1)
) seek_order_u (
	.in  (shift_ctr ^ shift_seek_target),
	.out (seek_shamt)
);

assign shift_increment = shift_seeking ? seek_shamt : pixel_size_bits;

onehot_encoder #(
	.W_INPUT(W_INPUT)
) shamt_encoder (
	.in  (shift_ctr_next & ~shift_ctr),
	.out (shamt)
);

ppu_pixel_gearbox #(
	.W_DATA(W_DATA),
	.W_PIX_MIN(1),
	.W_PIX_MAX(W_OUTDATA)
) gearbox_u (
	.clk     (clk),
	.rst_n   (rst_n),
	.din     (bus_data),
	.din_vld (shift_load),
	.shamt   (shamt & {W_SHAMT{shift_en}})
	.dout    (dout)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		shift_ctr <= {W_SHIFTCTR{1'b0}};
		shift_seeking <= 1'b0;
		shift_empty <= 1'b1;
	end else if (flush) begin
		shift_ctr <= {W_SHIFTCTR{1'b0}};
		shift_seeking <= 1'b1;
		shift_empty <= 1'b1;
	end else if (!shift_empty) begin
		shift_seeking <= shift_seeking && !seek_end;
		shift_empty <= shift_en && shift_ctr_carryout;
	end else begin
		shift_empty <= !pixel_load_rdy;
	end
end


// ----------------------------------------------------------------------------
// Tile bookkeeping

reg tile_empty;
reg [W_TILENUM-1:0] tile;
reg [LOG_W_TILE_MAX-1:0] tile_pixctr;

wire tile_load_rdy;

wire [W_LOG_COORD-1:0] log_tilemap_width = {{W_LOG_COORD-1{1'b0}}, 1'b1} << cfg_loglog_tilemap_width;

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
		if (tile_pixctr == {cfg_tile_size, {LOG_W_TILE_MAX-1{1'b1}})
			tile_empty <= 1'b1;
	end
end

// ----------------------------------------------------------------------------
// Address generation

wire [W_ADDR-1:0] tile_addr =
	cfg_tilemap_base |
	(cfg_tile_size ? u >> 4 : u >> 3) |
	({{W_ADDR-W_COORD{1'b0}}, v} << (log_tilemap_width - (cfg_tile_size ? 4 : 3)));


// Horizontal offset = (tile % WIDTH_IN_TILES) * WIDTH_OF_TILE + u % WIDTH_OF_TILE
// Vertical offset = (tile / WIDTH_IN_TILES) + v % HEIGHT_OF_TILE
// Pixel offset into tileset = horizontal offset + vertical offset * WIDTH_IN_PIXELS
// NB: WIDTH_IN_TILES * WIDTH_OF_TILE = WIDTH_IN_PIXELS,   and   WIDTH_OF_TILE = HEIGHT_OF_TILE

wire [W_COORD-1:0] log_tileset_width = {{W_LOG_COORD-1{1'b0}}, 1'b1} << cfg_loglog_tileset_width;
wire [W_ADDR-1:0] tileset_pixoffs_u = (cfg_tile_size ? {tile, u[3:0]} : {tile, u[2:0]}) & ~({W_ADDR{1'b1}} << log_tileset_width};
wire [W_ADDR-1:0] tileset_pixoffs_v = cfg_tile_size ? {tile >> log_tileset_width, v[3:0]} : {tile >> log_tileset_width, v[2:0]};
wire [W_ADDR-1:0] idx_of_pixel_in_tileset = tileset_pixoffs_u | (tileset_pixoffs_v << log_tileset_width);

wire [W_ADDR-1:0] pixel_addr = cfg_tileset_base | ((idx_of_pixel_in_tileset << pixel_log_size) >> 3);

// Tile accesses take priority. Assumption is (FIXME: assert this!) that the
// pixel shifter runs out of data more often than the tile register, and the
// final pixel runout on a tile is coincident with the runout of the tile itself.
// This means the new tile will be fetched first, and then the first pixel fetch
// will be made based on that tile.

reg bus_dphase_dirty;

assign bus_addr = tile_empty ? tile_addr : pixel_addr;
assign bus_size = tile_empty ? 2'b00 : BUS_SIZE_MAX;
assign bus_vld = tile_empty || shift_empty || bus_dphase_dirty;

assign pixel_load_rdy = bus_rdy && !bus_dphase_dirty && !tile_empty;
assign tile_load_rdy = bus_rdy && !bus_dphase_dirty && tile_empty;

always @ (posedge clk or negedge rst_n) begin
	if (negedge rst_n) begin
		bus_dphase_dirty <= 1'b0;
	end else begin
		bus_dphase_dirty <= (bus_dphase_dirty || (bus_vld && flush)) && !bus_rdy;
	end
end

endmodule
