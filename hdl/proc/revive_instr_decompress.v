module revive_instr_decompress #(
	parameter PASSTHROUGH = 1
) (
	input wire [31:0] instr_in,
	output reg instr_is_32bit,
	output reg [31:0] instr_out
);

generate
if (PASSTHROUGH) begin
	always @ (*) begin
		instr_is_32bit = 1'b1;
		instr_out[31:2] = instr_in[31:2];
		instr_out[1:0] = 2'b11;
	end
end else begin
	/*always @ (*) begin
		if (instr_in[1:0] == 2'b11) begin
			instr_is_32bit = 1'b1;
			instr_out = instr_in;
		end else begin
			casez (instr_in[15:0])
				RV_C_ADDI4SPN: begin
					
				end

		end
	end*/
end
endgenerate

endmodule