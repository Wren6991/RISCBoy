module pullup_input #(
	parameter INVERT = 1
) (
	output wire in,
	inout wire pad
);

`ifdef PULLUP_ICE40

wire padin;
assign in = padin ^ INVERT;

SB_IO #(
	.PIN_TYPE(6'b00_00_01),
	//           |  |  |
	//           |  |  \----- Unregistered input
	//           |  \-------- Registered output (don't care)
	//           \----------- Permanent output disable
	.PULLUP(1'b1)
) buffer (
	.PACKAGE_PIN (pad),
	.D_IN_0      (padin)
);

`else

assign (pull0, pull1) pad = 1'b1;
assign in = pad ^ INVERT;

`endif

endmodule