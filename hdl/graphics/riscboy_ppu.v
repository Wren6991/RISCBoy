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
localparam W_COORD = 10;
parameter N_LAYERS = 2;
// Should be locals but ISIM bug etc etc:
parameter W_PXFIFO_LEVEL  = $clog2(PXFIFO_DEPTH + 1);
parameter W_LCDCTRL_SHAMT = $clog2(W_LCD_PIXDATA + 1);
parameter W_LOG_COORD = $clog2(W_COORD);
parameter W_LAYERSEL = N_LAYERS > 1 ? $clog2(N_LAYERS) : 1;
parameter W_SHIFTCTR = $clog2(W_DATA);

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

localparam N_BACKGROUND = 2;
wire [N_BACKGROUND-1:0]             bg_csr_en;
wire [N_BACKGROUND*W_PIXMODE-1:0]   bg_csr_pixmode;
wire [N_BACKGROUND-1:0]             bg_csr_transparency;
wire [N_BACKGROUND-1:0]             bg_csr_tilesize;
wire [N_BACKGROUND*W_LOG_COORD-1:0] bg_csr_pfwidth;
wire [N_BACKGROUND*W_LOG_COORD-1:0] bg_csr_pfheight;
wire [N_BACKGROUND*4-1:0]           bg_csr_paloffs;
wire [N_BACKGROUND-1:0]             bg_flush;
wire [N_BACKGROUND*W_COORD-1:0]     bg_scroll_y;
wire [N_BACKGROUND*W_COORD-1:0]     bg_scroll_x;
wire [N_BACKGROUND*24-1:0]          bg_tsbase;
wire [N_BACKGROUND*24-1:0]          bg_tmbase;

localparam N_SPRITE = 4;
wire [N_SPRITE-1:0]           sprite_en;
wire [N_SPRITE*8-1:0]         sprite_tile;
wire [N_SPRITE*4-1:0]         sprite_paloffs;
wire [N_SPRITE*W_COORD-1:0]   sprite_pos_x;
wire [N_SPRITE*W_COORD-1:0]   sprite_pos_y;
wire [N_SPRITE-1:0]           sprite_flush;
wire                          sprite_flush_all;
wire [23:0]                   sprite_tsbase;
wire [2:0]                    sprite_pixmode;
wire                          sprite_tilesize;

wire [W_LCD_PIXDATA-1:0]   pxfifo_direct_wdata;
wire                       pxfifo_direct_wen;

wire                       pxfifo_wfull;
wire                       pxfifo_wempty;
wire [W_PXFIFO_LEVEL-1:0]  pxfifo_wlevel;

wire [W_LCDCTRL_SHAMT-1:0] lcdctrl_shamt;
wire                       lcdctrl_busy;

