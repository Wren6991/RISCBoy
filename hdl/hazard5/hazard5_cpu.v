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

module hazard5_cpu #(
	parameter RESET_VECTOR = 32'h0000_0000,
	localparam W_ADDR = 32,
	localparam W_DATA = 32
) (
	// Global signals
	input wire                       clk,
	input wire                       rst_n,

	// AHB-lite Master port
	output reg  [W_ADDR-1:0]         ahblm_haddr,
	output reg                       ahblm_hwrite,
	output reg  [1:0]                ahblm_htrans,
	output reg  [2:0]                ahblm_hsize,
	output wire [2:0]                ahblm_hburst,
	output wire [3:0]                ahblm_hprot,
	output wire                      ahblm_hmastlock,
	input  wire                      ahblm_hready,
	input  wire                      ahblm_hresp,
	output reg  [W_DATA-1:0]         ahblm_hwdata,
	input  wire [W_DATA-1:0]         ahblm_hrdata
);

`include "rv_opcodes.vh"
`include "hazard5_ops.vh"

`undef ASSERT
`ifdef ENABLE_ASSERTIONS
`define ASSERT(x) assert(x)
`else
`define ASSERT(x)
`endif

localparam N_REGS = 32;
// should be localparam but ISIM can't cope
parameter W_REGADDR = $clog2(N_REGS);
localparam NOP_INSTR = 32'h13;	// addi x0, x0, 0

wire flush_d_x;

wire d_stall;
wire x_stall;
wire m_stall;

// ============================================================================
//                              AHB-lite Master
// ============================================================================

localparam HTRANS_IDLE = 2'b00;
localparam HTRANS_NSEQ = 2'b10;
localparam HSIZE_WORD  = 3'd2;
localparam HSIZE_HWORD = 3'd1;
localparam HSIZE_BYTE  = 3'd0;

// Tie off AHB signals we don't care about
assign ahblm_hburst = 3'b000;   // HBURST_SINGLE
assign ahblm_hprot = 4'b0011;   // Lie and say everything is non-cacheable non-bufferable privileged data access
assign ahblm_hmastlock = 1'b0;  // Not supported by processor (or by slaves!)

// "regs" are all combinational signals from X.
reg               ahb_req_d;
reg  [W_ADDR-1:0] ahb_haddr_d;
reg  [2:0]        ahb_hsize_d;
reg               ahb_hwrite_d;
wire              ahb_req_i;
wire [2:0]        ahb_hsize_i;
wire [W_ADDR-1:0] ahb_haddr_i;


// Arbitrate requests from competing sources
wire m_jump_req;
wire ahb_gnt_i;
wire ahb_gnt_d;

assign {ahb_gnt_i, ahb_gnt_d} =
	m_jump_req ? 2'b10 :
	ahb_req_d  ? 2'b01 :
	ahb_req_i  ? 2'b10 :
	             2'b00 ;

// Keep track of whether instr/data access is active in AHB dataphase.
reg ahb_active_dph_i;
reg ahb_active_dph_d;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ahb_active_dph_i <= 1'b0;
		ahb_active_dph_d <= 1'b0;
	end else if (ahblm_hready) begin
		ahb_active_dph_i <= ahb_gnt_i;
		ahb_active_dph_d <= ahb_gnt_d;
	end
end

