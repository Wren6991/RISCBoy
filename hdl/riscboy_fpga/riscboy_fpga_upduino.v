// Modified FPGA top-level suitable for the Gnarly Grey Upduino V2.0 dev board
// (e.g. use the internal oscillator rather than a GBIN, tie off the SRAM interface...)

module riscboy_fpga (
	output wire led_r,
	output wire led_g,
	output wire led_b,
	output wire led_mirror, // green LED reflected to a GPIO so it can be probed

	inout wire uart_tx,
	inout wire uart_rx,

	inout wire lcd_scl,
	inout wire lcd_sdo,
	inout wire lcd_cs,
	inout wire lcd_dc,
	inout wire lcd_pwm,
	inout wire lcd_rst,

	inout wire flash_miso,
	inout wire flash_mosi,
	inout wire flash_sclk,
	inout wire flash_cs
);

// Clock + Reset resources

wire clk_osc;
wire clk_sys;
wire rst_n;

SB_HFOSC #(
  .CLKHF_DIV ("0b10") // divide by 4 -> 12 MHz
) inthosc (
  .CLKHFPU (1'b1),
  .CLKHFEN (1'b1),
  .CLKHF   (clk_osc)
);

// We can't close timing at this speed (normally around 14 MHz),
// but the timings are conservative, and it seems to work for playing around :)
localparam USE_PLL = 0;

generate
if (USE_PLL) begin: has_pll
	pll_12_18 pll (
		.clock_in  (clk_osc),
		.clock_out (clk_sys), // -> 18 MHz
		.locked    (   )
	);
end else begin: no_pll
	assign clk_sys = clk_osc;
end
endgenerate

fpga_reset #(
	.SHIFT (3),
	.COUNT (200) // need at least 3 us delay before accessing BRAMs on iCE40
) rstgen (
	.clk         (clk_osc),
	.force_rst_n (1'b1),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

wire gpio_led;

wire [2:0] gpio_unused;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex"),
	.GPIO_IS_PAD(16'hfffe)
) core (
	.clk(clk_sys),
	.rst_n(rst_n),

	.gpio({
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
		gpio_led
	})
);

wire heartbeat;

blinky #(
	.CLK_HZ (12_000_000),
	.BLINK_HZ (1),
	.FANCY (0)
) blinky_u (
	.clk (clk_osc),
	.blink (heartbeat)
);

SB_RGBA_DRV #(
  .CURRENT_MODE("0b1"),
  .RGB0_CURRENT("0b000001"),
  .RGB1_CURRENT("0b000001"),
  .RGB2_CURRENT("0b000001")
) rgba_driver (
  .CURREN(1'b1),
  .RGBLEDEN(1'b1),
  .RGB0PWM(gpio_led),
  .RGB1PWM(1'b0),
  .RGB2PWM(1'b0),//heartbeat),
  .RGB0(led_g),
  .RGB1(led_b),
  .RGB2(led_r)
);

assign led_mirror = gpio_led;

endmodule