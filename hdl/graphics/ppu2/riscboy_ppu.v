/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2020 Luke Wren                                       *
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

// Pixel processing unit, version 2

module riscboy_ppu #(
	parameter PXFIFO_DEPTH = 8,
	parameter W_HADDR = 32,
	parameter W_HDATA = 32,
	parameter W_DATA = 16,
	parameter ADDR_MASK = 32'h200fffff
) (
	input  wire               clk_ppu,
	input  wire               clk_lcd,
	input  wire               rst_n,

	output wire               irq,

	// AHB-lite master port
	output wire [W_HADDR-1:0] ahblm_haddr,
	output wire               ahblm_hwrite,
	output wire [1:0]         ahblm_htrans,
	output wire [2:0]         ahblm_hsize,
	output wire [2:0]         ahblm_hburst,
	output wire [3:0]         ahblm_hprot,
	output wire               ahblm_hmastlock,
	input  wire               ahblm_hready,
	input  wire               ahblm_hresp,
	output wire [W_HDATA-1:0] ahblm_hwdata,
	input  wire [W_HDATA-1:0] ahblm_hrdata,

	// APB slave port
	input  wire               apbs_psel,
	input  wire               apbs_penable,
	input  wire               apbs_pwrite,
	input  wire [15:0]        apbs_paddr,
	input  wire [W_HDATA-1:0] apbs_pwdata,
	output wire [W_HDATA-1:0] apbs_prdata,
	output wire               apbs_pready,
	output wire               apbs_pslverr,

	output wire               lcd_cs,
	output wire               lcd_dc,
	output wire               lcd_sck,
	output wire               lcd_mosi
);

