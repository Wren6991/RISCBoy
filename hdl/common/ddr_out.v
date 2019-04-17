// Timing:
// d_rise, d_fall are both sampled on the same rising clk edge.
// d_rise goes straight to the pad, and d_fall follows a half-cycle later.
// oe determines output enable for entire following clock cycle.

module ddr_out (
	input wire clk,
	input wire rst_n,

	input wire d_rise,
	input wire d_fall,
	input wire e,
	output reg q
);

`ifdef FPGA_ICE40

reg d_fall_r;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		d_fall_r <= 1'b0;
	else
		d_fall_r <= d_fall;

SB_IO #(
	.PIN_TYPE (6'b01_00_00),
	//            |  |  |
	//            |  |  \----- Registered input (and no clock!)
	//            |  \-------- DDR output
	//            \----------- Permanent output enable
	.PULLUP (1'b 0)
) buffer (
	.PACKAGE_PIN  (q),
	.OUTPUT_CLK   (clk),
	.CLOCK_ENABLE (e),
	.D_OUT_0      (d_rise),
	.D_OUT_1      (d_fall_r)
);

`else

// Blocking to intermediates, nonblocking to outputs
// to avoid simulation issues
reg q0, q1;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		{q0, q1} = 2'd0;
	else if (e === 1'b1 || e === 1'bz) // Cell enabled if disconnected (iCE40)
		{q0, q1} = {d_rise, d_fall};

always @ (*)
	q <= clk ? q0 : q1;

`endif

endmodule
