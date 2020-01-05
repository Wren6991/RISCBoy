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

 // A fully-synchronous Gray + binary dual up-counter

module gray_counter #(
	parameter W_CTR = 4
) (
	input  wire             clk,
	input  wire             rst_n,

	input  wire             en,
	input  wire             clr,
	output wire [W_CTR-1:0] count_bin,
	output wire [W_CTR-1:0] count_bin_next,
	output wire [W_CTR-1:0] count_gry
);

reg [W_CTR-1:0] ctr_bin;
(* keep = 1'b1 *)(* no_retiming = 1'b1 *) reg [W_CTR-1:0] ctr_gry;

assign count_bin = ctr_bin;
assign count_gry = ctr_gry;

assign count_bin_next = ctr_bin + 1'b1;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ctr_bin <= {W_CTR{1'b0}};
		ctr_gry <= {W_CTR{1'b0}};
	end else if (clr) begin
		ctr_bin <= {W_CTR{1'b0}};
		ctr_gry <= {W_CTR{1'b0}};
	end else if (en) begin
		ctr_bin <= count_bin_next;
		ctr_gry <= count_bin_next ^ (count_bin_next >> 1);
	end
end

endmodule
