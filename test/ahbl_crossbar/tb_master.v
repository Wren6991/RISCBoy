module tb_master #(
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter TEST_LEN = 64,
	parameter N_MASTERS = 4
) (
	input wire              clk,
	input wire              rst_n,
	input wire [1:0]        master_id,
	output reg              success,

	input wire              ahbl_hready,
	input wire              ahbl_hresp,
	output reg [W_ADDR-1:0] ahbl_haddr,
	output reg              ahbl_hwrite,
	output reg [1:0]        ahbl_htrans,
	output reg [2:0]        ahbl_hsize,
	output reg [2:0]        ahbl_hburst, 
	output reg [3:0]        ahbl_hprot,
	output reg              ahbl_hmastlock,
	output reg [W_DATA-1:0] ahbl_hwdata,
	input wire [W_DATA-1:0] ahbl_hrdata
);

`include "../common/ahb_tasks.vh"

reg [7:0] test_vec [0:TEST_LEN-1];
reg [7:0] rdata;
integer i;

initial begin
	ahbl_haddr = 0;
	ahbl_hwrite = 0;
	ahbl_htrans = 0;
	ahbl_hsize = 0;
	ahbl_hburst = 0;
	ahbl_hprot = 4'b0011;
	ahbl_hmastlock = 1'b0;
	ahbl_hwdata = 0;

	success = 0;

	for (i = 0; i < TEST_LEN; i = i + 1) begin
		test_vec[i] = $random;
	end

	@ (posedge rst_n);
	@ (posedge clk);
	@ (posedge clk);

	$display("Master %d beginning write", master_id);

	for (i = 0; i < TEST_LEN; i = i + 1) begin
		ahb_write_byte(test_vec[i], i * N_MASTERS + master_id);
		while ($random % 2)
			@ (posedge clk);
	end

	$display("Master %d beginning read", master_id);

	for (i = 0; i < TEST_LEN; i = i + 1) begin
		ahb_read_byte(rdata, i * N_MASTERS + master_id);
		if (rdata != test_vec[i]) begin
			$display("Test FAILED: Master %d, mismatch at %h: %h (r) != %h (w)", master_id, i * 4 + master_id, rdata, test_vec[i]);
			$finish(2);
		end
		while ($random % 2)
			@ (posedge clk);
	end

	success = 1;
end

endmodule