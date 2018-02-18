module revive_instr_decompress (
	input wire [31:0] instr_in,
	output wire instr_is_32bit,
	output wire [31:2] instr_out
);

