// Modified FPGA top-level suitable for the TinyFPGA BX

module riscboy_fpga (
	input wire clk_osc,

	output wire led,

	inout wire uart_tx,
	inout wire uart_rx,

	inout wire lcd_cs,
	inout wire lcd_dc,
	inout wire lcd_sclk,
	inout wire lcd_mosi,
	inout wire lcd_pwm,
	inout wire lcd_rst,

	inout wire flash_miso,
	inout wire flash_mosi,
	inout wire flash_sclk,
	inout wire flash_cs
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys;
wire rst_n;
wire pll_lock;

pll_16_24 pll (
	.clock_in  (clk_osc), // 16 MHz external oscillator
	.clock_out (clk_sys),
	.locked    (pll_lock)
);

fpga_reset #(
	.SHIFT (3),
	.COUNT (200) // need at least 3 us delay before accessing BRAMs on iCE40
) rstgen (
	.clk         (clk_osc),
	.force_rst_n (pll_lock),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

localparam N_PADS = N_GPIOS;
wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex")
) core (
	.clk_sys (clk_sys),
	.clk_lcd (clk_sys),
	.rst_n   (rst_n),

	.sram_addr   (/* unused */),
	.sram_dq     (            ),
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

tristate_io pad_uart_tx (
	.out (padout[PIN_UART_TX]),
	.oe  (padoe[PIN_UART_TX]),
	.in  (padin[PIN_UART_TX]),
	.pad (uart_tx)
);

tristate_io pad_uart_rx (
	.out (padout[PIN_UART_RX]),
	.oe  (padoe[PIN_UART_RX]),
	.in  (padin[PIN_UART_RX]),
	.pad (uart_rx)
);

tristate_io pad_flash_miso (
	.out (padout[PIN_FLASH_MISO]),
	.oe  (padoe[PIN_FLASH_MISO]),
	.in  (padin[PIN_FLASH_MISO]),
	.pad (flash_miso)
);

tristate_io pad_flash_mosi (
	.out (padout[PIN_FLASH_MOSI]),
	.oe  (padoe[PIN_FLASH_MOSI]),
	.in  (padin[PIN_FLASH_MOSI]),
	.pad (flash_mosi)
);

tristate_io pad_flash_sclk (
	.out (padout[PIN_FLASH_SCLK]),
	.oe  (padoe[PIN_FLASH_SCLK]),
	.in  (padin[PIN_FLASH_SCLK]),
	.pad (flash_sclk)
);

tristate_io pad_flash_cs (
	.out (padout[PIN_FLASH_CS]),
	.oe  (padoe[PIN_FLASH_CS]),
	.in  (padin[PIN_FLASH_CS]),
	.pad (flash_cs)
);

tristate_io pad_led (
	.out (padout[PIN_LED]),
	.oe  (padoe[PIN_LED]),
	.in  (padin[PIN_LED]),
	.pad (led)
);

endmodule
