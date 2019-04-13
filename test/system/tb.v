module tb;

`include "gpio_pinmap.vh"

localparam CLK_PERIOD = 20;

localparam W_SRAM0_ADDR = 18;
localparam SRAM0_DEPTH = 1 << W_SRAM0_ADDR;

reg clk;
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

assign (pull0, pull1) pads = {N_PADS{1'b1}}; // stop getting Xs in processor when checking IOs

// ============================================================================
// DUT
// ============================================================================

riscboy_core #(
	.BOOTRAM_PRELOAD("../ram_init32.hex")
) dut (
	.clk         (clk),
	.rst_n       (rst_n),
	
	.padout      (padout),
	.padoe       (padoe),
	.padin       (padin),

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

always #(CLK_PERIOD * 0.5) clk = !clk;

initial begin
	clk = 1'b0;
	rst_n = 1'b0;

	#(10 * CLK_PERIOD);
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
	.DEPTH(SRAM0_DEPTH)
) inst_sram_async (
	.addr  (sram_addr),
	.dq    (sram_dq),
	.ce_n  (sram_ce_n),
	.oe_n  (sram_oe_n),
	.we_n  (sram_we_n),
	.ben_n (sram_byte_n)
);

endmodule