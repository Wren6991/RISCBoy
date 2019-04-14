module ahb_async_sram #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter DEPTH = 1 << 11,
	parameter W_SRAM_ADDR = $clog2(DEPTH) // Let this default
) (
	// Globals
	input wire                   clk,
	input wire                   rst_n,

	// AHB lite slave interface
	output wire                  ahbls_hready_resp,
	input  wire                  ahbls_hready,
	output wire                  ahbls_hresp,
	input  wire [W_ADDR-1:0]     ahbls_haddr,
	input  wire                  ahbls_hwrite,
	input  wire [1:0]            ahbls_htrans,
	input  wire [2:0]            ahbls_hsize,
	input  wire [2:0]            ahbls_hburst,
	input  wire [3:0]            ahbls_hprot,
	input  wire                  ahbls_hmastlock,
	input  wire [W_DATA-1:0]     ahbls_hwdata,
	output wire [W_DATA-1:0]     ahbls_hrdata,

	output reg [W_SRAM_ADDR-1:0] sram_addr,
	inout wire [W_DATA-1:0]      sram_dq,
	output reg                   sram_ce_n,
	output wire                  sram_we_n, // DDR output
	output reg                   sram_oe_n,
	output reg [W_DATA/8-1:0]    sram_byte_n
);

parameter W_BYTEADDR = $clog2(W_DATA / 8);

// Tie off unused AHBL signals

assign ahbls_hready_resp = 1'b1;
assign ahbls_hresp = 1'b0;

// Combinatorially generate the byte strobes from address + size buses

wire [W_DATA/8-1:0] bytemask_noshift = ~({W_DATA/8{1'b1}} << (8'h1 << ahbls_hsize));
wire [W_DATA/8-1:0] bytemask = bytemask_noshift << ahbls_haddr[W_BYTEADDR-1:0];

// AHBL request marshalling/translation

wire we_next = ahbls_htrans[1] && ahbls_hwrite && ahbls_hready;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sram_addr <= {W_SRAM_ADDR{1'b0}};
		sram_ce_n <= 1'b1;
		sram_oe_n <= 1'b1;
		sram_byte_n <= {W_DATA/8{1'b1}};
	end else if (ahbls_hready) begin
		if (ahbls_htrans[1]) begin
			sram_addr <= ahbls_haddr[W_BYTEADDR +: W_SRAM_ADDR];
			sram_ce_n <= 1'b0;
			sram_oe_n <= ahbls_hwrite;
			sram_byte_n <= ~bytemask;
		end	else begin
			sram_ce_n <= 1'b1;
			sram_oe_n <= 1'b1;
			sram_byte_n <= {W_DATA/8{1'b1}};
		end
	end
end

ddr_out we_ddr (
	.clk    (clk),
	.rst_n  (rst_n),
	.d_rise (1'b1),
	.d_fall (!we_next),
	.q      (sram_we_n)
);

// SRAM tristating

wire [W_DATA-1:0] sram_q;
assign ahbls_hrdata = sram_q & {W_DATA{!sram_oe_n}};

tristate_io iobuf [W_DATA-1:0] (
	.out (ahbls_hwdata),
	.oe  (sram_oe_n),
	.in  (sram_q),
	.pad (sram_dq)
);

endmodule