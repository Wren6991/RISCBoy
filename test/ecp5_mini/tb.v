module tb;

localparam CLK_PERIOD = 10.0;

reg clk_osc = 0;
wire [7:0] led;

always #(0.5 * CLK_PERIOD) clk_osc = !clk_osc;

riscboy_fpga #(
	.PRELOAD_FILE ("../bootram_init32.hex")
) dut (
	.clk_osc (clk_osc),
	.led     (led)
);

endmodule
