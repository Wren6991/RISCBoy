// Yosys/arachne have issues with tristate inference.
// Use this wrapper to instantiate an IO block directly.

module tristate_io (
	input wire out,
	input wire oe,
	output wire in,
	inout wire pad
);

`ifdef TRISTATE_ICE40

SB_IO #(
    .PIN_TYPE (6'b1010_01),
    .PULLUP   (1'b0)
) buffer (
    .PACKAGE_PIN   (pad),
    .OUTPUT_ENABLE (oe),
    .D_OUT_0       (out),
    .D_IN_0        (in)
);

`else

assign pad = oe ? out : 1'bz;
assign in = pad;

`endif

endmodule