module riscboy_ppu_sprite_agu #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter W_COORD = 9,
	parameter N_SPRITE = 8,
	parameter ADDR_MASK = {W_ADDR{1'b1}},
	// Driven parameters:
	parameter W_SHIFTCTR = $clog2(W_DATA)
) (
	input  wire                         clk,
	input  wire                         rst_n,

	input  wire  [W_COORD-1:0]          beam_x,
	input  wire  [W_COORD-1:0]          beam_y,

	input  wire  [N_SPRITE*W_COORD-1:0] cfg_sprite_pos_x,
	input  wire  [N_SPRITE*W_COORD-1:0] cfg_sprite_pos_y,
	input  wire  [N_SPRITE*8-1:0]       cfg_sprite_tile,
	input  wire  [23:0]                 cfg_sprite_tsbase,
	input  wire  [2:0]                  cfg_sprite_pixmode,
	input  wire                         cfg_sprite_tilesize,

	input  wire [N_SPRITE-1:0]          sprite_req,
	output wire [N_SPRITE-1:0]          sprite_ack,
	output wire                         sprite_active,
	output wire [W_COORD-1:0]           sprite_x_count,
	output wire                         sprite_must_seek,
	output wire [W_SHIFTCTR-1:0]        sprite_shift_seek_target,

	input  wire [N_SPRITE-1:0]          sprite_bus_vld,
	output wire [N_SPRITE-1:0]          sprite_bus_rdy,
	input  wire [N_SPRITE*5-1:0]        sprite_bus_postcount,
	output wire [W_DATA-1:0]            sprite_bus_data,

	output wire                         bus_vld,
	output wire [W_ADDR-1:0]            bus_addr,
	output wire [1:0]                   bus_size,
	input  wire                         bus_rdy,
	input  wire [W_DATA-1:0]            bus_data
);

`include "riscboy_ppu_const.vh"

parameter BUS_SIZE_MAX = $clog2(W_DATA) - 3;

// ----------------------------------------------------------------------------
// Handle requests for coordinate calculations and comparisons

wire [N_SPRITE-1:0] sprite_req_gnt;

onehot_priority #(
	.W_INPUT (N_SPRITE)
) sprite_coord_prisel (
 .in  (sprite_req),
 .out (sprite_req_gnt)
);

wire [W_COORD-1:0] chosen_sprite_pos_x;
wire [W_COORD-1:0] chosen_sprite_pos_y;

onehot_mux #(
	.N_INPUTS (N_SPRITE),
	.W_INPUT  (W_COORD)
) mux_sprite_x (
	.in  (cfg_sprite_pos_x),
	.sel (sprite_req_gnt),
	.out (chosen_sprite_pos_x)
);

onehot_mux #(
	.N_INPUTS (N_SPRITE),
	.W_INPUT  (W_COORD)
) mux_sprite_y (
	.in  (cfg_sprite_pos_y),
	.sel (sprite_req_gnt),
	.out (chosen_sprite_pos_y)
);

wire [4:0] tile_size = cfg_sprite_tilesize ? 5'd16 : 5'd8;
wire [2:0] pixel_log_size = MODE_LOG_PIXSIZE(cfg_sprite_pixmode);

wire sprite_intersects_y = beam_y < chosen_sprite_pos_y && beam_y + tile_size >= chosen_sprite_pos_y;
// or perhaps (requires spec change):
// wire sprite_intersects_y = !({beam_y - chosen_sprite_pos_y} & {{W_COORD-4{1'b1}}, cfg_sprite_tilesize, 3'h0});

wire beam_x_right_of_lbound = beam_x + tile_size >= chosen_sprite_pos_x;
wire beam_x_left_of_rbound = beam_x < chosen_sprite_pos_x;
assign sprite_active = sprite_intersects_y && beam_x_left_of_rbound;

assign sprite_x_count = beam_x_left_of_rbound ?
	chosen_sprite_pos_x - beam_x : {W_COORD{1'b0}};

assign sprite_must_seek = beam_x_right_of_lbound;
assign sprite_shift_seek_target = {tile_size - sprite_x_count[4:0]} << pixel_log_size;

assign sprite_ack = sprite_req_gnt;

// ----------------------------------------------------------------------------
// Translate sprite fetch requests into full bus requests

wire [N_SPRITE-1:0] sprite_bus_gnt_comb;

onehot_priority #(
	.W_INPUT (N_SPRITE)
) sprite_bus_prisel (
	.in  (sprite_bus_vld),
	.out (sprite_bus_gnt_comb)
);

reg [N_SPRITE-1:0] sprite_bus_gnt_reg;
wire [N_SPRITE-1:0] sprite_bus_gnt = |sprite_bus_gnt_reg ? sprite_bus_gnt_reg : sprite_bus_gnt_comb;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		sprite_bus_gnt_reg <= {N_SPRITE{1'b0}};
	else if (bus_rdy || ~|sprite_bus_gnt_reg)
		sprite_bus_gnt_reg <= sprite_bus_gnt_comb & ~sprite_bus_rdy;

wire [7:0] bus_chosen_tile;
wire [4:0] bus_chosen_postcount;
wire [W_COORD-1:0] bus_chosen_pos_y;

onehot_mux #(
	.N_INPUTS (N_SPRITE),
	.W_INPUT  (8)
) mux_bus_tile (
	.in  (cfg_sprite_tile),
	.sel (sprite_bus_gnt),
	.out (bus_chosen_tile)
);

onehot_mux #(
	.N_INPUTS (N_SPRITE),
	.W_INPUT  (5)
) mux_bus_postcount (
	.in  (sprite_bus_postcount),
	.sel (sprite_bus_gnt),
	.out (bus_chosen_postcount)
);

onehot_mux #(
	.N_INPUTS (N_SPRITE),
	.W_INPUT  (W_COORD)
) mux_bus_pos_y (
	.in  (cfg_sprite_pos_y),
	.sel (sprite_bus_gnt),
	.out (bus_chosen_pos_y)
);

wire [3:0] bus_pixel_v = beam_y - bus_chosen_pos_y;
wire [3:0] bus_pixel_u = tile_size - bus_chosen_postcount;
wire [W_ADDR-1:0] idx_of_pixel_in_tileset = cfg_sprite_tilesize ?
	{{W_ADDR-16{1'b0}}, bus_chosen_tile, bus_pixel_v[3:0], bus_pixel_u[3:0]} :
	{{W_ADDR-14{1'b0}}, bus_chosen_tile, bus_pixel_v[2:0], bus_pixel_u[2:0]};

assign bus_addr = ({cfg_sprite_tsbase, 8'h0} | ((idx_of_pixel_in_tileset << pixel_log_size) >> 3))
	& ({W_ADDR{1'b1}} << BUS_SIZE_MAX) & ADDR_MASK;
assign bus_size = BUS_SIZE_MAX[2:0];
assign bus_vld = |sprite_bus_gnt;

assign sprite_bus_rdy = sprite_bus_gnt_reg & {N_SPRITE{bus_rdy}};
assign sprite_bus_data = bus_data;

endmodule
