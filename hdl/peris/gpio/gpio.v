// GPIO module for FPGABoy
// APB master can bitbash, and control muxing of peripheral onto pad.

module gpio #(
	parameter N_PADS  = 16
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
	input wire spi_sclk,
	input wire spi_cs,
	input wire spi_sdo,
	output wire spi_sdi
);

`include "gpio_pinmap.vh"

localparam W_FSEL = 1;
localparam N_FSELS = 1 << W_FSEL;

wire [W_FSEL-1:0] fsel [0:N_PADS-1];

// Output muxing

wire [N_PADS-1:0] proc_out;
wire [N_PADS-1:0] proc_oe;

always @ (*) begin: gpio_mux
	integer i;
	for (i = 0; i < N_PADS; i = i + 1) begin
		if (fsel[i] == 1'b0) begin
			padout[i] = proc_out[i];
			padoe[0] = proc_oe[i];
		end else case (i)
			PIN_UART_TX    : begin padout[i] = uart_tx;  padoe[i] = 1'b1; end
			PIN_FLASH_CS   : begin padout[i] = spi_cs;   padoe[i] = 1'b1; end
			PIN_FLASH_SCLK : begin padout[i] = spi_sclk; padoe[i] = 1'b1; end
			PIN_FLASH_MOSI : begin padout[i] = spi_sdo;  padoe[i] = 1'b1; end
			PIN_LCD_PWM    : begin padout[i] = lcd_pwm;  padoe[i] = 1'b1; end
			default        : begin                       padoe[i] = 1'b0; end
		endcase
	end
end

// Register inputs before sending to processor

reg [N_PADS-1:0] padin_reg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		padin_reg <= {N_PADS{1'b0}};
	end else begin
		padin_reg <= padin;
	end
end

// Input assignments (TODO: multi-source input muxing? When needed)

assign uart_rx = padin_reg[PIN_UART_RX]; // UART isn't going to mind an extra clock of latency!
assign spi_sdi = padin[PIN_FLASH_MISO];  // SPI certainly will though

// APB Regblock

gpio_regs inst_gpio_regs
(
	.clk          (clk),
	.rst_n        (rst_n),
	.apbs_psel    (apbs_psel),
	.apbs_penable (apbs_penable),
	.apbs_pwrite  (apbs_pwrite),
	.apbs_paddr   (apbs_paddr),
	.apbs_pwdata  (apbs_pwdata),
	.apbs_prdata  (apbs_prdata),
	.apbs_pready  (apbs_pready),
	.apbs_pslverr (apbs_pslverr),
	.out_o        (proc_out),
	.dir_o        (proc_oe),
	.in_i         (padin_reg),
	.fsel0_p0_o   (fsel[0 ]),
	.fsel0_p1_o   (fsel[1 ]),
	.fsel0_p2_o   (fsel[2 ]),
	.fsel0_p3_o   (fsel[3 ]),
	.fsel0_p4_o   (fsel[4 ]),
	.fsel0_p5_o   (fsel[5 ]),
	.fsel0_p6_o   (fsel[6 ]),
	.fsel0_p7_o   (fsel[7 ]),
	.fsel0_p8_o   (fsel[8 ]),
	.fsel0_p9_o   (fsel[9 ]),
	.fsel0_p10_o  (fsel[10]),
	.fsel0_p11_o  (fsel[11]),
	.fsel0_p12_o  (fsel[12]),
	.fsel0_p13_o  (fsel[13]),
	.fsel0_p14_o  (fsel[14]),
	.fsel0_p15_o  (fsel[15])
);

endmodule