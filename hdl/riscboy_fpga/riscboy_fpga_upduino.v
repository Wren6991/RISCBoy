// Modified FPGA top-level suitable for the Gnarly Grey Upduino V2.0 dev board
// (e.g. use the internal oscillator rather than a GBIN, tie off the SRAM interface...)

module riscboy_fpga (
	output wire led_r,
	output wire led_g,
	output wire led_b,

	output wire uart_tx,
	input wire uart_rx
);

// Clock + Reset resources

wire clk_osc;
wire clk_sys;
assign clk_sys = clk_osc; // TODO PLL

SB_HFOSC #(
  .CLKHF_DIV ("0b10") // divide by 4 -> 12 MHz
) inthosc (
  .CLKHFPU (1'b1),
  .CLKHFEN (1'b1),
  .CLKHF (clk_osc)
);

// Crappy behavioural reset generator
(* keep = 1'b1 *) reg [19:0] rst_delay = 20'h0;
wire rst_n = rst_delay[0];
always @ (posedge clk_sys)
	rst_delay <= ~(~rst_delay >> 1);

// Instantiate the actual logic

wire gpio_led;

wire [12:0] gpio_unused;

riscboy_core #(
	.BOOTRAM_PRELOAD ("bootram_init32.hex"),
	.GPIO_IS_PAD(16'hfffe)
) core (
	.clk(clk_sys),
	.rst_n(rst_n),

	.gpio({
		uart_tx,
		uart_rx,
		gpio_unused, // usd_clk,
		// usd_cmd,
		// usd_dat,
		// lcd_cs,
		// lcd_dc,
		// lcd_pwm,
		// lcd_reset,
		// lcd_scl,
		// lcd_sda,
		// lcd_sdo,
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


endmodule