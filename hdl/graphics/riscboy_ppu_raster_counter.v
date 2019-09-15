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

 module riscboy_ppu_raster_counter #(
	parameter W_COORD = 12
) (
	input  wire               clk,
	input  wire               rst_n,

	input  wire               e,
	input  wire               clr,
	input  wire               halt,

	input  wire [W_COORD-1:0] w,
	input  wire [W_COORD-1:0] h,
	output reg  [W_COORD-1:0] x,
	output reg  [W_COORD-1:0] y,

	output reg                halted,
	input  wire               resume
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		x <= {W_COORD{1'b0}};
		y <= {W_COORD{1'b0}};
		halted <= 1'b0;
	end else if (clr) begin
		x <= {W_COORD{1'b0}};
		y <= {W_COORD{1'b0}};
		halted <= 1'b0;
	end else if (halt) begin
		halted <= 1'b1;		
	end else if (e && !halted) begin
		if (x == w) begin
			x <= {W_COORD{1'b0}};
			if (y == h) begin
				y <= {W_COORD{1'b0}}
				halted <= 1'b1;
			end else begin
				y <= y + 1'b1;
			end
		end else begin
			x <= x + 1'b1;
		end
	end else if (resume) begin
		halted <= 1'b0;
	end
end

endmodule
