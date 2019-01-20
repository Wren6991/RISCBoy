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

// TODO: nonblocking deferred writes, with write->read bypass on address match
// (remove wait states)

module ahb_sync_sram #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter DEPTH = 1 << 11,
	parameter PRELOAD_FILE = "NONE"
) (
	// Globals
	input wire clk,
	input wire rst_n,

	// AHB lite slave interface
	output wire               ahbls_hready_resp,
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

wire [W_BYTES-1:0] wmask_noshift = ~({W_BYTES{1'b1}} << (1 << ahbls_hsize));
wire [W_BYTES-1:0] wmask = wmask_noshift << ahbls_haddr[W_BYTEADDR-1:0];
reg [W_BYTES-1:0] wen;

reg [W_SRAM_ADDR-1:0] addr_saved;
wire [W_SRAM_ADDR-1:0] sram_addr = hreadyout ?
	ahbls_haddr[W_BYTEADDR +: W_SRAM_ADDR] : addr_saved;

reg hreadyout;
assign ahbls_hready_resp = hreadyout;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		hreadyout <= 1'b1;
		wen <= {W_BYTES{1'b0}};
		addr_saved <= {W_SRAM_ADDR{1'b0}};
	end else begin
		if (ahbls_hwrite && ahbls_htrans[1] && hreadyout) begin
			hreadyout <= 1'b0;
			wen <= wmask;
			addr_saved <= ahbls_haddr[W_BYTEADDR +: W_SRAM_ADDR];
		end else begin
			hreadyout <= 1'b1;
			wen <= {W_BYTES{1'b0}};
		end
	end
end

sram_sync #(
	.WIDTH(W_DATA),
	.DEPTH(DEPTH),
	.BYTE_ENABLE(1),
	.PRELOAD_FILE(PRELOAD_FILE)
) sram (
	.clk   (clk),
	.wen   (wen),
	.addr  (sram_addr),
	.wdata (ahbls_hwdata),
	.rdata (ahbls_hrdata)
);

endmodule
