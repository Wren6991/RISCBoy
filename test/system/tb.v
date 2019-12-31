module tb;

`include "gpio_pinmap.vh"

localparam CLK_PERIOD_SYS = 20;
localparam CLK_PERIOD_LCD = 30;

localparam W_SRAM0_ADDR = 18;
localparam SRAM0_DEPTH = 1 << W_SRAM0_ADDR;

reg clk_sys;
reg clk_lcd;
reg rst_n;

localparam N_PADS = 23;

wire [N_PADS-1:0]       pads;
wire [N_PADS-1:0]       padout;
wire [N_PADS-1:0]       padoe;
wire [N_PADS-1:0]       padin;

wire [W_SRAM0_ADDR-1:0] sram_addr;
wire [15:0]             sram_dq;
wire                    sram_ce_n;
wire                    sram_we_n;
wire                    sram_oe_n;
wire [1:0]              sram_byte_n;

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
	.BOOTRAM_PRELOAD(""),
	.CPU_RESET_VECTOR(32'h200000c0)
) dut (
	.clk_sys     (clk_sys),
	.clk_lcd     (clk_lcd),
	.rst_n       (rst_n),
	
	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin),

	.lcd_cs      (lcd_cs),
	.lcd_dc      (lcd_dc),
	.lcd_sck     (lcd_sck),
	.lcd_mosi    (lcd_mosi),

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
always #(CLK_PERIOD_LCD * 0.5) clk_lcd = !clk_lcd;

initial begin
	clk_sys = 1'b0;
	clk_lcd = 1'b0;
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
) uart_rx (
	.rx(pads[PIN_UART_TX])
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
	fd = $fopen("lcd_dump.hex", "wb");
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