ppu_regs regs (
	.clk                       (clk_ppu),
	.rst_n                     (rst_n_ppu),

	.apbs_psel                 (apbs_psel && !apbs_paddr[11]), // FIXME terrible hack to map PRAM write port
	.apbs_penable              (apbs_penable),
	.apbs_pwrite               (apbs_pwrite),
	.apbs_paddr                (apbs_paddr),
	.apbs_pwdata               (apbs_pwdata),
	.apbs_prdata               (apbs_prdata),
	.apbs_pready               (apbs_pready),
	.apbs_pslverr              (apbs_pslverr),

	.csr_run_o                 (csr_run),
	.csr_halt_o                (csr_halt),
	.csr_running_i             (csr_running),
	.csr_halt_hsync_o          (csr_halt_hsync),
	.csr_halt_vsync_o          (csr_halt_vsync),

	.default_bg_colour_o       (default_bg_colour),

	.dispsize_w_o              (raster_w),
	.dispsize_h_o              (raster_h),
	.beam_x_i                  (raster_x),
	.beam_y_i                  (raster_y),

	.concat_bg_en_o            (bg_csr_en),
	.concat_bg_pixmode_o       (bg_csr_pixmode),
	.concat_bg_transparency_o  (bg_csr_transparency),
	.concat_bg_tilesize_o      (bg_csr_tilesize),
	.concat_bg_pfwidth_o       (bg_csr_pfwidth),
	.concat_bg_pfheight_o      (bg_csr_pfheight),
	.concat_bg_paloffs_o       (bg_csr_paloffs),
	.concat_bg_scroll_y_o      (bg_scroll_y),
	.concat_bg_scroll_x_o      (bg_scroll_x),
	.concat_bg_tsbase_o        (bg_tsbase),
	.concat_bg_tmbase_o        (bg_tmbase),

	.concat_sp_en_o            (sprite_en),
	.concat_sp_tile_o          (sprite_tile),
	.concat_sp_paloffs_o       (sprite_paloffs),
	.concat_sp_pos_x_o         (sprite_pos_x),
	.concat_sp_pos_y_o         (sprite_pos_y),
	.sp_csr_pixmode_o          (sprite_pixmode),
	.sp_csr_tilesize_o         (sprite_tilesize),
	.sp_tsbase_o               (sprite_tsbase),

	.lcd_pxfifo_o              (pxfifo_direct_wdata),
	.lcd_pxfifo_wen            (pxfifo_direct_wen),
	.lcd_csr_pxfifo_empty_i    (pxfifo_wempty),
	.lcd_csr_pxfifo_full_i     (pxfifo_wfull),
	.lcd_csr_pxfifo_level_i    (pxfifo_wlevel & 6'h0),
	.lcd_csr_lcd_cs_o          (lcd_cs),
	.lcd_csr_lcd_dc_o          (lcd_dc),
	.lcd_csr_lcd_shiftcnt_o    (lcdctrl_shamt),
	.lcd_csr_tx_busy_i         (lcdctrl_busy),

	.wstrobe_bg_flush          (bg_flush),
	.wstrobe_sp_flush          (sprite_flush),
	.wstrobe_sp_flush_all      (sprite_flush_all)
);

// ----------------------------------------------------------------------------
// Blender and raster counter

wire hsync;
wire vsync;

// hsync and vsync are registered signals from raster counter which we must respond to precisely.
// csr run/halt are decoded from the bus (-> long paths), but we can respond a little more loosely.
reg ppu_running_reg;
wire ppu_running = ppu_running_reg && !(csr_halt_vsync && vsync || csr_halt_hsync && hsync);
assign csr_running = ppu_running;

always @ (posedge clk_ppu or negedge rst_n_ppu) begin
	if (!rst_n_ppu) begin
		ppu_running_reg <= 1'b0;
	end else begin
		ppu_running_reg <= (ppu_running || csr_run) && !csr_halt;
	end
end

wire raster_count_advance;

riscboy_ppu_raster_counter #(
	.W_COORD (W_COORD)
) raster_counter_u (
	.clk         (clk_ppu),
	.rst_n       (rst_n_ppu),
	.en          (raster_count_advance),
	.clr         (1'b0), // FIXME
	.w           (raster_w),
	.h           (raster_h),
	.x           (raster_x),
	.y           (raster_y),
	.start_row   (hsync),
	.start_frame (vsync)
);

wire                                          bg_blend_vld     [0:N_BACKGROUND-1];
wire                                          bg_blend_rdy     [0:N_BACKGROUND-1];
wire                                          bg_blend_alpha   [0:N_BACKGROUND-1];
wire [W_PIXDATA-1:0]                          bg_blend_pixdata [0:N_BACKGROUND-1];
wire [W_PIXMODE-1:0]                          bg_blend_mode    [0:N_BACKGROUND-1];
wire [W_LAYERSEL-1:0]                         bg_blend_layer   [0:N_BACKGROUND-1];

wire                                          sp_blend_vld     [0:N_SPRITE-1];
wire                                          sp_blend_rdy     [0:N_SPRITE-1];
wire                                          sp_blend_alpha   [0:N_SPRITE-1];
wire [W_PIXDATA-1:0]                          sp_blend_pixdata [0:N_SPRITE-1];
wire [W_PIXMODE-1:0]                          sp_blend_mode    [0:N_SPRITE-1];
wire [W_LAYERSEL-1:0]                         sp_blend_layer   [0:N_SPRITE-1];

wire [N_SPRITE+N_BACKGROUND-1:0]              blend_in_vld;
wire [N_SPRITE+N_BACKGROUND-1:0]              blend_in_rdy;
wire [N_SPRITE+N_BACKGROUND-1:0]              blend_in_alpha;
wire [(N_SPRITE+N_BACKGROUND)*W_PIXDATA-1:0]  blend_in_pixdata;
wire [(N_SPRITE+N_BACKGROUND)*W_PIXMODE-1:0]  blend_in_mode;
wire [(N_SPRITE+N_BACKGROUND)*W_LAYERSEL-1:0] blend_in_layer;

wire                                          blend_out_vld;
wire                                          blend_out_rdy;
wire [W_PIXDATA-1:0]                          blend_out_pixdata;
wire                                          blend_out_paletted;

// Collate sprite + background blend requests. Really wish I was using nMigen right now
genvar bg;
generate
for (bg = 0; bg < N_BACKGROUND; bg = bg + 1) begin: bg_blend_tieoff
	assign bg_blend_layer[bg] = 0; // FIXME
	assign bg_blend_mode[bg] = bg_csr_pixmode[W_PIXMODE * bg +: W_PIXMODE];
	assign bg_blend_rdy[bg] = blend_in_rdy[bg];
end
endgenerate

genvar sp;
generate
for (sp = 0; sp < N_SPRITE; sp = sp + 1) begin: sp_blend_tieoff
	assign sp_blend_layer[sp] = 0; // FIXME
	assign sp_blend_mode[sp] = sprite_pixmode;
	assign sp_blend_rdy[sp] = blend_in_rdy[sp + N_BACKGROUND];
end
endgenerate

// Reverse connections. Lowest blender request wins tie break, and we want:
// - Sprites beat backgrounds
// - Higher-numbered backgrounds win
// A consequence of this is that higher-numbered sprites win.
genvar g;
generate
for (g = 0; g < N_SPRITE + N_BACKGROUND; g = g + 1) begin: blend_input_hookup
	integer grev = N_SPRITE + N_BACKGROUND - 1 - g;
	if (g < N_BACKGROUND) begin
		assign blend_in_vld     [grev * 1 +: 1]                   = bg_blend_vld     [g];
		assign blend_in_alpha   [grev * 1 +: 1]                   = bg_blend_alpha   [g];
		assign blend_in_pixdata [grev * W_PIXDATA +: W_PIXDATA]   = bg_blend_pixdata [g];
		assign blend_in_mode    [grev * W_PIXMODE +: W_PIXMODE]   = bg_blend_mode    [g];
		assign blend_in_layer   [grev * W_LAYERSEL +: W_LAYERSEL] = bg_blend_layer   [g];
	end else begin
		assign blend_in_vld     [grev * 1 +: 1]                   = sp_blend_vld     [g - N_BACKGROUND];
		assign blend_in_alpha   [grev * 1 +: 1]                   = sp_blend_alpha   [g - N_BACKGROUND];
		assign blend_in_pixdata [grev * W_PIXDATA +: W_PIXDATA]   = sp_blend_pixdata [g - N_BACKGROUND];
		assign blend_in_mode    [grev * W_PIXMODE +: W_PIXMODE]   = sp_blend_mode    [g - N_BACKGROUND];
		assign blend_in_layer   [grev * W_LAYERSEL +: W_LAYERSEL] = sp_blend_layer   [g - N_BACKGROUND];

	end
end
endgenerate

riscboy_ppu_blender #(
	.N_REQ(N_BACKGROUND + N_SPRITE),
	.N_LAYERS(N_LAYERS)
) inst_riscboy_ppu_blender (
	.req_vld           (blend_in_vld),
	.req_rdy           (blend_in_rdy),
	.req_alpha         (blend_in_alpha),
	.req_pixdata       (blend_in_pixdata),
	.req_mode          (blend_in_mode),
	.req_layer         (blend_in_layer),
	.default_bg_colour (default_bg_colour),

	.out_vld           (blend_out_vld),
	.out_rdy           (blend_out_rdy),
	.out_pixdata       (blend_out_pixdata),
	.out_paletted      (blend_out_paletted)
);

