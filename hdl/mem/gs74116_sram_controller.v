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

//
// SRAM controller for GS74116AGP SRAM (and similar)
//
// Truth table from datasheet
//
// -----+------+------+------+------+---------+---------
// CE_n | OE_n | WE_n | LB_n | UB_n | DQ[7:0] | DQ[15:8]
// -----+------+------+------+------+---------+---------
//   1  |  X   |  X   |  X   |  X   | Hi-Z    | Hi-Z
// -----+------+------+------+------+---------+---------
//   0  |  0   |  1   |  0   |  0   | Read    | Read
//   0  |  0   |  1   |  1   |  0   | Hi-Z    | Read
//   0  |  0   |  1   |  0   |  1   | Read    | Hi-Z
// -----+------+------+------+------+---------+---------
//   0  |  X   |  0   |  0   |  0   | Write   | Write
//   0  |  X   |  0   |  1   |  0   | Hi-Z    | Write
//   0  |  X   |  0   |  0   |  1   | Write   | Hi-Z
// -----+------+------+------+------+---------+---------
//   0  |  1   |  1   |  X   |  X   | Hi-Z    | Hi-Z
//   0  |  X   |  X   |  1   |  1   | Hi-Z    | Hi-Z
//
// Read timing: assert address, CE, OE and byte enables, and wait for 10 ns
// Write timing: assert address, CE, byte enables, data. Wait 3 ns. 
//  Assert WE. Wait 7 ns.
// Data sampled by SRAM on rising edge (deassertion; active low!)
// This is not really achievable, so we use a DDR output to attain a 50/50 duty cycle on WE,
// which does limit our max speed to around 70MHz instead of 100 MHz.

module gs74116_sram_controller #(
	localparam W_DATA = 32,
	localparam W_ADDR = 32,
	localparam SRAM_W_DATA = 16,
	parameter SRAM_W_ADDR = 18
) (
	// Globals
	input wire clk,
	input wire rst_n,

	// AHB lite slave interface
	output reg                      ahbls_hready_resp,
	output wire                     ahbls_hresp,
	input wire [W_ADDR-1:0]         ahbls_haddr,
	input wire                      ahbls_hwrite,
	input wire [1:0]                ahbls_htrans,
	input wire [2:0]                ahbls_hsize,
	input wire [2:0]                ahbls_hburst,
	input wire [3:0]                ahbls_hprot,
	input wire                      ahbls_hmastlock,
	input wire [W_DATA-1:0]         ahbls_hwdata,
	output wire [W_DATA-1:0]        ahbls_hrdata,

	// SRAM interface
	output reg [SRAM_W_ADDR-1:0]    sram_addr,
	inout wire [SRAM_W_DATA-1:0]    sram_dq,
	output reg                      sram_ce_n,
	output reg                      sram_oe_n,
	output reg                      sram_we_n,
	output reg                      sram_ub_n,
	output reg                      sram_lb_n
);
/*

// EVERYTHING IS FINE STOP ASKING
assign ahbls_hresp = 1'b0;

localparam STATE_IDLE  = 2'h0;
localparam STATE_READ  = 2'h1;
localparam STATE_WRITE = 2'h2;
reg [1:0] state;
reg [3:0] byte_enables;

reg [W_DATA-W_SRAM_DATA-1:0] read_buffer;
wire [SRAM_W_ADDR-1:0] addr_word_aligned = {ahbls_haddr[SRAM_W_ADDR-1:2], 2'b00};

// Operations will complete in one cycle, if they do not span multiple halfwords
assign ahbs_hready_resp = !(byte_enables[3:2] && byte_enables[1:0]);

// ==================
// SRAM control logic
// ==================

always @ (*) begin
	// Defaults to help protect from latch inference
	sram_dq = {SRAM_W_DATA{1'bZ}};
	{sram_ub_n, sram_lb_n} = 2'b11;

	if (state == STATE_IDLE) begin
		sram_addr = {W_SRAM_DATA{1'b0}};
	end else begin
		if (byte_enables[3:2]) begin
			if (state == STATE_WRITE) begin
				sram_dq = ahbs_hwdata[31:16];
			end
			sram_addr = addr_word_aligned + 2'b10;
			{sram_ub_n, sram_lb_n} = ~byte_enables[3:2];
		end else begin
			if (state == STATE_WRITE) begin
				sram_dq = ahbs_hwdata[15:0];
			end
			sram_addr = addr_word_aligned;
			{sram_ub_n, sram_lb_n} = ~byte_enables[1:0];
		end
	end

	if (ahbls_hready && state != STATE_IDLE) begin
		if (byte_enables[3:2]) begin
			ahbs_hrdata = {sram_dq, 16'h0000};
		end else begin
			ahbs_hrdata = {read_buffer, sram_dq};
		end
	end else begin
		ahbs_hrdata = {32{1'b0}};
	end

	sram_oe_n = state != STATE_READ;
	sram_ce_n = 1'b0;
	// Clock as a combinational input: what's the worst that could happen?
	// TODO: make this a DDR output flop, in a portable way
	sram_we_n = clk ? 1'b1 : state != STATE_WRITE;
end

// ==================
// AHBL state machine
// ==================

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		read_buffer <= {(W_DATA - SRAM_W_DATA){1'b0}};
		state <= STATE_IDLE;
	end else begin
		if (byte_enables[3:2]) begin
			byte_enables[3:2] <= 2'b00;
			if (state == STATE_READ) begin
				read_buffer <= sram_dq;
			end
		end else begin
			byte_enables[1:0] <= 2'b00;
		end
		if (ahbls_hready_resp) begin
			if (ahbls_htrans[1]) begin
				state <= ahbls_hwrite ? STATE_WRITE : STATE_READ;
				case (ahbls_hsize)
				3'h0: begin
					byte_enables <= (1 << ahbls_haddr[1:0]);
				end
				3'h1: begin
					// All AHB transfers are naturally-aligned
					byte_enables <= ahbls_haddr[1] ? 4'b1100 : 4'b0011;
				end
				default: begin
					byte_enables <= 4'b1111;
				end
				endcase
			end else begin
				state <= STATE_IDLE;
			end
		end
	end
end
*/
endmodule