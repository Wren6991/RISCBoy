module memdump #(
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter ADDR_START = 32'h20080000,
	parameter ADDR_STOP = ADDR_START + (1 << 13)
) (
	// Global signals
	input wire               clk,
	input wire               rst_n,

	// AHB-lite Master port
	output wire [W_ADDR-1:0] ahblm_haddr,
	output wire              ahblm_hwrite,
	output wire [1:0]        ahblm_htrans,
	output wire [2:0]        ahblm_hsize,
	output wire [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	input  wire              ahblm_hready,
	input  wire              ahblm_hresp,
	output wire [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata,

	output reg serial_out
);

// Sit in place of the processor. Read in memory and dump it out via raw differential manchester serial.

// ============================================================================
// FIFO decouples bus interface from data modulator
// ============================================================================

wire fifo_wen;
wire fifo_ren;
wire fifo_full;
wire fifo_empty;
wire [W_DATA-1:0] fifo_rdata;

sync_fifo #(
	.DEPTH(4),
	.WIDTH(W_DATA)
) inst_sync_fifo (
	.clk    (clk),
	.rst_n  (rst_n),
	.w_data (ahblm_hrdata),
	.w_en   (fifo_wen),
	.r_data (fifo_rdata),
	.r_en   (fifo_ren),
	.full   (fifo_full),
	.empty  (fifo_empty),
	.level  ()
);

// ============================================================================
// Bus interface
// ============================================================================

reg [W_ADDR-1:0] addr;
reg              dphase_active;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dphase_active <= 1'b0;
		addr <= ADDR_START;
	end else if (ahblm_hready) begin
		dphase_active <= ahblm_htrans[1];
		if (ahblm_htrans[1])
			addr <= addr + W_DATA / 8;
	end
end

assign fifo_wen = dphase_active && ahblm_hready;

assign ahblm_haddr = addr;
assign ahblm_hwrite = 1'b0;
assign ahblm_htrans = {!(fifo_full || addr == ADDR_STOP || dphase_active), 1'b0};
parameter HSIZE = $clog2(W_DATA/8); // fuck ISIM
assign ahblm_hsize = HSIZE;
assign ahblm_hprot = 0;
assign ahblm_hburst = 0;
assign ahblm_hwdata = 0;
assign ahblm_hmastlock = 1'b0;

// ============================================================================
// Data modulator
// ============================================================================

parameter W_CTR = $clog2(W_DATA + 1);

reg pingpong;
reg [W_CTR-1:0] ctr;
reg [W_DATA-1:0] shift;

assign fifo_ren = !fifo_empty && (ctr == 0 || (ctr == 1 && pingpong));

// Shifting logic

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pingpong <= 1'b0;
		ctr <= {W_CTR{1'b0}};
		shift <= {W_DATA{1'b0}};
	end else if (fifo_ren) begin
		ctr <= W_DATA;
		shift <= fifo_rdata;
		pingpong <= 1'b0;
	end else if (|ctr) begin
		pingpong <= !pingpong;
		if (pingpong) begin
			ctr <= ctr - 1'b1;
			shift <= shift << 1;
		end
	end
end

// Actual BMPC

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		serial_out <= 1'b0;
	end else if (|ctr) begin
		serial_out <= serial_out ^ (!pingpong || shift[W_DATA - 1]);
	end
end

endmodule