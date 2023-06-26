`default_nettype none

module riscboy_fpga (
	input  wire                    clk_osc,

	output wire [7:0]              led,

	output wire                    uart_tx,
	input  wire                    uart_rx,
	output wire                    uart_rts,
	input  wire                    uart_cts,

	input  wire                    dpad_u,
	input  wire                    dpad_d,
	input  wire                    dpad_l,
	input  wire                    dpad_r,
	input  wire                    btn_a,

	input  wire                    flash_miso,
	output wire                    flash_mosi,
	output wire                    flash_sclk,
	output wire                    flash_cs,

	output wire                    lcd_cs,
	output wire                    lcd_dc,
	output wire                    lcd_sclk,
	output wire                    lcd_mosi,

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

pll_12_48 pll (
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
localparam W_SRAM0_DATA = 16;
localparam N_PADS = N_GPIOS;

wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

wire                      sramphy_clk;
wire                      sramphy_rst_n;
wire [W_SRAM0_ADDR-1:0]   sramphy_addr;
wire [W_SRAM0_DATA-1:0]   sramphy_dq_out;
wire [W_SRAM0_DATA-1:0]   sramphy_dq_oe;
wire [W_SRAM0_DATA-1:0]   sramphy_dq_in;
wire                      sramphy_ce_n;
wire                      sramphy_we_n;
wire                      sramphy_oe_n;
wire [W_SRAM0_DATA/8-1:0] sramphy_byte_n;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex")
) core (
	.clk_sys        (clk_sys),
	.clk_lcd_pix    (1'b0), // unused for SPI display
	.clk_lcd_bit    (clk_lcd),
	.rst_n          (rst_n),

	.lcd_pwm        (/* unused */),

	.uart_tx        (uart_tx),
	.uart_rx        (uart_rx),
	.uart_rts       (uart_rts),
	.uart_cts       (uart_cts),

	.spi_sclk       (flash_sclk),
	.spi_cs         (flash_cs),
	.spi_sdo        (flash_mosi),
	.spi_sdi        (flash_miso),

	.sram_phy_clk   (sramphy_clk),
	.sram_phy_rst_n (sramphy_rst_n),
	.sram_addr      (sramphy_addr),
	.sram_dq_out    (sramphy_dq_out),
	.sram_dq_oe     (sramphy_dq_oe),
	.sram_dq_in     (sramphy_dq_in),
	.sram_ce_n      (sramphy_ce_n),
	.sram_we_n      (sramphy_we_n),
	.sram_oe_n      (sramphy_oe_n),
	.sram_byte_n    (sramphy_byte_n),

	.tbio_paddr     (/* unused */),
	.tbio_psel      (/* unused */),
	.tbio_penable   (/* unused */),
	.tbio_pwrite    (/* unused */),
	.tbio_pwdata    (/* unused */),
	.tbio_pready    (1'b1),
	.tbio_pslverr   (1'b0),
	.tbio_prdata    (32'h0),

	.lcdp           ({lcd_cs, lcd_dc, lcd_sclk, lcd_mosi}),

	.padout         (padout),
	.padoe          (padoe),
	.padin          (padin)
);

// SRAM PHY

async_sram_phy #(
	.W_ADDR     (W_SRAM0_ADDR),
	.W_DATA     (W_SRAM0_DATA),
	.DQ_SYNC_IN (1)
) sram_phy_u (
	.clk         (sramphy_clk),
	.rst_n       (sramphy_rst_n),
	.ctrl_addr   (sramphy_addr),
	.ctrl_dq_out (sramphy_dq_out),
	.ctrl_dq_oe  (sramphy_dq_oe),
	.ctrl_dq_in  (sramphy_dq_in),
	.ctrl_ce_n   (sramphy_ce_n),
	.ctrl_we_n   (sramphy_we_n),
	.ctrl_oe_n   (sramphy_oe_n),
	.ctrl_byte_n (sramphy_byte_n),
	.sram_addr   (sram_addr),
	.sram_dq     (sram_dq),
	.sram_ce_n   (/* unused */),
	.sram_we_n   (sram_we_n),
	.sram_oe_n   (sram_oe_n),
	.sram_byte_n (sram_byte_n)
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

`ifndef YOSYS
`default_nettype wire
`endif
