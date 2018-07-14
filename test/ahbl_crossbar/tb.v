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

// Map 2 SRAMs into a single flat memory region.
// Attach 2 masters to SRAMs via crossbar.
// Each master writes to byte 0, 1, 2 or 3 (assigned per master)
// of every single word in SRAM array.
// Random idle periods are inserted between writes.
// They then read back their bytes to verify, again with random idle.

module tb();

localparam W_ADDR = 32;
localparam W_DATA = 32;
localparam N_MASTERS = 2;
localparam N_SRAMS = 2;
localparam SRAM_DEPTH = 8;
localparam TEST_LEN = N_SRAMS * SRAM_DEPTH * (W_DATA / 8 / N_MASTERS);

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

wire [N_SRAMS-1:0]          sram_hready;
wire [N_SRAMS-1:0]          sram_hready_resp;
wire [N_SRAMS-1:0]          sram_hresp;
wire [N_SRAMS*W_ADDR-1:0]   sram_haddr;
wire [N_SRAMS-1:0]          sram_hwrite;
wire [N_SRAMS*2-1:0]        sram_htrans;
wire [N_SRAMS*3-1:0]        sram_hsize;
wire [N_SRAMS*3-1:0]        sram_hburst;
wire [N_SRAMS*4-1:0]        sram_hprot;
wire [N_SRAMS-1:0]          sram_hmastlock;
wire [N_SRAMS*W_DATA-1:0]   sram_hwdata;
wire [N_SRAMS*W_DATA-1:0]   sram_hrdata;


ahbl_crossbar #(
	.N_MASTERS(N_MASTERS),
	.N_SLAVES(N_SRAMS),
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA),
	.ADDR_MAP (128'h00000060_00000040_00000020_00000000),
	.ADDR_MASK(128'h000000e0_000000e0_000000e0_000000e0)
) inst_ahbl_crossbar (
	.clk              (clk),
	.rst_n            (rst_n),
	.src_hready_resp  (master_hready),
	.src_hresp        (master_hresp),
	.src_haddr        (master_haddr),
	.src_hwrite       (master_hwrite),
	.src_htrans       (master_htrans),
	.src_hsize        (master_hsize),
	.src_hburst       (master_hburst),
	.src_hprot        (master_hprot),
	.src_hmastlock    (master_hmastlock),
	.src_hwdata       (master_hwdata),
	.src_hrdata       (master_hrdata),
	.dst_hready_resp  (sram_hready_resp),
	.dst_hready       (sram_hready),
	.dst_haddr        (sram_haddr),
	.dst_hwrite       (sram_hwrite),
	.dst_htrans       (sram_htrans),
	.dst_hsize        (sram_hsize),
	.dst_hburst       (sram_hburst),
	.dst_hprot        (sram_hprot),
	.dst_hmastlock    (sram_hmastlock),
	.dst_hresp        (sram_hresp),
	.dst_hwdata       (sram_hwdata),
	.dst_hrdata       (sram_hrdata)
);

tb_master #(
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA),
	.TEST_LEN(TEST_LEN),
	.N_MASTERS(N_MASTERS)
) inst_tb_master[N_MASTERS-1:0] (
	.clk            (clk),
	.rst_n          (rst_n),
	.master_id      (4'b01_00),
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
) inst_ahb_sync_sram[0:N_SRAMS-1] (
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