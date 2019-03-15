module hazard5_decode #(
	parameter EXTENSION_C = 1,   // compressed instruction extension
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter RESET_VECTOR = 32'h0,
	parameter W_REGADDR = 5
) (
	input wire clk,
	input wire rst_n,

	input wire  [31:0] fd_cir,
	input wire  [1:0] fd_cir_vld,
	output wire [1:0] df_cir_use,
	output wire       df_cir_lock,
	output reg               d_jump_req,
	output reg  [W_ADDR-1:0] d_jump_target,

	output wire d_stall,
	input wire  x_stall,
	input wire  flush_d_x,
	input wire  f_jump_rdy,
	input wire  f_jump_now,
	input wire  [W_ADDR-1:0] f_jump_target,

	output reg [W_REGADDR-1:0] d_rs1, // combinatorial
	output reg [W_REGADDR-1:0] d_rs2, // combinatorial

	output reg  [W_DATA-1:0]    dx_imm,
	output reg  [W_REGADDR-1:0] dx_rs1,
	output reg  [W_REGADDR-1:0] dx_rs2,
	output reg  [W_REGADDR-1:0] dx_rd,
	output reg  [W_ALUSRC-1:0]  dx_alusrc_a,
	output reg  [W_ALUSRC-1:0]  dx_alusrc_b,
	output reg  [W_ALUOP-1:0]   dx_aluop,
	output reg  [W_MEMOP-1:0]   dx_memop,
	output reg  [W_BCOND-1:0]   dx_branchcond,
	output reg  [W_ADDR-1:0]    dx_branchoffs,
	output reg                  dx_jump_is_regoffs,
	output reg  [W_ADDR-1:0]    dx_pc,
	output reg  [W_ADDR-1:0]    dx_mispredict_addr,
	output reg                  dx_except_invalid_instr
);


// TODO TODO factor this out in a cleaner way, e.g. separate out registers and stall logic.

`include "rv_opcodes.vh"
`include "hazard5_ops.vh"

// ============================================================================
// PC/CIR control
// ============================================================================

wire d_starved = ~|fd_cir_vld || fd_cir_vld[0] && d_instr_is_32bit;
assign d_stall = x_stall ||
	d_starved || (d_jump_req && !f_jump_rdy);
assign df_cir_use =
	d_starved || d_stall ? 2'h0 :
	d_instr_is_32bit ? 2'h2 : 2'h1;

// CIR Locking is required if we successfully assert a jump request, but decode is stalled.
// (This only happens if decode stall is caused by X stall, not if fetch is starved!)
// The reason for this is that, if the CIR is not locked in, it can be trashed by
// incoming fetch data before the roadblock clears ahead of us, which will squash any other
// side effects this instruction may have besides jumping! This includes:
// - Linking for JAL
// - Mispredict recovery for branches
// Note that it is not possible to simply gate the jump request based on X stalling,
// because X stall is a function of hready, and jump request feeds haddr htrans etc.


wire assert_cir_lock = d_jump_req && f_jump_rdy && d_stall;
wire deassert_cir_lock = !d_stall;
reg cir_lock_prev;

assign df_cir_lock = (cir_lock_prev && !deassert_cir_lock) || assert_cir_lock;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		cir_lock_prev <= 1'b0;
	else
		cir_lock_prev <= df_cir_lock;

reg  [W_ADDR-1:0]    pc;
wire [W_ADDR-1:0]    pc_next = pc + (d_instr_is_32bit ? 32'h4 : 32'h2);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pc <= RESET_VECTOR;
	end else begin
		if (f_jump_now)
			pc <= f_jump_target;
		else if (!d_stall && !cir_lock_prev)
			pc <= pc_next;
	end
end

// If the current CIR is there due to locking, it is a jump which has already had primary effect.
wire jump_enable = !d_starved && !cir_lock_prev;

