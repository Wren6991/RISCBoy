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

// Connect an AHBL master to multiple SRAMs via a splitter,
// and check that they function as a single, larger SRAM

module tb();

localparam W_ADDR = 32;
localparam W_DATA = 32;
localparam N_SRAMS = 4;
localparam SRAM_DEPTH = 64;
localparam TEST_LEN = SRAM_DEPTH * N_SRAMS;

reg               clk;
reg               rst_n;
wire              ahbl_hready;
wire              ahbl_hresp;
reg  [W_ADDR-1:0] ahbl_haddr;
reg               ahbl_hwrite;
reg  [1:0]        ahbl_htrans;
reg  [2:0]        ahbl_hsize;
reg  [2:0]        ahbl_hburst; 
reg  [3:0]        ahbl_hprot;
reg               ahbl_hmastlock;
reg  [W_DATA-1:0] ahbl_hwdata;
wire [W_DATA-1:0] ahbl_hrdata;

`include "../common/ahb_tasks.vh"

wire [N_SRAMS-1:0]        sram_hready;
wire [N_SRAMS-1:0]        sram_hready_resp;
wire [N_SRAMS-1:0]        sram_hresp;
wire [N_SRAMS*W_ADDR-1:0] sram_haddr;
wire [N_SRAMS-1:0]        sram_hwrite;
wire [N_SRAMS*2-1:0]      sram_htrans;
wire [N_SRAMS*3-1:0]      sram_hsize;
wire [N_SRAMS*3-1:0]      sram_hburst;
wire [N_SRAMS*4-1:0]      sram_hprot;
wire [N_SRAMS-1:0]        sram_hmastlock;
wire [N_SRAMS*W_DATA-1:0] sram_hwdata;
wire [N_SRAMS*W_DATA-1:0] sram_hrdata;

ahb_sync_sram #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.DEPTH(SRAM_DEPTH)
) inst_sram[0:N_SRAMS-1] (
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready_resp (sram_hready_resp),
	.ahbls_hready      (sram_hready),
	.ahbls_hresp       (sram_hresp),
	.ahbls_haddr       (sram_haddr),
	.ahbls_hwrite      (sram_hwrite),
	.ahbls_htrans      (sram_htrans),
	.ahbls_hsize       (sram_hsize),
	.ahbls_hburst      (sram_hburst),
	.ahbls_hprot       (sram_hprot),
	.ahbls_hmastlock   (sram_hmastlock),
	.ahbls_hwdata      (sram_hwdata),
	.ahbls_hrdata      (sram_hrdata)
);


ahbl_splitter #(
	.N_PORTS(N_SRAMS),
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA),
	.ADDR_MAP (128'h00000300_00000200_00000100_00000000),
	.ADDR_MASK(128'h00000f00_00000f00_00000f00_00000f00)
) inst_ahbl_splitter (
	.clk             (clk),
	.rst_n           (rst_n),
	// Connect slave port to testbench master
	.src_hready      (ahbl_hready),
	.src_hready_resp (ahbl_hready),
	.src_hresp       (ahbl_hresp),
	.src_haddr       (ahbl_haddr),
	.src_hwrite      (ahbl_hwrite),
	.src_htrans      (ahbl_htrans),
	.src_hsize       (ahbl_hsize),
	.src_hburst      (ahbl_hburst),
	.src_hprot       (ahbl_hprot),
	.src_hmastlock   (ahbl_hmastlock),
	.src_hwdata      (ahbl_hwdata),
	.src_hrdata      (ahbl_hrdata),
	// Connect master ports to sram slaves
	.dst_hready      (sram_hready),
	.dst_hready_resp (sram_hready_resp),
	.dst_hresp       (sram_hresp),
	.dst_haddr       (sram_haddr),
	.dst_hwrite      (sram_hwrite),
	.dst_htrans      (sram_htrans),
	.dst_hsize       (sram_hsize),
	.dst_hburst      (sram_hburst),
	.dst_hprot       (sram_hprot),
	.dst_hmastlock   (sram_hmastlock),
	.dst_hwdata      (sram_hwdata),
	.dst_hrdata      (sram_hrdata)
);

localparam CLK_PERIOD = 10;

always #(0.5 * CLK_PERIOD) clk = !clk;

reg [W_DATA-1:0] test_vec [0:TEST_LEN-1];
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

	for (i = 0; i < TEST_LEN; i = i + 1) begin
		test_vec[i] = $random;
	end

	#(3 * CLK_PERIOD);
	rst_n = 1;
	#(CLK_PERIOD);
	// Test starts

	$display("Word read/write");

	for (i = 0; i < TEST_LEN; i = i + 1) begin
		ahb_write_word(test_vec[i], i * 4);
	end

	$display("reading back...");

	for (i = 0; i < TEST_LEN; i = i + 1) begin
		ahb_read_word(rdata, i * 4);
		if (rdata != test_vec[i]) begin
			$display("Test FAILED: Mismatch at %h: %h (r) != %h (w)", i * 4, rdata, test_vec[i]);
			$finish(2);
		end
	end

	$display("Test PASSED.");
	$finish(2);
end


endmodule