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

// Common AHB master testbench tasks

// The params/localparams W_ADDR and W_DATA must be defined before including this file.
// They are the width of the AHB address and data bus, respectively.
//
// You must also declare global regs/wires with names:
//
// reg               clk;
// wire              ahbl_hready;
// wire              ahbl_hresp;
// reg  [W_ADDR-1:0] ahbl_haddr;
// reg               ahbl_hwrite;
// reg  [1:0]        ahbl_htrans;
// reg  [2:0]        ahbl_hsize;
// reg  [2:0]        ahbl_hburst; 
// reg  [3:0]        ahbl_hprot;
// reg               ahbl_hmastlock;
// reg  [W_DATA-1:0] ahbl_hwdata;
// wire [W_DATA-1:0] ahbl_hrdata;
//
// (Can just copy/paste this declaration block)
// Unfortunately these can't be passed to the tasks as inputs/outputs,
// as Verilog (or at least ISIM) only updates inputs once, on task entry,
// and only asserts outputs once, on task exit. Globals it is then!

// TODO: any way to have overlapping address/data phase?

localparam HTRANS_IDLE = 2'b00;
localparam HTRANS_NSEQ = 2'b10;


task ahb_wait_ready;
begin
	@ (posedge clk);
	while (!ahbl_hready) begin
		@ (posedge clk);
	end
end
endtask

task ahb_addr_phase;
	input               hwrite;
	input [W_ADDR-1:0] haddr;
	input [2:0]        hsize;
begin
	ahbl_hwrite = hwrite;
	ahbl_haddr = haddr;
	ahbl_hsize = hsize;
	ahbl_htrans = HTRANS_NSEQ;

	ahb_wait_ready();

	ahbl_htrans = HTRANS_IDLE;
	ahbl_haddr = 0;
end
endtask


task ahb_write_byte;
	input [7:0]        wdata;
	input [W_ADDR-1:0] waddr;
begin
	ahb_addr_phase(1'b1, waddr, 3'b000);
	ahbl_hwdata = {(W_DATA / 8){wdata}};
	ahb_wait_ready();
end
endtask

task ahb_write_halfword;
	input [15:0]       wdata;
	input [W_ADDR-1:0] waddr;
begin
	ahb_addr_phase(1'b1, waddr, 3'b001);
	ahbl_hwdata = {(W_DATA / 16){wdata}};
	ahb_wait_ready();
end
endtask

task ahb_write_word;
	input [31:0]       wdata;
	input [W_ADDR-1:0] waddr;
begin
	ahb_addr_phase(1'b1, waddr, 3'b010);
	ahbl_hwdata = {(W_DATA / 32){wdata}};
	ahb_wait_ready();
end
endtask

task ahb_read_byte;
	output [7:0]        rdata;
	input  [W_ADDR-1:0] raddr;
begin
	ahb_addr_phase(1'b0, raddr, 3'b000);
	ahb_wait_ready();
	rdata = ahbl_hrdata[raddr[$clog2(W_DATA)-4:0] * 8 +: 8];
end
endtask

task ahb_read_halfword;
	output [15:0]       rdata;
	input  [W_ADDR-1:0] raddr;
begin
	ahb_addr_phase(1'b0, raddr, 3'b001);
	ahb_wait_ready();
	rdata = ahbl_hrdata[raddr[$clog2(W_DATA)-4:1] * 16 +: 16];
end
endtask

task ahb_read_word;
	output [31:0]       rdata;
	input  [W_ADDR-1:0] raddr;
begin
	ahb_addr_phase(1'b0, raddr, 3'b010);
	ahb_wait_ready();
	if (W_DATA > 32) begin
		rdata = ahbl_hrdata[raddr[$clog2(W_DATA)-4:2] * 32 +: 32];
	end else begin
		rdata = ahbl_hrdata;
	end
end
endtask
