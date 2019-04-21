module rvfi_wrapper (
	input wire clock,
	input wire reset,
	`RVFI_OUTPUTS
);

// ----------------------------------------------------------------------------
// Memory interface
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
	assume(
		hready ||
		$past(hready, 1) ||
		$past(hready, 2) ||
		$past(hready, 3) ||
		$past(hready, 4)
	);
`endif

// ----------------------------------------------------------------------------
// Device under test
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
// RVFI instrumentation
// ----------------------------------------------------------------------------

// One mismatch between Hazard5 and RVFI is it does not have a concept of
// whether a given pipestage contains a valid instruction; upon flush
// it tries to change the minimum amount of pipeline state to suppress side-
// effects (since this reduces control-path fanout).
//
// This means we need to attach significant state modelling to diagnose exactly
// what the core is up to and document it in a way that RVFI understands.
//
// We consider instructions to "retire" as they cross the M/W pipe register.

// Hazard5 is an in-order core:
reg [63:0] retire_ctr;
assign rvfi_order = retire_ctr;
always @ (posedge clock or posedge reset)
	if (reset)
		retire_ctr <= 0;
	else if (rvfi_valid)
		retire_ctr <= retire_ctr + 1;


// Register file monitor:
assign rvfi_rd_addr = dut.mw_rd;
assign rvfi_rd_wdata = dut.mw_result;

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

always @ (posedge clk) begin
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

always @ (posedge clk) begin
	if (hready) begin
		// RVFI has an AXI-like concept of byte strobes, rather than AHB-like
		rvfi_mem_addr <= haddr_dph & 32'hffff_fffc;
		{rvfi_mem_rmask, rvfi_mem_wmask} <= 0;
		if (htrans_dph[1] && hwrite_dph) begin
			rvfi_mem_wmask <= mem_bytemask_dph;
			rvfi_mem_wdata <= hwdata;
		end else if (htrans_dph[1] && !hwrite_dph) begin
			rvfi_mem_rmask <= mem_bytemask_dph;
			rvfi_mem_rmask <= hrdata;
		end
	end else begin
		// As far as RVFI is concerned nothing happens except final cycle of dphase
		{rvfi_mem_rmask, rvfi_mem_wmask} <= 0;
	end
end

endmodule
