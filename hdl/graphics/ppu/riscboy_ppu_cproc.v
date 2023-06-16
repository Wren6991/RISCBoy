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

// PPU command processor
// - Segment and decode the instruction stream
// - Test blit requests for intersection with current scanline and clip region
// - Generate commands for blitting hardware

`default_nettype none

module riscboy_ppu_cproc #(
	parameter W_COORD_SX       = 9,
	parameter W_COORD_SY       = 8,
	parameter W_COORD_UV       = 10,
	parameter W_SPAN_TYPE      = 3,
	parameter W_STACK_PTR      = 3,
	parameter W_MEM_ADDR       = 18,
	parameter GLOBAL_ADDR_MASK = {W_MEM_ADDR{1'b1}},
	parameter W_MEM_DATA       = 16,  // do not modify
	parameter W_INSTR          = 32   // do not modify
) (
	input  wire                   clk,
	input  wire                   rst_n,

	input  wire                   ppu_running,
	input  wire [W_MEM_ADDR-1:0]  entrypoint,
	input  wire                   entrypoint_vld,

	output wire                   bus_addr_vld,
	input  wire                   bus_addr_rdy,
	output wire [W_MEM_ADDR-1:0]  bus_addr,
	input  wire                   bus_data_vld,
	input  wire [W_MEM_DATA-1:0]  bus_data,

	input  wire [W_COORD_SY-1:0]  beam_y,
	output wire                   hsync,
	input  wire                   scanbuf_rdy,

	// Coordinate generator setup interface
	output wire                   cgen_start_affine,
	output wire                   cgen_start_simple,
	output wire [W_COORD_UV-1:0]  cgen_raster_offs_x,
	output wire [W_COORD_UV-1:0]  cgen_raster_offs_y,
	output wire [W_INSTR-1:0]     cgen_aparam_data,
	output wire                   cgen_aparam_vld,
	input  wire                   cgen_aparam_rdy,

	// Broadcast to blitter hardware. No backpressure on start, but we won't
	// issue another start until we see a done. Outputs are only valid when
	// span_start is high.
	output wire                   span_start,
	output wire [W_COORD_SX-1:0]  span_x0,
	output wire [W_COORD_SX-1:0]  span_count,
	output wire [W_SPAN_TYPE-1:0] span_type,
	output wire [1:0]             span_pixmode,
	output wire [2:0]             span_paloffs,
	output wire [14:0]            span_fill_colour,
	output wire [W_MEM_ADDR-1:0]  span_tilemap_ptr,
	output wire [W_MEM_ADDR-1:0]  span_texture_ptr,
	output wire [2:0]             span_texsize,
	output wire                   span_tilesize,
	output wire                   span_ablit_halfsize,
	input  wire                   span_done
);

`include "riscboy_ppu_const.vh"

localparam W_STATE           = 4;
localparam S_EXECUTE         = 4'd0;
localparam S_SKIP_INSTR_DATA = 4'd1;
localparam S_SYNC_WAIT       = 4'd2;
localparam S_SPAN_WAIT       = 4'd3;
localparam S_BLIT_IMG        = 4'd4;
localparam S_TILE_TILEMAP    = 4'd5;
localparam S_TILE_TILESET    = 4'd6;
localparam S_ABLIT_APARAM    = 4'd7;
localparam S_ABLIT_IMG       = 4'd8;
localparam S_ATILE_APARAM    = 4'd9;
localparam S_ATILE_TILEMAP   = 4'd10;
localparam S_ATILE_TILESET   = 4'd11;
localparam S_PUSH_DATA       = 4'd12;
localparam S_POPJ_JUMP       = 4'd13;


reg [W_STATE-1:0]            state;
reg [2:0]                    data_ctr;
reg [W_MEM_ADDR-1:0]         tilemap_ptr;

reg [W_COORD_SX-1:0]         clip_x0;
reg [W_COORD_SX-1:0]         clip_x1;

reg [2:0]                    texsize;
reg [INSTR_PALOFFS_BITS-1:0] paloffs;
reg                          tilesize;
reg                          ablit_halfsize;

wire                         instr_vld;
wire                         instr_rdy;
wire [W_INSTR-1:0]           instr;
wire [INSTR_OPCODE_BITS-1:0] opcode = instr[INSTR_OPCODE_LSB +: INSTR_OPCODE_BITS];

wire                         skip_span; // e.g. offscreen blit -- note this is valid only during S_EXECUTE
wire                         jump_taken;
wire                         jump_target_vld;
wire                         jump_target_rdy;

