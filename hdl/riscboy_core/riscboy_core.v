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

// riscboy_core contains the full system, except for Clock, Reset and Power
// (CRaP) which lives in the chip/fpga/testbench top level

module riscboy_core #(
	parameter BOOTRAM_PRELOAD = "",
	parameter CPU_RESET_VECTOR = 32'h200800c0,
	parameter W_SRAM0_ADDR = 18,
	parameter SRAM0_INTERNAL = 0,
	parameter SRAM0_PRELOAD = "", // For INTERNAL only

	parameter DISPLAY_TYPE = "SPI", // Valid values are "SPI" and "DVI"

	// STUB == remove interface to save LUTs
	parameter STUB_UART         = 0,
	parameter STUB_SPI          = 0,
	parameter STUB_PWM          = 0,
	parameter CUTDOWN_PROCESSOR = 0,
	parameter NO_SRAM_WRITE_BUF = 0,
	parameter UART_FIFO_DEPTH   = 4,

	parameter N_PADS = 11 // Let this default
) (
	input wire                     clk_sys,
	input wire                     clk_lcd_pix, // Pixel clock for DVI. Unused for SPI.
	input wire                     clk_lcd_bit, // Pixel clock x5 for DVI. Serial clock for SPI.
	input wire                     rst_n,

	// GPIOs and hard peripheral signals
	output wire [N_PADS-1:0]       padout,
	output wire [N_PADS-1:0]       padoe,
	input  wire [N_PADS-1:0]       padin,

	output wire                    lcd_pwm,
	output wire                    uart_tx,
	input  wire                    uart_rx,
	output wire                    uart_rts,
	input  wire                    uart_cts,
	output wire                    spi_sclk,
	output wire                    spi_cs,
	output wire                    spi_sdo,
	input  wire                    spi_sdi,

	output wire [W_SRAM0_ADDR-1:0] sram_addr,
	inout  wire [15:0]             sram_dq,
	output wire                    sram_ce_n,
	output wire                    sram_we_n,
	output wire                    sram_oe_n,
	output wire [1:0]              sram_byte_n,

	// If interface is SPI, lcdp is {lcd_cs, lcd_dc, lcd_sck, lcd_mosi} and lcdn is zeroes.
	// If interfaces is DVI, lcdp is the positive of {CLK, TMDS2, TMDS1, TMDS0} and lcdn is the negative of these.
	output wire [3:0]              lcdp,
	output wire [3:0]              lcdn
);

localparam W_ADDR = 32;
localparam W_DATA = 32;
localparam W_PADDR = 16;

// =============================================================================
//  Instance interconnects
// =============================================================================

wire               proc0_hready;
wire               proc0_hresp;
wire [W_ADDR-1:0]  proc0_haddr;
wire               proc0_hwrite;
wire [1:0]         proc0_htrans;
wire [2:0]         proc0_hsize;
wire [2:0]         proc0_hburst;
wire [3:0]         proc0_hprot;
wire               proc0_hmastlock;
wire [W_DATA-1:0]  proc0_hwdata;
wire [W_DATA-1:0]  proc0_hrdata;

wire               ppu_hready;
wire               ppu_hresp;
wire [W_ADDR-1:0]  ppu_haddr;
wire               ppu_hwrite;
wire [1:0]         ppu_htrans;
wire [2:0]         ppu_hsize;
wire [2:0]         ppu_hburst;
wire [3:0]         ppu_hprot;
wire               ppu_hmastlock;
wire [W_DATA-1:0]  ppu_hwdata;
wire [W_DATA-1:0]  ppu_hrdata;

wire               bridge_hready;
wire               bridge_hready_resp;
wire               bridge_hresp;
wire [W_ADDR-1:0]  bridge_haddr;
wire               bridge_hwrite;
wire [1:0]         bridge_htrans;
wire [2:0]         bridge_hsize;
wire [2:0]         bridge_hburst;
wire [3:0]         bridge_hprot;
wire               bridge_hmastlock;
wire [W_DATA-1:0]  bridge_hwdata;
wire [W_DATA-1:0]  bridge_hrdata;

wire               sram0_hready;
wire               sram0_hready_resp;
wire               sram0_hresp;
wire [W_ADDR-1:0]  sram0_haddr;
wire               sram0_hwrite;
wire [1:0]         sram0_htrans;
wire [2:0]         sram0_hsize;
wire [2:0]         sram0_hburst;
wire [3:0]         sram0_hprot;
wire               sram0_hmastlock;
wire [W_DATA-1:0]  sram0_hwdata;
wire [W_DATA-1:0]  sram0_hrdata;

