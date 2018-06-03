// Radix-2 multiplier, based on Karatsuba method
// May cause your synthesis tool to shit a brick

module radix2_mult #(
	parameter W = 32
) (
	input wire [W-1:0] a,
	input wire [W-1:0] b,
	output reg [W*2-1:0] out
);

generate
if (W <= 4) begin
	always @ (*) begin
		out = a * b;
	end
end else if (W % 2) begin: odd
	wire [W-2:0] pp0;
	wire [W+2:0] pp1;
	wire [W+0:0] pp2;

	radix2_mult #(.W(W / 2)) mult0
	(
		.a      (a[0 +: W/2]),
		.b      (b[0 +: W/2]),
		.out    (pp0)
	);
	radix2_mult #(.W(W / 2 + 1)) mult1
	(
		.a      ({2'b00, a[0 +: W/2]} + a[W/2 +: W/2 + 1]),
		.b      ({2'b00, b[0 +: W/2]} + b[W/2 +: W/2 + 1]),
		.out    (pp1)
	);
	radix2_mult #(.W(W / 2 + 1)) mult2
	(
		.a      (a[W/2 +: W/2 + 1]),
		.b      (b[W/2 +: W/2 + 1]),
		.out    (pp2)
	);
	always @ (*) begin
		out = pp0 + (pp1 - pp0 - pp2 << W/2) + (pp2 << W - 1);
	end
end else begin: even
	wire [W-1:0] pp0;
	wire [W+1:0] pp1;
	wire [W-1:0] pp2;

	radix2_mult #(.W(W / 2)) mult0
	(
		.a      (a[ 0  +: W/2]),
		.b      (b[ 0  +: W/2]),
		.out    (pp0)
	);
	radix2_mult #(.W(W / 2)) mult1
	(
		.a      (a[ 0  +: W/2] + a[W/2 +: W/2]),
		.b      (b[ 0  +: W/2] + b[W/2 +: W/2]),
		.out    (pp1)
	);
	radix2_mult #(.W(W / 2)) mult2
	(
		.a      (a[W/2 +: W/2]),
		.b      (b[W/2 +: W/2]),
		.out    (pp2)
	);

	always @ (*) begin
		out = pp0 + (pp1 - pp0 - pp2 << W/2) + (pp2 << W);
	end
end
endgenerate

endmodule