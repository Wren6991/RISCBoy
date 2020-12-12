module riscboy_fpga (
	input  wire                     clk_osc,

	output wire [7:0]               led,

	output wire                     uart_tx,
	input  wire                     uart_rx,
	output wire                     uart_rts,
	input  wire                     uart_cts,

	input  wire                     dpad_u,
	input  wire                     dpad_d,
	input  wire                     dpad_l,
	input  wire                     dpad_r,
	input  wire                     btn_a,

	input  wire                     flash_miso,
	output wire                     flash_mosi,
	output wire                     flash_sclk,
	output wire                     flash_cs,

	output wire                     lcd_cs,
	output wire                     lcd_dc,
	output wire                     lcd_sclk,
	output wire                     lcd_mosi,

	output wire [W_SRAM0_ADDR-1:0] sram_addr,
	inout  wire [15:0]             sram_dq,
	// output wire                    sram_ce_n,  Tied to ground externally. See PCF file
	output wire                    sram_we_n,
	output wire                    sram_oe_n,
	output wire [1:0]              sram_byte_n
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys;
wire clk_lcd = clk_sys;
wire rst_n;
wire pll_lock;

pll_12_36 pll (
	.clock_in  (clk_osc),
	.clock_out (clk_sys),
	.locked    (pll_lock)
);

fpga_reset #(
	.SHIFT (3),
	.COUNT (200) // need at least 3 us delay before accessing BRAMs on iCE40
) rstgen (
	.clk         (clk_sys),
	.force_rst_n (pll_lock),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

localparam W_SRAM0_ADDR = 18;
localparam N_PADS = N_GPIOS;

wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex")
) core (
	.clk_sys     (clk_sys),
	.clk_lcd_pix (1'b0), // unused for SPI display
	.clk_lcd_bit (clk_lcd),
	.rst_n       (rst_n),

	.lcd_pwm     (/* unused */),

	.uart_tx     (uart_tx),
	.uart_rx     (uart_rx),
	.uart_rts    (uart_rts),
	.uart_cts    (uart_cts),

	.spi_sclk    (flash_sclk),
	.spi_cs      (flash_cs),
	.spi_sdo     (flash_mosi),
	.spi_sdi     (flash_miso),

	.sram_addr   (sram_addr),
	.sram_dq     (sram_dq),
	.sram_ce_n   (sram_ce_n),
	.sram_we_n   (sram_we_n),
	.sram_oe_n   (sram_oe_n),
	.sram_byte_n (sram_byte_n),

	.lcdp        ({lcd_cs, lcd_dc, lcd_sclk, lcd_mosi}),

	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin)
);

// GPIO

pullup_input in_u (
	.in  (padin[PIN_DPAD_U]),
	.pad (dpad_u)
);

pullup_input in_d (
	.in  (padin[PIN_DPAD_D]),
	.pad (dpad_d)
);

pullup_input in_l (
	.in  (padin[PIN_DPAD_L]),
	.pad (dpad_l)
);

pullup_input in_r (
	.in  (padin[PIN_DPAD_R]),
	.pad (dpad_r)
);

pullup_input in_a (
	.in  (padin[PIN_BTN_A]),
	.pad (btn_a)
);

assign led = {
	!uart_tx,
	!uart_rx,
	padin[PIN_DPAD_U],
	padin[PIN_DPAD_D],
	padin[PIN_DPAD_L],
	padin[PIN_DPAD_R],
	padin[PIN_BTN_A],
	padout[PIN_LED] && padoe[PIN_LED]
};

endmodule
