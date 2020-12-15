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

// DVI display controller for RISCBoy PPU
//
// Clock inputs:
//
// - clk_sys is the clock used by the APB bus interface and the PPU scanout
//  interface
//
// - clk_pix is the DVI pixel clock, used to generate display timings and
//   clock the TMDS encoding logic. This is assumed to be asynchronous to
//   clk_sys, though tying clk_sys and clk_pix together is harmless.
//
// - clk_bit is a half-rate bit clock. It must be precisely 5x clk_pix, and must
//   derive from the same phase reference as clk_pix.
//
// An asynchronous reset is provided for each clock domain. The deassertion of
// these resets must be synchronised to the relevant clock.

module riscboy_ppu_dispctrl_dvi #(
	parameter PXFIFO_DEPTH = 8,
	parameter W_COORD_SX = 9,
	parameter W_DATA  = 16, // Do not modify
	parameter W_SHAMT = $clog2(W_DATA + 1) // Do not modify
) (
	input  wire                  clk_sys,
	input  wire                  rst_n_sys,
	input  wire                  clk_pix,
	input  wire                  rst_n_pix,
	input  wire                  clk_bit,
	input  wire                  rst_n_bit,

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

	// 4 pseudo-differential pairs: {CLK, TMDS2, TMDS1, TMDS0}
	output wire [3:0] dvip,
	output wire [3:0] dvin
);

// Should be locals but ISIM bug etc etc:
parameter W_PXFIFO_LEVEL  = $clog2(PXFIFO_DEPTH + 1);

// ----------------------------------------------------------------------------
// Scanbuf interface and APB slave interface (system clock domain)

wire csr_en;

dispctrl_dvi_regs regs (
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

	.csr_en_o           (csr_en)
);

// Scan out to pixel FIFO. Output resolution is double input resolution: we
// write each pixel to the pixel FIFO twice after reading from the scanbuf,
// and each scanline is read twice before releasing. This gives an input of
// QVGA 60Hz.

wire                      pxfifo_wfull;
wire                      pxfifo_wempty;
wire [W_PXFIFO_LEVEL-1:0] pxfifo_wlevel;

// For every 1 read there are two writes. This register will read 01 during
// the first write, 10 (shifted along) during the second write, or 00 if no
// write is taking place.
reg [1:0] wen_state;
reg       scanline_second_read;

assign scanout_ren = csr_en && scanout_buf_rdy && !wen_state[0] && (
	pxfifo_wlevel + |wen_state < PXFIFO_DEPTH - 2
);
wire end_of_scanline = scanout_ren && scanout_raddr == 319; // FIXME hardcoded
assign scanout_buf_release = end_of_scanline && scanline_second_read;


always @ (posedge clk_sys or negedge rst_n_sys) begin
	if (!rst_n_sys) begin
		scanout_raddr <= {W_COORD_SX{1'b0}};
		wen_state <= 2'h0;
		scanline_second_read <= 1'b0;
	end else if (!csr_en) begin
		scanout_raddr <= {W_COORD_SX{1'b0}};
		wen_state <= 2'h0;
		scanline_second_read <= 1'b0;
	end else begin
		wen_state <= (wen_state << 1) | scanout_ren;
		if (scanout_ren) begin
			scanout_raddr <= end_of_scanline ? {W_COORD_SX{1'b0}} : scanout_raddr + 1'b1;
			if (end_of_scanline)
				scanline_second_read <= !scanline_second_read;
		end
	end
end

wire pxfifo_wen = |wen_state;

// ----------------------------------------------------------------------------
// System to pixel clock domain crossing


wire [W_DATA-1:0] pxfifo_wdata = scanout_rdata;

wire [W_DATA-1:0] pxfifo_rdata;
wire              pxfifo_pop;

async_fifo #(
	.W_DATA (W_DATA),
	.W_ADDR (W_PXFIFO_LEVEL - 1)
) pixel_fifo (
	.wclk   (clk_sys),
	.wrst_n (rst_n_sys),

	.wdata  (scanout_rdata),
	.wpush  (|pxfifo_wen),
	.wfull  (pxfifo_wfull),
	.wempty (pxfifo_wempty),
	.wlevel (pxfifo_wlevel),

	.rclk   (clk_pix),
	.rrst_n (rst_n_pix),

	.rdata  (pxfifo_rdata),
	.rpop   (pxfifo_pop),
	.rfull  (/* unused */),
	.rempty (/* unused */),
	.rlevel (/* unused */)
);

wire csr_en_clkpix;

sync_1bit sync_lcd_shamt (
	.clk   (clk_pix),
	.rst_n (rst_n_pix),
	.i     (csr_en),
	.o     (csr_en_clkpix)
);

// ----------------------------------------------------------------------------
// DVI Logic

wire [9:0] tmds0;
wire [9:0] tmds1;
wire [9:0] tmds2;

dvi_tx_parallel #(
	// Timings here are 640x480p 60 Hz timings from CEA-861D, but with extra 800
	// pixels of horizontal blanking, to get 480p 30 Hz with a legal pixel clock.
	// My monitors and TV don't mind this, but yours might
	.H_SYNC_POLARITY (1'b0),
	.H_FRONT_PORCH   (16),
	.H_SYNC_WIDTH    (96),
	.H_BACK_PORCH    (848),
	.H_ACTIVE_PIXELS (640),

	.V_SYNC_POLARITY (1'b0),
	.V_FRONT_PORCH   (10),
	.V_SYNC_WIDTH    (2),
	.V_BACK_PORCH    (33),
	.V_ACTIVE_LINES  (480),

	// We are doubling the pixels anyway, so can use the *much* smaller
	// pixel-doubled encoder
	.SMOL_TMDS_ENCODE (1)
) dvi_tx_ctrl (
	.clk     (clk_pix),
	.rst_n   (rst_n_pix),
	.en      (csr_en_clkpix),

	.r       ({pxfifo_rdata[15:11] , 3'h0}),
	.g       ({pxfifo_rdata[10:5]  , 2'h0}),
	.b       ({pxfifo_rdata[4:0]   , 3'h0}),
	.rgb_rdy (pxfifo_pop),

	.tmds2   (tmds2),
	.tmds1   (tmds1),
	.tmds0   (tmds0)
);

dvi_serialiser ser0 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds0),
	.qp        (dvip[0]),
	.qn        (dvin[0])
);

dvi_serialiser ser1 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds1),
	.qp        (dvip[1]),
	.qn        (dvin[1])
);


dvi_serialiser ser2 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds2),
	.qp        (dvip[2]),
	.qn        (dvin[2])
);

dvi_clock_driver serclk (
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.qp        (dvip[3]),
	.qn        (dvin[3])
);


endmodule
