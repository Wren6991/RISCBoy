module riscboy_fpga (
	input wire                     clk_osc,

	output wire [6:0]              led,

	inout wire                     uart_tx,
	inout wire                     uart_rx,

	inout wire                     dpad_u,
	inout wire                     dpad_d,
	inout wire                     dpad_l,
	inout wire                     dpad_r,

	inout wire                     flash_miso,
	inout wire                     flash_mosi,
	inout wire                     flash_sclk,
	inout wire                     flash_cs,

	output wire                    lcd_cs,
	output wire                    lcd_dc,
	output wire                    lcd_sclk,
	output wire                    lcd_mosi,
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys = clk_osc;
wire clk_lcd = clk_osc;
wire rst_n;
wire pll_lock = 1'b1;

// pll_12_36 pll (
// 	.clock_in  (clk_osc),
// 	.clock_out (clk_sys),
// 	.locked    (pll_lock)
// );

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
	.BOOTRAM_PRELOAD ("bootram_init32.hex"),
	.CUTDOWN_PROCESSOR (1),
	.STUB_SPI (1),
	.STUB_PWM (1)
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

// TODO this isn't great.
// Ideally we would have an array of tristate_ios and connect up the pads.
// However it seems like there is no way of connecting inout ports together in Verilog
// apart from in the module instantiation???

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

// TODO these are shared with PMOD pins on icebreaker, and they aren't critical
// tristate_io pad_uart_rts (
// 	.out (padout[PIN_UART_RTS]),
// 	.oe  (padoe[PIN_UART_RTS]),
// 	.in  (padin[PIN_UART_RTS]),
// 	.pad (uart_rts)
// );

// tristate_io pad_uart_cts (
// 	.out (padout[PIN_UART_CTS]),
// 	.oe  (padoe[PIN_UART_CTS]),
// 	.in  (padin[PIN_UART_CTS]),
// 	.pad (uart_cts)
// );

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
	!padout[PIN_UART_TX],
	!padin[PIN_UART_RX],
	padin[PIN_DPAD_U],
	padin[PIN_DPAD_D],
	padin[PIN_DPAD_L],
	// LEDs on main board are inverted:
	!padin[PIN_DPAD_R],
	!(padout[PIN_LED] && padoe[PIN_LED])
};

endmodule
