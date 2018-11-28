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
	output reg               d_jump_req,
	output reg  [W_ADDR-1:0] d_jump_target,

	output wire d_stall,
	input wire  x_stall,
	input wire  flush_d_x,
	input wire  f_jump_rdy,
	input wire  f_jump_now,
	input wire  [W_ADDR-1:0] f_jump_target,

	output wire [W_REGADDR-1:0] d_rs1,
	output wire [W_REGADDR-1:0] d_rs2,

	output reg  [W_DATA-1:0]    dx_imm,
	output reg  [W_REGADDR-1:0] dx_rs1,
	output reg  [W_REGADDR-1:0] dx_rs2,
	output reg  [W_REGADDR-1:0] dx_rd,
	output reg  [W_ALUSRC-1:0]  dx_alusrc_a,
	output reg  [W_ALUSRC-1:0]  dx_alusrc_b,
	output reg  [W_ALUOP-1:0]   dx_aluop,
	output reg  [W_MEMOP-1:0]   dx_memop,
	output reg  [W_BCOND-1:0]   dx_branchcond,
	output reg                  dx_jump_is_regoffs,
	output reg  [W_ADDR-1:0]    dx_pc,
	output reg  [W_ADDR-1:0]    dx_mispredict_addr,
	output reg                  dx_except_invalid_instr
);


// TODO TODO factor this out in a cleaner way, e.g. separate out registers and stall logic.

`include "rv_opcodes.vh"
`include "hazard5_ops.vh"


wire d_starved = ~|fd_cir_vld || fd_cir_vld[0] && d_instr_is_32bit;
assign d_stall = x_stall ||
	d_starved || (d_jump_req && !f_jump_rdy);
assign df_cir_use =
	d_starved || d_stall ? 2'h0 :
	d_instr_is_32bit ? 2'h2 : 2'h1;

// Expand compressed instructions, and tell F how much instr data we are using

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

// Various D-local regs/wires
reg  [W_ADDR-1:0]    d_pc;
wire [W_ADDR-1:0]    d_pc_next = d_pc + (d_instr_is_32bit ? 32'h4 : 32'h2);

assign               d_rs1 = d_instr[19:15];
assign               d_rs2 = d_instr[24:20];
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
	// Branches are major opcode 1100011, JAL is 1100111:
	d_jump_target = d_pc + (d_instr[2] ? d_imm_j : d_imm_b);

	casez ({d_instr[31], d_instr})
	{1'b1, RV_BEQ }: d_jump_req = !d_starved;
	{1'b1, RV_BNE }: d_jump_req = !d_starved;
	{1'b1, RV_BLT }: d_jump_req = !d_starved;
	{1'b1, RV_BGE }: d_jump_req = !d_starved;
	{1'b1, RV_BLTU}: d_jump_req = !d_starved;
	{1'b1, RV_BGEU}: d_jump_req = !d_starved;
	{1'bz, RV_JAL }: d_jump_req = !d_starved;
	default: d_jump_req = 1'b0;
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
		dx_alusrc_a <= ALUSRCA_RS1;
		dx_alusrc_b <= ALUSRCB_RS2;
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
		RV_JALR:    begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_branchcond <= BCOND_ALWAYS; dx_alusrc_a <= ALUSRCA_LINKADDR; dx_rs2 <= {W_REGADDR{1'b0}}; dx_jump_is_regoffs <= 1'b1; end
		RV_JAL:     begin dx_aluop <= ALUOP_ADD; dx_alusrc_a <= ALUSRCA_LINKADDR; dx_rs1 <= {W_REGADDR{1'b0}}; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_LUI:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_u; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_rs1 <= {W_REGADDR{1'b0}}; end
		RV_AUIPC:   begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_u; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_alusrc_a <= ALUSRCA_PC;  dx_rs1 <= {W_REGADDR{1'b0}}; end
		RV_ADDI:    begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_SLLI:    begin dx_aluop <= ALUOP_SLL; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_SLTI:    begin dx_aluop <= ALUOP_LT;  dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_SLTIU:   begin dx_aluop <= ALUOP_LTU; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_XORI:    begin dx_aluop <= ALUOP_XOR; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_SRLI:    begin dx_aluop <= ALUOP_SRL; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_SRAI:    begin dx_aluop <= ALUOP_SRA; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_ORI:     begin dx_aluop <= ALUOP_OR;  dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
		RV_ANDI:    begin dx_aluop <= ALUOP_AND; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; end
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
		RV_LB:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_memop <= MEMOP_LB;  end
		RV_LH:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_memop <= MEMOP_LH;  end
		RV_LW:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_memop <= MEMOP_LW;  end
		RV_LBU:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_memop <= MEMOP_LBU; end
		RV_LHU:     begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_i; dx_alusrc_b <= ALUSRCB_IMM; dx_rs2 <= {W_REGADDR{1'b0}}; dx_memop <= MEMOP_LHU; end
		RV_SB:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_s; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_SB;  dx_rd <= {W_REGADDR{1'b0}}; end
		RV_SH:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_s; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_SH;  dx_rd <= {W_REGADDR{1'b0}}; end
		RV_SW:      begin dx_aluop <= ALUOP_ADD; dx_imm <= d_imm_s; dx_alusrc_b <= ALUSRCB_IMM; dx_memop <= MEMOP_SW;  dx_rd <= {W_REGADDR{1'b0}}; end
		RV_FENCE:   begin dx_rd <= {W_REGADDR{1'b0}}; end  // NOP
		RV_FENCE_I: begin dx_rd <= {W_REGADDR{1'b0}}; end  // NOP
		RV_SYSTEM:  begin if (!d_starved) $display("Syscall @ PC %h: %h", d_pc, d_instr); end
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

endmodule