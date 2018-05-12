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

module ahb_sync_sram #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter DEPTH = 1 << 10
) (
	// Globals
	input wire clk,
	input wire rst_n,

	// AHB lite slave interface
	output wire              ahbls_hready_resp,
	output wire              ahbls_hresp,
	input wire [W_ADDR-1:0]  ahbls_haddr,
	input wire               ahbls_hwrite,
	input wire [1:0]         ahbls_htrans,
	input wire [2:0]         ahbls_hsize,
	input wire [2:0]         ahbls_hburst,
	input wire [3:0]         ahbls_hprot,
	input wire               ahbls_hmastlock,
	input wire [W_DATA-1:0]  ahbls_hwdata,
	output reg [W_DATA-1:0]  ahbls_hrdata
);

integer i;

// synthesis translate_off
/*initial begin
	if ($clog2(W_DATA) + 1 != $clog2(W_DATA + 1) || W_DATA < 16) begin
		$display("Error: ahb_sync_sram: W_DATA must be power of two, and >= 16");
		$finish(2);
	end
end*/
// synthesis translate_on

// This should be localparam but ISIM won't allow the $clog2 call for localparams
// because of "reasons"
parameter W_SRAM_ADDR = $clog2(DEPTH);
parameter MAX_HSIZE = $clog2(W_DATA) - 3;
localparam W_BYTES = W_DATA / 8;

localparam STATE_IDLE = 2'h0;
localparam STATE_READ = 2'h1;
localparam STATE_WRITE = 2'h2;

reg  [W_BYTES-1:0] w_mask_noshift;
wire [W_BYTES-1:0] w_mask;

// NB: we assume little-endian addressing here

reg [2:0]        hsize_d;
always @ (*) begin
	for (i = 0; i < W_BYTES; i = i + 1) begin
		w_mask_noshift[i] = i < (1 << hsize_d);
	end
end
assign w_mask = w_mask_noshift << haddr_d[$clog2(W_BYTES)-1:0];

// Byte swizzling for read/write data
wire [W_DATA-1:0] sram_rdata;
reg  [W_DATA-1:0] sram_rdata_rot;

always @ (*) begin
	for (i = 0; i < W_BYTES; i = i + 1) begin
		sram_rdata_rot[i * 8 +: 8] = sram_rdata[((i + haddr_d[$clog2(W_BYTES)-1:0]) % W_BYTES) * 8 +: 8];
	end
	if (state == STATE_READ) begin
		for (i = 0; i < W_BYTES; i = i + 1) begin
			ahbls_hrdata[i * 8 +: 8] = sram_rdata_rot[(i % (1 << hsize_d)) * 8 +: 8];
		end
	end else begin
		ahbls_hrdata = {W_DATA{1'b0}};
	end
end

reg [W_DATA-1:0] sram_wdata;

always @ (*) begin
	for (i = 0; i < W_BYTES; i = i + 1) begin
		//sram_wdata[i * 8 +: 8] = ahbls_hwdata[(i % (1 << hsize_d)) * 8 +: 8];
		// Assume that master performs this data replication.
		// TODO: check this assumption and remove this block
		sram_wdata[i * 8 +: 8] = ahbls_hwdata[i * 8 +: 8];
	end
end

// =================
// AHB State Machine
// =================


// There is a timing issue with a write followed immediately by a read: for SRAM, write data and
// address are presented on same clock. For AHB they are different phases. We would therefore
// need to be able to access two addresses at once to perform read and write at same time!
// The same timing issue creates an idle cycle when read is followed by write, so one option is to
// buffer the final write until this idle cycle is reached, and bypass in the buffered write if
// AHB tries to access the address targeted by this write.
// For simplicity, we are just inserting an AHB wait state.
// TODO: do the other thing

reg [1:0] state;
reg [W_ADDR-1:0] haddr_d;

assign ahbls_hready_resp = !(state == STATE_WRITE && ahbls_htrans[1] && !ahbls_hwrite);
assign ahbls_hresp = 1'b0;

wire [W_ADDR-1:0] sram_addr_full = state == STATE_WRITE ? haddr_d : ahbls_haddr;
wire [W_SRAM_ADDR-1:0] sram_addr = sram_addr_full[MAX_HSIZE +: W_SRAM_ADDR];

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		state <= STATE_IDLE;
		haddr_d <= {W_ADDR{1'b0}};
		hsize_d <= 3'h0;
	end else begin
		if (state == STATE_WRITE) begin
			state <= STATE_IDLE;
		end
		if (ahbls_hready_resp) begin
			if (ahbls_htrans[1]) begin
				state <= ahbls_hwrite ? STATE_WRITE : STATE_READ;
				hsize_d <= ahbls_hsize;
				haddr_d <= ahbls_haddr;
			end else begin
				state <= STATE_IDLE;
			end
		end
	end
end


sram_sync #(
	.WIDTH(W_DATA),
	.DEPTH(DEPTH),
	.BYTE_ENABLE(1)
) sram (
	.clk   (clk),
	.wen   (state == STATE_WRITE ? w_mask : {W_BYTES{1'b0}}),
	.addr  (sram_addr),
	.wdata (sram_wdata),
	.rdata (sram_rdata)
);

endmodule