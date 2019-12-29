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

module ahbl_crossbar #(
	parameter N_MASTERS = 2,
	parameter N_SLAVES = 3,
	parameter W_ADDR = 32,
	parameter W_DATA = 32,

	parameter ADDR_MAP  = 96'h40000000_20080000_20000000,
	parameter ADDR_MASK = 96'he0000000_e0080000_e0080000,

	// These are redundant, but I couldn't find a convincingly-constant way to
	// slice the matrix in both directions for both splitters and arbiters.
	// Setting CONN_MATRIX only is sufficient to remove connectivity, but
	// setting CONN_MATRIX_TRANSPOSE too will get you the full LUT savings of
	// parameter-based tie-offs.
	parameter CONN_MATRIX = {N_MASTERS{
		{N_SLAVES{1'b1}}
	}},
	parameter CONN_MATRIX_TRANSPOSE = {N_SLAVES{
		{N_MASTERS{1'b1}}
	}}
) (
	// Global signals
	input wire                         clk,
	input wire                         rst_n,

	// From masters; function as slave ports
	output wire [N_MASTERS-1:0]        src_hready_resp,
	output wire [N_MASTERS-1:0]        src_hresp,
	input  wire [N_MASTERS*W_ADDR-1:0] src_haddr,
	input  wire [N_MASTERS-1:0]        src_hwrite,
	input  wire [N_MASTERS*2-1:0]      src_htrans,
	input  wire [N_MASTERS*3-1:0]      src_hsize,
	input  wire [N_MASTERS*3-1:0]      src_hburst,
	input  wire [N_MASTERS*4-1:0]      src_hprot,
	input  wire [N_MASTERS-1:0]        src_hmastlock,
	input  wire [N_MASTERS*W_DATA-1:0] src_hwdata,
	output wire [N_MASTERS*W_DATA-1:0] src_hrdata,

	// To slaves; function as master ports
	output wire [N_SLAVES-1:0]         dst_hready,
	input  wire [N_SLAVES-1:0]         dst_hready_resp,
	input  wire [N_SLAVES-1:0]         dst_hresp,
	output wire [N_SLAVES*W_ADDR-1:0]  dst_haddr,
	output wire [N_SLAVES-1:0]         dst_hwrite,
	output wire [N_SLAVES*2-1:0]       dst_htrans,
	output wire [N_SLAVES*3-1:0]       dst_hsize,
	output wire [N_SLAVES*3-1:0]       dst_hburst,
	output wire [N_SLAVES*4-1:0]       dst_hprot,
	output wire [N_SLAVES-1:0]         dst_hmastlock,
	output wire [N_SLAVES*W_DATA-1:0]  dst_hwdata,
	input  wire [N_SLAVES*W_DATA-1:0]  dst_hrdata
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

genvar i, j;

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

	for (j = 0; j < N_SLAVES; j = j + 1) begin: split_connect
		if (CONN_MATRIX[i * N_SLAVES + j] && CONN_MATRIX_TRANSPOSE[j * N_MASTERS + i]) begin
			assign xbar_hready[i][j]                  = split_hready[j];
			assign xbar_haddr[i][j]                   = split_haddr[W_ADDR * j +: W_ADDR];
			assign xbar_hwrite[i][j]                  = split_hwrite[j];
			assign xbar_htrans[i][j]                  = split_htrans[2 * j +: 2];
			assign xbar_hsize[i][j]                   = split_hsize[3 * j +: 3];
			assign xbar_hburst[i][j]                  = split_hburst[3 * j +: 3];
			assign xbar_hprot[i][j]                   = split_hprot[4 * j +: 4];
			assign xbar_hmastlock[i][j]               = split_hmastlock[j];
			assign xbar_hwdata[i][j]                  = split_hwdata[W_DATA * j +: W_DATA];

			assign split_hready_resp[j]               = xbar_hready_resp[i][j];
			assign split_hresp[j]                     = xbar_hresp[i][j];
			assign split_hrdata[W_DATA * j +: W_DATA] = xbar_hrdata[i][j];
		end else begin
			// Disconnected
			assign xbar_hready[i][j]                  = 1'b1;
			assign xbar_haddr[i][j]                   = {W_ADDR{1'b0}};
			assign xbar_hwrite[i][j]                  = 1'b0;
			assign xbar_htrans[i][j]                  = 2'h0;
			assign xbar_hsize[i][j]                   = 3'h0;
			assign xbar_hburst[i][j]                  = 3'h0;
			assign xbar_hprot[i][j]                   = 4'h0;
			assign xbar_hmastlock[i][j]               = 1'b0;
			assign xbar_hwdata[i][j]                  = {W_DATA{1'b0}};

			assign split_hready_resp[j]               = 1'b1;
			assign split_hresp[j]                     = 1'b1;
			assign split_hrdata[W_DATA * j +: W_DATA] = {W_DATA{1'b0}};
		end
	end

	ahbl_splitter #(
		.N_PORTS(N_SLAVES),
		.W_ADDR(W_ADDR),
		.W_DATA(W_DATA),
		.ADDR_MAP  (ADDR_MAP),
		.ADDR_MASK (ADDR_MASK),
		.CONN_MASK (CONN_MATRIX[i * N_SLAVES +: N_SLAVES])
	) split (
		.clk             (clk),
		.rst_n           (rst_n),
		.src_hready      (src_hready_resp[i]),	// HREADY_RESP tied -> HREADY at master level
		.src_hready_resp (src_hready_resp[i]),
		.src_hresp       (src_hresp[i]),
		.src_haddr       (src_haddr[W_ADDR * i +: W_ADDR]),
		.src_hwrite      (src_hwrite[i]),
		.src_htrans      (src_htrans[2 * i +: 2]),
		.src_hsize       (src_hsize[3 * i +: 3]),
		.src_hburst      (src_hburst[3 * i +: 3]),
		.src_hprot       (src_hprot[4 * i +: 4]),
		.src_hmastlock   (src_hmastlock[i]),
		.src_hwdata      (src_hwdata[W_DATA * i +: W_DATA]),
		.src_hrdata      (src_hrdata[W_DATA * i +: W_DATA]),
		.dst_hready      (split_hready),
		.dst_hready_resp (split_hready_resp),
		.dst_hresp       (split_hresp),
		.dst_haddr       (split_haddr),
		.dst_hwrite      (split_hwrite),
		.dst_htrans      (split_htrans),
		.dst_hsize       (split_hsize),
		.dst_hburst      (split_hburst),
		.dst_hprot       (split_hprot),
		.dst_hmastlock   (split_hmastlock),
		.dst_hwdata      (split_hwdata),
		.dst_hrdata      (split_hrdata)
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

	for (i = 0; i < N_MASTERS; i = i + 1) begin: arb_connect
		assign arb_hready[i]                    = xbar_hready[i][j];
		assign arb_haddr[W_ADDR * i +: W_ADDR]  = xbar_haddr[i][j];
		assign arb_hwrite[i]                    = xbar_hwrite[i][j];
		assign arb_htrans[2 * i +: 2]           = xbar_htrans[i][j];
		assign arb_hsize[3 * i +: 3]            = xbar_hsize[i][j];
		assign arb_hburst[3 * i +: 3]           = xbar_hburst[i][j];
		assign arb_hprot[4 * i +: 4]            = xbar_hprot[i][j];
		assign arb_hmastlock[i]                 = xbar_hmastlock[i][j];
		assign arb_hwdata[W_DATA * i +: W_DATA] = xbar_hwdata[i][j];
		assign xbar_hready_resp[i][j]           = arb_hready_resp[i];
		assign xbar_hresp[i][j]                 = arb_hresp[i];
		assign xbar_hrdata[i][j]                = arb_hrdata[W_DATA * i +: W_DATA];
	end

	ahbl_arbiter #(
		.N_PORTS   (N_MASTERS),
		.W_ADDR    (W_ADDR),
		.W_DATA    (W_DATA),
		.CONN_MASK (CONN_MATRIX_TRANSPOSE[j * N_MASTERS +: N_MASTERS])
	) arb (
		.clk             (clk),
		.rst_n           (rst_n),
		.src_hready      (arb_hready),
		.src_hready_resp (arb_hready_resp),
		.src_hresp       (arb_hresp),
		.src_haddr       (arb_haddr),
		.src_hwrite      (arb_hwrite),
		.src_htrans      (arb_htrans),
		.src_hsize       (arb_hsize),
		.src_hburst      (arb_hburst),
		.src_hprot       (arb_hprot),
		.src_hmastlock   (arb_hmastlock),
		.src_hwdata      (arb_hwdata),
		.src_hrdata      (arb_hrdata),
		.dst_hready      (dst_hready[j]),
		.dst_hready_resp (dst_hready_resp[j]),
		.dst_hresp       (dst_hresp[j]),
		.dst_haddr       (dst_haddr[W_ADDR * j +: W_ADDR]),
		.dst_hwrite      (dst_hwrite[j]),
		.dst_htrans      (dst_htrans[2 * j +: 2]),
		.dst_hsize       (dst_hsize[3 * j +: 3]),
		.dst_hburst      (dst_hburst[3 * j +: 3]),
		.dst_hprot       (dst_hprot[4 * j +: 4]),
		.dst_hmastlock   (dst_hmastlock[j]),
		.dst_hwdata      (dst_hwdata[W_DATA * j +: W_DATA]),
		.dst_hrdata      (dst_hrdata[W_DATA * j +: W_DATA])
	);
end
endgenerate

endmodule
