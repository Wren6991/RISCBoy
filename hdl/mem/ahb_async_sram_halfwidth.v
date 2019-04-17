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

	output wire [W_SRAM_ADDR-1:0]   sram_addr,
	inout  wire [W_SRAM_DATA-1:0]   sram_dq,
	output wire                     sram_ce_n,
	output wire                     sram_we_n, // DDR output
	output wire                     sram_oe_n,
	output wire [W_SRAM_DATA/8-1:0] sram_byte_n
);

parameter W_BYTEADDR = $clog2(W_SRAM_DATA / 8);

assign ahbls_hresp = 1'b0;

reg hready_r;
reg long_dphase;
reg write_dph;
reg read_dph;
reg addr_lsb;

// AHBL decode and muxing

wire [W_SRAM_DATA/8-1:0] bytemask_noshift = ~({W_SRAM_DATA/8{1'b1}} << (8'h1 << ahbls_hsize));
wire [W_SRAM_DATA/8-1:0] bytemask = bytemask_noshift << ahbls_haddr[W_BYTEADDR-1:0];
wire aphase_full_width = (8'h1 << ahbls_hsize) == W_DATA / 8; // indicates next dphase will be long

wire we_next = ahbls_htrans[1] && ahbls_hwrite && ahbls_hready
	|| long_dphase && write_dph && !hready_r;

wire [W_SRAM_DATA-1:0] sram_q;
wire [W_SRAM_DATA-1:0] sram_rdata = sram_q & {W_SRAM_DATA{read_dph}};
wire [W_SRAM_DATA-1:0] sram_wdata = ahbls_hwdata[(addr_lsb ? W_SRAM_DATA : 0) +: W_SRAM_DATA];
reg  [W_SRAM_DATA-1:0] rdata_buf;
assign ahbls_hrdata = {sram_rdata, long_dphase ? rdata_buf : sram_rdata};

assign ahbls_hready_resp = hready_r;

// AHBL state machine

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		hready_r <= 1'b1;
		long_dphase <= 1'b0;
		write_dph <= 1'b0;
		read_dph <= 1'b0;
		addr_lsb <= 1'b0;
	end else if (ahbls_hready) begin
		if (ahbls_htrans[1]) begin
			long_dphase <= aphase_full_width;
			hready_r <= !aphase_full_width;
			write_dph <= ahbls_hwrite;
			read_dph <= !ahbls_hwrite;
			addr_lsb <= ahbls_haddr[W_BYTEADDR];
		end	else begin
			write_dph <= 1'b0;
			long_dphase <= 1'b0;
			read_dph <= 1'b0;
			hready_r <= 1'b1;
		end
	end else if (long_dphase && !hready_r) begin
		rdata_buf <= sram_rdata;
		hready_r <= 1'b1;
		addr_lsb <= 1'b1;
	end
end

// External SRAM hookup (tristating etc)

ddr_out we_ddr (
	.clk    (clk),
	.rst_n  (rst_n),
	.d_rise (1'b1),
	.d_fall (!we_next),
	.e      (1'b1),
	.q      (sram_we_n)
);

dffe_out addr_dffe [W_SRAM_ADDR-2:0] (
	.clk (clk),
	.d   (ahbls_haddr[W_BYTEADDR + 1 +: W_SRAM_ADDR - 1]),
	.e   (ahbls_htrans[1] && ahbls_hready),
	.q   (sram_addr[W_SRAM_ADDR-1:1])
);

dffe_out addr0_dffe (
	.clk (clk),
	.d   (ahbls_haddr[W_BYTEADDR] || (long_dphase && !ahbls_hready)),
	.e   (1'b1),           // HACK 1'b1 is overgenerous, but tying high means we can colocate with
	.q   (sram_addr[0])    // WEn. Any other address pin would put clock enable on WEn which is fatal.
);

dffe_out ce_dffe (
	.clk (clk),
	.d   (!ahbls_htrans[1]),
	.e   (ahbls_hready),
	.q   (sram_ce_n)
);

dffe_out oe_dffe (
	.clk (clk),
	.d   (ahbls_hwrite || !ahbls_htrans[1]),
	.e   (ahbls_htrans[1] && ahbls_hready), // HACK see ben_dffe
	.q   (sram_oe_n)
);

dffe_out ben_dffe [1:0] (
	.clk (clk),
	.d   (~bytemask),
	.e   (ahbls_htrans[1] && ahbls_hready), // HACK: ideally would be hready, but due to stupid iCE40 design,
	.q   (sram_byte_n)                      // needs to match the colocated IO, since there is one CE per two IOBs.
	);                                      // On HX8k-EVN ben[1] shares with addr[11] and ben[0] is on its own.

tristate_io iobuf [W_SRAM_DATA-1:0] (
	.out (sram_wdata),
	.oe  (write_dph),
	.in  (sram_q),
	.pad (sram_dq)
);

endmodule