always @ (*) begin
	// Branches are major opcode 1100011, JAL is 1100111:
	d_jump_target = pc + (d_instr[2] ? d_imm_j : d_imm_b);

	casez ({d_instr[31], d_instr})
	{1'b1, RV_BEQ }: d_jump_req = jump_enable;
	{1'b1, RV_BNE }: d_jump_req = jump_enable;
	{1'b1, RV_BLT }: d_jump_req = jump_enable;
	{1'b1, RV_BGE }: d_jump_req = jump_enable;
	{1'b1, RV_BLTU}: d_jump_req = jump_enable;
	{1'b1, RV_BGEU}: d_jump_req = jump_enable;
	{1'bz, RV_JAL }: d_jump_req = jump_enable;
	default: d_jump_req = 1'b0;
	endcase
end

// ============================================================================
// Expand compressed instructions
// ============================================================================

wire [31:0] d_instr;
wire        d_instr_is_32bit;
wire        d_invalid_16bit;
reg         d_invalid_32bit;
wire        d_invalid = d_invalid_16bit || d_invalid_32bit;

hazard5_instr_decompress #(
	.PASSTHROUGH(!EXTENSION_C)
) decomp (
	.instr_in(fd_cir),
	.instr_is_32bit(d_instr_is_32bit),
	.instr_out(d_instr),
	.invalid(d_invalid_16bit)
);

// ============================================================================
// Decode X controls
// ============================================================================

// Decode various immmediate formats
wire [31:0] d_imm_i = {{21{d_instr[31]}}, d_instr[30:20]};
wire [31:0] d_imm_s = {{21{d_instr[31]}}, d_instr[30:25], d_instr[11:7]};
wire [31:0] d_imm_b = {{20{d_instr[31]}}, d_instr[7], d_instr[30:25], d_instr[11:8], 1'b0};
wire [31:0] d_imm_u = {d_instr[31:12], {12{1'b0}}};
wire [31:0] d_imm_j = {{12{d_instr[31]}}, d_instr[19:12], d_instr[20], d_instr[30:21], 1'b0};
wire [31:0] d_imm_isize = {29'h0, 2'h01 ^ {2{d_instr_is_32bit}}, 1'b0};

// Combinatorials:
reg  [W_REGADDR-1:0] d_rd;
reg  [W_DATA-1:0]    d_imm;
reg  [W_DATA-1:0]    d_branchoffs;
reg  [W_ALUSRC-1:0]  d_alusrc_a;
reg  [W_ALUSRC-1:0]  d_alusrc_b;
reg  [W_ALUOP-1:0]   d_aluop;
reg  [W_MEMOP-1:0]   d_memop;
reg  [W_BCOND-1:0]   d_branchcond;
reg                  d_jump_is_regoffs;


always @ (*) begin
	// Assign some defaults
	d_rs1 = d_instr[19:15];
	d_rs2 = d_instr[24:20];
	d_rd  = d_instr[11: 7];
	d_imm = d_imm_i;
	d_branchoffs = d_imm_i;
	d_alusrc_a = ALUSRCA_RS1;
	d_alusrc_b = ALUSRCB_RS2;
	d_aluop = ALUOP_ADD;
	d_memop = MEMOP_NONE;
	d_branchcond = BCOND_NEVER;
	d_jump_is_regoffs = 1'b0;
	d_invalid_32bit = 1'b0;

	casez (d_instr)
	RV_BEQ:     begin d_rd = {W_REGADDR{1'b0}}; d_aluop = ALUOP_SUB; d_branchoffs = d_imm_b; d_branchcond = BCOND_ZERO;  end
	RV_BNE:     begin d_rd = {W_REGADDR{1'b0}}; d_aluop = ALUOP_SUB; d_branchoffs = d_imm_b; d_branchcond = BCOND_NZERO; end
	RV_BLT:     begin d_rd = {W_REGADDR{1'b0}}; d_aluop = ALUOP_LT;  d_branchoffs = d_imm_b; d_branchcond = BCOND_NZERO; end
	RV_BGE:     begin d_rd = {W_REGADDR{1'b0}}; d_aluop = ALUOP_LT;  d_branchoffs = d_imm_b; d_branchcond = BCOND_ZERO; end
	RV_BLTU:    begin d_rd = {W_REGADDR{1'b0}}; d_aluop = ALUOP_LTU; d_branchoffs = d_imm_b; d_branchcond = BCOND_NZERO; end
	RV_BGEU:    begin d_rd = {W_REGADDR{1'b0}}; d_aluop = ALUOP_LTU; d_branchoffs = d_imm_b; d_branchcond = BCOND_ZERO; end
	RV_JALR:    begin d_aluop = ALUOP_ADD; d_imm = d_imm_isize; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_branchcond = BCOND_ALWAYS; d_alusrc_a = ALUSRCA_PC; d_jump_is_regoffs = 1'b1; end
	RV_JAL:     begin d_aluop = ALUOP_ADD; d_imm = d_imm_isize; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_alusrc_a = ALUSRCA_PC; d_rs1 = {W_REGADDR{1'b0}}; end
	RV_LUI:     begin d_aluop = ALUOP_ADD; d_imm = d_imm_u; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_rs1 = {W_REGADDR{1'b0}}; end
	RV_AUIPC:   begin d_aluop = ALUOP_ADD; d_imm = d_imm_u; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_alusrc_a = ALUSRCA_PC;  d_rs1 = {W_REGADDR{1'b0}}; end
	RV_ADDI:    begin d_aluop = ALUOP_ADD; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_SLLI:    begin d_aluop = ALUOP_SLL; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_SLTI:    begin d_aluop = ALUOP_LT;  d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_SLTIU:   begin d_aluop = ALUOP_LTU; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_XORI:    begin d_aluop = ALUOP_XOR; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_SRLI:    begin d_aluop = ALUOP_SRL; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_SRAI:    begin d_aluop = ALUOP_SRA; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_ORI:     begin d_aluop = ALUOP_OR;  d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_ANDI:    begin d_aluop = ALUOP_AND; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; end
	RV_ADD:     begin d_aluop = ALUOP_ADD; end
	RV_SUB:     begin d_aluop = ALUOP_SUB; end
	RV_SLL:     begin d_aluop = ALUOP_SLL; end
	RV_SLT:     begin d_aluop = ALUOP_LT;  end
	RV_SLTU:    begin d_aluop = ALUOP_LTU; end
	RV_XOR:     begin d_aluop = ALUOP_XOR; end
	RV_SRL:     begin d_aluop = ALUOP_SRL; end
	RV_SRA:     begin d_aluop = ALUOP_SRA; end
	RV_OR:      begin d_aluop = ALUOP_OR;  end
	RV_AND:     begin d_aluop = ALUOP_AND; end
	RV_LB:      begin d_aluop = ALUOP_ADD; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_memop = MEMOP_LB;  end
	RV_LH:      begin d_aluop = ALUOP_ADD; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_memop = MEMOP_LH;  end
	RV_LW:      begin d_aluop = ALUOP_ADD; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_memop = MEMOP_LW;  end
	RV_LBU:     begin d_aluop = ALUOP_ADD; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_memop = MEMOP_LBU; end
	RV_LHU:     begin d_aluop = ALUOP_ADD; d_imm = d_imm_i; d_alusrc_b = ALUSRCB_IMM; d_rs2 = {W_REGADDR{1'b0}}; d_memop = MEMOP_LHU; end
	RV_SB:      begin d_aluop = ALUOP_ADD; d_imm = d_imm_s; d_alusrc_b = ALUSRCB_IMM; d_memop = MEMOP_SB;  d_rd = {W_REGADDR{1'b0}}; end
	RV_SH:      begin d_aluop = ALUOP_ADD; d_imm = d_imm_s; d_alusrc_b = ALUSRCB_IMM; d_memop = MEMOP_SH;  d_rd = {W_REGADDR{1'b0}}; end
	RV_SW:      begin d_aluop = ALUOP_ADD; d_imm = d_imm_s; d_alusrc_b = ALUSRCB_IMM; d_memop = MEMOP_SW;  d_rd = {W_REGADDR{1'b0}}; end
	RV_FENCE:   begin d_rd = {W_REGADDR{1'b0}}; end  // NOP
	RV_FENCE_I: begin d_rd = {W_REGADDR{1'b0}}; end  // NOP // TODO: this should be jump to PC + 4. Evaluate the cost of doing this in decode (or find a way of doing it in X).
	RV_SYSTEM:  begin
		//synthesis translate_off
		if (!d_stall) $display("Syscall @ PC %h: %h", pc, d_instr);
		//synthesis translate_on
	 end
	default:    begin d_invalid_32bit = 1'b1; end
	endcase
end


always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		{dx_rs1, dx_rs2, dx_rd} <= {(3 * W_REGADDR){1'b0}};
		dx_alusrc_a <= ALUSRCA_RS1;
		dx_alusrc_b <= ALUSRCB_RS2;
		dx_aluop <= ALUOP_ADD;
		dx_memop <= MEMOP_NONE;
		dx_branchcond <= BCOND_NEVER;
		dx_jump_is_regoffs <= 1'b0;
		dx_except_invalid_instr <= 1'b0;
	end else if (!x_stall) begin
		dx_rs1 <= d_rs1;
		dx_rs2 <= d_rs2;
		dx_rd <= d_rd;
		dx_alusrc_a <= d_alusrc_a;
		dx_alusrc_b <= d_alusrc_b;
		dx_aluop <= d_aluop;
		dx_memop <= d_memop;
		dx_branchcond <= d_branchcond;
		dx_jump_is_regoffs <= d_jump_is_regoffs;
		dx_except_invalid_instr <= d_invalid;

		// Bubble assertion
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

// No reset required on these; will be masked by the resettable pipeline controls until they're valid
always @ (posedge clk) begin
	if (!x_stall) begin
		dx_imm <= d_imm;
		dx_branchoffs <= d_branchoffs;
		dx_pc <= pc;
	end
	// When we lock CIR, PC changes immediately afterward due to jump.
	// However the locked instruction will still need its mispredict/link value
	// (JAL or branch) so we need to calculate this *immediately*
	// and then leave the precalculated value in place during lock.
	if (assert_cir_lock || (!x_stall && !cir_lock_prev))
		dx_mispredict_addr <= pc_next;
	// This relies on the assumption (which should be tested..!) that,
	// when executing a locked instruction, the instruction in X
	// does not need the prior contents of dx_mispredict_addr.
	// At time of writing these are JAL, JALR and mispredicted branches.
end

endmodule
