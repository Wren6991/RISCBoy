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
	parameter RESET_VECTOR = 32'h0000_0000;
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

`include "rv_opcodes.vh"
`include "alu_ops.vh"

localparam N_REGS = 32;
localparam W_REGADDR = $clog2(N_REGS);

// ============================================================================
//                                AHB Master
// ============================================================================

localparam HTRANS_IDLE = 2'b00;
localparam HTRANS_NSEQ = 2'b10;

// Tie off AHB signals we don't care about
assign ahblm_hburst = 3'b000;	// HBURST_SINGLE
assign ahblm_hprot = 4'b0011;	// Lie and say everything is non-cacheable non-bufferable privileged data access
assign ahblm_hmastlock = 1'b0;	// Not supported by processor (or by slaves!)

wire              ahb_req_d;
wire [W_ADDR-1:0] ahb_haddr_d;
wire [2:0]        ahb_hsize_d;
wire              ahb_hwrite_d;
wire              ahb_req_i;
wire [W_ADDR-1:0] ahb_haddr_i;

always @ (*) begin
	if (ahb_req_i) begin
		ahblm_htrans = HTRANS_NSEQ;
		ahblm_haddr  = ahb_haddr_i;
		ahblm_hsize  = 3'h2;
		ahblm_hwrite = 1'b0;
	end else if (ahb_req_d) begin
		ahblm_htrans = HTRANS_NSEQ;
		ahblm_haddr  = ahb_haddr_d;
		ahblm_hsize  = ahb_hsize_d;
		ahblm_hwrite = ahb_hwrite_d;
	end else begin
		ahblm_htrans = HTRANS_IDLE;
		ahblm_haddr  = {W_ADDR{1'b0}};
		ahblm_hsize  = 3'h0;
		ahblm_hwrite = 1'b0;
	end
end


// ============================================================================
//                               Pipe Stage F
// ============================================================================

wire [W_DATA-1:0] wf_icache_rdata;
reg               wf_icache_valid;

wire [W_ADDR-1:0] f_icache_waddr;
wire [W_DATA-1:0] f_icache_wdata;
wire              f_icache_wen;
reg  [31:0]       f_fetch_buf;
reg  [1:0]        f_buf_level;
wire [1:0]        f_buf_level_next;

reg [31:0]        fd_cir;

wire              df_instr_is_32bit;


// Calculate next buffer level combinatorially, so that it is visible to W
// fetch logic in-cycle.
always @ (*) begin
	if (df_instr_is_32bit) begin
		if (f_buf_level == 2'h2) begin
			f_buf_level_next = 2'h0;
		end else begin
			f_buf_level_next = f_buf_level;
		end
	end else begin
		if (f_buf_level == 2'h2) begin
			f_buf_level_next = 2'h1;
		end else begin
			f_buf_level_next = f_buf_level + 1'b1;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		f_fetch_buf <= 32'h0;
		f_buf_level <= 2'h0;
		fd_cir  <= 32'h0;
	end else begin
		// Instruction addressing is defined little endian by RISC-V spec.
		// D will consume either all of CIR, or bits [15:0]
		if (df_instr_is_32bit) begin
			if (f_buf_level == 2'h2) begin
				// No new fetch data since buffer is full; level will go to 0
				fd_cir <= f_fetch_buf;
			end else if (f_buf_level == 2'h1) begin
				if (wf_icache_valid) begin
					fd_cir <= {wf_icache_rdata[15:0], f_fetch_buf[15:0]};
					f_fetch_buf[15:0] <= wf_icache_rdata[31:16];
				end else begin
					fd_cir <= {ahblm_hrdata[15:0], f_fetch_buf[15:0]};
					f_fetch_buf[15:0] <= ahblm_hrdata[31:16];
				end
			end else begin
				if (wf_icache_valid) begin
					fd_cir <= wf_icache_rdata;
				end else begin
					fd_cir <= ahblm_hrdata;
				end
			end
		end else begin
			if (f_buf_level == 2'h2) begin
				// No new fetch data since buffer is full; level will go to 1
				fd_cir <= {f_fetch_buf[15:0], fd_cir[31:16]};
				f_fetch_buf <= {16'h0, f_fetch_buf[31:16]};
			end else if (f_buf_level == 2'h1) begin
				fd_cir <= {f_fetch_buf[15:0], fd_cir[31:16]};
				if (wf_icache_valid) begin
					f_fetch_buf <= wf_icache_rdata;
				end else begin
					f_fetch_buf <= ahblm_hrdata;
				end
			end else begin
				if (wf_icache_valid) begin
					fd_cir <= {wf_icache_rdata[15:0], fd_cir[31:16]};
					f_fetch_buf[15:0] <= wf_icache_rdata[31:16];
				end else begin
					fd_cir <= {ahblm_hrdata[15:0], fd_cir[31:16]};
					f_fetch_buf[15:0] <= ahblm_hrdata[31:16];
				end
			end		
		end
		f_buf_level <= f_buf_level_next;
	end
end

// ============================================================================
//                               Pipe Stage D
// ============================================================================

wire [31:2]          d_instr;
reg  [W_ADDR-1:0]    d_pc;
wire [W_ADDR-1:0]    d_pc_next = d_pc + (df_instr_is_32bit ? 3'h4 : 3'h2);

wire [W_REGADDR-1:0] d_rs1 = d_instr[19:15];
wire [W_REGADDR-1:0] d_rs2 = d_instr[24:20];
wire [W_REGADDR-1:0] d_rd  = d_instr[11: 7];

// Decode various immmediate formats
wire [31:0] d_imm_i = {{21{d_instr[31]}}, d_instr[30:20]};
wire [31:0] d_imm_s = {{21{d_instr[31]}}, d_instr[30:25], d_instr[11:7]};
wire [31:0] d_imm_b = {{20{d_instr[31]}}, d_instr[7], d_instr[30:25], d_instr[11:8], 1'b0};
wire [31:0] d_imm_u = {d_instr[31:12], {12{1'b0}}};
wire [31:0] d_imm_j = {{12{d_instr[31]}}, d_instr[19:12], d_instr[20], d_instr[30:21], 1'b0};

reg  [W_DATA-1:0]    dx_imm;
reg  [W_REGADDR-1:0] dx_rs1;
reg  [W_REGADDR-1:0] dx_rs2;
reg  [W_REGADDR-1:0] dx_rd;
reg  [W_ALUSRC-1:0]  dx_alusrc_a;
reg  [W_ALUSRC-1:0]  dx_alusrc_b;
reg  [W_ALUOP-1:0]   dx_aluop;
reg  [W_MEMOP-1:0]   dx_memop;
reg  [W_BCOND-1:0]   dx_branchcond;
wire [W_DATA-1:0]    dx_rdata1;	// Registered internally in regfile
wire [W_DATA-1:0]    dx_rdata2;
reg  [W_ADDR-1:0]    dx_pc;
reg  [W_ADDR-1:0]    dx_linkaddr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		{dx_imm, dx_rs1, dx_rs2, dx_rd, dx_rdata1, dx_rdata2} <= {(3 * W_DATA + 3 * W_REGADDR){1'b0}};
		{dx_alusrc_a, dx_alusrc_b, dx_aluop} <= {(W_ALUOP + 2){1'b0}};
		dx_memop <= {W_MEMOP{1'b0}};
		d_pc <= {W_ADDR{1'b0}};
		dx_branchcond <= {W_BCOND{1'b0}};
	end else begin
		// Assign some defaults
		dx_rs1 <= d_rs1;
		dx_rs2 <= d_rs2;
		dx_rd <= d_rd;
		dx_imm <= d_imm_i;
		dx_alusrc_a <= ALUSRCA_RS1;
		dx_alusrc_b <= ALUSRCB_RS2;
		dx_memop <= MEMOP_NONE;
		dx_branchcond <= BCOND_NEVER;
		dx_pc <= d_pc;
		dx_linkaddr <= d_pc_next;
		d_pc <= d_pc_next;

		// Decode ALU controls
		casez ({d_instr, 2'b11})
		RV_BEQ:     begin dx_aluop <= ALUOP_SUB; dx_imm <= d_imm_b; dx_branchcond <= BCOND_ZERO;  end
		RV_BNE:     begin dx_aluop <= ALUOP_SUB; dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BLT:     begin dx_aluop <= ALUOP_LT;  dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BGE:     begin dx_aluop <= ALUOP_GE;  dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BLTU:    begin dx_aluop <= ALUOP_LTU; dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_BGEU:    begin dx_aluop <= ALUOP_GEU; dx_imm <= d_imm_b; dx_branchcond <= BCOND_NZERO; end
		RV_JALR:    begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_j; dx_branchcond <= BCOND_ALWAYS; dx_alusrc_a <= ALUSRCA_LINKADDR; dx_alusrc_b <= ALUSRCB_ZERO; end
		RV_JAL:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_branchcond <= BCOND_ALWAYS; dx_alusrc_a <= ALUSRCA_LINKADDR; dx_alusrc_b <= ALUSRCB_ZERO; end
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
		default:    begin $display("Invalid instruction! %h", d_instr); end
		endcase
	end
end

revive_instr_decompress decomp(
	.instr_in(fd_cir),
	.instr_is_32bit(df_instr_is_32bit),
	.instr_out(d_instr)
);


// ============================================================================
//                               Pipe Stage X
// ============================================================================

wire [W_DATA-1:0] x_op_a;
wire [W_DATA-1:0] x_op_a;

reg [W_DATA-1:0]  xm_result;
reg [W_ADDR-1:0]  xm_jump_target;
reg               xm_jump;
reg [W_MEMOP-1:0] xm_memop;

// TODO: speculative execution on branches, earlier jumping for unconditional jumps

// ALU operand muxes
always @ (*) begin
	case (dx_alusrc_a)
	ALUSRCA_RS1: begin
		if (!dx_rs1) begin
			x_op_a = {W_DATA{1'b0}};
		end else if (xm_rd && xm_rd == dx_rs1) begin
			x_op_a = xm_result; // TODO: stall if mem op
		end else if (mw_rd && mw_rd == dx_rs1) begin
			x_op_a = mw_result;
		end else begin
			x_op_a = dx_rdata1;
		end
	end
	ALUSRCA_LINKADDR: begin
		x_op_a = dx_linkaddr;
	end
	ALUSRCA_PC: begin
		x_op_a = dx_pc;
	end
	default: begin
		x_op_a = {W_DATA{1'b0}};
	end
	endcase

	case (dx_alusrc_b)
	ALUSRCB_RS2: begin
		if (!dx_rs2) begin
			x_op_b = {W_DATA{1'b0}};
		end else if (xm_rd && xm_rd == dx_rs2) begin
			x_op_b = xm_result; // TODO: stall if mem op
		end else if (mw_rd && mw_rd == dx_rs2) begin
			x_op_b = mw_result;
		end else begin
			x_op_b = dx_rdata2;
		end
	end
	ALUSRCB_IMM: begin
		x_op_b = dx_imm;
	end
	default: begin
		x_op_b = {W_DATA{1'b0}};
	end
	endcase
end

// AHB transaction request
always @ (*) begin
	ahb_req_d = !dx_memop[3];
	ahb_haddr_d = x_alu_result;
	ahb_hwrite_d = dx_memop == MEMOP_SW || dx_memop == MEMOP_SH || dx_memop == MEMOP_SB;
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		{xm_jump_target, xm_jump} <= {(W_ADDR + 1){1'b0}};
		xm_result <= {W_DATA{1'b0}};
		xm_memop <= MEMOP_NONE;
	end else begin
		xm_jump_target <= dx_imm + (??fasfafasd?? ? dx_pc : dx_rdata1);
		case (dx_branchcond)
			BCOND_ALWAYS: begin xm_jump <= 1'b1; end
			BCOND_ZERO:   begin xm_jump <= alu_zero; end
			BCOND_NZERO:  begin xm_jump <= !alu_zero; end
			default:      begin xm_jump <= 1'b0; end
		endcase
		xm_result <= x_alu_result;
		xm_memop <= dx_memop;
	end
end

revive_alu alu (
	.aluop  (dx_aluop),
	.op_a   (x_op_a),
	.op_b   (x_op_b),
	.result (x_alu_result),
	.zero   (x_alu_zero)
);

// ============================================================================
//                               Pipe Stage M
// ============================================================================

reg [W_REGADDR-1:0] mw_rd;
reg [W_DATA-1:0]    mw_result;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mw_rd <= {W_REGADDR{1'b0}};
		mw_result <= {W_DATA{1'b0}};
	end else begin
		mw_rd <= xm_rd;
		mw_result <= xm_result;
	end
end


// ============================================================================
//                               Pipe Stage W
// ============================================================================

wire [W_ADDR-1:0] w_icache_raddr;
wire              w_icache_valid;

reg [W_ADDR-1:0] w_fetchaddr;

assign ahb_haddr_i = w_fetchaddr;
assign ahb_req_i = !f_buf_level_next[1];

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		wf_icache_valid <= 1'b0;
		w_fetchaddr <= RESET_VECTOR;
	end else begin
		wf_icache_valid <= w_icache_valid;
		if (ahb_req_i) begin
			w_fetchaddr <= w_fetchaddr + 3'h4;
		end
	end
end

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
	.rdata1 (dx_rdata1),
	.raddr2 (d_rs2),
	.rdata2 (dx_rdata2),
	// Signals driven during W
	.waddr  (mw_rd),
	.wdata  (mw_result),
	.wen    (|mw_rd)
);

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

