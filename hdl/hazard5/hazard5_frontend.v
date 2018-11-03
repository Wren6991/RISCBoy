module hazard5_frontend #(
	parameter W_ADDR = 32,   // other sizes currently unsupported
	parameter W_DATA = 32,   // other sizes currently unsupported
	parameter FIFO_DEPTH = 2 // power of 2, >= 1
) (
	input wire clk,
	input wire rst_n,

	// Fetch interface
	// addr_vld may be asserted at any time, but after assertion,
	// neither addr nor addr_vld may change until the cycle after addr_rdy.
	// There is no backpressure on the data interface; the front end
	// must ensure it does not request data it cannot receive.
	// addr_rdy and dat_vld may be functions of hready, and
	// may not be used to compute combinational outputs.
	output wire              mem_size, // 1'b1 -> 32 bit access
	output wire [W_ADDR-1:0] mem_addr,
	output wire              mem_addr_vld,
	input wire               mem_addr_rdy,
	input wire  [W_DATA-1:0] mem_data,
	input wire               mem_data_vld,

	// Jump/flush interface
	// Processor may assert vld at any time. The request will not go through
	// unless rdy is high. Processor *may* alter request during this time.
	// Inputs must not be a function of hready.
	input wire  [W_ADDR-1:0] jump_target,
	input wire               jump_target_vld,
	output wire              jump_target_rdy,

	// Interface to Decode
	// Note reg/wire distinction
	// => decode is providing live feedback on the CIR it is decoding,
	//    which we fetched previously
	// This works OK because size is decoded from 2 LSBs of instruction, so cheap.
	output reg  [31:0]       cir,
	output reg  [1:0]        cir_vld, // number of valid halfwords in CIR
	input wire  [1:0]        cir_req  // number of halfwords D will have room for
);


`ifdef FORMAL
`define ASSERT(x) assert(x)
`else
`define ASSERT(x)
`endif

//synthesis translate_off
initial if (W_DATA != 32) begin $error("Frontend requires 32-bit databus"); end
initial if ((1 << $clog2(FIFO_DEPTH)) != FIFO_DEPTH) begin $error("Frontend FIFO depth must be power of 2"); end
initial if (!FIFO_DEPTH) begin $error("Frontend FIFO depth must be > 0"); end
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
wire fifo_full = fifo_wptr ^ fifo_rptr == (1'b1 & {W_FIFO_PTR{1'b1}}) << (W_FIFO_PTR - 1);
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

// Keep track of some useful state of the memory interface

reg        mem_addr_hold;
reg  [1:0] pending_fetches;
reg  [1:0] ctr_flush_pending;
wire [1:0] pending_fetches_next = pending_fetches + (mem_addr_vld && mem_addr_rdy) - mem_data_vld;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mem_addr_hold <= 1'b0;
		pending_fetches <= 2'h0;
		ctr_flush_pending <= 2'h0;
	end else begin
		`ASSERT(ctr_flush_pending <= pending_fetches);
		mem_addr_hold <= mem_addr_vld && !mem_addr_rdy;
		pending_fetches <= pending_fetches_next;
		if (jump_target_vld && jump_target_rdy) begin
			// If the jump request goes straight to the bus, exclude from flush count
			ctr_flush_pending <= pending_fetches_next - !mem_addr_hold;
		end else if (ctr_flush_pending && mem_data_vld) begin
			ctr_flush_pending <= ctr_flush_pending - 1'b1;
		end
	end
end

