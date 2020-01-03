/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2018 Luke Wren                                       *
 *                                                                    *
 * Everyone is permitted to copy and distribute verbatim or modified  *
 * copies of this license document and accompanying software, and     *
 * changing either is allowed.                                        *
 *                                                                    *
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION  *
 *                                                                    *
 * 0. You just DO WHAT THE FUCK YOU WANT TO.                          *
 * 1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.             *
 *                                                                    *
 *********************************************************************/

// Simple serial display "controller" for PPU.
// Two jobs:
// - Shift out a continously-clocked stream of pixel data from the FIFO,
//   for screen update
// - Shift out individual bytes from the FIFO, for control purposes

module riscboy_ppu_dispctrl #(
	parameter W_DATA  = 16,
	parameter W_SHAMT = $clog2(W_DATA + 1) // do not modify
) (
	input  wire               clk,
	input  wire               rst_n,

	input  wire               pxfifo_vld,
	output wire               pxfifo_rdy,
	input  wire [W_DATA-1:0]  pxfifo_rdata,
	// How many bits to shift from this pxfifo word before moving on. Generally
	// either 8 or W_DATA:
	input  wire               pxfifo_shiftcount,

    // Goes low when the output shifter completely empties
    // Software uses this flag in conjunction with pxfifo empty to check
    // when it is safe to toggle CSn and D/C, or modify shiftcount
	output wire               tx_busy,

	output wire               lcd_sck,
	output wire               lcd_mosi
);

reg [W_DATA-1:0]  shift;
reg [W_SHAMT-1:0] shift_ctr;

assign pxfifo_rdy = ~|(shift_ctr[W_SHAMT-1:1]);
assign tx_busy = |shift_ctr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		shift <= {W_DATA{1'b0}};
		shift_ctr <= {W_SHAMT{1'b0}};
	end else begin
		shift_ctr <= shift_ctr - |shift_ctr;
		shift <= shift << 1;
		if (pxfifo_vld && pxfifo_rdy) begin
			shift <= pxfifo_rdata;
			shift_ctr[W_SHAMT-1:W_SHAMT-2] <= {pxfifo_shiftcount, !pxfifo_shiftcount};
		end
	end
end

ddr_out sck_ddr (
	.clk    (clk),
	.rst_n  (rst_n),

	.d_rise (1'b0),
	.d_fall (tx_busy),
	.e      (1'b1),
	.q      (lcd_sck)
);

dffe_out mosi_dffe (
	.clk (clk),
	.d   (shift[W_DATA - 1]),
	.e   (1'b1),
	.q   (lcd_mosi)
);

endmodule
