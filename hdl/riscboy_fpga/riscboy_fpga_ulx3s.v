// Modified FPGA top-level suitable for the ULX3S

module riscboy_fpga (
	input wire                     clk_osc,

	output wire [7:0]              led,

	inout wire                     uart_tx,
	inout wire                     uart_rx,

	inout wire                     flash_miso,
	inout wire                     flash_mosi,
	// inout wire                     flash_sclk, handled by USRMCLK primitive
	inout wire                     flash_cs,

	output wire                    lcd_cs,
	output wire                    lcd_dc,
	output wire                    lcd_sclk,
	output wire                    lcd_mosi
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys;
wire clk_lcd = clk_sys;
wire rst_n;
wire pll_lock = 1;

assign clk_sys = clk_osc;

fpga_reset por (
	.clk         (clk_sys),
	.force_rst_n (pll_lock),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

localparam N_PADS = N_GPIOS;

wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex"),
	.W_SRAM0_ADDR    (15), // 2**15 words = 128 kiB
	.SRAM0_INTERNAL  (1)   // Instantiate a second internal SRAM bank, rather than external async SRAM controller
) core (
	.clk_sys     (clk_sys),
	.clk_lcd     (clk_lcd),
	.rst_n       (rst_n),

	.sram_addr   (/* unused */),
	.sram_dq     (/* unused */),
	.sram_ce_n   (/* unused */),
	.sram_we_n   (/* unused */),
	.sram_oe_n   (/* unused */),
	.sram_byte_n (/* unused */),

	.lcd_cs      (lcd_cs),
	.lcd_dc      (lcd_dc),
	.lcd_sck     (lcd_sclk),
	.lcd_mosi    (lcd_mosi),

	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin)
);

// GPIO
// TODO hook up UART, SPI etc
tristate_io pads [4:0] (
	.out ({padout[PIN_UART_TX], padout[PIN_UART_RX], padout[PIN_FLASH_MISO], padout[PIN_FLASH_MOSI], padout[PIN_FLASH_CS]}),
	.oe  ({padoe [PIN_UART_TX], padoe [PIN_UART_RX], padoe [PIN_FLASH_MISO], padoe [PIN_FLASH_MOSI], padoe [PIN_FLASH_CS]}),
	.in  ({padin [PIN_UART_TX], padin [PIN_UART_RX], padin [PIN_FLASH_MISO], padin [PIN_FLASH_MOSI], padin [PIN_FLASH_CS]}),
	.pad ({uart_tx, uart_rx, flash_miso, flash_mosi, flash_cs})
);


// Lattice describes USRMCLKTS as an active-high output disable, i.e. active-low enable
USRMCLK pad_sclk(
	.USRMCLKI  (padout[PIN_FLASH_SCLK]),
	.USRMCLKTS (!padoe[PIN_FLASH_SCLK])
);

wire blink;

blinky #(
	.CLK_HZ   (12_000_000),
	.BLINK_HZ (1),
	.FANCY    (0)
) blinky_u (
	.clk   (clk_osc),
	.blink (blink)
);

assign led = {
	!padout[PIN_UART_TX],
	!padin[PIN_UART_RX],
	4'h0,
	blink,
	padout[PIN_LED] && padoe[PIN_LED]
};

endmodule
