module tb;

`include "hazard5_ops.vh"

`ifndef XLEN
`define XLEN 32
`endif
`ifndef UNROLL
`define UNROLL 1
`endif

localparam XLEN = `XLEN ;
localparam UNROLL = `UNROLL ;

(* keep *) reg               clk;
(* keep *) wire              rst_n;
(* keep *) reg  [2:0]        op;
(* keep *) reg               op_vld;
(* keep *) wire              op_rdy;
(* keep *) reg               op_kill;
(* keep *) reg  [XLEN-1:0]   op_a;
(* keep *) reg  [XLEN-1:0]   op_b;

(* keep *) wire [XLEN-1:0]   result_h;
(* keep *) wire [XLEN-1:0]   result_l;
(* keep *) wire              result_vld;

reg [7:0] reset_ctr;
initial assume(reset_ctr == 0);
always @ (posedge clk)
	reset_ctr <= reset_ctr + 1;
assign rst_n = reset_ctr >= 2;

hazard5_muldiv_seq #(
	.XLEN   (XLEN),
	.UNROLL (UNROLL)
) dut (
	.clk        (clk),
	.rst_n      (rst_n),

	.op         (op),
	.op_vld     (op_vld),
	.op_rdy     (op_rdy),
	.op_kill    (op_kill),
	.op_a       (op_a),
	.op_b       (op_b),

	.result_h   (result_h),
	.result_l   (result_l),
	.result_vld (result_vld)
);


always assume (!op_kill); // FIXME this weakens the proof, although we do still sweep the whole input space

// ----------------------------------------------------------------------------
// Properties

reg  [2:0]        prev_op;
reg  [XLEN-1:0]   prev_op_a;
reg  [XLEN-1:0]   prev_op_b;

always @ (posedge clk) begin
	if (!rst_n) begin
		prev_op <= M_OP_MUL;
		prev_op_a <= {XLEN{1'b0}};
		prev_op_b <= {XLEN{1'b0}};
	end else if (op_vld && (op_rdy || op_kill)) begin
		prev_op <= op;
		prev_op_a <= op_a;
		prev_op_b <= op_b;
	end
end

wire [XLEN-1:0] spec_mul    = prev_op_a * prev_op_b;
wire [XLEN-1:0] spec_mulh   = ({{XLEN{prev_op_a[XLEN-1]}}, prev_op_a} * {{XLEN{prev_op_b[XLEN-1]}}, prev_op_b}) >> XLEN;
wire [XLEN-1:0] spec_mulhsu = ({{XLEN{prev_op_a[XLEN-1]}}, prev_op_a} * {{XLEN{1'b0             }}, prev_op_b}) >> XLEN;
wire [XLEN-1:0] spec_mulhu  = ({{XLEN{1'b0             }}, prev_op_a} * {{XLEN{1'b0             }}, prev_op_b}) >> XLEN;

wire [XLEN-1:0] spec_divu   = prev_op_b ? prev_op_a / prev_op_b : {XLEN{1'b1}}; // div zero -> all-ones
wire [XLEN-1:0] spec_div    = ~|prev_op_b ? {XLEN{1'b1}}                                                  : // div zero -> all-ones
                              prev_op_a == {1'b1, {XLEN-1{1'b0}}} && prev_op_b == {XLEN{1'b1}} ? prev_op_a : // negative overflow case
                              $signed(prev_op_a) / $signed(prev_op_b);                                      // otherwise pretty normal

wire [XLEN-1:0] spec_remu   = ~|prev_op_b ? prev_op_a : prev_op_a % prev_op_b; // remainder equal to dividend if divisor is 0, like it SHOULD BE EVERYWHERE
wire [XLEN-1:0] spec_rem    = ~|prev_op_b ? prev_op_a :
                              prev_op_a == {1'b1, {XLEN-1{1'b0}}} && prev_op_b == {XLEN{1'b1}} ? {XLEN{1'b0}} : // negative overflow case
                              $signed(prev_op_a) % $signed(prev_op_b);


always @ (posedge clk) if (result_vld && reset_ctr > 4) begin
	case (prev_op)
		M_OP_MUL    : assert(result_l == spec_mul);
		M_OP_MULH   : assert(result_h == spec_mulh);
		M_OP_MULHSU : assert(result_h == spec_mulhsu);
		M_OP_MULHU  : assert(result_h == spec_mulhu);
		M_OP_DIV    : assert(result_l == spec_div);
		M_OP_DIVU   : assert(result_l == spec_divu);
		M_OP_REM    : assert(result_h == spec_rem);
		M_OP_REMU   : assert(result_h == spec_remu);
	endcase
end

endmodule