assign raster_count_advance = blend_out_vld && blend_out_rdy;

// ----------------------------------------------------------------------------
// Post-blend palette lookup

// FIXME terrible write port mapping

wire                  pmap_in_rdy;
wire                  pmap_out_vld;
wire                  pmap_out_rdy = !pxfifo_wfull;
wire [W_PIXDATA-1:0]  pmap_out_pixdata;

assign blend_out_rdy = pmap_in_rdy && ppu_running;
wire pmap_in_vld = blend_out_vld && ppu_running;

riscboy_ppu_palette_mapper #(
	.W_PIXDATA     (W_PIXDATA),
	.W_PALETTE_IDX (8)
) palette_mapper_u (
	.clk         (clk_ppu),
	.rst_n       (rst_n_ppu),

	.in_vld      (pmap_in_vld),
	.in_rdy      (pmap_in_rdy),
	.in_data     (blend_out_pixdata),
	.in_paletted (blend_out_paletted),

	.pram_waddr  (apbs_paddr[8:1]),
	.pram_wdata  (apbs_pwdata[W_PIXDATA-1:0]),
	.pram_wen    (apbs_psel && apbs_penable && apbs_pwrite && apbs_paddr[11]),

	.out_vld     (pmap_out_vld),
	.out_rdy     (pmap_out_rdy),
	.out_data    (pmap_out_pixdata)
);

