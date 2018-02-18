module revive_instr_decompress (
	input wire [31:0] instr_in,
	output wire instr_is_32bit,
	output wire [31:2] instr_out
);

assign instr_out = instr_in[31:2];
assign instr_is_32bit = 1'b1;