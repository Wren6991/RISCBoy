// This module just drives a reset and makes sure the top-level ports don't disappear

module tb;

reg clk;
reg rst_n;

(* keep *) wire [31:0]  haddr;
(* keep *) wire         hwrite;
(* keep *) wire [1:0]   htrans;
(* keep *) wire [2:0]   hsize;
(* keep *) wire [2:0]   hburst;
(* keep *) wire [3:0]   hprot;
(* keep *) wire         hmastlock;
(* keep *) wire         hready;
(* keep *) wire         hresp;
(* keep *) wire [31:0]  hwdata;
(* keep *) wire [31:0]  hrdata;

hazard5_cpu #(
	.RESET_VECTOR(0),
	.EXTENSION_C(1)
) dut (
	.clk             (clk),
	.rst_n           (rst_n),
	.ahblm_haddr     (haddr),
	.ahblm_hwrite    (hwrite),
	.ahblm_htrans    (htrans),
	.ahblm_hsize     (hsize),
	.ahblm_hburst    (hburst),
	.ahblm_hprot     (hprot),
	.ahblm_hmastlock (hmastlock),
	.ahblm_hready    (hready),
	.ahblm_hresp     (hresp),
	.ahblm_hwdata    (hwdata),
	.ahblm_hrdata    (hrdata)
);

initial assume(rst_n == 0);

always @ (posedge clk)
	rst_n <= 1'b1;

endmodule
