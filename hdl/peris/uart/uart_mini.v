module uart_mini #(
	parameter FIFO_DEPTH = 4
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
	output reg tx
);

wire [7:0] txfifo_wdata;
wire       txfifo_wen;
wire [7:0] txfifo_rdata;
wire       txfifo_ren;
wire       txfifo_full;
wire       txfifo_empty;
wire [7:0] txfifo_level;

wire [7:0] rxfifo_wdata;
wire       rxfifo_wen;
wire [7:0] rxfifo_rdata;
wire       rxfifo_ren;
wire       rxfifo_full;
wire       rxfifo_empty;
wire [7:0] rxfifo_level;



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
	.w_data (rxfifo_wdata),
	.w_en   (rxfifo_wen),
	.r_data (rxfifo_rdata),
	.r_en   (rxfifo_ren),
	.full   (rxfifo_full),
	.empty  (rxfifo_empty),
	.level  (rxfifo_level)
);

uart_regs regs
(
	.clk            (clk),
	.rst_n          (rst_n),
	.apbs_psel      (apbs_psel),
	.apbs_penable   (apbs_penable),
	.apbs_pwrite    (apbs_pwrite),
	.apbs_paddr     (apbs_paddr),
	.apbs_pwdata    (apbs_pwdata),
	.apbs_prdata    (apbs_prdata),
	.apbs_pready    (apbs_pready),
	.apbs_pslverr   (apbs_pslverr),
	.csr_en_o       (csr_en_o),
	.csr_busy_i     (csr_busy_i),
	.csr_txie_o     (csr_txie_o),
	.csr_rxie_o     (csr_rxie_o),
	.div_int_o      (div_int_o),
	.div_frac_o     (div_frac_o),
	.tfstat_level_i (txfifo_level),
	.tfstat_full_i  (txfifo_full),
	.tfstat_empty_i (txfifo_empty),
	.rfstat_level_i (rxfifo_level),
	.rfstat_full_i  (rxfifo_full),
	.rfstat_empty_i (rxfifo_empty),
	.tx__o          (txfifo_wdata),
	.tx__wen        (txfifo_wen),
	.rx__i          (rxfifo_rdata),
	.rx__ren        (rxfifo)
);

endmodule