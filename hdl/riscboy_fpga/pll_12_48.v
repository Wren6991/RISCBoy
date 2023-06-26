module pll_12_48 #(
    parameter ICE40_PAD = 0
) (
	input  clock_in,
	output clock_out,
	output locked
	);

`ifdef FPGA_ICE40

/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        12.000 MHz
 * Requested output frequency:   36.000 MHz
 * Achieved output frequency:    36.000 MHz
 */

generate
if (ICE40_PAD) begin: pll_pad

SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b0111111),	// DIVF = 63
		.DIVQ(3'b100),		// DIVQ =  4
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.PACKAGEPIN(clock_in),
		.PLLOUTCORE(clock_out)
		);

end else begin: pll_core

SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0000),     // DIVR =  0
        .DIVF(7'b0111111),  // DIVF = 63
        .DIVQ(3'b100),      // DIVQ =  4
        .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
    ) uut (
        .LOCK(locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .REFERENCECLK(clock_in),
        .PLLOUTCORE(clock_out)
        );

end
endgenerate

`else

$fatal("No PLL available for the current platform");

`endif

endmodule
