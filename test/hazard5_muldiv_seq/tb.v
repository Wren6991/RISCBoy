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
	@ (posedge clk);
	while (!result_vld)
		@ (posedge clk);
end
endtask

always #(0.5 * CLK_PERIOD) clk = !clk;

initial begin: stimulus
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

	do_calc(3, 4, M_OP_MUL);
	$display("%h", result_l);

	$finish;
end

endmodule
