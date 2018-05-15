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

// Convert an AHB master performing possibly unaligned accesses
// to a master performing (possibly multiple) naturally-aligned accesses.
// The RISC-V ISA permits unaligned accesses, but AHB does not. Inserting this 
// module inline on the bus is simpler than working this logic into the pipeline.

// Byte transfers: always aligned
//
// Halfword transfers:
// addr % 2 == 0:
//  -> aligned
// addr % 2 == 1:
//  -> byte transfer to addr, byte transfer to addr + 1
//
// Word transfers:
// addr % 4 == 0:
//  -> aligned
// addr % 4 == 1:
// -> byte transfer to addr
// -> halfword transfer to addr + 1
// -> byte transfer to addr + 3
// addr % 4 == 2:
// -> halfword transfer to addr
// -> halfword transfer to addr + 2
// addr % 4 == 3:
// -> byte transfer to addr
// -> halfword transfer to addr + 1
// -> byte transfer to addr + 3

module ahbl_align32 #(
	localparam W_ADDR = 32,
	localparam W_DATA = 32
) (
	// Global signals
	input wire               clk,
	input wire               rst_n,

	// Slave port
	input  wire              abhls_hready,
	output wire              ahbls_hready_resp,
	output wire              ahbls_hresp,
	input  wire [W_ADDR-1:0] ahbls_haddr,
	input  wire              ahbls_hwrite,
	input  wire [1:0]        ahbls_htrans,
	input  wire [2:0]        ahbls_hsize,
	input  wire [2:0]        ahbls_hburst,
	input  wire [3:0]        ahbls_hprot,
	input  wire              ahbls_hmastlock,
	input  wire [W_DATA-1:0] ahbls_hwdata,
	output wire [W_DATA-1:0] ahbls_hrdata,

	// Master port
	output wire              abhlm_hready,
	input  wire              ahblm_hready_resp,
	input  wire              ahblm_hresp,
	output wire [W_ADDR-1:0] ahblm_haddr,
	output wire              ahblm_hwrite,
	output wire [1:0]        ahblm_htrans,
	output wire [2:0]        ahblm_hsize,
	output wire [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	output wire [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata
);

localparam HTRANS_IDLE = 2'b00;
localparam HTRANS_NSEQ = 2'b10;

localparam HSIZE_BYTE  = 3'b000;
localparam HSIZE_HWORD = 3'b001;
localparam HSIZE_WORD  = 3'b010;

localparam STATE_IDLE   = 3'h0;
localparam STATE_BYTE0  = 3'h1;
localparam STATE_HWORD0 = 3'h2;
localparam STATE_HWORD1 = 3'h3;
localparam STATE_WORD0  = 3'h4;
localparam STATE_WORD1  = 3'h5;
localparam STATE_WORD2  = 3'h6;

/*wire last_trans =
	 STATE == STATE_BYTE0                   ||
	(STATE == STATE_HWORD0 && !haddr_d[0])  ||
	 STATE == STATE_HWORD1                  ||
	(STATE == STATE_WORD0 && !haddr_d[1:0]) ||
	(STATE == STATE_WORD1 && !haddr_d[0])   ||
	 STATE == STATE_WORD2;
*/


endmodule