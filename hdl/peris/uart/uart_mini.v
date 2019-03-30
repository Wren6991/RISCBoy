// Simple UART for FPGABoy

// - APB slave interface
// - 8 data bits, 1 stop bit, 1 start bit ONLY
// - fractional clock divider (16:8 by default; changing requires regblock update)
// - parameterised FIFOs with interrupts, sticky overflow/underflow status
// - "minimum viable UART"

module uart_mini #(
	parameter FIFO_DEPTH = 2, // must be power of 2, >= 2
	parameter OVERSAMPLE = 8  // must be power of 2, >= 4
) (
	input wire clk,
	input wire rst_n,

	// APB Port
	input wire apbs_psel,
	input wire apbs_penable,
	input wire apbs_pwrite,
	input wire [15:0] apbs_paddr,
	input wire [31:0] apbs_pwdata,
	output wire [31:0] apbs_prdata,
	output wire apbs_pready,
	output wire apbs_pslverr,

	input wire rx,
	output reg tx,

	output wire irq,
	output wire dreq
);

parameter W_FLEVEL = $clog2(FIFO_DEPTH + 1);
parameter W_OVER = $clog2(OVERSAMPLE);

// 10 bits with 8x oversample will get us from a 72 MHz sysclk
// to a little below 9600 baud. Who cares about slower speeds
localparam W_DIV_INT = 10;
localparam W_DIV_FRAC = 8;


wire [7:0]          txfifo_wdata;
wire                txfifo_wen;
wire [7:0]          txfifo_rdata;
wire                txfifo_ren;
wire                txfifo_full;
wire                txfifo_empty;
wire [W_FLEVEL-1:0] txfifo_level;

reg                 rxfifo_wen;
wire [7:0]          rxfifo_rdata;
wire                rxfifo_ren;
wire                rxfifo_full;
wire                rxfifo_empty;
wire [W_FLEVEL-1:0] rxfifo_level;

wire csr_en;
wire csr_txie;
wire csr_rxie;
assign irq = (csr_txie && !txfifo_full) || (csr_rxie && !rxfifo_empty);
assign dreq = irq;

wire clk_en;

// ================
// TX State Machine
// ================

reg [W_OVER-1:0] tx_over_ctr;
reg [3:0] tx_state;
reg [7:0] tx_shifter;

localparam TX_IDLE = 0;
localparam TX_START = 1;
// 2...9 are data states
localparam TX_STOP = 10;

