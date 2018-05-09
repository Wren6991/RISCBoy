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

module revive_alu (
	input  wire [3:0]  aluop,
	input  wire [31:0] op_a,
	input  wire [31:0] op_b,
	output reg  [31:0] result,
	output reg         zero
);

`include "alu_ops.vh"

wire [31:0] sum  = op_a + op_b;
wire [31:0] diff = op_a - op_b;

wire [63:0] op_a_sext = {{32{op_a[31]}}, op_a};
wire [63:0] op_a_zext = {32'h0, op_a};
wire [4:0] shamt = op_b[4:0];

always @ (*) begin
	case (aluop)
		ALUOP_ADD: begin result = sum; end
		ALUOP_SUB: begin result = diff; end
		ALUOP_LT:  begin result = diff[31] + 32'h0; end
		ALUOP_GE:  begin result = !diff[31] + 32'h0; end
		ALUOP_LTU: begin result = op_a < op_b; end
		ALUOP_GEU: begin result = op_a >= op_b; end
		ALUOP_AND: begin result = op_a & op_b; end
		ALUOP_OR:  begin result = op_a | op_b; end
		ALUOP_XOR: begin result = op_a ^ op_b; end
		ALUOP_SRL: begin result = op_a_zext[shamt +: 32]; end
		ALUOP_SRA: begin result = op_a_sext[shamt +: 32]; end
		ALUOP_SLL: begin result = op_a << shamt; end
	endcase
	zero = !result;
end

endmodule