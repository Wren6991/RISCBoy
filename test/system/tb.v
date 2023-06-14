module tb;

// Set to 1 to use internal SRAM0, and DVI display output
localparam ECP5_PLATFORM = 0;

`include "gpio_pinmap.vh"

localparam CLK_PERIOD_SYS = 10;
localparam CLK_PERIOD_LCD_PIX = ECP5_PLATFORM ? 20 : 10;
localparam CLK_PERIOD_LCD_BIT = ECP5_PLATFORM ? 4 : 10;

localparam W_SRAM0_ADDR = 18;
localparam SRAM0_DEPTH = 1 << W_SRAM0_ADDR;

reg clk_sys;
reg clk_lcd_pix;
reg clk_lcd_bit;
reg rst_n;

localparam N_PADS = N_GPIOS;

wire [N_PADS-1:0]       pads;
wire [N_PADS-1:0]       padout;
wire [N_PADS-1:0]       padoe;
wire [N_PADS-1:0]       padin;

wire                    lcd_pwm;
wire                    uart_tx;
wire                    uart_rx;
wire                    uart_rts;
wire                    uart_cts;
wire                    spi_sclk;
wire                    spi_cs;
wire                    spi_sdo;
wire                    spi_sdi;

wire                    sramphy_clk;
wire                    sramphy_rst_n;
wire [W_SRAM0_ADDR-1:0] sramphy_addr;
wire [15:0]             sramphy_dq_out;
wire [15:0]             sramphy_dq_oe;
wire [15:0]             sramphy_dq_in;
wire                    sramphy_ce_n;
wire                    sramphy_we_n;
wire                    sramphy_oe_n;
wire [1:0]              sramphy_byte_n;

wire                    lcd_cs;
wire                    lcd_dc;
wire                    lcd_sck;
wire                    lcd_mosi;

assign (pull0, pull1) pads = {N_PADS{1'b1}}; // stop getting Xs in processor when checking IOs

// ============================================================================
// DUT
// ============================================================================

riscboy_core #(
	// Skip bootloader: instead initialise main memory directly and jump straight there.
	.BOOTRAM_PRELOAD  (""),
	.CPU_RESET_VECTOR (32'h200000c0),

	.SRAM0_INTERNAL   (ECP5_PLATFORM),
	.W_SRAM0_ADDR     (ECP5_PLATFORM ? 15 : 18), // 2**15 words = 128k or 2**18 halfwords = 512k
	.SRAM0_PRELOAD    ("../ram_init32.hex"),     // Only valid if SRAM0_INTERNAL is set (so for ECP5_PLATFORM)
	.DISPLAY_TYPE     (ECP5_PLATFORM ? "DVI" : "SPI"),
	.N_PADS           (N_PADS)
) dut (
	.clk_sys        (clk_sys),
	.clk_lcd_pix    (clk_lcd_pix),
	.clk_lcd_bit    (clk_lcd_bit),
	.rst_n          (rst_n),
	
	.padout         (padout),
	.padoe          (padoe),
	.padin          (padin),

	.lcd_pwm        (lcd_pwm),
	.uart_tx        (uart_tx),
	.uart_rx        (uart_rx),
	.uart_rts       (uart_rts),
	.uart_cts       (uart_cts),
	.spi_sclk       (spi_sclk),
	.spi_cs         (spi_cs),
	.spi_sdo        (spi_sdo),
	.spi_sdi        (spi_sdi),

	.lcdp           ({lcd_cs, lcd_dc, lcd_sck, lcd_mosi}),

	.sram_phy_clk   (sramphy_clk),
	.sram_phy_rst_n (sramphy_rst_n),
	.sram_addr      (sramphy_addr),
	.sram_dq_out    (sramphy_dq_out),
	.sram_dq_oe     (sramphy_dq_oe),
	.sram_dq_in     (sramphy_dq_in),
	.sram_ce_n      (sramphy_ce_n),
	.sram_we_n      (sramphy_we_n),
	.sram_oe_n      (sramphy_oe_n),
	.sram_byte_n    (sramphy_byte_n)
);

wire [W_SRAM0_ADDR-1:0] sram_addr;
wire [15:0]             sram_dq;
wire                    sram_ce_n;
wire                    sram_we_n;
wire                    sram_oe_n;
wire [1:0]              sram_byte_n;

async_sram_phy #(
	.W_ADDR(18),
	.W_DATA(16)
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
	.sram_ce_n   (sram_ce_n),
	.sram_we_n   (sram_we_n),
	.sram_oe_n   (sram_oe_n),
	.sram_byte_n (sram_byte_n)
);



// ============================================================================
// Stimulus and peripherals
// ============================================================================

always #(CLK_PERIOD_SYS * 0.5) clk_sys = !clk_sys;
always #(CLK_PERIOD_LCD_PIX * 0.5) clk_lcd_pix = !clk_lcd_pix;
always #(CLK_PERIOD_LCD_BIT * 0.5) clk_lcd_bit = !clk_lcd_bit;

initial begin
	clk_sys = 1'b0;
	clk_lcd_pix = 1'b0;
	clk_lcd_bit = 1'b0;
	rst_n = 1'b0;

	#(10 * CLK_PERIOD_SYS);
	rst_n = 1'b1;
end

tristate_io padbuf [0:N_PADS-1] (
	.out (padout),
	.oe  (padoe),
	.in  (padin),
	.pad (pads)
);

behav_uart_rx #(
	.BAUD_RATE(115200.0),
	.BUF_SIZE(256)
) uart_rx_to_console (
	.rx(uart_tx)
);

sram_async #(
	.W_DATA(16),
	.DEPTH(SRAM0_DEPTH),
	.PRELOAD_FILE ("../ram_init16.hex")
) inst_sram_async (
	.addr  (sram_addr),
	.dq    (sram_dq),
	.ce_n  (sram_ce_n),
	.oe_n  (sram_oe_n),
	.we_n  (sram_we_n),
	.ben_n (sram_byte_n)
);

// ============================================================================
// Monitoring
// ============================================================================

localparam MONITOR_BUS = 0;
localparam MONITOR_LCD = 1;

localparam W_ADDR = 32;
localparam W_DATA = 32;

wire               proc0_hready    = dut.proc0_hready;
wire               proc0_hresp     = dut.proc0_hresp;
wire [W_ADDR-1:0]  proc0_haddr     = dut.proc0_haddr;
wire               proc0_hwrite    = dut.proc0_hwrite;
wire [1:0]         proc0_htrans    = dut.proc0_htrans;
wire [2:0]         proc0_hsize     = dut.proc0_hsize;
wire [2:0]         proc0_hburst    = dut.proc0_hburst;
wire [3:0]         proc0_hprot     = dut.proc0_hprot;
wire               proc0_hmastlock = dut.proc0_hmastlock;
wire [W_DATA-1:0]  proc0_hwdata    = dut.proc0_hwdata;
wire [W_DATA-1:0]  proc0_hrdata    = dut.proc0_hrdata;

reg  [W_ADDR-1:0]  dph_addr;
reg  [2:0]         dph_size;
reg                dph_act_w;
reg                dph_act_r;

wire [7:0] size_str =
	dph_size == 3'h0 ? "b" :
	dph_size == 3'h1 ? "h" :
	                   "w" ;

always @ (posedge clk_sys or negedge rst_n) begin
	if (!rst_n) begin
		dph_addr <= 0;
		dph_act_w <= 0;
		dph_act_r <= 0;
		dph_size <= 0;
		$timeformat(-9, 2, " ns", 20);
	end else if (MONITOR_BUS && proc0_hready) begin
		dph_addr <= proc0_haddr;
		dph_size <= proc0_hsize;
		dph_act_w <= proc0_htrans[1] && proc0_hwrite;
		dph_act_r <= proc0_htrans[1] && !proc0_hwrite;
		if (dph_act_w)
			$display("%t PROC0: WRITE <%h>%s: %h", $time, dph_addr, size_str, proc0_hwdata);
		if (dph_act_r)
			$display("%t PROC0: READ  <%h>%s: %h", $time, dph_addr, size_str, proc0_hrdata);
	end
end

localparam LCD_DATSIZE = 16;

initial if (MONITOR_LCD) begin: monitor_lcd
	integer fd;
	integer shift_count = 0;
	reg [LCD_DATSIZE-1:0] sreg = 0;
	fd = $fopen("../lcd_dump.hex", "wb");
	while (1) begin
		@ (posedge lcd_sck or posedge lcd_cs);
		if (lcd_cs) begin
			shift_count = 0;
		end else if (lcd_dc) begin
			sreg = {sreg[LCD_DATSIZE-2:0], lcd_mosi};
			shift_count = shift_count + 1;
			if (shift_count >= LCD_DATSIZE) begin
				shift_count = 0;
				$fdisplay(fd, "%h", sreg);
				$fflush(fd);
			end
		end
	end
end

endmodule
