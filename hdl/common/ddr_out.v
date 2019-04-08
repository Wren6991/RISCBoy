// Timing:
// d_rise, d_fall are both sampled on the same rising clk edge.
// d_rise goes straight to the pad, and d_fall follows a half-cycle later.
// oe determines output enable for entire following clock cycle.

module ddr_out (
	input wire clk,
	input wire rst_n,

	input wire d_rise,
	input wire d_fall,
	output reg q
)

`ifdef DDROUT_ICE40

reg d_fall_r;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		d_fall_r <= 1'b0;
	else
		d_fall_r <= d_fall;

SB_IO #(
	.PIN_TYPE(6'b01_00_00),
	//           |  |  |
	//           |  |  \----- Registered input (save a little power as unused)
	//           |  \-------- DDR output
	//           \----------- Permanent output enable
	.PULLUP(1'b 0)
) buffer (
	.PACKAGE_PIN(q),
	.D_OUT_0(d_rise),
	.D_OUT_1(d_fall_r)
);


`else

// Note blocking assignment to intermediates
reg q0, q1;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		{q0, q1} = 2'd0;
	else
		{q0, q1} = d_rise, d_fall;

// Note nonblocking assignment to output
always @ (*)
	q <= clk ? q0 : q1;

`endif