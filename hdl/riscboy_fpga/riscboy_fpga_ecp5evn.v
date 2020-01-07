// Modified FPGA top-level suitable for the TinyFPGA BX

module riscboy_fpga (
	input wire                     clk_osc,

	output wire [7:0]              led

);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys = clk_osc;
wire clk_lcd = clk_sys;
wire rst_n;
wire pll_lock = 1'b1;

fpga_reset #(
	.SHIFT (3),
	.COUNT (200) // need at least 3 us delay before accessing BRAMs on iCE40
) rstgen (
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
	.BOOTRAM_PRELOAD ("bootram_init32.hex")
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

	.lcd_cs      (/* unused */),
	.lcd_dc      (/* unused */),
	.lcd_sck     (/* unused */),
	.lcd_mosi    (/* unused */),

	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin)
);

// GPIO

// TODO this isn't great.
// Ideally we would have an array of tristate_ios and connect up the pads.
// However it seems like there is no way of connecting inout ports together in Verilog
// apart from in the module instantiation???

// tristate_io pad_uart_tx (
// 	.out (padout[PIN_UART_TX]),
// 	.oe  (padoe[PIN_UART_TX]),
// 	.in  (padin[PIN_UART_TX]),
// 	.pad (uart_tx)
// );

// tristate_io pad_uart_rx (
// 	.out (padout[PIN_UART_RX]),
// 	.oe  (padoe[PIN_UART_RX]),
// 	.in  (padin[PIN_UART_RX]),
// 	.pad (uart_rx)
// );

// tristate_io pad_flash_miso (
// 	.out (padout[PIN_FLASH_MISO]),
// 	.oe  (padoe[PIN_FLASH_MISO]),
// 	.in  (padin[PIN_FLASH_MISO]),
// 	.pad (flash_miso)
// );

// tristate_io pad_flash_mosi (
// 	.out (padout[PIN_FLASH_MOSI]),
// 	.oe  (padoe[PIN_FLASH_MOSI]),
// 	.in  (padin[PIN_FLASH_MOSI]),
// 	.pad (flash_mosi)
// );

// tristate_io pad_flash_sclk (
// 	.out (padout[PIN_FLASH_SCLK]),
// 	.oe  (padoe[PIN_FLASH_SCLK]),
// 	.in  (padin[PIN_FLASH_SCLK]),
// 	.pad (flash_sclk)
// );

// tristate_io pad_flash_cs (
// 	.out (padout[PIN_FLASH_CS]),
// 	.oe  (padoe[PIN_FLASH_CS]),
// 	.in  (padin[PIN_FLASH_CS]),
// 	.pad (flash_cs)
// );

// pullup_input in_u (
// 	.in  (padin[PIN_DPAD_U]),
// 	.pad (dpad_u)
// );

// pullup_input in_d (
// 	.in  (padin[PIN_DPAD_D]),
// 	.pad (dpad_d)
// );

// pullup_input in_l (
// 	.in  (padin[PIN_DPAD_L]),
// 	.pad (dpad_l)
// );

// pullup_input in_r (
// 	.in  (padin[PIN_DPAD_R]),
// 	.pad (dpad_r)
// );

// pullup_input in_a (
// 	.in  (padin[PIN_BTN_A]),
// 	.pad (btn_a)
// );

assign led = {
	!padout[PIN_UART_TX],
	!padin[PIN_UART_RX],
	padin[PIN_DPAD_U],
	padin[PIN_DPAD_D],
	padin[PIN_DPAD_L],
	padin[PIN_DPAD_R],
	padin[PIN_BTN_A],
	padout[PIN_LED] && padoe[PIN_LED]
};

endmodule
