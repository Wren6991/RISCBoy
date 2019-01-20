module tb;

localparam CLK_PERIOD = 20;

localparam RAM_BASE = 32'h2000_0000;
localparam RAM_SIZE_BYTES = 1 << 18;
localparam RAM_DEPTH = RAM_SIZE_BYTES / 4;
integer i;

reg clk;
reg rst_n;

wire [15:0] pads;

riscboy_core #(
	.BOOTRAM_PRELOAD("../ram_init32.hex")
) dut (
	.clk(clk),
	.rst_n(rst_n),
	.gpio(pads)
);

always #(CLK_PERIOD * 0.5) clk = !clk;

initial begin
	clk = 1'b0;
	rst_n = 1'b0;

	#(10 * CLK_PERIOD);
	rst_n = 1'b1;
end

behav_uart_rx #(
	.BAUD_RATE(115200.0),
	.BUF_SIZE(256)
) uart_rx (
	.rx(pads[15])
);

endmodule