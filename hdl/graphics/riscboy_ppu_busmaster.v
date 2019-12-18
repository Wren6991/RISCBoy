module riscboy_ppu_busmaster #(
	parameter N_REQ = 10,
	parameter W_ADDR = 32,
	parameter W_DATA = 32  // must be 32 (just up here for use on ports)
) (
	input wire                    clk,
	input wire                    rst_n,

	// Once vld asserted, can not be deasserted until rdy is seen.
	// If addr+size is held constant, rdy indicates data is present on data bus.
	// If addr+size are not held constant (e.g. due to flush) the data response
	// is undefined, and should be discarded. However vld must still be held
	// high until rdy is seen.
	input wire [N_REQ-1:0]        req_vld,
	input wire [N_REQ*W_ADDR-1:0] req_addr,
	input wire [N_REQ*2-1:0]      req_size,
	input wire [N_REQ-1:0]        req_rdy,
	input wire [N_REQ*W_DATA-1:0] req_data,

	// AHB-lite Master port
	output wire [W_ADDR-1:0]      ahblm_haddr,
	output wire                   ahblm_hwrite,
	output wire [1:0]             ahblm_htrans,
	output wire [2:0]             ahblm_hsize,
	output wire [2:0]             ahblm_hburst,
	output wire [3:0]             ahblm_hprot,
	output wire                   ahblm_hmastlock,
	input  wire                   ahblm_hready,
	input  wire                   ahblm_hresp,
	output wire [W_DATA-1:0]      ahblm_hwdata,
	input  wire [W_DATA-1:0]      ahblm_hrdata
);

// Tie off unused bus outputs

assign ahblm_hwrite = 1'b0;
assign ahblm_hburst = 3'h0;
assign ahblm_hprot = 4'b0011; // non-cacheable non-bufferable privileged data access
assign ahblm_hmastlock = 1'b0;
assign ahblm_hwdata = {W_DATA{1'b0}};

// ----------------------------------------------------------------------------
// Request arbitration

wire [N_REQ-1:0] grant_aph_comb;
reg  [N_REQ-1:0] grant_aph_reg;
wire [N_REQ-1:0] grant_aph = |grant_aph_reg ? grant_aph_reg : grant_aph_comb;

reg [N_REQ-1:0] grant_dph;
wire [N_REQ-1:0] req_filtered = req_vld & ~(grant_aph_reg | grant_dph);

onehot_priority #(
	.W_INPUT (N_REQ)
) req_priority_u (
	.in  (req_filtered),
	.out (grant_aph_comb)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		grant_aph_reg <= {N_REQ{1'b0}};
		grant_dph <= {N_REQ{1'b0}};
	end else if (ahblm_hready) begin
		grant_aph_reg <= {N_REQ{1'b0}};
		grant_dph <= grant_aph;
	end else begin
		grant_aph_reg <= grant_aph;
	end
end

// This could be a long path; a good way to cut it is to only use the
// registered version of transaction attributes. Would cost one latency cycle.
wire [W_ADDR-1:0] req_addr_muxed;
wire [1:0]        req_size_muxed;

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (W_ADDR)
) addr_mux_u (
	.in  (req_addr),
	.sel (grant_aph_comb),
	.out (req_addr_muxed)
);

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (2)
) size_mux_u (
	.in  (req_size),
	.sel (grant_aph_comb),
	.out (req_size_muxed)
);

// ----------------------------------------------------------------------------
// Bus request generation

// AHBL requires that aphase transaction attributes are held constant after
// assertion of htrans, until hready goes high. This means at least the grant
// must be held, but we also need to hold address + size due to the way we
// have specified the request interface.

wire use_buf_transattr = |grant_aph_reg;

reg [W_ADDR-1:0] aph_buf_addr;
reg [1:0]        aph_buf_size;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		aph_buf_addr <= {W_ADDR{1'b0}};
		aph_buf_size <= 2'h0;
	end else if (|req_filtered && !use_buf_transattr && !ahblm_hready) begin
		aph_buf_addr <= req_addr_muxed;
		aph_buf_size <= req_size_muxed;
	end
end

assign ahblm_haddr = use_buf_transattr ? aph_buf_addr : req_addr_muxed;
assign ahblm_hsize = {1'b0, use_buf_transattr ? aph_buf_size : req_size_muxed};
assign ahblm_htrans = {|grant_aph, 1'b0};

// ----------------------------------------------------------------------------
// Data phase response steering

reg [1:0]        dph_buf_addr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dph_buf_addr <= 2'h0;
	end else if (ahblm_hready) begin
		dph_buf_addr <= ahblm_haddr[1:0];
	end
end

wire [W_DATA-1:0] hrdata_steered = {
	ahblm_hrdata[31:16],
	dph_buf_addr[1] ? ahblm_hrdata[31:24] : ahblm_hrdata[15:8],
	ahblm_hrdata[dph_buf_addr * 8 +: 8]
};

assign req_rdy = grant_dph & {N_REQ{ahblm_hready}};
assign req_data = {N_REQ{hrdata_steered}};

endmodule
