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
	.ahblm_haddr     (ahblm_haddr),
	.ahblm_hwrite    (ahblm_hwrite),
	.ahblm_htrans    (ahblm_htrans),
	.ahblm_hsize     (ahblm_hsize),
	.ahblm_hburst    (ahblm_hburst),
	.ahblm_hprot     (ahblm_hprot),
	.ahblm_hmastlock (ahblm_hmastlock),
	.ahblm_hready    (ahblm_hready),
	.ahblm_hresp     (ahblm_hresp),
	.ahblm_hwdata    (ahblm_hwdata),
	.ahblm_hrdata    (ahblm_hrdata)
);

initial assume(rst_n == 0);

always @ (posedge clk)
	rst_n <= 1'b1;

endmodule