// Instructions contain byte addresses (with some LSBs invalid due to
// alignment constraints). Need to be shifted to get SRAM addresses.
localparam INSTR_ADDR_SHIFT  = 1;
wire [W_MEM_ADDR-1:0] instr_ptr_arg = (instr & GLOBAL_ADDR_MASK & INSTR_ADDR_MASK) >> INSTR_ADDR_SHIFT;

// Control state machine

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		state           <= S_EXECUTE;
		data_ctr        <= 3'h0;
		tilemap_ptr     <= {W_MEM_ADDR{1'b0}};
		clip_x0         <= {W_COORD_SX{1'b0}};
		clip_x1         <= {W_COORD_SX{1'b0}};
		texsize         <= 3'h0;
		paloffs         <= {INSTR_PALOFFS_BITS{1'b0}};
		tilesize        <= 1'b0;
		ablit_halfsize  <= 1'b0;
	end else if (ppu_running && (instr_vld || !instr_rdy)) case (state)

		S_EXECUTE: begin

			texsize <= INSTR_BLIT_SIZE(instr);
			paloffs <= instr[INSTR_PALOFFS_LSB +: INSTR_PALOFFS_BITS];
			tilesize <= INSTR_TILE_SIZE(instr);
			ablit_halfsize <= instr[INSTR_ABLIT_HALFSIZE_LSB];
			data_ctr <= 3'h0;

			case (opcode)
			OPCODE_SYNC: state <= S_SYNC_WAIT;
			OPCODE_CLIP: begin
				clip_x0 <= instr[INSTR_X_LSB +: INSTR_X_BITS];
				clip_x1 <= instr[INSTR_Y_LSB +: INSTR_Y_BITS];
			end
			OPCODE_FILL: state <= S_SPAN_WAIT;
			OPCODE_BLIT: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h0;
			end else begin
				state <= S_BLIT_IMG;
			end
			OPCODE_TILE: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h1;
			end else begin
				state <= S_TILE_TILEMAP;
			end
			OPCODE_ABLIT: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h3;
			end else begin
				state <= S_ABLIT_APARAM;
				data_ctr <= 3'h2;
			end
			OPCODE_ATILE: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h4;
			end else begin
				state <= S_ATILE_APARAM;
				data_ctr <= 3'h2;
			end
			OPCODE_PUSH: state <= S_PUSH_DATA;
			OPCODE_POPJ: if (jump_taken) begin
				state <= S_POPJ_JUMP;
			end else begin
				state <= S_EXECUTE;
			end
			endcase
		end

		S_SKIP_INSTR_DATA: begin
			data_ctr <= data_ctr - 1'b1;
			if (~|data_ctr)
				state <= S_EXECUTE;
		end
		S_SYNC_WAIT: begin
			if (scanbuf_rdy)
				state <= S_EXECUTE;
		end
		S_SPAN_WAIT: begin
			// TODO eliminate this state and stall in S_EXECUTE to save a cycle
			if (span_done)
				state <= S_EXECUTE;
		end
		S_BLIT_IMG: state <= S_SPAN_WAIT;
		S_TILE_TILEMAP: begin
			state <= S_TILE_TILESET;
			tilemap_ptr <= instr_ptr_arg;
			texsize <= INSTR_PF_SIZE(instr);
		end
		S_TILE_TILESET: state <= S_SPAN_WAIT;
		S_ABLIT_APARAM: if (cgen_aparam_rdy) begin
			data_ctr <= data_ctr - 1'b1;
			if (~|data_ctr)
				state <= S_ABLIT_IMG;
		end
		S_ABLIT_IMG: state <= S_SPAN_WAIT;
		S_ATILE_APARAM: if (cgen_aparam_rdy) begin
			data_ctr <= data_ctr - 1'b1;
			if (~|data_ctr)
				state <= S_ATILE_TILEMAP;
		end
		S_ATILE_TILEMAP: begin
			state <= S_ATILE_TILESET;
			tilemap_ptr <= instr_ptr_arg;
			texsize <= INSTR_PF_SIZE(instr);
		end
		S_ATILE_TILESET: state <= S_SPAN_WAIT;
		S_PUSH_DATA: begin
			state <= S_EXECUTE;
		end
		S_POPJ_JUMP: begin
			if (jump_target_rdy)
				state <= S_EXECUTE;
		end

	endcase
end

wire exec_opcode_this_cycle = instr_vld && instr_rdy && state == S_EXECUTE;

assign hsync = exec_opcode_this_cycle && opcode == OPCODE_SYNC;

wire [INSTR_BCOND_BITS-1:0] branch_cond = instr[INSTR_BCOND_LSB +: INSTR_BCOND_BITS];
wire [INSTR_Y_BITS-1:0] branch_compval = instr[INSTR_X_LSB +: INSTR_X_BITS];
assign jump_taken =
	branch_cond == BCOND_ALWAYS ||
	branch_cond == BCOND_YLT && beam_y < branch_compval ||
	branch_cond == BCOND_YGE && beam_y >= branch_compval;

assign instr_rdy = !(
	state == S_SPAN_WAIT ||
	state == S_SYNC_WAIT ||
	jump_target_vld && !jump_target_rdy
) && ppu_running;

// ----------------------------------------------------------------------------
// Intersection calculations and span setup

// Calculate intersection of test region with clip region. For BLIT/ABLIT,
// also test against a high alias of the clip region, offset by (1 << INSTR_X_BITS),
// to get correct wrapping behaviour. TODO this can result in two clip regions
// passing; ideally we would draw both, but this mainly matters for systems
// with bigger screens and more RAM :)
//
// Note intersections are decoded directly from the instruction word, so are
// only valid in the EXECUTE state

function [INSTR_X_BITS:0] min; input [INSTR_X_BITS:0] a; input [INSTR_X_BITS:0] b; min = a < b ? a : b; endfunction
function [INSTR_X_BITS:0] max; input [INSTR_X_BITS:0] a; input [INSTR_X_BITS:0] b; max = a > b ? a : b; endfunction

// TILE/ATILE/FILL use the whole scanline
wire use_blit_region = opcode == OPCODE_BLIT || opcode == OPCODE_ABLIT;
wire [INSTR_X_BITS:0] blit_size = (11'h8 << INSTR_BLIT_SIZE(instr)) - 11'h1; // Actually the distance between start and end, which is one less than count
wire [INSTR_X_BITS:0] test_xl = use_blit_region ? {1'b0, instr[INSTR_X_LSB +: INSTR_X_BITS]} : {INSTR_X_BITS+1{1'b0}};
wire [INSTR_X_BITS:0] test_xr = use_blit_region ? test_xl + blit_size : {{INSTR_X_BITS+1-W_COORD_SX{1'b0}}, {W_COORD_SX{1'b1}}};

wire [INSTR_X_BITS:0] xl_clip_primary =   max(test_xl, clip_x0);
wire [INSTR_X_BITS:0] xr_clip_primary =   min(test_xr, clip_x1);
wire [INSTR_X_BITS:0] xl_clip_secondary = max(test_xl, {{INSTR_X_BITS+1-W_COORD_SX{1'b0}}, clip_x0} | {1'b1, {INSTR_X_BITS{1'b0}}});
wire [INSTR_X_BITS:0] xr_clip_secondary = min(test_xr, {{INSTR_X_BITS+1-W_COORD_SX{1'b0}}, clip_x1} | {1'b1, {INSTR_X_BITS{1'b0}}});

wire clip_pass_primary = xl_clip_primary < xr_clip_primary;
wire clip_pass_secondary = xl_clip_secondary < xr_clip_secondary;
wire [INSTR_Y_BITS:0] blit_y_offs = {1'b0, {{INSTR_Y_BITS-W_COORD_SY{1'b0}}, beam_y} - instr[INSTR_Y_LSB +: INSTR_Y_BITS]};
// Note <= not <, because blit_size is end - start, not the pixel count (off by one)
wire blit_intersects_y = !(blit_y_offs > blit_size);

assign skip_span =
	!(clip_pass_primary || (clip_pass_secondary && use_blit_region)) // Skip if X intersect fails
	|| (use_blit_region && !blit_intersects_y);                      // Skip if Y intersect fails


wire [W_COORD_SX-1:0] span_x0_comb = use_blit_region && clip_pass_secondary ? xl_clip_secondary : xl_clip_primary;
wire [W_COORD_SX-1:0] span_count_comb_primary = xr_clip_primary - xl_clip_primary;
wire [W_COORD_SX-1:0] span_count_comb_secondary = xr_clip_secondary - xl_clip_secondary;
wire [W_COORD_SX-1:0] span_count_comb = use_blit_region && clip_pass_secondary ?
	span_count_comb_secondary : span_count_comb_primary;

reg [W_COORD_SX-1:0] span_x0_saved;
reg [W_COORD_SX-1:0] span_count_saved;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		span_x0_saved <= {W_COORD_SX{1'b0}};
		span_count_saved <= {W_COORD_SX{1'b0}};
	end else if (state == S_EXECUTE && instr_vld && instr_rdy) begin
		span_x0_saved <= span_x0_comb;
		span_count_saved <= span_count_comb;
	end
end

// Note we're using xl_clip_primary instead of span_x0_comb because it's
// assumed that any span in S_EXECUTE is a FILL instruction.
assign span_x0 = state == S_EXECUTE ? xl_clip_primary : span_x0_saved;
assign span_count = state == S_EXECUTE ? span_count_comb_primary : span_count_saved;

assign span_type =
	state == S_BLIT_IMG ? SPANTYPE_BLIT :
	state == S_ABLIT_IMG ? SPANTYPE_ABLIT :
	state == S_TILE_TILESET ? SPANTYPE_TILE :
	state == S_ATILE_TILESET ? SPANTYPE_ATILE : SPANTYPE_FILL;

assign span_pixmode = state == S_EXECUTE ? PIXMODE_ARGB1555 : instr[INSTR_PIXMODE_LSB +: INSTR_PIXMODE_BITS];
assign span_paloffs = paloffs;
assign span_fill_colour = instr[14:0];
assign span_texture_ptr = instr_ptr_arg;
assign span_tilemap_ptr = tilemap_ptr;
assign span_texsize = texsize;
assign span_tilesize = tilesize;
assign span_ablit_halfsize = ablit_halfsize;

assign span_start = instr_vld && instr_rdy && (
	// Avoid using the full `skip_span` comparison combinatorially for FILL:
	state == S_EXECUTE && opcode == OPCODE_FILL && clip_pass_primary ||
	state == S_BLIT_IMG ||
	state == S_ABLIT_IMG ||
	state == S_TILE_TILESET ||
	state == S_ATILE_TILESET
);

assign cgen_aparam_vld = instr_vld && (state == S_ABLIT_APARAM || state == S_ATILE_APARAM);
assign cgen_aparam_data = instr;
assign cgen_start_simple = exec_opcode_this_cycle && (
	opcode == OPCODE_BLIT || opcode == OPCODE_TILE
);
assign cgen_start_affine = exec_opcode_this_cycle && (
	opcode == OPCODE_ABLIT || opcode == OPCODE_ATILE
);
assign cgen_raster_offs_y = blit_y_offs[W_COORD_UV-1:0];
assign cgen_raster_offs_x = span_x0_comb - instr[INSTR_X_LSB +: INSTR_X_BITS];

// ----------------------------------------------------------------------------
// Instruction frontend and call stack

// Note the jump is conditional but the pop is not. The pop is on cycle n and
// the jump request asserts on cycle n + 1 (easiest way to deal with sync rd
// port, and jump performance not critical)
wire stack_pop = exec_opcode_this_cycle && opcode == OPCODE_POPJ;
wire stack_push = instr_vld && instr_rdy && state == S_PUSH_DATA;

reg [W_STACK_PTR-1:0] stack_ptr;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		stack_ptr <= {W_STACK_PTR{1'b0}};
	else
		stack_ptr <= (stack_ptr + stack_push) - stack_pop;

wire [W_MEM_ADDR-1:0] stack_wdata = instr_ptr_arg;
wire [W_MEM_ADDR-1:0] stack_rdata;

sram_sync_1r1w #(
	.WIDTH (W_MEM_ADDR),
	.DEPTH (1 << W_STACK_PTR)
) call_stack_mem (
	.clk   (clk),

	.wen   (stack_push),
	.waddr (stack_ptr),
	.wdata (stack_wdata),

	.ren   (stack_pop),
	.raddr (stack_ptr - 1'b1), // empty stack convention
	.rdata (stack_rdata)
);

wire [W_MEM_ADDR-1:0] jump_target = (entrypoint_vld && !ppu_running ? entrypoint : stack_rdata) & GLOBAL_ADDR_MASK & ({W_MEM_ADDR{1'b1}} << 1);
assign jump_target_vld = state == S_POPJ_JUMP || (entrypoint_vld && !ppu_running);

riscboy_ppu_cproc_frontend #(
	.ADDR_MASK  (GLOBAL_ADDR_MASK),
	.W_ADDR     (W_MEM_ADDR),
	.W_DATA     (W_MEM_DATA)
) inst_riscboy_ppu_cproc_frontend (
	.clk             (clk),
	.rst_n           (rst_n),
	.ppu_running     (ppu_running),

	.bus_addr_vld    (bus_addr_vld),
	.bus_addr_rdy    (bus_addr_rdy),
	.bus_addr        (bus_addr),
	.bus_data_vld    (bus_data_vld),
	.bus_data        (bus_data),

	.jump_target_vld (jump_target_vld),
	.jump_target_rdy (jump_target_rdy),
	.jump_target     (jump_target),

	.instr_vld       (instr_vld),
	.instr_rdy       (instr_rdy),
	.instr           (instr)
);

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