wire               sram1_hready;
wire               sram1_hready_resp;
wire               sram1_hresp;
wire [W_ADDR-1:0]  sram1_haddr;
wire               sram1_hwrite;
wire [1:0]         sram1_htrans;
wire [2:0]         sram1_hsize;
wire [2:0]         sram1_hburst;
wire [3:0]         sram1_hprot;
wire               sram1_hmastlock;
wire [W_DATA-1:0]  sram1_hwdata;
wire [W_DATA-1:0]  sram1_hrdata;

wire [W_PADDR-1:0] bridge_paddr;
wire               bridge_psel;
wire               bridge_penable;
wire               bridge_pwrite;
wire [W_DATA-1:0]  bridge_pwdata;
wire               bridge_pready;
wire [W_DATA-1:0]  bridge_prdata;
wire               bridge_pslverr;

wire [W_PADDR-1:0] tbman_paddr;
wire               tbman_psel;
wire               tbman_penable;
wire               tbman_pwrite;
wire [W_DATA-1:0]  tbman_pwdata;
wire               tbman_pready;
wire [W_DATA-1:0]  tbman_prdata;
wire               tbman_pslverr;

wire [15:0]        tbman_irq_force;

wire [W_PADDR-1:0] uart_paddr;
wire               uart_psel;
wire               uart_penable;
wire               uart_pwrite;
wire [W_DATA-1:0]  uart_pwdata;
wire               uart_pready;
wire [W_DATA-1:0]  uart_prdata;
wire               uart_pslverr;
wire               uart_irq;

wire [W_PADDR-1:0] spi_paddr;
wire               spi_psel;
wire               spi_penable;
wire               spi_pwrite;
wire [W_DATA-1:0]  spi_pwdata;
wire               spi_pready;
wire [W_DATA-1:0]  spi_prdata;
wire               spi_pslverr;

wire [W_PADDR-1:0] pwm_paddr;
wire               pwm_psel;
wire               pwm_penable;
wire               pwm_pwrite;
wire [W_DATA-1:0]  pwm_pwdata;
wire               pwm_pready;
wire [W_DATA-1:0]  pwm_prdata;
wire               pwm_pslverr;

wire [W_PADDR-1:0] gpio_paddr;
wire               gpio_psel;
wire               gpio_penable;
wire               gpio_pwrite;
wire [W_DATA-1:0]  gpio_pwdata;
wire               gpio_pready;
wire [W_DATA-1:0]  gpio_prdata;
wire               gpio_pslverr;

wire [W_PADDR-1:0] ppu_apbs_paddr;
wire               ppu_apbs_psel;
wire               ppu_apbs_penable;
wire               ppu_apbs_pwrite;
wire [W_DATA-1:0]  ppu_apbs_pwdata;
wire               ppu_apbs_pready;
wire [W_DATA-1:0]  ppu_apbs_prdata;
wire               ppu_apbs_pslverr;
wire               ppu_irq;

wire [W_PADDR-1:0] lcd_apbs_paddr;
wire               lcd_apbs_psel;
wire               lcd_apbs_penable;
wire               lcd_apbs_pwrite;
wire [W_DATA-1:0]  lcd_apbs_pwdata;
wire               lcd_apbs_pready;
wire [W_DATA-1:0]  lcd_apbs_prdata;
wire               lcd_apbs_pslverr;

wire [W_COORD_SX-1:0] lcd_scanout_raddr;
wire                  lcd_scanout_ren;
wire          [15:0]  lcd_scanout_rdata;
wire                  lcd_scanout_buf_rdy;
wire                  lcd_scanout_buf_release;

// =============================================================================
//  Masters
// =============================================================================

