// Randomly perform reads to some fixed target addresses to create contention with other masters

module trafficgen #(
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter IDLENESS = 2,
	parameter TARGET_ADDR = 0
) (
	// Global signals
	input wire               clk,
	input wire               rst_n,

	// AHB-lite Master port
	output wire [W_ADDR-1:0] ahblm_haddr,
	output wire              ahblm_hwrite,
	output reg  [1:0]        ahblm_htrans,
	output wire [2:0]        ahblm_hsize,
	output wire [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	input  wire              ahblm_hready,
	input  wire              ahblm_hresp,
	output wire [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata
);

parameter HSIZE = $clog2(W_DATA / 8);

localparam HTRANS_IDLE = 2'h0;
localparam HTRANS_NSEQ = 2'h2;

assign ahblm_haddr = TARGET_ADDR;
assign ahblm_hwrite = 1'b0;
assign ahblm_hsize = HSIZE;
assign ahblm_hburst = 3'h0;
assign ahblm_hprot = 4'b0011;
assign ahblm_hmastlock = 1'b0;
assign ahblm_hwdata = {W_DATA{1'b0}};

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ahblm_htrans <= HTRANS_IDLE;
	end else if (ahblm_hready) begin
		if ($random % (IDLENESS + 1) == 0)
			ahblm_htrans <= HTRANS_NSEQ;
		else
			ahblm_htrans <= HTRANS_IDLE;
	end
end

endmodule