// ----------------------------------------------------------------------------
// Test intent: assert that, if D contains an instruction,
// memory[PC] == CIR.
// ----------------------------------------------------------------------------

localparam IMEM_SIZE_BYTES = 32;

// First set some ground rules for bus port

// AHB-lite requires: data phase of IDLE has no wait states
always @ (posedge clk)
	if ($past(ahblm_htrans) == 2'b00 && $past(ahblm_hready))
		assume(ahblm_hready);

// Handling of bus faults is not tested
always assume(!hresp);

// Shouldn't need fairness constrain; prover should be able to
// work out for itself that 100% stall is uninteresting, as CIR will
// never become valid.

// ----------------------------------------------------------------------------
// Instruction Memory Model
// ----------------------------------------------------------------------------

reg [15:0] imem [0:IMEM_SIZE_BYTES/2-1];

always @ (*) begin: constrain_mem
	integer i;
	for (i = 0; i < IMEM_SIZE_BYTES / 2; i = i + 1)
		assume(imem[i] == $anyconst);
end

reg [31:0] haddr_dph;

always @ (posedge clk)
	if (ahblm_hready)
		haddr_dph <= ahblm_haddr;

always assume(ahblm_hrdata == {
	imem[{haddr_dph[2 +: $clog2(IMEM_SIZE_BYTES / 4)], 1'b1}],
	imem[{haddr_dph[2 +: $clog2(IMEM_SIZE_BYTES / 4)], 1'b0}]
});

// ----------------------------------------------------------------------------
// Consistency Check
// ----------------------------------------------------------------------------
// CIR should match memory at the location indicated by PC

always assume(d_pc <= IMEM_SIZE_BYTES - 4);

(* keep *) wire [31:0] cir_expected = {
	imem[d_pc[1 +: $clog2(IMEM_SIZE_BYTES / 2)] + 1'b1],
	imem[d_pc[1 +: $clog2(IMEM_SIZE_BYTES / 2)]]
};

always @ (posedge clk) if (rst_n) begin
	if (fd_cir_vld >= 2'h1)
		assert(fd_cir[15:0] == cir_expected[15:0]);
	if (fd_cir_vld >= 2'h2)
		assert(fd_cir[31:16] == cir_expected[31:16]);
end

// Other helpful assertions
// Not part of what we are checking, but potentially help the induction proof
always @ (posedge clk) if (rst_n) begin
	assert(fd_cir_vld == 0 || fd_cir_vld == 1 || fd_cir_vld == 2);
	// This one is actually a required AHB-lite property
	if (!$past(ahblm_hready) && $past(rst_n) && $past(ahblm_htrans) == 2'b10) begin
		assert($stable(ahblm_haddr));
		assert($stable(ahblm_hwrite));
		assert($stable(ahblm_htrans));
		assert($stable(ahblm_hsize));
	end
	// Likewise, natural alignment of transfers is required in AHB-lite
	assert(!(ahblm_haddr & ~({32{1'b1}} << ahblm_hsize)));
	// During induction I have seen a non-halfword aligned jump on the jump request bus
	if (f_jump_req)
		assert(!f_jump_target[0]);
	// Data must come from somewhere!
	if ($past(fd_cir_vld) == 0)
		assert(fd_cir_vld == 0 || $past(ahblm_hready));
end
