module revive_frontend #(
	parameter W_ADDR = 32,
	parameter W_DATA = 32,
	parameter FIFO_DEPTH = 4
) (
	input wire clk,
	input wire rst_n,

	// Fetch interface
	// No backpressure on either direction.
	// mem_addr is valid only for a single cycle. User must buffer if there is a stall.
	// Likewise the frontend always captures received data, because we guarantee space in the FIFO.
	output wire [W_ADDR-1:0] mem_addr,
	output wire              mem_addr_vld,
	input wire  [W_DATA-1:0] mem_data,
	input wire               mem_data_vld,
	// We don't increment pending count if this is high.
	// This means an external pending buffer is occupied, and will be safely overwritten.
	input wire               mem_req_replaces_last,

	// Jump/flush interface
	// Processor must not assert vld whilst a flush is currently in progress!
	// (i.e. not until first fresh data comes back after flush)
	input wire  [W_ADDR-1:0] jump_target,
	input wire               jump_target_vld,

	// Interface to Decode
	// Note reg/wire distinction
	// => decode is providing live feedback on the CIR it is decoding,
	//    which we fetched previously
	output reg  [31:0]       cir,
	output reg  [1:0]        cir_vld, // this is a mask, not a count
	input wire  [1:0]        cir_rdy  // likewise
);


`ifdef FORMAL
`define ASSERT(x) assert(x)
`else
`define ASSERT(x)
`endif

//synthesis translate_off
initial if (W_DATA != 32) begin $display("Frontend requires 32-bit databus"); $finish; end
initial if ((1 << $clog2(FIFO_DEPTH)) != FIFO_DEPTH) begin $display("Frontend FIFO depth must be power of 2"); $finish; end
//synthesis translate_on

localparam W_BUNDLE = W_DATA / 2;
localparam W_FIFO_PTR = $clog2(FIFO_DEPTH + 1)

// ----------------------------------------------------------------------------
// Fetch Queue (FIFO)
// This is a little different from either a normal sync fifo or sync fwft fifo
// so it's worth implementing from scratch

reg [W_DATA-1:0] fifo_mem [0:FIFO_DEPTH-1];
reg [W_FIFO_PTR-1:0] fifo_wptr;
reg [W_FIFO_PTR-1:0] fifo_rptr;

wire [W_FIFO_PTR-1:0] fifo_level = fifo_rptr - fifo_wptr;
wire fifo_full = fifo_wptr ^ fifo_rptr == {1'b1, {W_FIFO_PTR-1{1'b0}}};
wire fifo_empty = fifo_wptr == fifo_rptr;
wire fifo_almost_full = fifo_level == FIFO_DEPTH - 1;

wire fifo_push;
wire fifo_pop;
wire [W_DATA-1:0] fifo_wdata;
wire [W_DATA-1:0] fifo_rdata;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		fifo_wptr <= {W_FIFO_PTR{1'b0}};
		fifo_rptr <= {W_FIFO_PTR{1'b0}};
	end else begin
		`ASSERT(!(fifo_pop && fifo_empty));
		`ASSERT(!(fifo_push && fifo_full));
		if (fifo_push) begin
			fifo_wptr <= fifo_wptr + 1'b1;
			fifo_mem[fifo_wptr] <= fifo_wdata;
		end
		if (jump_target_vld) begin
			fifo_rptr <= fifo_wptr;
		end else if (fifo_pop) begin
			fifo_rptr <= fifo_rptr + 1'b1;
		end
	end
end

assign fifo_rdata = fifo_mem[fifo_rptr];

// ----------------------------------------------------------------------------
// Fetch logic

reg [W_ADDR-1:0] fetch_addr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		fetch_addr <= {W_ADDR{1'b0}}; // TODO: reset vectoring
	end else begin
		if (jump_target_vld) begin
			fetch_addr <= {jump_target[W_ADDR-1:2], 2'b00} + 3'h4;
		end else if (mem_addr_vld) begin
			fetch_addr <= fetch_addr + 3'h4;
		end
	end
end

// At most, one active aph, one active dph, one buffered aph
reg [1:0] pending_fetches;
reg [1:0] pending_flush_ctr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pending_fetches <= 2'h0;
		pending_flush_ctr <= 2'h0;
	end else begin
		`ASSERT(pending_flush_ctr <= pending_fetches);
		pending_fetches <= pending_fetches + (mem_addr_vld && !mem_req_replaces_last) - mem_data_vld;
		if (jump_target_vld) begin
			// The flush counter tracks fetches still not retired, excluding the one made upon flushing.
			pending_flush_ctr <= pending_fetches - (mem_addr_vld && mem_req_replaces_last) - mem_data_vld;
		end else if (pending_flush_ctr && mem_data_vld) begin
			pending_flush_ctr <= pending_flush_ctr - 1'b1;
		end
	end
