module revive_frontend (
	input  wire [31:0] ahbl_hrdata,
	input  wire [31:0] icache_rdata,
	input  wire        icache_valid,
	input  wire        ahbl_hready,
	output wire        fetch_req,
	input  wire        fetch_gnt
);