hazard5_cpu_1port #(
	.RESET_VECTOR    (CPU_RESET_VECTOR),
	.EXTENSION_C     (!CUTDOWN_PROCESSOR),
	.EXTENSION_M     (!CUTDOWN_PROCESSOR),
	.MULDIV_UNROLL   (1),
	.CSR_M_MANDATORY (0), // Not going to spend LUTs on a register telling me which architecture is implemented
	.CSR_M_TRAP      (!CUTDOWN_PROCESSOR), // Do need IRQs though
	.CSR_COUNTER     (0), // 64 bit counters who do you think you are
	.REDUCED_BYPASS  (CUTDOWN_PROCESSOR),
	.MTVEC_WMASK     (32'h00080000), // Restrict MTVEC to SRAM0_BASE or SRAM1_BASE, to save gates
	.MTVEC_INIT      (32'h20000000)
) hazard5_cpu_u (
	.clk             (clk_sys),
	.rst_n           (rst_n),
	.ahblm_hready    (proc0_hready),
	.ahblm_hresp     (proc0_hresp),
	.ahblm_haddr     (proc0_haddr),
	.ahblm_hwrite    (proc0_hwrite),
	.ahblm_htrans    (proc0_htrans),
	.ahblm_hsize     (proc0_hsize),
	.ahblm_hburst    (proc0_hburst),
	.ahblm_hprot     (proc0_hprot),
	.ahblm_hmastlock (proc0_hmastlock),
	.ahblm_hwdata    (proc0_hwdata),
	.ahblm_hrdata    (proc0_hrdata),
	.irq             ({
		14'h0,
		uart_irq,
		ppu_irq
	} | tbman_irq_force)
);

localparam W_COORD_SX = 9;
localparam W_COORD_SY = 8;

riscboy_ppu #(
	.W_COORD_SX (W_COORD_SX),
	.W_COORD_SY (W_COORD_SY)
) inst_riscboy_ppu (
	.clk                 (clk_sys),
	.rst_n               (rst_n),

	.irq                 (ppu_irq),

	.ahblm_hready        (ppu_hready),
	.ahblm_hresp         (ppu_hresp),
	.ahblm_haddr         (ppu_haddr),
	.ahblm_hwrite        (ppu_hwrite),
	.ahblm_htrans        (ppu_htrans),
	.ahblm_hsize         (ppu_hsize),
	.ahblm_hburst        (ppu_hburst),
	.ahblm_hprot         (ppu_hprot),
	.ahblm_hmastlock     (ppu_hmastlock),
	.ahblm_hwdata        (ppu_hwdata),
	.ahblm_hrdata        (ppu_hrdata),

	.apbs_psel           (ppu_apbs_psel),
	.apbs_penable        (ppu_apbs_penable),
	.apbs_pwrite         (ppu_apbs_pwrite),
	.apbs_paddr          (ppu_apbs_paddr),
	.apbs_pwdata         (ppu_apbs_pwdata),
	.apbs_prdata         (ppu_apbs_prdata),
	.apbs_pready         (ppu_apbs_pready),
	.apbs_pslverr        (ppu_apbs_pslverr),

	.scanout_raddr       (lcd_scanout_raddr),
	.scanout_ren         (lcd_scanout_ren),
	.scanout_rdata       (lcd_scanout_rdata),
	.scanout_buf_rdy     (lcd_scanout_buf_rdy),
	.scanout_buf_release (lcd_scanout_buf_release)
);

generate
if (DISPLAY_TYPE == "SPI") begin: gen_dispctrl_spi

	wire rst_n_lcd_bit;

	reset_sync #(
		.N_CYCLES (2)
	) reset_sync_bit (
		.clk       (clk_lcd_bit),
		.rst_n_in  (rst_n),
		.rst_n_out (rst_n_lcd_bit)
	);

	riscboy_ppu_dispctrl_spi #(
		.PXFIFO_DEPTH (8),
		.W_COORD_SX   (W_COORD_SX)
	) dispctrl_spi_u (
		.clk_sys             (clk_sys),
		.rst_n_sys           (rst_n),
		.clk_tx              (clk_lcd_bit),
		.rst_n_tx            (rst_n_lcd_bit),

		.apbs_psel           (lcd_apbs_psel),
		.apbs_penable        (lcd_apbs_penable),
		.apbs_pwrite         (lcd_apbs_pwrite),
		.apbs_paddr          (lcd_apbs_paddr),
		.apbs_pwdata         (lcd_apbs_pwdata),
		.apbs_prdata         (lcd_apbs_prdata),
		.apbs_pready         (lcd_apbs_pready),
		.apbs_pslverr        (lcd_apbs_pslverr),

		.scanout_raddr       (lcd_scanout_raddr),
		.scanout_ren         (lcd_scanout_ren),
		.scanout_rdata       (lcd_scanout_rdata),
		.scanout_buf_rdy     (lcd_scanout_buf_rdy),
		.scanout_buf_release (lcd_scanout_buf_release),

		.lcd_cs              (lcdp[3]),
		.lcd_dc              (lcdp[2]),
		.lcd_sck             (lcdp[1]),
		.lcd_mosi            (lcdp[0])
	);

	assign lcdn = 4'h0;