wire tx_busy = tx_state != TX_IDLE || !txfifo_empty;
assign txfifo_ren = clk_en && !txfifo_empty && !tx_over_ctr &&
	(tx_state == TX_IDLE || tx_state == TX_STOP);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tx <= 1'b1;
		tx_over_ctr <= {W_OVER{1'b0}};
		tx_state <= TX_IDLE;
		tx_shifter <= 8'h0;
	end else if (!csr_en) begin
		// Put TX into synchronous reset when disabled.
		tx <= 1'b1;
		tx_over_ctr <= {W_OVER{1'b0}};
		tx_state <= TX_IDLE;
		tx_shifter <= 8'h0;
	end else begin
		if (clk_en)
			tx_over_ctr <= tx_over_ctr + 1'b1;
		if (clk_en && !tx_over_ctr) begin
			tx_state <= tx_state + 1'b1;
			case (tx_state)
			TX_IDLE: begin
				if (txfifo_empty) begin
					// Hold counter whilst idle, so we respond immediately
					tx_over_ctr <= {W_OVER{1'b0}};
					tx_state <= TX_IDLE;
				end else begin
					tx_shifter <= txfifo_rdata;
					tx <= 1'b0;
				end
			end
			TX_START: begin
				tx_shifter <= tx_shifter >> 1;
				tx <= tx_shifter[0];
			end
			TX_STOP: begin
				if (txfifo_empty) begin
					tx_state <= TX_IDLE;
					tx_over_ctr <= {W_OVER{1'b0}};
				end else begin
					tx_shifter <= txfifo_rdata;
					tx_state <= TX_START;
					tx <= 1'b0;
				end
			end
			default: begin
				// Data states
				tx_shifter <= tx_shifter >> 1;
				if (tx_state == TX_STOP - 1) begin
					tx <= 1'b1;
				end else begin
					tx <= tx_shifter[0];
				end
			end
			endcase
		end
	end
end

// ================
// RX State Machine
// ================

reg [W_OVER-1:0] rx_over_ctr;
reg [3:0] rx_state;
reg [7:0] rx_shifter;

localparam RX_IDLE = 0;
localparam RX_START1 = 1; // 1 bit period
localparam RX_START2 = 2; // 0.5 bit periods
// 3...10 are data states
localparam RX_STOP = 11;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		rx_over_ctr <= {W_OVER{1'b0}};
		rx_state <= RX_IDLE;
		rx_shifter <= 8'h0;
		rxfifo_wen <= 1'b0;
	end else if (!csr_en) begin
		rx_over_ctr <= {W_OVER{1'b0}};
		rx_state <= RX_IDLE;
		rx_shifter <= 8'h0;
		rxfifo_wen <= 1'b0;
	end else begin
		rxfifo_wen <= 1'b0;
		if (clk_en)
			rx_over_ctr <= rx_over_ctr + 1'b1;
		if (clk_en && !rx_over_ctr) begin
			rx_state <= rx_state + 1'b1;
			case (rx_state)
			RX_IDLE: begin
				if (!rx) begin
					rx_state <= RX_START1;
				end else begin
					// Hold oversample counter to maintain readiness
					rx_over_ctr <= {W_OVER{1'b0}};
				end
			end
			RX_START1: begin
				rx_over_ctr <= OVERSAMPLE / 2;	// shorten next state by 1/2
			end
			RX_START2: begin
				rx_shifter <= (rx_shifter >> 1) | (rx << 7);
			end
			RX_STOP: begin
				// Nothing to do here
			end
			default: begin
				// Data states
				if (rx_state == RX_STOP - 1) begin
					// shorten next state; we've been sampling in the middle of bit periods, now get back to edge.
					rx_over_ctr <= OVERSAMPLE / 2 + 1;
					// Don't push if there is no valid stop bit
					rxfifo_wen <= rx;
				end else begin
					rx_shifter <= (rx_shifter >> 1) | (rx << 7);
				end
			end
			endcase
		end
	end
end

// =================================
// FIFOs, Clock Divider and Regblock
// =================================

wire [W_DIV_INT-1:0]  div_int;
wire [W_DIV_FRAC-1:0] div_frac;

clkdiv_frac #(
	.W_DIV_INT(W_DIV_INT),
	.W_DIV_FRAC(W_DIV_FRAC)
) inst_clkdiv_frac (
	.clk      (clk),
	.rst_n    (rst_n),
	.en       (csr_en),
	.div_int  (div_int),
	.div_frac (div_frac),
	.clk_en   (clk_en)
);

sync_fifo #(
	.DEPTH(FIFO_DEPTH),
	.WIDTH(8)
) txfifo (
	.clk    (clk),
	.rst_n  (rst_n),
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
	.rst_n  (rst_n),
	.w_data (rx_shifter),
	.w_en   (rxfifo_wen),
	.r_data (rxfifo_rdata),
	.r_en   (rxfifo_ren),
	.full   (rxfifo_full),
	.empty  (rxfifo_empty),
	.level  (rxfifo_level)
);

uart_regs regs (
	.clk             (clk),
	.rst_n           (rst_n),

	.apbs_psel       (apbs_psel),
	.apbs_penable    (apbs_penable),
	.apbs_pwrite     (apbs_pwrite),
	.apbs_paddr      (apbs_paddr),
	.apbs_pwdata     (apbs_pwdata),
	.apbs_prdata     (apbs_prdata),
	.apbs_pready     (apbs_pready),
	.apbs_pslverr    (apbs_pslverr),

	.csr_en_o        (csr_en),
	.csr_busy_i      (tx_busy),
	.csr_txie_o      (csr_txie),
	.csr_rxie_o      (csr_rxie),
	.div_int_o       (div_int),
	.div_frac_o      (div_frac),
	.fstat_txlevel_i (txfifo_level | 8'h0),
	.fstat_txfull_i  (txfifo_full),
	.fstat_txempty_i (txfifo_empty),
	.fstat_txover_i  (txfifo_full && txfifo_wen),
	.fstat_txunder_i (txfifo_empty && txfifo_ren),
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