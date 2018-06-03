module wallace_adder #(
	parameter W = 32, // valid for W >= 1
	parameter N = 2   // valid for N >= 2
) (
	input  wire [W*N-1:0] in,
	output wire [W-1:0]   out
);

generate
if (N == 2) begin: base
	assign out = in[0 +: W] + in[W +: W];
end else begin: recurse
	localparam N_NEXT = N / 3 * 2 + N % 3;
	integer i;

	reg [N_NEXT*W-1:0] psum;

	wallace_adder #(
		.W(W),
		.N(N_NEXT)
	) wadd (
		.in(psum),
		.out(out)
	);

	always @ (*) begin
		for (i = 0; i < N; i = i + 3) begin
			if (N - i >= 3) begin
				psum[(i / 3 * 2 + 0) * W +: W] = in[(i + 0) * W +: W] ^ in[(i + 1) * W +: W] ^ in[(i + 2) * W +: W];
				psum[(i / 3 * 2 + 1) * W +: W] = (
					(in[(i + 0) * W +: W] & in[(i + 1) * W +: W]) |
					(in[(i + 1) * W +: W] & in[(i + 2) * W +: W]) |
					(in[(i + 2) * W +: W] & in[(i + 0) * W +: W])) << 1;
			end else if (N - i == 2) begin
				psum[i / 3 * 2 * W +: 2 * W] = in[i * W +: 2 * W];
			end else begin
				psum[i / 3 * 2 * W +: W] = in[i * W +: W];
			end
		end
	end
end
endgenerate

endmodule