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

module riscboy_ppu_cproc_frontend #(
	parameter ADDR_MASK = 32'hffff_fffc,
	parameter W_ADDR = 32, // do not modify
	parameter W_DATA = 32  // do not modify
) (
	input  wire              clk,
	input  wire              rst_n,

	input  wire              ppu_running,

	output wire              bus_addr_vld,
	input  wire              bus_addr_rdy,
	output wire [W_ADDR-1:0] bus_addr,

	input  wire              bus_data_vld,
	input  wire [W_DATA-1:0] bus_data,

	input  wire              jump_target_vld,
	output wire              jump_target_rdy,
	input  wire [W_ADDR-1:0] jump_target,

	output wire              instr_vld,
	input  wire              instr_rdy,
	output wire [W_DATA-1:0] instr
);

`ifdef FORMAL
always @ (posedge clk) if (rst_n && $past(rst_n)) begin
	// We must keep bus address asserted until it goes through (AHB-lite constraint)
	if (ppu_running && $past(bus_addr_vld && !bus_addr_rdy)) begin
		assert(bus_addr_vld);
		assert($stable(bus_addr));
	end
	// Require the same to be true of the jump request
	if (ppu_running && $past(jump_target_vld && !jump_target_rdy)) begin
		assert(jump_target_vld);
		assert($stable(jump_target));
	end
end
`endif

reg [W_ADDR-1:0] pc;
wire jump_now = jump_target_vld && (jump_target_rdy || !ppu_running);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pc <= {W_ADDR{1'b0}};
	end else if (jump_now) begin
		pc <= jump_target & ADDR_MASK;
	end else if (bus_addr_vld && bus_addr_rdy) begin
		pc <= (pc & ADDR_MASK) + 3'h4;
	end
end

wire instr_buf_ren = instr_vld && instr_rdy;
wire instr_buf_full;
wire instr_buf_empty;

skid_buffer #(
	.WIDTH (W_DATA)
) instr_buf (
	.clk   (clk),
	.rst_n (rst_n),

	.wdata (bus_data),
	.wen   (bus_data_vld),
	.rdata (instr),
	.ren   (instr_buf_ren),

	.flush (jump_now),

	.full  (instr_buf_full),
	.empty (instr_buf_empty),
	.level (/* unused */)
);

// ----------------------------------------------------------------------------
// Handshaking

reg dphase_in_flight;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dphase_in_flight <= 1'b0;
	end else begin
		dphase_in_flight <= (dphase_in_flight && !bus_data_vld) || (bus_addr_vld && bus_addr_rdy);
`ifdef FORMAL
		if (!dphase_in_flight)
			assert(!bus_data_vld);
`endif
	end
end

assign bus_addr = pc & ADDR_MASK;
assign bus_addr_vld = instr_buf_empty || !(instr_buf_full || dphase_in_flight);

// Easy way to make sure nothing is in flight at the point where we assert the
// jump address (may cause a wasted fetch so TODO revisit this later)
assign jump_target_rdy = instr_buf_full;

assign instr_vld = !instr_buf_empty;

endmodule