end

// Using the non-registered version of pending_fetches would improve FIFO
// utilisation, but create a combinatorial path from hready to address phase!
// TODO: for systems with small FIFOs this might be an interesting tradeoff. Parameter?
wire fetch_stall = fifo_full
	|| fifo_almost_full && pending_fetches
	|| pending_fetches > 2'h1;
assign mem_addr_vld = jump_target_vld || !fetch_stall;

reg unaligned_jump_reg;
wire unaligned_jump_comb = jump_target_vld && jump_target[1:0];
wire unaligned_jump = unaligned_jump_reg || unaligned_jump_comb;

always @ (posedge clk or negedge rst_n) begin
	if (rst_n) begin
		unaligned_jump_reg <= 1'b0;
	end else begin
		unaligned_jump_reg <= unaligned_jump_reg
			&& !(mem_data_vld && !pending_flush_ctr)
			|| unaligned_jump_comb;
	end
end

// ----------------------------------------------------------------------------
// Instruction assembly yard (IMUX)

reg [W_BUNDLE-1:0] halfword_buf;
reg halfword_buf_vld;

wire [W_DATA-1:0] fetch_data = fifo_empty ? mem_data : fifo_rdata;
wire fetch_data_vld = !fifo_empty || (mem_data_vld && !pending_flush_ctr);

// CIR LSBs have 4 sources, on cycles where they change:
// - CIR MSBs (instr was 16 bit)
// - Halfword buffer (instr was 32 bit and hwb valid)
// - Fetch LSBs (instr was 32 bit and hwb nonvalid)
// - Fetch MSBs (unaligned jump)
// CIR MSBs have 3:
// - Halfword buffer (instr was 16-bit and hwb valid)
// - Fetch LSBs (16-bit instr and hwb nonvalid, 32-bit and hwb valid)
// - Fetch MSBs (32-bit instr and hwb nonvalid)
// For unaligned jump/flush, CIR MSBs will always be invalid, so
// we don't care about its value in this case.
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		cir <= 32'h0;
		cir_vld <= 2'h0;
		halfword_buf <= {W_BUNDLE{1'b0}};
		halfword_buf_vld <= 1'b0;
	end else begin
		// Update CIR contents
		if (cir_rdy || jump_target_vld || unaligned_jump_reg) begin
			case (1'b1)
				unaligned_jump                  : cir[0 +: W_BUNDLE] <= fetch_data[W_BUNDLE +: W_BUNDLE];
				cir_rdy[1] && !halfword_buf_vld : cir[0 +: W_BUNDLE] <= fetch_data[0 +: W_BUNDLE];
				cir_rdy[1]                      : cir[0 +: W_BUNDLE] <= halfword_buf;
				default                         : cir[0 +: W_BUNDLE] <= cir[W_BUNDLE +: W_BUNDLE];
			endcase
			case (1'b1)
				cir_rdy[1] ~^ halfword_buf_vld  : cir[W_BUNDLE +: W_BUNDLE] <= fetch_data[0 +: W_BUNDLE];
				cir_rdy[1]                      : cir[W_BUNDLE +: W_BUNDLE] <= fetch_data[W_BUNDLE +: W_BUNDLE];
				default                         : cir[W_BUNDLE +: W_BUNDLE] <= halfword_buf;
			endcase
		end
		// Update CIR flags
		
	end
end

endmodule