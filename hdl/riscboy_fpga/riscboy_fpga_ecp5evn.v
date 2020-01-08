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
// TODO hook up UART, SPI etc
assign led = ~padout[7:0];
assign padin = 0;

endmodule
