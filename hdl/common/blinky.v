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
localparam W_CTR = $clog2(COUNT);
reg [W_CTR-1:0] ctr = {W_CTR{1'b0}};

generate
if (FANCY) begin: breathe
	localparam W_ACCUM = W_CTR > 8 ? 8 : W_CTR;

	reg rising = 1'b1;
	reg blink_r = 1'b0;
	reg [W_ACCUM-1:0] accum = {W_ACCUM{1'b0}};

	wire [W_CTR-1:0] ctr_next = rising ? ctr + 1'b1 : ctr - 1'b1;

	always @ (posedge clk) begin
		ctr <= ctr_next;
		if (rising && ctr_next == COUNT - 1)
			rising <= 1'b0;
		else if (!rising && ctr_next == 0)
			rising <= 1'b1;
		{blink_r, accum} <= accum + ctr[W_CTR-1 -: W_ACCUM];
	end

	assign blink = blink_r;
end else begin: blink

	reg blink_r = 1'b0;

	always @ (posedge clk) begin
		if (|ctr) begin
			ctr <= ctr - 1'b1;
		end else begin
			ctr <= COUNT - 1;
			blink_r <= !blink_r;
		end
	end

	assign blink = blink_r;
end
endgenerate

endmodule