end else begin: gen_dispctrl_dvi// assume "DVI"

	wire rst_n_lcd_pix;
	wire rst_n_lcd_bit;

	reset_sync #(
		.N_CYCLES (2)
	) reset_sync_pix (
		.clk       (clk_lcd_pix),
		.rst_n_in  (rst_n),
		.rst_n_out (rst_n_lcd_pix)
	);

	reset_sync #(
		.N_CYCLES (2)
	) reset_sync_bit (
		.clk       (clk_lcd_bit),
		.rst_n_in  (rst_n),
		.rst_n_out (rst_n_lcd_bit)
	);

	riscboy_ppu_dispctrl_dvi #(
		.PXFIFO_DEPTH (8),
		.W_COORD_SX   (W_COORD_SX)
	) dispctrl_dvi_u (
		.clk_sys             (clk_sys),
		.rst_n_sys           (rst_n),
		.clk_pix             (clk_lcd_pix),
		.rst_n_pix           (rst_n_lcd_pix),
		.clk_bit             (clk_lcd_bit),
		.rst_n_bit           (rst_n_lcd_bit),

		.apbs_psel           (lcd_apbs_psel),
		.apbs_penable        (lcd_apbs_penable),
		.apbs_pwrite         (lcd_apbs_pwrite),
		.apbs_paddr          (lcd_apbs_paddr),
		.apbs_pwdata         (lcd_apbs_pwdata),
		.apbs_prdata         (lcd_apbs_prdata),
		.apbs_pready         (lcd_apbs_pready),
		.apbs_pslverr        (lcd_apbs_pslverr),

		.scanout_raddr       (lcd_scanout_raddr),
		.scanout_ren         (lcd_scanout_ren),
		.scanout_rdata       (lcd_scanout_rdata),
		.scanout_buf_rdy     (lcd_scanout_buf_rdy),
		.scanout_buf_release (lcd_scanout_buf_release),

		.dvip                (lcdp),
		.dvin                (lcdn)
	);

end
endgenerate

// =============================================================================
//  Busfabric
// =============================================================================

