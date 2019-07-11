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

// Combined multiply/divide/modulo circuit
// All operations performed at 1 bit per clock; aiming for minimal resource usage

// When op_force is high, the vld/rdy handshake is ignored, and a new operation
// starts immediately. Needed for processor flushing (e.g. mispredict, trap)

// Start of multiply: multiplicand (rs2) goes into op_b_r, multiplier goes into
// LSBs of accum. We shift multiplier up at the same time as shifting MSB round,
// but do not allow multiplier bits to leak through into MSBs.
// Multiplier is gone when multiply finishes.

// Start of divide: divisor goes into op_b_r, dividend goes into LSBs of accum.
// Each cycle we subtract divisor from MSBs, and commit if no underflow.

// The actual multiply/divide hardware is just unsigned. We handle signedness
// at input/output.

module hazard5_muldiv_seq #(
	parameter XLEN = 32,
	parameter UNROLL = 1,
	parameter W_CTR = $clog2(XLEN + 1) // do not modify
) (
	input  wire [2:0]        op,
	input  wire              op_vld,
	output reg               op_rdy,
	input  wire              op_force,
	input  wire [XLEN-1:0]   op_a,
	input wire  [XLEN-1:0]   op_b,

	output wire [XLEN-1:0]   result_h,
	output wire [XLEN-1:0]   result_l,
	output reg  [XLEN-1:0]   result_vld
);

`include "hazard5_ops.vh"

//synthesis translate_off
initial if (UNROLL & (UNROLL - 1))
	$error("%m: UNROLL must be a power of 2");
//synthesis translate_on

reg [W_M_OP-1:0] op_r;

wire op_a_signed =
	op == M_OP_MULH ||
	op == M_OP_MULHSU ||
	op == M_OP_DIV ||
	op == M_OP_MOD;

wire op_b_signed =
	op == M_OP_MULH ||
	op == M_OP_DIV ||
	op == M_OP_MOD;

wire op_a_neg = op_a_signed && op_a[XLEN-1];
wire op_b_neg = op_b_signed && op_a[XLEN-1];
wire op_a_abs = op_a_neg ? -op_a : op_a;
wire op_b_abs = op_b_neg ? -op_b : op_b;

reg [2*XLEN-1:0] accum;
reg [XLEN-1:0]   op_b_r; // Divisor or multiplier
reg              op_a_neg_r;
reg              op_b_neg_r;

// Arithmetic circuits

reg [2*XLEN-1:0] accum_next;
reg [XLEN-1:0]   addend;
reg [XLEN  :0]   addsub_tmp;
reg              add_inhibit;
reg [XLEN-1:0]   alu_result;

wire is_div = op_r[2];

always @ (*) begin: alu
	integer i;
	accum_next = accum;
	for (i = 0; i < UNROLL; ++i) begin
		addend = is_div ? -op_b_r : op_b_r;
		addsub_tmp = {1'b0, accum[XLEN +: XLEN]} + {1'b0, addend};
		add_inhibit = is_div ? addsub_tmp[XLEN] : !op_b_r[XLEN-1]
        alu_result = add_inhibit ? accum_next[XLEN +: XLEN] : addsub_tmp[XLEN-1:0];
        accum_next = {alu_result[XLEN-2:1], accum_next[XLEN-1:0], alu_result[XLEN-1]};
	end
end

// Main state machine

reg [W_CTR-1:0] ctr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ctr <= {W_CTR{1'b0}};
		op_r <= {W_M_OP{1'b0}};
		op_a_neg_r <= 1'b0;
		op_b_neg_r <= 1'b0;
		op_b_r <= {XLEN{1'b0}};
		accum <= {XLEN*2{1'b0}};
	end else if (op_force || (op_vld && op_rdy)) begin
		ctr <= XLEN[W_CTR-1:0];
		op_r <= op;
		op_a_neg_r <= op_a_neg;
		op_b_neg_r <= op_b_neg;
		op_b_r <= op_b_abs;
		accum <= {{XLEN{1'b0}}, op_a_abs};
	end else if (ctr) begin
		ctr <= ctr - UNROLL[W_CTR-1:0];
		accum <= accum_next;
	end
end

endmodule
