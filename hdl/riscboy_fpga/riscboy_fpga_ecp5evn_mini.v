module riscboy_fpga #(
	parameter PRELOAD_FILE = "bootram_init32.hex"
) (
	input wire                     clk_osc,
	output wire [7:0]              led
);

`include "gpio_pinmap.vh"

// Clock + Reset resources

wire clk_sys = clk_osc;
wire rst_n;

fpga_reset #(
	.SHIFT (3),
	.COUNT (200)
) rstgen (
	.clk         (clk_sys),
	.force_rst_n (1'b1),
	.rst_n       (rst_n)
);

// Instantiate the actual logic

localparam W_ADDR = 32;
localparam W_DATA = 32;
localparam W_PADDR = 16;

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

wire [W_PADDR-1:0] gpio_paddr;
wire               gpio_psel;
wire               gpio_penable;
wire               gpio_pwrite;
wire [W_DATA-1:0]  gpio_pwdata;
wire               gpio_pready;
wire [W_DATA-1:0]  gpio_prdata;
wire               gpio_pslverr;


hazard5_cpu #(
	.RESET_VECTOR    (32'h200800c0),
	.EXTENSION_C     (1),
	.CSR_M_MANDATORY (0),
	.CSR_M_TRAP      (0),
	.CSR_COUNTER     (0)
) inst_hazard5_cpu (
	.clk             (clk_sys),
	.rst_n           (rst_n),

	.ahblm_haddr     (proc0_haddr),
	.ahblm_hwrite    (proc0_hwrite),
	.ahblm_htrans    (proc0_htrans),
	.ahblm_hsize     (proc0_hsize),
	.ahblm_hburst    (proc0_hburst),
	.ahblm_hprot     (proc0_hprot),
	.ahblm_hmastlock (proc0_hmastlock),
	.ahblm_hready    (proc0_hready),
	.ahblm_hresp     (proc0_hresp),
	.ahblm_hwdata    (proc0_hwdata),
	.ahblm_hrdata    (proc0_hrdata),
	.irq             (16'h0)
);


ahbl_splitter #(
	.N_PORTS   (2),
	.W_ADDR    (W_ADDR),
	.W_DATA    (W_DATA),
	.ADDR_MAP  (64'h00000000_20000000), // Cheekily minimise amount of decode, should be 40000000_20080000
	.ADDR_MASK (64'h20000000_20000000)  //                                               e0000000_e0080000
) inst_ahbl_splitter (
	.clk             (clk_sys),
	.rst_n           (rst_n),

	.src_hready      (proc0_hready),
	.src_hready_resp (proc0_hready),
	.src_hresp       (proc0_hresp),
	.src_haddr       (proc0_haddr),
	.src_hwrite      (proc0_hwrite),
	.src_htrans      (proc0_htrans),
	.src_hsize       (proc0_hsize),
	.src_hburst      (proc0_hburst),
	.src_hprot       (proc0_hprot),
	.src_hmastlock   (proc0_hmastlock),
	.src_hwdata      (proc0_hwdata),
	.src_hrdata      (proc0_hrdata),

	.dst_hready      ({bridge_hready      , sram0_hready     }),
	.dst_hready_resp ({bridge_hready_resp , sram0_hready_resp}),
	.dst_hresp       ({bridge_hresp       , sram0_hresp      }),
	.dst_haddr       ({bridge_haddr       , sram0_haddr      }),
	.dst_hwrite      ({bridge_hwrite      , sram0_hwrite     }),
	.dst_htrans      ({bridge_htrans      , sram0_htrans     }),
	.dst_hsize       ({bridge_hsize       , sram0_hsize      }),
	.dst_hburst      ({bridge_hburst      , sram0_hburst     }),
	.dst_hprot       ({bridge_hprot       , sram0_hprot      }),
	.dst_hmastlock   ({bridge_hmastlock   , sram0_hmastlock  }),
	.dst_hwdata      ({bridge_hwdata      , sram0_hwdata     }),
	.dst_hrdata      ({bridge_hrdata      , sram0_hrdata     })
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

	.apbm_paddr        (gpio_paddr),
	.apbm_psel         (gpio_psel),
	.apbm_penable      (gpio_penable),
	.apbm_pwrite       (gpio_pwrite),
	.apbm_pwdata       (gpio_pwdata),
	.apbm_pready       (gpio_pready),
	.apbm_prdata       (gpio_prdata),
	.apbm_pslverr      (gpio_pslverr)
);

ahb_sync_sram #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.DEPTH(1 << 11), // 2^11 words = 8 kiB
	.PRELOAD_FILE (PRELOAD_FILE)
) sram1 (
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

localparam N_PADS = N_GPIOS;

wire [N_PADS-1:0] padout;
wire [N_PADS-1:0] padoe;
wire [N_PADS-1:0] padin;

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
	.padin        (padin),

	.lcd_pwm      (/* unused */),
	.uart_tx      (/* unused */),
	.uart_rx      (/* unused */),
	.spi_cs       (/* unused */),
	.spi_sclk     (/* unused */),
	.spi_sdo      (/* unused */),
	.spi_sdi      (/* unused */)
);

blinky #(
	.CLK_HZ   (12_000_000),
	.BLINK_HZ (1)
) blinky_u (
	.clk   (clk_osc),
	.blink (led[7])
);

assign led[6] = !rst_n;
assign led[5:0] = ~padout[5:0];
assign padin = 0;

endmodule
