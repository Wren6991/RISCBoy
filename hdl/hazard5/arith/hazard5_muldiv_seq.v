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

// Combined multiply/divide/modulo circuit.
// All operations performed at 1 bit per clock; aiming for minimal resource usage.
// There are lots of opportunities for off-by-one errors here. See muldiv_model.py
// for a simple reference model of the mul/div/mod iterations.
//
// When op_force is high, the vld/rdy handshake is ignored, and a new operation
// starts immediately. Needed for processor flushing (e.g. mispredict, trap)
//
// The actual multiply/divide hardware is unsigned. We handle signedness at
// input/output.

module hazard5_muldiv_seq #(
	parameter XLEN = 32,
	parameter UNROLL = 1,
	parameter W_CTR = $clog2(XLEN + 1) // do not modify
) (
	input  wire              clk,
	input  wire              rst_n,
	input  wire [2:0]        op,
	input  wire              op_vld,
	output wire              op_rdy,
	input  wire              op_force,
	input  wire [XLEN-1:0]   op_a,
	input  wire [XLEN-1:0]   op_b,

	output wire [XLEN-1:0]   result_h, // mulh* or mod*
	output wire [XLEN-1:0]   result_l, // mul   or div*
	output wire              result_vld
);

`include "hazard5_ops.vh"

//synthesis translate_off
generate if (UNROLL & (UNROLL - 1) || ~|UNROLL)
	initial $fatal("%m: UNROLL must be a positive power of 2");
endgenerate
//synthesis translate_on

// ----------------------------------------------------------------------------
// Operation decode, operand sign adjustment

// On the first cycle, op_a and op_b go straight through to the accumulator
// and the divisor/multiplicand register. They are then adjusted in-place
// on the next cycle. This allows the same circuits to be reused for sign
// adjustment before output (and helps input timing).

reg [W_M_OP-1:0] op_r;
reg [2*XLEN-1:0] accum;
reg [XLEN-1:0]   op_b_r;
reg              op_a_neg_r;
reg              op_b_neg_r;

wire op_a_signed =
	op_r == M_OP_MULH ||
	op_r == M_OP_MULHSU ||
	op_r == M_OP_DIV ||
	op_r == M_OP_MOD;

wire op_b_signed =
	op_r == M_OP_MULH ||
	op_r == M_OP_DIV ||
	op_r == M_OP_MOD;

wire op_a_neg = op_a_signed && accum[XLEN-1];
wire op_b_neg = op_b_signed && op_b_r[XLEN-1];

wire is_div = op_r[2];

// Controls for modifying sign of all/part of accumulator
wire accum_neg_l;
wire accum_inv_h;
wire accum_incr_h;

// ----------------------------------------------------------------------------
// Arithmetic circuit

// Combinatorials:
reg [2*XLEN-1:0] accum_next;
reg [2*XLEN-1:0] addend;
reg [2*XLEN-1:0] shift_tmp;
reg [2*XLEN-1:0] addsub_tmp;
reg              neg_l_borrow;

always @ (*) begin: alu
	integer i;
	// Multiply/divide iteration layers
	accum_next = accum;
	addend = {2*XLEN{1'b0}};
	addsub_tmp = {2*XLEN{1'b0}};
	neg_l_borrow = 1'b0;
	for (i = 0; i < UNROLL; i = i + 1) begin
		addend = {is_div && |op_b_r, op_b_r, {XLEN-1{1'b0}}};
		shift_tmp = is_div ? accum_next : accum_next >> 1;
		addsub_tmp = shift_tmp + addend;
		accum_next = (is_div ? !addsub_tmp[2 * XLEN - 1] : accum_next[0]) ?
			addsub_tmp : shift_tmp;
		if (is_div)
			accum_next = {accum_next[2*XLEN-2:0], !addsub_tmp[2 * XLEN - 1]};
	end
	// Alternative path for negation of all/part of accumulator
	if (accum_neg_l)
		{neg_l_borrow, accum_next[XLEN-1:0]} = {~accum[XLEN-1:0]} + 1'b1;
	if (accum_incr_h || accum_inv_h)
		accum_next[XLEN +: XLEN] = (accum[XLEN +: XLEN] ^ {XLEN{accum_inv_h}})
			+ accum_incr_h;
end

// ----------------------------------------------------------------------------
// Main state machine

reg sign_preadj_done;
reg [W_CTR-1:0] ctr;
reg sign_postadj_done;
reg sign_postadj_carry;

localparam CTR_TOP = XLEN[W_CTR-1:0];

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ctr <= {W_CTR{1'b0}};
		sign_preadj_done <= 1'b0;
		sign_postadj_done <= 1'b0;
		sign_postadj_carry <= 1'b0;
		op_r <= {W_M_OP{1'b0}};
		op_a_neg_r <= 1'b0;
		op_b_neg_r <= 1'b0;
		op_b_r <= {XLEN{1'b0}};
		accum <= {XLEN*2{1'b0}};
	end else if (op_force || (op_vld && op_rdy)) begin
		// Initialise circuit with operands + state
		ctr <= CTR_TOP;
		sign_preadj_done <= 1'b0;
		sign_postadj_done <= 1'b0;
		sign_postadj_carry <= 1'b0;
		op_r <= op;
		op_b_r <= op_b;
		accum <= {{XLEN{1'b0}}, op_a};
	end else if (!sign_preadj_done) begin
		// Pre-adjust sign if necessary, else perform first iteration immediately
		op_a_neg_r <= op_a_neg;
		op_b_neg_r <= op_b_neg;
		sign_preadj_done <= 1'b1;
		if (accum_neg_l || (op_b_neg ^ is_div)) begin
			if (accum_neg_l)
				accum[0 +: XLEN] <= accum_next[0 +: XLEN];
			if (op_b_neg ^ is_div)
				op_b_r <= -op_b_r;
		end else begin
			ctr <= ctr - UNROLL[W_CTR-1:0];
			accum <= accum_next;
		end
	end else if (ctr) begin
		ctr <= ctr - UNROLL[W_CTR-1:0];
		accum <= accum_next;
	end else if (!sign_postadj_done || sign_postadj_carry) begin
		sign_postadj_done <= 1'b1;
		if (accum_inv_h || accum_incr_h)
			accum[XLEN +: XLEN] <= accum_next[XLEN +: XLEN];
		if (accum_neg_l) begin
			accum[0 +: XLEN] <= accum_next[0 +: XLEN];
			if (!is_div) begin
				sign_postadj_carry <= neg_l_borrow;
				sign_postadj_done <= !neg_l_borrow;
			end
		end
	end
end

// ----------------------------------------------------------------------------
// Sign adjustment control

// Pre-adjustment: for any a, b we want |a|, |b|. Note that the magnitude of any
// 32-bit signed integer is representable by a 32-bit unsigned integer.

// Post-adjustment for division:
// We seek q, r to satisfy a = b * q + r, where a and b are given,
// and |r| < |b|. One way to do this is if
// sgn(r) = sgn(a)
// sgn(q) = sgn(a) ^ sgn(b)
// This has additional nice properties like
// -(a / b) = (-a) / b = a / (-b)

// Post-adjustment for multiplication:
// We have calculated the 2*XLEN result of |a| * |b|.
// Negate the entire accumulator if sgn(a) ^ sgn(b).
// This is done in two steps (to share div/mod circuit, and avoid 64-bit carry):
// - Negate lower half of accumulator, and invert upper half
// - Increment upper half if lower half carried

wire do_postadj = ~|{ctr, sign_postadj_done};
wire op_signs_differ = op_a_neg_r ^ op_b_neg_r;

assign accum_neg_l =
	!sign_preadj_done && op_a_neg ||
	do_postadj && !sign_postadj_carry && op_signs_differ && !(is_div && ~|op_b_r);

assign {accum_incr_h, accum_inv_h} =
	do_postadj &&  is_div && op_a_neg_r                             ? 2'b11 :
	do_postadj && !is_div && op_signs_differ && !sign_postadj_carry ? 2'b01 :
	do_postadj && !is_div && op_signs_differ &&  sign_postadj_carry ? 2'b10 :
	                                                                  2'b00 ;

// ----------------------------------------------------------------------------
// Outputs

assign {result_h, result_l} = accum;
assign op_rdy = ~|{ctr, accum_neg_l, accum_incr_h, accum_inv_h};
assign result_vld = op_rdy;

endmodule