// ----------------------------------------------------------------------------
// Backgrounds

wire              bg_bus_vld  [0:N_BACKGROUND-1];
wire [W_ADDR-1:0] bg_bus_addr [0:N_BACKGROUND-1];
wire [1:0]        bg_bus_size [0:N_BACKGROUND-1];
wire [W_DATA-1:0] bg_bus_data [0:N_BACKGROUND-1];
wire              bg_bus_rdy  [0:N_BACKGROUND-1];

generate
for (bg = 0; bg < N_BACKGROUND; bg = bg + 1) begin: bg_instantiate
	riscboy_ppu_background #(
		.W_COORD           (W_COORD),
		.W_OUTDATA         (W_PIXDATA),
		.W_ADDR            (W_ADDR),
		.W_DATA            (W_DATA)
	) bg (
		.clk                (clk_ppu),
		.rst_n              (rst_n_ppu),
		.en                 (bg_csr_en[bg]),
		.flush              (hsync || bg_flush[bg]),
		.beam_x             (raster_x),
		.beam_y             (raster_y),

		.bus_vld            (bg_bus_vld[bg]),
		.bus_addr           (bg_bus_addr[bg]),
		.bus_size           (bg_bus_size[bg]),
		.bus_rdy            (bg_bus_rdy[bg]),
		.bus_data           (bg_bus_data[bg]),

		.cfg_scroll_x       (bg_scroll_x[bg * W_COORD +: W_COORD]),
		.cfg_scroll_y       (bg_scroll_y[bg * W_COORD +: W_COORD]),
		.cfg_log_w          (bg_csr_pfwidth[bg * 4 +: 4]),
		.cfg_log_h          (bg_csr_pfheight[bg * 4 +: 4]),
		.cfg_tileset_base   ({bg_tsbase[bg * 24 +: 24], 8'h0}),
		.cfg_tilemap_base   ({bg_tmbase[bg * 24 +: 24], 8'h0}),
		.cfg_tile_size      (bg_csr_tilesize[bg]),
		.cfg_pixel_mode     (bg_csr_pixmode[bg * W_PIXMODE +: W_PIXMODE]),
		.cfg_transparency   (bg_csr_transparency[bg]),
		.cfg_palette_offset (bg_csr_paloffs[bg * 4 +: 4]),

		.out_vld            (bg_blend_vld[bg]),
		.out_rdy            (bg_blend_rdy[bg]),
		.out_alpha          (bg_blend_alpha[bg]),
		.out_pixdata        (bg_blend_pixdata[bg])
	);
end
endgenerate

// ----------------------------------------------------------------------------
// Sprites and sprite AGU

wire [N_SPRITE-1:0]   sprite_agu_req;
wire [N_SPRITE-1:0]   sprite_agu_ack;
wire                  sprite_agu_active;
wire [W_COORD-1:0]    sprite_agu_x_precount;
wire [4:0]            sprite_agu_x_postcount;
wire [W_SHIFTCTR-1:0] sprite_agu_shift_seek_target;

wire                  sagu_bus_vld;
wire [W_ADDR-1:0]     sagu_bus_addr;
wire [1:0]            sagu_bus_size;
wire [W_DATA-1:0]     sagu_bus_data;
wire                  sagu_bus_rdy;

wire [N_SPRITE-1:0]   sprite_bus_vld;
wire [N_SPRITE-1:0]   sprite_bus_rdy;
wire [N_SPRITE*5-1:0] sprite_bus_postcount;
wire [W_DATA-1:0]     sprite_bus_data;

riscboy_ppu_sprite_agu #(
	.W_DATA   (W_DATA),
	.W_ADDR   (W_ADDR),
	.W_COORD  (W_COORD),
	.N_SPRITE (N_SPRITE)
) sprite_agu (
	.clk                      (clk_ppu),
	.rst_n                    (rst_n_ppu),
	.beam_x                   (raster_x),
	.beam_y                   (raster_y),

	.cfg_sprite_pos_x         (sprite_pos_x),
	.cfg_sprite_pos_y         (sprite_pos_y),
	.cfg_sprite_tile          (sprite_tile),
	.cfg_sprite_tsbase        (sprite_tsbase),
	.cfg_sprite_pixmode       (sprite_pixmode),
	.cfg_sprite_tilesize      (sprite_tilesize),

	.sprite_req               (sprite_agu_req),
	.sprite_ack               (sprite_agu_ack),
	.sprite_active            (sprite_agu_active),
	.sprite_x_precount        (sprite_agu_x_precount),
	.sprite_x_postcount       (sprite_agu_x_postcount),
	.sprite_shift_seek_target (sprite_agu_shift_seek_target),

	.sprite_bus_vld           (sprite_bus_vld),
	.sprite_bus_rdy           (sprite_bus_rdy),
	.sprite_bus_postcount     (sprite_bus_postcount),
	.sprite_bus_data          (sprite_bus_data),

	.bus_vld                  (sagu_bus_vld),
	.bus_addr                 (sagu_bus_addr),
	.bus_size                 (sagu_bus_size),
	.bus_rdy                  (sagu_bus_rdy),
	.bus_data                 (sagu_bus_data)
);

generate
for (sp = 0; sp < N_SPRITE; sp = sp + 1) begin: sprite_instantiate
	riscboy_ppu_sprite #(
		.W_DATA    (W_DATA),
		.W_OUTDATA (W_PIXDATA),
		.W_COORD   (W_COORD)
	) sp (
		.clk                   (clk_ppu),
		.rst_n                 (rst_n_ppu),
		.flush                 (hsync || sprite_flush[sp] || sprite_flush_all),
		.en                    (sprite_en[sp]),

		.cfg_pixel_mode        (sprite_pixmode),
		.cfg_palette_offs      (sprite_paloffs[sp * 4 +: 4]),

		.agu_req               (sprite_agu_req[sp]),
		.agu_ack               (sprite_agu_ack[sp]),
		.agu_active            (sprite_agu_active),
		.agu_x_precount        (sprite_agu_x_precount),
		.agu_x_postcount       (sprite_agu_x_postcount),
		.agu_shift_seek_target (sprite_agu_shift_seek_target),

		.bus_vld               (sprite_bus_vld[sp]),
		.bus_rdy               (sprite_bus_rdy[sp]),
		.bus_postcount         (sprite_bus_postcount[sp * 5 +: 5]),
		.bus_data              (sprite_bus_data),

		.out_vld               (sp_blend_vld[sp]),
		.out_rdy               (sp_blend_rdy[sp]),
		.out_alpha             (sp_blend_alpha[sp]),
		.out_pixdata           (sp_blend_pixdata[sp])
	);
end
endgenerate

// ----------------------------------------------------------------------------
// LCD shifter and clock crossing

wire                       lcdctrl_busy_clklcd;
wire [W_LCDCTRL_SHAMT-1:0] lcdctrl_shamt_clklcd;

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

localparam N_BUS_REQ = N_BACKGROUND + 1;

wire [N_BUS_REQ-1:0]        bus_req_vld;
wire [N_BUS_REQ*W_ADDR-1:0] bus_req_addr;
wire [N_BUS_REQ*2-1:0]      bus_req_size;
wire [N_BUS_REQ-1:0]        bus_req_rdy;
wire [N_BUS_REQ*W_DATA-1:0] bus_req_data;

genvar req;
generate
for (req = 0; req < N_BUS_REQ; req = req + 1) begin: bus_req_hookup
	if (req < N_BACKGROUND) begin
		assign bus_req_vld [req]                    = bg_bus_vld[req];
		assign bus_req_addr[req * W_ADDR +: W_ADDR] = bg_bus_addr[req];
		assign bus_req_size[req * 2 +: 2]           = bg_bus_size[req];
		assign bg_bus_rdy  [req]                    = bus_req_rdy[req];
		assign bg_bus_data [req]                    = bus_req_data[req * W_DATA +: W_DATA];
	end else begin
		assign bus_req_vld [req]                    = sagu_bus_vld;
		assign bus_req_addr[req * W_ADDR +: W_ADDR] = sagu_bus_addr;
		assign bus_req_size[req * 2 +: 2]           = sagu_bus_size;
		assign sagu_bus_rdy                         = bus_req_rdy[req];
		assign sagu_bus_data                        = bus_req_data[req * W_DATA +: W_DATA];
	end
end
endgenerate

riscboy_ppu_busmaster #(
	.N_REQ  (N_BACKGROUND + 1),
	.W_ADDR (W_ADDR),
	.W_DATA (W_DATA)
) inst_riscboy_ppu_busmaster (
	.clk             (clk_ppu),
	.rst_n           (rst_n_ppu),

	.ppu_running     (ppu_running),

	.req_vld         (bus_req_vld),
	.req_addr        (bus_req_addr),
	.req_size        (bus_req_size),
	.req_rdy         (bus_req_rdy),
	.req_data        (bus_req_data),

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