ahbl_crossbar #(
	.N_MASTERS (2),
	.N_SLAVES  (3),
	.W_ADDR    (W_ADDR),
	.W_DATA    (W_DATA),
	.ADDR_MAP  (96'h40000000_20080000_20000000),
	.ADDR_MASK (96'he0000000_e0080000_e0080000),
	.CONN_MATRIX ({
		3'b111,
		3'b001
	}),
	.CONN_MATRIX_TRANSPOSE ({
		2'b10,
		2'b10,
		2'b11
	})
) inst_ahbl_crossbar (
	.clk             (clk_sys),
	.rst_n           (rst_n),
	.src_hready_resp ({proc0_hready    , ppu_hready   }), // Lower master wins (ppu has priority)
	.src_hresp       ({proc0_hresp     , ppu_hresp    }),
	.src_haddr       ({proc0_haddr     , ppu_haddr    }),
	.src_hwrite      ({proc0_hwrite    , ppu_hwrite   }),
	// Workaround for bug in AHB arbiter for slaves with wait states (used to
	// be cancelled out by a different bug in APB bridge!):
	.src_htrans      ({proc0_htrans & {2{proc0_hready}}, ppu_htrans & {2{ppu_hready}}}),
	.src_hsize       ({proc0_hsize     , ppu_hsize    }),
	.src_hburst      ({proc0_hburst    , ppu_hburst   }),
	.src_hprot       ({proc0_hprot     , ppu_hprot    }),
	.src_hmastlock   ({proc0_hmastlock , ppu_hmastlock}),
	.src_hwdata      ({proc0_hwdata    , ppu_hwdata   }),
	.src_hrdata      ({proc0_hrdata    , ppu_hrdata   }),

	.dst_hready      ({bridge_hready      , sram1_hready      , sram0_hready     }),
	.dst_hready_resp ({bridge_hready_resp , sram1_hready_resp , sram0_hready_resp}),
	.dst_hresp       ({bridge_hresp       , sram1_hresp       , sram0_hresp      }),
	.dst_haddr       ({bridge_haddr       , sram1_haddr       , sram0_haddr      }),
	.dst_hwrite      ({bridge_hwrite      , sram1_hwrite      , sram0_hwrite     }),
	.dst_htrans      ({bridge_htrans      , sram1_htrans      , sram0_htrans     }),
	.dst_hsize       ({bridge_hsize       , sram1_hsize       , sram0_hsize      }),
	.dst_hburst      ({bridge_hburst      , sram1_hburst      , sram0_hburst     }),
	.dst_hprot       ({bridge_hprot       , sram1_hprot       , sram0_hprot      }),
	.dst_hmastlock   ({bridge_hmastlock   , sram1_hmastlock   , sram0_hmastlock  }),
	.dst_hwdata      ({bridge_hwdata      , sram1_hwdata      , sram0_hwdata     }),
	.dst_hrdata      ({bridge_hrdata      , sram1_hrdata      , sram0_hrdata     })
);

ahbl_to_apb #(
	.W_HADDR(W_ADDR),
	.W_PADDR(W_PADDR),
	.W_DATA(W_DATA)
) inst_ahbl_to_apb (
	.clk               (clk_sys),
	.rst_n             (rst_n),
	.ahbls_hready      (bridge_hready),
	.ahbls_hready_resp (bridge_hready_resp),
	.ahbls_hresp       (bridge_hresp),
	.ahbls_haddr       (bridge_haddr),
	.ahbls_hwrite      (bridge_hwrite),
	.ahbls_htrans      (bridge_htrans),
	.ahbls_hsize       (bridge_hsize),
	.ahbls_hburst      (bridge_hburst),
	.ahbls_hprot       (bridge_hprot),
	.ahbls_hmastlock   (bridge_hmastlock),
	.ahbls_hwdata      (bridge_hwdata),
	.ahbls_hrdata      (bridge_hrdata),

	.apbm_paddr        (bridge_paddr),
	.apbm_psel         (bridge_psel),
	.apbm_penable      (bridge_penable),
	.apbm_pwrite       (bridge_pwrite),
	.apbm_pwdata       (bridge_pwdata),
	.apbm_pready       (bridge_pready),
	.apbm_prdata       (bridge_prdata),
	.apbm_pslverr      (bridge_pslverr)
);

apb_splitter #(
	.W_ADDR(W_PADDR),
	.W_DATA(W_DATA),
	.N_SLAVES(7),
	.ADDR_MAP (112'hf000_5000_4000_3000_2000_1000_0000),
	.ADDR_MASK(112'hf000_f000_f000_f000_f000_f000_f000)
) inst_apb_splitter (
	.apbs_paddr   (bridge_paddr),
	.apbs_psel    (bridge_psel),
	.apbs_penable (bridge_penable),
	.apbs_pwrite  (bridge_pwrite),
	.apbs_pwdata  (bridge_pwdata),
	.apbs_pready  (bridge_pready),
	.apbs_prdata  (bridge_prdata),
	.apbs_pslverr (bridge_pslverr),
	.apbm_paddr   ({tbman_paddr   , lcd_apbs_paddr    , ppu_apbs_paddr    , spi_paddr   , pwm_paddr   , uart_paddr   , gpio_paddr  }),
	.apbm_psel    ({tbman_psel    , lcd_apbs_psel     , ppu_apbs_psel     , spi_psel    , pwm_psel    , uart_psel    , gpio_psel   }),
	.apbm_penable ({tbman_penable , lcd_apbs_penable  , ppu_apbs_penable  , spi_penable , pwm_penable , uart_penable , gpio_penable}),
	.apbm_pwrite  ({tbman_pwrite  , lcd_apbs_pwrite   , ppu_apbs_pwrite   , spi_pwrite  , pwm_pwrite  , uart_pwrite  , gpio_pwrite }),
	.apbm_pwdata  ({tbman_pwdata  , lcd_apbs_pwdata   , ppu_apbs_pwdata   , spi_pwdata  , pwm_pwdata  , uart_pwdata  , gpio_pwdata }),
	.apbm_pready  ({tbman_pready  , lcd_apbs_pready   , ppu_apbs_pready   , spi_pready  , pwm_pready  , uart_pready  , gpio_pready }),
	.apbm_prdata  ({tbman_prdata  , lcd_apbs_prdata   , ppu_apbs_prdata   , spi_prdata  , pwm_prdata  , uart_prdata  , gpio_prdata }),
	.apbm_pslverr ({tbman_pslverr , lcd_apbs_pslverr  , ppu_apbs_pslverr  , spi_pslverr , pwm_pslverr , uart_pslverr , gpio_pslverr})
);


// =============================================================================
//  Slaves
// =============================================================================

// SRAM 0: external asynchronous SRAM.
// Second stage is loaded into here by the initial bootloader.
// Vast majority of code and data for games will be here.

generate
if (!SRAM0_INTERNAL) begin: has_sram0_ctrl
	ahb_async_sram_halfwidth #(
		.W_DATA(W_DATA),
		.W_ADDR(W_ADDR),
		.DEPTH(1 << W_SRAM0_ADDR)
	) sram0_ctrl (
		.clk               (clk_sys),
		.rst_n             (rst_n),
		.ahbls_hready_resp (sram0_hready_resp),
		.ahbls_hready      (sram0_hready),
		.ahbls_hresp       (sram0_hresp),
		.ahbls_haddr       (sram0_haddr),
		.ahbls_hwrite      (sram0_hwrite),
		.ahbls_htrans      (sram0_htrans),
		.ahbls_hsize       (sram0_hsize),
		.ahbls_hburst      (sram0_hburst),
		.ahbls_hprot       (sram0_hprot),
		.ahbls_hmastlock   (sram0_hmastlock),
		.ahbls_hwdata      (sram0_hwdata),
		.ahbls_hrdata      (sram0_hrdata),

		.sram_addr         (sram_addr),
		.sram_dq           (sram_dq),
		.sram_ce_n         (sram_ce_n),
		.sram_we_n         (sram_we_n),
		.sram_oe_n         (sram_oe_n),
		.sram_byte_n       (sram_byte_n)
	);
