module spi_mini #(
	parameter FIFO_DEPTH = 2
) (
	input wire clk,
	input wire rst_n,

	input wire apbs_psel,
	input wire apbs_penable,
	input wire apbs_pwrite,
	input wire [15:0] apbs_paddr,
	input wire [31:0] apbs_pwdata,
	output wire [31:0] apbs_prdata,
	output wire apbs_pready,
	output wire apbs_pslverr,

	output reg sclk,
	output reg sdo,
	input wire sdi,
	output reg cs_n
);

parameter W_FLEVEL = $clog2(FIFO_DEPTH + 1);
localparam W_DIV_INT = 6;
localparam W_DATA = 8;

wire rst_n_sync;

reset_sync #(
	.N_CYCLES (2)
) inst_reset_sync (
	.clk       (clk),
	.rst_n_in  (rst_n),
	.rst_n_out (rst_n_sync)
);

// -----------------------------------------------------------------------------
// Interconnects
// -----------------------------------------------------------------------------

reg clk_en;

wire csr_csauto;
wire csr_cs;
wire csr_loopback;
wire csr_read_en;
wire csr_cpol;
wire csr_cpha;
wire csr_busy;
wire [W_DIV_INT-1:0] div;

wire [W_DATA-1:0]   txfifo_wdata;
wire                txfifo_wen;
wire [W_DATA-1:0]   txfifo_rdata;
wire                txfifo_ren;
wire                txfifo_full;
wire                txfifo_empty;
wire [W_FLEVEL-1:0] txfifo_level;

reg                 rxfifo_wen;
wire [W_DATA-1:0]   rxfifo_rdata;
wire                rxfifo_ren;
wire                rxfifo_full;
wire                rxfifo_empty;
wire [W_FLEVEL-1:0] rxfifo_level;


// -----------------------------------------------------------------------------
// SPI state machine
// -----------------------------------------------------------------------------

localparam W_STATE = 4;
localparam S_IDLE       = 4'h0;
localparam S_DATA_FIRST = 4'h1;
// ...
localparam S_DATA_LAST  = 4'h8;
localparam S_BACKPORCH  = 4'h9; // Space between last SCLK pulse and CS deassertion

reg [W_DATA-1:0] tx_shift;
reg [W_DATA-1:0] rx_shift;
reg cs_r;
reg sclk_r;
wire shift_in = csr_loopback ? sdo : sdi;

reg [W_STATE-1:0] state;

