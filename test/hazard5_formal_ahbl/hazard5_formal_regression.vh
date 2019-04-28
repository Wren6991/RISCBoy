// ----------------------------------------------------------------------------
// Test intent: assert that software cannot cause the processor
// to disobey AHB-lite specification (AMBA 3.0 AHB-lite)
// ----------------------------------------------------------------------------

localparam IMEM_SIZE_BYTES = 32;

// First set some ground rules for bus responses

// AHB-lite requires: data phase of IDLE has no wait states
always @ (posedge clk)
	if ($past(ahblm_htrans) == 2'b00 && $past(ahblm_hready))
		assume(ahblm_hready);

// Handling of bus faults is not tested
always assume(!hresp);

// Struggle with induction without a fairness constraint.
// TODO: the issue is that the prover will initialise prefetch FIFO to be
// full of garbage and then stall processor until just before end of test,
// releasing its own garbage.
// Fairness ensures prefetch FIFO clears out during assumption portion of induction.

// always @ (posedge clk) assume(ahblm_hready || $past(ahblm_hready));

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

always assume(d_pc <= IMEM_SIZE_BYTES - 4);
always assume(ahblm_hrdata == {
	imem[{haddr_dph[2 +: $clog2(IMEM_SIZE_BYTES / 4)], 1'b1}],
	imem[{haddr_dph[2 +: $clog2(IMEM_SIZE_BYTES / 4)], 1'b0}]
});

always assume(!dx_except_invalid_instr); // SHOULD REMOVE, it just gives slightly nicer disassemblies

// ----------------------------------------------------------------------------
// Consistency Check
// ----------------------------------------------------------------------------

// Couple of useful state variables
reg write_dph;
reg read_dph;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		write_dph <= 1'b0;
		read_dph <= 1'b0;
	end else if (ahblm_hready) begin
		if (ahblm_htrans[1]) begin
			write_dph <= ahblm_hwrite;
			read_dph <= !ahblm_hwrite;
		end else begin
			write_dph <= 1'b0;
			read_dph <= 1'b0;
		end
	end
end

// Actual bus properties
always @ (posedge clk) if (rst_n) begin
	// 3.6.1 and 3.6.2: no change to an active aphase request
	if ($past(rst_n && !ahblm_hready && ahblm_htrans[1])) begin
		assert($stable(ahblm_haddr));
		assert($stable(ahblm_hwrite));
		assert($stable(ahblm_htrans));
		assert($stable(ahblm_hsize));
	end
	// Natural alignment of transfers is required in AHB-lite
	assert(!(ahbl_htrans[1] && ahblm_haddr & ~({32{1'b1}} << ahblm_hsize)));
	// We are a 32-bit master
	assert(ahblm_hsize <= 2);
	// hwdata must be stable during write data phase
	if (write_dph && !$past(ahblm_hready))
		assert($stable(ahblm_hwdata));
	// We don't do bursted transfers
	assert(ahblm_htrans == 2'b10 || ahblm_htrans == 2'b00);
end
