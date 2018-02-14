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

// ReVive CPU core
// See the documentation
// Don't worry if you don't understand it -- I don't either

module revive_cpu #(
	localparam W_ADDR = 32,
	localparam W_DATA = 32
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// AHB-lite Master port
	input  wire                      abhlm_hready,
	input  wire                      ahblm_hresp,
	output wire [W_ADDR-1:0]         ahblm_haddr,
	output wire                      ahblm_hwrite,
	output wire [1:0]                ahblm_htrans,
	output wire [2:0]                ahblm_hsize,
	output wire [2:0]                ahblm_hburst,
	output wire [3:0]                ahblm_hprot,
	output wire                      ahblm_hmastlock,
	output wire [W_DATA-1:0]         ahblm_hwdata,
	input  wire [W_DATA-1:0]         ahblm_hrdata
);

localparam N_REGS = 32;
localparam W_REGADDR = $clog2(N_REGS);

localparam HTRANS_IDLE = 2'b00;
localparam HTRANS_NSEQ = 2'b10;

// Tie off AHB signals we don't care about
assign ahblm_hburst = 3'b000;	// HBURST_SINGLE
assign ahblm_hprot = 4'b0011;	// Lie and say everything is non-cacheable non-bufferable privileged data access
assign ahblm_hmastlock = 1'b0;	// Not supported by processor (or by slaves!)

// ============================================================================
//                               Pipe Stage F
// ============================================================================

wire [W_DATA-1:0] wf_icache_rdata;
reg               wf_icache_valid;

wire [W_ADDR-1:0] f_icache_waddr;
wire [W_DATA-1:0] f_icache_wdata;
wire              f_icache_wen;
reg  [15:0]       halfword_buf;
reg               hwbuf_valid;

reg [31:0]        fd_cir;

wire              df_instr_is_32bit;


always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		halfword_buf <= 16'h0;
		hwbuf_valid <= 1'b0;
		fd_cir <= 16'h0;
	end else begin
		// Instruction addressing is defined little endian by RISC-V spec.
		// D will consume either all of CIR, or bits [15:0]
		if (wf_icache_valid) begin
			if (hwbuf_valid) begin
				if (df_instr_is_32bit) begin
					fd_cir <= {wf_icache_rdata[15:0], halfword_buf};
					halfword_buf <= wf_icache_rdata[31:16];
					hwbuf_valid <= 1'b1;
				end else begin
					fd_cir <= {halfword_buf, fd_cir[31:16]};
					halfword_buf <= wf_icache_rdata[15:0];	// TODO: what do we do with the other half?
					hwbuf_valid <= 1'b1;
				end
			end else begin
				if (df_instr_is_32bit) begin
					fd_cir <= wf_icache_rdata;
					hwbuf_valid <= 1'b0;
				end else begin
					fd_cir <= {wf_icache_rdata[15:0], fd_cir[31:16]};
					halfword_buf <= wf_icache_rdata[31:16];
					hwbuf_valid <= 1'b1;
				end
			end
		end else begin
			if (hwbuf_valid) begin
				if (df_instr_is_32bit) begin
					// TODO: we are assuming hready. Need to add ready/valid pipeline handshakes so that we can stall on !hready
					fd_cir <= {ahblm_hrdata[15:0], halfword_buf};
					halfword_buf <= ahblm_hrdata[31:16];
					hwbuf_valid <= 1'b1;
				end else begin
					fd_cir <= {halfword_buf, fd_cir[31:16]};
					halfword_buf <= ahblm_hrdata[15:0];	// Same problem! ^^^
					hwbuf_valid <= 1'b1;
				end
			end else begin
				if (df_instr_is_32bit) begin
					fd_cir <= ahblm_hrdata;
					hwbuf_valid <= 1'b0;
				end else begin
					fd_cir <= {ahblm_hrdata[15:0], fd_cir[31:16]};
					halfword_buf <= ahblm_hrdata[31:16];
					hwbuf_valid <= 1'b1;
				end
			end
		end
	end
end

// ============================================================================
//                               Pipe Stage D
// ============================================================================

wire [W_REGADDR-1:0] w_regfile_waddr;
wire [W_DATA-1:0]    w_regfile_wdata;
wire                 w_regfile_wen;

wire [W_REGADDR-1:0] d_rs1;
wire [W_REGADDR-1:0] d_rs2;
wire [W_DATA-1:0]    d_rdata1;
wire [W_DATA-1:0]    d_rdata2;

regfile_1w2r #(
	.FAKE_DUALPORT(0),
	.RESET_REGS(1),
	.N_REGS(N_REGS),
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR)
) inst_regfile_1w2r (
	// Global signals
	.clk    (clk),
	.rst_n  (rst_n),
	// Signals driven during D
	.raddr1 (d_rs1),
	.rdata1 (d_rdata1),
	.raddr2 (d_rs2),
	.rdata2 (d_rdata2),
	// Signals driven during W
	.waddr  (w_regfile_waddr),
	.wdata  (w_regfile_wdata),
	.wen    (w_regfile_wen)
);

// ============================================================================
//                               Pipe Stage X
// ============================================================================

// Something something ALU

// ============================================================================
//                               Pipe Stage M
// ============================================================================

// ============================================================================
//                               Pipe Stage W
// ============================================================================

wire [W_ADDR-1:0] w_icache_raddr;
wire              w_icache_valid;


always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wf_icache_valid <= 1'b0;
	end else begin
		wf_icache_valid <= w_icache_valid;
	end
end

cache_ro_full_assoc #(
	.W_DATA(W_DATA),
	.W_ADDR(W_ADDR),
	.N_ENTRIES(8)
) icache (
	.clk(clk),
	.rst_n(rst_n),

	.raddr(w_icache_raddr),
	.rdata(wf_icache_rdata),
	.rvalid(w_icache_valid),

	.waddr(f_icache_waddr),
	.wdata(f_icache_wdata),
	.wen(f_icache_wen)
);

