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

	input  wire               en,
	input  wire               clr,

	input  wire [W_COORD-1:0] w,
	input  wire [W_COORD-1:0] h,
	output reg  [W_COORD-1:0] x,
	output reg  [W_COORD-1:0] y,

	output reg                start_row,
	output reg                start_frame
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		x <= {W_COORD{1'b0}};
		y <= {W_COORD{1'b0}};
	end else if (clr) begin
		x <= {W_COORD{1'b0}};
		y <= {W_COORD{1'b0}};
	end else if (en) begin
		if (x == w) begin
			x <= {W_COORD{1'b0}};
			if (y == h)
				y <= {W_COORD{1'b0}};
			else
				y <= y + 1'b1;
		end else begin
			x <= x + 1'b1;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		start_row <= 1'b0;
		start_frame <= 1'b0;
	end else if (clr || !en) begin
		start_row <= 1'b0;
		start_frame <= 1'b0;
	end else begin
		start_frame <= x == w && y == h;
		start_row <= x == w;				
	end
end

endmodule
