// Modified FPGA top-level suitable for the ULX3S, with DVI video output

module riscboy_fpga (
	input  wire       clk_osc,

	output wire [7:0] led,

	output wire       uart_tx,
	input  wire       uart_rx,

	// DPad is ULX3S direction buttons, A is fire 2, B is fire 1
	input  wire       dpad_u,
	input  wire       dpad_d,
	input  wire       dpad_l,
	input  wire       dpad_r,
	input  wire       btn_a,
	input  wire       btn_b,
	// POWERn button used as global reset
	input  wire       btn_rst_n,

	input  wire       flash_miso,
	output wire       flash_mosi,
	output wire       flash_cs,

	// Differential display interface. 3 LSBs are TMDS 0, 1, 2. MSB is clock channel.
	output wire [3:0] gpdi_dp,
	output wire [3:0] gpdi_dn,

	// Serial display interface
	output wire       lcd_cs,
	output wire       lcd_dc,
	output wire       lcd_sclk,
	output wire       lcd_mosi
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire rst_n;
wire clk_sys;
wire clk_pix = clk_osc;
wire clk_bit;

wire pll_lock_sys;
wire pll_lock_bit;

pll_25_50 pll_sys (
	.clkin   (clk_osc),
	.clkout0 (clk_sys),
	.locked  (pll_lock_sys)
);

pll_25_125 pll_bit (
	.clkin   (clk_osc),
	.clkout0 (clk_bit),
	.locked  (pll_lock_bit)
);

fpga_reset por (
	.clk         (clk_sys),
	.force_rst_n (pll_lock_bit && pll_lock_sys && btn_rst_n),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

localparam N_PADS = N_GPIOS;

wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

// SCLK needs to be connected via a USERMCLK primitive on ECP5
wire flash_sclk;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex"),
	.W_SRAM0_ADDR    (15), // 2**15 words = 128 kiB
	.SRAM0_INTERNAL  (1),  // Instantiate a second internal SRAM bank, rather than external async SRAM controller
	.DISPLAY_TYPE    ("DVI")
) core (
	.clk_sys     (clk_sys),
	.clk_lcd_pix (clk_pix),
	.clk_lcd_bit (clk_bit),
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

	.lcdp        (gpdi_dp),
	.lcdn        (gpdi_dn),

	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin)
);

// Lattice describes USRMCLKTS as an active-high output disable, i.e. active-low enable
USRMCLK pad_sclk(
	.USRMCLKI  (flash_sclk),
	.USRMCLKTS (1'b0)
);

wire blink;

blinky #(
	.CLK_HZ   (25_000_000),
	.BLINK_HZ (1),
	.FANCY    (0)
) blinky_u (
	.clk   (clk_osc),
	.blink (blink)
);

pullup_input #(
	.INVERT (0)
) button_pads[5:0] (
	.in({
		padin[PIN_DPAD_U],
		padin[PIN_DPAD_D],
		padin[PIN_DPAD_L],
		padin[PIN_DPAD_R],
		padin[PIN_BTN_A],
		padin[PIN_BTN_B]
	}),
	.pad({
		dpad_u,
		dpad_d,
		dpad_l,
		dpad_r,
		btn_a,
		btn_b
	})
);

assign led = {
	!uart_tx,
	!uart_rx,
	4'h0,
	blink,
	padout[PIN_LED] && padoe[PIN_LED]
};

endmodule
