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


module tb;

`include "hazard5_ops.vh"

localparam CLK_PERIOD = 10.0;
localparam XLEN = 32;
localparam UNROLL = 1;

reg               clk;
reg               rst_n;

reg  [2:0]        op;
reg               op_vld;
reg               op_force;
reg  [XLEN-1:0]   op_a;
reg  [XLEN-1:0]   op_b;

wire              op_rdy;
wire [XLEN-1:0]   result_h; // mulh* or mod*
wire [XLEN-1:0]   result_l; // mul   or div*
wire              result_vld;

hazard5_muldiv_seq #(
	.XLEN(XLEN),
	.UNROLL(UNROLL)
) inst_hazard5_muldiv_seq (
	.clk        (clk),
	.rst_n      (rst_n),
	.op         (op),
	.op_vld     (op_vld),
	.op_rdy     (op_rdy),
	.op_force   (op_force),
	.op_a       (op_a),
	.op_b       (op_b),
	.result_h   (result_h),
	.result_l   (result_l),
	.result_vld (result_vld)
);

task do_calc;
	input  [XLEN-1:0] do_op_a;
	input  [XLEN-1:0] do_op_b;
	input  [2:0]      do_op;
begin
	@ (posedge clk);
	op <= do_op;
	op_a <= do_op_a;
	op_b <= do_op_b;
	op_vld <= 1'b1;
	@ (posedge clk);
	while (!op_rdy)
		@ (posedge clk);
	op_vld <= 1'b0;
	op <= 0;
	op_a <= 0;
	op_b <= 0;
	@ (posedge clk);
	while (!result_vld)
		@ (posedge clk);
end
endtask

function [2*XLEN-1:0] sext;
	input [XLEN-1:0] x;
begin
	sext = {{XLEN{x[XLEN - 1]}}, x};
end
endfunction


always #(0.5 * CLK_PERIOD) clk = !clk;

localparam TEST_SIZE = 1000;
localparam X0 = {XLEN{1'b0}};

initial begin: stimulus
	reg [XLEN-1:0]   a_tmp;
	reg [XLEN-1:0]   b_tmp;
	reg [2*XLEN-1:0] gold_result;
	reg [XLEN-1:0]   gold_result_h;
	reg [XLEN-1:0]   gold_result_l;
	integer i;

	clk = 1'b0;
	rst_n = 1'b0;
	op = 0;
	op_vld = 0;
	op_force = 0;
	op_a = 0;
	op_b = 0;

	@ (posedge clk);
	@ (posedge clk);
	rst_n = 1'b1;
	@ (posedge clk);

	$display("MULHU + MUL");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = $random;
		gold_result = a_tmp * b_tmp;
		do_calc(a_tmp, b_tmp, M_OP_MULHU);
		if (gold_result != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", gold_result, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("MULH + MUL");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = $random;
		gold_result = sext(a_tmp) * sext(b_tmp);
		do_calc(a_tmp, b_tmp, M_OP_MULH);
		if (gold_result != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", gold_result, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("MULHSU + MUL");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = $random;
		gold_result = sext(a_tmp) * b_tmp;
		do_calc(a_tmp, b_tmp, M_OP_MULHSU);
		if (gold_result != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", gold_result, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("MUL only");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = $random;
		gold_result_l = a_tmp * b_tmp;
		do_calc(a_tmp, b_tmp, M_OP_MUL);
		if (gold_result_l != result_l) begin
			$display("Mismatch: %h (gold) != %h (gate)", gold_result_l, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("DIVU + MODU");


	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = $random;
		while (!b_tmp)
			b_tmp = $random;
		gold_result_l = a_tmp / b_tmp;
		gold_result_h = a_tmp % b_tmp;
		do_calc(a_tmp, b_tmp, M_OP_DIVU);
		if ({gold_result_h, gold_result_l} != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", {gold_result_h, gold_result_l}, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("DIV + MOD");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = $random;
		while (!b_tmp)
			b_tmp = $random;
		gold_result_l = $signed(a_tmp) / $signed(b_tmp);
		gold_result_h = $signed(a_tmp) % $signed(b_tmp);
		do_calc(a_tmp, b_tmp, M_OP_DIV);
		if ({gold_result_h, gold_result_l} != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", {gold_result_h, gold_result_l}, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("DIVU + MODU by 0");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = 0;
		gold_result_l = {XLEN{1'b1}};
		gold_result_h = a_tmp;
		do_calc(a_tmp, b_tmp, M_OP_DIVU);
		if ({gold_result_h, gold_result_l} != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", {gold_result_h, gold_result_l}, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("DIV + MOD by 0");

	for (i = 0; i < TEST_SIZE; i = i + 1) begin
		a_tmp = $random;
		b_tmp = 0;
		gold_result_l = {XLEN{1'b1}};
		gold_result_h = a_tmp;
		do_calc(a_tmp, b_tmp, M_OP_DIV);
		if ({gold_result_h, gold_result_l} != {result_h, result_l}) begin
			$display("Mismatch: %h (gold) != %h (gate)", {gold_result_h, gold_result_l}, {result_h, result_l});
			$display("Operands: %h %h", a_tmp, b_tmp);
			$finish;
		end
	end

	$display("DIV signed overflow");

	gold_result_h = {XLEN{1'b0}};
	gold_result_l = {1'b1, {XLEN-1{1'b0}}};

	do_calc({1'b1, {XLEN-1{1'b0}}}, 1, M_OP_DIV);
	if ({gold_result_h, gold_result_l} != {result_h, result_l}) begin
		$display("Mismatch: %h (gold) != %h (gate)", {gold_result_h, gold_result_l}, {result_h, result_l});
		$display("Operands: %h %h", a_tmp, b_tmp);
		$finish;
	end

	$display("Test PASSED.");

	$finish;
end

endmodule
