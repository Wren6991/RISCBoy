module blinky #(
	parameter CLK_HZ = 12_000_000,
	parameter BLINK_HZ = 1
) (
	input wire clk,
	output wire blink
);

localparam COUNT = CLK_HZ / BLINK_HZ / 2;
localparam W_CTR = $clog2(COUNT);

reg [W_CTR-1:0] ctr = {W_CTR{1'b0}};
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

endmodule