end else begin: has_internal_sram0
	// For ECP5 and UP5k, we can have a large internal RAM bank instead
	ahb_sync_sram #(
		.W_DATA            (W_DATA),
		.W_ADDR            (W_ADDR),
		.DEPTH             (1 << W_SRAM0_ADDR),
		.HAS_WRITE_BUFFER  (!NO_SRAM_WRITE_BUF),
		.PRELOAD_FILE      (SRAM0_PRELOAD)
	) sram0 (
		.clk               (clk_sys),
		.rst_n             (rst_n),

		.ahbls_hready_resp (sram0_hready_resp),
		.ahbls_hready      (sram0_hready),
		.ahbls_hresp       (sram0_hresp),
		.ahbls_haddr       (sram0_haddr),
		.ahbls_hwrite      (sram0_hwrite),
		.ahbls_htrans      (sram0_htrans),
		.ahbls_hsize       (sram0_hsize),
		.ahbls_hburst      (sram0_hburst),
		.ahbls_hprot       (sram0_hprot),
		.ahbls_hmastlock   (sram0_hmastlock),
		.ahbls_hwdata      (sram0_hwdata),
		.ahbls_hrdata      (sram0_hrdata)
	);

	assign sram_addr = {W_SRAM0_ADDR{1'b0}};
	assign sram_ce_n = 1'b0;
	assign sram_we_n = 1'b0;
	assign sram_oe_n = 1'b0;
	assign sram_byte_n = 2'h0;
end
endgenerate

// SRAM 1: internal synchronous SRAM.
// Used for first-stage bootcode, and thereafter for processor stack
// + small amount of hot code

ahb_sync_sram #(
	.W_DATA            (W_DATA),
	.W_ADDR            (W_ADDR),
	.DEPTH             (1 << 11), // 2^11 words = 8 kiB
	.HAS_WRITE_BUFFER  (!NO_SRAM_WRITE_BUF),
	.PRELOAD_FILE      (BOOTRAM_PRELOAD)
) sram1 (
	.clk               (clk_sys),
	.rst_n             (rst_n),
	.ahbls_hready_resp (sram1_hready_resp),
	.ahbls_hready      (sram1_hready),
	.ahbls_hresp       (sram1_hresp),
	.ahbls_haddr       (sram1_haddr),
	.ahbls_hwrite      (sram1_hwrite),
	.ahbls_htrans      (sram1_htrans),
	.ahbls_hsize       (sram1_hsize),
	.ahbls_hburst      (sram1_hburst),
	.ahbls_hprot       (sram1_hprot),
	.ahbls_hmastlock   (sram1_hmastlock),
	.ahbls_hwdata      (sram1_hwdata),
	.ahbls_hrdata      (sram1_hrdata)
);

tbman #(
	.STUB_UART (STUB_UART),
	.STUB_SPI  (STUB_SPI),
	.STUB_PWM  (STUB_PWM)
) inst_tbman (
	.clk              (clk_sys),
	.rst_n            (rst_n),
	.apbs_psel        (tbman_psel),
	.apbs_penable     (tbman_penable),
	.apbs_pwrite      (tbman_pwrite),
	.apbs_paddr       (tbman_paddr),
	.apbs_pwdata      (tbman_pwdata),
	.apbs_prdata      (tbman_prdata),
	.apbs_pready      (tbman_pready),
	.apbs_pslverr     (tbman_pslverr),

	.irq_force        (tbman_irq_force) // FIXME testing only, need proper platform IRQ controller
);

