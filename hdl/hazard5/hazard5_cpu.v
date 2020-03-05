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
	parameter RESET_VECTOR    = 32'h0,// Address of first instruction executed
	parameter EXTENSION_C     = 1,    // Support for compressed (variable-width) instructions
	parameter EXTENSION_M     = 1,    // Support for hardware multiply/divide/modulo instructions
	parameter MULDIV_UNROLL   = 1,    // Bits per clock for multiply/divide circuit, if present. Pow2.

	parameter CSR_M_MANDATORY = 1,    // Bare minimum e.g. misa. Spec says must = 1, but I won't tell anyone
	parameter CSR_M_TRAP      = 1,    // Include M-mode trap-handling CSRs
	parameter CSR_COUNTER     = 0,    // Include performance counters and relevant M-mode CSRs
	parameter MTVEC_WMASK     = 32'hfffff000,
	                                  // Save gates by making trap vector base partly fixed (legal, as it's WARL).
	                                  // Note the entire vector table must always be aligned to its size, rounded
	                                  // up to a power of two, so careful with the low-order bits.
	parameter MTVEC_INIT      = 32'h00000000,
	                                  // Initial value of trap vector base. Bits clear in MTVEC_WMASK will
	                                  // never change from this initial value. Bits set in MTVEC_WMASK can
	                                  // be written/set/cleared as normal.

	parameter W_ADDR          = 32,   // Do not modify
	parameter W_DATA          = 32    // Do not modify
) (
	// Global signals
	input wire               clk,
	input wire               rst_n,

	`ifdef RISCV_FORMAL
	`RVFI_OUTPUTS ,
	`endif

	// AHB-lite Master port
	output reg  [W_ADDR-1:0] ahblm_haddr,
	output reg               ahblm_hwrite,
	output reg  [1:0]        ahblm_htrans,
	output reg  [2:0]        ahblm_hsize,
	output wire [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	input  wire              ahblm_hready,
	input  wire              ahblm_hresp,
	output reg  [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata,

	// External level-sensitive interrupt sources (tie 0 if unused)
	input wire [15:0]        irq
);

`include "hazard5_ops.vh"

`ifdef FORMAL
// Only yosys-smtbmc seems to support immediate assertions
`ifdef RISCV_FORMAL
`define ASSERT(x)
`else
`define ASSERT(x) assert(x)
`endif
`else
`define ASSERT(x)
//synthesis translate_off
`undef ASSERT
`define ASSERT(x) if (!x) begin $display("Assertion failed!"); $finish(1); end
//synthesis translate_on
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

reg       bus_hold_aph;
reg [1:0] ahb_gnt_id_prev;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		bus_hold_aph <= 1'b0;
		ahb_gnt_id_prev <= 2'h0;
	end else begin
		bus_hold_aph <= ahblm_htrans[1] && !ahblm_hready;
		ahb_gnt_id_prev <= {ahb_gnt_i, ahb_gnt_d};
	end
end

assign {ahb_gnt_i, ahb_gnt_d} =
	bus_hold_aph ? ahb_gnt_id_prev :
	m_jump_req   ? 2'b10 :
	ahb_req_d    ? 2'b01 :
	ahb_req_i    ? 2'b10 :
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
wire              d_jump_req;
wire [W_ADDR-1:0] d_jump_target;

wire              f_jump_req = d_jump_req || m_jump_req;
wire [W_ADDR-1:0] f_jump_target = m_jump_req ? m_jump_target : d_jump_target;
wire              f_jump_rdy;
wire              f_jump_now = f_jump_req && f_jump_rdy;

wire [31:0] fd_cir;
wire [1:0]  fd_cir_vld;
wire [1:0]  df_cir_use;
wire        df_cir_lock;

wire f_mem_size;
assign ahb_hsize_i = f_mem_size ? HSIZE_WORD : HSIZE_HWORD;

hazard5_frontend #(
	.EXTENSION_C(EXTENSION_C),
	.W_ADDR(W_ADDR),
	.W_DATA(32),
	.FIFO_DEPTH(2),
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
	.cir_use         (df_cir_use),
	.cir_lock        (df_cir_lock)
);

assign flush_d_x = m_jump_req && f_jump_rdy;

