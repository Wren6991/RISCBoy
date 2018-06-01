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
// which lives in the chip/fpga top level


module fpgaboy_core #(
	parameter SIMULATION = 1
) (
	input wire clk,
	input wire rst_n
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

// =============================================================================
//  Masters
// =============================================================================

revive_cpu #(
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
	.clk               (clk),
	.rst_n             (rst_n),
	.ahbls_hready_resp (proc0_hready),
	.ahbls_hresp       (proc0_hresp),
	.ahbls_haddr       (proc0_haddr),
	.ahbls_hwrite      (proc0_hwrite),
	.ahbls_htrans      (proc0_htrans),
	.ahbls_hsize       (proc0_hsize),
	.ahbls_hburst      (proc0_hburst),
	.ahbls_hprot       (proc0_hprot),
	.ahbls_hmastlock   (proc0_hmastlock),
	.ahbls_hwdata      (proc0_hwdata),
	.ahbls_hrdata      (proc0_hrdata),

	.ahblm_hready      ({bridge_hready,      sram0_hready     }),
	.ahblm_hready_resp ({bridge_hready_resp, sram0_hready_resp}),
	.ahblm_hresp       ({bridge_hresp,       sram0_hresp      }),
	.ahblm_haddr       ({bridge_haddr,       sram0_haddr      }),
	.ahblm_hwrite      ({bridge_hwrite,      sram0_hwrite     }),
	.ahblm_htrans      ({bridge_htrans,      sram0_htrans     }),
	.ahblm_hsize       ({bridge_hsize,       sram0_hsize      }),
	.ahblm_hburst      ({bridge_hburst,      sram0_hburst     }),
	.ahblm_hprot       ({bridge_hprot,       sram0_hprot      }),
	.ahblm_hmastlock   ({bridge_hmastlock,   sram0_hmastlock  }),
	.ahblm_hwdata      ({bridge_hwdata,      sram0_hwdata     }),
	.ahblm_hrdata      ({bridge_hrdata,      sram0_hrdata     })
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
	.N_SLAVES(1),
	.ADDR_MAP(16'hf000),
	.ADDR_MASK(16'hf000)
) inst_apb_splitter (
	.apbs_paddr   (bridge_paddr),
	.apbs_psel    (bridge_psel),
	.apbs_penable (bridge_penable),
	.apbs_pwrite  (bridge_pwrite),
	.apbs_pwdata  (bridge_pwdata),
	.apbs_pready  (bridge_pready),
	.apbs_prdata  (bridge_prdata),
	.apbs_pslverr (bridge_pslverr),
	.apbm_paddr   ({tbman_paddr  }),
	.apbm_psel    ({tbman_psel   }),
	.apbm_penable ({tbman_penable}),
	.apbm_pwrite  ({tbman_pwrite }),
	.apbm_pwdata  ({tbman_pwdata }),
	.apbm_pready  ({tbman_pready }),
	.apbm_prdata  ({tbman_prdata }),
	.apbm_pslverr ({tbman_pslverr})
);


// =============================================================================
//  Slaves
// =============================================================================

ahb_sync_sram #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.DEPTH(1 << 16)
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


tbman #(
	.SIMULATION(SIMULATION)
) inst_tbman (
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



endmodule