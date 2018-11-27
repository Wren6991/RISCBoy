module riscboy_fpga (
	input wire clk_osc,

	output wire fpga_heartbeat,

	// Named GPIOs
	inout wire        fpga_uart_rx,
	inout wire        fpga_uart_tx,
	inout wire [9:0]  gpio_sw,

	inout wire        lcd_cs,
	inout wire        lcd_dc,
	inout wire        lcd_pwm,
	inout wire        lcd_reset,
	inout wire        lcd_scl,
	inout wire        lcd_sda,
	inout wire        lcd_sdo,
	inout wire        usd_clk,
	inout wire        usd_cmd,
	inout wire [3:0]  usd_dat,

	// External async SRAM
	// numbering is consistent with datasheet...
	inout wire [17:0] sram_a,
	inout wire [16:1] sram_dq,
	inout wire        sram_ce,
	inout wire        sram_lb,
	inout wire        sram_oe,
	inout wire        sram_ub,
	inout wire        sram_we
);

wire clk_sys;
assign clk_sys = clk_osc; // TODO PLL

// Crappy behavioural reset generator

reg [7:0] rst_delay = 8'h0;
wire rst_n = rst_delay[0];
always @ (posedge clk_sys)
	rst_delay <= {1'b1, rst_delay[7:1]};

// Instantiate the actual logic

riscboy_core core (
	.clk(clk_sys),
	.rst_n(rst_n),

	.gpio({
		gpio_sw[0],
		usd_clk,
		usd_cmd,
		usd_dat,
		lcd_cs,
		lcd_dc,
		lcd_pwm,
		lcd_reset,
		lcd_scl,
		lcd_sda,
		lcd_sdo,
		fpga_uart_rx,
		fpga_uart_tx
	})
);

endmodule