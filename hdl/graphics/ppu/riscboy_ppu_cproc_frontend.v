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

// Instruction frontend for PPU command processor

`default_nettype none

module riscboy_ppu_cproc_frontend #(
	parameter W_ADDR    = 18,
	parameter ADDR_MASK = {W_ADDR{1'b1}},
	parameter W_DATA    = 16,        // do not modify
	parameter W_INSTR   = 2 * W_DATA // do not modify
) (
	input  wire               clk,
	input  wire               rst_n,

	input  wire               ppu_running,

	output wire               bus_addr_vld,
	input  wire               bus_addr_rdy,
	output wire [W_ADDR-1:0]  bus_addr,

	input  wire               bus_data_vld,
	input  wire [W_DATA-1:0]  bus_data,

	input  wire               jump_target_vld,
	output wire               jump_target_rdy,
	input  wire [W_ADDR-1:0]  jump_target,

	output wire               instr_vld,
	input  wire               instr_rdy,
	output wire [W_INSTR-1:0] instr
);

// ----------------------------------------------------------------------------
// Instruction prefetch buffer

localparam BUF_DEPTH = 6;
localparam W_BUF_LEVEL = 3;

reg [W_ADDR-1:0] pc;
wire jump_now = jump_target_vld && (jump_target_rdy || !ppu_running);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pc <= {W_ADDR{1'b0}};
	end else if (jump_now) begin
		pc <= jump_target & ADDR_MASK;
	end else if (bus_addr_vld && bus_addr_rdy) begin
		pc <= ((pc & ADDR_MASK) + 1'b1) & ADDR_MASK;
	end
end

wire [W_DATA-1:0]      instr_buf_rdata;
wire                   instr_buf_ren;
wire                   instr_buf_full;
wire                   instr_buf_empty;
wire [W_BUF_LEVEL-1:0] instr_buf_level;

sync_fifo #(
	.WIDTH (W_DATA),
	.DEPTH (BUF_DEPTH)
) instr_buf (
	.clk   (clk),
	.rst_n (rst_n),

	.wdata (bus_data),
	.wen   (bus_data_vld),
	.rdata (instr_buf_rdata),
	.ren   (instr_buf_ren),

	.flush (jump_now),

	.full  (instr_buf_full),
	.empty (instr_buf_empty),
	.level (instr_buf_level)
);

// Easy way to make sure nothing is in flight at the point where we assert the
// jump address (may cause a wasted fetch so TODO revisit this later)
assign jump_target_rdy = instr_buf_full;

// ----------------------------------------------------------------------------
// Assemble 32-bit instructions from 16-bit fetch data

reg [W_DATA-1:0] instr_firsthalf;
reg              instr_firsthalf_vld;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		instr_firsthalf <= {W_DATA{1'b0}};
	end else if (jump_now) begin
		instr_firsthalf_vld <= 1'b0;
	end else if (instr_buf_ren && !instr_firsthalf_vld) begin
		instr_firsthalf_vld <= 1'b1;
		instr_firsthalf <= instr_buf_rdata;
	end else if (instr_vld && instr_rdy) begin
		instr_firsthalf_vld <= 1'b0;
	end
end

assign instr_vld     = !instr_buf_empty && instr_firsthalf_vld;
assign instr_buf_ren = !instr_buf_empty && (instr_rdy || !instr_firsthalf_vld);
assign instr         = {instr_buf_rdata, instr_firsthalf};

// ----------------------------------------------------------------------------
// Bus request generation

reg [W_BUF_LEVEL-1:0] fetches_in_flight;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
	 fetches_in_flight <= {W_BUF_LEVEL{1'b0}};
	end else begin
	 fetches_in_flight <= fetches_in_flight
			+ {{W_BUF_LEVEL-1{1'b0}}, (bus_addr_vld && bus_addr_rdy)}
			- {{W_BUF_LEVEL-1{1'b0}},  bus_data_vld                 };
	end
end

assign bus_addr = pc & ADDR_MASK;
assign bus_addr_vld = instr_buf_level + fetches_in_flight < BUF_DEPTH;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
