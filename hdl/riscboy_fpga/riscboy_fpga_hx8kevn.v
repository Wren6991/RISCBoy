// Modified FPGA top-level suitable for the TinyFPGA BX

module riscboy_fpga (
	input wire clk_osc,

	output wire [7:0] led,

	inout wire uart_tx,
	inout wire uart_rx,

	// inout wire lcd_scl,
	// inout wire lcd_sdo,
	// inout wire lcd_cs,
	// inout wire lcd_dc,
	// inout wire lcd_pwm,
	// inout wire lcd_rst,

	inout wire flash_miso,
	inout wire flash_mosi,
	inout wire flash_sclk,
	inout wire flash_cs
);

// Clock + Reset resources

wire clk_sys;
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
	.clk         (clk_osc),
	.force_rst_n (pll_lock),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

localparam N_PADS = 16;

wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex")
) core (
	.clk    (clk_sys),
	.rst_n  (rst_n),

	.padout (padout),
	.padoe  (padoe),
	.padin  (padin)
);

// GPIO

wire [2:0] gpio_unused;

tristate_io  pads [N_PADS-1:0] (

	.out    (padout),
	.out_en (padoe),
	.in     (padin),

	.pad ({
		uart_tx,
		uart_rx,
		flash_miso,
		flash_mosi,
		flash_sclk,
		flash_cs,
		gpio_unused,
		lcd_rst,
		lcd_pwm,
		lcd_dc,
		lcd_cs,
		lcd_scl,
	    lcd_sdo,
		led[0]
	})
);

assign led[7] = !padout[15]; // uart_tx
assign led[6] = !padin[14];  // uart_rx
assign led[5:1] = 0;

endmodule