/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2019 Luke Wren                                       *
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

 module riscboy_ppu #(
	parameter PXFIFO_DEPTH = 8,
	parameter W_DATA = 32,
	parameter W_ADDR = 32
) (
	input  wire              clk_ppu,
	input  wire              clk_lcd,
	input  wire              rst_n,

	// AHB-lite master port
	output wire [W_ADDR-1:0] ahblm_haddr,
	output wire              ahblm_hwrite,
	output wire [1:0]        ahblm_htrans,
	output wire [2:0]        ahblm_hsize,
	output wire [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	input  wire              ahblm_hready,
	input  wire              ahblm_hresp,
	output wire [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata,

	// APB slave port
	input  wire              apbs_psel,
	input  wire              apbs_penable,
	input  wire              apbs_pwrite,
	input  wire [15:0]       apbs_paddr,
	input  wire [W_DATA-1:0] apbs_pwdata,
	output wire [W_DATA-1:0] apbs_prdata,
	output wire              apbs_pready,
	output wire              apbs_pslverr,

	output wire              lcd_cs,
	output wire              lcd_dc,
	output wire              lcd_sck,
	output wire              lcd_mosi
);

`include "riscboy_ppu_const.vh"

localparam W_PIXDATA = 15;
localparam W_LCD_PIXDATA = 16;
localparam W_COORD = 12;
parameter N_LAYERS = 2;
// Should be locals but ISIM bug etc etc:
parameter W_PXFIFO_LEVEL  = $clog2(PXFIFO_DEPTH + 1);
parameter W_LCDCTRL_SHAMT = $clog2(W_LCD_PIXDATA + 1);
parameter W_LOG_COORD = $clog2(W_COORD);
parameter W_LAYERSEL = N_LAYERS > 1 ? $clog2(N_LAYERS) : 1;

// ----------------------------------------------------------------------------
// Reset synchronisers and regblock

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

wire                       csr_run;
wire                       csr_halt;
wire                       csr_running;
wire                       csr_halt_hsync;
wire                       csr_halt_vsync;

wire [W_PIXDATA-1:0]       default_bg_colour;

wire [W_COORD-1:0]         raster_w;
wire [W_COORD-1:0]         raster_h;
wire [W_COORD-1:0]         raster_x;
wire [W_COORD-1:0]         raster_y;

wire                       bg0_csr_en;
wire [W_PIXMODE-1:0]       bg0_csr_pixmode;
wire                       bg0_csr_transparency;
wire                       bg0_csr_tilesize;
wire [W_LOG_COORD-1:0]     bg0_csr_pfwidth;
wire [W_LOG_COORD-1:0]     bg0_csr_pfheight;
wire                       bg0_csr_flush;
wire [W_COORD-1:0]         bg0_scroll_y;
wire [W_COORD-1:0]         bg0_scroll_x;
wire [23:0]                bg0_tsbase;
wire [23:0]                bg0_tmbase;

wire [W_LCD_PIXDATA-1:0]   pxfifo_direct_wdata;
wire                       pxfifo_direct_wen;

wire                       pxfifo_wfull;
wire                       pxfifo_wempty;
wire [W_PXFIFO_LEVEL-1:0]  pxfifo_wlevel;

wire [W_LCDCTRL_SHAMT-1:0] lcdctrl_shamt;
wire                       lcdctrl_busy;

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
	.csr_halt_o             (csr_halt),
	.csr_running_i          (csr_running),
	.csr_halt_hsync_o       (csr_halt_hsync),
	.csr_halt_vsync_o       (csr_halt_vsync),

	.default_bg_colour_o    (default_bg_colour),

	.dispsize_w_o           (raster_w),
	.dispsize_h_o           (raster_h),
	.beam_x_i               (raster_x),
	.beam_y_i               (raster_y),

	.bg0_csr_en_o           (bg0_csr_en),
	.bg0_csr_pixmode_o      (bg0_csr_pixmode),
	.bg0_csr_transparency_o (bg0_csr_transparency),
	.bg0_csr_tilesize_o     (bg0_csr_tilesize),
	.bg0_csr_pfwidth_o      (bg0_csr_pfwidth),
	.bg0_csr_pfheight_o     (bg0_csr_pfheight),
	.bg0_csr_flush_o        (bg0_csr_flush),
	.bg0_scroll_y_o         (bg0_scroll_y),
	.bg0_scroll_x_o         (bg0_scroll_x),
	.bg0_tsbase_o           (bg0_tsbase),
	.bg0_tmbase_o           (bg0_tmbase),

	.lcd_pxfifo_o           (pxfifo_direct_wdata),
	.lcd_pxfifo_wen         (pxfifo_direct_wen),
	.lcd_csr_pxfifo_empty_i (pxfifo_wempty),
	.lcd_csr_pxfifo_full_i  (pxfifo_wfull),
	.lcd_csr_pxfifo_level_i (pxfifo_wlevel & 6'h0),
	.lcd_csr_lcd_cs_o       (lcd_cs),
	.lcd_csr_lcd_dc_o       (lcd_dc),
	.lcd_csr_lcd_shiftcnt_o (lcdctrl_shamt),
	.lcd_csr_tx_busy_i      (lcdctrl_busy)
);

// ----------------------------------------------------------------------------
// Blender and raster counter

wire hsync;
wire vsync;

// hsync and vsync are registered signals from raster counter which we must respond to precisely.
// csr run/halt are decoded from the bus (-> long paths), but we can respond a little more loosely.
reg ppu_running_reg;
wire ppu_running = ppu_running_reg && !(csr_halt_vsync && vsync || csr_halt_hsync && hsync);

always @ (posedge clk_ppu or negedge rst_n_ppu) begin
	if (!rst_n) begin
		ppu_running_reg <= 1'b0;
	end else begin
		ppu_running_reg <= (ppu_running || csr_run) && !csr_halt;
	end
end

riscboy_ppu_raster_counter #(
	.W_COORD (W_COORD)
) raster_counter_u (
	.clk         (clk_ppu),
	.rst_n       (rst_n_ppu),
	.en          (ppu_running),
	.clr         (1'b0), // FIXME
	.w           (raster_w),
	.h           (raster_h),
	.x           (raster_x),
	.y           (raster_y),
	.start_row   (hsync),
	.start_frame (vsync)
);

localparam N_BACKGROUND = 1;

wire                  bg_blend_vld     [0:N_BACKGROUND-1];
wire                  bg_blend_rdy     [0:N_BACKGROUND-1];
wire                  bg_blend_alpha   [0:N_BACKGROUND-1];
wire [W_PIXDATA-1:0]  bg_blend_pixdata [0:N_BACKGROUND-1];
wire [W_PIXMODE-1:0]  bg_blend_mode    [0:N_BACKGROUND-1]; // TODO: timing of pixel mode vs flush?
wire [W_LAYERSEL-1:0] bg_blend_layer   [0:N_BACKGROUND-1];

assign bg_blend_layer[0] = 0; // FIXME

wire                  blend_out_vld;
wire                  blend_out_rdy = ppu_running && !pxfifo_wfull;
wire [W_PIXDATA-1:0]  blend_out_pixdata;
wire                  blend_out_paletted;

riscboy_ppu_blender #(
	.N_REQ(1),
	.N_LAYERS(N_LAYERS)
) inst_riscboy_ppu_blender (
	.req_vld           (bg_blend_vld[0]), // FIXME support more than just a single background :)
	.req_rdy           (bg_blend_rdy[0]),
	.req_alpha         (bg_blend_alpha[0]),
	.req_pixdata       (bg_blend_pixdata[0]),
	.req_mode          (bg_blend_mode[0]),
	.req_layer         (bg_blend_layer[0]),
	.default_bg_colour (default_bg_colour),

	.out_vld           (blend_out_vld),
	.out_rdy           (blend_out_rdy),
	.out_pixdata       (blend_out_pixdata),
	.out_paletted      (blend_out_paletted)
);

// ----------------------------------------------------------------------------
// Backgrounds


wire              bg_bus_vld  [0:N_BACKGROUND-1];
wire [W_ADDR-1:0] bg_bus_addr [0:N_BACKGROUND-1];
wire [1:0]        bg_bus_size [0:N_BACKGROUND-1];
wire [W_DATA-1:0] bg_bus_data [0:N_BACKGROUND-1];
wire              bg_bus_rdy  [0:N_BACKGROUND-1];


riscboy_ppu_background #(
	.W_COORD           (W_COORD),
	.W_OUTDATA         (W_PIXDATA),
	.W_ADDR            (W_ADDR),
	.W_DATA            (W_DATA)
) bg0 (
	.clk              (clk_ppu),
	.rst_n            (rst_n_ppu),
	.en               (bg0_csr_en),
	.flush            (hsync || bg0_csr_flush),
	.beam_x           (raster_x),
	.beam_y           (raster_x),

	.bus_vld          (bg_bus_vld[0]),
	.bus_addr         (bg_bus_addr[0]),
	.bus_size         (bg_bus_size[0]),
	.bus_rdy          (bg_bus_rdy[0]),
	.bus_data         (bg_bus_data[0]),

	.cfg_scroll_x     (bg0_scroll_x),
	.cfg_scroll_y     (bg0_scroll_y),
	.cfg_log_w        (bg0_csr_pfwidth),
	.cfg_log_h        (bg0_csr_pfheight),
	.cfg_tileset_base ({bg0_tsbase, 8'h0}),
	.cfg_tilemap_base ({bg0_tmbase, 8'h0}),
	.cfg_tile_size    (bg0_csr_tilesize),
	.cfg_pixel_mode   (bg0_csr_pixmode),
	.cfg_transparency (bg0_csr_transparency),

	.out_vld          (bg_blend_vld[0]),
	.out_rdy          (bg_blend_rdy[0]),
	.out_alpha        (bg_blend_alpha[0]),
	.out_pixdata      (bg_blend_pixdata[0])
);

// ----------------------------------------------------------------------------
// LCD shifter and clock crossing

wire                       lcdctrl_busy_clklcd;
wire [W_LCDCTRL_SHAMT-1:0] lcdctrl_shamt_clklcd;

wire [W_LCD_PIXDATA-1:0]   pxfifo_wdata = blend_out_vld ? {blend_out_pixdata[14:5], 1'b0, blend_out_pixdata[4:0]} : pxfifo_direct_wdata;
wire                       pxfifo_wen = pxfifo_direct_wen || (blend_out_vld && blend_out_rdy);

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

sync_1bit sync_lcd_shamt [W_LCDCTRL_SHAMT-1:0] (
	.clk   (clk_lcd),
	.rst_n (rst_n_lcd),
	.i     (lcdctrl_shamt),
	.o     (lcdctrl_shamt_clklcd)
);

async_fifo #(
	.W_DATA(W_LCD_PIXDATA),
	.W_ADDR(W_PXFIFO_LEVEL - 1)
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

// ----------------------------------------------------------------------------
// AHB-lite busmaster

riscboy_ppu_busmaster #(
	.N_REQ(N_BACKGROUND),
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA)
) inst_riscboy_ppu_busmaster (
	.clk             (clk_ppu),
	.rst_n           (rst_n_ppu),

	.req_vld         (bg_bus_vld[0]), // TODO
	.req_addr        (bg_bus_addr[0]),
	.req_size        (bg_bus_size[0]),
	.req_rdy         (bg_bus_rdy[0]),
	.req_data        (bg_bus_data[0]),

	.ahblm_haddr     (ahblm_haddr),
	.ahblm_hwrite    (ahblm_hwrite),
	.ahblm_htrans    (ahblm_htrans),
	.ahblm_hsize     (ahblm_hsize),
	.ahblm_hburst    (ahblm_hburst),
	.ahblm_hprot     (ahblm_hprot),
	.ahblm_hmastlock (ahblm_hmastlock),
	.ahblm_hready    (ahblm_hready),
	.ahblm_hresp     (ahblm_hresp),
	.ahblm_hwdata    (ahblm_hwdata),
	.ahblm_hrdata    (ahblm_hrdata)
);

endmodule
