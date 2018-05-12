/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2018 Luke Wren                                       *
 *                                                                    *
 * Everyone is permitted to copy and distribute verbatim or modified  *
 * copies of this license document and accompanying software, and     *
 * changing either is allowed.                                        *
 *                                                                    *
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION  *
 *                                                                    *
 * 0. You just DO WHAT THE FUCK YOU WANT TO.                          *
 * 1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.             *
 *                                                                    *
 *********************************************************************/

/*
 * Display controller for ILI9314 SPI LCD
 * (with integrated pixel FIFO)
 *
 * Usage:
 *
 * 1. Frame Enable low for at least 1 clock
 * 2. With fen high, use write enable (wen) to clock in 1 frame's worth of pixels
 * 3. GOTO 1
 *
 * This controller does *not* perform the LCD initialisation sequence 
 * (to save LUTS); you should bitbang this with the CPU and then
 * switch the pins over once the LCD is initialised.
 *
 * Clock divisor parameter can be an integer >= 1.
 * A clock divisor of 1 is a special case, with the system clock
 * passed straight through to sck. Note that any other odd divisor
 * will give a non 50-50 clock duty cycle.
 *
 * Frame width, height etc. are configurable rather than programmable,
 * to save LUTs in the FPGA implementation. Would be easy to adapt
 * to dynamic signals.
 */

module ili9314_controller #(
	parameter FRAME_WIDTH = 320,
	parameter FRAME_HEIGHT = 240,
	parameter W_PIXDATA = 16,
	parameter W_PWM = 12,
	parameter CLK_DIVISOR = 1
) (
	input wire                  clk,
	input wire                  rst_n,
	// Control/data interface
	input wire                  fifo_wen,
	input wire  [W_PIXDATA-1:0] fifo_wdata,
	input wire  [W_PWM-1:0]     pwm_level,
	output wire                 fifo_full,
	output wire                 idle,
	// LCD interface
	output reg                  lcd_rst_n,  // LCD external reset
	output reg                  lcd_cs_n,   // chip select
	output reg                  lcd_sck,    // serial clock
	output reg                  lcd_sda,    // LCD's serial data input
	output reg                  lcd_dc_n,   // data if 1, cmd if 0
	output reg                  lcd_backlight
);


// Generate divided clock enable, and external clock output
reg clk_en;

generate
if (CLK_DIVISOR == 1) begin
	// Pass clock straight through
	always @ (*) begin
		clk_en = 1'b1;
		lcd_sck = clk;
	end
end else if (CLK_DIVISOR > 1) begin
	reg [$clog2(CLK_DIVISOR)-1:0] clk_ctr;

	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			clk_en <= 1'b1;
			lcd_sck <= 1'b0;
			clk_ctr <= 0;
		end else begin
			clk_ctr <= clk_ctr + 1'b1;
			clk_en <= 1'b0;
			if (clk_ctr == CLK_DIVISOR >> 1) begin
				lcd_sck <= 1'b1;
			end else if (clk_ctr == CLK_DIVISOR) begin
				clk_en <= 1'b1;
				lcd_sck <= 1'b0;
				clk_ctr <= 0;
			end
		end
	end
end else begin
	// synthesis translate_off
	initial begin
		$display("Clock divisor must be >= 1");
		$finish;
	end
	// synthesis translate_on
end
endgenerate


// Backlight PWM
reg [W_PWM-1:0] pwm_ctr;
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pwm_ctr <= {W_PWM{1'b0}};
		lcd_backlight <= 1'b0;
	end else begin
		pwm_ctr <= pwm_ctr + 1'b1;
		if (pwm_ctr == pwm_level) begin
			lcd_backlight <= 1'b0;
		end else if (!pwm_ctr) begin
			lcd_backlight <= 1'b1;
		end
	end
end


endmodule