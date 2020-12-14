module riscboy_fpga (
	input wire        clk_osc,

	output wire [6:0] led,

	output wire       uart_tx,
	input  wire       uart_rx,

	input  wire       dpad_u,
	input  wire       dpad_d,
	input  wire       dpad_l,
	input  wire       dpad_r,

	input  wire       flash_miso,
	output wire       flash_mosi,
	output wire       flash_sclk,
	output wire       flash_cs,

	output wire       lcd_cs,
	output wire       lcd_dc,
	output wire       lcd_sclk,
	output wire       lcd_mosi,
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys;
wire clk_lcd;
wire rst_n;
wire pll_lock;

SB_HFOSC #(
  .CLKHF_DIV ("0b10") // divide by 4 -> 12 MHz
) inthosc (
  .CLKHFPU (1'b1),
  .CLKHFEN (1'b1),
  .CLKHF   (clk_sys)
);

pll_12_36 #(
	.ICE40_PAD (1)
) pll_lcd (
	.clock_in  (clk_osc),
	.clock_out (clk_lcd),
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
	.BOOTRAM_PRELOAD   ("bootram_init32.hex"),
	.SRAM0_INTERNAL    (1),
	.W_SRAM0_ADDR      (15), // 2**15 words = 128 kB

	.CUTDOWN_PROCESSOR (1),
	.STUB_SPI          (1),
	.STUB_PWM          (1),
	.UART_FIFO_DEPTH   (2)
) core (
	.clk_sys     (clk_sys),
	.clk_lcd_pix (1'b0), // unused for SPI display
	.clk_lcd_bit (clk_lcd),
	.rst_n       (rst_n),

	.lcd_pwm     (/* unused */),

	.uart_tx     (uart_tx),
	.uart_rx     (uart_rx),
	.uart_rts    (/* unused */),
	.uart_cts    (/* unused */),

	.spi_sclk    (flash_sclk),
	.spi_cs      (flash_cs),
	.spi_sdo     (flash_mosi),
	.spi_sdi     (flash_miso),

	.sram_addr   (/* unused */),
	.sram_dq     (/* unused */),
	.sram_ce_n   (/* unused */),
	.sram_we_n   (/* unused */),
	.sram_oe_n   (/* unused */),
	.sram_byte_n (/* unused */),

	.lcdp        ({lcd_cs, lcd_dc, lcd_sclk, lcd_mosi}),

	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin)
);

// Button on main board is inverted, but buttons on snapoff are not.

pullup_input #(
	.INVERT (0)
) in_u (
	.in  (padin[PIN_DPAD_U]),
	.pad (dpad_u)
);

pullup_input #(
	.INVERT(0)
) in_d (
	.in  (padin[PIN_DPAD_D]),
	.pad (dpad_d)
);

pullup_input #(
	.INVERT (1)
) in_l (
	.in  (padin[PIN_DPAD_L]),
	.pad (dpad_l)
);

pullup_input #(
	.INVERT(0)
) in_r (
	.in  (padin[PIN_DPAD_R]),
	.pad (dpad_r)
);

assign led = {
	!uart_tx,
	!uart_rx,
	padin[PIN_DPAD_U],
	padin[PIN_DPAD_D],
	padin[PIN_DPAD_L],
	// LEDs on main board are inverted:
	!padin[PIN_DPAD_R],
	!(padout[PIN_LED] && padoe[PIN_LED])
};

endmodule
