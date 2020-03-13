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

module riscboy_ppu_cproc #(
	parameter W_COORD_SX = 9,
	parameter W_COORD_SY = 8,
	parameter W_COORD_UV = 10,
	parameter W_SPAN_TYPE = 3,
	parameter W_ADDR = 32, // do not modify
	parameter W_DATA = 32  // do not modify
) (
	input  wire                   clk,
	input  wire                   rst_n,

	input  wire                   ppu_running,
	input  wire [W_ADDR-1:0]      entrypoint,
	input  wire                   entrypoint_vld,

	output wire                   bus_addr_vld,
	input  wire                   bus_addr_rdy,
	output wire [W_ADDR-1:0]      bus_addr,
	input  wire                   bus_data_vld,
	input  wire [W_DATA-1:0]      bus_data,

	input  wire [W_COORD_SY-1:0]  beam_y,
	output wire                   hsync,
	input  wire                   scanbuf_rdy,

	// Coordinate generator setup interface
	output wire                   cgen_start_affine,
	output wire                   cgen_start_simple,
	output wire [W_COORD_UV-1:0]  cgen_raster_offs_x,
	output wire [W_COORD_UV-1:0]  cgen_raster_offs_y,
	output wire [W_DATA-1:0]      cgen_aparam_data,
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
	output wire [W_ADDR-1:0]      span_tilemap_ptr,
	output wire [W_ADDR-1:0]      span_texture_ptr,
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
localparam S_POKE_ADDR       = 4'd12;
localparam S_POKE_DATA       = 4'd13;
localparam S_JUMP_ADDR       = 4'd14;

reg [W_STATE-1:0]            state;
reg [2:0]                    data_ctr;
reg [W_DATA-1:0]             tmp_buf;

reg [W_COORD_SX-1:0]         clip_x0;
reg [W_COORD_SX-1:0]         clip_x1;
reg [W_COORD_UV-1:0]         target_x;
reg [W_COORD_UV-1:0]         target_y;

reg [2:0]                    texsize;
reg [INSTR_PALOFFS_BITS-1:0] paloffs;
reg                          tilesize;
reg                          ablit_halfsize;

wire                         instr_vld;
wire                         instr_rdy;
wire [W_DATA-1:0]            instr;
wire [INSTR_OPCODE_BITS-1:0] opcode = instr[INSTR_OPCODE_LSB +: INSTR_OPCODE_BITS];

wire                         skip_span; // e.g. offscreen blit
wire                         jump_taken;
wire                         jump_target_vld;
wire                         jump_target_rdy;

// Control state machine

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		state    <= S_EXECUTE;
		data_ctr <= 3'h0;
		tmp_buf  <= {W_DATA{1'b0}};
		clip_x0  <= {W_COORD_SX{1'b0}};
		clip_x1  <= {W_COORD_SX{1'b0}};
		target_x <= {W_COORD_UV{1'b0}};
		target_y <= {W_COORD_UV{1'b0}};
		texsize  <= 3'h0;
		paloffs  <= {INSTR_PALOFFS_BITS{1'b0}};
		tilesize <= 1'b0;
		ablit_halfsize <= 1'b0;
	end else if (ppu_running && (instr_vld || !instr_rdy)) case (state)

		S_EXECUTE: case (opcode)
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
				texsize <= INSTR_BLIT_SIZE(instr);
				paloffs <= instr[INSTR_PALOFFS_LSB +: INSTR_PALOFFS_BITS];
				target_x <= instr[INSTR_X_LSB +: INSTR_X_BITS];
				target_y <= instr[INSTR_X_LSB +: INSTR_Y_BITS];
			end
			OPCODE_TILE: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h1;
			end else begin
				state <= S_TILE_TILEMAP;
				tilesize <= INSTR_TILE_SIZE(instr);
				paloffs <= instr[INSTR_PALOFFS_LSB +: INSTR_PALOFFS_BITS];
				target_x <= instr[INSTR_X_LSB +: INSTR_X_BITS];
				target_y <= instr[INSTR_X_LSB +: INSTR_Y_BITS];
			end
			OPCODE_ABLIT: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h3;
			end else begin
				state <= S_ABLIT_APARAM;
				data_ctr <= 3'h2;
				texsize <= INSTR_BLIT_SIZE(instr);
				paloffs <= instr[INSTR_PALOFFS_LSB +: INSTR_PALOFFS_BITS];
				target_x <= instr[INSTR_X_LSB +: INSTR_X_BITS];
				target_y <= instr[INSTR_X_LSB +: INSTR_Y_BITS];
				ablit_halfsize <= instr[INSTR_ABLIT_HALFSIZE_LSB];
			end
			OPCODE_ATILE: if (skip_span) begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h4;
			end else begin
				state <= S_ATILE_APARAM;
				data_ctr <= 3'h2;
				tilesize <= INSTR_TILE_SIZE(instr);
				paloffs <= instr[INSTR_PALOFFS_LSB +: INSTR_PALOFFS_BITS];
				target_x <= instr[INSTR_X_LSB +: INSTR_X_BITS];
				target_y <= instr[INSTR_X_LSB +: INSTR_Y_BITS];
			end
			OPCODE_POKE: state <= S_POKE_ADDR;
			OPCODE_JUMP: if (jump_taken) begin
				state <= S_JUMP_ADDR;
			end else begin
				state <= S_SKIP_INSTR_DATA;
				data_ctr <= 3'h0;
			end
		endcase

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
			tmp_buf <= instr & INSTR_ADDR_MASK; // tilemap ptr
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
			tmp_buf <= instr & INSTR_ADDR_MASK; // tilemap ptr
			texsize <= INSTR_PF_SIZE(instr);
		end
		S_ATILE_TILEMAP: state <= S_SPAN_WAIT;
		S_POKE_ADDR: begin
			state <= S_POKE_DATA;
			tmp_buf <= instr & INSTR_ADDR_MASK;
		end
		S_POKE_DATA: begin
			// TODO actually hook this up
			state <= S_EXECUTE;
		end
		S_JUMP_ADDR: begin
			if (jump_target_rdy)
				state <= S_EXECUTE;
		end

	endcase
end

assign hsync = instr_vld && instr_rdy && opcode == OPCODE_SYNC;

assign jump_taken = 1'b1; // TODO condition codes

assign instr_rdy = !(
	state == S_SPAN_WAIT ||
	state == S_SYNC_WAIT ||
	jump_target_vld && !jump_target_rdy
) && ppu_running;

assign cgen_aparam_vld = instr_vld && (state == S_ABLIT_APARAM || state == S_ATILE_APARAM);
assign cgen_aparam_data = instr;

// ----------------------------------------------------------------------------
// Intersection calculations and span setup

assign skip_span = clip_x0 > clip_x1 || opcode != OPCODE_FILL; // TODO

assign span_start =
	state == S_EXECUTE && opcode == OPCODE_FILL && !skip_span ||
	1'b0; // TODO

assign span_x0 = clip_x0; // TODO
assign span_count = clip_x1 - clip_x0; // TODO
assign span_type =
	state == S_BLIT_IMG ? SPANTYPE_BLIT :
	state == S_ABLIT_IMG ? SPANTYPE_ABLIT :
	state == S_TILE_TILESET ? SPANTYPE_TILE :
	state == S_ATILE_TILESET ? SPANTYPE_ATILE : SPANTYPE_FILL;

assign span_pixmode = state == S_EXECUTE ? PIXMODE_ARGB1555 : instr[INSTR_PIXMODE_LSB +: INSTR_PIXMODE_BITS];
assign span_paloffs = paloffs;
assign span_fill_colour = instr[14:0];
assign span_texture_ptr = instr & INSTR_ADDR_MASK;
assign span_tilemap_ptr = tmp_buf & INSTR_ADDR_MASK;
assign span_texsize = texsize;
assign span_tilesize = tilesize;
assign span_ablit_halfsize = ablit_halfsize;

// ----------------------------------------------------------------------------
// Instruction frontend

wire [W_ADDR-1:0] jump_target = (entrypoint_vld && !ppu_running ? entrypoint : instr) & INSTR_ADDR_MASK;
assign jump_target_vld = (state == S_JUMP_ADDR && instr_vld) || (entrypoint_vld && !ppu_running);

riscboy_ppu_cproc_frontend #(
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA)
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
