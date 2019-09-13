module riscboy_ppu #(
	parameter PXFIFO_DEPTH = 8
) (
	input  wire        clk_ppu,
	input  wire        clk_lcd,
	input  wire        rst_n,

	input  wire        apbs_psel,
	input  wire        apbs_penable,
	input  wire        apbs_pwrite,
	input  wire [15:0] apbs_paddr,
	input  wire [31:0] apbs_pwdata,
	output wire [31:0] apbs_prdata,
	output wire        apbs_pready,
	output wire        apbs_pslverr,

	output wire lcd_cs,
	output wire lcd_dc,
	output wire lcd_sck,
	output wire lcd_mosi
);

localparam W_PXDATA = 16;
// Should be locals but ISIM bug etc etc
parameter W_PXFIFO_LEVEL  = $clog2(PXFIFO_DEPTH + 1);
parameter W_LCDCTRL_SHAMT = $clog2(W_PXDATA + 1);

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

wire [W_PXDATA-1:0]        pxfifo_direct_wdata;
wire                       pxfifo_direct_wen;

wire                       pxfifo_wfull;
wire                       pxfifo_wempty;
wire [W_PXFIFO_LEVEL-1:0]  pxfifo_wlevel;

wire [W_LCDCTRL_SHAMT-1:0] lcdctrl_shamt;
wire                       lcdctrl_busy;

riscboy_ppu_regs regs (
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

	.lcd_pxfifo_o           (pxfifo_direct_wdata),
	.lcd_pxfifo_wen         (pxfifo_direct_wen),
	.lcd_csr_pxfifo_empty_i (pxfifo_wempty),
	.lcd_csr_pxfifo_full_i  (pxfifo_wfull),
	.lcd_csr_pxfifo_level_i (pxfifo_wlevel),
	.lcd_csr_lcd_cs_o       (lcd_cs),
	.lcd_csr_lcd_dc_o       (lcd_dc),
	.lcd_csr_lcd_shiftcnt_o (lcdctrl_shamt),
	.lcd_csr_tx_busy_i      (lcdctrl_busy)
);

// ----------------------------------------------------------------------------
// LCD shifter and clock crossing

wire                       lcdctrl_busy_clklcd;
wire [W_LCDCTRL_SHAMT-1:0] lcdctrl_shamt_clklcd;

wire [W_PXDATA-1:0] lcd_rdata;
wire pxfifo_rempty;
wire pxfifo_rdy;
wire pxfifo_pop = pxfifo_rdy && !pxfifo_rempty;

sync_1bit sync_lcd_busy (
	.clk   (clk_ppu),
	.rst_n (rst_n_ppu),
	.i     (lcdctrl_busy_clklcd),
	.o     (lcdctrL_busy)
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
	.W_DATA(W_PXDATA),
	.W_ADDR(W_PXFIFO_LEVEL - 1)
) inst_async_fifo (
	.wclk   (clk_ppu),
	.wrst_n (rst_n_ppu),

	.wdata  (pxfifo_direct_wdata),
	.wpush  (pxfifo_direct_wen),
	.wfull  (pxfifo_wfull),
	.wempty (pxfifo_wempty),
	.wlevel (pxfifo_wlevel),

	.rclk   (clk_lcd),
	.rrst_n (rst_n_lcd),

	.rdata  (),
	.rpop   (pxfifo_pop),
	.rfull  (/* unused */),
	.rempty (rempty),
	.rlevel (/* unused */)
);

riscboy_ppu_dispctrl #(
	.W_DATA (W_PXDATA)
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