// Fetch addr runs ahead of the PC, in word increments.
reg [W_ADDR-1:0] fetch_addr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		fetch_addr <= {W_ADDR{1'b0}}; // TODO: reset vectoring
	end else begin
		if (jump_target_vld && jump_target_rdy) begin
			fetch_addr <= {jump_target[W_ADDR-1:2], 2'b00} + (mem_addr_rdy ? 3'h4 : 3'h0);
		end else if (mem_addr_vld && mem_addr_rdy) begin
			fetch_addr <= fetch_addr + 3'h4;
		end
	end
end

// Using the non-registered version of pending_fetches would improve FIFO
// utilisation, but create a combinatorial path from hready to address phase!
wire fetch_stall = fifo_full
	|| fifo_almost_full && pending_fetches
	|| pending_fetches > 2'h1;


// unaligned jump is handled in two different places:
// - during address phase, offset may be applied to fetch_addr if hready was low when jump_vld was high
// - during data phase, need to assemble CIR differently.

wire unaligned_jump_now = jump_target_rdy && jump_target_vld && jump_target[1];
reg unaligned_jump_aph;
reg unaligned_jump_dph;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		unaligned_jump_aph <= 1'b0;
		unaligned_jump_dph <= 1'b0;
	end else begin
		if (mem_addr_rdy) begin
			unaligned_jump_aph <= 1'b0;
		end
		if (mem_data_vld && !ctr_flush_pending) begin
			unaligned_jump_dph <= 1'b0;
		end
		if (unaligned_jump_now) begin
			unaligned_jump_dph <= 1'b1;
			unaligned_jump_aph <= !mem_addr_rdy;
		end
	end
end

// Combinatorially generate the address-phase request
always @ (*) begin
	mem_addr = {W_ADDR{1'b0}};
	mem_addr_vld = 1'b1;
	mem_size = 1'b1; // almost all accesses are 32 bit
	case (1'b1)
		mem_addr_hold   : begin mem_addr = {fetch_addr[W_ADDR-1:2], unaligned_jump_aph, 1'b0}; mem_size = !unaligned_jump_aph; end
		jump_target_vld : begin mem_addr = jump_target; mem_size = !unaligned_jump_now; end
		!fetch_stall    : begin mem_addr = fetch_addr; end
		default         : begin mem_addr_vld = 1'b0; end
	endcase
end

assign jump_target_rdy = !mem_addr_hold;


// ----------------------------------------------------------------------------
// Instruction assembly yard (IMUX)

/*------------+---------------------------------+-----------------------------------+-----------------------------------+
| buf  \  req |                0                |               1                   |             2                     |
+-------------+---------------------------------+-----------------------------------+-----------------------------------+
|      0      | Decode stalled, don't touch     | Shouldn't happen                  | Fill empty CIR                    |
|             |                                 | (assert this)                     |                                   |
+-------------+---------------------------------+-----------------------------------+-----------------------------------+
|      1      | Decode stalled, don't touch     | Tried to decode half of 32b.      | Decoded 16b instruction.          |
|             |                                 | Need topup.                       | Want full refill.                 |
+-------------+---------------------------------+-----------------------------------+-----------------------------------+
|      2      | Decode stalled, don't touch     | Decoded lower half as 16b.        | Full 32-bit CIR decoded.          |
|             |                                 | Shift and topup.                  | Want full refill.                 |
+-------------+---------------------------------+-----------------------------------+-----------------------------------+
|      3      | Decode stalled, don't touch     | Decoded lower hw as 16b.          | Full 32-bit CIR decoded.          |
|             |                                 | Shift and topup.                  | Shift in from hwbuf and backfill. |
+-------------+---------------------------------+-----------------------------------+----------------------------------*/

wire [W_DATA-1:0] fetch_data = fifo_empty ? mem_data : fifo_rdata;
wire fetch_data_vld = !fifo_empty || (mem_data_vld && !ctr_flush_pending);

// buf_level is the number of valid halfwords in {hwbuf, cir}.
// cir_vld and hwbuf_vld are functions of this.
reg [1:0] buf_level;
reg [W_BUNDLE-1:0] hwbuf;
reg hwbuf_vld;

wire [1:0] instr_consumption = cir_req <= cir_vld ? cir_req : cir_vld;
wire buf_level_next =
	jump_target_vld || ctr_flush_pending ? 2'h0 :
	fetch_data_vld && unaligned_jump_dph ? 2'h1 :
	buf_level + {fetch_data_vld, 1'b0} - instr_consumption;



always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		buf_level <= 2'h0;
		hwbuf_vld <= 1'b0;
		cir_vld <= 2'h0;
		cir <= 32'h0;
		hwbuf <= {W_BUNDLE{1'b0}};
	end else begin
		`ASSERT(cir_vld <= 2);
		`ASSERT(cir_req <= 2);
		`ASSERT(!(cir_vld == 0 && cir_req == 1));
		// Update CIR flags
		buf_level <= buf_level_next;
		cir_vld <= buf_level_next & ~(buf_level_next >> 1'b1);
		hwbuf_vld <= &buf_level_next;
		// Update CIR contents
		if (cir_req) begin
			// LSBs
			casez ({unaligned_jump_dph, cir_req, buf_level})
				5'b1_??_?? : cir[0 +: W_BUNDLE] <= fetch_data[W_BUNDLE +: W_BUNDLE];
				5'b0_?1_1? : cir[0 +: W_BUNDLE] <= cir[W_BUNDLE +: W_BUNDLE];
                5'b0_1?_11 : cir[0 +: W_BUNDLE] <= hwbuf;
                5'b0_1?_?? : cir[0 +: W_BUNDLE] <= fetch_data[0 +: W_BUNDLE];
				default: begin end
			endcase
			// MSBs














































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
		hwbuf <= {W_BUNDLE{1'b0}};
		hwbuf_vld <= 1'b0;
	end else begin
		// Update CIR contents
		if (cir_rdy || jump_target_vld || unaligned_jump_reg) begin
			case (1'b1)
				unaligned_jump_dph              : cir[0 +: W_BUNDLE] <= fetch_data[W_BUNDLE +: W_BUNDLE];
				cir_rdy[1] && !hwbuf_vld : cir[0 +: W_BUNDLE] <= fetch_data[0 +: W_BUNDLE];
				cir_rdy[1]                      : cir[0 +: W_BUNDLE] <= hwbuf;
				default                         : cir[0 +: W_BUNDLE] <= cir[W_BUNDLE +: W_BUNDLE];
			endcase
			case (1'b1)
				cir_rdy[1] ~^ hwbuf_vld  : cir[W_BUNDLE +: W_BUNDLE] <= fetch_data[0 +: W_BUNDLE];
				cir_rdy[1]                      : cir[W_BUNDLE +: W_BUNDLE] <= fetch_data[W_BUNDLE +: W_BUNDLE];
				default                         : cir[W_BUNDLE +: W_BUNDLE] <= hwbuf;
			endcase
		end
		// Update CIR flags
		
	end
end

endmodule