`include "riscboy_ppu_const.vh"

localparam W_PIXDATA = 16;
localparam W_LCD_PIXDATA = 16;
localparam W_COORD_SX = 9;
localparam W_COORD_SY = 8;
localparam W_COORD_UV = 10;
// Should be locals but ISIM bug etc etc:
parameter W_PXFIFO_LEVEL  = $clog2(PXFIFO_DEPTH + 1);

wire rst_n_ppu;
wire rst_n_lcd;

reset_sync sync_rst_ppu (
	.clk       (clk_ppu),
	.rst_n_in  (rst_n),
	.rst_n_out (rst_n_ppu)
);

reset_sync sync_rst_lcd (
	.clk       (clk_lcd),
	.rst_n_in  (rst_n),
	.rst_n_out (rst_n_lcd)
);

// ----------------------------------------------------------------------------
// Regblock

wire                      csr_run;
wire                      csr_running;
wire                      csr_halt_hsync;
wire                      csr_halt_vsync;

wire [W_COORD_SX-1:0]     dispsize_w;
wire [W_COORD_SY-1:0]     dispsize_h;

wire [W_HADDR-1:0]        cproc_pc_wdata;
wire                      cproc_pc_wen;

wire [W_LCD_PIXDATA-1:0]  pxfifo_direct_wdata;
wire                      pxfifo_direct_wen;
wire                      pxfifo_wfull;
wire                      pxfifo_wempty;
wire [W_PXFIFO_LEVEL-1:0] pxfifo_wlevel;
wire                      lcdctrl_shamt;
wire                      lcdctrl_busy;

wire                      ints_vsync;
wire                      ints_hsync;
wire                      inte_vsync;
wire                      inte_hsync;
wire                      vsync = 1'b0; // FIXME
wire                      hsync = 1'b0; // FIXME

assign irq = |({ints_hsync, ints_vsync} & {inte_hsync, inte_vsync});

ppu_regs regs (
	.clk                    (clk_ppu),
	.rst_n                  (rst_n_ppu),

	.apbs_psel              (apbs_psel),
	.apbs_penable           (apbs_penable),
	.apbs_pwrite            (apbs_pwrite),
	.apbs_paddr             (apbs_paddr),
	.apbs_pwdata            (apbs_pwdata),
	.apbs_prdata            (apbs_prdata),
	.apbs_pready            (apbs_pready),
	.apbs_pslverr           (apbs_pslverr),

	.csr_run_o              (csr_run),
	.csr_running_i          (csr_running),
	.csr_halt_hsync_o       (csr_halt_hsync),
	.csr_halt_vsync_o       (csr_halt_vsync),

	.dispsize_w_o           (dispsize_w),
	.dispsize_h_o           (dispsize_h),

	.cproc_pc_o             (cproc_pc_wdata),
	.cproc_pc_wen           (cproc_pc_wen),

	.lcd_pxfifo_o           (pxfifo_direct_wdata),
	.lcd_pxfifo_wen         (pxfifo_direct_wen),
	.lcd_csr_pxfifo_empty_i (pxfifo_wempty),
	.lcd_csr_pxfifo_full_i  (pxfifo_wfull),
	.lcd_csr_pxfifo_level_i (pxfifo_wlevel),
	.lcd_csr_lcd_cs_o       (lcd_cs),
	.lcd_csr_lcd_dc_o       (lcd_dc),
	.lcd_csr_tx_busy_i      (lcdctrl_busy),
	.lcd_csr_lcd_shiftcnt_o (lcdctrl_shamt),

	.ints_vsync_i           (vsync),
	.ints_vsync_o           (ints_vsync),
	.ints_hsync_i           (hsync),
	.ints_hsync_o           (ints_hsync),
	.inte_vsync_o           (inte_vsync),
	.inte_hsync_o           (inte_hsync)
);

// ----------------------------------------------------------------------------
// LCD shifter and clock crossing

wire                       lcdctrl_busy_clklcd;
wire                       lcdctrl_shamt_clklcd;

wire [W_LCD_PIXDATA-1:0]   pxfifo_wdata = pxfifo_direct_wen ? pxfifo_direct_wdata :
	{pmap_out_pixdata[14:5], 1'b0, pmap_out_pixdata[4:0]};
wire                       pxfifo_wen = pxfifo_direct_wen || (pmap_out_vld && pmap_out_rdy);

wire [W_LCD_PIXDATA-1:0]   pxfifo_rdata;
wire                       pxfifo_rempty;
wire                       pxfifo_rdy;
wire                       pxfifo_pop = pxfifo_rdy && !pxfifo_rempty;

sync_1bit sync_lcd_busy (
	.clk   (clk_ppu),
	.rst_n (rst_n_ppu),
	.i     (lcdctrl_busy_clklcd),
	.o     (lcdctrl_busy)
);

// It should be ok to use simple 2FF sync here because software maintains
// guarantee that this only changes when PPU + shifter are idle

sync_1bit sync_lcd_shamt (
	.clk   (clk_lcd),
	.rst_n (rst_n_lcd),
	.i     (lcdctrl_shamt),
	.o     (lcdctrl_shamt_clklcd)
);

async_fifo #(
	.W_DATA (W_LCD_PIXDATA),
	.W_ADDR (W_PXFIFO_LEVEL - 1)
) inst_async_fifo (
	.wclk   (clk_ppu),
	.wrst_n (rst_n_ppu),

	.wdata  (pxfifo_wdata),
	.wpush  (pxfifo_wen),
	.wfull  (pxfifo_wfull),
	.wempty (pxfifo_wempty),
	.wlevel (pxfifo_wlevel),

	.rclk   (clk_lcd),
	.rrst_n (rst_n_lcd),

	.rdata  (pxfifo_rdata),
	.rpop   (pxfifo_pop),
	.rfull  (/* unused */),
	.rempty (pxfifo_rempty),
	.rlevel (/* unused */)
);

riscboy_ppu_dispctrl #(
	.W_DATA (W_LCD_PIXDATA)
) inst_riscboy_ppu_dispctrl (
	.clk               (clk_lcd),
	.rst_n             (rst_n_lcd),
	.pxfifo_vld        (!pxfifo_rempty),
	.pxfifo_rdy        (pxfifo_rdy),
	.pxfifo_rdata      (pxfifo_rdata),
	.pxfifo_shiftcount (lcdctrl_shamt_clklcd),
	.tx_busy           (lcdctrl_busy_clklcd),
	// Outputs to LCD
	.lcd_sck           (lcd_sck),
	.lcd_mosi          (lcd_mosi)
);

endmodule
