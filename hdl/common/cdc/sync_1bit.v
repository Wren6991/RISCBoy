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

// A standard 2FF synchronizer; used to mitigate metastabilities as part
// of more-comprehensive async handshakes.
// The implementation provided here is... ok... but you should use
// this wrapper to inject your own FPGA- or library-specific cells.

 module sync_1bit #(
	parameter N_STAGES = 2 // Should be >=2
) (
	input wire clk,
	input wire rst_n,
	input wire i,
	output wire o
);

(* keep = 1'b1 *) reg [N_STAGES-1:0] sync_flops;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		sync_flops <= {N_STAGES{1'b0}};
	else
		sync_flops <= {sync_flops[N_STAGES-2:0], i};

assign o = sync_flops[N_STAGES-1];

endmodule
