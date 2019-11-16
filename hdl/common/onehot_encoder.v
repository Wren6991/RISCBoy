// Encodes a one-hot vector at the input as a binary integer at the output.
// Results are invalid if the input is not one-hot or zero.
// (Perhaps filter input with a onehot_priority first, forming a priority encoder)

module onehot_encoder #(
	parameter W_INPUT = 8,
	parameter W_OUTPUT = $clog2(W_INPUT) // it's best to let this default
) (
	input  wire [W_INPUT-1:0]  in,
	output wire [W_OUTPUT-1:0] out
);

reg [W_OUTPUT-1:0] out_r;
assign out = out_r;

always @ (*) begin: encode
	reg [W_OUTPUT:0] i;
	out_r = {W_OUTPUT{1'b0}};
	for (i = 0; i < W_INPUT; i = i + 1)
		if (in[i])
			out_r = out_r | i[W_OUTPUT-1:0];
end

endmodule

