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

 // AHB-lite to synchronous SRAM adapter with no wait states.
 // Uses a write buffer with a write-to-read forwarding path
 // to handle SRAM address collisions caused by misalignment of
 // AHBL write address and write data.

module ahb_sync_sram #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter DEPTH = 1 << 11,
	parameter PRELOAD_FILE = ""
) (
	// Globals
	input wire clk,
	input wire rst_n,

	// AHB lite slave interface
	output wire               ahbls_hready_resp,
	input  wire               ahbls_hready,
	output wire               ahbls_hresp,
	input  wire [W_ADDR-1:0]  ahbls_haddr,
	input  wire               ahbls_hwrite,
	input  wire [1:0]         ahbls_htrans,
	input  wire [2:0]         ahbls_hsize,
	input  wire [2:0]         ahbls_hburst,
	input  wire [3:0]         ahbls_hprot,
	input  wire               ahbls_hmastlock,
	input  wire [W_DATA-1:0]  ahbls_hwdata,
	output wire [W_DATA-1:0]  ahbls_hrdata
);

// This should be localparam but ISIM won't allow the $clog2 call for localparams
// because of "reasons"
parameter  W_SRAM_ADDR = $clog2(DEPTH);
localparam W_BYTES     = W_DATA / 8;
parameter  W_BYTEADDR  = $clog2(W_BYTES);

assign ahbls_hresp = 1'b0;
assign ahbls_hready_resp = 1'b1;

// Need to buffer at least a write address,
// and potentially the data too:
reg [W_SRAM_ADDR-1:0] addr_saved;
reg [W_DATA-1:0]      wdata_saved;
reg [W_BYTES-1:0]     wmask_saved;
reg                   wbuf_vld;

// Decode AHBL controls
wire ahb_read_aphase  = ahbls_htrans[1] && ahbls_hready && !ahbls_hwrite;
wire ahb_write_aphase = ahbls_htrans[1] && ahbls_hready &&  ahbls_hwrite;
wire write_retire = |wmask_saved && !ahb_read_aphase;
wire write_capture = !wbuf_vld && |wmask_saved && ahb_read_aphase;

wire [W_SRAM_ADDR-1:0] haddr_row = ahbls_haddr[W_BYTEADDR +: W_SRAM_ADDR];
wire [W_BYTES-1:0] wmask_noshift = ~({W_BYTES{1'b1}} << (1 << ahbls_hsize));
wire [W_BYTES-1:0] wmask = wmask_noshift << ahbls_haddr[W_BYTEADDR-1:0];

// AHBL state machine (mainly controlling write buffer)
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wmask_saved <= {W_BYTES{1'b0}};
		addr_saved <= {W_SRAM_ADDR{1'b0}};
		wdata_saved <= {W_DATA{1'b0}};
		wbuf_vld <= 1'b0;
	end else begin
		if (ahb_write_aphase) begin
			wmask_saved <= wmask;
			addr_saved <= haddr_row;
		end else if (write_retire) begin
			wmask_saved <= {W_BYTES{1'b0}};
		end
		if (write_capture) begin: capture
			integer i;
			wbuf_vld <= 1'b1;
			for (i = 0; i < W_BYTES; i = i + 1)
				if (wmask_saved[i])
					wdata_saved[i * 8 +: 8] <= ahbls_hwdata[i * 8 +: 8];
		end else if (write_retire) begin
			wbuf_vld <= 1'b0;
		end
	end
end

// SRAM controls
wire [W_BYTES-1:0] sram_wen = write_retire ? wmask_saved : {W_BYTES{1'b0}};
wire [W_SRAM_ADDR-1:0] sram_addr = write_retire ? addr_saved : haddr_row;
wire [W_DATA-1:0] sram_wdata = wbuf_vld ? wdata_saved : ahbls_hwdata;
wire [W_DATA-1:0] sram_rdata;

// Merge buffered write data into AHBL read bus
reg [W_SRAM_ADDR-1:0] haddr_dphase;
wire addr_match = haddr_dphase == addr_saved;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		haddr_dphase <= {W_SRAM_ADDR{1'b0}};
	else if (ahbls_hready)
		haddr_dphase <= haddr_row;

genvar b;
generate
for (b = 0; b < W_BYTES; b = b + 1) begin: write_merge
	assign ahbls_hrdata[b * 8 +: 8] = addr_match && wbuf_vld && wmask_saved[b] ?
		wdata_saved[b * 8 +: 8] : sram_rdata[b * 8 +: 8];
end
endgenerate

sram_sync #(
	.WIDTH(W_DATA),
	.DEPTH(DEPTH),
	.BYTE_ENABLE(1),
	.PRELOAD_FILE(PRELOAD_FILE)
) sram (
	.clk   (clk),
	.wen   (sram_wen),
	.addr  (sram_addr),
	.wdata (sram_wdata),
	.rdata (sram_rdata)
);

endmodule
