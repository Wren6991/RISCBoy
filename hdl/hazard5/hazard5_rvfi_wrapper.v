module rvfi_wrapper (
	input wire clock,
	input wire reset,
	`RVFI_OUTPUTS
);

// ----------------------------------------------------------------------------
// Memory Interface
// ----------------------------------------------------------------------------

(* keep *) wire [31:0] haddr;
(* keep *) wire        hwrite;
(* keep *) wire [1:0]  htrans;
(* keep *) wire [2:0]  hsize;
(* keep *) wire [2:0]  hburst;
(* keep *) wire [3:0]  hprot;
(* keep *) wire        hmastlock;
(* keep *) wire        hready;
(* keep *) wire        hresp;
(* keep *) wire [31:0] hwdata;
(* keep *) wire [31:0] hrdata;

// AHB-lite requires: data phase of IDLE has no wait states
always @ (posedge clock)
	if ($past(htrans) == 2'b00 && $past(hready))
		assume(hready);

// Handling of bus faults is not tested
always assume(!hresp);

`ifdef MEMIO_FAIRNESS
always @ (posedge clock)
	assume(|{
		hready,
		$past(hready, 1),
		$past(hready, 2),
		$past(hready, 3),
		$past(hready, 4)
	});
`endif

// ----------------------------------------------------------------------------
// Device Under Test
// ----------------------------------------------------------------------------

hazard5_cpu #(
	.RESET_VECTOR(0),
	.EXTENSION_C(1)
) dut (
	.clk             (clock),
	.rst_n           (!reset),
	.ahblm_haddr     (haddr),
	.ahblm_hwrite    (hwrite),
	.ahblm_htrans    (htrans),
	.ahblm_hsize     (hsize),
	.ahblm_hburst    (hburst),
	.ahblm_hprot     (hprot),
	.ahblm_hmastlock (hmastlock),
	.ahblm_hready    (hready),
	.ahblm_hresp     (hresp),
	.ahblm_hwdata    (hwdata),
	.ahblm_hrdata    (hrdata)
);

// ----------------------------------------------------------------------------
// RVFI Instrumentation
// ----------------------------------------------------------------------------

// We consider instructions to "retire" as they cross the M/W pipe register.

// ----------------------------------------------------------------------------
// Instruction monitor

// Diagnose whether X, M contain valid in-flight instructions, to produce
// rvfi_valid signal.

reg x_valid, m_valid;
reg [31:0] x_instr;
reg [31:0] m_instr;

reg rvfi_valid_r;
reg [31:0] rvfi_insn_r;
reg rvfi_trap_r;

assign rvfi_valid = rvfi_valid_r;
assign rvfi_insn = rvfi_insn_r;
assign rvfi_trap = rvfi_trap_r;

always @ (posedge clock or posedge reset) begin
	if (reset) begin
		x_valid <= 1'b0;
		m_valid <= 1'b0;
		rvfi_valid_r <= 1'b0;
		rvfi_trap_r <= 1'b0;
		rvfi_insn_r <= 32'h0;
	end else begin
		if (!dut.x_stall) begin
			m_valid <= x_valid;
			m_instr <= x_instr;
			x_valid <= 1'b0;
		end
		if (dut.flush_d_x) begin
			x_valid <= 1'b0;
			m_valid <= m_valid && dut.m_stall;
		end else if (dut.df_cir_use) begin
			x_valid <= 1'b1;
			x_instr <= {
				dut.fd_cir[31:16] & {16{dut.df_cir_use[1]}},
				dut.fd_cir[15:0]
			};
		end
		rvfi_valid_r <= dut.m_valid && !dut.m_stall;
		rvfi_insn_r <= m_instr;
		rvfi_trap_r <=
			dut.xm_except_invalid_instr ||
			dut.xm_except_unaligned ||
			dut.m_except_bus_fault;
	end
end

// Hazard5 is an in-order core:
reg [63:0] retire_ctr;
assign rvfi_order = retire_ctr;
always @ (posedge clock or posedge reset)
	if (reset)
		retire_ctr <= 0;
	else if (rvfi_valid)
		retire_ctr <= retire_ctr + 1;

assign rvfi_mode = 2'h3; // M-mode only
assign rvfi_intr = 1'b0; // TODO

// ----------------------------------------------------------------------------
// PC and jump monitor

reg [31:0] xm_pc;
reg [31:0] xm_pc_next;

always @ (posedge clock or posedge reset) begin
	if (reset) begin
		xm_pc <= 0;
		xm_pc_next <= 0;
	end else begin
		xm_pc <= dut.dx_pc;
		// Will take early jump into account, but not mispredict or late jump:
		xm_pc_next <= dut.inst_hazard5_decode.pc;
	end
end

reg [31:0] rvfi_pc_rdata_r;
reg [31:0] rvfi_pc_wdata_r;

assign rvfi_pc_rdata = rvfi_pc_rdata_r;
assign rvfi_pc_wdata = rvfi_pc_wdata_r;

always @ (posedge clock) begin
	if (!dut.m_stall) begin
		rvfi_pc_rdata_r <= xm_pc;
		rvfi_pc_wdata_r <= dut.m_jump_req ? dut.m_jump_target : xm_pc_next;
	end
end

// ----------------------------------------------------------------------------
// Register file monitor:
assign rvfi_rd_addr = dut.mw_rd;
assign rvfi_rd_wdata = dut.mw_result;

// Do not reimplement internal bypassing logic. Danger of implementing
// it correctly here but incorrectly in core.

reg [31:0] xm_rdata1;

always @ (posedge clock or posedge reset)
	if (reset)
		xm_rdata1 <= 32'h0;
	else if (!dut.x_stall)
		xm_rdata1 <= dut.x_rs1_bypass;

reg [4:0]  rvfi_rs1_addr_r;
reg [4:0]  rvfi_rs2_addr_r;
reg [31:0] rvfi_rs1_rdata_r;
reg [31:0] rvfi_rs2_rdata_r;

assign rvfi_rs1_addr = rvfi_rs1_addr_r;
assign rvfi_rs2_addr = rvfi_rs2_addr_r;
assign rvfi_rs1_rdata = rvfi_rs1_rdata_r;
assign rvfi_rs2_rdata = rvfi_rs2_rdata_r;

always @ (posedge clock or posedge reset) begin
	if (reset) begin
		rvfi_rs1_addr_r <= 5'h0;
		rvfi_rs2_addr_r <= 5'h0;
		rvfi_rs1_rdata_r <= 32'h0;
		rvfi_rs2_rdata_r <= 32'h0;
	end else begin
		rvfi_rs1_addr_r <= dut.m_stall ? 5'h0 : dut.xm_rs1;
		rvfi_rs2_addr_r <= dut.m_stall ? 5'h0 : dut.xm_rs2;
		rvfi_rs1_rdata_r <= xm_rdata1;
		rvfi_rs2_rdata_r <= dut.m_wdata;
	end
end

// ----------------------------------------------------------------------------
// Load/store monitor: based on bus signals, NOT processor internals.
// Marshal up a description of the current data phase, and then register this
// into the RVFI signals.

`ifndef RISCV_FORMAL_ALIGNED_MEM
initial $fatal;
`endif

reg [31:0] haddr_dph;
reg        hwrite_dph;
reg [1:0]  htrans_dph;
reg [2:0]  hsize_dph;

always @ (posedge clock) begin
	if (hready) begin
		htrans_dph <= htrans & {2{dut.ahb_gnt_d}}; // Load/store only!
		haddr_dph <= haddr;
		hwrite_dph <= hwrite;
		hsize_dph <= hsize;
	end
end

wire [3:0] mem_bytemask_dph = (
	hsize_dph == 3'h0 ? 4'h1 :
	hsize_dph == 3'h1 ? 4'h3 :
	                    4'hf
	) << haddr_dph[1:0];

reg [31:0] rvfi_mem_addr_r;
reg [3:0]  rvfi_mem_rmask_r;
reg [31:0] rvfi_mem_rdata_r;
reg [3:0]  rvfi_mem_wmask_r;
reg [31:0] rvfi_mem_wdata_r;

assign rvfi_mem_addr = rvfi_mem_addr_r;
assign rvfi_mem_rmask = rvfi_mem_rmask_r;
assign rvfi_mem_rdata = rvfi_mem_rdata_r;
assign rvfi_mem_wmask = rvfi_mem_wmask_r;
assign rvfi_mem_wdata = rvfi_mem_wdata_r;

always @ (posedge clock) begin
	if (hready) begin
		// RVFI has an AXI-like concept of byte strobes, rather than AHB-like
		rvfi_mem_addr_r <= haddr_dph & 32'hffff_fffc;
		{rvfi_mem_rmask_r, rvfi_mem_wmask_r} <= 0;
		if (htrans_dph[1] && hwrite_dph) begin
			rvfi_mem_wmask_r <= mem_bytemask_dph;
			rvfi_mem_wdata_r <= hwdata;
		end else if (htrans_dph[1] && !hwrite_dph) begin
			rvfi_mem_rmask_r <= mem_bytemask_dph;
			rvfi_mem_rdata_r <= hrdata;
		end
	end else begin
		// As far as RVFI is concerned nothing happens except final cycle of dphase
		{rvfi_mem_rmask_r, rvfi_mem_wmask_r} <= 0;
	end
end

endmodule
