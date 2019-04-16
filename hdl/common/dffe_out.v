module dffe_out (
	input  wire clk,
	input  wire d,
	input  wire e,
	output wire q
);

`ifdef FPGA_ICE40

SB_IO #(
	.PIN_TYPE (6'b01_01_00),
	//            |  |  |
	//            |  |  \----- Registered input (and no clock!)
	//            |  \-------- Registered output
	//            \----------- Permanent output enable
	.PULLUP (1'b 0)
) buffer (
	.PACKAGE_PIN  (q),
	.OUTPUT_CLK   (clk),
	.CLOCK_ENABLE (e),
	.D_OUT_0      (d)
);

`else

reg q_r;
assign q = q_r;

always @ (posedge clk)
	if (e)
		q_r <= d;

`endif

endmodule
