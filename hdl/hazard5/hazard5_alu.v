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

module hazard5_alu #(
	parameter W_DATA = 32
) (
	input  wire [3:0]        aluop,
	input  wire [W_DATA-1:0] op_a,
	input  wire [W_DATA-1:0] op_b,
	output reg  [W_DATA-1:0] result,
	output reg               zero
);

`include "hazard5_ops.vh"

function msb;
input [W_DATA-1:0] x;
begin
	msb = x[W_DATA-1];
end
endfunction

wire [W_DATA-1:0] sum  = op_a + op_b;
wire [W_DATA-1:0] diff;
wire borrow;
assign {borrow, diff} = op_a - op_b;

wire ltu = borrow;
reg lt;
always @ (*) begin
	if (msb(op_b) && !msb(op_a)) begin
		lt = 1'b0;
	end else if (msb(op_a) && !msb(op_b)) begin
		lt = 1'b1;
	end else begin
		lt = msb(diff);
	end
end

wire [W_DATA-1:0] shift_dout;
reg shift_right_nleft;
reg shift_arith;

hazard5_shift_rla #(
	.W_DATA(W_DATA),
	.W_SHAMT(5)
) shifter (
	.din(op_a),
	.shamt(op_b[4:0]),
	.right_nleft(shift_right_nleft),
	.arith(shift_arith),
	.dout(shift_dout)
);

always @ (*) begin
	shift_right_nleft = 1'b0;
	shift_arith = 1'b0;
	case (aluop)
		/*ALUOP_ADD*/default: begin result = sum; end
		ALUOP_SUB: begin result = diff; end
		ALUOP_LT:  begin result = {{W_DATA-1{1'b0}}, lt}; end
		ALUOP_GE:  begin result = {{W_DATA-1{1'b0}}, !lt}; end
		ALUOP_LTU: begin result = {{W_DATA-1{1'b0}}, ltu}; end
		ALUOP_GEU: begin result = {{W_DATA-1{1'b0}}, !ltu}; end
		ALUOP_AND: begin result = op_a & op_b; end
		ALUOP_OR:  begin result = op_a | op_b; end
		ALUOP_XOR: begin result = op_a ^ op_b; end
		ALUOP_SRL: begin shift_right_nleft = 1'b1; result = shift_dout; end
		ALUOP_SRA: begin shift_right_nleft = 1'b1; shift_arith = 1'b1; result = shift_dout; end
		ALUOP_SLL: begin result = shift_dout; end
	endcase
	zero = !result;
end

`ifdef FORMAL
// Really we're just interested in the shifts and comparisons, as these are
// the nontrivial ones. However, easier to test everything!

wire clk;
always @ (posedge clk) begin
	case(aluop)
	default: begin end
	ALUOP_ADD: assert(result == op_a + op_b);
	ALUOP_SUB: assert(result == op_a - op_b);
	ALUOP_LT:  assert(result == $signed(op_a) < $signed(op_b));
	ALUOP_GE:  assert(result == $signed(op_a) >= $signed(op_b));
	ALUOP_LTU: assert(result == op_a < op_b);
	ALUOP_GEU: assert(result == op_a >= op_b);
	ALUOP_AND: assert(result == (op_a & op_b));
	ALUOP_OR:  assert(result == (op_a | op_b));
	ALUOP_XOR: assert(result == (op_a ^ op_b));
	ALUOP_SRL: assert(result == op_a >> op_b[4:0]);
	ALUOP_SRA: assert($signed(result) == $signed(op_a) >>> $signed(op_b[4:0]));
	ALUOP_SLL: assert(result == op_a << op_b[4:0]);
	endcase
end
`endif

endmodule