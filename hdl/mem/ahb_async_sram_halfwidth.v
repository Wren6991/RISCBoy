// Adapt AHB bus to an async SRAM with half width.
// Feels like there is a loss of generality/parameterisation here,
// but for RISCBoy there is some scope to do e.g. double-pumped reads
// to improve performance, so makes sense to have a special-case
// half-width-only controller to inject these.

// Size of memory is DEPTH * W_SRAM_DATA

module ahb_async_sram_halfwidth #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter DEPTH = 1 << 11,
	parameter W_SRAM_ADDR = $clog2(DEPTH), // Let this default
	parameter W_SRAM_DATA = W_DATA / 2     // Let this default
) (
	// Globals
	input wire                      clk,
	input wire                      rst_n,

	// AHB lite slave interface
	output wire                     ahbls_hready_resp,
	input  wire                     ahbls_hready,
	output wire                     ahbls_hresp,
	input  wire [W_ADDR-1:0]        ahbls_haddr,
	input  wire                     ahbls_hwrite,
	input  wire [1:0]               ahbls_htrans,
	input  wire [2:0]               ahbls_hsize,
	input  wire [2:0]               ahbls_hburst,
	input  wire [3:0]               ahbls_hprot,
	input  wire                     ahbls_hmastlock,
	input  wire [W_DATA-1:0]        ahbls_hwdata,
	output wire [W_DATA-1:0]        ahbls_hrdata,

	output reg  [W_SRAM_ADDR-1:0]   sram_addr,
	inout  wire [W_SRAM_DATA-1:0]   sram_dq,
	output reg                      sram_ce_n,
	output wire                     sram_we_n, // DDR output
	output reg                      sram_oe_n,
	output reg  [W_SRAM_DATA/8-1:0] sram_byte_n
);

parameter W_BYTEADDR = $clog2(W_SRAM_DATA / 8);

assign ahbls_hresp = 1'b0;

// AHBL decode and muxing

wire [W_DATA/8-1:0] bytemask_noshift = ~({W_DATA/8{1'b1}} << (8'h1 << ahbls_hsize));
wire [W_DATA/8-1:0] bytemask = bytemask_noshift << ahbls_haddr[W_BYTEADDR-1:0];
wire aphase_full_width = (8'h1 << ahbls_hsize) == W_DATA / 8; // indicates next dphase will be long

reg hready_r;
reg long_dphase;
wire we_next = ahbls_htrans[1] && ahbls_hwrite && ahbls_hready
	|| long_dphase && sram_oe_n && !hready_r;

wire [W_SRAM_DATA-1:0] sram_q;
wire [W_SRAM_DATA-1:0] sram_rdata = sram_q & {W_SRAM_DATA{!sram_oe_n}};
wire [W_SRAM_DATA-1:0] sram_wdata = ahbls_hwdata[(sram_addr[0] ? W_SRAM_DATA : 0) +: W_SRAM_DATA];	
reg  [W_SRAM_DATA-1:0] rdata_buf;
assign ahbls_hrdata = {sram_rdata, long_dphase ? rdata_buf : sram_rdata};

assign ahbls_hready_resp = hready_r;

// AHBL state machine

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sram_addr <= {W_SRAM_ADDR{1'b0}};
		sram_ce_n <= 1'b1;
		sram_oe_n <= 1'b1;
		sram_byte_n <= {W_DATA/8{1'b1}};
		hready_r <= 1'b1;
		long_dphase <= 1'b0;
	end else if (ahbls_hready) begin
		if (ahbls_htrans[1]) begin
			sram_addr <= ahbls_haddr[W_BYTEADDR +: W_SRAM_ADDR];
			sram_ce_n <= 1'b0;
			sram_oe_n <= ahbls_hwrite;
			sram_byte_n <= ~bytemask;
			long_dphase <= aphase_full_width;
			hready_r <= !aphase_full_width;
		end	else begin
			sram_ce_n <= 1'b1;
			sram_oe_n <= 1'b1;
			sram_byte_n <= {W_DATA/8{1'b1}};
			long_dphase <= 1'b0;
			hready_r <= 1'b1;
		end
	end else if (long_dphase && !hready_r) begin
		rdata_buf <= sram_rdata;
		sram_addr[0] <= 1'b1;
		hready_r <= 1'b1;
	end
end

// External SRAM hookup (tristating etc)

ddr_out we_ddr (
	.clk    (clk),
	.rst_n  (rst_n),
	.d_rise (!we_next),
	.d_fall (1'b1),
	.q      (sram_we_n)
);

tristate_io iobuf [W_SRAM_DATA-1:0] (
	.out (sram_wdata),
	.oe  (sram_oe_n),
	.in  (sram_q),
	.pad (sram_dq)
);

endmodule