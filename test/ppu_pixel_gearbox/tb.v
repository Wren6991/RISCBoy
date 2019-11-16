module tb;

// ----------------------------------------------------------------------------
// DUT

localparam CLK_PERIOD = 10.0;

localparam W_DATA = 32;
localparam W_PIX_MIN = 1;
localparam W_PIX_MAX = 16;

reg                  clk;
reg                  rst_n;

reg  [W_DATA-1:0]    din;
reg                  din_vld;
reg  [2:0]           shamt;

wire [W_PIX_MAX-1:0] dout;

ppu_pixel_gearbox #(
	.W_DATA(W_DATA),
	.W_PIX_MIN(W_PIX_MIN),
	.W_PIX_MAX(W_PIX_MAX)
) inst_ppu_pixel_gearbox (
	.clk     (clk),
	.rst_n   (rst_n),
	.din     (din),
	.din_vld (din_vld),
	.shamt   (shamt),
	.dout    (dout)
);

// ----------------------------------------------------------------------------
// Stimulus

always #(0.5 * CLK_PERIOD) clk = !clk;

integer rep, i;

reg [4:0] shift_ctr;
reg [4:0] shift_ctr_next;
reg [31:0] shift_expect;

wire [2:0] shamt_encode;

onehot_encoder #(
	.W_INPUT(5)
) encoder_u (
	.in  (shift_ctr_next & ~shift_ctr),
	.out (shamt_encode)
);

initial begin
	clk = 1'b0;
	rst_n = 1'b0;
	din = {W_DATA{1'b0}};
	din_vld = 1'b0;
	shamt = 3'h0;

	#(5 * CLK_PERIOD);
	rst_n = 1'b1;

	@ (posedge clk);
	din_vld <= 1'b1;
	@ (posedge clk);
	din_vld <= 1'b0;
	@ (posedge clk);

	if (!(dout === {W_PIX_MAX{1'b0}})) begin
		$display("Sanity check fail");
		$finish;
	end

	for (rep = 0; rep < 10; rep = rep + 1) begin
		@ (posedge clk);
		shift_expect = $random;
		shift_ctr = 0;
		shift_ctr_next = 1;
		din <= shift_expect;
		din_vld <= 1'b1;
		@ (posedge clk);
		din_vld <= 1'b0;
		@ (posedge clk);
		for (i = 0; i < W_DATA; i = i + 1) begin
			if (!(dout[0] === shift_expect[0])) begin
				$display("Fail, i = %d", i);
				$finish;
			end
			shift_ctr_next <= shift_ctr_next + 1'b1;
			shift_ctr <= shift_ctr_next;
			shamt <= shamt_encode + 1'b1;
			@ (posedge clk);
			shamt <= 0;
			shift_expect <= shift_expect >> 1;
			@ (posedge clk);
		end
	end

	$display("Test PASSED.");
	$finish;
end

endmodule
