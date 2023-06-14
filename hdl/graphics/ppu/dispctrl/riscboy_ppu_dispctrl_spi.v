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

// Simple serial display "controller" for PPU.
// Two jobs:
// - Shift out a continously-clocked stream of pixel data from the scanbuf,
//   for screen update
// - Shift out individual bytes from the APB interface, for control purposes

module riscboy_ppu_dispctrl_spi #(
	parameter PXFIFO_DEPTH = 8,
	parameter W_COORD_SX = 9,
	parameter W_DATA  = 16,
	parameter W_SHAMT = $clog2(W_DATA + 1) // do not modify
) (
	input  wire                  clk_sys,
	input  wire                  rst_n_sys,
	input  wire                  clk_tx,
	input  wire                  rst_n_tx,

	// APB slave port
	input  wire                  apbs_psel,
	input  wire                  apbs_penable,
	input  wire                  apbs_pwrite,
	input  wire [15:0]           apbs_paddr,
	input  wire [31:0]           apbs_pwdata,
	output wire [31:0]           apbs_prdata,
	output wire                  apbs_pready,
	output wire                  apbs_pslverr,

	// Scanbuf read port signals
	output reg  [W_COORD_SX-1:0] scanout_raddr,
	output wire                  scanout_ren,
	input  wire [W_DATA-1:0]     scanout_rdata,
	input  wire                  scanout_buf_rdy,
	output wire                  scanout_buf_release,

	// Outputs to display
	output wire                  lcd_cs,
	output wire                  lcd_dc,
	output wire                  lcd_sck,
	output wire                  lcd_mosi
);

// Should be locals but ISIM bug etc etc:
parameter W_PXFIFO_LEVEL  = $clog2(PXFIFO_DEPTH + 1);

// ----------------------------------------------------------------------------
// Scanbuf interface and APB slave interface (system clock domain)

wire [W_DATA-1:0]         pxfifo_direct_wdata;
wire                      pxfifo_direct_wen;
wire                      pxfifo_wfull;
wire                      pxfifo_wempty;
wire [W_PXFIFO_LEVEL-1:0] pxfifo_wlevel;
wire                      lcdctrl_shamt;
wire                      lcdctrl_busy;

wire [W_COORD_SX-1:0]     dispsize_w;

dispctrl_spi_regs inst_dispctrl_spi_regs (
	.clk                (clk_sys),
	.rst_n              (rst_n_sys),

	.apbs_psel          (apbs_psel),
	.apbs_penable       (apbs_penable),
	.apbs_pwrite        (apbs_pwrite),
	.apbs_paddr         (apbs_paddr),
	.apbs_pwdata        (apbs_pwdata),
	.apbs_prdata        (apbs_prdata),
	.apbs_pready        (apbs_pready),
	.apbs_pslverr       (apbs_pslverr),

	.csr_pxfifo_empty_i (pxfifo_wempty),
	.csr_pxfifo_full_i  (pxfifo_wfull),
	.csr_lcd_cs_o       (lcd_cs),
	.csr_lcd_dc_o       (lcd_dc),
	.csr_tx_busy_i      (lcdctrl_busy),
	.csr_lcd_shiftcnt_o (lcdctrl_shamt),

	.dispsize_w_o       (dispsize_w),

	.pxfifo_o           (pxfifo_direct_wdata),
	.pxfifo_wen         (pxfifo_direct_wen)
);

// Scan out to pixel FIFO

assign scanout_ren = scanout_buf_rdy && (
	pxfifo_wlevel < PXFIFO_DEPTH - 2 || !(pxfifo_wfull || pxfifo_scan_wen)
);
assign scanout_buf_release = scanout_ren && scanout_raddr == dispsize_w;

reg pxfifo_scan_wen;

always @ (posedge clk_sys or negedge rst_n_sys) begin
	if (!rst_n_sys) begin
		scanout_raddr <= {W_COORD_SX{1'b0}};
		pxfifo_scan_wen <= 1'b0;
	end else begin
		pxfifo_scan_wen <= scanout_ren;
		if (scanout_ren) begin
			scanout_raddr <= scanout_buf_release ? {W_COORD_SX{1'b0}} : scanout_raddr + 1'b1;
		end
	end
end


// ----------------------------------------------------------------------------
// Clock domain crossing

wire              lcdctrl_busy_clklcd;
wire              lcdctrl_shamt_clklcd;

wire [W_DATA-1:0] pxfifo_wdata = pxfifo_direct_wen ? pxfifo_direct_wdata : scanout_rdata;
wire              pxfifo_wen = pxfifo_direct_wen || pxfifo_scan_wen;

wire [W_DATA-1:0] pxfifo_rdata;
wire              pxfifo_rempty;
wire              pxfifo_rdy;
wire              pxfifo_pop = pxfifo_rdy && !pxfifo_rempty;

async_fifo #(
	.W_DATA (W_DATA),
	.W_ADDR (W_PXFIFO_LEVEL - 1)
) pixel_fifo (
	.wclk   (clk_sys),
	.wrst_n (rst_n_sys),

	.wdata  (pxfifo_wdata),
	.wpush  (pxfifo_wen),
	.wfull  (pxfifo_wfull),
	.wempty (pxfifo_wempty),
	.wlevel (pxfifo_wlevel),

	.rclk   (clk_tx),
	.rrst_n (rst_n_tx),

	.rdata  (pxfifo_rdata),
	.rpop   (pxfifo_pop),
	.rfull  (/* unused */),
	.rempty (pxfifo_rempty),
	.rlevel (/* unused */)
);

sync_1bit sync_lcd_busy (
	.clk   (clk_sys),
	.rst_n (rst_n_sys),
	.i     (lcdctrl_busy_clklcd),
	.o     (lcdctrl_busy)
);

// It should be ok to use simple 2FF sync here because software maintains
// guarantee that this only changes when PPU + shifter are idle

sync_1bit sync_lcd_shamt (
	.clk   (clk_tx),
	.rst_n (rst_n_tx),
	.i     (lcdctrl_shamt),
	.o     (lcdctrl_shamt_clklcd)
);


// ----------------------------------------------------------------------------
// Shifter logic (TX clock domain)

reg [W_DATA-1:0]  shift;
reg [W_SHAMT-1:0] shift_ctr;

assign pxfifo_rdy = ~|(shift_ctr[W_SHAMT-1:1]);
assign lcdctrl_busy_clklcd = |shift_ctr;

always @ (posedge clk_tx or negedge rst_n_tx) begin
	if (!rst_n_tx) begin
		shift <= {W_DATA{1'b0}};
		shift_ctr <= {W_SHAMT{1'b0}};
	end else begin
		shift_ctr <= shift_ctr - |shift_ctr;
		shift <= shift << 1;
		if (pxfifo_pop) begin
			shift <= pxfifo_rdata;
			shift_ctr[W_SHAMT-1:W_SHAMT-2] <= {lcdctrl_shamt_clklcd, !lcdctrl_shamt_clklcd};
		end
	end
end

ddr_out sck_ddr (
	.clk    (clk_tx),
	.rst_n  (rst_n_tx),

	.d_rise (1'b0),
	.d_fall (lcdctrl_busy_clklcd),
	.q      (lcd_sck)
);

dffe_out mosi_dffe (
	.clk (clk_tx),
	.d   (shift[W_DATA - 1]),
	.e   (1'b1),
	.q   (lcd_mosi)
);

endmodule