always @ (posedge clk or negedge rst_n_sync) begin
	if (!rst_n_sync) begin
		cs_r <= 1'b1;
		sclk_r <= 1'b0;
		sdo <= 1'b0;
		rxfifo_wen <= 1'b0;
		tx_shift <= {W_DATA{1'b0}};
		rx_shift <= {W_DATA{1'b0}};
		state <= S_IDLE;
	end else if (clk_en) begin
		rxfifo_wen <= 1'b0;
		case (state)
		S_IDLE: begin
			if (!txfifo_empty) begin
				state <= S_DATA_FIRST;
				cs_r <= 1'b0;
				tx_shift <= txfifo_rdata;
				if (!csr_cpha)
					sdo <= txfifo_rdata[W_DATA-1];
			end
		end
		S_DATA_LAST: begin
			sclk_r <= !sclk_r;
			if (sclk_r) begin
				if (txfifo_empty) begin
					state <= S_BACKPORCH;
				end else begin
					state <= S_DATA_FIRST;
					tx_shift <= txfifo_rdata;
					if (!csr_cpha)
						sdo <= txfifo_rdata[W_DATA-1];
				end
				rxfifo_wen <= csr_read_en;
			end
			if (csr_cpha) begin
				if (!sclk_r)
					sdo <= tx_shift[W_DATA-1];
			end
			if (csr_cpha == sclk_r)
				rx_shift <= {rx_shift[W_DATA-2:0], shift_in};
		end
		S_BACKPORCH: begin
			state <= S_IDLE;
			cs_r <= 1'b1;
			sdo <= 1'b0;
		end
		default: begin // Data states (except last)
			sclk_r <= !sclk_r;
			if (sclk_r) begin
				state <= state + 1'b1;
				tx_shift <= tx_shift << 1;
			end
			if (csr_cpha == sclk_r)
				rx_shift <= {rx_shift[W_DATA-2:0], shift_in};
			else
				sdo <= csr_cpha ? tx_shift[W_DATA-1] : tx_shift[W_DATA-2];
		end
		endcase
	end else begin
		rxfifo_wen <= 1'b0;
	end
end

assign csr_busy = state != S_IDLE;
assign txfifo_ren = clk_en && !txfifo_empty && (state == S_IDLE || (state == S_DATA_LAST && sclk_r));

always @ (*)
	if (csr_csauto)
		cs_n = cs_r;
	else
		cs_n = csr_cs;

always @ (*)
	sclk = sclk_r ^ csr_cpol;

// -----------------------------------------------------------------------------
// FIFOs, clock divider and register block
// -----------------------------------------------------------------------------

reg [W_DIV_INT-1:0] clkdiv_ctr;

always @ (posedge clk or negedge rst_n_sync) begin
	if (!rst_n_sync) begin
		clk_en <= 1'b0;
		clkdiv_ctr <= {{W_DIV_INT-1{1'b0}}, 1'b1};
	end else begin
		if (clkdiv_ctr == 1'b1) begin
			clk_en <= 1'b1;
			clkdiv_ctr <= div;
		end else begin
			clk_en <= 1'b0;
			clkdiv_ctr <= clkdiv_ctr - 1'b1;
		end
	end
end

sync_fifo #(
	.DEPTH(FIFO_DEPTH),
	.WIDTH(8)
) txfifo (
	.clk    (clk),
	.rst_n  (rst_n_sync),
	.w_data (txfifo_wdata),
	.w_en   (txfifo_wen),
	.r_data (txfifo_rdata),
	.r_en   (txfifo_ren),
	.full   (txfifo_full),
	.empty  (txfifo_empty),
	.level  (txfifo_level)
);

sync_fifo #(
	.DEPTH(FIFO_DEPTH),
	.WIDTH(8)
) rxfifo (
	.clk    (clk),
	.rst_n  (rst_n_sync),
	.w_data (rx_shift),
	.w_en   (rxfifo_wen),
	.r_data (rxfifo_rdata),
	.r_en   (rxfifo_ren),
	.full   (rxfifo_full),
	.empty  (rxfifo_empty),
	.level  (rxfifo_level)
);

spi_regs regs
(
	.clk             (clk),
	.rst_n           (rst_n_sync),

	.apbs_psel       (apbs_psel),
	.apbs_penable    (apbs_penable),
	.apbs_pwrite     (apbs_pwrite),
	.apbs_paddr      (apbs_paddr),
	.apbs_pwdata     (apbs_pwdata),
	.apbs_prdata     (apbs_prdata),
	.apbs_pready     (apbs_pready),
	.apbs_pslverr    (apbs_pslverr),

	.csr_csauto_o    (csr_csauto),
	.csr_cs_o        (csr_cs),
	.csr_loopback_o  (csr_loopback),
	.csr_read_en_o   (csr_read_en),
	.csr_cpol_o      (csr_cpol),
	.csr_cpha_o      (csr_cpha),
	.csr_busy_i      (csr_busy),
	.div_o           (div),
	.fstat_txlevel_i (txfifo_level | 8'h0),
	.fstat_txfull_i  (txfifo_full),
	.fstat_txempty_i (txfifo_empty),
	.fstat_txover_i  (txfifo_full && txfifo_wen),
	.fstat_rxlevel_i (rxfifo_level | 8'h0),
	.fstat_rxfull_i  (rxfifo_full),
	.fstat_rxempty_i (rxfifo_empty),
	.fstat_rxover_i  (rxfifo_full && rxfifo_wen),
	.fstat_rxunder_i (rxfifo_empty && rxfifo_ren),
	.tx_o            (txfifo_wdata),
	.tx_wen          (txfifo_wen),
	.rx_i            (rxfifo_rdata),
	.rx_ren          (rxfifo_ren)
);

endmodule
