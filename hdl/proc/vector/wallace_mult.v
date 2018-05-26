module wallace_mult #(
	parameter W = 32
) (
	input wire            sext_a,
	input wire            sext_b,
	input wire  [W-1:0]   a,
	input wire  [W-1:0]   b,
	output wire [W*2-1:0] out
);


reg [W*W*2-1:0] pprod_noinv;
reg [W*W*2-1:0] pprod;
integer i;

always @ (*) begin
	for (i = 0; i < W; i = i + 1) begin
		pprod_noinv[i * W * 2 +: W * 2] = ({2*W{b[i]}} & {{W{sext_a && a[W-1]}}, a}) << i;
		if (sext_b && i == W - 1) begin
			pprod[i * W * 2 +: W * 2] = -pprod_noinv[i * W * 2 +: W * 2];
		end else begin
			pprod[i * W * 2 +: W * 2] =  pprod_noinv[i * W * 2 +: W * 2];
		end
	end
end

wallace_adder #(
	.W(W * 2),
	.N(W)
) add0 (
	.in(pprod),
	.out(out)
);

endmodule
