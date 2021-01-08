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

	// output wire       lcd_cs,
	// output wire       lcd_dc,
	// output wire       lcd_sclk,
	// output wire       lcd_mosi,

	output wire [3:0]  dvi_p,
	output wire [3:0]  dvi_n
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_pix;
wire clk_bit;
reg clk_sys;
wire pll_lock;
wire rst_n_por;

pll_12_126 #(
	.ICE40_PAD (1)
) pll_lcd (
	.clock_in  (clk_osc),
	.clock_out (clk_bit),
	.locked    (pll_lock)
);

fpga_reset #(
	.SHIFT (3),
	.COUNT (0) // TODO the iCE40 BRAMs need some delay before their contents is valid; is the PLL lock delay enough?
) rstgen (
	.clk         (clk_bit),
	.force_rst_n (pll_lock),
	.rst_n       (rst_n_por)
);

// Pixel clock: 126 / 5 -> 25.2 MHz
reg [4:0] clkdiv_pix;
assign clk_pix = clkdiv_pix[0];
always @ (posedge clk_bit or negedge rst_n_por)
	if (!rst_n_por)
		clkdiv_pix <= 5'b11100;
	else
		clkdiv_pix <= {clkdiv_pix[0],  clkdiv_pix[4:1]};

// System clock: 126 /  -> 14 MHz
localparam SYS_CLK_RATIO = 10;
reg [SYS_CLK_RATIO-1:0] clkdiv_sys;
assign clk_sys = clkdiv_sys[0];
always @ (posedge clk_bit or negedge rst_n_por)
	if (!rst_n_por)	
		clkdiv_sys <= {SYS_CLK_RATIO{1'b1}} << (SYS_CLK_RATIO / 2);
	else
		clkdiv_sys <= {clkdiv_sys[0], clkdiv_sys[SYS_CLK_RATIO-1:1]};

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

	.DISPLAY_TYPE      ("DVI"),

	.CUTDOWN_PROCESSOR (1),
	.STUB_SPI          (1),
	.STUB_PWM          (1),
	.NO_SRAM_WRITE_BUF (1),
	.UART_FIFO_DEPTH   (1)
) core (
	.clk_sys     (clk_sys),
	.clk_lcd_pix (clk_pix),
	.clk_lcd_bit (clk_sys),
	.rst_n       (rst_n_por),

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

	// .lcdp        ({lcd_cs, lcd_dc, lcd_sclk, lcd_mosi}),

	.lcdp        (dvi_p),
	.lcdn        (dvi_n),

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
