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


module tb();


localparam W_DATA = 32;
localparam W_ADDR = 32;
localparam MEM_DEPTH = 1 << 4;
localparam W_SRAM_DATA = W_DATA / 2;

parameter W_SRAM_ADDR = $clog2(MEM_DEPTH) + 1;

`include "../common/ahb_tasks.vh"

reg clk;
reg rst_n;

wire                     ahbl_hready;
wire                     ahbl_hresp;
reg  [W_ADDR-1:0]        ahbl_haddr;
reg                      ahbl_hwrite;
reg  [1:0]               ahbl_htrans;
reg  [2:0]               ahbl_hsize;
reg  [2:0]               ahbl_hburst; 
reg  [3:0]               ahbl_hprot;
reg                      ahbl_hmastlock;
reg  [W_DATA-1:0]        ahbl_hwdata;
wire [W_DATA-1:0]        ahbl_hrdata;

wire [W_SRAM_ADDR-1:0]   sram_addr;
wire [W_SRAM_DATA-1:0]   sram_dq;
wire                     sram_ce_n;
wire                     sram_we_n;
wire                     sram_oe_n;
wire [W_SRAM_DATA/8-1:0] sram_byte_n;

ahb_async_sram_halfwidth #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.DEPTH(MEM_DEPTH * 2)
) uut (
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready_resp (ahbl_hready),
	.ahbls_hready      (ahbl_hready),
	.ahbls_hresp       (ahbl_hresp),
	.ahbls_haddr       (ahbl_haddr),
	.ahbls_hwrite      (ahbl_hwrite),
	.ahbls_htrans      (ahbl_htrans),
	.ahbls_hsize       (ahbl_hsize),
	.ahbls_hburst      (ahbl_hburst),
	.ahbls_hprot       (ahbl_hprot),
	.ahbls_hmastlock   (ahbl_hmastlock),
	.ahbls_hwdata      (ahbl_hwdata),
	.ahbls_hrdata      (ahbl_hrdata),

	.sram_addr         (sram_addr),
	.sram_dq           (sram_dq),
	.sram_ce_n         (sram_ce_n),
	.sram_we_n         (sram_we_n),
	.sram_oe_n         (sram_oe_n),
	.sram_byte_n       (sram_byte_n)
);

sram_async #(
	.W_DATA (W_SRAM_DATA),
	.DEPTH (MEM_DEPTH * 2)
) mem (
	.addr  (sram_addr),
	.dq    (sram_dq),
	.ce_n  (sram_ce_n),
	.oe_n  (sram_oe_n),
	.we_n  (sram_we_n),
	.ben_n (sram_byte_n)
);

localparam CLK_PERIOD = 10;

always #(0.5 * CLK_PERIOD) clk = !clk;

reg [W_DATA-1:0] test_vec [0:MEM_DEPTH-1];
integer i;

reg [W_DATA-1:0] rdata;

initial begin
	clk = 0;
	rst_n = 0;
	ahbl_haddr = 0;
	ahbl_hwrite = 0;
	ahbl_htrans = 0;
	ahbl_hsize = 0;
	ahbl_hburst = 0;
	ahbl_hprot = 4'b0011;
	ahbl_hmastlock = 1'b0;

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		test_vec[i] = $random;
	end

	#(3 * CLK_PERIOD);
	rst_n = 1;
	#(CLK_PERIOD);
	// Test starts

	$display("Word read/write");

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		ahb_write_word(test_vec[i], i * 4);
	end

	$display("reading back...");

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		ahb_read_word(rdata, i * 4);
		if (rdata !== test_vec[i]) begin
			$display("Test FAILED: Mismatch at %h: %h (r) != %h (w)", i * 4, rdata, test_vec[i]);
			$finish(2);
		end
	end

	$display("Halfword read/write");

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		ahb_write_halfword(test_vec[i], i * 2);
	end

	$display("reading back...");

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		ahb_read_halfword(rdata, i * 2);
		if (rdata[15:0] !== test_vec[i][15:0]) begin
			$display("Test FAILED: Mismatch at %h: %h (r) != %h (w)", i * 2, rdata[15:0], test_vec[i][15:0]);
			$finish(2);
		end
	end

	$display("Byte read/write");

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		ahb_write_byte(test_vec[i], i);
	end

	$display("reading back...");

	for (i = 0; i < MEM_DEPTH; i = i + 1) begin
		ahb_read_byte(rdata, i);
		if (rdata[7:0] !== test_vec[i][7:0]) begin
			$display("Test FAILED: Mismatch at %h: %h (r) != %h (w)", i * 2, rdata[7:0], test_vec[i][7:0]);
			$finish(2);
		end
	end

	$display("Test PASSED.");
	$finish;
end

endmodule