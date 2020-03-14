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
`default_nettype none

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
localparam W_COORD_FRAC = 8;
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
wire                      vsync;
wire                      hsync;

ppu_regs regs (
	.clk                    (clk_ppu),
	.rst_n                  (rst_n_ppu),

	.apbs_psel              (apbs_psel && !apbs_paddr[11]), // TODO clean up this hack for mapping palette RAM at 2kB
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
	.lcd_csr_pxfifo_level_i ({2'h0, pxfifo_wlevel}),
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
// Vsync and run/halt logic
//
// We don't allow the user to halt the PPU arbitrarily, to avoid some very
// messy cleanup. Always run until either end of scanline or end of frame,
// depending on user config (both of which are triggered by a command
// processor SYNC instruction). Optionally, an IRQ is generated on either of
// these events.

reg [W_COORD_SY-1:0] raster_y;
reg                  ppu_running;

// hsync is generated by the cproc's SYNC instruction
assign vsync = hsync && raster_y == dispsize_h;
assign csr_running = ppu_running;

always @ (posedge clk_ppu or negedge rst_n_ppu) begin
	if (!rst_n_ppu) begin
		raster_y <= {W_COORD_SY{1'b0}};
		ppu_running <= 1'b0;
	end else begin
		raster_y <= vsync ? {W_COORD_SY{1'b0}} : raster_y + hsync;
		ppu_running <= (ppu_running || csr_run)
			&& !(vsync && csr_halt_vsync)
			&& !(hsync && csr_halt_hsync);
	end
end

assign irq = |({ints_hsync, ints_vsync} & {inte_hsync, inte_vsync});

// ----------------------------------------------------------------------------
// Command processor

wire                  cproc_bus_aph_vld;
wire                  cproc_bus_aph_rdy;
wire [W_HADDR-1:0]    cproc_bus_aph_addr;
wire [1:0]            cproc_bus_aph_size = 2'h2;
wire                  cproc_bus_dph_vld;
wire [W_HDATA-1:0]    cproc_bus_dph_data;

wire                  blitter_scanbuf_rdy;

wire                  cgen_start_affine;
wire                  cgen_start_simple;
wire [W_COORD_UV-1:0] cgen_raster_offs_x;
wire [W_COORD_UV-1:0] cgen_raster_offs_y;
wire [W_HDATA-1:0]    cgen_aparam_data;
wire                  cgen_aparam_vld;
wire                  cgen_aparam_rdy;

wire                  span_start;
wire [W_COORD_SX-1:0] span_x0;
wire [W_COORD_SX-1:0] span_count;
wire [W_SPANTYPE-1:0] span_type;
wire [1:0]            span_pixmode;
wire [2:0]            span_paloffs;
wire [14:0]           span_fill_colour;
wire [W_HADDR-1:0]    span_tilemap_ptr;
wire [W_HADDR-1:0]    span_texture_ptr;
wire [2:0]            span_texsize;
wire                  span_tilesize;
wire                  span_ablit_halfsize;
wire                  span_done;

riscboy_ppu_cproc #(
	.W_COORD_SX  (W_COORD_SX),
	.W_COORD_SY  (W_COORD_SY),
	.W_COORD_UV  (W_COORD_UV),
	.W_SPAN_TYPE (W_SPANTYPE),
	.W_ADDR      (W_HADDR),
	.W_DATA      (W_HDATA)
) cproc (
	.clk                 (clk_ppu),
	.rst_n               (rst_n_ppu),

	.ppu_running         (ppu_running),
	.entrypoint          (cproc_pc_wdata),
	.entrypoint_vld      (cproc_pc_wen),

	.bus_addr_vld        (cproc_bus_aph_vld),
	.bus_addr_rdy        (cproc_bus_aph_rdy),
	.bus_addr            (cproc_bus_aph_addr),
	.bus_data_vld        (cproc_bus_dph_vld),
	.bus_data            (cproc_bus_dph_data),

	.beam_y              (raster_y),
	.hsync               (hsync),
	.scanbuf_rdy         (blitter_scanbuf_rdy),

	.cgen_start_affine   (cgen_start_affine),
	.cgen_start_simple   (cgen_start_simple),
	.cgen_raster_offs_x  (cgen_raster_offs_x),
	.cgen_raster_offs_y  (cgen_raster_offs_y),
	.cgen_aparam_data    (cgen_aparam_data),
	.cgen_aparam_vld     (cgen_aparam_vld),
	.cgen_aparam_rdy     (cgen_aparam_rdy),

	.span_start          (span_start),
	.span_x0             (span_x0),
	.span_count          (span_count),
	.span_type           (span_type),
	.span_pixmode        (span_pixmode),
	.span_paloffs        (span_paloffs),
	.span_fill_colour    (span_fill_colour),
	.span_tilemap_ptr    (span_tilemap_ptr),
	.span_texture_ptr    (span_texture_ptr),
	.span_texsize        (span_texsize),
	.span_tilesize       (span_tilesize),
	.span_ablit_halfsize (span_ablit_halfsize),
	.span_done           (span_done)
);

// ----------------------------------------------------------------------------
// Address generation

wire [W_COORD_UV-1:0] cgen_out_u;
wire [W_COORD_UV-1:0] cgen_out_v;
wire                  cgen_out_vld;
wire                  cgen_out_rdy_tile = 1'b0; // FIXME
wire                  cgen_out_rdy_blit;
wire                  cgen_out_rdy = cgen_out_rdy_tile || cgen_out_rdy_blit;

`ifdef FORMAL
always @ (posedge clk) if (rst_n) assert(!(cgen_out_rdy_tile && cgen_out_rdy_blit));
`endif

riscboy_ppu_affine_coord_gen #(
	.W_COORD_INT  (W_COORD_UV),
	.W_COORD_FRAC (W_COORD_FRAC),
	.W_BUS_DATA   (W_HDATA)
) cgen (
	.clk           (clk_ppu),
	.rst_n         (rst_n_ppu),
	.start_affine  (cgen_start_affine),
	.start_simple  (cgen_start_simple),
	.raster_offs_x (cgen_raster_offs_x),
	.raster_offs_y (cgen_raster_offs_y),
	.aparam_data   (cgen_aparam_data),
	.aparam_vld    (cgen_aparam_vld),
	.aparam_rdy    (cgen_aparam_rdy),
	.out_u         (cgen_out_u),
	.out_v         (cgen_out_v),
	.out_vld       (cgen_out_vld),
	.out_rdy       (cgen_out_rdy)
);

wire                  pixel_bus_aph_vld;
wire                  pixel_bus_aph_rdy;
wire [W_HADDR-1:0]    pixel_bus_aph_addr;
wire [1:0]            pixel_bus_aph_size;
wire                  pixel_bus_dph_vld;
wire [W_HDATA-1:0]    pixel_bus_dph_data;

wire [3:0]            pinfo_u;
wire                  pinfo_discard;
wire                  pinfo_vld;
wire                  pinfo_rdy;

riscboy_ppu_pixel_agu #(
	.W_COORD_SX  (W_COORD_SX),
	.W_COORD_UV  (W_COORD_UV),
	.W_SPAN_TYPE (W_SPANTYPE),
	.W_ADDR      (W_HADDR)
) pixel_agu (
	.clk                 (clk_ppu),
	.rst_n               (rst_n_ppu),

	.bus_addr_vld        (pixel_bus_aph_vld),
	.bus_addr_rdy        (pixel_bus_aph_rdy),
	.bus_size            (pixel_bus_aph_size),
	.bus_addr            (pixel_bus_aph_addr),

	.span_start          (span_start),
	.span_count          (span_count),
	.span_type           (span_type),
	.span_pixmode        (span_pixmode),
	.span_texture_ptr    (span_texture_ptr),
	.span_texsize        (span_texsize),
	.span_tilesize       (span_tilesize),
	.span_ablit_halfsize (span_ablit_halfsize),

	.cgen_u              (cgen_out_u),
	.cgen_v              (cgen_out_v),
	.cgen_vld            (cgen_out_vld),
	.cgen_rdy            (cgen_out_rdy_blit),

	.tinfo_u             (/* TODO tinfo_u*/),
	.tinfo_v             (/* TODO tinfo_v*/),
	.tinfo_tilenum       (/* TODO tinfo_tilenum*/),
	.tinfo_discard       (/* TODO tinfo_discard*/),
	.tinfo_vld           (/* TODO tinfo_vld*/),
	.tinfo_rdy           (/* TODO tinfo_rdy*/),

	.pinfo_u             (pinfo_u),
	.pinfo_discard       (pinfo_discard),
	.pinfo_vld           (pinfo_vld),
	.pinfo_rdy           (pinfo_rdy)
);


// ----------------------------------------------------------------------------
// Pixel data unpack

wire                  blender_in_vld;
wire                  blender_in_blank;
wire [W_PIXDATA-1:0]  blender_in_data;
wire                  blender_in_paletted;

riscboy_ppu_pixel_unpack #(
	.W_COORD_SX  (W_COORD_SX),
	.W_SPAN_TYPE (W_SPANTYPE)
) pixel_unpack (
	.clk              (clk_ppu),
	.rst_n            (rst_n_ppu),

	.in_data          (pixel_bus_dph_data[W_PIXDATA-1:0]),
	.in_vld           (pixel_bus_dph_vld),

	.pinfo_u          (pinfo_u),
	.pinfo_discard    (pinfo_discard),
	.pinfo_vld        (pinfo_vld),
	.pinfo_rdy        (pinfo_rdy),

	.span_start       (span_start),
	.span_x0          (span_x0),
	.span_count       (span_count),
	.span_type        (span_type),
	.span_pixmode     (span_pixmode),
	.span_paloffs     (span_paloffs),
	.span_fill_colour (span_fill_colour),
	.span_done        (/* unused */),

	.out_vld          (blender_in_vld),
	.out_blank        (blender_in_blank),
	.out_data         (blender_in_data),
	.out_paletted     (blender_in_paletted)
);


// ----------------------------------------------------------------------------
// Scanline buffers, blender and scanout

// Currently we are just doing 1-bit transparency, so blender does not require
// read-modify-write. This means all writes are from blender, and all reads
// are from scanout, so the read/write buses are commoned up across the two
// scanline buffers, and we just decode *strobes* based on which scanbuf the
// blender/scanout is operating on.

reg                   blitter_current_scanbuf;
reg                   scanout_current_scanbuf;
reg  [1:0]            scanbuf_dirty;

wire [W_COORD_SX-1:0] scanbuf_waddr;
wire [W_PIXDATA-2:0]  scanbuf_wdata;
wire                  scanbuf_wen;

wire [W_COORD_SX-1:0] scanbuf_raddr;
wire [W_PIXDATA-2:0]  scanbuf_rdata0;
wire [W_PIXDATA-2:0]  scanbuf_rdata1;
wire                  scanbuf_ren;

sram_sync_1r1w #(
	.WIDTH (W_PIXDATA - 1), // no alpha
	.DEPTH (1 << W_COORD_SX)
) scanbuf0 (
	.clk   (clk_ppu),
	.waddr (scanbuf_waddr),
	.wdata (scanbuf_wdata),
	.wen   (scanbuf_wen && !blitter_current_scanbuf),
	.raddr (scanbuf_raddr),
	.rdata (scanbuf_rdata0),
	.ren   (scanbuf_ren && !scanout_current_scanbuf)
);

sram_sync_1r1w #(
	.WIDTH (W_PIXDATA - 1),
	.DEPTH (1 << W_COORD_SX)
) scanbuf1 (
	.clk   (clk_ppu),
	.waddr (scanbuf_waddr),
	.wdata (scanbuf_wdata),
	.wen   (scanbuf_wen && blitter_current_scanbuf),
	.raddr (scanbuf_raddr),
	.rdata (scanbuf_rdata1),
	.ren   (scanbuf_ren && scanout_current_scanbuf)
);

riscboy_ppu_blender #(
	.W_PIXDATA     (W_PIXDATA),
	.W_COORD_SX    (W_COORD_SX),
	.W_PALETTE_IDX (8)
) blender (
	.clk           (clk_ppu),
	.rst_n         (rst_n_ppu),

	.in_vld        (blender_in_vld),
	.in_data       (blender_in_data),
	.in_paletted   (blender_in_paletted),
	.in_blank      (blender_in_blank),

	.pram_waddr    (apbs_paddr[7:0]), // TODO this sucks
	.pram_wdata    (apbs_pwdata[W_PIXDATA-1:0]),
	.pram_wen      (apbs_pwrite && apbs_penable && apbs_psel && apbs_paddr[11]),

	.scanbuf_waddr (scanbuf_waddr),
	.scanbuf_wdata (scanbuf_wdata),
	.scanbuf_wen   (scanbuf_wen),

	.span_start    (span_start),
	.span_x0       (span_x0),
	.span_count    (span_count),
	.span_done     (span_done)
);

// Scan out to pixel FIFO
// TODO this is a lot of logic to have at this hierarchy level, move this to a better place, once that place is apparent

reg pxfifo_scan_wen;
reg scanout_buf_last_read;
reg [W_COORD_SX-1:0] scanout_x;

wire [W_PIXDATA-2:0] pxfifo_scan_wdata = scanout_buf_last_read ? scanbuf_rdata1 : scanbuf_rdata0;
wire scanout_done = scanbuf_ren && scanout_x == dispsize_w;
assign scanbuf_raddr = scanout_x;
assign scanbuf_ren = scanbuf_dirty[scanout_current_scanbuf] && (
	pxfifo_wlevel < PXFIFO_DEPTH - 2 || !(pxfifo_wfull || pxfifo_scan_wen)
);

always @ (posedge clk_ppu or negedge rst_n_ppu) begin
	if (!rst_n_ppu) begin
		scanout_x <= {W_COORD_SX{1'b0}};
		pxfifo_scan_wen <= 1'b0;
		scanout_buf_last_read <= 1'b0;
	end else begin
		pxfifo_scan_wen <= scanbuf_ren;
		if (scanbuf_ren) begin
			scanout_buf_last_read <= scanout_current_scanbuf;
			scanout_x <= scanout_done ? {W_COORD_SX{1'b0}} : scanout_x + 1'b1;
		end
	end
end

// Scanbuffer clean/dirty flags

always @ (posedge clk_ppu or negedge rst_n_ppu) begin
	if (!rst_n_ppu) begin
		blitter_current_scanbuf <= 1'b0;
		scanout_current_scanbuf <= 1'b0;
		scanbuf_dirty <= 2'b00;
	end else begin
		if (hsync) begin
			blitter_current_scanbuf <= !blitter_current_scanbuf;
			scanbuf_dirty[blitter_current_scanbuf] <= 1'b1;
		end
		if (scanout_done) begin
			scanout_current_scanbuf <= !scanout_current_scanbuf;
			scanbuf_dirty[scanout_current_scanbuf] <= 1'b0;
		end
	end
end

assign blitter_scanbuf_rdy = !scanbuf_dirty[blitter_current_scanbuf];

// ----------------------------------------------------------------------------
// LCD shifter and clock crossing

wire                       lcdctrl_busy_clklcd;
wire                       lcdctrl_shamt_clklcd;

wire [W_LCD_PIXDATA-1:0]   pxfifo_wdata = pxfifo_direct_wen ? pxfifo_direct_wdata :
	{pxfifo_scan_wdata[14:5], 1'b0, pxfifo_scan_wdata[4:0]};
wire                       pxfifo_wen = pxfifo_direct_wen || pxfifo_scan_wen;

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
) pixel_fifo (
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
) dispctrl (
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
// Busmaster

riscboy_ppu_busmaster #(
	.N_REQ     (2),
	.W_ADDR    (W_HADDR),
	.W_DATA    (W_HDATA),
	.ADDR_MASK (ADDR_MASK)
) busmaster (
	.clk             (clk_ppu),
	.rst_n           (rst_n_ppu),
	.ppu_running     (ppu_running),

	// Lowest significance wins
	.req_aph_vld     ({pixel_bus_aph_vld  , cproc_bus_aph_vld  }),
	.req_aph_rdy     ({pixel_bus_aph_rdy  , cproc_bus_aph_rdy  }),
	.req_aph_addr    ({pixel_bus_aph_addr , cproc_bus_aph_addr }),
	.req_aph_size    ({pixel_bus_aph_size , cproc_bus_aph_size }),
	.req_dph_vld     ({pixel_bus_dph_vld  , cproc_bus_dph_vld  }),
	.req_dph_data    ({pixel_bus_dph_data , cproc_bus_dph_data }),

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
