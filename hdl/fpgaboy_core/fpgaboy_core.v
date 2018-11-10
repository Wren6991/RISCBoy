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

// fpgaboy_core contains the full system, except for 
// Clock, Reset and Power (CRaP)
// which lives in the chip/fpga/testbench top level


module fpgaboy_core #(
	localparam N_PADS = 16
) (
	input wire clk,
	input wire rst_n,

	inout wire [15:0] gpio
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

wire [W_PADDR-1:0] uart_paddr;
wire               uart_psel;
wire               uart_penable;
wire               uart_pwrite;
wire [W_DATA-1:0]  uart_pwdata;
wire               uart_pready;
wire [W_DATA-1:0]  uart_prdata;
wire               uart_pslverr;

wire               uart_tx;
wire               uart_rx;

wire [W_PADDR-1:0] gpio_paddr;
wire               gpio_psel;
wire               gpio_penable;
wire               gpio_pwrite;
wire [W_DATA-1:0]  gpio_pwdata;
wire               gpio_pready;
wire [W_DATA-1:0]  gpio_prdata;
wire               gpio_pslverr;

// =============================================================================
//  Masters
// =============================================================================

hazard5_cpu #(
	.RESET_VECTOR(32'h20000000),
	.CACHE_DEPTH(0)
) inst_revive_cpu (
	.clk             (clk),
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
	.ahblm_hrdata    (proc0_hrdata)
);
// =============================================================================
//  Busfabric
// =============================================================================

ahbl_crossbar #(
	.N_MASTERS(1),
	.N_SLAVES(2),
	.W_ADDR(W_ADDR),
	.W_DATA(W_DATA),
	.ADDR_MAP (64'h40000000_20000000),
	.ADDR_MASK(64'he0000000_e0000000)
) inst_ahbl_crossbar (
	.clk             (clk),
	.rst_n           (rst_n),
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

	.dst_hready      ({bridge_hready,      sram0_hready     }),
	.dst_hready_resp ({bridge_hready_resp, sram0_hready_resp}),
	.dst_hresp       ({bridge_hresp,       sram0_hresp      }),
	.dst_haddr       ({bridge_haddr,       sram0_haddr      }),
	.dst_hwrite      ({bridge_hwrite,      sram0_hwrite     }),
	.dst_htrans      ({bridge_htrans,      sram0_htrans     }),
	.dst_hsize       ({bridge_hsize,       sram0_hsize      }),
	.dst_hburst      ({bridge_hburst,      sram0_hburst     }),
	.dst_hprot       ({bridge_hprot,       sram0_hprot      }),
	.dst_hmastlock   ({bridge_hmastlock,   sram0_hmastlock  }),
	.dst_hwdata      ({bridge_hwdata,      sram0_hwdata     }),
	.dst_hrdata      ({bridge_hrdata,      sram0_hrdata     })
);

ahbl_to_apb #(
	.W_HADDR(W_ADDR),
	.W_PADDR(W_PADDR),
	.W_DATA(W_DATA)
) inst_ahbl_to_apb (
	.clk               (clk),
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
	.N_SLAVES(3),
	.ADDR_MAP (48'hf000_1000_0000),
	.ADDR_MASK(48'hf000_f000_f000)
) inst_apb_splitter (
	.apbs_paddr   (bridge_paddr),
	.apbs_psel    (bridge_psel),
	.apbs_penable (bridge_penable),
	.apbs_pwrite  (bridge_pwrite),
	.apbs_pwdata  (bridge_pwdata),
	.apbs_pready  (bridge_pready),
	.apbs_prdata  (bridge_prdata),
	.apbs_pslverr (bridge_pslverr),
	.apbm_paddr   ({tbman_paddr   , uart_paddr   , gpio_paddr  }),
	.apbm_psel    ({tbman_psel    , uart_psel    , gpio_psel   }),
	.apbm_penable ({tbman_penable , uart_penable , gpio_penable}),
	.apbm_pwrite  ({tbman_pwrite  , uart_pwrite  , gpio_pwrite }),
	.apbm_pwdata  ({tbman_pwdata  , uart_pwdata  , gpio_pwdata }),
	.apbm_pready  ({tbman_pready  , uart_pready  , gpio_pready }),
	.apbm_prdata  ({tbman_prdata  , uart_prdata  , gpio_prdata }),
	.apbm_pslverr ({tbman_pslverr , uart_pslverr , gpio_pslverr})
);


// =============================================================================
//  Slaves
// =============================================================================

ahb_sync_sram #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.DEPTH(1 << 17) // 2^17 words = 0.5 MiB
) sram0 (
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready_resp (sram0_hready_resp),
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

tbman inst_tbman (
	.clk              (clk),
	.rst_n            (rst_n),
	.apbs_psel        (tbman_psel),
	.apbs_penable     (tbman_penable),
	.apbs_pwrite      (tbman_pwrite),
	.apbs_paddr       (tbman_paddr),
	.apbs_pwdata      (tbman_pwdata),
	.apbs_prdata      (tbman_prdata),
	.apbs_pready      (tbman_pready),
	.apbs_pslverr     (tbman_pslverr)
);

uart_mini #(
	.FIFO_DEPTH(2),
	.OVERSAMPLE(8)
) inst_uart_mini (
	.clk          (clk),
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
	.irq          (),
	.dreq         ()
);


gpio #(
	.N_PADS(N_PADS)
) inst_gpio (
	.clk          (clk),
	.rst_n        (rst_n),
	.apbs_psel    (gpio_psel),
	.apbs_penable (gpio_penable),
	.apbs_pwrite  (gpio_pwrite),
	.apbs_paddr   (gpio_paddr),
	.apbs_pwdata  (gpio_pwdata),
	.apbs_prdata  (gpio_prdata),
	.apbs_pready  (gpio_pready),
	.apbs_pslverr (gpio_pslverr),
	.pads         (gpio),
	.uart_tx      (uart_tx),
	.uart_rx      (uart_rx)
);

endmodule