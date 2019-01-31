// FPGA heartbeat light
// (hence lack of reset!)

module blinky #(
	parameter CLK_HZ = 12_000_000,
	parameter BLINK_HZ = 1,
	parameter FANCY = 0
) (
	input wire clk,
	output wire blink
);

localparam COUNT = CLK_HZ / BLINK_HZ / 2;
parameter W_CTR = $clog2(COUNT);
reg [W_CTR-1:0] ctr = {W_CTR{1'b0}};

reg blink_r = 1'b0;
assign blink = blink_r;

generate
if (FANCY) begin: breathe
	localparam W_ACCUM = W_CTR > 8 ? 8 : W_CTR;

	reg rising = 1'b1;
	reg [W_ACCUM-1:0] accum = {W_ACCUM{1'b0}};

	wire [W_CTR-1:0] ctr_next = rising ? ctr + 1'b1 : ctr - 1'b1;
	wire [W_ACCUM-1:0] brightness_linear = ctr[W_CTR-1 -: W_ACCUM];
	wire [2*W_ACCUM-1:0] brightness_sq = brightness_linear * brightness_linear;

	always @ (posedge clk) begin
		ctr <= ctr_next;
		if (rising && ctr_next == COUNT - 1)
			rising <= 1'b0;
		else if (!rising && ctr_next == 0)
			rising <= 1'b1;
		{blink_r, accum} <= accum + brightness_sq[W_ACCUM +: W_ACCUM];
	end
end else begin: flash
	always @ (posedge clk) begin
		if (|ctr) begin
			ctr <= ctr - 1'b1;
		end else begin
			ctr <= COUNT - 1;
			blink_r <= !blink_r;
		end
	end
end
endgenerate

endmodule