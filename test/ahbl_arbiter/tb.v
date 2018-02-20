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

// Connect 4 masters to a single SRAM.
// Each master writes to byte 0, 1, 2 or 3 (assigned to each master)
// of every single word in SRAM.
// Random idle periods are inserted between writes.
// They then read back their bytes to verify. 

module tb();

localparam W_ADDR = 32;
localparam W_DATA = 32;
localparam N_MASTERS = 4;
localparam SRAM_DEPTH = 64;

reg               clk;
reg               rst_n;

wire [N_MASTERS-1:0]        success;

wire [N_MASTERS-1:0]        master_hready;
wire [N_MASTERS-1:0]        master_hready_resp;
wire [N_MASTERS-1:0]        master_hresp;
wire [N_MASTERS*W_ADDR-1:0] master_haddr;
wire [N_MASTERS-1:0]        master_hwrite;
wire [N_MASTERS*2-1:0]      master_htrans;
wire [N_MASTERS*3-1:0]      master_hsize;
wire [N_MASTERS*3-1:0]      master_hburst;
wire [N_MASTERS*4-1:0]      master_hprot;
wire [N_MASTERS-1:0]        master_hmastlock;
wire [N_MASTERS*W_DATA-1:0] master_hwdata;
wire [N_MASTERS*W_DATA-1:0] master_hrdata;

wire                        sram_hready;
wire                        sram_hready_resp;
wire                        sram_hresp;
wire [W_ADDR-1:0]           sram_haddr;
wire                        sram_hwrite;
wire [1:0]                  sram_htrans;
wire [2:0]                  sram_hsize;
wire [2:0]                  sram_hburst;
wire [3:0]                  sram_hprot;
wire                        sram_hmastlock;
wire [W_DATA-1:0]           sram_hwdata;
wire [W_DATA-1:0]           sram_hrdata;

ahbl_arbiter #(
	.N_PORTS(N_MASTERS),
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA)
) inst_ahbl_arbiter (
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready      (master_hready),
	.ahbls_hready_resp (master_hready),
	.ahbls_hresp       (master_hresp),
	.ahbls_haddr       (master_haddr),
	.ahbls_hwrite      (master_hwrite),
	.ahbls_htrans      (master_htrans),
	.ahbls_hsize       (master_hsize),
	.ahbls_hburst      (master_hburst),
	.ahbls_hprot       (master_hprot),
	.ahbls_hmastlock   (master_hmastlock),
	.ahbls_hwdata      (master_hwdata),
	.ahbls_hrdata      (master_hrdata),
	.ahblm_hready_resp (sram_hready_resp),
	.ahblm_hresp       (sram_hresp),
	.ahblm_haddr       (sram_haddr),
	.ahblm_hwrite      (sram_hwrite),
	.ahblm_htrans      (sram_htrans),
	.ahblm_hsize       (sram_hsize),
	.ahblm_hburst      (sram_hburst),
	.ahblm_hprot       (sram_hprot),
	.ahblm_hmastlock   (sram_hmastlock),
	.ahblm_hwdata      (sram_hwdata),
	.ahblm_hrdata      (sram_hrdata)
);

tb_master #(
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA),
	.TEST_LEN(SRAM_DEPTH)
) inst_tb_master[N_MASTERS-1:0] (
	.clk            (clk),
	.rst_n          (rst_n),
	.master_id      (8'b11_10_01_00),
	.success        (success),
	.ahbl_hready    (master_hready),
	.ahbl_hresp     (master_hresp),
	.ahbl_haddr     (master_haddr),
	.ahbl_hwrite    (master_hwrite),
	.ahbl_htrans    (master_htrans),
	.ahbl_hsize     (master_hsize),
	.ahbl_hburst    (master_hburst),
	.ahbl_hprot     (master_hprot),
	.ahbl_hmastlock (master_hmastlock),
	.ahbl_hwdata    (master_hwdata),
	.ahbl_hrdata    (master_hrdata)
);

ahb_sync_sram #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.DEPTH(SRAM_DEPTH)
) inst_ahb_sync_sram (
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready_resp (sram_hready_resp),
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


localparam CLK_PERIOD = 10;

always #(0.5 * CLK_PERIOD) clk = !clk;

initial begin
	clk = 0;
	rst_n = 0;

	#(3 * CLK_PERIOD);
	rst_n = 1;

	@ (posedge &success);
	$display("Test PASSED.");
	$finish(2);
end

endmodule