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

// Wrapper module to instantiate an M x N crossbar of ahbl_splitter and
// ahbl_arbiter modules

// TODO: add connectivity matrix parameter

module ahbl_crossbar (
	parameter N_MASTERS = 2,
	parameter N_SLAVES = 2,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter ADDR_MAP  = 64'h20000000_00000000,
	parameter ADDR_MASK = 64'hf0000000_f0000000
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// Master ports
	output wire [N_MASTERS-1:0]        ahblm_hready_resp,
	output wire [N_MASTERS-1:0]        ahblm_hresp,
	input  wire [N_MASTERS*W_ADDR-1:0] ahblm_haddr,
	input  wire [N_MASTERS-1:0]        ahblm_hwrite,
	input  wire [N_MASTERS*2-1:0]      ahblm_htrans,
	input  wire [N_MASTERS*3-1:0]      ahblm_hsize,
	input  wire [N_MASTERS*3-1:0]      ahblm_hburst,
	input  wire [N_MASTERS*4-1:0]      ahblm_hprot,
	input  wire [N_MASTERS-1:0]        ahblm_hmastlock,
	input  wire [N_MASTERS*W_DATA-1:0] ahblm_hwdata,
	output wire [N_MASTERS*W_DATA-1:0] ahblm_hrdata,

	// Slave ports
	output wire [N_SLAVES-1:0]         abhls_hready,
	input  wire [N_SLAVES-1:0]         ahbls_hready_resp,
	input  wire [N_SLAVES-1:0]         ahbls_hresp,
	output wire [N_SLAVES*W_ADDR-1:0]  ahbls_haddr,
	output wire [N_SLAVES-1:0]         ahbls_hwrite,
	output wire [N_SLAVES*2-1:0]       ahbls_htrans,
	output wire [N_SLAVES*3-1:0]       ahbls_hsize,
	output wire [N_SLAVES*3-1:0]       ahbls_hburst,
	output wire [N_SLAVES*4-1:0]       ahbls_hprot,
	output wire [N_SLAVES-1:0]         ahbls_hmastlock,
	output wire [N_SLAVES*W_DATA-1:0]  ahbls_hwdata,
	input  wire [N_SLAVES*W_DATA-1:0]  ahbls_hrdata
);


// ================================================
// Instance interconnect for splitters <-> arbiters
// ================================================

wire              xbar_hready      [0:N_MASTERS-1][0:N_SLAVES-1];
wire              xbar_hready_resp [0:N_MASTERS-1][0:N_SLAVES-1];
wire              xbar_hresp       [0:N_MASTERS-1][0:N_SLAVES-1];
wire [W_ADDR-1:0] xbar_haddr       [0:N_MASTERS-1][0:N_SLAVES-1];
wire              xbar_hwrite      [0:N_MASTERS-1][0:N_SLAVES-1];
wire [1:0]        xbar_htrans      [0:N_MASTERS-1][0:N_SLAVES-1];
wire [2:0]        xbar_hsize       [0:N_MASTERS-1][0:N_SLAVES-1];
wire [2:0]        xbar_hburst      [0:N_MASTERS-1][0:N_SLAVES-1];
wire [3:0]        xbar_hprot       [0:N_MASTERS-1][0:N_SLAVES-1];
wire              xbar_hmastlock   [0:N_MASTERS-1][0:N_SLAVES-1];
wire [W_DATA-1:0] xbar_hwdata      [0:N_MASTERS-1][0:N_SLAVES-1];
wire [W_DATA-1:0] xbar_hrdata      [0:N_MASTERS-1][0:N_SLAVES-1];

integer i, j;

// =======================
// Splitter instantiations
// =======================

generate
for (i = 0; i < N_MASTERS; i = i + 1) begin: split_instantiate
	// If I ever meet the person who decided Verilog can't have arrays as module parameters,
	// I'm gonna make a speed bump out of them
	wire [N_SLAVES-1:0]         split_hready;
	wire [N_SLAVES-1:0]         split_hready_resp;
	wire [N_SLAVES-1:0]         split_hresp;
	wire [N_SLAVES*W_ADDR-1:0]  split_haddr;
	wire [N_SLAVES-1:0]         split_hwrite;
	wire [N_SLAVES*2-1:0]       split_htrans;
	wire [N_SLAVES*3-1:0]       split_hsize;
	wire [N_SLAVES*3-1:0]       split_hburst;
	wire [N_SLAVES*4-1:0]       split_hprot;
	wire [N_SLAVES-1:0]         split_hmastlock;
	wire [N_SLAVES*W_DATA-1:0]  split_hwdata;
	wire [N_SLAVES*W_DATA-1:0]  split_hrdata;

	for (j = 0; j < N_SLAVES; j = j + 1) begin
		xbar_hready[i][j]                  = split_hready[j];
		xbar_haddr[i][j]                   = split_haddr[W_ADDR * j +: W_ADDR];
		xbar_hwrite[i][j]                  = split_hwrite[j];
		xbar_htrans[i][j]                  = split_htrans[2 * j +: 2];
		xbar_hsize[i][j]                   = split_hsize[3 * j +: 3];
		xbar_hburst[i][j]                  = split_hburst[3 * j +: 3];
		xbar_hprot[i][j]                   = split_hprot[4 * j +: 3];
		xbar_hmastlock[i][j]               = split_hmastlock[j];
		xbar_hwdata[i][j]                  = split_hwdata[W_DATA * j +: W_DATA];

		split_hready_resp[j]               = xbar_hready_resp[i][j];
		split_hresp[j]                     = xbar_hresp[i][j];
		split_hrdata[W_DATA * j +: W_DATA] = xbar_hrdata[i][j];
	end

	ahbl_splitter #(
		.N_PORTS(N_SLAVES),
		.W_ADDR(W_ADDR),
		.W_DATA(W_DATA),
		.ADDR_MAP(ADDR_MAP),
		.ADDR_MASK(ADDR_MASK)
	) split (
		.clk               (clk),
		.rst_n             (rst_n),
		.abhlm_hready      (abhlm_hready_resp[i]),	// HREADY_RESP tied -> HREADY at master level
		.ahblm_hready_resp (ahblm_hready_resp[i]),
		.ahblm_hresp       (ahblm_hresp[i]),
		.ahblm_haddr       (ahblm_haddr[W_ADDR * i +: W_ADDR]),
		.ahblm_hwrite      (ahblm_hwrite[i]),
		.ahblm_htrans      (ahblm_htrans[2 * i +: 2]),
		.ahblm_hsize       (ahblm_hsize[3 * i +: 3]),
		.ahblm_hburst      (ahblm_hburst[3 * i +: 3]),
		.ahblm_hprot       (ahblm_hprot[4 * i +: 4]),
		.ahblm_hmastlock   (ahblm_hmastlock[i]),
		.ahblm_hwdata      (ahblm_hwdata[W_DATA * i +: W_DATA]),
		.ahblm_hrdata      (ahblm_hrdata[W_DATA * i +: W_DATA]),
		.abhls_hready      (split_hready),
		.ahbls_hready_resp (split_hready_resp),
		.ahbls_hresp       (split_hresp),
		.ahbls_haddr       (split_haddr),
		.ahbls_hwrite      (split_hwrite),
		.ahbls_htrans      (split_htrans),
		.ahbls_hsize       (split_hsize),
		.ahbls_hburst      (split_hburst),
		.ahbls_hprot       (split_hprot),
		.ahbls_hmastlock   (split_hmastlock),
		.ahbls_hwdata      (split_hwdata),
		.ahbls_hrdata      (split_hrdata)
	);