// ============================================================================
//                               Pipe Stage D
// ============================================================================

// X-check on pieces of instruction which frontend claims are valid
//synthesis translate_off
always @ (posedge clk) begin
	if (rst_n) begin
		if (|fd_cir_vld && (^fd_cir[15:0] === 1'bx)) begin
			$display("CIR LSBs are X, should be valid!");
			$finish;
		end
		if (fd_cir_vld[1] && (^fd_cir === 1'bX)) begin
			$display("CIR contains X, should be fully valid!");
			$finish;
		end
	end
end
//synthesis translate_on

wire [W_ADDR-1:0]    d_pc; // FIXME only used for riscv-formal

// To register file
wire [W_REGADDR-1:0] d_rs1;
wire [W_REGADDR-1:0] d_rs2;

// To X
wire [W_DATA-1:0]    dx_imm;
wire [W_REGADDR-1:0] dx_rs1;
wire [W_REGADDR-1:0] dx_rs2;
wire [W_REGADDR-1:0] dx_rd;
wire [W_ALUSRC-1:0]  dx_alusrc_a;
wire [W_ALUSRC-1:0]  dx_alusrc_b;
wire [W_ALUOP-1:0]   dx_aluop;
wire [W_MEMOP-1:0]   dx_memop;
wire [W_MULOP-1:0]   dx_mulop;
wire [W_BCOND-1:0]   dx_branchcond;
wire [W_ADDR-1:0]    dx_jump_target;
wire                 dx_jump_is_regoffs;
wire                 dx_result_is_linkaddr;
wire [W_ADDR-1:0]    dx_pc;
wire [W_ADDR-1:0]    dx_mispredict_addr;
wire [W_EXCEPT-1:0]  dx_except;
wire                 dx_csr_ren;
wire                 dx_csr_wen;
wire [1:0]           dx_csr_wtype;
wire                 dx_csr_w_imm;

hazard5_decode #(
	.EXTENSION_C  (EXTENSION_C),
	.EXTENSION_M  (EXTENSION_M),
	.HAVE_CSR     (CSR_M_MANDATORY || CSR_M_TRAP || CSR_COUNTER),
	.W_ADDR       (W_ADDR),
	.W_DATA       (W_DATA),
	.RESET_VECTOR (RESET_VECTOR),
	.W_REGADDR    (W_REGADDR)
) inst_hazard5_decode (
	.clk                   (clk),
	.rst_n                 (rst_n),

	.fd_cir                (fd_cir),
	.fd_cir_vld            (fd_cir_vld),
	.df_cir_use            (df_cir_use),
	.df_cir_lock           (df_cir_lock),
	.d_jump_req            (d_jump_req),
	.d_jump_target         (d_jump_target),
	.d_pc                  (d_pc),

	.d_stall               (d_stall),
	.x_stall               (x_stall),
	.flush_d_x             (flush_d_x),
	.f_jump_rdy            (f_jump_rdy),
	.f_jump_now            (f_jump_now),
	.f_jump_target         (f_jump_target),

	.d_rs1                 (d_rs1),
	.d_rs2                 (d_rs2),
	.dx_imm                (dx_imm),
	.dx_rs1                (dx_rs1),
	.dx_rs2                (dx_rs2),
	.dx_rd                 (dx_rd),
	.dx_alusrc_a           (dx_alusrc_a),
	.dx_alusrc_b           (dx_alusrc_b),
	.dx_aluop              (dx_aluop),
	.dx_memop              (dx_memop),
	.dx_mulop              (dx_mulop),
	.dx_csr_ren            (dx_csr_ren),
	.dx_csr_wen            (dx_csr_wen),
	.dx_csr_wtype          (dx_csr_wtype),
	.dx_csr_w_imm          (dx_csr_w_imm),
	.dx_branchcond         (dx_branchcond),
	.dx_jump_target        (dx_jump_target),
	.dx_jump_is_regoffs    (dx_jump_is_regoffs),
	.dx_result_is_linkaddr (dx_result_is_linkaddr),
	.dx_pc                 (dx_pc),
	.dx_mispredict_addr    (dx_mispredict_addr),
	.dx_except             (dx_except)
);

// ============================================================================
//                               Pipe Stage X
// ============================================================================

// Register the write which took place to the regfile on previous cycle, and bypass.
// This is an alternative to a write -> read bypass in the regfile,
// which we can't implement whilst maintaining BRAM inference compatibility (iCE40).
reg  [W_REGADDR-1:0] mw_rd;
reg  [W_DATA-1:0]    mw_result;

// From register file:
wire [W_DATA-1:0]    dx_rdata1;
wire [W_DATA-1:0]    dx_rdata2;

// Combinational regs for muxing
reg   [W_DATA-1:0]   x_rs1_bypass;
reg   [W_DATA-1:0]   x_rs2_bypass;
reg   [W_DATA-1:0]   x_op_a;
reg   [W_DATA-1:0]   x_op_b;
wire  [W_DATA-1:0]   x_alu_result;
wire  [W_DATA-1:0]   x_alu_add;
wire                 x_alu_cmp;

wire [W_DATA-1:0]    x_trap_addr;
wire [W_DATA-1:0]    x_mepc;
wire                 x_trap_enter;
wire                 x_trap_exit;

reg  [W_REGADDR-1:0] xm_rs1;
reg  [W_REGADDR-1:0] xm_rs2;
reg  [W_REGADDR-1:0] xm_rd;
reg  [W_DATA-1:0]    xm_result;
reg  [W_ADDR-1:0]    xm_jump_target;
reg  [W_DATA-1:0]    xm_store_data;
reg                  xm_jump;
reg  [W_MEMOP-1:0]   xm_memop;

// For JALR, the LSB of the result must be cleared by hardware
wire [W_ADDR-1:0] x_taken_jump_target = dx_jump_is_regoffs ? x_alu_add & ~32'h1 : dx_jump_target;
wire [W_ADDR-1:0] x_jump_target =
	x_trap_exit                                 ? x_mepc             : // Note precedence -- it's possible to have enter && exit, but in this case enter_rdy is false.
	x_trap_enter                                ? x_trap_addr        :
	dx_imm[31] && dx_branchcond != BCOND_ALWAYS ? dx_mispredict_addr :
	                                              x_taken_jump_target;

reg x_stall_raw;
wire x_stall_muldiv;

assign x_stall = m_stall ||
	x_stall_raw || x_stall_muldiv || ahb_req_d && !(ahb_gnt_d && ahblm_hready);

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

wire x_memop_vld = !dx_memop[3];
wire x_memop_write = dx_memop == MEMOP_SW || dx_memop == MEMOP_SH || dx_memop == MEMOP_SB;
wire x_unaligned_addr =
	ahb_hsize_d == HSIZE_WORD && |ahb_haddr_d[1:0] ||
	ahb_hsize_d == HSIZE_HWORD && ahb_haddr_d[0];

wire x_except_load_misaligned = x_memop_vld && x_unaligned_addr && !x_memop_write;
wire x_except_store_misaligned = x_memop_vld && x_unaligned_addr && x_memop_write;

always @ (*) begin
	// Need to be careful not to use anything hready-sourced to gate htrans!
	ahb_haddr_d = x_alu_add;
	ahb_hwrite_d = x_memop_write;
	case (dx_memop)
		MEMOP_LW:  ahb_hsize_d = HSIZE_WORD;
		MEMOP_SW:  ahb_hsize_d = HSIZE_WORD;
		MEMOP_LH:  ahb_hsize_d = HSIZE_HWORD;
		MEMOP_LHU: ahb_hsize_d = HSIZE_HWORD;
		MEMOP_SH:  ahb_hsize_d = HSIZE_HWORD;
		default:   ahb_hsize_d = HSIZE_BYTE;
	endcase
	ahb_req_d = x_memop_vld && !(x_stall_raw || flush_d_x || x_trap_enter);
end

// ALU operand muxes and bypass
always @ (*) begin
	if (~|dx_rs1) begin
		x_rs1_bypass = {W_DATA{1'b0}};
	end else if (xm_rd == dx_rs1) begin
		x_rs1_bypass = xm_result;
	end else if (mw_rd == dx_rs1) begin
		x_rs1_bypass = mw_result;
	end else begin
		x_rs1_bypass = dx_rdata1;
	end
	if (~|dx_rs2) begin
		x_rs2_bypass = {W_DATA{1'b0}};
	end else if (xm_rd == dx_rs2) begin
		x_rs2_bypass = xm_result;
	end else if (mw_rd == dx_rs2) begin
		x_rs2_bypass = mw_result;
	end else begin
		x_rs2_bypass = dx_rdata2;
	end

	if (dx_alusrc_a)
		x_op_a = dx_pc;
	else
		x_op_a = x_rs1_bypass;

	if (dx_alusrc_b)
		x_op_b = dx_imm;
	else
		x_op_b = x_rs2_bypass;
end

// CSRs and Trap Handling

wire   x_except_ecall         = dx_except == EXCEPT_ECALL;
wire   x_except_breakpoint    = dx_except == EXCEPT_EBREAK;
wire   x_except_invalid_instr = dx_except == EXCEPT_INSTR_ILLEGAL;
assign x_trap_exit            = dx_except == EXCEPT_MRET && !(x_stall || m_jump_req);
wire   x_trap_enter_rdy       = !(x_stall || m_jump_req || x_trap_exit);
wire   x_trap_is_exception; // diagnostic

`ifdef FORMAL
always @ (posedge clk) begin
	if (flush_d_x)
		assert(!x_trap_enter_rdy);
	if (x_trap_exit)
		assert(!ahb_req_d);
end
`endif

wire [W_DATA-1:0] x_csr_wdata = dx_csr_w_imm ?
	{{W_DATA-5{1'b0}}, dx_rs1} : x_rs1_bypass;

wire [W_DATA-1:0] x_csr_rdata;

hazard5_csr #(
	.XLEN            (W_DATA),
	.CSR_M_MANDATORY (CSR_M_MANDATORY),
	.CSR_M_TRAP      (CSR_M_TRAP),
	.CSR_COUNTER     (CSR_COUNTER),
	.EXTENSION_C     (EXTENSION_C),
	.EXTENSION_M     (EXTENSION_M),
	.MTVEC_WMASK     (MTVEC_WMASK),
	.MTVEC_INIT      (MTVEC_INIT)
) inst_hazard5_csr (
	.clk                     (clk),
	.rst_n                   (rst_n),
	// CSR access port
	// *en_soon are early access strobes which are not a function of bus stall.
	// Can generate access faults (hence traps), but do not actually perform access.
	.addr                    (dx_imm[11:0]),
	.wdata                   (x_csr_wdata),
	.wen_soon                (dx_csr_wen),
	.wen                     (dx_csr_wen && !(x_stall || flush_d_x)),
	.wtype                   (dx_csr_wtype),
	.rdata                   (x_csr_rdata),
	.ren_soon                (dx_csr_ren),
	.ren                     (dx_csr_ren && !(x_stall || flush_d_x)),
	// Trap signalling
	.trap_addr               (x_trap_addr),
	.trap_enter_vld          (x_trap_enter),
	.trap_enter_rdy          (x_trap_enter_rdy),
	.trap_exit               (x_trap_exit),
	.trap_is_exception       (x_trap_is_exception),
	.mepc_in                 (dx_pc),
	.mepc_out                (x_mepc),
	// IRQ and exception requests
	.irq                     (irq),
	.except_instr_misaligned (1'b0), // TODO
	.except_instr_fault      (1'b0), // TODO
	.except_instr_invalid    (x_except_invalid_instr),
	.except_breakpoint       (x_except_breakpoint),
	.except_load_misaligned  (x_except_load_misaligned),
	.except_load_fault       (1'b0), // TODO
	.except_store_misaligned (x_except_store_misaligned),
	.except_store_fault      (1'b0), // TODO
	.except_ecall            (x_except_ecall),
	// Other CSR-specific signalling
	.instr_ret               (1'b0)  // TODO
);

// Multiply/divide

wire [W_DATA-1:0] x_muldiv_result;

generate
if (EXTENSION_M) begin: has_muldiv
	wire              x_muldiv_op_vld;
	wire              x_muldiv_op_rdy;
	wire              x_muldiv_result_vld;
	wire [W_DATA-1:0] x_muldiv_result_h;
	wire [W_DATA-1:0] x_muldiv_result_l;

	reg x_muldiv_posted;
	always @ (posedge clk or negedge rst_n)
		if (!rst_n)
			x_muldiv_posted <= 1'b0;
		else
			x_muldiv_posted <= (x_muldiv_posted || (x_muldiv_op_vld && x_muldiv_op_rdy)) && x_stall;

	wire x_muldiv_kill = flush_d_x || x_trap_enter; // TODO this takes an extra cycle to kill muldiv before trap entry
	assign x_muldiv_op_vld = dx_aluop == ALUOP_MULDIV && !x_muldiv_posted
		&& !x_stall_raw && !x_muldiv_kill;

	hazard5_muldiv_seq #(
		.XLEN   (W_DATA),
		.UNROLL (MULDIV_UNROLL)
	) muldiv (
		.clk        (clk),
		.rst_n      (rst_n),
		.op         (dx_mulop),
		.op_vld     (x_muldiv_op_vld),
		.op_rdy     (x_muldiv_op_rdy),
		.op_kill    (x_muldiv_kill),
		.op_a       (x_rs1_bypass),
		.op_b       (x_rs2_bypass),

		.result_h   (x_muldiv_result_h),
		.result_l   (x_muldiv_result_l),
		.result_vld (x_muldiv_result_vld)
	);

	// TODO fusion of MULHx->MUL and DIVy->REMy sequences
	wire x_muldiv_result_is_high =
		dx_mulop == M_OP_MULH ||
		dx_mulop == M_OP_MULHSU ||
		dx_mulop == M_OP_MULHU ||
		dx_mulop == M_OP_REM ||
		dx_mulop == M_OP_REMU;
	assign x_muldiv_result = x_muldiv_result_is_high ? x_muldiv_result_h : x_muldiv_result_l;
	assign x_stall_muldiv = x_muldiv_op_vld || !x_muldiv_result_vld;

`ifdef FORMAL
	always @ (posedge clk) if (dx_aluop != ALUOP_MULDIV) assert(!x_stall_muldiv);
`endif

end else begin: no_muldiv

	assign x_muldiv_result = {W_DATA{1'b0}};
	assign x_muldiv_result_vld = 1'b1;

	assign x_stall_muldiv = 1'b0;

end
endgenerate

// State machine and branch detection
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		xm_jump <= 1'b0;
		xm_memop <= MEMOP_NONE;
		{xm_rs1, xm_rs2, xm_rd} <= {3 * W_REGADDR{1'b0}};
	end else begin
		// TODO: this assertion may become untrue depending on how we handle exceptions/IRQs when stalled?
		//`ASSERT(!(m_stall && flush_d_x));// bubble insertion logic below is broken otherwise
		if (!m_stall) begin
			{xm_rs1, xm_rs2, xm_rd} <= {dx_rs1, dx_rs2, dx_rd};
			// If the transfer is unaligned, make sure it is completely NOP'd on the bus
			xm_memop <= dx_memop | {x_unaligned_addr, 3'h0};
			if (x_stall || flush_d_x || x_trap_enter) begin
				// Insert bubble
				xm_rd <= {W_REGADDR{1'b0}};
				xm_jump <= 1'b0;
				xm_memop <= MEMOP_NONE;
			end
			if (!(x_stall || flush_d_x)) begin
				case (dx_branchcond)
					BCOND_ALWAYS: xm_jump <= 1'b1;
					// For branches, we are either taking a branch late, or recovering from
					// an incorrectly taken branch, depending on sign of branch offset.
					BCOND_ZERO: xm_jump <= !x_alu_cmp ^ dx_imm[31];
					BCOND_NZERO: xm_jump <= x_alu_cmp ^ dx_imm[31];
					default xm_jump <= 1'b0;
				endcase
				if (x_trap_enter || x_trap_exit)
					xm_jump <= 1'b1;
			end
		end
	end
end

// No reset on datapath flops
always @ (posedge clk)
	if (!m_stall) begin
		xm_result <=
			dx_result_is_linkaddr                   ? dx_mispredict_addr :
			dx_csr_ren                              ? x_csr_rdata :
			EXTENSION_M && dx_aluop == ALUOP_MULDIV ? x_muldiv_result :
			                                          x_alu_result;
		xm_store_data <= x_rs2_bypass;
		xm_jump_target <= x_jump_target;
	end

hazard5_alu alu (
	.aluop      (dx_aluop),
	.op_a       (x_op_a),
	.op_b       (x_op_b),
	.result     (x_alu_result),
	.result_add (x_alu_add),
	.cmp        (x_alu_cmp)
);

// ============================================================================
//                               Pipe Stage M
// ============================================================================

reg [W_DATA-1:0] m_rdata_shift;
reg [W_DATA-1:0] m_wdata;
reg [W_DATA-1:0] m_result;
assign m_jump_req = xm_jump;
assign m_jump_target = xm_jump_target;

assign m_stall = (ahb_active_dph_d && !ahblm_hready) || (m_jump_req && !f_jump_rdy);

wire m_except_bus_fault = ahblm_hresp; // TODO: handle differently for LSU/ifetch?

always @ (*) begin
	// Local forwarding of store data
	if (|mw_rd && xm_rs2 == mw_rd) begin
		m_wdata = mw_result;
	end else begin
		m_wdata = xm_store_data;
	end
	// Replicate store data to ensure appropriate byte lane is driven
	case (xm_memop)
		MEMOP_SW: ahblm_hwdata = m_wdata;
		MEMOP_SH: ahblm_hwdata = {2{m_wdata[15:0]}};
		MEMOP_SB: ahblm_hwdata = {4{m_wdata[7:0]}};
		default:  ahblm_hwdata = 32'h0;
	endcase
	// Pick out correct data from load access, and sign/unsign extend it.
	// This is slightly cheaper than a normal shift:
	case (xm_result[1:0])
		2'b00: m_rdata_shift = ahblm_hrdata;
		2'b01: m_rdata_shift = {ahblm_hrdata[31:8],  ahblm_hrdata[15:8]};
		2'b10: m_rdata_shift = {ahblm_hrdata[31:16], ahblm_hrdata[31:16]};
		2'b11: m_rdata_shift = {ahblm_hrdata[31:8],  ahblm_hrdata[31:24]};
	endcase

	case (xm_memop)
		MEMOP_LW:  m_result = m_rdata_shift;
		MEMOP_LH:  m_result = {{16{m_rdata_shift[15]}}, m_rdata_shift[15:0]};
		MEMOP_LHU: m_result = {16'h0, m_rdata_shift[15:0]};
		MEMOP_LB:  m_result = {{24{m_rdata_shift[7]}}, m_rdata_shift[7:0]};
		MEMOP_LBU: m_result = {24'h0, m_rdata_shift[7:0]};
		default:   m_result = xm_result;
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mw_rd <= {W_REGADDR{1'b0}};
	end else if (!m_stall) begin
		//synthesis translate_off
		// TODO: proper exception support
		if (m_except_bus_fault) begin
			$display("Bus fault!");
			$finish;
		end
		if (^ahblm_hwdata === 1'bX) begin
			$display("Writing Xs to memory!");
			$finish;
		end
		//synthesis translate_on
		mw_rd <= xm_rd;
	end
end

// No need to reset result register, as reset on mw_rd protects register file from it
always @ (posedge clk)
	if (!m_stall)
		mw_result <= m_result;

// ============================================================================
//                               Pipe Stage W
// ============================================================================

// mw_result and mw_rd register the most recent write to the register file,
// so that X can bypass them in.

wire w_reg_wen = |xm_rd && !m_stall;

//synthesis translate_off
always @ (posedge clk) begin
	if (rst_n) begin
		if (w_reg_wen && (^m_result === 1'bX)) begin
			$display("Writing X to register file!");
			$finish;
		end
	end
end
//synthesis translate_on

hazard5_regfile_1w2r #(
	.FAKE_DUALPORT(0),
`ifdef SIM
	.RESET_REGS(1),
`elsif FORMAL
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

	.waddr  (xm_rd),
	.wdata  (m_result),
	.wen    (w_reg_wen)
);

`ifdef RISCV_FORMAL
`include "hazard5_rvfi_monitor.vh"
`endif

`ifdef HAZARD5_FORMAL_REGRESSION
// Each formal regression provides its own file with the below name:
`include "hazard5_formal_regression.vh"
`endif

endmodule
