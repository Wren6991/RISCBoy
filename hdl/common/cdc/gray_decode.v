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

 module gray_decode #(
 	parameter N = 4
 ) (
 	input  wire [N-1:0] i,
 	output reg  [N-1:0] o
 );

always @ (*) begin: decode
	integer j;
	o[N-1] = i[N-1];
	for (j = N - 2; j >= 0; j = j - 1)
		o[j] = i[j] ^ o[j + 1];
end

endmodule