generate
if (STUB_PWM) begin
	assign pwm_pready = 1'b1;
	assign pwm_pslverr = 1'b0;
	assign pwm_prdata = {W_DATA{1'b0}};
	assign lcd_pwm = 1'b1;
end else begin

	pwm_tiny inst_pwm_tiny (
		.clk          (clk_sys),
		.rst_n        (rst_n),
		.apbs_psel    (pwm_psel),
		.apbs_penable (pwm_penable),
		.apbs_pwrite  (pwm_pwrite),
		.apbs_paddr   (pwm_paddr),
		.apbs_pwdata  (pwm_pwdata),
		.apbs_prdata  (pwm_prdata),
		.apbs_pready  (pwm_pready),
		.apbs_pslverr (pwm_pslverr),
		.padout       (lcd_pwm)
	);

end
endgenerate

generate
if (STUB_UART) begin
	assign uart_pready = 1'b1;
	assign uart_pslverr = 1'b0;
	assign uart_prdata = {W_DATA{1'b0}};
	assign uart_tx = 1'b1;
	assign uart_rts = 1'b1;
end else begin

	uart_mini #(
		.FIFO_DEPTH (UART_FIFO_DEPTH),
		.OVERSAMPLE (8),
		.RTS_LEVEL  (1)
	) inst_uart_mini (
		.clk          (clk_sys),
		.rst_n        (rst_n),
		.apbs_psel    (uart_psel),
		.apbs_penable (uart_penable),
		.apbs_pwrite  (uart_pwrite),
		.apbs_paddr   (uart_paddr),
		.apbs_pwdata  (uart_pwdata),
		.apbs_prdata  (uart_prdata),
		.apbs_pready  (uart_pready),
		.apbs_pslverr (uart_pslverr),
		.rx           (uart_rx),
		.tx           (uart_tx),
		.rts          (uart_rts),
		.cts          (uart_cts),
		.irq          (uart_irq),
		.dreq         ()
	);

end
endgenerate

generate
if (STUB_SPI) begin
	assign spi_pready = 1'b1;
	assign spi_pslverr = 1'b0;
	assign spi_prdata = {W_DATA{1'b0}};
	assign spi_sclk = 1'b0;
	assign spi_cs = 1'b1;
	assign spi_sdo = 1'b0;
end else begin

	spi_mini #(
		.FIFO_DEPTH(2)
	) inst_spi_mini (
		.clk          (clk_sys),
		.rst_n        (rst_n),
		.apbs_psel    (spi_psel),
		.apbs_penable (spi_penable),
		.apbs_pwrite  (spi_pwrite),
		.apbs_paddr   (spi_paddr),
		.apbs_pwdata  (spi_pwdata),
		.apbs_prdata  (spi_prdata),
		.apbs_pready  (spi_pready),
		.apbs_pslverr (spi_pslverr),
		.sclk         (spi_sclk),
		.sdo          (spi_sdo),
		.sdi          (spi_sdi),
		.cs_n         (spi_cs)
	);

end
endgenerate

gpio #(
	.N_PADS (N_PADS)
) inst_gpio (
	.clk          (clk_sys),
	.rst_n        (rst_n),
	.apbs_psel    (gpio_psel),
	.apbs_penable (gpio_penable),
	.apbs_pwrite  (gpio_pwrite),
	.apbs_paddr   (gpio_paddr),
	.apbs_pwdata  (gpio_pwdata),
	.apbs_prdata  (gpio_prdata),
	.apbs_pready  (gpio_pready),
	.apbs_pslverr (gpio_pslverr),

	.padout       (padout),
	.padoe        (padoe),
	.padin        (padin)
);

endmodule
