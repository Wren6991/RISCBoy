/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2019 Luke Wren                                       *
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
// Explanation:
// The PPU has a high ratio between databus width and smallest pixel (32 : 1)
// It also needs to support a range of pow-2 sized pixels (16 -> 1)
// An obvious implementation is a register, same size as databus,
// with mux taps for shift by 16, shift by 8, shift by 4 etc.
//
// A more efficient implementation is:
// - A databus-sized register
// - The left half can be copied to right half
// - OR, the left half of the right half can be copied to the right half of the right half
// - So on, recursively
//
// i.e. we can copy [31:16] -> [15:0], OR [15:8] -> [7:0], OR [7:4] -> [3:0], and so on.
// This takes around 1/3 the LUTs of the obvious implementation, since the number of
// mux taps is exponentially distributed, with most flops having 1 or 0 taps.
//
// so if we want to shift by 8 bits each clock, we would do:
// - initial state   [31:24  23:16  15:8    7:0 ]
// - copy by 8       [31:24  23:16  15:8   15:8 ]
// - copy by 16      [31:24  23:16  31:24  23:16]
// - copy by 8       [31:24  23:16  31:24  31:24]
//
// Power consumed is also much lower than a shifter, not that we are worried.
// 


module riscboy_ppu_pixel_gearbox #(
	parameter W_DATA = 32,
	parameter W_PIX_MIN = 1,
	parameter W_PIX_MAX = 16,
	parameter SHAMT_MAX = $clog2(W_DATA / W_PIX_MIN), // let this default
	parameter W_SHAMT = $clog2(SHAMT_MAX + 1) // let this default
) (
	input  wire                 clk,
	input  wire                 rst_n,

	input  wire [W_DATA-1:0]    din,
	input  wire                 din_vld,
	input  wire [W_SHAMT-1:0]   shamt,
	output wire [W_PIX_MAX-1:0] dout
);

reg [W_DATA-1:0] sreg;
assign dout = sreg;

always @ (posedge clk or negedge rst_n) begin: shift
	integer i, j;
	integer shiftsize;
	if (!rst_n) begin
		sreg <= {W_DATA{1'b0}};
	end	else if (din_vld) begin
		sreg <= din;
	end else begin
		// This is more painful than it ought to be because some tools don't cope with loop iterator
		// used for width of indexed part select, even though the value is known at elaboration time
		for (i = 1; i <= SHAMT_MAX; i = i + 1) begin
			shiftsize = 1 << (i - 1);
			if (shamt == i) begin
				for (j = 0; j < W_DATA; j = j + 1)
					if (j < shiftsize)
						sreg[j] = sreg[j + shiftsize];
			end
		end
	end
end

// For the case of W_DATA = 32 the above would be equivalent to:
//
// case (shamt)
// 	3'h5: shifter[0 +: 16] <= shifter[16 +: 16];
// 	3'h4: shifter[0 +: 8 ] <= shifter[8  +: 8 ];
// 	3'h3: shifter[0 +: 4 ] <= shifter[4  +: 4 ];
// 	3'h2: shifter[0 +: 2 ] <= shifter[2  +: 2 ];
// 	3'h1: shifter[0 +: 1 ] <= shifter[1  +: 1 ];
// 	default: begin end
// endcase

endmodule