// Address-phase signal passthrough
always @ (*) begin
	if (ahb_gnt_d) begin
		ahblm_htrans = HTRANS_NSEQ;
		ahblm_haddr  = ahb_haddr_d;
		ahblm_hsize  = ahb_hsize_d;
		ahblm_hwrite = ahb_hwrite_d;
	end else if (ahb_gnt_i) begin
		ahblm_htrans = HTRANS_NSEQ;
		ahblm_haddr  = ahb_haddr_i;
		ahblm_hsize  = ahb_hsize_i;
		ahblm_hwrite = 1'b0;
	end else begin
		ahblm_htrans = HTRANS_IDLE;
		ahblm_haddr  = {W_ADDR{1'b0}}; // TODO: make this the same as one of the others to save gates?
		ahblm_hsize  = 3'h0;
		ahblm_hwrite = 1'b0;
	end
end

// ============================================================================
//                               Pipe Stage F
// ============================================================================

wire [W_ADDR-1:0] m_jump_target;
reg               d_jump_req;
reg  [W_ADDR-1:0] d_jump_target;

wire              f_jump_req = d_jump_req || m_jump_req;
wire [W_ADDR-1:0] f_jump_target = m_jump_req ? m_jump_target : d_jump_target;
wire              f_jump_rdy;
wire              f_jump_now = f_jump_req && f_jump_rdy;

wire [31:0] fd_cir;
wire [1:0] fd_cir_vld;
wire [1:0] df_cir_use;

wire f_mem_size;
assign ahb_hsize_i = f_mem_size ? HSIZE_WORD : HSIZE_HWORD;

hazard5_frontend #(
	.W_ADDR(W_ADDR),
	.W_DATA(32),
	.FIFO_DEPTH(1),
	.RESET_VECTOR(RESET_VECTOR)
) frontend (
	.clk             (clk),
	.rst_n           (rst_n),

	.mem_size        (f_mem_size),
	.mem_addr        (ahb_haddr_i),
	.mem_addr_vld    (ahb_req_i),
	.mem_addr_rdy    (ahblm_hready && ahb_gnt_i),

	.mem_data        (ahblm_hrdata),
	.mem_data_vld    (ahblm_hready && ahb_active_dph_i),

	.jump_target     (f_jump_target),
	.jump_target_vld (f_jump_req),
	.jump_target_rdy (f_jump_rdy),

	.cir             (fd_cir),
	.cir_vld         (fd_cir_vld),
	.cir_use         (df_cir_use)
);

assign flush_d_x = m_jump_req && f_jump_rdy;

// ============================================================================
//                               Pipe Stage D
// ============================================================================


reg  [W_DATA-1:0]    dx_imm;
reg  [W_REGADDR-1:0] dx_rs1;
reg  [W_REGADDR-1:0] dx_rs2;
reg  [W_REGADDR-1:0] dx_rd;
reg  [W_ALUSRC-1:0]  dx_alusrc_a;
reg  [W_ALUSRC-1:0]  dx_alusrc_b;
reg  [W_ALUOP-1:0]   dx_aluop;
reg  [W_MEMOP-1:0]   dx_memop;
reg  [W_BCOND-1:0]   dx_branchcond;
reg                  dx_jump_is_regoffs;
wire [W_DATA-1:0]    dx_rdata1;	// Registered internally in regfile
wire [W_DATA-1:0]    dx_rdata2;
reg  [W_ADDR-1:0]    dx_pc;
reg  [W_ADDR-1:0]    dx_mispredict_addr;
reg                  dx_except_invalid_instr;

wire d_cir_empty = ~|fd_cir_vld || (fd_cir_vld == 2'd1 && d_instr_is_32bit);

assign d_stall = x_stall ||
	d_cir_empty || (d_jump_req && !f_jump_rdy);

// Expand compressed instructions, and tell F how much instr data we are using

wire [31:0] d_instr;
wire        d_instr_is_32bit;
wire        d_invalid_16bit;
reg         d_invalid_32bit;
wire        d_invalid = d_invalid_16bit || d_invalid_32bit;

hazard5_instr_decompress #(
	.PASSTHROUGH(0)
) decomp (
	.instr_in(fd_cir),
	.instr_is_32bit(d_instr_is_32bit),
	.instr_out(d_instr),
	.invalid(d_invalid_16bit)
);

wire d_starved = ~|fd_cir_vld || fd_cir_vld[0] && d_instr_is_32bit;
assign df_cir_use =
	d_starved || d_stall ? 2'h0 :
	d_instr_is_32bit ? 2'h2 : 2'h1;


// Various D-local regs/wires
reg  [W_ADDR-1:0]    d_pc;
wire [W_ADDR-1:0]    d_pc_next = d_pc + (d_instr_is_32bit ? 32'h4 : 32'h2);

wire [W_REGADDR-1:0] d_rs1 = d_instr[19:15];
wire [W_REGADDR-1:0] d_rs2 = d_instr[24:20];
wire [W_REGADDR-1:0] d_rd  = d_instr[11: 7];

// Decode various immmediate formats
wire [31:0] d_imm_i = {{21{d_instr[31]}}, d_instr[30:20]};
wire [31:0] d_imm_s = {{21{d_instr[31]}}, d_instr[30:25], d_instr[11:7]};
wire [31:0] d_imm_b = {{20{d_instr[31]}}, d_instr[7], d_instr[30:25], d_instr[11:8], 1'b0};
wire [31:0] d_imm_u = {d_instr[31:12], {12{1'b0}}};
wire [31:0] d_imm_j = {{12{d_instr[31]}}, d_instr[19:12], d_instr[20], d_instr[30:21], 1'b0};

// Jump decode
// Sign bit of immediate gives branch direction; backward branches predicted taken.

always @ (*) begin
	casez ({d_instr[31], d_instr})
	{1'b1, RV_BEQ }: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_b; end
	{1'b1, RV_BNE }: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_b; end
	{1'b1, RV_BLT }: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_b; end
	{1'b1, RV_BGE }: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_b; end
	{1'b1, RV_BLTU}: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_b; end
	{1'b1, RV_BGEU}: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_b; end
	{1'bz, RV_JAL }: begin d_jump_req = !d_cir_empty; d_jump_target = d_pc + d_imm_j; end
	default: begin d_jump_req = 1'b0; d_jump_target = {W_ADDR{1'b0}}; end
	endcase
end

// TODO: refactor the two big case statements
always @ (*) begin
	casez (d_instr)
	RV_BEQ:     d_invalid_32bit = 1'b0;
	RV_BNE:     d_invalid_32bit = 1'b0;
	RV_BLT:     d_invalid_32bit = 1'b0;
	RV_BGE:     d_invalid_32bit = 1'b0;
	RV_BLTU:    d_invalid_32bit = 1'b0;
	RV_BGEU:    d_invalid_32bit = 1'b0;
	RV_JALR:    d_invalid_32bit = 1'b0;
	RV_JAL:     d_invalid_32bit = 1'b0;
	RV_LUI:     d_invalid_32bit = 1'b0;
	RV_AUIPC:   d_invalid_32bit = 1'b0;
	RV_ADDI:    d_invalid_32bit = 1'b0;
	RV_SLLI:    d_invalid_32bit = 1'b0;
	RV_SLTI:    d_invalid_32bit = 1'b0;
	RV_SLTIU:   d_invalid_32bit = 1'b0;
	RV_XORI:    d_invalid_32bit = 1'b0;
	RV_SRLI:    d_invalid_32bit = 1'b0;
	RV_SRAI:    d_invalid_32bit = 1'b0;
	RV_ORI:     d_invalid_32bit = 1'b0;
	RV_ANDI:    d_invalid_32bit = 1'b0;
	RV_ADD:     d_invalid_32bit = 1'b0;
	RV_SUB:     d_invalid_32bit = 1'b0;
	RV_SLL:     d_invalid_32bit = 1'b0;
	RV_SLT:     d_invalid_32bit = 1'b0;
	RV_SLTU:    d_invalid_32bit = 1'b0;
	RV_XOR:     d_invalid_32bit = 1'b0;
	RV_SRL:     d_invalid_32bit = 1'b0;
	RV_SRA:     d_invalid_32bit = 1'b0;
	RV_OR:      d_invalid_32bit = 1'b0;
	RV_AND:     d_invalid_32bit = 1'b0;
	RV_LB:      d_invalid_32bit = 1'b0;
	RV_LH:      d_invalid_32bit = 1'b0;
	RV_LW:      d_invalid_32bit = 1'b0;
	RV_LBU:     d_invalid_32bit = 1'b0;
	RV_LHU:     d_invalid_32bit = 1'b0;
	RV_SB:      d_invalid_32bit = 1'b0;
	RV_SH:      d_invalid_32bit = 1'b0;
	RV_SW:      d_invalid_32bit = 1'b0;
	RV_FENCE:   d_invalid_32bit = 1'b0;
	RV_FENCE_I: d_invalid_32bit = 1'b0;
	RV_SYSTEM:  d_invalid_32bit = 1'b0;
	default:    d_invalid_32bit = 1'b1;
	endcase
end


always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		{dx_imm, dx_rs1, dx_rs2, dx_rd} <= {(W_DATA + 3 * W_REGADDR){1'b0}};
		dx_alusrc_a <= ALUSRCA_ZERO;
		dx_alusrc_b <= ALUSRCB_ZERO;
		dx_aluop <= ALUOP_ADD;
		dx_memop <= MEMOP_NONE;
		d_pc <= RESET_VECTOR;
		dx_pc <= {W_ADDR{1'b0}};
		dx_mispredict_addr <= {W_ADDR{1'b0}};
		dx_branchcond <= BCOND_NEVER;
		dx_jump_is_regoffs <= 1'b0;
		dx_except_invalid_instr <= 1'b0;
	end else if (!x_stall) begin
		if (f_jump_now) begin
			d_pc <= f_jump_target;
			dx_pc <= d_pc;
		end else if (d_stall) begin
			d_pc <= d_pc;
		end else begin
			d_pc <= d_pc_next;
			dx_pc <= d_pc;
		end

		// Assign some defaults
		dx_rs1 <= d_rs1;
		dx_rs2 <= d_rs2;
		dx_rd <= d_rd;
		dx_imm <= d_imm_i;
		dx_alusrc_a <= ALUSRCA_RS1;
		dx_alusrc_b <= ALUSRCB_RS2;
		dx_memop <= MEMOP_NONE;
		dx_branchcond <= BCOND_NEVER;
		dx_jump_is_regoffs <= 1'b0;
		dx_mispredict_addr <= d_pc_next;
		dx_except_invalid_instr <= 1'b0;

		casez (d_instr)
		RV_BEQ:     begin dx_rd <= {W_REGADDR{1'b0}}; dx_aluop <= ALUOP_SUB; dx_imm <= d_imm_b; dx_branchcond <= BCOND_ZERO;  end
		RV_BNE:     begin dx_rd <= {W_REGADDR{1'b0}}; dx_aluop <= ALUOP_SUB; dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BLT:     begin dx_rd <= {W_REGADDR{1'b0}}; dx_aluop <= ALUOP_LT;  dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BGE:     begin dx_rd <= {W_REGADDR{1'b0}}; dx_aluop <= ALUOP_GE;  dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BLTU:    begin dx_rd <= {W_REGADDR{1'b0}}; dx_aluop <= ALUOP_LTU; dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BGEU:    begin dx_rd <= {W_REGADDR{1'b0}}; dx_aluop <= ALUOP_GEU; dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_JALR:    begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_branchcond <= BCOND_ALWAYS; dx_alusrc_a <= ALUSRCA_LINKADDR; dx_alusrc_b <= ALUSRCB_ZERO; dx_jump_is_regoffs <= 1'b1; end
		RV_JAL:     begin dx_aluop <= ALUOP_ADD; dx_alusrc_a <= ALUSRCA_LINKADDR; dx_alusrc_b <= ALUSRCB_ZERO; end
		RV_LUI:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_u; dx_alusrc_b <= ALUSRCB_IMM; dx_alusrc_a <= ALUSRCA_ZERO; end
		RV_AUIPC:   begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_u; dx_alusrc_b <= ALUSRCB_IMM; dx_alusrc_a <= ALUSRCA_PC; end
		RV_ADDI:    begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_SLLI:    begin dx_aluop <= ALUOP_SLL; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_SLTI:    begin dx_aluop <= ALUOP_LT;  dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_SLTIU:   begin dx_aluop <= ALUOP_LTU; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_XORI:    begin dx_aluop <= ALUOP_XOR; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_SRLI:    begin dx_aluop <= ALUOP_SRL; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_SRAI:    begin dx_aluop <= ALUOP_SRA; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_ORI:     begin dx_aluop <= ALUOP_OR;  dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_ANDI:    begin dx_aluop <= ALUOP_AND; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; end
		RV_ADD:     begin dx_aluop <= ALUOP_ADD; end
		RV_SUB:     begin dx_aluop <= ALUOP_SUB; end
		RV_SLL:     begin dx_aluop <= ALUOP_SLL; end
		RV_SLT:     begin dx_aluop <= ALUOP_LT;  end
		RV_SLTU:    begin dx_aluop <= ALUOP_LTU; end
		RV_XOR:     begin dx_aluop <= ALUOP_XOR; end
		RV_SRL:     begin dx_aluop <= ALUOP_SRL; end
		RV_SRA:     begin dx_aluop <= ALUOP_SRA; end
		RV_OR:      begin dx_aluop <= ALUOP_OR;  end
		RV_AND:     begin dx_aluop <= ALUOP_AND; end
		RV_LB:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_LB;  end
		RV_LH:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_LH;  end
		RV_LW:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_LW;  end
		RV_LBU:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_LBU; end
		RV_LHU:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_LHU; end
		RV_SB:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_s; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_SB;  dx_rd <= {W_REGADDR{1'b0}}; end
		RV_SH:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_s; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_SH;  dx_rd <= {W_REGADDR{1'b0}}; end
		RV_SW:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_s; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_SW;  dx_rd <= {W_REGADDR{1'b0}}; end
		RV_FENCE:   begin dx_rd <= {W_REGADDR{1'b0}}; end  // NOP
		RV_FENCE_I: begin dx_rd <= {W_REGADDR{1'b0}}; end  // NOP
		RV_SYSTEM:  begin $display("Syscall: %h", d_instr); end
		default:    begin dx_except_invalid_instr <= 1'b1; end
		endcase

		if (d_stall || flush_d_x) begin
			dx_branchcond <= BCOND_NEVER;
			dx_memop <= MEMOP_NONE;
			dx_rd <= 5'h0;
			dx_except_invalid_instr <= 1'b0;
			// Also need to clear rs1, rs2, due to a nasty sequence of events:
			// Suppose we have a load, followed by a dependent branch, which is predicted taken
			// - branch will stall in D until AHB master becomes free
			// - on next cycle, prediction causes jump, and bubble is in X
			// - if X gets branch's rs1, rs2, it will cause spurious RAW stall
			// - on next cycle, branch will not progress into X due to RAW stall, but *will* be replaced in D due to jump
			// - branch mispredict now cannot be corrected
			dx_rs1 <= 5'h0;
			dx_rs2 <= 5'h0;
		end
	end
end

reg [W_REGADDR-1:0] mw_rd;
reg [W_DATA-1:0]    mw_result;

hazard5_regfile_1w2r #(
	.FAKE_DUALPORT(0),
`ifdef SIM
	.RESET_REGS(1),
`else
	.RESET_REGS(0),
`endif
	.N_REGS(N_REGS),
	.W_DATA(W_DATA)
) inst_regfile_1w2r (
	.clk    (clk),
	.rst_n  (rst_n),
	// On stall, we feed X's addresses back into regfile
	// so that output does not change.
	.raddr1 (x_stall ? dx_rs1 : d_rs1),
	.rdata1 (dx_rdata1),
	.raddr2 (x_stall ? dx_rs2 : d_rs2),
	.rdata2 (dx_rdata2),

	.waddr  (mw_rd),
	.wdata  (mw_result),
	.wen    (|mw_rd)
);

// ============================================================================
//                               Pipe Stage X
// ============================================================================

// Register the write which took place to the regfile on previous cycle, and bypass.
// This is an alternative to a write -> read bypass in the regfile,
// which we can't implement whilst maintaining BRAM inference compatibility (iCE40).
reg  [W_REGADDR-1:0] wx_rd;
reg  [W_DATA-1:0]    wx_result;

// Combinational regs for muxing
reg   [W_DATA-1:0]   x_rs1_bypass;
reg   [W_DATA-1:0]   x_rs2_bypass;
reg   [W_DATA-1:0]   x_op_a;
reg   [W_DATA-1:0]   x_op_b;
wire  [31:0]         x_alu_result;
wire                 x_alu_zero;

reg  [W_REGADDR-1:0] xm_rs1;
reg  [W_REGADDR-1:0] xm_rs2;
reg  [W_REGADDR-1:0] xm_rd;
reg  [W_DATA-1:0]    xm_result;
reg  [W_ADDR-1:0]    xm_jump_target;
reg                  xm_jump;
reg  [W_MEMOP-1:0]   xm_memop;
reg                  xm_except_invalid_instr;

wire [W_ADDR-1:0] x_taken_jump_target = dx_imm + (dx_jump_is_regoffs ? x_rs1_bypass : dx_pc);

reg x_stall_raw;

assign x_stall = m_stall ||
	x_stall_raw || ahb_req_d && !(ahb_gnt_d && ahblm_hready);

// Load-use hazard detection
always @ (*) begin
	x_stall_raw = 1'b0;
	if (xm_memop < MEMOP_SW) begin
		if (|xm_rd && xm_rd == dx_rs1) begin
			// Store addresses cannot be bypassed later, so there is no exception here.
			x_stall_raw = 1'b1;
		end else if (|xm_rd && xm_rd == dx_rs2) begin
			// Store data can be bypassed in M. Any other instructions must stall.
			x_stall_raw = !(dx_memop == MEMOP_SW || dx_memop == MEMOP_SH || dx_memop == MEMOP_SB);
		end
	end
end

// AHB transaction request
always @ (*) begin
	// Need to be careful not to use anything hready-sourced to gate htrans!
	ahb_req_d = ~|(dx_memop & 4'h8) && !x_stall_raw && !flush_d_x;
	ahb_haddr_d = x_alu_result;
	ahb_hwrite_d = dx_memop == MEMOP_SW || dx_memop == MEMOP_SH || dx_memop == MEMOP_SB;
	case (dx_memop)
		MEMOP_LW:  ahb_hsize_d = HSIZE_WORD;
		MEMOP_SW:  ahb_hsize_d = HSIZE_WORD;
		MEMOP_LH:  ahb_hsize_d = HSIZE_HWORD;
		MEMOP_LHU: ahb_hsize_d = HSIZE_HWORD;
		MEMOP_SH:  ahb_hsize_d = HSIZE_HWORD;
		default:   ahb_hsize_d = HSIZE_BYTE;
	endcase
end

// ALU operand muxes and bypass
always @ (*) begin
	if (~|dx_rs1) begin
		x_rs1_bypass = {W_DATA{1'b0}};
	end else if (xm_rd == dx_rs1) begin
		x_rs1_bypass = xm_result;
	end else if (mw_rd == dx_rs1) begin
		x_rs1_bypass = mw_result;
	end else if (wx_rd == dx_rs1) begin
		x_rs1_bypass = wx_result;
	end else begin
		x_rs1_bypass = dx_rdata1;
	end
	if (~|dx_rs2) begin
		x_rs2_bypass = {W_DATA{1'b0}};
	end else if (xm_rd == dx_rs2) begin
		x_rs2_bypass = xm_result;
	end else if (mw_rd == dx_rs2) begin
		x_rs2_bypass = mw_result;
	end else if (wx_rd == dx_rs2) begin
		x_rs2_bypass = wx_result;
	end else begin
		x_rs2_bypass = dx_rdata2;
	end
	case (dx_alusrc_a)
		ALUSRCA_RS1:      x_op_a = x_rs1_bypass;
		ALUSRCA_LINKADDR: x_op_a = dx_mispredict_addr;
		ALUSRCA_PC:       x_op_a = dx_pc;
		default:          x_op_a = {W_DATA{1'b0}};
	endcase

	case (dx_alusrc_b)
		ALUSRCB_RS2:      x_op_b = x_rs2_bypass;
		ALUSRCB_IMM:      x_op_b = dx_imm;
		default:          x_op_b = {W_DATA{1'b0}};
	endcase
end

// State machine and branch detection
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		{xm_jump_target, xm_jump} <= {(W_ADDR + 1){1'b0}};
		xm_result <= {W_DATA{1'b0}};
		xm_memop <= MEMOP_NONE;
		{xm_rs1, xm_rs2, xm_rd} <= {3 * W_REGADDR{1'b0}};
		xm_except_invalid_instr <= 1'b0;
	end else begin
		`ASSERT(!(m_stall && flush_d_x));// bubble insertion logic below is broken otherwise
		if (!m_stall) begin
			{xm_rs1, xm_rs2, xm_rd} <= {dx_rs1, dx_rs2, dx_rd};
			xm_result <= x_alu_result;
			xm_memop <= dx_memop;
			if (x_stall || flush_d_x) begin
				// Insert bubble
				xm_rd <= {W_REGADDR{1'b0}};
				xm_jump <= 1'b0;
				xm_memop <= MEMOP_NONE;
				xm_except_invalid_instr <= 1'b0;
			end else begin
				case (dx_branchcond)
					BCOND_ALWAYS: begin
						xm_jump <= 1'b1;
						xm_jump_target <= x_taken_jump_target;
					end
					BCOND_ZERO: begin
						// For branches, we are either taking a branch late, or recovering from
						// an incorrectly taken branch, depending on sign of branch offset.
						xm_jump <= x_alu_zero ^ dx_imm[31];
						xm_jump_target <= dx_imm[31] ? dx_mispredict_addr : x_taken_jump_target;
					end
					BCOND_NZERO: begin
						xm_jump <= !x_alu_zero ^ dx_imm[31];
						xm_jump_target <= dx_imm[31] ? dx_mispredict_addr : x_taken_jump_target;
					end
					default: begin
						xm_jump <= 1'b0;
						xm_jump_target <= x_rs2_bypass;	// (ab)use this pathway to pass store data
					end
				endcase
				xm_except_invalid_instr <= dx_except_invalid_instr;
			end
		end
	end
end

hazard5_alu alu (
	.aluop  (dx_aluop),
	.op_a   (x_op_a),
	.op_b   (x_op_b),
	.result (x_alu_result),
	.zero   (x_alu_zero)
);

// ============================================================================
//                               Pipe Stage M
// ============================================================================

reg [1:0]           m_shift;
reg [W_DATA-1:0]    m_rdata_shift;
reg [W_DATA-1:0]    m_wdata;

assign m_jump_req = xm_jump;
assign m_jump_target = xm_jump_target;

assign m_stall = (ahb_active_dph_d && !ahblm_hready) || (m_jump_req && !f_jump_rdy);

always @ (*) begin
	// Local forwarding of store data
	if (~|mw_rd && xm_rs2 == mw_rd) begin
		m_wdata = mw_result;
	end else begin
		m_wdata = xm_jump_target;
	end
	case (xm_memop)
		MEMOP_SW: ahblm_hwdata = m_wdata;
		MEMOP_SH: ahblm_hwdata = {2{m_wdata[15:0]}};
		MEMOP_SB: ahblm_hwdata = {4{m_wdata[7:0]}};
		default:  ahblm_hwdata = 32'h0;
	endcase
	case (xm_memop)
		MEMOP_LW:  m_shift = 2'h0;
		MEMOP_LH:  m_shift = {xm_result[1], 1'b0};
		MEMOP_LHU: m_shift = {xm_result[1], 1'b0};
		default:   m_shift = xm_result[1:0];
	endcase
	// Little endian!
	m_rdata_shift = ahblm_hrdata >> (m_shift << 3);
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mw_rd <= {W_REGADDR{1'b0}};
		mw_result <= {W_DATA{1'b0}};
	end else if (!m_stall) begin
		//synthesis translate_off
		// TODO: proper exception support
		if (xm_except_invalid_instr)
			$display("Invalid instruction!");
		//synthesis translate_on
		mw_rd <= xm_rd;
		case (xm_memop)
			MEMOP_LW:  mw_result <= m_rdata_shift;
			MEMOP_LH:  mw_result <= {{16{m_rdata_shift[15]}}, m_rdata_shift[15:0]};
			MEMOP_LHU: mw_result <= {16'h0, m_rdata_shift[15:0]};
			MEMOP_LB:  mw_result <= {{24{m_rdata_shift[7]}}, m_rdata_shift[7:0]};
			MEMOP_LBU: mw_result <= {24'h0, m_rdata_shift[7:0]};
			default:   mw_result <= xm_result;
		endcase
	end
end

// ============================================================================
//                               Pipe Stage W
// ============================================================================

// Update logic for extra bypass stage, replacing regfile internal bypass

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wx_rd <= {W_REGADDR{1'b0}};
		wx_result <= {W_DATA{1'b0}};
	end else if (!m_stall) begin
		wx_result <= mw_result;
		wx_rd <= mw_rd;
	end
end

`ifdef FORMAL
`include "hazard5_formal.vh"
`endif

endmodule