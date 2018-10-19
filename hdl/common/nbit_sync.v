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

// N-bit synchroniser

// Shepherd a multibit signal safely between two clock domains, with some delay.
// Uses valid/ack handshake (aka 2-bit Gray counter, 1 bit per clock domain)
// Both clocks must be free-running!

module nbit_sync #(
	parameter W_DATA = 32,
	parameter SYNC_STAGES = 1 // must be >= 1
) (
	input wire              wrst_n,
	input wire              wclk,
	input wire [W_DATA-1:0] wdata,

	input wire              rrst_n,
	input wire              rclk,
	output reg [W_DATA-1:0] rdata
);

reg                   wvalid;    // Data valid, driven in W
reg [SYNC_STAGES-1:0] wack;      // Data acknowledge, sync'd
reg [SYNC_STAGES-1:0] rvalid;    // Data valid, sync'd
reg                   rack;      // Data acknowledge, driven in R
reg [W_DATA-1:0]      cross_reg; // The signal being synchronised

// Write state machine

always @ (posedge wclk or negedge wrst_n) begin
	if (!wrst_n) begin
		wvalid <= 1'b0;
		wack <= {SYNC_STAGES{1'b0}};
		cross_reg <= {W_DATA{1'b0}};
	end else begin
		wack <= (wack >> 1) | (rack << SYNC_STAGES - 1);
		if (wvalid && wack[0]) begin
			wvalid <= 1'b0;
		end else if (!wvalid && !wack[0]) begin
			wvalid <= 1'b1;
			cross_reg <= wdata;
		end
	end
end

// Read state machine

always @ (posedge rclk or negedge rrst_n) begin
	if (!rrst_n) begin
		rvalid <= {SYNC_STAGES{1'b0}};
		rack <= 1'b0;
		rdata <= {W_DATA{1'b0}};
	end else begin
		rvalid <= (rvalid >> 1 ) | (wvalid << SYNC_STAGES - 1);
		if (rack && !rvalid[0]) begin
			rack <= 1'b0;
		end else if (rvalid[0] && !rack) begin
			rack <= 1'b0;
			rdata <= cross_reg;
		end
	end
end

endmodule