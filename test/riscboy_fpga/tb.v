module tb;

reg         clk_osc;
wire        fpga_heartbeat;

wire        audio_pwm;
wire        fpga_uart_rx;
wire        fpga_uart_tx;
wire [9:0]  gpio_sw;

wire        lcd_cs;
wire        lcd_dc;
wire        lcd_pwm;
wire        lcd_reset;
wire        lcd_scl;
wire        lcd_sda;
wire        lcd_sdo;
wire        usd_clk;
wire        usd_cmd;
wire [3:0]  usd_dat;

wire [17:0] sram_a;
wire [16:1] sram_dq;
wire        sram_ce;
wire        sram_lb;
wire        sram_oe;
wire        sram_ub;
wire        sram_we;

riscboy_fpga inst_riscboy_fpga
(
	.clk_osc        (clk_osc),
	.fpga_heartbeat (fpga_heartbeat),
	.audio_pwm      (audio_pwm),
	.fpga_uart_rx   (fpga_uart_rx),
	.fpga_uart_tx   (fpga_uart_tx),
	.gpio_sw        (gpio_sw),
	.lcd_cs         (lcd_cs),
	.lcd_dc         (lcd_dc),
	.lcd_pwm        (lcd_pwm),
	.lcd_reset      (lcd_reset),
	.lcd_scl        (lcd_scl),
	.lcd_sda        (lcd_sda),
	.lcd_sdo        (lcd_sdo),
	.usd_clk        (usd_clk),
	.usd_cmd        (usd_cmd),
	.usd_dat        (usd_dat),
	.sram_a         (sram_a),
	.sram_dq        (sram_dq),
	.sram_ce        (sram_ce),
	.sram_lb        (sram_lb),
	.sram_oe        (sram_oe),
	.sram_ub        (sram_ub),
	.sram_we        (sram_we)
);

localparam CLK_OSC_PERIOD = 1000.0 / 12.0;

initial clk_osc = 1'b0;
always #(0.5 * CLK_OSC_PERIOD) clk_osc = !clk_osc;

endmodule