end
endgenerate

// ======================
// Arbiter instantiations
// ======================

generate
for (j = 0; j < N_SLAVES; j = j + 1) begin: arb_instantiate
	wire [N_MASTERS-1:0]         arb_hready;
	wire [N_MASTERS-1:0]         arb_hready_resp;
	wire [N_MASTERS-1:0]         arb_hresp;
	wire [N_MASTERS*W_ADDR-1:0]  arb_haddr;
	wire [N_MASTERS-1:0]         arb_hwrite;
	wire [N_MASTERS*2-1:0]       arb_htrans;
	wire [N_MASTERS*3-1:0]       arb_hsize;
	wire [N_MASTERS*3-1:0]       arb_hburst;
	wire [N_MASTERS*4-1:0]       arb_hprot;
	wire [N_MASTERS-1:0]         arb_hmastlock;
	wire [N_MASTERS*W_DATA-1:0]  arb_hwdata;
	wire [N_MASTERS*W_DATA-1:0]  arb_hrdata;

	for (i = 0; i < N_MASTERS; i = i + 1) begin
		arb_hready[j]                    = xbar_hready[i][j];
		arb_haddr[W_ADDR * j +: W_ADDR]  = xbar_haddr[i][j];
		arb_hwrite[j]                    = xbar_hwrite[i][j];
		arb_htrans[2 * j +: 2]           = xbar_htrans[i][j];
		arb_hsize[3 * j +: 3]            = xbar_hsize[i][j];
		arb_hburst[3 * j +: 3]           = xbar_hburst[i][j];
		arb_hprot[4 * j +: 3]            = xbar_hprot[i][j];
		arb_hmastlock[j]                 = xbar_hmastlock[i][j];
		arb_hwdata[W_DATA * j +: W_DATA] = xbar_hwdata[i][j];
		xbar_hready_resp[i][j]           = arb_hready_resp[j];
		xbar_hresp[i][j]                 = arb_hresp[j];
		xbar_hrdata[i][j]                = arb_hrdata[W_DATA * j +: W_DATA];
	end

	ahbl_arbiter #(
		.N_PORTS(N_MASTERS),
		.W_ADDR(W_ADDR),
		.W_DATA(W_DATA)
	) arb (
		.clk               (clk),
		.rst_n             (rst_n),
		.abhlm_hready      (arb_hready),
		.ahblm_hready_resp (arb_hready_resp),
		.ahblm_hresp       (arb_hresp),
		.ahblm_haddr       (arb_haddr),
		.ahblm_hwrite      (arb_hwrite),
		.ahblm_htrans      (arb_htrans),
		.ahblm_hsize       (arb_hsize),
		.ahblm_hburst      (arb_hburst),
		.ahblm_hprot       (arb_hprot),
		.ahblm_hmastlock   (arb_hmastlock),
		.ahblm_hwdata      (arb_hwdata),
		.ahblm_hrdata      (arb_hrdata),
		.abhls_hready      (abhls_hready[j]),
		.ahbls_hready_resp (ahbls_hready_resp[j]),
		.ahbls_hresp       (ahbls_hresp[j]),
		.ahbls_haddr       (ahbls_haddr[W_ADDR * j +: W_ADDR]),
		.ahbls_hwrite      (ahbls_hwrite[j]),
		.ahbls_htrans      (ahbls_htrans[2 * j +: 2]),
		.ahbls_hsize       (ahbls_hsize[3 * j +: 3]),
		.ahbls_hburst      (ahbls_hburst[3 * j +: 3]),
		.ahbls_hprot       (ahbls_hprot[4 * j +: 4]),
		.ahbls_hmastlock   (ahbls_hmastlock[j]),
		.ahbls_hwdata      (ahbls_hwdata[W_DATA * j +: W_DATA]),
		.ahbls_hrdata      (ahbls_hrdata[W_DATA * j +: W_DATA])
	);
end
endgenerate