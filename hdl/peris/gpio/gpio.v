// GPIO module for FPGABoy
// APB master can bitbash, and control muxing of peripheral onto pad.

module gpio #(
	parameter N_PADS = 25
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

	output reg [N_PADS-1:0] padout,
	output reg [N_PADS-1:0] padoe,
	input wire [N_PADS-1:0] padin,

	// Peripheral signals

	input wire lcd_pwm,
	input wire uart_tx,
	output wire uart_rx,
	input wire uart_rts,
	output wire uart_cts,
	input wire spi_sclk,
	input wire spi_cs,
	input wire spi_sdo,
	output wire spi_sdi
);

`include "gpio_pinmap.vh"

wire rst_n_sync;

reset_sync #(
	.N_CYCLES (2)
) inst_reset_sync (
	.clk       (clk),
	.rst_n_in  (rst_n),
	.rst_n_out (rst_n_sync)
);

localparam W_FSEL = 1;
localparam N_FSELS = 1 << W_FSEL;

wire [W_FSEL*N_PADS-1:0] fsel_packed;
wire [W_FSEL-1:0] fsel [0:N_PADS-1];

genvar g;
generate
for (g = 0; g < N_PADS; g = g + 1) begin: fsel_unpack
	assign fsel[g] = fsel_packed[g * W_FSEL +: W_FSEL];
end
endgenerate

// Output muxing

wire [N_PADS-1:0] proc_out;
wire [N_PADS-1:0] proc_oe;

always @ (*) begin: gpio_mux
	integer i;
	for (i = 0; i < N_PADS; i = i + 1) begin
		if (fsel[i] == 1'b0) begin
			padout[i] = proc_out[i];
			padoe[i] = proc_oe[i];
		end else case (i)
			PIN_UART_TX    : begin padout[i] = uart_tx;  padoe[i] = 1'b1; end
			PIN_UART_RTS   : begin padout[i] = uart_rts; padoe[i] = 1'b1; end
			PIN_FLASH_CS   : begin padout[i] = spi_cs;   padoe[i] = 1'b1; end
			PIN_FLASH_SCLK : begin padout[i] = spi_sclk; padoe[i] = 1'b1; end
			PIN_FLASH_MOSI : begin padout[i] = spi_sdo;  padoe[i] = 1'b1; end
			PIN_LCD_PWM    : begin padout[i] = lcd_pwm;  padoe[i] = 1'b1; end
			default        : begin padout[i] = 1'b0;     padoe[i] = 1'b0; end
		endcase
	end
end

// Register inputs before sending to processor

reg [N_PADS-1:0] padin_reg;

always @ (posedge clk or negedge rst_n_sync) begin
	if (!rst_n_sync) begin
		padin_reg <= {N_PADS{1'b0}};
	end else begin
		padin_reg <= padin;
	end
end

// Input assignments (TODO: multi-source input muxing? When needed)

assign uart_rx = padin_reg[PIN_UART_RX]; // UART isn't going to mind an extra clock of latency!
assign uart_cts = padin_reg[PIN_UART_CTS];
assign spi_sdi = padin[PIN_FLASH_MISO];  // SPI certainly will though

// APB Regblock

gpio_regs inst_gpio_regs
(
	.clk           (clk),
	.rst_n         (rst_n_sync),
	.apbs_psel     (apbs_psel),
	.apbs_penable  (apbs_penable),
	.apbs_pwrite   (apbs_pwrite),
	.apbs_paddr    (apbs_paddr),
	.apbs_pwdata   (apbs_pwdata),
	.apbs_prdata   (apbs_prdata),
	.apbs_pready   (apbs_pready),
	.apbs_pslverr  (apbs_pslverr),
	.out_o         (proc_out),
	.dir_o         (proc_oe),
	.in_i          (padin_reg),
	.concat_fsel_o (fsel_packed)
);

endmodule
